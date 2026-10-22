// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { LaneHandler } from "./LaneHandler.sol";

/// Echidna / Medusa property entry point (Anthropic lane, r001). Actions are inherited from LaneHandler.
contract LaneEchidna is LaneHandler {
    function echidna_solvency() public view returns (bool) { return propSolvency(); }
    function echidna_conservation() public view returns (bool) { return propConservation(); }
    function echidna_pot_matches_sales() public view returns (bool) { return propPotMatchesSales(); }
    function echidna_refund_liability() public view returns (bool) { return propRefundLiabilityMatchesLiveTickets(); }
    function echidna_ranges_partition() public view returns (bool) { return propRangesPartition(); }
    function echidna_outcome_consistent() public view returns (bool) { return propOutcomeConsistent(); }
    function echidna_prize_custody() public view returns (bool) { return propPrizeCustody(); }
    function echidna_settlement_totals() public view returns (bool) { return propSettlementTotals(); }
    function echidna_no_flags() public view returns (bool) { return propNoFlags(); }
}
