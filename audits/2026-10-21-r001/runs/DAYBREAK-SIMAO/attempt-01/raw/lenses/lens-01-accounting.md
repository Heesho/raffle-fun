# Lens 1 — Accounting Desync

Runtime-supplied model field: unknown.

Result: no `FINDING` or `LEAD` block. Within the supplied scope, every intended USDC outflow consumes an equal recorded liability, every terminal allocation preserves the full pot, and no source-supported sequence makes aggregate claims exceed the raffle's USDC balance. The edge cases that survive only require a claimant to deliberately strand its own claim or require a trusted dependency to violate its stated trust model, so the shared rules exclude them.

## Money-map execution

[Model: raffle creation and prize escrow] A sponsor gives one configured NFT. In return, a new raffle is assigned one permanent identifier and becomes usable only after that NFT is reported as owned by it. The factory's lifetime count and its three registry views gain one matching raffle; no USDC claim exists yet.

[Why: RaffleFactory.sol:119] Why are the new raffle's registry entries recorded before the NFT handoff finishes? The implicit belief is transaction atomicity: the temporary membership is useful while the external NFT call runs, factory reentry is barred, and any failed handoff or post-handoff ownership check rolls back the count, clone, registry, and NFT movement together.

[Defeat: createRaffle]

1. A sponsor supplies `reserveEntries = 0`, `endTime = block.timestamp`, or `endTime = block.timestamp + 30 days + 1`; creation stops before any durable count, registry, or custody change.
2. A prize at address `P` calls back twice or reenters `createRaffle` while raffle `R1` is being funded; `R1` accepts only the exact first `P/tokenId/sponsor/factory` handoff, and the factory's active reentry lock rejects the nested creation. A later failure rolls the whole creation back.
3. A sponsor chooses the predicted address of `R1` as `sponsorRecipient`; initialization compares that recipient with `address(this)` and reverts. Choosing an already registered raffle `R0`, the factory, USDC, wrapper, implementation, or prize address is also rejected.

[Model: clone initialization] No user value moves. The fresh raffle receives its fixed sponsor, destinations, prize identity, reserve, end time, and identifier, and moves from uninitialized to waiting for its prize. This can happen once and only as part of the factory's atomic creation.

[Defeat: initialize]

1. Address `A` calls a fresh clone directly before the factory can do so; there is no externally observable gap because clone creation and factory initialization are in one transaction, and `A` is not the immutable factory.
2. The factory tries to initialize `R1` twice with raffle IDs `1` and `2`; the second call sees the consumed initialization flag and reverts.
3. Parameters name `R1`, USDC, wrapper, factory, implementation, prize token, or existing registered raffle `R0` as a protocol destination; initialization rejects that exact address before activation.

[Model: prize activation] The configured NFT arrives from the sponsor through the factory. The raffle changes from waiting for the prize to selling tickets; no sale balance or claimant total changes.

[Defeat: onERC721Received]

1. Token `P` supplies the right token ID but names `0x000000000000000000000000000000000000bEEF` instead of the sponsor as the previous owner; the handoff is rejected.
2. The sponsor calls the receiver hook directly, or `P` names an operator other than the canonical factory; the handoff is rejected.
3. `P` reports the hook successfully and then moves the NFT away before returning; the factory's final ownership and active-state checks revert the entire creation under ordinary ERC-721 semantics.

[Model: entry purchase] A buyer gives `entryCount * 1,000,000` raw USDC units. The chosen recipient gets one ticket covering exactly that many new consecutive entries. Lifetime entries rise by `entryCount`, lifetime tickets rise by one, and the unallocated sale pot rises by exactly the payment.

[Why: Raffle.sol:225] Why is payment collected before the new range and totals are credited? The required belief is that canonical USDC either completes the exact fee-free payment or fails, while the transaction also rolls back the payment if range creation or ticket delivery later fails; the reentry lock prevents observing a half-credited purchase through another value-moving raffle call.

[Defeat: buyEntries]

1. A buyer requests `0` entries or requests `2` when `totalEntries = type(uint128).max - 1`; the call stops before payment and cannot wrap the range.
2. A buyer pays for three entries but recipient `R0` is an already registered raffle, the factory, USDC, wrapper, prize token, implementation, or the current raffle; ticket delivery is rejected and the three-USDC payment rolls back.
3. Recipient contract `C` receives ticket `7` and, during receipt, attempts another purchase, refund, or redemption; the active value-operation lock rejects it. `C` may transfer ticket `7`, but that transfers the same claim and changes none of the pot or entry totals.

[Model: ticket transfer] The old owner gives away one existing bearer claim and the new owner receives the identical entry range. No USDC enters or leaves, and no entry, ticket, or liability total changes.

