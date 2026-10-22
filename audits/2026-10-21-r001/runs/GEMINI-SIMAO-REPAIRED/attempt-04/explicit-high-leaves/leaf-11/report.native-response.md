### Phase 0 & Phase 1 — Protocol Vocabulary & Money Map Walkthrough (Lens 11: Edge & Terminal States)

#### Lifecycle 1: Creation & Escrow (`RaffleFactory::createRaffle` → `Raffle::initialize` → `Raffle::onERC721Received`)

[Model: RaffleFactory::createRaffle]
A sponsor supplies an NFT they own (`prizeToken`, `prizeTokenId`), a payout address (`sponsorRecipient`), a minimum entry threshold (`reserveEntries`), and a sale end timestamp (`endTime`). The factory increments its lifetime raffle counter (`raffleCount`), deploys a new clone (`raffle`), initializes its configuration in `AwaitingPrize` status, records the clone in the factory registries (`raffleById`, `idByRaffle`, `isRaffle`), pulls the NFT from the sponsor into the clone, and verifies that the clone now owns the NFT and has transitioned to `Active`.

[Why: RaffleFactory.sol:758]
Why does `RaffleFactory::createRaffle` set `isRaffle[raffle] = true` only after `IRaffle(raffle).initialize(...)` has already run at line 742, given that `initialize` calls `_isProtocolDestination` which queries `canonicalFactory.isRaffle(destination)`?
Because inside `Raffle::initialize`, `address(this)` is already `raffle`, and `_isProtocolDestination` checks `destination == address(this)` before querying `canonicalFactory.isRaffle(destination)`. However, the code rests on the implicit belief that no *earlier* raffle could have already accepted `raffle`'s address before `isRaffle[raffle]` became `true`.

[Defeat: RaffleFactory::_validateCreateParams]
1. Attacker `0xA11ce` calls `createRaffle` with `reserveEntries = 0`, attempting to create a raffle where `totalEntries >= reserveEntries` holds even with 0 entries sold; defeated by `if (params.reserveEntries == 0) revert ZeroReserveEntries()` at `RaffleFactory.sol:811`.
2. Attacker `0xA11ce` calls `createRaffle` at `block.timestamp = 1_700_000_000` with `endTime = 1_700_000_000` (zero duration) or `endTime = 1_700_000_000 + 30 days + 1` (exceeding max duration); defeated by `params.endTime <= currentTime` (`RaffleFactory.sol:733`) and `saleDuration > RaffleConstants.MAX_SALE_DURATION` (`RaffleFactory.sol:735`).
3. Attacker `0xA11ce` deploys a custom `prizeToken` `0xBad721` whose `safeTransferFrom` returns without calling `onERC721Received` or without transferring ownership of `prizeTokenId = 1` to `raffle`; defeated by `prize.ownerOf(params.prizeTokenId) != raffle` (`RaffleFactory.sol:762`) and `IRaffle(raffle).status() != IRaffle.Status.Active` (`RaffleFactory.sol:765`).

[Model: Raffle::initialize]
The factory configures a freshly deployed clone once with `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime`, locking `initialized = true` and setting `status = Status.AwaitingPrize`. No tokens move and all monetary totals remain zero.

[Model: Raffle::onERC721Received]
When `prizeToken` delivers `prizeTokenId` from `sponsor` with `factory` as operator while the raffle is in `Status.AwaitingPrize`, the raffle accepts the NFT and transitions `status` from `Status.AwaitingPrize` to `Status.Active`.

[Defeat: Raffle::onERC721Received]
1. Attacker `0xA11ce` calls `raffle.onERC721Received(factory, sponsor, prizeTokenId, "")` directly before or during escrow; defeated by `msg.sender != address(prizeToken)` at `Raffle.sol:435`.
2. Sponsor `0x5p0n50r` calls `prizeToken.safeTransferFrom(sponsor, raffle, prizeTokenId)` directly without going through `factory`; defeated by `operator != factory` at `Raffle.sol:436`.
3. Attacker `0xA11ce` calls `prizeToken.safeTransferFrom(0xA11ce, raffle, otherTokenId)` after the raffle is `Active`; defeated by `status != Status.AwaitingPrize` at `Raffle.sol:435`.

