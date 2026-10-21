# Lens 11 Audit Report — Edge & Terminal States (`Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`)

## Phase 0–3: Money Map & Stateful Function Walkthrough (Edge & Terminal States)

### 1. Raffle Creation & Initialization (`RaffleFactory::createRaffle`, `Raffle::initialize`, `Raffle::onERC721Received`)

[Model: createRaffle]
A sponsor deposits one unique collectible prize into a freshly created raffle contract and configures the minimum number of entries required for the prize to be won, the sale closing time, and the recipient address for the sponsor's eventual payout. In return, the raffle becomes active and ready to sell entries. No dollar pot totals change yet; the factory increments its total number of created raffles by one and records the new raffle in its directory.

[Why: RaffleFactory.sol:106]
Why does `RaffleFactory::createRaffle` deploy each clone with `Clones.clone(raffleImplementation)` (which uses the standard `CREATE` opcode) while relying on `isRaffle[destination]` and `destination.code.length != 0` in `Raffle::_isProtocolDestination` to block raffle clones from being configured as recipients or owning tickets? Because the code implicitly assumes that a raffle clone's address cannot be used as a recipient or ticket holder before the clone is deployed — overlooking that `CREATE` addresses from `RaffleFactory` are completely deterministic from the factory's address and sequential nonce (`nonce = raffleId + 1`).

[Defeat: createRaffle]
1. Sponsor calls `createRaffle` for Raffle 1 (`raffleId = 1`, factory nonce `2`) passing `sponsorRecipient = 0xFutureRaffle2` (the deterministic `CREATE` address of `raffleId = 2` at factory nonce `3`). At this moment `isRaffle[0xFutureRaffle2]` is `false` and `0xFutureRaffle2.code.length == 0`, so both `RaffleFactory::_validateCreateParams` and `Raffle::initialize` accept `0xFutureRaffle2`. Once Raffle 2 is later deployed at `0xFutureRaffle2`, `isRaffle[0xFutureRaffle2]` becomes `true`, causing `Raffle::releaseSponsorProceeds` in Raffle 1 to permanently revert with `InvalidQuoteDestination(0xFutureRaffle2)` while `Raffle::releaseSponsorPrize` transfers Raffle 1's NFT into Raffle 2 via raw `transferFrom`, stranding the NFT inside Raffle 2.
2. During `createRaffle`, an untrusted `prizeToken` contract executes `raffle.onERC721Received` (which sets `status = Status.Active` at `Raffle.sol:428`), and then inside `prizeToken.ownerOf(params.prizeTokenId)` at `RaffleFactory.sol:129` (while `RaffleFactory`'s reentrancy lock is held, but the new `Raffle` clone's reentrancy lock is unentered) calls `raffle.buyEntries(buyer, 1)`, causing `TicketPurchased` to be emitted before `RaffleCreated`.
3. Sponsor attempts to pass `endTime = uint64(block.timestamp)` or `reserveEntries = 0`; `createRaffle` reverts with `InvalidEndTime` and `ZeroReserveEntries` respectively.

---

### 2. Buying Entries & Ticket Minting/Transfers (`Raffle::buyEntries`, `Raffle::_update`)

[Model: buyEntries]
A buyer pays one dollar per requested entry into the raffle contract and designates a recipient address. In return, the recipient receives a single numbered ticket covering the contiguous range of entry numbers just purchased. The raffle's total sold entries increase by the number of entries bought, the ticket counter increases by one, and the unallocated dollar pot increases by one dollar per entry bought.

[Why: Raffle.sol:602]
Why does `_isProtocolDestination` gate the `canonicalFactory.isRaffle(destination)` check behind `if (!unsafeDestination && destination.code.length != 0)`? Because the code assumes any canonical raffle clone already has deployed runtime code when `_isProtocolDestination` is evaluated during `_update` or `initialize` — which is false for any not-yet-deployed future raffle clone address deterministically derived from `RaffleFactory`'s `CREATE` nonce.

