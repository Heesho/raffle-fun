### Scope & Lens 5 Orientation

`raffle.fun` (`Raffle`, `RaffleFactory`, `RaffleConstants`) is a **single-chain** Ethereum protocol with no cross-chain bridges (no LayerZero, CCIP, or Connext). Per Lens 5 rules, we focus on every asynchronous boundary, split-transaction state transition, request/callback pair, clone initialization path, and untrusted external escrow/recipient callback:
1. **Creation & Escrow boundary:** `RaffleFactory::createRaffle` → `Clones.clone` → `Raffle::initialize` → `prize.safeTransferFrom` → `Raffle::onERC721Received`.
2. **Entry Purchase & Mint Callback boundary:** `Raffle::buyEntries` → `quoteToken.safeTransferFrom` → `_safeMint` → `IERC721Receiver(recipient).onERC721Received`.
3. **Asynchronous VRF Request / Callback boundary:** `Raffle::requestDraw` → `VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative` → `rawFulfillRandomWords` → `Raffle::fulfillRandomWords` vs `Raffle::enableRefunds`.
4. **Decoupled Resolution → Settlement → Redemption / Claims:** `fulfillRandomWords` (tx 1) → `settleWinningTicket` (tx 2) → `redeemWinningTicket` / `releaseSponsorProceeds` / `releaseProtocolFees` / `releaseSponsorPrize` (tx 3+).
5. **Timeout / Refund Lifecycle:** `enableRefunds` → `refundTickets` + `releaseSponsorPrize`.

---

### Phase 0–3 — Models, Questions, Defeats, and Lifecycle Walks

#### 1. Creation & Escrow (`RaffleFactory::createRaffle`, `Raffle::initialize`, `Raffle::onERC721Received`)

[Model: RaffleFactory::createRaffle]
A sponsor supplies an NFT they own, a recipient address for sponsor payouts, an entry threshold (`reserveEntries`), and a sale end timestamp. The factory increments `raffleCount`, deploys a new clone of `raffleImplementation`, initializes the clone in `AwaitingPrize` status, records the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the sponsor's NFT into the clone. The NFT transfer triggers the clone's receiver hook, switching `status` from `AwaitingPrize` to `Active`. The factory then verifies that the clone still owns the NFT and is in `Active` status.

[Model: Raffle::initialize]
Called once by the factory on a newly deployed clone. It locks `initialized = true`, screens `sponsor`, `protocolTreasury`, and `sponsorRecipient` against known protocol addresses (`_isProtocolDestination`), records the raffle parameters, and sets `status = AwaitingPrize`.

[Model: Raffle::onERC721Received]
When the configured `prizeToken` transfers `prizeTokenId` from `sponsor` with `factory` as operator while the clone is in `AwaitingPrize`, the clone transitions `status` to `Active` and accepts the NFT.

[Why: Raffle.sol:615]
Why does `_isProtocolDestination` guard `canonicalFactory.isRaffle(destination)` behind `destination.code.length != 0`, and what implicit belief does that rest on?
It assumes that every clone address that will ever belong to this factory already has deployed bytecode (`code.length != 0`) and is already registered in `isRaffle` at the time `_isProtocolDestination` is evaluated. However, `Clones.clone(raffleImplementation)` uses `CREATE`, so every future clone address is deterministically known from `(address(factory), nonce)` *before* it has bytecode or `isRaffle[destination] == true`.

[Why: RaffleFactory.sol:761]
Why does `createRaffle` check `if (IRaffle(raffle).status() != IRaffle.Status.Active)` after `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`?
Because `prize` is an untrusted contract whose `safeTransferFrom` could either skip calling `raffle.onERC721Received` (leaving `status == AwaitingPrize`) or reenter `raffle` after `onERC721Received` sets `status = Active` (for instance, `sponsor` calling `raffle.enableRefunds()` during a transfer hook to flip `status` to `Refunding`).

