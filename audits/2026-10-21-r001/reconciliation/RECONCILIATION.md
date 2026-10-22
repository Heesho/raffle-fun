# Post-seal reconciliation — raffle.fun r001

Reconciled at 2026-10-21T17:43:31.697142+00:00. Input snapshot cutoff: 2026-10-21T17:34:20Z. This is a disclosed cross-review step after first-pass seals, not another independent blind review. No original report/seal or production source was changed. No owner acceptance, risk acceptance or scope relaxation is inferred.

The register contains two production issue families: **RF-001, conditional High under the explicit untrusted-prize design**, and **RF-002, Low, execution-confirmed sponsor-selected asset stranding with an honest ERC721**. Ten separate dependency, integration, documentation, closed-lead or evidence entries prevent those qualifications from disappearing. Six test-assurance issues remain separate from production defects.

All 14 included FIRST-PASS/SEAL pairs matched their report SHA256. They contain 13 distinct report texts, not 13 independent model votes: one Gebal report is copied byte-for-byte, and the Trail of Bits aggregate has a separately sealed source-only predecessor. Unsealed peer results and DAYBREAK-PASHOV/SIMAO/TOB attempt-03 content were not inspected. Reports sealed after the snapshot are not silently included. A seal proves integrity, not native-stage completeness. The DAYBREAK-PASHOV first pass explicitly says its specialists produced no review; its controller proof is attributed separately. Other reported incomplete stages remain incomplete; this reconciliation does not certify harness completion.

## Root causes and disagreements

RF-001 joins DAYBREAK-SIMAO H-1/H-2/H-3/H-4 into the single chain the original report itself identifies. The fake custody/delivery and later refusal variants share an unenforced prize-semantics boundary. Independent sponsor/treasury release is deliberate design behavior; settlement being permissionless or storage-only is not separately counted as a vulnerability. The quote ledger may be fully conserved even while the promised NFT is unavailable. EVM rollback restores the failed redemption transaction; it cannot reverse a sponsor payment made in an earlier transaction.

DESIGN.md:2 explicitly calls arbitrary prizes untrusted; IRaffle.sol:12–15 assumes honest compliant prizes. High ratings from the Daybreak reports, conditional High/Medium from supplements, and informational/unscored OpenAI leads are all retained. The chosen disposition is a validated conditional design violation with an unresolved trust-policy conflict, not unconditional theft from honest NFTs. A sealed two-test mock proves the contract can accept fabricated ownership reports and pay 95% to its sponsor. Its separate actualOwner mapping is illustrative, not an oracle for a real collection’s value. The permanent-refusal ordering is supported by the actual source; no new hostile-prize campaign was run. Delaying payment alone cannot authenticate a lying prize, and a refund fallback requires retained sponsor and treasury funds plus careful winner-liveness rules.

RF-002 is stronger than a generic warning about users sending to bad addresses: the parent’s existing honest-ERC721 test configures a future same-factory clone as sponsorRecipient, deploys that clone, returns token1 into it using transferFrom, and shows that normal recipient-clone completion releases only token2. The test passed. This validates a missing current destination check at sponsor-prize delivery and an actual same-factory transfer forbidden by the literal design. The sponsor selected the sink. No capability to replace an ordinary victim EOA, steal another raffle’s quote funds or reduce buyer refunds is established. A fresh runtime check prevents the transfer but does not by itself recover an immutable blocked claim. Foreign-factory variants remain source-established with additional configuration prerequisites; using another raffle’s ticket as a prize need not itself cause permanent loss.

DAYBREAK-SIMAO M-1/M-2 remain preserved at their original Medium ratings. This reconciliation classifies them as issuer/recipient availability dependencies, not demonstrated unauthorized protocol exploits. Sender freeze and recipient freeze are kept separate because only the latter might be addressed by authenticated recipient redirection; neither is evidence of a deployed freeze, and migration cannot move tokens from an issuer-blocked sender.

## Custody, claims and proof limits

Raw balances are not the same as obligations. Unsolicited quote/native/NFT donations have no recorded claimant and no rescue; this can strand the donor’s asset without making legitimate quote claims insolvent. A donation may make balance greater than accounted liabilities. The RF-002 sponsor-prize return is a protocol-directed transfer, so it is not dismissed as an unsolicited donation. Ticket ownership or successful receiver acceptance similarly does not prove a contract can exercise a bearer claim. Current-owner authority, callable recipient capability, external token availability and arithmetic backing are distinct conditions.

No new broad campaign was run. Evidence is the frozen source, sealed reports and the specifically cited existing mock/recipient/mutation artifacts. Cross-model agreement is never treated as proof. The prior symbolic accounting results remain bounded to their declared actors, counts, mocks and orderings; they do not authenticate arbitrary NFT semantics or all recipient capabilities.

## Reconciled register

