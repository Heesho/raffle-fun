# Audit Execution Plan — Google Gemini Provider Lane (`2026-10-21-r001`)

## 1. Role & Authorization
- **Coordinator & Executor**: Google Gemini (`gemini-4-argon`, Gemini 4 Argon (High), executed via Antigravity IDE / Language Server `hub-2.25.0`).
- **Writable Report Directory**: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/gemini`
- **Isolated Runtime Directory**: `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini`
  - Note: Runtime placed under `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini` (outside the repository and outside all other providers' runtimes) because macOS `sandbox-exec` in non-interactive overnight mode denies shell writes to `/Users/hishamel-husseini/.codex/...` while permitting full non-interactive read/write access to the conversation scratch directory.

## 2. Selected Gemini Model & Runner Provenance
- **Official Documentation Verification**: Checked `ai.google.dev/gemini-api/docs/models` and Antigravity 2026 model documentation on `2026-10-21`. Flagship frontier reasoning model in the current Google Gemini 4 family is **Gemini 4 Argon** (`gemini-4-argon`, `High` thinking), alongside the Gemini 3.1 / 2.5 Pro lines.
- **Actual Account & Runner Probe**:
  - Runner binary: `/Applications/Antigravity.app/Contents/Resources/bin/language_server` (`ANTIGRAVITY_LS_VERSION=hub-2.25.0`, `ANTIGRAVITY_CLI_ALIAS=agy`).
  - Active session model verified in `.system_generated/logs/transcript.jsonl`: **Gemini 4 Argon (High)** (`gemini-4-argon`, thinking effort `High`).
  - Subagent runner: `invoke_subagent` with `Model: "inherit"` spawns isolated subagent conversations on the exact same `gemini-4-argon` (`High` thinking) model with automatic fallback disabled.
  - Standalone external CLI check: `gemini` CLI is not installed on `PATH`, and `GEMINI_API_KEY` / `GOOGLE_API_KEY` are not exported in the shell environment; authenticated Gemini 4 Argon (High) access is provided natively through the Antigravity language server and subagent orchestration engine.

## 3. Five Required Provider Cells + Supplementary Cold Review

| Cell ID | Upstream Harness | Requested Pin | Resolved Pin | Planned Execution Route & Status |
|---|---|---|---|---|
| `GEMINI-SIMAO` | `0xSimao AI` (`https://github.com/0xsimao/0xsimao-ai`) | `3f81e5803174182a7db07eca87849d2b3d571113` | `3f81e5803174182a7db07eca87849d2b3d571113` | **ELIGIBLE (Cold Source-Only)**: Native 6-turn workflow (`SKILL.md` explicitly model- and harness-agnostic). Build `money-map.md`, `source.md` (explicitly scoping interfaces `IRaffle.sol` and `IRaffleFactory.sol`), and `lens-1-bundle.md`..`lens-12-bundle.md`. Run 12 independent `invoke_subagent` (`Model: "inherit"`) specialists, preserve bundles and raw outputs, adjudicate via `severity-calibration.md` gates, and format native report. |
| `GEMINI-PASHOV` | `Pashov Skills / solidity-auditor` (`https://github.com/pashov/skills`) | `8ce544c9c9affab448d3dc4c79191d052e3a57ec` | `8ce544c9c9affab448d3dc4c79191d052e3a57ec` | **ELIGIBLE (Cold Source-Only)**: Native 5-turn workflow (`passes = 1`, prior-project memory OFF, explicit file list scoping all 5 production files including interfaces). Build `source.md`, `scope.tsv`, and `agent-1-bundle.md`..`agent-12-bundle.md`. Run 12 independent `invoke_subagent` (`Model: "inherit"`) specialists, run Turn 4 `judging.md` + `dedup-and-assembly.md` (`run-1.md`), and execute Turn 5 native `assemble.sh` to produce `full-report.md`. |
| `GEMINI-OPENKRITT` | `OpenKritt` (`https://github.com/Kritt-ai/open-kritt`) | `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` | `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` | **BLOCKED (Unsupported Provider Route in Upstream Engine)**: Upstream `open_kritt_engine/harnesses.py` (line 206) hardcodes `MODEL_PROVIDERS = {"codex", "claude", "openrouter", "xai", "deepseek"}` and `run_model_prompt` (lines 443–451) only dispatches CLI runners `codex`, `claude-code`, and `grok-build`. Per Rule 7, recorded as `BLOCKED` with full provenance rather than replaced by a homemade review. |
| `GEMINI-TOB` | `Trail of Bits Skills` (`https://github.com/trailofbits/skills`) | `82fe8226252622fa807643bdca1710901198553a` | `82fe8226252622fa807643bdca1710901198553a` | **ELIGIBLE (Cold Source-Only)**: Declared 6-skill aggregate (3 mandatory + 3 added declared stages; explicitly not claiming the full catalog): (1) `audit-context-building`, (2) `entry-point-analyzer`, (3) `token-integration-analyzer`, (4) `guidelines-advisor`, (5) `spec-to-code-compliance`, (6) `secure-workflow-guide` + `code-maturity-assessor`. Each stage executed by an independent `invoke_subagent` (`Model: "inherit"`) specialist against clean-context. |
| `GEMINI-GEBAL` | `Gebal` (`https://github.com/Heesho/gebal`) | `5c68ec0284dc642823abe81cbc0e02fcb080a69f` (failed remote fetch) | `9ad24645f92a3821ae4539db5f1be52b48ed379e` | **ELIGIBLE (Two Separately Bound Runs)**: (a) **Attempt 01 (Cold Source-Only Run)** on an isolated copy of `clean-context`: native `gebal init` -> `gebal review` -> `gebal approve --actor assistant:antigravity-gemini-4-argon` -> `gebal run` -> `gebal context`, cold review via `agents/REVIEW.md` + `agents/response.schema.json` bound to exact `snapshotHash`/`contextHash`, `gebal import-review`, and `gebal report` (`md`, `json`, `html`, `sarif`). (b) **Attempt 02 (Post-Seal Test-Inclusive Run)** on an isolated copy of `target.tar.gz` after `FIRST-PASS.md` is sealed, separately bound to its own `snapshotHash`/`contextHash`. |
| `GEMINI-SUPPLEMENTARY` | Independent Whole-System Gemini Review | N/A | N/A | **ELIGIBLE (Cold Source-Only)**: Independent first-principles mathematical, economic, state-machine, and cross-contract composition analysis of all 5 production contracts and 31 reachable dependency files. |

