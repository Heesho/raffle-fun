// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import { RaffleInvariantTest } from "./RaffleInvariant.t.sol";
contract ReachabilityProbeTest is RaffleInvariantTest {
    function testGuidedCashSettlementUsesExistingEconomicInvariant() public {
        handler.buy(3);
        handler.warpToEnd();
        handler.requestDraw();
        handler.fulfill(0);
        handler.settleCandidateWinner(0);
        assertTrue(raffle.settlementComplete(), "guided sequence failed to settle");
        invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund();
    }
}
