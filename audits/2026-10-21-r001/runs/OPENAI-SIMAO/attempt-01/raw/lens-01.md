# Lens 01 — Accounting Desync — native specialist response

Target revision supplied in bundle: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.
Requested and locally accepted model configuration: `gpt-6-astra`, effort `ultra`. Provider-returned model and effort: unknown; no actual tool metadata identifying either was supplied. These fields are provenance, not an inference from model self-description.

Independence: Read the complete 1,888-line lens bundle in eight bounded chunks. No peer output, history, tests, reports, scanner output, memory, network, or external service was consulted. Additional reads are restricted to reachable target dependency source and source-location checks. Target is unchanged. This is a source review; no execution result is claimed.

## Money model and properties

Buyers pay one USDC per entry and receive a transferable ticket. The ticket carries either its original full purchase-value refund or the result attached to its selected range. The current holder owns the claim; the payer does not retain a second claim. There is no yield or time-weighted entitlement. The sponsor supplies one NFT; the draw caller supplies the separate native oracle fee.

Write set: `buyEntries` increments `totalEntries`, `ticketCount`, the newly allocated range, and `unsettledPot`. `enableRefunds` moves the entire pot to `remainingRefundLiability`. `_settleWinningTicket` moves the entire pot to the winner/sponsor/treasury buckets. Each payout zeros its own bucket, and each refund reduces the refund bucket by the burned range value. Ticket transfers change ownership only. Burns intentionally do not rewrite historical counts/ranges. The factory increments its count and writes its three registry views together in the same atomic creation.

Properties checked:
1. Outstanding USDC buckets equal collected USDC minus successful USDC payouts; direct donations may create surplus but never claims.
2. The immutable historical ranges partition entries 1 through `totalEntries`; lifetime ticket count never exceeds entry count.
3. Each collected USDC unit enters exactly one of the pot, refund liability, or settled buckets and leaves through one matching debit.
4. NFT and cash settlement totals equal the old pot; no result can subsequently enter refunds.
5. Refunds burn only currently owned tickets and debit exactly their entry count times the fixed price, once.
6. Winner redemption uses the current owner, burns once, and rolls back entirely on failed delivery.
7. Sponsor and treasury payouts are independent and conserve balances in every payout order.
8. Prize return and winner prize release are mutually exclusive; the truthful custody assumption must be stated separately from USDC solvency.
9. A request spends only its caller's native contribution and returns its surplus; preexisting forced native funds do not enlarge the caller's refund.
10. Factory creation, registration, prize receipt and final checks commit or revert together; clone storage and liabilities remain separate.

## Working analysis, organized by lifecycle

[Model: createRaffle]
The sponsor gives one specified NFT to a newly created raffle. In exchange the sponsor gains the fixed proceeds rights and, for cash/refund outcomes, the right to have that NFT returned to its selected recipient. Successful creation increments the raffle count once and registers one address in all registry views. It creates no USDC liability.

[Why: RaffleFactory.sol:123]
Why register the clone before the prize contract is called? The transfer and its callback must already recognize the new clone as same-factory plumbing. Atomic rollback is the implicit protection if the later custody or active-state check fails.

[Defeat: createRaffle]
1. Prize contract P calls `createRaffle` again while depositing token 7 into clone R: the factory-wide reentrancy guard rejects the second creation, so it cannot duplicate raffle IDs or partly persist registry entries.
2. P invokes R's receiver callback, buys 3 entries with 3 USDC while R is temporarily Active, and then fails the final ownership check: the entire outer transaction, including those purchases and USDC movement, reverts.
3. P reports correct interface/custody answers, then permanently rejects future delivery of token 7: creation succeeds, but the NFT entitlement may later be unreachable. This is the prize-trust discrepancy assessed separately below; honest initial ownership reporting does not promise future transferability.

[Model: initialize]
A fresh raffle receives its sponsor, fixed payout destinations, prize identity, reserve and end time from its creating factory. Nobody pays or receives money in this step. No monetary bucket is credited, and the raffle must wait for the prize before selling entries.

[Defeat: initialize]
1. Address A calls initialize on a registered clone a second time: the initialized flag rejects it before any recipient can be overwritten.
2. A initializes a fresh proxy it deployed itself: A is not the immutable canonical factory, so the call fails.
3. A initializes the shared implementation: its constructor already locked initialization; no clone's sponsor or balances can be replaced through it.

