# raffle.fun smart-contract audit r001

**Status: FINALIZED WITH QUALIFICATIONS.** The audit matrix contains 23 target cells: 20 are qualified or complete, and three required OpenAI cells remain **INCOMPLETE / ACTUAL_PROVIDER_REJECTED**. Those three failures were not retried, rephrased, substituted or counted as completed reviews. This report is not release approval, external-auditor certification, owner risk acceptance or a claim of universal security.

Frozen target: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. The repository was clean at capture. The audit changed no frozen production source, performed no production remediation or deployment, and sent no live transaction. All evidence links below are relative to this audit package.

## Executive assessment

The reconciliation has exactly **two production root-cause families**:

1. **RF-001 — conditional High:** under the explicit DESIGN boundary that arbitrary prize contracts are untrusted, a sponsor-controlled or later nontransferable prize can defeat promised NFT delivery while the sponsor and protocol proceeds are independently payable. A Daybreak Trail of Bits report rates the chain Critical; that rating is preserved as dissent, not adopted as the controlling severity. The demonstrated behavior is High under the untrusted-prize scope and a trust/integration limitation under the narrower honest, continuously transferable ERC-721 assumption.
2. **RF-002 — Low:** destination screening can be bypassed by a sponsor-selected future same-factory clone address, and factory-local screening accepts an owner-selected existing other-factory clone. Executed local cases show the selector's own prize, quote claim or bearer ticket becoming stranded or unclaimable. They do not show arbitrary third-party theft, loss of buyer refund liabilities or a drain of another raffle's accounted funds.

The final register contains **21 mixed entries**—root families, observations, configuration risks, documentation issues, unresolved leads, closed candidates, evidence limits and advisory work—not 21 vulnerabilities. It separately preserves nine audit-assurance issues. Counts of reports, original IDs, functions, tests, model outputs or agreement are not security votes or proof.

Ordinary-path testing supplies substantial evidence for exact quote allocation, refund accounting, current-owner authorization, state transitions, authenticated callbacks and atomic rollback under the declared mocks and bounds. It does not remove RF-001, prove every external integration, turn no-counterexample campaigns into proofs, or establish live deployment identity. No unconditional Critical exploit, arbitrary-EOA theft or production quote-ledger insolvency was demonstrated.

Final reconciliation identifiers:

| Artifact | Final value |
|---|---|
| Source report paths / distinct sealed report hashes | `28` / `27` |
| Original attribution links | `739` |
| [Final register](reconciliation/findings-register-final.json) SHA-256 | `14fd10f03ae1ae1e503d04e8ff68d382319d42cced4552d12eab92b04f0f6242` |
| [Final reconciliation](reconciliation/FINAL-RECONCILIATION.md) SHA-256 | `b5b443439f827ce572d5ba57efde0f9d474211756b13aa3df798c58654e80c7b` |
| [Final reconciliation seal](reconciliation/FINAL-RECONCILIATION-SEAL.json) SHA-256 | `c5e388d04b64d71c22ada44b36c6f8e7b27a0bf37052cd6039845a9d5dd33186` |

## Frozen scope and architecture

Production scope is five Solidity files: `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol` and `libraries/RaffleConstants.sol`. The dependency boundary includes 31 exact reachable imported files, notably the actually compiled OpenZeppelin 5.6.1 and Chainlink Contracts 1.5.0 closure. The capture covers 435 tracked inputs, lockfiles, submodule/dependency revisions, build and deployment configuration, and a clean design description. See [scope](SCOPE.md), [scope inventory](scope-files.txt), [freeze manifest](freeze.json) and [dependency hashes](dependency-hashes.json).

The system uses immutable factory-created ERC-1167 raffle clones and transferable bearer tickets. Purchases create exact six-decimal quote-token liabilities. An authenticated VRF callback selects a global entry. Terminal settlement allocates 95% sponsor / 5% protocol for an NFT outcome, or 80% winner / 15% sponsor / 5% protocol for a cash outcome. Timed-out sales or drawings can move the unsettled pot into full ticket-refund liability. Fixed recipient claims are permissionlessly releasable but cannot be redirected by the caller.

Exact quote accounting assumes the configured canonical quote token transfers the requested amount without fee, rebasing or false-success semantics. ERC-165 responses, receiver callbacks and `ownerOf` are statements made by the selected NFT contract; they are not cryptographic proof of honest or permanently transferable prize semantics. No deployed Raffle or Factory instance was supplied, so deployed-bytecode comparison is not applicable to this candidate.

Normal Foundry profiles use Solidity `0.8.36+commit.8a079791`, Cancun, optimizer 200 and `viaIR=false`; the coverage and comparison profiles are separately identified. Seven Foundry profiles and two Hardhat profiles were captured. The initial guessed solc executable path failed; compiler-artifact provenance, rather than that failed probe, binds the successful compiler identity. See [toolchain](toolchain.json) and [compiler provenance](compiler-artifact-provenance.json).

