# Native Gemini route repair

The supported authenticated route is the official native Antigravity CLI `agy` 1.4.4, staged at `bin/agy`. The public release payload matched its official SHA-512 manifest. Existing local authentication worked without a browser login, credentials extraction, global settings edits, or a new service purchase. See `antigravity-install-provenance.json` and `command-log.jsonl`.

## Verified runtime

- `agy models` advertised `gemini-4-argon-high`. Explicit `/model` and `/effort` probes returned that slug and `high`. An unknown model exited 1; `--effort max` with this model exited 1. The harmless connectivity run returned `ROUTE_OK`, with native stream `init.model` set to `gemini-4-argon-high`.
- `--dangerously-skip-permissions` produced native `permission_mode: always-proceed`; a native `run_command` created and read a harmless canary successfully. `--mode auto` warned that auto mode is unavailable for this account and continued in its default mode. Do not claim that auto mode was selected successfully.
- A custom-agent fixture was accepted and appeared in `init.agent`. `agy agents` nevertheless returned no entries, and `init.tools` stayed at the default tool catalog. Tool restrictions and discovery enforcement are therefore unproven; the default runtime with explicit pinned skill instructions is the verified execution route.
- A JSON-schema probe returned a valid object in terminal `result.structured_output`. Use that object for schema-bound workflow agents. `result.response` duplicated the JSON in this probe and was not independently parseable as one JSON document.
- These observations prove the selected native harness model and successful authenticated responses. They do not expose an independently returned provider revision or prove a particular backend checkpoint.

`run_native_gemini.py` is ready for controller invocation. It starts a fresh conversation in the supplied working directory, preserves native NDJSON/stdout/stderr, pins the model and high effort, uses native `--print-timeout 0`, and has no outer wall-clock limit, automatic retries, continuation, or review import. The optional permission flag requires the already authorized isolated workflow. Output directories must be new.

The documented global configuration paths contained no AGENTS/GEMINI rules, skills, custom agents, plugins, or CLI settings; the only discovered MCP profile was an empty file. This inventory is in `global-context-inventory.json`. No supported per-run switch guaranteeing isolation from every possible personal-memory mechanism was established. Fresh cwd and absence of continuation should not be described as such a guarantee.

## Prepared workspaces and setup correction

`prepared-workspaces.json` identifies SIMAO, PASHOV, GEBAL, and six separate ToB stage workspaces. Each now contains all 43 frozen clean-context files, including 36 Solidity files: five owned sources and 31 pinned dependencies. Simao's 18 resources, Pashov's complete solidity-auditor tree, and each ToB stage's exact skill tree were copied. Referenced ToB plugin workflow JavaScript and custom-agent definitions were retained unmodified under `upstream-plugins/`.

The initial copy helper wrongly excluded `node_modules`. The first readiness message incorrectly counted the source template rather than the destination: initial workspaces contained 12 clean-context files, five Solidity sources, and zero dependency files. The correction only added the 31 absent dependency files; it did not rewrite existing inputs. SIMAO additions occurred at filesystem ctime 18:09:28.263587–18:09:28.277734 UTC, PASHOV at 18:09:28.295175–18:09:28.304606 UTC, and all copy/verification work finished at 18:09:28.547177 UTC. The parent had already started both model attempts based on the incorrect readiness message. Assessments begun before closure was available must be treated as limited or rerun. `dependency-copy-correction.json` preserves every added path/hash, the timestamps, root cause, and limitations. Copied mtime/birthtime values are source metadata and do not identify copy time. No further changes to those active workspaces were made after this correction.

ToB S1 and S5 require a Workflow engine. The default Antigravity tool catalog exposes `run_workflow`, but compatibility with the pinned Claude Workflow JavaScript engine has not been established. Copying resources alone does not execute the native workflow. A disclosed runtime adapter that executes the exact pinned JavaScript body with equivalent schema-bound independent calls is a distinct controller method; a generic prompt is not evidence of native workflow execution. Preserve S5's unchanged default/max fan-out limits.

## Gebal native cold context

`gebal-intake-complete39/setup-result.json` is the completed setup. A pristine archive of effective pinned Gebal revision `9ad24645f92a3821ae4539db5f1be52b48ed379e` ran under Node `v22.23.3`, using independent local state. The controller created a source-only, no-provider-egress plan, approved its exact hash under delegated authorization, completed intake, and exported the native context. No review was imported and no model assessment was launched by this setup agent.

- Native context: 39 files, comprising five owned Solidity files, 31 Solidity dependencies, and three build configuration files.
- Plan: `c35ed605-83a5-44f3-9c26-9515a3f7a045`; approval hash `a7b6569e61c08240f2eb0a8f4f1756b3e62e4f7399e0d77227e66ba1da4710e6`.
- Intake run: `f2fea02e-0d56-4440-b9a8-dbd764357706`.
- Snapshot hash: `520205ade6130391972086d8fe8a24a6d6e60c1ecfdaf795110d78d8d0375fdb`.
- Context hash: `6e679ad388dc6cca777f066e0cce87ccf1962c9fb310f3f263c6e5fa3db4352a`.

The earlier eight-file context remains separately preserved in `gebal-intake/` as the incomplete setup draft. It is superseded by `gebal-intake-complete39/cold-context.json`. The complete context also resides in the prepared Gebal workspace at `gebal-context/cold-context.json`. Original compiler/build configuration, including `gas_reports`, was preserved.

## Official documentation

The official [installation guide](https://www.antigravity.google/docs/getting-started/) supplied the installer. The [authentication guide](https://www.antigravity.google/docs/install?tab=cli) documents shared local sign-in. [Headless mode](https://www.antigravity.google/docs/cli/headless/) documents model pinning, schema output, and invalid-model failure. [Custom agents](https://www.antigravity.google/docs/subagents/), [skills](https://www.antigravity.google/docs/skills/), and [rules](https://www.antigravity.google/docs/rules/) document their discovery paths. Original HTML snapshots and hashes are preserved in `official-docs/` and `official-docs-sources.json`.
