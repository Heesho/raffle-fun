[Model: implementation and factory construction]
No participant value is accepted. Deployment fixes the payment token, randomness provider, treasury, and one locked raffle template; the factory starts with zero raffles, while the template is deliberately marked initialized and terminal so it cannot become a live raffle.

[Defeat: constructor]
I tried (1) a payment-token or wrapper address with no code, (2) a payment token whose decimal query reverts or returns 5/7 instead of 6, and (3) a zero treasury or a treasury equal to the factory, payment token, wrapper, or newly created template. Construction rejects each case atomically. At the theoretical maximum raffle count, the checked increment in `createRaffle` reverts before any lasting registry or custody change.

[Model: clone initialization]
No participant value moves. The factory gives a fresh clone its sponsor, payout destinations, prize identity, raffle number, reserve, and sale end; initialization changes the clone from an unused record into a record waiting for exactly one prize.

[Defeat: initialize]
I tried (1) a non-factory caller on a fresh clone, (2) a second initialization, and (3) zero or known protocol-plumbing addresses for each configured party. The first two fail before configuration can change and the third rolls the whole initialization back. The factory supplies the separately checked nonzero reserve and valid end time, so the clone-only omission of those checks is not externally reachable during atomic creation.

[Model: raffle creation, escrow, and activation]
The sponsor gives one identified NFT and receives an autonomous active raffle plus the future right to the configured sponsor payout. The factory count rises by one, all three registry entries are written once, the clone records its configuration, and the clone changes from waiting for the prize to active only during the expected deposit.

[Defeat: createRaffle]
I tried (1) the first raffle with `endTime == block.timestamp`, `endTime == block.timestamp + 1`, exactly 30 days, and 30 days plus one second, (2) reserve zero, a prize with no code, a false/reverting ERC-721 interface response, and an already registered raffle as the prize, and (3) a prize that accepts the initial deposit but can later pause, freeze, seize, burn, or selectively reject transfers. The numeric and identity edges are handled and every failed creation unwinds the count, registry, clone, and NFT move. Move (3) passes creation and remains live at the winning terminal state; it is the finding below.

[Model: prize receipt]
The sponsor's identified NFT becomes the backing for the raffle, and the clone changes from waiting to active. No sale balance exists yet and no ticket exists.

[Why: Raffle.sol:428]
Why is one successful receipt treated as proof that the prize will remain deliverable at the end? The implicit belief is that present ownership implies future transferability, but a standards-reporting NFT with a pause or freeze control can make that belief false after escrow.

[Defeat: onERC721Received]
I tried (1) the right token with the wrong ID, (2) the right ID with the wrong prior owner or operator, and (3) a second callback after activation. All reject. A hostile configured token can originate the syntactically correct callback and satisfy the factory's immediate owner query, but those checks do not constrain its later paused/frozen state.

[LastOut: create -> escrow -> activate]
There is no distribution cohort yet. On success the only sponsor asset is held by the active clone; on any failure the entire creation transaction unwinds and the sponsor remains owner. The final sponsor is therefore short by zero at this stage, subject only to the later-transferability defect isolated below.

[Model: entry purchase]
The buyer gives 1,000,000 payment-token units for each entry purchased and the named recipient gets one transferable ticket covering exactly that many consecutive entries. Lifetime entries rise by the number purchased, lifetime tickets rise by one, the new range is recorded, and the unallocated sale pot rises by exactly the payment.

[Defeat: buyEntries]
I tried (1) zero entries and a zero recipient, (2) a purchase one second before sale end and exactly at sale end, and (3) a purchase that fills `totalEntries` exactly to `uint128.max` followed by one more entry. Zero and at/after-end purchases reject; the final representable entry is accepted and the next purchase rejects before `firstEntry`, `lastEntry`, ticket count, or the pot can overflow. The first ticket starts at entry 1, a sole ticket covers the entire sold range, and a recipient-hook failure unwinds both payment and all accounting.

[Model: ticket ownership update]
The current ticket holder either gives the whole bearer claim to another address or destroys it while collecting the associated terminal claim. Historical entry coverage and lifetime counts do not change; only current claim ownership changes, and a burn is coupled to redemption or refund by the calling path.

