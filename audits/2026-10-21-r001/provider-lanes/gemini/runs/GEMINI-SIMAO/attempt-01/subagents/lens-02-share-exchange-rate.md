# 0xSimao Audit Report — Lens 2 (Shares, Exchange Rates & Redemption)

## Phase 0 & Working Protocol Analysis (with Mandatory Markers)

### 1. Factory Creation & Prize Escrow (`RaffleFactory::createRaffle`, `Raffle::initialize`, `Raffle::onERC721Received`)

`[Model: createRaffle]`
A sponsor supplies an NFT (`prizeToken`, `prizeTokenId`), a payout address (`sponsorRecipient`), a reserve entry threshold (`reserveEntries`), and a sale end timestamp (`endTime`). The factory increments its global `raffleCount`, deploys a new clone of `raffleImplementation`, initializes the clone in `AwaitingPrize` status, records the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the prize NFT from the sponsor into the clone. The receiver hook on the clone switches the clone's status from `AwaitingPrize` to `Active`. The factory then verifies that the clone holds ownership of the NFT and remains in `Active` status before emitting `RaffleCreated`.

`[Why: RaffleFactory.sol:106]`
Why does `RaffleFactory::createRaffle` deploy clones via `Clones.clone(raffleImplementation)` (which uses the `CREATE` opcode) while relying on `isRaffle[destination]` and `destination.code.length != 0` to screen out sibling raffle clones in `_validateCreateParams` and `Raffle::_isProtocolDestination`?
- First answer: Because only deployed clones are registered in `isRaffle`.
- Deeper question: What implicit belief does that rest on? It rests on the belief that a `Raffle` clone address cannot be supplied as a ticket recipient, `sponsorRecipient`, or `protocolTreasury` *before* the clone is deployed. Because `CREATE` addresses are strictly deterministic from `(address(factory), factoryNonce)`, any future `Raffle` clone address has `code.length == 0` and `isRaffle == false` prior to its creation, bypassing every `_isProtocolDestination` check at entry time and flipping `_isProtocolDestination` to `true` once deployed.

`[Why: Raffle.sol:190]`
Why does `Raffle::initialize` check `_isProtocolDestination(params.protocolTreasury, params.prizeToken)` on every raffle creation when `protocolTreasury` is an immutable set once in `RaffleFactory`'s constructor?
- First answer: To ensure `protocolTreasury` does not collide with `address(this)` (the newly cloned raffle) or `params.prizeToken`.
- Deeper question: What implicit belief does that rest on? It assumes `protocolTreasury` will never equal a future `Raffle` clone's deterministic `CREATE` address. If `protocolTreasury` was configured to the deterministic `CREATE` address of future clone $k$, `RaffleFactory` works for clones $1 \dots k-1$ and then permanently bricks `createRaffle` at clone $k$ (because `destination == address(this)` reverts in `initialize`, rolling back the factory nonce).

`[Defeat: createRaffle]`
1. **Precomputed Future Clone as `sponsorRecipient`**: Attacker computes `futureRaffle = computeCreateAddress(factory, factoryNonce + 1)` (where `raffleId = 2` will be deployed), calls `createRaffle` for Raffle 1 with `sponsorRecipient = futureRaffle`, and then calls `createRaffle` for Raffle 2 so `isRaffle[futureRaffle]` becomes `true`.
2. **Reentrant `buyEntries` from Untrusted `prizeToken` During Escrow**: Sponsor deploys an ERC-721 `prizeToken` whose `safeTransferFrom` calls `raffle.onERC721Received(factory, sponsor, tokenId, "")` (transitioning `raffle` to `Status.Active`) and then immediately calls `raffle.buyEntries(attacker, 10)` before returning to `RaffleFactory::createRaffle`. Because `Raffle`'s `nonReentrant` guard is separate from `RaffleFactory`'s and `status` remains `Status.Active`, the post-conditions `prize.ownerOf(prizeTokenId) == raffle` and `status() == Status.Active` at `RaffleFactory.sol:129-134` both pass, emitting `TicketPurchased` prior to `RaffleCreated`.
3. **Fake `onERC721Received` Callback**: A contract at `0xdead` calls `raffle.onERC721Received(factory, sponsor, prizeTokenId, "")` directly; defeated by `msg.sender != address(prizeToken)` at `Raffle.sol:422`.

