#!/bin/zsh
set -u

AUDIT_CLI=/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex
AUDIT_ROOT=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-attempt-02
mkdir -p "$AUDIT_ROOT/artifacts/raw/context-functions" "$AUDIT_ROOT/artifacts/logs/context-functions" "$AUDIT_ROOT/prompts/generated" "$AUDIT_ROOT/audit-context/functions"

SYSTEM_CONTEXT=$(jq -c '{language,actors,entrypoints,state}' "$AUDIT_ROOT/artifacts/raw/context-orient.last.json")

for INDEX in {0..11}; do
  NUMBER=$(printf '%02d' $((INDEX + 1)))
  CANDIDATE=$(jq -c ".candidates[$INDEX]" "$AUDIT_ROOT/artifacts/raw/context-orient.last.json")
  NAME=$(print -r -- "$CANDIDATE" | jq -r '.name')
  SLUG=$(print -r -- "$NAME" | sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)
  ANALYSIS_FILE="audit-context/functions/${NUMBER}-${SLUG}.md"
  PROMPT="$AUDIT_ROOT/prompts/generated/context-function-${NUMBER}.md"
  cp "$AUDIT_ROOT/prompts/context-function-base.md" "$PROMPT"
  {
    print -r -- ''
    print -r -- "Assigned candidate: $CANDIDATE"
    print -r -- "Native orientation context: $SYSTEM_CONTEXT"
    print -r -- "Assigned analysisFile: $ANALYSIS_FILE"
  } >> "$PROMPT"

  "$AUDIT_CLI" exec --ephemeral --ignore-user-config --ignore-rules --disable shell_snapshot --disable apps --disable plugins --skip-git-repo-check \
    -c features.multi_agent=false -c agents.max_threads=1 -s read-only -C "$AUDIT_ROOT" \
    -m gpt-daybreak-blue-latest --cyber-access-program daybreak_blue -c 'model_reasoning_effort="ultra"' \
    --output-schema "$AUDIT_ROOT/harness/function-record-schema.json" --json \
    -o "$AUDIT_ROOT/artifacts/raw/context-functions/${NUMBER}-${SLUG}.last.json" - \
    < "$PROMPT" \
    > "$AUDIT_ROOT/artifacts/raw/context-functions/${NUMBER}-${SLUG}.jsonl" \
    2> "$AUDIT_ROOT/artifacts/raw/context-functions/${NUMBER}-${SLUG}.stderr" &
  print -r -- "$!\t$NUMBER\t$SLUG\t$ANALYSIS_FILE" >> "$AUDIT_ROOT/artifacts/logs/context-functions/pids.tsv"
done

wait

for LAST in "$AUDIT_ROOT"/artifacts/raw/context-functions/*.last.json; do
  [[ -f "$LAST" ]] || continue
  ANALYSIS_FILE=$(jq -r '.analysisFile' "$LAST")
  jq -r '.analysisMarkdown' "$LAST" > "$AUDIT_ROOT/$ANALYSIS_FILE"
done
