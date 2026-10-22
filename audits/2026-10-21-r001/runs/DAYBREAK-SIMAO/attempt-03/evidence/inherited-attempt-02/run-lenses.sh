#!/bin/zsh
set -u

runner_bin=/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex
work_dir=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-attempt-02
runner_home=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runner-home
typeset -a stage_pids

for lens_id in {1..12}; do
  (
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
      -o ".audit-evidence/raw/lenses/lens-${lens_id}-response.md" \
      - < ".audit-evidence/prompts/lens-${lens_id}.txt" \
      > ".audit-evidence/raw/lenses/lens-${lens_id}-events.jsonl" \
      2> ".audit-evidence/raw/lenses/lens-${lens_id}-stderr.txt"
    stage_status=$?
    print -r -- "$stage_status" > ".audit-evidence/raw/lenses/lens-${lens_id}-exit.txt"
  ) &
  stage_pids+=("$!")
done

for stage_pid in "${stage_pids[@]}"; do
  wait "$stage_pid"
done
