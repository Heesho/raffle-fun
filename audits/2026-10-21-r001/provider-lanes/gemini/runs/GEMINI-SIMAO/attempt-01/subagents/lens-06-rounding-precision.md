### Phase 0–4 Reasoning & Protocol Trace (Lens 6: Rounding, Precision & Scale)

[Model: createRaffle]
A sponsor supplies an ERC-721 prize token and token ID, a sponsor recipient address, a reserve entry threshold, and an exclusive sale end timestamp. The factory increments `raffleCount` by 1 to assign `raffleId`, deploys a new clone of `raffleImplementation`, initializes the clone with those parameters (`status = AwaitingPrize`), registers the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the prize NFT from the sponsor into the clone. The clone's receiver hook transitions `status` from `AwaitingPrize` to `Active`. No quote-token totals change during creation.

[Why: RaffleFactory.sol:125]
Why is `isRaffle[raffle] = true` written after `IRaffle(raffle).initialize(...)` rather than before it, and why does `_isProtocolDestination` check `destination.code.length != 0` before querying `canonicalFactory.isRaffle(destination)`?
The code assumes that a Raffle clone can only be referenced as a destination after it has already been deployed and registered in `isRaffle`, and relies on `destination == address(this)` inside `initialize()` to catch self-targeting of the currently initializing clone. That exposes the implicit assumption that future `Raffle` clone addresses cannot be predicted and supplied before deployment — whereas `Clones.clone` uses `CREATE`, making every future clone address deterministic from `(address(factory), nonce)` while `code.length == 0` and `isRaffle == false`.

[Defeat: createRaffle]
1. Sponsor calls `createRaffle` with `params.endTime = uint64(block.timestamp)` or `uint64(block.timestamp + 30 days + 1)`: rejected by `params.endTime <= currentTime` (`InvalidEndTime`) and `saleDuration > MAX_SALE_DURATION` (`SaleDurationTooLong`).
2. Sponsor calls `createRaffle` with `params.reserveEntries = 0`: rejected by `if (params.reserveEntries == 0) revert ZeroReserveEntries()` in `_validateCreateParams`.
3. Sponsor calls `createRaffle` where `params.sponsorRecipient` is set to the deterministic `CREATE` address of the next clone (`futureRaffle` at factory nonce `raffleCount + 2`): `_validateCreateParams` and `Raffle::initialize` both pass because `isRaffle[futureRaffle]` is `false` and `futureRaffle.code.length == 0` at that moment; once the next raffle is deployed at `futureRaffle`, `isRaffle[futureRaffle]` becomes `true`, causing `releaseSponsorProceeds()` on the first raffle to revert with `InvalidQuoteDestination(futureRaffle)` and `releaseSponsorPrize()` to transfer the prize NFT directly into the second raffle clone.

[Model: buyEntries]
A buyer specifies a ticket recipient and a positive `entryCount` (as `uint128`) before `endTime` while the raffle is `Active`. The buyer transfers `entryCount * 1,000,000` raw USDC units into the raffle contract. In return, the raffle advances `totalEntries` from `totalEntries` to `totalEntries + entryCount`, increments `ticketCount` by 1, records the inclusive 1-based range `[firstEntry, lastEntry]` for the new `ticketId`, adds `entryCount * 1,000,000` to `unsettledPot`, and mints `ticketId` to `recipient`.

[Why: Raffle.sol:219]
Why does `buyEntries` check `if (entryCount > type(uint128).max - totalEntries)` before computing `uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE`?
Because `totalEntries`, `firstEntry`, `lastEntry`, and `winningEntry` are stored as `uint128` to pack storage slots, while `grossAmount` and `unsettledPot` are `uint256`. Bounding cumulative `totalEntries` to `type(uint128).max` ensures `lastEntry = totalEntries + entryCount` never overflows `uint128`, `ticketCount` (which increments by 1 per purchase of `>= 1` entries) never overflows `uint128`, and `unsettledPot <= uint256(type(uint128).max) * 1_000_000` never overflows `uint256`.

