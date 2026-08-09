:::part id="part-vi" no="Part VI" title="Economic Outcomes" compact="true"
Successful randomness charges the same protocol fee in NFT and cash branches. Oracle-
liveness failure charges no fee and reserves the gross pot for exact ticket refunds.
- 27|Outcome Overview
- 28|NFT Awarded
- 29|Cash Fallback
- 30|No Sales
- 31|Early Empty Close
- 32|Draw Not Requested
- 33|Draw Timed Out
- 34|Fee and Rounding Math
:::

# Part VI | Economic Outcomes

## 27. Outcome Overview

:::figure src="diagrams/09-outcome-comparison.svg" num="10" title="Outcome comparison" caption="Successful randomness produces one selected ticket and a fee. Liveness failure produces no winner or fee. Zero sales closes without a request."
:::

<!-- table:breakable -->
| Status | Trigger | Winning bearer | Protocol fee | Sponsor USDC | NFT claimant | Ticket refunds |
| --- | --- | --- | --: | --- | --- | --- |
| `NftWon` | valid callback; sold count at least threshold | burns selected ticket for NFT | {{PROTOCOL_FEE_PERCENT}} of gross, floored | all post-fee USDC | winning bearer | none |
| `CashWon` | valid callback; sold count below threshold | burns selected ticket for {{CASH_WINNER_PERCENT}} of post-fee pot | {{PROTOCOL_FEE_PERCENT}} of gross, floored | post-fee arithmetic remainder | fixed recovery recipient | none for other tickets |
| `Refunding` | missing request or callback deadline finalized | none | none | none | fixed recovery recipient | each current bearer burns for exact price |
| `Closed` | zero sold tickets | none | none | none | fixed recovery recipient | none because none sold |

`AwaitingPrize`, `Active`, and `Drawing` are nonterminal lifecycle statuses. The
winning and recovery claims can remain unredeemed after a terminal status. A status
records the economic result, not proof that every external transfer has completed.

## 28. NFT Awarded

Scenario A sells 120 tickets at 10.00 USDC with a threshold of 100:

| Allocation | Human amount | Raw six-decimal units |
| --- | --: | --: |
| Gross sales | {{EXAMPLE_NFT_GROSS}} USDC | `{{RAW_NFT_GROSS}}` |
| Protocol fee | {{EXAMPLE_NFT_FEE}} USDC | `{{RAW_NFT_FEE}}` |
| Sponsor claim | {{EXAMPLE_NFT_SPONSOR}} USDC | `{{RAW_NFT_SPONSOR}}` |
| Winner | Pixel Passport #42 | selected ticket burns |

:::figure src="diagrams/10-nft-awarded-flow.svg" num="11" title="NFT-awarded money flow" caption="The selected bearer burns for the NFT. Sponsor and treasury USDC are independent pull claims."
:::

The callback credits the treasury and sponsor; it does not transfer USDC. The selected
ticket remains transferable until an owner calls `redeemWinningTicket(to)`. The burn
occurs before safe transfer of the prize. If the destination rejects the NFT, the
complete transaction reverts and restores the ticket and prize state.

The sponsor can claim {{EXAMPLE_NFT_SPONSOR}} USDC to a safe nonzero destination. The
treasury can claim {{EXAMPLE_NFT_FEE}} USDC independently. Failure by either recipient
does not block the winner or the other quote claimant.

## 29. Cash Fallback

Scenario B sells 80 tickets, below the threshold, and receives a valid callback:

| Allocation | Human amount | Raw six-decimal units |
| --- | --: | --: |
| Gross sales | {{EXAMPLE_CASH_GROSS}} USDC | `{{RAW_CASH_GROSS}}` |
| Protocol fee | {{EXAMPLE_CASH_FEE}} USDC | `{{RAW_CASH_FEE}}` |
| Post-fee distributable | {{EXAMPLE_CASH_DISTRIBUTABLE}} USDC | gross minus fee |
| Winning bearer cash | {{EXAMPLE_CASH_WINNER}} USDC | `{{RAW_CASH_WINNER}}` |
| Sponsor cash remainder | {{EXAMPLE_CASH_SPONSOR}} USDC | `{{RAW_CASH_SPONSOR}}` |
| Recovery recipient | Pixel Passport #42 | separate NFT claim |

:::figure src="diagrams/11-cash-fallback-flow.svg" num="12" title="Cash-fallback money flow" caption="The winner share is {{CASH_WINNER_PERCENT}} of the post-fee pot, not of gross sales. The recovery recipient claims the NFT."
:::

