# Deployment runbook

Hardhat Ignition is the canonical deployment pipeline. The Foundry script is an
independent constructor/state comparison. Never deploy from an unclean or
unreproducible checkout.

The executable security handoff checklist is
[`packages/contracts/audit/RELEASE-CHECKLIST.md`](../packages/contracts/audit/RELEASE-CHECKLIST.md).
Unchecked items there are release blockers, not optional recommendations.

## Frozen toolchain

- Solidity `0.8.36`, exact pragmas, EVM target `cancun`;
- OpenZeppelin Contracts `5.6.1`;
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
- the factory-wide USDC reviewed for exact-transfer/non-rebasing behavior and
  issuer pause/blacklist controls; deployment validation must read six decimals and an
  unpaused state;
- callback gas limit tested with production bytecode;
- nonzero treasury and final `Ownable2Step` owner are reviewed multisigs, and ownership
  acceptance is complete before any deployment record is published;
- Base Sepolia smoke tests cover NFT and cash success, empty closure, all three refund
  deadlines, bounded ticket-burn refunds, transfer locking, NFT delivery failure, and
  failed-destination retry;
- the default Entropy provider is reviewed and a provider-pinning design is completed,
  or its substitution risk is explicitly accepted by independent review.

## Inputs

```text
DEPLOYER_PRIVATE_KEY
QUOTE_TOKEN
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
   constructor argument and deployed bytecode hash.
5. Verify with `pnpm verify:base-sepolia`.
6. Confirm `pendingOwner` is exactly the reviewed Safe, accept ownership from it, then
   require `owner == Safe` and `pendingOwner == address(0)`.
7. Verify `quoteToken()` is the reviewed USDC contract, has runtime bytecode, reports
   six decimals, and is not paused.
8. Create a validated deployment record with the exact 40-hex source commit and run
   `pnpm --filter @raffle-fun/contracts deployment:write ./candidate.json`.
9. Regenerate SDK/subgraph ABIs, create the network manifest, deploy the indexer, and
   configure the web app from that record.
10. Execute and document every smoke-test lifecycle, including exact deadline
    boundaries and post-failure refunds.

Mainnet has no default root deployment command. Add a reviewed, environment-guarded
operator procedure only after audit fixes and testnet monitoring.

## Monitoring and incident response

Monitor creation failures, draw requests, request/callback/NFT-redemption deadlines,
ignored callbacks, refund enablement, remaining refund and winning-cash liabilities,
quote solvency, USDC pause/blacklist indicators, redemptions, owner/pending-owner
changes, creation pause, and treasury events.

Existing raffles cannot be upgraded or paused. Response is limited to pausing future
creation, warning users, removing UI exposure, and deploying a new factory. Lifecycle
recovery in an existing raffle remains permissionless and cannot be redirected by the
owner.