[Defeat: buyEntries]
1. Attacker calls `buyEntries(recipient, 0)` to mint a zero-cost ticket with an inverted range `[totalEntries + 1, totalEntries]`: blocked by `if (entryCount == 0) revert ZeroEntryCount()` at `Raffle.sol:218`.
2. Attacker contract receives `ticketId` via `_safeMint`'s `onERC721Received` callback and attempts to reenter `buyEntries`, `enableRefunds`, or `requestDraw`: blocked by `nonReentrant` modifier on all external state-changing functions, and all state updates (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`) occur before `_safeMint`.
3. Attacker calls `buyEntries(futureRaffle, 1)` where `futureRaffle` is the deterministic `CREATE` address of the next raffle clone (`futureRaffle.code.length == 0`): `_isProtocolDestination` returns `false` and `ERC721Utils.checkOnERC721Received` skips the callback because `to.code.length == 0`, minting the ticket to an address that later becomes a registered `Raffle` clone.

[Model: requestDraw]
Any caller invokes `requestDraw()` during `[endTime, endTime + 2 days)` when `status == Active` and `totalEntries > 0`, attaching native ETH (`msg.value`) at least equal to the wrapper's quoted request price for `callbackGasLimit = 300,000` and 1 word. The raffle transitions `status` to `Drawing`, records `drawRequestedAt = uint64(block.timestamp)`, sets `_requestInFlight = true`, pays `paidPrice` in native ETH to the Chainlink VRF v2.5 wrapper to request 1 random word with 30 confirmations, records `vrfRequestId`, clears `_requestInFlight`, and refunds `msg.value - paidPrice` in native ETH to `msg.sender`. No USDC accounting totals change.

[Why: Raffle.sol:258]
Why does `requestDraw` check `if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value)` after already checking `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` at line 250?
Because `requestRandomnessPayInNative` in `VRFV2PlusWrapperConsumerBase` recomputes `requestPrice` via `i_vrfV2PlusWrapper.calculateRequestPriceNative` and sends `{value: requestPrice}` from `address(this).balance`. If `address(this).balance` had pre-existing native ETH (e.g. forced via `selfdestruct` or sent before clone deployment) and the wrapper returned a higher `paidPrice` than `msg.value`, `msg.value - paidPrice` at line 262 would underflow without the explicit `paidPrice > msg.value` check.

[Defeat: requestDraw]
1. Attacker sends native ETH directly to `Raffle` to desynchronize native balance accounting: rejected by `receive() external payable { revert DirectNativeTransfer(); }`.
2. Malicious caller contract invokes `requestDraw` with `msg.value > paidPrice` and attempts to reenter `Raffle` from its `receive()` hook during the `excess` ETH refund at `Raffle.sol:267`: blocked by `nonReentrant` on `requestDraw` and all other state-changing functions, while `rawFulfillRandomWords` is restricted to `msg.sender == address(i_vrfV2PlusWrapper)`.
3. Attacker calls `requestDraw` at `block.timestamp == drawRequestDeadline()` (`endTime + 2 days`): rejected by `if (block.timestamp >= requestDeadline) revert DrawRequestWindowExpired(requestDeadline, block.timestamp)`.

[Model: fulfillRandomWords]
The Chainlink VRF wrapper calls `rawFulfillRandomWords(requestId, randomWords)`, which verifies `msg.sender == address(i_vrfV2PlusWrapper)` and delegates to `fulfillRandomWords`. If `_requestInFlight` is false, `status == Drawing`, `requestId == vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < drawRequestedAt + 2 days`, the raffle computes `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`, records `resolvedAt = uint64(block.timestamp)`, and transitions `status` to `NftWon` if `totalEntries >= reserveEntries` or `CashWon` if `totalEntries < reserveEntries`. No token balances or quote-token totals move during callback fulfillment.

