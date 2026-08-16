# Current-Commit Findings

**Reviewed source:** `5772e54ba89c06646815ed52a881cd8940f094ca`. These are internal campaign findings, not an independent audit. No production Solidity was changed.

## Severity summary

| Severity      |                          Open | Fixed in campaign |           Accepted/external |
| ------------- | ----------------------------: | ----------------: | --------------------------: |
| Critical      |                             0 |                 0 |                           0 |
| High          |          0 production defects |                 0 | 1 external trust assumption |
| Medium        |          0 production defects |    3 test defects |    1 composition limitation |
| Low           | 3 off-chain/test/release gaps |                 3 |                 1 size risk |
| Informational |  1 documentation/release item |                 0 |                           0 |

Passing tests do not establish that no undiscovered Critical or High defect exists.

---

ID: CURRENT-EXT-01  
Title: Entropy provider can selectively withhold an unfavorable reveal  
Severity: High  
Confidence: High  
Status: Unresolved external trust assumption  
Category: Randomness / economic fairness  
Affected contracts: `Raffle` and the configured Pyth Entropy provider  
Violated invariant: The draw source should not be able to choose between resolution and a full-refund timeout after learning the result.  
Attacker prerequisites: Control/collusion with the configured provider, advance result knowledge, ability to omit or censor reveal, and economic exposure to tickets/sponsor outcome.  
Impact: A ticket-owning provider obtains an abort option. In the simplified model its advantage over always revealing is `fG(1-f)`, maximized at `G/4` for 50% ticket ownership. Sponsor/provider coalition payoff depends on NFT value and prize recovery.  
Minimal trace: Own fraction `f`; request resolves internally to a losing ticket; withhold callback; after two days call or permit `enableRefunds`; recover ticket costs. Reveal favorable results.  
Root cause: Authenticated randomness does not imply provider liveness or freedom from outcome-dependent withholding. The timeout necessarily supplies a fallback.  
Regression test: `test_current_protocol_model.py` selective-reveal calculation plus Entropy timeout/callback race tests. Tests model but cannot remediate the trust capability.  
Patch: No small local patch. See threat-model recommendations for provider pinning/monitoring, composed entropy, alternative RNG, independent sources, or bonds/slashing.  
Residual risk: Remains until the randomness trust model changes or is explicitly accepted and disclosed.

---

ID: CURRENT-COMP-01  
Title: Cross-Factory nested raffle-ticket prize can become permanently stranded  
Severity: Medium  
Confidence: High  
Status: Accepted limitation pending owner-facing policy  
Category: Asset composition / bearer capability  
Affected contracts: Two `RaffleFactory` instances and their Raffles  
Violated invariant: No supported prize should enter a state from which neither winner delivery nor sponsor recovery can move it. Buyer quote solvency is not violated.  
Attacker prerequisites: Sponsor owns an inner Raffle ticket, uses it as a prize in a Raffle from another Factory, and the inner lifecycle later locks that ticket as Drawing/winner.  
Impact: Outer NFT delivery and later recovery can both fail. Outer buyers still receive full per-ticket refunds after the NFT-delivery timeout, but the nested ticket/prize may remain in outer escrow indefinitely.  
Minimal trace: Create inner ticket; create outer raffle in another Factory using it as prize; sell/resolve outer to `NftWon`; request/resolve inner so the escrowed ID is locked; outer redemption fails; after 30 days outer refunds succeed; recovery remains blocked.  
Root cause: A standards-compliant ERC-721 may impose later transfer locks unknown to the receiving Factory. Registry destination checks cover only the same Factory.  
Regression test: `RaffleExtremeTest.testCrossFactoryNestedPrizeCanLockWhileOuterBuyersStillRecoverQuote` (campaign-added deterministic test).  
Patch: Small policy option: document raffle-ticket prizes as unsupported. Stronger rejection would require a cross-Factory registry/asset policy and cannot identify every dynamic-transfer ERC-721.  
Residual risk: Any upgradeable/freezable prize can create a similar custody failure; perfect capability detection is impossible.

---

