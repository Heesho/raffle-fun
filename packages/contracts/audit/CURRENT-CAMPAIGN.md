# Current-Commit Adversarial Campaign Record

This document records fresh internal evidence produced against source commit `5772e54ba89c06646815ed52a881cd8940f094ca` on 2026-08-16. It is not an independent audit. Historical reports were read for context only and retain their original reviewed commits.

## Identity and initial baseline

| Item                  | Observed value                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------------- |
| repository / branch   | `/Users/hishamel-husseini/Documents/projects/raffle-fun`, `main` tracking `origin/main`                   |
| source commit         | `5772e54ba89c06646815ed52a881cd8940f094ca` (`test: add extreme smart contract campaign`)                  |
| upstream divergence   | 0 ahead / 0 behind                                                                                        |
| initial worktree      | clean; no dirty or untracked paths                                                                        |
| submodule             | `packages/contracts/lib/forge-std` at `37a36ca...`                                                        |
| Node / pnpm           | repository commands pinned to Node `22.23.2`; pnpm `11.18.0` (default Node 20 Corepack invocation failed) |
| Forge / Cast / Anvil  | `1.7.1`, commit `4072e...`                                                                                |
| standalone solc       | unavailable; Forge used solc `0.8.36`                                                                     |
| Hardhat               | `3.11.1`                                                                                                  |
| Python                | `3.14.6`                                                                                                  |
| compiler              | Solidity `0.8.36`, Cancun, optimizer on, 1,000 runs, no via-IR                                            |
| initial lock identity | SHA-256 `ddb9053c30d228e8b1aa9fb0e3e124af61a6c8be8cf43b3df2a1ccdf9fef0b9f`                                |
| key dependencies      | OpenZeppelin Contracts `5.6.1`; Pyth Entropy SDK Solidity `2.2.1`                                         |

The mandatory pre-edit commands were run before any edit. No applicable repository-root `AGENTS.md` or `CLAUDE.md` existed; dependency/sibling instruction files were not applicable. `git submodule update --init --recursive` and frozen installation passed. The install printed update metadata but did not alter the lock.

## Baseline gates

| Command                         | Fresh baseline result                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `pnpm format:check`             | failed on three pre-existing files: `docs/whitepaper/src/generate-figures.mjs` and two historical audit Markdown files |
| `pnpm lint`                     | pass, 0 errors / 209 warnings                                                                                          |
| `pnpm typecheck`                | pass                                                                                                                   |
| `pnpm build`                    | initial sandbox Hardhat cache-mutex denial; pass when rerun with required filesystem access                            |
| `pnpm test`                     | pass; Foundry 88 pass / 0 fail / 1 skip; Hardhat 9 / 0; subgraph 6; SDK 9; web 15; other workspace tasks pass/cached   |
| `pnpm contracts:test:foundry`   | 88 pass / 0 fail / 1 intentional fork skip                                                                             |
| `pnpm contracts:test:hardhat`   | 9 pass / 0 fail                                                                                                        |
| `pnpm contracts:coverage`       | 99.74% lines, 94.38% branches, 100% functions                                                                          |
| `pnpm contracts:gas`            | pass; snapshot matched                                                                                                 |
| `pnpm contracts:slither`        | failed: `slither: command not found` under repository PATH; direct Slither later ran successfully                      |
| SDK `sync:check`                | pass                                                                                                                   |
| subgraph codegen/build/test     | pass / pass / 6 pass                                                                                                   |
| `forge fmt --check`             | failed on pre-existing Solidity formatting drift                                                                       |
| `forge build --sizes`           | pass; see size table                                                                                                   |
| `FOUNDRY_PROFILE=ci forge test` | 88 pass / 0 fail / 1 skip                                                                                              |

The initial ordinary invariant reported 17,263 calls and 17,263 reverts for the setup-only `configure` action because the entire handler contract—not an explicit selector set—was targeted and the normal profile allowed reverts. This was not a production failure; it was a vacuous-action test defect.

## Current worktree improvements and red/green evidence