[LastOut: Creation & Escrow]
No quote tokens have entered the raffle yet (`unsettledPot == 0`). If the raffle is immediately cancelled via `enableRefunds()` with `totalEntries == 0`, the sole depositor (`sponsor`) recovers `prizeTokenId` via `releaseSponsorPrize()`, leaving zero residual liabilities and zero trapped assets (provided `sponsorRecipient` is not a precomputed future clone address).

---

#### Lifecycle 2: Entry Purchase (`Raffle::buyEntries` & `Raffle::_update`)

[Model: Raffle::buyEntries]
A buyer pays `entryCount * 1,000,000` units of USDC to the raffle while `status == Status.Active` and `block.timestamp < endTime`. The raffle advances `totalEntries` by `entryCount`, increments `ticketCount` by 1, records the inclusive range `[firstEntry, lastEntry]` for the new `ticketId`, adds the USDC paid to `unsettledPot`, and mints the ERC-721 ticket `ticketId` to `recipient`.

[Why: Raffle.sol:232]
Why does `buyEntries` bound `entryCount` by `type(uint128).max - totalEntries` while computing `grossAmount = uint256(entryCount) * ENTRY_PRICE` in `uint256`?
Because `TicketRange.firstEntry`, `TicketRange.lastEntry`, `totalEntries`, and `winningEntry` are packed as `uint128`, whereas `uint256(type(uint128).max) * 1_000_000` ($\approx 3.4 \times 10^{44}$) fits within `uint256` without overflow.

[Defeat: Raffle::buyEntries]
1. Attacker `0xA11ce` calls `buyEntries(0xA11ce, 0)` to mint a free ticket with range `[totalEntries + 1, totalEntries]`; defeated by `if (entryCount == 0) revert ZeroEntryCount()` at `Raffle.sol:231`.
2. Attacker `0xA11ce` calls `buyEntries(0xA11ce, 1)` at `block.timestamp == endTime`; defeated by `if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp)` at `Raffle.sol:229`.
3. Attacker contract `0xA11ce` re-enters `buyEntries` or `enableRefunds` from `onERC721Received` during `_safeMint(recipient, ticketId)` at `Raffle.sol:248`; defeated by `nonReentrant` on all state-changing raffle functions and because `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are all updated before `_safeMint`.

[Model: Raffle::_update]
Transfers, mints, or burns `ticketId` by updating ERC-721 ownership and balance records after verifying that any non-zero recipient `to` is not a known protocol sink (`_isProtocolDestination`). No USDC totals or ticket ranges change.

[LastOut: Entry Purchase]
After $k$ purchases totaling `totalEntries` entries, `unsettledPot == uint256(totalEntries) * 1_000_000`, `quoteToken.balanceOf(address(this)) >= unsettledPot`, and tickets $1 \dots k$ partition $[1, \text{totalEntries}]$ with no overlaps or gaps.

---

#### Lifecycle 3: Draw & Resolution (`Raffle::requestDraw` → `Raffle::fulfillRandomWords`)

[Model: Raffle::requestDraw]
Any caller after `endTime` and before `endTime + 2 days` (when `totalEntries > 0` and `status == Status.Active`) sends native ETH to pay the Chainlink VRF wrapper fee. The raffle transitions `status` to `Status.Drawing`, records `drawRequestedAt = uint64(block.timestamp)`, sets `_requestInFlight = true`, pays the wrapper `paidPrice` in native ETH for 1 random word, records `vrfRequestId`, clears `_requestInFlight = false`, and refunds any excess native ETH (`msg.value - paidPrice`) to `msg.sender`.

[Why: Raffle.sol:267]
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and reset it to `false` after writing `vrfRequestId = requestId`?
Because `vrfRequestId` is still `0` during the external call `requestRandomnessPayInNative`; if a wrapper implementation invoked `rawFulfillRandomWords(0, ...)` synchronously before `requestRandomnessPayInNative` returned, `requestId == vrfRequestId` (`0 == 0`) would otherwise pass and resolve the raffle before `vrfRequestId` was stored.

[Defeat: Raffle::requestDraw]
1. Attacker `0xA11ce` calls `requestDraw()` when `totalEntries == 0` so `fulfillRandomWords` will divide by zero on `randomWords[0] % uint256(totalEntries)`; defeated by `if (totalEntries == 0) revert NoEntriesSold()` at `Raffle.sol:256`.
2. Attacker `0xA11ce` calls `requestDraw()` at `block.timestamp == endTime + 2 days` (exact deadline boundary); defeated by `if (block.timestamp >= requestDeadline) revert DrawRequestWindowExpired(...)` at `Raffle.sol:258`.
3. Malicious contract `0xA11ce` calls `requestDraw()` with `msg.value = quotedFee + 1 wei` and attempts to re-enter `requestDraw()` or `enableRefunds()` from its `receive()` fallback when refunded `1 wei` at `Raffle.sol:280`, or returns a 10 MB payload to cause out-of-gas; defeated by `nonReentrant` and assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` with zero output copy length.

