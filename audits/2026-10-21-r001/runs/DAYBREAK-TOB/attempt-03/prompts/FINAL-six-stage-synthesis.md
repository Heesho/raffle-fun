# DAYBREAK-TOB final six-stage synthesis judge

You are the final synthesis judge for the already-executed, same-cell Trail of Bits audit lineage `DAYBREAK-TOB`, attempt 03. This is not a new cold review and not permission to repair production. Produce the exact consolidated native-method audit report as Markdown on stdout. The CLI captures stdout directly to the requested report file.

## Mandatory route and identity treatment

The actual runner route for this judge is externally fixed to:

- model selection: `gpt-daybreak-blue-latest`
- cyber access program: `daybreak_blue`
- reasoning effort: `ultra`
- multi-agent: disabled
- fallback: disabled

Do not claim a provider-returned model identity unless the JSON event stream actually supplies it. It has not done so in prior stages; say `unknown` if this run likewise omits it.

## Frozen scope and prohibitions

- Frozen target commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.
- Runtime target: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target`.
- Scope: all five production Solidity files, their 31 reachable Solidity dependency files, and clean `DESIGN.md`.
- Do not inspect any other audit cell, scanner campaign, historical audit, historical test corpus, accepted-risk register, or reconciliation material.
- Do not inspect attempt 02. It must merely remain preserved and untouched.
- Do not modify production, dependencies, configuration, lockfiles, freeze material, stage reports, stage seals, `FIRST-PASS.md`, or the root source-first-pass `SEAL.json`.
- Do not run new scanners or tests. This is evidence synthesis and adjudication only.
- Do not perform live transactions, publish, purchase services, or implement remediation.
- You may read only the same-cell sources and evidence explicitly listed below.

## Pinned native method

Pinned Trail of Bits upstream: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits`, commit `82fe8226252622fa807643bdca1710901198553a`.

Read the complete `SKILL.md` and directly referenced workflow/report resources for these six skills, in this native order:

1. `plugins/building-secure-contracts/skills/audit-context-building/SKILL.md`
2. `plugins/building-secure-contracts/skills/entry-point-analyzer/SKILL.md`
3. `plugins/building-secure-contracts/skills/token-integration-analyzer/SKILL.md`
4. `plugins/building-secure-contracts/skills/guidelines-advisor/SKILL.md`
5. `plugins/building-secure-contracts/skills/spec-to-code-compliance/SKILL.md`
6. `plugins/building-secure-contracts/skills/secure-workflow-guide/SKILL.md`

This is the authorized six-skill aggregate, not the full catalog.

## Required evidence to read

