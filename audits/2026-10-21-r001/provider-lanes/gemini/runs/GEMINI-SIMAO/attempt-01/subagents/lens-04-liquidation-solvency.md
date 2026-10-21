# 0xSimao Audit — Lens 4 (Liquidation, Bad Debt & Solvency)

## Working Trace & Mandatory Reasoning Protocol

### 1. Factory Creation & Clone Initialization (`RaffleFactory.sol`, `Raffle.sol`)

`[Model: createRaffle]`
A sponsor provides an ERC-721 prize NFT along with a sale end timestamp, a minimum entry threshold (`reserveEntries`), and a payout address (`sponsorRecipient`). The factory increments `raffleCount`, deploys a new clone of `raffleImplementation`, initializes the clone in `AwaitingPrize` status, registers the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the sponsor's NFT into the clone. The NFT transfer triggers `onERC721Received` on the clone, moving its status to `Active`.

`[Model: initialize]`
The factory sets the clone's fixed configuration (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`), marks `initialized = true`, and sets `status = Status.AwaitingPrize` after verifying that `sponsor`, `protocolTreasury`, and `sponsorRecipient` are non-zero and not known protocol plumbing.

`[Model: onERC721Received]`
When the configured `prizeToken` transfers `prizeTokenId` from `sponsor` with `factory` as operator while the clone is in `Status.AwaitingPrize`, the clone accepts custody of the prize NFT and transitions `status` from `Status.AwaitingPrize` to `Status.Active`.

`[Why: RaffleFactory.sol:106]`
Why does `RaffleFactory::createRaffle` deploy clones with `Clones.clone(raffleImplementation)` (`CREATE`) and register `isRaffle[raffle] = true` only at creation time while `Raffle::_isProtocolDestination` checks `destination.code.length != 0 && canonicalFactory.isRaffle(destination)`?
Because the code implicitly assumes that a canonical raffle clone's address cannot be known or used as a recipient before `createRaffle` deploys it. In reality, `CREATE` addresses are strictly deterministic from `address(factory)` and the factory's contract nonce (`1 + raffleCount`), so any future raffle clone address has `code.length == 0` and `isRaffle == false` prior to its creation.

`[Defeat: _validateCreateParams]`
1. Attacker computes `futureRaffle = computeCreateAddress(factory, factoryNonce + 1)` (where `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false`) and calls `createRaffle` for `Raffle #1` with `sponsorRecipient = futureRaffle`. `_validateCreateParams` and `Raffle::initialize` both pass because `isRaffle[futureRaffle]` is `false` and `futureRaffle.code.length == 0`. Once `Raffle #2` is deployed at `futureRaffle`, `isRaffle[futureRaffle]` becomes `true`.
2. Attacker deploys an ERC-721 contract `MaliciousPrize` that returns `true` from `supportsInterface(0x80ac58cd)` and transfers `prizeTokenId = 1` to `raffle` in `createRaffle`, attempting to call `raffle.enableRefunds()` reentrantly inside `safeTransferFrom` after `onERC721Received` sets `status = Status.Active`. Defeated by `if (IRaffle(raffle).status() != IRaffle.Status.Active) revert PrizeEscrowVerificationFailed(...)` at `RaffleFactory.sol:133`.
3. Attacker frontruns a victim sponsor who approved `RaffleFactory` on `prizeToken` by calling `createRaffle` with the victim's `prizeTokenId` and `sponsorRecipient = attacker`. Defeated because `RaffleFactory.sol:128` calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, which checks `previousOwner == msg.sender` in `ERC721::transferFrom` and `from == sponsor` in `Raffle::onERC721Received`.

---

### 2. Entry Purchases & Ticket Transfers (`Raffle.sol`)

