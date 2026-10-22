#!/usr/bin/env bash
# Mutation analysis: run the spec test-suite (A-F unit/fuzz, handler sanity, invariant campaign) against each mutant.
# Each mutant gets its own Foundry project that symlinks the harness src/test and remaps `raffle/` to the mutant copy.
set -u
ART="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"
OUT="$ART/step4/mutation-results.txt"
: > "$OUT"
for M in $(ls "$ART/mutants" | grep '^M'); do
  d="$ART/mutant-runs/$M"; mkdir -p "$d"
  ln -sfn ../../harness/src "$d/src"; ln -sfn ../../harness/test "$d/test"
  cat > "$d/foundry.toml" <<TOML
[profile.default]
src = "src"
test = "test"
out = "out"
cache_path = "cache"
libs = []
solc_version = "0.8.36"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = false
offline = true
allow_paths = ["../../../packages", "../../mutants", "../../harness"]
remappings = [
  "@openzeppelin/contracts/=../../../packages/contracts/node_modules/@openzeppelin/contracts/",
  "@chainlink/contracts/=../../../packages/contracts/node_modules/@chainlink/contracts/",
  "raffle/=../../mutants/$M/src/",
]
code_size_limit = 1_000_000
fuzz = { runs = 300, seed = "0x4d555441" }
invariant = { runs = 120, depth = 100, fail_on_revert = false }
TOML
  log="$d/forge-test.log"
  ( cd "$d" && forge test --no-match-contract "RaffleCanaryTest|G_FindingsTest" > "$log" 2>&1 )
  rc=$?
  # sanity: confirm the mutant source was really compiled (remapping took effect)
  used=$(grep -c "mutants/$M/src/Raffle.sol" "$d/cache/solidity-files-cache.json" 2>/dev/null || echo 0)
  fails=$(grep -E '^\[FAIL' "$log" | sed -E 's/\[FAIL[^]]*\] *//; s/\(.*//' | sort -u | tr '\n' ' ')
  if [ $rc -ne 0 ] && [ -n "$fails" ]; then verdict=KILLED; elif [ $rc -ne 0 ]; then verdict="ERROR(rc=$rc)"; else verdict=SURVIVED; fi
  echo "$M | $verdict | mutant-compiled=$used | failing: ${fails:-none}" | tee -a "$OUT"
done