Attempt root: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03`.

Read completely:

- S1 dossier: `artifacts/stages/01-audit-context/inherited/DOSSIER.md`
- S1 function records and index beneath `artifacts/stages/01-audit-context/inherited/`
- S1 seal: `artifacts/stages/01-audit-context/SEAL.json`
- S2 report and seal: `artifacts/stages/02-entry-point/REPORT.md`, `artifacts/stages/02-entry-point/SEAL.json`
- S3 report and seal: `artifacts/stages/03-token-integration/REPORT.md`, `artifacts/stages/03-token-integration/SEAL.json`
- S4 report and seal: `artifacts/stages/04-guidelines/REPORT.md`, `artifacts/stages/04-guidelines/SEAL.json`
- S5 report, summary, requirements, undocumented behaviors, records/refutations indexes, and seal beneath `artifacts/stages/05-spec-compliance/`
- Immutable source-only synthesis: `FIRST-PASS.md`, `FIRST-PASS.timestamp`, `FIRST-PASS.sha256`, root `SEAL.json`, and `artifacts/seals/first-pass-summary.json`
- S6 report, result summary, property matrix, detailed findings, manual review, Slither triage, file coverage, and seal beneath `artifacts/stages/06-secure-workflow/`
- Freeze checks: `artifacts/logs/freeze-after-s5.json`, `artifacts/logs/freeze-before-s6.json`, `artifacts/logs/freeze-after-s6.json`
- Pinned skill hashes: `artifacts/resources/skill-hashes.sha256`
- Target file/hash inventories: `target/dependency-hashes.json` and `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/freeze.json`

You may inspect the five production files, 31 listed dependency files, and `DESIGN.md` only to check citations or resolve conflicts in the sealed evidence. Do not inspect pre-existing project tests.

## Lineage and exposure boundary

The immutable source-only first pass was sealed at `2026-10-21T22:52:38Z`, before S6 began at `2026-10-21T22:54:27Z`. Preserve that boundary explicitly:

- `FIRST-PASS.md` is the unmodified source-only conclusion from S1–S5.
- S6 scanner/test/reproduction evidence may confirm, narrow, contradict, or add findings, but must never be described as if it informed the earlier source-only pass.
- State which findings were source-first-pass findings, which were dynamically confirmed/refuted, and which were newly found in S6.
- No cross-cell reconciliation occurred.

## Required report content

Produce a self-contained final report with, at minimum:

1. Audit identity, scope, frozen commit, pinned method commit, exact route tuple, provider-identity caveat, authorization boundaries, and overall disposition.
2. A six-stage execution ledger table in native order, naming the exact skill, inherited/fresh status, core inputs, completion evidence, report/dossier SHA-256, seal SHA-256, route, and meaningful controller adaptations/local failures. Do not imply inherited S1 was rerun; it was validated byte-for-byte from the same cell. State that attempt 02 remains preserved and was not used.
3. The source-first-pass seal/exposure chronology and hash evidence.
4. An executive risk summary and final consolidated finding totals.
5. A canonical final findings register that deduplicates stage-local findings. Each final finding must have a stable final ID, severity, confidence, affected files/lines/functions, source-stage lineage, S6 dynamic status, exploit/precondition narrative, impact, evidence links, and concrete remediation direction. Explicitly adjudicate any stage severity disagreement rather than silently selecting one.
6. Separate treatment for specification/documentation divergences and out-of-scope/unverifiable claims, including the early empty-raffle close and frontend reread language.
7. S6 tool/test results: Slither and all 14-result triage status, ERC-721 checker, proxy/upgrade search, `slither-prop` disposition, all three printers and rendered DOT/PNG/PDF, Foundry unit/fuzz results, intentional negative-property results, invariant counts, Echidna counts/seed/corpus, measured coverage, and every material local repair. Clearly distinguish intentional counterexample failures from unexpected failures.
8. Per-property coverage, preferably by referencing and summarizing the complete S6 matrix without omitting failed or unresolved properties.
9. Per-file coverage for all five production files and all 31 dependency files. You may compact the dependency table, but every dependency must remain individually accounted for.
10. Function-analysis depth: state that S1 contains all 12 native function records; preserve S1/S2 depth gaps and any unresolved deep-analysis leads rather than claiming exhaustive formal proof.
11. S5 method accounting: 56 requirements, 56 records, 56 analyses, 11 initially nonimplemented, 22 refutations, 7 surviving divergences, 4 dropped candidates, and 11 undocumented consequential behaviors. Record the controller adaptation that processed all 56 rather than the workflow's default cap of 30 while preserving native phases/refuters.
12. Unresolved external/deployment leads, explicit limitations, prioritized actions, and a final completeness checklist for exactly these six skills (not the full catalog).
13. Integrity: clean freeze results (435 files per root, 5 production, 31 dependencies), the 43/43 isolated-copy verification, no source/config/lock/freeze changes, no production remediation, no live transactions.

## Evidence discipline

- Use absolute clickable Markdown links for local evidence where helpful.
- Do not turn tool warnings or intentional negative tests into false vulnerabilities.
- Do not present a passing generated campaign as formal proof.
- Do not overstate deployed Chainlink wrapper or quote-token identity: deployment data was absent.
- If two sealed stages conflict, explain and adjudicate using the strongest evidence; do not rewrite either earlier artifact.
- Preserve all unresolved leads.
- Conclude with exact hashes for the immutable source-first-pass report/seal and all six stage reports/dossier/seals, plus the S6 manifest.

Output only the final Markdown report.
