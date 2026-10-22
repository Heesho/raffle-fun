# Reproduce this round

Run from the control-package directory, not the production contract directory. All commands below are local and do not deploy/broadcast/publish or remediate sources. Preserve the supplied archives and manifests; never regenerate a freeze to hide a difference.

## Verify the target

`python3 verify-freeze.py`

The verifier binds original tracked files, the retained snapshot, the five-file clean production scope, the31-file dependency closure, source archives and freeze manifest. `freeze.json` records the original commit, exact paths, hashes and submodule revision. `working-tree.patch` was empty at capture. `scope-files.txt` is the production file inventory. The archives/manifest are read-only tamper-evident captures, not an operating-system WORM guarantee.

For portable recovery, verify `target.tar.gz` and `clean-context.tar.gz` against their recorded hashes, then extract into NEW directories outside the original repository. Never overwrite the current working tree or an earlier attempt.

## Restore isolated dependency context

Use the retained `runtime` path in freeze.json, or a fresh target extraction. Node22.23.2, pnpm11.18.0 and the committed pnpm-lock.yaml were used for project validation. The initial install was `pnpm install --frozen-lockfile --ignore-scripts` in that isolated copy, not in the original checkout. All later package scripts executed only in isolated validation or campaign directories. The ignored git-hosted era-contracts build hook warning is retained in dependency-install.log.

`prepare-context.py` records the reachable dependency closure; it must not be re-run to overwrite the frozen context after intake. Both source and dependency version drift require a new audit candidate.

## Exact campaign commands and evidence

`campaign-plan.json`, per-attempt `command` in result.json, and `tool-campaign-results.json` preserve actual commands, working directories, timeouts, exit codes and output hashes. Use `run-command.py SLOT TIMEOUT_SECONDS ISOLATED_CWD EXECUTABLE ARGS...` to retain a new attempt without overwriting the old one. It verifies frozen bytes before/after. `campaigns.py`, `static-campaigns.py`, `echidna-campaigns.py`, `integration-followup.py`, and `profile-artifacts.py` are retained orchestration sources. Do not run concurrent builds sharing mutable out/cache/artifacts directories.

Build config and SDK before dependent checks: `pnpm --filter @raffle-fun/config build`, then `pnpm --filter @raffle-fun/sdk build`. SDK/web initial pre-build failures are preserved; successful reruns use the proper order.

Core tool versions/configuration are in toolchain.json. Aderyn0.6.8 and Medusa1.5.1 release binaries were checksum verified; Halmos0.3.3 was installed into a dedicated Python3.12 virtualenv. `tool-install.json`, `medusa-release.json`, per-tool help and raw outputs preserve provenance. Medusa's native CLI did not expose a seed flag; no exact random scheduling reproduction is claimed. Replay retained corpora for deterministic counterexamples if one exists.

For Halmos, copy the explicitly numbered harness from runs/TOOL-HALMOS into a FRESH isolated project test directory and use the exact attempt command/bounds in its MANIFEST/SUMMARY. Two symbolic authorization properties passed; refund/cash/NFT obligations remain unresolved. Do not label timed-out solver paths as proofs.

Mutation variants are explicitly different bytecode, isolated test-efficacy experiments. They are not alternative audited production candidates. Their exact diff/scripts and action reachability probes are in runs/TOOL-MUTATION-QUALITY.

## Model reviews

The exact runner arguments, model/effort/access program, fresh context prompts, events and stage ledgers are in runs/<cell>/<attempt>/. Use `launch-openai.py CELL METHOD` only to create a fresh local review attempt; METHOD is simao, pashov, tob or gebal. It uses the same immutable clean context and preserves previous attempts. No fallback is configured. An interrupted/blocked attempt is not silently upgraded to a completed audit. OpenKritt requires its own native infrastructure, not a generic replacement review.

Claude/Gemini handoffs are full instructions in prompts/*-overnight.md and have exclusive provider-lanes output roots. An external report becomes eligible for reconciliation only after verifying source/context hashes, actual runner identity evidence, stage completeness and first-pass seal. A handoff prompt or route probe alone supplies zero review completion.

Gebal source-only contexts/imports remain origin-bound. Never change snapshotHash/contextHash or import a cold review into a test-inclusive run. Its selected available revision differs from the unresolvable historical reference; original checkout failure is retained in upstream-fetch.json. Docker test-inclusive checks remained a separate obligation.

## Interpret results

Read ASSESSMENT.json with raw result.json. Scanner nonzero finding exits can still represent a completed scan; tool/setup crashes, native or outer timeouts, absent tests and unsupported model routes cannot represent passes. Coverage is instrumented test coverage, not proof, and does not cover interfaces as executable code. All proposed remedies require separate authorization and a new candidate/targeted re-audit. No owner acceptance is invented.

## Final corrections and exact continuation reproduction — 2026-10-21

Earlier statements that Halmos accounting obligations and Gebal deterministic checks remained unresolved are historical. Current bounded closures and the distinct Gebal compatibility method are documented in `TOOL-CAMPAIGN-SUMMARY.md`. Do not erase the original failures or rerun a cold review against a test-inclusive context.

For a new full-release tool attempt, from this control directory use the retained isolated validation path in freeze.json and the exact helper:

```sh
python3 run-command.py TOOL-RELEASE-EXTENDED 4200 /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/validation/packages/contracts env FOUNDRY_PROFILE=audit_release forge test -vv
```

The helper allocates a new attempt and preserves integrity checks. Only run when that isolated project's mutable build outputs are idle; use a fresh dependency-complete extraction and adjust cwd for independent parallel work. Native release profile timeout behavior and actual observed runs/calls are recorded in `runs/TOOL-RELEASE-EXTENDED/attempt-01/campaign-statistics-final.json`; do not replace measured counters with configured values.

For Halmos, construct NEW isolated projects with:

```sh
python3 runs/TOOL-HALMOS-CONTINUATION/reproduce_isolation.py --destination /absolute/new/halmos-continuation
```

Replay exact command arrays, environment and timeouts from `runs/TOOL-HALMOS-CONTINUATION/EXECUTION-MANIFEST.json`, replacing only corresponding new project/output locations; preserve solver versions, input bounds, harness bytes and each query's arithmetic refinement. The retained closure can be independently checked with `python3 runs/TOOL-HALMOS-CONTINUATION/verify_closure.py`; its exact SMT-to-result references are in `CLOSURE.json`. Never relabel an original CLI TIMEOUT as PASS merely because later exact obligations were closed.

For Gebal's disclosed Docker-only deterministic compatibility method, use:

```sh
python3 runs/GEBAL-DETERMINISTIC/rerun.py /absolute/new/gebal-deterministic-output
```

That script requires a new output directory, verifies target/controller hashes, creates a fresh native state/plan, records delegated assistant authorization honestly, and binds an independent test-inclusive context. It requires the retained immutable image and local Unix Docker socket; no host-tool fallback or remote provider egress is configured. This is not the unmodified upstream controller and not a model review.

For Echidna/Medusa and other campaigns, replay actual per-attempt command arrays and configs rather than guessing CLI flags. Original Echidna native timeout attempts remain incomplete; the distinct 3000-target commands/configs are in `TOOL-ECHIDNA-BOUNDED-{1,2}/attempt-01/result.json`. Medusa exposed no seed flag. ABI equality means canonical entry-set equality, not top-level ABI array byte order. No live fork/deployed-bytecode coverage is implied by the local checks.