[Defeat: RaffleFactory::createRaffle]
1. Attacker `0xA11CE` deploys a malicious ERC-721 `0xDEAD01` that returns `true` for `supportsInterface(0x80ac58cd)`, does not call `onERC721Received` during `safeTransferFrom`, and returns `raffle` from `ownerOf(1)` — defeated by `if (IRaffle(raffle).status() != IRaffle.Status.Active)` at `RaffleFactory.sol:765`.
2. Attacker `0xA11CE` deploys an ERC-721 `0xDEAD02` that calls `raffle.onERC721Received(factory, 0xA11CE, 1, "")` during `safeTransferFrom` and then calls back into `0xA11CE`, which immediately calls `raffle.enableRefunds()` (since `totalEntries == 0` and `msg.sender == sponsor`) — defeated by `if (IRaffle(raffle).status() != IRaffle.Status.Active)` at `RaffleFactory.sol:765`.
3. Attacker `0xA11CE` precomputes the address of the next clone `futureRaffle2 = computeCreateAddress(factory, factory.raffleCount() + 2)` (which currently has `code.length == 0` and `isRaffle[futureRaffle2] == false`), creates `raffle1` with `sponsorRecipient = futureRaffle2`, and then anyone creates `raffle2` at `futureRaffle2` — `_validateCreateParams` (`RaffleFactory.sol:799`) and `Raffle::initialize` (`Raffle.sol:206`) both pass at creation time, but once `raffle2` exists, `raffle1.releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(futureRaffle2)` while `raffle1.releaseSponsorPrize()` transfers `raffle1`'s NFT directly into `raffle2`.

[LastOut: Creation & Escrow]
Only the single `prizeTokenId` is escrowed into `raffle` during `createRaffle`; no USDC has entered yet (`unsettledPot == 0`). If `totalEntries == 0`, `sponsor` (or anyone at `>= endTime`) calls `enableRefunds()` and `releaseSponsorPrize()`, returning `prizeTokenId` to `sponsorRecipient` (unless `sponsorRecipient` became a registered raffle clone after initialization).

---

#### 2. Entry Purchase (`Raffle::buyEntries` & `Raffle::_update`)

[Model: Raffle::buyEntries]
A buyer pays `entryCount * 1,000,000` USDC into the raffle before `endTime` while `status == Active`. The raffle assigns the contiguous global entry range `[totalEntries + 1, totalEntries + entryCount]` to sequential ticket `ticketCount + 1`, increments `totalEntries` by `entryCount`, increments `ticketCount` by 1, increases `unsettledPot` by `entryCount * 1,000,000`, and mints the ERC-721 ticket to `recipient` (invoking `recipient.onERC721Received` if `recipient` has code).

[Model: Raffle::_update]
Transfers, mints, or burns `ticketId`. Whenever `to != address(0)`, it screens `to` via `_isProtocolDestination(to, address(prizeToken))` so tickets cannot be transferred to known protocol addresses, then updates ownership and balances.

