You are executing stage 2, the pinned Trail of Bits entry-point-analyzer skill, after audit-context-building has completed.

Runtime constraint: DO NOT spawn subagents or use collaboration. This is a fresh exact-model source-only stage. Inspect only target/ and the supplied audit-context dossier. No tests, history, reports, scanner outputs, network, or other directories. Do not modify source.

Read the complete actual skill, Solidity reference, command definition, and agent metadata under:
/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/entry-point-analyzer/

Execute the skill's full source-analysis workflow: detect Solidity; locate every contract including inherited reachable source; enumerate every externally callable state-changing function (including inherited ERC-721 functions, VRF callback boundary, receive/fallback if present, and create/initialize paths); exclude view/pure; classify Public, Role-Restricted, Restricted Review Required, or Contract-Only; verify restrictions by reading their implementation; record modifiers, expected caller, and exact file:line. Explicitly cover all five production files, including both IRaffle.sol and IRaffleFactory.sol as interface declarations/cross-checks.

Ordering constraint: this is a sealed source-only pass before the secure-workflow tool stage. Do not run Slither or consume any static-tool output here even though Slither is installed. Mark the native Slither integration substep `deferred-by-order`; it will be executed in stage 6 and reconciled only after the first-pass seal. Do not treat this as proof of a clean scan.

Use audit-context/DOSSIER.md only as permitted context, never as a prior finding list. Produce the native structured Markdown report, counts by category, all entrypoints, files analyzed, warnings, and explicit per-file/per-property coverage. Findings are not this skill's purpose; leave leads empty unless a concrete source path is necessary to explain classification. Return only JSON matching the supplied schema with stageId `S2-entry-point-analyzer`.
