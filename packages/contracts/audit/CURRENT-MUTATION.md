# Current-Source Mutation Campaign

## Identity and reproducibility

The historical Gambit reports reviewed older commits and are context only. This campaign adds a current-source runner and declarative mutant set:

- runner: `scripts/current_mutation.py`
- configuration: `audit/current-mutations.json`
- source target: committed production Solidity at `5772e54ba89c06646815ed52a881cd8940f094ca`
- test oracle: the active checkout's current Foundry tests, overlaid onto a detached disposable worktree
- command: `PYTHONPYCACHEPREFIX=/tmp/raffle-pycache python3 scripts/current_mutation.py`
- per-mutant gate: `forge test -q --no-match-contract BaseForkTest`

The runner creates a temporary detached git worktree, links the existing dependency installation/submodule, copies the active tests, applies exactly one source-fragment mutation, runs the test gate, restores from an in-memory original, and removes only the temporary worktree. It never changes active production source. Match count must be exactly one; zero/ambiguous matches are classified invalid and make the run fail.

`audit/current-mutation-results.json` records the initial run and `audit/current-mutation-survivor-rerun.json` records the focused red/green rerun. A zero exit requires no survivor, compile error, or invalid definition.

## Target set

The 38 deterministic mutants cover:

- Drawing and selected-winner transfer locks;
- zero-based/wrong-denominator winner mapping;
- callback in-flight, status, and sequence checks;
- threshold, fee, and cash split arithmetic;
- unsettled-pot clearing;
- refund amount, liability decrement, and ticket burn;
- both sides of exact outgoing and incoming token deltas;
- inclusive/exclusive sale boundaries;
- 0/101 purchase bounds and sequential IDs;
- prize-delivery ownership verification;
- NFT timeout claimed guard and early finalization;
- known-protocol transfer destinations;
- ownership renunciation and creation pause;
- maximum start/duration/metadata boundaries;
- zero price/threshold;
- creation prize ownership and Active-state verification;
- Lens sale/draw/batch boundaries.

This is a focused security sample, not exhaustive mutation of every expression or event field. Event-field corruption, sponsor/winner swaps, liability clearing after interaction, every status comparison, and deployment/off-chain mutations remain expansion targets.

## Results

| Metric                                           |   Current result |
| ------------------------------------------------ | ---------------: |
| defined                                          |               38 |
| initial compiled and killed                      |               30 |
| initial survivors                                |                8 |
| initial compile errors / invalid definitions     |            0 / 0 |
| initial raw score                                |           78.95% |
| survivors killed after deterministic regressions |                8 |
| final survivors                                  |                0 |
| final compiled mutation score                    | **38/38 (100%)** |

The runner separately detects compiler errors; none occurred in either run. A compiler-rejected mutant was therefore not counted as a security kill.

## Survivor review

| Mutant                                    | Initial classification | Missing sensitivity                                                                            | Preserved regression                                                 | Rerun  |
| ----------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------ |
| M-05 remove callback in-flight check      | test gap               | synchronous callback used nonzero sequence, while zero sequence was tested only asynchronously | `testSynchronousZeroSequenceCannotMatchDefaultStoredSequence`        | killed |
| M-20 allow 101-ticket purchase            | test gap               | Solidity purchase tested 0 but not 101 (refund batch did test 101; SDK now did too)            | exact `InvalidQuantity(101,100)` purchase assertion                  | killed |
| M-23 omit NFT delivery owner verification | test gap               | freezing/reverting prize existed, successful misdirection did not                              | `testRegressionMisdirectedPrizeCannotConsumeWinnerOrReleaseProceeds` | killed |
| M-29 reject exact seven-day start delay   | test gap               | only maximum+1 rejection was asserted                                                          | exact maximum accepted creation                                      | killed |
| M-30 reject exact 30-day sale duration    | test gap               | only maximum+1 rejection was asserted                                                          | exact maximum accepted creation                                      | killed |
| M-33 reject exact 2,048-byte metadata     | test gap               | only 2,049-byte rejection was asserted                                                         | exact maximum accepted creation                                      | killed |
| M-36 Lens allows draw at grace deadline   | test gap               | contract boundary existed without Lens parity assertion                                        | `testLensExactSaleAndRequestGraceBoundariesMatchRaffle`              | killed |
| M-37 Lens allows buy at sale end          | test gap               | contract boundary existed without Lens parity assertion                                        | same Lens boundary regression                                        | killed |

All survivors were test defects, not equivalent/unreachable mutants, specification ambiguities, or reproduced production defects. Production source already contained the intended checks, so only deterministic tests were added.

The 100% result applies only to these 38 hand-selected, compiling current-source mutants. It is not an exhaustive mutation score.

## Gambit availability

No current Gambit executable was present at the historical `/tmp/raffle-audit-tools/gambit` location or on the active PATH. Therefore no fresh Gambit-generated count or score is claimed. The custom deterministic runner preserves current-source reproducibility without pretending it is equivalent to broad Gambit operator enumeration.
