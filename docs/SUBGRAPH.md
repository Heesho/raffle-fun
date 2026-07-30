# Subgraph

## Model

Each deployment indexes one chain. `RaffleFactory` is the static data source;
`RaffleCreated` initializes the `Raffle` entity and creates a dynamic `Raffle`
template. The factory emits before prize escrow, allowing the template to receive
`PrizeDeposited` later in the same transaction/block.

Entities:

- mutable state: `Protocol`, `QuoteTokenStats`, `Raffle`, `Account`,
  `AccountTokenStats`, `RaffleAccount`, `Ticket`, `ProtocolDayData`,
  `RaffleDayData`;
- immutable history: `Purchase`, `DrawRequest`, `Resolution`, `QuoteClaim`,
  `PrizeClaim`, `RaffleTransfer`.

IDs avoid unbounded arrays. Event histories use transaction hash plus log index and
guard duplicate delivery before changing aggregates. Monetary protocol, account, and
daily aggregates are partitioned by quote token; values from different ERC20s are
never added together. `QuoteTokenVerificationUpdated` maintains the mutable discovery
label used by public UI lists; it does not alter raffle state.

## Generated sources

ABIs come from Hardhat artifacts:

```bash
pnpm contracts:build
pnpm sdk:sync
pnpm subgraph:codegen
```

Do not edit `packages/subgraph/abis/*.json` or generated bindings manually.
`pnpm --filter @raffle-fun/sdk sync:check` fails if committed ABI outputs drift.

## Manifest generation

The checked-in `subgraph.yaml` is a compile/test template without a fake factory
address. Production generation reads the validated network deployment record:

```bash
pnpm --filter @raffle-fun/subgraph manifest:base-sepolia
pnpm --filter @raffle-fun/subgraph manifest:base
```

This creates `subgraph.generated.yaml` with the exact factory address and start block.
Missing records fail; there is no zero-address fallback.

## Test and build

```bash
pnpm subgraph:codegen
pnpm subgraph:build
pnpm subgraph:test
```

Matchstick covers dynamic template creation, same-block prize deposit, purchases,
multi-ticket ownership, transfers, both resolution branches, claims, aggregates, and
duplicate-event idempotency.

## Local and Studio deployment

```bash
pnpm --filter @raffle-fun/subgraph deploy:local
pnpm --filter @raffle-fun/subgraph deploy:studio
```

Run manifest generation first for Studio. A local Graph Node expects JSON-RPC, IPFS,
Postgres, and Graph Node endpoints from the documented script.

## Consumer rules

The index supplies lists, search, profiles, per-token aggregates, and activity. It may
lag, reorganize, or fail. A transaction client must reread factory/raffle state
onchain, validate the chain, selected quote token, and provider, fetch current Entropy
fee, and simulate the call.
