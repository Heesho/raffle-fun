# S5 continuation adapter

The actual spec-compliance.js at Trail of Bits pin 82fe8226252622fa807643bdca1710901198553a executes through the original disclosed host primitives. Its only source transformation is `export const meta =` to `const meta =` for AsyncFunction. Both originals and the one-token patch are retained.

The inherited invocation is `{path:"target",spec:"target/DESIGN.md",outDir:"audit/S5/spec-compliance",limit:4}`. Native ranking, fan-out limit, barriers, verification lenses, drop rules, schemas, and report prompt remain unchanged. The output directory resolves in the continuation workspace and is copied verbatim into this artifact directory. Native paths in responses remain unchanged for replay fidelity.

The primitive adapter adds byte equality checks for preserved request files, reuses completed responses 001 and 002, appends a separate continuation journal, and supports a terminal STOP marker. No inherited file or seal is rewritten. The host adapter diff is retained.

Each fresh request uses the explicitly recorded absolute Codex executable, `exec --ignore-user-config --ephemeral --skip-git-repo-check -s danger-full-access -m gpt-6-astra -c model_reasoning_effort="ultra" -c features.multi_agent=false --json`, plus absolute CWD, input/output/schema paths. No cyber access program is specified and no model fallback exists. Provider-returned model/effort are unknown unless actually present in response metadata. Native low/medium effort requests are overridden by the user's explicit ultra mandate.

The typed checker is resolved by including the exact pinned checker text and every referenced skill resource in each fresh context. The local shell/apply_patch capabilities implement the upstream Write primitive. Every request keeps its unchanged native prompt/schema and exact CLI prompt, command, raw JSONL, stderr, final JSON, normalized response, and completion metadata.

Strict structured output requires every object property to be required and additionalProperties=false. The CLI-only schema therefore wraps native optional properties in an anyOf with null, and the controller removes null object properties before validating with the unchanged native schema. No substantive field is generated, edited, or judged by the adapter.

The controller schedules at most four independent fresh CLI processes at once; this limits runtime concurrency only, not native requirement selection. Genuine cybersecurity refusal stops the affected stage without retry/rephrasing/rerouting. Local/runtime errors are retained for classification and may be repaired, with attempts preserved. Source-only boundaries prohibit test/scanner/compiler/fuzzer results and historical audit material. Resource hashing, schema validation, replay equality, and immutability checks are local execution integrity checks, not target behavioral tests.

The inherited outDir is resolved through the symlink continuation/audit/S5/spec-compliance → attempt-02/S5/native-output/spec-compliance. Thus native analysis/report writes land directly in the authorized artifact root. The spec-compliance directory here is an exact publication mirror. Controller request/response/journal state remains under continuation/audit/S5.