[Why: Raffle.sol:498]
Why are code-less destinations not checked against future factory membership? The guard assumes a destination that is not registered now cannot later become protocol plumbing. A future clone address can be predicted and preloaded, but doing so requires the current owner or its approved operator to strand that owner's own claim; runtime payment checks also reject it after registration, so no third-party loss was established.

[Defeat: _update]
I tried (1) minting or transferring to this raffle, the factory, the payment token, wrapper, prize token, template, or an already registered raffle, (2) transferring to a predicted not-yet-deployed clone and then deploying it, and (3) transferring the sole or winning ticket after sale end, resolution, or settlement. Move (1) rejects, move (2) can only strand a voluntarily directed bearer claim and was not elevated under the self-harm rule, and move (3) correctly makes the new current owner the claimant without changing the unique historical winning range. Burns to zero remain available only through the internal terminal paths.

[LastOut: buy -> hold/transfer ticket]
This acquisition phase has no payout by itself. After the final purchase, recorded ranges still partition `[1,totalEntries]`, and the unallocated pot equals every represented entry times the fixed price. Transfers change who will be last out, not how much is owed; shortage before a terminal transition is zero.

[Model: draw request]
After sales end, a caller gives native currency to buy one randomness request. The wrapper receives its actual price, the same caller receives every excess unit, the raffle changes from active to drawing, and the request time and identifier are recorded; the sale pot is untouched.

[Why: Raffle.sol:253]
Why is the full-width chain timestamp narrowed without proving it fits? The code assumes all request timestamps are at most `uint64.max`, even though a raffle ending at that maximum has a two-day request window that extends beyond it.

[Defeat: requestDraw]
I tried (1) zero sold entries, one sold entry, and the maximum sold-entry count, (2) the instant before sale end, exactly at sale end, one second before the request deadline, and exactly at the deadline, and (3) exact quoted value, an underpayment, an actual wrapper price above the supplied value, and an excess refund to a reverting caller. The ordinary boundaries and all failure rollbacks are sound. At `block.timestamp == uint64.max + 1`, however, an otherwise open request window can store zero and make the callback deadline immediately expired; this saturation-only condition is retained as a lead.

[Model: randomness resolution]
No user gives or receives value. One authenticated word selects exactly one sold entry, records the resolution time, and changes drawing into either NFT-won at or above the reserve or cash-won below it; the sale pot remains unallocated until settlement.

[Defeat: fulfillRandomWords]
I tried (1) a callback during request setup, a wrong identifier, and a duplicate after resolution, (2) zero words, two words, and one word equal to zero or `uint256.max`, and (3) one second before and exactly at the callback deadline. Invalid, duplicate, and exact-deadline callbacks are ignored without state drift; valid words always map into `[1,totalEntries]`. `totalEntries == reserveEntries` selects NFT-won, one below selects cash-won, and the largest representable entry count remains safe. The sibling `resolvedAt` narrowing at Raffle.sol:520 also wraps after `uint64.max`, though result selection still completes when a pre-maximum request has a post-maximum callback.

[LastOut: sale ends -> request -> callback]
The native payment is not shared: the wrapper gets exactly its actual price and the requester gets all excess in the same transaction, or the whole request reverts. Thus the final requester has no residual native claim and the sale pot remains fully backed; ordinary-boundary shortage is zero.

[Model: refund activation]
No new value arrives or leaves. On a permitted cancellation or timeout, the entire unallocated sale pot becomes the aggregate ticket-refund obligation, the old pot becomes zero, and the raffle becomes refunding.

[Defeat: enableRefunds]
I tried (1) an empty raffle where the sponsor calls before end and a stranger calls immediately before and exactly at end, (2) a sold active raffle immediately before and exactly at the request deadline, and (3) a drawing raffle immediately before and exactly at the callback deadline. The sponsor alone can cancel the empty raffle early; each public timeout opens exactly at its exclusive deadline; no resolved or already-refunding state can be overwritten. Zero liability on empty cancellation and full liability on sold cancellation are both preserved.

[Model: winning-ticket settlement]
No asset moves and the caller receives nothing. A caller identifies the unique historical ticket containing the selected entry; the unallocated sale pot becomes winner, sponsor, and treasury obligations, the pot becomes zero, and settlement is permanently marked complete.

[Why: Raffle.sol:543]
Why may the NFT-won branch make 100% of the payment pot releasable before the winner receives the NFT? It assumes escrow is equivalent to deliverability, leaving no dependency between the sponsor's consideration and successful terminal delivery.