[Why: Raffle.sol:248]
Why is `_safeMint(recipient, ticketId)` called *after* `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are updated?
Because `_safeMint` invokes `onERC721Received` on an untrusted `recipient` contract, which can immediately call `Raffle::transferFrom` (not `nonReentrant`) to transfer `ticketId` to another address; updating all ticket range and pot state before `_safeMint` ensures any in-callback transfer observes consistent state.

[Defeat: Raffle::buyEntries]
1. Attacker `0xB0B` deploys a contract `recipient = 0xCAFE` whose `onERC721Received` calls `raffle.buyEntries(0xCAFE, 1)` or `raffle.enableRefunds()` — defeated by `nonReentrant` on `buyEntries` and `enableRefunds`.
2. Attacker `0xB0B` deploys `recipient = 0xCAFE` whose `onERC721Received` calls `raffle.transferFrom(0xCAFE, 0xBEEF, ticketId)` during `_safeMint` — `_mint` already set `_owners[ticketId] = 0xCAFE` and `_ticketRanges[ticketId]` is already written, so the transfer to `0xBEEF` succeeds cleanly without corrupting `totalEntries`, `ticketCount`, or `unsettledPot`.
3. Buyer `0xB0B` calls `buyEntries(futureRaffle2, 5)` where `futureRaffle2 = computeCreateAddress(factory, factory.raffleCount() + 2)` has not been deployed yet (`futureRaffle2.code.length == 0`) — `_isProtocolDestination` returns `false` and `ERC721Utils.checkOnERC721Received` skips the callback because `futureRaffle2.code.length == 0`. Once `futureRaffle2` is later deployed via `createRaffle`, `ticketId` is owned by `futureRaffle2` and can never be transferred, refunded, or redeemed.

[LastOut: Entry Purchase]
After `k` purchases totaling `totalEntries` entries, `unsettledPot == totalEntries * 1,000,000 == quoteToken.balanceOf(address(this))`, and tickets `1..k` partition `[1, totalEntries]` without gaps or overlaps.

---

#### 3. Draw & Resolution (`Raffle::requestDraw` & `Raffle::fulfillRandomWords`)

[Model: Raffle::requestDraw]
In `[endTime, endTime + 2 days)` when `status == Active` and `totalEntries > 0`, a caller sends native ETH at least equal to `getVrfRequestPrice()`. The raffle transitions `status` to `Drawing`, records `drawRequestedAt = block.timestamp`, sets `_requestInFlight = true`, pays `paidPrice` in native ETH to `i_vrfV2PlusWrapper` to request 1 random word, records `vrfRequestId`, clears `_requestInFlight = false`, and refunds `msg.value - paidPrice` native ETH to `msg.sender`.

[Model: Raffle::fulfillRandomWords]
Called by `i_vrfV2PlusWrapper` via `rawFulfillRandomWords`. If `_requestInFlight` is false, `status == Drawing`, `requestId == vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < callbackDeadline()`, it computes `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and sets `status` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`). Otherwise it emits `VrfCallbackIgnored` and returns without changing state.

[Why: Raffle.sol:267]
Why does `requestDraw` set `_requestInFlight = true` before `requestRandomnessPayInNative` and check `!_requestInFlight` in `fulfillRandomWords`?
Because `vrfRequestId` is still `0` until `requestRandomnessPayInNative` returns on line 272; without `_requestInFlight`, a wrapper that returned `requestId == 0` and invoked `rawFulfillRandomWords(0, ...)` synchronously during `requestRandomnessPayInNative` would pass `requestId == vrfRequestId` (`0 == 0`) before `requestDraw` finished recording the request.

[Why: Raffle.sol:270]
Why does `requestRandomnessPayInNative` price the VRF request using `calculateRequestPriceNative(callbackGasLimit, 1)`, and what does that assume?
`VRFV2PlusWrapper.calculateRequestPriceNative` prices the native fee using `tx.gasprice` of the `requestDraw` transaction. The code assumes that a single permissionless call to `requestDraw` cannot be under-priced relative to subsequent fulfillment gas prices for the 2-day callback window, because `status` immediately becomes `Status.Drawing` and there is no function to retry or bump the VRF fee.

[Defeat: Raffle::requestDraw]
1. Attacker `0xCAFE` force-sends `1 ether` to `raffle` via `selfdestruct` and then calls `requestDraw{value: 0}()` hoping `requestRandomnessPayInNative` spends the forced ETH — defeated by `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` at `Raffle.sol:263` and `if (paidPrice > msg.value)` at `Raffle.sol:271`.
2. Attacker `0xCAFE` calls `requestDraw{value: quotedFee + 1 wei}()` from a contract whose `receive()` reenters `requestDraw()` or `enableRefunds()` during the 1 wei excess refund at `Raffle.sol:280` — defeated by `nonReentrant` on both `requestDraw` and `enableRefunds`.
3. A sponsor whose NFT floor price rose above `95% * grossSales` (or a buyer who wants a refund) calls `requestDraw()` at `block.timestamp == endTime` during a low `tx.gasprice` trough; if network gas prices spike for the next `2 days` (`DRAW_CALLBACK_TIMEOUT`) so the VRF wrapper cannot fulfill at that gas price, no participant can re-request or top up the VRF fee because `status == Status.Drawing` blocks any second `requestDraw()` call.

[LastOut: Draw & Resolution]
`requestDraw` and `fulfillRandomWords` do not touch `quoteToken` or `unsettledPot`. `paidPrice` of `msg.value` goes to `i_vrfV2PlusWrapper` and `msg.value - paidPrice` goes back to `msg.sender`, leaving `0` net native ETH retained by `Raffle`.

---

#### 4. Settlement & Claims (`_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`)

[Model: Raffle::_settleWinningTicket]
When `status` is `NftWon` or `CashWon` and `settlementComplete == false`, verifies that `ticketId`'s range `[firstEntry, lastEntry]` contains `winningEntry`. Moves `unsettledPot` to `0`, sets `settlementComplete = true` and `winningTicketId = ticketId`, allocates `protocolFees = floor(grossPot * 500 / 10000)` (5%), and in `NftWon` allocates `sponsorProceeds = grossPot - protocolFees` (95%), whereas in `CashWon` allocates `winnerProceeds = floor(grossPot * 8000 / 10000)` (80%) and `sponsorProceeds = grossPot - protocolFees - winnerProceeds` (15%).

[Model: Raffle::redeemWinningTicket]
When `status` is `NftWon` or `CashWon` and `winnerRedeemed == false`, settles `ticketId` if not already settled (or verifies `ticketId == winningTicketId`), checks `msg.sender == ownerOf(ticketId)`, sets `winnerRecipient = winner` and `winnerRedeemed = true`, and burns `ticketId`. In `NftWon`, sets `prizeClaimed = true`, transfers `prizeTokenId` to `winner`, and verifies `prizeToken.ownerOf(prizeTokenId) == winner`. In `CashWon`, zeroes `winnerProceeds` and transfers that USDC amount to `winner`.

[Model: Raffle::releaseSponsorProceeds]
Zeroes `sponsorProceeds` (reverting if 0) and transfers that USDC amount to `sponsorRecipient` after checking `_isProtocolDestination`.

[Model: Raffle::releaseProtocolFees]
Zeroes `protocolFees` (reverting if 0) and transfers that USDC amount to `protocolTreasury` after checking `_isProtocolDestination`.

[Model: Raffle::releaseSponsorPrize]
When `status` is `CashWon` or `Refunding` and `prizeClaimed == false`, sets `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