`[Model: buyEntries]`
A buyer pays `entryCount * 1,000,000` raw USDC units into the raffle while `status == Status.Active` and `block.timestamp < endTime`. In return, `totalEntries` increases by `entryCount`, `ticketCount` increases by `1`, `unsettledPot` increases by the USDC paid, `_ticketRanges[ticketId]` records the inclusive range `[oldTotalEntries + 1, oldTotalEntries + entryCount]`, and the `recipient` receives newly minted ERC-721 ticket `ticketId`.

`[Why: Raffle.sol:593]`
Why does `_isProtocolDestination` check `destination.code.length != 0` before querying `canonicalFactory.isRaffle(destination)`?
To save an external `STATICCALL` to `factory.isRaffle(destination)` when `destination` is an EOA (`code.length == 0`). However, this rests on the implicit belief that an address with `code.length == 0` today can never become a contract where `canonicalFactory.isRaffle(destination) == true` later.

`[Defeat: _isProtocolDestination]`
1. Buyer calls `buyEntries(futureRaffle, 10)` (or `transferFrom(buyer, futureRaffle, ticketId)`) on `Raffle #1` where `futureRaffle` is the deterministic `CREATE` address of `Raffle #2`. Because `futureRaffle.code.length == 0` before `Raffle #2` is created, `_isProtocolDestination(futureRaffle, address(prizeToken))` returns `false`, and `_safeMint` skips `onERC721Received` because `to.code.length == 0`. When `Raffle #2` is subsequently created, `Raffle #2` owns `ticketId` in `Raffle #1`, permanently stranding the claim because `Raffle #2` has no way to transfer, redeem, or refund the ticket.
2. Attacker attempts to transfer a ticket to `address(this)`, `factory`, `quoteToken`, `vrfWrapper`, `prizeToken`, or `raffleImplementation`. Defeated by the explicit equality checks in `Raffle.sol:599-601`.
3. Attacker attempts to mint a ticket to an already-deployed canonical raffle clone `raffleById[1]`. Defeated because `raffleById[1].code.length == 45 != 0` and `canonicalFactory.isRaffle(raffleById[1]) == true`.

---

### 3. VRF Draw Request & Callback Resolution (`Raffle.sol`, `VRFV2PlusWrapperConsumerBase.sol`)

`[Model: requestDraw]`
Any caller after `endTime` and before `endTime + 2 days` (when `status == Status.Active` and `totalEntries > 0`) supplies native ETH to pay the Chainlink VRF wrapper fee. The raffle transitions `status` to `Status.Drawing`, records `drawRequestedAt = block.timestamp` and `vrfRequestId = requestId`, pays `paidPrice` in native ETH to the VRF wrapper, and refunds any `msg.value - paidPrice` excess native ETH to the caller. No USDC accounting totals change.

`[Why: Raffle.sol:254]`
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and reset `_requestInFlight = false` after storing `vrfRequestId = requestId`?
Because `rawFulfillRandomWords` is an external function without `nonReentrant`, and `vrfRequestId` is only returned after `requestRandomnessPayInNative` completes. Without `_requestInFlight`, a synchronous callback from a wrapper implementation during `requestRandomnessPayInNative` would see `vrfRequestId == 0` (before `vrfRequestId` is written) or resolve the raffle before `requestDraw` finishes state updates.

`[Defeat: requestDraw]`
1. Attacker calls `requestDraw` from a contract with `msg.value = quotedFee + 1 wei` whose `receive()` reverts, attempting to block draw requests. This only reverts the attacker's own transaction (`NativeRefundFailed`), leaving `status == Status.Active` for any honest caller.
2. Attacker sends native ETH directly to the raffle clone via `selfdestruct` so `address(this).balance > 0`, then calls `requestDraw` with `msg.value = 0` hoping `requestRandomnessPayInNative` spends the forced balance. Defeated by `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` at `Raffle.sol:250` and `if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value)` at `Raffle.sol:258`.
3. Attacker calls `requestDraw` at `block.timestamp == drawRequestDeadline()`. Defeated by `if (block.timestamp >= requestDeadline) revert DrawRequestWindowExpired(...)` at `Raffle.sol:245`.

