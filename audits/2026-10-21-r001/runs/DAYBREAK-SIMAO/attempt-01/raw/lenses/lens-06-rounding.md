[Model: Raffle.constructor]
No participant gives value or receives a claim. The shared implementation is permanently marked initialized and placed in a non-sale lifecycle state, so those two state fields change but no asset total does.

[Model: Raffle.initialize]
No asset moves. A fresh raffle records who supplied the prize, who may receive the sponsor side, the prize identity, the entry threshold, and the closing time, then moves from uninitialized to waiting for the prize.

[Model: RaffleFactory.createRaffle]
The sponsor gives one unique prize to a newly created raffle. In return, the raffle becomes the sole registered sale for that prize; the factory's raffle count rises by one and its three registry records are populated atomically.

[Model: Raffle.onERC721Received]
The sponsor's configured prize finishes moving into the raffle. The raffle gives no immediate payout; it changes from waiting for the prize to accepting entry purchases.

[Model: Raffle.buyEntries]
The buyer gives `entryCount * 1,000,000` raw quote-token units and the nominated recipient gets one transferable ticket covering exactly that many consecutive entries. Lifetime sold entries rise by `entryCount`, lifetime tickets rise by one, and the unallocated sale pot rises by the exact payment.

[Why: Raffle.sol:220]
Why is `type(uint128).max - totalEntries` the relevant bound? The implicit belief is that every later entry-range endpoint and winning-entry representation must fit the same 128-bit domain; checking the remaining capacity before either addition makes that belief true.

[Defeat: buyEntries]
1. With zero prior entries, Alice requests `2^128 - 1` entries. The payment is `340282366920938463463374607431768211455000000` raw units, which is below `2^256 - 1`, and the last entry is exactly `2^128 - 1`.
2. With `totalEntries = 2^128 - 2`, Bob requests two entries. Remaining capacity is one, so the call reverts before `totalEntries + entryCount`; no wrapped range can be minted.
3. With one entry per ticket, `ticketCount` can never exceed `totalEntries`. The final possible one-entry purchase can take both values from `2^128 - 2` to `2^128 - 1`, but a further purchase fails the entry-capacity check before the ticket counter advances.

[Model: Raffle._update]
The current ticket holder gives the entire bearer claim to the recipient, or gives it up when it is consumed. Entry counts, pot amounts, and the historical covered range do not change.

[Model: Raffle.requestDraw]
The requester gives native currency to pay for one randomness request. The wrapper receives its actual price, the requester immediately receives every excess unit, and the raffle records that a draw is pending together with the request time and identifier; sale-token totals do not change.

[Why: Raffle.sol:254]
Why is the current timestamp narrowed to 64 bits? The implicit belief is that chain time remains below `2^64` seconds. That bound lasts roughly 584.5 billion years; at `2^64` a request in the final post-`uint64` deadline window would store zero, but there is no reachable present-chain or economically meaningful path to that condition.

[Defeat: requestDraw]
1. If the quoted wrapper price is 9 wei and Alice supplies 8 wei, the request reverts before any timestamp or request state is recorded.
2. If the actual paid price is 9 wei and Alice supplies 9 wei, all 9 wei go to the wrapper and the excess is zero.
3. If the actual paid price is 9 wei and Alice supplies 12 wei, the wrapper receives 9 and Alice receives 3; subtraction occurs only after the code proves the paid price is no greater than 12.

[Model: Raffle.fulfillRandomWords]
No participant gives or receives an asset. One authenticated random number selects a one-based sold entry, the resolution time is recorded, and the raffle changes to either the unique-prize result or the cash result.

[Why: Raffle.sol:519]
Why is the modulo result safe to narrow to 128 bits? A nonzero sold-entry total is at most `2^128 - 1`; the remainder is at most one less than that total, and adding one therefore produces a value in `[1, totalEntries]`.

[Defeat: fulfillRandomWords]
1. With zero entries, no caller can reach modulo because draw initiation rejects the raffle; division by zero is unreachable.
2. With three entries, `2^256 mod 3 = 1`, so entry 1 has exactly one more preimage than entries 2 and 3. The absolute advantage is one word out of `2^256`, and there is only one accepted draw, so it has no practical or repeatable extraction path.
3. With `totalEntries = 2^128 - 1`, `2^256 = (2^128 - 1)(2^128 + 1) + 1`. The largest remainder is `2^128 - 2`, so adding one still fits exactly in 128 bits. The single-extra-preimage modulo bias remains only `1 / 2^256` in absolute probability.

[Model: Raffle.enableRefunds]
No new value enters or leaves. The entire unallocated sale pot becomes the amount owed to outstanding ticket holders, the old pot becomes zero, and the raffle enters the refund lifecycle.

[Model: Raffle.settleWinningTicket]
The caller gives no value and receives none. The call proves which historical ticket covers the selected entry and delegates the one-time conversion of the sale pot into final recipient claims.

[Model: Raffle._settleWinningTicket]
No asset moves. The whole sale pot is replaced by the cash-winner, sponsor, and treasury claims appropriate to the result; the unallocated pot becomes zero and the winning ticket is recorded.

[Why: Raffle.sol:548]
Why is the sponsor amount computed as the residual instead of as a separately rounded 15% or 95% amount? The implicit belief is that the sponsor is the designated remainder recipient, so subtracting the other allocations makes the final claims sum to the old pot for every integer input.

