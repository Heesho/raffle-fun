# Test campaign

Review date: 2026-08-09. Reviewer: internal Codex adversarial review.

This ledger reports completed commands and actual results. Configured but incomplete
runs are identified as partial; unavailable tools are identified as not executed.

## Environment

| Component                   | Version/configuration                                                               |
| --------------------------- | ----------------------------------------------------------------------------------- |
| reviewed commit             | `a2120f5e163dc3641d9864773febbfedca047edb` plus recorded dirty-worktree fingerprint |
| Node / pnpm                 | Node `v24.14.0` local runner; pnpm `11.18.0`                                        |
| Forge, Cast, Anvil          | `1.2.3-stable`, commit `a813a2cee7dd4926e7c56fd8a785b54f32e0d10f`                   |
| Solidity                    | `0.8.36+commit.8a079791.Darwin.appleclang`                                          |
| production build            | Cancun, optimizer enabled, 1,000 runs, via-IR disabled                              |
| OpenZeppelin / Pyth         | Contracts `5.6.1`; Entropy SDK `2.2.1`                                              |
| Hardhat / Viem              | `3.11.1`; `2.55.10`                                                                 |
| Slither / Solhint           | `0.11.6`; `6.2.3`                                                                   |
| Echidna / Medusa            | `2.3.3`; `1.5.1`                                                                    |
| Gambit / Halmos / Z3        | `1.0.6`; `0.3.3`; `4.12.6`                                                          |
| Aderyn / Semgrep / Gitleaks | `0.6.8`; `1.170.0`; `8.30.1`                                                        |

## Foundry unit, integration, and regression tests

The baseline was 46/46 tests. The final remediated default suite completed 70 passed,
zero failed, and one RPC-gated fork suite skipped (71 total). The suite adds
protocol-self destination, future-raffle recovery, factory destination, Entropy
adversarial, multi-actor, differential, fork, gas, and symbolic-focused coverage.

Key preserved regressions:

- `testRegressionUnsafeTransferCannotAssignWinningCredentialToRaffle`;
- `testRegressionPredictedRaffleCannotBeItsOwnRecoveryRecipient`;
- `testRegressionPredictedRaffleCannotBeItsOwnTreasury`;
- `testRegressionTicketsRejectKnownProtocolDestinations`;
- `testRegressionFactoryRejectsKnownProtocolFixedClaimants`;
- `testRegressionFutureRaffleCanRecoverTicketsTransferredBeforeItsDeployment`;
- `testRegressionFutureRaffleCanRecoverFixedClaims`;
- `testRegressionSeparatePurchasesContinueSequentialTicketIds`.

## Foundry fuzz campaigns

| Campaign                                         | Seed                                           |                                                                       Completed work | Result |
| ------------------------------------------------ | ---------------------------------------------- | -----------------------------------------------------------------------------------: | ------ |
| critical arithmetic/range/refund/auth/accounting | `0x41554449545f46555a5a`                       |                                               6 properties x 100,000 = 600,000 cases | pass   |
| second critical seed                             | `0x41554449545f535452494354`                   |                                                 6 properties x 10,000 = 60,000 cases | pass   |
| differential model                               | `0x444946464552454e5449414c5f3230323630383039` | 10,000 sequences, 1-32 actions each, assertion after every action and terminal drain | pass   |

The differential model independently tracks status, sale timing, ticket issuance and
ownership, transfers, request/callback, timeout ordering, refunds, fee, cash split,
all quote liabilities, donations, prize claimant, burns, and prize exit. After each
sequence it advances deadlines, chooses either success or liveness failure, burns all
remaining bearer claims in bounded batches, claims sponsor/treasury balances, claims
the prize, and asserts zero accounted quote remains.

Commands:

```text
FOUNDRY_PROFILE=audit forge test --match-contract RaffleFuzzTest \
  --fuzz-seed 0x41554449545f46555a5a -vv
FOUNDRY_PROFILE=audit_strict forge test --match-contract RaffleFuzzTest \
  --fuzz-seed 0x41554449545f535452494354 -vv
forge test --match-contract RaffleDifferentialTest --fuzz-runs 10000 \
  --fuzz-seed 0x444946464552454e5449414c5f3230323630383039 -vv
```

## Stateful invariants

| Campaign               | Runs x depth | Properties | Actual handler calls |                    Reverts | Result |
| ---------------------- | -----------: | ---------: | -------------------: | -------------------------: | ------ |
| multi-actor hostile    |  1,000 x 256 |          3 |              768,000 | tolerated expected reverts | pass   |
| guarded routine strict |  1,000 x 256 |          4 |            1,024,000 |                          0 | pass   |
| guarded release strict |  5,000 x 512 |          4 |           10,240,000 |                          0 | pass   |

The release campaign used `fail_on_revert = true`. Its guarded purchase action buys
one ticket per handler call to stay below Foundry's per-property invariant timeout;
multi-ticket behavior is exercised by unit, fuzz, gas, and broad multi-actor tests.
All guarded actions have explicit reachability counters/properties.

Partial timeout-tuning attempts are not counted as passes. Four-property progress in
successive attempts included `3616/3232/3220/3375`, `3472/3400/3456/3373`, and
`4857/4869/4869/4842` runs, all with zero reverts. The final optimized guarded handler
then completed the full `5000/5000/5000/5000` target.

```text
FOUNDRY_PROFILE=ci forge test --match-contract RaffleMultiActorInvariantTest -vv
FOUNDRY_PROFILE=audit_strict forge test --match-contract RaffleStrictInvariantTest -vv
FOUNDRY_PROFILE=audit_release forge test --match-contract RaffleStrictInvariantTest -vv
```

## Independent property fuzzers

| Tool          | Seed                              | Actual transactions/calls | Properties/tests | Result |
| ------------- | --------------------------------- | ------------------------: | ---------------: | ------ |
| Echidna 2.3.3 | 20260809                          |                   100,209 |                6 | pass   |
| Echidna 2.3.3 | 20260810                          |                   100,212 |                6 | pass   |
| Echidna total | two seeds                         |                   200,421 |                6 | pass   |
| Medusa 1.5.1  | configured deterministic campaign |                   113,261 |               23 | pass   |

Corpora are preserved under `packages/contracts/audit-corpus/`. Both tools compiled
and executed the harness; these were not zero-transaction smoke runs.

## Mutation testing

Gambit 1.0.6 generated 30 broad Raffle, 10 Factory, and 12 final
`recoverProtocolOwnedClaim` mutants in disposable copies. All 52 compiled. The broad
campaign initially killed 39/40; a sequential-purchase regression killed its one
non-equivalent survivor. The final targeted campaign killed 12/12 and caused exact
cash/refund return-value assertions to be added.

| Generated | Compiling | Killed | Surviving | Equivalent | Raw score | Adjusted score |
| --------: | --------: | -----: | --------: | ---------: | --------: | -------------: |
|        52 |        52 |     52 |         0 |          0 |      100% |           100% |

See `MUTATION-TESTING.md` for the pinned command and target classes.

## Symbolic checks

Halmos 0.3.3 with Z3 4.12.6 passed five focused production checks:

- one-ticket selection is ticket 1;
- normal resolution excludes timeout failure;
- timeout failure excludes a later callback;
- a winning ticket consumes at most once;
- a refundable ticket consumes at most once.

Path counts were `2/1/2/2/2`. SMTChecker with CHC/Z3 compiled the exact production
standard JSON but reported 14-228 unsupported dependency features and had no embedded
production assertions, so it is inconclusive. Certora was not configured. Mythril
0.24.8 was not executed because it supports Python 3.7-3.10 while the available
isolated runtime is Python 3.12. These supplemental gaps are not represented as passes.

