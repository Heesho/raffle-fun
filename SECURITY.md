# Security policy

## Status and scope

Raffle Fun v2 has completed an internal adversarial hardening campaign and remains
independently unaudited. Fuzzing, invariants, differential models, mutation testing,
static analysis, fork checks, and internal code review are defense-in-depth measures;
none is an independent audit or a claim of production safety. The internal evidence is
recorded in [`packages/contracts/audit/INTERNAL-AUDIT.md`](packages/contracts/audit/INTERNAL-AUDIT.md).

In scope:

- `packages/contracts/src/Raffle.sol`
- `packages/contracts/src/RaffleFactory.sol`
- `packages/contracts/src/RaffleLens.sol`
- first-party interfaces/libraries
- deployment configuration that can change the deployed bytecode or ownership
- SDK/web behavior that can construct unsafe transaction parameters
- subgraph bugs that materially misrepresent financial state

Mocks, test-only forced-native behavior, development infrastructure, and already
disclosed dependency vulnerabilities are out of bounty scope unless they demonstrate
an exploitable production impact.

## Private disclosure

Do not publish an unpatched vulnerability in an issue, pull request, social post, or
public chat. Send a minimal report to the repository maintainers through GitHub's
private vulnerability reporting feature. Include:

- affected commit and component;
- impact and required preconditions;
- reproducible steps or a focused test;
- whether funds, prize custody, randomness, or liveness are affected;
- any proposed remediation, if available.

Do not include private keys, credentials, or unrelated personal data. Maintainers
should acknowledge a complete report within 5 business days, provide a triage status
within 10 business days, and coordinate disclosure after a fix. These are targets,
not a guarantee.

## Safe research

Use local networks or accounts/assets you control. Do not:

- access another person's wallet or data;
- disrupt a live oracle, RPC, indexer, or UI;
- exploit a production deployment to prove impact;
- retain, transfer, or destroy user assets.

## Dependency posture

The dependency tree is pinned and audited in CI. As of 2026-08-09, `pnpm audit`
reports no critical, high, or moderate findings. One low-severity advisory remains in
the development-only Hardhat verification path through `elliptic@6.6.1`; although the
advisory identifies `6.6.2` as patched, npm still publishes `6.6.1` as the latest
release. It is not bundled into the contracts or web runtime and must be upgraded when
the upstream package is available.

The Graph CLI still declares the abandoned `decompress` package. The workspace
replaces it with the maintained, security-patched `@xhmikosr/decompress` fork while
preserving the dependency name expected by the CLI.

## Operational response

Existing raffles cannot be upgraded or paused. If a vulnerability is confirmed,
maintainers can pause creation, warn users, remove the frontend deployment, and deploy
a new factory version, but cannot rewrite the economics or seize assets in existing
raffles. Existing raffles retain their permissionless empty closure, draw, oracle
deadline, bounded ticket-burn refund, bearer-prize, and pull-claim paths.

## Supported recovery envelope

The protocol's recovery property applies only to a standards-compliant ERC721 whose
ownership and safe transfers remain honest, and the factory-wide exact-transfer,
non-rebasing USDC whose transfers remain available. The contracts cannot guarantee
recovery against malicious or upgraded assets, pauses/freezes/blacklists/burns, a
halted or reorganized chain, lost keys, or unrelated NFTs forced in through unsafe
`transferFrom`. No administrator rescue function exists for those cases.
