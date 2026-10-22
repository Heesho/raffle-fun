# Lens 3 — Temporal Cohorts & Distribution Fairness

## Money-map-first model

The changing-holder claims are the range tickets. Each ticket represents a fixed, non-overlapping set of paid entries, and the entire refund or winner entitlement follows the ticket. The sale pot has only three possible destinations: full ticket refunds; an 80% cash-winner / 15% sponsor / 5% treasury split; or a 95% sponsor / 5% treasury split paired with delivery of the escrowed NFT. There is no cumulative reward index, time-weighted balance, or pro-rata pool share. The temporal questions are therefore (a) whether a late entry can take an earlier cohort's economic entitlement, (b) whether a transfer duplicates or destroys a ticket entitlement, and (c) whether one independently released terminal claim can leave the last claimant without the different asset they are owed.

[Model: RaffleFactory.createRaffle] The sponsor gives one identified NFT and receives an active raffle whose fixed recipient may later collect sponsor proceeds or the returned NFT. The factory's raffle count rises by one, both registry directions are filled, and the NFT moves into the new raffle; failure anywhere cancels the whole creation.

[Model: Raffle.initialize] A fresh raffle receives its sponsor, payout recipient, treasury, prize, reserve, and closing time. Nobody gives or receives value yet; the lifecycle moves from unused to waiting for the named prize.

[Model: Raffle.onERC721Received] The sponsor's exact NFT enters from the factory and the raffle opens for purchases. The only changed tracked fact is the lifecycle becoming active.

[Model: Raffle.buyEntries] The payer gives exactly one USDC per entry and the chosen recipient receives one transferable ticket covering a new contiguous entry range. Sold entries and ticket count rise, and the same USDC amount is added to the unallocated sale pot.

[Model: Raffle._update] No money moves. The entire bearer claim represented by one ticket moves from its old owner to its new owner, while its paid entry range and every global total remain unchanged.

[Model: Raffle.requestDraw] The caller gives native currency only to buy one randomness request and receives every unused unit back immediately. The sale pot is untouched; the lifecycle becomes drawing and the request identity and time are recorded.

[Model: Raffle.fulfillRandomWords] Nobody gives or receives value. One paid entry is selected, the resolution time is recorded, and the result becomes either NFT-won or cash-won according to the final sold-entry total.

[Model: Raffle.enableRefunds] No asset leaves yet. The whole unallocated sale pot is relabelled as the amount owed to unrefunded tickets, the old pot becomes zero, and the lifecycle becomes refunding.

[Model: Raffle._settleWinningTicket] A caller supplies the one ticket whose paid range contains the selected entry and receives nothing for doing so. The unallocated pot becomes fixed winner, sponsor, and treasury obligations; settlement and the winning ticket identity become final.

[Model: Raffle.redeemWinningTicket] The current winning-ticket owner gives up and destroys that ticket and receives either the escrowed NFT or the complete cash-winner amount. The cash obligation becomes zero in the cash branch; winner-consumed and, for an NFT result, prize-consumed facts become final only if delivery succeeds.

[Model: Raffle.refundTickets] The current owner gives up one to one hundred tickets and receives exactly one USDC per represented entry. The refund obligation falls by the same amount; any failed payment restores every burned ticket and the old obligation.

[Model: Raffle.releaseSponsorProceeds] Any caller can trigger payment, but only the fixed sponsor recipient receives the complete sponsor amount. That obligation becomes zero.

[Model: Raffle.releaseProtocolFees] Any caller can trigger payment, but only the fixed treasury receives the complete fee amount. That obligation becomes zero.

[Model: Raffle.releaseSponsorPrize] In a cash or refund result, any caller can return the escrowed NFT to the fixed sponsor recipient. The prize becomes consumed only if delivery and the ownership check both succeed.

[Why: Raffle.sol:230] Why are the sold-entry and ticket totals advanced before the new recipient is contacted? Because the recipient is adversarial and must observe a fully backed, uniquely ranged claim; the implicit belief is that cancellation of the contact also cancels the preceding payment and accounting, which transaction rollback satisfies.

[Why: Raffle.sol:509] Why is ticket ownership deliberately not fixed when randomness resolves? Because the protocol defines the ticket as a transferable bearer claim through redemption; correctness therefore depends on every terminal payment consulting the current owner exactly once, rather than preserving the owner at draw time.

[Why: Raffle.sol:540] Why can anybody allocate the winning liabilities without reading the ticket owner? Because allocation changes only the labels on an already held pot, while the ticket itself continues to carry the right to the terminal asset.