[Why: Raffle.sol:474] Why do range records remain after a ticket is burned? They are historical coverage needed to prove which unique ticket contained a selected entry; current claimability comes from ticket ownership and the one-time terminal flags, not from deleting the range.

[Defeat: _update]

1. Owner `A` transfers ticket `9` directly to current raffle `R1`; the direct self-address check rejects it.
2. `A` transfers ticket `9` to already registered raffle `R0`; the runtime factory-membership check rejects it.
3. `A` deliberately transfers ticket `9` to code-less address `R2` and later causes `R2` to become a raffle. The initial transfer can pass, but only `A` selected and surrendered the bearer claim to that counterfactual address. The resulting inaccessible claim is self-harm, creates no excess claim, and cannot make another cohort short.

[Model: draw request] A caller gives native currency. The wrapper receives its actual request price, and the same caller receives every excess unit immediately. The raffle records one request and its start time and moves from selling to awaiting randomness; sale USDC remains untouched.

[Why: Raffle.sol:252] Why are callbacks ignored while the request call is still in flight? The code relies on persisting the wrapper's returned request identifier before any callback can become authoritative, preventing a synchronous or stale callback from resolving against identifier zero or partially recorded request state.

[Defeat: requestDraw]

1. Caller `A` requests one second before sale end or exactly at `endTime + 2 days`; the time guards reject the request before native value can be retained.
2. The quoted fee is `1 ether`, `A` sends `1 ether`, and the wrapper reports an actual price above `1 ether`; the explicit post-call check reverts the wrapper payment and all request state.
3. The actual price is `1 ether`, contract `C` sends `1 ether + 7 wei`, and `C` rejects the `7 wei` return; the whole request, wrapper payment, status change, and retained excess revert. Only `C` can cause this failure and `C` loses no retained value.

[Model: randomness resolution] No user gives or receives value. One authenticated word selects exactly one sold entry, records the resolution time, and fixes either the NFT outcome or cash outcome according to the already fixed sold-entry total and reserve.

[Defeat: fulfillRandomWords]

1. The wrapper supplies request ID `41` when the stored ID is `42`; the callback is ignored and no winner state changes.
2. The wrapper supplies zero or two words for request `42`; the callback is ignored and modulo selection never executes.
3. Request `42` began at time `T`; a callback at exactly `T + 2 days` is ignored, so it cannot race a refund transition at the exclusive deadline into two terminal branches.

[Model: refund activation] No asset moves. The entire unallocated USDC pot changes names from sale pot to ticket-refund liability, by the identical amount, and the raffle enters its final refund state.

[Why: Raffle.sol:296] Why is the old pot copied before it is cleared? The implicit belief is conservation across liability buckets: a single pre-change amount must become the refund total, after which there must be no remaining sale-pot claim that could be allocated a second time.

[Defeat: enableRefunds]

1. A sold active raffle at `endTime + 2 days - 1` is forced toward refunds; the request-window deadline blocks the transition.
2. A drawing raffle requested at `T` is forced toward refunds at `T + 2 days - 1`; the callback deadline blocks the transition.
3. At the applicable exact deadline, refunds may be enabled, but status and pot are changed once. Any later valid-looking callback is ignored because the raffle is already refunding, and a second refund activation is rejected.

[Model: winning-ticket settlement] No asset moves and ticket ownership is unchanged. The whole old sale pot is consumed once and replaced by the winner, sponsor, and treasury liabilities appropriate to the already fixed outcome. The winning range is recorded once.

[Why: Raffle.sol:539] Why may someone who does not own the ticket perform settlement? Settlement only proves which historical range contains the selected entry and divides the common pot; it gives the caller no claim. The bearer remains whoever owns the ticket at later redemption.

[Why: Raffle.sol:543] Why is the old pot read before it is cleared? Every percentage and the sponsor remainder must share the same pre-settlement base; clearing first would allocate zero, while clearing after the three amounts are fixed makes the one-time conservation equation explicit.

[Defeat: _settleWinningTicket]

1. Caller `A` supplies never-minted ticket `0` or `ticketCount + 1`; its stored range is `[0,0]`, which cannot contain a one-based winning entry.
2. The winning entry is `8`, and `A` supplies ticket `3` with range `[9,12]`; the containment check rejects it without allocating any liability.
3. After ticket `2` has settled the pot, `A` submits ticket `2` again or a different ticket; the consumed-settlement flag rejects both, so no second set of claims can be created.