Cold first-pass contexts excluded repository tests, historical audit findings, accepted-risk lists, scanner results and cross-review conclusions. Test-exposed, tool-assisted, historical and reconciliation work occurred only in separately declared later stages. Native harness tools remain part of their declared workflows and are not described as source-only review.

## Production root families

### RF-001 — Prize delivery can fail while NFT-outcome proceeds remain independently payable

**Severity:** High under the explicit untrusted-prize DESIGN scope. **Confidence:** high in reachability and accounting behavior; classification remains scope-dependent. **Dissent:** Daybreak ToB reports Critical; other preserved judgments include High, Medium and Low/integration risk.

A sponsor can select a prize implementation that fabricates receipt or ownership statements, or genuinely escrows a token and later pauses, seizes or refuses outgoing transfer. The factory accepts the callback and reported ownership, buyers fund the raffle, and the normal VRF path can resolve `NftWon`. Settlement then creates sponsor and protocol claims independently of successful prize delivery. A payout completed in an earlier transaction is not rolled back by a later failed redemption, and `NftWon` has no failed-delivery refund transition.

The required capability is control over the selected collection's semantics or transfer authority, or an equivalent post-escrow external collection failure. Quote-token, VRF and buyer-wallet compromise are not required. The impact is that a sponsor may receive 95% of gross sales while the winner lacks enforceable delivery of the promised NFT. Quote liabilities can remain exactly conserved, so this is a cross-asset economic guarantee failure rather than demonstrated quote insolvency. It does not exploit an honest ERC-721 that remains truthful and transferable, and it does not drain another clone.

Frozen anchors are `RaffleFactory.sol:127–134,171–177` and `Raffle.sol:309–337,375–391,416–430,533–555`; the scope conflict is between `DESIGN.md:2` and `IRaffle.sol:12–15`. The fabricated-semantics reproduction and execution log are retained in [the Daybreak Pashov proof directory](runs/DAYBREAK-PASHOV/attempt-01/proofs/). A later sealed paused-prize test executes settlement, sponsor payout and failed winner redemption in [Gemini ToB S3](runs/GEMINI-TOB-REPAIRED/attempt-04/S3/pre-validation-capture/artifacts/scratch/contracts-orig/test/foundry/TokenIntegrationProperties.t.sol). These mocks demonstrate mechanisms; they do not certify any named deployed collection.

The controlling High rating follows the explicit untrusted-prize boundary and the sponsor-retains-sales impact. The Critical uplift is not adopted because uncapped gross volume alone does not establish system-wide compromise, the sponsor/prize capability and buyer participation remain material preconditions, and no other raffle or arbitrary victim balance is drained. The dissent remains in the final register; agreement is not used as evidence.

Remediation must begin with a product decision: either state and enforce a trusted-collection model, including upgrade/pause/seizure authority, or define a funded failed-delivery exit. An allowlist narrows exposure but does not itself prevent later administrative action. `ownerOf` cannot authenticate a dishonest token. Any payout gate or fallback must cover sponsor and protocol buckets, unsettled and settled `NftWon`, winner non-redemption, already paid claims and exact conservation. No model-proposed patch is approved.

### RF-002 — Temporal and factory-local destination checks permit self-selected clone sinks

**Severity:** Low. **Confidence:** high for the executed local cases; practical relevance remains limited by self-selection.

The root has three separately scoped, executed variants:

- A sponsor sets raffle A's immutable recipient to the predictable address of a future same-factory raffle B. The address has no code and is not registered at validation time. After B is deployed, A can transfer an honest ERC-721 sponsor prize into B, which has no arbitrary exit for that asset.
- In the same future-recipient setup, runtime quote screening rejects A's sponsor-proceeds release once B is registered. The transaction reverts atomically, the sponsor's immutable claim remains backed but unavailable, and an unrelated protocol-fee release still succeeds.
- A ticket owner or authorized sender selects an already deployed clone belonging to another factory. The local registry omits it, so the ticket transfer succeeds. The receiving clone has no general method to originate the ticket owner's redemption or transfer the foreign ticket back. This case needs no future-address prediction.

The first two are sponsor-selected same-factory own-recipient failures. The third is an owner-selected existing other-factory bearer-claim loss. None demonstrates an attacker choosing an unrelated victim's recipient, theft from an EOA, or loss of buyer refund liability. The proof scope and sealed logs are listed in the [RF-002 proof-scope addendum](reconciliation/finalization/RF002-PROOF-SCOPE-ADDENDUM.md).

