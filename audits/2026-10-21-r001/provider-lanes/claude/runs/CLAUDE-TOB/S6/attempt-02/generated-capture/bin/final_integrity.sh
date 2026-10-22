#!/bin/bash
# Generated scratch helper (S6 attempt-02): final source-integrity verification.
#  1. every pre-existing original file re-hashed and compared with the baseline manifest taken before any tool ran
#  2. original tree listing compared (detects new/removed files such as out/, cache/, lib/ in packages/contracts)
#  3. dependency-hashes.json re-verified
#  4. every isolated harness copy's production sources compared with the originals
set -u
W="$1"
cd "$W" || exit 2
EV=evidence/99-integrity
rc=0
echo "final_check_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
find . -path ./evidence -prune -o -path ./_generated -prune -o -name 'TOB-S6-secure-workflow-guide.md' -prune -o -type f -print \
  | LC_ALL=C sort | while read -r f; do shasum -a 256 "$f"; done > $EV/final-sha256-all-original-files.txt
if diff $EV/baseline-sha256-all-original-files.txt $EV/final-sha256-all-original-files.txt > $EV/final-vs-baseline.diff; then
  echo "[OK] all $(wc -l < $EV/baseline-sha256-all-original-files.txt | tr -d ' ') original files byte-identical to baseline"
else
  echo "[FAIL] original files changed:"; cat $EV/final-vs-baseline.diff; rc=1
fi
find . -path ./evidence -prune -o -path ./_generated -prune -o -name 'TOB-S6-secure-workflow-guide.md' -prune -o \( -type f -o -type d -o -type l \) -print \
  | LC_ALL=C sort > $EV/final-tree-listing.txt
if diff $EV/baseline-tree-listing.txt $EV/final-tree-listing.txt > $EV/final-tree-vs-baseline.diff; then
  echo "[OK] original tree listing unchanged ($(wc -l < $EV/final-tree-listing.txt | tr -d ' ') entries; no out/, cache/, lib/ or other new paths)"
else
  echo "[FAIL] original tree changed:"; cat $EV/final-tree-vs-baseline.diff; rc=1
fi
if /opt/homebrew/bin/python3.11 -I _generated/bin/verify_dep_hashes.py "$W" > $EV/final-dependency-hash-verification.txt; then
  echo "[OK] $(tail -1 $EV/final-dependency-hash-verification.txt)"
else
  echo "[FAIL] dependency manifest mismatch"; tail -3 $EV/final-dependency-hash-verification.txt; rc=1
fi
(cd packages/contracts && find src node_modules -type f | LC_ALL=C sort | xargs shasum -a 256) > /tmp/s6a2_final_orig.txt
for d in harness harness-upgradeability-model harness-slither-prop harness-props run-echidna-property run-echidna-assertion run-medusa run-halmos; do
  if [ -d "_generated/$d" ]; then
    (cd "_generated/$d" && find src node_modules -type f -not -path 'src/generated-model/*' | LC_ALL=C sort | xargs shasum -a 256) > /tmp/s6a2_final_$d.txt
    if diff -q /tmp/s6a2_final_$d.txt /tmp/s6a2_final_orig.txt > /dev/null; then
      echo "[OK] _generated/$d production sources+deps byte-identical to originals ($(wc -l < /tmp/s6a2_final_$d.txt | tr -d ' ') files)"
    else
      echo "[FAIL] _generated/$d differs"; rc=1
    fi
  fi
done
echo "five_production_files_final_sha256:"
shasum -a 256 packages/contracts/src/Raffle.sol packages/contracts/src/RaffleFactory.sol packages/contracts/src/interfaces/IRaffle.sol \
  packages/contracts/src/interfaces/IRaffleFactory.sol packages/contracts/src/libraries/RaffleConstants.sol packages/contracts/foundry.toml DESIGN.md
exit $rc
