#!/bin/bash
# Generated scratch helper (S6 attempt-02). Runs one command and preserves raw evidence:
#   <prefix>.meta.txt   cwd, UTC start/end, exact shell-quoted argv, relevant env overrides, exit code
#   <prefix>.stdout.txt complete standard output
#   <prefix>.stderr.txt complete standard error
# Usage: rec.sh <evidence-prefix> -- <command> [args...]
set -u
prefix="$1"; shift
[ "${1:-}" = "--" ] && shift
mkdir -p "$(dirname "$prefix")"
meta="$prefix.meta.txt"
{
  echo "cwd: $(pwd)"
  echo "start_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'argv:'; printf ' %q' "$@"; echo
  for v in FOUNDRY_SOLC FOUNDRY_OFFLINE FOUNDRY_PROFILE FOUNDRY_OUT FOUNDRY_CACHE_PATH SOLC_VERSION PATH_PREPEND; do
    if [ -n "${!v+x}" ]; then echo "env $v=${!v}"; fi
  done
} > "$meta"
start=$(date +%s)
"$@" > "$prefix.stdout.txt" 2> "$prefix.stderr.txt"
rc=$?
end=$(date +%s)
{
  echo "end_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "elapsed_seconds: $((end - start))"
  echo "exit_code: $rc"
  echo "stdout_bytes: $(wc -c < "$prefix.stdout.txt" | tr -d ' ')"
  echo "stderr_bytes: $(wc -c < "$prefix.stderr.txt" | tr -d ' ')"
} >> "$meta"
exit $rc
