### Phase 0 & 1 — Vocabulary, Tracked Totals, and Model Walkthrough

In `raffle.fun`, each `Raffle` clone is an ERC-1167 minimal proxy created by `RaffleFactory` that escrows one ERC-721 `prizeTokenId` and sells `ENTRY_PRICE` (`1_000_000` raw units of 6-decimal `quoteToken` USDC) entries. Each purchase mints one sequential ERC-721 ticket (`ticketId`) whose claim is defined by `_ticketRanges[ticketId] = TicketRange(firstEntry, lastEntry)` covering `entryCount = lastEntry - firstEntry + 1` entries.

Let us model every function that moves value or writes a tracked total:

`[Model: RaffleFactory::createRaffle]`
A sponsor supplies a prize NFT and raffle configuration (`sponsorRecipient`, `prizeToken`, `prizeTokenId`, `reserveEntries`, `endTime`). The factory increments `raffleCount` by 1, deploys a clone of `raffleImplementation`, initializes the clone, records the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the sponsor's `prizeTokenId` into the clone, activating it for entry sales.

`[Model: Raffle::initialize]`
The factory configures a freshly deployed clone once by setting `initialized = true`, storing the sponsor, payout recipients (`sponsorRecipient`, `protocolTreasury`), prize identifier (`prizeToken`, `prizeTokenId`), `raffleId`, `reserveEntries`, and `endTime`, and setting `status` to `AwaitingPrize`.

`[Model: Raffle::onERC721Received]`
When the configured `prizeToken` transfers `prizeTokenId` from `sponsor` with `factory` as operator while `status` is `AwaitingPrize`, the raffle transitions `status` from `AwaitingPrize` to `Active` so entries can be purchased.

`[Model: Raffle::buyEntries]`
A buyer gives `entryCount * 1,000,000` units of USDC (`quoteToken`) and receives a newly minted ERC-721 ticket (`ticketId = ticketCount + 1`) assigned to `recipient`. The raffle increases `totalEntries` by `entryCount`, increments `ticketCount` by 1, records `[totalEntries_before + 1, totalEntries_after]` in `_ticketRanges[ticketId]`, and increases `unsettledPot` by `entryCount * 1,000,000`.

`[Model: Raffle::requestDraw]`
After `endTime` and before `endTime + 2 days` (when `totalEntries > 0`), a caller gives native ETH at least equal to the Chainlink VRF wrapper quote. The raffle sets `status` to `Drawing`, records `drawRequestedAt = block.timestamp` and `vrfRequestId`, pays `paidPrice` in native ETH to `i_vrfV2PlusWrapper`, and returns `msg.value - paidPrice` in native ETH to the caller.

`[Model: Raffle::fulfillRandomWords]`
Before `drawRequestedAt + 2 days`, the Chainlink VRF wrapper supplies one random word. The raffle selects `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and transitions `status` from `Drawing` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`).

`[Model: Raffle::enableRefunds]`
When a raffle expires with zero entries (or is cancelled early by `sponsor` with zero entries), misses its 2-day draw request window, or misses its 2-day VRF callback window, the caller moves the entire `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status` to `Refunding`.

`[Model: Raffle::_settleWinningTicket]`
Once `status` is `NftWon` or `CashWon`, any caller supplies the `ticketId` whose `_ticketRanges[ticketId]` contains `winningEntry`. No tokens move; the raffle sets `settlementComplete = true`, records `winningTicketId = ticketId`, zeroes `unsettledPot`, and splits the former `unsettledPot` into `protocolFees` (5% rounded down), `winnerProceeds` (0 in `NftWon`, 80% rounded down in `CashWon`), and `sponsorProceeds` (the exact remainder: 95% in `NftWon`, 15% plus any rounding remainder in `CashWon`).

`[Model: Raffle::redeemWinningTicket]`
The current owner of `winningTicketId` surrenders and burns `winningTicketId` (settling it first if `settlementComplete` is still false). The raffle records `winnerRecipient = winner` and `winnerRedeemed = true`. If `status` is `NftWon`, the raffle sets `prizeClaimed = true` and transfers `prizeTokenId` to `winner`; if `status` is `CashWon`, the raffle zeroes `winnerProceeds` and transfers that USDC amount to `winner`.