[Model: Raffle::fulfillRandomWords]
When the Chainlink VRF wrapper delivers 1 random word for `vrfRequestId` while `status == Status.Drawing`, `_requestInFlight == false`, and `block.timestamp < drawRequestedAt + 2 days`, the raffle computes `winningEntry` in `[1, totalEntries]`, records `resolvedAt = uint64(block.timestamp)`, and sets `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`. Otherwise the callback is ignored without reverting.

[Defeat: Raffle::fulfillRandomWords]
1. Attacker `0xA11ce` calls `rawFulfillRandomWords(vrfRequestId, [0])` directly to choose the winner; defeated by `if (msg.sender != vrfWrapperAddr) revert OnlyVRFWrapperCanFulfill(...)` in `VRFV2PlusWrapperConsumerBase.sol:103`.
2. A late VRF fulfillment arrives at `block.timestamp == callbackDeadline()` right before or after `enableRefunds()`; defeated by `block.timestamp >= callbackDeadline()` and `status != Status.Drawing` at `Raffle.sol:524-525`, which emit `VrfCallbackIgnored` and return without reverting.
3. `totalEntries == 1` (sole entry) or `randomWords[0] == type(uint256).max`; `randomWords[0] % 1 + 1 == 1`, and for any `totalEntries >= 1`, `(randomWords[0] % uint256(totalEntries)) + 1` stays within `[1, totalEntries]` without `uint128` overflow because `totalEntries <= type(uint128).max`.

[LastOut: Draw & Resolution]
No assets leave during `requestDraw` or `fulfillRandomWords` except the caller's own native ETH (`paidPrice` to `i_vrfV2PlusWrapper` and `excess` back to `msg.sender`). `unsettledPot` remains equal to `totalEntries * 1_000_000`.

---

#### Lifecycle 4: Settlement & Claims (`settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`)

[Model: Raffle::_settleWinningTicket]
Any caller supplies `ticketId` after the raffle is in `Status.NftWon` or `Status.CashWon`. The raffle verifies that `winningEntry` lies within `ticketId`'s stored `[firstEntry, lastEntry]` range, marks `settlementComplete = true`, records `winningTicketId = ticketId`, moves `unsettledPot` to `0`, allocates 5% (`Math.mulDiv(grossPot, 500, 10_000)`) to `protocolFees`, and in `Status.NftWon` allocates the remaining 95% to `sponsorProceeds`, or in `Status.CashWon` allocates 80% (`Math.mulDiv(grossPot, 8000, 10_000)`) to `winnerProceeds` and the remaining 15% (`grossPot - protocolFee - cashAmount`) to `sponsorProceeds`.

[Why: Raffle.sol:353]
Why does `redeemWinningTicket` check `if (cashAmount == 0) revert NoWinnerProceeds()` in the `Status.CashWon` branch when `_settleWinningTicket` sets `winnerProceeds = cashAmount`?
It acts as a defense-in-depth guard against zero-value payouts; because `requestDraw` requires `totalEntries >= 1` and `ENTRY_PRICE == 1_000_000`, `grossPot >= 1_000_000`, so in `Status.CashWon`, `cashAmount = (totalEntries * 1_000_000 * 8000) / 10_000 = totalEntries * 800_000 >= 800_000 > 0` always holds.

