#!/bin/zsh
set -u

audit_output="/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03"
stage_output="$audit_output/artifacts/stages/05-spec-compliance"
cell_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation"
runner="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
schema="$stage_output/refutation.schema.json"

run_one() {
  local job="$1"
  local requirement_id="${job%-*}"
  local lens="${job##*-}"
  local prompt_file="$stage_output/prompts/refute-${job}.md"
  local output_file="$stage_output/refutations/${job}.json"
  local events_file="$stage_output/raw/refute/${job}.events.jsonl"
  local stderr_file="$stage_output/raw/refute/${job}.stderr.txt"
  local exit_file="$stage_output/raw/refute/${job}.exit-code.txt"
  local requirement_file="$stage_output/requirements.json"
  local record_file="$stage_output/records/${requirement_id}.json"
  local analysis_file="$stage_output/requirements/${requirement_id}.md"

  mkdir -p "$stage_output/raw/refute"

  {
    printf '%s\n\n' "Execute the Refute phase for exactly one candidate divergence in the pinned Trail of Bits spec-to-code-compliance workflow. Act as the independent ${lens} refuter. Do not assess any other requirement."
    printf '%s\n\n' "Route tuple: model gpt-daybreak-blue-latest; cyber access program daybreak_blue; reasoning effort ultra; fallback disabled. Provider identity is unknown unless events supply it. Frozen target SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155."
    printf '%s\n' "Requirement record:"
    jq -c --arg id "$requirement_id" '.requirements[] | select(.id == $id)' "$requirement_file"
    printf '\n%s\n' "Candidate alignment record:"
    jq -c . "$record_file"
    printf '\n%s\n' "Full candidate analysis: $analysis_file"
    printf '%s\n\n' "Read that full analysis before deciding."
    if [[ "$lens" == "code" ]]; then
      printf '%s\n\n' "CODE REFUTER LENS: Try to disprove the claimed divergence from the implementation side. Search for missed enforcement in callees, callers, modifiers, base contracts, constructors, type bounds, and all relevant branches. Check whether the cited code was misread. A matching name is not evidence. Cite exact file:line support in your reasoning."
    else
      printf '%s\n\n' "DOCUMENT REFUTER LENS: Try to disprove the claimed divergence from the specification side. Read target/DESIGN.md in full and test whether context, qualifiers, definitions, trust assumptions, or another section changes the requirement or makes the candidate's interpretation wrong. Quote the controlling document language and cite its exact lines."
    fi
    printf '%s\n\n' "Read in full: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/SKILL.md; /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/workflows/spec-compliance.js; /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/agents/spec-compliance-checker.md; and ANALYSIS_FORMAT.md, DOMAIN_NOTES.md, WORKED_EXAMPLE.md, DIVERGENCE_RUBRIC.md under /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/spec-to-code-compliance/skills/spec-to-code-compliance/resources/. Judge against target/DESIGN.md and the implementation under target: all five production files plus relevant files among the 31 dependencies in target/dependency-hashes.json."
    printf '%s\n\n' "Return only the JSON required by the supplied schema. Set refuted=true only if the candidate divergence should be dropped. If the divergence survives but needs a factual correction, use correction and revisedVerdict; otherwise use null."
    printf '%s\n' "Cold-stage boundary: do not read tests, scanners, prior audits, other cells, attempt-02, S2-S4 reports, other requirement records/refutations, or peer findings. Do not modify target/config/lock/freeze files. Multi-agent is disabled; never call collaboration/spawn/message/wait tools. Return directly."
  } > "$prompt_file"

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
    --output-schema "$schema" \
    -o "$output_file" \
    - < "$prompt_file" > "$events_file" 2> "$stderr_file"
  local run_status=$?
  printf '%s\n' "$run_status" > "$exit_file"
  return "$run_status"
}

if [[ "${1:-}" == "one" ]]; then
  run_one "$2"
  exit $?
fi

awk 'NF { print $0 "-code"; print $0 "-doc" }' "$stage_output/divergence-ids.txt" | xargs -n 1 -P 6 "$0" one