[Model: onERC721Received]
The prize contract reports arrival of the configured NFT from the sponsor through the factory. This changes the raffle from waiting to active without moving or crediting USDC. The surrounding factory transaction verifies reported ownership after the callback.

[Why: Raffle.sol:428]
Why does a callback's assertion suffice to activate sales before the factory verifies ownership? Correctness depends on the outer factory transaction remaining atomic, and on treating the prize contract's custody claims as truthful. The first belief holds at transaction boundaries; the second is weaker than DESIGN.md's statement that arbitrary prize contracts are untrusted.

[Defeat: onERC721Received]
1. EOA A supplies the right token ID, sponsor and operator fields: `msg.sender` is not the configured prize contract, so activation fails.
2. The real prize contract repeats the exact callback after activation: the state is no longer AwaitingPrize, so no lifecycle reset is possible.
3. The prize contract supplies a genuine-looking callback and lies in `ownerOf`: both checks trust the same untrusted source. This does not change USDC arithmetic, but cannot prove an honest NFT entitlement.

[LastOut: Create]
With an honest supported prize, successful creation holds exactly token 7 for its future entitled recipient and owes zero USDC. Failed creation leaves no raffle registration, paid entries, or retained NFT movement. For a nontruthful or permanently rejecting prize, the later NFT claimant can be short one deliverable NFT even though all USDC buckets remain balanced; see the explicit trust-boundary lead.

[Model: buyEntries]
A payer sends `entryCount` USDC and chooses who receives one ticket for that many consecutive entries. Total sold entries rises by that count; lifetime tickets rises by one; the unallocated pot rises by the identical purchase price. The receiver may transfer the ticket but receives no second entitlement.

[Why: Raffle.sol:224]
Why credit the requested amount without measuring actual receipt? The immutable quote token is explicitly trusted canonical, fee-free, non-rebasing USDC. Under that stated assumption the requested and received amounts match. A fee-charging substitute is outside the quote-token trust model; this is not silently generalized to arbitrary tokens.

[Defeat: buyEntries]
1. With total entries equal to `2**128 - 1`, A requests one more entry: the cap check rejects before payment or mint, so neither count can wrap.
2. Receiver B transfers the freshly received 3-entry ticket to C inside the receiver callback and tries a second purchase/refund: ordinary authorized transfer can change the bearer, but every monetary entry point is locked by the current purchase; the paid 3-entry range remains unique.
3. B rejects receipt after 3 USDC was pulled and totals updated: the callback failure rolls back both payment and accounting, so no unbacked ticket or stranded paid purchase commits.

[Model: _update and inherited ticket transfer/burn]
Moving a ticket moves its whole remaining bearer claim from one owner to another; no money moves and the total claim does not change. Burning it erases its live ownership only. The enclosing refund or winner operation makes the matching monetary or prize debit, while the old range remains available as historical information.

[Why: Raffle.sol:497]
Why allow ticket transfers during terminal states and while other actions run? Payout rights are intentionally tied to current ownership and amounts to immutable ranges, so transfers never recalculate a pot. The inherited ownership updates contain no user callback; safe-receipt callbacks occur after ownership has changed.

[Defeat: _update]
1. A sends ticket 1 to the current raffle, its same-factory sibling or the quote-token contract: the destination filter rejects before the inherited ownership update.
2. A sends a non-owned ticket without approval to ordinary C: inherited authorization rejects; no claim can be reassigned for free.
3. A tries to burn by externally transferring ticket 1 to zero: inherited transfer rejects zero; only the guarded claim paths can invoke the internal burn. Burned ranges cannot be converted into a newly live ticket.

[LastOut: Buy/transfer]
A pays 2 USDC for ticket 1, B pays 3 USDC for ticket 2, and A transfers ticket 1 to C. The raffle holds 5 USDC and owes exactly 5 USDC before resolution/refund. In refunds, C can take 2 and B can take 3 in either order; the last holder receives its full price. Neither A nor an approved operator gains a second withdrawal right. Direct donations add only excess balance, not an extra claim.

[Model: requestDraw]
The caller contributes native currency to fund one randomness request. The raffle pays the wrapper the fee actually used by the inherited request helper and returns the caller's exact overpayment. No USDC bucket changes. The raffle records its request and deadline before it can resolve.

[Why: Raffle.sol:258]
Why check the returned fee against this call's contribution after the helper has already paid it? If the fee differs from the first quote, this check prevents a successful request from consuming preexisting forced native funds on the caller's behalf; an excessive actual fee reverts the entire request payment.

