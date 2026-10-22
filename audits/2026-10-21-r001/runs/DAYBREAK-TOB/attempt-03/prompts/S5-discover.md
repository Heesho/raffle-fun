Execute the Extract/discovery phase of the pinned Trail of Bits `spec-to-code-compliance` workflow for the same DAYBREAK-TOB cell. This is a structured native workflow step, not a generic review.

Route tuple: `gpt-daybreak-blue-latest`, `daybreak_blue`, `model_reasoning_effort=ultra`, fallback disabled; provider identity unknown if absent from events. Frozen SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

Root: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target`.
Explicit authoritative specification hint: `target/DESIGN.md`.
Implementation: all five production files and the 31 dependencies in `target/dependency-hashes.json`.

Read in full before acting:
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/SKILL.md`
- `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/workflows/spec-compliance.js`

Follow DISCOVERY_SCHEMA exactly. Find documents that independently state intended behavior. `DESIGN.md` is the supplied clean specification. Production interface NatSpec is part of the implementation being judged and may corroborate or contradict the design, but do not treat those same implementation files as a separate authoritative spec input; doing so would check code documentation against itself. Return only the JSON object required by the output schema.

Do not read tests, scanner output, audit history, attempt-02, peer-stage reports, or other cells. Do not edit anything. Do not call collaboration/spawn/message/wait tools; return directly.