[Model: winning-ticket redemption] The current winning-ticket owner gives up and destroys that bearer claim. In an NFT outcome, that owner receives the one escrowed NFT and the prize-consumed flag advances. In a cash outcome, the owner receives the complete recorded winner amount and that liability becomes zero. A failed delivery restores the ticket, flags, and liability through transaction rollback.

[Defeat: redeemWinningTicket]

1. Ticket `2` is owned by `A`, and caller `B` supplies it; ownership is checked after any needed settlement and before delivery, so `B` receives nothing and cannot burn `A`'s claim.
2. Ticket `2` was settled and then transferred from `A` to `B`; `A` can no longer redeem, while `B` can redeem the same fixed range exactly once. Settlement did not snapshot the old owner.
3. In a cash result with `winnerProceeds = 4,000,000`, the USDC payment fails; the earlier burn, recipient record, consumed flag, and zeroing of `winnerProceeds` all revert, leaving the full `4,000,000` claim intact.

[Model: ticket refunds] A current owner gives up one to one hundred tickets. The owner receives exactly `represented entries * 1,000,000` raw USDC units. The aggregate refund liability and actual USDC balance fall by that same amount; historical sold-entry and range facts remain unchanged.

[Why: Raffle.sol:365] Why is the refund amount derived from the stored inclusive ranges instead of a caller amount? Each range was fixed at paid purchase time, so this reproduces the original payment independently of transfer history and gives the caller no quantity to inflate.

[Defeat: refundTickets]

1. Owner `A` submits `[4,4]`; the first occurrence burns ticket `4`, the second ownership lookup fails, and transaction rollback restores the first burn and liability.
2. `A` submits its ticket `4` together with ticket `5` owned by `B`; the foreign-owner check reverts the whole batch, so `A` cannot debit `B`'s liability or keep a partial payment.
3. `A` submits a 101-ticket batch or an already burned ticket; the size or existence check rejects it before any persistent liability reduction. A successful batch can sum no more entries than the globally sold `uint128` amount.

[Model: sponsor proceeds release] The immutable sponsor recipient receives its complete recorded USDC amount. That single liability becomes zero before the payment and is restored if payment fails; every other claimant's bucket is untouched.

[Defeat: releaseSponsorProceeds]

1. Caller `A` invokes release before settlement, when the sponsor amount is zero; the call rejects and transfers nothing.
2. The recipient was an already known protocol address at creation; initialization rejected the raffle, so no such live sponsor claim can exist.
3. The sponsor deliberately chose a code-less future clone address `R2`; after `R2` is registered, the payout-time membership check rejects the transfer and preserves the sponsor liability. This can strand only the creator-selected sponsor claim and cannot consume the winner or treasury balance.

[Model: protocol fee release] The immutable treasury receives its complete recorded USDC amount. The treasury liability becomes zero before payment and is restored if payment fails; winner and sponsor liabilities are untouched.

[Defeat: releaseProtocolFees]

1. Caller `A` invokes release before settlement or a second time; a zero fee balance rejects both calls.
2. Treasury is the factory, USDC, wrapper, or implementation at deployment; factory construction rejects that configuration.
3. Treasury was configured as a future clone address `Rk`; creation of clone `Rk` later fails because initialization sees the treasury equal the current raffle. The factory transaction rolls its nonce and count back, so value is never paid into that clone through this path. This is deployment self-misconfiguration, not an attacker-created accounting shortfall.

[Model: sponsor prize release] In a cash or refund result, the sponsor recipient receives the one escrowed NFT. The prize-consumed flag advances once, and a failed transfer or wrong reported owner restores it. No USDC liability changes.

[Defeat: releaseSponsorPrize]

1. Caller `A` attempts release while the raffle is active, drawing, or in the NFT-winner state; the outcome guard rejects it.
2. Caller `A` releases successfully and caller `B` repeats; the prize-consumed flag rejects the second transfer.
3. The sponsor deliberately selected code-less future clone address `R2`, which later becomes registered. The NFT path does not re-screen `R2` and can move the sponsor's NFT there, but the only party that selected this counterfactual destination is the sponsor at creation. It neither creates a second NFT claim nor takes value from another cohort, so it is excluded as self-harm under the shared rules.

## Required last-user-out tests

[LastOut: create -> escrow -> activate] On success, exactly one raffle owns the NFT and there is no quote claimant. On any failed callback, ownership check, or active-state check, the creation transaction removes the clone, registry writes, and custody movement together. There is no last quote user and no partial factory liability.

[LastOut: buy -> hold/transfer ticket] Five entries bought as tickets covering two and three entries create `5,000,000` units of pot and exactly five entry claims. Any number or order of ticket transfers changes only who holds those claims. The terminal refund, cash, and NFT branches below each begin with the same `5,000,000`; transfer order introduces a shortfall of `0`.