`[Model: fulfillRandomWords]`
When the Chainlink VRF wrapper delivers a single random word for `vrfRequestId` while `status == Status.Drawing` and `block.timestamp < drawRequestedAt + 2 days`, the raffle computes `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and sets `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`.

---

### 4. Settlement, Redemptions, Proceeds Release & Refunds (`Raffle.sol`)

`[Model: _settleWinningTicket]`
Any caller supplies `ticketId` after the raffle is in `Status.NftWon` or `Status.CashWon`. The raffle verifies that `winningEntry` lies within `_ticketRanges[ticketId]`, zeroes `unsettledPot`, sets `settlementComplete = true` and `winningTicketId = ticketId`, allocates `protocolFees = floor(grossPot * 500 / 10000)`, and either allocates `sponsorProceeds = grossPot - protocolFees` (when `Status.NftWon`) or allocates `winnerProceeds = floor(grossPot * 8000 / 10000)` and `sponsorProceeds = grossPot - protocolFees - winnerProceeds` (when `Status.CashWon`).

`[Why: Raffle.sol:546]`
Why does `_settleWinningTicket` compute `sponsorAmount = grossPot - protocolFee - cashAmount` as the remainder rather than `Math.mulDiv(grossPot, 1500, 10_000)`?
To guarantee exact conservation (`protocolFees + winnerProceeds + sponsorProceeds == unsettledPot`) without leaving rounding dust unallocated in the contract. Furthermore, because `grossPot = totalEntries * 1,000,000` is always an exact multiple of `BPS = 10,000`, both `protocolFee` and `cashAmount` divide without remainder.

`[Defeat: _settleWinningTicket]`
1. Attacker calls `settleWinningTicket(0)` or `settleWinningTicket(999)` for an unminted ticket ID. For unminted IDs, `ticketRange` returns `(0, 0)`, and since `winningEntry >= 1`, `selectedEntry > lastEntry` triggers `TicketDoesNotContainWinningEntry`.
2. Attacker calls `settleWinningTicket(winningTicketId)` a second time to re-populate `sponsorProceeds` or `winnerProceeds` after `unsettledPot` was zeroed. Defeated by `if (settlementComplete) revert SettlementAlreadyComplete()` at `Raffle.sol:534`.
3. Attacker frontruns `redeemWinningTicket(winningTicketId)` with `settleWinningTicket(winningTicketId)`. In `redeemWinningTicket` (`Raffle.sol:314-318`), when `settlementComplete` is already `true`, it simply verifies `ticketId == winningTicketId` and proceeds without reverting.

`[Model: redeemWinningTicket]`
The current owner of `winningTicketId` burns `winningTicketId` (settling it first if `settlementComplete == false`), sets `winnerRecipient = winner` and `winnerRedeemed = true`, and either sets `prizeClaimed = true` and receives the escrowed prize NFT (in `Status.NftWon`) or zeroes `winnerProceeds` and receives `winnerProceeds` in USDC (in `Status.CashWon`).

`[Why: Raffle.sol:334]`
Why does `redeemWinningTicket` (and `releaseSponsorPrize` at `Raffle.sol:404`) transfer the prize NFT using `prizeToken.transferFrom` followed by an `ownerOf` check instead of `prizeToken.safeTransferFrom`, and without calling `_isProtocolDestination`?
It uses `transferFrom` to avoid untrusted `onERC721Received` callbacks during prize release, relying on `initialize` and `_update` having already screened `sponsorRecipient` and ticket owners via `_isProtocolDestination`. However, that assumption breaks if `sponsorRecipient` (or the ticket owner) was a precomputed future `Raffle` clone address that had `code.length == 0` when screened at `initialize` or `_update` time.

`[Defeat: redeemWinningTicket]`
1. Winner is blacklisted on `quoteToken` (USDC) in `Status.CashWon` or blocked on `prizeToken` in `Status.NftWon`. Because `Raffle::_update` does not touch `quoteToken` or `prizeToken`, the winner can call `Raffle::transferFrom(winner, freshAddress, winningTicketId)` and redeem from `freshAddress`.
2. Attacker who is approved on `winningTicketId` (via `approve` or `setApprovalForAll`) tries to call `redeemWinningTicket(winningTicketId)` to steal the payout. Defeated because `Raffle.sol:320-321` checks `address winner = ownerOf(ticketId); if (msg.sender != winner) revert NotTicketOwner(...)`. (The operator would have to `transferFrom` the ticket to themselves first, which is standard ERC-721 bearer behavior).
3. Malicious `prizeToken` returns silently from `transferFrom` without changing ownership. Defeated by `if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner)` at `Raffle.sol:335`.

`[Model: releaseSponsorProceeds]`
Any caller triggers the payout of the full `sponsorProceeds` balance to `sponsorRecipient`, zeroing `sponsorProceeds` and transferring `amount` of USDC.

`[Model: releaseProtocolFees]`
Any caller triggers the payout of the full `protocolFees` balance to `protocolTreasury`, zeroing `protocolFees` and transferring `amount` of USDC.

`[Model: releaseSponsorPrize]`
When the raffle is in `Status.CashWon` or `Status.Refunding` and `prizeClaimed == false`, any caller triggers the return of `prizeTokenId` to `sponsorRecipient`, setting `prizeClaimed = true`.

`[Why: Raffle.sol:565]`
Why does `_transferQuote` re-check `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` when `initialize` and `_update` already checked `_isProtocolDestination`?
As defense-in-depth against paying USDC to protocol contracts; however, if `to` was a precomputed future `Raffle` clone address when `initialize` or `_update` ran, `_isProtocolDestination(to, ...)` flips from `false` to `true` once that clone is deployed, causing `_transferQuote` to permanently revert and lock the USDC liability inside the raffle.

`[Defeat: releaseSponsorPrize]`
1. Sponsor creates `Raffle #1` with `sponsorRecipient = futureRaffle` (the deterministic `CREATE` address of `Raffle #2`). After `Raffle #2` is deployed, `Raffle #1` enters `Status.Refunding` or `Status.CashWon`. Calling `Raffle #1.releaseSponsorPrize()` succeeds because `Raffle.sol:404` omits `_isProtocolDestination(recipient, address(prizeToken))` and uses `transferFrom` (bypassing `Raffle #2.onERC721Received`), moving `Raffle #1`'s prize NFT directly into `Raffle #2` where it is permanently locked.
2. Attacker calls `releaseSponsorPrize()` in `Status.NftWon`. Defeated by `if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) revert SponsorPrizeUnavailable(currentStatus)` at `Raffle.sol:397`.
3. Attacker calls `releaseSponsorPrize()` twice. Defeated by `if (prizeClaimed) revert PrizeAlreadyClaimed()` at `Raffle.sol:400`.

