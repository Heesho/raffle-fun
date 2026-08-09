:::part id="part-viii" no="Part VIII" title="Claims and Custody" compact="true"
Sponsor and treasury proceeds are pull claims. Winning and refund rights are bearer
redemptions. Prize recovery is a fixed-recipient claim.
- 42|Why Some Payments Are Pulled
- 43|Quote Claims
- 44|Claim-for Payments
- 45|Winning Prize Redemption
- 46|Sponsor-Side Prize Recovery
- 47|Native-Fee Overpayment
- 48|Donations and Surplus
- 49|Claims That Can Still Fail
:::

# Part VIII | Claims and Custody

## 42. Why Some Payments Are Pulled

Pushing every asset during the randomness callback would couple settlement to external
token contracts, prize receivers, sponsor wallets, and treasury wallets. One failure
could block the callback or consume unpredictable gas.

raffle.fun makes the callback storage-only. It records the selected ticket and quote
liabilities. Recipients act later and independently.

The exact model is mixed:

- sponsor and treasury proceeds are pull claims;
- NFT-winning and cash-winning rights are consumed by burning the selected ticket;
- refunds are consumed by burning bounded batches of tickets;
- sponsor-side prize recovery is initiated by the fixed recipient;
- native Entropy overpayment is returned immediately, not pulled later.

:::figure src="diagrams/15-pull-claim-architecture.svg" num="16" title="Claims and bearer redemptions" caption="Each asset path has a specific claimant and destination rule. A failed transfer reverts without consuming the right."
:::

## 43. Quote Claims

`claimQuote(to)` pays the caller's complete `claimableQuote[msg.sender]` balance to a
chosen nonzero destination. Only sponsor and treasury amounts are normally credited to
this mapping.

Before transfer, the contract clears the individual and aggregate liability. It then
requires exact raffle debit and exact recipient credit. A revert restores the cleared
claim because the whole transaction is atomic.

The function rejects payment to the raffle itself. It also rejects a zero destination
and an account with no claim.

## 44. Claim-for Quote Payments

`claimQuoteFor(account)` may be called by anyone, but it hard-codes the destination to
`account`. A keeper can help a sponsor or treasury submit a claim without gaining the
ability to redirect funds.

This helper is useful for ordinary externally owned accounts and callable contract
wallets. A malicious, blacklisted, paused, or self-referential destination may still
fail. Protocol creation checks and the selective protocol-owned recovery helper cover
known same-factory cases, not every arbitrary address.

## 45. Winning Prize Redemption

In `NftWon`, the current owner calls `redeemWinningTicket(to)`. The contract confirms
actual ownership, burns the ticket, marks the prize claimed, and safely transfers the
NFT to the chosen nonzero destination.

The caller may not be only an approved operator. It must equal `ownerOf`. A rejecting
destination reverts the entire operation and restores the ticket and prize claim.

In `CashWon`, the same function burns the selected ticket and exact-transfers
`winnerCashLiability` to the chosen destination. It does not transfer the NFT.

There is no general `claimPrizeFor` function. No third party can force a winning
bearer's prize to the bearer address. The bearer must initiate redemption or transfer
the ticket to a capable owner.

## 46. Sponsor-Side Prize Recovery

`claimSponsorPrize(to)` is available only to the immutable
`sponsorPrizeRecoveryRecipient` in `CashWon`, `Refunding`, or `Closed`. It marks
`prizeClaimed` and safely transfers the configured NFT to the chosen nonzero
destination.

The sponsor cannot call unless it is also the fixed recovery recipient. The factory
owner, treasury, frontend, and refund finalizer cannot call on the recipient's behalf.

A same-factory raffle that owns a prize right through a predicted future address has a
narrow permissionless recovery path. Any caller can invoke the holding raffle's
`recoverProtocolOwnedClaim`, but it can target only a registered raffle, select only
one of four fixed claim kinds, and route recovered assets only to the holder raffle's
immutable recovery recipient.

## 47. Native-Fee Overpayment

The draw requester pays Base-native currency to `requestDraw`. The raffle forwards
exactly Pyth's quoted fee and immediately returns excess native currency to the
requester.

There is no `claimNative`, native liability mapping, or later overpayment withdrawal.
If the requester rejects the immediate return, the whole request reverts.

Direct native transfers to the raffle revert. Native value can still be forced by EVM
mechanisms outside an ordinary call. Forced value is unaccounted surplus and creates
no claim.

## 48. Direct Donations and Surplus

Direct USDC donations and forced native value:

- do not increase tickets or gross sales;
- do not change the selected winner;
- do not change fee, sponsor, winner, or refund arithmetic;
- do not create a claim for the donor;
- appear as value above protocol accounting;
- cannot be swept by the factory owner.

The no-rescue choice reduces administrator seizure power but can leave surplus or
unrelated assets permanently inaccessible.

## 49. Claims That Can Still Fail

A valid onchain right can still be hard or impossible to realize:

- USDC may pause, blacklist, upgrade, or report dishonest balances;
- a prize contract may reject safe transfer, burn the token, reenter, or change code;
- a chosen contract destination may reject ERC-721 receipt;
- a bearer ticket may be unsafe-transferred to an incapable arbitrary contract;
- the claimant may lose keys or use a broken wallet;
- the Base sequencer or network may delay or censor transactions;
- gas costs may exceed a user's available native currency.

Atomic reverts preserve contract state when an external interaction fails. They do not
make the external dependency available.
