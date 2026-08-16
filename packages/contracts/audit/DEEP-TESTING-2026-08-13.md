# Deep contract testing follow-up — 2026-08-13

## Scope and conclusion

The production contracts at commit `fe09d476cbe770d770cbc2603a1ce73330739025`
were exercised without modifying production Solidity or broadcasting any transaction.
No new production implementation defect was found. The campaign did find five test
quality defects: one stale Echidna oracle, two vacuous Halmos paths, and two missing
mutation assertions. All were corrected in the test suite and the affected campaigns
then passed non-vacuously.

This result is strong evidence for the tested safety and accounting properties. It is
not a proof of trustlessness or release readiness. The Entropy provider's documented
selective-reveal capability remains an unresolved High trust assumption, and the
external-audit, deployment, operational, legal, and monitored testnet blockers in
`RELEASE-CHECKLIST.md` still apply.

## Results

| Campaign                         |                                                                      Result |
| -------------------------------- | --------------------------------------------------------------------------: |
| Final Foundry aggregate          |                               74 passed, 0 failed, 1 RPC-gated test skipped |
| Hardhat integration              |                                                          9 passed, 0 failed |
| Arithmetic/value fuzzing         |                              1,200,000 cases across two deterministic seeds |
| Independent differential model   |           100,000 state-machine sequences, 1–32 actions plus terminal drain |
| Broad and multi-actor invariants |                                                     2,816,000 handler calls |
| Strict release invariants        |                  385,148 sequences; 197,195,776 calls; zero handler reverts |
| Final dual-harness Echidna rerun |                                   200,439 calls; 12 property results passed |
| Halmos 0.3.3 / Z3 4.12.6         |                                      5 checks, 9 feasible paths, 0 failures |
| Current-commit Gambit sample     |                            24/24 compiling mutants killed after regressions |
| Pinned Base forks                |               Base mainnet and Base Sepolia passed against live public RPCs |
| Compiler differentials           |                       default, via-IR, optimizer-off, and Prague all passed |
| Storage-layout differential      |          default and via-IR layouts identical for Raffle, Factory, and Lens |
| Slither 0.11.6                   |                                      49 contracts, 64 detectors, 0 findings |
| Production coverage              |                               99.74% lines, 94.38% branches, 100% functions |
| Secrets                          |                                           Gitleaks full-history scan passed |
| Dependencies                     | no critical/high/moderate advisory; one low development/transitive advisory |

The strict invariant profile ran until its one-hour timeout and substantially exceeded
its nominal sequence target:

- prize escrow: 94,384 runs and 48,324,608 calls;
- quote accounting: 61,918 runs and 31,702,016 calls;
- monotonic status/resolution: 93,109 runs and 47,671,808 calls;
- winner/fee bounds: 135,737 runs and 69,497,344 calls.

## Test-suite defects found and corrected

### Echidna terminal-history oracle

The NFT-timeout path correctly transitions `NftWon` to `Refunding` while retaining
`winningTicketId` as historical resolution data. The old property incorrectly required
the winner to reset to zero outside `NftWon`/`CashWon`. Echidna shrank this to a four-step
counterexample. The property now keys pre-resolution behavior from `resolvedAt` and
accepts the retained in-range winner in the post-resolution refund state.

The harness is now split into two independently targetable deployments:

- `RaffleEchidna`, with threshold 25, exercises cash settlement and can cross into NFT settlement;
- `RaffleNftEchidna`, with threshold 1, forces NFT settlement and covers the 30-day NFT timeout refund path.

The final isolated runs used seeds `20260813` and `20260815`. Coverage confirmed the
cash branch in the broad harness and the NFT result plus `nftRedemptionDeadline()`
refund transition in the NFT harness.

### Halmos vacuity

Two credential-consumption checks paid the factory address because the symbolic test
contract is also the direct raffle factory. The hardened production destination guard
correctly rejected both payouts, so Halmos reported that all paths reverted. The tests
now pay an independent address and assert final recipient balances/ownership. The same
five-check command then passed all nine feasible paths with no revert-all warning.

### Mutation survivors

A deterministic 24-mutant sample targeted request timing, Entropy sequence state,
refund transitions, winner redemption, NFT/cash accounting, winner selection, and
exact quote transfers. Twenty-two mutants died immediately. The two survivors were:

1. treating every non-Active/non-Drawing status as an NFT-timeout refund candidate;
2. zeroing the advertised sponsor amount in the NFT `RaffleResolved` event.

Regression tests now require `enableRefunds()` to reject `CashWon`, claimed `NftWon`,
`Refunding`, and `Closed`, and assert every indexed/data field of the NFT resolution
event. Both former survivors were rerun in disposable worktrees and killed, producing
a final 24/24 score for this sample.

## Environment and integration checks

The pinned fork suite passed at Base block `49,752,968` and Base Sepolia block
`45,263,498`. It exercised deployed USDC metadata and exact transfers, live Pyth
Entropy interface/provider/fee reads, factory deployment, NFT escrow and recovery,
ticket purchase, draw request, and rejection of a direct unauthorized callback.

The full non-fork suite also passed under via-IR, with the optimizer disabled, and with
Prague EVM rules. Default and via-IR storage layouts were normalized and compared
byte-for-byte with no differences.

## Remaining limits

- Transfer locking blocks post-request winner acquisition, but does not prevent an
  Entropy provider that already owns tickets from selectively revealing favorable
  randomness and accepting refunds otherwise.
- Public fork RPC success does not replace monitored testnet operation or mainnet
  deployment verification.
- USDC issuer controls, malicious or changing ERC-721 behavior, Base sequencing, lost
  keys, and arbitrary non-callable ticket destinations remain external assumptions.
- `RaffleFactory` runtime remains only 309 bytes below EIP-170.
- The repository-wide formatter check still reports pre-existing style drift in
  untouched Solidity files.
- Fuzzing, symbolic execution, mutation testing, static analysis, and forks cannot
  enumerate every state or external behavior; an independent audit of the exact final
  commit remains required.