Frozen anchors are `RaffleFactory.sol:105–134,163–169` and `Raffle.sol:395–406,564–605`. The original honest-token future-clone reproduction is [RecipientValidation.t.sol](reconciliation/recipient-validation/RecipientValidation.t.sol). Claude S6 executes the quote-lock case in [RaffleScenarios.t.sol](provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02/generated-capture/harness-props/props/foundry/RaffleScenarios.t.sol); Daybreak S6 executes the existing other-factory ticket case in [S6SecureWorkflow.t.sol](runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tests/sources/S6SecureWorkflow.t.sol).

If global clone isolation is a required invariant, apply a consistent runtime destination policy across quote, prize and ticket paths. A refusal check can stop new movement but cannot recover an immutable claim already aimed at an unusable recipient. Any recovery or recipient-rotation design must prove rightful authority and must not capture another party's future-address claim. Changing CREATE mechanics alone is not a complete recovery policy.

## Other register entries

The following 19 entries plus RF-001 and RF-002 make the register's 21 mixed entries. They are not 19 additional confirmed vulnerabilities.

| IDs | Final classification and conclusion |
|---|---|
| OBS-001, OBS-002 | Dependency/recipient availability: issuer-side quote freezes can block all exits; an unusable fixed sponsor or treasury recipient can lose its own payout availability. Liabilities can remain preserved. Earlier Medium ratings remain attribution, not controlling severity. |
| OBS-003 | Unsupported quote semantics: transfer fees, rebasing or false-success behavior break exact nominal accounting. Deployment must bind the supported canonical token identity. |
| OBS-004 | ERC-721 receiver acceptance or address-level ownership does not prove that a contract can later originate an owner-only claim or transfer. This includes counterfactual and otherwise incapable recipients. |
| OBS-005 | Unsolicited token donations are outside recorded liabilities and have no rescue path. Extra custody is not claimant-ledger insolvency. |
| DOC-001 | Broad refund prose omits the sponsor's limited ability to close an empty raffle early. No paid entrant exists in that branch. |
| LEAD-001 | Pending VRF disclosure may disadvantage standing secondary-market orders, but no real marketplace ordering exploit or randomness manipulation was established. |
| OBS-006 | A funded prize callback can buy an entry after clone activation but before `RaffleCreated`; failure of final escrow checks still rolls back the whole transaction. This is a phase/event integration observation, not a free purchase. |
| CONFIG-001 | A treasury equal to the future clone at the current factory nonce can make initialization revert and permanently block creation at that nonce. It is deployer-controlled self-lock, not a drain of existing raffles. |
| OBS-007 | Generic ticket metadata does not authenticate a canonical clone or current claim value. Integrators need chain, factory, clone, owner, range and outcome context. |
| LEAD-002 | A reorganization may rebind an unconfirmed CREATE-derived address before a client purchase; the required live chain/client sequence was not demonstrated. |
| CONFIG-002, OBS-008 | An unreachable reserve intentionally forces the cash branch. Draw completion depends on somebody paying the native VRF fee, but functioning dependencies leave a bounded refund route. |
| CLOSED-001, CLOSED-002 | Modulo bias is negligible at the stated bounds; sponsor participation, reserve crossing and single-buyer economics follow the configured open-sale rules. |
| CLOSED-003, CLOSED-004 | `uint64` timestamp wrap is impractical on intended chains. A valid paid purchase legitimately removes the empty-sale cancellation condition. |
| EVIDENCE-001 | Pinned public-fork request paths were verified, but live candidate identity and genuine off-chain VRF fulfillment remain unverified. |
| ADVISORY-001 | Documentation, gas, process, monitoring and style recommendations are work items without security severity. |

Every original ID, severity, source line, actor capability, disagreement and disposition is retained in the [final register](reconciliation/findings-register-final.json). Historical acceptance language is not current owner acceptance.

## Assurance issues

These nine issues qualify how much confidence the campaigns support. They are not frozen production defects.

| ID | Assurance conclusion |
|---|---|
| AQ-001 | Swallowed reverts and no-op paths can leave economic actions inactive while invariants still pass. A purchase-always-reverts mutant survived the strict invariant campaign. |
| AQ-002 | Handlers that select the real ticket owner do not exercise adversarial callers and can miss removal of an owner check. |
| AQ-003 | Deadline prefilters omit forbidden exact boundaries and can hide inclusive-boundary mutations. |
| AQ-004 | Independent allocation checks are valuable, but short-run branch reachability is weak and some ghost values follow implementation state. |
| AQ-005 | The standalone Python model fails to roll back lazy settlement after a rejected unauthorized redemption. Solidity rolls back; passing Python tests are not equivalence proof. |
| AQ-006 | Eleven of 52 historical mutant definitions do not apply to this revision. They are stale definitions, not surviving current mutants, and must not inflate a score. |
| AQ-007 | Partial/rejected workflows, absent transient inputs and unknown returned model fields must not become false completion or coverage claims. Deliberate clean-context exclusions do not prove repository-wide absence. |
| AQ-008 | The proposed “Option C” delivery fallback moves zero terminal balances when `NftWon` is still unsettled, leaving the pot outside its proposed refund liability. It is a flawed uncompiled suggestion, not production code or an approved fix. |
| AQ-009 | Sealed model claims and caller reachability required append-only correction: Gemini ToB asserted missing NatSpec that exists, contradicted source on callback/event details, inferred repository absence from reduced context, used `vm.prank` as if a contract with no callable claim method could originate a transaction, misstated S5's denominator (`219` extracted / `10` checked / `209` unchecked), and conflicted with its own future-clone description. The original text remains sealed; corrections control reconciliation. |