---

### 2. Entry Purchase & Ticket Minting (`Raffle::buyEntries`, `Raffle::_update`)

`[Model: buyEntries]`
A buyer gives `entryCount * 1,000,000` raw units of USDC to the raffle clone and receives one sequential ERC-721 ticket NFT minted to `recipient` that represents the inclusive entry range `[totalEntries + 1, totalEntries + entryCount]`. The raffle increases `totalEntries` by `entryCount`, increments `ticketCount` by 1, stores the range in `_ticketRanges[ticketId]`, and increases `unsettledPot` by `entryCount * 1,000,000`.

`[Model: _update]`
When a ticket is minted, transferred, or burned, ownership of `ticketId` moves from `previousOwner` to `to` (with `to == address(0)` burning the ticket). Before updating balances and owner mappings, if `to != address(0)`, the contract checks `_isProtocolDestination(to, address(prizeToken))` to block transfers to known protocol sinks.

`[Why: Raffle.sol:602]`
Why does `_isProtocolDestination` guard `canonicalFactory.isRaffle(destination)` behind `if (!unsafeDestination && destination.code.length != 0)`?
- First answer: To save an external `STATICCALL` to `factory.isRaffle` when `destination` is an EOA (`code.length == 0`).
- Deeper question: What implicit belief does that rest on? It rests on the belief that an address with `code.length == 0` today can never become a registered `Raffle` clone (`isRaffle[destination] == true`) tomorrow, and that `ERC721Utils.checkOnERC721Received` only needs to check `to.code.length > 0` at mint/transfer time. Because future `Raffle` clones are deployed via `CREATE` at predictable addresses that currently have `code.length == 0`, both `_isProtocolDestination` and `checkOnERC721Received` pass before the clone is deployed.

