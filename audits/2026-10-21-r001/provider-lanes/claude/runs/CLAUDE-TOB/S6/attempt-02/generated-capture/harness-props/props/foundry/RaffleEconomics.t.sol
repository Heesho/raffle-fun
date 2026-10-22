// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02): quantifies manual-review finding S6-F5 (reserve outcome can be flipped by
// a last-moment sponsor-controlled purchase) against the UNMODIFIED production contracts.
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { RaffleScenarioBase } from "./RaffleScenarios.t.sol";

contract RaffleEconomicsTest is RaffleScenarioBase {
    address internal constant SPONSOR_SYBIL = address(uint160(0x5B11));

    /// Buyers fund 900 entries of a raffle whose reserve is 1,000 (they expect the 80% cash outcome). Just before
    /// endTime the sponsor buys the 100-entry shortfall from a fresh address. Compare sponsor-side payoffs.
    function test_F5_sponsorSybilCrossesReserve_flipsOutcome() public {
        uint256 snap = vm.snapshotState();

        // Baseline: no flip -> CashWon.
        (IRaffle r0, uint256 id0) = _newRaffle(1000);
        _buy(r0, ALICE, 450);
        _buy(r0, BOB, 450);
        vm.warp(r0.endTime());
        r0.requestDraw();
        uint256[] memory w = new uint256[](1);
        w[0] = 0;
        wrapper.fulfill(address(r0), r0.vrfRequestId(), w);
        require(r0.status() == IRaffle.Status.CashWon, "baseline CashWon");
        r0.settleWinningTicket(1);
        uint256 baselineSponsorUsdc = r0.sponsorProceeds();
        uint256 baselineWinnerCash = r0.winnerProceeds();
        emit log_named_uint("baseline sponsor USDC (keeps NFT too)", baselineSponsorUsdc);
        emit log_named_uint("baseline winner cash (80% of buyers' 900 USDC)", baselineWinnerCash);
        _eq(baselineSponsorUsdc, 135_000_000, "15% of 900");
        _eq(baselineWinnerCash, 720_000_000, "80% of 900");
        id0;

        vm.revertToState(snap);

        // Flip: sponsor-controlled address buys the 100-entry shortfall at the last second.
        (IRaffle r1,) = _newRaffle(1000);
        _buy(r1, ALICE, 450);
        _buy(r1, BOB, 450);
        vm.warp(r1.endTime() - 1);
        _buy(r1, SPONSOR_SYBIL, 100); // costs 100 USDC
        vm.warp(r1.endTime());
        r1.requestDraw();
        wrapper.fulfill(address(r1), r1.vrfRequestId(), w); // entry 1 -> ALICE wins the NFT
        require(r1.status() == IRaffle.Status.NftWon, "flipped to NftWon");
        r1.settleWinningTicket(1);
        uint256 flippedSponsorUsdc = r1.sponsorProceeds();
        emit log_named_uint("flipped sponsor USDC gross", flippedSponsorUsdc);
        _eq(flippedSponsorUsdc, 950_000_000, "95% of 1000");
        uint256 netGain = flippedSponsorUsdc - 100_000_000; // minus the sybil purchase
        emit log_named_uint("flipped sponsor net USDC (after 100 USDC sybil buy)", netGain);
        _eq(netGain, 850_000_000, "net");
        // Effective cost of crossing the reserve: the 5% fee on the sponsor's own entries.
        _eq(r1.protocolFees() - 45_000_000, 5_000_000, "sponsor's flip cost = 5% of shortfall");
        // Buyers' collective payout changed from 720 USDC cash to one NFT.
        emit log_named_uint("buyers' collective cash payout after flip", r1.winnerProceeds());
        _eq(r1.winnerProceeds(), 0, "no cash for buyers");
    }
}
