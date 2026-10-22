### Phase 0 & Phase 1 — Protocol Vocabulary, Money Map & Tracked Totals

In `raffle.fun`, a `sponsor` creates an immutable `Raffle` ERC-1167 clone via [`RaffleFactory::createRaffle`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/SIMAO/attempt-04/leaf-workspaces/leaf-04/packages/contracts/src/RaffleFactory.sol#L730-L781) by atomically escrowing one ERC-721 prize (`prizeToken`, `prizeTokenId`). Users buy entries at a fixed price of `1,000,000` units of six-decimal USDC (`ENTRY_PRICE`) via [`Raffle::buyEntries`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/SIMAO/attempt-04/leaf-workspaces/leaf-04/packages/contracts/src/Raffle.sol#L222-L250) and receive one sequential ERC-721 ticket representing the contiguous inclusive entry range `[firstEntry, lastEntry]`.

Under **Lens 4 (Liquidation, Bad Debt & Solvency)**, this protocol has no leveraged debt positions or liquidations; its solvency and bad-debt surface is the **liability conservation, threshold resolution, and claim-clearing machinery** across `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, and `prizeClaimed`.

---

### Phase 2 & Phase 3 — Function Models, Deep-Drill Questions, Defeat Tests & Lifecycle Walkthroughs

#### 1. Creation & Escrow Lifecycle (`RaffleFactory::createRaffle` → `Raffle::initialize` → `Raffle::onERC721Received`)

[Model: RaffleFactory::createRaffle]
A sponsor supplies an NFT prize and configuration parameters (`sponsorRecipient`, `prizeToken`, `prizeTokenId`, `reserveEntries`, `endTime`). The factory increments `raffleCount`, deploys a new clone, initializes its configuration in `Status.AwaitingPrize`, records the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the sponsor's NFT into the clone. Upon receiving the NFT callback, the clone transitions to `Status.Active`.

[Why: RaffleFactory.sol:742]
Why does `RaffleFactory::createRaffle` call `IRaffle(raffle).initialize(...)` at line 742 *before* setting `isRaffle[raffle] = true` at line 758?
Because inside `Raffle::initialize`, `_isProtocolDestination` already rejects `destination == address(this)` for the newly created clone itself, so the code implicitly assumes that no configuration address can be a *future* raffle clone that has not yet been deployed or registered in `isRaffle`.

[Why: Raffle.sol:615]
Why does `_isProtocolDestination` guard the `canonicalFactory.isRaffle(destination)` call behind `if (!unsafeDestination && destination.code.length != 0)`?
Because the author wants to avoid an external staticcall for EOAs, resting on the implicit belief that a `Raffle` clone always has `code.length != 0` at the time its address is screened—which is false for a precomputed `CREATE` address of a not-yet-deployed `Raffle` clone.

[Defeat: RaffleFactory::createRaffle]
1. Attacker calls `createRaffle` with `params.sponsorRecipient = address(raffle)` (the predicted `CREATE` address of the clone being deployed in that very transaction): defeated at `Raffle.sol:206` because `Raffle::initialize` checks `_isProtocolDestination(params.sponsorRecipient, params.prizeToken)` where `destination == address(this)` is `true`.
2. Attacker front-runs an honest sponsor `Alice` who approved `prizeTokenId` to `RaffleFactory`, calling `createRaffle` with `params.prizeTokenId = Alice's tokenId`: defeated at `RaffleFactory.sol:761` because `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` passes `msg.sender` (the attacker) as `from`, reverting with `ERC721IncorrectOwner`.
3. Attacker calls `createRaffle` for Raffle #1 with `params.sponsorRecipient` set to the deterministic `CREATE` address of Raffle #2 (`keccak256(rlp(factory, nonce + 1))`), and then creates Raffle #2: `createRaffle` for Raffle #1 succeeds because `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false` during Raffle #1 creation; once Raffle #2 is created, `isRaffle[sponsorRecipient]` becomes `true`.

---

#### 2. Entry Purchase & Ticket Transfer Lifecycle (`Raffle::buyEntries` & `Raffle::_update`)

[Model: Raffle::buyEntries]
A buyer pays `entryCount * 1,000,000` USDC into the raffle while `status == Status.Active` and `block.timestamp < endTime`. The raffle advances `totalEntries` by `entryCount`, increments `ticketCount` by 1, records `[firstEntry, lastEntry]` for the new `ticketId`, adds the USDC paid to `unsettledPot`, and mints `ticketId` to `recipient`.

[Why: Raffle.sol:232]
Why does `buyEntries` bound `entryCount` by `type(uint128).max - totalEntries` while `unsettledPot` is a `uint256`?
Because `totalEntries`, `firstEntry`, `lastEntry`, and `winningEntry` are packed as `uint128`, and `uint256(type(uint128).max) * 1_000_000` is `< 2^148`, which guarantees `unsettledPot` and `grossSales()` can never overflow `uint256` and `ticketCount` (incremented at most once per entry) can never overflow `uint128`.

[Defeat: Raffle::buyEntries]
1. Attacker deploys an `IERC721Receiver` contract `Hook` and calls `buyEntries(address(Hook), 1)`, attempting to re-enter `buyEntries`, `enableRefunds`, or `refundTickets` inside `Hook::onERC721Received`: defeated by the `nonReentrant` modifier on all external state-changing functions of `Raffle`.
2. Attacker calls `buyEntries(address(Hook), 1)` and inside `Hook::onERC721Received` calls `Raffle::transferFrom(address(Hook), alice, ticketId)` (which does not have `nonReentrant`): `_mint` in OpenZeppelin `ERC721` updates `_owners[ticketId]` and `_balances[Hook]` *before* invoking `ERC721Utils.checkOnERC721Received`, and `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are already updated at lines 243–246, so transferring the ticket during the mint callback leaves all accounting totals intact.
3. Attacker calls `buyEntries(futureRaffle, 1)` where `futureRaffle` is the next `CREATE` address of `RaffleFactory`: `_isProtocolDestination(futureRaffle, address(prizeToken))` returns `false` and `_safeMint` skips `onERC721Received` because `futureRaffle.code.length == 0`; when the next raffle is deployed at `futureRaffle`, `ticketId` becomes permanently owned by a `Raffle` clone that has no method to transfer, redeem, or refund it.

---

#### 3. Draw Request & Resolution Lifecycle (`Raffle::requestDraw` → `Raffle::fulfillRandomWords`)

[Model: Raffle::requestDraw]
During `[endTime, endTime + 2 days)` on a raffle with at least one sold entry, any caller sends native ETH to cover the Chainlink VRF request price. The raffle transitions `status` to `Status.Drawing`, records `drawRequestedAt`, pays the exact native wrapper price to `i_vrfV2PlusWrapper`, stores `vrfRequestId`, and refunds any excess native ETH (`msg.value - paidPrice`) to `msg.sender`.

[Why: Raffle.sol:267]
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and reset it to `false` only after `vrfRequestId = requestId` is written?
Because `vrfRequestId` is still `0` during the external call to the wrapper; if a wrapper implementation ever invoked `rawFulfillRandomWords(0, ...)` synchronously before returning `requestId`, `requestId == vrfRequestId` (`0 == 0`) would pass unless `_requestInFlight` rejected the callback.

[Defeat: Raffle::requestDraw]
1. Attacker force-sends `1 ether` to `Raffle` via `selfdestruct` before `requestDraw` is called, attempting to corrupt the native fee accounting or steal ETH: `VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative` forwards `{value: requestPrice}` (not `address(this).balance`), and `requestDraw` refunds `msg.value - paidPrice` (not `address(this).balance`), so forced ETH neither breaks the call nor leaks to the caller unless `paidPrice > quotedFee` within `msg.value`.
2. Attacker calls `requestDraw` from a contract whose `receive()` reverts when `excess > 0`, trying to brick the draw state in `Status.Drawing`: the revert at `Raffle.sol:282` (`NativeRefundFailed`) reverts the entire `requestDraw` transaction, leaving `status == Status.Active` so any honest keeper can still call `requestDraw`.
3. Attacker attempts to front-run `requestDraw` with `enableRefunds()` at `block.timestamp == drawRequestDeadline() - 1`: defeated at `Raffle.sol:300` because `enableRefunds()` reverts while `block.timestamp < drawRequestDeadline()`.

[Model: Raffle::fulfillRandomWords]
When the Chainlink VRF wrapper delivers one random word for `vrfRequestId` while `status == Status.Drawing` and strictly before `drawRequestedAt + 2 days`, the raffle maps the random word into `[1, totalEntries]` as `winningEntry`, records `resolvedAt`, and sets `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`.

[Defeat: Raffle::fulfillRandomWords]
1. Wrapper sends a callback with `randomWords.length == 0` or `randomWords.length == 2`: ignored without reverting at `Raffle.sol:524` (`randomWords.length != 1`), preserving liveness.
2. Wrapper delivers a late callback at `block.timestamp == callbackDeadline()`: ignored at `Raffle.sol:525` (`block.timestamp >= callbackDeadline()`), and `enableRefunds()` is simultaneously unlocked at `Raffle.sol:304` (`block.timestamp >= deadline`), leaving zero dead time between the two paths.
3. Duplicate callback arrives after the raffle has already transitioned to `Status.NftWon`, `Status.CashWon`, or `Status.Refunding`: ignored at `Raffle.sol:524` (`status != Status.Drawing`), so `winningEntry` and `status` cannot be overwritten.

---

#### 4. Settlement & Claims Lifecycle (`_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`)

[Model: Raffle::_settleWinningTicket]
In `Status.NftWon` or `Status.CashWon`, any caller supplies `ticketId`. The raffle verifies that `winningEntry` lies within `ticketId`'s `[firstEntry, lastEntry]` range, zeroes `unsettledPot`, records `settlementComplete = true` and `winningTicketId = ticketId`, allocates 5% of the pot (rounded down) to `protocolFees`, and in `Status.NftWon` allocates the remaining 95% to `sponsorProceeds`, or in `Status.CashWon` allocates 80% (rounded down) to `winnerProceeds` and the remaining 15% (plus any rounding dust) to `sponsorProceeds`.

[Why: Raffle.sol:551]
Why does `_settleWinningTicket` verify `_requireWinningTicket(ticketId)` without checking `ownerOf(ticketId)` or transferring the NFT/USDC?
Because the protocol separates liability calculation from claim disbursement so that a passive or reverting winning ticket owner cannot prevent `protocolTreasury` and `sponsorRecipient` from claiming their USDC allocations—resting on the implicit belief that in `Status.NftWon`, the escrowed `prizeToken` will always be deliverable when the winner later calls `redeemWinningTicket`.

[Model: Raffle::redeemWinningTicket]
The current owner of `winningTicketId` calls `redeemWinningTicket(ticketId)` (which settles first if `settlementComplete == false`). The raffle records `winnerRecipient = winner` and `winnerRedeemed = true`, burns `ticketId`, and in `Status.NftWon` marks `prizeClaimed = true`, transfers `prizeTokenId` to `winner`, and verifies `prizeToken.ownerOf(prizeTokenId) == winner`; or in `Status.CashWon` zeroes `winnerProceeds` and transfers that USDC amount to `winner`.

[Why: Raffle.sol:353]
Why does `redeemWinningTicket` check `if (cashAmount == 0) revert NoWinnerProceeds()` in the `CashWon` branch?
As a defense-in-depth guard against zero-value transfers; since `requestDraw` requires `totalEntries >= 1` and `ENTRY_PRICE = 1_000_000`, `grossPot >= 1_000_000` and `cashAmount = Math.mulDiv(grossPot, 8000, 10_000) >= 800_000 > 0`, so `cashAmount` is strictly positive for every reachable `CashWon` state.

[Defeat: Raffle::redeemWinningTicket]
1. Attacker calls `settleWinningTicket(0)` for an unminted ticket ID (where `_ticketRanges[0]` is `{0, 0}`): defeated at `Raffle.sol:595` because `winningEntry >= 1 > lastEntry (0)`, reverting with `TicketDoesNotContainWinningEntry(0, winningEntry)`.
2. Winner is a contract without `onERC721Received`: `redeemWinningTicket` uses `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` rather than `safeTransferFrom`, so delivery to a contract winner without `IERC721Receiver` still succeeds.
3. Sponsor uses an ERC-721 `prizeToken` that allows escrow to `Raffle` during `createRaffle` (e.g., when `from == sponsor` or before `endTime`) but reverts or blocks `transferFrom(address(this), winner, prizeTokenId)` during `redeemWinningTicket` (e.g., via collection pause, blacklist, transfer validator policy rejecting contract `from`/`msg.sender`, or sponsor-controlled logic): `settleWinningTicket` and `releaseSponsorProceeds` still pay 95% of `grossSales` in USDC to `sponsorRecipient`, while `redeemWinningTicket` reverts permanently and the winner receives neither the NFT nor a USDC refund.

[Model: Raffle::releaseSponsorProceeds]
Any caller triggers the transfer of the full `sponsorProceeds` balance to `sponsorRecipient` after zeroing `sponsorProceeds`.

[Model: Raffle::releaseProtocolFees]
Any caller triggers the transfer of the full `protocolFees` balance to `protocolTreasury` after zeroing `protocolFees`.

[Model: Raffle::releaseSponsorPrize]
In `Status.CashWon` or `Status.Refunding`, when `prizeClaimed == false`, any caller marks `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

[Why: Raffle.sol:417]
Why does `releaseSponsorPrize` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without checking `_isProtocolDestination(recipient, address(prizeToken))`, whereas `releaseSponsorProceeds` calls `_transferQuote(recipient, amount)` which *does* check `_isProtocolDestination(recipient, address(prizeToken))`?
Because `releaseSponsorPrize` assumes `sponsorRecipient` was permanently validated during `initialize`, overlooking that `sponsorRecipient` can become a registered `Raffle` clone (`isRaffle[sponsorRecipient] == true`) after `initialize` if `sponsorRecipient` was set to a future clone's deterministic `CREATE` address.

[LastOut: NftWon Settlement & Claims Lifecycle]
Suppose Buyer A buys 3 entries (`3,000,000` USDC, ticket 1: `[1, 3]`) and Buyer B buys 7 entries (`7,000,000` USDC, ticket 2: `[4, 10]`), with `reserveEntries = 10`. `unsettledPot = 10,000,000` USDC, `quoteToken.balanceOf(raffle) = 10,000,000`. VRF selects `winningEntry = 5` (ticket 2, Buyer B), setting `status = Status.NftWon`.
1. `_settleWinningTicket(2)` sets `unsettledPot = 0`, `protocolFees = 500,000` (5%), `sponsorProceeds = 9,500,000` (95%), `winnerProceeds = 0`. Sum of tracked quote liabilities = `10,000,000 == quoteToken.balanceOf(raffle)`.
2. `releaseProtocolFees()` pays `500,000` USDC to `protocolTreasury` (`protocolFees = 0`, balance = `9,500,000`).
3. `releaseSponsorProceeds()` pays `9,500,000` USDC to `sponsorRecipient` (`sponsorProceeds = 0`, balance = `0`).
4. Buyer B calls `redeemWinningTicket(2)` and receives `prizeTokenId` (`prizeClaimed = true`, `winnerRedeemed = true`).
Every cohort is paid in full with `0` USDC shortfall, *provided* `prizeToken.transferFrom` does not revert and `sponsorRecipient` did not become a registered `Raffle` clone after initialization.

[LastOut: CashWon Settlement & Claims Lifecycle]
Suppose Buyer A buys 1 entry (`1,000,000` USDC, ticket 1: `[1, 1]`) and Buyer B buys 2 entries (`2,000,000` USDC, ticket 2: `[2, 3]`), with `reserveEntries = 5`. `unsettledPot = 3,000,000` USDC. VRF selects `winningEntry = 1` (ticket 1, Buyer A), setting `status = Status.CashWon`.
1. `_settleWinningTicket(1)` sets `unsettledPot = 0`, `protocolFees = Math.mulDiv(3,000,000, 500, 10,000) = 150,000`, `winnerProceeds = Math.mulDiv(3,000,000, 8000, 10,000) = 2,400,000`, and `sponsorProceeds = 3,000,000 - 150,000 - 2,400,000 = 450,000`. Sum = `150,000 + 2,400,000 + 450,000 = 3,000,000 == quoteToken.balanceOf(raffle)`.
2. Regardless of withdrawal order (`releaseProtocolFees`, `releaseSponsorProceeds`, `redeemWinningTicket(1)`, `releaseSponsorPrize`), the last claimant out receives their exact allocation (`150,000`, `450,000`, or `2,400,000` USDC, plus `prizeTokenId` to `sponsorRecipient`), leaving `accountedQuoteBalance() == 0` and `quoteToken.balanceOf(raffle) == 0`.

---

#### 5. Refund Lifecycle (`Raffle::enableRefunds` → `Raffle::refundTickets` + `Raffle::releaseSponsorPrize`)

[Model: Raffle::enableRefunds]
When a raffle is `Status.Active` with zero entries (callable by `sponsor` anytime or anyone at `>= endTime`), `Status.Active` with sold entries at `>= endTime + 2 days`, or `Status.Drawing` at `>= drawRequestedAt + 2 days`, the raffle moves `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status = Status.Refunding`.

[Model: Raffle::refundTickets]
In `Status.Refunding`, a caller supplies 1 to 100 `ticketIds` they own. For each ticket, the raffle verifies `msg.sender == ownerOf(ticketId)`, computes its entry count `lastEntry - firstEntry + 1`, and burns the ticket. It then deducts `aggregateEntries * 1,000,000` from `remainingRefundLiability` and transfers that exact USDC amount to `msg.sender`.

[Defeat: Raffle::refundTickets]
1. Attacker passes duplicate ticket IDs `[1, 1]` in `ticketIds` to claim twice against `remainingRefundLiability`: on the first iteration `_burn(1)` sets `_owners[1] = address(0)`, so on the second iteration `ownerOf(1)` reverts with `ERC721NonexistentToken(1)`.
2. Attacker buys 1,000 separate 1-entry tickets hoping to exceed `MAX_REFUND_TICKET_BATCH_SIZE = 100` and lock funds: `refundTickets` can be called repeatedly in batches of up to 100 tickets per transaction until all tickets are refunded.
3. Attacker calls `redeemWinningTicket` first and then tries to transition to `Status.Refunding`: impossible because `enableRefunds` only accepts `Status.Active` or `Status.Drawing`, and `redeemWinningTicket` only accepts `Status.NftWon` or `Status.CashWon`.

[LastOut: Refund Lifecycle]
Suppose Buyer A buys `e_A` entries (`e_A * 1,000,000` USDC), Buyer B buys `e_B` entries (`e_B * 1,000,000` USDC), and Buyer C buys `e_C` entries (`e_C * 1,000,000` USDC). `unsettledPot = (e_A + e_B + e_C) * 1,000,000` USDC. After `enableRefunds()`, `remainingRefundLiability = (e_A + e_B + e_C) * 1,000,000`.
1. Buyer C refunds first: burns ticket C, `remainingRefundLiability` decreases by `e_C * 1,000,000`, receives `e_C * 1,000,000` USDC.
2. Buyer A refunds second: burns ticket A, `remainingRefundLiability` decreases by `e_A * 1,000,000`, receives `e_A * 1,000,000` USDC.
3. Buyer B (last user out) refunds last: burns ticket B, `remainingRefundLiability` decreases by `e_B * 1,000,000` to `0`, receives `e_B * 1,000,000` USDC in full. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`. The protocol is short by `0`.

---

### Phase 5 — Saturation Sweep

1. **Sweep of `_isProtocolDestination` across all asset-movement and configuration sites (`Raffle.sol:200-208`, `Raffle.sol:511`, `Raffle.sol:578`, `Raffle.sol:347`, `Raffle.sol:417`, `RaffleFactory.sol:790-802`)**:
   - `RaffleFactory::_validateCreateParams` and `Raffle::initialize` check `isRaffle` / `_isProtocolDestination` at creation time, when future `Raffle` clones have `code.length == 0` and `isRaffle == false`.
   - `Raffle::_update` checks `_isProtocolDestination` on ticket mint/transfer, which skips `canonicalFactory.isRaffle(destination)` when `destination.code.length == 0`.
   - `Raffle::_transferQuote` re-checks `_isProtocolDestination` at USDC withdrawal time (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`), so if `sponsorRecipient` becomes a registered `Raffle` clone after initialization, `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination`.
   - `Raffle::releaseSponsorPrize` (`Raffle.sol:417`) and `Raffle::redeemWinningTicket` (`Raffle.sol:347`) do **not** call `_isProtocolDestination` before `prizeToken.transferFrom`, allowing `releaseSponsorPrize` to transfer the prize NFT directly into a `Raffle` clone if `sponsorRecipient` was set to a precomputed future clone address.
