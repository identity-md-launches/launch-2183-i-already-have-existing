// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPot} from "../src/IMDPot.sol";
import {MockToken} from "./MockToken.sol";

contract PotHandler is Test {
    IMDPot public pot;
    MockToken public token;
    address public admin;
    address[4] public actors;

    constructor(IMDPot pot_, MockToken token_, address admin_) {
        pot = pot_;
        token = token_;
        admin = admin_;
        for (uint256 i; i < 4; ++i) {
            actors[i] = address(uint160(uint256(keccak256(abi.encode("invariant actor", i)))));
            token.mint(actors[i], 1_000_000 ether);
            vm.prank(actors[i]);
            token.approve(address(pot), type(uint256).max);
        }
    }

    function buy(uint8 actor, uint16 count) external {
        vm.prank(actors[actor % 4]);
        try pot.buyTickets(bound(count, 1, 100)) {} catch {}
    }

    function resolve(bytes32 entropy, bool expire) external {
        IMDPot.Round memory round = pot.getRound(pot.currentRoundId());
        if (round.status == IMDPot.RoundStatus.Active) {
            vm.warp(uint256(round.endTime) + (pot.paused() ? 1 days : 0));
            if (pot.paused()) {
                pot.cancelRound();
                return;
            }
            pot.finalizeRound();
            round = pot.getRound(pot.currentRoundId());
        }
        if (round.status == IMDPot.RoundStatus.Drawing) {
            vm.roll(round.drawBlock + (expire ? 257 : 1));
            if (expire) {
                pot.cancelRound();
            } else {
                vm.setBlockhash(round.drawBlock, entropy == 0 ? bytes32(uint256(1)) : entropy);
                pot.finalizeRound();
            }
        }
    }

    function claim(uint8 actor) external {
        vm.prank(actors[actor % 4]);
        try pot.claim() {} catch {}
    }

    function refund(uint8 actor, uint8 id) external {
        uint256 roundId = bound(id, 1, pot.currentRoundId());
        vm.prank(actors[actor % 4]);
        try pot.refund(roundId) {} catch {}
    }

    function redeem(uint8 actor) external {
        vm.prank(actors[actor % 4]);
        try pot.redeemMultiplier() {} catch {}
    }

    function sync(uint8 actor) external {
        pot.syncPoints(actors[actor % 4]);
    }

    function togglePause() external {
        bool wasPaused = pot.paused();
        vm.prank(admin);
        if (wasPaused) pot.unpause();
        else pot.pause();
    }
}

contract IMDPotInvariantTest is Test {
    IMDPot private pot;
    MockToken private token;
    PotHandler private handler;
    address private admin;

    function setUp() public {
        vm.warp(1_800_000_000);
        vm.roll(1000);
        admin = makeAddr("invariant admin");
        pot = new IMDPot(admin);
        token = new MockToken(18);
        vm.prank(admin);
        pot.setToken(address(token));
        handler = new PotHandler(pot, token, admin);
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.resolve.selector;
        selectors[2] = handler.claim.selector;
        selectors[3] = handler.refund.selector;
        selectors[4] = handler.redeem.selector;
        selectors[5] = handler.sync.selector;
        selectors[6] = handler.togglePause.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_balanceCoversExactlyEveryObligation() public view {
        assertEq(token.balanceOf(address(pot)), pot.totalObligations());
        uint256 supplyAccounted =
            token.balanceOf(address(pot)) + token.balanceOf(admin) + token.balanceOf(pot.DEAD_ADDRESS());
        uint256 claims;
        uint256 weight;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            supplyAccounted += token.balanceOf(actor);
            claims += pot.claimable(actor);
            weight += pot.weightOf(pot.currentRoundId(), actor);
        }
        assertEq(supplyAccounted, 4_000_000 ether);
        assertEq(claims, pot.totalClaimable());
        assertEq(weight, pot.totalWeight(pot.currentRoundId()));
    }

    function invariant_refundsAndLockedSharesMatchHistoricalRounds() public view {
        uint256 refunds;
        uint256 locked;
        for (uint256 id = 1; id < pot.currentRoundId(); ++id) {
            IMDPot.Round memory round = pot.getRound(id);
            assertTrue(round.status == IMDPot.RoundStatus.Finalized || round.status == IMDPot.RoundStatus.Cancelled);
            locked += round.locked;
            if (round.status == IMDPot.RoundStatus.Cancelled) {
                for (uint256 i; i < 4; ++i) {
                    refunds += pot.ticketsOf(id, handler.actors(i)) * pot.ticketPrice();
                }
                assertEq(round.locked + round.treasuryFee + round.burned, 0);
            } else {
                assertEq(
                    round.prizes[0] + round.prizes[1] + round.prizes[2] + round.locked + round.treasuryFee
                        + round.burned,
                    round.pool
                );
            }
        }
        assertEq(refunds, pot.totalRefundable());
        assertEq(locked, pot.totalLocked());
    }
}
