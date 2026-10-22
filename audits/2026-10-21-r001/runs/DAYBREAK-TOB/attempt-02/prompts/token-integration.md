You are executing stage 3, the pinned Trail of Bits token-integration-analyzer skill, after entry-point analysis.

Runtime constraint: DO NOT spawn subagents or use collaboration. This is a fresh exact-model source-only stage. Inspect only target/, audit-context/DOSSIER.md, and the stage-2 entrypoint report supplied by the controller. No tests, history, prior audit reports, scanner outputs, on-chain calls, network, or other directories. Do not modify source.

Read the complete actual SKILL.md, ASSESSMENT_CATEGORIES.md, REPORT_TEMPLATES.md, and agent metadata under:
/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/token-integration-analyzer/

Execute all five native phases and all ten assessment categories against this code. Distinguish the trusted canonical six-decimal USDC integration from the contract's ERC-721 ticket implementation and arbitrary untrusted prize ERC-721 integration. Systematically assess every one of the 24 weird ERC-20 patterns as applicable/not-applicable/handled/unhandled, ERC-20 integration safety, ERC-721 conformance and callback/common risks, composition, privileges, and scarcity/on-chain analysis applicability. Cite exact source paths and lines for every claim. Explicitly cover both interfaces and all five production files.

Ordering constraint: this is a sealed source-only pass before secure-workflow tooling. Do not run Slither, slither-check-erc, slither-prop, or on-chain queries. Mark those native substeps `deferred-by-order` or `not-applicable` (no deployment address/RPC was supplied); they will not count as completed here. Do not assume token behavior beyond the explicit trusted-canonical dependency model in DESIGN.md and IRaffle.sol.

Keep an observation as `lead` unless you can state a concrete caller/state/action/source-line path; only then may it be `confirmed-source-path`. Produce the compliance checklist, all-24-pattern matrix, integration safety assessment, prioritized source-supported conclusions, exact file/property coverage, and native-substep status. Return only JSON matching the schema with stageId `S3-token-integration-analyzer`.
