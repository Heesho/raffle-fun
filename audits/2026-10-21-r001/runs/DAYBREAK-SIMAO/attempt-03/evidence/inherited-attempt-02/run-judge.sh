#!/bin/zsh
set -u

runner_bin=/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex
work_dir=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-attempt-02
runner_home=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runner-home

env CODEX_HOME="$runner_home" "$runner_bin" exec \
  --ignore-user-config \
  --ignore-rules \
  --ephemeral \
  --skip-git-repo-check \
  -s read-only \
  -C "$work_dir" \
  -m gpt-daybreak-blue-latest \
  --cyber-access-program daybreak_blue \
  -c 'model_reasoning_effort="ultra"' \
  -c features.multi_agent=false \
  --json \
  -o .audit-evidence/raw/gates/native-judge-response.md \
  - < .audit-evidence/prompts/native-judge.txt \
  > .audit-evidence/raw/gates/native-judge-events.jsonl \
  2> .audit-evidence/raw/gates/native-judge-stderr.txt
stage_status=$?
print -r -- "$stage_status" > .audit-evidence/raw/gates/native-judge-exit.txt
exit "$stage_status"
