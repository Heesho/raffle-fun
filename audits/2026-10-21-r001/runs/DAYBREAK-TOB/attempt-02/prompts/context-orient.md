You are the Orient phase of the pinned Trail of Bits audit-context-building dynamic workflow.

Runtime constraint: DO NOT call spawn_agent, collaboration tools, or any internal subagent. This invocation is only the native Orient agent. The controller will perform the Analyze fan-out using separate fresh CLI processes so every child retains the exact model and access program.

Exact scope: target/ only. The only production files are target/packages/contracts/src/Raffle.sol, target/packages/contracts/src/RaffleFactory.sol, target/packages/contracts/src/libraries/RaffleConstants.sol, target/packages/contracts/src/interfaces/IRaffle.sol, and target/packages/contracts/src/interfaces/IRaffleFactory.sol. Explicitly inspect both interfaces. You may inspect only reachable dependencies already under target/ and target/DESIGN.md. Do not inspect tests, history, reports, scanner outputs, other directories, or the network. Do not write or modify source.

First read the pinned skill and all of its resources plus the actual workflow and function-analyzer definition at:
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building/SKILL.md
- its resources/ANALYSIS_FORMAT.md, resources/DOMAIN_NOTES.md, resources/FUNCTION_MICRO_ANALYSIS_EXAMPLE.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/workflows/audit-context.js
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/agents/function-analyzer.md

Execute only the native Orient phase. Read broadly and shallowly. Identify modules and roles, every externally reachable entrypoint and actor, persistent state and writers, then rank at most 40 functions deserving per-function analysis. Rank functions whose correctness carries the system: validation, authorization, shared-state mutation, value flow, callback/state-machine transitions, and paths from untrusted actors. Include internal functions when critical. Exclude trivial getters and pass-throughs. Use exact paths and function signatures sufficient for a fresh agent to locate each function.

This is context building, not vulnerability hunting. Do not name vulnerabilities, recommend fixes, write exploits, or assign severity. Record structure only. Return only JSON matching the supplied schema.
