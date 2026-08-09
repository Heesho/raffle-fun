# Economics and accounting

## Fixed constants

```text
BPS                           = 10,000
PROTOCOL_FEE_BPS              = 500    (5% of gross normal settlement)
CASH_WINNER_BPS               = 8,000  (80% of distributable cash branch)
MAX_TICKETS_PER_PURCHASE      = 100
MAX_REFUND_CREDIT_BATCH_SIZE  = 100
MAX_START_DELAY               = 7 days
MAX_SALE_DURATION             = 30 days
DRAW_REQUEST_GRACE_PERIOD     = 3 days
DRAW_CALLBACK_TIMEOUT         = 2 days
```

The advertised ticket price is the exact gross amount paid. All math uses raw token
units and floor rounding; decimals are display metadata only. New raffles may use only
tokens currently verified by the canonical factory. Delisting affects future creation
only.

## Purchase

```text
purchaseGross = ticketPrice × quantity
```

The raffle pulls the gross amount once, verifies the exact balance increase, and adds
it to both `grossSales` and `unsettledPot`. The minimum ticket count selects the
economic branch; it is not a sales cap.

## Normal resolution

```text
grossPot         = unsettledPot
protocolFee      = floor(grossPot × 500 / 10,000)
distributablePot = grossPot − protocolFee
thresholdMet     = totalTickets >= minimumTickets
```

When met, the winning ticket owner receives the NFT and the sponsor receives the
complete distributable pot. When missed:

```text
winnerCash  = floor(distributablePot × 8,000 / 10,000)
sponsorCash = distributablePot − winnerCash
```

The sponsor subtraction receives every rounding remainder. Conservation is exact:

```text
NFT branch:  protocolFee + sponsorCash = grossPot
cash branch: protocolFee + winnerCash + sponsorCash = grossPot
```

## Failed draw

Missing-request and callback-timeout outcomes charge no protocol fee and award no
sponsor proceeds or winner benefit:

```text
grossRefundLiability = grossSales = ticketPrice × totalTickets
protocolFee          = 0
```

The terminal transition moves the whole unsettled pot to
`uncreditedRefundLiability`. Each ticket later moves exactly one `ticketPrice` from
that aggregate into the frozen owner's `claimableQuote`. Therefore, after all ticket
IDs are credited, total refunds equal gross sales exactly. Crediting is bounded and
makes no token call; claim order cannot change totals.

## Continuous invariant

```text
accountedQuoteBalance =
    unsettledPot
  + uncreditedRefundLiability
  + totalClaimableQuote

quoteToken.balanceOf(raffle) >= accountedQuoteBalance
```

Claims reduce `totalClaimableQuote` only if an exact outgoing transfer succeeds.
Direct token donations are unaccounted surplus and do not affect economics. Native
accounting separately equals `totalClaimableNative`; forced native value is surplus.

## Asset/role overlap

Sponsor, winner, treasury, recovery recipient, buyer, and ticket recipient may be the
same account. Quote credits accumulate in one mapping. A recovery recipient receives
the prize in no-sales, cancellation, cash-fallback, and failed-draw branches, but
normal sponsor quote proceeds still belong to the sponsor. No branch lets a normal
winner also receive refunds, or the sponsor receive normal proceeds after a failed
draw.