## Static analysis and secrets

- Slither 0.11.6: 49 contracts, 64 detectors, zero final results.
- Required Slither human, contract, function, variables/auth, entry-point, call-graph,
  and inheritance printers completed.
- Aderyn 0.6.8: 88 detectors; three high-pattern and six low-pattern groups manually
  reviewed as false positives or accepted bounded design.
- Semgrep 1.170.0: 50 community Solidity rules from rules commit
  `40b8c63f75dc7c22c8a77482d73bfb864b146f7e`; 17 style/performance/false-positive
  results manually reviewed.
- Solhint 6.2.3: no production error; warnings classified in `STATIC-ANALYSIS.md`.
- Gitleaks 8.30.1: full history passed after ignoring exactly six historical sandbox
  address fingerprints. A final source-only worktree scan also passed after eight
  line-specific public Ethereum-address false positives were classified.
- pnpm audit: no critical, high, or moderate advisory; one low development-only
  transitive advisory.

## Coverage

The final production-only run reported:

| Metric     |          Covered |
| ---------- | ---------------: |
| lines      |   100% (370/370) |
| statements | 99.78% (459/460) |
| branches   |   98.84% (85/86) |
| functions  |     100% (38/38) |

The sole branch not counted as covered is the `_requireStatus` condition at
`Raffle.sol:455`; LCOV reports its revert path as `-` rather than zero hits because
Foundry could not anchor that optimized inline revert. The same line accounts for the
sole uncounted statement. Explicit valid- and invalid-status unit/security calls
exercise both semantic paths. Foundry also emitted the corresponding
instrumentation-anchor warnings. Coverage is evidence of execution, not proof of
safety.

```text
forge coverage --report summary --no-match-coverage '^(script/|src/mocks/|test/)'
```

## Gas and bytecode

Canonical measured gas:

| Operation                             |                           Gas |
| ------------------------------------- | ----------------------------: |
| factory construction                  |                     4,990,781 |
| factory raffle creation               |                     3,676,141 |
| 100-ticket EOA purchase               |                     2,657,921 |
| 100-ticket contract-receiver purchase |                     2,803,881 |
| `requestDraw`                         |                       144,903 |
| oracle fulfillment transaction        |                       122,231 |
| exact internal callback work          |                        95,078 |
| missing-request refund finalization   |                        25,922 |
| callback-timeout refund finalization  |                        26,190 |
| one refund burn                       |  18,813 worst observed branch |
| 100-refund burn                       | 601,290 worst observed branch |
| quote claim                           |                        33,816 |
| fixed claim-for                       |                        33,840 |
| winning NFT redemption                |                        37,485 |
| cash redemption                       |                        18,270 |
| sponsor prize claim                   |                        29,425 |
| Lens single                           |                        55,738 |
| Lens maximum batch (64)               |                     2,471,642 |

The 300,000 callback setting leaves 204,922 gas, or 68.31%, above the measured
storage work. The maximum refund batch uses 3.58% and the maximum ticket purchase uses
16.71% of Base's documented 16,777,216 maximum transaction gas. No terminal transition
scales with total tickets. The requested 100-raffle Lens read is not applicable because
the production cap is intentionally 64; the maximum supported batch was measured.

Canonical final production sizes:

| Contract      |  Runtime | Initcode | EIP-170 runtime margin |
| ------------- | -------: | -------: | ---------------------: |
| Raffle        | 16,817 B | 19,251 B |                7,759 B |
| RaffleFactory | 24,311 B | 25,109 B |                  265 B |
| RaffleLens    |  6,625 B |  6,845 B |               17,951 B |

Factory size margin is a release-sensitive residual risk; any production change must
repeat the size gate.

## Compiler differentials