[Defeat: requestDraw]
1. R already holds 5 forced ETH; A supplies 0.2 ETH and the actual fee is 0.3 ETH: even if the helper temporarily draws on R's balance, the post-call check reverts all effects because 0.3 exceeds 0.2.
2. A supplies 0.4 ETH for a 0.3 ETH actual fee and rejects the 0.1 ETH refund: the entire request reverts, including the wrapper payment and lifecycle writes; A cannot make others fund its fee.
3. The wrapper calls back synchronously before the request ID is stored: the in-flight flag ignores it. A later matching callback may resolve; otherwise the timeout permits full USDC refunds.

[Model: fulfillRandomWords]
The authenticated wrapper supplies one result for the current request. This selects exactly one entry and chooses NFT or cash according to the fixed reserve. It moves no asset, allocates no money, and does not choose an owner. The recorded pot remains available for later settlement.

[Defeat: fulfillRandomWords]
1. A invokes the public inherited callback with the correct request ID and random word 0: the inherited wrapper-address check rejects A.
2. The wrapper returns the right ID with zero/two words or a different ID with one word: the handler ignores it before any modulo operation or state write.
3. A valid result arrives exactly at `drawRequestedAt + 2 days`, after refunds were enabled, or after a previous accepted callback: deadline/current-state checks reject it, so no refunded pot can become prize proceeds.

[LastOut: Draw]
For a 5-USDC pot, a caller contributing 0.4 ETH for a 0.3-ETH request receives 0.1 ETH back and leaves the pot unchanged. Previously forced native funds remain untouched. A valid result moves the 5-USDC pot only when settled; a failed/late request branch refunds all 5 USDC after its deadline. The final ticket refund receives its full amount; oracle cost is borne only by the voluntary draw caller and is not a USDC shortfall.

[Model: enableRefunds]
When the allowed no-sale or timeout branch is reached, the entire unallocated pot becomes the aggregate full-refund entitlement. The pot is zeroed. The sponsor separately regains the right to its NFT; no USDC is yet paid.

[Why: Raffle.sol:298]
Why assign rather than add to the refund bucket? There is exactly one transition into Refunding and no path out. The source state can have only an unallocated pot, so the destination bucket must still be zero. A repeated call is blocked by state, not by hoping the amount is unchanged.

[Defeat: enableRefunds]
1. Sponsor S cancels just after an honest buyer pays 1 USDC before sale end: positive entries force the sold-raffle timeout branch, so S cannot cancel a sold raffle early.
2. A requests refunds at request deadline minus one second: the request window remains open and refunds fail; at the exact deadline requestDraw fails and refunds succeed.
3. A calls after NFT/cash resolution, or calls again after Refunding: the state check rejects, so allocated or already refunded balances cannot be recredited.

[Model: refundTickets]
The current owner burns between one and 100 tickets and receives exactly one USDC for each entry those tickets represent. The aggregate outstanding refund amount falls by the exact same price before payment. All ticket burns and the debit are undone if payment fails.

[Why: Raffle.sol:365]
Why keep historical ranges after a ticket is burned? Historical range coverage is not the right to payment: the live ownership check is. A second reference to that ID encounters no owner, even in the same batch.

[Defeat: refundTickets]
1. In a 5-USDC refund state, A submits `[1,1]` for its 2-USDC ticket: the first burn removes ownership and the second lookup reverts the entire batch; A cannot obtain 4 USDC.
2. A submits its own ticket 1 and B's ticket 2: B's ownership check fails and restores the first burn; no partial debit commits.
3. A's recipient is rejected by USDC or payment fails: the whole batch reverts and the liability/tickets remain intact; another holder's independent refund still uses its own fully backed amount.

[LastOut: Timeout/cancel/refund]
With 7 paid entries split into tickets of 1, 2 and 4 entries, the pot becomes exactly 7 USDC of refunds. Refunding 4, then 2, then 1 leaves balances and liabilities 3, 1, then 0 USDC. Reversing the order gives 6, 4, then 0. Duplicate/nonexistent/foreign-ID batches do not change any committed state. The final holder is paid 100%; shortfall 0. Empty cancellation starts and ends with zero USDC and only returns the NFT. Failed/blocked USDC delivery preserves its exact liability and backing; no other holder inherits that loss.
