You are executing native stage S2 of the same DAYBREAK-TOB audit cell. This is the Trail of Bits `entry-point-analyzer` stage, not a generic security review.

Authoritative route: requested model `gpt-daybreak-blue-latest`, cybersecurity access program `daybreak_blue`, reasoning effort `ultra`, no fallback. Record this accepted local selection in the report. Provider-returned identity is `unknown` unless the JSON event stream explicitly supplies it.

Frozen target SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.
Target root (read-only): `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target`.
Scope: all five production Solidity files under `target/packages/contracts/src`, their 31 reachable dependency files listed in `target/dependency-hashes.json`, and clean `target/DESIGN.md` only.
Native context dossier (read in full): `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md`.

Before analysis, read these pinned method resources in full:
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/entry-point-analyzer/skills/entry-point-analyzer/SKILL.md`
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/entry-point-analyzer/skills/entry-point-analyzer/references/solidity.md`

Execute the literal workflow: detect language; locate every in-scope contract/interface/library and relevant inherited contract; enumerate every externally callable state-changing function (excluding view/pure); trace actual modifiers and inline gates; classify each as Public (Unrestricted), Role-Restricted, Restricted (Review Required), or Contract-Only; and emit the native structured Markdown report. Include inherited ERC721 entry points and the Chainlink callback gateway that are callable on a Raffle clone, without double-counting interface declarations as runtime functions. List constructors separately as deployment-time entry points because the reference says they are not recurring entry points. Verify callbacks rather than classifying from names.

Cold-stage exposure rule: do not run or read Slither, test, scanner, prior audit, other-cell, or peer-stage output. The controller must seal the source-only stages before secure-workflow tool exposure. This is an explicit controller adaptation to the native optional-tool step: perform and document the skill's permitted manual analysis now; Slither cross-checking is deferred to S6. Do not read any S2-S6 report from attempt-02 or any other cell.

Required report additions:
- exact source/file/line evidence for every entry point and every restriction;
- category counts and a reconciliation table proving the counts equal the enumerated functions;
- per-file coverage for all five production files and each relevant reachable dependency (explicitly explain dependency files with zero runtime entry points);
- analysis warnings, exclusions, unresolved leads, and per-function depth gaps;
- method/resource paths and SHA-ready provenance; target SHA; route tuple; source-only exposure statement;
- no vulnerability hunting, exploit claims, test results, or remediation.

Do not edit the target, production/config/lock/freeze files, or the inherited dossier. Your final response must be only the complete native S2 Markdown report; the controller records it verbatim.

Local-runner guard: multi-agent operation is disabled for this fresh context. Do not call any collaboration, spawn, message, or wait tool. There are no child agents to wait for. After completing file reads and analysis, return the report directly.
