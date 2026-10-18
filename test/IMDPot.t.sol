// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "../src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

contract FactoryProbe {
    function deploy(address owner) external returns (IMDPot) {
        return new IMDPot(owner);
    }
}

/// @dev A contract wallet exercising the same calls used by an embedded Privy wallet.
contract PlayerWallet {
    IMDPot private pot;
    bool public reentered;
    bytes public result;

    constructor(IMDPot pot_) {
        pot = pot_;
    }

    function buy(MockToken token, uint256 count) external {
        token.approve(address(pot), count * pot.ticketPrice());
        pot.buyTickets(count);
    }

    function claim() external {
        pot.claim();
    }

    function refund(uint256 id) external {
        pot.refund(id);
    }

    function onTokenTransfer() external {
        (reentered, result) = address(pot).call(abi.encodeCall(IMDPot.claim, ()));
    }

    function onRefundTransfer(uint256 id) external {
        (reentered, result) = address(pot).call(abi.encodeCall(IMDPot.refund, (id)));
    }
}

contract IMDPotTest is Test {
    IMDPot internal pot;
    MockToken internal token;
    address internal admin;
    address internal alice;
    address internal bob;
    address internal carol;

    function setUp() public {
        vm.warp(1_800_000_000);
        vm.roll(1000);
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        pot = new IMDPot(admin);
        token = new MockToken(18);
        vm.prank(admin);
        pot.setToken(address(token));
        _fund(alice);
        _fund(bob);
        _fund(carol);
    }

    function _fund(address account) internal {
        token.mint(account, 1_000_000 ether);
        vm.prank(account);
        token.approve(address(pot), type(uint256).max);
    }

    function _buy(address account, uint256 count) internal {
        vm.prank(account);
        pot.buyTickets(count);
    }

    function _commit() internal returns (uint256 target) {
        vm.warp(pot.getRound(pot.currentRoundId()).endTime);
        pot.finalizeRound();
        return pot.getRound(pot.currentRoundId()).drawBlock;
    }

    function _settle() internal {
        uint256 target = _commit();
        vm.roll(target + 1);
        vm.setBlockhash(target, keccak256(abi.encode("test draw", pot.currentRoundId())));
        pot.finalizeRound();
    }

    function _assertConserved() internal view {
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function _cancelExpired() internal {
        uint256 target = _commit();
        vm.roll(target + 257);
        pot.cancelRound();
    }

    function _earnLoyalty(address account) internal {
        for (uint256 i; i < 10; ++i) {
            _buy(account, 100);
            _settle();
        }
    }

    function test_factoryUsesExplicitLaunchOwnerWithoutExternalConstructorCalls() public {
        FactoryProbe factory = new FactoryProbe();
        IMDPot fresh = factory.deploy(admin);
        assertEq(fresh.owner(), admin);
        assertEq(fresh.TREASURY(), admin);
        assertFalse(fresh.isConfigured());
        assertEq(fresh.currentRoundId(), 1);
        assertEq(fresh.totalObligations(), 0);
        vm.expectRevert(IMDPot.TokenNotConfigured.selector);
        fresh.buyTickets(1);
        vm.expectRevert(IMDPot.TokenNotConfigured.selector);
        fresh.finalizeRound();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableInvalidOwner.selector, address(0)));
        new IMDPot(address(0));
    }

    function test_onlyOwnerCanConfigureAndOnlyOnce() public {
        IMDPot fresh = new IMDPot(admin);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        fresh.setToken(address(token));
        vm.startPrank(admin);
        vm.expectRevert(IMDPot.ZeroAddress.selector);
        fresh.setToken(address(0));
        vm.expectRevert(abi.encodeWithSelector(IMDPot.NotAContract.selector, alice));
        fresh.setToken(alice);
        MockToken noDecimals = new MockToken(0);
        vm.expectRevert(IMDPot.InvalidTokenDecimals.selector);
        fresh.setToken(address(noDecimals));
        MockToken tooMany = new MockToken(19);
        vm.expectRevert(IMDPot.InvalidTokenDecimals.selector);
        fresh.setToken(address(tooMany));
        fresh.setToken(address(token));
        vm.expectRevert(IMDPot.TokenAlreadySet.selector);
        fresh.setToken(address(token));
        vm.stopPrank();
        assertTrue(fresh.isConfigured());
        assertEq(fresh.ticketPrice(), 0.1 ether);
    }

    function testFuzz_priceIsOneTenthForSupportedDecimals(uint8 d) public {
        d = uint8(bound(d, 1, 18));
        IMDPot fresh = new IMDPot(admin);
        MockToken asset = new MockToken(d);
        vm.prank(admin);
        fresh.setToken(address(asset));
        assertEq(fresh.ticketPrice() * 10, 10 ** d);
    }

    function test_timerStartsOnFirstTicketAndDoesNotExtend() public {
        assertEq(pot.timeRemaining(), 900);
        vm.warp(block.timestamp + 1 days);
        _buy(alice, 1);
        IMDPot.Round memory round = pot.getRound(1);
        assertEq(round.startTime, block.timestamp);
        assertEq(round.endTime - round.startTime, 900);
        vm.warp(block.timestamp + 600);
        _buy(bob, 2);
        assertEq(pot.timeRemaining(), 300);
        assertEq(pot.getRound(1).endTime, round.endTime);
        assertEq(pot.getRound(1).participantCount, 2);
        _assertConserved();
    }

    function test_entryRejectsZeroTooManyAndInsufficientApprovalOrBalance() public {
        vm.expectRevert(IMDPot.InvalidTicketCount.selector);
        pot.buyTickets(0);
        vm.expectRevert(IMDPot.InvalidTicketCount.selector);
        pot.buyTickets(1_000_001);
        vm.prank(alice);
        token.approve(address(pot), 0);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        _buy(alice, 1);
        address unfunded = makeAddr("unfunded");
        vm.prank(unfunded);
        token.approve(address(pot), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        _buy(unfunded, 1);
        assertEq(uint256(pot.getRound(1).status), 0);
        assertEq(pot.getParticipants(1).length, 0);
        assertEq(pot.totalWeight(1), 0);
    }

    function test_entryAtDeadlineAndWhileDrawingRejects() public {
        _buy(alice, 1);
        vm.warp(pot.getRound(1).endTime - 1);
        _buy(bob, 1);
        vm.warp(block.timestamp + 1);
        assertEq(pot.timeRemaining(), 0);
        vm.expectRevert(IMDPot.RoundClosed.selector);
        _buy(carol, 1);
        pot.finalizeRound();
        vm.expectRevert(IMDPot.RoundDrawing.selector);
        _buy(carol, 1);
        _assertConserved();
    }

    function test_reviewedPurchaseCannotEnterAnotherRound() public {
        vm.prank(alice);
        pot.buyTicketsForRound(1, 2);
        _settle();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.UnexpectedRound.selector, 1, 2));
        vm.prank(bob);
        pot.buyTicketsForRound(1, 1);
        assertEq(pot.ticketsOf(2, bob), 0);
        vm.prank(bob);
        pot.buyTicketsForRound(2, 1);
        assertEq(pot.ticketsOf(2, bob), 1);
        _assertConserved();
    }

    function test_repeatedPurchasesDoNotDuplicateParticipants() public {
        _buy(alice, 2);
        _buy(bob, 1);
        _buy(alice, 3);
        assertEq(pot.ticketsOf(1, alice), 5);
        assertEq(pot.getRound(1).participantCount, 2);
        assertEq(pot.participantIndex(1, alice), 1);
        assertEq(pot.participantIndex(1, bob), 2);
        assertEq(pot.weightOf(1, alice), 50_000);
        assertEq(pot.totalWeight(1), 60_000);
    }

    function test_finalizeBeforeEntryOrBeforeEndRejects() public {
        vm.expectRevert(IMDPot.RoundNotActive.selector);
        pot.finalizeRound();
        _buy(alice, 1);
        vm.expectRevert(IMDPot.RoundNotEnded.selector);
        pot.finalizeRound();
    }

    function test_drawCommitsExactlyThreeBlocksAndCannotReroll() public {
        _buy(alice, 1);
        uint256 expected = block.number + 3;
        uint256 target = _commit();
        assertEq(target, expected);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.DrawNotReady.selector, target));
        pot.finalizeRound();
        vm.roll(target);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.DrawNotReady.selector, target));
        pot.finalizeRound();
        vm.expectRevert(IMDPot.CancelTooEarly.selector);
        pot.cancelRound();
        vm.roll(target + 1);
        vm.setBlockhash(target, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(IMDPot.DrawHashUnavailable.selector, target));
        pot.finalizeRound();
        assertEq(pot.getRound(1).drawBlock, target);
        vm.setBlockhash(target, bytes32(uint256(123)));
        pot.finalizeRound();
        assertEq(pot.getRound(1).drawBlockHash, bytes32(uint256(123)));
        assertEq(pot.currentRoundId(), 2);
        vm.expectRevert(IMDPot.RoundNotActive.selector);
        pot.finalizeRound();
    }

    function test_lastBlockhashBoundarySettlesAndCannotCancel() public {
        _buy(alice, 1);
        uint256 target = _commit();
        vm.roll(target + 256);
        vm.setBlockhash(target, bytes32(uint256(999)));
        vm.expectRevert(IMDPot.CancelTooEarly.selector);
        pot.cancelRound();
        pot.finalizeRound();
        assertEq(uint256(pot.getRound(1).status), 3);
    }

    function test_expiredDrawCannotSettleOrBeRecommitted() public {
        _buy(alice, 4);
        uint256 target = _commit();
        vm.roll(target + 257);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.DrawExpired.selector, target));
        pot.finalizeRound();
        assertEq(pot.getRound(1).drawBlock, target);
        vm.prank(carol);
        pot.cancelRound();
        assertEq(pot.totalRefundable(), 0.4 ether);
        assertEq(pot.currentRoundId(), 2);
        assertEq(pot.totalLocked(), 0);
        vm.expectRevert(IMDPot.RoundNotActive.selector);
        pot.cancelRound();
        _assertConserved();
    }

    function test_settlementConservesSharesAndPullClaims() public {
        _buy(alice, 1);
        _buy(bob, 1);
        _buy(carol, 1);
        _settle();
        IMDPot.Round memory round = pot.getRound(1);
        assertEq(round.prizes[0], 0.12 ether);
        assertEq(round.prizes[1], 0.06 ether);
        assertEq(round.prizes[2], 0.03 ether);
        assertEq(round.burned, 0.03 ether);
        assertEq(round.treasuryFee, 0.015 ether);
        assertEq(round.locked, 0.045 ether);
        assertTrue(
            round.winners[0] != round.winners[1] && round.winners[1] != round.winners[2]
                && round.winners[0] != round.winners[2]
        );
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), round.burned);
        assertEq(token.balanceOf(admin), round.treasuryFee);
        assertEq(pot.totalClaimable(), 0.21 ether);
        for (uint256 i; i < 3; ++i) {
            vm.prank(round.winners[i]);
            pot.claim();
        }
        assertEq(pot.totalClaimable(), 0);
        assertEq(token.balanceOf(address(pot)), round.locked);
        vm.expectRevert(IMDPot.NothingToClaim.selector);
        vm.prank(round.winners[0]);
        pot.claim();
        _assertConserved();
    }

    function test_oneTicketReceivesAllSeventyPercentAndNoEmptyPrizes() public {
        _buy(alice, 1);
        _settle();
        IMDPot.Round memory round = pot.getRound(1);
        assertEq(round.winners[0], alice);
        assertEq(round.winners[1], address(0));
        assertEq(round.prizes[0], 0.07 ether);
        assertEq(round.prizes[1] + round.prizes[2], 0);
        assertEq(pot.claimable(alice), 0.07 ether);
        _assertConserved();
    }

    function test_twoTicketsCanGiveSameWalletTwoPrizesAndRollThirdIntoFirst() public {
        _buy(alice, 2);
        _settle();
        IMDPot.Round memory round = pot.getRound(1);
        assertEq(round.winners[0], alice);
        assertEq(round.winners[1], alice);
        assertEq(round.prizes[0], 0.1 ether);
        assertEq(round.prizes[1], 0.04 ether);
        assertEq(round.prizes[2], 0);
        assertEq(pot.claimable(alice), 0.14 ether);
        assertEq(pot.totalWeight(1), 20_000);
    }

    function test_oddBaseUnitRoundingAssignedToFirstPrize() public {
        IMDPot tinyPot = new IMDPot(admin);
        MockToken tinyToken = new MockToken(1);
        vm.prank(admin);
        tinyPot.setToken(address(tinyToken));
        tinyToken.mint(alice, 11);
        vm.startPrank(alice);
        tinyToken.approve(address(tinyPot), 11);
        tinyPot.buyTickets(11);
        vm.stopPrank();
        vm.warp(tinyPot.getRound(1).endTime);
        tinyPot.finalizeRound();
        uint256 target = tinyPot.getRound(1).drawBlock;
        vm.roll(target + 1);
        vm.setBlockhash(target, bytes32(uint256(11)));
        tinyPot.finalizeRound();
        IMDPot.Round memory round = tinyPot.getRound(1);
        assertEq(round.prizes[0], 6);
        assertEq(round.prizes[1], 2);
        assertEq(round.prizes[2], 1);
        assertEq(round.burned + round.treasuryFee + round.locked + tinyPot.totalClaimable(), 11);
        assertEq(tinyToken.balanceOf(address(tinyPot)), tinyPot.totalObligations());
    }

    function test_pauseBlocksEntriesAndCommitButCommittedDrawSettlesAndClaimsWork() public {
        _buy(alice, 1);
        vm.prank(admin);
        pot.pause();
        vm.expectRevert(IMDPot.EnforcedPause.selector);
        _buy(bob, 1);
        vm.warp(pot.getRound(1).endTime);
        vm.expectRevert(IMDPot.EnforcedPause.selector);
        pot.finalizeRound();
        vm.prank(admin);
        pot.unpause();
        pot.finalizeRound();
        uint256 target = pot.getRound(1).drawBlock;
        vm.prank(admin);
        pot.pause();
        vm.roll(target + 1);
        vm.setBlockhash(target, bytes32(uint256(42)));
        pot.finalizeRound();
        vm.prank(alice);
        pot.claim();
        _assertConserved();
    }

    function test_pausedActiveRoundCancelsOnlyAfterOneDayAndRefundsInFull() public {
        _buy(alice, 5);
        _buy(bob, 3);
        uint256 end = pot.getRound(1).endTime;
        vm.prank(admin);
        pot.pause();
        vm.warp(end + 1 days - 1);
        vm.expectRevert(IMDPot.CancelTooEarly.selector);
        pot.cancelRound();
        vm.warp(end + 1 days);
        vm.prank(carol);
        pot.cancelRound();
        assertEq(pot.totalRefundable(), 0.8 ether);
        vm.prank(alice);
        pot.refund(1);
        assertEq(token.balanceOf(alice), 1_000_000 ether);
        assertEq(pot.totalRefundable(), 0.3 ether);
        vm.prank(bob);
        pot.refund(1);
        assertEq(pot.totalRefundable(), 0);
        vm.expectRevert(IMDPot.NothingToRefund.selector);
        vm.prank(alice);
        pot.refund(1);
        vm.expectRevert(IMDPot.RoundNotCancelled.selector);
        vm.prank(alice);
        pot.refund(2);
        (uint256 points, uint256 played,,) = pot.getPlayer(alice);
        assertEq(points, 0);
        assertEq(played, 0);
        _assertConserved();
    }

    function test_ownerCannotCancelAnUnpausedRoundEvenAfterOneDay() public {
        _buy(alice, 1);
        vm.warp(pot.getRound(1).endTime + 2 days);
        vm.expectRevert(IMDPot.CancelTooEarly.selector);
        vm.prank(admin);
        pot.cancelRound();
    }

    function test_failedFeeTransferDoesNotBlockSettlementAndRetryPaysExactlyOnce() public {
        _buy(alice, 10);
        token.setBlocked(pot.DEAD_ADDRESS(), true);
        token.setBlocked(admin, true);
        _settle();
        assertEq(pot.pendingBurn(), 0.1 ether);
        assertEq(pot.pendingTreasury(), 0.05 ether);
        assertEq(pot.totalClaimable(), 0.7 ether);
        _assertConserved();
        pot.flushPendingFees();
        assertEq(pot.pendingBurn(), 0.1 ether);
        token.setBlocked(pot.DEAD_ADDRESS(), false);
        pot.flushPendingFees();
        assertEq(pot.pendingBurn(), 0);
        assertEq(pot.pendingTreasury(), 0.05 ether);
        token.setBlocked(admin, false);
        pot.flushPendingFees();
        assertEq(pot.pendingTreasury(), 0);
        assertEq(token.balanceOf(admin), 0.05 ether);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0.1 ether);
        vm.expectRevert(IMDPot.NothingToFlush.selector);
        pot.flushPendingFees();
        _assertConserved();
    }

    function test_falseReturnAfterMovingTokensRollsBackFeeSubcall() public {
        _buy(alice, 10);
        token.setFalseAfterTransfer(true);
        _settle();
        assertEq(token.balanceOf(admin), 0);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), 0);
        assertEq(pot.pendingBurn(), 0.1 ether);
        _assertConserved();
        token.setFalseAfterTransfer(false);
        pot.flushPendingFees();
        _assertConserved();
    }

    function test_claimFailurePreservesCreditAndDoesNotBlockAnotherWinner() public {
        _buy(alice, 1);
        _buy(bob, 1);
        _buy(carol, 1);
        _settle();
        token.setBlocked(alice, true);
        uint256 credit = pot.claimable(alice);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        vm.prank(alice);
        pot.claim();
        assertEq(pot.claimable(alice), credit);
        vm.prank(bob);
        pot.claim();
        token.setBlocked(alice, false);
        vm.prank(alice);
        pot.claim();
        _assertConserved();
    }

    function test_refundFailurePreservesTicketAndRefundObligation() public {
        _buy(alice, 4);
        _cancelExpired();
        token.setBlocked(alice, true);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        vm.prank(alice);
        pot.refund(1);
        assertEq(pot.ticketsOf(1, alice), 4);
        assertEq(pot.totalRefundable(), 0.4 ether);
        token.setBlocked(alice, false);
        vm.prank(alice);
        pot.refund(1);
        _assertConserved();
    }

    function test_taxedEntryAndFalseReturnRejectWithoutRecordingTickets() public {
        token.setTax(100);
        vm.expectRevert(IMDPot.TransferAmountMismatch.selector);
        _buy(alice, 1);
        assertEq(pot.totalWeight(1), 0);
        token.setTax(0);
        token.setFalseAfterTransfer(true);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token)));
        _buy(alice, 1);
        assertEq(token.balanceOf(address(pot)), 0);
    }

    function test_taxedPayoutCannotSilentlyUnderpay() public {
        _buy(alice, 10);
        _settle();
        token.setTax(100);
        vm.expectRevert(IMDPot.TransferAmountMismatch.selector);
        vm.prank(alice);
        pot.claim();
        assertEq(pot.claimable(alice), 0.7 ether);
        token.setTax(0);
        vm.prank(alice);
        pot.claim();
        _assertConserved();
    }

    function test_noReturnERC20Supported() public {
        token.setOmitReturn(true);
        _buy(alice, 10);
        _settle();
        vm.prank(alice);
        pot.claim();
        _assertConserved();
    }

    function test_entryReentrancyFailsAndOuterEntryRemainsCorrect() public {
        token.setCallback(address(pot), abi.encodeCall(IMDPot.buyTickets, (1)));
        _buy(alice, 2);
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), IMDPot.ReentrancyGuardReentrantCall.selector);
        assertEq(pot.ticketsOf(1, alice), 2);
        _assertConserved();
    }

    function test_contractWalletCanPlayAndCannotReenterClaim() public {
        PlayerWallet wallet = new PlayerWallet(pot);
        token.mint(address(wallet), 1 ether);
        wallet.buy(token, 10);
        _settle();
        token.setCallback(address(wallet), abi.encodeCall(PlayerWallet.onTokenTransfer, ()));
        wallet.claim();
        assertFalse(wallet.reentered());
        assertEq(bytes4(wallet.result()), IMDPot.ReentrancyGuardReentrantCall.selector);
        assertEq(token.balanceOf(address(wallet)), 0.7 ether);
        assertEq(pot.claimable(address(wallet)), 0);
        _assertConserved();
    }

    function test_feeReentrancyAndUnauthorizedSelfCallCannotDrain() public {
        _buy(alice, 10);
        token.setCallback(address(pot), abi.encodeCall(IMDPot.flushPendingFees, ()));
        _settle();
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), IMDPot.ReentrancyGuardReentrantCall.selector);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, address(this)));
        pot.transferFee(alice, 1);
        _assertConserved();
    }

    function test_contractWalletCannotReenterRefund() public {
        PlayerWallet wallet = new PlayerWallet(pot);
        token.mint(address(wallet), 1 ether);
        wallet.buy(token, 10);
        _cancelExpired();
        token.setCallback(address(wallet), abi.encodeCall(PlayerWallet.onRefundTransfer, (1)));
        wallet.refund(1);
        assertFalse(wallet.reentered());
        assertEq(bytes4(wallet.result()), IMDPot.ReentrancyGuardReentrantCall.selector);
        assertEq(token.balanceOf(address(wallet)), 1 ether);
        assertEq(pot.ticketsOf(1, address(wallet)), 0);
        assertEq(pot.totalRefundable(), 0);
        _assertConserved();
    }

    function test_boostedSingleTicketStillCannotWinTwice() public {
        _earnLoyalty(alice);
        vm.prank(alice);
        pot.redeemMultiplier();
        uint256 id = pot.currentRoundId();
        _buy(alice, 1);
        _buy(bob, 1);
        _buy(carol, 1);
        _settle();
        IMDPot.Round memory round = pot.getRound(id);
        assertTrue(round.winners[0] != round.winners[1]);
        assertTrue(round.winners[0] != round.winners[2]);
        assertTrue(round.winners[1] != round.winners[2]);
        assertEq(pot.totalWeight(id), 32_500);
        _assertConserved();
    }

    function test_pointsCreditOncePerSettledTicketAndRound() public {
        _buy(alice, 2);
        _buy(alice, 3);
        _settle();
        (uint256 points, uint256 played,, bool redeem) = pot.getPlayer(alice);
        assertEq(points, 5);
        assertEq(played, 1);
        assertFalse(redeem);
        pot.syncPoints(alice);
        pot.syncPoints(alice);
        (points, played,,) = pot.getPlayer(alice);
        assertEq(points, 5);
        assertEq(played, 1);
        _buy(alice, 2);
        _settle();
        (points, played,,) = pot.getPlayer(alice);
        assertEq(points, 7);
        assertEq(played, 2);
    }

    function test_loyaltyThresholdsInsufficientRoundsAndPoints() public {
        _buy(alice, 1000);
        _settle();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.InsufficientRoundsPlayed.selector, 1, 10));
        vm.prank(alice);
        pot.redeemMultiplier();
        for (uint256 i; i < 10; ++i) {
            _buy(bob, 1);
            _settle();
        }
        vm.expectRevert(abi.encodeWithSelector(IMDPot.InsufficientPoints.selector, 10, 100));
        vm.prank(bob);
        pot.redeemMultiplier();
    }

    function test_boostCapsAtTwoXAndIsFrozenForEntireRound() public {
        _earnLoyalty(alice);
        for (uint256 i; i < 4; ++i) {
            vm.prank(alice);
            pot.redeemMultiplier();
        }
        (uint256 points, uint256 played, uint256 boost, bool redeem) = pot.getPlayer(alice);
        assertEq(points, 600);
        assertEq(played, 10);
        assertEq(boost, 10_000);
        assertFalse(redeem);
        vm.expectRevert(IMDPot.MultiplierAtMax.selector);
        vm.prank(alice);
        pot.redeemMultiplier();
        uint256 id = pot.currentRoundId();
        _buy(alice, 2);
        _buy(bob, 2);
        _buy(alice, 3);
        assertEq(pot.roundBoostBps(id, alice), 10_000);
        assertEq(pot.weightOf(id, alice), 100_000);
        assertEq(pot.totalWeight(id), 120_000);
        vm.expectRevert(IMDPot.MultiplierAtMax.selector);
        vm.prank(alice);
        pot.redeemMultiplier();
        _settle();
        _buy(alice, 1);
        assertEq(pot.roundBoostBps(pot.currentRoundId(), alice), 0);
    }

    function test_redemptionDuringRoundAppliesOnlyToNextRound() public {
        _earnLoyalty(alice);
        _buy(alice, 1);
        uint256 id = pot.currentRoundId();
        vm.prank(alice);
        pot.redeemMultiplier();
        _buy(alice, 1);
        assertEq(pot.weightOf(id, alice), 20_000);
        _settle();
        _buy(alice, 1);
        assertEq(pot.roundBoostBps(id + 1, alice), 2500);
        assertEq(pot.weightOf(id + 1, alice), 12_500);
    }

    function test_cancelRestoresBoostWithoutAwardingPointsOrRequiringRefundFirst() public {
        _earnLoyalty(alice);
        vm.prank(alice);
        pot.redeemMultiplier();
        uint256 id = pot.currentRoundId();
        _buy(alice, 5);
        vm.prank(alice);
        pot.redeemMultiplier();
        _cancelExpired();
        (uint256 points, uint256 played, uint256 boost,) = pot.getPlayer(alice);
        assertEq(points, 800);
        assertEq(played, 10);
        assertEq(boost, 5000);
        _buy(alice, 1);
        assertEq(pot.roundBoostBps(id + 1, alice), 5000);
        vm.prank(alice);
        pot.refund(id);
        pot.syncPoints(alice);
        (points, played, boost,) = pot.getPlayer(alice);
        assertEq(points, 800);
        assertEq(played, 10);
        assertEq(boost, 0);
        _assertConserved();
    }

    function test_twoStepOwnershipAndFixedTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        pot.pause();
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableInvalidOwner.selector, address(0)));
        vm.prank(admin);
        pot.transferOwnership(address(0));
        vm.prank(admin);
        pot.transferOwnership(alice);
        assertEq(pot.owner(), admin);
        assertEq(pot.pendingOwner(), alice);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        pot.acceptOwnership();
        vm.prank(alice);
        pot.acceptOwnership();
        assertEq(pot.owner(), alice);
        assertEq(pot.pendingOwner(), address(0));
        assertEq(pot.TREASURY(), admin);
        vm.prank(alice);
        pot.pause();
        vm.expectRevert(IMDPot.EnforcedPause.selector);
        vm.prank(alice);
        pot.pause();
        vm.prank(alice);
        pot.unpause();
        vm.expectRevert(IMDPot.ExpectedPause.selector);
        vm.prank(alice);
        pot.unpause();
        vm.expectRevert(IMDPot.OwnershipCannotBeRenounced.selector);
        vm.prank(alice);
        pot.renounceOwnership();
    }

    function test_ownerCannotRescueGameTokenIncludingLockedShareOrDonations() public {
        _buy(alice, 10);
        _settle();
        token.mint(address(pot), 1 ether);
        vm.expectRevert(IMDPot.CannotRescueGameToken.selector);
        vm.prank(admin);
        pot.rescueForeignToken(address(token), admin);
        MockToken foreign = new MockToken(18);
        foreign.mint(address(pot), 100);
        vm.expectRevert(abi.encodeWithSelector(IMDPot.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        pot.rescueForeignToken(address(foreign), alice);
        vm.prank(admin);
        pot.rescueForeignToken(address(foreign), admin);
        assertEq(foreign.balanceOf(admin), 100);
        assertGe(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function testFuzz_conservationAcrossSettlementsRefundsAndClaims(uint32 a, uint32 b, uint32 c, bytes32 hash) public {
        uint256 ca = bound(a, 1, 1000);
        uint256 cb = bound(b, 1, 1000);
        uint256 cc = bound(c, 1, 1000);
        _buy(alice, ca);
        _buy(bob, cb);
        _buy(carol, cc);
        _assertConserved();
        uint256 target = _commit();
        vm.roll(target + 1);
        vm.setBlockhash(target, hash == 0 ? bytes32(uint256(1)) : hash);
        pot.finalizeRound();
        IMDPot.Round memory round = pot.getRound(1);
        assertEq(
            round.prizes[0] + round.prizes[1] + round.prizes[2] + round.burned + round.treasuryFee + round.locked,
            round.pool
        );
        _assertConserved();
        address[3] memory accounts = [alice, bob, carol];
        for (uint256 i; i < 3; ++i) {
            if (pot.claimable(accounts[i]) > 0) {
                vm.prank(accounts[i]);
                pot.claim();
            }
        }
        _buy(alice, cc);
        _buy(bob, ca);
        _cancelExpired();
        _assertConserved();
        vm.prank(alice);
        pot.refund(2);
        vm.prank(bob);
        pot.refund(2);
        assertEq(token.balanceOf(address(pot)), pot.totalLocked());
        _assertConserved();
    }
}
