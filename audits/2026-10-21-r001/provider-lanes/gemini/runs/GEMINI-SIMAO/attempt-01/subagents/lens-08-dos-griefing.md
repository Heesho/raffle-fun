# 0xSimao Audit Report — Lens 8: Denial of Service & Griefing

## Phase 0 & Phase 1 — Vocabulary, Money Map, and Function Models

`[Model: createRaffle]`
A sponsor supplies an ERC-721 prize token and configuration (`sponsorRecipient`, `prizeToken`, `prizeTokenId`, `reserveEntries`, `endTime`). The factory increments `raffleCount`, deploys a new clone of `raffleImplementation`, initializes the clone in `Status.AwaitingPrize`, registers `raffleById[raffleId] = raffle`, `idByRaffle[raffle] = raffleId`, and `isRaffle[raffle] = true`, and transfers the prize NFT from the sponsor into the clone. The clone's receiver hook transitions `status` from `AwaitingPrize` to `Active`, and the factory verifies that the clone owns the prize NFT and is `Active`.

`[Model: initialize]`
The factory configures a freshly deployed clone once with `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime`, sets `initialized = true`, and sets `status = Status.AwaitingPrize`. No asset balances or entry totals change yet.

`[Model: onERC721Received]`
When the configured `prizeToken` transfers `prizeTokenId` from `sponsor` with `factory` as operator while the raffle is in `Status.AwaitingPrize`, the raffle accepts custody of the prize NFT and transitions `status` to `Status.Active`.

`[Model: buyEntries]`
A buyer gives `entryCount * 1,000,000` raw units of six-decimal USDC (`quoteToken`) to the raffle while `status == Status.Active` and `block.timestamp < endTime`. In return, `recipient` receives one sequential ERC-721 ticket (`ticketId = ticketCount + 1`) representing the inclusive 1-based entry range `[totalEntries + 1, totalEntries + entryCount]`. `totalEntries` increases by `entryCount`, `ticketCount` increases by `1`, `_ticketRanges[ticketId]` records the range, and `unsettledPot` increases by `entryCount * 1,000,000`.

`[Model: requestDraw]`
After `endTime` and before `endTime + 2 days` (with `totalEntries > 0`), a caller supplies native ETH (`msg.value >= quotedFee`) to request one random word from the Chainlink VRF v2.5 native wrapper. The raffle transitions `status` from `Status.Active` to `Status.Drawing`, records `drawRequestedAt = block.timestamp` and `vrfRequestId = requestId`, pays `paidPrice` in native ETH to the VRF wrapper, and returns any `excess = msg.value - paidPrice` in native ETH to `msg.sender`. `unsettledPot` and `totalEntries` are unchanged.

