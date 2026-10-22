[Model: implementation lock]
No participant gives or receives value. The reusable implementation is permanently marked unusable, preventing it from becoming an unbacked raffle.

[Model: clone initialization]
The factory supplies the sponsor, recipients, prize identity, reserve, and timing. No asset moves; the clone advances once to waiting for its configured prize.

[Model: raffle creation]
The sponsor gives one prize NFT and receives a future claim to proceeds or return of that NFT. The factory’s raffle count grows by one, its three registry records are created, and the new raffle becomes active only after custody is confirmed.

[Model: prize activation]
The sponsor’s configured NFT enters the raffle. Prize custody begins and the lifecycle changes from waiting for the prize to active.

[Model: entry purchase]
A buyer gives `entryCount × 1,000,000` raw USDC units; the recipient receives one transferable ticket covering exactly that many entries. Sold entries, tickets issued, and the unallocated sales total increase.

[Model: ticket ownership update]
A holder gives a ticket to another address, transferring its complete bearer claim. Entry counts, sales totals, and liabilities do not change.

[Model: draw funding]
The requester gives native currency; Chainlink receives the actual request price and the requester receives every excess unit. The raffle records one pending draw, but its USDC totals do not change.

[Model: refund activation]
No asset moves. The entire unallocated sales total is reclassified one-for-one as the outstanding refund total.

[Model: random resolution]
No asset moves. One entry from the fixed sold-entry population is selected, and the outcome becomes either NFT-won or cash-won.

[Model: permissionless winner settlement]
The caller gives no asset and receives no asset. The winning range is proved and the unallocated sales total is divided into winner, sponsor, and treasury claims.

[Model: terminal allocation]
For an NFT result, the sales total becomes 95% sponsor and 5% treasury claims. For a cash result, it becomes 80% winner, 15% sponsor, and 5% treasury claims.

[Model: winning redemption]
The current winning-ticket owner destroys the ticket and receives either the NFT or the complete cash-winner amount. The corresponding winner or prize claim is consumed exactly once.

[Model: ticket refund]
A holder destroys selected live tickets and receives `represented entries × 1,000,000` raw USDC units. The outstanding refund total decreases by exactly the payment.

[Model: sponsor cash release]
The sponsor recipient receives the complete sponsor claim. That claim is cleared atomically.

[Model: protocol fee release]
The treasury receives the complete protocol-fee claim. That claim is cleared atomically.

[Model: sponsor prize return]
After a cash result or refund transition, the sponsor recipient receives the escrowed NFT and the single prize claim is consumed.

[Model: quote payout helper]
A beneficiary receives one complete USDC claim whose corresponding liability has already been cleared. A failed payment restores all preceding state changes.

[Model: rejected native transfer]
A sender attempting an unrelated native-currency transfer receives no claim; the transaction rejects, so no value or tracked total changes.

[Why: Raffle.sol:223]
Why does multiplying a 128-bit entry count by `1,000,000` preserve scale and safety? Each entry is exactly `1,000,000` six-decimal units, and the maximum product occupies only 148 bits.

[Why: Raffle.sol:231]
Why is there no separate overflow guard for the ticket count? Every ticket contains at least one entry, so tickets issued can never exceed sold entries, whose 128-bit capacity is checked first.

[Why: Raffle.sol:253]
Why may the current timestamp be narrowed to 64 bits? Creation and request windows keep accepted timestamps near deployment time, relying on the realizable-chain assumption that timestamps remain below `2^64`.

[Why: Raffle.sol:254]
Why must an in-progress request temporarily reject resolution? The request identifier is not recorded until the external request returns, so accepting a synchronous response would compare against incomplete state.

[Why: Raffle.sol:258]
Why is the actual price checked after requesting randomness? The trusted wrapper reports the definitive price during the request, and transaction rollback restores the payment and lifecycle if it exceeds the supplied value.

[Why: Raffle.sol:363]
Why can refund arithmetic trust a stored historical range? Ownership is verified first, only a purchase creates the range, and a live ticket cannot previously have been destroyed.

[Why: Raffle.sol:368]
Why cannot subtracting a refund underflow the refund total? The total initially equals all ticket values, ranges are disjoint, and each live ticket can be destroyed only once.

[Why: Raffle.sol:459]
Why cannot adding two days overflow the request deadline? The end time is 64-bit and is widened before adding a small constant.

[Why: Raffle.sol:464]
Why is zero a safe “no callback deadline” sentinel? A valid draw records a practical nonzero chain timestamp before an asynchronous response can be accepted.

[Why: Raffle.sol:518]
Why are modulo-by-zero and narrowing excluded? Entering the draw requires at least one entry, sales are then frozen, and the selected value is at most the 128-bit sold-entry total.

[Why: Raffle.sol:542]
Why is the protocol fee rounded down? The specification assigns the aggregate floor to the treasury; moreover, every valid pot is a multiple of `1,000,000`, making the 5% result exact.

[Why: Raffle.sol:547]
Why is the sponsor amount calculated as the remainder? This assigns every raw unit exactly once even if percentage division could leave dust; at the configured entry scale, the result is exactly 15%.

[Why: RaffleFactory.sol:76]
Why does the factory check six decimals? It establishes the arithmetic scale; canonical token identity remains an explicit deployment trust boundary rather than something decimals metadata can prove.

[Why: RaffleFactory.sol:101]
Why is the duration subtraction ordered safely? A preceding strict comparison proves the supplied end time exceeds the current time.

[Why: RaffleFactory.sol:105]
Why is the raffle count increment not separately capped? Exhausting 256 bits would require `2^256` successful clone creations and is not a reachable economic state.

