// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

/// @dev Complements the original suite with atomicity, handover and cross-round cases.
contract IMDPotBoundariesTest is Test {
    IMDPot internal pot;
    MockToken internal token;
    address internal owner;
    address internal alice;
    address internal bob;

    function setUp() public {
        vm.warp(1_800_000_123);
        vm.roll(10_000);
        owner = makeAddr("boundary owner");
        alice = makeAddr("boundary alice");
        bob = makeAddr("boundary bob");
        pot = new IMDPot(owner);
        token = new MockToken(18);
        vm.prank(owner);
        pot.setToken(address(token));
        token.mint(alice, 1_000_000 ether);
        token.mint(bob, 1_000_000 ether);
        vm.prank(alice);
        token.approve(address(pot), type(uint256).max);
        vm.prank(bob);
        token.approve(address(pot), type(uint256).max);
    }

    function _buy(address actor, uint256 count) internal {
        vm.prank(actor);
        pot.buyTickets(count);
    }

    function _settle() internal {
        uint256 id = pot.currentRoundId();
        vm.warp(pot.getRound(id).endTime);
        pot.finalizeRound();
        uint256 target = pot.getRound(id).drawBlock;
        vm.roll(target + 1);
        vm.setBlockhash(target, keccak256(abi.encode("boundary draw", id)));
        pot.finalizeRound();
    }

    function _cancel() internal {
        uint256 id = pot.currentRoundId();
        vm.warp(pot.getRound(id).endTime);
        pot.finalizeRound();
        vm.roll(pot.getRound(id).drawBlock + 257);
        pot.cancelRound();
    }

    function _playerHash(address actor) internal view returns (bytes32) {
        (uint256 points, uint256 played, uint256 boost, bool redeem) = pot.getPlayer(actor);
        return keccak256(abi.encode(points, played, boost, redeem));
    }

    function _stateHash(uint256 id, address actor) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                pot.getRound(id),
                pot.getParticipants(id),
                pot.participantIndex(id, actor),
                pot.ticketsOf(id, actor),
                pot.roundBoostBps(id, actor),
                pot.totalWeight(id),
                pot.currentRoundId(),
                pot.totalObligations(),
                pot.claimable(actor),
                _playerHash(actor),
                token.balanceOf(actor),
                token.balanceOf(address(pot)),
                token.allowance(actor, address(pot))
            )
        );
    }

    function test_maximumPurchaseIsPerCallAndMaxUintCannotMutateAnActiveRound() public {
        _buy(alice, 1_000_000);
        _buy(alice, 1_000_000);
        assertEq(pot.ticketsOf(1, alice), 2_000_000);
        assertEq(pot.getParticipants(1).length, 1);
        bytes32 beforeState = _stateHash(1, alice);
        vm.expectRevert(IMDPot.InvalidTicketCount.selector);
        vm.prank(alice);
        pot.buyTickets(type(uint256).max);
        assertEq(_stateHash(1, alice), beforeState);
        assertEq(token.balanceOf(address(pot)), 200_000 ether);
        assertEq(pot.totalWeight(1), 20_000_000_000);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_deadlinePurchaseAndCommitAreComplementary(uint32 offset, bool guarded) public {
        _buy(alice, 1);
        uint256 end = pot.getRound(1).endTime;
        uint256 time = end - 1 + bound(offset, 0, 2);
        vm.warp(time);
        if (time < end) {
            vm.prank(bob);
            if (guarded) pot.buyTicketsForRound(1, 1);
            else pot.buyTickets(1);
            assertEq(pot.timeRemaining(), 1);
            vm.expectRevert(IMDPot.RoundNotEnded.selector);
            pot.finalizeRound();
        } else {
            bytes32 beforeState = _stateHash(1, bob);
            vm.expectRevert(IMDPot.RoundClosed.selector);
            vm.prank(bob);
            if (guarded) pot.buyTicketsForRound(1, 1);
            else pot.buyTickets(1);
            assertEq(_stateHash(1, bob), beforeState);
            pot.finalizeRound();
            assertEq(pot.timeRemaining(), 0);
            assertEq(uint256(pot.getRound(1).status), uint256(IMDPot.RoundStatus.Drawing));
        }
        assertEq(pot.getRound(1).endTime, end);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function test_failedFirstPurchaseDoesNotConsumeQueuedBoostOrCreditPriorRoundTwice() public {
        for (uint256 i; i < 10; ++i) {
            _buy(alice, 100);
            _settle();
        }
        vm.prank(alice);
        pot.redeemMultiplier();
        uint256 id = pot.currentRoundId();
        vm.prank(alice);
        token.approve(address(pot), 0);
        bytes32 beforeState = _stateHash(id, alice);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        _buy(alice, 1);
        assertEq(_stateHash(id, alice), beforeState);
        assertEq(pot.timeRemaining(), 900);
        (uint256 points, uint256 played, uint256 boost,) = pot.getPlayer(alice);
        assertEq(points, 900);
        assertEq(played, 10);
        assertEq(boost, 2500);
        vm.prank(alice);
        token.approve(address(pot), 1 ether);
        _buy(alice, 1);
        assertEq(pot.weightOf(id, alice), 12_500);
        assertEq(pot.roundBoostBps(id, alice), 2500);
        (points, played, boost,) = pot.getPlayer(alice);
        assertEq(points, 900);
        assertEq(played, 10);
        assertEq(boost, 0);
    }

    function test_refundsCanBeClaimedOutOfOrderWhilePrizesAndNewRoundStayIndependent() public {
        _buy(alice, 3);
        _cancel();
        _buy(alice, 5);
        _settle();
        _buy(alice, 7);
        _cancel();
        _buy(bob, 11);
        bytes32 liveRound = keccak256(abi.encode(pot.getRound(4)));
        uint256 claim = pot.claimable(alice);
        vm.prank(owner);
        pot.pause();
        uint256 beforeBalance = token.balanceOf(alice);
        vm.prank(alice);
        pot.refund(3);
        vm.prank(alice);
        pot.claim();
        vm.prank(alice);
        pot.refund(1);
        assertEq(token.balanceOf(alice) - beforeBalance, 1 ether + claim);
        assertEq(pot.totalRefundable(), 0);
        assertEq(pot.totalClaimable(), 0);
        assertEq(pot.ticketsOf(2, alice), 5, "claim must preserve settled participation");
        assertEq(keccak256(abi.encode(pot.getRound(4))), liveRound);
        assertEq(pot.ticketsOf(4, bob), 11);
        assertEq(pot.currentRoundId(), 4);
        assertEq(token.balanceOf(address(pot)), pot.totalLocked() + 1.1 ether);
        vm.expectRevert(IMDPot.NothingToRefund.selector);
        vm.prank(alice);
        pot.refund(3);
        vm.expectRevert(IMDPot.RoundNotCancelled.selector);
        vm.prank(alice);
        pot.refund(2);
        vm.expectRevert(IMDPot.RoundNotCancelled.selector);
        vm.prank(alice);
        pot.refund(type(uint256).max);
        (uint256 points, uint256 played,,) = pot.getPlayer(alice);
        assertEq(points, 5);
        assertEq(played, 1);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_allOwnerMethodsRejectAnUnprivilegedCaller(address caller, uint8 operation) public {
        if (caller == owner) caller = alice;
        bytes[] memory calls = new bytes[](6);
        calls[0] = abi.encodeCall(IMDPot.setToken, (address(token)));
        calls[1] = abi.encodeCall(IMDPot.pause, ());
        calls[2] = abi.encodeCall(IMDPot.unpause, ());
        calls[3] = abi.encodeCall(IMDPot.transferOwnership, (caller));
        calls[4] = abi.encodeCall(IMDPot.renounceOwnership, ());
        calls[5] = abi.encodeCall(IMDPot.rescueForeignToken, (address(token), caller));
        vm.prank(caller);
        (bool ok, bytes memory result) = address(pot).call(calls[operation % calls.length]);
        assertFalse(ok);
        assertEq(result, abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, caller));
        assertEq(pot.owner(), owner);
        assertEq(pot.pendingOwner(), address(0));
        assertFalse(pot.paused());
        assertEq(pot.token(), address(token));
    }

    function test_replacedOwnershipNomineeCannotAcceptAndFeesStillPayOriginalOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableInvalidOwner.selector, address(pot)));
        pot.transferOwnership(address(pot));
        pot.transferOwnership(alice);
        pot.transferOwnership(bob);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        pot.acceptOwnership();
        vm.prank(bob);
        pot.acceptOwnership();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, owner));
        vm.prank(owner);
        pot.pause();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, owner));
        vm.prank(owner);
        pot.transferOwnership(owner);
        _buy(alice, 10);
        _settle();
        assertEq(token.balanceOf(owner), 0.05 ether);
        assertEq(token.balanceOf(bob), 1_000_000 ether, "handover must not redirect fees");
        assertEq(pot.TREASURY(), owner);
    }

    function test_cancelledReviewedRoundCannotEnterFreshRoundOrChangePause() public {
        _buy(alice, 1);
        vm.prank(owner);
        pot.pause();
        vm.warp(pot.getRound(1).endTime + 1 days);
        vm.prank(bob);
        pot.cancelRound();
        assertTrue(pot.paused());
        assertEq(pot.currentRoundId(), 2);
        vm.prank(owner);
        pot.unpause();
        bytes32 beforeState = _stateHash(2, bob);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.UnexpectedRound.selector, 1, 2));
        vm.prank(bob);
        pot.buyTicketsForRound(1, 2);
        assertEq(_stateHash(2, bob), beforeState);
        uint256 newStart = vm.getBlockTimestamp() + 30 days;
        vm.warp(newStart);
        _buy(bob, 1);
        assertEq(pot.getRound(2).startTime, newStart);
        assertEq(pot.timeRemaining(), 900);
    }
}
