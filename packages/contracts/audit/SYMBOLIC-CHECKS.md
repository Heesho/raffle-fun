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

Solidity SMTChecker was also invoked with the exact production standard JSON, CHC,
Z3, a 20-second query timeout, and `assert` targets. Compilation completed, but the
production dependency graph reported 14-228 unsupported language features per
contract and contains no embedded production assertions. It is recorded as a partial,
inconclusive whole-graph attempt, not a proof.

Certora is not configured. Mythril `0.24.8` requires Python 3.7-3.10 while the
available isolated runtime is Python 3.12; it was not executed. Halmos does not prove
multi-ticket arithmetic, arbitrary ERC-20/ERC-721 behavior, factory deployment, or
whole-protocol liveness. The protocol is not formally verified.
