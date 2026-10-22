---
name: audit-route-metadata-only
description: Metadata-only fixture; do not invoke for assessed review.
mainAgent: true
subagent: true
model: inherit
commandExecutionPolicy: off
tools:
  - view_file
  - grep_search
  - list_dir
  - find_by_name
  - finish
skills: []
plugins: []
---
Only a metadata fixture. No assessed audit work is authorized through this fixture.
