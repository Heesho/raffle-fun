# 0xSimao Audit Report — Lens 9: Access, Authorization & Trust Boundaries

## Phase 0 & Phase 1 — Protocol Vocabulary & Value-Moving Models

`[Model: createRaffle]`
A sponsor supplies an ERC-721 prize (`prizeToken`, `prizeTokenId`), a `sponsorRecipient`, a `reserveEntries` threshold, and an exclusive `endTime`. `RaffleFactory::createRaffle` increments `raffleCount`, deploys an ERC-1167 clone of `raffleImplementation`, initializes the clone in `Status.AwaitingPrize`, registers the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the prize NFT from `msg.sender` to the clone, triggering `Raffle::onERC721Received` to transition `status` to `Status.Active`.

`[Model: buyEntries]`
A buyer supplies a `recipient` address and positive `entryCount` before `endTime` while the raffle is `Status.Active`. The buyer transfers `entryCount * 1,000,000` units of canonical 6-decimal USDC into the raffle clone. The raffle increments `ticketCount` by 1, advances `totalEntries` by `entryCount`, records the inclusive 1-based range `[firstEntry, lastEntry]` in `_ticketRanges[ticketId]`, adds the USDC amount to `unsettledPot`, and mints the sequential ERC-721 `ticketId` to `recipient`.

`[Model: requestDraw]`
Any caller in `[endTime, endTime + 2 days)` when `totalEntries > 0` and `status == Status.Active` supplies native ETH at least equal to the quoted Chainlink VRF v2.5 wrapper price. The raffle sets `status = Status.Drawing` and `drawRequestedAt = uint64(block.timestamp)`, pays `paidPrice` in native ETH to `i_vrfV2PlusWrapper` for 1 random word, stores `vrfRequestId`, and refunds `msg.value - paidPrice` in native ETH to `msg.sender`.

`[Model: fulfillRandomWords]`
The immutable Chainlink VRF wrapper calls `rawFulfillRandomWords` with `requestId` and one random word. If the raffle is in `Status.Drawing`, not `_requestInFlight`, matches `vrfRequestId`, has 1 word, and `block.timestamp < drawRequestedAt + 2 days`, the raffle records `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = uint64(block.timestamp)`, and transitions `status` to `Status.NftWon` (when `totalEntries >= reserveEntries`) or `Status.CashWon` (when `totalEntries < reserveEntries`).

`[Model: enableRefunds]`
In `Status.Active` with `totalEntries == 0` (by `sponsor` before `endTime` or anyone at `>= endTime`), `Status.Active` with `totalEntries > 0` at `>= endTime + 2 days`, or `Status.Drawing` at `>= drawRequestedAt + 2 days`, the raffle moves `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status = Status.Refunding`.

`[Model: settleWinningTicket]`
In `Status.NftWon` or `Status.CashWon` when `!settlementComplete`, any caller passes the `ticketId` whose stored `_ticketRanges[ticketId]` contains `winningEntry`. `_settleWinningTicket` allocates `protocolFees = floor(unsettledPot * 500 / 10000)`. In `Status.NftWon`, `sponsorProceeds = unsettledPot - protocolFees`. In `Status.CashWon`, `winnerProceeds = floor(unsettledPot * 8000 / 10000)` and `sponsorProceeds = unsettledPot - protocolFees - winnerProceeds`. It zeroes `unsettledPot`, records `winningTicketId = ticketId`, and sets `settlementComplete = true`.

`[Model: redeemWinningTicket]`
The current owner (`msg.sender == ownerOf(ticketId)`) of the winning ticket in `Status.NftWon` or `Status.CashWon` settles if not yet settled, records `winnerRecipient = winner` and `winnerRedeemed = true`, and burns `ticketId`. In `Status.NftWon`, it sets `prizeClaimed = true` and transfers the prize NFT to `winner`. In `Status.CashWon`, it zeroes `winnerProceeds` and transfers that USDC claim to `winner`.

`[Model: refundTickets]`
In `Status.Refunding`, a ticket owner passes 1 to 100 owned `ticketIds`. Each ticket is verified for `msg.sender == ownerOf(ticketId)` and burned while summing `(lastEntry - firstEntry + 1)`. The raffle decrements `remainingRefundLiability` by `aggregateEntries * 1,000,000` and transfers that USDC amount to `msg.sender`.

`[Model: releaseSponsorProceeds]`
Any caller triggers the transfer of the entire current `sponsorProceeds` to `sponsorRecipient`, zeroing `sponsorProceeds` before transferring USDC.