ID: CURRENT-TEST-01  
Title: Ordinary invariant campaign targeted a setup-only action that always reverted  
Severity: Medium (test quality; no production impact shown)  
Confidence: High  
Status: Fixed in campaign  
Category: Test defect / vacuity  
Affected contracts: `RaffleHandler` and `RaffleInvariantTest` test contracts  
Violated invariant: Every targeted invariant action must be intentionally reachable; hidden handler reverts must not be counted as useful exploration.  
Attacker prerequisites: None; test configuration defect.  
Impact: Baseline ordinary invariants recorded 17,263 `configure` calls and 17,263 reverts with `fail_on_revert=false`, wasting exploration and obscuring action-quality review.  
Minimal trace: Target handler contract; after setup call `configure(address)` once; it reverts `AlreadyConfigured`.  
Root cause: `targetContract(handler)` implicitly included `configure`. Normal invariant configuration tolerated reverts and there was no reachability meta-property.  
Regression test: Instrumented red run failed `assertion failed: 1 != 0` and shrank to one configure call. Final `invariantEverySelectedActionIsReachableAndConfigureIsExcluded` asserts zero configure attempts.  
Patch: Use an explicit 14-selector target set; retain action counts and zero-attempt assertion.  
Residual risk: Other handlers depend on manual call-table review; durable per-action count assertions are not universal.

---

ID: CURRENT-SDK-01  
Title: SDK purchase builder did not reject malformed quantity before RPC use  
Severity: Low  
Confidence: High  
Status: Fixed in campaign  
Category: Off-chain correctness / transaction preflight  
Affected contracts: None; `@raffle-fun/sdk` actions  
Violated invariant: A write builder should reject purchase quantities outside the on-chain 1–100 bound locally.  
Attacker prerequisites: Caller supplies 0 or 101.  
Impact: The transaction would ultimately revert during simulation/on-chain, but callers incurred avoidable RPC work and received later/less precise feedback.  
Minimal trace: Call purchase action with quantity 0 or 101.  
Root cause: The action delegated bound validation entirely to simulation.  
Regression test: `actions.test.ts` accepts 1/100 and rejects 0/101; it was first run red with `validatePurchaseQuantity is not a function`.  
Patch: Add/export `validatePurchaseQuantity` and call it before reading/simulating.  
Residual risk: On-chain validation remains authoritative; current state can change between simulation and inclusion.

---

ID: CURRENT-TEST-02  
Title: Synchronous zero-sequence callback was not covered by the in-flight regression  
Severity: Medium (test quality; production guard already correct)  
Confidence: High  
Status: Fixed in campaign  
Category: Mutation survivor / test defect  
Affected contracts: `Raffle` callback guard and `EntropyAdversarialTest`  
Violated invariant: A synchronous callback must be ignored even when its sequence equals the default stored sequence before `requestV2` returns.  
Attacker prerequisites: Hostile Entropy returns sequence zero and calls back synchronously with sequence zero.  
Impact: Current production is protected by `_requestInFlight`, but the prior regression did not prove that guard was necessary; removing it survived because the synchronous test used sequence 1 while stored state was zero.  
Minimal trace: Configure fixed sequence 0 and one synchronous callback; request draw; without `_requestInFlight`, callback sees `Drawing` and matching default sequence 0 and resolves before the request returns.  
Root cause: Synchronous-callback and zero-sequence edge cases were tested separately, not in composition.  
Regression test: `testSynchronousZeroSequenceCannotMatchDefaultStoredSequence`; current source passes, and mutant M-05 must fail it.  
Patch: Test-only composition regression; no production change because the correct in-flight guard already exists.  
Residual risk: Mutation expansion should continue composing sentinel/default values with reentrancy and ordering edges.

---

ID: CURRENT-DEP-01  
Title: Dependency graph contained High nanoid advisory  
Severity: Low for protocol custody; High upstream advisory rating  
Confidence: High  
Status: Fixed in campaign  
Category: Build/web dependency  
Affected contracts: No production Solidity; workspace transitive dependencies  
Violated invariant: Release dependency audit should have no known High advisory with an available compatible patch.  
Attacker prerequisites: Reach the affected transitive ID-generation behavior with malicious size input.  
Impact: `GHSA-2v37-7h3g-55p8` affected `nanoid 3.3.17` transitively. No direct on-chain custody impact was demonstrated.  
Minimal trace: `pnpm audit --audit-level high`.  
Root cause: Transitive resolution remained on 3.3.17.  
Regression test: Audit first failed, then passed after lock/override update.  
Patch: Root override `nanoid: 3.3.18`, focused lock update, frozen reinstall.  
Residual risk: One Low `elliptic <=6.6.1` advisory remains and no 6.6.2 release exists.