| ID | Classification | Status |
| --- | --- | --- |
| RF-001 — Adversarial prize semantics can defeat economic delivery while NFT-outcome proceeds are payable | High under the explicit untrusted-prize DESIGN scope; trust limitation under the narrower honest-prize interface scope | validated_conditional_path_scope_conflict_open |
| RF-002 — Temporal and factory-local destination screening permits sponsor-selected clone sinks | Low | validated_honest_erc721_reproduction |
| OBS-001 — Quote issuer sender freeze can block all exits while preserving liabilities | Informational dependency risk; original Medium retained in attribution | conditional_dependency_risk_not_unauthorized_protocol_exploit |
| OBS-002 — Fixed sponsor or treasury recipient can lose quote-transfer availability | Informational integration limitation; original Medium retained in attribution | conditional_immutable_recipient_risk |
| OBS-003 — Nominal quote accounting assumes canonical fee-free non-rebasing transfers | Informational trust assumption | outside_declared_quote_semantics_no_in_scope_exploit |
| OBS-004 — Receiver acceptance and address-level ownership do not prove bearer claim usability | Informational | self_selected_recipient_limitation |
| OBS-005 — Unsolicited assets have no rescue and are outside recorded liabilities | Informational | documented_design_consequence_not_claim_insolvency |
| DOC-001 — General refund deadline wording omits empty-raffle early cancellation | Informational | source_behavior_intended_by_interface_no_buyer_loss |
| CLOSED-001 — VRF modulo reduction has negligible finite-word bias | None | closed_no_practical_exploit_established |
| CLOSED-002 — Sponsor buying reserve-crossing entries changes the openly specified outcome | None | closed_expected_open_sale_behavior |
| CLOSED-003 — uint64 timestamp narrowing beyond representable chain time | None | closed_unreachable_practical_precondition |
| EVIDENCE-001 — Canonical deployment identity and real oracle/callback configuration remain unverified | Unscored | requires_deployment_evidence |

The machine-readable [findings register](findings-register.json) supplies each entry’s exact source spans, capabilities, sequence, impact limits, proof paths, confidence, remedy and re-audit properties. It preserves 63 report-level attributions; original IDs are never rewritten. Unnumbered observations have `original_id: null` and retain their exact original label/ordinal. The byte-identical copied Gebal report is registered as a duplicate input rather than counted again.

## Original named IDs and disposition

| Original report | Original ID | Reconciled entry | Original severity/status |
| --- | --- | --- | --- |
| DAYBREAK-GEBAL/attempt-01/deliverables | FP-01 | RF-001 | High; finding |
| DAYBREAK-PASHOV/attempt-01 | CL-01 | RF-001 | Unscored; controller lead; native Pashov specialists returned no reviews |
| DAYBREAK-SIMAO/attempt-01 | H-1 | RF-001 | High; finding; original report explicitly says one composite chain |
| DAYBREAK-SIMAO/attempt-01 | H-2 | RF-001 | High; finding; original report explicitly says one composite chain |
| DAYBREAK-SIMAO/attempt-01 | H-3 | RF-001 | High; finding; original report explicitly says one composite chain |
| DAYBREAK-SIMAO/attempt-01 | H-4 | RF-001 | High; finding; original report explicitly says one composite chain |
| DAYBREAK-TOB/attempt-02 | L-02 | RF-001 | Unscored; lead in incomplete native source pass |
| OPENAI-GEBAL/attempt-02 | L-01 | RF-001 | Informational; lead |
| OPENAI-PASHOV/attempt-01 | Raffle.releaseSponsorProceeds  /  untrusted-prize-payout | RF-001 | Unscored; sole native retained lead; zero findings |
| SUP-A1/attempt-01 | SUP-A1-L1 | RF-001 | Potential High if arbitrary malicious prizes supported; conditional lead |
| SUP-A2/attempt-01 | SUP-A2-U01 | RF-001 | Conditional Medium; unresolved specification/trust-boundary issue |
| SUP-S1/attempt-01 | SUP-S1-T1 | RF-001 | Conditional High impact; conditional trust gap |
| DAYBREAK-GEBAL/attempt-01/deliverables | FP-02 | RF-002 | Low; finding |
| DAYBREAK-TOB/attempt-02 | L-01 | RF-002 | Unscored; lead in incomplete native source pass |
| OPENAI-GEBAL/attempt-01 | C01 | RF-002 | Low; source-supported candidate |
| OPENAI-GEBAL/attempt-02 | L-02 | RF-002 | Unscored; unconfirmed integration lead |
| SUP-A1/attempt-01 | SUP-A1-I1 | RF-002 | Informational; established informational observation |
| SUP-A2/attempt-01 | SUP-A2-01 | RF-002 | Low; source-demonstrated issue |
| DAYBREAK-SIMAO/attempt-01 | M-1 | OBS-001 | Medium; finding |
| SUP-A1/attempt-01 | SUP-A1-L2 | OBS-001 | Dependency/configuration risk; conditional lead |
| DAYBREAK-SIMAO/attempt-01 | M-2 | OBS-002 | Medium; finding |
| SUP-A1/attempt-01 | SUP-A1-L2 | OBS-002 | Dependency/configuration risk; conditional lead |
| SUP-A1/attempt-01 | SUP-A1-L2 | OBS-003 | Dependency/configuration risk; conditional lead |
| SUP-A1/attempt-01 | SUP-A1-L3 | OBS-004 | Informational; integration limitation |
| DAYBREAK-TOB/attempt-02 | L-03 | DOC-001 | Unscored; lead in incomplete native source pass |