[Why: Raffle.sol:550] Why does the sponsor receive the arithmetic remainder rather than an independently rounded 15%? Because this makes winner plus sponsor plus treasury equal the old pot for every raw unit and prevents the last quote claimant from inheriting rounding debt.

[Why: Raffle.sol:326] Why is the owner checked only after settlement has possibly occurred? Because permissionless allocation must not freeze a bearer claim, but delivery must follow the owner at the instant the ticket is destroyed.

[Why: Raffle.sol:593] Why is the factory's raffle registry consulted only when the destination already has code? The implicit belief is that a code-less destination cannot become protocol plumbing after receiving a claim; a predicted future clone address defeats that belief, although the reviewed paths did not produce a non-self-harm victim from the bypass.

## Guard-defeat passes

[Defeat: buyEntries] (1) Bob buys one entry at `endTime - 1` and is included, while the same purchase at `endTime` is rejected; there is no overlapping sale/draw timestamp. (2) Bob pays for Alice and Alice receives the entire new ticket; no old Alice entitlement or checkpoint is overwritten because every purchase has a new ticket. (3) A recipient moves the just-created ticket during its receipt callback; the range and pot were already complete, and the one claim simply follows the new owner.

[Defeat: requestDraw/enableRefunds] (1) At `drawRequestDeadline - 1`, a request can begin and refunds cannot. (2) At the exact request deadline, the request is rejected and refunds can begin. (3) At the exact callback deadline, the callback is ignored and refunds can begin. No boundary permits both terminal states.

[Defeat: fulfillRandomWords] (1) The wrapper calls with the wrong request number. (2) It calls with zero or two words. (3) It calls at the exact deadline. Each case leaves the raffle unresolved and preserves the later refund path; no late cohort can replace an already accepted winner.

[Defeat: _settleWinningTicket] (1) Bob supplies never-minted ticket zero, whose empty range cannot contain a positive winning entry. (2) Bob supplies a real losing ticket and fails the range proof. (3) Alice transfers the actual winner after somebody settles it; settlement remains unique, and the recorded ticket ID still identifies the same range while the whole bearer claim moves to its new owner.

[Defeat: refundTickets] (1) Alice repeats one ticket ID in a batch; the second ownership lookup fails and the entire batch returns to its starting state. (2) Alice includes Bob's ticket; the entire batch fails. (3) Bob refunds first and Alice refunds last; each ticket debits only its own fixed range value, so ordering cannot make Alice absorb Bob's payment.

[Defeat: redeemWinningTicket] (1) An approved operator but not the owner calls and cannot take the winner asset. (2) The owner calls twice; the first call destroys the ticket and marks the winner consumed. (3) The owner transfers after settlement but before redemption; the new owner alone can destroy the same recorded ticket and receives the one terminal asset. There is no snapshot that pays both holders.

[Defeat: releaseSponsorProceeds] (1) In a cash result, the sponsor takes its amount before the winner; the separately reserved winner amount remains fully backed. (2) In a refund result there is no sponsor quote amount, so this path cannot consume ticket backing. (3) In an NFT result, a malicious or pausable prize accepts escrow but refuses the eventual outbound transfer; the sponsor amount can nevertheless leave first. This third move breaks cross-asset finality and is the finding below.

[Defeat: _isProtocolDestination] (1) Sending a ticket to the current raffle, factory, implementation, token plumbing, or an already registered raffle is rejected. (2) Sending to an ordinary contract that can manage the ticket is allowed. (3) Sending to the predicted address of the next clone before it exists is allowed, and later deployment can strand the claim there. The payer or current owner must voluntarily direct its own bearer claim to that address (or already grant an operator the power to take it), so no unwilling victim was established and this self-harm-only route is not reported.

## Required two-user timelines

### Cash-winner distribution

- `t0`: Alice buys 2 entries for 2 USDC. The pot is 2 USDC.
- `t1`: Bob buys 3 entries for 3 USDC. The pot is 5 USDC and the final holder set has five equally priced entries.
- `t2`: The reserve is missed and the raffle allocates 4 USDC to the winning ticket, 0.75 USDC to the sponsor, and 0.25 USDC to the treasury. If Alice's range wins, Alice receives 4 and Bob 0; if Bob's range wins, Bob receives 4 and Alice 0. Alice's expected receipt is `2/5 * 4 = 1.6` USDC, exactly the same 80% of her payment she would have received when she was the only cohort. Bob's expected receipt is `3/5 * 4 = 2.4` USDC, exactly 80% of his own payment. Bob receives no positive expected share of the `t0→t1` pot.

