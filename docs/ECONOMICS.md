# Economics and accounting

Every v1 factory is bound to one immutable six-decimal quote token. A production
Ethereum factory must use official USDC.

## Fixed entry price and uncapped reserve

One raffle number always costs exactly:

```text
ENTRY_PRICE = 1_000_000 raw USDC = 1 USDC
```

A purchase of `n` entries transfers `n * ENTRY_PRICE` and mints one ticket
covering `n` consecutive numbers. The contract has no economic maximum price,
maximum total, or sale sell-out. `uint128` bounds entry counts only as an unreachable
machine limit.

The sponsor sets `reserveEntries` before creation. Because each entry is one dollar,
the reserve is the gross sales threshold in whole USDC. It is not the sponsor's net
payout: at exactly the reserve, the sponsor receives 95% after the protocol fee.
Equality counts as success:

```text
totalEntries >= reserveEntries  => NFT result
totalEntries <  reserveEntries  => cash result
```

If the sponsor wants a particular net amount `ask`, the corresponding gross reserve is:

```text
reserveEntries = ceil(ask / 0.95 USDC)
```

## Successful-result fee

```text
protocolFee = floor(grossSales * 500 / 10_000)
netPot      = grossSales - protocolFee
cashWinner  = floor(grossSales * 8_000 / 10_000)
cashSponsor = grossSales - protocolFee - cashWinner
```

The fee is 5% of aggregate gross sales and is calculated once, avoiding
per-purchase rounding.

### NFT result

The callback records only the result and winning entry. When anyone later settles the
winning ticket, the contract records its ID without reading its owner or burning it and
allocates:

```text
protocolFees    = protocolFee
sponsorProceeds = netPot
winner cash     = 0
```

The ticket remains transferable. Its current owner receives the NFT only by atomically
burning the ticket through `redeemWinningTicket`.

### Cash result

The callback records only the result and winning entry. When anyone later settles the
winning ticket, the transaction records its ID and allocates:

```text
protocolFees    = protocolFee
winnerProceeds = cashWinner
sponsorProceeds = cashSponsor
```

The sponsor also receives the NFT back. Assigning the subtraction remainder to the
sponsor conserves every raw quote-token unit. The cash result is final and never
changes to refunds. The cash amount remains attached to the transferable winning
ticket until its current owner atomically burns it and receives the amount through
`redeemWinningTicket`.

### Examples

With 100 entries and a reserve of 100:

| Recipient         |  Result |
| ----------------- | ------: |
| winning ticket    |     NFT |
| protocol treasury |  5 USDC |
| sponsor           | 95 USDC |

With 80 entries and a reserve of 100:

| Recipient         |        Result |
| ----------------- | ------------: |
| winning ticket    |       64 USDC |
| protocol treasury |        4 USDC |
| sponsor           | 12 USDC + NFT |

## Refunds

Three paths enter refunds: an empty raffle, a sold raffle with no request by
`endTime + 2 days`, or an accepted draw request with no valid callback before
`drawRequestedAt + 2 days`. The request and callback windows exclude their respective
deadlines; both refund transitions include them. A valid earlier callback is final.
Refunds charge no fee. Each ticket refunds:

```text
(lastEntry - firstEntry + 1) * ENTRY_PRICE
```

A refund call accepts at most 100 tickets, but a ticket can represent any positive
entry count. Duplicate, nonexistent, or foreign tickets revert the entire batch.

## Conservation

At every supported state:

```text
accountedQuoteBalance
  = unsettledPot
  + remainingRefundLiability
  + winnerProceeds
  + sponsorProceeds
  + protocolFees
```

The contract's actual quote balance must be at least that amount. Purchases and
outgoing transfers verify both expected balance deltas. Direct token donations are
unaccounted surplus and cannot be swept or converted into claims.

USDC issuer pauses, blacklists, upgrades, or other transfer failures may delay or
prevent individual payments. Exact-delta checking prevents silent underpayment but
cannot force an unavailable token to transfer.
