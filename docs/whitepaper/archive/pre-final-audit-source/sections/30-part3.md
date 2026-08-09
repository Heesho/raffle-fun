:::part id="part-iii" no="Part III" title="How a Raffle Works"
The full mechanics, from the creation transaction to the moment the winner is fixed.
- 10|Creating a Raffle
- 11|Buying Tickets
- 12|The Raffle Timeline
- 13|The Minimum-Ticket Threshold
- 14|Requesting the Draw
- 15|How Randomness Works
- 16|Freezing the Winner
:::

# Chapter 10 | Creating a Raffle

:::callout kind="sentence"
One transaction creates the raffle contract, fixes every rule forever, and locks the
prize inside it; if any part fails, nothing happens at all.
:::

Ava wants to raffle Sunset Study #7. She first approves the raffle.fun factory to
move that one NFT (a standard ERC-721 permission). Then she calls the factory's
createRaffle function with her chosen parameters. Everything in the following table
is fixed permanently the moment the transaction succeeds.

| Input | Meaning | Rules the factory enforces |
| --- | --- | --- |
| Prize contract and token ID | which exact NFT is at stake | must be a deployed contract that affirmatively reports ERC-721 support |
| Payment token | the one currency of this raffle | must be on the factory's admitted list at creation time |
| Recovery address | where the prize returns in every non-winner ending | zero means "use the sponsor"; fixed forever |
| Ticket price | gross price per ticket, in raw token units | must be nonzero; what you advertise is what buyers pay |
| Minimum tickets | the threshold that picks the payout branch | must be nonzero; not a sales cap |
| Start time | when sales open (inclusive) | now, or up to 7 days in the future; zero means "now" |
| End time | when sales stop (exclusive) | after start; the sale window may be at most 30 days |
| Metadata URI | a link describing the raffle, shown on every ticket | at most 2,048 bytes |

Ava picks: 10 USDC per ticket, minimum 100 tickets, a 14-day sale starting now, and
her own vault wallet as the recovery address.

## What the one transaction does

The factory checks every input, deploys a fresh raffle contract at a predictable
address, initializes it with the full configuration, registers it so applications
can recognize official raffles, emits a creation event that indexers use, transfers
the prize from Ava into the new contract, and finally verifies with the NFT contract
itself that the raffle now owns the prize. Atomicity is the point: there is no state
in which a raffle exists without its prize, or a prize left a wallet without its
raffle. If Ava forgot the NFT approval, or the collection misbehaves, the entire
transaction reverts.

:::callout kind="hood"
The new raffle is an EIP-1167 minimal proxy (a "clone"): a tiny contract that
delegates all logic to one shared, locked implementation while keeping its own
isolated storage. Its address is computed with CREATE2 from the chain ID, the
raffle's sequence number, the sponsor, the payment token, and the exact prize, so
integrators can predict it before creation. The clone accepts initialization only
from a factory whose recorded implementation matches the one baked into the clone's
own bytecode, which blocks look-alike factories. Ticket collections are named
"Raffle Fun Ticket #N" with symbol "RFT-N".
:::

# Chapter 11 | Buying Tickets

:::callout kind="sentence"
Buying is a two-step ritual, approve then buy, and the contract checks the exact
payment, the exact window, and the exact quantity before minting numbered tickets.
:::

Because ERC-20 tokens require a spending permission, Ben first approves the raffle
to take 50 USDC, then calls buyTickets asking for 5 tickets for himself. Wallets
that support transaction batching can present both steps as one confirmation; the
raffle.fun web app uses that when available and falls back to two steps when not.
That app behavior is convenience, not protocol: any wallet that can call the
contract can buy tickets.

The contract enforces, in order: the raffle is Active with the prize in escrow; the
time is within the sale window (start inclusive, end exclusive); the recipient is a
real address; the quantity is between 1 and 100; and the total price, ticket price
times quantity, does not overflow. It then pulls the payment and verifies its own
balance grew by exactly that amount, which is what rejects fee-skimming or otherwise
dishonest tokens. Only then does it mint the tickets: a contiguous block of new
numbers to the recipient Ben named, which can be himself or anyone else. One event
records buyer, recipient, quantity, ticket range, and amount paid.

If anything fails, everything fails: a reverted purchase leaves no half-minted
tickets and takes no money. There is no per-person limit beyond the 100-per-
transaction bound; a determined buyer can send multiple transactions, and each added
ticket dilutes everyone's odds visibly, including theirs.

:::callout kind="example"
Maya buys 10 tickets for 100 USDC and directs 2 of them in a second purchase to her
friend Leo's wallet. The pot now holds Ben's 50, Maya's 100, and Leo's tickets cost
Maya 20. Nothing about a later purchase changes what an earlier buyer paid, but
every purchase changes the live odds, which the contract exposes for anyone to read.
:::

# Chapter 12 | The Raffle Timeline

