# 0xSimao Audit Report — Lens 3: Temporal Cohorts & Distribution Fairness

## Phase 0–3: Protocol Model, Reasoning Protocol Markers & Lifecycle Walkthrough

### Value-Moving & Total-Writing Functions (`[Model]`, `[Why]`, `[Defeat]`)

`[Model: RaffleFactory::createRaffle]`
A sponsor gives one specific NFT prize to a newly created raffle contract and specifies who should receive the sponsor's share of entry sales (and the returned NFT if the raffle does not award the NFT), how many entries must be sold for the NFT to be awarded, and when entry sales end. In return, the factory increments the global raffle count (`raffleCount`), records the new raffle in its directory (`raffleById`, `idByRaffle`, `isRaffle`), moves the prize NFT from the sponsor into the new raffle contract, and activates the raffle (`status = Active`).

`[Why: RaffleFactory.sol:109]`
Why does `createRaffle` call `IRaffle(raffle).initialize(...)` before setting `isRaffle[raffle] = true` on line 125? Because `initialize` runs before registration, `_isProtocolDestination` inside `initialize` cannot rely on `isRaffle[raffle]` to reject the clone's own address and must explicitly check `destination == address(this)`. However, any *future* clone address (`raffleCount + 2`, etc.) is not yet in `isRaffle` and has no code yet, meaning the code implicitly assumes no caller will supply a deterministic future `CREATE` clone address as `sponsorRecipient` or `protocolTreasury`.

`[Why: RaffleFactory.sol:178]`
Why does `_validateCreateParams` only check `params.reserveEntries == 0` with no upper bound on `reserveEntries`? The code implicitly assumes a sponsor will choose a reachable reserve threshold, overlooking that setting `reserveEntries` to `type(uint128).max` makes the NFT-award outcome (`totalEntries >= reserveEntries`) mathematically unreachable and locks the raffle into the `CashWon` branch where the sponsor keeps the NFT and takes 15% of all entry sales.

`[Defeat: RaffleFactory::createRaffle]`
1. Sponsor `0x1111...1111` calls `createRaffle` with `reserveEntries = type(uint128).max` (`3.4028e38` entries) and a high-value NFT (`prizeTokenId = 1`). Because `RaffleFactory.sol:178` only checks `reserveEntries != 0`, the raffle is created as `Active` even though `totalEntries >= reserveEntries` can never be reached with the entire circulating supply of USDC, guaranteeing `Status.CashWon` where the sponsor gets their NFT back via `releaseSponsorPrize()` plus 15% of all buyers' USDC via `releaseSponsorProceeds()`.
2. Sponsor `0x1111...1111` computes the next deterministic `CREATE` address of `RaffleFactory` (`futureRaffle2 = keccak256(rlp([factory, nonce + 1]))[12:]`) and calls `createRaffle` for Raffle #1 with `sponsorRecipient = futureRaffle2`. At creation time (`t0`), `futureRaffle2.code.length == 0` and `isRaffle[futureRaffle2] == false`, passing both `_validateCreateParams` and `Raffle::initialize`. Once Raffle #2 is deployed at `futureRaffle2` (`t1`), `isRaffle[futureRaffle2]` becomes `true`, causing `_transferQuote` in `releaseSponsorProceeds()` on Raffle #1 to revert with `InvalidQuoteDestination(futureRaffle2)` while `releaseSponsorPrize()` transfers Raffle #1's NFT directly into Raffle #2 where it is permanently stuck.
3. During `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` at `RaffleFactory.sol:128`, a custom `prizeToken` invokes `raffle.onERC721Received` (setting `status = Status.Active` at `Raffle.sol:428`) and then re-enters `raffle.buyEntries(attacker, 10)` before `createRaffle` finishes, causing `TicketPurchased` to be emitted before `RaffleCreated`.

`[Model: Raffle::buyEntries]`
A buyer gives 1 USDC (`1,000,000` raw quote-token units) per requested entry to the raffle contract before `endTime`. In return, the specified recipient gets one newly minted sequential ERC-721 ticket (`ticketId = ticketCount + 1`) representing the contiguous inclusive entry range `[totalEntries + 1, totalEntries + entryCount]`. The raffle increases `totalEntries` by `entryCount`, increments `ticketCount` by 1, records `[firstEntry, lastEntry]` in `_ticketRanges[ticketId]`, and increases `unsettledPot` by `entryCount * 1,000,000`.