The four-mutant quality campaign changed fee allocation, removed an owner check, made a deadline inclusive and disabled purchases in disposable copies. Unit/fuzz/security tests killed all four. Short invariant runs initially killed none; a larger run killed the fee mutant, while disabled purchases still passed due to caught failures. This is why action success, expected failures and no-ops must be reported separately. See [mutation summary](runs/TOOL-MUTATION-QUALITY/SUMMARY.md).

## Model and harness matrix

“Qualified” means the evidence is usable under its disclosed method and provenance limits. It does not rename a native ERROR to SUCCESS, erase an earlier refusal, prove every finding, or imply complete function depth.

| Method | OpenAI Astra | Claude Opus 5.5 | Gemini Argon High | Additional Daybreak Blue |
|---|---|---|---|---|
| 0xSimao | **INCOMPLETE — ACTUAL_PROVIDER_REJECTED** | **QUALIFIED modified method**; original reasoning-extraction refusal preserved | **QUALIFIED repaired method**; native SUCCESS, leaf 03/04 ERROR retained | **COMPLETE** |
| Pashov | **INCOMPLETE — ACTUAL_PROVIDER_REJECTED** | **COMPLETE / QUALIFIED** native specialist, judge and assembler chain | **QUALIFIED method output**; native and two same-conversation continuation ERRORs retained | **COMPLETE** |
| OpenKritt | **COMPLETE / QUALIFIED** native modified method; 0 records | **QUALIFIED modified method**; final values below | **COMPLETE / QUALIFIED** modified method; 0 records | **COMPLETE / QUALIFIED**; 4 records, 3 distinct candidates |
| Trail of Bits | **INCOMPLETE — ACTUAL_PROVIDER_REJECTED** | **QUALIFIED** six declared stages; bounded gaps retained | **COMPLETE / QUALIFIED** six declared stages with AQ-009 corrections | **QUALIFIED** six declared stages; Critical dissent and seal-version gap retained |
| Gebal | **COMPLETE / QUALIFIED** | **COMPLETE / QUALIFIED** | **COMPLETE / QUALIFIED** corrected cold review | **COMPLETE / QUALIFIED** |

Supplementary reviews `SUP-A1` (accounting/custody/economics, Astra ultra), `SUP-A2` (authority/lifecycle/composition, Astra ultra) and `SUP-S1` (whole-system, GPT-6.1 Sol) are all complete and sealed. Thus the 23-cell ledger is **12/15 required harness cells qualified or complete, 5/5 additional Daybreak cells qualified or complete, 3/3 supplementary reviews complete, and 3/15 required harness cells provider-rejected**.

The fresh Daybreak coordinator that performed late semantic qualification and final delivery coordination is **outside these 23 cells**. The earlier OpenAI root/orchestration rejection, the rejected OpenKritt `supp_whole` validator and the separately rejected counterfactual-recipient `supp_authority` validator are also outside the 23-cell denominator. Neither rejected validator was retried or replaced; the earlier honest-NFT recipient reproduction retains its independent local-test provenance.

The coordinator requested and locally accepted `gpt-daybreak-blue-latest` with `daybreak_blue` access and `ultra` effort, with no fallback; the provider-returned underlying identity remains unknown. This records use of the supported access route, not a claim that the application's existing root model changed. This coordinator received no OpenAI safety rejection. One auxiliary subagent route returned a 403 availability error (“Daybreak isn't available for this model”); it was preserved separately, not treated as a safety refusal, and was not retried or silently substituted. See [route evidence](runs/COORDINATOR-DAYBREAK/attempt-01/ROUTE-EVIDENCE.json) and the [auxiliary route error](runs/COORDINATOR-DAYBREAK/attempt-01/AUXILIARY-SUBAGENT-ROUTE-ERROR.json).

### Routing and method qualifications