[Why: Raffle.sol:556]
Why does `_settleWinningTicket` allocate `sponsorProceeds` and `protocolFees` in `Status.NftWon` without checking `prizeClaimed` or `prizeToken.ownerOf(prizeTokenId) == address(this)`?
The design decouples settlement from winner redemption so an unresponsive or contract-based winning ticket owner cannot block `sponsorRecipient` and `protocolTreasury` from claiming their USDC proceeds. However, this rests on the implicit belief that `prizeToken` will always remain transferable to `winner` in `redeemWinningTicket` after `createRaffle` succeeded — if `prizeToken` is an untrusted, pausable, or expiring ERC-721 (e.g., an ENS name that expires before `endTime`), `releaseSponsorProceeds()` still pays the sponsor 95% of `grossSales` while `redeemWinningTicket()` permanently reverts.

[Why: Raffle.sol:417]
Why does `releaseSponsorPrize()` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` directly without calling `_isProtocolDestination(recipient, address(prizeToken))` (unlike `_transferQuote` in `releaseSponsorProceeds()`)?
The code assumes `sponsorRecipient` was already permanently validated in `initialize()`. Because `isRaffle` grows over time as new clones are deployed at deterministic `CREATE` addresses, `_transferQuote` re-checks `_isProtocolDestination` at claim time while `releaseSponsorPrize` does not.

[Defeat: Raffle::redeemWinningTicket]
1. Attacker passes `ticketId = 0` (unminted, range `[0, 0]`) to `settleWinningTicket(0)` — defeated because `winningEntry` is in `[1, totalEntries]`, so `selectedEntry > lastEntry` (`>= 1 > 0`) reverts with `TicketDoesNotContainWinningEntry(0, selectedEntry)` at `Raffle.sol:596`.
2. In `Status.CashWon` with `totalEntries = 1` (`unsettledPot = 1_000_000`), attacker tries to cause rounding dust or zero `winnerProceeds` — `protocolFee = 50_000`, `cashAmount = 800_000`, `sponsorAmount = 150_000`, `50_000 + 800_000 + 150_000 == 1_000_000` with zero dust for every `totalEntries >= 1`.
3. Sponsor creates a raffle with an expiring or pausable/untrusted `prizeToken` (or an ENS NFT expiring before `endTime`), users buy `reserveEntries` entries, draw resolves to `Status.NftWon`, and sponsor calls `settleWinningTicket(winningTicketId)` + `releaseSponsorProceeds()` — sponsor extracts 95% of the USDC pot while the winner's `redeemWinningTicket(winningTicketId)` reverts permanently on `prizeToken.transferFrom`.

[LastOut: Settlement & Claims]
For any `totalEntries >= 1`, `grossPot = totalEntries * 1,000,000`.
- In `Status.NftWon`: `protocolFees = totalEntries * 50,000`, `sponsorProceeds = totalEntries * 950,000`, `winnerProceeds = 0`. Whether `releaseProtocolFees()`, `releaseSponsorProceeds()`, or `redeemWinningTicket()` executes last, `totalEntries * 50,000 + totalEntries * 950,000 == grossPot`, so the last claimant is paid in full with `0` USDC shortfall and `accountedQuoteBalance()` reaches `0`.
- In `Status.CashWon`: `protocolFees = totalEntries * 50,000`, `winnerProceeds = totalEntries * 800,000`, `sponsorProceeds = totalEntries * 150,000`. Regardless of withdrawal order among winner, sponsor, and treasury, `50,000 + 800,000 + 150,000 == 1,000,000` per entry, so the last claimant gets paid in full with `0` USDC shortfall.

---

#### 5. Refund Lifecycle (`Raffle::enableRefunds` & `Raffle::refundTickets`)

[Model: Raffle::enableRefunds]
When `status == Active` (at `>= endTime` or by `sponsor` if `totalEntries == 0`; at `>= endTime + 2 days` if `totalEntries > 0`) or `status == Drawing` (at `>= drawRequestedAt + 2 days`), moves `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status = Refunding`.

[Model: Raffle::refundTickets]
In `status == Refunding`, a caller supplies 1 to 100 `ticketIds` they own. For each ticket, the contract verifies `msg.sender == ownerOf(ticketId)`, adds `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns `ticketId`. It then decrements `remainingRefundLiability` by `aggregateEntries * 1,000,000` and transfers that USDC amount to `msg.sender`.

