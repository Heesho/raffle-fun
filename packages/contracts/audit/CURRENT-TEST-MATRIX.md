# Current v1 test matrix — 2026-08-18

Candidate: committed Ethereum v1 range-ticket audit candidate. The implementation is
`92eccb4beda71175dfeab4fa2282fbcfaab075c4`; mutation evidence was committed in
`e9e0e730c17c07b21e911aa0c02804336e4f146b`. This matrix is internal evidence, not an
independent audit, and the complete gate set must be rerun from the clean final release SHA.

> The totals below are preserved evidence for the recorded pre-remediation SHAs. They
> do not validate the later hard request/callback-boundary change, official Chainlink
> consumer-base migration, or bearer-redemption redesign; affected rows require a clean
> rerun against the final release SHA.

In the lifecycle rows, `D = drawRequestDeadline() = endTime + 2 days` and
`C = callbackDeadline() = drawRequestedAt + 2 days`.

## Latest verified totals

| Layer               |                                   Result | Freshness / limitation                                            |
| ------------------- | ---------------------------------------: | ----------------------------------------------------------------- |
| Foundry             |                      72 passed, 0 failed | excludes the RPC-gated fork test                                  |
| Ethereum fork       |                                1 skipped | compiled; no RPC-backed result claimed for this candidate         |
| Hardhat             |                      22 passed, 0 failed | includes deployment, source-verification, and journey regressions |
| independent model   |                      11 passed, 0 failed | separate Python lifecycle/economics model                         |
| mutation            |            52/52 declared mutants killed | hand-selected compiling set, not exhaustive                       |
| gas                 |                      57 passed, 0 failed | deterministic snapshot and check                                  |
| gas/fork            |                                1 skipped | RPC-gated fork case                                               |
| SDK                 |                      14 passed, 0 failed | v1 actions, bigint validation, and economics                      |
| web                 |                      15 passed, 0 failed | v1 UI/sandbox behavior                                            |
| subgraph            |                       7 passed, 0 failed | includes ignored-VRF-callback indexing                            |
| production coverage | 100.00% lines/functions, 94.12% branches | committed candidate result; reproduce on final release SHA        |
| Slither             |    47 contracts, 64 detectors, 0 results | empty triage database; one exact source annotation is documented  |
| Gitleaks            |                                  0 leaks | tracked candidate and 25-commit history scans                     |

Eight Foundry fuzz properties passed the 1,000-case default and 100,000-case audit
profiles. Seven stateful invariants passed the default 16,384-call/property profile and
the 256,000-call/property audit and strict profiles. The strict profile enables
`fail_on_revert` and completed with zero handler reverts.

Fresh production-only coverage is 100.00% lines, 100.00% functions, and 94.12%
branches. Reproduction from a clean checkout of the exact final release SHA remains required.

Slither exits 0 with no results and an empty triage database. One exact source annotation
documents the fixed-clone initialization heuristic without globally disabling its
detector. Gitleaks also exits 0 for the committed candidate and 25-commit history.

## Lifecycle and authorization

| Property                                          | Required evidence                                                                   | Current evidence                                            |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Locked implementation and one-time initialization | direct implementation and clone reinitialization reject                             | Foundry unit/security                                       |
| Atomic creation                                   | clone registration, initialization, prize escrow, and activation roll back together | Foundry unit/security + Hardhat journey                     |
| Future-only pause                                 | creation rejects while existing raffles remain operable                             | Foundry unit + deployment tests                             |
| Immediate sale and maximum duration               | sale begins at creation and cannot exceed 30 days                                   | Foundry boundary + mutation                                 |
| Bearer ownership                                  | tickets transfer before close, while drawing, and after resolution until burned     | Foundry unit/fuzz/invariant                                 |
| Draw-request window                               | request succeeds exactly in `[endTime, drawRequestDeadline())`                      | Foundry unit + model; remediated-SHA rerun required         |
| Missing request                                   | sold `Active` refund rejects before `D` and opens at `D`; request rejects at `D`    | Foundry unit + model; remediated-SHA rerun required         |
| Missing callback                                  | callback resolves before `C`; at `C` it is ignored and refunds open                 | Foundry unit + model; remediated-SHA rerun required         |
| Result finality                                   | neither resolved branch can later enter refunds                                     | Foundry unit + model                                        |
| Cash callback finality                            | no later refund transition                                                          | Foundry unit/invariant/model                                |
| Last-valid-second request                         | request at `D - 1` gives a fresh two-day callback window, almost four days from end | Foundry unit/invariant/model; remediated-SHA rerun required |
| Empty raffle                                      | zero-liability `Refunding`; sponsor recovery preserved                              | Foundry unit                                                |

