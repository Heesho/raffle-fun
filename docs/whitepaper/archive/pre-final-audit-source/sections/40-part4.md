:::part id="part-iv" no="Part IV" title="Outcomes and Money"
Every way a raffle can end, and where every unit of money goes in each one.
- 17|Outcome Overview
- 18|Threshold Met: the NFT Branch
- 19|Threshold Missed: the Cash Branch
- 20|No Sales and Early Cancellation
- 21|Failed Draws, Timeouts, and Refunds
- 22|Fees and Accounting
- 23|Why Claims Are Pulled
:::

# Chapter 17 | Outcome Overview

Every raffle ends in exactly one of six recorded outcomes. This chapter is the map;
the next four chapters walk each road.

:::figure src="diagrams/outcomes.svg" num="9" title="All six terminal outcomes" caption="The two outcomes decided by the random draw (top) and the four endings where no draw ever completes (bottom). Every card lists who gets the NFT, who gets money, and who may finalize. No other endings exist in the contract."
:::

<!-- table:breakable,small -->
| Outcome | Triggered by | NFT goes to | Ticket holders receive | Sponsor receives | Protocol fee | Randomness | Finalized by |
| --- | --- | --- | --- | --- | --- | --- | --- |
| NftAwarded | draw lands, tickets >= minimum | winner | nothing (winner got the NFT) | 95% of pot | 5% of pot | required | Entropy callback |
| CashFallback | draw lands, tickets < minimum | recovery address | winner alone: 76% of pot | 19% of pot plus rounding dust | 5% of pot | required | Entropy callback |
| NoSales | end passes, zero sold | recovery address | no holders exist | nothing (no pot) | none | never requested | anyone |
| CancelledBeforeSale | sponsor cancels, zero sold | recovery address | no holders exist | nothing (no pot) | none | never requested | sponsor only |
| DrawNotRequested | 3 days pass after end, no request | recovery address | full ticket price back, per ticket | nothing | none | never requested | anyone |
| DrawTimedOut | request accepted, 2 days no callback | recovery address | full ticket price back, per ticket | nothing | none | requested, unanswered | anyone |

Three regularities are worth noticing. The prize always goes to exactly one of two
places: the winner (only in NftAwarded) or the fixed recovery address (everywhere
else). The protocol charges its fee only when a verified random draw actually
resolved the raffle; every failure and every empty raffle is free. And the two
refund outcomes are economically identical: what differs is only which deadline
expired.

# Chapter 18 | Threshold Met: the NFT Branch

:::callout kind="sentence"
When the draw lands with at least the minimum sold, the winning ticket's holder
claims the NFT, the sponsor is credited 95 percent of the pot, and the treasury 5
percent.
:::

Ava's raffle closes at 120 tickets, comfortably past her minimum of 100. Noor holds
ticket 87. Someone requests the draw; the random number arrives and maps to
ticket 87. In that single callback transaction the contract records: winner Noor,
outcome NftAwarded, prize claimant Noor, treasury credited 60 USDC (5 percent of
the 1,200 pot), sponsor credited the remaining 1,140 USDC. No tokens move yet.

Noor then calls claimPrize with the destination of her choice, and the NFT leaves
escrow to that address. Ava calls claimQuote and withdraws 1,140 USDC; the treasury
withdraws its 60. Each claim is independent. If Noor is on vacation for a month, her
claim waits untouched; nothing expires, and nobody can jump the queue or redirect
it. Alternatively, anyone may call the push variants (claimPrizeFor, claimQuoteFor)
which deliver only to the recorded claimant, useful for helping a less technical
winner.

The winner receives no share of the money in this branch; the winner's prize is the
NFT itself. All other ticket holders receive nothing, which is what "raffle" means;
their tickets remain as souvenirs.

# Chapter 19 | Threshold Missed: the Cash Branch

:::callout kind="sentence"
When the draw lands below the minimum, the raffle still draws one winner, but the
prize is cash: 80 percent of the post-fee pot, while the NFT returns to the
sponsor's recovery address.
:::

Suppose instead only 80 tickets sold by closing time, and the draw picks ticket 12,
held by Ben. The pot is 800 USDC. The callback computes: fee 40 USDC (5 percent),
distributable 760, winner's share 608 (80 percent of 760, which is 76 percent of the
whole pot), sponsor's share the exact remainder, 152. The prize claimant is the
recovery address Ava configured. Ben withdraws 608 USDC; Ava withdraws 152 and her
vault wallet reclaims the artwork.

The design reasoning: the sponsor set the minimum as the level of interest below
which parting with the prize is not worth it, so the prize returns. But buyers took
a real chance and someone must win something real, so the bulk of the pot becomes a
cash prize. The sponsor's 19 percent compensates the effort of running the raffle
while keeping the sponsor's incentive pointed at reaching the minimum, not missing
it. Ticket holders other than the winner receive nothing in this branch either.