[Why: Raffle.sol:377]
Why is `_burn(ticketId)` executed inside the `for` loop on each iteration rather than after the loop?
Burning inside the loop immediately sets `_owners[ticketId] = address(0)`, so a duplicate `ticketId` in the same `ticketIds` array reverts on the second encounter at `ownerOf(ticketId)` with `ERC721NonexistentToken(ticketId)`.

[Defeat: Raffle::refundTickets]
1. Attacker calls `refundTickets([1, 1])` with duplicate `ticketId = 1` in the same batch to double-claim — defeated at `index = 1` because `index = 0` called `_burn(1)`, causing `ownerOf(1)` at `Raffle.sol:372` to revert with `ERC721NonexistentToken(1)`.
2. Attacker calls `refundTickets([1])` after `ticketId = 1` was already burned — defeated by `ownerOf(1)` reverting with `ERC721NonexistentToken(1)` even though `_ticketRanges[1]` remains populated in storage.
3. Attacker buys 101 separate 1-entry tickets and tries to lock refunds via gas limit — `refundTickets` accepts batches of 1..100 tickets per call and can be called repeatedly across multiple transactions until all tickets are refunded.

[LastOut: Refund Lifecycle]
Each minted ticket `i` has `lastEntry_i - firstEntry_i + 1 == entryCount_i` and added `entryCount_i * 1,000,000` to `unsettledPot`. When `enableRefunds()` sets `remainingRefundLiability = unsettledPot`, the sum of `(lastEntry_i - firstEntry_i + 1) * 1,000,000` over all minted tickets `1..ticketCount` equals `remainingRefundLiability == quoteToken.balanceOf(address(this))`. Regardless of the order in which ticket owners call `refundTickets`, the last ticket owner to refund receives 100% of their `entryCount_i * 1,000,000` USDC, leaving `remainingRefundLiability == 0` and `0` shortfall.

---