[Defeat: Raffle::_settleWinningTicket]
1. Attacker `0xA11ce` calls `settleWinningTicket(0)` or `settleWinningTicket(999)` (unminted ticket ID with range `[0, 0]`); since `winningEntry >= 1`, `selectedEntry > lastEntry` (`1 > 0`) triggers `TicketDoesNotContainWinningEntry` at `Raffle.sol:596`.
2. Attacker `0xA11ce` calls `settleWinningTicket(losingTicketId)` to record their own ticket as `winningTicketId`; defeated because `[firstEntry, lastEntry]` intervals are disjoint and only the unique ticket covering `winningEntry` passes `_requireWinningTicket` at `Raffle.sol:551`.
3. Attacker `0xA11ce` calls `settleWinningTicket(winningTicketId)` before the winning ticket owner calls `redeemWinningTicket(winningTicketId)` to front-run redemption; `redeemWinningTicket` checks `if (!settlementComplete)` (`Raffle.sol:327`) and proceeds directly to verify `ticketId == winningTicketId` and `msg.sender == ownerOf(ticketId)`, so front-running `settleWinningTicket` does not block `redeemWinningTicket`.

[Model: Raffle::redeemWinningTicket]
The current owner of `winningTicketId` calls `redeemWinningTicket(ticketId)` in `Status.NftWon` or `Status.CashWon` (settling first if not yet settled). The raffle records `winnerRecipient = winner`, marks `winnerRedeemed = true`, burns `ticketId`, and either transfers `prizeTokenId` to `winner` (marking `prizeClaimed = true` and verifying `prizeToken.ownerOf(prizeTokenId) == winner`) in `Status.NftWon`, or zeroes `winnerProceeds` and transfers `cashAmount` USDC to `winner` in `Status.CashWon`.

[Model: Raffle::releaseSponsorProceeds]
Any caller triggers a full payout of `sponsorProceeds` USDC to `sponsorRecipient`, zeroing `sponsorProceeds`.

[Model: Raffle::releaseProtocolFees]
Any caller triggers a full payout of `protocolFees` USDC to `protocolTreasury`, zeroing `protocolFees`.

[Model: Raffle::releaseSponsorPrize]
In `Status.CashWon` or `Status.Refunding`, any caller triggers delivery of the escrowed NFT (`prizeTokenId`) back to `sponsorRecipient`, setting `prizeClaimed = true` and verifying `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

[LastOut: Settlement & Claims]
For any `totalEntries >= 1`, `grossPot = uint256(totalEntries) * 1_000_000`.
- In `Status.NftWon`: `protocolFees = totalEntries * 50_000`, `sponsorProceeds = grossPot - protocolFees = totalEntries * 950_000`, `winnerProceeds = 0`. Sum of USDC claims is `totalEntries * (50_000 + 950_000) == grossPot`.
- In `Status.CashWon`: `protocolFees = totalEntries * 50_000`, `winnerProceeds = totalEntries * 800_000`, `sponsorProceeds = grossPot - protocolFees - winnerProceeds = totalEntries * 150_000`. Sum of USDC claims is `totalEntries * (50_000 + 800_000 + 150_000) == grossPot`.
In whatever order `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, and `releaseSponsorPrize` are called, the last claimant is paid in full with zero shortfall (`accountedQuoteBalance()` reaches `0` and `quoteToken.balanceOf(address(this))` has `0` shortfall), unless a recipient address has become a registered `isRaffle` clone or been blocked by an external token contract.

---

#### Lifecycle 5: Refund Lifecycle (`enableRefunds` → `refundTickets` + `releaseSponsorPrize`)

[Model: Raffle::enableRefunds]
Transitions the raffle to `Status.Refunding`, moves `unsettledPot` into `remainingRefundLiability`, and zeroes `unsettledPot`. Allowed when:
1. `status == Status.Active` and `totalEntries == 0` (by `sponsor` before `endTime`, or by anyone at `block.timestamp >= endTime`),
2. `status == Status.Active` and `totalEntries > 0` at `block.timestamp >= endTime + 2 days`, or
3. `status == Status.Drawing` at `block.timestamp >= drawRequestedAt + 2 days`.

