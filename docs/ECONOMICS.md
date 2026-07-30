# Economics

## Constants

```text
BPS                  = 10,000
PROTOCOL_FEE_BPS     = 500  (5%)
PROVIDER_FEE_BPS     = 500  (5% when supplied and allowlisted)
CASH_WINNER_BPS      = 8,000 (80% of net pot)
MAX_TICKETS_PER_BUY  = 100
```

The gross ticket price is the total payment. All math operates in raw quote-token
units with floor rounding. Each raffle fixes one contract-backed ERC20 at creation;
verification is not required and amounts from different tokens are never combined.

## Purchase

For ticket price `P`, quantity `Q`, and provider-valid flag `V`:

```text
G  = P × Q
Fp = floor(G × 500 / 10,000)
Fr = V ? floor(G × 500 / 10,000) : 0
N  = G − Fp − Fr
```

The contract pulls `G` once, requires the balance to increase by exactly `G`, credits
`Fp` to the captured protocol treasury and `Fr` to the provider, and adds `N` to the
net pot. Thus:

```text
Fp + Fr + N = G
```

Rounding cannot create a deficit. Small purchases may round a fee down to zero, which
leaves that remainder in `N`.

## Resolution

Threshold equality uses the NFT branch:

```text
thresholdMet = totalTickets >= minimumTickets
```

When true, the winner claims the NFT and the sponsor receives the whole net pot.

When false:

```text
winnerCash  = floor(netPot × 8,000 / 10,000)
sponsorCash = netPot − winnerCash
```

The sponsor-side subtraction receives every rounding remainder, so created claims
equal the exact pot.

## Fixed vectors

These vectors use a six-decimal USDC-like quote token. The formulas are identical for
WETH or another exact-transfer token; only the raw unit scale changes.

### Provider, threshold met

`P = 1,000,000`, `Q = 120`, `minimum = 100`:

```text
gross       120,000,000 (120 USDC)
protocol      6,000,000
provider      6,000,000
net         108,000,000
winner      NFT
sponsor     108 USDC
```

### Provider, threshold missed

`P = 1,000,000`, `Q = 80`, `minimum = 100`:

```text
gross       80,000,000 (80 USDC)
protocol     4,000,000
provider     4,000,000
net         72,000,000
winner      57,600,000 (57.60 USDC)
sponsor     NFT + 14,400,000 (14.40 USDC)
```

### No provider

At 80 one-USDC tickets:

```text
gross       80 USDC
protocol     4 USDC
provider     0
net         76 USDC
cash winner 60.80 USDC
sponsor     NFT + 15.20 USDC
```

## Threshold selection

There is intentionally no maximum economic threshold. A high value cannot draw more
than gross sales or create insolvency; it only makes the cash branch more likely.
Sponsors and buyers must assess whether the implied gross target
`ticketPrice × minimumTickets` is realistic.

## Claims and overlap

Sponsor, winner, provider, treasury, buyer, and recipient may be the same address.
Credits accumulate in one `claimableQuote` mapping and are claimed once. Claim order
does not change the total. Direct quote-token transfers are unaccounted surplus and
cannot settle, cancel, or resolve a raffle.
