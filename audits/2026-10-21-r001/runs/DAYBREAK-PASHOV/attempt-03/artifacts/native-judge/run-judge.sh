#!/bin/sh
set -u

runtime_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation/runtime/native-judge"
cell_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation"
runner_home="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runner-home"
codex_bin="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
prompt_file="$runtime_root/judge-prompt.txt"
output_file="$runtime_root/raw/judge-response.md"
events_file="$runtime_root/logs/judge.jsonl"
stderr_file="$runtime_root/logs/judge.stderr"
status_file="$runtime_root/logs/judge.status.tsv"
command_file="$runtime_root/logs/judge.command.txt"

printf '%s\n' "env CODEX_HOME=$runner_home $codex_bin exec --ignore-user-config --ephemeral --skip-git-repo-check -s danger-full-access -C $cell_root -m gpt-daybreak-blue-latest --cyber-access-program daybreak_blue -c model_reasoning_effort=\"ultra\" -c features.multi_agent=false --json -o $output_file - < $prompt_file" > "$command_file"
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
env CODEX_HOME="$runner_home" "$codex_bin" exec \
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
  -o "$output_file" \
  - < "$prompt_file" > "$events_file" 2> "$stderr_file"
status=$?
finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t%s\t%s\n' "$started_at" "$finished_at" "$status" > "$status_file"
exit "$status"