[Why: Raffle.sol:518]
Why is `uint128((randomWords[0] % uint256(totalEntries)) + 1)` guaranteed not to divide by zero or overflow `uint128`?
Because `status == Status.Drawing` is only reachable via `requestDraw()`, which requires `totalEntries != 0` (`NoEntriesSold`), and `buyEntries()` enforces `totalEntries <= type(uint128).max`. Thus `randomWords[0] % uint256(totalEntries)` lies in `[0, totalEntries - 1]`, and adding 1 yields a value in `[1, totalEntries] <= type(uint128).max`.

[Defeat: fulfillRandomWords]
1. Wrapper delivers callback at `block.timestamp == callbackDeadline()` (`drawRequestedAt + 2 days`): `block.timestamp >= callbackDeadline()` evaluates to `true`, emitting `VrfCallbackIgnored` and returning without state changes so `enableRefunds()` can proceed at the exact same timestamp.
2. Wrapper delivers duplicate callback after raffle already resolved to `NftWon` or `CashWon`: `status != Status.Drawing` evaluates to `true`, emitting `VrfCallbackIgnored` and returning harmlessly.
3. Wrapper delivers callback with `randomWords.length == 0` or `randomWords.length == 2`: `randomWords.length != 1` evaluates to `true`, emitting `VrfCallbackIgnored` and returning without reverting the VRF transaction.

[Model: _settleWinningTicket]
Any caller supplies a `ticketId` when `status` is `NftWon` or `CashWon` and `settlementComplete` is `false`. The function verifies that `winningEntry` lies within `_ticketRanges[ticketId]`, reads `grossPot = unsettledPot`, computes `protocolFee = floor(grossPot * 500 / 10,000)`, and in `NftWon` sets `sponsorAmount = grossPot - protocolFee` (`winnerProceeds = 0`), or in `CashWon` computes `cashAmount = floor(grossPot * 8,000 / 10,000)` and sets `sponsorAmount = grossPot - protocolFee - cashAmount` and `winnerProceeds = cashAmount`. It sets `settlementComplete = true`, `winningTicketId = ticketId`, `unsettledPot = 0`, `sponsorProceeds = sponsorAmount`, and `protocolFees = protocolFee`.

[Why: Raffle.sol:540]
Why can `Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS)` and `Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS)` never lose even 1 wei to floor rounding?
Because `grossPot` is always an integer multiple of `ENTRY_PRICE = 1_000_000`, and `RaffleConstants.BPS = 10_000` divides `1_000_000` evenly (`1_000_000 / 10_000 = 100`). Every single entry contributes exactly `50,000` raw USDC units to `protocolFee` and (in `CashWon`) `800,000` raw USDC units to `cashAmount`, so both divisions are always exact with zero remainder for every possible `totalEntries >= 1`.

[Defeat: _settleWinningTicket]
1. Attacker calls `settleWinningTicket(0)` (an unminted ticket ID where `firstEntry == 0` and `lastEntry == 0`): since `winningEntry >= 1`, `selectedEntry > lastEntry` (`1 > 0`) triggers `TicketDoesNotContainWinningEntry(0, winningEntry)`.
2. Attacker calls `settleWinningTicket(nonWinningTicketId)` to misallocate `winningTicketId`: since minted ticket ranges form a disjoint contiguous partition of `[1, totalEntries]`, every `nonWinningTicketId` fails `selectedEntry < firstEntry || selectedEntry > lastEntry`.
3. Attacker calls `settleWinningTicket(winningTicketId)` a second time to re-allocate proceeds: blocked by `if (settlementComplete) revert SettlementAlreadyComplete()`.

[Model: redeemWinningTicket]
The current owner of `winningTicketId` calls `redeemWinningTicket(ticketId)` when `status` is `NftWon` or `CashWon` and `winnerRedeemed` is `false`. If `settlementComplete` is `false`, it settles `ticketId` first; otherwise it verifies `ticketId == winningTicketId`. It checks `msg.sender == ownerOf(ticketId)`, records `winnerRecipient = winner` and `winnerRedeemed = true`, and burns `ticketId`. If `status == NftWon`, it sets `prizeClaimed = true`, transfers `prizeTokenId` to `winner`, and verifies `prizeToken.ownerOf(prizeTokenId) == winner`. If `status == CashWon`, it zeroes `winnerProceeds` and transfers `cashAmount` USDC to `winner`.