[Defeat: buyEntries]
1. Mallory buys one entry: she pays `1,000,000`, receives range `[1,1]`, and creates exactly that liability.
2. From an empty raffle she requests `2^128−1` entries: the `148`-bit gross amount and terminal range remain representable.
3. With `totalEntries = 2^128−2`, she requests two entries: the bounds check rejects the purchase; requesting one safely reaches the maximum.

[Defeat: requestDraw]
1. A requester supplies an exact `1,000`-wei price: all `1,000` wei go to the wrapper.
2. The requester supplies `1,001` wei for a `1,000`-wei actual price: exactly one wei returns.
3. If the actual price is `1,001` while only `1,000` was supplied, the transaction reverts atomically and retains nothing.

[Defeat: enableRefunds]
1. A sold raffle is finalized one second before its request deadline: the transition is rejected.
2. It is finalized exactly at the deadline: the entire pot moves into refund liability.
3. The sponsor closes an empty raffle before sale end: both quote-token totals remain zero and only the NFT-return path opens.

[Defeat: fulfillRandomWords]
1. With three entries, random word `0` selects entry `1`.
2. Word `1` selects entry `2`.
3. Word `2^256−1` selects entry `1`; modulo bias gives one bucket only one extra preimage out of `2^256`, and authenticated randomness is not caller-selectable.

[Defeat: _settleWinningTicket]
1. A one-entry cash raffle allocates `800,000` to the winner, `150,000` to the sponsor, and `50,000` to the treasury.
2. At `2^128−1` entries, the gross amount is 148 bits and even the largest rate numerator is only 161 bits.
3. A second settlement attempt is rejected before any allocation can repeat.

[Defeat: refundTickets]
1. Submitting `[1,1]` destroys the first occurrence and then fails ownership on the duplicate, reverting the entire operation.
2. Refunding 100 distinct tickets cannot aggregate more than the globally capped sold-entry count.
3. A final one-entry ticket against a `1,000,000` liability receives all `1,000,000`, leaving zero.

[Defeat: createRaffle]
1. An end time equal to the current timestamp is rejected.
2. An end time exactly 30 days later is accepted without truncation.
3. An end time 30 days and one second later is rejected before clone creation or prize movement.

[Defeat: terminal claim ordering]
1. From a `3,000,000` cash pot, the winner claims `2,400,000` first.
2. The treasury may then claim `150,000`.
3. The sponsor, claiming last, still receives the full remaining `450,000`; either other ordering yields the same result.

[Defeat: percentage granularity]
1. One entry produces exact 5%, 80%, 15%, and 95% amounts.
2. Splitting purchases across many tickets does not split settlement calculations because rates apply once to the aggregate pot.
3. Forced USDC donations do not enter the tracked pot and therefore cannot alter rates or claims.

[Defeat: deadline boundaries]
1. A draw at `endTime−1` is rejected as early.
2. A draw at `endTime` is accepted.
3. A draw or callback exactly at its exclusive deadline is rejected while refunds become available at that same timestamp.

[LastOut: create and escrow]
There is one NFT and one raffle custodian. No fractional claim is created; the NFT remains available for exactly one eventual winner delivery or sponsor return.

[LastOut: buy and transfer]
For tickets covering `[1,2]`, `[3,5]`, and `[6,6]`, six entries create `6,000,000` of backed claims. Transfers change claim ownership but not the total or range coverage.

[LastOut: successful draw]
The requester’s full excess is returned in the request transaction. The USDC pot remains untouched and fully backed while awaiting terminal allocation.

[LastOut: NFT settlement and redemption]
With three entries, the sponsor and treasury claims are `2,850,000` and `150,000`. Whichever claims last is paid in full, and the winning-ticket owner independently receives the NFT.

[LastOut: cash settlement and redemption]
With three entries, claims are `2,400,000`, `450,000`, and `150,000`. After any two claimants withdraw, the last receives its complete fixed balance; the raffle is short by zero.

[LastOut: timeout and refunds]
Alice’s two-entry ticket, Bob’s three-entry ticket, and Carol’s one-entry ticket start with `6,000,000` liability. After Alice and Bob receive `2,000,000` and `3,000,000`, Carol receives the final `1,000,000`; the shortfall is zero.

[LastOut: empty raffle]
There is no quote-token claimant. The sole escrowed NFT returns exactly once to the sponsor recipient.

[LastOut: independent releases]
Winner, sponsor, and treasury releases clear separate fixed claims. Every permutation ends with the final claimant paid in full and the accounted USDC balance at zero.

NO FINDINGS OR LEADS

Coverage: `Raffle.sol` — entry/range arithmetic, all liability migrations, percentage allocation, refund aggregation, native-fee subtraction, random modulo, timestamp/count casts, boundary ordering, and every payout order. `RaffleFactory.sol` — decimal scale, end-time subtraction, duration limits, raffle counter, registry sequencing, and escrow activation. `IRaffle.sol` and `IRaffleFactory.sol` — ABI widths, units, return types, lifecycle descriptions, and economic percentages against implementation behavior. `RaffleConstants.sol` — six-decimal price, basis-point denominator/rates, time units, batch cap, and gas/count widths. `DESIGN.md` — floor/remainder policy, terminal splits, exclusive deadlines, and full-refund requirements. Properties covered: zero/minimum/maximum inputs, division direction, remainder allocation, division-before-multiplication, intermediate overflow, narrowing casts, subtraction ordering, modulo bias, sibling arithmetic sites, saturation across both result branches, and the Last User Out test.