- OpenAI source lanes requested and locally selected `gpt-6-astra` at `ultra`, with automatic fallback disabled. Provider-returned identity fields are absent and remain unknown. Simao, seven Pashov specialist routes and the ToB continuation received actual OpenAI cybersecurity-risk rejection. No substitute is counted. The earlier OpenAI ToB source material remains limited evidence; unfinished continuation content was not adopted.
- Daybreak cells selected `gpt-daybreak-blue-latest` at `ultra` under the named access program, with no fallback. The underlying provider-returned identity is unknown and is not inferred from the alias.
- Claude streams corroborate `claude-opus-5-5`; argv requested `max`, but server-applied effort was not echoed. Claude Simao's original private-reasoning protocol was refused. The separately named PUBLIC-EVIDENCE variant used twelve foreground Opus/max lenses plus native judgment/proof with concise public evidence; the refusal remains historical and incomplete. Claude ToB's original S6 timeout remains preserved: S1 deeply analyzed 12 selected functions and listed 9 not deeply analyzed; S5 checked its native default 10 of 248 requirements and deferred 238; the six selected skills are not the full ToB catalog.
- The Claude OpenKritt cell is a distinct modified-controller method because the unmodified route was blocked by the bundled runner/version gate. Its pinned engine, method patch, lockfile drift, source identity, database/export capture, configured workflow and missing auto-removed stdout are disclosed rather than represented as stock OpenKritt.
- Corrected Gemini routes used the official Antigravity CLI 1.4.4 selection `gemini-4-argon-high` with `high`; client initialization corroborates selection, while the provider-internal revision and applied server effort remain unknown. Original contradictory handoffs, limited dependency contexts, inherited-child uncertainty and unsupported probes remain separate limited evidence.
- Gemini Simao's native SUCCESS does not erase historical leaf 03/04 ERROR. Fourteen vanished literal input paths remain absent, but exact preserved per-leaf byte equivalents were independently hash-verified. Gemini Pashov's native stream and both same-conversation continuations remain ERROR/failed; the method output is qualified through append-only Daybreak adjudication, with 13 exact effective input copies verified, literal paths still absent and the request-5 preimage chronology retained. No native ERROR is relabeled SUCCESS.
- Gemini ToB completed the six declared stages, not the full catalog. S1 analyzed 12 selected functions and left 9 not analyzed; S5 checked 10 of 219 extracted requirements and left 209 unchecked. Same-UUID terminal reports and historical network ERRORs coexist; AQ-009 controls corrected claims. Optional Manticore was unavailable, and tool-assisted stages are not source-only.
- Gebal cold exports/imports remain bound to their own context hashes. The Docker deterministic path is a separately disclosed compatibility method with patches and failed attempts retained; it is not retroactively imported as a cold model review. Local ToB host primitives likewise use disclosed adapters.

### OpenKritt candidate and validation boundary

OpenAI/Astra and Gemini native OpenKritt runs produced zero candidate records. Zero candidates means no eligible ranker/postprocessor work for those runs and is not proof of absence. Daybreak produced four records: paused-prize/payout, future clone, forged escrow and a duplicate forged-escrow record; they reconcile into RF-001/RF-002 and no new root.

Claude OpenKritt final values:

| Field | Final value |
|---|---|
| Completed logical lineages / metadata attempts | `193` / `195` |
| Native finding records / canonical findings | `0` / `0` |
| New production root families | `0` |
| Completion receipt SHA-256 | `52b75bba1bb78ce25514b950a102364409e69ca19204e420dadfa773b23cfebe` |
| Raw-first-pass seal SHA-256 | `d13dd715c36102d61818d67598d92510665237ee1acf8f838026c131b6d31417` |
| Final method seal SHA-256 | `bbab1ac2c461fca324aa50c7c142a402293000fa47ecf79607cd831f569ab8a1` |

The separate OpenAI `supp_whole` validator was rejected after partial work and was not retried. A separate `supp_authority` follow-up for counterfactual-recipient validation was also actually OpenAI-rejected and not retried; the earlier honest-NFT local reproduction remains retained. Both follow-up rejections are outside the 23-cell denominator and are listed in [the provider-rejection record](PROVIDER-REJECTIONS.md). Therefore native OpenKritt completion is not represented as independent validation of every candidate or of a zero-result conclusion.

## Executed tool evidence

### Core and integration campaigns

