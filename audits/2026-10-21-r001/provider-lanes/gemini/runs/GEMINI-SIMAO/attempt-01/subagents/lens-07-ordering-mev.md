# 0xSimao Audit Report — Lens 7 (Ordering, MEV & Price Manipulation)

## Phase 0–4 Reasoning & Protocol Trace

### Function Models (`[Model: ...]`)

`[Model: createRaffle]`
A sponsor supplies an ERC-721 prize token and ID, a sponsor payout address, a reserve entry threshold, and an exclusive sale end timestamp. The factory increments `raffleCount`, deploys a new clone of `Raffle`, initializes it in `AwaitingPrize`, registers it in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the prize NFT from the sponsor into the clone. The clone's receiver callback switches its status to `Active`, and the factory verifies that the clone owns the prize NFT and is `Active`.

`[Model: buyEntries]`
While the raffle is `Active` and before `endTime`, a buyer pays `entryCount * 1,000,000` raw USDC units into the raffle and receives a newly minted ERC-721 ticket whose ID is `ticketCount + 1` and whose stored range covers `[totalEntries + 1, totalEntries + entryCount]`. The raffle increases `totalEntries` by `entryCount`, increments `ticketCount` by 1, and adds the USDC payment to `unsettledPot`.

`[Model: requestDraw]`
In the window `[endTime, endTime + 2 days)` when `totalEntries > 0`, any caller supplies native ETH to cover the Chainlink VRF v2.5 wrapper fee. The raffle switches from `Active` to `Drawing`, records `drawRequestedAt = block.timestamp` and the returned `vrfRequestId`, pays `paidPrice` in native ETH to the wrapper, and returns any excess `msg.value - paidPrice` back to the caller.

`[Model: fulfillRandomWords]`
Before `drawRequestedAt + 2 days`, the Chainlink VRF wrapper delivers one random word for `vrfRequestId`. The raffle picks `winningEntry = (randomWords[0] % totalEntries) + 1`, records `resolvedAt = block.timestamp`, and sets `status` to `NftWon` if `totalEntries >= reserveEntries` or `CashWon` if `totalEntries < reserveEntries`. No balances or liabilities move yet.

`[Model: enableRefunds]`
Transitions the raffle to `Refunding`, zeroes `unsettledPot`, and moves its entire value into `remainingRefundLiability`. This is permitted in three cases: (1) while `Active` with `totalEntries == 0` (by `sponsor` before `endTime`, or anyone at/after `endTime`), (2) while `Active` with `totalEntries > 0` at/after `endTime + 2 days`, or (3) while `Drawing` at/after `drawRequestedAt + 2 days`.

`[Model: _settleWinningTicket]`
Once resolved to `NftWon` or `CashWon`, any caller passes the `ticketId` whose stored `[firstEntry, lastEntry]` range contains `winningEntry`. The raffle zeroes `unsettledPot`, allocates 5% of the pot (floored) to `protocolFees`, allocates 80% of the pot (floored) to `winnerProceeds` if `CashWon` (or 0 if `NftWon`), and allocates the remaining pot to `sponsorProceeds`. It records `winningTicketId = ticketId` and `settlementComplete = true`.

`[Model: redeemWinningTicket]`
The current owner of `winningTicketId` burns the ticket (settling first if not yet settled), records `winnerRecipient = msg.sender` and `winnerRedeemed = true`, and receives either the escrowed prize NFT (marking `prizeClaimed = true` in `NftWon`) or the `winnerProceeds` USDC balance (zeroing `winnerProceeds` in `CashWon`).

`[Model: refundTickets]`
In `Refunding`, a ticket owner passes 1 to 100 of their own ticket IDs. Each ticket is burned, its entry count `lastEntry - firstEntry + 1` is summed, `remainingRefundLiability` is reduced by `aggregateEntries * 1,000,000`, and that exact USDC amount is transferred to `msg.sender`.

