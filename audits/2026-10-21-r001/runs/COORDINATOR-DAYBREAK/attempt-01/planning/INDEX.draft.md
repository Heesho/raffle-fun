# raffle.fun r001 evidence index

Frozen target `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. The final 23-cell matrix is **20 complete or qualified-complete plus three actual OpenAI provider-rejected**. File presence alone does not establish workflow completion; [matrix qualification](matrix.json), [provider validation](PROVIDER-HANDOFF-VALIDATION.md), and the [final receipt registry](reconciliation/FINAL-RECEIPT-REGISTRY.json) control that claim. Original failures, refusals, timeouts, transport errors, superseded attempts, and first-pass seals remain append-only.

## Final assessment and provenance

- [Final assessment](FINAL-AUDIT-REPORT.md)
- [Final status](STATUS.md)
- [23-cell matrix](matrix.json)
- [External-provider qualification](PROVIDER-HANDOFF-VALIDATION.md)
- [Per-file and per-property coverage](PER-FILE-PROPERTY-COVERAGE.md)
- [Native methods and compatibility disclosures](NATIVE-METHODS.md)
- [Actual provider refusals](PROVIDER-REJECTIONS.md)
- [Frozen scope](SCOPE.md), [scope inventory](scope-files.txt), [freeze manifest](freeze.json), and [dependency hashes](dependency-hashes.json)
- [Exact rerun instructions](RERUN.md) and [retry history](RETRIES.md)
- Reusable external handoffs: [Claude coordinator prompt](prompts/claude-overnight.md) and [Gemini coordinator prompt](prompts/gemini-overnight.md). These are reproduction instructions, not evidence of a new run; actual selected-attempt prompts and commands remain in their provider-lane directories.

## Reconciliation and integrity

- [Final reconciliation](reconciliation/FINAL-RECONCILIATION.md)
- [Final findings register](reconciliation/findings-register-final.json)
- [Final reconciliation seal](reconciliation/FINAL-RECONCILIATION-SEAL.json)
- [Final receipt registry](reconciliation/FINAL-RECEIPT-REGISTRY.json)
- [Final recursive receipt check](reconciliation/FINAL-RECEIPT-INTEGRITY.json)
- [RF-002 proof-scope addendum](reconciliation/finalization/RF002-PROOF-SCOPE-ADDENDUM.md)
- [Known historical binding limits](reconciliation/finalization/KNOWN-HISTORICAL-BINDING-LIMITS.json)
- [OpenAI ToB raw-log diagnostic](reconciliation/finalization/OPENAI-TOB-01-RAW-LOG-BINDING-DIAGNOSTIC.json) and [S4 runtime-binding diagnostic](reconciliation/finalization/OPENAI-TOB-01-S4-RUNTIME-BINDING-DIAGNOSTIC.json)
- [Claude OpenKritt pre-seal exposure](provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01/PRE-SEAL-STATUS-EXPOSURE.json), [accounting exposure record](reconciliation/finalization/ACCIDENTAL-STATUS-ENDPOINT-EXPOSURE.json), and [parent addendum](reconciliation/finalization/PARENT-STATUS-EXPOSURE-ADDENDUM.json)
- [Historical comparison](reconciliation/HISTORICAL-COMPARISON.md)

Final reconciliation bindings: register `14fd10f03ae1ae1e503d04e8ff68d382319d42cced4552d12eab92b04f0f6242`; reconciliation `b5b443439f827ce572d5ba57efde0f9d474211756b13aa3df798c58654e80c7b`; reconciliation seal `c5e388d04b64d71c22ada44b36c6f8e7b27a0bf37052cd6039845a9d5dd33186`; source paths/distinct hashes/attributions `28 / 27 / 739`.

## Target cells

`QUALIFIED COMPLETE` means the selected disclosed continuation or modified method is complete; it never changes the status of an earlier refusal, `ERROR`, timeout, blocker, or failed attempt.

| Cell | Final effective status | Selected evidence | Required qualification |
|---|---|---|---|
| OPENAI-SIMAO | INCOMPLETE / PROVIDER_REJECTED | [attempt-01](runs/OPENAI-SIMAO/attempt-01/) | Actual OpenAI cybersecurity rejection; partial stages only; no retry or substitute. |
| OPENAI-PASHOV | INCOMPLETE / PROVIDER_REJECTED | [attempt-01](runs/OPENAI-PASHOV/attempt-01/) | Five of twelve specialists completed; seven actual OpenAI rejections; no retry or substitute. |
| OPENAI-OPENKRITT | QUALIFIED COMPLETE / SEALED | [attempt-02](runs/OPENAI-OPENKRITT/attempt-02/) | Compatibility-patched native method; independent `supp_whole` validator separately provider-rejected. |
| OPENAI-TOB | INCOMPLETE / PROVIDER_REJECTED | [attempt-02](runs/OPENAI-TOB/attempt-02/) | Continuation actually rejected; earlier partial source stages retained; four historical receipt mismatches disclosed. |
| OPENAI-GEBAL | COMPLETE / SEALED | [attempt-02](runs/OPENAI-GEBAL/attempt-02/) | Native source-only method; deterministic compatibility context remains separate. |
| CLAUDE-SIMAO | QUALIFIED COMPLETE / SEALED | [public-evidence attempt-02](provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-02/) | Original method remains Anthropic-refused; killed public-evidence attempt-01 retained. |
| CLAUDE-PASHOV | COMPLETE / SEALED | [attempt-01](provider-lanes/claude/runs/CLAUDE-PASHOV/attempt-01/) | Twelve specialists; consolidated provider seal; tool-assisted sketches; server-applied effort unknown. |
| CLAUDE-OPENKRITT | QUALIFIED COMPLETE / SEALED | [modified final capture](provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01/final-capture/) | Terminal receipt/seal hashes `52b75bba1bb78ce25514b950a102364409e69ca19204e420dadfa773b23cfebe` / `bbab1ac2c461fca324aa50c7c142a402293000fa47ecf79607cd831f569ab8a1`; original route remains blocked. |
| CLAUDE-TOB | QUALIFIED COMPLETE / SEALED | [S6 attempt-02](provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02/) | Six declared skills only; 12 selected/9 shallower functions; S5 10/248 with 238 deferred; two Halmos unknowns. |
| CLAUDE-GEBAL | COMPLETE / SEALED | [native attempt-01](provider-lanes/claude/runs/CLAUDE-GEBAL/native-attempt-01/) | 39-file cold review; intake-only deterministic task list; consolidated provider seal. |
| GEMINI-SIMAO | QUALIFIED COMPLETE / SEALED | [repaired attempt-04](runs/GEMINI-SIMAO-REPAIRED/attempt-04/) | Native success plus append-only adjudication; leaf 03/04 errors and fourteen absent literal paths retained. |
| GEMINI-PASHOV | QUALIFIED COMPLETE / SEALED | [repaired attempt-04](runs/GEMINI-PASHOV-REPAIRED/attempt-04/) | Method output qualified through adjudication; original plus two continuation errors remain; thirteen absent literal paths retained. |
| GEMINI-OPENKRITT | QUALIFIED COMPLETE / SEALED | [native engine attempt-03](provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03/) | Pinned engine with disclosed file-spool adapter; zero candidates is not absence proof; failed calls/metadata retained. |
| GEMINI-TOB | QUALIFIED COMPLETE / SEALED | [repaired attempt-04](runs/GEMINI-TOB-REPAIRED/attempt-04/) | Six declared stages; S1 12 selected/9 unanalyzed; S5 10/219 with 209 unchecked; sticky errors and AQ-009 retained. |
| GEMINI-GEBAL | COMPLETE / SEALED | [repaired attempt-03](runs/GEMINI-GEBAL-REPAIRED/attempt-03/) | Unmodified 39-file cold native review; earlier zero-dependency contexts retained as incomplete history. |
| DAYBREAK-SIMAO | COMPLETE / SEALED | [attempt-03](runs/DAYBREAK-SIMAO/attempt-03/) | Corrected native attempt; earlier interrupted/rejected auxiliary attempts retained. |
| DAYBREAK-PASHOV | COMPLETE / SEALED | [attempt-03](runs/DAYBREAK-PASHOV/attempt-03/) | Corrected native attempt; sealed first pass used as the lane receipt. |
| DAYBREAK-OPENKRITT | QUALIFIED COMPLETE / SEALED | [attempt-02](runs/DAYBREAK-OPENKRITT/attempt-02/) | Compatibility-patched native method; original method artifacts preserved. |
| DAYBREAK-TOB | QUALIFIED COMPLETE / SEALED | [attempt-03](runs/DAYBREAK-TOB/attempt-03/) | Six declared stages plus adjudication; Critical dissent, bounded campaigns, and source-seal-version gap retained. |
| DAYBREAK-GEBAL | COMPLETE / SEALED | [attempt-02](runs/DAYBREAK-GEBAL/attempt-02/) | Native source-only method; deterministic compatibility context remains separate. |
| SUP-A1 | COMPLETE / SEALED | [attempt-01](runs/SUP-A1/attempt-01/) | Source-only supplementary review; later tools separately attributed. |
| SUP-A2 | COMPLETE / SEALED | [attempt-01](runs/SUP-A2/attempt-01/) | Architecture, authority, lifecycle, and rollback review. |
| SUP-S1 | COMPLETE / SEALED | [attempt-01](runs/SUP-S1/attempt-01/) | Source/dependency coverage map; unused APIs and live deployment remain outside closure. |

## Coordinator and out-of-denominator evidence

The [Daybreak coordinator](runs/COORDINATOR-DAYBREAK/attempt-01/) is outside the 23 original slots and must not be added as a row or vote. The [root](reconciliation/finalization/OPENAI-ROOT-ORCHESTRATION-REJECTION-RECEIPT.json) and [orchestration](reconciliation/finalization/OPENAI-ORCHESTRATION-REJECTION-RECEIPT.json) rejection receipts are also outside the denominator. They preserve actual OpenAI rejection without changing the three rejected model/harness cells.

## Tool and integration evidence

- [Cumulative tool ledger](tool-campaign-results-final.json)
- [Tool campaign summary](TOOL-CAMPAIGN-SUMMARY.md) and [extended addendum](TOOL-CAMPAIGN-ADDENDUM.md)
- [Extended Echidna results](ECHIDNA-EXTENDED-RESULTS.json)
- [Halmos closure](runs/TOOL-HALMOS-CONTINUATION/CLOSURE.json)
- [Mutation-quality summary](runs/TOOL-MUTATION-QUALITY/SUMMARY.md)
- [Pinned public-fork validation](PUBLIC-FORK-VALIDATION.md)
- [Dependency review](reconciliation/DEPENDENCY-REVIEW.md)
- [SDK ABI equality](sdk-abi-equality-final.json)
- [Claude ToB S6 evidence](provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02/preserved/evidence/04-properties/) and [Daybreak ToB S6 property ledger](runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SECURITY_PROPERTIES.md)

No artifact here authorizes a production change, deployment, publication, or owner risk acceptance. The coordinator's [pre-exit read-only verification](runs/COORDINATOR-DAYBREAK/attempt-01/PRE-EXIT-READ-ONLY-VERIFICATION.json) binds the promoted report set. Parent-owned whole-package sealing follows only after all writers exit; its `FINAL-VERIFICATION.json` must retain the four known historical mismatches—and no others—explicitly.
