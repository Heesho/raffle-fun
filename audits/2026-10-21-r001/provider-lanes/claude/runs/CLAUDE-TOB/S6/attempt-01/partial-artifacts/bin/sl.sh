#!/usr/bin/env bash
# Wrapper: run a slither-family tool against the in-scope sources in solc mode (never Foundry autodetect,
# so nothing is written under packages/). Usage: sl.sh <tool> <target.sol> [extra args...]
set -uo pipefail
WORK="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORK"
source tob-s6-artifacts/slither/env.sh
tool="$1"; shift; target="$1"; shift
"$tool" "$target" --compile-force-framework solc --solc "$SOLC" --solc-remaps "$REMAPS" \
  --solc-args "$SOLC_ARGS --allow-paths ." "$@"
rc=$?
find packages -type f -print0 | sort -z | xargs -0 shasum -a 256 > /tmp/tob-s6-now.txt
if ! diff -q tob-s6-artifacts/integrity/packages-sha256-before.txt /tmp/tob-s6-now.txt >/dev/null; then
  echo "!!! WARNING: packages/ tree changed after $tool run" >&2
fi
exit $rc