`[Model: releaseSponsorProceeds]`
Anyone triggers payout of the current `sponsorProceeds` balance; the raffle zeroes `sponsorProceeds` and transfers that USDC amount to the immutable `sponsorRecipient`.

`[Model: releaseProtocolFees]`
Anyone triggers payout of the current `protocolFees` balance; the raffle zeroes `protocolFees` and transfers that USDC amount to the immutable `protocolTreasury`.

`[Model: releaseSponsorPrize]`
In `CashWon` or `Refunding` when `prizeClaimed` is false, anyone triggers return of the prize NFT; the raffle sets `prizeClaimed = true` and transfers `prizeTokenId` to `sponsorRecipient`.

---

### Deep-Drill Questions (`[Why: ...]`)

`[Why: Raffle.sol:280]`
Why does the sponsor's early cancellation check in `enableRefunds()` test `if (totalEntries == 0)` while `buyEntries()` remains open in the same block without any sponsor pause or cancellation lock?
Because the code assumes that if a raffle is empty when the sponsor decides to cancel, no one will buy a single 1 USDC entry before the sponsor's transaction lands—ignoring that in a public mempool an attacker can front-run `enableRefunds()` with `buyEntries(attacker, 1)` to force `totalEntries == 1` and revert the sponsor's cancellation.

`[Why: Raffle.sol:498]`
Why does `_update()` allow ticket transfers in every `status` (`Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`) instead of freezing transfers during `Drawing` or restricting post-resolution transfers to unredeemed claims?
Because the design treats tickets as unconditional ERC-721 bearer tokens across all states, implicitly assuming that secondary buyers reread chain and mempool state—ignoring that during `Status.Drawing`, the VRF fulfillment transaction `rawFulfillRandomWords` reveals `randomWords[0]` in the public mempool before inclusion, letting MEV searchers compute `winningEntry` and front-run open secondary listings or collection bids.

`[Why: Raffle.sol:521]`
Why does `fulfillRandomWords()` step the sponsor's proceeds discontinuously from 15% of `unsettledPot` (at `totalEntries == reserveEntries - 1`, `CashWon`) to 95% of `unsettledPot` (at `totalEntries == reserveEntries`, `NftWon`) while allowing the sponsor to buy entries up to `endTime`?
Because the code assumes `totalEntries` reflects organic buyer demand independent of the sponsor, overlooking that a sponsor can monitor `totalEntries` right before `endTime` and self-purchase the remaining `reserveEntries - totalEntries` entries to capture an 80% jump on all previously deposited user funds whenever the NFT is worth less than the unlocked pot jump.

`[Why: Raffle.sol:243]`
Why does `requestDraw()` only check `if (totalEntries == 0) revert NoEntriesSold()` rather than requiring at least two tickets or `totalEntries >= reserveEntries`?
Because the code treats any non-zero `totalEntries` as a valid raffle draw, overlooking that if only a single buyer entered (`ticketCount == 1`) and `totalEntries < reserveEntries`, calling `requestDraw()` at `endTime` resolves to `CashWon` where the sole buyer wins 80% of their own deposit back while the sponsor extracts 15% of the buyer's deposit plus keeps the prize NFT (and treasury takes 5%).

`[Why: Raffle.sol:602]`
Why does `_isProtocolDestination()` skip `canonicalFactory.isRaffle(destination)` when `destination.code.length == 0`?
Because the code assumes a `Raffle` clone can only be identified after it has been deployed with code and registered in `isRaffle`, overlooking that `RaffleFactory::createRaffle` uses `Clones.clone` (`CREATE` opcode), so every future `Raffle` clone address is 100% deterministic from `(address(factory), nonce)` before deployment when `code.length == 0`.

