# Subgraph

Each deployment indexes one factory plus dynamic raffle templates. `RaffleCreated`
contains the recovery recipient and request grace deadline; the template then observes
the same-transaction `PrizeDeposited` event.

Mutable entities cover protocol/token aggregates, raffles, accounts, tickets, and
daily data. Immutable histories cover purchases, requests, successful resolutions,
draw failures, per-ticket refund credits, quote/prize claims, and ticket transfers.
`Raffle` exposes request/callback timestamps, remaining refund liability, total
credited refunds, prize claimant, and terminal outcome. `Ticket` records the frozen
refund owner and credited flag.

Event IDs use transaction hash plus log index and handlers guard duplicate delivery.
Amounts remain partitioned by quote token. Token admission is indexed for discovery;
delisting never rewrites existing raffle state.

## Generated sources and verification

```bash
pnpm contracts:build
pnpm sdk:sync
pnpm subgraph:codegen
pnpm subgraph:build
pnpm subgraph:test
pnpm --filter @raffle-fun/sdk sync:check
```

Do not hand-edit generated ABI/binding files. Matchstick covers atomic template
creation, same-block escrow, purchases/transfers, both normal branches, failed draw,
bounded ticket refund reconstruction, claims, aggregates, and idempotency.

The checked-in manifest is a build/test template. Production manifest generation must
read a validated network deployment record; there is no zero-address fallback.

The index may lag, reorganize, or fail. Transaction clients must reread registered
live state, deadlines, claimant/liability values, current token admission where
relevant, and the current entropy fee, then simulate before requesting a signature.