2. **Sweep of untrusted `prizeToken` interactions (`RaffleFactory.sol:761-764`, `Raffle.sol:347-350`, `Raffle.sol:417-418`)**:
   - `RaffleFactory::createRaffle` verifies escrow via `safeTransferFrom` + `ownerOf`.
   - `Raffle::_settleWinningTicket` (`Raffle.sol:556-568`) allocates `sponsorProceeds` (95% of `unsettledPot`) in `Status.NftWon` without requiring `prizeClaimed == true` (i.e., before `redeemWinningTicket` proves the untrusted `prizeToken` can actually be transferred out of `Raffle` to `winner`).

---

### Findings & Leads

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: decoupled-settlement-solvency | group_key: Raffle | _settleWinningTicket | decoupled-settlement-solvency
smell: In `Raffle.sol:556-568`, `_settleWinningTicket` unconditionally moves 95% of `unsettledPot` into `sponsorProceeds` in `Status.NftWon` and `releaseSponsorProceeds` (`Raffle.sol:388-395`) releases it to `sponsorRecipient` before `redeemWinningTicket` (`Raffle.sol:347-350`) transfers `prizeTokenId` to the winner, while no fallback path exists to transition from `Status.NftWon` to `Status.Refunding` if `prizeToken.transferFrom` reverts.
unverified: Whether an in-scope `prizeToken` is permitted to be an arbitrary untrusted ERC-721 (as stated in `DESIGN.md:5`: "arbitrary prize contracts and ticket recipients are untrusted") or is restricted by trust assumption to non-pausable, non-blacklisting, non-hooked ERC-721 contracts (as stated in `IRaffle.sol:839`: "Supported prizes are honest, standards-compliant ERC-721s").
description: If `prizeToken` blocks or reverts `transferFrom(address(this), winner, prizeTokenId)` at redemption time (via pause, blacklist, transfer validator policy rejecting contract senders, or sponsor-controlled logic), the sponsor still withdraws 95% of all buyers' USDC via `settleWinningTicket` and `releaseSponsorProceeds` while the winning ticket holder receives neither the NFT nor a refund.
```

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-bypass
smell: In `Raffle.sol:615-617` and `RaffleFactory.sol:739-758`, `_isProtocolDestination` only queries `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`, while `RaffleFactory::createRaffle` deploys clones via `Clones.clone` using predictable `CREATE` nonces, and `releaseSponsorPrize` (`Raffle.sol:417`) omits `_isProtocolDestination` entirely.
unverified: Whether any honest cohort can be induced to set `sponsorRecipient` or ticket `recipient` to a precomputed future `Raffle` clone address without self-harm, since `sponsorRecipient` is chosen by the sponsor and ticket `recipient` is chosen by the ticket buyer or transferrer.
description: Setting `sponsorRecipient` or a ticket `recipient` in Raffle #1 to the deterministic `CREATE` address of a not-yet-deployed Raffle #2 bypasses `_isProtocolDestination` (and `_safeMint`'s `code.length > 0` check), and once Raffle #2 is created (`isRaffle == true`), `releaseSponsorProceeds` in Raffle #1 permanently reverts with `InvalidQuoteDestination`, any ticket held by Raffle #2 is permanently unclaimable, and `releaseSponsorPrize` transfers Raffle #1's prize NFT into Raffle #2 where it is permanently locked.
```