## 4. Phased Execution Schedule & Budgets
1. **Phase 1 — Freeze Verification & Control Package Initialization** (Complete)
2. **Phase 2 — Cold Source-Only Reviews (Strictly Before Reading Any Tests/Historical Audits)**
   - Stage upstream harness files into isolated runtime and verify SHA-256 against `upstreams.jsonl`.
   - Record `GEMINI-OPENKRITT` `attempt-01` blocker evidence.
   - Execute `GEMINI-SIMAO` `attempt-01` (12 specialist subagents + Turn 6 adjudication/report).
   - Execute `GEMINI-PASHOV` `attempt-01` (12 specialist subagents + Turn 4 judge/dedup + Turn 5 `assemble.sh`).
   - Execute `GEMINI-TOB` `attempt-01` (6 stage specialist subagents + consolidated report).
   - Execute `GEMINI-GEBAL` `attempt-01` (cold source-only native CLI snapshot/context/import/reports).
   - Execute `GEMINI-SUPPLEMENTARY` `attempt-01` (independent whole-system mathematical & architectural review).
3. **Phase 3 — First-Pass Sealing**
   - Consolidate all cold-review findings into `FIRST-PASS.md`.
   - Record UTC timestamp and seal SHA-256 in `FIRST-PASS.md.sha256` before inspecting `target.tar.gz` or running deterministic tests/scanners.
4. **Phase 4 — Post-Seal Validation & Local Tool Campaigns**
   - Unpack `target.tar.gz` into `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini/validation`.
   - Run core campaigns (Slither, Aderyn, Echidna, Halmos) and project validation stack (Foundry, Hardhat, TypeScript/SDK/ABI checks, plus evaluation of Medusa, mutation testing, Certora, SMTChecker, dependency checks), retaining exact versions, commands, exit codes, seeds, and blocker diagnostics where host sandbox restrictions apply.
   - Execute `GEMINI-GEBAL` `attempt-02` (post-seal test-inclusive run).
5. **Phase 5 — Reconciliation, Final Report & Freeze Re-Verification**
   - Deduplicate and reconcile all sealed Gemini findings and tool campaign results in `reconciliation/`.
   - Write `FINAL-AUDIT-REPORT.md`, update `matrix.json`, `toolchain.json`, and `STATUS.md`.
   - Re-verify all 435 tracked files in the repository, `target.tar.gz`, `clean-context.tar.gz`, and `dependency-hashes.json`.