`[Why: Raffle.sol:209]`
Why does `buyEntries` allow `msg.sender` or `recipient` to be `sponsor` or `sponsorRecipient` right up to `endTime - 1`? The code implicitly assumes entry purchases are always beneficial to existing participants, overlooking the severe payout discontinuity at `totalEntries == reserveEntries` where flipping the outcome from `CashWon` to `NftWon` transfers 80% of the previously accumulated pot from ticket buyers to `sponsorRecipient` while returning 95% of the sponsor's own last-second purchase back to `sponsorRecipient`.

`[Defeat: Raffle::buyEntries]`
1. Early buyer Alice (`0xA11ce...`) buys 500 entries (`500e6` USDC) at `t0` in a raffle with `reserveEntries = 1,000` for an NFT worth `100e6` USDC. At `t1 = endTime - 1`, Sponsor Bob (`0xB0b...`) calls `buyEntries(0xB0b, 500)` with `500e6` USDC, pushing `totalEntries` from `500` to `1,000 == reserveEntries`. This flips the raffle from `CashWon` (where Alice was owed `400e6` USDC) to `NftWon` (where Bob claims `950e6` USDC via `releaseSponsorProceeds()`, paying only `25e6` net for his 500 entries while capturing `400e6` USDC from Alice's pot plus a 50% chance to keep his own NFT).
2. Buyer `0x2222...2222` calls `buyEntries(futureRaffle2, 1)` where `futureRaffle2` is the deterministic `CREATE` address of the next raffle clone (`futureRaffle2.code.length == 0` at `t0`). `_update` and `_safeMint` succeed because `futureRaffle2` has no code yet. After `createRaffle` deploys Raffle #2 at `futureRaffle2`, the ticket in Raffle #1 is owned by Raffle #2 (`isRaffle[futureRaffle2] == true`), which cannot call `redeemWinningTicket` or `refundTickets`.
3. When Sponsor Alice (`0xA11ce...`) broadcasts `enableRefunds()` before `endTime` to cancel an empty raffle (`totalEntries == 0`), Attacker Bob (`0xB0b...`) front-runs with `buyEntries(0xB0b, 1)` for `1e6` USDC, setting `totalEntries = 1` and causing Alice's `enableRefunds()` call to revert with `RefundsNotAvailable`, locking Alice's NFT until `endTime` (up to 30 days).

`[Model: Raffle::requestDraw]`
Any caller gives native ETH at least equal to the Chainlink VRF wrapper's current request price during `[endTime, endTime + 2 days)` when at least one entry has been sold. In return, the raffle forwards the exact required native fee to the Chainlink wrapper to request one random word, refunds any excess ETH to the caller, sets `status = Drawing`, records `drawRequestedAt = block.timestamp`, and stores `vrfRequestId`. No quote-token totals change.

`[Why: Raffle.sol:254]`
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and clear it afterwards? Because `rawFulfillRandomWords` inherited from `VRFV2PlusWrapperConsumerBase` does not have the `nonReentrant` modifier; without `_requestInFlight`, a synchronous callback from the wrapper during `requestRandomnessPayInNative` would execute before `vrfRequestId = requestId` is written on line 259.

`[Defeat: Raffle::requestDraw]`
1. In a raffle where `0 < totalEntries < reserveEntries` (e.g., `totalEntries = 10`, `unsettledPot = 10e6` USDC), calling `requestDraw()` forces `CashWon`, which takes `2e6` USDC (20%) away from ticket buyers to pay `sponsorRecipient` (`1.5e6`) and `protocolTreasury` (`0.5e6`). Rational ticket buyers refuse to call `requestDraw()` so that `enableRefunds()` at `endTime + 2 days` returns 100% (`10e6` USDC) to buyers; if the Chainlink VRF native fee exceeds `1.5e6` USDC in ETH value, even the sponsor will not call `requestDraw()`, delaying refunds by 2 days.
2. A contract caller `0x3333...3333` with a reverting `receive()` calls `requestDraw()` with `msg.value > paidPrice`, causing the assembly call on line 267 to fail and revert the entire `requestDraw()` transaction with `NativeRefundFailed`; however, this only reverts the caller's own transaction.
3. A caller invokes `requestDraw()` at `block.timestamp = endTime + 2 days - 1` when L1 basefee is at a temporary low before a 48-hour gas spike; if Chainlink nodes do not fulfill before `drawRequestedAt + 2 days`, `fulfillRandomWords` ignores late callbacks and `enableRefunds()` unlocks full refunds at `drawRequestedAt + 2 days`.

`[Model: Raffle::fulfillRandomWords]`
The Chainlink VRF wrapper gives the raffle one random number for `vrfRequestId` before `drawRequestedAt + 2 days`. In return, the raffle computes the winning entry in `[1, totalEntries]`, stores `winningEntry` and `resolvedAt`, and transitions `status` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`). No token balances or pot variables change yet.

`[Model: Raffle::enableRefunds]`
A caller triggers the refund state when an active raffle has zero entries (callable by the sponsor before `endTime` or anyone at/after `endTime`), when an active raffle with sold entries misses the 2-day draw request window (`block.timestamp >= endTime + 2 days`), or when a drawing raffle misses the 2-day VRF callback window (`block.timestamp >= drawRequestedAt + 2 days`). The raffle moves the entire `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and sets `status = Refunding`.

`[Why: Raffle.sol:280]`
Why does `enableRefunds` allow `sponsor` to cancel before `endTime` only when `totalEntries == 0`? The code assumes the sponsor shouldn't be able to rug ticket buyers after sales start, and assumes that if `totalEntries == 0` the sponsor can freely cancel — failing to account for mempool front-running where a 1-USDC `buyEntries` call transitions `totalEntries` from `0` to `1` right before the sponsor's `enableRefunds()` executes.

`[Defeat: Raffle::enableRefunds]`
1. Sponsor Alice (`0xA11ce...`) calls `enableRefunds()` at `t = 1500 < endTime` while `totalEntries == 0`. Attacker Bob (`0xB0b...`) front-runs with `buyEntries(0xB0b, 1)` (`1e6` USDC). Alice's `enableRefunds()` reverts with `RefundsNotAvailable`, locking Alice's NFT until `endTime` (or stealing it for 1 USDC if `reserveEntries == 1`).
2. After `enableRefunds()` sets `status = Status.Refunding` at `block.timestamp == callbackDeadline()`, the Chainlink VRF wrapper delivers a late `rawFulfillRandomWords` callback in the same block (`block.timestamp == callbackDeadline()`). `fulfillRandomWords` checks `status != Status.Drawing || block.timestamp >= callbackDeadline()`, emits `VrfCallbackIgnored`, and returns without reverting or overwriting `Status.Refunding`.
3. A caller attempts to call `enableRefunds()` twice to reset `remainingRefundLiability` to `unsettledPot` (`0`) after `unsettledPot` was zeroed on the first call; the second call reverts with `InvalidStatus(Status.Refunding)` at `Raffle.sol:293`.

`[Model: Raffle::_settleWinningTicket]`
Any caller provides a `ticketId` whose `[firstEntry, lastEntry]` range contains `winningEntry` when `status` is `NftWon` or `CashWon`. The raffle calculates the 5% `protocolFees` (rounded down from `unsettledPot`), calculates the 80% `winnerProceeds` if `status == CashWon` (rounded down from `unsettledPot`), assigns the remaining `unsettledPot` to `sponsorProceeds`, sets `unsettledPot = 0`, records `winningTicketId = ticketId`, and sets `settlementComplete = true`.

`[Model: Raffle::redeemWinningTicket]`
The current owner of `winningTicketId` burns their winning ticket (settling the winning ticket first if not yet settled). In return, the raffle sets `winnerRecipient = winner` and `winnerRedeemed = true`, burns `ticketId`, and either transfers the prize NFT (`prizeToken`, `prizeTokenId`) to `winner` and sets `prizeClaimed = true` (when `status == NftWon`), or zeroes `winnerProceeds` and transfers that USDC amount to `winner` (when `status == CashWon`).

`[Why: Raffle.sol:334]`
Why does `redeemWinningTicket` call `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` without checking `_isProtocolDestination(winner, address(prizeToken))`, whereas `_transferQuote` on line 565 checks `_isProtocolDestination`? Because the author assumed `_update` already prevented any protocol destination from ever becoming `ownerOf(ticketId)`, overlooking that a future `Raffle` clone address has `code.length == 0` and `isRaffle == false` when the ticket is minted/transferred at `t0`, and becomes a registered `Raffle` clone at `t1` before `redeemWinningTicket` is called at `t2`.

`[Defeat: Raffle::redeemWinningTicket]`
1. Ticket `1` is minted to `futureRaffle2` (the next `CREATE` address of `RaffleFactory`) at `t0` via `buyEntries(futureRaffle2, 100)`. At `t1`, Raffle #2 is created at `futureRaffle2`. At `t2`, Ticket `1` wins Raffle #1. Anyone can call `settleWinningTicket(1)`, allowing the sponsor and protocol to claim their USDC, but `redeemWinningTicket(1)` can only be called by `msg.sender == ownerOf(1) == futureRaffle2` (`Raffle.sol:321`), which has no function to call `redeemWinningTicket`, permanently freezing the prize NFT (in `NftWon`) or `winnerProceeds` (in `CashWon`) in Raffle #1.
2. A malicious sponsor creates a raffle with a custom ERC-721 `prizeToken` that allows `safeTransferFrom` into the raffle during `createRaffle` but reverts on `transferFrom` when `from == raffle`. Once buyers push `totalEntries >= reserveEntries` and the raffle resolves to `NftWon`, the sponsor calls `settleWinningTicket` and `releaseSponsorProceeds()` to take 95% of the buyers' USDC while `redeemWinningTicket` reverts forever on line 334.
3. A winning ticket holder whose address `0xBad...` is blacklisted by USDC in `CashWon` cannot receive USDC directly via `_transferQuote(0xBad..., cashAmount)`. However, because `_update` does not call `quoteToken`, `0xBad...` can call `transferFrom(0xBad..., 0xClean..., winningTicketId)` and redeem from `0xClean...`.

`[Model: Raffle::refundTickets]`
In `Status.Refunding`, a ticket owner passes a batch of 1 to 100 `ticketIds` they own. The raffle burns each ticket, sums the number of entries (`lastEntry - firstEntry + 1`) across all burned tickets in the batch, subtracts `aggregateEntries * 1,000,000` from `remainingRefundLiability`, and transfers `aggregateEntries * 1,000,000` USDC to `msg.sender`.

`[Model: Raffle::releaseSponsorProceeds]`
Any caller triggers the payout of `sponsorProceeds` when `sponsorProceeds > 0`. The raffle sets `sponsorProceeds = 0` and transfers that USDC amount to `sponsorRecipient`.

`[Model: Raffle::releaseProtocolFees]`
Any caller triggers the payout of `protocolFees` when `protocolFees > 0`. The raffle sets `protocolFees = 0` and transfers that USDC amount to `protocolTreasury`.

`[Model: Raffle::releaseSponsorPrize]`
In `Status.CashWon` or `Status.Refunding`, any caller triggers the return of the escrowed prize NFT when `prizeClaimed == false`. The raffle sets `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient`, and checks `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

`[Why: Raffle.sol:404]`
Why does `releaseSponsorPrize` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without checking `_isProtocolDestination(recipient, address(prizeToken))`? Because the code assumes `sponsorRecipient` was permanently validated at `initialize` (`Raffle.sol:193`), missing that `sponsorRecipient` can be set to a future `Raffle` clone address `futureRaffle2` before Raffle #2 is deployed, and then `releaseSponsorPrize()` moves the prize NFT directly into Raffle #2 (violating `"Never move assets between raffle clones"` in `DESIGN.md` and permanently locking the NFT inside Raffle #2).

---

### Closing Lifecycle Tests (`[LastOut]`)

`[LastOut: NftWon]`
Suppose 3 buyers purchase entries in Raffle #1 (`reserveEntries = 10`): Buyer 1 buys 3 entries (`3e6` USDC, Ticket 1: `[1,3]`), Buyer 2 buys 3 entries (`3e6` USDC, Ticket 2: `[4,6]`), Buyer 3 buys 4 entries (`4e6` USDC, Ticket 3: `[7,10]`). Total `unsettledPot = 10,000,000` (`10e6` USDC), `quoteToken.balanceOf(raffle) = 10,000,000`.
Draw resolves to `winningEntry = 5` (Ticket 2) and `status = Status.NftWon`.
In `_settleWinningTicket(2)`:
- `protocolFee = Math.mulDiv(10_000_000, 500, 10_000) = 500,000`.
- `sponsorAmount = 10_000_000 - 500,000 = 9,500,000`.
- `unsettledPot = 0`, `protocolFees = 500,000`, `sponsorProceeds = 9,500,000`, `winnerProceeds = 0`.
Worst-order withdrawals:
1. `releaseProtocolFees()` pays `500,000` USDC to `protocolTreasury` (`9,500,000` USDC remaining).
2. `releaseSponsorProceeds()` pays `9,500,000` USDC to `sponsorRecipient` (`0` USDC remaining).
3. Buyer 2 calls `redeemWinningTicket(2)`, burning Ticket 2 and receiving `prizeTokenId` (`prizeClaimed = true`).
Every claim is paid in full with `0` USDC shortfall and `0` dust left behind (`10,000,000` is an exact multiple of `10,000`), provided `sponsorRecipient` and `protocolTreasury` did not become protocol destinations (`futureRaffle`) after initialization.

`[LastOut: CashWon]`
Suppose 2 buyers purchase entries in Raffle #1 (`reserveEntries = 10`): Buyer 1 buys 1 entry (`1e6` USDC, Ticket 1: `[1,1]`), Buyer 2 buys 2 entries (`2e6` USDC, Ticket 2: `[2,3]`). Total `unsettledPot = 3,000,000` (`3e6` USDC), `quoteToken.balanceOf(raffle) = 3,000,000`.
Draw resolves to `winningEntry = 1` (Ticket 1) and `status = Status.CashWon`.
In `_settleWinningTicket(1)`:
- `protocolFee = Math.mulDiv(3_000,000, 500, 10_000) = 150,000`.
- `cashAmount = Math.mulDiv(3_000_000, 8000, 10_000) = 2,400,000`.
- `sponsorAmount = 3_000_000 - 150,000 - 2,400,000 = 450,000`.
- `unsettledPot = 0`, `protocolFees = 150,000`, `winnerProceeds = 2,400,000`, `sponsorProceeds = 450,000`.
Worst-order withdrawals:
1. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient` (`prizeClaimed = true`).
2. `releaseSponsorProceeds()` pays `450,000` USDC to `sponsorRecipient` (`2,550,000` USDC remaining).
3. `releaseProtocolFees()` pays `150,000` USDC to `protocolTreasury` (`2,400,000` USDC remaining).
4. Buyer 1 calls `redeemWinningTicket(1)`, burning Ticket 1 and receiving `2,400,000` USDC (`0` USDC remaining).
The last claimant out is paid in full with `0` shortfall.

`[LastOut: Refunding]`
Suppose 3 buyers purchase entries in Raffle #1: Buyer 1 buys 1 entry (`1e6` USDC, Ticket 1: `[1,1]`), Buyer 2 buys 5 entries (`5e6` USDC, Ticket 2: `[2,6]`), Buyer 3 buys 4 entries (`4e6` USDC, Ticket 3: `[7,10]`). Total `unsettledPot = 10,000,000` (`10e6` USDC).
After `drawRequestDeadline()`, `enableRefunds()` sets `unsettledPot = 0`, `remainingRefundLiability = 10,000,000`, `status = Status.Refunding`.
Worst-order withdrawals:
1. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
2. Buyer 2 calls `refundTickets([2])`, burning Ticket 2 (`6 - 2 + 1 = 5` entries), subtracting `5,000,000` from `remainingRefundLiability` (now `5,000,000`), and receiving `5,000,000` USDC.
3. Buyer 3 calls `refundTickets([3])`, burning Ticket 3 (`10 - 7 + 1 = 4` entries), subtracting `4,000,000` from `remainingRefundLiability` (now `1,000,000`), and receiving `4,000,000` USDC.
4. Buyer 1 (last user out) calls `refundTickets([1])`, burning Ticket 1 (`1 - 1 + 1 = 1` entry), subtracting `1,000,000` from `remainingRefundLiability` (now `0`), and receiving `1,000,000` USDC.
The last user out is paid in full with `0` shortfall, unless a ticket was minted/transferred at `t0` to a precomputed future `Raffle` clone address that was deployed at `t1` (in which case that ticket's refund is permanently bricked by `_isProtocolDestination` in `_transferQuote`).

---

## Findings & Leads

```
FINDING | contract: Raffle | function: buyEntries | bug_class: late-cohort-dilution | group_key: Raffle | buyEntries | late-cohort-dilution
root_cause: In Raffle.sol:209, buyEntries() does not restrict sponsor or sponsorRecipient from purchasing entries, and in Raffle.sol:521 and Raffle.sol:544, crossing reserveEntries switches the entire accumulated pot from 80% buyer / 15% sponsor (CashWon) to 0% buyer / 95% sponsor (NftWon), rebating 95% of the sponsor's last-second top-up back to sponsorRecipient.
internal_pre: An active raffle where genuine buyers have purchased E1 < reserveEntries entries and the market value of the prize NFT is less than 0.80 * E1 * ENTRY_PRICE + 0.95 * (reserveEntries - E1) * ENTRY_PRICE.
external_pre: None
path:
  1. At t0 = 1000, Sponsor Bob creates a raffle with reserveEntries = 1000 (1,000 USDC), endTime = 2000, and an NFT prize worth 100 USDC, and Alice calls buyEntries(alice, 500) paying 500,000,000 (500 USDC) for entries [1, 500].
  2. By t1 = 1999 (one second before endTime), totalEntries is 500 < 1000; under the accrued CashWon outcome, Alice holds 100% of tickets and is owed 80% of the pot = 400,000,000 (400 USDC), while Sponsor Bob is owed 15% = 75,000,000 (75 USDC) plus his 100 USDC NFT back (175 USDC total value).
  3. At t1 = 1999, Sponsor Bob calls buyEntries(bob, 500) paying 500,000,000 (500 USDC) for entries [501, 1000], increasing totalEntries to 1000 == reserveEntries and unsettledPot to 1,000,000,000 (1,000 USDC).
  4. At t2 = 2000, requestDraw() and fulfillRandomWords() resolve the raffle to Status.NftWon (totalEntries >= reserveEntries), and _settleWinningTicket() allocates 950,000,000 (950 USDC) to sponsorProceeds (Bob) and 50,000,000 (50 USDC) to protocolFees.
impact: Early ticket buyer cohort (Alice) is left holding the loss: Alice's entitlement drops from a guaranteed 400 USDC cash payout (in CashWon) to a 50% chance at a 100 USDC NFT (50 USDC expected value, a 350 USDC loss), while Sponsor Bob pays only 25 USDC in net protocol fees on his 500 USDC t1 deposit to extract an extra 375 USDC in cash from Alice's t0 deposit plus a 50% chance of winning back his own NFT.
mitigation: In Raffle.sol:209 and Raffle.sol:497 (_update), reject sponsor and sponsorRecipient in _isProtocolDestination (or track sponsor-affiliated entries separately so they do not count toward reserveEntries or generate sponsorProceeds rebates).
```

```
FINDING | contract: Raffle | function: enableRefunds | bug_class: frontrun-dos | group_key: Raffle | enableRefunds | frontrun-dos
root_cause: In Raffle.sol:280, enableRefunds() conditions the sponsor's pre-endTime cancellation right on totalEntries == 0 while Raffle.sol:209 (buyEntries) allows any caller to buy 1 entry and set totalEntries = 1 before endTime.
internal_pre: An active raffle with totalEntries == 0 and block.timestamp < endTime.
external_pre: None
path:
  1. At t0 = 1000, Sponsor Alice calls createRaffle() with endTime = 2593000 (30 days) and reserveEntries = 100 (or reserveEntries = 1), escrowing her prize NFT into the raffle clone (status = Status.Active, totalEntries = 0).
  2. At t1 = 2000, Alice broadcasts enableRefunds() to cancel the empty raffle and recover her prize NFT via releaseSponsorPrize(), and Attacker Bob front-runs Alice's transaction in the same block with buyEntries(bob, 1) paying 1,000,000 (1 USDC), setting totalEntries = 1 and unsettledPot = 1,000,000.
  3. At t1 = 2000, Alice's enableRefunds() call executes, takes the else branch at Raffle.sol:285 because totalEntries == 1, and reverts with RefundsNotAvailable(2765800, 2000).
  4. At t2 = 2593000 (30 days later), if reserveEntries == 1, Bob calls requestDraw() and wins Alice's NFT for 1 USDC; if reserveEntries > 1, Alice's NFT has been locked for 30 days and Bob recovers 800,000 (0.80 USDC) via CashWon redemption (net griefing cost of 0.20 USDC).
impact: Sponsor (Alice) is left holding the loss: her empty-raffle cancellation right is defeated for a net cost of 0.20 USDC, locking her escrowed prize NFT until endTime (up to 30 days) or forcing its sale for 1 USDC if reserveEntries == 1.
mitigation: Add a sponsor-callable cancel function or short cancellation grace period, or require a minimum entry purchase threshold / allow the sponsor to cancel before endTime by refunding existing ticket holders plus a cancellation fee.
```

```
FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: missing-upper-bound | group_key: RaffleFactory | _validateCreateParams | missing-upper-bound
root_cause: In RaffleFactory.sol:178, _validateCreateParams() checks only params.reserveEntries == 0 and enforces no upper bound on params.reserveEntries relative to realistic quoteToken supply.
internal_pre: None
external_pre: None
path:
  1. At t0 = 1000, Sponsor Bob calls createRaffle() with a prize NFT worth 50,000 USDC and sets reserveEntries = type(uint128).max (340,282,366,920,938,463,463,374,607,431,768,211,455 entries, requiring 3.4028e38 USDC), which passes RaffleFactory.sol:178 and activates the raffle.
  2. At t1 = 1500, Alice and other buyers purchase 10,000 entries for 10,000,000,000 (10,000 USDC), increasing totalEntries to 10,000 and unsettledPot to 10,000,000,000 while Status.NftWon at Raffle.sol:521 (totalEntries >= reserveEntries) is mathematically unreachable.
  3. At t2 = 2000 (endTime), Bob calls requestDraw(), VRF resolves to Status.CashWon with 100% certainty, and Bob calls settleWinningTicket(), releaseSponsorProceeds(), and releaseSponsorPrize() to reclaim his NFT and collect 1,500,000,000 (1,500 USDC = 15% of the pot) while protocolTreasury collects 500,000,000 (500 USDC).
impact: Ticket buyers (Alice's cohort) are left holding a guaranteed 2,000 USDC (20% of pot) collective loss with zero possibility of ever reaching the NftWon branch, while Sponsor Bob extracts 15% of all ticket sales risk-free without ever putting his NFT at risk.
mitigation: In RaffleFactory.sol:178, enforce a reasonable upper bound constant MAX_RESERVE_ENTRIES on params.reserveEntries (e.g., if (params.reserveEntries == 0 || params.reserveEntries > RaffleConstants.MAX_RESERVE_ENTRIES) revert).
```

```
FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: time-of-check-time-of-use-sink-bypass | group_key: Raffle | _isProtocolDestination | time-of-check-time-of-use-sink-bypass
root_cause: In Raffle.sol:602-604, _isProtocolDestination() only checks canonicalFactory.isRaffle(destination) when destination.code.length != 0, and in Raffle.sol:334 and Raffle.sol:404, prizeToken.transferFrom() does not call _isProtocolDestination() at all, allowing a deterministic future RaffleFactory CREATE clone address to pass screening at t0 before being deployed at t1.
internal_pre: None
external_pre: None
path:
  1. At t0 = 1000, when RaffleFactory.raffleCount() == 1, an actor computes the deterministic CREATE address of Raffle #2 (futureRaffle2 = computeCreateAddress(factory, 3), which currently has code.length == 0 and isRaffle[futureRaffle2] == false) and either sets sponsorRecipient = futureRaffle2 in createRaffle() for Raffle #1 or calls buyEntries(futureRaffle2, 10) on Raffle #1.
  2. At t1 = 1500, any user calls RaffleFactory::createRaffle(), which clones Raffle #2 at futureRaffle2 via Clones.clone(raffleImplementation) (RaffleFactory.sol:106) and sets isRaffle[futureRaffle2] = true (RaffleFactory.sol:125).
  3. At t2 = 2000, Raffle #1 resolves to CashWon or Refunding and settles: calling releaseSponsorProceeds() (or redeemWinningTicket() / refundTickets() for a ticket owned by futureRaffle2) reverts permanently in _transferQuote() at Raffle.sol:565 with InvalidQuoteDestination(futureRaffle2) because isRaffle[futureRaffle2] is now true, while calling releaseSponsorPrize() at Raffle.sol:404 transfers Raffle #1's prize NFT via unsafe transferFrom directly into Raffle #2 (futureRaffle2), which has no rescue function.
impact: Quote-token claims (sponsorProceeds, winnerProceeds, or remainingRefundLiability) in Raffle #1 are permanently frozen in Raffle #1 because _transferQuote reverts at t2, and Raffle #1's prize NFT is transferred directly into Raffle #2 where it is permanently frozen (violating the DESIGN.md invariant "Never move assets between raffle clones"). Additionally, if RaffleFactory is deployed with protocolTreasury_ equal to a future clone address futureRaffle_k, RaffleFactory::createRaffle() permanently reverts at Raffle.sol:190 once raffleCount reaches k.
mitigation: In Raffle.sol:334 and Raffle.sol:404, check if (_isProtocolDestination(recipient, address(prizeToken))) revert before transferring the prize NFT, or use Clones.cloneDeterministic with msg.sender-salted CREATE2 in RaffleFactory.sol:106 so uncreated clone addresses cannot be precomputed and occupied before deployment.
```

```
LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: untrusted-prize-token-revert | group_key: Raffle | redeemWinningTicket | untrusted-prize-token-revert
smell: In Raffle.sol:334 and Raffle.sol:375, _settleWinningTicket() and releaseSponsorProceeds() allow the sponsor to withdraw 95% of unsettledPot in Status.NftWon even if the untrusted prizeToken reverts or fails ownerOf verification in redeemWinningTicket().
unverified: Whether prize tokens with sponsor-controlled transfer restrictions, pause switches, or blocklists are considered in-scope under DESIGN.md ("arbitrary prize contracts and ticket recipients are untrusted") or excluded by IRaffle.sol:16 ("Supported prizes are honest, standards-compliant ERC-721s").
description: If arbitrary prize contracts are untrusted as stated in DESIGN.md, a malicious sponsor can deploy an ERC-721 that permits safeTransferFrom into the raffle clone during createRaffle() but reverts transferFrom() out of the raffle clone in redeemWinningTicket(), allowing the sponsor to collect 95% of the USDC pot in NftWon while denying the winner the NFT.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: immutable-recipient-blacklist-dos | group_key: Raffle | releaseSponsorProceeds | immutable-recipient-blacklist-dos
smell: In Raffle.sol:380 and Raffle.sol:390, sponsorRecipient and protocolTreasury are immutable per-raffle addresses with no fallback recipient if blacklisted by canonical USDC between raffle creation (t0) and payout release (t2), whereas a blacklisted ticket owner can transfer their ERC-721 ticket via _update() to an unblacklisted address before calling redeemWinningTicket() or refundTickets().
unverified: Whether canonical USDC blacklisting of sponsorRecipient or protocolTreasury mid-raffle is treated as an accepted external token risk.
description: Because _transferQuote() must transfer USDC directly to the immutable sponsorRecipient or protocolTreasury address, a USDC blacklist event between createRaffle() and settlement permanently locks sponsorProceeds or protocolFees inside the Raffle clone.
```