`[Model: releaseProtocolFees]`
Any caller triggers the transfer of the entire current `protocolFees` to `protocolTreasury`, zeroing `protocolFees` before transferring USDC.

`[Model: releaseSponsorPrize]`
In `Status.CashWon` or `Status.Refunding` when `!prizeClaimed`, any caller sets `prizeClaimed = true` and transfers `prizeTokenId` back to `sponsorRecipient`.

---

## Phase 2 & Phase 3 — Guard Interrogation (`[Why]` & `[Defeat]`)

`[Why: Raffle.sol:602]`
Why does `_isProtocolDestination` check `if (!unsafeDestination && destination.code.length != 0) { unsafeDestination = canonicalFactory.isRaffle(destination); }` at both entry (`initialize`, `_update`) and exit (`_transferQuote`)?
The code rests on the implicit belief that whether an address is a same-factory `Raffle` clone is time-invariant once an address is accepted as a `sponsorRecipient`, `protocolTreasury`, or ticket owner (`to`). That belief fails for counterfactual `CREATE` addresses of future `Raffle` clones deployed by `RaffleFactory::createRaffle`: because `Clones.clone(raffleImplementation)` uses `CREATE` (`address = keccak256(rlp([factory, nonce]))[12:]`), the address of every future `Raffle` clone has `code.length == 0` and `isRaffle[destination] == false` before that clone is created, and flips to `code.length == 45` and `isRaffle[destination] == true` once `createRaffle` reaches that nonce.

`[Defeat: _isProtocolDestination]`
1. **Counterfactual `futureRaffle` as ticket recipient (`buyEntries` / `transferFrom`)**: Compute `futureRaffle = computeCreateAddress(factory, raffleCount + 2)`. Call `buyEntries(futureRaffle, 1)` or `transferFrom(owner, futureRaffle, ticketId)`. At this moment `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false`, so `_isProtocolDestination` in `_update` (`Raffle.sol:498`) returns `false` and `ERC721Utils.checkOnERC721Received` (`ERC721.sol:290`) is a no-op. Once the next raffle is created via `createRaffle`, `futureRaffle` becomes a registered `Raffle` clone (`isRaffle[futureRaffle] == true`) owning `ticketId`, with no function to transfer, burn, refund, or redeem it.
2. **Counterfactual `futureRaffle` as `sponsorRecipient` (`createRaffle` -> `releaseSponsorProceeds`)**: Pass `sponsorRecipient = computeCreateAddress(factory, raffleCount + 2)` in `createRaffle` for Raffle #1. Both `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:166`) and `Raffle::initialize` (`Raffle.sol:193`) pass because `isRaffle[sponsorRecipient] == false`. After Raffle #2 is created at that address, `isRaffle[sponsorRecipient]` becomes `true`. When Raffle #1 settles, `releaseSponsorProceeds()` calls `_transferQuote(sponsorRecipient, amount)` (`Raffle.sol:380`), which re-runs `_isProtocolDestination(to, address(prizeToken))` (`Raffle.sol:565`) and permanently reverts with `InvalidQuoteDestination(sponsorRecipient)`.
3. **Counterfactual `futureRaffle` as `sponsorRecipient` (`createRaffle` -> `releaseSponsorPrize`)**: Under the same setup where `sponsorRecipient` of Raffle #1 is the counterfactual address of Raffle #2, if Raffle #1 resolves to `Status.CashWon` or `Status.Refunding`, `releaseSponsorPrize()` (`Raffle.sol:404`) does not call `_isProtocolDestination` and uses raw `prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId)` (not `safeTransferFrom`), transferring Raffle #1's prize NFT directly into Raffle #2 (`futureRaffle`), bypassing `Raffle::onERC721Received` and permanently stranding the NFT inside Raffle #2.