`[Why: Raffle.sol:404]`
Why does `releaseSponsorPrize()` transfer the prize NFT to `sponsorRecipient` via `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without checking `_isProtocolDestination(recipient, address(prizeToken))`, whereas `_transferQuote()` re-checks `_isProtocolDestination()` at withdrawal time?
Because the author assumed `initialize()` already screened `sponsorRecipient` once and that its status as a non-protocol destination could never change afterward—which is false for a precomputed future `Raffle` clone address deployed after initialization.

---

### Guard Defeat Attempts (`[Defeat: ...]`)

`[Defeat: enableRefunds]`
1. **Mempool front-run with 1-entry purchase (`Raffle.sol:280`)**: Sponsor calls `enableRefunds()` at `t = 1000` (`endTime = 2,592,000`, `totalEntries = 0`). Attacker front-runs with `buyEntries(0xAttacker, 1)` paying `1,000,000` USDC. `totalEntries` becomes `1`, causing `enableRefunds()` to hit the `else` branch (`Raffle.sol:285`) and revert with `RefundsNotAvailable(2764800, 1000)`, locking the sponsor's NFT for up to 32 days (or stealing it for 1 USDC if `reserveEntries == 1`).
2. **Pre-end non-sponsor call (`Raffle.sol:282`)**: Caller `0xBeef != sponsor` calls `enableRefunds()` at `t = 1000 < endTime` with `totalEntries = 0`. Reverts with `RefundsNotAvailable(endTime, 1000)`. Guard holds.
3. **Boundary timestamp call during `Drawing` (`Raffle.sol:291`)**: Caller calls `enableRefunds()` at `block.timestamp == callbackDeadline() - 1`. Reverts with `RefundsNotAvailable(callbackDeadline(), block.timestamp)`. At `block.timestamp == callbackDeadline()`, `fulfillRandomWords` ignores any callback (`block.timestamp >= callbackDeadline()`) and `enableRefunds()` succeeds. Guard holds on boundary.

`[Defeat: _isProtocolDestination]`
1. **Precomputed next-nonce `Raffle` clone as `sponsorRecipient` (`Raffle.sol:602`, `RaffleFactory.sol:106`)**: When `raffleCount == 1` (factory nonce 2), compute `futureRaffle2 = computeCreateAddress(factory, 3)`. Create Raffle 1 with `sponsorRecipient = futureRaffle2` (passes `initialize` and `_validateCreateParams` because `futureRaffle2.code.length == 0` and `isRaffle[futureRaffle2] == false`). Then create Raffle 2 at `futureRaffle2`. Now `isRaffle[futureRaffle2] == true`: in Raffle 1, `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(futureRaffle2)`, and `releaseSponsorPrize()` transfers Raffle 1's prize NFT into Raffle 2 (`futureRaffle2`), violating "Never move assets between raffle clones" and locking both assets.
2. **Precomputed next-nonce `Raffle` clone as ticket recipient (`Raffle.sol:235, 498`)**: In Raffle 1, call `buyEntries(futureRaffle2, 10)` before Raffle 2 is created. Because `futureRaffle2.code.length == 0`, `_update` passes `_isProtocolDestination` and `_safeMint` skips `onERC721Received`. Once Raffle 2 is created at `futureRaffle2`, the ticket is owned by Raffle 2, which has no function to transfer, redeem, or refund ERC-721 tickets, permanently stranding `10,000,000` USDC in `remainingRefundLiability` (or `winnerProceeds` / the prize NFT if it wins).
3. **Direct transfer to existing Raffle clone (`Raffle.sol:498`)**: Call `transferFrom(user, existingRaffle1, ticketId)` on Raffle 2. Since `existingRaffle1.code.length == 45` and `isRaffle[existingRaffle1] == true`, `_isProtocolDestination` returns `true` and reverts with `UnsafeProtocolDestination(existingRaffle1)`. Guard holds for already-deployed clones.

`[Defeat: requestDraw]`
1. **Single-participant `CashWon` trigger (`Raffle.sol:243`)**: User `0xAlice` buys 100 entries (`100,000,000` USDC) in a raffle with `reserveEntries = 1000`. No one else buys entries before `endTime`. At `block.timestamp == endTime`, `sponsor` calls `requestDraw()`. VRF resolves to `CashWon`: `0xAlice` gets `80,000,000` USDC, `sponsorRecipient` gets `15,000,000` USDC plus the prize NFT back, and `protocolTreasury` gets `5,000,000` USDC—extracting 20% of Alice's deposit despite zero other participants.
2. **Pre-funded clone native balance extraction (`Raffle.sol:262`)**: Send 1 ETH to predicted clone address before `createRaffle`. Call `requestDraw()` with `msg.value = quotedFee`. `excess` is computed as `msg.value - paidPrice = 0`, not `address(this).balance`, so the caller cannot sweep the pre-existing 1 ETH. Guard holds.
3. **Synchronous callback during `requestDraw` (`Raffle.sol:254, 511`)**: If a wrapper attempted to call `rawFulfillRandomWords` synchronously inside `requestRandomWordsInNative`, `_requestInFlight` is `true` (`Raffle.sol:254`), so `fulfillRandomWords` emits `VrfCallbackIgnored` and returns early (`Raffle.sol:511`). Guard holds.

---

### Last User Out Tests (`[LastOut: ...]`)

`[LastOut: NftWon]`
Suppose `totalEntries` entries are sold (`unsettledPot = totalEntries * 1,000,000`). In `_settleWinningTicket`, `protocolFee = Math.mulDiv(grossPot, 500, 10_000) = totalEntries * 50,000` and `sponsorAmount = grossPot - protocolFee = totalEntries * 950,000`. `winnerProceeds = 0`.
- `redeemWinningTicket(winningTicketId)` transfers the escrowed ERC-721 prize NFT to `ownerOf(winningTicketId)`.
- `releaseSponsorProceeds()` transfers `totalEntries * 950,000` USDC to `sponsorRecipient`.
- `releaseProtocolFees()` transfers `totalEntries * 50,000` USDC to `protocolTreasury`.
Total USDC paid out: `totalEntries * (950,000 + 50,000) = totalEntries * 1,000,000 == grossPot`. The last claimant is paid in full with 0 shortfall (unless `sponsorRecipient` was set to a precomputed future `Raffle` clone address, which reverts `_transferQuote`).

`[LastOut: CashWon]`
Suppose `totalEntries` entries are sold (`unsettledPot = totalEntries * 1,000,000`). In `_settleWinningTicket`, `protocolFee = Math.mulDiv(grossPot, 500, 10_000) = totalEntries * 50,000`, `cashAmount = Math.mulDiv(grossPot, 8000, 10_000) = totalEntries * 800,000`, and `sponsorAmount = grossPot - protocolFee - cashAmount = totalEntries * 150,000`.
- `redeemWinningTicket(winningTicketId)` transfers `totalEntries * 800,000` USDC to `ownerOf(winningTicketId)`.
- `releaseSponsorProceeds()` transfers `totalEntries * 150,000` USDC to `sponsorRecipient`.
- `releaseProtocolFees()` transfers `totalEntries * 50,000` USDC to `protocolTreasury`.
- `releaseSponsorPrize()` returns the escrowed ERC-721 prize NFT to `sponsorRecipient`.
Total USDC paid out: `totalEntries * (800,000 + 150,000 + 50,000) = totalEntries * 1,000,000 == grossPot`. Because `ENTRY_PRICE = 1,000,000` is an exact multiple of `BPS = 10,000`, there is zero rounding dust and the last claimant is paid in full (unless the winning ticket or `sponsorRecipient` is a precomputed future `Raffle` clone address).

`[LastOut: Refunding]`
Suppose `ticketCount` tickets are minted, partitioning `[1, totalEntries]`, with `unsettledPot = totalEntries * 1,000,000`. `enableRefunds()` sets `remainingRefundLiability = totalEntries * 1,000,000` and `unsettledPot = 0`.
As each ticket holder calls `refundTickets` in any order, burning ticket `i` refunds `(lastEntry_i - firstEntry_i + 1) * 1,000,000` and decrements `remainingRefundLiability` by that exact amount. Because the ranges `[firstEntry_i, lastEntry_i]` form a contiguous disjoint partition of `[1, totalEntries]`, the sum of `(lastEntry_i - firstEntry_i + 1)` across all `i in 1..ticketCount` equals `totalEntries`. The last user out receives their full `entryCount * 1,000,000` USDC refund and reduces `remainingRefundLiability` to `0` with 0 shortfall (unless a ticket was minted/transferred to a precomputed future `Raffle` clone address, which can never call `refundTickets`).

---

## Findings & Leads

FINDING | contract: Raffle | function: enableRefunds | bug_class: frontrunning-griefing | group_key: Raffle | enableRefunds | frontrunning-griefing
root_cause: In Raffle.sol:280, the sponsor's pre-endTime cancellation path in enableRefunds() checks `if (totalEntries == 0)` without any mechanism for the sponsor to pause sales or cancel once a single entry is purchased, allowing anyone to front-run the sponsor's `enableRefunds()` call with a 1-entry `buyEntries()` call.
internal_pre: A raffle is in `Status.Active` with `totalEntries == 0` and `block.timestamp < endTime`.
external_pre: None
path:
  1. Sponsor creates a raffle via `RaffleFactory::createRaffle` with a prize NFT (e.g. worth 10,000 USDC), `reserveEntries = 10_000`, and `endTime = block.timestamp + 30 days` (or `reserveEntries = 1` for a promotional raffle).
  2. Before `endTime` while `totalEntries == 0`, the sponsor submits `Raffle::enableRefunds()` to cancel the empty raffle and recover the prize NFT via `releaseSponsorPrize()`.
  3. Attacker observes `enableRefunds()` in the mempool and front-runs it with `Raffle::buyEntries(attacker, 1)`, paying `1,000,000` raw USDC units (1 USDC).
  4. `totalEntries` increments from `0` to `1` (`Raffle.sol:230`).
  5. The sponsor's `enableRefunds()` transaction executes next in the same block, fails `if (totalEntries == 0)` at `Raffle.sol:280`, enters the `else` branch at `Raffle.sol:285`, and reverts with `RefundsNotAvailable(drawRequestDeadline(), block.timestamp)`.
  6. If `reserveEntries == 1`, the attacker calls `requestDraw()` at `endTime` and wins the sponsor's prize NFT (`Status.NftWon`) for 1 USDC. If `reserveEntries > 1`, the sponsor's prize NFT is locked until at least `endTime` (up to 30 days) or `endTime + 2 days` (32 days); if `requestDraw()` is not called, at `endTime + 2 days` the attacker calls `enableRefunds()` and `refundTickets([1])` to recover 100% of their 1 USDC (0 USDC principal cost), or if the sponsor pays the VRF fee to call `requestDraw()` at `endTime`, the attacker is the sole ticket holder and wins 80% of their 1 USDC back (`0.80 USDC`), costing the attacker at most `0.20 USDC`.
impact: The sponsor loses their empty-raffle cancellation right and has their escrowed prize NFT locked for up to 32 days (and is forced to either wait until `endTime + 2 days` or pay the Chainlink VRF fee at `endTime`) at 0 to 0.20 USDC cost to the attacker; if `reserveEntries == 1`, the sponsor loses the prize NFT outright for 1 USDC.
mitigation: Add a `cancelRaffle()` function (or allow `msg.sender == sponsor` in `enableRefunds()` before `endTime`) that transitions the raffle to `Status.Refunding` before `endTime` even if front-run, or enforce a short cancellation cooldown / commit step during which `buyEntries()` is disabled.

FINDING | contract: Raffle | function: buyEntries | bug_class: discrete-jump-arbitrage | group_key: Raffle | buyEntries | discrete-jump-arbitrage
root_cause: In Raffle.sol:209 and Raffle.sol:521, `buyEntries()` allows any address (including `sponsor`, `sponsorRecipient`, or a sponsor sybil) to purchase entries right before `endTime`, while `fulfillRandomWords()` discontinuously jumps the sponsor's cash allocation from 15% of `unsettledPot` (`Status.CashWon`, `totalEntries < reserveEntries`) to 95% of `unsettledPot` (`Status.NftWon`, `totalEntries >= reserveEntries`).
internal_pre: A raffle is in `Status.Active` near `endTime` with `0 < totalEntries < reserveEntries`, where the 80% pot jump on existing user entries exceeds `0.05 * (reserveEntries - totalEntries) * ENTRY_PRICE` plus the sponsor's expected cost of losing the NFT `(totalEntries / reserveEntries) * prizeValue`.
external_pre: None
path:
  1. Sponsor creates a raffle with `reserveEntries = 100` (`100,000,000` raw USDC) escrowing an NFT worth `10,000,000` USDC (10 USDC).
  2. Honest buyers purchase `totalEntries = 80` entries (`80,000,000` USDC in `unsettledPot`). If the sale ends at 80 entries (`Status.CashWon`), the winning user receives `64,000,000` USDC (80%), `protocolTreasury` receives `4,000,000` USDC (5%), and the sponsor receives `12,000,000` USDC (15%) plus the 10 USDC NFT (`22,000,000` USDC total value).
  3. Right before `endTime` (`block.timestamp = endTime - 1`), the sponsor front-runs the sale end by calling `Raffle::buyEntries(sponsor, 20)`, paying `20,000,000` USDC (20 USDC) so `totalEntries` reaches `100 == reserveEntries`.
  4. At `endTime`, `requestDraw()` is called and VRF fulfills `fulfillRandomWords()`, setting `status = Status.NftWon` (`Raffle.sol:521`).
  5. In `_settleWinningTicket()` (`Raffle.sol:543`), `sponsorProceeds` is set to `95,000,000` USDC (95% of the 100 USDC pot). The sponsor claims `95,000,000` USDC via `releaseSponsorProceeds()` (netting `75,000,000` USDC in cash after subtracting their `20,000,000` USDC entry cost, plus a 20/100 = 20% chance of winning their own 10 USDC NFT back).
impact: Existing ticket buyers lose their `64,000,000` USDC `CashWon` payout (receiving an NFT worth `10,000,000` USDC instead, with only an 80% chance of winning it), while the sponsor extracts `53,000,000` USDC of net guaranteed value (`55,000,000` USDC in expected value) from the buyers' deposits by crossing the `reserveEntries` threshold at the last second.
mitigation: Either replace the discontinuous 15%-to-95% cliff at `reserveEntries` with a continuous payout curve or allow ticket holders to opt into a refund if `reserveEntries` is only met in the final window before `endTime`.

FINDING | contract: Raffle | function: requestDraw | bug_class: single-entrant-extraction | group_key: Raffle | requestDraw | single-entrant-extraction
root_cause: In Raffle.sol:243, `requestDraw()` checks only `if (totalEntries == 0) revert NoEntriesSold()` rather than requiring `ticketCount > 1` (or `totalEntries >= reserveEntries`), allowing the sponsor to trigger a VRF draw when only a single buyer entered and missed the reserve.
internal_pre: A raffle reaches `block.timestamp >= endTime` with `ticketCount == 1` (or a single buyer owning all `totalEntries`) and `0 < totalEntries < reserveEntries`.
external_pre: None
path:
  1. Sponsor creates a raffle with `reserveEntries = 1000`.
  2. A single buyer (Alice) calls `Raffle::buyEntries(alice, 100)`, paying `100,000,000` USDC (100 USDC) for `ticketId = 1` (`firstEntry = 1, lastEntry = 100`).
  3. No other user buys entries before `endTime`, so `totalEntries = 100 < reserveEntries` and Alice is the only participant in the raffle.
  4. At `block.timestamp == endTime`, instead of letting the raffle expire into `Status.Refunding` (where Alice would recover 100% of her 100 USDC), the sponsor calls `Raffle::requestDraw()` (`Raffle.sol:240`).
  5. Chainlink VRF fulfills `fulfillRandomWords()`, setting `status = Status.CashWon` (`Raffle.sol:521`).
  6. Upon settlement and redemption (`_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseSponsorPrize`, `releaseProtocolFees`), Alice receives only `80,000,000` USDC (80% of her own deposit), while the sponsor receives `15,000,000` USDC (15% of Alice's deposit) plus recovers the prize NFT, and `protocolTreasury` receives `5,000,000` USDC (5%).
impact: A sole participant in an under-subscribed raffle (`ticketCount == 1`, `totalEntries < reserveEntries`) loses 20% of their principal (`15%` to `sponsorRecipient` and `5%` to `protocolTreasury`) despite no other participants entering the raffle and the NFT prize not being at stake.
mitigation: In `Raffle.sol:243` (`requestDraw`) and `Raffle.sol:280` (`enableRefunds`), treat a raffle with `ticketCount < 2` and `totalEntries < reserveEntries` as eligible only for `enableRefunds()` at `endTime` rather than `requestDraw()`.

FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-bypass
root_cause: In Raffle.sol:602-604 (`_isProtocolDestination`) and RaffleFactory.sol:159,166 (`_validateCreateParams`), clone screening relies on `destination.code.length != 0` and `isRaffle[destination]` while `RaffleFactory::createRaffle` (`RaffleFactory.sol:106`) deploys clones via `Clones.clone` (`CREATE` with sequential factory nonce), and `Raffle::releaseSponsorPrize` (`Raffle.sol:404`) omits `_isProtocolDestination` entirely.
internal_pre: None
external_pre: None
path:
  1. When `RaffleFactory::raffleCount()` is `k` (factory nonce `k + 1`), an actor computes the deterministic `CREATE` address of the next raffle clone `futureRaffle = computeCreateAddress(address(factory), k + 2)`. At this moment, `futureRaffle.code.length == 0` and `factory.isRaffle(futureRaffle) == false`.
  2. Raffle `k + 1` is created with `sponsorRecipient = futureRaffle` (passing `RaffleFactory.sol:166` and `Raffle.sol:193`), or a user calls `buyEntries(futureRaffle, 10)` / `transferFrom(user, futureRaffle, ticketId)` in an existing Raffle `k` (passing `Raffle.sol:498` and `_safeMint` because `futureRaffle.code.length == 0`).
  3. The next raffle clone is deployed at `futureRaffle` via `RaffleFactory::createRaffle`, setting `futureRaffle.code.length = 45` and `factory.isRaffle(futureRaffle) = true`.
  4. When Raffle `k + 1` ends in `CashWon` or `Refunding`, calling `releaseSponsorPrize()` (`Raffle.sol:404`) transfers Raffle `k + 1`'s prize NFT directly into `futureRaffle` via `prizeToken.transferFrom` (because `releaseSponsorPrize` does not check `_isProtocolDestination`), violating the spec invariant "Never move assets between raffle clones" (`DESIGN.md:5`) and permanently locking the prize NFT inside `futureRaffle`.
  5. When Raffle `k + 1` settles in `NftWon` or `CashWon`, calling `releaseSponsorProceeds()` (`Raffle.sol:380`) invokes `_transferQuote(futureRaffle, amount)` (`Raffle.sol:565`), which now sees `isRaffle[futureRaffle] == true` and permanently reverts with `InvalidQuoteDestination(futureRaffle)`, freezing `sponsorProceeds` forever. Likewise, any ticket owned by `futureRaffle` can never call `refundTickets` or `redeemWinningTicket`, permanently locking its USDC liability or won prize in Raffle `k`.
impact: Prize NFTs are transferred between raffle clones and permanently locked inside the recipient clone, and USDC liabilities (`sponsorProceeds`, `remainingRefundLiability`, `winnerProceeds`) are permanently frozen in the source raffle clone.
mitigation: Add `if (_isProtocolDestination(recipient, address(prizeToken))) revert InvalidQuoteDestination(recipient);` in `Raffle::releaseSponsorPrize()` (`Raffle.sol:403`), or deploy clones via `Clones.cloneDeterministic` with a salt committed to `msg.sender` and `params` so future clone addresses cannot be targeted before creation.

FINDING | contract: Raffle | function: _update | bug_class: mempool-frontrunning | group_key: Raffle | _update | mempool-frontrunning
root_cause: In Raffle.sol:497-502, `_update()` permits ERC-721 ticket transfers while `status == Status.Drawing` and permits transfers of losing tickets after `status == Status.NftWon` or `Status.CashWon`, allowing MEV bots to front-run the public `rawFulfillRandomWords` callback transaction against secondary ticket listings or bids.
internal_pre: A raffle is in `Status.Drawing` (or resolved to `NftWon`/`CashWon`) while a ticket holder has an active ERC-721 sale listing or a buyer has an active collection/ticket bid on a secondary marketplace.
external_pre: The Chainlink VRF node broadcasts `rawFulfillRandomWords(requestId, randomWords)` to the public mempool.
path:
  1. A raffle with `totalEntries = 100` enters `Status.Drawing` via `requestDraw()`. Ticket #5 (covering entries `[41, 50]`) is listed for sale on an NFT marketplace for 15 USDC (or a buyer has an open collection bid for `Raffle` tickets at 5 USDC).
  2. The Chainlink VRF wrapper transaction calling `rawFulfillRandomWords(requestId, randomWords)` appears in the public mempool.
  3. An MEV bot reads `randomWords[0]` from the pending transaction, computes `winningEntry = uint128((randomWords[0] % 100) + 1)` (`Raffle.sol:518`), and sees that `winningEntry = 45` (which belongs to Ticket #5).
  4. The MEV bot front-runs `rawFulfillRandomWords` to buy Ticket #5 for 15 USDC (calling `Raffle::transferFrom`, which succeeds because `_update` at `Raffle.sol:497` does not block transfers during `Status.Drawing`), or if its own ticket does not contain `winningEntry = 45`, dumps its losing ticket into the open 5 USDC collection bid before (or even after) `rawFulfillRandomWords` executes.
  5. `rawFulfillRandomWords` executes in the same block, resolving the raffle to `Status.NftWon`, and the MEV bot immediately calls `redeemWinningTicket(5)` to claim the prize NFT.
impact: Secondary ticket sellers with active listings during `Status.Drawing` have their winning tickets sniped with 100% certainty before VRF resolution lands on-chain, and secondary buyers with collection bids can have guaranteed-losing tickets dumped on them during `Status.Drawing` or after resolution (`NftWon`/`CashWon`).
mitigation: In `Raffle::_update` (`Raffle.sol:497`), revert on non-mint/non-burn transfers (`from != address(0) && to != address(0)`) when `status == Status.Drawing`, and when `status == Status.NftWon || status == Status.CashWon` revert unless `winningEntry >= _ticketRanges[ticketId].firstEntry && winningEntry <= _ticketRanges[ticketId].lastEntry`.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: event-ordering-reentrancy | group_key: RaffleFactory | createRaffle | event-ordering-reentrancy
smell: In RaffleFactory.sol:128, `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` is called on the untrusted `prizeToken` before `emit RaffleCreated(...)` at RaffleFactory.sol:136, while `Raffle`'s reentrancy guard is not entered during `onERC721Received` (`Raffle.sol:416`).
unverified: Whether off-chain indexers in this deployment drop `TicketPurchased` events emitted for a `raffle` address before its corresponding `RaffleCreated` event is emitted in the same transaction.
description: Because `Raffle::onERC721Received` sets `status = Status.Active` inside `prize.safeTransferFrom` before `RaffleFactory::createRaffle` emits `RaffleCreated`, an ERC-721 `prizeToken` with a transfer hook (or a custom prize contract) can call `raffle.buyEntries()` during `safeTransferFrom`, causing `PrizeDeposited` and `TicketPurchased` to be emitted before `RaffleCreated`.

