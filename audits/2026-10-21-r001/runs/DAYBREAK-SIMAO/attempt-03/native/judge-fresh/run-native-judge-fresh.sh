#!/bin/zsh
set -u

date -u +%Y-%m-%dT%H:%M:%SZ > /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/started-at.txt

env CODEX_HOME=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runner-home \
  /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec \
  --ignore-user-config \
  --ephemeral \
  --skip-git-repo-check \
  -s danger-full-access \
  -C /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation \
  -m gpt-daybreak-blue-latest \
  --cyber-access-program daybreak_blue \
  -c 'model_reasoning_effort="ultra"' \
  -c features.multi_agent=false \
  --json \
  -o /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/native-judge-response.md \
  - \
  < /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/.audit-evidence/prompts/native-judge.txt \
  > /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/native-judge-events.jsonl \
  2> /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/native-judge-stderr.txt

stage_status=$?
print -r -- "$stage_status" > /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/native-judge-exit.txt
date -u +%Y-%m-%dT%H:%M:%SZ > /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/native/judge-fresh/finished-at.txt
exit "$stage_status"
