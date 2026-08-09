# Internal adversarial audit baseline

Review date: 2026-08-09 (Europe/Podgorica)

This is an internal review of an uncommitted worktree. It is not an independent audit.

## Reviewed source identity

- fetched `origin/main`: `a2120f5e163dc3641d9864773febbfedca047edb` (`Harden raffle settlement and recovery lifecycle`);
- local `main`: the same SHA;
- starting branch: `codex/contracts-simplified-settlement`;
- audit branch: `codex/raffle-fun-adversarial-audit`;
- baseline worktree patch fingerprint from `git diff | git hash-object --stdin` before audit-only tests:
  `55589ce1fce0bd5579e60df747796575df9b0d96`;
- baseline dirty state: 65 tracked modified files, no untracked files;
- public deployment or broadcast: none performed.

The audit prompt describes the superseded clone, admission-list, transfer-freeze,
refund-credit, and native-pull-liability architecture at `main`. The reviewed worktree
instead contains the subsequently approved constructor-deployed, single-USDC,
transferable bearer-burn settlement refactor. Production Solidity is the source of
truth. Clone-, initializer-, CREATE2-, allowlist-, frozen-owner-, refund-credit-, and
native-pull-liability requirements are therefore recorded as superseded or not
applicable; they are not silently reintroduced.

## Toolchain and compilation

| Component                                        | Captured value                                                    |
| ------------------------------------------------ | ----------------------------------------------------------------- |
| Node                                             | `v24.14.0` locally; repository requires `>=22.13 <23`             |
| pnpm                                             | `11.18.0` through Corepack                                        |
| Forge/Cast/Anvil                                 | `1.2.3-stable`, commit `a813a2cee7dd4926e7c56fd8a785b54f32e0d10f` |
| Solidity                                         | `0.8.36+commit.8a079791.Darwin.appleclang`                        |
| EVM target                                       | `cancun`                                                          |
| optimizer                                        | enabled, 1,000 runs                                               |
| production via-IR                                | disabled                                                          |
| comparison via-IR                                | enabled, optimizer 1,000 runs                                     |
| OpenZeppelin Contracts                           | `5.6.1`                                                           |
| OpenZeppelin Contracts Upgradeable               | not installed; constructor architecture                           |
| Pyth Entropy Solidity SDK                        | `2.2.1`                                                           |
| Hardhat                                          | `3.11.1`                                                          |
| Viem                                             | `2.55.10`                                                         |
| Slither                                          | `0.11.6`                                                          |
| Solhint                                          | `6.2.3`                                                           |
| Echidna                                          | `2.3.3`                                                           |
| Gitleaks                                         | `8.30.1`                                                          |
| Aderyn, Semgrep, Mythril, Medusa, Halmos, Gambit | unavailable at baseline                                           |

Exact configuration was captured with `forge config --json` from
`packages/contracts`. The default Foundry profile uses 1,000 fuzz runs with seed
`0x524146464c45` and 256 invariant runs at depth 64 with `fail_on_revert = false`.
The existing CI profile uses 10,000 fuzz runs and 1,000 invariant runs at depth 256.

## Production bytecode baseline

Captured with `forge build --sizes` using the production Foundry profile:

| Contract        |  Runtime | Initcode | EIP-170 runtime margin | EIP-3860 initcode margin |
| --------------- | -------: | -------: | ---------------------: | -----------------------: |
| `Raffle`        | 16,418 B | 18,400 B |                8,158 B |                 30,752 B |
| `RaffleFactory` | 23,242 B | 23,956 B |                1,334 B |                 25,196 B |
| `RaffleLens`    |  6,789 B |  7,009 B |               17,787 B |                 42,143 B |

The factory is the size-constrained production contract.

## Test, coverage, and gas baseline

`forge test -vv` completed 46/46 tests:

- 25 unit tests;
- 7 security tests;
- 6 fuzz properties, 1,000 cases each;
- 8 stateful invariants, 256 runs x 64 calls = 16,384 calls per invariant;
- no failures or skips.