## Range tickets and complexity

| Property                          | Required evidence                                                          | Current evidence                     |
| --------------------------------- | -------------------------------------------------------------------------- | ------------------------------------ |
| One ticket per purchase           | positive counts through `uint128` maximum produce one ticket               | Foundry unit/fuzz/mutation           |
| Sequential ID + stored range      | exact ID order, first/last lookup, adjacency, no gaps, clone isolation     | Foundry unit/fuzz/invariant/mutation |
| Separate counts                   | `totalEntries` and `ticketCount` advance independently                     | Foundry unit/invariant/subgraph      |
| Overflow atomicity                | cumulative `uint128` overflow reverts without payment or mint              | Foundry unit/mutation                |
| O(1) purchase                     | gas does not scale with entries in one ticket                              | Foundry gas regression               |
| O(1) callback                     | callback contains no ticket search or external user/asset call             | Foundry unit/security/gas            |
| O(1) winner proof                 | supplied range contains `winningEntry`; adjacent and foreign ranges reject | Foundry unit/fuzz/invariant          |
| Ticket-bounded refund             | batch length is 1–100 tickets, independent of stored entry counts          | Foundry unit/fuzz/gas/mutation       |
| No per-entry expansion downstream | SDK/web/subgraph retain bigint ranges and one ticket entity                | SDK/web/subgraph tests               |

## Chainlink VRF

| Property                   | Required evidence                                                                                                                                                   | Current evidence                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Fixed parameters           | 300,000 callback gas, 30 confirmations, one word, native payment                                                                                                    | Foundry unit + Hardhat journey                                 |
| Dynamic native request fee | insufficient, exact, overpayment, price change, refund failure                                                                                                      | Foundry unit + adversarial wrapper                             |
| Wrapper authentication     | unauthorized raw callback rejects                                                                                                                                   | Foundry unit; RPC-backed fork pending                          |
| In-flight defense          | synchronous valid/wrong/duplicate/zero-ID attempts cannot resolve early                                                                                             | adversarial wrapper + mutation                                 |
| Request matching           | authenticated ABI-decodable wrong, stale, repeated, wrong-word-count, duplicate, and deadline-expired callbacks are harmless; unauthorized/undecodable calls revert | Foundry unit/security/invariant; remediated-SHA rerun required |
| Request atomicity          | price/request failures cannot leave a persisted drawing request                                                                                                     | adversarial wrapper                                            |
| Callback boundedness       | both terminal branches remain below the mock 300,000 budget                                                                                                         | Foundry gas regression                                         |
| Winner formula             | result is always within `[1,totalEntries]`; last entry is reachable                                                                                                 | Foundry unit/fuzz/invariant + model                            |
| Live configuration bound   | callback + wrapper + EIP-150 overhead fits coordinator maximum                                                                                                      | Hardhat boundary regression; release-day live check pending    |
| Ignored-callback telemetry | immutable diagnostic entity and aggregate counter                                                                                                                   | subgraph mapping test + independent closure review             |

## Economics and settlement