`[Defeat: buyEntries]`
1. **Minting Ticket to Precomputed Future `Raffle` Clone**: In Raffle 1 (`Active`), caller invokes `buyEntries(futureRaffle, 1)` where `futureRaffle` is the deterministic `CREATE` address of the next raffle clone on `RaffleFactory`. Because `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false`, `_isProtocolDestination` returns `false` and `_safeMint` skips `onERC721Received`. When Raffle 2 is subsequently created at `futureRaffle`, Raffle 2 owns `ticketId = 1` in Raffle 1 with no function to transfer, redeem, or refund it.
2. **Transferring Ticket Inside `onERC721Received` Callback**: Contract `recipient` receives `_safeMint(recipient, ticketId)` at `Raffle.sol:235` and, inside `onERC721Received`, calls `raffle.transferFrom(recipient, secondaryOwner, ticketId)`. Because `transferFrom` does not have `nonReentrant` and all state (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`, `_owners[ticketId]`) was already committed at lines 230-234, accounting remains intact.
3. **Overflowing `totalEntries`**: Caller passes `entryCount = type(uint128).max` when `totalEntries = 1`; defeated by `if (entryCount > type(uint128).max - totalEntries) revert TotalEntriesOverflow(...)` at `Raffle.sol:219`.

---

### 3. Draw Request & VRF Resolution (`Raffle::requestDraw`, `Raffle::fulfillRandomWords`, `Raffle::enableRefunds`)

`[Model: requestDraw]`
After `endTime` and before `endTime + 2 days` on a raffle with at least one sold entry, any caller supplies native ETH to cover the Chainlink VRF v2.5 wrapper fee. The raffle transitions `status` from `Active` to `Drawing`, records `drawRequestedAt = block.timestamp` and `vrfRequestId = requestId`, pays `paidPrice` in native ETH to `i_vrfV2PlusWrapper`, and refunds `msg.value - paidPrice` in native ETH back to `msg.sender`. No quote-token totals change.

`[Model: fulfillRandomWords]`
When the VRF wrapper responds before `drawRequestedAt + 2 days` for the active `vrfRequestId` with one random word, the raffle selects `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and transitions `status` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`). No quote-token totals or asset balances move during the callback.

`[Model: enableRefunds]`
When a raffle has no entries sold (callable by `sponsor` anytime or anyone at `endTime`), or when the draw request window expires (`endTime + 2 days`), or when the VRF callback window expires (`drawRequestedAt + 2 days`), the raffle moves the entire `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and transitions `status` to `Refunding`.

`[Why: Raffle.sol:267]`
Why does `requestDraw` refund `excess = msg.value - paidPrice` using an assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` after `_requestInFlight = false`?
- First answer: Because the exact wrapper price `paidPrice` is returned by `requestRandomnessPayInNative` and any overpayment must be returned to `msg.sender`.
- Deeper question: What implicit belief does that rest on? It rests on `nonReentrant` blocking `msg.sender` from re-entering `Raffle` state-changing functions during the native refund call, and on `excess` being computed strictly as `msg.value - paidPrice` rather than `address(this).balance`.

`[Defeat: requestDraw]`
1. **Synchronous VRF Callback During `requestRandomWordsInNative`**: If the wrapper calls `rawFulfillRandomWords` synchronously before `vrfRequestId = requestId` is written at `Raffle.sol:259`, `_requestInFlight` is `true` (`Raffle.sol:254`), causing `fulfillRandomWords` (`Raffle.sol:511`) to emit `VrfCallbackIgnored` and return without resolving prematurely.
2. **Force-Sending ETH via `selfdestruct` Before `requestDraw`**: Attacker sends 1 ETH via `selfdestruct` to `raffle` and calls `requestDraw()` with `msg.value = quotedFee`. Because `Raffle.sol:262` computes `excess = msg.value - paidPrice` rather than reading `address(this).balance`, the attacker cannot sweep the force-sent ETH, nor does it break `paidPrice > msg.value`.
3. **Calling `requestDraw` at Exact `drawRequestDeadline()`**: Caller submits `requestDraw` at `block.timestamp == endTime + 2 days`; defeated by `if (block.timestamp >= requestDeadline) revert DrawRequestWindowExpired(...)` at `Raffle.sol:245`, ensuring clean Partition with `enableRefunds()`.

---

### 4. Settlement, Redemption, Refunds & Proceeds Release (`Raffle::_settleWinningTicket`, `Raffle::redeemWinningTicket`, `Raffle::refundTickets`, `Raffle::releaseSponsorProceeds`, `Raffle::releaseProtocolFees`, `Raffle::releaseSponsorPrize`, `Raffle::_transferQuote`)

`[Model: _settleWinningTicket]`
Once the raffle is in `NftWon` or `CashWon`, any caller supplies a `ticketId` whose stored `[firstEntry, lastEntry]` range contains `winningEntry`. The raffle zeroes `unsettledPot` and splits that exact amount into `protocolFees` (5% rounded down), `winnerProceeds` (0 in `NftWon`, or 80% rounded down in `CashWon`), and `sponsorProceeds` (the exact remainder `grossPot - protocolFee` or `grossPot - protocolFee - cashAmount`), while recording `winningTicketId = ticketId` and `settlementComplete = true`.

`[Model: redeemWinningTicket]`
The current owner of `winningTicketId` burns their ticket NFT (settling the winning ticket first if not yet settled), records `winnerRecipient = winner` and `winnerRedeemed = true`, and receives either the escrowed prize NFT (in `NftWon`, setting `prizeClaimed = true`) or `winnerProceeds` in USDC (in `CashWon`, zeroing `winnerProceeds`).

`[Model: refundTickets]`
In `Refunding` status, a caller supplies between 1 and 100 `ticketIds` they own. Each ticket is burned and its entry count `lastEntry - firstEntry + 1` is summed into `aggregateEntries`. The raffle decrements `remainingRefundLiability` by `amount = aggregateEntries * 1,000,000` and transfers `amount` USDC to `msg.sender`.

`[Model: releaseSponsorProceeds]`
Any caller triggers payout of the full `sponsorProceeds` balance, zeroing `sponsorProceeds` and transferring that USDC amount to `sponsorRecipient` after checking `_isProtocolDestination`.

`[Model: releaseProtocolFees]`
Any caller triggers payout of the full `protocolFees` balance, zeroing `protocolFees` and transferring that USDC amount to `protocolTreasury` after checking `_isProtocolDestination`.

`[Model: releaseSponsorPrize]`
In `CashWon` or `Refunding` status when `prizeClaimed` is `false`, any caller sets `prizeClaimed = true` and transfers `prizeTokenId` of `prizeToken` from the raffle to `sponsorRecipient`, verifying `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

`[Model: _transferQuote]`
Checks that the recipient `to` is not a protocol destination via `_isProtocolDestination(to, address(prizeToken))` and transfers `amount` of `quoteToken` to `to`.

`[Why: Raffle.sol:565]`
Why does `_transferQuote` re-check `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` at withdrawal/release time when `sponsorRecipient`, `protocolTreasury`, and ticket recipients were already checked at `initialize` and `_update` time?
- First answer: As defense-in-depth so USDC is never transferred into a protocol contract.
- Deeper question: When can `_isProtocolDestination(to, address(prizeToken))` evaluate to `false` at `initialize`/`_update` time and `true` at `_transferQuote` time? Look at all 7 conditions in `_isProtocolDestination`: the first 6 (`address(this)`, `factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `prizeToken_`, `raffleImplementation`) are immutable/constant after `initialize`. Only the 7th condition (`destination.code.length != 0 && canonicalFactory.isRaffle(destination)`) can change over time! And when it flips from `false` to `true` (because `to` was a precomputed `CREATE` address of a subsequent `Raffle` clone), `_transferQuote` reverts permanently, locking the USDC in `Raffle` forever!

`[Why: Raffle.sol:404]`
Why does `releaseSponsorPrize()` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` WITHOUT calling `_isProtocolDestination(recipient, address(prizeToken))` first, unlike `_transferQuote`?
- First answer: Because `Raffle::initialize` and `RaffleFactory::_validateCreateParams` already checked `sponsorRecipient` at creation time.
- Deeper question: What happens if `sponsorRecipient` was set to a precomputed future `Raffle` clone address `futureRaffle` (which passed creation checks before `futureRaffle` was deployed) and `futureRaffle` is now deployed? `_transferQuote` in `releaseSponsorProceeds()` catches `isRaffle[futureRaffle] == true` and reverts, whereas `releaseSponsorPrize()` lacks `_isProtocolDestination(recipient, address(prizeToken))` and transfers the prize NFT directly into `futureRaffle`—violating the design invariant *"Never move assets between raffle clones"* and permanently stranding the NFT inside `futureRaffle`!

`[Why: Raffle.sol:388]`
Why does `releaseSponsorProceeds()` allow the sponsor to withdraw `sponsorProceeds` (95% of the pot) in `Status.NftWon` without checking `prizeClaimed == true` (i.e. before `redeemWinningTicket` has delivered `prizeToken` to the winner)?
- First answer: Because `DESIGN.md` specifies that *"Sponsor and treasury can claim independently after settlement."*
- Deeper question: What implicit belief does that rest on? It rests on the assumption that once `prizeTokenId` is escrowed in `createRaffle`, `prizeToken.transferFrom(address(this), winner, prizeTokenId)` in `redeemWinningTicket` will remain executable for an honest winner. However, because `redeemWinningTicket` uses `transferFrom` (not `safeTransferFrom`), a winner cannot grief `transferFrom`; only `prizeToken` itself can cause `transferFrom` to fail. If `prizeToken` is an untrusted/pausable/admin-controlled/upgradable ERC-721 that blocks transfers out of `raffle` after `createRaffle`, the sponsor still extracts 95% of all buyers' USDC via `settleWinningTicket` + `releaseSponsorProceeds` while the winner's `redeemWinningTicket` reverts permanently.

`[Defeat: redeemWinningTicket]`
1. **Winning Ticket Owned by Precomputed Sibling `Raffle` Clone**: Ticket containing `winningEntry` was minted or transferred to `futureRaffle` before `futureRaffle` was deployed via `RaffleFactory::createRaffle`. Once `futureRaffle` is deployed, `ownerOf(winningTicketId) == futureRaffle`. Anyone can call `settleWinningTicket(winningTicketId)` (allowing the sponsor and treasury to take 95% + 5% of the USDC pot in `NftWon`), but `redeemWinningTicket(winningTicketId)` requires `msg.sender == ownerOf(winningTicketId)`, which `futureRaffle` can never call, permanently locking the prize NFT (in `NftWon`) or 80% cash prize (in `CashWon`) in the raffle.
2. **USDC-Blacklisted Winner Transfers Ticket Before Redemption**: Suppose `winner` (an EOA or contract) is blacklisted by `quoteToken` (USDC) after buying a ticket in a `CashWon` raffle. Because `Raffle::transferFrom` does not touch `quoteToken`, `winner` calls `raffle.transferFrom(winner, freshAddress, winningTicketId)` and then calls `redeemWinningTicket(winningTicketId)` from `freshAddress`, bypassing the USDC blacklist cleanly.
3. **Settling With a Non-Winning Ticket ID**: Caller passes `ticketId = 999` (unminted, range `[0, 0]`) to `settleWinningTicket(999)`; defeated by `_requireWinningTicket` (`Raffle.sol:577-583`) since `winningEntry >= 1 > 0 == lastEntry`.

`[Defeat: refundTickets]`
1. **Duplicate Ticket IDs in Batch**: Caller passes `ticketIds = [1, 1]` to `refundTickets` to double-claim a refund; defeated because iteration 0 calls `_burn(1)` (`Raffle.sol:364`), setting `_owners[1] = address(0)`, so iteration 1's `ownerOf(1)` (`Raffle.sol:359`) reverts with `ERC721NonexistentToken(1)`.
2. **Ticket Owned by Precomputed Sibling `Raffle` Clone**: If a ticket was minted/transferred to `futureRaffle` prior to `futureRaffle`'s deployment, `futureRaffle` can never call `refundTickets`, leaving `remainingRefundLiability > 0` permanently.
3. **Oversized Batch DoS**: Caller passes 101 tickets; defeated by `MAX_REFUND_TICKET_BATCH_SIZE = 100`, while owners with >100 tickets can call `refundTickets` across multiple transactions.

---

## Closing Lifecycle Tests (`[LastOut: ...]`)

`[LastOut: ReserveMet-NftWon]`
- **Setup**: Sponsor creates Raffle 1 with `reserveEntries = 3`. Buyer A buys 1 entry (`ticketId = 1`, `[1, 1]`, pays `1,000,000` USDC). Buyer B buys 2 entries (`ticketId = 2`, `[2, 3]`, pays `2,000,000` USDC). `totalEntries = 3`, `unsettledPot = 3,000,000`, `quoteToken.balanceOf(raffle) = 3,000,000`.
- **Resolution & Settlement**: VRF selects `winningEntry = 2` (`status = Status.NftWon`). `_settleWinningTicket(2)` computes:
  - `protocolFee = Math.mulDiv(3_000_000, 500, 10_000) = 150,000`
  - `sponsorAmount = 3_000_000 - 150,000 = 2,850,000`
  - `unsettledPot = 0`, `protocolFees = 150,000`, `sponsorProceeds = 2,850,000`, `winnerProceeds = 0`.
- **Withdrawal in worst order**:
  1. `releaseSponsorProceeds()` pays `2,850,000` USDC to `sponsorRecipient` (`balance = 150,000`).
  2. `releaseProtocolFees()` pays `150,000` USDC to `protocolTreasury` (`balance = 0`, `accountedQuoteBalance() = 0`).
  3. Buyer B calls `redeemWinningTicket(2)`, burning `ticketId = 2` and receiving `prizeTokenId`.
- **Verdict**: Every cohort is paid in full (`2,850,000 + 150,000 == 3,000,000` USDC, plus the NFT), with 0 shortfall—**EXCEPT** if `sponsorRecipient` or `ownerOf(2)` was set to a precomputed future `Raffle` clone address before that clone was deployed, in which case the last claimant (`sponsorRecipient` in `releaseSponsorProceeds` or `futureRaffle` in `redeemWinningTicket`) reverts and their claim is permanently locked.

`[LastOut: ReserveMissed-CashWon]`
- **Setup**: Sponsor creates Raffle 1 with `reserveEntries = 5`. Buyer A buys 1 entry (`ticketId = 1`, `[1, 1]`, pays `1,000,000` USDC). Buyer B buys 2 entries (`ticketId = 2`, `[2, 3]`, pays `2,000,000` USDC). `totalEntries = 3 < 5`, `unsettledPot = 3,000,000`, `quoteToken.balanceOf(raffle) = 3,000,000`.
- **Resolution & Settlement**: VRF selects `winningEntry = 1` (`status = Status.CashWon`). `_settleWinningTicket(1)` computes:
  - `protocolFee = Math.mulDiv(3_000_000, 500, 10_000) = 150,000`
  - `cashAmount = Math.mulDiv(3_000_000, 8000, 10_000) = 2,400,000`
  - `sponsorAmount = 3_000,000 - 150,000 - 2,400,000 = 450,000`
  - `unsettledPot = 0`, `winnerProceeds = 2,400,000`, `sponsorProceeds = 450,000`, `protocolFees = 150,000`.
- **Withdrawal in worst order**:
  1. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
  2. `releaseProtocolFees()` pays `150,000` USDC to `protocolTreasury` (`balance = 2,850,000`).
  3. `releaseSponsorProceeds()` pays `450,000` USDC to `sponsorRecipient` (`balance = 2,400,000`).
  4. Buyer A calls `redeemWinningTicket(1)`, burning `ticketId = 1` and receiving `2,400,000` USDC (`balance = 0`, `accountedQuoteBalance() = 0`).
- **Verdict**: Because `grossPot` is always an integer multiple of `ENTRY_PRICE = 1,000,000` and `BPS = 10,000` divides `1,000,000` evenly (`1,000,000 / 10,000 = 100`), `protocolFee + cashAmount + sponsorAmount == grossPot` holds identically with zero rounding loss and 0 shortfall—unless a recipient is a precomputed future `Raffle` clone.

`[LastOut: Refunding]`
- **Setup**: Buyer A buys 1 entry (`ticketId = 1`, `[1, 1]`, `1,000,000` USDC), Buyer B buys 3 entries (`ticketId = 2`, `[2, 4]`, `3,000,000` USDC), Buyer C buys 2 entries (`ticketId = 3`, `[5, 6]`, `2,000,000` USDC). `totalEntries = 6`, `unsettledPot = 6,000,000`.
- **Transition**: After `drawRequestDeadline()`, `enableRefunds()` moves `unsettledPot = 0`, `remainingRefundLiability = 6,000,000`, `status = Status.Refunding`.
- **Withdrawal in worst order**:
  1. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
  2. Buyer B calls `refundTickets([2])`: `aggregateEntries = 4 - 2 + 1 = 3`, receives `3,000,000` USDC, `remainingRefundLiability = 3,000,000`.
  3. Buyer C calls `refundTickets([3])`: `aggregateEntries = 6 - 5 + 1 = 2`, receives `2,000,000` USDC, `remainingRefundLiability = 1,000,000`.
  4. Buyer A (last user out) calls `refundTickets([1])`: `aggregateEntries = 1 - 1 + 1 = 1`, receives `1,000,000` USDC, `remainingRefundLiability = 0`, `quoteToken.balanceOf(raffle) = 0`.
- **Verdict**: Every ticket's inclusive range `[firstEntry, lastEntry]` satisfies `lastEntry - firstEntry + 1 == entryCount`, so the last user out receives 100% of their deposit with 0 shortfall—unless a ticket was minted/transferred to a precomputed future `Raffle` clone.

---

## Findings & Leads

```
FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-bypass
root_cause: In Raffle.sol:602-604 (and RaffleFactory.sol:159,166), `_isProtocolDestination` only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`, failing to reject deterministic future `CREATE` clone addresses of `RaffleFactory` before those clones are deployed, while `releaseSponsorPrize` in Raffle.sol:404 omits `_isProtocolDestination(recipient, address(prizeToken))` entirely.
internal_pre: None
external_pre: None
path:
  1. Assume `RaffleFactory` is deployed at `factory` (nonce 1 was `new Raffle` in the constructor, so Raffle 1 will be deployed at nonce 2 and Raffle 2 will be deployed at `futureRaffle2 = computeCreateAddress(factory, 3)`). At this point, `futureRaffle2.code.length == 0` and `factory.isRaffle(futureRaffle2) == false`.
  2. In Raffle 1 (or during Raffle 1 creation), `futureRaffle2` is supplied as a ticket recipient in `buyEntries(futureRaffle2, 10)` (paying `10,000,000` USDC for `ticketId = 1` covering entries `[1, 10]`) or via `transferFrom(user, futureRaffle2, 1)`, OR as `sponsorRecipient = futureRaffle2` in `createRaffle`. Both `Raffle::_isProtocolDestination(futureRaffle2, prizeToken)` and `ERC721Utils::checkOnERC721Received` see `futureRaffle2.code.length == 0` and succeed.
  3. Any sponsor calls `factory.createRaffle(...)` to create Raffle 2, which executes `Clones.clone(raffleImplementation)` via `CREATE` at nonce 3, deploying Raffle 2 at `futureRaffle2` and setting `factory.isRaffle[futureRaffle2] = true`.
  4. Now `_isProtocolDestination(futureRaffle2, prizeToken)` in Raffle 1 evaluates to `true`:
     - If `futureRaffle2` owns `ticketId = 1` in Raffle 1 and Raffle 1 enters `Status.Refunding`, `futureRaffle2` has no function to call `refundTickets`, permanently locking `10,000,000` USDC and preventing `remainingRefundLiability` from ever reaching 0.
     - If `futureRaffle2` owns the winning `ticketId = 1` in Raffle 1 when `status == Status.NftWon`, anyone can call `settleWinningTicket(1)` (paying 95% USDC to the sponsor and 5% to the treasury), but `redeemWinningTicket(1)` can never be called by `futureRaffle2`, permanently locking the escrowed prize NFT in Raffle 1.
     - If `sponsorRecipient` of Raffle 1 was set to `futureRaffle2`, `releaseSponsorProceeds()` calls `_transferQuote(futureRaffle2, amount)` which now reverts with `InvalidQuoteDestination(futureRaffle2)` (permanently locking `sponsorProceeds` in Raffle 1), while in `CashWon` or `Refunding`, `releaseSponsorPrize()` (which omits `_isProtocolDestination` at `Raffle.sol:404`) transfers Raffle 1's prize NFT directly into Raffle 2 (`futureRaffle2`), violating the "Never move assets between raffle clones" invariant and permanently locking the NFT inside Raffle 2.
impact: Permanent freezing of the escrowed prize NFT (in Raffle 1 on `NftWon`, or inside Raffle 2 via `releaseSponsorPrize` on `CashWon`/`Refunding`) and permanent freezing of USDC claims (`sponsorProceeds`, `winnerProceeds`, or `remainingRefundLiability`) held by or payable to `futureRaffle2`, leaving the ticket holder or `sponsorRecipient` holding a 100% loss of the locked NFT and USDC.
mitigation: Deploy clones in `RaffleFactory::createRaffle` using `Clones.cloneDeterministic` with a salt derived from `keccak256(abi.encode(msg.sender, raffleId, blockhash(block.number - 1)))` (or require `recipient` / `sponsorRecipient` to either have code or sign/confirm, and add `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` in `Raffle::releaseSponsorPrize` at `Raffle.sol:401`).
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: untrusted-prize-token-settlement-decoupling | group_key: Raffle | releaseSponsorProceeds | untrusted-prize-token-settlement-decoupling
smell: In `Raffle.sol:375-382` and `Raffle.sol:533-558`, `_settleWinningTicket` allocates `sponsorProceeds = grossPot - protocolFee` (95% of buyers' USDC) in `Status.NftWon` and `releaseSponsorProceeds()` releases that USDC to `sponsorRecipient` without requiring `prizeClaimed == true` (i.e., before `redeemWinningTicket` has verified that `prizeToken.transferFrom(address(this), winner, prizeTokenId)` succeeds).
unverified: Whether the threat model treats a sponsor-deployed or admin-pausable/upgradable `prizeToken` that passes `createRaffle` escrow (`safeTransferFrom` + `ownerOf == raffle`) and subsequently blocks or reverts `transferFrom(raffle, winner, prizeTokenId)` in `redeemWinningTicket` as in-scope (given `DESIGN.md` states "arbitrary prize contracts and ticket recipients are untrusted" while `IRaffle.sol` states "Supported prizes are honest, standards-compliant ERC-721s").
description: Because `redeemWinningTicket` uses `transferFrom` rather than `safeTransferFrom`, an honest or malicious `winner` can never cause `prizeToken.transferFrom` to revert on a standard ERC-721, so decoupling `releaseSponsorProceeds()` from `prizeClaimed` in `Status.NftWon` only enables a malicious sponsor with a controllable/reverting `prizeToken` to extract 95% of ticket buyers' USDC while denying the winner the NFT.
```

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: prize-escrow-reentrant-activation | group_key: RaffleFactory | createRaffle | prize-escrow-reentrant-activation
smell: In `RaffleFactory.sol:128-135`, `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` invokes `raffle.onERC721Received` (which sets `raffle.status = Status.Active` at `Raffle.sol:428`), after which the untrusted `prizeToken` contract still has execution control before `createRaffle` finishes and before `RaffleCreated` is emitted.
unverified: Whether pre-creation-event actions on the newly active `raffle` clone (such as calling `raffle.buyEntries(...)` inside `prizeToken.safeTransferFrom` after `onERC721Received` returns, which preserves `status() == Status.Active` and passes `RaffleFactory.sol:132`) can corrupt off-chain indexer state or harm third-party buyers beyond reordering `TicketPurchased` ahead of `RaffleCreated`.
description: Because `Raffle::onERC721Received` activates the raffle inside the untrusted `prizeToken.safeTransferFrom` call and `Raffle`'s `nonReentrant` lock is independent of `RaffleFactory`'s, an untrusted `prizeToken` can execute `buyEntries` on the clone before `createRaffle` completes and emits `RaffleCreated`.
```