Production-only coverage from
`forge coverage --report summary --no-match-coverage '^(script/|src/mocks/|test/)'`:

| Metric     |         Coverage |
| ---------- | ---------------: |
| lines      | 99.72% (355/356) |
| statements | 99.30% (428/431) |
| branches   |   98.65% (73/74) |
| functions  |     100% (41/41) |

Foundry emitted instrumentation-anchor warnings while optimizer and via-IR were
disabled for coverage. The one uncovered Lens line and three statements require
manual review; coverage is not treated as proof.

`forge snapshot --check` passed. Baseline measured medians include approximately
146,044 gas for `requestDraw`, 76,448 gas for winner redemption, 55,425 gas for
refund enablement, and batch-dependent refund redemption up to 922,629 gas in the
existing campaign. Constructor raffle creation is approximately 3.61M gas. A fresh
post-remediation worst-case report is required.

## Dependency baseline

`pnpm audit --json` reported 1,054 total dependencies and one low-severity,
development-only advisory: `GHSA-848j-6mx2-7j84` through Hardhat verification's
`elliptic@6.6.1`. Critical, high, and moderate counts were zero.

## Deployment baseline

- `deployments/` contains only `schema.json`; there are no signed or live deployment
  records in the reviewed worktree.
- Hardhat exposes Base (8453) and Base Sepolia (84532) network definitions but no
  command was run against either network.
- No public address is enabled for writes by the checked-in configuration.
- Fork validation had not been executed at baseline.

## CI baseline

The latest fetched `main` workflows for `a2120f5` were not green:

- Contracts/Foundry failed because the job did not install JavaScript dependencies
  required by Solidity imports.
- Contracts/static-analysis failed because Slither invoked `forge` in a job where
  Foundry was not installed.
- Web failed because workspace `config` and `sdk` build outputs did not exist before
  standalone web typechecking.
- Hardhat/SDK/repository failed because subgraph generated sources did not exist before
  root typechecking.
- Subgraph passed.
- The scheduled security workflow failed its secret-scan job on sandbox address-like
  fixtures classified by Gitleaks as generic API keys; dependency audit passed.

These failures are release-process findings even though local commands pass in a
previously built workspace.

## Known findings at the end of baseline reproduction

The following were reproduced before any production-code remediation:

1. an unsafe ticket transfer to the raffle makes the raffle the bearer credential and
   permanently prevents an externally initiated winning redemption;
2. a sponsor can configure the deterministically predicted new raffle as its own fixed
   recovery recipient, permanently preventing sponsor-side NFT recovery;
3. a factory owner can configure the predicted new raffle as treasury, leaving the
   protocol-fee claim owned by an account unable to initiate `claimQuote` while
   `claimQuoteFor` rejects the self-destination;
4. current CI is not reproducible from a fresh checkout.

The three custody/accounting reproductions are preserved in
`RaffleSecurity.t.sol` and passed against the vulnerable baseline.

## Documented external assumptions

The supported recovery claim assumes an honest standards-compliant ERC-721 whose
ownership and safe transfers remain available, plus an admitted non-rebasing exact-
transfer ERC-20 whose transfers and balance reads remain honest and available. It does
not cover issuer freezes/blacklists, malicious or upgraded tokens, dishonest
`ownerOf`/`balanceOf`, lost keys, unrelated NFTs forced into escrow, universal chain
censorship, or a halted/reorganized chain. The audit separately tests protocol-created
self-destinations because those are deterministic contract behavior rather than an
external asset failure.

## Baseline commands

```text
git fetch origin main
git rev-parse HEAD main origin/main
git status --short --branch
git diff --name-only
node --version
corepack pnpm --version
forge --version
cast --version
anvil --version
<svm solc 0.8.36> --version
forge config --json
forge build --sizes
forge test -vv
forge coverage --report summary --no-match-coverage '^(script/|src/mocks/|test/)'
forge snapshot --check
pnpm audit --json
gh run list --branch main --limit 5
gh run view <run> --log-failed
```
