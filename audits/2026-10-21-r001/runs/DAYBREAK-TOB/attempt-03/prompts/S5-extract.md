Execute the requirements-extraction barrier of the pinned Trail of Bits `spec-to-code-compliance` workflow for the same DAYBREAK-TOB cell. This is native extraction, not implementation analysis.

Route tuple: `gpt-daybreak-blue-latest`, `daybreak_blue`, reasoning `ultra`, fallback disabled; provider identity unknown if omitted. Frozen SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

Read in full:
- specification `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/DESIGN.md`;
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/SKILL.md`;
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/workflows/spec-compliance.js`;
- all four resources under `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/resources/`.

Extract every independently checkable implementation claim from DESIGN.md, quoted verbatim. Split compound claims even when several requirements must reuse the same full sentence as their verbatim quote. Use stable sequential IDs `REQ-01`, `REQ-02`, ... in document order. Set kind, force, and a concrete one-line `checkable` criterion. Do not inspect or judge the implementation in this extraction context. Do not turn the final meta-sentence about source determining actual behavior or the statement about materials not provided into implementation requirements; they define audit evidence precedence/scope.

Return only the JSON object required by REQUIREMENTS_SCHEMA. Do not edit anything, read tests/scanners/audits/other cells/peer reports, or call collaboration/spawn/message/wait tools.
