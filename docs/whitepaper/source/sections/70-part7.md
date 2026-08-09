:::part id="part-vii" no="Part VII" title="Failed-Draw Refunds" compact="true"
The final reviewed implementation uses transferable bearer tickets that burn for
refunds. It does not snapshot owners or credit refunds in a separate batch.
- 35|Why Refund Redemption Is Bounded
- 36|Who Owns the Refund
- 37|Redeeming Refunds
- 38|Receiving the Refund
- 39|Ticket Transfers
- 40|Refund Conservation
- 41|Why Failure Charges No Fee
:::

# Part VII | Failed-Draw Refunds

## 35. Why Refund Redemption Is Bounded

A raffle may sell many tickets. Processing every ticket in one transaction would
create a loop whose gas cost grows with total sales. At some size, the transaction
could become too expensive or impossible to include.

The reviewed contract solves this by letting each actual owner submit 1 through
{{MAX_REFUND_BATCH}} ticket IDs per call. Each call performs bounded ownership checks,
burns, liability reduction, and one exact USDC transfer.

This is not permissionless refund crediting. An unrelated keeper cannot pre-credit a
refund to a frozen owner. The owner of every listed ticket must be the caller.

## 36. Who Owns the Refund?

The refund belongs to the current owner of an unburned refundable ticket. Ownership is
evaluated when `redeemRefundTickets` executes.

If Maya buys ticket 12, transfers it to Leo before `Refunding`, and Leo transfers it to
Noor after `Refunding`, Noor may burn it for 10.00 USDC. Maya and Leo have no stored
refund claim for that ticket. The bearer right moved with the unburned NFT.

This rule is simple but operationally important. Do not transfer a refundable ticket
unless you intend to transfer its unconsumed refund right.

## 37. Redeeming Refunds

:::figure src="diagrams/14-refund-redemption.svg" num="15" title="Refund redemption" caption="The actual owner supplies a bounded list, each ticket burns, the aggregate liability falls, and exact USDC moves to the chosen destination in one reverting transaction."
:::

The caller supplies a list of ticket IDs and a nonzero destination. The function
requires `Refunding`, a list length from 1 through {{MAX_REFUND_BATCH}}, and actual
caller ownership of every ID.

For each ticket, the raffle reads `ownerOf`, rejects a foreign owner, and burns the
token. It then calculates:

`refundAmount = ticketPrice x ticketIds.length`

The function subtracts that amount from `remainingRefundLiability` and performs one
exact outgoing USDC transfer.

Duplicate IDs, already burned IDs, nonexistent IDs, foreign tickets, a zero
destination, an oversized list, or an unsupported USDC transfer revert the complete
transaction. Earlier tentative burns and liability changes in that call are restored.

## 38. Receiving the Refund

The ticket owner may choose a different nonzero USDC destination. This is useful if
the ownership wallet is blacklisted, a contract wallet needs funds elsewhere, or an
operator separates signing and custody.

Choosing another destination does not let someone else redeem the ticket. The caller
must still be the actual owner. The outgoing token must debit the raffle and credit the
destination by exactly the expected amount.

No separate pull claim remains after a successful refund transaction. The ticket burn
and USDC transfer succeed together.

## 39. Ticket Transfers During Refunds

Tickets remain ordinary ERC-721 bearer tokens in `Refunding`. A transfer before burn
moves the refund right. A transfer and a competing refund transaction may race; the
first valid transaction included changes or consumes ownership, and the other must
re-evaluate or revert.

After redemption, the ticket is burned. It cannot transfer as a souvenir and its
metadata URI is no longer returned by `tokenURI` because the token no longer exists.

Known protocol destinations remain rejected. Arbitrary user-selected incapable
contracts remain a risk. If an unsafe transfer locks a refundable ticket in such a
contract, `remainingRefundLiability` may remain forever because there is no generic
administrator rescue.

## 40. Refund Conservation

Immediately after refund finalization:

`remainingRefundLiability = grossSales`

After any successful refund redemption:

`USDC already refunded + remainingRefundLiability = grossSales`

Equivalently, for `n` burned refund tickets:

`remainingRefundLiability = grossSales - (n x ticketPrice)`

The broader contract identity is:

`accountedQuoteBalance = unsettledPot + remainingRefundLiability + winnerCashLiability + totalClaimableQuote`

Only one branch should carry each unit. Direct USDC donations can make the contract's
actual balance greater than this accounting identity, but cannot change the identity
or create a claim.

## 41. Why Failed Draws Charge No Fee

The protocol fee is created only inside a valid Entropy callback that reaches
`NftWon` or `CashWon`. `enableRefunds` does not calculate or credit a fee.

The design treats missing request and missing callback as failure to complete the paid
random outcome. The gross ticket pot remains dedicated to exact ticket refunds. The
sponsor receives no quote proceeds and the treasury receives no fee, while the fixed
recovery recipient may recover the NFT.

:::callout kind="noguarantee" title="A liability is not a force field"
Exact accounting preserves what the contract owes. It cannot make a paused or
blacklisted USDC contract transfer, make a trapped bearer call redemption, or guarantee
Base inclusion.
:::