[Defeat: _settleWinningTicket]
1. For one entry, gross is `1,000,000`. A cash result allocates `1,000,000 * 8,000 / 10,000 = 800,000` to the winner, `1,000,000 * 500 / 10,000 = 50,000` to the treasury, and `150,000` to the sponsor. The sum is exactly `1,000,000`; no calculation rounds to zero.
2. For three entries, gross is `3,000,000`. An NFT result allocates `150,000` to the treasury and the exact `2,850,000` residual to the sponsor. A cash result instead allocates `2,400,000`, `150,000`, and `450,000`; both branches conserve all `3,000,000` units.
3. For `N = 2^128 - 1` entries, gross is `N * 1,000,000`, the fee is exactly `N * 50,000`, the cash award is exactly `N * 800,000`, and the cash sponsor amount is exactly `N * 150,000`. Even `gross * 8,000` is about `2.72e48`, far below the roughly `1.16e77` 256-bit maximum, and `Math.mulDiv` also avoids intermediate-overflow loss.

[Model: Raffle.redeemWinningTicket]
The current winning-ticket holder gives up and destroys the ticket claim, then receives either the unique prize or the entire recorded cash-winner amount. The winner claim becomes zero on a cash result; the consumed-ticket and delivered-prize flags change exactly once.

[Model: Raffle.refundTickets]
The current owner gives up each selected ticket and receives `1,000,000` raw quote units for every entry represented by those tickets. The outstanding refund total falls by precisely the payment; lifetime sales and historical ranges remain unchanged because they are historical facts.

[Why: Raffle.sol:364]
Why does range size add one after subtracting the endpoints? Ticket ranges are inclusive; for `[7, 7]`, `7 - 7 + 1 = 1`, and for `[7, 9]`, `9 - 7 + 1 = 3`. Every live ticket's endpoints were created in increasing order, so the subtraction cannot underflow.

[Defeat: refundTickets]
1. For tickets covering `[1, 1]` and `[2, 3]`, the computed entry counts are one and two, yielding refunds of `1,000,000` and `2,000,000` in either order.
2. Supplying the same ticket twice burns it on the first loop iteration and fails ownership lookup on the second; atomic failure restores the first burn and prevents a double refund.
3. Although a batch can contain 100 tickets, their nonoverlapping ranges together cannot represent more than the global `2^128 - 1` entries. Thus the aggregate and its multiplication by `1,000,000` have the same safe bound as the sale pot.

[Model: Raffle.releaseSponsorProceeds]
The caller gives and receives nothing. The immutable sponsor recipient receives the complete sponsor claim, and that claim becomes zero before delivery.

[Model: Raffle.releaseProtocolFees]
The caller gives and receives nothing. The immutable treasury receives the complete protocol claim, and that claim becomes zero before delivery.

[Model: Raffle.releaseSponsorPrize]
The caller gives and receives nothing. After a cash result or refund transition, the sponsor recipient receives the one escrowed prize and the prize claim is permanently consumed.

[Model: Raffle._transferQuote]
The selected recipient receives one complete recorded quote-token payment. The calling path has already reduced the corresponding amount owed, and a failed delivery restores that reduction with the rest of the call.

[Why: RaffleFactory.sol:69]
Why is six-decimal metadata sufficient for the arithmetic scale? The implicit belief is the stated trust boundary: deployment supplies canonical, non-rebasing, fee-free USDC. Within that boundary, a reported precision of six makes `1,000,000` exactly one token and keeps every entry payment on the basis-point denominator grid.

[Defeat: createRaffle]
1. A token reporting 18 decimals is rejected because 18 is not the required 6; the one-entry constant cannot silently become one-millionth or one-trillionth of the intended denomination.
2. With `endTime == block.timestamp`, creation rejects the timestamp before subtracting, so sale-duration arithmetic cannot underflow.
3. With `endTime = block.timestamp + 30 days + 1`, the exact second-based duration exceeds the fixed maximum and is rejected; all time constants use explicit day units.

[LastOut: draw-request native-value lifecycle]
For an actual wrapper price of 9 wei and 12 wei supplied, 9 leaves for the wrapper and 3 returns to the requester in the same call. The raffle retains zero attributable native currency, so there is no last requester left short.

[LastOut: refund lifecycle]
With three entries split as one-entry and two-entry tickets, refunding either ticket first leaves exactly the other ticket's `2,000,000` or `1,000,000` claim. The second and last owner is paid in full, after which both the recorded liability and attributable quote balance are zero.

[LastOut: cash-win lifecycle]
For a `3,000,000` pot, the three claims are winner `2,400,000`, sponsor `450,000`, and treasury `150,000`. In the worst order, any two may withdraw first; their sum leaves exactly the third claim, so the last claimant is paid in full and the protocol is short by zero.

[LastOut: NFT-win lifecycle]
For a `3,000,000` pot, sponsor and treasury claims are `2,850,000` and `150,000`. Either release order leaves the other amount exactly. The winning ticket separately receives the sole prize, so the last quote claimant and the prize claimant are both paid in full; shortfall is zero.

[LastOut: empty-raffle lifecycle]
No entry payment was collected and no quote claimant exists. The sponsor recipient receives the sole escrowed prize, leaving no tracked asset or unpaid claimant.

Saturation covered every arithmetic shape in scope: both percentage calculations and both settlement branches; sale, refund, and lifetime-gross multiplications; inclusive-range subtraction; native-value subtraction; entry and ticket increments; timestamp additions and narrowings; random modulo and narrowing; factory count and duration arithmetic; the six-decimal check; and every constant's unit. The minimum sale pot makes both percentage outputs nonzero, every possible pot is an exact multiple of `10,000`, all value-bearing products fit 256 bits, and every allocation or refund path conserves the complete pot.

No FINDING or LEAD was identified for the Rounding, Precision & Scale lens.