[LastOut: CashWon quote claims] With gross sales of 5 USDC, pay the 0.75 sponsor amount first, then the 0.25 fee, and the 4-USDC winner last: the last claimant is paid in full and the quote balance and all three obligations reach zero. Reversing all three payments has the same result.

### NFT-winner distribution with an honest deliverable prize

- `t0`: Alice buys 2 entries for 2 USDC.
- `t1`: Bob buys 3 entries for 3 USDC.
- `t2`: The reserve is met. The sponsor receives 4.75 USDC, the treasury receives 0.25 USDC, and exactly one NFT follows the selected range: Alice has a 2/5 chance and Bob a 3/5 chance. This is a winner-takes-all sale, not distribution of value accrued to earlier holders. Bob's later entries dilute Alice's NFT probability, but they do so while the advertised sale remains open and by adding the same-price entries the outcome is defined to count; Alice had no fixed pre-close probability snapshot.

[LastOut: NftWon with deliverable prize] In either order, the sponsor and treasury exhaust exactly 5 USDC and the winning owner receives the sole NFT. The last quote claimant is paid in full and the last asset claimant receives the prize.

### Full-refund distribution

- `t0`: Alice buys 2 entries for 2 USDC.
- `t1`: Bob buys 3 entries for 3 USDC.
- `t2`: The draw path expires and 5 USDC becomes refund backing. Bob burns his ticket first and receives 3; Alice burns hers last and receives 2. Reversing the order gives Alice 2 and Bob 3. Neither user's receipt depends on when the other joined or exited.

[LastOut: Refunding] In the worst order, every ticket except Alice's is refunded first. The remaining obligation equals Alice's represented entry count times one USDC, Alice receives that complete amount, and both the obligation and intended quote balance reach zero. Duplicate, foreign, and already burned tickets cannot debit it twice.

### Transfer between resolution and redemption

- `t0`: Alice owns a two-entry ticket and Bob owns a three-entry ticket.
- `t1`: Randomness selects an entry in Alice's range; no owner snapshot or payment occurs.
- `t2`: Alice transfers the winning ticket to Bob for whatever consideration they choose. Alice ends with no protocol claim; Bob owns the whole winning ticket and receives the single 4-USDC cash amount or the single NFT when he destroys it. The transfer moves past and future entitlement together and cannot create a second claim.

### Fixed recipients and native request value

- Sponsor proceeds and protocol fees do not use a changing holder set: Alice triggering a release at `t0`, Bob triggering it at `t1`, or either triggering it at `t2` always pays only the same fixed recipient and never rewards the caller.
- A draw requester who sends the request price plus 0.2 native units receives exactly 0.2 back in the same transaction. A later requester never shares that refund, and failed return cancels the request rather than charging a different cohort.

## Broken last-user-out ordering and saturation

[LastOut: NftWon with adversarial prize] `t0`: Mallory sponsors a prize that accepts escrow and reports the raffle as owner. `t1`: Alice buys 100 entries for 100 USDC and is the only possible winner. `t2`: the reserve is met, Alice's ticket is selected, and settlement creates 95 USDC of sponsor proceeds plus 5 USDC of fees. Mallory and the treasury withdraw those amounts first. `t3`: Alice calls redemption last; the prize blocks transfer from the raffle, so her transaction reverts. The raffle is now short Alice's reachable claim by exactly one NFT, offers her zero USDC fallback, and holds zero sale USDC after the two earlier releases.

The pattern was saturated across every sibling exit and result branch:

