#!/bin/bash
RT=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude; T=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/harness/trailofbits/plugins
run(){ python3 $RT/bin/run_cell.py CLAUDE-TOB/$1 attempt-01 --prompt-file $RT/prompts/CLAUDE-TOB-$1.txt --plugin-dir $2 --preserve-glob 'TOB-*.md' --preserve-glob audit-context --preserve-glob spec-compliance --preserve-glob crytic-export > $RT/logs/CLAUDE-TOB-$1-attempt-01.log 2>&1 & }
run S1 $T/audit-context-building
run S2 $T/entry-point-analyzer
run S3 $T/building-secure-contracts
run S4 $T/building-secure-contracts
run S5 $T/spec-to-code-compliance
run S6 $T/building-secure-contracts
wait
