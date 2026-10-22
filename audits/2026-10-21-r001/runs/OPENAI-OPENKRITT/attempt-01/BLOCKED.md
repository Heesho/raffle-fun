# OPENAI-OPENKRITT: BLOCKED

Recorded at 2026-10-21T07:59:02.614144Z. Requested model: `gpt-6-astra`. Requested effort: `ultra`. Required access program: `none explicitly requested`.

No native scan ran. No result is being substituted from a manual review, synthetic workflow runner, or other harness. Completed workflow jobs, dedupe jobs, ranker jobs, and post-script jobs are all **0**. Provider-returned model/access-program identity is unknown.

## Pinned method and scope

Upstream: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/openkritt` at commit `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`; the final diagnostic reports a clean upstream working tree. Applicable instructions read: upstream `AGENTS.md` and `CONTRIBUTING.md`; the ancestor `.codex/AGENTS.md` was empty. No upstream file was modified. Intended target is only the existing clean-context source snapshot, never the production checkout, audit outputs, other reviews, or historical findings.

`METHOD-PROVENANCE.json` records SHA256 hashes for the inspected engine/control resources and complete bundled SQL migration resource set. These are available method resources, not a claim that a scan selected or injected them. No provider credential or token file was opened or printed. The diagnostic Python process used `-B`, avoiding bytecode writes to the upstream. Own runtime root: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/OPENAI-OPENKRITT/attempt-01/runtime`.

## Native architecture: no Docker/DB-free scan route

- `engine/open_kritt_engine/__main__.py:1-4` dispatches to `worker.main`; `worker.py:1937-1944` unconditionally validates the scan runner before entering the worker.
- `harnesses.py:881-901` requires a Docker executable, an absolute host mapping for engine data, a live daemon, and a local scan-runner image. There is no direct local scan bypass in this validation.
- `CodexHarness._run`, `harnesses.py:1769-1801`, always wraps tool-enabled runs in `_scan_docker_command` when `allow_tools=True`. Its default is true. `_scan_docker_command:935-1069` creates a per-job container/network, binds the isolated home/workspace, and uses `--pull never`.
- The local `allow_tools=False` path is used by draft generation (`generation.py:832`), which generates workflow/post-script drafts; it is not the production source scanner. Reusing it to manually feed code would change the method.
- Native worker state, workflows, scan records, queue/results, and post-processing use PostgreSQL through `Database.connect` (`db.py:89-96`), `EngineConfig.database_url` (`config.py:38-40,66-90`), and worker/postprocessor database operations. The headless CLI calls the backend API; it is not a database-free offline runner (`scripts/kritt-headless-lib.mjs:534-549`). No native standalone scan command was established.

## Three bounded setup diagnostics

The complete commands, exit codes, and captured non-secret output are in `DIAGNOSTICS.json`. No diagnostic subprocess was allowed more than 10 seconds. No daemon, DB, provider job, container, live deployment, or publish action was started.

1. **Pinned source/applicability inspection:** confirmed the exact commit and native Docker/PostgreSQL architecture. The repository provides genuine bundled workflows, so an unavailable/fabricated workflow is not being claimed as the sole blocker.
2. **Native harness import and command construction attempt:** import failed with `ModuleNotFoundError: No module named 'jsonschema'`. Both `jsonschema` and `psycopg` are absent from the host Python environment. Command construction did not execute. No `postgres`, `initdb`, `pg_ctl`, or `psql` executable was on PATH. No existing database connection was attempted or inspected.
3. **Native availability/entrypoint diagnostic:** Docker CLI is installed; `docker info --format '{{.ServerVersion}}'` exited 1 because `/var/run/docker.sock` does not exist. Native `python3 -B -m open_kritt_engine` exited 1 before scanning because required Python dependencies are absent. Local runner image existence cannot be verified while the daemon is unavailable. The clean upstream working-tree check made no changes.

These failures establish that the current host cannot execute the pinned native stack as supplied. Missing Python packages are individually remediable; they do not remove the daemon/database requirements. The task budget did not authorize replacing the native architecture with a hand-built runner, and none was created.

## Exact model and access-program routing

The pinned native command can express `-m gpt-6-astra` and `model_reasoning_effort="ultra"`. Actual admission by the native model catalog and access through its Linux Codex runner are unverified. Authenticated success from the bundled macOS CLI does not establish identical behavior from the pinned runner.

`harnesses.py:1654-1716` builds `codex --search exec --json -C ... -m MODEL ... -c 'model_reasoning_effort="EFFORT"'` for tool-enabled scans. `models.py:8-13` stores only model, model_provider, harness, and thinking_effort. `backend/src/lib/constants.js:71-91` includes `ultra`, and `backend/src/lib/modelSelection.js:20-40` additionally requires the requested model/effort to appear in the native provider catalog. That catalog was not available without the running stack.

The product's `codex` provider maps to the ordinary Codex provider, not to a cyber access-program (`harnesses.py:1077-1097`). Setting `CODEX_MODEL_PROVIDER` cannot supply `--cyber-access-program`. The isolated Codex job copies only `auth.json`, not operator `config.toml` (`workspace.py:159-184`); its credential copy routine skips source symlinks (`workspace.py:1848-1853`). Therefore the parent-reported probe home containing an auth symlink cannot be presumed to be a working native credential source. No credentials were read to test this; it is a source-based setup caveat.