[Defeat: redeemWinningTicket]
1. Non-owner calls `redeemWinningTicket(winningTicketId)`: blocked by `if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner)`.
2. Winner is USDC-blocklisted in `CashWon` (or blocked by `prizeToken` in `NftWon`): because `settleWinningTicket` does not lock `winnerRecipient` and `_update` allows transfers in `NftWon`/`CashWon` prior to `_burn`, the winner can call `transferFrom(winner, alternateAddress, winningTicketId)` and redeem from `alternateAddress`.
3. Untrusted `prizeToken` attempts to silently skip transferring the NFT in `transferFrom` without reverting: caught by `if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner)`.

[Model: enableRefunds]
When a raffle has no entries sold (`totalEntries == 0` and `msg.sender == sponsor || block.timestamp >= endTime`), or draw was not requested in time (`status == Active`, `totalEntries > 0`, `block.timestamp >= endTime + 2 days`), or VRF callback did not arrive in time (`status == Drawing`, `block.timestamp >= drawRequestedAt + 2 days`), `enableRefunds()` moves the entire `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and transitions `status` to `Refunding`.

[Model: refundTickets]
In `Status.Refunding`, a ticket owner passes an array of 1 to 100 `ticketIds` they own. For each `ticketId`, the contract verifies `msg.sender == ownerOf(ticketId)`, adds `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns `ticketId`. After the loop, it computes `amount = aggregateEntries * 1,000,000`, subtracts `amount` from `remainingRefundLiability`, and transfers `amount` USDC to `msg.sender`.

[Defeat: refundTickets]
1. Attacker passes duplicate `[ticketId, ticketId]` in `ticketIds` to claim double refund: the first iteration calls `_burn(ticketId)` (setting `_owners[ticketId] = address(0)`), so the second iteration reverts inside `ownerOf(ticketId)` with `ERC721NonexistentToken(ticketId)`.
2. Attacker passes unminted `ticketId` (where `firstEntry == 0, lastEntry == 0` would underflow `lastEntry - firstEntry` if reached): `ownerOf(ticketId)` is executed before `ticketRange(ticketId)` and reverts with `ERC721NonexistentToken(ticketId)`.
3. Attacker passes 101 tickets in one call: rejected by `if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) revert InvalidTicketBatchSize(...)`.

[Model: releaseSponsorProceeds]
Any caller invokes `releaseSponsorProceeds()` after settlement when `sponsorProceeds > 0`. The contract caches `amount = sponsorProceeds`, sets `sponsorProceeds = 0`, and transfers `amount` USDC to `sponsorRecipient`.

[Model: releaseProtocolFees]
Any caller invokes `releaseProtocolFees()` after settlement when `protocolFees > 0`. The contract caches `amount = protocolFees`, sets `protocolFees = 0`, and transfers `amount` USDC to `protocolTreasury`.

[Model: releaseSponsorPrize]
Any caller invokes `releaseSponsorPrize()` when `status` is `CashWon` or `Refunding` and `prizeClaimed` is `false`. The contract sets `prizeClaimed = true`, transfers `prizeTokenId` from the raffle to `sponsorRecipient`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

[LastOut: Reserve Met (NftWon)]
Suppose `reserveEntries = 3`. Buyer 1 buys 1 entry (`1,000,000` USDC, ticket 1 `[1,1]`) and Buyer 2 buys 2 entries (`2,000,000` USDC, ticket 2 `[2,3]`). `unsettledPot = 3,000,000` USDC. After VRF resolves to `NftWon` with `winningEntry = 2`, `_settleWinningTicket(2)` allocates `protocolFees = 150,000` USDC and `sponsorProceeds = 2,850,000` USDC (`150,000 + 2,850,000 == 3,000,000`). In any withdrawal order (`releaseProtocolFees`, `releaseSponsorProceeds`, `redeemWinningTicket`), the last party out receives their exact full entitlement (`150,000` USDC, `2,850,000` USDC, and `prizeTokenId` respectively), leaving `0` shortfall and `0` leftover dust.

