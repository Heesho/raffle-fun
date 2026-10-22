#!/bin/zsh
set -eu

stage="/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance"
expected_ids="$(jq -r '.requirements[].id' "$stage/requirements.json" | sort)"
record_ids="$(find "$stage/records" -type f -name 'REQ-*.json' -exec basename {} .json \; | sort)"
analysis_ids="$(find "$stage/requirements" -type f -name 'REQ-*.md' -exec basename {} .md \; | sort)"

[[ "$record_ids" == "$expected_ids" ]] || { print -u2 'record ID set differs from extracted requirements'; exit 1; }
[[ "$analysis_ids" == "$expected_ids" ]] || { print -u2 'analysis ID set differs from extracted requirements'; exit 1; }

for id in ${(f)expected_ids}; do
  jq -e --arg id "$id" '
    .requirementId == $id and
    (.analysisFile | type == "string") and
    (.verdict | IN("implemented", "partial", "contradicted", "absent", "stronger-than-spec", "undecidable")) and
    (.confidence | IN("high", "medium", "low")) and
    (.searched | type == "array" and length > 0) and
    (.reasoning | type == "string" and length > 0)
  ' "$stage/records/$id.json" >/dev/null
  [[ -s "$stage/requirements/$id.md" ]] || { print -u2 "empty analysis: $id"; exit 1; }
  [[ "$(cat "$stage/raw/align/$id.exit-code.txt")" == 0 ]] || { print -u2 "nonzero align exit: $id"; exit 1; }
  rg -q '"type":"turn.completed"' "$stage/raw/align/$id.events.jsonl" || { print -u2 "no completed turn: $id"; exit 1; }
done

nonimplemented="$(for f in "$stage"/records/REQ-*.json; do [[ "$(jq -r .verdict "$f")" == implemented ]] || basename "$f" .json; done | sort)"
for id in ${(f)nonimplemented}; do
  for lens in code doc; do
    f="$stage/refutations/$id-$lens.json"
    [[ -s "$f" ]] || { print -u2 "missing refutation: $id-$lens"; exit 1; }
    jq -e '(.refuted | type == "boolean") and (.reasoning | type == "string" and length > 0)' "$f" >/dev/null
    [[ "$(cat "$stage/raw/refute/$id-$lens.exit-code.txt")" == 0 ]] || { print -u2 "nonzero refutation exit: $id-$lens"; exit 1; }
    rg -q '"type":"turn.completed"' "$stage/raw/refute/$id-$lens.events.jsonl" || { print -u2 "no completed refutation turn: $id-$lens"; exit 1; }
  done
done

jq -e '.behaviors | type == "array"' "$stage/undocumented.json" >/dev/null
[[ "$(cat "$stage/raw/undocumented.exit-code.txt")" == 0 ]]
rg -q '"type":"turn.completed"' "$stage/raw/undocumented.events.jsonl"

printf 'requirements=%s\n' "$(print -r -- "$expected_ids" | wc -l | tr -d ' ')"
printf 'records=%s\n' "$(print -r -- "$record_ids" | wc -l | tr -d ' ')"
printf 'analyses=%s\n' "$(print -r -- "$analysis_ids" | wc -l | tr -d ' ')"
printf 'nonimplemented=%s\n' "$(print -r -- "$nonimplemented" | sed '/^$/d' | wc -l | tr -d ' ')"
printf 'refutations=%s\n' "$(find "$stage/refutations" -type f -name 'REQ-*.json' | wc -l | tr -d ' ')"
printf 'undocumented=%s\n' "$(jq '.behaviors | length' "$stage/undocumented.json")"
