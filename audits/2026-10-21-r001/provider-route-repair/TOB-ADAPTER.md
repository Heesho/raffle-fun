# Disclosed host adapter for exact pinned ToB workflow JavaScript

`tob-native-workflow-adapter.mjs` executes the unmodified algorithm bodies of ToB `audit-context.js` and `spec-compliance.js` from revision `82fe8226252622fa807643bdca1710901198553a`. This is a disclosed host controller using native Antigravity calls, not a claim that Antigravity implements Claude's Workflow engine.

The only source transformation replaces `export const meta` with `const meta`; an AsyncFunction receives `args`, `agent`, `parallel`, `pipeline`, `phase`, `log`, and `budget`. Both original/transformed source hashes, the complete source, adapter hash, native CLI hash, validator metadata, source agent hashes, and runtime settings are recorded at launch. Only two allowlisted exact workflow hashes may execute on the host. Assessed source files are not evaluated by this controller.

Each workflow `agent()` request starts a fresh native `agy` process with explicit `gemini-4-argon-high`, high effort, `--dangerously-skip-permissions`, NDJSON output, an exact upstream schema file, and `--print-timeout 0`. The adapter has no wall-clock cap, automatic retry, fallback model, or conversation continuation. It captures argv, prompt, schema, native stdout/stderr/log, unique conversation identity, init model and permission mode, token usage, and structured output. Schema data is taken only from terminal `result.structured_output` and independently validated with existing local Ajv 8.20.0; textual `result.response` is not parsed. [Ajv's API documentation](https://ajv.js.org/api.html) describes the compiled validator used here.

Pinned `agentType` Markdown is resolved from the exact copied plugin agent definition, hash-verified, preserved verbatim in the call evidence, and prepended verbatim to that invocation. A separate instruction identifies the original `{baseDir}` path and maps tool names to native equivalents. Unknown agent types fail explicitly. The exact S5 script itself has a typed-checker recovery path; that original recovery is retained and logged. The adapter adds no recovery of its own.

The scheduler limits actual native agent calls to two concurrently, configurable from one through four. Parallel and pipeline result arrays preserve input order. Failed parallel/pipeline items become `null`, with recorded errors. Pipeline stages do not hold agent permits, so their nested parallel refutation calls cannot deadlock. Already requested native calls are drained before final result recording, including the S5 early-return path where its reverse sweep may still be active.

`budget.total` is zero and `budget.remaining()` returns zero. Thus the unchanged S1 script chooses its default 12 functions (maximum 40), and S5 its default 10 requirements (maximum 30). No all-functions or all-requirements coverage claim follows. Every original phase, selection rule, refutation, and report assembly is driven by the exact JavaScript. Upstream low/medium effort options are retained in call records; actual effort is always high under the user's model requirement.

Prepared launch configurations:

- `tob-s1-adapter-config.json`: fresh S1 workspace, exact audit-context workflow.
- `tob-s5-adapter-config.json`: fresh S5 workspace, exact spec-compliance workflow and `DESIGN.md` specification.

The exact Node 22.23.3 launch commands are in `tob-adapter-setup-result.json`. No assessed execution was launched during setup. Output directories must not already exist.

Six setup-only synthetic tests passed. They exercise pinned source gating, schema validation and duplicated textual JSON, model/conversation mismatch rejection, named-agent resolution, bounded nested scheduling and result order, exact S1 default fan-out, and exact S5 duplicate IDs, default selection, reverse sweep, independent refutations, the original recovery path, deferred requirements, and outright failures. These tests use synthetic mock returns and are not audit evidence. Their TAP output is preserved in `tob-adapter-setup-selftest.stdout.txt`.
