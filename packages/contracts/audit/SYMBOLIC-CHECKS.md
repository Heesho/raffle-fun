# Symbolic and formal checks

Halmos `0.3.3` with Z3 `4.12.6` ran the production `Raffle` through a concrete
one-ticket setup with symbolic `bytes32` randomness:

```text
/tmp/raffle-halmos-venv/bin/halmos --root . \
  --contract RaffleSymbolicTest --solver z3 --loop 2 --statistics --no-status
```

Five focused properties passed, zero failed:

1. one ticket always selects ticket 1 (2 paths);
2. normal resolution excludes later timeout finalization (2 paths);
3. timeout finalization excludes a late callback (2 paths);
4. the winning bearer credential can be consumed at most once (2 paths);
5. a refund bearer credential can be consumed at most once (1 path).

The 2026-08-13 follow-up rerun initially reported `revert-all` for checks 4 and 5.
Their payout destination was the test contract, which is also the direct raffle
factory and is correctly rejected by the hardened production destination guard. The
harness now uses an independent payout address and asserts final prize ownership or
quote balance. The rerun then passed all five checks and nine feasible paths without a
vacuity warning.

Solidity SMTChecker was also invoked with the exact production standard JSON, CHC,
Z3, a 20-second query timeout, and `assert` targets. Compilation completed, but the
production dependency graph reported 14-228 unsupported language features per
contract and contains no embedded production assertions. It is recorded as a partial,
inconclusive whole-graph attempt, not a proof.

Certora is not configured. Mythril `0.24.8` requires Python 3.7-3.10 while the
available isolated runtime is Python 3.12; it was not executed. Halmos does not prove
multi-ticket arithmetic, arbitrary ERC-20/ERC-721 behavior, factory deployment, or
whole-protocol liveness. The protocol is not formally verified.