| Campaign | Retained result and controlling limit |
|---|---|
| Foundry release | 79 passed, 0 failed, 1 historical unconfigured RPC-fork skip. Nine fuzz tests ran 100,000 cases each. Nine invariants reported 233,698,304 total native calls; handler attempts are not all successful economic actions. The longer run took about 3,854 seconds, and the earlier timeout remains preserved. |
| Echidna core | Two extended 100,000-target campaigns completed at 100,040 and 100,077 actual calls, six properties each, sequence length 100, one worker, seeds `2026102101` and `2026102102`. Native rejected-input and revert counts are unknown. Earlier 180-second incomplete attempts and 3,000-target campaigns remain separate. |
| Medusa core | A bounded 100,000-target campaign completed 26 native checks, including six actual properties. Assertion/function checks are not 20 additional independent invariants. No exact scheduling-seed replay is claimed. |
| Halmos core | Original refund/cash/NFT properties passed on the declared real-factory/clone domains. Stronger success wrappers prevented silent ordinary-revert satisfaction. Eleven residual SMT obligations were discharged UNSAT through the unchanged arithmetic refinement and alternative solvers; original TIMEOUT statuses remain preserved. Larger amounts, actors, transfers, callback words, payout orderings and hostile tokens are outside the proof domains. |
| Slither and Aderyn | Complete scans produced 23 source-triaged observations in total; no scanner-only exploit was established. Slither's finding-gate exit 255 is not analyzer failure. Gebal's separate Slither run adds 22 mock observations and repeats the same 12 production observations. |
| Mutation | Four valid disposable mutants compiled and were killed by unit/fuzz/security tests, but all survived short invariants and the purchase-disabled mutant exposed vacuity. Eleven historical definitions are stale for this revision. |
| Public forks | Maintained mainnet and Sepolia tests passed at blocks 26242794 and 11964220 with exact block hashes retained. Real USDC transfer behavior, positive wrapper fee, local wrapper request and unauthorized callback rejection were exercised with mock prize and cheatcode-funded buyers; no genuine off-chain fulfillment occurred. |
| Build and adjacent packages | Seven Foundry and two Hardhat profiles compiled. Adjacent tests include 22 Hardhat, 16 SDK, 25 web, 8 subgraph and 11 standalone Python tests. Format, lint, typecheck, codegen, ABI and local gas/size checks completed after recorded setup repairs. The config-package command selected zero tests. |

Exact commands, versions, exit codes, durations, seeds, bounds, retries and raw output are in the [cumulative tool ledger](tool-campaign-results-final.json), [tool summary](TOOL-CAMPAIGN-SUMMARY.md), [extended Echidna result](ECHIDNA-EXTENDED-RESULTS.json) and [Halmos closure](runs/TOOL-HALMOS-CONTINUATION/CLOSURE.json).

### Late declared-workflow campaigns

Claude ToB S6 retained 20/20 passing Foundry tests across six suites, including two 2,000-run fuzz tests; a 400,073-call Echidna property campaign with nine properties (seed `6206211`); a 400,047-call assertion campaign with 38 checks (seed `9917731`); and a 3,116,102-call Medusa campaign with 46 passes and four workers. Custom Slither structural checks passed 12 predicates. Halmos passed seven checks and timed out on two—refund conservation and full symbolic split exactness—even after recorded Z3 and bounded follow-ups. Those timeouts remain unknown, not passes or counterexamples. See [Claude S6 preserved evidence](provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02/preserved/evidence/04-properties/).

Daybreak ToB S6 retained 21/21 unit/fuzz tests, including two 10,000-case fuzz properties. Three Foundry invariants ran 256 runs × 128 calls each, 98,304 reported calls total, but only a single actor buying in one active raffle was in that invariant domain. Echidna ran four purchase-only properties for 20,007 calls at sequence length 64 and seed `1396142931`; it becomes a no-op after at most 64 successful buys. Two intentional negative Foundry properties produced the expected counterexamples for global clone isolation and self-reported prize custody. Slither returned 14 results, no High/Medium findings; exit 255 is its finding gate. No formal proof was performed in this late Daybreak stage. See [Daybreak S6 property ledger](runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SECURITY_PROPERTIES.md).

These late campaigns add bounded corroboration and explicit counterexamples. Their property counts, call counts and passing tests are not independent model votes or universal proofs.

## File and property coverage

| Production file | Source review | Instrumented execution |
|---|---|---|
| `Raffle.sol` | Every production function and exposed inherited mutation surface mapped | 246/247 lines; 31/31 functions; 52/58 branches |
| `RaffleFactory.sol` | Constructor, all production functions, clone creation and registries/getters mapped | 61/61 lines; 4/4 functions; 17/18 branches |
| `interfaces/IRaffle.sol` | Types, events, errors, signatures, getters and declared assumptions mapped | No meaningful executable denominator |
| `interfaces/IRaffleFactory.sol` | All declarations and deployment assumptions mapped | No meaningful executable denominator |
| `libraries/RaffleConstants.sol` | Economic, deadline, batch, callback and unit constants mapped | No meaningful executable denominator |

The [per-file/property map](PER-FILE-PROPERTY-COVERAGE.md) links custody, allocation, range partition, authorization, initialization, deadlines, prize delivery, economic delivery, recipient isolation, VRF behavior, rollback, gas bounds, handler quality, integration, reference mathematics and dependency provenance. Reading all 31 reachable dependency files is not a complete audit of every unused package API.

Instrumented coverage does not establish assertion quality or deployed identity. Default/CI/audit/strict/release template outputs match; coverage and comparison implementations differ while ABIs match. Unoptimized coverage bytecode exceeds EIP-170, while optimized production runtime is 15,947 bytes for Raffle and 3,949 bytes for Factory. Runtime immutables prevent treating a template hash as an instance hash.

