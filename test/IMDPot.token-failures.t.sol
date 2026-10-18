// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

/// @dev An offline external asset, deliberately moving balances BEFORE returning bad data.
contract MalformedPotToken {
    enum Reply {
        True,
        Empty,
        False,
        Short,
        Long,
        NonBoolean,
        RevertAfterMove,
        ExhaustGas
    }

    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    Reply public incoming;
    Reply public outgoing;
    uint256 public recipientFeeBps;
    uint256 public senderFeeBps;
    bool public noMovement;
    address public gasGriefRecipient;
    error TokenRejected();

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setReplies(Reply incoming_, Reply outgoing_) external {
        incoming = incoming_;
        outgoing = outgoing_;
    }

    function setFees(uint256 recipientFee_, uint256 senderFee_) external {
        recipientFeeBps = recipientFee_;
        senderFeeBps = senderFee_;
    }

    function setNoMovement(bool value) external {
        noMovement = value;
    }

    function setGasGriefRecipient(address recipient) external {
        gasGriefRecipient = recipient;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        if (!noMovement) _move(from, to, amount);
        return _reply(incoming);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (!noMovement) _move(msg.sender, to, amount);
        if (to == gasGriefRecipient) {
            assembly ("memory-safe") { invalid() }
        }
        return _reply(outgoing);
    }

    function _move(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount + amount * senderFeeBps / 10_000;
        balanceOf[to] += amount - amount * recipientFeeBps / 10_000;
    }

    function _reply(Reply reply) private pure returns (bool) {
        if (reply == Reply.True) return true;
        if (reply == Reply.Empty) {
            assembly ("memory-safe") { return(0, 0) }
        }
        if (reply == Reply.False) return false;
        if (reply == Reply.Short) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(31, 1)
            }
        }
        if (reply == Reply.Long) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 0)
                return(0, 64)
            }
        }
        if (reply == Reply.NonBoolean) {
            assembly ("memory-safe") {
                mstore(0, 2)
                return(0, 32)
            }
        }
        if (reply == Reply.RevertAfterMove) revert TokenRejected();
        assembly ("memory-safe") { invalid() }
    }
}