Rounding, stated plainly: both the fee and the winner's share round down to the
smallest token unit, and the sponsor's share is defined as what remains, so the
three parts always sum to the pot exactly. With USDC the largest possible rounding
effect is under two millionths of a dollar, always in the sponsor's favor.

# Chapter 20 | No Sales and Early Cancellation

Two quiet endings share a property: no money ever entered, so nothing needs
distributing and neither branch involves randomness or fees.

**No sales.** The closing time passes with zero tickets sold. Anyone (a bot, an
indexer, Ava herself) calls closeNoSales; the raffle resolves with outcome NoSales,
and the recovery address may reclaim the NFT. Because the call is permissionless, a
sponsor who lost their keys after creation does not strand the prize: anyone can
close, and the recovery address (a separate wallet, if the sponsor chose wisely) can
reclaim.

**Early cancellation.** Before the first ticket sells, and only then, the sponsor
may cancel outright, at any moment, even mid-sale or after the end. The raffle moves
to the Cancelled state, and the recovery address reclaims the prize. The instant
ticket 1 sells, this power is gone forever: from then on the raffle can only end
through a draw, a no-sales close (impossible once a ticket exists), or the refund
path. A sponsor can therefore never pull the prize out from under paying
participants.

:::callout kind="enforce"
cancelBeforeSales checks the caller is the sponsor and that totalTickets is zero;
closeNoSales checks the end has passed and totalTickets is zero. Both set the prize
claimant to the fixed recovery address and are terminal. There is no path in the
contract that cancels a raffle with even one sold ticket.
:::

# Chapter 21 | Failed Draws, Timeouts, and Refunds

:::callout kind="sentence"
If the draw is never requested within 3 days of closing, or a requested draw goes
unanswered for 2 days, anyone can switch the raffle into refund mode: every ticket
is credited its exact price back, no fee is charged, and the prize returns home.
:::

A raffle that sold tickets owes its participants an ending. Normally that ending is
the draw; but the draw depends on two things the contract cannot compel: some person
sending the request, and the oracle answering it. The protocol converts both
dependencies into fixed deadlines with a deterministic exit.

:::figure src="diagrams/oracle-liveness.svg" num="10" title="Timeout and refund flow" caption="The two questions every sold-out-of-time raffle answers: was the draw requested in 3 days, and did the callback arrive in 2? Two 'no' roads lead to the same Refunding state, where anyone can credit every ticket its refund. The gray box explains the race a late callback can still win."
:::

## The two deadlines

The request window: from the closing time until 3 days after it, requestDraw is
open to everyone. At the deadline, requestDraw shuts and finalizeUnrequestedDraw
opens, also to everyone. The callback window: an accepted request starts a 2-day
clock; if no valid callback lands in time, finalizeTimedOutDraw opens to everyone.
One subtlety is deliberate: a late callback is still honored until the moment a
timeout transaction actually executes. At the boundary the two race, the first one
included on the chain wins, and the loser becomes a harmless no-op. What can never
happen is a mixed result: either the raffle resolved with a winner, or it refunds
everyone, never both.

## How refunds work

Entering Refunding does three things at once: the entire pot is reclassified as
refund debt, the prize claimant becomes the recovery address, and outcome
DrawNotRequested or DrawTimedOut is recorded. No protocol fee is charged, and the
sponsor receives none of the pot: a failed raffle earns nobody anything.

Refunds are then credited ticket by ticket, in permissionless batches of up to 100
ticket IDs per transaction. For each ticket, the contract records the current
holder, marks the ticket as credited (each ticket exactly once, enforced), and adds
exactly one ticket price to that holder's withdrawable balance. Crediting touches no
external contract, so a hostile holder cannot block a batch that includes them, and
one holder's problem never delays another's refund. Because each ticket is frozen
from the moment Refunding begins until it is credited, the refund goes precisely to
whoever held the ticket when the raffle failed. Holders then withdraw with the same
pull claim as any other payout; the batching cost is borne by whoever volunteers to
send the crediting transactions (typically the frontend operator or any interested
holder), never deducted from refunds.

:::callout kind="example"
The 80-ticket raffle's request window expires with no request (say the fee spiked
and everyone hesitated). Anyone calls finalizeUnrequestedDraw. The 800 USDC pot
becomes 80 refunds of exactly 10 USDC. One transaction credits tickets 1 through 80:
Ben's balance rises by 50 (his 5 tickets), Maya's by 80, Leo's by 20 for the two
tickets Maya gave him (the holder, not the payer, is refunded), Noor's by 200, and
so on. Ava's vault reclaims the artwork. Nobody profits and nobody loses except the
3 days everyone spent waiting.
:::

:::callout kind="noguarantee"
The refund guarantee covers what the contract controls: the money is reserved, the
crediting is permissionless, and the claims never expire. It does not cover a
payment-token issuer freezing transfers, a chain outage outlasting every deadline,
or a holder losing their own keys. Those sit on the trust map in Chapter 31.
:::

# Chapter 22 | Fees and Accounting