Every raffle lives on a single, fixed timeline. Two figures carry this chapter: the
clock view and the state-machine view of the same journey.

:::figure src="diagrams/timeline.svg" num="5" title="The raffle clock" caption="The phases of a raffle in time order, with every boundary the contract compares against. Solid vertical rules are exact timestamps; the dashed drops beneath show the two deadline-triggered refund exits. The sale window boundaries are chosen by the sponsor within fixed caps; the 3-day and 2-day windows after it are protocol constants."
:::

The boundary semantics are exact and worth stating once, precisely. Buying requires
start <= now < end: a purchase in the very second the sale ends already fails.
Closing actions (the draw request, and the no-sales close) require now >= end: they
work in that same second. The draw request additionally requires now < end + 3 days.
The two failure exits open at their deadlines inclusively: missing-request
finalization at end + 3 days, callback-timeout finalization 2 days after the request
was accepted.

:::figure src="diagrams/lifecycle.svg" num="6" title="The complete state machine" caption="Every state a raffle can occupy and every transition between them, with the exact caller and condition on each arrow. Red arrows are the deadline-driven failure paths anyone can trigger. Dots mark terminal states: once reached, only claims remain, and nothing can ever change the outcome."
:::

A raffle is created in AwaitingPrize and becomes Active in the same transaction once
the prize is verified. From Active it can move four ways: to Cancelled (sponsor
cancels while zero tickets are sold), to Resolved via the no-sales close (anyone,
after the end, zero tickets), to DrawRequested (anyone requests the draw in its
window), or to Refunding (the request window expires unused). From DrawRequested it
moves to Resolved when the matching random result arrives, or to Refunding if the
result stays missing for 2 days. No transition ever runs backward.

# Chapter 13 | The Minimum-Ticket Threshold

:::callout kind="sentence"
The minimum is a promise about outcomes, not a cap on sales: it decides which payout
branch runs, while sales continue to the fixed closing time regardless.
:::

Think of the minimum as the sponsor saying: "this prize is worth giving away only if
at least this much interest shows up." Ava set 100 tickets at 10 USDC, an implied
1,000 USDC of gross interest. The threshold is evaluated exactly once, inside the
draw's callback, by one comparison: tickets sold >= minimum.

| Scenario at the draw | Comparison | Branch |
| --- | --- | --- |
| 99 tickets sold | 99 >= 100 is false | cash fallback: winner gets 76 percent of the pot, prize returns |
| 100 tickets sold | 100 >= 100 is true | NFT awarded: equality counts as met |
| 101 tickets sold | 101 >= 100 is true | NFT awarded; sales had continued normally |

Sales do not stop at 100. If the raffle is popular, tickets keep selling until the
closing time; 120 tickets mean a 1,200 USDC pot. Each ticket past the minimum grows
the pot and dilutes everyone's individual odds, visibly, in real time. There is also
no upper limit on what a sponsor may set as a minimum. An unrealistically high
minimum cannot break accounting; it simply makes the cash-fallback branch the likely
outcome, which buyers can see before buying.

:::callout kind="holder"
Before buying, look at two numbers together: tickets sold so far versus the minimum
(how likely is the NFT branch?) and tickets sold overall (what are my odds?). The
official app shows both, plus the flip point where the outcome would switch.
:::

# Chapter 14 | Requesting the Draw

:::callout kind="sentence"
After the sale closes, anyone, not just the sponsor, can pay a small fee in ETH to
request the raffle's one and only random draw within a 3-day window.
:::

Randomness is not free: Pyth Entropy charges a fee, denominated in the network's
native currency (ETH), to fund the callback transaction it will send later.
The raffle exposes the current fee, read live from Entropy for the raffle's
configured callback gas allowance. Whoever calls requestDraw attaches at least that
fee; the contract forwards the exact fee to Entropy and credits any overpayment to
the caller as a withdrawable balance, so overpaying by a safety margin is harmless.

Making the request permissionless removes a hostage scenario: no single party, not
the sponsor and not the operator of any website, is the mandatory trigger. Any
ticket holder who wants the draw to happen can make it happen for the cost of the
fee. The request must satisfy: raffle Active, sale ended, at least one ticket sold,
and now within 3 days after the end. The first success is also the last: the state
advances before the external call, so a second request has nothing to act on. If the
request transaction reverts (say, the fee reading failed), nothing changed and
anyone can simply try again within the window.

:::callout kind="hood"
requestDraw stores the exact timestamp (starting the 2-day callback clock), sets an
in-flight guard, and only then calls Entropy's requestV2 with the configured gas
limit. The returned sequence number, the unique ID of this randomness request, is
stored; the guard closes. A hostile "callback" delivered synchronously during the
request, before the sequence is stored, is ignored by the guard. The DrawRequested
event carries the sequence, requester, fee paid, refundable excess, request time,
and the callback deadline, so indexers can display the full schedule.
:::