- canonical Foundry and Hardhat use Solidity 0.8.36, Cancun, optimizer 1,000, no IR;
- final via-IR sizes were Raffle `14,708/17,534`, Factory `22,171/22,808`, Lens
  `6,522/6,698` runtime/initcode; all 70 local tests passed under the comparison
  profile and the RPC-gated fork suite skipped as designed;
- via-IR and non-IR storage layouts matched exactly;
- optimizer-disabled coverage execution passed all 70 final local tests;
- Prague semantic comparison passed all 70 final local tests;
- Shanghai compilation is intentionally unsupported because OpenZeppelin 5.6.1 uses
  Cancun `mcopy`; Base production supports Cancun.

Production settings were not changed merely because via-IR is smaller.

## Base forks and Pyth

Pinned fork tests passed 2/2:

| Network      | Chain ID |      Block | Dependencies                           |
| ------------ | -------: | ---------: | -------------------------------------- |
| Base mainnet |     8453 | 49,752,968 | official USDC and Pyth Entropy v2      |
| Base Sepolia |    84532 | 45,263,498 | official test USDC and Pyth Entropy v2 |

The tests exercised real fee and request encoding, exact USDC deltas, standard ERC-721
deposit/claim, and callback-sender authentication. Mainnet `getFeeV2(300000)` returned
`10,000,000,000,000` wei at the pinned block; the Pyth request event reported an
effective provider gas limit of 500,000. The fork does not impersonate Pyth to claim a
real production callback. See `FORK-VALIDATION.md`.

## SDK, subgraph, frontend, and deployment

- SDK: generated ABI/type synchronization completed; ten SDK tests pass, including
  claim-kind ordinals and empty, duplicate, nonpositive, and greater-than-100 refund
  ID rejection.
- Subgraph: ABI/codegen/build/tests completed; handlers reconstruct the single status,
  burns, claims, prize claimant, and liabilities.
- Frontend: lint, typecheck, unit tests, and production build are final release gates;
  writes simulate live chain state and missing deployments fail closed.
- Deployment: two Hardhat deployment-record tests and three deployment/lifecycle
  integration tests pass. Validation checks RPC chain and head, block, official chain
  dependencies, runtime code, immutable factory bindings, callback gas, treasury,
  owner/pending owner, and Lens binding. Mainnet additionally requires verified source
  and a contract-wallet final owner.

## Final repository commands

```text
corepack pnpm install --frozen-lockfile
corepack pnpm format:check
corepack pnpm lint
corepack pnpm typecheck
corepack pnpm build
corepack pnpm test
corepack pnpm contracts:build
corepack pnpm contracts:test:foundry
corepack pnpm contracts:test:hardhat
corepack pnpm contracts:coverage
corepack pnpm contracts:gas
corepack pnpm contracts:slither
corepack pnpm --filter @raffle-fun/sdk sync:check
corepack pnpm --filter @raffle-fun/sdk test
corepack pnpm subgraph:codegen
corepack pnpm subgraph:build
corepack pnpm subgraph:test
corepack pnpm --filter @raffle-fun/web lint
corepack pnpm --filter @raffle-fun/web typecheck
corepack pnpm --filter @raffle-fun/web test
corepack pnpm --filter @raffle-fun/web build
corepack pnpm audit --audit-level high
```

## Failures, remediation, and blocked capabilities

- Baseline clean-checkout CI failures were fixed by installing dependencies/toolchains
  and generating dependent artifacts in the correct order.
- The strict invariant handler's original O(n) owner search hit the per-property time
  cap; direct guarded selection and one-ticket purchase removed test-harness scaling.
- One broad-campaign mutation survivor caused the sequential-ticket regression and
  was killed. The final 12-mutant recovery campaign also killed every mutant.
- No independent-fuzzer counterexample remained to convert.
- Mythril was not executed; SMTChecker was inconclusive; Certora was not configured.
- No public/testnet transaction was broadcast. Pinned forks passed, but monitored Base
  Sepolia operation remains a release blocker rather than a completed campaign.
