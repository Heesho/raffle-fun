#!/bin/sh
set -eu

runtime_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation/runtime/native-judge"
previous_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-attempt-02/.audit-gDK92V"
method_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/pashov/solidity-auditor"
bundle_part="$runtime_root/judge-bundle.md.part"
bundle="$runtime_root/judge-bundle.md"

: > "$bundle_part"
printf '%s\n\n' '# DAYBREAK-PASHOV native Turn 4 judge bundle' >> "$bundle_part"
printf '%s\n' 'This bundle contains only the frozen source-first-pass context, the accepted corrected specialist final responses, and the pinned native method resources.' >> "$bundle_part"
printf '%s\n\n' 'The initial specialist wave is deliberately excluded because the controller superseded it. Memory and known-finding context are off.' >> "$bundle_part"

printf '%s\n\n' '# PINNED SKILL.md' >> "$bundle_part"
cat "$method_root/SKILL.md" >> "$bundle_part"
printf '\n%s\n\n' '# PINNED dedup-and-assembly.md' >> "$bundle_part"
cat "$method_root/references/dedup-and-assembly.md" >> "$bundle_part"
printf '\n%s\n\n' '# PINNED judging.md' >> "$bundle_part"
cat "$method_root/references/judging.md" >> "$bundle_part"
printf '\n%s\n\n' '# PINNED report-formatting.md' >> "$bundle_part"
cat "$method_root/references/report-formatting.md" >> "$bundle_part"
printf '\n%s\n\n' '# PINNED report-language.md' >> "$bundle_part"
cat "$method_root/references/report-language.md" >> "$bundle_part"
printf '\n%s\n\n' '# FROZEN SOURCE, CLEAN DESIGN, INTERFACES, AND REACHABLE DEPENDENCIES' >> "$bundle_part"
cat "$previous_root/source.md" >> "$bundle_part"

for agent_number in 1 2 3 4 5 6 7 8 9 10 11 12; do
  printf '\n# ACCEPTED CORRECTED SPECIALIST %s FINAL RESPONSE\n\n' "$agent_number" >> "$bundle_part"
  cat "$previous_root/raw/agent-$agent_number-valid.md" >> "$bundle_part"
  printf '\n' >> "$bundle_part"
done

mv "$bundle_part" "$bundle"
shasum -a 256 "$bundle" > "$runtime_root/judge-bundle.sha256"
wc -l -c "$bundle" > "$runtime_root/judge-bundle.size"