The native Dockerfile pins Linux npm Codex `0.145.0` (`engine/Dockerfile:15`), Python `3.12.14`, Node `24.15.0`, and Docker CLI `29.8.0`. The successful access probe reported by the parent used the different bundled macOS executable at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`. It returned `ACCESS_OK` for both requested routes, but did not expose resolved model/program fields. This is evidence that account access is available through that CLI, not evidence that the native engine executed or propagated the program.

No alternate model/provider fallback was configured. Native model selection inherits the base tuple when depth/postprocess overrides are omitted (`models.py:24-89`); those defaults must be explicitly audited in a future scan. Native invalid-output recovery can resume the same session/model (`harnesses.py:1810-1866,1885-1929`) and is not an alternate-model fallback. There is no identified toggle disabling that internal same-model recovery. Retry counts were set to zero only for the startup diagnostics. No promise of a provider-side fallback policy or returned model identity is made.

## Workflow, injected skills, ranker, post-processing, and counts

No database scan was created, so **selected workflow, selected skills, selected ranker, and selected post-scripts are unset**. Actual injected skill count is 0. Those null selections are not to be mistaken for an executed workflow with empty optional resources.

The genuine applicable candidate is the bundled `external-flow-analysis` in `backend/src/lib/defaultWorkflowSeeds.json:1-77`:

| Depth | Native step template | Multi-output | Last step |
|---|---|---|---|
| 0 | Map external entrypoints | true | false |
| 1 | Trace reachable flows | true | false |
| 2 | Investigate flow vulnerabilities | true | true |

This is **3 depths and 3 step templates**, not a predetermined three model calls. Native output-dependent fanout determines job counts. Planned invocation count remains unknown; executed count is zero. The other bundled workflow, `Cosmos ABCI Panic Halt Review`, is Go/Cosmos-specific and was not chosen for this Solidity project. The full workflow resource is hashed, preserving exact prompt/schema text without silently modifying it for this target.

Optional skills are seeded in `database/init/014_seed_agent_skills.sql`. Several are explicitly concise bridge/reference text, including Pashov Solidity, rather than the full external skill bodies. They must not be represented as full imported skills. Native installation writes per-skill files plus the `open-kritt-selected-skills` bundle (`workspace.py:1856-1868`) and invocation comes from `prompting.py:655-672`. None were installed here.

The available bundled ranker is `Blockchain security triage` (`backend/src/lib/defaultSeverityRankers.js:3-17`). Its exact text is hashed; it was not selected or run. Native post-processing first deduplicates, then severity-ranks canonical findings, then runs chosen per-finding post-scripts (`post_processing.py:451-479`). Batches use `BATCH_SIZE=50` (`post_processing.py:42`); scripts depend on actual configured IDs and canonical findings (`1028-1126`). Empty findings can complete without those model calls. All seed/update SQL resources are hashed so a future fresh database's post-script contents can be reconstructed at this commit. No post-script content or selection was fabricated.

## Reproducible unblock sequence

1. Provide a fresh isolated Docker daemon and PostgreSQL/backend stack for this pinned checkout. Use distinct compose project/data/credential/local-repo roots for each cell; do not attach existing production data or audit-output directories. Run the repository's documented native setup/start procedure with all data paths redirected to the cell runtime. Disable Codex auto-update and automatic global Docker pruning, keep bounded workers/subagents, and set explicit job timeouts/retry policy. Record resulting image IDs/digests and CLI version.
2. Install the exact `engine/requirements.txt` into that runtime, or build the exact pinned `engine/Dockerfile`; initialize the database with its bundled migrations and seed resources. The host-only module-import failure can be reproduced with `cd engine` followed by `python3 -B -m open_kritt_engine`; installing packages alone is insufficient because native startup then requires Docker and a valid runner image.
3. Use native login/provider management to provide the already authorized account to the isolated runtime without exposing token contents. Verify native model catalog admission for `gpt-6-astra` at `ultra`. An API key is not inherently required when the native Codex login path is correctly configured.
4. For Daybreak, obtain native engine support that explicitly preserves `--cyber-access-program daybreak_blue` for initial jobs, all depth/post-processing jobs, and same-session output recovery, together with a compatible runner CLI. The pinned revision has no such interface; a future changed upstream must be separately pinned and clearly identified. Do not rename the model, silently choose another model, or use a shim that would be mislabeled as this pinned native engine.
5. Create and snapshot an actual native scan configuration: exact bundled workflow ID/content hash, precise clean source scope and dependency closure, chosen skill bodies/hashes (or explicitly none), ranker text/hash, selected post-scripts/hashes, base/depth/postprocess model tuples, repeat count, and concurrency limits. Then run the native engine, record stage/job counts and raw provenance, and collect output through the native export. Do not mark the present blocked attempt successful retroactively.

No production changes, peer-finding consultation, live interaction, publication, or credentials access occurred during these diagnostics.
