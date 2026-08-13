# Economics and accounting

Every factory is bound to one immutable exact-transfer USDC contract. `ticketPrice`
is the total paid per ticket; no fee is added at checkout.

For every successfully delivered prize or cash result:

```text
protocol fee       = floor(grossSales × 500 / 10_000)
distributable pot  = grossSales − protocol fee
```

If `totalTickets >= minimumTickets`, the callback records the winner but leaves the
gross pot unsettled. The winning ticket's NFT redemption and the creation of the
sponsor/treasury pull claims happen atomically. If delivery is not completed within 30
days, all tickets become refundable and no fee or sponsor proceeds are created.

If the threshold is missed:

```text
winning ticket cash = floor(distributable pot × 8_000 / 10_000)
sponsor cash        = distributable pot − winning ticket cash
```

The recovery recipient also withdraws the NFT. Assigning the division remainder to
the sponsor makes the split conserve value exactly.

Example with 80 tickets at 1 USDC and a 100-ticket threshold:

| Recipient                  |     Amount |
| -------------------------- | ---------: |
| Protocol treasury          |  4.00 USDC |
| Winning ticket             | 60.80 USDC |
| Sponsor                    | 15.20 USDC |
| Sponsor recovery recipient |        NFT |

Refunding charges no protocol fee and awards no sponsor proceeds. Each outstanding
ticket burns for exactly one `ticketPrice`, so the complete gross pot remains
attributable without an all-ticket loop.

The contract's accounted balance is always:

```text
unsettledPot
  + remainingRefundLiability
  + winnerCashLiability
  + totalClaimableQuote
```

Direct token donations are reported as surplus and never become raffle liabilities.
Incoming and outgoing transfers verify exact balance deltas; fee-on-transfer,
rebasing, or otherwise non-exact tokens are unsupported.