### Findings & Leads

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: deterministic-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | deterministic-clone-destination-bypass
smell: `Raffle.sol:615` (`_isProtocolDestination`), `RaffleFactory.sol:713` (`constructor`), and `RaffleFactory.sol:792-799` (`_validateCreateParams`) only reject registered `isRaffle` clones that already exist (`destination.code.length != 0`), while `RaffleFactory.sol:739` deploys clones with deterministic `CREATE` (`Clones.clone`) and `Raffle.sol:417` (`releaseSponsorPrize`) omits `_isProtocolDestination`.
unverified: A non-self-harm incentive for a sponsor, buyer, or deployer to set `sponsorRecipient`, a ticket `recipient`, or `protocolTreasury` to a precomputed future `Clones.clone` address `computeCreateAddress(factory, nonce)` before that clone is created.
description: Because future clone addresses have `code.length == 0` and `isRaffle == false` until `createRaffle` reaches their `CREATE` nonce, setting `sponsorRecipient` or a ticket `recipient` to a future clone address passes initial checks, but once that clone is created `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination`, `releaseSponsorPrize()` transfers the prize NFT into the other raffle clone where it is locked, and any ticket owned by the clone is permanently unclaimable.
```

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: decoupled-escrow-settlement-without-prize-delivery | group_key: Raffle | _settleWinningTicket | decoupled-escrow-settlement-without-prize-delivery
smell: In `Status.NftWon`, `Raffle.sol:556-569` (`_settleWinningTicket`) and `Raffle.sol:388-395` (`releaseSponsorProceeds`) release 95% of `unsettledPot` to `sponsorRecipient` without requiring `prizeClaimed == true` or verifying that `prizeToken` can still be transferred to `winner` in `redeemWinningTicket` (`Raffle.sol:347`).
unverified: Whether an in-scope deployment permits ERC-721 tokens with expiration (e.g., ENS `.eth` names expiring during the up-to-34-day raffle window), pause/blacklist hooks, or sponsor-controlled transfer restrictions as `prizeToken`.
description: Because `settleWinningTicket` and `releaseSponsorProceeds` are decoupled from `redeemWinningTicket`, if the escrowed `prizeToken` expires, pauses, or reverts on `transferFrom` after `createRaffle`, the sponsor still collects 95% of buyers' USDC in `Status.NftWon` while the winning ticket holder's `redeemWinningTicket` permanently reverts and refunds can never be enabled.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: single-shot-vrf-request-gas-pricing | group_key: Raffle | requestDraw | single-shot-vrf-request-gas-pricing
smell: `Raffle.sol:265-270` transitions `status` irreversibly to `Status.Drawing` on a single permissionless `requestDraw()` call that prices the Chainlink VRF v2.5 native direct-funding request using the caller's `tx.gasprice` (`i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)`), with no retry or fee-bump path in `Status.Drawing`.
unverified: Whether the target chain's basefee / VRF lane `maxGasPrice` or wrapper subscription balance can remain unable to fulfill a low-`tx.gasprice` request for the full `DRAW_CALLBACK_TIMEOUT` (`2 days`).
description: An actor who prefers `Status.Refunding` over the draw outcome (such as a sponsor after `reserveEntries` is met and the NFT floor price rises) can call `requestDraw()` at `endTime` during a low-gas-price window; if gas prices spike above the VRF fulfillment threshold for 2 days, no participant can re-request or bump the VRF fee, forcing the raffle into `enableRefunds()`.
```

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: callback-activation-before-creation-complete | group_key: RaffleFactory | createRaffle | callback-activation-before-creation-complete
smell: In `RaffleFactory.sol:761`, `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` triggers `Raffle::onERC721Received` (`Raffle.sol:441`), which sets `raffle.status = Status.Active` without holding `Raffle`'s `nonReentrant` guard before `safeTransferFrom` returns to `RaffleFactory::createRaffle`.
unverified: Any state corruption beyond inverted event ordering (`PrizeDeposited` and `TicketPurchased` emitted before `RaffleCreated`) when an untrusted `prizeToken` calls `raffle.buyEntries` inside `safeTransferFrom` after `onERC721Received`.
description: Because `onERC721Received` activates the clone mid-transfer while `Raffle`'s reentrancy lock is unheld, a hook in `prizeToken.safeTransferFrom` can call `raffle.buyEntries` and mint tickets before `RaffleFactory::createRaffle` finishes its post-escrow checks and emits `RaffleCreated`.
```
