# Current protocol specification

Status: normative security-review summary for the committed Ethereum v1 audit candidate.
Production Solidity and interfaces are authoritative if this document conflicts with code.

## Contract graph and fixed configuration

`RaffleFactory` deploys one locked `Raffle` implementation and creates canonical,
non-upgradeable ERC-1167 clones. Its two-step owner may pause future creation only.
Every clone shares the factory's immutable six-decimal quote token, Chainlink VRF v2.5
native direct-funding wrapper, protocol treasury, 300,000 callback gas limit, and 30
request confirmations.

Each raffle fixes its sponsor, immutable `sponsorRecipient`, prize contract and token ID,
reserve entry count, and exclusive sale end. The sponsor is `msg.sender` at creation;
the recipient may be a different operational or cold wallet. There is no Lens, raffle
administrator, upgrade path, generic call, rescue function, variable entry price, or
protocol-level gross-value cap.

## Creation, entries, and tickets

Creation clones, initializes, registers, escrows the exact NFT, and verifies custody and
`Active` status in one atomic transaction. Each entry costs exactly `1_000_000` raw quote
units. `buyEntries(recipient, entryCount)` collects `entryCount` dollars and mints one
ERC-721 ticket with a sequential ID. A separate mapping stores that ticket's inclusive
`uint128` entry range. Ranges start at one and partition all sold entries without gaps.

Unburned tickets remain transferable in every status. Current `ownerOf(ticketId)` is the
bearer credential at settlement or refund time. Purchase and winning-ticket verification
are O(1) in entry count; refunds loop over at most 100 supplied ticket IDs.

## Lifecycle and liveness

```text
0 AwaitingPrize
1 Active
2 Drawing
3 NftWon
4 CashWon
5 Refunding
```

```mermaid
stateDiagram-v2
  [*] --> AwaitingPrize: clone initialization
  AwaitingPrize --> Active: exact prize deposit
  Active --> Drawing: permissionless request in [end, D)
  Active --> Refunding: empty raffle or sold raffle at D
  Drawing --> NftWon: valid callback; reserve met
  Drawing --> CashWon: valid callback; reserve missed
  Drawing --> Refunding: callback deadline C
```

Sales require `now < endTime`. Let `D = drawRequestDeadline() = endTime + 2 days`.
For a sold raffle, `requestDraw` is callable exactly in `[endTime, D)`. If no request
succeeds, anyone may enable full refunds at and after `D`; a request at `D` is invalid.
A request enters `Drawing` before calling the wrapper and sets
`C = callbackDeadline() = drawRequestedAt + 2 days`. An authenticated, ABI-decodable,
matching callback may resolve only before `C`. At and after `C` it is ignored, even if
no refund transaction has executed, while anyone may enable full refunds. Neither
deadline changes status automatically.

A request included at `D - 1` receives its own two-day callback window, so the last
nominal callback/refund boundary is almost four days after sale end. Censorship or a
reorganization that removes a request or callback after its cutoff prevents replay and
can force the refund branch.

A valid callback records only `winningEntry`, `resolvedAt`, and the final `NftWon` or
`CashWon` status. Neither resolved status can later enter refunds. An empty raffle can
enter zero-liability `Refunding` immediately through the sponsor or after `endTime`
through anyone.

## Randomness

Any account may pay the live native wrapper price for one word. Exact fee is forwarded
and excess is returned atomically. Only the immutable wrapper is authorized. Only
wrapper-authenticated calls whose calldata ABI-decodes reach the callback qualification
logic. In-flight, wrong-request, stale, duplicate, wrong-word-count, and deadline-expired
callbacks are ignored with an event; unauthorized calls and undecodable calldata revert
earlier.

```text
winningEntry = (randomWord % totalEntries) + 1
result = totalEntries >= reserveEntries ? NftWon : CashWon
```

The callback never searches tickets, loops over entries, transfers a token, or calls a
user. Its fixed gas-unit limit does not cap Ethereum's gas price; the wrapper's live
native quote changes with gas pricing.

## Settlement and fixed destinations

`settleWinningTicket(ticketId)` is permissionless. The contract proves the supplied
range contains `winningEntry`, snapshots its current owner as `winnerRecipient`, burns
the ticket, and records every terminal liability without transferring an external
asset. There is no caller-selected destination.

For gross sales `G`:

```text
protocolFee = floor(G * 500 / 10_000)
cashWinner  = floor(G * 8_000 / 10_000)
```

- `NftWon`: record the ticket owner as the fixed NFT recipient, `G - protocolFee` as
  `sponsorProceeds`, and `protocolFee` as `protocolFees`.
- `CashWon`: record `cashWinner` as `winnerProceeds`, `G - protocolFee - cashWinner`
  for the sponsor, and `protocolFee` for the protocol. The sponsor prize is independently
  releasable.
- `Refunding`: the current owner calls `refundTickets`, burns one to 100 owned tickets,
  and receives exactly their aggregate entry count times one USDC.

Anyone may call `releaseWinnerProceeds`, `releaseWinnerPrize`,
`releaseSponsorProceeds`, `releaseProtocolFees`, or `releaseSponsorPrize`. They always
pay the snapshotted winner or immutable sponsor/treasury recipient; the caller cannot
redirect value. A failed winner release restores only that winner claim and cannot
roll back settlement or another party's liability.

NFT delivery deliberately uses ERC-721 `transferFrom` plus `ownerOf` verification so a
contract recipient cannot veto fixed delivery by rejecting a receiver callback. A
noncompliant prize contract remains outside the supported-asset model.

## Accounting

```text
accountedQuoteBalance
  = unsettledPot
  + remainingRefundLiability
  + winnerProceeds
  + sponsorProceeds
  + protocolFees
```

Incoming and outgoing quote transfers verify exact sender and recipient balance deltas.
Settlement has no external asset interaction. Each release zeroes only its own claim
before an external interaction under a reentrancy guard; a failed transfer restores
that claim without affecting settlement or other recipients. Direct quote donations are
unaccounted surplus and have no rescue path.

## Trust boundary

Correctness assumes available exact-transfer official USDC, an honest standards-compliant
ERC-721 prize, Ethereum inclusion/finality, and the configured Chainlink wrapper and
coordinator. Existing clones cannot be patched. Release blockers and accepted external
risks are tracked in `CURRENT-RESIDUAL-RISKS.md` and `RELEASE-CHECKLIST.md`.