1. **Invariant reachability:** test-only instrumentation first made repeated `configure` observable. A focused run failed deterministically with `assertion failed: 1 != 0`, shrunk to one `configure(address)` call. The invariant now targets an explicit 14-selector list and asserts zero repeated-configuration attempts. The resulting ordinary campaign made 16,384 calls per property, reached every selected action (roughly 1,100 each), and had zero handler reverts.
2. **SDK quantity preflight:** a new test first failed because `validatePurchaseQuantity` did not exist. The SDK now rejects 0 and 101 locally while accepting 1 and 100 before RPC simulation. SDK result became 10 pass.
3. **Nested Raffle prizes:** deterministic tests prove same-Factory nested ticket escrow reverts atomically. Cross-Factory nesting succeeds; if the inner ticket becomes locked, outer NFT delivery and recovery fail, while outer buyers can still recover their entire quote pot after the 30-day timeout. The cross-Factory prize can remain stranded; no production policy was changed.
4. **Independent models:** Python models import no production artifact/helper. Two seeds execute 2,000 randomized sequences each, terminal drains, lifecycle/ownership/race checks, integer economics, modulo analysis, and selective-reveal math. Result: 8 pass / 0 fail.
5. **Dependency advisory:** `pnpm audit --audit-level high` initially reported High `GHSA-2v37-7h3g-55p8` through `nanoid 3.3.17`. A root override to `3.3.18` and focused lock update cleared High findings. Full audit retains one Low `elliptic <=6.6.1`; `6.6.2` does not exist (`ERR_PNPM_NO_MATCHING_VERSION`).
6. **Current-source mutation:** 38 deterministic production mutants compiled. Thirty died initially; eight survivors exposed composed-sequence, exact-boundary, Lens-parity, purchase-bound, and malicious-prize test gaps. Added regressions killed all eight on a focused rerun. Final sample result: 38/38, with no equivalent/unreachable survivor and no compiler failure.

Final lockfile SHA-256 after the focused advisory remediation is `912de3547634a1714c9c5933e634be102b032400b956ec1ad2a729a6aec146b4`.

No production Solidity file was changed because no concrete supported-asset production invariant violation was reproduced.

## Foundry, fuzz, invariant, and model evidence

At the first compiler-differential checkpoint, current tests contained 91 runnable passes, zero failures, and one disabled-by-default fork skip. Added evidence then accounted for two nested-prize tests and one invariant meta-property. The initial compiler differential matrix ran that suite with:

| Configuration                                                                 | Result                                                                                    |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| canonical: optimizer 1,000, Cancun, no via-IR                                 | 91 pass / 0 fail / 1 skip                                                                 |
| via-IR comparison profile                                                     | 91 pass / 0 fail / 1 skip                                                                 |
| optimizer disabled (`coverage` profile)                                       | pass, exit 0                                                                              |
| alternative Prague EVM                                                        | pass, exit 0; evidence only, not a deployable configuration claim                         |
| `audit_strict`: 10,000 fuzz runs; invariant 1,000 x depth 256; fail on revert | pass, exit 0                                                                              |
| `audit_release` full-suite superset                                           | stopped incomplete after 1:15:50 with no failure output; not counted as a pass            |
| `audit_release` repository-intended `RaffleStrictInvariantTest` target        | pass, exit 0; 5,000 x depth 512 x 4 properties = 10,240,000 handler calls; fail on revert |

After all mutation regressions, final canonical, gas-snapshot, and coverage executions contained **94 pass / 0 fail / 1 skip**. `audit_strict` also passed the complete final worktree. Via-IR, optimizer-disabled, and Prague-EVM profiles were rerun after the final regressions and each exited 0. Final production coverage was **99.74% lines, 95.51% branches, and 100.00% functions**; the baseline branch figure was 94.38%.

Canonical fuzz configuration is seed `0x524146464c45`, 1,000 cases per fuzz property. Via-IR output confirmed 6 `RaffleFuzz` properties at 1,000 runs and one differential property at 1,000 runs. Ordinary, strict, multi-actor, and fleet invariant tables all showed selected actions reached with zero top-level handler reverts after correction.

Independent Python result:

```text
8 tests passed; seeds 0x524146464c45 and 0x20260816; 2,000 randomized sequences per seed
```

## External fuzzers

Echidna `2.3.2` was run against the current worktree:

| Harness / seed                    |   Calls | Corpus | Unique instructions | Properties | Result |
| --------------------------------- | ------: | -----: | ------------------: | ---------: | ------ |
| smoke / 20260816                  |   1,204 |      5 |         not emitted |          6 | 6 pass |
| `RaffleEchidna` cash / 20260816   | 100,164 |     16 |              13,467 |          6 | 6 pass |
| `RaffleNftEchidna` NFT / 20260817 | 100,250 |     17 |              13,966 |          6 | 6 pass |

