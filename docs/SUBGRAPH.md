# Subgraph

The subgraph indexes the factory registry, the one raffle status, bearer ticket
ownership and burns, the four quote liabilities, purchases, draw requests,
resolutions, refund enablement, redemptions, and sponsor/treasury claims.

Important entities include `Raffle`, `Ticket`, `Resolution`, `RefundEnable`,
`RefundRedemption`, `WinningRedemption`, `QuoteClaim`, and `SponsorPrizeClaim`.
`Raffle.status` uses the same seven values as `IRaffle.Status`; the indexer does not
recreate a state/outcome split.

The subgraph is a discovery and history layer, never transaction authority. The web
uses `RaffleLens` to authenticate addresses and refresh current owner, deadlines,
liabilities, Entropy fee, and available actions before writes.

ABIs are generated from canonical Hardhat artifacts:

```bash
pnpm --filter @raffle-fun/contracts compile
pnpm --filter @raffle-fun/sdk sync
pnpm --filter @raffle-fun/subgraph codegen
pnpm --filter @raffle-fun/subgraph build
pnpm --filter @raffle-fun/subgraph test
```
