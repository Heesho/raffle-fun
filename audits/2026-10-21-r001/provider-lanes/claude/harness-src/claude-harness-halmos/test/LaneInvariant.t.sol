// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { LaneHandler } from "./LaneHandler.sol";

/// Foundry stateful invariant campaign over LaneHandler (Anthropic lane, r001).
contract LaneInvariantTest is Test {
    LaneHandler internal h;

    function setUp() public {
        h = new LaneHandler();
        targetContract(address(h));
    }

    function invariant_solvency() public view { assertTrue(h.propSolvency(), "solvency"); }
    function invariant_conservation() public view { assertTrue(h.propConservation(), "conservation"); }
    function invariant_potMatchesSales() public view { assertTrue(h.propPotMatchesSales(), "pot==sales"); }
    function invariant_refundLiability() public view { assertTrue(h.propRefundLiabilityMatchesLiveTickets(), "refund liability"); }
    function invariant_rangesPartition() public view { assertTrue(h.propRangesPartition(), "ranges partition"); }
    function invariant_outcomeConsistent() public view { assertTrue(h.propOutcomeConsistent(), "outcome"); }
    function invariant_prizeCustody() public view { assertTrue(h.propPrizeCustody(), "prize custody"); }
    function invariant_settlementTotals() public view { assertTrue(h.propSettlementTotals(), "settlement totals"); }
    function invariant_noFlags() public view { assertTrue(h.propNoFlags(), "handler flags"); }

    /// Vacuity/coverage report: which lifecycle states the campaign reached.
    function invariant_zz_callSummary() public view {
        h.calls();
    }
}

import { console2 } from "forge-std/console2.sol";

contract LaneInvariantCoverage is LaneInvariantTest {
    function afterInvariant() public view {
        bytes32[12] memory k = [bytes32("buy"), "transfer", "requestDraw", "fulfillCall", "enableRefunds", "settle",
            "redeemNft", "redeemCash", "refund", "releaseSponsor", "releaseProtocol", "releasePrize"];
        for (uint256 i; i < k.length; i++) console2.log(string(abi.encodePacked(k[i])), h.ok(k[i]));
        console2.log("statusSeenMask", h.statusSeenMask());
    }
}
