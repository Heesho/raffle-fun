# Subgraph

The subgraph is a discovery and history layer for the canonical factory and its
clones. It is never transaction authority; clients must simulate writes against live
chain state.

## Range-ticket model

One `Ticket` entity is created for each `TicketPurchased` event. It stores the
sequential token ID plus `firstEntry`, `lastEntry`, and `entryCount`. The mapping
never loops from first to last and never creates one entity per raffle number.

ERC-721 `Transfer` events update the current owner and burn state. Because ERC-721
emits the mint transfer before `TicketPurchased`, the handler permits a temporary
ticket shell and fills its range from the later event in the same transaction.

The winning entry is known at `RaffleResolved`, but finding the containing ticket
would require an index scan. The subgraph deliberately does not do that. It records
`winningTicketId` only when a valid ticket is settled; clients can compare an
individual ticket's range with `winningEntry` directly.

## Indexed state

Primary mutable entities include:

- `Protocol`, `QuoteTokenStats`, and daily aggregates;
- `Raffle` with the six-state enum and five quote-liability buckets;
- `Ticket`, `Purchase`, and `RaffleTransfer`;
- account and raffle-participation aggregates;
- `DrawRequest`, `Resolution`, and `RefundEnable`;
- refund, winning settlement and redemption, sponsor/protocol release, and sponsor
  prize-release history.

All integer amounts and ticket IDs remain Graph `BigInt`; they are never cast
through JavaScript `Number`.

The schema has no Lens, per-entry Ticket, Closed status, scheduled start, mutable
ticket price, metadata URI, or recovery-recipient field. Cash resolutions record both
winner and sponsor amounts directly from the canonical event.

## Generated ABI flow

ABIs are synchronized from canonical Hardhat artifacts:

```bash
pnpm --filter @raffle-fun/contracts compile
pnpm --filter @raffle-fun/sdk sync
pnpm --filter @raffle-fun/subgraph codegen
pnpm --filter @raffle-fun/subgraph build
pnpm --filter @raffle-fun/subgraph test
```

The manifest is generated from a validated deployment record. No placeholder
deployment address is accepted. `WinningTicketSettled` records the winning ticket ID,
settler, and allocated liabilities without fixing an owner. `WinningTicketRedeemed`
records the owner who atomically burns the ticket and receives its cash or NFT. Sponsor
and protocol releases remain separate events.