`[Why: Raffle.sol:404]`
Why does `releaseSponsorPrize()` use `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without calling `_isProtocolDestination(recipient, address(prizeToken))` and without `safeTransferFrom`?
The code avoids `safeTransferFrom` on prize payouts so a contract recipient cannot revert or reenter via `onERC721Received`, and assumes `sponsorRecipient` was already permanently validated at `initialize` (`Raffle.sol:193`). However, because `releaseSponsorPrize()` is permissionless (`external`, callable by any `msg.sender`) and `sponsorRecipient` is shared between USDC proceeds (`releaseSponsorProceeds`) and NFT return (`releaseSponsorPrize`), any contract `sponsorRecipient` that cannot transfer ERC-721s (or a counterfactual `futureRaffle` address that became a `Raffle` clone after `initialize`) will silently receive and trap the prize NFT when any third party calls `releaseSponsorPrize()`.

`[Defeat: requestDraw]`
1. **Caller supplies minimum gas price (`tx.gasprice == block.basefee`) at `block.timestamp == endTime`**: Because `requestDraw()` is permissionless and can only be called once (`_requireStatus(Status.Active)` -> `status = Status.Drawing`), any caller at `endTime` locks in the single VRF request at their transaction's `tx.gasprice` (`VRFV2PlusWrapper.calculateRequestPriceNative` prices the request using `tx.gasprice`). However, `callbackGasLimit = 300_000`, `requestConfirmations = 30`, `numWords = 1`, and `nativePayment = true` are all hardcoded constants in `Raffle.sol:254-256`.
2. **Caller is a contract that reenters or reverts on the native `excess` refund (`Raffle.sol:267`)**: If the caller reverts in `receive()`, the entire `requestDraw()` call reverts (`if (!success) revert NativeRefundFailed(msg.sender, excess)`), leaving `status == Status.Active` so another caller can request the draw. If the caller attempts to reenter during the refund `call`, `nonReentrant` blocks all state-changing `Raffle` entry points, `_requestInFlight` is already `false`, and `vrfRequestId` is already stored.
3. **Pre-funding the clone address with native ETH before `Clones.clone`**: Even if `address(this).balance > msg.value` via pre-existing balance at the `CREATE` address, `Raffle.sol:250` checks `msg.value >= quotedFee`, `Raffle.sol:258` checks `paidPrice <= msg.value`, and `Raffle.sol:261` computes `excess = msg.value - paidPrice` from `msg.value` rather than `address(this).balance`.

`[Defeat: redeemWinningTicket]`
1. **Non-owner or ERC-721 approved operator calls `redeemWinningTicket(winningTicketId)`**: `Raffle.sol:320-321` checks `address winner = ownerOf(ticketId); if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);`, rejecting operators even if approved via `approve` or `setApprovalForAll`.
2. **Caller passes a non-winning or unminted `ticketId` when `!settlementComplete`**: `_settleWinningTicket` calls `_requireWinningTicket(ticketId)` (`Raffle.sol:579-585`). Since `winningEntry` is in `[1, totalEntries]` and unminted tickets have range `[0, 0]`, `selectedEntry > lastEntry` (`>= 1 > 0`) always reverts with `TicketDoesNotContainWinningEntry`.
3. **Winning ticket owner is USDC-blocklisted (`Status.CashWon`) or rejected by `prizeToken` (`Status.NftWon`)**: Because `_update` (`Raffle.sol:497`) allows ticket transfers in all states (`Status.NftWon`, `Status.CashWon`, `Status.Refunding`) without interacting with `quoteToken` or `prizeToken`, a blocklisted winner can transfer `winningTicketId` to an unblocked address and call `redeemWinningTicket` from the new owner.

---

## Phase 4 — Last User Out Tests (`[LastOut]`)

`[LastOut: NftWon]`
Suppose buyers purchase entries totaling `totalEntries >= reserveEntries`, paying `grossPot = totalEntries * 1,000,000` USDC into `unsettledPot`. After `requestDraw()` and `fulfillRandomWords()`, `status == Status.NftWon`. `_settleWinningTicket(winningTicketId)` sets `protocolFees = Math.mulDiv(grossPot, 500, 10_000)`, `sponsorProceeds = grossPot - protocolFees`, `winnerProceeds = 0`, and `unsettledPot = 0`. Since `protocolFees + sponsorProceeds == grossPot` identically, in any claim order (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`), the last claimant receives 100% of their allocation and `accountedQuoteBalance()` reaches `0` (unless `sponsorRecipient`, `protocolTreasury`, or `ownerOf(winningTicketId)` is a counterfactual `Raffle` clone deployed after initialization/transfer, which bricks that claimant's withdrawal via `_isProtocolDestination`).

`[LastOut: CashWon]`
Suppose buyers purchase `1 <= totalEntries < reserveEntries`, paying `grossPot = totalEntries * 1,000,000` USDC. After `requestDraw()` and `fulfillRandomWords()`, `status == Status.CashWon`. `_settleWinningTicket(winningTicketId)` sets `protocolFees = Math.mulDiv(grossPot, 500, 10_000)`, `winnerProceeds = Math.mulDiv(grossPot, 8000, 10_000)`, `sponsorProceeds = grossPot - protocolFees - winnerProceeds`, and `unsettledPot = 0`. Because `protocolFees + winnerProceeds + sponsorProceeds == grossPot` holds without rounding loss for all `grossPot`, in any claim order (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`), the last claimant is paid in full and `accountedQuoteBalance()` reaches `0` (subject to the same counterfactual `Raffle` clone destination caveat).

`[LastOut: Refunding]`
Suppose tickets `1..ticketCount` partition `[1, totalEntries]` into contiguous disjoint ranges `[firstEntry_i, lastEntry_i]`, with `unsettledPot = totalEntries * 1,000,000`. `enableRefunds()` moves `unsettledPot` to `remainingRefundLiability`. Each ticket `i` can be burned once in `refundTickets`, claiming `(lastEntry_i - firstEntry_i + 1) * 1,000,000` USDC. Because $\sum_{i=1}^{\text{ticketCount}} (\text{lastEntry}_i - \text{firstEntry}_i + 1) = \text{totalEntries}$, the last ticket holder to call `refundTickets` receives 100% of their refund and reduces `remainingRefundLiability` to `0`.

---

## Findings & Leads

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: counterfactual-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | counterfactual-clone-destination-bypass
smell: In Raffle.sol:602-604 and RaffleFactory.sol:159,166, _isProtocolDestination and _validateCreateParams only reject registered Raffle clones that already have deployed code (destination.code.length != 0 && canonicalFactory.isRaffle(destination)), allowing deterministic future CREATE clone addresses of RaffleFactory to pass validation before deployment and then flip _isProtocolDestination to true once deployed.
unverified: How an attacker could force an honest victim (rather than the caller's own ticket or sponsor configuration) to set a precomputed future Raffle clone address as recipient, to, or sponsorRecipient.
description: Because RaffleFactory deploys clones via CREATE using sequential factory nonces, a precomputed future Raffle clone address passes _isProtocolDestination at initialize or _update time (and skips checkOnERC721Received in _safeMint since code.length == 0), but once deployed via createRaffle, isRaffle becomes true—permanently bricking releaseSponsorProceeds via InvalidQuoteDestination or locking any ticket (and in Status.NftWon, the prize NFT itself) owned by that clone.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-protocol-destination-check | group_key: Raffle | releaseSponsorPrize | missing-protocol-destination-check
smell: In Raffle.sol:404, releaseSponsorPrize() transfers the prize NFT to sponsorRecipient via prizeToken.transferFrom(address(this), recipient, prizeTokenId) without re-checking _isProtocolDestination(recipient, address(prizeToken)) (unlike _transferQuote in Raffle.sol:565) and without safeTransferFrom.
unverified: Whether an honest sponsor can be induced to set sponsorRecipient to a counterfactual future Raffle clone address or a contract incapable of transferring ERC-721 tokens.
description: If sponsorRecipient is set to a counterfactual future Raffle clone address before that clone is deployed, or to a contract that only handles ERC-20 sponsorProceeds, permissionless callers can invoke releaseSponsorPrize() in CashWon or Refunding to force the prize NFT via raw transferFrom into the target contract (including another Raffle clone, violating DESIGN.md's "Never move assets between raffle clones" invariant) where it is permanently unrecoverable.
```

```
LEAD | contract: RaffleFactory | function: constructor | bug_class: counterfactual-treasury-dos | group_key: RaffleFactory | constructor | counterfactual-treasury-dos
smell: In RaffleFactory.sol:80-91, the constructor checks protocolTreasury_ against address(this), quoteToken_, vrfWrapper_, and implementation (nonce 1), but cannot check whether protocolTreasury_ matches a future CREATE clone address of RaffleFactory (nonce >= 2), while Raffle::initialize (Raffle.sol:190) reverts if _isProtocolDestination(params.protocolTreasury, params.prizeToken) is true.
unverified: Whether deployment tooling could ever supply a counterfactual RaffleFactory CREATE address as protocolTreasury_.
description: If protocolTreasury_ matches the deterministic CREATE address of future clone k, RaffleFactory::createRaffle works for raffles 1..k-1 but permanently reverts at Raffle::initialize (Raffle.sol:190) when attempting to deploy clone k because params.protocolTreasury == address(this), bricking all future raffle creation on the factory.
```