`[Model: enableRefunds]`
When an active raffle has `totalEntries == 0` (callable by `sponsor` before `endTime` or anyone at/after `endTime`), or `status == Status.Active` at/after `endTime + 2 days`, or `status == Status.Drawing` at/after `drawRequestedAt + 2 days`, the function moves `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and transitions `status` to `Status.Refunding`.

`[Defeat: enableRefunds]`
1. Sponsor tries to call `enableRefunds()` before `endTime` after 1 entry has been bought (`totalEntries == 1`). Defeated by `if (totalEntries == 0)` branch check at `Raffle.sol:280`; when `totalEntries > 0`, `deadline = drawRequestDeadline()` (`endTime + 2 days`) applies even to `sponsor`.
2. Attacker tries to call `enableRefunds()` at `block.timestamp == callbackDeadline() - 1` while `status == Status.Drawing`. Defeated by `if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp)` at `Raffle.sol:291`.
3. VRF callback arrives in the same block after `enableRefunds()` has already set `status = Status.Refunding`. In `fulfillRandomWords` (`Raffle.sol:511`), `status != Status.Drawing` is true, so the callback emits `VrfCallbackIgnored` and returns without overwriting `Status.Refunding`.

`[Model: refundTickets]`
In `Status.Refunding`, a ticket owner passes an array of 1 to 100 `ticketIds` they own. Each ticket is burned, its entry count `lastEntry - firstEntry + 1` is summed into `aggregateEntries`, `remainingRefundLiability` is reduced by `aggregateEntries * 1,000,000`, and that exact USDC amount is transferred to `msg.sender`.

`[Defeat: refundTickets]`
1. Attacker passes duplicate ticket IDs `[1, 1]` in `ticketIds` to claim a double refund. On index 0, `_burn(1)` deletes `_owners[1]`; on index 1, `ownerOf(1)` reverts with `ERC721NonexistentToken(1)`.
2. Attacker passes 101 ticket IDs. Defeated by `if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) revert InvalidTicketBatchSize(...)` at `Raffle.sol:352`.
3. Attacker passes a ticket ID owned by another user. Defeated by `if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner)` at `Raffle.sol:360`.

---

### 5. Closing Lifecycle Tests (`[LastOut]`)

`[LastOut: NftWon]`
Suppose Buyers 1..N purchase `totalEntries >= reserveEntries` entries, depositing `grossPot = totalEntries * 1,000,000` USDC into `unsettledPot`. After VRF resolves to `Status.NftWon` and `_settleWinningTicket` executes:
- `protocolFees = floor(grossPot * 500 / 10000) = totalEntries * 50,000`
- `sponsorProceeds = grossPot - protocolFees = totalEntries * 950,000`
- `winnerProceeds = 0`
Walking claims in any order (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`):
- The winner burns `winningTicketId` and receives `prizeTokenId`.
- `sponsorRecipient` receives `totalEntries * 950,000` USDC.
- `protocolTreasury` receives `totalEntries * 50,000` USDC.
Total USDC paid out is `totalEntries * 1,000,000 == grossPot`. The last claimant out is paid in full with `0` shortfall and `0` dust remaining (unless `sponsorRecipient` or the winning ticket owner is a post- deployed `Raffle` clone address or USDC-blacklisted address, as detailed in the leads below).