`[Model: fulfillRandomWords]`
The Chainlink VRF wrapper delivers one random word for `vrfRequestId` while `status == Status.Drawing` and `block.timestamp < drawRequestedAt + 2 days`. The raffle computes `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and transitions `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`. `unsettledPot` remains unallocated until settlement.

`[Model: enableRefunds]`
A caller transitions the raffle to `Status.Refunding` when either: (a) `status == Status.Active` and `totalEntries == 0` (callable by `sponsor` before `endTime`, or anyone at `block.timestamp >= endTime`), (b) `status == Status.Active`, `totalEntries > 0`, and `block.timestamp >= endTime + 2 days`, or (c) `status == Status.Drawing` and `block.timestamp >= drawRequestedAt + 2 days`. The entire `unsettledPot` is moved into `remainingRefundLiability`, and `unsettledPot` is zeroed.

`[Model: _settleWinningTicket]`
In `Status.NftWon` or `Status.CashWon`, any caller supplies `ticketId` whose stored `_ticketRanges[ticketId]` contains `winningEntry`. The raffle zeroes `unsettledPot` (`grossPot`) and splits it into terminal claim buckets: `protocolFees = floor(grossPot * 500 / 10,000)` (5%), `winnerProceeds = 0` (in `NftWon`) or `floor(grossPot * 8,000 / 10,000)` (80% in `CashWon`), and `sponsorProceeds = grossPot - protocolFees - winnerProceeds` (95% in `NftWon` or 15% in `CashWon`). `settlementComplete` is set to `true` and `winningTicketId` is recorded without checking ticket ownership or transferring assets.

`[Model: redeemWinningTicket]`
The current owner (`msg.sender == ownerOf(ticketId)`) of the winning ticket settles it (if not already settled), sets `winnerRecipient = msg.sender` and `winnerRedeemed = true`, and burns `ticketId`. If `status == Status.NftWon`, `prizeClaimed` is set to `true` and the prize NFT is transferred to the winner (reverting if `prizeToken.ownerOf(prizeTokenId) != winner`). If `status == Status.CashWon`, `winnerProceeds` is zeroed and paid in USDC to the winner.

`[Model: refundTickets]`
In `Status.Refunding`, a ticket owner passes 1 to 100 `ticketIds` they own. Each ticket is burned and its entry count (`lastEntry - firstEntry + 1`) is summed into `aggregateEntries`. `remainingRefundLiability` is decreased by `amount = aggregateEntries * 1,000,000`, and `amount` of USDC is transferred to `msg.sender`.

`[Model: releaseSponsorProceeds]`
Any caller triggers payout of `sponsorProceeds` in USDC to the immutable `sponsorRecipient`, zeroing `sponsorProceeds`.

`[Model: releaseProtocolFees]`
Any caller triggers payout of `protocolFees` in USDC to the immutable `protocolTreasury`, zeroing `protocolFees`.

`[Model: releaseSponsorPrize]`
In `Status.CashWon` or `Status.Refunding`, when `prizeClaimed == false`, any caller sets `prizeClaimed = true` and transfers the escrowed prize NFT (`prizeToken`, `prizeTokenId`) back to `sponsorRecipient` (reverting if `prizeToken.ownerOf(prizeTokenId) != sponsorRecipient`).

---

## Phase 2 & Phase 3 — Deep Interrogation (`[Why]` and `[Defeat]`)

`[Why: Raffle.sol:593]`
Why does `_isProtocolDestination(address destination, address prizeToken_)` guard the `canonicalFactory.isRaffle(destination)` call with `if (!unsafeDestination && destination.code.length != 0)`?
The code assumes that any raffle clone that could ever be passed as `destination` already has deployed bytecode (`code.length != 0`) and is already registered in `isRaffle` at the moment `_isProtocolDestination` runs. However, `RaffleFactory::createRaffle` uses `Clones.clone(raffleImplementation)`, which deploys clones via `CREATE` (`address = keccak256(rlp([factory, nonce]))[12:]`). A future raffle clone's address is 100% deterministic from `RaffleFactory`'s nonce *before* it is deployed — when its `code.length == 0` and `isRaffle[futureRaffle] == false`!

`[Why: Raffle.sol:565]`
Why does `_transferQuote` re-verify `_isProtocolDestination(to, address(prizeToken))` at USDC payout time, whereas `releaseSponsorPrize()` (`Raffle.sol:404`) and `redeemWinningTicket()` (`Raffle.sol:334`) do not re-verify `_isProtocolDestination` before transferring the prize NFT?
The code assumes that checking `_isProtocolDestination` at `initialize` (for `sponsorRecipient`) and `_update` (for ticket owners) is sufficient for NFT transfers, while adding a defense-in-depth check in `_transferQuote`. Because a precomputed future `Raffle` clone address passes `initialize` and `_update` before that clone is created and then becomes `isRaffle[futureRaffle] == true` after that clone is created, this creates an asymmetry: `_transferQuote` reverts with `InvalidQuoteDestination(futureRaffle)` (permanently locking USDC claims), while `releaseSponsorPrize()` succeeds and transfers the prize NFT directly into `futureRaffle` (violating `DESIGN.md`'s rule *"Never move assets between raffle clones"* and permanently stranding the NFT inside `futureRaffle`).

`[Why: Raffle.sol:334]`
Why do `redeemWinningTicket` (`Raffle.sol:334`) and `releaseSponsorPrize` (`Raffle.sol:404`) use `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` followed by an `ownerOf` check instead of `safeTransferFrom`?
To prevent a contract recipient from reverting or reentering via `onERC721Received`, while verifying ownership changed via `prizeToken.ownerOf(prizeTokenId) == recipient`.

`[Why: Raffle.sol:280]`
Why does `enableRefunds()` allow `sponsor` to enable refunds before `endTime` only when `totalEntries == 0`?
The code assumes that once `totalEntries > 0`, a real buyer is participating and the sponsor must not be able to rug the draw. However, because a single entry costs only `1,000,000` (1 USDC) and is 100% refundable if no draw is requested (or 80% refundable to the sole buyer if a draw is requested when `reserveEntries > 1`), an attacker seeing a sponsor's `enableRefunds()` transaction in the mempool can front-run it with `buyEntries(attacker, 1)`, blocking the sponsor's cancellation and locking the prize NFT until `endTime + 2 days` (up to 32 days) at zero or 0.20 USDC net cost.

`[Why: Raffle.sol:314]`
Why is `settleWinningTicket` (`_settleWinningTicket`, `Raffle.sol:533`) separated from `redeemWinningTicket` (`Raffle.sol:309`), and why does `releaseSponsorProceeds` (`Raffle.sol:375`) not require `prizeClaimed == true` when `status == Status.NftWon`?
The code separates storage-only liability allocation from winner redemption so a passive or griefing winner cannot hold `sponsorProceeds` and `protocolFees` hostage by refusing to call `redeemWinningTicket`. However, this rests on the implicit belief that in `Status.NftWon`, `prizeToken.transferFrom(address(this), winner, prizeTokenId)` will always succeed when the winner calls `redeemWinningTicket`. If `prizeToken` is a malicious/untrusted contract (per `DESIGN.md`: *"arbitrary prize contracts and ticket recipients are untrusted"*) or a paused/frozen/transfer-restricted ERC-721 that reverts on `transferFrom` after `createRaffle`, the sponsor still extracts 95% of all buyers' USDC via `settleWinningTicket` + `releaseSponsorProceeds`, while `redeemWinningTicket` permanently reverts and there is no fallback from `Status.NftWon` to `Status.Refunding`.

`[Why: Raffle.sol:254]`
Why is `_requestInFlight = true` set before `requestRandomnessPayInNative` and cleared after `vrfRequestId = requestId` in `requestDraw`?
Because `vrfRequestId` is `0` until `requestRandomnessPayInNative` returns `requestId`; if a wrapper implementation synchronously invoked `rawFulfillRandomWords(0, ...)` during the request call, `requestId == vrfRequestId` (`0 == 0`) would pass unless blocked by `_requestInFlight`.

`[Why: Raffle.sol:352]`
Why is `refundTickets` bounded to `MAX_REFUND_TICKET_BATCH_SIZE = 100` tickets per call while `buyEntries` allows arbitrary `uint128` entries per ticket?
Because each `buyEntries` call mints a single ERC-721 ticket storing `[firstEntry, lastEntry]`, so `refundTickets` does `O(1)` work per ticket regardless of how many entries that ticket represents, and bounding the array to 100 tickets prevents out-of-gas reverts while allowing holders of >100 tickets to refund across multiple transactions.

---

### Guard Defeat Attempts (`[Defeat]`)

`[Defeat: _isProtocolDestination]`
1. **Precomputed next `Raffle` clone address via `CREATE` nonce**: Attacker computes `futureRaffle = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(factory), uint8(nonce))))))` before `createRaffle` deploys that clone. At that moment `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false`, so `_isProtocolDestination(futureRaffle, prizeToken)` returns `false` in `initialize` and `_update`. Once `factory.createRaffle` is called, `futureRaffle` is deployed and `isRaffle[futureRaffle]` becomes `true`.
2. **Cross-raffle `prizeToken` address**: Attacker passes `destination = prizeTokenOfAnotherRaffle`. `_isProtocolDestination` only checks `destination == prizeToken_` of *this* raffle, not other raffles' `prizeToken`s (which are external ERC-721 contracts, not protocol clones).
3. **Self-reference during `Raffle::initialize` before `isRaffle[raffle] = true`**: In `RaffleFactory::createRaffle`, `initialize` is called at line 109 before `isRaffle[raffle] = true` at line 125. Passing `sponsorRecipient = raffle` is caught by `destination == address(this)` inside `_isProtocolDestination` even though `isRaffle[raffle]` is still `false`.

`[Defeat: createRaffle]`
1. **Reentrant `prizeToken.safeTransferFrom` callback**: Malicious `prizeToken` calls `raffle.onERC721Received(factory, sponsor, tokenId, "")` (setting `status = Status.Active`) and then before returning from `safeTransferFrom` calls `raffle.enableRefunds()`. Fails if `sponsor != prizeToken` (which is blocked by `_isProtocolDestination(sponsor, prizeToken)`), and if `status` leaves `Active`, `RaffleFactory.sol:132` (`if (IRaffle(raffle).status() != IRaffle.Status.Active) revert`) reverts the entire `createRaffle` call.
2. **Pre-funding predicted clone address with ETH or USDC**: Attacker transfers 1 wei of ETH (via coinbase/selfdestruct) or 1 unit of `quoteToken` to the predicted `CREATE` clone address before `createRaffle`. `Clones.clone` (`CREATE`) succeeds when `balance > 0` as long as `code.length == 0 && nonce == 0`, and `Raffle` never reads `address(this).balance` or `quoteToken.balanceOf(address(this))`.
3. **Fake ERC-721 `prizeToken` that lies about `ownerOf`**: `prizeToken` returns `raffle` in `ownerOf(prizeTokenId)` during `createRaffle` (`RaffleFactory.sol:129`), then later refuses `transferFrom` in `redeemWinningTicket`. This succeeds at `createRaffle` and enables the untrusted-`prizeToken` settlement asymmetry in `Status.NftWon`.

`[Defeat: buyEntries]`
1. **Reentering via `_safeMint` -> `onERC721Received`**: Contract `recipient` implements `onERC721Received` and attempts to call `buyEntries`, `requestDraw`, `enableRefunds`, or `refundTickets`. Blocked by `nonReentrant` on all state-changing raffle functions.
2. **Transferring the newly minted ticket inside `onERC721Received`**: Contract `recipient` calls `raffle.transferFrom(recipient, otherAddr, ticketId)` inside `onERC721Received` (since `ERC721.transferFrom` is not `nonReentrant`). Succeeds harmlessly because `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` were already updated before `_safeMint`.
3. **Overflowing `totalEntries` or `grossAmount`**: Passing `entryCount = type(uint128).max` reverts at `entryCount > type(uint128).max - totalEntries` or in `quoteToken.safeTransferFrom` (exceeding total USDC supply).

`[Defeat: requestDraw]`
1. **Calling `requestDraw` from a contract that reverts or gas-bombs on ETH receive with `msg.value > paidPrice`**: Reverts the caller's own transaction with `NativeRefundFailed(msg.sender, excess)`; any honest caller can still call `requestDraw()` in a separate transaction.
2. **Calling `requestDraw` at the last second (`endTime + 2 days - 1`) to delay refunds**: Requires paying the real native Chainlink VRF fee (`getVrfRequestPrice()`), and Chainlink VRF fulfills within ~30 blocks (`requestConfirmations = 30`). Only delays refunds by up to 2 days if Chainlink VRF itself fails to fulfill.
3. **Underpaying gas price to make VRF callback unfulfilled**: Ethereum post-London enforces `tx.gasprice >= block.basefee`, and Chainlink's `VRFV2PlusWrapper` charges its configured overhead and premium on top of `tx.gasprice`.

`[Defeat: fulfillRandomWords]`
1. **Wrapper delivers `randomWords` with `length == 0` or `length == 2`**: Caught by `randomWords.length != 1`, which emits `VrfCallbackIgnored` and returns without reverting or changing state.
2. **Late VRF callback arrives at `block.timestamp == callbackDeadline()`**: Caught by `block.timestamp >= callbackDeadline()`, ignored cleanly so `enableRefunds()` is available at that exact timestamp.
3. **Out-of-gas during callback execution**: `fulfillRandomWords` performs no loops or external calls and writes only `winningEntry`, `resolvedAt`, and `status`, consuming <50,000 gas against `VRF_CALLBACK_GAS_LIMIT = 300_000`.

`[Defeat: enableRefunds]`
1. **Front-running `sponsor`'s pre-`endTime` cancellation (`totalEntries == 0`) with `buyEntries(attacker, 1)`**: Attacker pays `1,000,000` USDC (1 entry) before `sponsor`'s `enableRefunds()` executes. `totalEntries` becomes `1`, causing `enableRefunds()` to revert with `RefundsNotAvailable(drawRequestDeadline(), block.timestamp)` and locking the sponsor's prize NFT until `endTime + 2 days` (at zero net cost if draw is not requested, or 0.20 USDC net cost if draw is requested and `reserveEntries > 1`).
2. **Calling `enableRefunds()` after `RaffleResolved`**: Blocked because `status` is `NftWon` or `CashWon`, which reverts with `InvalidStatus(status)`.
3. **Calling `enableRefunds()` twice to overwrite `remainingRefundLiability` with `0`**: Blocked because the first call sets `status = Status.Refunding`, and the second call hits the `else` branch and reverts with `InvalidStatus(Status.Refunding)`.

`[Defeat: _settleWinningTicket]`
1. **Passing an unminted `ticketId` (e.g., `0` or `ticketCount + 1`)**: `ticketRange(ticketId)` returns `(0, 0)`, and since `winningEntry >= 1`, `selectedEntry > lastEntry` (`1 > 0`) reverts with `TicketDoesNotContainWinningEntry(ticketId, selectedEntry)`.
2. **Settling when `prizeToken` cannot be transferred in `Status.NftWon`**: `_settleWinningTicket` does not touch `prizeToken` and immediately allocates `sponsorProceeds` (95%) and `protocolFees` (5%), allowing the sponsor to withdraw 95% of buyers' USDC via `releaseSponsorProceeds()` even if `redeemWinningTicket` permanently reverts on `prizeToken.transferFrom`.
3. **Rounding dust loss across `protocolFees`, `winnerProceeds`, and `sponsorProceeds`**: Because `ENTRY_PRICE = 1,000,000` is an exact multiple of `BPS = 10,000`, `grossPot` is always a multiple of `10,000`, so `Math.mulDiv` produces zero rounding dust and `sponsorProceeds` receives the exact difference `grossPot - protocolFee - cashAmount`.

`[Defeat: redeemWinningTicket]`
1. **Winner address is blacklisted by USDC (`quoteToken`) in `Status.CashWon`**: Direct call from `winner` reverts in `_transferQuote`, but because `Raffle::_update` does not call `quoteToken`, the winner can call `raffle.transferFrom(winner, freshAddress, winningTicketId)` and call `redeemWinningTicket` from `freshAddress`.
2. **Ticket was minted or transferred to a precomputed future `Raffle` clone (`futureRaffle`) before that clone was deployed**: Once `futureRaffle` is deployed via `createRaffle`, `futureRaffle` has no function to transfer or redeem the ticket, permanently stranding the prize NFT (in `NftWon`) or `winnerProceeds` (in `CashWon`) in the raffle.
3. **Malicious or paused `prizeToken` in `Status.NftWon`**: `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` (or the subsequent `ownerOf` check) reverts, reverting the ticket burn and permanently blocking winner redemption with no fallback to `Status.Refunding`.

`[Defeat: refundTickets]`
1. **Passing duplicate `ticketIds` in the same batch (`[1, 1]`)**: First iteration burns ticket `1` (`_owners[1] = address(0)`); second iteration calls `ownerOf(1)` which reverts with `ERC721NonexistentToken(1)`.
2. **Refunding a ticket after transferring it**: `ownerOf(ticketId)` checks current ownership and `_burn(ticketId)` clears ownership, so each ticket can be refunded at most once.
3. **Buyer holds >100 tickets**: Buyer can call `refundTickets` multiple times in batches of `<= 100` tickets.

`[Defeat: releaseSponsorProceeds]`
1. **`sponsorRecipient` is blacklisted by USDC (`quoteToken`)**: `_transferQuote(sponsorRecipient, amount)` reverts in `quoteToken.safeTransfer`. Because `sponsorRecipient` is immutable per raffle with no fallback recipient, `sponsorProceeds` is stuck unless unblacklisted by Circle.
2. **`sponsorRecipient` was set to a precomputed future `Raffle` clone (`futureRaffle`) before `futureRaffle` was deployed**: Once `futureRaffle` is deployed via `createRaffle`, `_isProtocolDestination(sponsorRecipient, address(prizeToken))` in `_transferQuote` returns `true` and permanently reverts with `InvalidQuoteDestination(futureRaffle)`.
3. **Calling `releaseSponsorProceeds()` when `sponsorProceeds == 0`**: Reverts with `NoSponsorProceeds()`.

`[Defeat: releaseProtocolFees]`
1. **`protocolTreasury` is blacklisted by USDC (`quoteToken`)**: `_transferQuote(protocolTreasury, amount)` reverts in `quoteToken.safeTransfer`, locking `protocolFees` unless unblacklisted.
2. **`protocolTreasury` was set to a precomputed future `Raffle` clone (`futureRaffle`) at factory deployment**: Once `futureRaffle` is deployed, `_transferQuote` reverts with `InvalidQuoteDestination(futureRaffle)`.
3. **Calling `releaseProtocolFees()` twice**: First call zeroes `protocolFees`; second call reverts with `NoProtocolFees()`.

`[Defeat: releaseSponsorPrize]`
1. **`sponsorRecipient` was set to a precomputed future `Raffle` clone (`futureRaffle`) before `futureRaffle` was deployed**: Unlike `_transferQuote`, `releaseSponsorPrize()` does not call `_isProtocolDestination(recipient, address(prizeToken))`. When called in `Status.CashWon` or `Status.Refunding`, `prizeToken.transferFrom(address(this), futureRaffle, prizeTokenId)` succeeds and transfers the prize NFT into `futureRaffle`, where it is permanently trapped.
2. **Calling `releaseSponsorPrize()` in `Status.NftWon` when the winner never redeems**: Reverts with `SponsorPrizeUnavailable(Status.NftWon)`.
3. **Calling `releaseSponsorPrize()` twice**: First call sets `prizeClaimed = true`; second call reverts with `PrizeAlreadyClaimed()`.

---

## Phase 4 — Closing Lifecycle & Last User Out Tests (`[LastOut]`)

`[LastOut: Reserve Met (NftWon)]`
Suppose `reserveEntries = 100`, Buyer A buys 60 entries (`60,000,000` USDC, ticket 1), Buyer B buys 40 entries (`40,000,000` USDC, ticket 2), so `totalEntries = 100` and `unsettledPot = 100,000,000` USDC. VRF selects entry `75` (ticket 2, Buyer B), setting `status = Status.NftWon`.
1. Settlement allocates `protocolFees = Math.mulDiv(100,000,000, 500, 10,000) = 5,000,000` USDC, `sponsorProceeds = 100,000,000 - 5,000,000 = 95,000,000` USDC, `winnerProceeds = 0`, and `unsettledPot = 0`.
2. In any withdrawal order (`releaseProtocolFees`, `releaseSponsorProceeds`, `redeemWinningTicket`), `protocolTreasury` receives `5,000,000` USDC, `sponsorRecipient` receives `95,000,000` USDC (`5,000,000 + 95,000,000 = 100,000,000` exact USDC balance, leaving `0` shortfall), and Buyer B receives `(prizeToken, prizeTokenId)` (provided `prizeToken.transferFrom` does not revert and `sponsorRecipient`/`protocolTreasury` are not USDC-blacklisted or future clones).

`[LastOut: Reserve Missed (CashWon)]`
Suppose `reserveEntries = 100`, Buyer A buys 30 entries (`30,000,000` USDC, ticket 1), Buyer B buys 20 entries (`20,000,000` USDC, ticket 2), so `totalEntries = 50 < 100` and `unsettledPot = 50,000,000` USDC. VRF selects entry `15` (ticket 1, Buyer A), setting `status = Status.CashWon`.
1. Settlement allocates `protocolFees = Math.mulDiv(50,000,000, 500, 10,000) = 2,500,000` USDC, `winnerProceeds = Math.mulDiv(50,000,000, 8,000, 10,000) = 40,000,000` USDC, `sponsorProceeds = 50,000,000 - 2,500,000 - 40,000,000 = 7,500,000` USDC, and `unsettledPot = 0`.
2. Regardless of the order in which `redeemWinningTicket(1)`, `releaseSponsorProceeds()`, `releaseProtocolFees()`, and `releaseSponsorPrize()` are called, the USDC claims sum to `40,000,000 + 7,500,000 + 2,500,000 = 50,000,000` USDC (matching the exact contract balance with `0` shortfall), and `sponsorRecipient` receives the prize NFT back.

`[LastOut: Refund Path (Refunding)]`
Suppose Buyer A buys 1 entry (`1,000,000` USDC, ticket 1), Buyer B buys 37 entries (`37,000,000` USDC, ticket 2), and Buyer C buys 12 entries (`12,000,000` USDC, ticket 3), so `totalEntries = 50` and `unsettledPot = 50,000,000` USDC. After `drawRequestDeadline` (or `callbackDeadline`) expires, `enableRefunds()` moves `unsettledPot` (`50,000,000`) to `remainingRefundLiability` (`50,000,000`).
1. Buyer C refunds ticket 3 (`12,000,000` USDC) -> `remainingRefundLiability = 38,000,000`.
2. Buyer B refunds ticket 2 (`37,000,000` USDC) -> `remainingRefundLiability = 1,000,000`.
3. Sponsor claims prize NFT via `releaseSponsorPrize()`.
4. Buyer A (last user out) refunds ticket 1 (`1,000,000` USDC) -> `remainingRefundLiability = 0`.
The last user out is paid in full (`1,000,000` USDC) with `0` shortfall, provided no ticket was transferred to a future `Raffle` clone address before that clone's creation.

---

## Phase 5 — Saturation Sweep Summary

1. **Pattern 1 — `_isProtocolDestination` vs Precomputed Future `CREATE` Clones**:
   Checked every site that screens protocol destinations across both contracts:
   - `RaffleFactory::constructor` (`RaffleFactory.sol:80, 90`) — does not check future clone addresses for `protocolTreasury_`.
   - `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:157-169`) — checks `isRaffle[params.prizeToken]` and `isRaffle[params.sponsorRecipient]`, which is `false` for not-yet-deployed `CREATE` clone addresses.
   - `Raffle::initialize` (`Raffle.sol:187-195`) — calls `_isProtocolDestination` for `sponsor`, `protocolTreasury`, and `sponsorRecipient`, which skips `isRaffle` when `destination.code.length == 0`.
   - `Raffle::_update` (`Raffle.sol:497-502`) — calls `_isProtocolDestination(to, address(prizeToken))` on mint/transfer, which returns `false` before the future clone is deployed.
   - `Raffle::_transferQuote` (`Raffle.sol:565`) — re-checks `_isProtocolDestination` at USDC payout time (so it reverts after the future clone is deployed).
   - `Raffle::redeemWinningTicket` (`Raffle.sol:334`) and `Raffle::releaseSponsorPrize` (`Raffle.sol:404`) — do **not** call `_isProtocolDestination` at NFT payout time (so `releaseSponsorPrize` transfers the prize NFT into the now-deployed `futureRaffle` clone).
2. **Pattern 2 — Settlement / Payout Independence vs Delivery Failure**:
   Checked all terminal outcomes (`NftWon`, `CashWon`, `Refunding`) for whether one party can claim proceeds when the counterparty's asset delivery fails:
   - Only `Status.NftWon` has an asymmetric asset swap (USDC to sponsor/treasury vs `prizeToken` NFT to winner) where `releaseSponsorProceeds` and `releaseProtocolFees` can execute before `redeemWinningTicket` verifies `prizeToken` delivery.

---

## Findings and Leads

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: asymmetric-settlement-dos | group_key: Raffle | _settleWinningTicket | asymmetric-settlement-dos
smell: In Raffle.sol:543-555 and Raffle.sol:375-382, _settleWinningTicket allocates sponsorProceeds (95% of grossPot) and releaseSponsorProceeds() pays the sponsor in Status.NftWon without requiring prizeClaimed == true or verifying that prizeToken can be transferred to the winner, and Status.NftWon has no timeout fallback to Status.Refunding if redeemWinningTicket reverts.
unverified: Whether an in-scope prizeToken can revert on prizeToken.transferFrom(address(this), winner, prizeTokenId) during Status.NftWon after succeeding in RaffleFactory::createRaffle (DESIGN.md line 5 states "arbitrary prize contracts and ticket recipients are untrusted", whereas IRaffle.sol line 17 states "Supported prizes are honest, standards-compliant ERC-721s").
description: If a prizeToken is malicious, paused (e.g., ERC721Pausable), frozen, or blocks transfers from the unwhitelisted clone via a transfer validator when Status.NftWon is reached, the sponsor still claims 95% of all buyers' USDC via settleWinningTicket and releaseSponsorProceeds while redeemWinningTicket permanently reverts and buyers cannot reach Refunding.
```

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-bypass
smell: In Raffle.sol:602-604 and RaffleFactory.sol:159,166, _isProtocolDestination and _validateCreateParams only reject existing registered clones (destination.code.length != 0 && canonicalFactory.isRaffle(destination)), but RaffleFactory deploys clones deterministically via CREATE (Clones.clone) whose future addresses have code.length == 0 and isRaffle == false before creation.
unverified: How an attacker can force an honest sponsor or ticket holder (rather than the caller's own address) to use a precomputed future Raffle clone address as sponsorRecipient or ticket recipient before that clone is deployed.
description: If a precomputed future Raffle clone address is used as sponsorRecipient or ticket recipient in Raffle N and then deployed in Raffle N+1, _transferQuote in Raffle N permanently reverts with InvalidQuoteDestination (locking sponsorProceeds), any ticket held by Raffle N+1 is permanently unredeemable/unrefundable, and releaseSponsorPrize() in Raffle N (which omits _isProtocolDestination at Raffle.sol:404) transfers the prize NFT directly into Raffle N+1, violating DESIGN.md's "Never move assets between raffle clones" invariant.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: cancellation-frontrun-griefing | group_key: Raffle | enableRefunds | cancellation-frontrun-griefing
smell: In Raffle.sol:280-285, sponsor pre-endTime cancellation via enableRefunds() is permitted only when totalEntries == 0, which can be invalidated by buying a single 1-USDC entry in buyEntries.
unverified: Whether blocking pre-endTime cancellation via a 1-entry purchase is considered outside the intended "empty-raffle cancellation" design tradeoff.
description: An attacker observing a sponsor's enableRefunds() transaction in the mempool can front-run it with buyEntries(attacker, 1) for 1 USDC, causing enableRefunds() to revert and locking the sponsor's prize NFT in the clone until endTime + 2 days (up to 32 days) at zero net capital cost if no draw is requested (100% refunded via refundTickets) or 0.20 USDC net cost if a draw is requested and reserveEntries > 1 (attacker wins 80% as sole participant).
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: blacklisted-immutable-recipient-dos | group_key: Raffle | releaseSponsorProceeds | blacklisted-immutable-recipient-dos
smell: In Raffle.sol:375-392, releaseSponsorProceeds() and releaseProtocolFees() transfer USDC only to the immutable sponsorRecipient and protocolTreasury addresses with no fallback recipient or transferability, whereas ticket claims (winnerProceeds and refunds) are attached to ERC-721 tickets that can be transferred via _update even if the current owner is USDC-blacklisted.
unverified: External pre-condition that Circle blacklists sponsorRecipient or protocolTreasury on canonical USDC during the raffle lifecycle.
description: If sponsorRecipient or protocolTreasury is blacklisted on quoteToken (canonical USDC) before claiming, releaseSponsorProceeds() or releaseProtocolFees() permanently reverts in _transferQuote, stranding those USDC proceeds in the Raffle clone.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: native-refund-revert-dos | group_key: Raffle | requestDraw | native-refund-revert-dos
smell: In Raffle.sol:262-270, requestDraw() refunds excess = msg.value - paidPrice to msg.sender via a low-level call and reverts with NativeRefundFailed if msg.sender cannot accept native ETH, without allowing a separate refundRecipient parameter.
unverified: Impact on third parties, since a revert in msg.sender's receive hook only reverts the caller's own requestDraw() transaction and any EOA or payable contract can still call requestDraw().
description: Smart contract callers of requestDraw() that lack a payable receive/fallback function cannot buffer msg.value above getVrfRequestPrice() to account for block-to-block gas-price or LINK/native feed changes without reverting on the excess ETH refund.
```