:::callout kind="noguarantee"
The protocol cannot force anyone to request the draw. If 3 days pass with no
successful request, an unlikely event for any raffle with interested participants,
since any of them can do it, the raffle becomes finalizable into full refunds, as
Chapter 21 describes.
:::

# Chapter 15 | How Randomness Works

:::callout kind="sentence"
The raffle asks an independent service, Pyth Entropy, for one random number through
an authenticated channel, and turns it into a winning ticket with one formula anyone
can recheck.
:::

Why not just use something already onchain, like a block's timestamp? Because
everything onchain is either predictable or influenceable by the parties who order
transactions, and an administrator picking a number is exactly the discretion this
protocol exists to remove. An **oracle** is a service that brings information from
outside the chain onto it; **Pyth Entropy** is an oracle specialized in randomness.
It works on a commit-reveal principle: parties commit to hidden values in advance
and the revealed combination is unpredictable to each of them alone.

:::figure src="diagrams/randomness-sequence.svg" num="7" title="The draw, transaction by transaction" caption="Two separate transactions: the request anyone sends, and the callback only the Entropy contract can deliver. Between them lies an offchain wait. The contract's checks on the callback are shown in the green box; everything it does is a storage write, never an asset transfer."
:::

## From random number to winning ticket

The callback delivers one 256-bit random number. The winning ticket is:

```text
winningTicketId = (randomNumber mod totalTickets) + 1
```

The modulo operation maps the huge random number onto the range 1 through
totalTickets, inclusive on both ends. A raffle with one ticket always selects ticket
1; the final ticket is exactly as likely as any other. The contract then reads that
ticket's current owner and records them as the winner, permanently.

:::callout kind="hood"
Strictly speaking, reducing a 256-bit number modulo N is perfectly uniform only when
N divides 2 to the 256th power. Otherwise some residues occur once more than others
across the full input space, giving a relative bias of at most N divided by 2 to the
256th. For any realistic ticket count (even billions), that bias is far below one in
10 to the 50th, which is many orders of magnitude smaller than, say, the probability
of guessing a private key. The whitepaper therefore says "equal odds" without
qualification in the main text, and notes the exact caveat here.
:::

## Authentication and replay

The callback path is locked down three ways: the caller must be the configured
Entropy contract (enforced by Pyth's consumer wrapper), the raffle must be in
DrawRequested, and the delivered sequence number must equal the stored one. Anything
else, a duplicate delivery, a wrong sequence, a delivery after the raffle already
settled, is ignored with a logged event and zero state change. One result is
accepted, ever. If delivery is delayed, Pyth's own tooling can replay the same
sequence; a replay delivers the same stored request and therefore the same result.
What the raffle does about prolonged silence is Chapter 21's subject: after 2 days,
the refund path opens.

:::callout kind="noguarantee"
This design makes the draw verifiable and non-repeatable, but its unpredictability
rests on Pyth's cryptographic and operational assumptions holding. The protocol
chose a specialist randomness service over homemade alternatives precisely because
those assumptions are explicit, documented, and independently scrutinized. They are
still assumptions, and Chapter 31 places them on the trust map.
:::

# Chapter 16 | Freezing the Winner

:::callout kind="sentence"
Ticket ownership matters up to one precise instant per path: the draw callback for
winnings, and refund crediting for refunds; transfers are frozen in the run-up to
each so the snapshot cannot be gamed.
:::

:::figure src="diagrams/ticket-snapshot.svg" num="8" title="Ticket transfers and the winner snapshot" caption="The three transfer regimes of a normal raffle: free movement while Active, a freeze from the successful draw request until resolution, and souvenir transfers afterward. The example beneath follows one ticket through a sale, the freeze, and both possible endings."
:::

The rules, stated once, exactly:

- While the raffle is Active, tickets transfer freely. Selling a ticket transfers
  the chance it represents: if it later wins, the new holder is the winner.
- The successful draw request freezes all owner-to-owner transfers. Nobody can trade
  while the random result is in flight, so nobody can buy a win after the fact or
  dump a losing ticket in the window between request and result.
- The callback snapshots the winning ticket's owner into permanent storage. From
  then on, transfers reopen and tickets are souvenirs; moving one moves no claim.
- On the failure path, entering Refunding freezes each ticket until its refund is
  credited to its current holder. The credited holder is thereby exactly the person
  who bore the loss of the failed raffle. After crediting, that ticket too becomes a
  freely transferable souvenir.

:::callout kind="example"
Maya transfers ticket 7 to Leo two days before the sale ends: allowed, and if ticket
7 wins, Leo wins. During the draw freeze Leo tries to sell it: the transaction
reverts with a transfers-frozen error. The draw picks ticket 87 (Noor's), so after
resolution Leo's ticket 7 is a keepsake he can move anywhere. In the alternate
failure timeline, ticket 7 stays locked until the refund batch credits Leo his 10
USDC, and only then can the ticket move.
:::
