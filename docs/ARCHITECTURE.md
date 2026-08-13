# Architecture

The protocol has three production contracts:

```mermaid
flowchart LR
  S[Sponsor] -->|createRaffle| F[RaffleFactory]
  F -->|CREATE constructor| R[Independent Raffle]
  F -->|safeTransferFrom exact prize| R
  U[Ticket holders] --> R
  P[Pyth Entropy v2] --> R
  L[RaffleLens] -->|read-only registry-authenticated view| R
```

## Constructor-deployed raffles

`RaffleFactory` uses ordinary `CREATE`; it does not use clones, initializers, proxies,
or deterministic addresses. Each raffle receives all dependencies and configuration in
its constructor. The constructor authenticates `msg.sender == factory` and begins in
`AwaitingPrize`.

The factory registers the new address, emits `RaffleCreated`, and transfers the exact
ERC-721 prize in the same transaction. The raffle receiver checks token contract,
token ID, sponsor, operator, and status. The factory then verifies `ownerOf` and
`Active`. Any failure reverts deployment, registry updates, events, and escrow.

## Factory authority

Every factory has one immutable USDC token, Pyth Entropy v2 address, and callback gas
limit. `Ownable2Step` administration can only pause future creation and select the
treasury captured by future raffles. It cannot alter existing raffles, replace their
dependencies, change a recipient, choose a winner, or rescue their assets.

`createRaffle` bounds start delay to seven days, sale duration to 30 days, ticket price
and threshold to positive values, and metadata to 2,048 bytes. A zero recovery
recipient defaults to the sponsor.

## Settlement

Tickets are ERC-721 bearer claims until a draw request fixes ownership. All transfers
freeze in `Drawing`, and the selected winner stays locked after resolution. For an NFT
win, the gross pot remains unsettled until exact prize delivery; successful delivery
creates sponsor and treasury pull claims. If delivery does not happen within 30 days,
the gross pot becomes full ticket refunds. Cash winners settle directly from callback
liabilities.

Known protocol contracts cannot receive tickets or asset payouts or be selected as new
fixed claimants. Future code-less addresses are unsupported. There is deliberately no
cross-raffle recovery dispatcher because a permissionless `CREATE` caller can capture a
predicted future raffle address.

The only quote accounting identity is:

```text
accountedQuoteBalance
  = unsettledPot
  + remainingRefundLiability
  + winnerCashLiability
  + totalClaimableQuote
```

## Read and indexing layers

`RaffleLens` is stateless and authenticates every raffle through the factory registry.
It returns the one status, four liabilities, current bearer ownership, deadlines,
dynamic Entropy fee, and account-specific actions. Its batch is capped at 64.

SDK and subgraph ABIs are generated from Hardhat artifacts. The subgraph mirrors status
and liabilities but is never authoritative for transactions; the web re-reads the lens
before every action.