[Defeat: Raffle::enableRefunds]
1. Non-sponsor `0xA11ce` calls `enableRefunds()` on an empty raffle (`totalEntries == 0`) at `block.timestamp = endTime - 1`; defeated by `if (msg.sender != sponsor && block.timestamp < deadline) revert RefundsNotAvailable(...)` at `Raffle.sol:295`.
2. Sponsor `0x5p0n50r` calls `enableRefunds()` at `block.timestamp = endTime - 1` after 1 entry has been sold (`totalEntries == 1`) to rug the draw; defeated because `totalEntries != 0` enters the `else` branch requiring `block.timestamp >= drawRequestDeadline()` (`Raffle.sol:299-300`).
3. Attacker `0xA11ce` calls `enableRefunds()` a second time when already in `Status.Refunding`; defeated by `else { revert InvalidStatus(status); }` at `Raffle.sol:306`.

[Model: Raffle::refundTickets]
In `Status.Refunding`, a ticket owner passes 1 to 100 `ticketIds` they own. For each `ticketId`, the raffle verifies `msg.sender == ownerOf(ticketId)`, adds `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns `ticketId`. It then computes `amount = aggregateEntries * 1_000_000`, subtracts `amount` from `remainingRefundLiability`, and transfers `amount` USDC to `msg.sender`.

[Why: Raffle.sol:377]
Why does `refundTickets` leave `_ticketRanges[ticketId]` populated in storage when calling `_burn(ticketId)` inside the loop?
Because `_burn(ticketId)` deletes `_owners[ticketId]` in `ERC721`, so any subsequent `ownerOf(ticketId)` call (including duplicate `ticketId` entries within the same `ticketIds` batch) immediately reverts with `ERC721NonexistentToken(ticketId)`, while preserving historical ranges for off-chain indexers.

[Defeat: Raffle::refundTickets]
1. Attacker `0xA11ce` passes duplicate ticket IDs `[1, 1]` in `ticketIds` to claim twice the refund for ticket `1`; defeated because iteration 0 calls `_burn(1)` (`Raffle.sol:377`), causing iteration 1's `ownerOf(1)` (`Raffle.sol:372`) to revert with `ERC721NonexistentToken(1)`.
2. Attacker `0xA11ce` passes `ticketIds = []` (empty array) or 101 ticket IDs; defeated by `if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) revert InvalidTicketBatchSize(...)` at `Raffle.sol:365`.
3. A user who bought 250 separate tickets (`> MAX_REFUND_TICKET_BATCH_SIZE = 100`) attempts to refund all of them; they can call `refundTickets` across 3 transactions (`100 + 100 + 50` tickets) because `refundTickets` tracks claims per burned `ticketId` rather than per address.

[LastOut: Refund Lifecycle]
When `enableRefunds()` executes, `remainingRefundLiability = unsettledPot = uint256(totalEntries) * 1_000_000`. Since the minted tickets $1 \dots \text{ticketCount}$ partition $[1, \text{totalEntries}]$, $\sum_{i=1}^{\text{ticketCount}} (\text{lastEntry}_i - \text{firstEntry}_i + 1) \times 1\_000\_000 = \text{uint256(totalEntries)} \times 1\_000\_000$. As every ticket owner calls `refundTickets` in any order, each ticket is burned once, `remainingRefundLiability` decreases to `0` on the final ticket, and the last user out is paid 100% of their entry cost with zero shortfall.

---

### Leads (Edge & Terminal State Analysis)

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: mid-flight-state-drift | group_key: Raffle | _isProtocolDestination | mid-flight-state-drift
smell: `Raffle::_isProtocolDestination` (`Raffle.sol:606-618`) and `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:790-802`) only reject addresses that are currently registered in `isRaffle` (with `destination.code.length != 0`), while `Raffle::releaseSponsorPrize` (`Raffle.sol:408-420`) omits `_isProtocolDestination` entirely before transferring the prize NFT.
unverified: How an honest sponsor, deployer, or ticket buyer would set `protocolTreasury`, `sponsorRecipient`, or a ticket `recipient` to a precomputed future `CREATE` clone address `computeCreateAddress(factory, nonce)` without intentional self-harm.
description: Because `Clones.clone` deploys sequential `CREATE` addresses whose `code.length` transitions from `0` to `45` and `isRaffle[addr]` transitions from `false` to `true` when later raffles are created, any future clone address accepted as `sponsorRecipient` or ticket `recipient` before its creation later fails `_transferQuote` in terminal states (permanently locking `sponsorProceeds`, `winnerProceeds`, or `remainingRefundLiability`), while `releaseSponsorPrize` transfers the prize NFT into that clone via `transferFrom`, violating the design rule never to move assets between raffle clones.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: threshold-boundary-cliff | group_key: Raffle | fulfillRandomWords | threshold-boundary-cliff
smell: At `Raffle.sol:534` (`status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon`) and `Raffle.sol:556-562`, crossing the single-entry threshold from `reserveEntries - 1` to `reserveEntries` discontinuously shifts 80% of the entire prior quote-token pot from the winning ticket holder (`CashWon`: 80% winner / 15% sponsor) to the sponsor (`NftWon`: 95% sponsor / 0% cash to winner).
unverified: Whether an external market condition where the escrowed NFT's fair value is strictly less than 80% of the reserve pot is considered an actionable exploit rather than an inherent game-theoretic property of the fixed-split specification.
description: When organic ticket sales stall below `reserveEntries` and the NFT is worth less than the 80% cash payout, the sponsor can buy the remaining `reserveEntries - totalEntries` entries right before `endTime` to force `Status.NftWon`, reclaiming 95% of their own top-up entries plus an extra 80% of all prior organic buyers' entries while retaining a `(reserveEntries - organicEntries) / reserveEntries` probability of winning their own NFT back.
```