- `releaseSponsorProceeds` and `releaseProtocolFees` both lack a condition tying an NFT-result payment to successful winner delivery. They are the two instances of the same root cause.
- A failed NFT redemption restores the ticket, `winnerRedeemed`, and `prizeClaimed` within that transaction, but cannot restore sponsor or treasury payments completed in earlier transactions.
- Direct redemption before either quote release is safe when the prize transfers, and it reverts cleanly when the prize does not; the exploit needs the independent quote releases to run first.
- The cash-result sibling does not have this deficit: the cash winner amount remains a separate obligation in the contract when sponsor and treasury withdraw.
- The refund sibling does not have this deficit: the full ticket obligation remains separate from returning the NFT to the sponsor.
- Returning the prize to the sponsor is unavailable in the NFT-result branch, so Alice cannot recover a refund and Mallory cannot use that function as the primary extraction path. The exploitable value exits through the two quote-release functions.
- Repeat redemption, repeat prize return, duplicate refunds, losing-ticket settlement, and post-redemption transfer are all consumed by a zeroed obligation, a one-way flag, or destruction of the ticket; no separate double-claim instance was found.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-proceeds-release
root_cause: `releaseSponsorProceeds` at Raffle.sol:375-381 and its sibling `releaseProtocolFees` at Raffle.sol:385-391 release all sale USDC in an NFT result without requiring `winnerRedeemed`, so the sponsor can be paid before the untrusted prize has successfully left escrow.
internal_pre: The raffle resolved `NftWon`, the winning ticket was settled, and neither the winning ticket nor prize has been redeemed.
external_pre: The sponsor-selected ERC-721 accepts the initial escrow and ownership verification but can later revert, pause, blacklist the raffle, or otherwise refuse the outbound winner transfer.
path:
  1. At t0 Mallory creates a raffle with `reserveEntries = 1`, names a sponsor recipient she controls, and supplies a prize contract that accepts escrow but whose outbound transfers she can block.
  2. At t1 Alice buys 100 entries for 100,000,000 raw USDC units; she owns the only ticket and is therefore the eventual winner.
  3. At t2 the draw resolves `NftWon`; Mallory (or any caller) settles Alice's ticket, allocating 95,000,000 units to Mallory's recipient and 5,000,000 units to the treasury.
  4. Mallory calls `releaseSponsorProceeds` and receives 95,000,000 units; the fee release can remove the remaining 5,000,000 units as well.
  5. At t3 Alice calls `redeemWinningTicket`; the prize rejects `transferFrom`, so Alice's redemption state rolls back, while the already completed quote payments remain final.
impact: Alice, the current winning-ticket owner, paid 100 USDC but can receive neither the promised NFT nor any refund; Mallory keeps 95 USDC despite withholding the prize, and after the fee release the raffle has no sale USDC left to make Alice whole.
mitigation: In both sponsor and protocol quote-release paths, reject release while `status == NftWon && !winnerRedeemed`; keep the sale pot unavailable to those recipients until successful prize delivery (and, if undeliverable prizes are to remain supported, add a bounded transition that converts the retained pot to ticket refunds).

## Economic temporal lead

- `t0`: Alice buys the only 1-USDC entry in a raffle whose reserve is two entries. If the sale closed in this state, Alice would be the sole cash winner and receive 0.8 USDC.
- `t1`: Immediately before the exclusive sale end, Mallory, who is also the sponsor and sponsor recipient, buys one entry for herself. The final count now meets the reserve.
- `t2`: The result becomes NFT-won. Mallory receives 1.9 of the 2 USDC gross, so her late entry has a net cash cost of negative 0.9 USDC, and she also has a 1/2 chance to win back her own NFT. Alice's cash fallback disappears and becomes a 1/2 chance at the NFT.

[Defeat: reserve outcome selection] (1) An unrelated Bob performs the same last-second purchase and pays the full economic cost; this is ordinary open-sale dilution. (2) Mallory performs it and recycles 95% of the combined pot, making the timing option uniquely cheap for the sponsor. (3) Mallory uses a fresh address, so excluding the recorded sponsor address alone does not remove the behavior. The source explicitly defines the threshold from all sold entries, so protocol intent and a sybil-resistant remedy cannot be established from scope.

LEAD | contract: Raffle | function: buyEntries | bug_class: sponsor-last-minute-reserve-manipulation | group_key: Raffle | buyEntries | sponsor-last-minute-reserve-manipulation
smell: A sponsor can wait for genuine demand, buy the final entries just before closing, flip the outcome from the 80% cash fallback to the NFT branch, and recycle 95% of the combined pot through its sponsor recipient while also holding the new winning chances.
unverified: The scoped specification defines the reserve using all entries and does not state that sponsor-funded entries must be excluded; on-chain identity is sybilable, so it is unclear whether this is an intended seller option or a prohibited cohort manipulation and no minimal sybil-resistant fix was established.
description: The concrete one-entry Alice / one-entry Mallory timeline removes Alice's 0.8-USDC fallback and lets Mallory net 0.9 USDC plus a 50% chance to retain the prize, but the entitlement Alice owns before the still-open sale closes is not specified strongly enough to elevate this to a finding.

## Conclusion

The per-ticket quote accounting, transfer semantics, deadline boundaries, rounding, and last-refunder behavior preserve the intended split for changing buyer cohorts. One concrete ordering defect remains: in the NFT branch, sponsor and treasury distributions can finish before the last claimant proves that the untrusted prize is deliverable. The sponsor top-up behavior is retained as a lead because it has a quantified temporal advantage but conflicts with no explicit in-scope rule.