:::callout kind="sentence"
One fee exists in the whole protocol: 5 percent of the pot, charged once, only when
a verified random draw resolves the raffle; every other flow is conservation.
:::

:::figure src="diagrams/money-flow.svg" num="11" title="Where the money goes" caption="The flow of ticket money from buyers through the pot to the three possible claimants, with the worked example's exact numbers, and the two flows that never mix with it: the oracle fee in ETH, and the failed-draw case where the split never happens and the full pot becomes refunds."
:::

## The formulas, exactly as implemented

All amounts are raw integer token units; divisions round down (floor).

```text
purchase           gross = ticketPrice x quantity
resolution         fee = floor(pot x 500 / 10,000)
                   distributable = pot - fee
threshold met      sponsorCash = distributable          (winner takes the NFT)
threshold missed   winnerCash = floor(distributable x 8,000 / 10,000)
                   sponsorCash = distributable - winnerCash
failed draw        refund per ticket = ticketPrice      (fee = 0)
identity           fee + winnerCash + sponsorCash = pot   (resolved branches)
                   sum of refunds = pot                   (refund branches)
```

Two design choices deserve a sentence each. The fee is computed once on the
aggregate pot at resolution, not per purchase, so splitting a purchase into many
tiny ones cannot shave the fee through repeated rounding. And the ticket price is
gross: the number advertised is exactly the number a buyer pays, with the fee taken
from the pot later rather than added on top at checkout.

## Worked examples, verified against the code

| Case | Pot | Fee (5%) | Winner | Sponsor |
| --- | --: | --: | --: | --: |
| 120 tickets x 10 USDC, minimum met | 1,200.00 | 60.00 | the NFT | 1,140.00 |
| 80 x 10 USDC, minimum missed | 800.00 | 40.00 | 608.00 | 152.00 |
| 99 x 10 USDC, one below minimum | 990.00 | 49.50 | 752.40 | 188.10 |
| 10 x 0.333333 USDC, missed (dust case) | 3.333330 | 0.166666 | 2.533331 | 0.633333 |
| 1 x 10 USDC, minimum missed | 10.00 | 0.50 | 7.60 | 1.90 |
| any failed draw | pot | 0 | 0 | 0; all pot refunded |

The dust case shows floor rounding at work: the exact 5 percent of 3,333,330 raw
units is 166,666.5, which floors to 166,666, and the winner's 80 percent floors
likewise; the sponsor's remainder absorbs both half-units. Every row reproduces
exactly with the SDK's math functions and matches the contract's own test vectors.

## The solvency invariant

At every moment, the raffle's actual token balance is at least the sum of its three
liabilities: the unsettled pot, the not-yet-credited refund debt, and the total of
all recorded claims. Tokens sent to the raffle by mistake (a direct donation rather
than a purchase) sit above that line as visible surplus: they are never counted as
anyone's claim, can never trigger or alter a settlement, and have no withdrawal
path. The same discipline applies to the native currency: only draw-fee overpayments
are claimable, and force-pushed ETH is inert surplus. These properties are enforced
by construction and continuously checked by the invariant test suite.

# Chapter 23 | Why Claims Are Pulled

:::callout kind="sentence"
The contract never sends assets to anyone on its own initiative; it records debts,
and each claimant withdraws, which turns one shared settlement into many independent
small transactions that cannot block each other.
:::

The alternative, pushing every payout automatically inside the callback, fails in
predictable ways. A single recipient who cannot receive tokens (a contract wallet
that rejects transfers, a blacklisted address) would make the entire settlement
revert, holding everyone else hostage. Pushing also maximizes reentrancy exposure,
where a malicious recipient's code runs in the middle of the sender's bookkeeping.
And it spends the oracle's limited callback gas on arbitrary third-party code. The
pull pattern, an application of the checks-effects-interactions principle, avoids
all three: the callback writes numbers and exits.

What pulling means in practice:

- Independence: your claim is a separate transaction. Anyone else's failure,
  malice, or absence cannot delay it.
- Retryability: a claim that fails (say, your chosen destination rejects the NFT)
  reverts atomically; the claim survives, and you retry with a better destination.
- Destination choice: claimQuote and claimPrize let the claimant direct assets to
  any safe address they control, which matters if their usual address is, for
  example, blacklisted by a token issuer. The one forbidden destination is the
  raffle itself.
- Help without power: the claim-for variants let anyone pay the gas to deliver a
  claim, but only to the recorded claimant, never to a destination of the helper's
  choosing.
- No deadlines: claims persist indefinitely. There is no sweep, no expiry, and no
  administrator who could confiscate an unclaimed balance.

:::callout kind="hood"
Every state-changing function is wrapped in a reentrancy guard, and every claim
clears the stored balance before touching the token, then verifies the raffle's
exact debit and the recipient's exact credit; a token that misdelivers reverts the
whole claim, restoring the debt. The prize claim sets its claimed flag before the
transfer for the same reason. These checks are what turn "a token behaved oddly"
into "the transaction reverted harmlessly" rather than "the books are wrong."
:::