```
LEAD | contract: RaffleFactory | function: _validateCreateParams | bug_class: unbounded-threshold-parameter | group_key: RaffleFactory | _validateCreateParams | unbounded-threshold-parameter
smell: `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:811`) rejects `params.reserveEntries == 0` and bounds `saleDuration <= 30 days`, but places no upper bound on `params.reserveEntries` (allowing values up to `type(uint128).max`, or $3.4 \times 10^{38}$ USDC).
unverified: Whether any user or integration would purchase entries in a raffle without inspecting the on-chain `reserveEntries` value.
description: Setting `reserveEntries` above the circulating supply of USDC (up to `type(uint128).max`) makes the `Status.NftWon` terminal state mathematically unreachable in `Raffle::fulfillRandomWords` (`Raffle.sol:534`), guaranteeing that the raffle resolves to `Status.CashWon` where the sponsor always reclaims the escrowed NFT via `releaseSponsorPrize` and collects 15% of gross ticket sales.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: terminal-state-blacklisted-recipient | group_key: Raffle | releaseSponsorProceeds | terminal-state-blacklisted-recipient
smell: Unlike ticket claims (which remain transferable ERC-721 tokens in all terminal states so a blacklisted owner can transfer the ticket before calling `redeemWinningTicket` or `refundTickets`), `sponsorRecipient` and `protocolTreasury` are immutable storage values (`Raffle.sol:211-212`) with no fallback recipient parameter in `releaseSponsorProceeds` (`Raffle.sol:388`), `releaseProtocolFees` (`Raffle.sol:398`), or `releaseSponsorPrize` (`Raffle.sol:408`).
unverified: External pre-condition that canonical USDC blacklists `sponsorRecipient` or `protocolTreasury`, or that `prizeToken` blocks transfers to `sponsorRecipient`, between `createRaffle` and terminal settlement.
description: If `sponsorRecipient` or `protocolTreasury` is blacklisted by `quoteToken` (or `sponsorRecipient` is rejected by `prizeToken.transferFrom`) before claims are released, the corresponding terminal payout function permanently reverts and strands those funds or the NFT in the clone forever.
```
