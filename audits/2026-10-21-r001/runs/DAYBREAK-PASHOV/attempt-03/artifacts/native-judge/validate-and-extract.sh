#!/bin/sh
set -eu

cell_root="/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation"
runtime_root="$cell_root/runtime/native-judge"
run_dir="$cell_root/.solidity-auditor/runs/20261021-005946"
response="$runtime_root/raw/judge-response.md"
events="$runtime_root/logs/judge.jsonl"
status_file="$runtime_root/logs/judge.status.tsv"

test -s "$response"
test "$(awk -F '\t' 'END { print $3 }' "$status_file")" = "0"
test "$(jq -r 'select(.type=="turn.completed") | .type' "$events" | wc -l | tr -d ' ')" = "1"
test "$(tail -n 1 "$events" | jq -r '.type')" = "turn.completed"
test "$(jq -r 'select(.type=="turn.failed" or .type=="error") | .type' "$events" | wc -l | tr -d ' ')" = "0"

test "$(grep -c '^=== GATE_DECISIONS_BEGIN ===$' "$response")" = "1"
test "$(grep -c '^=== GATE_DECISIONS_END ===$' "$response")" = "1"
test "$(grep -c '^=== COVERAGE_BEGIN ===$' "$response")" = "1"
test "$(grep -c '^=== COVERAGE_END ===$' "$response")" = "1"
test "$(grep -c '^=== RUN_FILE_BEGIN ===$' "$response")" = "1"
test "$(grep -c '^=== RUN_FILE_END ===$' "$response")" = "1"
test "$(sed -n '1p' "$response")" = "=== GATE_DECISIONS_BEGIN ==="
test "$(awk 'NF { line=$0 } END { print line }' "$response")" = "=== RUN_FILE_END ==="

awk '/^=== GATE_DECISIONS_BEGIN ===$/ { keep=1; next } /^=== GATE_DECISIONS_END ===$/ { keep=0; exit } keep' "$response" > "$runtime_root/gate-decisions.md"
awk '/^=== COVERAGE_BEGIN ===$/ { keep=1; next } /^=== COVERAGE_END ===$/ { keep=0; exit } keep' "$response" > "$runtime_root/coverage.md"
awk '/^=== RUN_FILE_BEGIN ===$/ { keep=1; next } /^=== RUN_FILE_END ===$/ { keep=0; exit } keep' "$response" > "$runtime_root/run-1.md"

# The assembler, not the model-written run block, owns sequential report numbering.
# Preserve the extraction, then remove only a redundant leading ordinal inside finding titles.
cp "$runtime_root/run-1.md" "$runtime_root/run-1.judge-extracted.md"
awk '
/^\[[0-9]+\] \*\*[0-9]+\. / {
  match($0, /^\[[0-9]+\] \*\*/)
  prefix = substr($0, 1, RLENGTH)
  rest = substr($0, RLENGTH + 1)
  sub(/^[0-9]+\. /, "", rest)
  print prefix rest
  next
}
{ print }
' "$runtime_root/run-1.judge-extracted.md" > "$runtime_root/run-1.md.part"
mv "$runtime_root/run-1.md.part" "$runtime_root/run-1.md"

test -s "$runtime_root/gate-decisions.md"
test -s "$runtime_root/coverage.md"
test -s "$runtime_root/run-1.md"
grep -Eq '^Completeness: [0-9]+ unique \(Contract, function\) in raw, [0-9]+ covered in final\.$' "$runtime_root/gate-decisions.md"

for required_file in \
  target/packages/contracts/src/Raffle.sol \
  target/packages/contracts/src/RaffleFactory.sol \
  target/packages/contracts/src/interfaces/IRaffle.sol \
  target/packages/contracts/src/interfaces/IRaffleFactory.sol \
  target/packages/contracts/src/libraries/RaffleConstants.sol
do
  grep -Fq "$required_file" "$runtime_root/coverage.md"
done

test "$(sed -n '1p' "$runtime_root/run-1.md")" = "# Run 1 — solidity-auditor"
grep -Fxq '<!--RUN pass=1 of=1 stamp=20261021-005946 sha=9238b6c agents=12/12-->' "$runtime_root/run-1.md"
test "$(grep -c '^## Findings$' "$runtime_root/run-1.md")" = "1"
test "$(grep -c '^## Leads$' "$runtime_root/run-1.md")" = "1"
test "$(grep -c '^<!--F ' "$runtime_root/run-1.md" || true)" = "$(grep -c '^<!--/F-->$' "$runtime_root/run-1.md" || true)"

awk '
/^<!--F / {
  open++
  line=$0
  if (line !~ / key=[a-z0-9-]+\|[a-z0-9-]+\|[a-z0-9-]+ /) bad++
  if (line ~ / kind=FINDING / && line !~ / conf=[0-9]+ /) bad++
  if (line ~ / kind=LEAD / && line ~ / conf=/) bad++
  if (line !~ / kind=(FINDING|LEAD) /) bad++
  if (line !~ / agents=[0-9]+-->$/) bad++
}
/^<!--\/F-->$/ { closes++ }
END { if (bad || open != closes) exit 1 }
' "$runtime_root/run-1.md"

if rg -n 'KNOWN|NEW|seen in [0-9]+/[0-9]+ runs|\*\*Memory\*\*' "$runtime_root/run-1.md" >/dev/null; then
  exit 1
fi

cp "$runtime_root/run-1.md" "$run_dir/run-1.md"
if ! awk -F '\t' '$1=="pass_1_agents" { found=1 } END { exit !found }' "$run_dir/scope.tsv"; then
  printf '%s\t%s\n' pass_1_agents 12/12 >> "$run_dir/scope.tsv"
fi

shasum -a 256 "$response" "$runtime_root/gate-decisions.md" "$runtime_root/coverage.md" "$run_dir/run-1.md" > "$runtime_root/judge-output-hashes.sha256"
