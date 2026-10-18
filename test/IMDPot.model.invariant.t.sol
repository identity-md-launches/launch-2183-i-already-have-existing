// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

/// @dev Independent ledger: only successful inputs, specified allocations and observed winners
/// update ghosts. Valid withdrawals MUST succeed; expected failures check the exact error.
/// The asset has one decimal, so a ticket costs one base unit and rounding occurs frequently.
contract PotLedgerHandler is Test {
    uint256 public constant INITIAL_BALANCE = 1_000_000_000_000;
    IMDPot public immutable pot;
    MockToken public immutable token;
    address public immutable admin;
    address[4] public actors;

    struct LedgerAccount {
        uint256 deposits;
        uint256 donations;
        uint256 prizes;
        uint256 claimed;
        uint256 refunded;
        uint256 points;
        uint256 played;
        uint256 pendingBoost;
    }

    struct ModelRound {
        IMDPot.RoundStatus status;
        uint256 pool;
        uint256 tickets;
        uint256 participants;
        uint256 weight;
        uint256 start;
        uint256 end;
        uint256 target;
        bytes32 terminalHash;
    }

    mapping(address => LedgerAccount) internal accounts;
    mapping(uint256 => ModelRound) internal modelRounds;
    mapping(uint256 => mapping(address => uint256)) internal purchased;
    mapping(uint256 => mapping(address => uint256)) internal boosts;
    mapping(uint256 => mapping(address => uint256)) internal indexes;
    mapping(uint256 => mapping(address => bool)) internal refunded;
    uint256 public modelRoundId = 1;
    bool internal modelPaused;
    bool internal burnBlocked;
    bool internal treasuryBlocked;
    bool internal emptyReply;

    uint256 public deposited;
    uint256 public donated;
    uint256 public prizesAllocated;
    uint256 public claimsPaid;
    uint256 public refundsAllocated;
    uint256 public refundsPaid;
    uint256 public locked;
    uint256 public burnOwed;
    uint256 public treasuryOwed;
    uint256 public burnPaid;
    uint256 public treasuryPaid;
    uint256 public successfulBuys;
    uint256 public successfulRedemptions;
    uint256 public settlements;
    uint256 public cancellations;
    uint256 public failedPayments;

    constructor(IMDPot pot_, MockToken token_, address admin_) {
        pot = pot_;
        token = token_;
        admin = admin_;
        for (uint256 i; i < 4; ++i) {
            actors[i] = makeAddr(string.concat("ledger actor ", vm.toString(i)));
            token.mint(actors[i], INITIAL_BALANCE);
            vm.prank(actors[i]);
            token.approve(address(pot), type(uint256).max);
        }
    }

    function _expect(address actor, bytes memory data, bytes memory expected) internal {
        vm.prank(actor);
        (bool ok, bytes memory result) = address(pot).call(data);
        assertFalse(ok, "operation expected to revert succeeded");
        assertEq(result, expected, "unexpected failure reason");
    }

    function buy(uint8 actorSeed, uint32 rawCount) public {
        address actor = actors[actorSeed % 4];
        uint256 count = bound(rawCount, 1, 1_000_000);
        uint256 id = modelRoundId;
        ModelRound storage round = modelRounds[id];
        bytes memory data = abi.encodeCall(IMDPot.buyTicketsForRound, (id, count));
        if (modelPaused) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.EnforcedPause.selector));
            return;
        }
        if (round.status == IMDPot.RoundStatus.Drawing) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.RoundDrawing.selector));
            return;
        }
        if (round.status == IMDPot.RoundStatus.Active && block.timestamp >= round.end) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.RoundClosed.selector));
            return;
        }
        uint256 balance = token.balanceOf(actor);
        vm.prank(actor);
        pot.buyTicketsForRound(id, count);
        assertEq(balance - token.balanceOf(actor), count);
        if (round.status == IMDPot.RoundStatus.Pending) {
            round.status = IMDPot.RoundStatus.Active;
            round.start = block.timestamp;
            round.end = block.timestamp + 900;
        }
        if (purchased[id][actor] == 0) {
            indexes[id][actor] = ++round.participants;
            boosts[id][actor] = accounts[actor].pendingBoost;
            accounts[actor].pendingBoost = 0;
        }
        purchased[id][actor] += count;
        round.pool += count;
        round.tickets += count;
        round.weight += count * (10_000 + boosts[id][actor]);
        accounts[actor].deposits += count;
        deposited += count;
        successfulBuys++;
    }

    /// @dev Commitment and settlement are separate handler calls, allowing pauses, claims,
    /// time advances and attempted buys between them. Time and block number never go backwards.
    function resolve(bytes32 entropy, uint8 mode) public {
        uint256 id = modelRoundId;
        ModelRound storage round = modelRounds[id];
        if (round.status == IMDPot.RoundStatus.Pending) return;
        if (round.status == IMDPot.RoundStatus.Active) {
            if (modelPaused) {
                vm.warp(max(block.timestamp, round.end + 1 days));
                pot.cancelRound();
                _cancelled(id);
            } else {
                vm.warp(max(block.timestamp, round.end));
                uint256 target = block.number + 3;
                pot.finalizeRound();
                round.status = IMDPot.RoundStatus.Drawing;
                round.target = target;
                assertEq(pot.getRound(id).drawBlock, target);
            }
            return;
        }
        assertEq(uint256(round.status), uint256(IMDPot.RoundStatus.Drawing));
        if (mode % 3 == 2 || block.number > round.target + 256) {
            vm.roll(max(block.number, round.target + 257));
            _expect(
                address(this),
                abi.encodeCall(IMDPot.finalizeRound, ()),
                abi.encodeWithSelector(IMDPot.DrawExpired.selector, round.target)
            );
            pot.cancelRound();
            _cancelled(id);
        } else {
            vm.roll(max(block.number, round.target + (mode % 3 == 0 ? 1 : 256)));
            if (entropy == bytes32(0)) entropy = keccak256("nonzero ledger blockhash");
            vm.setBlockhash(round.target, entropy);
            pot.finalizeRound();
            _finalized(id, entropy);
        }
    }

    function _cancelled(uint256 id) internal {
        ModelRound storage round = modelRounds[id];
        round.status = IMDPot.RoundStatus.Cancelled;
        for (uint256 i; i < 4; ++i) {
            accounts[actors[i]].pendingBoost += boosts[id][actors[i]];
        }
        refundsAllocated += round.pool;
        cancellations++;
        modelRoundId++;
        IMDPot.Round memory actual = pot.getRound(id);
        assertEq(uint256(actual.status), uint256(IMDPot.RoundStatus.Cancelled));
        assertEq(actual.burned + actual.treasuryFee + actual.locked, 0);
        assertEq(actual.prizes[0] + actual.prizes[1] + actual.prizes[2], 0);
        round.terminalHash = keccak256(abi.encode(actual));
    }

    function _finalized(uint256 id, bytes32 entropy) internal {
        ModelRound storage round = modelRounds[id];
        IMDPot.Round memory actual = pot.getRound(id);
        assertEq(uint256(actual.status), uint256(IMDPot.RoundStatus.Finalized));
        assertEq(actual.drawBlockHash, entropy);
        assertEq(actual.randomWord, uint256(keccak256(abi.encode(entropy, block.chainid, address(pot), id))));
        assertEq(actual.pool, round.pool);
        assertEq(actual.burned, round.pool / 10);
        assertEq(actual.treasuryFee, round.pool / 20);
        assertEq(actual.locked, round.pool * 15 / 100);
        uint256 slots = min(round.tickets, 3);
        assertEq(actual.prizes[1], slots >= 2 ? round.pool / 5 : 0);
        assertEq(actual.prizes[2], slots >= 3 ? round.pool / 10 : 0);
        uint256 prizePool = round.pool - actual.burned - actual.treasuryFee - actual.locked;
        assertEq(actual.prizes[0], prizePool - actual.prizes[1] - actual.prizes[2]);
        uint256[4] memory wins;
        for (uint256 slot; slot < 3; ++slot) {
            if (slot >= slots) {
                assertEq(actual.winners[slot], address(0));
                continue;
            }
            bool found;
            for (uint256 i; i < 4; ++i) {
                if (actors[i] == actual.winners[slot]) {
                    found = true;
                    assertLe(++wins[i], purchased[id][actors[i]], "a ticket won more than once");
                    accounts[actors[i]].prizes += actual.prizes[slot];
                }
            }
            assertTrue(found, "winner never bought a ticket");
        }
        for (uint256 i; i < 4; ++i) {
            uint256 tickets = purchased[id][actors[i]];
            if (tickets > 0) {
                accounts[actors[i]].points += tickets;
                accounts[actors[i]].played++;
            }
        }
        prizesAllocated += prizePool;
        locked += actual.locked;
        burnOwed += actual.burned;
        treasuryOwed += actual.treasuryFee;
        _modelFeePayment();
        round.status = IMDPot.RoundStatus.Finalized;
        round.terminalHash = keccak256(abi.encode(actual));
        settlements++;
        modelRoundId++;
    }

    function claim(uint8 actorSeed) public {
        address actor = actors[actorSeed % 4];
        LedgerAccount storage account = accounts[actor];
        uint256 amount = account.prizes - account.claimed;
        if (amount == 0) {
            _expect(actor, abi.encodeCall(IMDPot.claim, ()), abi.encodeWithSelector(IMDPot.NothingToClaim.selector));
            return;
        }
        uint256 beforeBalance = token.balanceOf(actor);
        vm.prank(actor);
        pot.claim();
        assertEq(token.balanceOf(actor) - beforeBalance, amount);
        account.claimed += amount;
        claimsPaid += amount;
    }

    function refund(uint8 actorSeed, uint256 rawId) public {
        address actor = actors[actorSeed % 4];
        uint256 id = bound(rawId, 1, modelRoundId + 2);
        bytes memory data = abi.encodeCall(IMDPot.refund, (id));
        if (modelRounds[id].status != IMDPot.RoundStatus.Cancelled) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.RoundNotCancelled.selector));
            return;
        }
        uint256 amount = purchased[id][actor];
        if (amount == 0 || refunded[id][actor]) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.NothingToRefund.selector));
            return;
        }
        uint256 beforeBalance = token.balanceOf(actor);
        vm.prank(actor);
        pot.refund(id);
        assertEq(token.balanceOf(actor) - beforeBalance, amount);
        refunded[id][actor] = true;
        accounts[actor].refunded += amount;
        refundsPaid += amount;
    }

    function _reserved(address actor) internal view returns (uint256) {
        IMDPot.RoundStatus status = modelRounds[modelRoundId].status;
        return
            status == IMDPot.RoundStatus.Active || status == IMDPot.RoundStatus.Drawing
                ? boosts[modelRoundId][actor]
                : 0;
    }

    function redeem(uint8 actorSeed) public {
        address actor = actors[actorSeed % 4];
        LedgerAccount storage account = accounts[actor];
        bytes memory data = abi.encodeCall(IMDPot.redeemMultiplier, ());
        if (account.played < 10) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.InsufficientRoundsPlayed.selector, account.played, 10));
        } else if (account.points < 100) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.InsufficientPoints.selector, account.points, 100));
        } else if (account.pendingBoost + _reserved(actor) >= 10_000) {
            _expect(actor, data, abi.encodeWithSelector(IMDPot.MultiplierAtMax.selector));
        } else {
            vm.prank(actor);
            pot.redeemMultiplier();
            account.points -= 100;
            account.pendingBoost += 2500;
            successfulRedemptions++;
        }
    }

    function sync(uint8 actorSeed) public {
        address actor = actors[actorSeed % 4];
        bytes32 beforeState = _playerHash(actor);
        pot.syncPoints(actor);
        pot.syncPoints(actor);
        assertEq(_playerHash(actor), beforeState, "sync must preserve projected values and be idempotent");
    }

    function _playerHash(address actor) internal view returns (bytes32) {
        (uint256 points, uint256 played, uint256 boost, bool canRedeem) = pot.getPlayer(actor);
        return keccak256(abi.encode(points, played, boost, canRedeem));
    }

    function togglePause() public {
        vm.prank(admin);
        if (modelPaused) pot.unpause();
        else pot.pause();
        modelPaused = !modelPaused;
    }

    function tick(uint32 secondsSeed, uint16 blocksSeed) public {
        vm.warp(block.timestamp + bound(secondsSeed, 0, 2 days));
        vm.roll(block.number + bound(blocksSeed, 0, 260));
    }

    function feePolicy(uint8 flags) public {
        burnBlocked = flags & 1 != 0;
        treasuryBlocked = flags & 2 != 0;
        emptyReply = flags & 4 != 0;
        token.setBlocked(pot.DEAD_ADDRESS(), burnBlocked);
        token.setBlocked(admin, treasuryBlocked);
        token.setOmitReturn(emptyReply);
    }

    function flush() public {
        if (burnOwed + treasuryOwed == 0) {
            _expect(
                address(this),
                abi.encodeCall(IMDPot.flushPendingFees, ()),
                abi.encodeWithSelector(IMDPot.NothingToFlush.selector)
            );
        } else {
            pot.flushPendingFees();
            _modelFeePayment();
        }
    }

    function _modelFeePayment() internal {
        if (!burnBlocked) {
            burnPaid += burnOwed;
            burnOwed = 0;
        }
        if (!treasuryBlocked) {
            treasuryPaid += treasuryOwed;
            treasuryOwed = 0;
        }
    }

    function donate(uint8 actorSeed, uint32 rawAmount) public {
        address actor = actors[actorSeed % 4];
        uint256 amount = bound(rawAmount, 1, 1_000_000);
        vm.prank(actor);
        (bool ok, bytes memory result) = address(token).call(abi.encodeCall(MockToken.transfer, (address(pot), amount)));
        assertTrue(ok, "donation transfer failed");
        assertTrue(result.length == 0 || (result.length == 32 && abi.decode(result, (bool))), "invalid donation reply");
        accounts[actor].donations += amount;
        donated += amount;
    }

    function failedPayment(uint8 actorSeed, uint8 fault) public {
        ModelRound storage round = modelRounds[modelRoundId];
        if (
            modelPaused || round.status == IMDPot.RoundStatus.Drawing
                || (round.status == IMDPot.RoundStatus.Active && block.timestamp >= round.end)
        ) return;
        address actor = actors[actorSeed % 4];
        bytes32 beforeState = keccak256(
            abi.encode(
                pot.getRound(modelRoundId),
                pot.getParticipants(modelRoundId),
                pot.totalWeight(modelRoundId),
                token.balanceOf(actor),
                token.balanceOf(address(pot)),
                _playerHash(actor)
            )
        );
        token.setOmitReturn(false);
        bytes memory expected;
        if (fault % 2 == 0) {
            token.setFalseAfterTransfer(true);
            expected = abi.encodeWithSelector(IMDPot.SafeERC20FailedOperation.selector, address(token));
        } else {
            token.setTax(10_000);
            expected = abi.encodeWithSelector(IMDPot.TransferAmountMismatch.selector);
        }
        _expect(actor, abi.encodeCall(IMDPot.buyTicketsForRound, (modelRoundId, 1)), expected);
        token.setFalseAfterTransfer(false);
        token.setTax(0);
        token.setOmitReturn(emptyReply);
        assertEq(
            keccak256(
                abi.encode(
                    pot.getRound(modelRoundId),
                    pot.getParticipants(modelRoundId),
                    pot.totalWeight(modelRoundId),
                    token.balanceOf(actor),
                    token.balanceOf(address(pot)),
                    _playerHash(actor)
                )
            ),
            beforeState
        );
        failedPayments++;
    }

    /// @notice GL-01: Custody equals successful deposits and donations minus actual exits.
    /// Guaranteed by exact-transfer accounting; donation surplus must never become a liability.
    function assertAccounting() public view {
        uint256 exits = claimsPaid + refundsPaid + burnPaid + treasuryPaid;
        assertEq(token.balanceOf(address(pot)), deposited + donated - exits);
        assertEq(pot.totalObligations(), deposited - exits);
        assertEq(pot.totalLocked(), locked);
        assertEq(pot.totalClaimable(), prizesAllocated - claimsPaid);
        assertEq(pot.totalRefundable(), refundsAllocated - refundsPaid);
        assertEq(pot.pendingBurn(), burnOwed);
        assertEq(pot.pendingTreasury(), treasuryOwed);
        assertEq(token.balanceOf(pot.DEAD_ADDRESS()), burnPaid);
        assertEq(token.balanceOf(admin), treasuryPaid);
        uint256 supply = token.balanceOf(address(pot)) + burnPaid + treasuryPaid;
        for (uint256 i; i < 4; ++i) {
            address actor = actors[i];
            LedgerAccount storage account = accounts[actor];
            assertEq(
                token.balanceOf(actor),
                INITIAL_BALANCE + account.claimed + account.refunded - account.deposits - account.donations
            );
            assertEq(pot.claimable(actor), account.prizes - account.claimed);
            supply += token.balanceOf(actor);
        }
        assertEq(supply, 4 * INITIAL_BALANCE);
    }

    /// @notice GL-02: Lazy player views agree with an eager ledger of settled tickets/redemptions.
    /// The live round's count, timer, participant order and weights match successful purchases.
    function assertPlayersAndLiveRound() public view {
        assertEq(pot.currentRoundId(), modelRoundId);
        assertEq(modelRoundId, 1 + settlements + cancellations);
        assertEq(pot.owner(), admin);
        assertEq(pot.TREASURY(), admin);
        assertEq(pot.ticketPrice(), 1);
        assertEq(pot.paused(), modelPaused);
        ModelRound storage round = modelRounds[modelRoundId];
        IMDPot.Round memory actual = pot.getRound(modelRoundId);
        assertEq(uint256(actual.status), uint256(round.status));
        assertEq(actual.pool, round.pool);
        assertEq(actual.totalTickets, round.tickets);
        assertEq(actual.participantCount, round.participants);
        assertEq(actual.startTime, round.start);
        assertEq(actual.endTime, round.end);
        assertEq(actual.drawBlock, round.target);
        assertEq(pot.totalWeight(modelRoundId), round.weight);
        uint256 remaining = round.status == IMDPot.RoundStatus.Pending
            ? 900
            : round.status == IMDPot.RoundStatus.Active && block.timestamp < round.end ? round.end - block.timestamp : 0;
        assertEq(pot.timeRemaining(), remaining);
        address[] memory participants = pot.getParticipants(modelRoundId);
        assertEq(participants.length, round.participants);
        for (uint256 i; i < 4; ++i) {
            address actor = actors[i];
            LedgerAccount storage account = accounts[actor];
            (uint256 points, uint256 played, uint256 pending, bool canRedeem) = pot.getPlayer(actor);
            assertEq(points, account.points);
            assertEq(played, account.played);
            assertEq(pending, account.pendingBoost);
            uint256 reserved = _reserved(actor);
            assertLe(pending + reserved, 10_000);
            assertEq(canRedeem, played >= 10 && points >= 100 && pending + reserved < 10_000);
            assertEq(pot.ticketsOf(modelRoundId, actor), purchased[modelRoundId][actor]);
            assertEq(pot.roundBoostBps(modelRoundId, actor), boosts[modelRoundId][actor]);
            assertEq(
                pot.weightOf(modelRoundId, actor),
                purchased[modelRoundId][actor] * (10_000 + boosts[modelRoundId][actor])
            );
            uint256 index = indexes[modelRoundId][actor];
            assertEq(pot.participantIndex(modelRoundId, actor), index);
            if (index != 0) assertEq(participants[index - 1], actor);
        }
    }

    /// @notice GL-03: Terminal round data never reopens or changes; refunds consume only their tickets.
    function assertHistory() public view {
        for (uint256 id = 1; id < modelRoundId; ++id) {
            ModelRound storage round = modelRounds[id];
            IMDPot.Round memory actual = pot.getRound(id);
            assertEq(keccak256(abi.encode(actual)), round.terminalHash);
            assertEq(uint256(actual.status), uint256(round.status));
            assertEq(actual.pool, round.pool);
            assertEq(actual.totalTickets, round.tickets);
            assertEq(actual.participantCount, round.participants);
            assertEq(pot.totalWeight(id), round.weight, "drawing must restore historical selection weight");
            for (uint256 i; i < 4; ++i) {
                address actor = actors[i];
                uint256 count = refunded[id][actor] ? 0 : purchased[id][actor];
                assertEq(pot.ticketsOf(id, actor), count);
                assertEq(pot.weightOf(id, actor), count * (10_000 + boosts[id][actor]));
            }
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 128
/// forge-config: default.invariant.fail-on-revert = true
contract IMDPotLedgerInvariantTest is Test {
    IMDPot internal pot;
    MockToken internal token;
    PotLedgerHandler internal handler;

    function setUp() public {
        vm.warp(1_800_000_123);
        vm.roll(10_000);
        address admin = makeAddr("ledger admin");
        token = new MockToken(1);
        pot = new IMDPot(admin);
        vm.prank(admin);
        pot.setToken(address(token));
        handler = new PotLedgerHandler(pot, token, admin);
        // Reach every loyalty branch from the first random call, rather than hoping a short
        // random sequence manages ten rounds. These are real, model-checked ticket purchases.
        for (uint256 round; round < 10; ++round) {
            for (uint8 actor; actor < 4; ++actor) {
                handler.buy(actor, 100);
            }
            handler.resolve(keccak256(abi.encode("prime", round)), 0);
            handler.resolve(keccak256(abi.encode("prime", round)), 0);
        }
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.resolve.selector;
        selectors[2] = handler.claim.selector;
        selectors[3] = handler.refund.selector;
        selectors[4] = handler.redeem.selector;
        selectors[5] = handler.sync.selector;
        selectors[6] = handler.togglePause.selector;
        selectors[7] = handler.tick.selector;
        selectors[8] = handler.feePolicy.selector;
        selectors[9] = handler.flush.selector;
        selectors[10] = handler.donate.selector;
        selectors[11] = handler.failedPayment.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_independentCustodyLedger() public view {
        handler.assertAccounting();
    }

    function invariant_playersAndActiveStateMatchModel() public view {
        handler.assertPlayersAndLiveRound();
    }

    function invariant_terminalRoundsStayImmutable() public view {
        handler.assertHistory();
    }

    /// @dev Withdrawal liveness at the end of EVERY random sequence. Clear only token fee
    /// blocklists, resolve any open round, then require all player claims/refunds to succeed.
    function afterInvariant() public {
        handler.feePolicy(0);
        handler.resolve(keccak256("drain draw"), 0);
        handler.resolve(keccak256("drain draw"), 0);
        handler.flush();
        for (uint8 actor; actor < 4; ++actor) {
            handler.claim(actor);
            for (uint256 id = 1; id < handler.modelRoundId(); ++id) {
                handler.refund(actor, id);
            }
            handler.sync(actor);
        }
        handler.assertAccounting();
        handler.assertPlayersAndLiveRound();
        handler.assertHistory();
        assertEq(token.balanceOf(address(pot)), handler.locked() + handler.donated());
        assertEq(pot.totalClaimable() + pot.totalRefundable() + pot.pendingBurn() + pot.pendingTreasury(), 0);
    }

    /// @dev Replays a deliberately dense trace as a deterministic check of the handler itself.
    function test_modelExercisesBoostRestorationDeferredFeesAndDelayedRefunds() public {
        handler.redeem(0);
        handler.redeem(0);
        handler.buy(0, 3);
        handler.redeem(0);
        handler.failedPayment(1, 0);
        handler.buy(1, 1);
        handler.togglePause();
        handler.resolve(keccak256("cancel with boost"), 0);
        handler.sync(0);
        handler.togglePause();
        handler.feePolicy(7);
        handler.buy(0, 11);
        handler.buy(2, 1);
        handler.resolve(keccak256("deferred fees"), 0);
        handler.resolve(keccak256("deferred fees"), 1);
        handler.donate(3, 17);
        handler.refund(0, 11);
        handler.refund(1, 11);
        handler.refund(0, 11);
        assertGt(handler.successfulRedemptions(), 0);
        assertGt(handler.cancellations(), 0);
        assertGt(handler.failedPayments(), 0);
        assertGt(handler.burnOwed() + handler.treasuryOwed(), 0);
        handler.assertAccounting();
        handler.assertPlayersAndLiveRound();
        handler.assertHistory();
        afterInvariant();
    }
}
