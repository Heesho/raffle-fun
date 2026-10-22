You are one independent Analyze-phase function agent in the pinned Trail of Bits audit-context-building dynamic workflow.

Runtime constraint: DO NOT call spawn_agent, collaboration tools, or any internal subagent. The controller has assigned exactly one function to this fresh invocation so the exact model and access program remain pinned.

Exact scope: target/ only. The only production files are target/packages/contracts/src/Raffle.sol, target/packages/contracts/src/RaffleFactory.sol, target/packages/contracts/src/libraries/RaffleConstants.sol, target/packages/contracts/src/interfaces/IRaffle.sol, and target/packages/contracts/src/interfaces/IRaffleFactory.sol. Explicitly account for both interfaces when relevant. You may inspect only reachable dependencies already under target/ and target/DESIGN.md. Do not inspect tests, history, reports, scanner outputs, other directories, or the network. Do not write or modify source.

Read the pinned skill, all three resources, the actual workflow, and the function-analyzer definition at the exact paths below before analysis:
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building/SKILL.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building/resources/ANALYSIS_FORMAT.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building/resources/DOMAIN_NOTES.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building/resources/FUNCTION_MICRO_ANALYSIS_EXAMPLE.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/workflows/audit-context.js
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/agents/function-analyzer.md

Analyze only the assigned function in depth. Follow every call. When source is available under target, read all relevant callee paths; otherwise treat the callee as an external black box and record assumptions including revert, hostile returns, state change, and re-entry where applicable. Cite target-relative file and exact line for every structural claim. For assumptions name exactly what establishes them, or use the literal phrase "nothing found". Carry honest open questions.

This is context building, not vulnerability hunting. Do not name vulnerabilities, propose fixes, write exploits, or assign severity. Return only JSON matching the supplied schema. `analysisMarkdown` must be the full prose deliverable following ANALYSIS_FORMAT.md; `analysisFile` must exactly equal the assigned path. The other fields are the compact native workflow record, not a prose summary.