The callback records the winner cash as `winnerCashLiability` and sponsor and treasury
amounts as ordinary quote claims. The selected ticket owner burns the ticket and
receives the exact cash amount in the same transaction. The recovery recipient claims
the NFT separately.

Cash fallback is a successful raffle outcome. It does not refund all buyers. Other
ticket holders receive no payment merely because the threshold was missed.

## 30. No Sales

Scenario E ends with zero tickets. No Entropy request is needed and there is no USDC
liability. At or after `endTime`, anyone may call `closeEmptyRaffle`. Status becomes
`Closed`, and the fixed recovery recipient may claim the prize.

Before `endTime`, the sponsor may call the same function if no tickets have sold. This
lets the sponsor end an unused raffle without waiting. Once ticket 1 is sold,
`closeEmptyRaffle` is permanently unavailable because `totalTickets` never decreases,
even when tickets later burn.

## 31. Early Empty Close

The current contract does not expose a general `cancel` function or `Cancelled`
status. The sponsor's only early-close path is a zero-sales close. This matters for
public wording:

- before any sale, the sponsor may close and the recovery recipient may claim the NFT;
- after any sale, the sponsor cannot cancel, change terms, or reclaim the NFT by
  discretion;
- a sold raffle must follow draw, cash/NFT settlement, or deadline refunds.

This is the accurate counterpart to the common phrase "cancellation before sales."
It should not be described as an administrator override.

## 32. Draw Not Requested

Scenario C uses the same 80-ticket, {{EXAMPLE_CASH_GROSS}} USDC gross pot, but no draw
request succeeds before the grace deadline.

:::figure src="diagrams/12-missing-request-refund.svg" num="13" title="Missing-request refund flow" caption="At the request-grace deadline, anyone may enable exact bearer refunds. There is no winner, fee, or sponsor proceeds."
:::

When anyone calls `enableRefunds` at or after the deadline:

- status moves from `Active` to `Refunding`;
- `unsettledPot` becomes zero;
- `remainingRefundLiability` becomes {{EXAMPLE_REFUND_TOTAL}} USDC;
- no winning ticket is selected;
- no treasury fee or sponsor claim is created;
- the recovery recipient can claim Pixel Passport #42.

Each current ticket owner may burn owned tickets for {{EXAMPLE_REFUND_EACH}} USDC
each. All 80 tickets together account for `{{RAW_REFUND_TOTAL}}` raw units.

## 33. Draw Timed Out

Scenario D accepts a valid request and freezes nothing. Ticket transfers remain
available. If no matching callback wins before timeout finalization, anyone calls
`enableRefunds` at or after `drawRequestedAt + {{CALLBACK_TIMEOUT_DAYS}} days`.

The financial outcome is the same as missing-request failure: no winner, no fee, no
sponsor proceeds, exact bearer refunds, and the NFT for the recovery recipient. The
event records that a request had been accepted.

A late callback after `Refunding` emits an ignored callback event and cannot reverse
refund liability. At the exact timeout boundary, transaction order decides whether
the callback or refund finalization wins.

## 34. Fee and Rounding Math

The successful-settlement formulas are:

`grossSales = ticketPrice x totalTickets`

`protocolFee = floor(grossSales x {{PROTOCOL_FEE_BPS}} / 10,000)`

`distributablePot = grossSales - protocolFee`

For `NftWon`:

`sponsorCash = distributablePot`

For `CashWon`:

`winnerCash = floor(distributablePot x {{CASH_WINNER_BPS}} / 10,000)`

`sponsorCash = distributablePot - winnerCash`

Solidity uses integer arithmetic. `Math.mulDiv` performs multiplication and division
with floor rounding. The sponsor receives the arithmetic remainder after winner cash,
so the fee, winner amount, and sponsor amount allocate every raw unit.

The winner gets {{CASH_WINNER_PERCENT}} of the post-fee distributable pot, not
{{CASH_WINNER_PERCENT}} of gross sales. With {{EXAMPLE_CASH_GROSS}} USDC gross, that
distinction produces {{EXAMPLE_CASH_WINNER}} USDC for the winner, not 640.00 USDC.

:::figure src="diagrams/21-worked-example.svg" num="14" title="Pixel Passport #42 across all branches" caption="All names and assets are fictional. Every monetary amount is produced by the build from compiled constants and six-decimal integer arithmetic."
:::
