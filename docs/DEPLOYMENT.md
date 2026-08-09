# Deployment runbook

Hardhat Ignition is the canonical deployment pipeline. The Foundry script is an
independent constructor/state comparison. Never deploy from an unclean or
unreproducible checkout.

## Frozen toolchain

- Solidity `0.8.36`, exact pragmas, EVM target `cancun`;
- OpenZeppelin Contracts and Contracts Upgradeable `5.6.1`;
- Pyth Entropy Solidity SDK `2.2.1`;
- forge-std commit `37a36ca389095b2f677abb07642634573ba7e265`;
- Node `>=22.13 <23`, workspace `22.23.2`; pnpm `11.18.0`.

Base supports Cancun semantics from Ecotone; changing the target requires a separate
network compatibility review. Hardhat and the default Foundry profile must compile
the same sources. The comparison Foundry profile additionally uses IR compilation.

## Non-negotiable gates

- independent audit/review of the exact source and dependency locks;
- full frozen-lockfile format, lint, type, build, test, coverage, gas, and Slither
  suite green with no unresolved critical/high/medium issue;
- compiler known-bugs/release notes rechecked at the release date;
- official Base Entropy v2 address and bytecode verified;
- every initial quote token reviewed for exact-transfer/non-rebasing behavior and
  issuer pause/blacklist controls;
- callback gas limit tested with production bytecode;
- nonzero treasury and final `Ownable2Step` owner are reviewed multisigs;
- Base Sepolia smoke tests cover success, no-sales, unrequested failure, timeout,
  bounded refund crediting, quote/prize claim, and failed-destination retry.

## Inputs

```text
DEPLOYER_PRIVATE_KEY
VERIFIED_QUOTE_TOKENS
ENTROPY
PROTOCOL_TREASURY
FACTORY_OWNER
CALLBACK_GAS_LIMIT       # default 300000 only after measurement
BASE_SEPOLIA_RPC_URL
BASE_RPC_URL             # mainnet procedure only
BASESCAN_API_KEY
```

Use an encrypted secret manager. The repository intentionally contains no real
deployment parameters or placeholder addresses.

## Base Sepolia procedure

1. Record the clean source commit, compiler binaries, dependency lock, and bytecode.
2. Run the complete validation matrix in the root README.
3. Prepare Ignition parameters outside version control and simulate deployment.
4. Deploy with `pnpm deploy:base-sepolia`; record every address, block, transaction,
   constructor argument, salt, and implementation bytecode hash.
5. Verify with `pnpm verify:base-sepolia`.
6. Confirm `pendingOwner` is exactly the reviewed Safe, then accept ownership from it.
7. Verify initial quote-token admission and that unverified-token creation reverts.
8. Create a validated deployment record with the exact 40-hex source commit and run
   `pnpm --filter @raffle-fun/contracts deployment:write ./candidate.json`.
9. Regenerate SDK/subgraph ABIs, create the network manifest, deploy the indexer, and
   configure the web app from that record.
10. Execute and document every smoke-test lifecycle, including exact deadline
    boundaries and post-failure refunds.

Mainnet has no default root deployment command. Add a reviewed, environment-guarded
operator procedure only after audit fixes and testnet monitoring.

## Monitoring and incident response

Monitor creation failures, draw requests, request/callback deadlines, ignored
callbacks, failure finalizations, remaining refund liability, quote solvency, claims,
owner/pending-owner changes, pause, treasury, and token-admission events.

Existing clones cannot be upgraded or paused. Response is limited to pausing future
creation, warning users, removing UI exposure, and deploying a new factory. Lifecycle
recovery in an existing clone remains permissionless and cannot be redirected by the
owner.
