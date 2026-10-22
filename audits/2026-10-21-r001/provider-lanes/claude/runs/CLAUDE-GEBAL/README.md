# CLAUDE-GEBAL — Gebal @ 9ad24645f92a3821ae4539db5f1be52b48ed379e × claude-opus-5-5

Pin provenance: the historical pin 5c68ec0284dc642823abe81cbc0e02fcb080a69f does not resolve remotely
(`../../../../upstream-fetch.json`: "not our ref"). The coordinator fetched the available HEAD 9ad2464
("Harden CLI harness and validate sandbox integrations"), and this lane reviewed and used it unmodified (git status clean).
Runtime: pinned node 22.23.3 / pnpm 10.34.6 in the lane runtime, `pnpm install --frozen-lockfile`, `pnpm build` (tsc) OK.

## Bound evidence (cold, source-only)
| Item | Value |
|---|---|
| plan | e31228e2-2890-4ed1-8a0f-e7b516245b4d, plan hash 79aa8bf3aefc39887d15c9240d7fe690ae5b32107c9622cd0f2f3c3599398b55 |
| approval | delegated assistant actor (the owner did not review the hash); see native-attempt-01/approve.txt |
| run | a184629e-4470-49a4-96a4-44695a238c6a (state succeeded, tasks: intake) |
| snapshotHash | 1c720af585db73b5867c91437f75776b3ef6ee9c6d7aa70ee51fe85dbad994ad |
| contextHash | cbec71422797334035a6a1ab2b5b6a22768aeb2d0a8b727b85d146017c351c7a (context.json sha256 8d369d1d…) |
| reviewer | attempt-01-review: Claude Code 2.1.299, claude-opus-5-5, effort max requested; provider-returned model claude-opus-5-5 (61 msgs) |
| review.json | sha256 b3d18d10…; schema-valid import, evidence 24f406a7…, 4 observations, disposition needs-review |
| native reports | native-attempt-01/report.md, report.json, findings.txt |

Exposure: the reviewer received only Gebal's exported context plus START_HERE/REVIEW/schema (no tests, no history, no tool output).

## Test-inclusive deterministic run — BLOCKED (separately bound; never mixed with the cold run)
- Gebal executes checks only inside its Docker sandbox image. `scripts/prepare-tools.py` supports only
  `--compiler 0.8.26|0.8.28|0.8.30` (hard-coded hashes, lines 21-23). The frozen profile pins solc 0.8.36. Adding a
  compiler entry would modify the controller (a distinct method).
- No dedicated local Docker daemon exists for this lane. The pre-existing `gebal` lima VM belongs to another workflow
  and was not used.
- The lane's deterministic Foundry/Echidna/Medusa/Halmos campaigns (see ../../tools/) are separate evidence
  and are NOT presented as Gebal output.