## Dependencies, SDK and deployment limits

The dependency scan contains 85 advisory records, 69 distinct GHSA IDs and 1,074 dependency-path occurrences. These are scanner counts, not production exploit counts. Flagged older transitive OpenZeppelin modules are absent from the actual compiled 5.6.1 closure; that fact does not certify every package or deployed dependency. See the [dependency review](reconciliation/DEPENDENCY-REVIEW.md).

DEP-01 is a controlled, unit-level Next image-optimizer DNS-check/socket mismatch. It does not demonstrate the deployed HTTPS route, DNS timing, hosting configuration or practical SSRF; the reviewed NFT image UI uses unoptimized images. DEP-02/03 remain conditional image-decoder and platform/feature risks. DEP-04 concerns Graph CLI developer archive traversal, and DEP-07 preserves remaining tooling-input paths. DEP-05 explains non-applicability of older OpenZeppelin advisories. DEP-06 is a provenance gap: 1,286 registry signatures verified, but an unpublished era-contracts npm packument cannot attest the pinned Git-sourced dependency. No tampering conclusion or automatic upgrade is inferred.

Canonical ABI comparison succeeded: all 125 Raffle and 26 Factory entries match compiler ABIs as canonical entry sets with tuple and parameter order preserved. Top-level array ordering differs, so this is not byte-for-byte array identity. See [ABI equality](sdk-abi-equality-final.json). SDK, web and subgraph tests do not establish a complete live wallet/browser/indexer/chain lifecycle.

Pinned public forks corroborate documented quote/wrapper address selection and local request compatibility, but they do not provide a live Raffle/Factory candidate, authentic off-chain VRF delivery, administrator guarantees, finality proof or every dependency-failure behavior. Halmos is the supported executed symbolic verifier; no successful separate Certora or SMTChecker result is claimed.

## Historical comparison

The two mechanisms are not presented as newly discovered. The sealed comparison maps 49 numbered historical IDs through 62 mappings from ten frozen documents. V12 IDs 243747/243754 discuss fabricated or unavailable prizes and independent payouts; 243748/243749/243759 discuss future-clone stranding; 243750 discusses the treasury/nonce creation collision. Those records apply to the older `3da958f` revision and preserve their original Invalid/conditional dispositions. R001 classifications rely on current `9238b6c` source and current proofs. See [historical comparison](reconciliation/HISTORICAL-COMPARISON.md).

Older H-03/H-04 material described a recovery helper on another architecture. That helper was removed because future-address recovery could capture another party's claim. It must not be revived as an obvious fix. The August 25 follow-up also declined to carry a historical 52/52 mutation score onto the changed nominal-USDC source. Historical risk acceptance is not current owner acceptance.

## Independence, exposure and evidence integrity

Sealed cold first passes remain independent of peer conclusions and post-seal tool findings. Cross-review reconciliation, historical comparison and test-exposed continuations are explicitly later work. Source receipt validity proves bytes and provenance; it does not by itself prove native workflow completion, model identity, source coverage or finding truth.

### Claude OpenKritt pre-seal narrative exposure

Before the Claude modified OpenKritt raw first-pass seal, whole status-API diagnostics unexpectedly included `recentEmptyResults` explanation prose. The Daybreak coordinator, parent administrative bridge and reconciliation/accounting owner saw that narrative while diagnosing lifecycle status. It was **not assessed or adopted as finding evidence, not fed back into the native reviewer, and did not change native inputs, the scan/database or earlier sealed reviews**. Subsequent polling was restricted to scalar lifecycle/counter fields. The raw terminal API, database dump, native export response, errors and available logs were sealed before final semantic adoption.

Accordingly, this report makes no absolute claim that those coordination readers remained narratively unexposed until the final seal. Native reviewer independence remains intact because the text was not supplied to the reviewer. The exact boundary is preserved in [the exposure notice](provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01/PRE-SEAL-STATUS-EXPOSURE.json), [accounting notice](reconciliation/finalization/ACCIDENTAL-STATUS-ENDPOINT-EXPOSURE.json) and [parent addendum](reconciliation/finalization/PARENT-STATUS-EXPOSURE-ADDENDUM.json).

### Four retained receipt-integrity mismatches

The final recursive receipt verifier must retain its original `ok=false` with exactly four qualified historical mismatches tied to OpenAI ToB attempt 01:

1. `runs/OPENAI-TOB/attempt-01/events.jsonl` grew after its original seal. An exact prefix at the sealed byte length matches the old hash and is preserved.
2. `runs/OPENAI-TOB/attempt-01/stderr.txt` likewise grew; its exact sealed prefix is preserved.
3. The old S4 runtime `STATUS.json` no longer matches the hash recorded by `artifacts/source-only/stage-seals.json`; no exact original-byte copy was found.
4. The old S4 runtime `raw/001-resources.json` likewise no longer matches its recorded hash; no exact original-byte copy was found.

