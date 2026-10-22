# CLAUDE-OPENKRITT-MOD attempt-01 — COMPLETE (modified controller, post-seal, disclosed)

**This is not the native CLAUDE-OPENKRITT cell.** That cell stays BLOCKED (`../../CLAUDE-OPENKRITT/attempt-01/BLOCKED.md`). This run is a distinct, disclosed method that the owner requested on 2026-10-21 ("do whatever you can to fix it and run it"). It ran after `FIRST-PASS.md` was sealed and is not part of that seal.

## Method
- **Base:** open-kritt @ `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` (the same pin as the native cell). Upstream HEAD `41a9d99` on 2026-10-21 still pinned Claude Code 2.1.215.
- **Controller modification** (`openkritt-mod.patch`, 4 files, +10/−2):
  - `@anthropic-ai/claude-code` 2.1.215 → 2.1.299 in `engine/Dockerfile` and `engine/Dockerfile.claude-runner`;
  - `claude-opus-5-5` (efforts low…max) added to `engine/open_kritt_engine/model_catalog.py` and `backend/src/lib/modelCatalog.js`.
  - Backend login still uses its bundled Claude Code 2.1.215 (login only).
- **Runtime config** (`docker-compose.override.yml`): the engine mounts the lima VM's rootless Docker socket.
- **Host:** new dedicated lima VM `raffle-claude-openkritt` (vz, 4 CPU, 8 GiB, 60 GiB). Pre-existing VMs were not touched.
- **Auth:** the owner completed the Claude subscription sign-in in OpenKritt Accounts. The assistant entered no credential.
- **Native method:** built-in workflow `external-flow-analysis` (seed sha256 `7bc89df1…`: entrypoints → flows → per-flow investigation). Default severity ranker "Blockchain security triage". Post-script "PoC Creator" (mandatory post-processing; chosen as OpenKritt's proof stage). No agent skills.
- **Target:** local repo `raffle-fun-r001-clean`, a git commit `9732b7d8…` of the frozen clean context (production hashes match the freeze). `repo_scope` names the five production files. The request is in `scan-request.json`.
- **Model:** scan, workflow and post-processing all `claude-opus-5-5`, thinking effort `max`, harness `claude-code`, provider `claude`.
  - Observed in a job container: `claude -p --model claude-opus-5-5 … --effort max`, Claude Code `2.1.299`, no `--fallback-model`.
  - The provider-returned identity per job is **unknown**: OpenKritt deletes per-job output directories and stores no `modelUsage`. Its database was not queried, because that would have required its password.

## Timeline and operator interventions (disclosed)
- **17:54:22Z** created. **00:42:50Z** completed (≈6 h 48 m, far beyond the 75-minute cell budget; the overrun is disclosed).
- Jobs 17 and 19 hung for more than 2 h 25 m with near-zero traffic. The 7200 s harness timeout did not reap them. At **21:07Z** the controller:
  - set `harnessTimeoutSeconds` 7200 → 2700 and `workerCount` 2 → 4 (memory capped capacity at 3) through `./kritt-headless settings set` (`settings-changes.log`);
  - stopped the two hung containers (`intervention.log`). The engine recorded them as failed attempt 1 (`model_process_error`, saved outputs in `model-error-outputs/`) and their retries completed.
- **Not by this lane:** a separate "Daybreak audit coordinator" session wrote `SUPERVISOR-BUG-DIAGNOSIS.json`, `LOGICAL-FAILURE-RESOLUTION-DIAGNOSIS.json`, `CAPTURE-HELPER-REPAIR.json`, `PRE-SEAL-STATUS-EXPOSURE.json` and `native-resume-supervisor/` into this directory (00:02–00:42Z). They are preserved unmodified as that session's records and are not part of this lane's evidence or commit.

## Result
- **Status:** completed. Attempts: 195 total, 193 completed, 2 failed (the two stopped jobs; their logical lineages completed on retry). Workflow depths 0/1/2.
- **rawCandidates = 0, findings = 0, canonicalFindings = 0, exploitable = 0.** The post-script ran 0 times (nothing to process). There is no export ZIP; the native CLI reports "This scan has no canonical findings to export." See `scan-final.json`.
- **Freeze:** `freeze-before.json` and `freeze-after.json` both `ok: true`.

## Interpretation
- Across 171+ externally reachable flow lineages, OpenKritt's investigators returned no concrete vulnerability with a supported attacker path. That agrees with the lane's adjudication of no confirmed Critical or High.
- It did not surface CL-01 (design-level prize trust) or CL-02 (self-inflicted counterfactual-clone strand). Both fall outside this workflow's "concrete attacker-controlled exploit" output contract.
- A zero-finding result is not evidence of absence, and the run used a modified controller.