[LastOut: Reserve Missed (CashWon)]
Suppose `reserveEntries = 5`. Buyer 1 buys 1 entry (`1,000,000` USDC, ticket 1 `[1,1]`) and Buyer 2 buys 2 entries (`2,000,000` USDC, ticket 2 `[2,3]`). `unsettledPot = 3,000,000` USDC. After VRF resolves to `CashWon` with `winningEntry = 1`, `_settleWinningTicket(1)` allocates `protocolFees = 150,000` USDC, `winnerProceeds = 2,400,000` USDC, and `sponsorProceeds = 450,000` USDC (`150,000 + 2,400,000 + 450,000 == 3,000,000`). In any withdrawal order (`releaseSponsorPrize`, `releaseProtocolFees`, `releaseSponsorProceeds`, `redeemWinningTicket`), the last party out is paid in full with `0` shortfall and `0` leftover dust.

[LastOut: Refund Path (Refunding)]
Suppose Buyer 1 buys 1 entry (`1,000,000` USDC, ticket 1 `[1,1]`) and Buyer 2 buys 2 entries (`2,000,000` USDC, ticket 2 `[2,3]`). `enableRefunds()` sets `remainingRefundLiability = 3,000,000` USDC. When Buyer 2 refunds ticket 2 (`2,000,000` USDC), `remainingRefundLiability` becomes `1,000,000` USDC; when Buyer 1 refunds ticket 1 (`1,000,000` USDC), `remainingRefundLiability` becomes `0` USDC; and `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`. The last user out is paid in full with `0` shortfall.

---

### Audit Output Blocks

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: deterministic-clone-address-bypass | group_key: Raffle | _isProtocolDestination | deterministic-clone-address-bypass
smell: `RaffleFactory::createRaffle` deploys clones via `Clones.clone` (`CREATE`), so future clone addresses (`futureRaffle`) are deterministic from `(address(factory), nonce)` and have `code.length == 0` and `isRaffle[futureRaffle] == false` prior to creation, bypassing `_isProtocolDestination` in `Raffle::initialize` and `Raffle::_update` as well as `RaffleFactory::_validateCreateParams`.
unverified: A third-party victim who loses funds involuntarily without having chosen `futureRaffle` as their own `sponsorRecipient`, `protocolTreasury`, or ticket recipient.
description: If a precomputed `futureRaffle` address is used as `sponsorRecipient` or ticket recipient before that clone is created and `futureRaffle` is subsequently deployed, `_transferQuote` will revert with `InvalidQuoteDestination(futureRaffle)` (permanently locking USDC liabilities in the earlier raffle) while `releaseSponsorPrize` (which lacks an `_isProtocolDestination` check) will transfer the prize NFT directly into `futureRaffle` where it cannot be rescued.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: unsafe-erc721-transfer-to-contract | group_key: Raffle | releaseSponsorPrize | unsafe-erc721-transfer-to-contract
smell: `Raffle::redeemWinningTicket` (`Raffle.sol:334`) and `Raffle::releaseSponsorPrize` (`Raffle.sol:404`) deliver the prize NFT via `prizeToken.transferFrom` instead of `safeTransferFrom`, verifying only `prizeToken.ownerOf(prizeTokenId) == recipient`.
unverified: Whether any target integration or smart contract wallet used as `sponsorRecipient` or `winner` requires an `onERC721Received` callback to credit or unlock incoming ERC-721 assets.
description: Using `transferFrom` avoids `onERC721Received` reentrancy and griefing on prize delivery, but smart contract recipients that rely on `IERC721Receiver.onERC721Received` to update internal accounting will receive the NFT without the callback firing.
```