The old files, old seals, current bytes, recovered prefixes and failure records remain unchanged. Byte-prefix recovery does not explain why logs grew or qualify workflow completion. The two unrecovered runtime bindings remain explicit. See [raw-log diagnostic](reconciliation/finalization/OPENAI-TOB-01-RAW-LOG-BINDING-DIAGNOSTIC.json), [S4 binding diagnostic](reconciliation/finalization/OPENAI-TOB-01-S4-RUNTIME-BINDING-DIAGNOSTIC.json) and [final recursive verifier](reconciliation/FINAL-RECEIPT-INTEGRITY.json).

These evidence-history mismatches do not indicate a frozen production-source mismatch. Removed Gemini transient input paths are separately qualified through exact preserved per-leaf byte copies; literal-path absence is not rewritten as original-path presence.

## Remediation and targeted re-audit

1. **Resolve RF-001's trust model.** Decide whether arbitrary prize implementations are supported. If not, bind allowed implementation and administrative semantics. If a delivery fallback is required, model every pre/post-settlement liability, both fee legs, winner non-redemption, prior payouts and exact conservation. Re-test fabricated callback/`ownerOf`, post-escrow pause/seizure, permanent refusal, successful delivery and every payout/refund ordering.
2. **Define destination and recipient capability policy.** Re-run the same-factory future-prize and quote-lock cases, the existing other-factory ticket case, treasury/nonce collision, own/foreign protocol sinks and actual callable contract-recipient paths. Prove that unrelated beneficiaries and raffles cannot be captured by any recovery design.
3. **Strengthen property assurance.** Record successful actions, expected failures and no-ops; use adversarial callers and exact deadline boundaries; repair the Python rollback model; replace stale mutants; and require intended properties to kill all valid mutants at declared bounds. Re-run the two unresolved late Claude Halmos obligations or report them unknown. Do not apply Option C.
4. **Validate the intended deployment.** Bind constructor arguments, candidate/source/compiler/deployed bytecode, canonical quote and wrapper addresses, fee/callback settings, deployment nonce and administrator assumptions. Exercise genuine intended marketplace/client ordering, claim-aware indexing and a real VRF lifecycle where authorized.
5. **Review dependency changes in isolated candidates.** Preserve locked provenance, route-specific regression tests, decoder/hosting configuration and tooling-input boundaries. Do not infer safety from advisory counts or update packages automatically.

No remediation or owner acceptance was authorized. Any approved fix must be a new frozen revision with an exact diff, configuration capture, regression/property suite and targeted re-audit. Preserve original reports, failures, dissent, rejections and historical comparisons append-only.

## Final freeze and delivery qualification

The final coordinator freeze verification matched all 435 frozen tracked inputs, all 31 reachable dependency files and all five production files with zero source errors. Completed attempts retain their before/after input checks. The promoted report set is then bound by a separate pre-exit read-only verification receipt:

The final read-only commands were `python3 verify-freeze.py` and `python3 verify-delivery.py --require-terminal`; both exited zero. The receipt below binds the promoted documents, final reconciliation, matrix and writer-shutdown evidence by SHA-256.

| Check | Final value |
|---|---|
| `verify-freeze.py` result | **PASS** — 435 tracked inputs, 31 reachable dependency files, 5 production files, 0 errors |
| [Pre-exit read-only verification](runs/COORDINATOR-DAYBREAK/attempt-01/PRE-EXIT-READ-ONLY-VERIFICATION.json) | Generated after report promotion so it can bind the report without a self-hash cycle |
| Matrix result | `23 target cells = 20 qualified/complete + 3 actual OpenAI provider-rejected` |
| Pending eligible source receipts | `0` |
| Pending semantic/post-source gates | `0` |
| Known receipt-integrity mismatches | `4`, retained and qualified above |

The complete audit trail includes [rerun instructions](RERUN.md), reusable [Claude](prompts/claude-overnight.md) and [Gemini](prompts/gemini-overnight.md) coordinator handoffs, [retry history](RETRIES.md), [provider validation](PROVIDER-HANDOFF-VALIDATION.md), [matrix](matrix.json), [coverage map](PER-FILE-PROPERTY-COVERAGE.md), [final reconciliation](reconciliation/FINAL-RECONCILIATION.md) and [final receipt registry](reconciliation/FINAL-RECEIPT-REGISTRY.json). Handoff prompts are reproduction instructions, not evidence of fresh runs; actual selected-attempt prompts and commands remain captured in their provider-lane directories. Re-execution must use fresh mutable directories and leave frozen source and sealed artifacts untouched.

The parent may create the whole-package delivery manifest and seal only after the Daybreak coordinator and audit-owned writers exit. That mechanical package seal is not a new security judgment and does not change the two-root reconciliation, three provider-rejected matrix cells, preserved dissent or explicit evidence limitations.
