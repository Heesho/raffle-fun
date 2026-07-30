# Economics

## Constants

```text
BPS                  = 10,000
PROTOCOL_FEE_BPS     = 500   (5% of the gross pot at resolution)
CASH_WINNER_BPS      = 8,000 (80% of the distributable pot)
MAX_TICKETS_PER_BUY  = 100
```

The advertised ticket price is the total payment. All math operates in raw
quote-token units with floor rounding. Each raffle fixes one contract-backed ERC20 at
creation; verification is not required and amounts from different tokens are never
combined.

## Purchase

For ticket price `P` and quantity `Q`:

```text
purchaseGross = P × Q
```

The contract pulls `purchaseGross` once, requires its balance to increase by exactly
that amount, and adds the entire payment to `unsettledPot`. It allocates no fee and
creates no quote-token claim during ticket sales.

The minimum-ticket value is an outcome threshold, not a sales cap. Once the minimum is
reached, buyers may continue purchasing tickets until the fixed exclusive `endTime`.
Each additional ticket increases the gross pot and changes every ticket's odds.

## Resolution

The callback calculates the protocol fee once from the aggregate pot:

```text
grossPot         = unsettledPot
protocolFee      = floor(grossPot × 500 / 10,000)
distributablePot = grossPot − protocolFee
thresholdMet     = totalTickets >= minimumTickets
```

Calculating one aggregate fee prevents a buyer from changing fee rounding by splitting
one purchase into many small transactions.

When the threshold is met, the winner claims the NFT and the sponsor receives the
whole distributable pot.

When the threshold is missed:

```text
winnerCash  = floor(distributablePot × 8,000 / 10,000)
sponsorCash = distributablePot − winnerCash
```

The sponsor-side subtraction receives every rounding remainder. In both branches:

```text
protocolFee + winnerCash + sponsorCash = grossPot
```

At resolution, `unsettledPot` becomes zero and the complete gross pot becomes pull
claims for the treasury, winner, and sponsor as applicable.

## Fixed vectors

These vectors use a six-decimal USDC-like quote token. The formulas are identical for
WETH or another exact-transfer token; only the raw unit scale changes.

### Threshold met, sales continue past the minimum

`P = 1,000,000`, `Q = 120`, `minimum = 100`:

```text
gross pot       120,000,000 (120 USDC)
protocol fee      6,000,000 (6 USDC)
distributable   114,000,000 (114 USDC)
winner          NFT
sponsor         114 USDC
```

Ticket 100 makes the NFT branch likely, but tickets 101 through 120 remain valid
because the sale is open until `endTime`.

### Threshold missed

`P = 1,000,000`, `Q = 80`, `minimum = 100`:

```text
gross pot       80,000,000 (80 USDC)
protocol fee     4,000,000 (4 USDC)
distributable   76,000,000 (76 USDC)
cash winner     60,800,000 (60.80 USDC)
sponsor         NFT + 15,200,000 (15.20 USDC)
```

## Threshold selection

There is intentionally no maximum economic threshold. A high value cannot draw more
than gross sales or create insolvency; it only makes the cash branch more likely.
Sponsors and buyers must assess whether the implied gross target
`ticketPrice × minimumTickets` is realistic.

## Claims and overlap

Sponsor, winner, treasury, buyer, and recipient may be the same address. Credits
accumulate in one `claimableQuote` mapping and are claimed once. Claim order does not
change the total. Direct quote-token transfers are unaccounted surplus and cannot
settle, cancel, or resolve a raffle.
