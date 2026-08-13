# Mutation testing

Gambit `1.0.6` was downloaded from the pinned upstream release into
`/tmp/raffle-audit-tools/gambit`. Mutants were generated in disposable directories
with seed `20260809`, exact solc `0.8.36`, Cancun, optimizer enabled for 1,000 runs,
and repository remappings.

```text
gambit mutate --json gambit-raffle.json
gambit mutate --json gambit-factory.json
gambit mutate -f RaffleFlattened.sol --functions recoverProtocolOwnedClaim \
  --contract Raffle -n 12 -s 20260809
forge test --no-match-contract BaseForkTest
```

| Result                    |                      Count |
| ------------------------- | -------------------------: |
| generated                 | 52 (42 Raffle, 10 Factory) |
| compiling                 |                         52 |
| killed before regressions |                         51 |
| initial survivors         |                          1 |
| equivalent                |                          0 |
| killed after regressions  |                         52 |
| final survivors           |                          0 |
| raw score                 |                       100% |
| equivalent-adjusted score |                       100% |

The broad sample's initial survivor changed the second purchase's `firstTicketId`
assignment to one.
`testRegressionSeparatePurchasesContinueSequentialTicketIds` was added and killed it.
The sample covered ticket-ID arithmetic, boundaries, state/status checks, accounting,
fee/split calculations, claim clearing, factory checks, and destination validation.

After H-04 remediation, a second deterministic sample targeted every branch and
returned amount in `recoverProtocolOwnedClaim`. All 12 mutants compiled and were
killed. Two assignment mutants showed that the regression had not asserted the
helper's returned cash/refund amounts; exact assertions were added and killed them.

This is a deterministic 52-mutant security sample, not an exhaustive enumeration of
every Gambit operator.

## 2026-08-13 current-commit follow-up

A fresh Gambit 1.0.6 sample generated 24 compiling mutants from the exact production
`Raffle` at `fe09d476cbe770d770cbc2603a1ce73330739025`. It targeted draw timing,
Entropy sequence state, all refund-finalization branches, winner redemption,
`nftRedemptionDeadline`, NFT/cash settlement, winner selection, and exact quote
transfers. Twenty-two mutants died on the existing suite. Two survivors exposed
missing assertions rather than accepted equivalence:

- an overbroad NFT-timeout branch could corrupt `CashWon` and terminal states;
- the NFT resolution event could report a zero sponsor amount.

The added terminal-state and exact-event regressions killed both on rerun. Final result:
24 generated, 24 compiling, 24 killed, zero survivor (100% for this seeded sample).