| Property                         | Required evidence                                                          | Current evidence                           |
| -------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------ |
| Fixed quote precision and price  | factory rejects non-six-decimal quote; entry price is `1_000_000`          | Foundry unit + Hardhat journey             |
| Reserve boundary                 | equality selects NFT; one below selects cash                               | Foundry unit/fuzz/model/mutation           |
| Cash economics                   | 80/5/15 winner/treasury/sponsor gross split                                | Foundry unit/fuzz/invariant/model          |
| NFT economics                    | gross stays escrowed until verified delivery, then 5%/95%                  | Foundry unit/fuzz/invariant/model          |
| Full refunds                     | no fee; each ticket returns exact range-weighted gross once                | Foundry unit/fuzz/invariant/model/mutation |
| Permissionless winner settlement | third party may deliver only to current owner                              | Foundry unit/fuzz/mutation                 |
| Fixed winner destination         | caller cannot redirect NFT or cash from the current owner                  | Foundry unit/mutation                      |
| Sponsor recovery                 | anyone releases NFT only to fixed sponsor recipient                        | Foundry unit/invariant/mutation            |
| Fixed quote releases             | anyone releases sponsor/treasury balances only to immutable recipients     | Foundry unit/invariant/mutation            |
| Failed-transfer rollback         | ticket, custody, liability, and claims remain unchanged                    | Foundry unit/security/mutation             |
| Exact token deltas               | taxed, false-return, short-credit, over-credit, and reentrant paths reject | Foundry security                           |
| Solvency                         | recorded claims/refunds conserve and remain backed by quote custody        | Foundry fuzz/invariant + model             |
| Donations                        | surplus quote/native value cannot create or consume liabilities            | Foundry unit/invariant                     |

## Factory, asset, and destination defenses

| Property              | Required evidence                                                          | Current evidence                                            |
| --------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Exact NFT escrow      | callback-only, no-op, redirecting, and reentrant prize transfers roll back | Foundry unit/security/mutation                              |
| Safe fixed identities | sponsor and treasury reject known protocol destinations                    | Foundry unit/mutation                                       |
| Runtime destinations  | ticket, NFT, quote, winner, and recovery paths reject known protocol sinks | Foundry unit/security/mutation                              |
| No admin over clones  | no factory upgrade or existing-raffle override exists                      | source review + ABI tests                                   |
| Canonical clones      | registered instances use the fixed implementation target                   | Foundry unit + Hardhat journey; live bytecode proof pending |

## Integration and release validation

| Layer              | Required evidence                                                          | Current evidence / remaining gate                        |
| ------------------ | -------------------------------------------------------------------------- | -------------------------------------------------------- |
| ABI                | generated SDK/subgraph ABIs match source; retired Lens/Pyth symbols absent | current drift checks reported green; repeat at final SHA |
| Deployment record  | chain, addresses, constants, hashes, final block, and ownership are bound  | Hardhat regressions; no signed live record               |
| Source publication | exact direct-contract match; omitted/proxy/similar-match metadata rejects  | Hardhat regression; no live verification                 |
| SDK                | `bigint` counts/ranges, explicit ticket IDs, fixed economics               | 14/14                                                    |
| Web                | fixed-$1 entries, range tickets, direct reads, settlement/refunds          | 15/15; repeat lint/typecheck/build at final SHA          |
| Subgraph           | one ticket per purchase, no per-entry loop, callback/result/burn state     | 7/7                                                      |
| External fuzzer    | harness compiles and reaches material terminal branches                    | runtime campaign pending                                 |
| Static analysis    | supported production rules pass on exact source                            | Slither green with 0 results; final-SHA rerun pending    |
| RPC forks          | pinned and latest-head Ethereum mainnet/Sepolia behavior                   | exact-candidate execution pending                        |

## Deliberate exclusions and supersession

Per-ticket, Lens, Pyth, Base, scheduled-start, metadata, capped-quantity, fleet, symbolic,
and obsolete differential suites targeted removed behavior. Material current properties
were moved into the v1 unit, security, VRF-adversarial, fuzz, invariant, model,
deployment, mutation, SDK, web, and subgraph suites. Historical results remain
commit-pinned evidence only and are superseded for this candidate.
