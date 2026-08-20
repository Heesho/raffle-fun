# Deployment runbook

There is no public deployment record in this repository. Hardhat Ignition is the
canonical deployment path; the Foundry script independently checks constructor and
state assumptions. Mainnet deployment remains blocked until the current v1 source is
independently audited and every release-checklist item is closed.

## Fixed deployment parameters

Each factory constructor receives:

```text
quoteToken          official six-decimal USDC
vrfWrapper          official Chainlink VRF v2.5 native direct-funding wrapper
protocolTreasury    reviewed immutable fee recipient
```

The implementation fixes:

```text
entry price            1 USDC
protocol fee           5%
callback gas           300,000
request confirmations  30
draw request timeout    2 days after sale end
callback timeout       2 days
max sale duration      30 days
max refund batch       100 tickets
```

The current official addresses are encoded only as validation allowlists, not as
unchecked deployment defaults. Reconfirm them against Chainlink and Circle at the
release block.

## Release gates

- independent audit of the exact source, generated ABI, dependency lock, and compiler;
- exact `@chainlink/contracts@1.5.0` dependency and official
  `VRFV2PlusWrapperConsumerBase` integration present in the verified implementation source;
- no unresolved critical, high, or medium finding;
- clean format, lint, typecheck, build, unit, fuzz, invariant, model, coverage, gas,
  Slither, SDK, subgraph, and web checks;
- Ethereum mainnet and Sepolia fork checks against the live USDC and VRF wrapper;
- callback measurement with production bytecode below the fixed 300,000 limit;
- reviewed contract-wallet treasury on mainnet;
- exact source verification for factory and implementation;
- successful Sepolia soak of both result branches, the no-request refund path, and
  the callback timeout;
- legal and compliance approval for every intended market and user flow;
- monitoring, keeper, incident-response, and frontend-disable procedures rehearsed.

The executable handoff list is
[packages/contracts/audit/RELEASE-CHECKLIST.md](../packages/contracts/audit/RELEASE-CHECKLIST.md).

## Environment

```text
DEPLOYER_PRIVATE_KEY
QUOTE_TOKEN
VRF_WRAPPER
PROTOCOL_TREASURY
SEPOLIA_RPC_URL
ETHEREUM_RPC_URL
ETHERSCAN_API_KEY
```

The same values are supplied as reviewed Ignition parameters or Foundry environment
variables. Do not store real keys or unreviewed parameter files in the repository.

## Sepolia procedure

1. Record a clean source commit, compiler version, lockfile hash, and expected
   bytecode.
2. Run the complete release validation matrix.
3. Reverify official Sepolia USDC and wrapper addresses from primary sources.
4. Deploy the factory with reviewed parameters using `pnpm deploy:sepolia`.
5. Record the factory transaction, factory address, and
   `raffleImplementation()` address.
6. Verify factory and implementation source. The implementation constructor arguments
   are the exact quote token and wrapper supplied to the factory.
7. Confirm the factory ABI exposes no owner, pause, upgrade, or mutable configuration.
8. Validate at a finalized block and record that block's hash plus every runtime code
   hash.
9. Require the implementation to report `initialized == true`,
   `status == Refunding`, `ENTRY_PRICE == 1_000_000`,
   `callbackGasLimit == 300_000`, and `requestConfirmations == 30`.
10. From a completely clean checkout of the recorded `sourceCommit`, write the
    candidate through the strict deployment-record validator. It force-compiles the
    production profile, requires solc 0.8.36 / optimizer 200 / Cancun, matches the
    deployment transaction input including constructor arguments, materializes and
    matches both runtimes from compiler immutable references, and independently checks
    exact Etherscan V2 source publication for the factory and implementation. Never
    hand-edit a placeholder into application configuration.
11. Regenerate and drift-check SDK/subgraph ABIs, deploy the subgraph, then configure
    the web application from the validated record.
12. Run the complete [Sepolia soak plan](SEPOLIA-SOAK.md).

For each created raffle, verify the canonical 45-byte ERC-1167 runtime embeds the
recorded implementation, the factory registry is bijective, the clone is initialized
and `Active`, and the configured prize is actually owned by the clone.

## Mainnet procedure

No default mainnet deployment command exists. Add a separately reviewed,
environment-guarded operator command only after the audit and Sepolia gates pass.
Repeat every validation at a finalized Ethereum block, require verified source and a
reviewed contract-wallet treasury, use a fresh deployment key, and publish the
deployment record only after independent verification.

Do not advertise or enable public creation while any record, source-verification,
indexer, keeper, legal, monitoring, or incident-response gate remains incomplete.

## Operational authority

The factory and existing raffles cannot be upgraded or paused. Incident response is
limited to warning users, disabling first-party surfaces and sponsor onboarding,
assisting permissionless draw, refund, settlement, and fixed-recipient release calls,
supporting owner-controlled redemption, and deploying a new factory. No operator can
rewrite or rescue a raffle.