---

ID: CURRENT-TEST-03  
Title: Exact accepted upper bounds and Lens boundary parity were not mutation-sensitive  
Severity: Low (test quality)  
Confidence: High  
Status: Fixed in campaign  
Category: Mutation survivors / boundary coverage  
Affected contracts: Test coverage for `Raffle`, `RaffleFactory`, and `RaffleLens`  
Violated invariant: Both accepted and rejected sides of every inclusive/exclusive bound must be asserted.  
Attacker prerequisites: A future regression changes `>` to `>=`, `<` to `<=`, or raises the purchase maximum.  
Impact: Mutants allowing 101 tickets, rejecting exactly 7-day start/30-day sale/2,048-byte metadata, and Lens allowing buy/draw at closed boundaries survived the initial current-source sample.  
Minimal trace: Apply M-20, M-29, M-30, M-33, M-36, or M-37 and run the pre-campaign suite.  
Root cause: Tests emphasized invalid `maximum+1` cases and contract paths, not exact accepted maxima or Lens/contract parity at the same timestamp.  
Regression test: Added 101-ticket rejection, exact maximum creation successes, and `testLensExactSaleAndRequestGraceBoundariesMatchRaffle`.  
Patch: Test-only boundary assertions; production comparisons were already correct.  
Residual risk: Mutation enumeration is focused, so unlisted boundary expressions may still lack sensitivity.

---

ID: CURRENT-TEST-04  
Title: Prize-delivery owner verification had no malicious misdirection regression  
Severity: Medium (test quality; production check already correct)  
Confidence: High  
Status: Fixed in campaign  
Category: Mutation survivor / asset-path regression  
Affected contracts: `Raffle.redeemWinningTicket` test coverage  
Violated invariant: Winner ticket/proceeds must not be consumed unless post-transfer `ownerOf` reports the intended destination.  
Attacker prerequisites: Prize returns successfully but transfers to another address.  
Impact: Removing the post-delivery `ownerOf` check (M-23) survived existing tests even though production had the right defense. A future regression could burn the credential and release sponsor/treasury proceeds after misdelivery.  
Minimal trace: Resolve NFT branch; arm a prize that redirects `safeTransferFrom` to a third party; winner redeems.  
Root cause: Existing tests covered reverting/frozen prizes and normal delivery, not successful misdirection.  
Regression test: `testRegressionMisdirectedPrizeCannotConsumeWinnerOrReleaseProceeds`; it asserts exact revert and complete rollback.  
Patch: Test-only malicious ERC-721 and regression; no production change.  
Residual risk: A fully malicious `ownerOf` can still lie consistently and remains an accepted asset assumption.

---

ID: CURRENT-DEPLOY-01  
Title: Deployment validator does not strongly bind the expected Factory runtime and all operational policy  
Severity: Low  
Confidence: Medium  
Status: Open release blocker  
Category: Deployment validation  
Affected contracts: Deployment tooling/records; `RaffleFactory` deployments  
Violated invariant: A production deployment record should prove the intended runtime/configuration at an exact chain/block rather than only code presence and selected getters.  
Attacker prerequisites: Wrong/stale/guessed deployment record or operator error.  
Impact: Off-chain clients may accept a contract with code and plausible bindings but an unexpected implementation/runtime, stale block context, or wrong Lens binding. Current tests already reject pending ownership, paused/incompatible quote policy, and an EOA mainnet treasury.  
Minimal trace: Supply a wrong runtime that returns expected selected getters; current validation lacks a complete expected-runtime identity check.  
Root cause: Validation emphasizes bindings/state and not a canonical runtime hash with immutable-reference handling and full operational policy.  
Regression test: Existing deployment tests cover completed ownership, pending-handoff rejection, quote decimals/pause compatibility, and mainnet treasury policy; explicit wrong-runtime, exact stale-block, and wrong-Lens identity cases are incomplete.  
Patch: Compare artifact runtime with immutable regions normalized or attest deployed bytecode; bind exact block hash, chain, proxy implementation, and Lens Factory while retaining existing ownership/quote/treasury checks.  
Residual risk: Proxy dependencies can change after validation; repeat validation and monitor.