Medusa `1.5.1` has no exposed deterministic-seed control. A temporary 500,000-test limit was used and the tracked 100,000 setting restored afterward:

| Harness |   Calls | Branches | Corpus | Properties (including public assertions/getters) | Result  |
| ------- | ------: | -------: | -----: | -----------------------------------------------: | ------- |
| cash    | 518,329 |    1,221 |     33 |                                               23 | 23 pass |
| NFT     | 529,570 |    1,266 |     37 |                                               23 | 23 pass |

The harnesses do not expose durable lifecycle branch counters as properties, so intended branch reachability is supported by separate harnesses/corpus/coverage, not proved by a harness meta-assertion. This remains a test-quality blocker.

## Static analysis, dependencies, and compiler data

| Tool              | Fresh result and disposition                                                                                                                                                                                                                                                                                                                         |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Slither `0.11.6`  | 49 contracts, 64 detectors, 0 results when invoked directly                                                                                                                                                                                                                                                                                          |
| Aderyn `0.6.8`    | scanned 17 Solidity files / 1,221 nSLOC / 88 detectors; 3 High and 11 Low heuristic findings manually dispositioned as OZ-authorized transfer, intentional forced-native lock, CEI/nonReentrant false positives, bounded loops, mocks, or style. Tool then crashed in macOS telemetry/network initialization with a null system-configuration object |
| Semgrep           | unavailable: `Failed to create system store X509 authenticator: ca-certs: empty trust anchors...`                                                                                                                                                                                                                                                    |
| Solhint           | 0 errors / 209 baseline warnings; 0 errors / 215 final warnings after added test contracts/branches                                                                                                                                                                                                                                                  |
| Gitleaks `8.30.1` | baseline git scan: 15 commits / approximately 8.20 MB / no leaks; final tracked diff 32.46 KB and untracked artifacts 160.44 KB each reported no leaks                                                                                                                                                                                               |
| dependency audit  | High cleared by `nanoid 3.3.18`; one unpatchable Low `elliptic` advisory remains                                                                                                                                                                                                                                                                     |
| compiler          | no production warning requiring remediation observed                                                                                                                                                                                                                                                                                                 |

Canonical and via-IR storage-layout JSON hashes are identical:

| Contract      | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Raffle        | `e58deb2cc2edd50d19ba7bc0d532cbe6e399faa8d32030634b2bd690b811f96c` |
| RaffleFactory | `7220a56475e03a070fab08576f258bcc52b7751723569dbde703e7cff6d4c893` |
| RaffleLens    | `5007e3b784841c1839d50e1c7c327054fd93a236126542d5218ef7d82f30c563` |

Size gate:

| Contract      | Runtime bytes | Initcode bytes | EIP-170 runtime margin |
| ------------- | ------------: | -------------: | ---------------------: |
| Raffle        |        16,726 |         19,174 |                  7,850 |
| RaffleFactory |        24,267 |         25,065 |                **309** |
| RaffleLens    |         6,954 |          7,174 |                 17,622 |

Factory headroom remains a release-sensitive 309 bytes. Any production edit requires another exact size gate.

Focused canonical gas measurements (test-environment gas, not Base fee estimates):

| Operation                               |           Gas |
| --------------------------------------- | ------------: |
| Factory construction                    |     4,981,961 |
| Factory Raffle creation                 |     3,657,825 |
| 100-ticket purchase, EOA                |     2,655,370 |
| 100-ticket purchase, receiver callbacks |     2,803,730 |
| draw request                            |       144,882 |
| callback body observed by mock          |        49,836 |
| oracle fulfillment transaction          |        76,989 |
| NFT winner redemption                   |       106,759 |
| cash winner redemption                  |        18,743 |
| missed-request refund finalization      |        25,944 |
| callback-timeout finalization           |        26,212 |
| one-ticket refund                       |        19,216 |
| 100-ticket refund                       |       601,693 |
| quote claim                             | 34,305–34,351 |
| sponsor prize recovery                  |        29,954 |
| single-Raffle Lens read                 |        59,502 |
| 64-Raffle Lens read                     |     2,618,451 |

The callback measurement is 16.61% of the configured 300,000 gas limit. Purchase/refund/Lens loops remain capped at 100/100/64, and terminal settlement contains no historical-ticket loop.

## Fork evidence

Read-only local fork tests sent no public transaction.

