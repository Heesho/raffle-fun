#!/bin/zsh
set -eu
AUDIT_ROOT=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-attempt-02
printf '[' > "$AUDIT_ROOT/artifacts/stages/context-records.json"
FIRST=1
for LAST in "$AUDIT_ROOT"/artifacts/raw/context-functions/*.last.json; do
  [[ -f "$LAST" ]] || continue
  if [[ $FIRST -eq 0 ]]; then printf ',' >> "$AUDIT_ROOT/artifacts/stages/context-records.json"; fi
  jq 'del(.analysisMarkdown)' "$LAST" >> "$AUDIT_ROOT/artifacts/stages/context-records.json"
  FIRST=0
done
printf ']\n' >> "$AUDIT_ROOT/artifacts/stages/context-records.json"

cp "$AUDIT_ROOT/prompts/context-synthesize-base.md" "$AUDIT_ROOT/prompts/generated/context-synthesize.md"
{
  print -r -- ''
  print -r -- 'ORIENTATION JSON:'
  cat "$AUDIT_ROOT/artifacts/raw/context-orient.last.json"
  print -r -- ''
  print -r -- 'PER-FUNCTION COMPACT RECORDS JSON:'
  cat "$AUDIT_ROOT/artifacts/stages/context-records.json"
} >> "$AUDIT_ROOT/prompts/generated/context-synthesize.md"