`[Model: Raffle::refundTickets]`
In `Refunding`, a ticket owner surrenders a batch of 1 to 100 owned tickets. Each ticket is burned, its entry span `lastEntry - firstEntry + 1` is summed into `aggregateEntries`, `remainingRefundLiability` is reduced by `aggregateEntries * 1,000,000`, and that exact USDC amount is transferred to `msg.sender`.

`[Model: Raffle::releaseSponsorProceeds]`
Any caller triggers payout of the settled `sponsorProceeds` claim. The raffle zeroes `sponsorProceeds` and transfers that USDC amount to `sponsorRecipient`.

`[Model: Raffle::releaseProtocolFees]`
Any caller triggers payout of the settled `protocolFees` claim. The raffle zeroes `protocolFees` and transfers that USDC amount to `protocolTreasury`.

`[Model: Raffle::releaseSponsorPrize]`
In `CashWon` or `Refunding`, any caller triggers return of the escrowed NFT. The raffle sets `prizeClaimed = true` and transfers `prizeTokenId` to `sponsorRecipient`.

`[Model: Raffle::_update]`
Whenever a ticket is minted, transferred, or burned, `_update` blocks any non-zero recipient that matches `_isProtocolDestination` and updates ERC-721 owner and balance mappings.

`[Model: Raffle::_transferQuote]`
Whenever USDC is paid out (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`), `_transferQuote` blocks any recipient matching `_isProtocolDestination` and transfers `amount` of `quoteToken` to `to`.

---

### Phase 2 & 3 — Drilling Non-Obvious Lines (`[Why]` & `[Defeat]`)

`[Why: packages/contracts/src/Raffle.sol:152]`
Why are `_ticketRanges[ticketId]` entries retained in storage after `_burn(ticketId)` in `refundTickets` and `redeemWinningTicket` instead of being deleted, and what implicit belief prevents a burned ticket's range from being reused?
The code rests on the belief that every value-extracting path checks live ERC-721 ownership (`ownerOf(ticketId)`) before reading `ticketRange(ticketId)`, or is guarded by a one-time state flag (`settlementComplete`, `winnerRedeemed`). Specifically, in `refundTickets` (`Raffle.sol:372`), `ownerOf(ticketId)` reverts with `ERC721NonexistentToken` on any burned ticket before `ticketRange(ticketId)` is summed; in `_settleWinningTicket` (`Raffle.sol:551`), `ownerOf` is not checked, but no ticket can be burned before `status` reaches `NftWon` or `CashWon` because `_burn` is only reachable in `redeemWinningTicket` (which settles first) or `refundTickets` (which requires `status == Refunding`).

`[Why: packages/contracts/src/Raffle.sol:267]`
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and clear it after storing `vrfRequestId`?
It rests on the belief that if the VRF wrapper (or a mock/test wrapper) synchronously invokes `rawFulfillRandomWords` inside `requestRandomWordsInNative` before `vrfRequestId = requestId` is written at `Raffle.sol:272`, `vrfRequestId` would still be `0` (or `_requestInFlight` prevents premature resolution before `requestDraw` finishes state updates).

`[Why: packages/contracts/src/Raffle.sol:327]`
Why is `_settleWinningTicket(ticketId)` decoupled from `redeemWinningTicket(ticketId)` so that anyone can settle liabilities without owning `winningTicketId` or delivering `prizeTokenId`?
It rests on the belief that if `sponsorProceeds` and `protocolFees` depended on the winning ticket owner calling `redeemWinningTicket`, a negligent or extortionate winner could refuse to redeem and freeze the sponsor's 95% (or 15%) USDC proceeds and the treasury's 5% fee forever—and simultaneously assumes that `prizeToken.transferFrom(address(this), winner, prizeTokenId)` will always succeed when the winner later calls `redeemWinningTicket`.

`[Why: packages/contracts/src/Raffle.sol:347]`
Why do `redeemWinningTicket` (`Raffle.sol:347`) and `releaseSponsorPrize` (`Raffle.sol:417`) use `prizeToken.transferFrom` instead of `safeTransferFrom`, and why do they omit `_isProtocolDestination`?
They use `transferFrom` so that a recipient contract without `IERC721Receiver` cannot revert prize delivery, and they implicitly assume `initialize` and `_update` already prevented `sponsorRecipient` and `winner` from being protocol destinations at configuration/transfer time.

`[Why: packages/contracts/src/Raffle.sol:615]`
Why does `_isProtocolDestination` gate `canonicalFactory.isRaffle(destination)` behind `destination.code.length != 0`, and why does `RaffleFactory.sol:739` deploy clones via `Clones.clone` (`CREATE`)?
The code assumes a `Raffle` clone can only be referenced as a destination after it has already been deployed and registered in `isRaffle`. However, `Clones.clone` uses `CREATE`, whose future deployment addresses are deterministically computable from `(address(factory), nonce)` while `destination.code.length == 0` and `isRaffle[destination] == false`.

Now let us attempt to defeat the protocol's guards:

`[Defeat: _isProtocolDestination]`
1. **Precomputed next-clone `CREATE` address (`futureClone = computeCreateAddress(factory, nextNonce)`):** Before Raffle #2 is created, `futureClone.code.length == 0` and `factory.isRaffle(futureClone) == false`. Passing `futureClone` as `sponsorRecipient` in `createRaffle` (Raffle #1) or as `recipient` in `buyEntries(futureClone, 1)` passes both `_validateCreateParams` and `_isProtocolDestination` (and `_safeMint` skips `onERC721Received` because `futureClone.code.length == 0`). Once Raffle #2 is created at `futureClone`, `isRaffle[futureClone]` becomes `true`: in Raffle #1, `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(futureClone)`, while `releaseSponsorPrize()` (which omits `_isProtocolDestination` and uses `transferFrom`) transfers Raffle #1's prize NFT into Raffle #2 (`futureClone`).
2. **Same-clone address during `createRaffle` (`params.sponsorRecipient = computeCreateAddress(factory, currentNonce)`):** Passes `RaffleFactory._validateCreateParams` (`isRaffle` is still `false` at line 799 before `Clones.clone`), deploys the clone at `params.sponsorRecipient`, and is then caught inside `Raffle.initialize` (`Raffle.sol:206`) only because `_isProtocolDestination` checks `destination == address(this)`.
3. **Setting `params.prizeToken = protocolTreasury` in `createRaffle`:** Passes `RaffleFactory._validateCreateParams` (which forgets to check `params.prizeToken == protocolTreasury`), and is caught in `Raffle.initialize` (`Raffle.sol:203`) because `_isProtocolDestination(params.protocolTreasury, params.prizeToken)` checks `destination == prizeToken_`.

`[Defeat: _settleWinningTicket]`
1. **Settling with an unminted `ticketId = 0` or `ticketId = 999`:** `ticketRange(ticketId)` returns `(0, 0)`. Since `winningEntry >= 1` in `NftWon`/`CashWon`, `selectedEntry > lastEntry` (`1 > 0`) triggers `TicketDoesNotContainWinningEntry`.
2. **Rounding loss across `protocolFee`, `cashAmount`, and `sponsorAmount`:** Every entry costs `ENTRY_PRICE = 1_000_000`, which is an exact multiple of `BPS = 10_000` (`1_000_000 / 10_000 = 100`). Thus `protocolFee = totalEntries * 50_000` and `cashAmount = totalEntries * 800_000` never even leave fractional dust, and `sponsorAmount = grossPot - protocolFee - cashAmount` conserves 100% of `grossPot`.
3. **Sponsor settling and claiming 95% USDC in `NftWon` when `prizeToken` delivery reverts:** Because `_settleWinningTicket` is storage-only and `releaseSponsorProceeds()` does not require `prizeClaimed == true`, a sponsor whose `prizeToken` reverts on `transferFrom(raffle, winner, prizeTokenId)` (an untrusted ERC-721 or a paused/frozen/blacklisted ERC-721) still extracts `95%` of `unsettledPot` while `redeemWinningTicket` reverts for the winner.

`[Defeat: redeemWinningTicket]`
1. **Settling with `ticketId = 1` then calling `redeemWinningTicket(2)`:** Blocked by `else if (ticketId != winningTicketId) revert WinningTicketMismatch(ticketId, winningTicketId)` at `Raffle.sol:329`.
2. **Reentering `redeemWinningTicket` from `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`:** Blocked by `nonReentrant` as well as `winnerRedeemed = true`, `prizeClaimed = true`, and `_burn(ticketId)` all being written before `prizeToken.transferFrom`.
3. **Transferring `winningTicketId` after `settleWinningTicket(winningTicketId)`:** `settleWinningTicket` only records `winningTicketId`, not `winnerRecipient`. When `ticketId` is transferred from `0xA11ce` to `0xB0b`, `redeemWinningTicket` reads current `ownerOf(ticketId) == 0xB0b`, requires `msg.sender == 0xB0b`, burns from `0xB0b`, and pays `0xB0b`.

`[Defeat: refundTickets]`
1. **Passing duplicate `[ticketId, ticketId]` in one `refundTickets` call:** Iteration 0 calls `_burn(ticketId)`, setting `_owners[ticketId] = address(0)`. Iteration 1 calls `ownerOf(ticketId)`, which reverts with `ERC721NonexistentToken(ticketId)`.
2. **Refunding a ticket then calling `settleWinningTicket` with its preserved `_ticketRanges[ticketId]`:** Impossible because `refundTickets` requires `status == Status.Refunding`, which is a terminal state from which `status` can never transition to `NftWon` or `CashWon`.
3. **Batch size griefing (`ticketIds.length > 100`):** Each user submits only their own `ticketIds` in batches of up to `100`, so another user minting 10,000 tickets cannot DoS a victim's `refundTickets` call.

`[Defeat: buyEntries]`
1. **Overflowing `totalEntries` (`uint128`) or `grossAmount` (`uint256`):** `entryCount > type(uint128).max - totalEntries` reverts with `TotalEntriesOverflow`, and `uint256(type(uint128).max) * 1_000_000 < 2^148 < type(uint256).max`.
2. **Reentering `Raffle` during `_safeMint` -> `recipient.onERC721Received`:** `nonReentrant` blocks all state-changing raffle functions except ERC-721 `transferFrom`/`approve`, and `_owners[ticketId]`, `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are already updated before `_safeMint`.
3. **Buying at `block.timestamp == endTime`:** Blocked by `if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp)`.

`[Defeat: releaseSponsorPrize]`
1. **Calling `releaseSponsorPrize` twice in `CashWon` or `Refunding`:** Blocked by `if (prizeClaimed) revert PrizeAlreadyClaimed()` and `prizeClaimed = true` before `prizeToken.transferFrom`.
2. **Calling `releaseSponsorPrize` when `status == Status.NftWon`:** Blocked by `if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) revert SponsorPrizeUnavailable(currentStatus)`.
3. **Calling `releaseSponsorPrize` when `sponsorRecipient` is a future `Raffle` clone deployed after Raffle #1 was initialized:** Because `releaseSponsorPrize` does not call `_isProtocolDestination(recipient, address(prizeToken))` and uses `prizeToken.transferFrom` (bypassing `Raffle.onERC721Received`), it succeeds and transfers `prizeTokenId` into the other `Raffle` clone.

---

### Phase 3 & 4 — Lifecycle Walkthroughs & Last User Out Tests (`[LastOut]`)

`[LastOut: Creation & Escrow]`
Sponsor calls `RaffleFactory::createRaffle`. The clone is initialized (`status = AwaitingPrize`), registered in factory mappings, and receives `prizeTokenId` via `safeTransferFrom`, transitioning `status` to `Active`. No quote tokens are held (`accountedQuoteBalance() == 0`). If 0 entries are sold, the sponsor (before `endTime`) or anyone (at `>= endTime`) calls `enableRefunds()` (`remainingRefundLiability = 0`) and `releaseSponsorPrize()`, returning `prizeTokenId` to `sponsorRecipient` with 0 shortfall.

`[LastOut: Entry Purchase]`
Buyers $1 \dots k$ purchase $e_1 \dots e_k$ entries. `totalEntries = \sum e_i`, `unsettledPot = \sum e_i \times 10^6`, and `quoteToken.balanceOf(address(this)) == unsettledPot`. Ticket ranges partition $[1, \text{totalEntries}]$ without gaps or overlaps.

`[LastOut: Draw & Resolution]`
Caller invokes `requestDraw()` with `msg.value >= quotedFee`. `paidPrice` is forwarded to `i_vrfV2PlusWrapper` and `msg.value - paidPrice` is refunded to `msg.sender`, leaving the contract's native ETH and USDC balances intact. `rawFulfillRandomWords` selects `winningEntry` in $[1, \text{totalEntries}]$ and sets `status` to `NftWon` or `CashWon`.

`[LastOut: Settlement & Claims]`
In `NftWon` or `CashWon`, `_settleWinningTicket` moves `grossPot = unsettledPot` into `protocolFees = \lfloor grossPot \times 500 / 10000 \rfloor`, `winnerProceeds` ($0$ in `NftWon`, $\lfloor grossPot \times 8000 / 10000 \rfloor$ in `CashWon`), and `sponsorProceeds = grossPot - protocolFees - winnerProceeds`. Because `grossPot + 0 == protocolFees + winnerProceeds + sponsorProceeds == quoteToken.balanceOf(address(this))`, when `redeemWinningTicket`, `releaseSponsorProceeds`, and `releaseProtocolFees` execute in any order, the last claimant out receives their exact allocation down to the last wei of USDC (`accountedQuoteBalance()` drops to `0` and `quoteToken.balanceOf(address(this))` drops to `0`), provided `to` has not become a blocked protocol destination and `prizeToken.transferFrom` does not revert.

`[LastOut: Refund Lifecycle]`
When `enableRefunds()` executes, `remainingRefundLiability = unsettledPot = \text{totalEntries} \times 10^6` and `unsettledPot = 0`. Because the minted tickets partition $[1, \text{totalEntries}]$, $\sum_{t=1}^{\text{ticketCount}} (\text{lastEntry}_t - \text{firstEntry}_t + 1) \times 10^6 == \text{remainingRefundLiability}$. As each ticket owner calls `refundTickets` in any order, `remainingRefundLiability` decreases by their exact entry value, and the last ticket owner out receives 100% of their `entryCount * 1_000_000` USDC with zero shortfall (`remainingRefundLiability == 0`), while `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.

---

### Phase 5 — Findings and Leads

```
FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: decoupled-settlement-claim | group_key: Raffle | releaseSponsorProceeds | decoupled-settlement-claim
root_cause: In Raffle.sol:556-568 (_settleWinningTicket) and Raffle.sol:388-395 (releaseSponsorProceeds), sponsorProceeds and protocolFees in Status.NftWon are credited and released without requiring prizeClaimed == true or providing a refund fallback if prizeToken delivery in redeemWinningTicket (Raffle.sol:347-350) reverts.
internal_pre: None
external_pre: prizeToken reverts or fails ownership verification on outbound transferFrom(address(this), winner, prizeTokenId) during Status.NftWon (either because prizeToken is an untrusted sponsor-deployed contract per DESIGN.md that blocks transfers after initial escrow, or because a pausable/upgradeable/blacklistable ERC-721 pauses or restricts transfers while in escrow).
path:
  1. Sponsor deploys or uses an ERC-721 contract `prizeToken` (`0xBeeF...`) that succeeds on the first `safeTransferFrom(sponsor, raffle, 1)` during `RaffleFactory::createRaffle` (with `reserveEntries = 100`) but reverts on subsequent transfers from `raffle` (or gets paused while escrowed).
  2. Honest buyers call `buyEntries` to purchase 100 entries for `100_000_000` USDC (100 USDC), setting `totalEntries = 100` and `unsettledPot = 100_000_000`.
  3. After `endTime`, `requestDraw()` and `rawFulfillRandomWords()` execute; because `totalEntries (100) >= reserveEntries (100)`, `status` transitions to `Status.NftWon`.
  4. Sponsor calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()`, which sets `sponsorProceeds = 95_000_000` and transfers `95_000_000` USDC (95 USDC) to `sponsorRecipient` without touching `prizeToken`.
  5. Winning ticket owner calls `redeemWinningTicket(winningTicketId)`, which reverts at `Raffle.sol:347` (`prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`) or `Raffle.sol:348` (`PrizeDeliveryVerificationFailed`).
impact: The winning ticket owner permanently loses the won NFT and cannot recover their USDC (and ticket buyers lose the entire `100_000_000` USDC pot), while `sponsorRecipient` extracts 95% of `grossSales` (`95_000_000` USDC) and `protocolTreasury` extracts 5% (`5_000_000` USDC) without the prize ever being delivered.
mitigation: In Status.NftWon, either escrow `prizeTokenId` out of `Raffle` during `_settleWinningTicket` / require `prizeClaimed` before `releaseSponsorProceeds` and `releaseProtocolFees` can be claimed, or allow transitioning to `Status.Refunding` before `sponsorProceeds`/`protocolFees` are released if `prizeToken.transferFrom` fails.
```

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-bypass
smell: In Raffle.sol:615, `_isProtocolDestination` only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`, while `RaffleFactory.sol:739` deploys clones via `Clones.clone` (`CREATE`) at deterministic future addresses where `code.length == 0` and `isRaffle == false` prior to creation; furthermore, `releaseSponsorPrize` (Raffle.sol:417) and `redeemWinningTicket` (Raffle.sol:347) use raw `prizeToken.transferFrom` without checking `_isProtocolDestination`.
unverified: Whether an attacker can induce an honest victim (rather than the caller/sponsor themselves) to specify a precomputed future `Raffle` clone address as `sponsorRecipient` or ticket `recipient`.
description: Precomputing the next `RaffleFactory` `CREATE` clone address (`futureRaffle`) allows setting `sponsorRecipient = futureRaffle` or minting/transferring tickets to `futureRaffle` before `futureRaffle` is deployed, which subsequently bricks `releaseSponsorProceeds()` / `refundTickets()` with `InvalidQuoteDestination(futureRaffle)` and causes `releaseSponsorPrize()` to transfer `prizeTokenId` directly into `futureRaffle`.
```

```
LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: unsafe-erc721-prize-transfer | group_key: Raffle | redeemWinningTicket | unsafe-erc721-prize-transfer
smell: `redeemWinningTicket` (Raffle.sol:347) and `releaseSponsorPrize` (Raffle.sol:417) deliver `prizeTokenId` using `prizeToken.transferFrom` instead of `safeTransferFrom`, whereas `buyEntries` (Raffle.sol:248) uses `_safeMint`.
unverified: Whether an external smart contract ticket owner or `sponsorRecipient` vault in the target deployment environment relies on `onERC721Received` callbacks to track incoming ERC-721 prize tokens.
description: Using `prizeToken.transferFrom` instead of `safeTransferFrom` in `redeemWinningTicket` and `releaseSponsorPrize` bypasses `IERC721Receiver.onERC721Received` on contract recipients, which can strand the prize NFT inside recipient contracts that require the ERC-721 receiver hook to register deposits.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: vrf-gas-price-griefing | group_key: Raffle | requestDraw | vrf-gas-price-griefing
smell: `requestDraw` (Raffle.sol:253-273) is permissionless, can only be called once (`status = Status.Drawing`), and prices the native VRF request via `VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative`, which computes `requestPrice` from the caller's `tx.gasprice` with no minimum gas price floor or retry path.
unverified: Whether the target chain's Chainlink VRF v2.5 wrapper and off-chain fulfillment nodes will delay fulfillment for the full `DRAW_CALLBACK_TIMEOUT = 2 days` when a request is submitted at a manipulated/minimal `tx.gasprice` right before a gas spike.
description: A regretful sponsor (when `totalEntries >= reserveEntries` and the NFT floor price rose) or losing-odds buyer can call `requestDraw()` at `endTime` with a minimal `tx.gasprice` to lock in an underpriced VRF request and attempt to stall callback fulfillment past `callbackDeadline()` into `enableRefunds()`.
```