| Mode                 | Base             | Base Sepolia     | Result                                                |
| -------------------- | ---------------- | ---------------- | ----------------------------------------------------- |
| pinned               | block 49,752,968 | block 45,263,498 | 2 pass / 0 fail / 2 skips for nonselected chain cases |
| latest observational | block 50,044,137 | block 45,554,666 | 2 pass / 0 fail / 2 skips for nonselected chain cases |

The tests observed chain IDs 8453/84532, code at official Circle USDC and Pyth Entropy addresses, USDC decimals 6, default provider/fee reads, a real-USDC purchase, request encoding, and unauthorized callback rejection. Latest-head output included a cache warning and is not reproducible evidence.

Observed bindings were Base Entropy `0x6E7D74FA7d5c90FEF9F0512987605a6d546181Bb`, Base USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`, Base Sepolia Entropy `0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c`, and Base Sepolia USDC `0x036CbD53842c5426634e7929541eC2318f3dCF7e`.

## Workspace components

| Component             | Fresh evidence                                                                                                                                                                                                                                                                                     |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hardhat               | 9 pass / 0 fail                                                                                                                                                                                                                                                                                    |
| SDK                   | ABI sync pass; 10 tests pass after quantity preflight regression                                                                                                                                                                                                                                   |
| subgraph              | codegen pass, build pass, 6 tests pass                                                                                                                                                                                                                                                             |
| web                   | 15 tests pass in aggregate workspace run                                                                                                                                                                                                                                                           |
| deployment validation | 9-test Hardhat suite passes, including completed ownership, pending-handoff rejection, unpaused six-decimal quote policy, incompatible/paused quote rejection, and EOA mainnet treasury rejection; expected runtime identity, exact stale-block binding, and wrong Lens identity remain incomplete |

The current subgraph does not index `EntropyCallbackIgnored`, which is a current off-chain observability gap. The superseded complete whitepaper and some historical audit text describe removed all-state transferability/early proceeds/recovery behavior; their historical labels must remain visible until a new public protocol document replaces them.

## Tool and evidence blockers

- Standalone `solc` was unavailable; Forge's pinned compiler was used.
- Repository `pnpm contracts:slither` could not find Slither; direct pinned invocation succeeded.
- Halmos/current symbolic runner was unavailable, so no fresh path counts or vacuity result is claimed.
- Gambit was unavailable, but the new deterministic disposable-worktree runner completed a 38-mutant current-source sample (38/38 after eight test-gap regressions). This is not equivalent to broad Gambit enumeration.
- Semgrep failed before analysis due an empty X.509 trust store.
- Aderyn produced findings then crashed during system/telemetry initialization; its report was still manually reviewed.
- A naive final `gitleaks dir .` traversed 2.54 GB of ignored dependencies/build output and produced 366 dependency-fixture matches. It is not counted as a source result; scoped scans of the actual tracked diff and untracked campaign artifacts found no leaks.
- Default fork tests skip by design; only explicit flag runs count as fork evidence.

## Historical reconciliation

Historical audit documents reviewed commits `a2120f5`, `fe09d476`, and `b992b23`; none reviewed `5772e54`. Statements about unrestricted transfers in all states, callback-time sponsor proceeds, the removed dispatcher, and `recoverProtocolOwnedClaim` do not describe current code. `INTERNAL-AUDIT.md` is explicitly historical, and the complete whitepaper warns that its security model is superseded. Those files were not rewritten to imply current review.

## Release interpretation

Green internal campaigns increase evidence only. They do not make the protocol safe, audited, formally verified, trustless, or production ready. `CURRENT-FINDINGS.md` and `CURRENT-RESIDUAL-RISKS.md` list the remaining blockers and external assumptions.

## Final repository state

Local `HEAD` remained `5772e54ba89c06646815ed52a881cd8940f094ca`; no commit, pull, push, deploy, broadcast, verification, or package publication occurred. During the campaign, the remote-tracking ref advanced independently from the initial 0/0 divergence to `origin/main` `d293735938f952d9ff9225b5cc64190eb6db40be`, leaving the reviewed checkout 0 ahead / 4 behind. Those four later documentation/formatting commits are not included in this review.

Final worktree state is intentionally dirty with 11 modified tracked files and 14 untracked campaign files. No file under `packages/contracts/src` or its production interfaces was modified. `git diff --check` passes. The submodule remains `37a36ca389095b2f677abb07642634573ba7e265`.
