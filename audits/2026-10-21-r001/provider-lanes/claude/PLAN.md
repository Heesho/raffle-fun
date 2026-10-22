# Anthropic provider lane — PLAN (raffle.fun audit r001)

Owner instruction: `audits/2026-10-21-r001/prompts/claude-overnight.md` (delegated overnight authorization; the owner did not personally review any plan hash).
Lane directory (exclusive): `audits/2026-10-21-r001/provider-lanes/claude/`
Lane runtime (exclusive): `~/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/` (called `RT` below)
Frozen target: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Common freeze: `../../freeze.json`, verified by `python3 ../../verify-freeze.py` before and after every attempt (recorded per attempt in `freeze-before.json` / `freeze-after.json`).

## Cells (stable IDs) and native methods
| Cell | Harness pin | Native method executed |
|---|---|---|
| CLAUDE-SIMAO | 0xsimao-ai @3f81e58 | `/simao:0xsimao-ai <5 files> --file-output`: money map → 12 independent lens subagents → native dedup/judge/report gates. Interfaces named explicitly (filename mode overrides the default `interfaces/` exclude). Bundles preserved (rm denied + 15 s preserver copy). |
| CLAUDE-PASHOV | pashov/skills solidity-auditor @8ce544c | `/pashov:solidity-auditor <5 files> --loop 1 --file-output`: memory off (1 pass, no `--memory`), 12 specialists, native dedup/gates, `assemble.sh` report. `AskUserQuestion` disabled, so the model question is skipped natively; specialists inherit the session model, which is also forced by `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-5-5`. |
| CLAUDE-OPENKRITT | open-kritt @43e1d19 | BLOCKED: see `runs/CLAUDE-OPENKRITT/attempt-01/BLOCKED.md`. |
| CLAUDE-TOB | trailofbits/skills @82fe822 | Six declared stages, each a separate fresh session: S1 audit-context-building (plugin workflow), S2 entry-point-analyzer, S3 token-integration-analyzer, S4 guidelines-advisor, S5 spec-to-code-compliance (plugin workflow), S6 secure-workflow-guide (tool-assisted: Slither). This is a six-skill aggregate, **not** the full ToB catalog. |
| CLAUDE-GEBAL | Heesho/gebal @9ad2464 (historical pin 5c68ec0 unresolvable remotely; see `../../upstream-fetch.json`) | Native CLI: `init` → scope → `review` (snapshot) → delegated `approve` → `run` → `context` export → Opus reviewer session writes `review.json` → `import-review` → `findings` → `report`. Cold review only. A test-inclusive deterministic run needs Gebal's sandbox (a container host) and is tracked separately. |
| CLAUDE-SUP (supplementary) | none | Independent whole-system cold review in an isolated Opus session. It does not replace any cell. |

## Model and runner controls
- Runner: Claude Code **2.1.299** installed with npm into `RT/claude-code` (the user's global install is untouched). The old 2.1.58 failure is preserved under `RT/probes/old-2.1.58` and in the OPENKRITT evidence.
- Every session: `--model claude-opus-5-5 --effort max`, no `--fallback-model`, `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-5-5`, `--setting-sources project` (user settings, including `switchModelsOnFlag`, are not loaded), `--settings {autoMemoryEnabled:false, deny rm/out-of-scope reads}`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, `--strict-mcp-config` (no MCP), only the cell's own plugin loaded via `--plugin-dir`, clean `env -i` (the inherited desktop `CLAUDE_EFFORT=high` is removed).
- Identity evidence per attempt: stream-json `init.model`, every assistant `message.model` (main and subagent), `result.modelUsage` keys, copied session and subagent transcripts. All of this is in `runner-selection.json`. The provider does not echo effort, so the server-side effort stays **unknown** and only the accepted local selection `max` is recorded.

## Independence and ordering
1. Cold phase (now): cells plus SUP run on fresh copies of `clean-context` only. No tests, history, scanner output or peer output are present.
2. Seal: `FIRST-PASS.md` collects every original cold report by path and SHA-256, then gets a timestamp and SHA-256 seal (`FIRST-PASS.md.sha256`) **before** reconciliation and before reading historical tests.
3. Deterministic/tool phase: in the separate validation copy `RT/validation/snapshot` (extracted from `target.tar.gz`, dependencies installed with the pinned node 22.23.2 / pnpm 11.18.0 and the lockfile, dependency hashes verified 31/31): Foundry build/tests/fuzz/invariants/coverage/gas, Slither, Aderyn, Echidna, Halmos, Medusa disposition, mutation, SMTChecker, Certora disposition, dependency checks. Raw outputs go in `tools/`.
4. Reconciliation (post-seal): dedup by root cause, local reproduction tests in the validation copy, final dispositions, `FINAL-AUDIT-REPORT.md`, `HANDOFF.md`.

## Budgets
6 h lane wall-clock (start 07:47Z). ≤75 min per cell attempt (enforced by the runner). ≤3 targeted setup attempts per recurring blocker.
