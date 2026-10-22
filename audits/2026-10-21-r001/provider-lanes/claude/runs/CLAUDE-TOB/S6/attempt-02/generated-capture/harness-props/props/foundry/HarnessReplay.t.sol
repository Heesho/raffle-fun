// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02): deterministic replays of Echidna-shrunk sequences against the property
// harness, used to identify which expectation fired (harness bug vs production defect) and to pin regressions.
import { RafflePropertiesHarness } from "../RaffleProperties.sol";

contract HarnessReplayTest {
    event log_named_string(string key, string val);
    event log_named_uint(string key, uint256 val);

    /// Echidna smoke3 counterexample: createRaffle(0,1,0); buy(0,0,0,113526434078166817345300);
    /// fastDrawAndResolve(0,0,0,0); redeem(0,0,1,false)
    function test_replay_smoke3_redeem_settles_cash() public {
        RafflePropertiesHarness h = new RafflePropertiesHarness{ value: 100 ether }();
        h.createRaffle(0, 1, 0);
        h.buy(0, 0, 0, 113526434078166817345300);
        h.fastDrawAndResolve(0, 0, 0, 0);
        h.redeem(0, 0, 1, false);
        emit log_named_uint("violations", h.violations());
        emit log_named_string("firstViolation", h.firstViolation());
        require(h.violations() == 0, h.firstViolation());
    }
}
