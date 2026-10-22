#!/bin/zsh
set -u

audit_output="/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03"
stage_output="$audit_output/artifacts/stages/05-spec-compliance"
cell_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation"
runner="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
requirements_json="$stage_output/requirements.json"
alignment_schema="$stage_output/alignment.schema.json"

run_one() {
  local requirement_id="$1"
  local analysis_file="$stage_output/requirements/${requirement_id}.md"
  local prompt_file="$stage_output/prompts/align-${requirement_id}.md"
  local record_file="$stage_output/records/${requirement_id}.json"
  local events_file="$stage_output/raw/align/${requirement_id}.events.jsonl"
  local stderr_file="$stage_output/raw/align/${requirement_id}.stderr.txt"
  local exit_file="$stage_output/raw/align/${requirement_id}.exit-code.txt"

  jq -r --arg requirement_id "$requirement_id" --arg analysis_file "$analysis_file" '
    .requirements[] | select(.id == $requirement_id) |
    "Execute the Align phase for exactly one requirement in the pinned Trail of Bits spec-to-code-compliance workflow. This is one native per-requirement checker context; do not review any other requirement.\n\n" +
    "Route tuple: model gpt-daybreak-blue-latest; cyber access program daybreak_blue; reasoning effort ultra; fallback disabled. Provider identity is unknown unless events supply it. Frozen target SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155.\n\n" +
    "Requirement record (quote must remain verbatim):\n" + (tojson) + "\n\n" +
    "Read the specification at /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/DESIGN.md and judge the implementation under that target root: all five production files plus all 31 dependencies in target/dependency-hashes.json. Read the inherited dossier at /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md as permitted system context.\n\n" +
    "Before judging, read in full: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/agents/spec-compliance-checker.md; the pinned SKILL.md; workflows/spec-compliance.js; and ANALYSIS_FORMAT.md, DOMAIN_NOTES.md, WORKED_EXAMPLE.md, DIVERGENCE_RUBRIC.md under that skill resources directory.\n\n" +
    "Follow enforcement through callees, callers, modifiers, base contracts, constructors, type bounds, and every relevant branch. A name is not evidence. Vary vocabulary and record exact search results before an absent verdict. Cite every code claim as file and line and quote the document verbatim. Judge only this requirement, using one of implemented, partial, contradicted, absent, stronger-than-spec, undecidable.\n\n" +
    "Write the full native per-requirement Markdown analysis, in the exact ANALYSIS_FORMAT section order, to " + $analysis_file + " using apply_patch. Then return only the compact JSON record required by ALIGNMENT_SCHEMA, with analysisFile set to that exact absolute path. Use null for documentProblem when none.\n\n" +
    "Cold-stage boundary: do not read tests, scanners, prior audits, other cells, attempt-02, S2-S4 reports, other requirement records, or peer findings. Do not modify target/config/lock/freeze files. Multi-agent is disabled; never call collaboration/spawn/message/wait tools. Return directly."
  ' "$requirements_json" > "$prompt_file"

  TMPDIR="$cell_root/.audit-runtime/tmp" "$runner" exec \
    --ignore-user-config \
    --ephemeral \
    --skip-git-repo-check \
    -s danger-full-access \
    -C "$cell_root" \
    -m gpt-daybreak-blue-latest \
    --cyber-access-program daybreak_blue \
    -c 'model_reasoning_effort="ultra"' \
    -c features.multi_agent=false \
    --json \
    --output-schema "$alignment_schema" \
    -o "$record_file" \
    - < "$prompt_file" > "$events_file" 2> "$stderr_file"
  local run_status=$?
  printf '%s\n' "$run_status" > "$exit_file"
  return "$run_status"
}

if [[ "${1:-}" == "one" ]]; then
  run_one "$2"
  exit $?
fi

jq -r '.requirements[].id' "$requirements_json" | xargs -n 1 -P 6 "$0" one