contract IMDPotTokenFailuresTest is Test {
    IMDPot internal pot;
    MalformedPotToken internal token;
    address internal owner;
    address internal alice;
    address internal bob;

    function setUp() public {
        vm.warp(1_800_000_123);
        vm.roll(1000);
        owner = makeAddr("malformed owner");
        alice = makeAddr("malformed alice");
        bob = makeAddr("malformed bob");
        pot = new IMDPot(owner);
        token = new MalformedPotToken();
        vm.prank(owner);
        pot.setToken(address(token));
        token.mint(alice, 1_000_000 ether);
        token.mint(bob, 1_000_000 ether);
        vm.prank(alice);
        token.approve(address(pot), type(uint256).max);
        vm.prank(bob);
        token.approve(address(pot), type(uint256).max);
    }

    function _buy(address account, uint256 count) internal {
        vm.prank(account);
        pot.buyTickets(count);
    }

    function _commit() internal returns (uint256 target) {
        vm.warp(pot.getRound(pot.currentRoundId()).endTime);
        pot.finalizeRound();
        target = pot.getRound(pot.currentRoundId()).drawBlock;
    }

    function _settle() internal {
        uint256 target = _commit();
        vm.roll(target + 1);
        vm.setBlockhash(target, keccak256(abi.encode("malformed draw", pot.currentRoundId())));
        pot.finalizeRound();
    }

    function _cancel() internal {
        uint256 target = _commit();
        vm.roll(target + 257);
        pot.cancelRound();
    }

    function _entryHash(address account) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                pot.getRound(1),
                pot.getParticipants(1),
                pot.totalWeight(1),
                pot.ticketsOf(1, account),
                pot.participantIndex(1, account),
                token.balanceOf(account),
                token.balanceOf(address(pot)),
                token.allowance(account, address(pot)),
                pot.totalObligations()
            )
        );
    }

    function _badReply(uint8 raw) internal pure returns (MalformedPotToken.Reply) {
        // ExhaustGas is tested in the bounded fee self-call, rather than consuming all test gas.
        return MalformedPotToken.Reply(2 + raw % 5);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_malformedEntryRevertsEveryEffect(uint8 reply, uint32 rawCount, bool roundStarted) public {
        if (roundStarted) _buy(alice, 4);
        uint256 count = bound(rawCount, 1, 1_000_000);
        token.setReplies(_badReply(reply), MalformedPotToken.Reply.True);
        bytes32 beforeState = _entryHash(bob);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        _buy(bob, count);
        assertEq(_entryHash(bob), beforeState);
        token.setReplies(MalformedPotToken.Reply.Empty, MalformedPotToken.Reply.Empty);
        _buy(bob, count);
        assertEq(pot.ticketsOf(1, bob), count, "failed entry must not leave a ticket or stuck guard");
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_malformedClaimPreservesTheEntireCredit(uint8 reply) public {
        _buy(alice, 10);
        _settle();
        uint256 credit = pot.claimable(alice);
        uint256 balance = token.balanceOf(alice);
        uint256 held = token.balanceOf(address(pot));
        token.setReplies(MalformedPotToken.Reply.True, _badReply(reply));
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        vm.prank(alice);
        pot.claim();
        assertEq(pot.claimable(alice), credit);
        assertEq(pot.totalClaimable(), credit);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(address(pot)), held);
        token.setReplies(MalformedPotToken.Reply.True, MalformedPotToken.Reply.Empty);
        vm.prank(alice);
        pot.claim();
        assertEq(token.balanceOf(alice), balance + credit);
        assertEq(pot.totalClaimable(), 0);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_taxOrSenderSurchargeCannotConsumeAClaimOrRefund(uint16 rawFee, bool senderCharged, bool refunding)
        public
    {
        _buy(alice, 10);
        if (refunding) _cancel();
        else _settle();
        // A donation ensures a sender surcharge is affordable: the balance delta check must catch it.
        token.mint(address(pot), 1 ether);
        uint256 fee = bound(rawFee, 1, 10_000);
        token.setFees(senderCharged ? 0 : fee, senderCharged ? fee : 0);
        uint256 amount = refunding ? 1 ether : pot.claimable(alice);
        uint256 held = token.balanceOf(address(pot));
        uint256 balance = token.balanceOf(alice);
        uint256 obligations = pot.totalObligations();
        vm.expectRevert(IMDPot.TransferAmountMismatch.selector);
        vm.prank(alice);
        if (refunding) pot.refund(1);
        else pot.claim();
        assertEq(token.balanceOf(address(pot)), held);
        assertEq(token.balanceOf(alice), balance);
        assertEq(pot.totalObligations(), obligations);
        if (refunding) {
            assertEq(pot.totalRefundable(), amount);
            assertEq(pot.ticketsOf(1, alice), 10);
        } else {
            assertEq(pot.claimable(alice), amount);
        }
        token.setFees(0, 0);
        vm.prank(alice);
        if (refunding) pot.refund(1);
        else pot.claim();
        assertEq(token.balanceOf(alice), balance + amount);
        assertEq(token.balanceOf(address(pot)) - pot.totalObligations(), 1 ether);
    }

    function test_trueReturnWithoutMovingValueCannotMintTicketsOrErasePrizeCredits() public {
        token.setNoMovement(true);
        vm.expectRevert(IMDPot.TransferAmountMismatch.selector);
        _buy(alice, 10);
        assertEq(pot.getRound(1).startTime, 0);
        assertEq(pot.getParticipants(1).length, 0);
        token.setNoMovement(false);
        _buy(alice, 10);
        _settle();
        token.setNoMovement(true);
        vm.expectRevert(IMDPot.TransferAmountMismatch.selector);
        vm.prank(alice);
        pot.claim();
        assertEq(pot.claimable(alice), 0.7 ether);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function test_feeGasGriefIsIsolatedFromOtherFeesAndWinnerWithdrawals() public {
        _buy(alice, 10);
        token.setGasGriefRecipient(pot.DEAD_ADDRESS());
        _settle();
        assertEq(pot.pendingBurn(), 0.1 ether);
        assertEq(pot.pendingTreasury(), 0);
        assertEq(token.balanceOf(owner), 0.05 ether);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0, "failed transfer must roll back the move");
        vm.prank(alice);
        pot.claim();
        assertEq(pot.totalClaimable(), 0);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
        token.setGasGriefRecipient(owner);
        _buy(bob, 20);
        _settle();
        assertEq(pot.pendingBurn(), 0);
        assertEq(pot.pendingTreasury(), 0.1 ether);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0.3 ether);
        vm.prank(owner);
        pot.pause();
        token.setGasGriefRecipient(alice);
        vm.prank(bob);
        pot.flushPendingFees();
        assertEq(pot.pendingTreasury(), 0);
        assertEq(token.balanceOf(owner), 0.15 ether);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_deferredMalformedFeesAccumulateAndCanBeRetriedWhilePaused(uint8 reply) public {
        _buy(alice, 10);
        token.setReplies(MalformedPotToken.Reply.True, _badReply(reply));
        _settle();
        _buy(bob, 20);
        _settle();
        assertEq(pot.pendingBurn(), 0.3 ether);
        assertEq(pot.pendingTreasury(), 0.15 ether);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0);
        assertEq(pot.totalClaimable(), 2.1 ether);
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
        vm.prank(owner);
        pot.pause();
        pot.flushPendingFees();
        assertEq(pot.pendingBurn(), 0.3 ether);
        assertEq(pot.pendingTreasury(), 0.15 ether);
        token.setReplies(MalformedPotToken.Reply.True, MalformedPotToken.Reply.Empty);
        vm.prank(alice);
        pot.flushPendingFees();
        assertEq(token.balanceOf(owner), 0.15 ether);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0.3 ether);
        assertEq(pot.pendingBurn() + pot.pendingTreasury(), 0);
        vm.expectRevert(IMDPot.NothingToFlush.selector);
        pot.flushPendingFees();
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function test_foreignRescueValidatesDestinationAndRollsBackMalformedTransfer() public {
        _buy(alice, 10);
        MalformedPotToken foreign = new MalformedPotToken();
        foreign.mint(address(pot), 100 ether);
        vm.startPrank(owner);
        vm.expectRevert(IMDPot.ZeroAddress.selector);
        pot.rescueForeignToken(address(foreign), address(0));
        vm.expectRevert(IMDPot.ZeroAddress.selector);
        pot.rescueForeignToken(address(foreign), address(pot));
        vm.expectRevert(abi.encodeWithSelector(IMDPot.NotAContract.selector, bob));
        pot.rescueForeignToken(bob, alice);
        vm.stopPrank();
        foreign.setReplies(MalformedPotToken.Reply.True, MalformedPotToken.Reply.NonBoolean);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(foreign)));
        vm.prank(owner);
        pot.rescueForeignToken(address(foreign), alice);
        assertEq(foreign.balanceOf(address(pot)), 100 ether);
        assertEq(foreign.balanceOf(alice), 0);
        foreign.setReplies(MalformedPotToken.Reply.True, MalformedPotToken.Reply.Empty);
        vm.prank(owner);
        pot.rescueForeignToken(address(foreign), alice);
        assertEq(foreign.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(address(pot)), 1 ether);
        assertEq(pot.ticketsOf(1, alice), 10);
    }

    /// @dev The callback token is ALSO the owner, so onlyOwner cannot mask a missing guard.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_ownerTokenCallbackCannotReenterAnyStateChangingEntrypoint(uint8 operation) public {
        MockToken callbackToken = new MockToken(18);
        IMDPot callbackPot = new IMDPot(address(callbackToken));
        vm.prank(address(callbackToken));
        callbackPot.setToken(address(callbackToken));
        bytes[] memory calls = new bytes[](15);
        calls[0] = abi.encodeCall(IMDPot.buyTickets, (1));
        calls[1] = abi.encodeCall(IMDPot.buyTicketsForRound, (1, 1));
        calls[2] = abi.encodeCall(IMDPot.finalizeRound, ());
        calls[3] = abi.encodeCall(IMDPot.cancelRound, ());
        calls[4] = abi.encodeCall(IMDPot.refund, (1));
        calls[5] = abi.encodeCall(IMDPot.claim, ());
        calls[6] = abi.encodeCall(IMDPot.flushPendingFees, ());
        calls[7] = abi.encodeCall(IMDPot.syncPoints, (alice));
        calls[8] = abi.encodeCall(IMDPot.redeemMultiplier, ());
        calls[9] = abi.encodeCall(IMDPot.transferOwnership, (bob));
        calls[10] = abi.encodeCall(IMDPot.acceptOwnership, ());
        calls[11] = abi.encodeCall(IMDPot.pause, ());
        calls[12] = abi.encodeCall(IMDPot.unpause, ());
        calls[13] = abi.encodeCall(IMDPot.setToken, (address(token)));
        calls[14] = abi.encodeCall(IMDPot.rescueForeignToken, (address(token), bob));
        callbackToken.setCallback(address(callbackPot), calls[operation % calls.length]);
        callbackToken.mint(alice, 1 ether);
        vm.prank(alice);
        callbackToken.approve(address(callbackPot), 1 ether);
        vm.prank(alice);
        callbackPot.buyTicketsForRound(1, 10);
        assertFalse(callbackToken.callbackSucceeded());
        assertEq(callbackToken.callbackResult(), abi.encodeWithSelector(IMDPot.ReentrancyGuardReentrantCall.selector));
        assertEq(callbackPot.ticketsOf(1, alice), 10);
        assertEq(callbackPot.owner(), address(callbackToken));
        assertEq(callbackPot.pendingOwner(), address(0));
        assertFalse(callbackPot.paused());
        assertEq(callbackToken.balanceOf(address(callbackPot)), callbackPot.totalObligations());
    }
}
