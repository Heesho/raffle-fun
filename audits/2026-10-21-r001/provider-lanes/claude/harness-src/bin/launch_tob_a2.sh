#!/bin/bash
RT=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude; T=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/harness/trailofbits/plugins
python3 $RT/bin/run_cell.py CLAUDE-TOB/S1 attempt-02 --prompt-file $RT/prompts/CLAUDE-TOB-S1-a2.txt --plugin-dir $T/audit-context-building --preserve-glob 'TOB-*.md' --preserve-glob audit-context > $RT/logs/CLAUDE-TOB-S1-attempt-02.log 2>&1 &
python3 $RT/bin/run_cell.py CLAUDE-TOB/S5 attempt-02 --prompt-file $RT/prompts/CLAUDE-TOB-S5-a2.txt --plugin-dir $T/spec-to-code-compliance --preserve-glob 'TOB-*.md' --preserve-glob spec-compliance > $RT/logs/CLAUDE-TOB-S5-attempt-02.log 2>&1 &
wait