[LastOut: sale ends -> request -> callback] If the actual wrapper price is `P` and the caller supplies `P + 7`, the wrapper receives `P` and the caller receives `7`; intended residual native balance is `0`. Resolution moves no USDC. If the request or excess return fails, all native and request-state effects revert. The native funder's last-out shortfall is `0`.

[LastOut: NFT result -> settle -> redeem/release] With gross USDC `G = 5,000,000`, settlement records protocol `250,000` and sponsor `4,750,000`, totaling `G`; the ticket owner separately receives the one NFT. If sponsor leaves first, the contract retains `250,000` for treasury; if treasury leaves first, it retains `4,750,000` for sponsor. The last quote claimant is paid in full and quote balance/liability end at `0`; prize custody ends with the one winning owner.

[LastOut: cash result -> settle -> redeem/release] With `G = 5,000,000`, winner gets `4,000,000`, protocol gets `250,000`, and sponsor gets the exact `750,000` remainder. In the worst order, sponsor and protocol leave first, so the contract still holds exactly `4,000,000` for the winner; reversing the order similarly preserves the remaining buckets. The last claimant is paid in full, ending with claims `0`, balance `0`, and shortfall `0`. The sponsor recipient can independently recover the NFT.

[LastOut: request/callback timeout -> refunds] Tickets covering two and three entries begin with liability and balance `5,000,000`. Refund the three-entry ticket first: both fall to `2,000,000`. The last owner burns the two-entry ticket and receives `2,000,000`; both reach `0`. Reversing the order produces the same result, so the last refunder is short by `0`.

[LastOut: empty raffle cancellation] No entry was sold, so quote balance and all quote claims are `0`. The sponsor can close before sale end, or anyone can close at or after it, and the sponsor recipient receives the sole NFT once. There is no last quote claimant and no unowned intended value.

## Saturation sweep

- Missing decrement: the only quote exits are winner cash redemption, ticket refund, sponsor release, and treasury release. Each zeroes or reduces exactly its own bucket before paying, and failure rolls that write back. There is no sibling exit, emergency exit, expiry exit, or factory route that transfers sale USDC without consuming a bucket.
- One-sided branch: NFT settlement deliberately creates no cash-winner liability, while cash settlement does; both allocate protocol fees and give the sponsor the exact remainder. Refund activation clears the pot and creates an equal refund liability in every permitted active/drawing timeout branch.
- Write-before-read: settlement reads the whole old pot before clearing it; redemption records the current owner before burning; refunds sum fixed ranges before reducing the aggregate. None uses a post-burn or post-zero denominator.
- Untracked balance: no payout or allocation uses `balanceOf(address(this))` or native contract balance as its source. Forced USDC can only make assets exceed claims, never claims exceed assets. Forced native currency and unrelated NFTs have no claimant and no extraction route, exactly as the supplied ownership model states.
- Reinitialization: clone configuration is one-time, ticket ranges are assigned once, and no terminal status returns to sales. There is no deposit-withdraw-deposit path that overwrites a still-live aggregate.
- Mismatched pair: purchase cost, range length, refund amount, and gross sales all use the same `entryCount * 1,000,000` relation. Cash and fee amounts share one gross base, and the sponsor receives `gross - winner - fee`, so rounding cannot leave an ownerless unit.
- Ignored actual amount: canonical USDC is expressly trusted to be fee-free and non-rebasing. The native wrapper path records its returned actual price rather than assuming the initial quote, checks it against supplied value, and refunds the exact difference.
- Cross-clone and predicted-address sweep: current protocol destinations are rejected for ticket ownership and quote payouts. A code-less future clone can be deliberately selected as a ticket or sponsor destination, but doing so only strands the selector's own bearer/sponsor claim; it cannot debit another raffle or manufacture a second claim. The sponsor-NFT transfer can place that sponsor's NFT in such a future clone, but there is no non-self victim or quote insolvency path.
- Delivery and reentry sweep: all quote-moving entry points are mutually guarded. A failed USDC or NFT delivery rolls back its preceding burn, zero, or consumed flag. A prize contract that lies about its own ownership can defeat any ownership query, but that neither desynchronizes the trusted USDC ledger nor supplies a meaningful stronger check the raffle could perform; no accounting finding follows from the token violating its own reported state.

Final balance sheet: after purchases, `actual USDC >= unsettledPot`; after refund activation, the same amount is `remainingRefundLiability`; after settlement, `winnerProceeds + sponsorProceeds + protocolFees` equals the old pot; after each successful exit, actual balance and the corresponding liability fall equally. Across every reachable intended lifecycle, aggregate quote claims exceed actual quote holdings by `0`.