[Defeat: settleWinningTicket]
I tried (1) ticket ID zero, an unminted ID, and each losing range, (2) the one valid range followed by a second settlement, and (3) a sole one-entry ticket at reserve 1, one entry below reserve, exactly at reserve, and total entries at `uint128.max`. Unique-range and one-shot guards are sound, and all allocations sum to the old pot. The clean arithmetic does not defeat a paused, frozen, seized, burned, or selectively reverting NFT because settlement never asks the prize whether it can be delivered.

[Model: winning-ticket redemption]
The current winning-ticket owner gives up the ticket and receives either the configured NFT or the full cash-winner obligation. The winning claim is marked consumed; for cash the winner balance becomes zero, and for NFT the prize is marked delivered. A failed delivery restores the ticket and every changed field in that transaction.

[Defeat: redeemWinningTicket]
I tried (1) a losing ticket before settlement and a different ticket after settlement, (2) an approved operator rather than the current owner and the new owner after a transfer, and (3) zero cash, a failing payment, and a paused/frozen NFT. Ownership, ticket matching, and cash rollback are sound. A direct redeem that encounters the paused NFT rolls its inline settlement back, but an attacker can then use the separate storage-only settlement and release the sponsor pot while the same redemption remains impossible.

[Model: ticket refunds]
The current owner gives up between one and 100 tickets and receives exactly the fixed price of every entry those tickets cover. Each ticket disappears, the aggregate refund obligation falls by the same amount paid, and lifetime ranges and counts remain historical.

[Defeat: refundTickets]
I tried (1) an empty list, one ticket, exactly 100 tickets, and 101 tickets, (2) duplicate, nonexistent, already burned, and foreign-owned IDs at the first and last array positions, and (3) the first refund, arbitrary ordering, a batch containing the sole ticket, and the final outstanding ticket. Bad batches revert all earlier loop effects. Valid distinct ranges cannot sum beyond `totalEntries`, subtraction is exact, and payment failure restores every burn and the obligation.

[Model: sponsor payment release]
The raffle gives the complete current sponsor obligation to the fixed sponsor recipient and reduces that obligation to zero. No other cohort balance changes.

[Defeat: releaseSponsorProceeds]
I tried (1) release before settlement or after an earlier release, (2) release first, between the other two cash claimants, and last, and (3) a recipient that cannot be paid or has become a registered raffle. Zero claims and unsafe destinations reject; a failed payment restores the obligation. In NFT-won, however, the nonzero sponsor obligation has no winner-delivery gate, which enables the finding below.

[Model: treasury payment release]
The raffle gives the complete current fee obligation to the fixed treasury and reduces that obligation to zero. No winner or sponsor obligation changes.

[Defeat: releaseProtocolFees]
I tried (1) release before settlement and repeated release, (2) release before and after the winner and sponsor, and (3) a failed payment. All ordinary paths are atomic and order-independent. Like the sponsor release, the NFT-won fee release is available before delivery, so the minimal terminal gate must cover both quote releases rather than only the sponsor's.

[Model: sponsor prize release]
In cash-won or refunding, the raffle gives the escrowed NFT to the fixed sponsor recipient and permanently consumes the prize-return claim. No payment-token obligation changes.

[Defeat: releaseSponsorPrize]
I tried (1) waiting, active, drawing, and NFT-won states, (2) the first and second call in cash-won/refunding, and (3) a paused token or a token that reports the wrong owner after transfer. Wrong-state and repeated calls reject, and failed delivery restores the claim flag. Here a permanently failed NFT return harms the sponsor-selected recipient rather than an entry claimant and cannot drain another cohort, so it is not a second instance of the finding.

[LastOut: NFT result -> settle -> redeem/release]
With a transferable prize, the winner gets the sole NFT and the sponsor and treasury can take the quote pot in either order; the quote shortage is zero. With the exact paused/frozen terminal state described below, the answer is no: the quote claimants can be paid to zero while the winning-ticket owner is still owed one configured NFT. The last winning claimant is short that entire prize, and there is no refund transition from NFT-won.

[LastOut: cash result -> settle -> redeem/release]
For gross `G`, the winner gets `floor(0.80G)`, the treasury gets `floor(0.05G)`, and the sponsor gets the exact remainder. Releasing them in the worst possible order leaves the last quote claimant fully paid and the intended token balance and obligations at zero. Because `G` is a multiple of 1,000,000 here, even the nominal percentage floors leave no fractional raw-unit dust; shortage is zero. The separate NFT return is owed only to the sponsor recipient.

