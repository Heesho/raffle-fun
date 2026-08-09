:::part id="part-iv" no="Part IV" title="Ticket Sales" compact="true"
Buyers pay the exact gross USDC price and receive sequential, transferable ERC-721
bearer tickets.
- 14|Sale Timeline
- 15|Buying Tickets
- 16|Threshold Behavior
- 17|Ownership and Transfers
- 18|Odds
:::

# Part IV | Ticket Sales

## 14. Sale Timeline

:::figure src="diagrams/05-sale-deadline-timeline.svg" num="5" title="Sale and deadline timeline" caption="The inclusive sale start and exclusive sale end are followed by a strict request window and an exact callback-timeout boundary."
:::

Purchases are allowed when all three conditions hold:

`status == Active`

`block.timestamp >= startTime`

`block.timestamp < endTime`

The exact start second is included. The exact end second is excluded. At `endTime`, a
sold raffle may accept a draw request and a zero-sales raffle may be closed by anyone.

Block timestamps and transaction ordering are supplied by the chain. A wallet sending
near a boundary cannot guarantee inclusion before the boundary. Users should avoid
last-second assumptions.

## 15. Buying Tickets

A buyer usually completes two USDC transactions. First, the buyer approves the raffle
to spend enough USDC. Second, the buyer calls `buyTickets(recipient, quantity)`.

The raffle requires:

- `Active` status and an open sale window;
- a nonzero recipient;
- a quantity from 1 through {{MAX_TICKETS_PER_PURCHASE}};
- safe multiplication of price by quantity;
- an exact USDC balance increase equal to the gross cost.

Only after exact payment does the raffle update `grossSales` and `unsettledPot`, assign
the next ticket range, and safely mint each ERC-721 to the recipient. A rejecting
contract recipient makes the complete purchase revert, including USDC payment and all
tentative ticket mints.

If Maya buys three tickets when 11 already exist, she receives IDs 12, 13, and 14.
The purchase event records the payer, recipient, quantity, first and last IDs, and
gross raw amount.

:::callout kind="holder" title="For ticket buyers"
Check the raffle address, chain, ticket price, quantity, recipient, USDC allowance,
and expected gross amount in the wallet. A successful approval does not itself buy a
ticket.
:::

## 16. Threshold Behavior

The threshold selects the economic branch only after a valid random callback:

| Sold tickets | 100-ticket threshold | Successful result |
| --: | --- | --- |
| 99 | below | `CashWon` |
| 100 | equal | `NftWon` |
| 101 | above | `NftWon` |

Equality counts as meeting the threshold because Solidity tests `totalTickets >=
minimumTickets`. Sales may continue above 100 until `endTime`.

The threshold does not change ticket price, odds, request timing, oracle source, fee
rate, or failure refunds. It only decides whether successful randomness gives the
winning bearer the NFT or cash.

## 17. Ticket Ownership and Transfers

:::figure src="diagrams/06-ticket-ownership.svg" num="6" title="Bearer ownership through time" caption="There is no transfer freeze or ownership snapshot. An unburned ticket carries its right to each current owner until redemption consumes it."
:::

Maya buys ticket 12 and transfers it to Leo during the sale. If ticket 12 is selected,
Leo may transfer it to Noor even after the callback. Noor then becomes the actual owner
who may burn it for the NFT or cash. If refunds are enabled instead, the current owner
may transfer ticket 12 before someone burns it for 10.00 USDC.

This is materially different from a snapshot design:

- draw request does not freeze transfers;
- refund finalization does not snapshot refund owners;
- no refund is pre-credited to a past owner;
- a transferred unburned ticket moves the unconsumed right;
- after burn, no souvenir ticket remains.

ERC-721 approval lets another account transfer a ticket, but the raffle redemption
functions require `msg.sender` to equal `ownerOf(ticketId)`. An approved operator cannot
directly redeem without first becoming the owner.

Safe and unsafe ERC-721 transfers both pass through raffle.fun's overridden
`transferFrom` logic for known protocol-destination checks. Safe transfer additionally
asks a contract recipient to confirm ERC-721 receipt. Unsafe transfer to an arbitrary
incapable contract can still lock the bearer right.

## 18. Odds

For one selected winning ticket, a holder's simple share of the ticket set is:

`tickets currently owned / total tickets sold`

If Maya owns 4 of 80 tickets, her current ownership share is 5%. That share changes
when more tickets sell or tickets transfer. The contract selects a ticket ID, not a
wallet. One wallet may own several IDs and one ID has one position in the mapping.

The formula describes ticket share, not a guarantee of winning. Pyth supplies a
256-bit value that is reduced with modulo. For most ticket counts, the 256-bit domain
is not divisible exactly by `totalTickets`, creating negligible but nonzero modulo
bias. The paper therefore does not claim perfect mathematical uniformity.

Cash fallback does not give every ticket a partial payout. It still selects one ticket.
Only its current owner may burn for the winner cash amount.
