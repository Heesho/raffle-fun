Act as the independent source-first-pass synthesis judge for the authorized DAYBREAK-TOB audit. Produce the immutable, pre-tools first-pass report from the five sealed source stages only.

Route tuple: model gpt-daybreak-blue-latest; cyber access program daybreak_blue; reasoning effort ultra; fallback disabled; multi-agent disabled. Provider identity is unknown unless an actual provider event supplies it. Frozen target SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155.

Read these sealed stage artifacts in full:
- S1 context: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md and /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/SEAL.json
- S2 entry points: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/REPORT.md and SEAL.json
- S3 token integration: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md and SEAL.json
- S4 guidelines: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md and SEAL.json
- S5 specification compliance: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, summary.json, report-input.json, and SEAL.json

Read target/DESIGN.md and the cited source directly before resolving disagreements. You may read S5 requirement analyses or S1 function records when a stage claim needs its native depth, but do not read anything outside the same-cell sealed source-stage lineage.

Write the finished Markdown report to exactly /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/FIRST-PASS.md using apply_patch. Then return only the supplied JSON summary with reportFile set to that exact absolute path.

Required report content:
1. State that this is the source-only first pass frozen before any S6 test/scanner exposure, with target SHA and exact route tuple.
2. Record exact lineage: S1 is validated same-cell inheritance from attempt-01 (12 native function records plus dossier, original evidence untouched); S2's first local wait-loop attempt is preserved and its fresh retry completed; S3 and S4 completed fresh; S4 used only an isolated compiler build; S5 checked all 56 rather than the native MAX_LIMIT=30 while preserving Extract → Align → Verify → Report and two refuters per non-implemented record. Attempt-02 remains preserved and unused.
3. Give a stage coverage table for S1-S5, their report hashes/seal times, scope, and remaining limitations. State S6 is deliberately pending behind this seal.
4. Reconcile and deduplicate every security/compliance candidate. Do not count the same malicious-prize issue three times merely because S3, S4, and S5 reached it independently. Resolve severity based on demonstrated consequence and preconditions; explain any severity change from a contributing stage. Distinguish exploitable/security findings, design-code divergences/documentation fixes, and out-of-scope compliance status.
5. For every consolidated finding include: unique ID, severity, title, affected files and exact lines, source-stage provenance, documented assumption/requirement where relevant, root cause, reachable sequence, consequence, preconditions, and a scoped remediation direction. Do not claim dynamic reproduction.
6. Preserve considered-and-dropped S5 candidates as non-findings, and state why they were dropped.
7. Include explicit per-production-file coverage for all five files and the 31-file dependency closure. Include per-property coverage for REQ-01 through REQ-56, with final status and consolidated finding cross-reference where applicable. The S5 matrix may be compactly reproduced but no property may disappear.
8. Include entry-point and function-depth coverage: S2's recurring entry-point counts, S1's 12/24 native function-candidate cut, and all depth gaps. Do not imply the aggregate is the full Trail of Bits catalog; it is exactly five source skills so far, with secure-workflow-guide pending.
9. Include unresolved leads and assumptions suitable for S6: concrete malicious prize behavior; standard ERC-721 contract-recipient delivery; nominal-vs-balance-delta quote accounting under the trusted-USDC assumption; callback/request ordering; future-clone destination reachability; timestamp-width edge; deployed address/provenance; frontend revision. Clearly distinguish leads from findings.
10. Include source-only completeness: no tests/scanners/cross-cell reconciliation, no live transactions, no production/config/lock/freeze changes, and clean freeze verification after S5.

Preserve every material minority view across stages instead of smoothing it away. Cite exact stage artifact paths for provenance and exact source file:line references for code claims. If a contributing report overstates a consequence, correct it explicitly. Do not invent provider identity.

Exposure boundary: do not read tests, tool/scanner output, other cells, root campaigns, attempt-02 content, historical audits, accepted risks, or cross-cell findings. Do not modify target/config/lock/freeze/source. Multi-agent is disabled; never call collaboration/spawn/message/wait tools. Return directly.