[Defeat: buyEntries]
1. A buyer calls `buyEntries(0xFutureRaffle2, 5)` on Raffle 1 before Raffle 2 is deployed at `0xFutureRaffle2`. In `_update` (`Raffle.sol:498`), `_isProtocolDestination(0xFutureRaffle2, address(prizeToken))` returns `false` because `0xFutureRaffle2.code.length == 0`, and in `_safeMint` (`ERC721Utils.sol:40`), `checkOnERC721Received` skips the callback check because `0xFutureRaffle2.code.length == 0`. When Raffle 2 is subsequently created at `0xFutureRaffle2`, ticket `#1` in Raffle 1 is now owned by Raffle 2, which has no function to transfer, burn, redeem, or refund the ticket.
2. When a sponsor submits `enableRefunds()` before `endTime` on an empty raffle (`totalEntries == 0`) to cancel and recover their NFT, an attacker frontruns `enableRefunds()` with `buyEntries(attacker, 1)` for `1_000_000` USDC (1 USDC). `totalEntries` becomes `1`, causing the sponsor's `enableRefunds()` call to hit the `totalEntries != 0` branch (`Raffle.sol:286`) and revert with `RefundsNotAvailable(endTime + 2 days, block.timestamp)`.
3. A contract `recipient` implements `onERC721Received` and, during `_safeMint(recipient, ticketId)` at `Raffle.sol:235`, calls `raffle.transferFrom(recipient, secondaryAddress, ticketId)`. Because `_update` is not `nonReentrant` and all state writes (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`) occurred before `_safeMint`, the transfer moves ownership to `secondaryAddress` without corrupting entry ranges or pot accounting.

---

### 3. Requesting & Fulfilling the Draw (`Raffle::requestDraw`, `Raffle::fulfillRandomWords`)

[Model: requestDraw]
Any caller sends native currency after the sale closing time (and within the two-day request window) to trigger the random draw for a raffle that has sold at least one entry. The raffle forwards the quoted native fee to the randomness provider, refunds any excess native currency back to the caller, records the request timestamp and identifier, and moves the raffle status from active to drawing. None of the dollar pot totals change.

[Why: Raffle.sol:257]
Why does `requestDraw` call `VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative` (which calculates `requestPrice` at the current transaction gas price and forwards only `{value: requestPrice}` to the wrapper) and immediately refund `msg.value - paidPrice` to `msg.sender`? Because the contract assumes the randomness wrapper only ever needs the exact fee quoted at the request transaction's gas price, leaving no way for a caller to overfund the request against gas spikes and no way to retry or top up a stuck `Drawing` request before `callbackDeadline()`.

[Defeat: requestDraw]
1. At `block.timestamp == endTime`, a participant who wants the raffle to fail into `Status.Refunding` (for instance, a sponsor whose NFT floor price appreciated far above `unsettledPot`, or a whale buyer who bought 99% of entries for an NFT whose value crashed before `endTime`) calls `requestDraw()` in a low-basefee block with `maxPriorityFeePerGas = 0`. Because `requestRandomnessPayInNative` only forwards `calculateRequestPriceNative` (computed from `tx.gasprice`) and refunds any extra `msg.value`, and `status` transitions permanently to `Status.Drawing`, no honest party can submit a higher-gas-price VRF request or top up the in-flight request; if gas spikes for 2 days (`DRAW_CALLBACK_TIMEOUT`), the callback cannot execute and the raffle is forced into `Status.Refunding`.
2. A contract caller invokes `requestDraw()` with `msg.value = quotedFee + 1 wei` and reverts inside its `receive()` fallback when `Raffle.sol:267` refunds `excess = 1 wei`; `requestDraw()` reverts with `NativeRefundFailed` and rolls back the entire request, allowing another caller to call `requestDraw()` with exact `quotedFee`.
3. A late Chainlink VRF fulfillment arrives at `block.timestamp == callbackDeadline()` (`drawRequestedAt + 2 days`). In `fulfillRandomWords` (`Raffle.sol:512`), `block.timestamp >= callbackDeadline()` evaluates to `true`, so the callback is ignored via `VrfCallbackIgnored` and cannot overwrite or race with `enableRefunds()`.

[Model: fulfillRandomWords]
When the randomness provider returns one random number before the two-day callback deadline while the raffle is drawing, the raffle picks one winning entry number uniformly between one and the total sold entries, records the resolution timestamp, and sets the outcome to NFT-won if total sold entries met or exceeded the reserve threshold, or cash-won if total sold entries fell short of the reserve threshold. The dollar pot remains in the unallocated pot until settlement.

---

### 4. Enabling & Claiming Refunds (`Raffle::enableRefunds`, `Raffle::refundTickets`)

[Model: enableRefunds]
When a raffle has no sold entries (callable by the sponsor before the sale ends or by anyone at or after the sale ends) or when the two-day draw request window or two-day callback window expires without resolution, the caller moves the raffle into the refunding state. The entire unallocated dollar pot is moved into the remaining refund liability total, setting the unallocated pot to zero.

[Model: refundTickets]
In the refunding state, a ticket owner submits between one and one hundred of their tickets. The raffle destroys those tickets, calculates one dollar for every entry covered by those tickets, subtracts that dollar amount from the remaining refund liability total, and sends that exact dollar amount to the ticket owner.

[Defeat: refundTickets]
1. A caller passes duplicate ticket IDs `[1, 1]` to `refundTickets`. Iteration 0 burns ticket `1` (`_owners[1] = address(0)`); iteration 1 calls `ownerOf(1)` which reverts with `ERC721NonexistentToken(1)`, reverting the entire batch.
2. A caller passes `ticketIds` of length `101` (`> MAX_REFUND_TICKET_BATCH_SIZE`); `refundTickets` reverts at `Raffle.sol:352` with `InvalidTicketBatchSize(101, 100)`.
3. A caller who was blacklisted by `quoteToken` (USDC) cannot receive USDC directly in `refundTickets([1])`. Because `_update` (`Raffle.sol:498`) permits ticket transfers in `Status.Refunding` without touching `quoteToken`, the ticket owner calls `raffle.transferFrom(blacklistedOwner, freshWallet, 1)` and `freshWallet` calls `raffle.refundTickets([1])`, recovering the refund cleanly.

---

### 5. Settlement, Winner Redemption, and Sponsor/Treasury Claims (`Raffle::settleWinningTicket`, `Raffle::redeemWinningTicket`, `Raffle::releaseSponsorProceeds`, `Raffle::releaseProtocolFees`, `Raffle::releaseSponsorPrize`)

[Model: settleWinningTicket]
After the raffle resolves to NFT-won or cash-won, any caller supplies the ticket ID whose entry range contains the winning entry number. The raffle verifies that the winning entry falls inside that ticket's range, moves the entire unallocated dollar pot to zero, and splits it into separate claimable totals: five percent (rounded down) to protocol fees, eighty percent (rounded down) to winner proceeds if cash-won (or zero if NFT-won), and the exact remaining dollars to sponsor proceeds. No tokens or prizes leave the contract during this step.

[Model: redeemWinningTicket]
The current owner of the winning ticket destroys the winning ticket (settling it first if not yet settled) to claim their prize. If the outcome is NFT-won, the raffle marks the prize as claimed and transfers the collectible prize to the ticket owner. If the outcome is cash-won, the raffle sets the winner proceeds total to zero and sends that dollar amount to the ticket owner.

[Model: releaseSponsorProceeds]
Any caller triggers the payout of the sponsor's allocated dollar proceeds. The raffle sets the sponsor proceeds total to zero and transfers that entire dollar amount to the pre-configured sponsor recipient.

[Model: releaseProtocolFees]
Any caller triggers the payout of the protocol's allocated dollar fees. The raffle sets the protocol fees total to zero and transfers that entire dollar amount to the pre-configured protocol treasury.

[Model: releaseSponsorPrize]
When the outcome is cash-won or refunding and the collectible prize has not yet been claimed, any caller triggers the return of the collectible prize. The raffle marks the prize as claimed and transfers the collectible prize back to the pre-configured sponsor recipient.

[Why: Raffle.sol:404]
Why does `releaseSponsorPrize` transfer the NFT to `sponsorRecipient` using `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without checking `_isProtocolDestination(recipient, address(prizeToken))`, whereas `_transferQuote` in `releaseSponsorProceeds` explicitly re-checks `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` at `Raffle.sol:565`? Because the author assumed `initialize` already permanently guaranteed `sponsorRecipient` is not a protocol destination — forgetting that `isRaffle(sponsorRecipient)` can flip from `false` to `true` after `initialize` if `sponsorRecipient` was a precomputed future `Raffle` clone address, and forgetting to apply the same runtime `_isProtocolDestination` guard to NFT delivery in `releaseSponsorPrize` and `redeemWinningTicket`.

[Defeat: redeemWinningTicket]
1. An attacker calls `settleWinningTicket(winningTicketId)` before the winning ticket owner calls `redeemWinningTicket(winningTicketId)`. In `redeemWinningTicket` (`Raffle.sol:314-318`), `settlementComplete` is already `true` and `ticketId == winningTicketId`, so redemption proceeds normally without reverting.
2. In `Status.CashWon`, an attacker attempts to settle with a non-existent `ticketId = 999` (`_ticketRanges[999] == {0, 0}`). Because `winningEntry >= 1 > lastEntry (0)`, `_requireWinningTicket(999)` at `Raffle.sol:582` reverts with `TicketDoesNotContainWinningEntry(999, winningEntry)`.
3. After `settleWinningTicket(winningTicketId)` has completed, the winning ticket owner transfers `winningTicketId` to `newOwner` via `transferFrom` and `newOwner` calls `redeemWinningTicket(winningTicketId)`. Because `_settleWinningTicket` does not snapshot `ownerOf(ticketId)` and `redeemWinningTicket` reads `address winner = ownerOf(ticketId)` at `Raffle.sol:320`, `newOwner` receives the prize or cash proceeds as intended.

---

## Phase 4: Last User Out Tests Across All Lifecycles

[LastOut: NftWon]
Suppose Buyers 1..k purchase `totalEntries >= reserveEntries` entries for `grossPot = totalEntries * 1_000_000` USDC (`unsettledPot = grossPot`). After VRF resolves to `Status.NftWon` and `_settleWinningTicket` executes:
- `protocolFees = Math.mulDiv(grossPot, 500, 10_000) = totalEntries * 50_000`
- `sponsorProceeds = grossPot - protocolFees = totalEntries * 950_000`
- `winnerProceeds = 0`, `unsettledPot = 0`, `remainingRefundLiability = 0`
In any withdrawal order across `{redeemWinningTicket, releaseSponsorProceeds, releaseProtocolFees}`, `protocolFees + sponsorProceeds == grossPot == quoteToken.balanceOf(address(this))`. The last claimant out is paid in full with `0` shortfall and `0` trapped dust.

[LastOut: CashWon]
Suppose Buyers 1..k purchase `0 < totalEntries < reserveEntries` entries for `grossPot = totalEntries * 1_000_000` USDC (`unsettledPot = grossPot`). After VRF resolves to `Status.CashWon` and `_settleWinningTicket` executes:
- `protocolFees = Math.mulDiv(grossPot, 500, 10_000) = totalEntries * 50_000`
- `winnerProceeds = Math.mulDiv(grossPot, 8000, 10_000) = totalEntries * 800_000`
- `sponsorProceeds = grossPot - protocolFees - winnerProceeds = totalEntries * 150_000`
- `unsettledPot = 0`, `remainingRefundLiability = 0`
In any withdrawal order across `{redeemWinningTicket, releaseSponsorProceeds, releaseProtocolFees, releaseSponsorPrize}`, `protocolFees + winnerProceeds + sponsorProceeds == grossPot == quoteToken.balanceOf(address(this))`. The last claimant out is paid in full with `0` shortfall and `0` trapped dust (unless the winning ticket or `sponsorRecipient` was set to a precomputed future `Raffle` clone address before that clone's creation, as detailed in the leads below).

[LastOut: Refunding]
Suppose Buyers 1..k purchase `totalEntries` entries across `ticketCount` tickets for `grossPot = totalEntries * 1_000_000` USDC (`unsettledPot = grossPot`). When `enableRefunds()` executes, `remainingRefundLiability = grossPot` and `unsettledPot = 0`. Because ticket ranges `[firstEntry_i, lastEntry_i]` form a contiguous partition of `[1, totalEntries]`, the sum of `(lastEntry_i - firstEntry_i + 1) * 1_000_000` across all `ticketId` in `1..ticketCount` equals `totalEntries * 1_000_000 == remainingRefundLiability`. In any refund order, the last ticket owner out is paid in full and reduces `remainingRefundLiability` to `0` with `0` shortfall (unless a ticket was minted/transferred to a precomputed future `Raffle` clone address before that clone was deployed, stranding that ticket's refund liability permanently).

---

## Findings & Leads

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-address-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-address-bypass
smell: Raffle::_isProtocolDestination (Raffle.sol:602) and RaffleFactory::_validateCreateParams (RaffleFactory.sol:159,166) only reject existing registered raffles (destination.code.length != 0 && canonicalFactory.isRaffle(destination)), but RaffleFactory::createRaffle deploys clones via CREATE (Clones.sol:57) whose future addresses are deterministic from the factory's sequential nonce before deployment.
unverified: Whether an external attacker can force an honest sponsor or honest buyer to use a precomputed future Raffle clone address without the sponsor or buyer supplying that address themselves.
description: Before Raffle N+1 is created at its deterministic CREATE address, futureRaffle has code.length == 0 and isRaffle[futureRaffle] == false, so it passes _isProtocolDestination during initialize and _update (and skips checkOnERC721Received in _safeMint), but once Raffle N+1 is deployed, isRaffle[futureRaffle] flips to true — permanently bricking _transferQuote with InvalidQuoteDestination(futureRaffle) for sponsorProceeds/protocolFees and permanently stranding any Raffle N tickets owned by futureRaffle.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-protocol-destination-check | group_key: Raffle | releaseSponsorPrize | missing-protocol-destination-check
smell: Raffle::releaseSponsorPrize (Raffle.sol:404) and Raffle::redeemWinningTicket (Raffle.sol:334) transfer the ERC-721 prize using raw prizeToken.transferFrom without checking _isProtocolDestination(recipient, address(prizeToken)), unlike _transferQuote (Raffle.sol:565) which re-checks _isProtocolDestination at claim time.
unverified: Whether sponsorRecipient or ownerOf(winningTicketId) can become a registered Raffle clone without the sponsor or ticket buyer initially specifying a precomputed future Raffle CREATE address.
description: If sponsorRecipient in Raffle 1 is set to the deterministic CREATE address of a future Raffle 2 before Raffle 2 is deployed, and Raffle 2 is subsequently created, releaseSponsorProceeds() in Raffle 1 reverts with InvalidQuoteDestination(raffle2), whereas permissionless releaseSponsorPrize() in Raffle 1 bypasses onERC721Received via raw transferFrom and sends Raffle 1's prize NFT into Raffle 2, violating the DESIGN.md invariant "Never move assets between raffle clones" and permanently locking the NFT.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: empty-raffle-cancellation-griefing | group_key: Raffle | enableRefunds | empty-raffle-cancellation-griefing
smell: In Raffle::enableRefunds (Raffle.sol:280-288), the sponsor's ability to cancel an empty raffle before endTime requires totalEntries == 0 at execution time, while buyEntries (Raffle.sol:209) allows anyone to buy 1 entry for 1 USDC (1_000_000 raw units) while status == Status.Active && block.timestamp < endTime.
unverified: Whether locking the sponsor's NFT until endTime (up to 30 days) or endTime + 2 days constitutes an exploitable griefing attack given that buying entries before endTime is part of normal raffle participation.
description: An attacker can frontrun a sponsor's pre-endTime enableRefunds() transaction with buyEntries(attacker, 1) for 1 USDC, flipping totalEntries from 0 to 1 so enableRefunds() reverts with RefundsNotAvailable(endTime + 2 days, block.timestamp) and locking the sponsor's prize NFT until at least endTime (and recovering the full 1 USDC at endTime + 2 days if no one pays the VRF fee for a 1-entry raffle).
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: vrf-underfunding-timeout-griefing | group_key: Raffle | requestDraw | vrf-underfunding-timeout-griefing
smell: Raffle::requestDraw (Raffle.sol:252-262) is permissionless, transitions status irreversibly to Status.Drawing with no retry or gas top-up mechanism, and calls VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative (VRFV2PlusWrapperConsumerBase.sol:100-113) which prices the callback at the request transaction's tx.gasprice and refunds all excess msg.value above calculateRequestPriceNative.
unverified: Whether an attacker can reliably keep Ethereum L1 gas prices elevated above Chainlink VRF v2.5 wrapper's fulfillment threshold for the full 2-day DRAW_CALLBACK_TIMEOUT window after submitting requestDraw() at a local basefee minimum with zero priority fee.
description: A participant who financially benefits from Status.Refunding over draw resolution (such as a sponsor whose NFT appreciated above the pot in NftWon, or a whale buyer whose NFT prize crashed in value before endTime) can frontrun honest draw requesters at endTime with a minimum-gas-price requestDraw() call; because excess msg.value is refunded and no second request or gas top-up is possible in Status.Drawing, a sustained 2-day gas spike causes VRF fulfillment to time out at callbackDeadline() and forces the raffle into Status.Refunding.
```

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: activation-before-creation-completion | group_key: RaffleFactory | createRaffle | activation-before-creation-completion
smell: In RaffleFactory::createRaffle (RaffleFactory.sol:128-136), prize.safeTransferFrom invokes Raffle::onERC721Received which sets the clone's status to Status.Active (Raffle.sol:428) before safeTransferFrom and prize.ownerOf complete and before RaffleCreated is emitted, while the clone's own ReentrancyGuard remains unentered.
unverified: Whether out-of-order TicketPurchased before RaffleCreated events or pre-completion entry purchases via an untrusted prizeToken hook can cause concrete financial loss to on-chain participants.
description: During createRaffle, an untrusted prizeToken contract can call raffle.buyEntries() after onERC721Received sets status = Status.Active (either at the end of safeTransferFrom or inside prize.ownerOf at RaffleFactory.sol:129), purchasing initial entries and emitting TicketPurchased before RaffleFactory finishes verification and emits RaffleCreated.
```