## Test assurance — separate from production findings

The unchanged baseline passed 70 selected unit/fuzz/security tests and nine stateful invariants. All four independently selected disposable mutants compiled and were killed by the existing unit/fuzz/security selection. All four survived the short 64-run/depth-64 invariant campaign. These statements are compatible: suite selection and action reachability matter, and four mutants are not a comprehensive mutation score.

### AQ-001 — Swallowed reverts permit an entirely inactive invariant campaign

All 9 invariants survived a valid-purchase-always-reverts mutant at 64 runs/depth64; audit_strict 16/depth64 also passed with zero handler reverts. Unit/fuzz/security selection killed it with59 failures. RaffleHandler.sol:61-72 catches purchase failures; many actions silently return; no minimum meaningful activity is proved.

**Remedy:** Track independent attempted/successful/unexpected-failure counters; assert allowed actions succeed; seed terminal branches without requiring every random sequence to hit all branches.
**Re-audit property:** A contract that rejects all valid purchases must fail a stateful campaign; successful cash/NFT/refund settlement and final exits must have measured witnesses.

### AQ-002 — Owner-only handler calls mask authorization mutations

The stateful handler pranks owner for redemption/refunds (RaffleHandler.sol:187-188,207-208), so removing winner owner guard survived all9 bounded invariants. Existing deterministic/fuzz/security tests killed it with3 failures. Two holder addresses do not provide adversarial caller coverage.

**Remedy:** Generate outsider, former owner, approved operator, buyer and recipient independently; retain positive current-owner actions.
**Re-audit property:** Unauthorized claim attempts must fail with complete state rollback; current bearer must still succeed.

### AQ-003 — Deadline action prefilters hide rejection-boundary defects

Handler requestDraw prefilter at RaffleHandler.sol:115-126 and Echidna:67-75 never calls outside the valid window. >= to > mutation survived9 bounded invariants; deterministic selection killed it with3 failures.

**Remedy:** Add invalid-action probes at boundary-1, boundary and boundary+1, with independently expected results.
**Re-audit property:** At exact request deadline requestDraw must reject and refunds become eligible; invalid calls must reach production rather than no-op in the handler.

### AQ-004 — Economic oracle is useful but short-run reachability and some ghosts are weak

Fee500->400bps survived64-run invariants but was killed at run120 in a512-run campaign and by9 unit/fuzz/security failures. Guided existing-oracle probe also killed it. Rate literals are independent; gross/payout ghosts partly copy contract getters/returns. Echidna actor/split gaps are source-reviewed, not mutation-tested.

**Remedy:** Seed lifecycle states, count successful branches, measure token balance deltas independently and add exact per-beneficiary Echidna split checks.
**Re-audit property:** Wrong fee allocation must be reached and rejected in each outcome; totals alone must not substitute for correct recipient shares.

### AQ-005 — Python reference model does not restore lazy settlement after unauthorized redemption

current_protocol_model.py:166-177 mutates through settle_winner:155-163 before raising not-owner. Probe changed settlement_complete false->true, unsettled1e6->0 and sponsor/treasury/winner claims0->150k/50k/800k despite rejection. Solidity transaction rollback and the passing owner/operator unit test preserve state; this is not a production rollback defect.

**Remedy:** Prevalidate or snapshot/restore modeled transactions; add full-state rollback comparison and actual differential contract execution if claiming differential assurance.
**Re-audit property:** Every rejected modeled action must leave the entire state unchanged just as Solidity does.

### AQ-006 — Historical mutation denominator contains stale definitions

11/52 historical mutation patterns have zero current-source matches; they are invalid definitions, not survivors/kills. Remaining41 uniquely match but were not compiled/executed here. Generic nonzero-exit classification can conflate infrastructure and assertion failures.

**Remedy:** Validate exact current-source applicability first, retain full logs/diffs and classify compiler failure/tool failure/timeout separately from assertion kill.
**Re-audit property:** Every claimed valid mutant must compile and have a documented semantic change; mutation score denominator must exclude invalid definitions.

## Evidence and source integrity

- Sealed malicious-prize evidence: DAYBREAK-PASHOV/attempt-01/proofs/UntrustedPrize.t.sol, final stdout and exit-code file, all listed in its sealed artifact manifest; two tests PASS. This is a controller proof, not a successful native specialist/judge finding.
- Honest future-recipient evidence: reconciliation/recipient-validation/RecipientValidation.t.sol:20–32 and runs/TOOL-RECIPIENT-VALIDATION/attempt-01/{stdout.txt,result.json}; one test PASS, process exit 0 and clean before/after frozen checks.
- Assurance evidence: runs/TOOL-MUTATION-QUALITY/SUMMARY.md and its sealed logs/diffs/normalized classifications. No mutant exists in the frozen production trees.
- Every first-pass source and seal hash is retained in findings-register.json. RECONCILIATION-SEAL.json binds this reconciliation and its register. Root final report and execution matrix remain separate deliverables.

No provider rejection occurred during this reconciliation. No new production fix, deployment, chain transaction or external approval was performed.
