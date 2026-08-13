# Extreme smart-contract testing — 2026-08-13

## Conclusion

This follow-up tested the production contracts at `b992b23eabfffb4f5604524951c673f70b920603`
plus the test-only changes described below. No production Solidity was changed and no
transaction was broadcast.

No new production implementation defect was found. Mutation testing found two missing
event assertions: callback-timeout and NFT-timeout refund events could be mutated to
claim that no draw had been accepted without failing the old suite. Exact assertions
for all three refund origins were added, and both mutants then died. The final targeted
mutation result was 36/36.

These results do not remove the documented High trust assumption in Pyth Entropy. A
provider that already owns tickets can know its result before reveal and selectively
withhold an unfavorable result. Drawing-state transfer locking prevents post-request
winner acquisition but cannot force provider liveness or honest reveal.

## New durable tests

`RaffleExtreme.t.sol` adds ten deterministic adversarial tests:

- exact callback and NFT-redemption deadline transaction ordering;
- callbacks and NFT redemptions one year after their deadlines when nobody has first
  finalized refunds;
- exact `RefundsEnabled` event semantics for missed request, callback timeout, and NFT
  timeout;
- full rollback when the first safe-minted ticket is transferred inside a receiver
  callback and a later mint callback reverts;
- atomic rejection of duplicate and mixed-owner refund batches;
- stale operator approvals across Drawing, winner lock, and Refunding;
- recipient-bonus and sender-rebate quote tokens on incoming and outgoing transfers;
- forced native currency remaining outside quote accounting and draw fees;
- sponsor, treasury, buyer, and winner address aliasing;
- interleaved NFT-win, cash-win, and refund lifecycles across three raffles.

`RaffleFleetInvariant.t.sol` drives three raffles sharing one factory, quote token,
Entropy mock, clock, sponsor, and treasury. It also mutates factory pause/treasury
policy, changes the shared Entropy fee, and attempts cross-raffle bearer transfers.
After every generated sequence it checks local and aggregate solvency, registry
identity, immutable captured configuration, ticket-owner isolation, winner bounds,
status monotonicity, and exact prize escrow ownership.

`BaseFork.t.sol` now has separately gated latest-head tests in addition to reproducible
pinned-block tests. Ordinary local runs remain RPC-independent.

## Campaign results

| Campaign | Result |
| --- | ---: |
| Foundry aggregate | 88 passed, 0 failed, 1 RPC-gated suite skipped |
| Hardhat integration/deployment | 9 passed, 0 failed |
| New fleet invariants, three independent seeds | 3,072,000 calls, 0 handler reverts, 0 violations |
| Fresh arithmetic/value fuzzing | 600,000 cases passed |
| Fresh differential-model fuzzing | 100,000 lifecycle sequences passed |
| Echidna 2.3.3, cash and forced-NFT harnesses | 1,000,747 calls; 12/12 properties passed |
| Medusa 1.5.1, cash and forced-NFT harnesses | 523,017 calls; 46/46 tests passed |
| Gambit 1.0.6 targeted sample | 36/36 compiling mutants killed after regressions |
| Halmos 0.3.3 / Z3 4.12.6 | 5 checks, 9 feasible paths, 0 failures |
| Live Base and Base Sepolia forks | pinned and latest-head suites passed |
| Compiler differentials | canonical, via-IR, optimizer-off, and Prague passed |
| Storage-layout differential | Raffle, Factory, and Lens identical under default/via-IR |
| Slither 0.11.6 | 49 contracts, 64 detectors, 0 results |
| Production coverage | 99.74% lines, 98.78% statements, 94.38% branches, 100% functions |
| Gas snapshot | regenerated for new tests and immediately rechecked successfully |

The final latest-head fork rerun observed Base block `49,923,565` and Base Sepolia
block `45,434,095`. It validated deployed USDC and Pyth code/interfaces, six-decimal
USDC behavior and exact transfer deltas, fee reads and request encoding, local
factory/raffle construction, prize escrow/recovery, ticket purchase, draw request, and
callback-wrapper authentication. Public chain state was only read through local forks.

Canonical runtime sizes remained:

| Contract | Runtime | EIP-170 margin |
| --- | ---: | ---: |
| Raffle | 16,726 bytes | 7,850 bytes |
| RaffleFactory | 24,267 bytes | 309 bytes |
| RaffleLens | 6,954 bytes | 17,622 bytes |

The Factory margin is release-sensitive. Any production change must repeat the size
gate and should not consume that margin casually.

## Important semantics made explicit

Deadlines make refund finalization permissionless; they do not automatically mutate
contract state. At the callback deadline, either a valid callback or `enableRefunds()`
can be the first transaction. Likewise, after the NFT redemption deadline, either the
winner redemption or refund finalization can be first. If nobody finalizes refunds, a
valid callback or NFT redemption remains executable even a year later. The new tests
lock in this transaction-ordering behavior so it cannot change accidentally.

## Remaining limits

- Entropy selective reveal/censorship remains a High external trust assumption.
- USDC can be paused, frozen, blacklisted, or upgraded by its issuer.
- A malicious or later-upgraded prize NFT can violate ERC-721 ownership semantics.
- Public fork success does not replace monitored Base Sepolia operation or an external
  audit of the exact release commit.
- Fuzzing, symbolic execution, mutation testing, and high coverage are evidence, not a
  mathematical proof of the entire protocol or its economic environment.