`[LastOut: CashWon]`
Suppose Buyers 1..N purchase `0 < totalEntries < reserveEntries` entries, depositing `grossPot = totalEntries * 1,000,000` USDC into `unsettledPot`. After VRF resolves to `Status.CashWon` and `_settleWinningTicket` executes:
- `protocolFees = floor(grossPot * 500 / 10000) = totalEntries * 50,000`
- `winnerProceeds = floor(grossPot * 8000 / 10000) = totalEntries * 800,000`
- `sponsorProceeds = grossPot - protocolFees - winnerProceeds = totalEntries * 150,000`
Walking claims in any order (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`):
- The winner burns `winningTicketId` and receives `totalEntries * 800,000` USDC.
- `sponsorRecipient` receives `totalEntries * 150,000` USDC and recovers `prizeTokenId` via `releaseSponsorPrize`.
- `protocolTreasury` receives `totalEntries * 50,000` USDC.
Total USDC paid out is `totalEntries * (800,000 + 150,000 + 50,000) = totalEntries * 1,000,000 == grossPot`. The last claimant out is paid in full with `0` shortfall.

`[LastOut: Refunding]`
Suppose Buyers 1..N purchase tickets `1..ticketCount` covering `[1, totalEntries]`, depositing `unsettledPot = totalEntries * 1,000,000` USDC. `enableRefunds()` moves `unsettledPot` to `remainingRefundLiability`.
Walking ticket owners calling `refundTickets` in any order:
- Each ticket `i` burns once and withdraws `(lastEntry_i - firstEntry_i + 1) * 1,000,000 = entryCount_i * 1,000,000` USDC.
- Since `sum_{i=1..ticketCount}(entryCount_i) == totalEntries`, the final ticket owner out withdraws the exact remaining balance, reducing `remainingRefundLiability` and `accountedQuoteBalance()` to `0` with `0` shortfall, while `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.

---

## Findings & Leads

LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: deterministic-clone-address-bypass | group_key: Raffle | _isProtocolDestination | deterministic-clone-address-bypass
smell: `RaffleFactory::createRaffle` (`RaffleFactory.sol:106`) deploys clones using `Clones.clone` (`CREATE`), whose future addresses are deterministic from the factory's nonce, while `Raffle::_isProtocolDestination` (`Raffle.sol:602-604`) and `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:159,166`) only reject addresses that already have `code.length != 0` and `isRaffle[destination] == true` at the time of the check.
unverified: A scenario where an attacker forces an honest victim (rather than the caller/sponsor themselves) to set `sponsorRecipient` or ticket `recipient` to an undeployed future `Raffle` clone address.
description: If an undeployed future `Raffle` clone address is supplied as `sponsorRecipient` in `createRaffle` or as `recipient`/`to` in `buyEntries`/`transferFrom`, it passes `_isProtocolDestination` (and `_safeMint` while `code.length == 0`), but once the next raffle is created at that address, `isRaffle` becomes `true` — permanently bricking `releaseSponsorProceeds()` via `InvalidQuoteDestination`, stranding any ticket held by that clone (`remainingRefundLiability`, `winnerProceeds`, or the `NftWon` prize), and allowing `releaseSponsorPrize()` (`Raffle.sol:404`) to transfer the prize NFT directly into the other raffle clone in violation of the spec invariant "Never move assets between raffle clones".

LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: immutable-recipient-blacklist-dos | group_key: Raffle | releaseSponsorProceeds | immutable-recipient-blacklist-dos
smell: Unlike ticket holders — who hold transferable ERC-721 bearer tickets and can transfer their ticket via `Raffle::transferFrom` to an unblocked address if blacklisted by `quoteToken` (USDC) or `prizeToken` — `sponsorRecipient` and `protocolTreasury` are immutable per raffle (`Raffle.sol:197-198`) with no fallback recipient or transferable claim.
unverified: Whether `sponsorRecipient` or `protocolTreasury` becoming blacklisted on canonical USDC (or `sponsorRecipient` becoming blocked on `prizeToken`) during an active raffle is considered in-scope beyond standard token-blacklist behavior.
description: If `sponsorRecipient` or `protocolTreasury` is blacklisted by `quoteToken` after `createRaffle`, `releaseSponsorProceeds()` (`Raffle.sol:375`) or `releaseProtocolFees()` (`Raffle.sol:385`) permanently reverts, stranding those USDC liabilities inside the clone forever (`accountedQuoteBalance()` can never reach zero).

LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: unsafe-erc721-transfer-to-contract | group_key: Raffle | releaseSponsorPrize | unsafe-erc721-transfer-to-contract
smell: `Raffle::redeemWinningTicket` (`Raffle.sol:334`) and `Raffle::releaseSponsorPrize` (`Raffle.sol:404`) deliver the prize NFT via `prizeToken.transferFrom` instead of `safeTransferFrom` without invoking `IERC721Receiver.onERC721Received` on the recipient.
unverified: Whether any intended smart-contract `sponsorRecipient` or ticket holder vault relies on `onERC721Received` callbacks to update internal accounting when receiving the prize NFT.
description: If `sponsorRecipient` (or a contract winner) is an NFT custody vault or contract that credits incoming ERC-721 tokens only inside `onERC721Received`, delivering the prize via raw `transferFrom` transfers token ownership on `prizeToken` without triggering the recipient contract's accounting hook.
