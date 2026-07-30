# Contributing

## Development contract

Use Node 22, pnpm 11.18.0, the pinned Solidity compiler, and the same canonical
`packages/contracts/src` tree for both Hardhat and Foundry. Do not add placeholder
addresses, copied ABIs, skipped tests, fake UI data, broad rescue functions, insecure
randomness, or unbounded settlement loops.

## Before opening a change

```bash
pnpm install --frozen-lockfile
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm --filter @raffle-fun/sdk sync:check
```

Contract changes also require:

```bash
pnpm contracts:test:foundry
pnpm contracts:test:hardhat
pnpm contracts:coverage
pnpm contracts:gas
pnpm contracts:slither
pnpm --filter @raffle-fun/contracts fmt:check
```

Update fixed vectors, invariants, ABI-generated files, subgraph mappings/tests,
documentation, and gas snapshots when behavior changes. Explain any coverage or gas
regression. A passing test is not evidence that a semantic change is safe.

## Commits and reviews

Keep commits focused and use clear imperative messages. Pull requests should describe
the invariant being preserved, threat-model impact, migration/deployment impact, and
commands actually run. Security-sensitive changes require independent review.
