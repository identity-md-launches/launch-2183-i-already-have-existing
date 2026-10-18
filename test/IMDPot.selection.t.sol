// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

contract IMDPotSelectionTest is Test {
    IMDPot internal pot;
    MockToken internal token;
    address internal admin;
    address[6] internal actors;

    function setUp() public {
        vm.warp(1_800_000_123);
        vm.roll(1000);
        admin = makeAddr("selection admin");
        token = new MockToken(1);
        pot = new IMDPot(admin);
        vm.prank(admin);
        pot.setToken(address(token));
        for (uint256 i; i < 6; ++i) {
            actors[i] = makeAddr(string.concat("selection actor ", vm.toString(i)));
            token.mint(actors[i], 100_000_000);
            vm.prank(actors[i]);
            token.approve(address(pot), type(uint256).max);
        }
        // Establish eligibility for independently varied 1x..2x weights on every fuzz case.
        for (uint256 round; round < 10; ++round) {
            for (uint256 i; i < 6; ++i) {
                _buy(actors[i], 100);
            }
            uint256 target = _commit();
            vm.roll(target + 1);
            vm.setBlockhash(target, keccak256(abi.encode("selection prime", round)));
            pot.finalizeRound();
        }
    }

    function _buy(address actor, uint256 count) internal {
        vm.prank(actor);
        pot.buyTickets(count);
    }

    function _commit() internal returns (uint256 target) {
        uint256 id = pot.currentRoundId();
        vm.warp(pot.getRound(id).endTime);
        pot.finalizeRound();
        return pot.getRound(id).drawBlock;
    }

    /// @dev Linear weighted intervals, independent of the production Fenwick tree. Remove
    /// one TICKET's weight per slot, leaving that wallet's other tickets in the candidate set.
    function _linearDraw(uint256 seed, uint256[6] memory counts, uint256[6] memory units)
        internal
        view
        returns (address[3] memory winners)
    {
        uint256 total;
        uint256 tickets;
        for (uint256 i; i < 6; ++i) {
            total += counts[i] * units[i];
            tickets += counts[i];
        }
        for (uint256 slot; slot < 3 && slot < tickets; ++slot) {
            uint256 position = uint256(keccak256(abi.encode(seed, slot))) % total;
            bool found;
            for (uint256 i; i < 6; ++i) {
                uint256 interval = counts[i] * units[i];
                if (position < interval) {
                    winners[slot] = actors[i];
                    counts[i]--;
                    total -= units[i];
                    found = true;
                    break;
                }
                position -= interval;
            }
            assertTrue(found, "linear oracle did not find a ticket");
        }
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_boostedSelectionMatchesIndependentLinearIntervals(
        uint32[6] memory rawCounts,
        uint8[6] memory redemptions,
        uint8 rawLength,
        bytes32 entropy
    ) public {
        uint256 length = bound(rawLength, 1, 6);
        uint256[6] memory counts;
        uint256[6] memory units;
        uint256 expectedWeight;
        uint256 totalTickets;
        for (uint256 i; i < length; ++i) {
            uint256 boosts = redemptions[i] % 5;
            for (uint256 j; j < boosts; ++j) {
                vm.prank(actors[i]);
                pot.redeemMultiplier();
            }
            units[i] = 10_000 + boosts * 2500;
            counts[i] = bound(rawCounts[i], 1, 1_000_000);
            _buy(actors[i], counts[i]);
            // Updating an older leaf before the next append exercises dynamic tree prefixes.
            if (i > 0) {
                uint256 repeat = rawCounts[i] % 3 + 1;
                _buy(actors[i - 1], repeat);
                counts[i - 1] += repeat;
            }
        }
        for (uint256 i; i < 6; ++i) {
            expectedWeight += counts[i] * units[i];
            totalTickets += counts[i];
        }
        assertEq(pot.totalWeight(11), expectedWeight);
        if (entropy == bytes32(0)) entropy = keccak256("nonzero selection hash");
        uint256 seed = uint256(keccak256(abi.encode(entropy, block.chainid, address(pot), uint256(11))));
        // Solidity memory arrays alias across internal calls: preserve the purchased counts.
        uint256[6] memory remaining;
        for (uint256 i; i < 6; ++i) {
            remaining[i] = counts[i];
        }
        address[3] memory expected = _linearDraw(seed, remaining, units);
        uint256 target = _commit();
        vm.roll(target + 1);
        vm.setBlockhash(target, entropy);
        pot.finalizeRound();
        IMDPot.Round memory actual = pot.getRound(11);
        assertEq(actual.randomWord, seed);
        assertEq(actual.totalTickets, totalTickets);
        assertEq(actual.pool, totalTickets);
        assertEq(abi.encode(actual.winners), abi.encode(expected));
        assertEq(pot.totalWeight(11), expectedWeight, "draw must restore all removed weights");
        for (uint256 i; i < 6; ++i) {
            assertEq(pot.ticketsOf(11, actors[i]), counts[i]);
            assertEq(pot.weightOf(11, actors[i]), counts[i] * units[i]);
        }
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
    }

    function test_drawResultDoesNotDependOnFinalizerTimestampOrPrevrandao() public {
        _buy(actors[0], 3);
        _buy(actors[1], 2);
        uint256 target = _commit();
        vm.roll(target + 1);
        vm.setBlockhash(target, keccak256("fixed committed hash"));
        uint256 snapshot = vm.snapshotState();
        vm.prank(actors[0]);
        pot.finalizeRound();
        bytes32 outcome = keccak256(abi.encode(pot.getRound(11)));
        uint256 firstCredit = pot.claimable(actors[0]);
        uint256 secondCredit = pot.claimable(actors[1]);
        assertTrue(vm.revertToState(snapshot));
        vm.warp(block.timestamp + 7 days);
        vm.prevrandao(keccak256("unrelated current randomness"));
        vm.prank(actors[5]);
        pot.finalizeRound();
        assertEq(keccak256(abi.encode(pot.getRound(11))), outcome);
        assertEq(pot.claimable(actors[0]), firstCredit);
        assertEq(pot.claimable(actors[1]), secondCredit);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_splittingAPurchasePreservesBoostWeightPriceAndTimer(uint32 rawCount, uint32 rawSplit, uint8 steps)
        public
    {
        uint256 count = bound(rawCount, 2, 1_000_000);
        uint256 split = bound(rawSplit, 1, count - 1);
        uint256 redemptions = steps % 4 + 1;
        for (uint256 i; i < redemptions; ++i) {
            vm.prank(actors[0]);
            pot.redeemMultiplier();
        }
        uint256 snapshot = vm.snapshotState();
        _buy(actors[0], count);
        bytes32 bulk = _purchaseHash();
        assertTrue(vm.revertToState(snapshot));
        _buy(actors[0], split);
        _buy(actors[0], count - split);
        assertEq(_purchaseHash(), bulk);
        assertEq(pot.totalWeight(11), count * (10_000 + redemptions * 2500));
    }

    function _purchaseHash() internal view returns (bytes32) {
        (uint256 points, uint256 played, uint256 pending, bool canRedeem) = pot.getPlayer(actors[0]);
        return keccak256(
            abi.encode(
                pot.getRound(11),
                pot.getParticipants(11),
                pot.totalWeight(11),
                pot.ticketsOf(11, actors[0]),
                token.balanceOf(actors[0]),
                token.balanceOf(address(pot)),
                token.allowance(actors[0], address(pot)),
                points,
                played,
                pending,
                canRedeem,
                pot.roundBoostBps(11, actors[0])
            )
        );
    }
}
