Preserved first non-successful tool outputs:

1. Directory/search command: `rg --files audit/S1 | sort | head -80 && rg -n ... audit/S1/*.json` returned exit 1 after successful directory listing because zsh reported `zsh:1: no matches found: audit/S1/*.json`. Corrected with exact file reads; no conclusions depended on that search.

2. Optional consistency subagent spawn failed: `Fatal error: failed to load model context for thread 01a15d79-d3e4-70e2-847b-2b8d08e88243: invalid thread-store request: no rollout found for thread id 01a15d79-d3e4-70e2-847b-2b8d08e88243`. No fallback model or spawned analysis was used.

3. Early batched read outputs were tool-truncated; request fields were subsequently parsed and selective fields re-read. Full original inputs are preserved at hashed paths in 014-resources.json.
