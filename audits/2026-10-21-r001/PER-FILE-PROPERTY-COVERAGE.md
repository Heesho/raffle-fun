# Per-file and per-property coverage — r001

Target `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. The five production files and 31 reachable dependency files retain the frozen bytes. Source reading, context inclusion, instrumented execution, native workflow completion, bounded assertions, symbolic domains, public-fork compatibility, and reconciliation are different measurements. None is a universal proof, and counts are not model votes.

Final matrix context is 23 cells: 20 complete or qualified-complete and three actual OpenAI provider-rejected. All ten Claude/Gemini cells are effective complete after the modified Claude OpenKritt terminal gate verified. That gate contributes provenance but does not change the instrumented line/function/branch denominators below. Final reconciliation contains `28` report paths, `27` distinct report hashes, and `739` attribution links.

## Production files

| File under `packages/contracts/src` | Source review | Instrumented lines | Functions | Branches |
|---|---|---:|---:|---:|
| `Raffle.sol` | Every production function and exposed inherited mutation surface mapped | 246/247 | 31/31 | 52/58 |
| `RaffleFactory.sol` | Constructor, all production functions, clone creation, registries and getters mapped | 61/61 | 4/4 | 17/18 |
| `interfaces/IRaffle.sol` | Types, events, errors, signatures, generated getters, and honest-prize specification conflict mapped | N/A | N/A | N/A |
| `interfaces/IRaffleFactory.sol` | All declarations and deployment-identity assumptions mapped | N/A | N/A | N/A |
| `libraries/RaffleConstants.sol` | Every economic, deadline, batch, callback, gas and unit constant mapped | N/A | N/A | N/A |

The counters come from [instrumented coverage](coverage-summary.json), whose unoptimized bytecode differs from the production profile. Interfaces and constants have no meaningful executable denominator. [SUP-S1](runs/SUP-S1/attempt-01/COVERAGE.md) covers the actually used ERC-721/receiver/guard, SafeERC20, Clones, Math and Chainlink base paths. Context inclusion is not an independent full audit of unused package APIs, the deployed wrapper implementation, live quote-token administration, or all external collection behavior.

## Properties

| ID | Property | Executed/reconciled evidence | Controlling limits and gaps |
|---|---|---|---|
| P01 | Quote custody and solvency | Foundry exact-solvency invariant; Echidna sales/liability properties; Medusa; bounded Halmos terminal drains | Exact-transfer quote mocks; fee/rebase/false-success tokens are unsupported; no universal issuer blacklist/pause proof |
| P02 | Per-beneficiary 80/15/5, 95/5 and full refunds | Independent literal-rate fuzz/invariants; Halmos literal expected balances; late ToB unit/fuzz ledgers | Aggregate conservation does not by itself assert each beneficiary rate; larger domains and payout permutations rely on source/fuzz rather than universal proof |
| P03 | Range partition, ticket sequence and unique winner | Three range/sequence/winner invariants; Echidna; source proof; late purchase-only campaigns | Original Halmos covers two tickets/two owners; late invariants are bounded; arbitrary callback words and uniformity are not universally proved |
| P04 | Current-owner authorization and atomic rollback | Unauthorized/operator/transfer tests; original and terminal Halmos owner checks; late negative paths | Stateful handlers commonly select actual owners; owner-check deletion survived the short invariant suite; Python model lacks EVM rollback |
| P05 | Initialization and factory-clone consistency | Factory unit/security tests, local Hardhat integration, complete source entrypoint pass | Canonical token/wrapper and live candidate bytecode remain deployment responsibilities; no candidate deployment was supplied |
| P06 | Lifecycle/deadline boundaries and refund liveness | Boundary regressions, deadline invariant, Echidna monotonic/deadline properties, late lifecycle examples | Valid-action prefilters exclude forbidden request boundary; inclusive-deadline mutant survived invariants; ordinary-path liveness assumes functioning dependencies and a funded caller |
| P07 | NFT custody and successful delivery | Malicious callback/token tests; Echidna custody; honest-OZ Halmos delivery; forged/paused-prize post-pass reproductions | A selected prize can self-attest dishonestly or later pause/seize/refuse transfer; receiver acceptance and `ownerOf` cannot prove lasting truthfulness or capability |
| P08 | Economic payout versus prize delivery | Sealed source findings; Daybreak Simao proofs; Gemini ToB paused-prize pass; Claude/Daybreak ToB ledgers; RF-001 | Sponsor/protocol payouts can be independent of later delivery. Controlling severity is conditional High under untrusted-prize scope; Critical remains dissent; trust-model decision unresolved |
| P09 | Recipient and clone-destination isolation | Same-factory future-prize reproduction; Claude S6 future quote-lock case; Daybreak S6 existing other-factory ticket case | Three narrow own-recipient/bearer-loss variants only; no arbitrary EOA theft, buyer-refund loss, or cross-raffle accounted-fund drain |
| P10 | VRF authority, callback ordering and gas | Inherited wrapper-auth source pass; mock callback/security/fee tests; gas checks; pinned mainnet/Sepolia request-path tests | No genuine off-chain fulfillment, full billing/configuration/finality proof, or arbitrary callback-word formal proof; modulo bias and reorg remain bounded/external |
| P11 | Transfer, reentrancy and rollback | OZ/guard/SafeERC20 reachable-path review; malicious receiver/quote/prize controls; late callback-order tests | Exact-transfer quote assumption; arbitrary ERC-721 honesty cannot be inferred; safe receipt does not prove future outbound capability |
| P12 | Gas-bounded batching and callback work | Maximum-100 refund observation at 667,412 gas; 61 gas-baseline tests; O(1) callback source pass | Local gas observations and selected profiles are not universal block-inclusion guarantees |
| P13 | Handler reachability and nonvacuity | Four-mutant experiment; unit/fuzz/security killed all four; extended invariant killed fee mutant; late handlers record bounded calls | All four mutants survived short invariants; purchase-disabled mutant survived strict invariants through caught reverts; reported calls include no-ops/reverts and are not all economic actions |
| P14 | SDK/frontend/indexer consistency | 16 SDK, 25 web, 8 subgraph tests; codegen/build/typechecks; canonical ABI sets 125/26 | Top-level ABI order differs; no complete deployed wallet/browser/indexer/chain flow |
| P15 | Reference mathematics and model fidelity | Independent formulas/balance deltas; 11 standalone Python tests; rollback diagnostic | Python tests are not Solidity differential verification; rejected lazy-redemption path mutates Python state without EVM rollback |
| P16 | Dependency and supply chain | Actual 31-file Solidity closure review; 69 distinct GHSA reachability review; 1,286 registry signatures | Git-sourced era-contracts lacks an npm packument attestation; signatures do not certify all dependencies or deployed administration |

## RF-002 expanded proof scope

The final Low root family contains three separately executed variants:

1. A sponsor chooses the predictable address of a future same-factory clone as its immutable recipient; after deployment, an honest NFT sponsor prize can be transferred into that clone and stranded.
2. In the same future-recipient setup, registration makes the sponsor's quote-proceeds release revert while an unrelated protocol-fee release remains possible; the claim stays backed but unavailable.
3. A ticket owner or authorized sender chooses an already deployed clone from another factory. The local registry omits it, so transfer succeeds, but the receiving clone has no general outbound owner call to redeem or return that foreign ticket.

The first two are same-factory future-address, own-recipient failures; the third is an existing other-factory bearer-claim loss and needs no prediction. These cases do not establish attacker-selected third-party recipients, EOA theft, buyer-refund loss, or a drain of another raffle. See the [sealed proof-scope addendum](reconciliation/finalization/RF002-PROOF-SCOPE-ADDENDUM.md).

## Core campaign interpretation

The release run reports 79 passes, zero failures and one historical unconfigured RPC-fork skip. Nine fuzz tests ran 100,000 cases each. Nine invariant results report **233,698,304 native calls**; handlers catch reverts and may return without an economic action. [The native counter ledger](runs/TOOL-RELEASE-EXTENDED/attempt-01/campaign-statistics-final.json) controls per-property counts.

Both extended Echidna campaigns reached their actual targets: 100,040 and 100,077 calls, six properties each, sequence length 100, one worker, seeds `2026102101` and `2026102102`. Earlier 180-second and 3,000-target attempts remain incomplete/short history. Native rejected-input and revert counts are unknown. Medusa completed 26 checks including six actual properties; the other checks are not independent invariants.

Original Halmos domains use two independently symbolic purchase amounts 1..16, two actors/tickets, exact-transfer quote, fixed VRF mocks, both refund orders, all bounded winning positions, and selected payout orders. Loop bound three did not truncate completed paths. Three accounting properties passed directly; stronger success-path exploration timed out, and eleven residual queries were discharged UNSAT through unchanged arithmetic refinement/alternative solvers. Native timeouts remain recorded. This is not proof over arbitrary actors, amounts, transfers, callback words, tokens, prize code or payout permutations. See [Halmos closure](runs/TOOL-HALMOS-CONTINUATION/SUMMARY.md).

The mutation campaign killed all four valid disposable mutants with unit/fuzz/security tests, but all four survived short invariants; the fee mutant later died at 120 invariant runs, while purchase-disabled behavior still passed strict invariants. Eleven of 52 historical mutation definitions do not match this revision and are invalid definitions, not surviving mutants. See [mutation quality](runs/TOOL-MUTATION-QUALITY/SUMMARY.md).

## Late declared-workflow campaigns

Claude ToB S6 retained:

- 20/20 Foundry tests across six suites, including two 2,000-case fuzz tests;
- 400,073 Echidna calls across nine properties at seed `6206211`;
- 400,047 assertion-campaign calls across 38 checks at seed `9917731`;
- 3,116,102 Medusa calls with 46 passes and four workers;
- 12 custom Slither structural predicates;
- seven Halmos passes and two timeout/unknown obligations, including refund conservation and full symbolic split exactness.

Its fuzzers use two raffles/four actors, ordinary entry counts 1..25 plus a large-buy action, refund batches no larger than eight, bounded warps and corruption modes. Full 100-ticket batches, all dishonest prize branches, and `paidPrice > msg.value` were not universally exercised. Manticore was unavailable; Halmos was a disclosed substitution. See [Claude S6 evidence](provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02/preserved/evidence/04-properties/).

Daybreak ToB S6 retained 21/21 unit/fuzz tests, including two 10,000-case properties. Three Foundry invariants ran 256 × 128 calls each—98,304 reported calls—but used a single actor buying entries 1..1000 in one active raffle. Echidna ran four purchase-only properties for 20,007 calls, sequence length 64 and seed `1396142931`; after at most 64 successful buys the handler becomes a no-op. Separate lifecycle/adversarial examples and two intentional negative properties do not turn the invariant domain into terminal or multi-actor proof. Slither returned 14 results with no High/Medium; exit 255 is the finding gate, not analyzer failure. No formal proof ran. See the [Daybreak S6 ledger](runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SECURITY_PROPERTIES.md).

Gemini ToB S3 preserved a nine-test suite containing a paused-prize reproduction: after an NFT result, the prize pauses, sponsor proceeds release, and winner redemption reverts. It is concrete conditional mock evidence, not a deployed-collection result. AQ-009 limits the separate recipient test because `vm.prank` impersonates a contract that has no claim-originating method. AQ-009 also corrects present NatSpec/events reported absent, reduced-context repository inferences, the S5 denominator, and internal future-clone contradictions. See [post-seal reconciliation](reconciliation/finalization/GEMINI-TOB-04-RECONCILIATION.md).

## Public forks and adjacent packages

Maintained mainnet and Sepolia tests passed at blocks 26,242,794 and 11,964,220 with exact hashes retained. They exercised actual published quote/wrapper addresses, real USDC transfer behavior, positive wrapper fee, local request flow and unauthorized callback rejection using a mock prize and cheatcode-funded buyer. They did not execute genuine off-chain VRF fulfillment, bind a supplied live Raffle/Factory instance, prove current/future administration, or establish chain finality. See [public-fork validation](PUBLIC-FORK-VALIDATION.md).

Adjacent results include 22 Hardhat, 16 SDK, 25 web, 8 subgraph and 11 standalone Python tests, plus build/typecheck/codegen/ABI/local gas and size checks. The config-package command selected zero tests. Canonical ABI entry sets match with tuple/parameter order preserved, but top-level array order differs; this is not byte-for-byte array equality.

## Provider and assurance boundary

External workflow qualification is tracked in [provider validation](PROVIDER-HANDOFF-VALIDATION.md). Claude Simao's original refusal, Claude OpenKritt's original blocker, Claude ToB's coverage bounds/timeouts, Gemini native/transport errors, missing literal historical paths, modified adapters, and unknown provider-internal revisions remain visible. A completed external lane does not add line/branch coverage unless a separately cited campaign executed it.

Claude OpenKritt completed 193 logical lineages across 195 metadata attempts, retaining failed rows 21/22 with completed logical counterparts, and produced `0 / 0` native/canonical findings. Zero findings is not proof of absence. The independent OpenAI validator was provider-rejected and incomplete.

Pre-seal Claude OpenKritt status diagnostics exposed explanation prose to coordination readers. It was not adopted or fed back to the reviewer, but complete pre-seal narrative non-exposure is not claimed. Receipt integrity also retains exactly four historical OpenAI ToB hash mismatches: two grown logs with recovered exact sealed prefixes and two unrecovered S4 runtime bindings. These assurance limits do not change the frozen file counters or turn coverage into a finding.

## Evidence index

- [Foundry](runs/TOOL-RELEASE-EXTENDED/attempt-01/campaign-statistics-final.json)
- [Echidna](ECHIDNA-EXTENDED-RESULTS.json)
- [Halmos](runs/TOOL-HALMOS-CONTINUATION/CLOSURE.json)
- [Mutation](runs/TOOL-MUTATION-QUALITY/SUMMARY.md)
- [Source/dependency map](runs/SUP-S1/attempt-01/COVERAGE.md)
- [Scanner triage](reconciliation/scanner-triage.json)
- [Dependency review](reconciliation/DEPENDENCY-REVIEW.md)
- [Recipient validation](runs/TOOL-RECIPIENT-VALIDATION/attempt-01/stdout.txt)
- [Daybreak Simao post-seal proof](runs/DAYBREAK-SIMAO/attempt-03/POST-SEAL-PROOF.md)
- [RF-002 addendum](reconciliation/finalization/RF002-PROOF-SCOPE-ADDENDUM.md)
- [AQ-009 reconciliation](reconciliation/finalization/GEMINI-TOB-04-RECONCILIATION.md)

## Applicability of generic audit areas

| Area | Disposition in this architecture |
|---|---|
| Custom signed messages, EIP-712 domains, permit nonces | Not applicable to the five production files: no custom signature/permit verifier. Ordinary transaction nonces, external token approvals, and ERC-721 owner/operator authorization are separate concerns. |
| Upgrade/admin transitions | No mutable protocol upgrade/admin entry point in the candidate. Constructor configuration, implementation lock, clone initialization and fixed beneficiaries are in scope. External token/prize/wrapper administration remains an integration assumption. |
| AMM slippage, lending, leverage and flash liquidity | Not protocol mechanisms here. This is a fixed-price sale with a configured reserve branch. Secondary-market ordering remains an unresolved external lead. |
| Cross-chain messages/bridges | Not present. Chain-specific deployment identity and finality remain external. |
| Price-oracle freshness | No direct price feed. Trusted wrapper fee pricing/fallback and live configuration are external; VRF caller authentication, request binding and deadlines are applicable and tested separately. |
| Shares, interest and recurring rewards | Not present. The applicable ledger is quote-token micro-units, entry ranges, bearer tickets, and pending terminal liabilities. |

These are source-scope statements, not claims that excluded frontend, wallet, token, wrapper, marketplace, deployment, or chain code lacks those mechanisms.