[LastOut: request/callback timeout -> refunds]
Historical ranges are disjoint and partition all sold entries. Burning valid tickets in any mix of one-to-100-ticket batches removes each range value exactly once, so the final unburned ticket receives its full range value and both intended payment-token balance and `remainingRefundLiability` reach zero. Missing, duplicated, or foreign tickets revert the whole attempted batch; shortage is zero.

[LastOut: empty raffle cancellation]
There is no quote claimant and the refund obligation is zero. The sponsor recipient is the sole terminal prize claimant; a failed NFT delivery leaves the claim retryable rather than consumed. With a transferable prize the last and only claimant is paid in full, and the quote shortage is zero.

The remaining paused/frozen sweep found no protocol-level pause or mutable mid-flight configuration: raffle parameters, rates, destinations, provider, and timeouts never change. Payment-token release failures are atomic and independently retryable under the stated trusted-token assumption. The prize-delivery pattern was saturated across both NFT exit sites and every terminal state: only `NftWon` lets other cohorts withdraw sale proceeds while an untrusted prize remains undelivered; in `CashWon` and `Refunding`, failure to return the NFT leaves the sponsor's own claim outstanding while ticket/cash cohorts remain independently payable.

FINDING | contract: Raffle | function: settleWinningTicket | bug_class: prize-delivery-decoupling | group_key: Raffle | settleWinningTicket | prize-delivery-decoupling
root_cause: In the `NftWon` branch at Raffle.sol:543-555, `_settleWinningTicket` turns the entire sale pot into immediately releasable sponsor and treasury balances without delivering the prize or conditioning either release on `winnerRedeemed`; Raffle.sol:375-390 then exposes both balances independently even if the escrowed NFT has become paused or frozen.
internal_pre: A raffle has one sold entry, `reserveEntries == 1`, an authenticated callback resolved it to `NftWon`, and the winning ticket has not redeemed.
external_pre: The sponsor or a colluding prize-token administrator can pause, freeze, seize, burn, or selectively block transfer of the configured NFT after its successful escrow.
path:
  1. A sponsor creates a reserve-1 raffle with an ERC-721 whose transfer pause it controls; escrow succeeds while transfers are enabled.
  2. A buyer purchases the sole entry for 1,000,000 raw payment-token units and necessarily owns the winning ticket after resolution.
  3. Before redemption, the sponsor pauses NFT transfers. The buyer's `redeemWinningTicket` call reaches the prize transfer and reverts, restoring its inline settlement and burn.
  4. The sponsor calls the separate `settleWinningTicket`, which succeeds without touching the paused NFT and allocates 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`.
  5. `releaseSponsorProceeds` pays 950,000 units to the sponsor recipient (and the treasury balance can likewise be released), while every later winner redemption continues to revert as long as the token remains paused.
impact: The sole winning-ticket owner paid 1,000,000 units but can receive neither the advertised NFT nor a refund, while the malicious sponsor extracts 95% of that payment and the treasury can take the remaining 5%; the winner is left holding the entire undeliverable-prize loss.
mitigation: In `NftWon`, gate both sponsor and treasury quote releases on successful `winnerRedeemed`/prize ownership verification; if permanently failed prize delivery must be tolerated, transition the still-held sale pot to ticket refunds instead of ever releasing it.

LEAD | contract: Raffle | function: requestDraw | bug_class: timestamp-downcast-saturation | group_key: Raffle | requestDraw | timestamp-downcast-saturation
smell: Raffle.sol:253 narrows `block.timestamp` to `uint64` even though `drawRequestDeadline()` is full-width and can extend two days beyond a `uint64.max` end time; at timestamp `uint64.max + 1` the stored request time becomes zero, `callbackDeadline()` returns zero, every callback is late, and refunds can open immediately. Raffle.sol:520 similarly wraps `resolvedAt` for a callback just beyond the same boundary.
unverified: This requires the chain timestamp to reach the `uint64` horizon and a raffle created shortly before it; no practically reachable present-day loss or supported chain environment at that timestamp could be established.
description: Preserve the timestamp at full width or reject an out-of-range request/callback before narrowing so the final representable raffle cannot be prematurely cancelled by wraparound.
