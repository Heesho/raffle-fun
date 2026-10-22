Execute the pinned Trail of Bits secure-workflow-guide literally and completely as native stage S6 of the authorized DAYBREAK-TOB audit.

Route tuple: model gpt-daybreak-blue-latest; cyber access program daybreak_blue; reasoning effort ultra; fallback disabled; multi-agent disabled. Provider identity is unknown unless an actual provider event supplies it. Frozen target SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155.

Read in full before acting:
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/SKILL.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/resources/WORKFLOW_STEPS.md
- /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/resources/EXAMPLE_REPORT.md
- permitted same-cell context dossier: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md

Work only on the isolated copy at:
/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/.audit-runtime/secure-workflow/target

The isolated copy was byte-verified against the 43-file frozen target immediately after the immutable source-first-pass seal. You may add tests, mocks, configs, build artifacts, and analysis files inside this isolated runtime only. Never modify the frozen target, production repository, configs/locks/freeze, FIRST-PASS.md, its detached hash/timestamp, or SEAL.json.

Write all persistent S6 evidence under:
/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/

Create and populate tool-output/, diagrams/, properties/, tests/, and logs/ there as needed. Preserve exact commands, versions, exit codes, stdout, stderr, generated DOT/PNG/PDF artifacts, test sources, configs, and machine-readable results. Copy created test/property sources from the isolated runtime into the S6 evidence tree without deleting runtime originals.

Environment facts you must use rather than rediscover as blockers:
- Forge exists at /Users/hishamel-husseini/.foundry/bin/forge.
- Slither and slither-check-erc exist under /opt/homebrew/bin.
- Docker exists under /opt/homebrew/bin/docker.
- A functioning Docker daemon is at unix:///Users/hishamel-husseini/.lima/gebal/sock/docker.sock; export DOCKER_HOST to that exact value for container commands.
- Graphviz dot and echidna-test were not on PATH at preflight. The user authorized local tool installation and defensive containers. Install/use them locally or through the working Docker daemon when needed; do not treat the missing default command or default Docker socket as a final blocker.
- No live transactions, broadcasting, service purchase, publishing, or production remediation is authorized.

Execute every native step, in order:

STEP 1 — Known security issues
- In the isolated packages/contracts root, run the actual `slither . --exclude-dependencies` scan.
- Repair local compiler/path/config failures and rerun. Preserve every attempt.
- Parse and triage every detector result by severity with exact source lines; distinguish confirmed, conditional, false positive, and informational.

STEP 2 — Special features
- Explicitly search for proxy/upgrade patterns before marking upgradeability not applicable.
- Raffle inherits ERC-721 behavior; run the applicable actual `slither-check-erc` ERC-721 conformance command(s), repairing local invocation issues and preserving attempts. If the tool cannot soundly check this clone/constructor arrangement, document exact command/output and supplement it with an explicit conformance matrix rather than silently skipping.
- Verify token interactions and third-party wrapper integration in source without reading the sealed token-stage report.
- Determine whether slither-prop applies. If it does not because this is not an ERC-20 implementation/Truffle project, prove that with source/tool evidence and cover project-specific properties in Step 4.

STEP 3 — Visual security inspection
- Execute actual Slither printers for inheritance-graph, function-summary, and vars-and-auth.
- Preserve raw outputs. Produce actual visual artifacts from DOT with Graphviz, installing or using a container if needed. A prose-only substitute is not acceptable.
- Review each artifact for shadowing/linearization, callable surfaces/access controls, and state-writer authorization.

STEP 4 — Security properties and testing
- Write a project-specific security property document covering lifecycle transitions, access controls, liability conservation, fee arithmetic/rounding, draw/callback timing, ticket ownership/burn semantics, reentrancy/external calls, ERC conformance, destination isolation, and untrusted prize/recipient behavior.
- Set up executable project-specific property/fuzz/invariant testing in the isolated copy. Foundry fuzz/invariant tests are acceptable as the native controller adaptation because this repository is Foundry-configured; Echidna is also encouraged if it can be installed/containerized. Do not merely recommend future fuzzing.
- Include adversarial mocks needed to test malformed/malicious ERC-721 prize semantics, incompatible contract recipients, callbacks/reentrancy, fee-on-transfer/nonstandard quote behavior where constructible, timing boundaries, accounting conservation, and cross-raffle destination invariants.
- Run the tests with deterministic seeds and meaningful run/depth counts. Preserve exact output and failures. A failing property is evidence, not permission to edit production code; reproduce/minimize it in the isolated copy only.
- Do not use existing project tests or historical test corpora; create this stage's tests from the frozen source and DESIGN.md only.

STEP 5 — Manual review
- Complete explicit source searches and analysis for privacy, front-running/ordering/MEV, cryptography/randomness/signatures/hashes, and DeFi/oracle/flash-loan/protocol assumptions. Mark N/A only after the required search evidence.

Final native S6 report requirements:
- Return a complete Markdown report as your final response; it will be captured verbatim as the stage REPORT.md.
- Cover all five steps, tool versions/commands/exit codes, all detector/check/printer/test outputs, diagram review, property matrix, fuzz/invariant results, manual areas, findings with exact file:line evidence, false-positive triage, limitations, unresolved leads, prioritized action plan, and workflow checklist.
- Give per-file coverage for all five production files and all 31 dependencies, and per-property/result coverage for every property you implemented or manually checked.
- Clearly label any controller adaptations (Foundry instead of Echidna/Manticore, Graphviz installation/container, compiler remapping fixes) and any unexecuted item with the exact technical reason after exhausting local remedies.
- State exact route evidence and provider identity unknown; do not claim a provider-returned model from the prompt.
- Do not read or cite FIRST-PASS.md, S2-S5 reports, attempt-02, other cells, peer findings, historical audits/tests/corpora, scanner campaigns, accepted risks, or reconciliation. This stage must independently derive its tool and manual conclusions from the dossier, DESIGN.md, source, and its own generated tool/test evidence.
- Do not call collaboration/spawn/message/wait tools. Return directly.