---

ID: CURRENT-SUBGRAPH-01  
Title: Ignored Entropy callbacks are not represented in the current subgraph  
Severity: Low  
Confidence: High  
Status: Open  
Category: Indexer observability  
Affected contracts: No Solidity defect; subgraph manifest/schema/mappings  
Violated invariant: Operational views should distinguish ignored stale/wrong/in-flight callback attempts from accepted resolution.  
Attacker prerequisites: Submit or cause an ignored callback; consumers rely only on subgraph diagnostics.  
Impact: On-chain status remains correct, but monitoring/investigation may omit oracle anomalies or repeated invalid callbacks.  
Minimal trace: Cause wrong-sequence/late callback; observe `EntropyCallbackIgnored` on-chain and no indexed entity/update.  
Root cause: Event is absent from current subgraph handlers/schema.  
Regression test: On-chain event assertions exist; no mapping test exists for this event.  
Patch: Add an immutable diagnostic entity/handler and mapping test, or explicitly document that raw logs are the monitoring source.  
Residual risk: Subgraph lag/reorgs remain; never use it as authorization.

---

ID: CURRENT-FUZZ-01  
Title: External-fuzzer branch reachability is not asserted by durable counters  
Severity: Low (test quality)  
Confidence: High  
Status: Open  
Category: Test defect / observability  
Affected contracts: Echidna and Medusa harnesses  
Violated invariant: An external campaign should fail if its intended cash/NFT/refund branches are dead.  
Attacker prerequisites: Harness/config drift.  
Impact: Properties could remain green while a desired branch silently becomes unreachable. Separate cash/NFT harnesses, retained corpora, instruction/branch counts, and deterministic tests provide evidence but not a self-checking guarantee.  
Minimal trace: Remove an action transition while leaving properties conditional on the resulting status.  
Root cause: Harnesses expose security properties but not per-branch ghost counters/meta-properties.  
Regression test: Fresh current cash/NFT campaigns reached nontrivial corpora; no red counter proof was added.  
Patch: Add monotonic ghost counters for each terminal origin/action and assert minimum reachability in bounded campaign-specific harnesses.  
Residual risk: Coverage can still overstate semantic diversity.

---

ID: CURRENT-SIZE-01  
Title: Factory has only 309 bytes of EIP-170 runtime headroom  
Severity: Low  
Confidence: High  
Status: Accepted release risk  
Category: Deployability / boundedness  
Affected contracts: `RaffleFactory`  
Violated invariant: Production changes must remain deployable under EIP-170.  
Attacker prerequisites: None; build configuration/source growth.  
Impact: A modest production patch may exceed 24,576 runtime bytes and become undeployable.  
Minimal trace: Canonical `forge build --sizes` reports 24,267 bytes.  
Root cause: Factory embeds Raffle creation bytecode and validation logic.  
Regression test: Existing size gate.  
Patch: No current patch. Treat exact size as mandatory after every production edit; avoid broad refactors.  
Residual risk: Compiler/dependency changes can move size without Solidity edits.

---

ID: CURRENT-DOC-01  
Title: Public and historical documents contain superseded protocol behavior  
Severity: Informational  
Confidence: High  
Status: Open release documentation blocker  
Category: Specification / operations  
Affected contracts: Documentation only  
Violated invariant: Operators and users should have one current public lifecycle/economics/security specification.  
Attacker prerequisites: Reader follows an older report/whitepaper despite its warning.  
Impact: Readers may expect all-state transferability, callback-time proceeds, or removed recovery/dispatcher behavior.  
Minimal trace: Compare current `Raffle.sol` with the explicitly superseded complete whitepaper and historical audit claims.  
Root cause: Code evolved after the reviewed commits; historical evidence was correctly retained rather than rewritten.  
Regression test: Current source reconciliation in `CURRENT-SPECIFICATION.md`.  
Patch: Publish a new versioned public spec/whitepaper linked to the deployment commit while preserving old documents as historical.  
Residual risk: Third-party copies/caches remain.
