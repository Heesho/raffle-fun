### Reasoning Protocol & Lifecycle Analysis

`[Model: createRaffle]`
A sponsor gives one specific non-fungible prize token (`prizeToken`, `prizeTokenId`) to a newly cloned raffle contract and specifies a payout recipient (`sponsorRecipient`), an entry threshold (`reserveEntries`), and a sale end time (`endTime`). In return, the factory deploys an isolated raffle clone, registers its address and ID in `raffleCount`, `raffleById`, `idByRaffle`, and `isRaffle`, and transitions the clone's `status` from `AwaitingPrize` to `Active` upon receiving the prize token.

`[Why: RaffleFactory.sol:756-767]`
Why does `createRaffle` register `isRaffle[raffle] = true` only when `createRaffle` is called and verify `prize.ownerOf(params.prizeTokenId) == raffle` and `status == Active` after transfer?
The code rests on the belief that checking `isRaffle[destination]` (and `destination.code.length != 0`) at the moment of configuration or transfer is sufficient to identify all protocol raffle clones, and that verifying ownership at creation guarantees the prize token will remain transferable at redemption. However, because `Clones.clone` uses `CREATE` from `RaffleFactory` with a sequential nonce, future raffle clone addresses are deterministic and have `code.length == 0` and `isRaffle == false` prior to their deployment.

`[Defeat: createRaffle]`
1. Sponsor `0xAAA1` computes the next `CREATE` address of `RaffleFactory` (`raffle_2 = computeCreateAddress(factory, factoryNonce + 1)`) and calls `createRaffle` for `raffle_1` with `sponsorRecipient = raffle_2`; both `_validateCreateParams` and `Raffle::initialize` pass because `raffle_2.code.length == 0` and `isRaffle[raffle_2] == false`.
2. Sponsor `0xAAA1` sets `reserveEntries = type(uint128).max` (`3.4028e38` entries, exceeding total circulating USDC supply) so `totalEntries >= reserveEntries` is unreachable while still collecting a 15% sponsor cut in `Status.CashWon`.
3. Sponsor `0xAAA1` deploys an ERC-721 `prizeToken` with a pausable or owner-controlled transfer gate that permits the initial escrow to `raffle_1` during `createRaffle` but reverts when `raffle_1` later attempts `prizeToken.transferFrom(raffle_1, winner, prizeTokenId)` in `redeemWinningTicket`.

`[LastOut: Creation & Escrow]`
During `createRaffle`, `prizeTokenId` is transferred from `msg.sender` to `raffle` and verified via `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active`. No quote tokens or tickets exist yet (`unsettledPot == 0`, `totalEntries == 0`, `ticketCount == 0`). If `totalEntries` remains `0`, the sponsor can call `enableRefunds()` and `releaseSponsorPrize()` to withdraw the escrowed NFT in full—unless `sponsorRecipient` was set to a future `RaffleFactory` clone address `raffle_2` deployed before `releaseSponsorPrize()`, in which case `releaseSponsorPrize()` transfers the NFT directly into `raffle_2` where it is permanently unrecoverable.

`[Model: buyEntries]`
A buyer gives `entryCount * 1,000,000` units of six-decimal USDC from `msg.sender`. In return, `recipient` receives one sequential transferable ERC-721 ticket (`ticketId = ticketCount + 1`) representing the contiguous inclusive entry interval `[totalEntries + 1, totalEntries + entryCount]`. The raffle's `totalEntries` increases by `entryCount`, `ticketCount` increases by `1`, `_ticketRanges[ticketId]` records the interval, and `unsettledPot` increases by `entryCount * 1,000,000`.

`[Why: Raffle.sol:232-248]`
Why does `buyEntries` only cap `entryCount` at `type(uint128).max - totalEntries` and check `_isProtocolDestination(to, address(prizeToken))` inside `_update`?
The code assumes that all entry purchases before `endTime` contribute symmetrically to the pot and that `_update` at mint/transfer time permanently prevents any `Raffle` clone from ever owning a ticket. It overlooks that in `Status.NftWon`, `95%` of every entry's USDC price flows back to `sponsorRecipient` (making the sponsor's net marginal cost per entry only `5%`, or `0.05 USDC`, compared to `1.00 USDC` for external buyers), and that `_update` allows minting or transferring a ticket to an undeployed future `Raffle` clone address whose `code.length` is `0` at purchase time.

`[Defeat: buyEntries]`
1. At `t0`, buyer `0xA11CE` buys `1,000` entries for `1,000e6` USDC in a raffle with `reserveEntries = 1,000`; at `t1 = endTime - 1`, sponsor `0x5P0N` buys `19,000` entries for `19,000e6` USDC, capturing `19,000 / 20,000 = 95%` of the winning odds while receiving `95% * 20,000e6 = 19,000e6` USDC back in `sponsorProceeds` (zero net USDC cost).
2. At `t0`, buyer `0xA11CE` buys `900` entries (`900e6` USDC) in a raffle with `reserveEntries = 1,000` and an NFT worth `100e6` USDC; at `t1 = endTime - 1`, sponsor `0x5P0N` buys `100` entries (`100e6` USDC) to force `totalEntries == 1,000 == reserveEntries`, switching the outcome from `Status.CashWon` (where `0xA11CE` would win `720e6` USDC) to `Status.NftWon` (where `0x5P0N` takes `950e6` USDC in `sponsorProceeds`).
3. At `t0`, buyer `0xB0B1` calls `buyEntries(raffle_2, 10)` where `raffle_2` is the deterministic `CREATE` address of the next `RaffleFactory` clone (`raffle_2.code.length == 0`); `_isProtocolDestination` returns `false` and `_safeMint` skips `onERC721Received`, stranding the ticket inside `raffle_2` once `raffle_2` is created at `t1`.

`[LastOut: Entry Purchase]`
Every `buyEntries` call pulls `entryCount * 1_000_000` canonical USDC and increments `unsettledPot` by the identical `grossAmount`, while assigning a non-overlapping range `[totalEntries + 1, totalEntries + entryCount]` to `ticketId = ticketCount + 1`. At the end of the `Entry Purchase` lifecycle, `unsettledPot == totalEntries * 1_000_000 == quoteToken.balanceOf(address(this))` with zero arithmetic drift.

`[Model: requestDraw]`
A caller gives native ETH (`msg.value`) at least equal to the Chainlink VRF wrapper's current native request price during `[endTime, endTime + 2 days)` when `totalEntries > 0`. In return, the caller receives any excess native ETH (`msg.value - paidPrice`) back, while the raffle pays `paidPrice` to the VRF wrapper, sets `status` to `Drawing`, records `drawRequestedAt = block.timestamp`, and stores `vrfRequestId`.

`[Why: Raffle.sol:256]`
Why does `requestDraw` only check `if (totalEntries == 0) revert NoEntriesSold()` rather than requiring at least two distinct ticket holders or `totalEntries >= reserveEntries`?
The code assumes that any non-zero `totalEntries` constitutes a valid raffle draw even when `totalEntries < reserveEntries` (`Status.CashWon`). Consequently, even when a single buyer holds 100% of `totalEntries` (playing against nobody else) and `reserveEntries` was missed, calling `requestDraw` forces a `CashWon` draw that deducts `20%` of that sole buyer's deposit (`15%` to `sponsorRecipient` and `5%` to `protocolTreasury`).

`[Defeat: requestDraw]`
1. Buyer `0xA11CE` is the sole participant in a raffle (`reserveEntries = 500`), buying `100` entries (`100e6` USDC) at `t0`; at `t2 = endTime`, sponsor `0x5P0N` calls `requestDraw()`, resolving to `Status.CashWon` where `0xA11CE` wins her own draw but only gets `80e6` USDC back while `0x5P0N` takes `15e6` USDC plus the returned NFT.
2. Caller `0xCA11` sends `msg.value = 1 ether` to `requestDraw()` when `paidPrice = 0.001 ether`; `requestDraw()` refunds `0.999 ether` via low-level `call` after setting `_requestInFlight = false` and `status = Status.Drawing`, while `nonReentrant` blocks re-entering state-changing raffle functions.
3. Force-sending `1 wei` of native ETH to `Raffle` prior to `requestDraw()` does not alter `paidPrice` or `excess = msg.value - paidPrice` because `requestDraw()` checks `msg.value >= quotedFee` and `paidPrice <= msg.value`.

`[Model: fulfillRandomWords]`
The Chainlink VRF wrapper supplies `requestId` and a 1-element `randomWords` array before `callbackDeadline()`. The function computes a 1-based `winningEntry` in `[1, totalEntries]`, records `resolvedAt = block.timestamp`, and sets `status` to `NftWon` if `totalEntries >= reserveEntries` or `CashWon` otherwise.

`[Why: Raffle.sol:523-528]`
Why does `fulfillRandomWords` return without reverting when `_requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1 || block.timestamp >= callbackDeadline()`?
The code rests on the belief that the VRF wrapper callback must never revert on stale or out-of-window responses, and that `block.timestamp >= callbackDeadline()` cleanly hands authority over to `enableRefunds()`.

`[Defeat: fulfillRandomWords]`
1. VRF wrapper delivers `rawFulfillRandomWords` at `block.timestamp == drawRequestedAt + 2 days`; `block.timestamp >= callbackDeadline()` evaluates to `true`, emitting `VrfCallbackIgnored` and leaving `status == Status.Drawing` so `enableRefunds()` can transition to `Status.Refunding`.
2. A synchronous callback during `requestRandomnessPayInNative` finds `_requestInFlight == true` and is ignored before `vrfRequestId` is written.
3. With `callbackGasLimit = 300_000`, `fulfillRandomWords` performs bounded arithmetic and writes a single packed storage slot (`resolvedAt`, `winningEntry`, `status`), consuming under `50,000` gas so it cannot be gas-griefed by buyer count.

`[LastOut: Draw & Resolution]`
During `requestDraw` and `fulfillRandomWords`, no `quoteToken` or `prizeToken` balances move; `paidPrice` native ETH is forwarded to `i_vrfV2PlusWrapper` and `excess = msg.value - paidPrice` is returned atomically to `msg.sender` with `0` native ETH shortfall, while `unsettledPot` remains untouched for either settlement or refund activation.

`[Model: _settleWinningTicket]`
A caller supplies the `ticketId` whose stored `[firstEntry, lastEntry]` range contains `winningEntry` after the raffle is in `NftWon` or `CashWon`. Nothing is transferred externally; `unsettledPot` is zeroed, `settlementComplete` is set to `true`, `winningTicketId` is set to `ticketId`, `protocolFees` is credited with `5%` of the pot (floored), and in `NftWon` `sponsorProceeds` is credited with the remaining `95%`, whereas in `CashWon` `winnerProceeds` is credited with `80%` (floored) and `sponsorProceeds` is credited with the remaining `15%`.

`[Model: redeemWinningTicket]`
The current owner (`msg.sender == ownerOf(ticketId)`) of `winningTicketId` burns the winning ticket (`_burn(ticketId)`), setting `winnerRedeemed = true` and `winnerRecipient = winner`. In return, if `status == Status.NftWon`, `prizeClaimed` is set to `true` and the contract transfers `prizeTokenId` to `winner`; if `status == Status.CashWon`, `winnerProceeds` is zeroed and transferred in USDC to `winner`.

`[Model: releaseSponsorProceeds]`
Any caller triggers the transfer of the entire `sponsorProceeds` USDC balance to `sponsorRecipient`, zeroing `sponsorProceeds`.

`[Model: releaseProtocolFees]`
Any caller triggers the transfer of the entire `protocolFees` USDC balance to `protocolTreasury`, zeroing `protocolFees`.

`[Model: releaseSponsorPrize]`
Any caller triggers the return of the escrowed NFT (`prizeToken`, `prizeTokenId`) to `sponsorRecipient` when `status` is `CashWon` or `Refunding`, setting `prizeClaimed = true`.

`[Why: Raffle.sol:417]`
Why does `releaseSponsorPrize` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` directly without checking `_isProtocolDestination(recipient, address(prizeToken))`, whereas `releaseSponsorProceeds` calls `_transferQuote(recipient, amount)` which enforces `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` at line 578?
The code assumes `initialize` already permanently prevented `sponsorRecipient` from being a protocol destination, forgetting that `_isProtocolDestination` checks `canonicalFactory.isRaffle(destination)` which changes over time as new clones are created, and omitting `_isProtocolDestination` entirely from the NFT transfer paths (`releaseSponsorPrize` at line 417 and `redeemWinningTicket` at line 347).

`[Defeat: releaseSponsorPrize]`
1. At `t0`, sponsor `0x5P0N` creates `raffle_1` with `sponsorRecipient = raffle_2` (the deterministic `CREATE` address of the next clone from `RaffleFactory`); at `t1`, `raffle_2` is created via `createRaffle`; at `t2`, `raffle_1` enters `Status.Refunding` or `Status.CashWon` and `releaseSponsorPrize()` transfers `prizeTokenId` via unsafe `transferFrom` directly into `raffle_2`, where it is permanently stuck because `raffle_2` only releases its own configured `prizeTokenId`.
2. In the same state at `t2` after `raffle_1` settles in `Status.CashWon` or `Status.NftWon`, calling `raffle_1.releaseSponsorProceeds()` reverts permanently with `InvalidQuoteDestination(raffle_2)` inside `_transferQuote` because `canonicalFactory.isRaffle(raffle_2)` is now `true`, permanently locking `sponsorProceeds` inside `raffle_1`.
3. In `Status.NftWon`, if `winningTicketId` was minted or transferred to `raffle_2` at `t0` before `raffle_2` was deployed at `t1`, neither `redeemWinningTicket` nor `releaseSponsorPrize` can ever extract `prizeTokenId` from `raffle_1`, permanently locking the NFT inside `raffle_1`.

`[LastOut: Settlement & Claims]`
In `Status.NftWon` and `Status.CashWon`, `_settleWinningTicket` partitions `grossPot = unsettledPot` into `protocolFees = floor(grossPot * 500 / 10_000)`, `winnerProceeds = (result == CashWon ? floor(grossPot * 8000 / 10_000) : 0)`, and `sponsorProceeds = grossPot - protocolFee - cashAmount`. Because `sponsorProceeds` is computed by subtraction, `protocolFees + winnerProceeds + sponsorProceeds == grossPot == quoteToken.balanceOf(address(this))` holds identically. In any normal withdrawal permutation of `releaseProtocolFees()`, `releaseSponsorProceeds()`, and `redeemWinningTicket()`, the last claimant out is paid in full with `0` shortfall—except when a recipient (`sponsorRecipient`, `winner`, or `protocolTreasury`) is a precomputed `RaffleFactory` clone address `raffle_k` that was deployed after `raffle_1` was initialized or after the winning ticket was minted/transferred. In that case, `canonicalFactory.isRaffle(raffle_k)` flips from `false` to `true`, causing `_transferQuote` to revert with `InvalidQuoteDestination(raffle_k)` (or making `redeemWinningTicket` uncallable by `raffle_k`), leaving the protocol unable to settle that liability and stranding `sponsorProceeds`, `winnerProceeds`, `protocolFees`, or `prizeTokenId` permanently.

`[Model: enableRefunds]`
A caller transitions the raffle to `Status.Refunding` (immediately if `msg.sender == sponsor && totalEntries == 0`, at `endTime` if `totalEntries == 0`, at `endTime + 2 days` if `status == Active && totalEntries > 0`, or at `drawRequestedAt + 2 days` if `status == Drawing`), moving `unsettledPot` into `remainingRefundLiability` and zeroing `unsettledPot`.

`[Model: refundTickets]`
A ticket owner burns a batch of `1` to `100` owned `ticketIds` in `Status.Refunding`. In return, `msg.sender` receives `aggregateEntries * 1,000,000` USDC, and `remainingRefundLiability` decreases by that exact amount.

`[Why: Raffle.sol:510-515]`
Why does `_update` check `if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) revert UnsafeProtocolDestination(to)` only during mint or transfer?
The code assumes `_isProtocolDestination(to, address(prizeToken))` is time-invariant, so once a ticket is minted or transferred to `to`, `to` can never become a protocol destination later. Because `_isProtocolDestination` skips addresses with `destination.code.length == 0` and only queries `canonicalFactory.isRaffle(destination)` against currently deployed clones, a ticket minted or transferred to a future clone address `raffle_k` at `t0` passes `_update` and becomes permanently unrefundable once `raffle_k` is deployed at `t1`.

`[Defeat: refundTickets]`
1. Passing duplicate ticket IDs `[1, 1]` in `ticketIds` burns ticket `1` on index `0` and reverts with `ERC721NonexistentToken(1)` on index `1` inside `ownerOf(1)`.
2. Passing more than `100` ticket IDs reverts with `InvalidTicketBatchSize(ticketQuantity, 100)`, while an owner holding `250` tickets can refund all of them across `3` sequential calls of `100`, `100`, and `50` tickets.
3. If ticket `1` (representing `10` entries = `10e6` USDC) was minted or transferred at `t0` to the deterministic `CREATE` address of `raffle_2` before `raffle_2` was deployed at `t1`, then when `raffle_1` enters `Status.Refunding` at `t2`, `raffle_2` has no function to call `refundTickets` (and `_transferQuote` would revert with `InvalidQuoteDestination(raffle_2)`), permanently stranding `10e6` USDC in `remainingRefundLiability`.

`[LastOut: Refund Lifecycle]`
When `enableRefunds()` executes, `remainingRefundLiability` is set to `unsettledPot = totalEntries * 1_000_000`. Because minted tickets `1 .. ticketCount` partition `[1, totalEntries]` into disjoint contiguous ranges `[firstEntry_i, lastEntry_i]`, the sum of `(lastEntry_i - firstEntry_i + 1) * 1_000_000` over all minted tickets equals `remainingRefundLiability` and equals `quoteToken.balanceOf(address(this))`. Walking every ticket holder calling `refundTickets` in any order, each ticket is burned once and decrements `remainingRefundLiability` by its exact deposit, so the last ticket holder out is paid 100% in full with `0` shortfall—unless a ticket was minted or transferred to an undeployed future `Raffle` clone address `raffle_k` before `raffle_k` was created, in which case that ticket's refund can never be claimed and its `remainingRefundLiability` remains permanently stuck in the contract.

---

```
FINDING | contract: Raffle | function: buyEntries | bug_class: cohort-dilution | group_key: Raffle | buyEntries | cohort-dilution
root_cause: In Raffle.sol:222, buyEntries does not cap totalEntries (e.g. at a maxEntries limit or reserveEntries) and does not prevent sponsor or sponsorRecipient from purchasing entries, while _settleWinningTicket in Raffle.sol:557 allocates 95% of all grossPot proceeds (including entries bought after reserveEntries is met) back to sponsorRecipient.
internal_pre: A raffle is in Status.Active with totalEntries >= reserveEntries (or approaching reserveEntries) before endTime.
external_pre: None
path:
  1. At t0, Sponsor (0x5P0N) creates a raffle for an NFT worth 1,000e6 USDC with reserveEntries = 1,000, and honest buyer Alice (0xA11CE) calls buyEntries(0xA11CE, 1_000), paying 1,000e6 USDC for entries [1, 1000] (100% of entries).
  2. At t1 = endTime - 1, Sponsor (0x5P0N) calls buyEntries(0x5P0N, 19_000), paying 19,000e6 USDC for entries [1001, 20000], bringing totalEntries to 20,000 and unsettledPot to 20,000e6 USDC.
  3. At t2 >= endTime, the draw resolves to Status.NftWon, settleWinningTicket is called (allocating protocolFees = 1,000e6 USDC and sponsorProceeds = 19,000e6 USDC), and 0x5P0N calls releaseSponsorProceeds() to recover all 19,000e6 USDC.
impact: Early ticket buyer Alice (0xA11CE) is left holding the loss: Alice paid 1,000e6 USDC ($1.00/entry) expecting 100% of the reserve pool, but Sponsor (0x5P0N) pays an effective marginal cost of only 5% ($0.05/entry, or 0 net USDC outlay at 19,000 entries since Alice's 1,000e6 USDC covers the entire 5% protocol fee on the 20,000e6 USDC pot) to dilute Alice's winning probability from 100% down to 5% (an expected loss of 950e6 USDC of NFT value for Alice, captured by Sponsor).
mitigation: Enforce an immutable maximum entry cap (or cap entry sales at reserveEntries) in Raffle::buyEntries so the sponsor cannot uncap-dilute buyers after the reserve is met using the 95% sponsor rebate.
```

```
FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: time-dependent-validation-bypass | group_key: Raffle | _isProtocolDestination | time-dependent-validation-bypass
root_cause: In Raffle.sol:615-617 (and RaffleFactory.sol:792,799), _isProtocolDestination only checks canonicalFactory.isRaffle(destination) when destination.code.length != 0, failing to reject deterministic future CREATE clone addresses of RaffleFactory before they are deployed, and in Raffle.sol:417 (releaseSponsorPrize) and Raffle.sol:347 (redeemWinningTicket) _isProtocolDestination is not checked on NFT delivery at all.
internal_pre: None
external_pre: None
path:
  1. At t0, Sponsor Alice (0xA11CE) creates raffle_1 via RaffleFactory::createRaffle with sponsorRecipient set to raffle_2 (the deterministic CREATE address for RaffleFactory's next nonce), or Buyer Alice mints/transfers a ticket in raffle_1 to raffle_2; because raffle_2.code.length == 0 and isRaffle[raffle_2] == false at t0, initialize() and _update() both succeed.
  2. At t1, another user Bob (0xB0B) calls RaffleFactory::createRaffle to create a second raffle, which deploys raffle_2 at that exact CREATE address and sets isRaffle[raffle_2] = true.
  3. At t2, after raffle_1 settles or enters Refunding: (a) calling raffle_1.releaseSponsorProceeds() reverts permanently with InvalidQuoteDestination(raffle_2) at Raffle.sol:578 because isRaffle[raffle_2] is now true, freezing all sponsorProceeds USDC in raffle_1; (b) calling raffle_1.releaseSponsorPrize() at Raffle.sol:417 bypasses _isProtocolDestination and uses unsafe transferFrom to move prizeTokenId from raffle_1 into raffle_2, permanently locking the NFT inside raffle_2; (c) any raffle_1 ticket owned by raffle_2 can never be refunded or redeemed, permanently locking remainingRefundLiability, winnerProceeds, or prizeTokenId inside raffle_1.
impact: The raffle_1 sponsor recipient or ticket claimant (and in Status.NftWon when a ticket owned by raffle_2 wins, both the winner and the sponsor) permanently loses the locked sponsorProceeds USDC, remainingRefundLiability USDC, winnerProceeds USDC, or escrowed prizeTokenId NFT, and assets are moved directly between raffle clones in violation of protocol invariants.
mitigation: Check _isProtocolDestination(recipient, address(prizeToken)) in releaseSponsorPrize() and the NftWon branch of redeemWinningTicket(), and use safeTransferFrom for prize delivery so Raffle::onERC721Received rejects inter-clone NFT transfers while disallowing unverified future clone destinations.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: single-buyer-cash-tax | group_key: Raffle | requestDraw | single-buyer-cash-tax
smell: In Raffle.sol:256, requestDraw() only checks totalEntries == 0 (and RaffleFactory.sol:811 places no upper bound on uint128 reserveEntries), allowing a draw to be triggered when totalEntries < reserveEntries even if ticketCount == 1 (a single buyer holds 100% of all entries).
unverified: Whether the CashWon 80% winner / 15% sponsor / 5% treasury split when only a single buyer participates (or when reserveEntries is set above total USDC supply) is considered intended specification behavior under DESIGN.md.
description: When only one buyer purchases entries at t0 and reserveEntries is missed at t1 = endTime, calling requestDraw() at t2 resolves to Status.CashWon where the sole buyer deterministically wins against themselves and loses 20% of their deposit (15% to sponsorRecipient and 5% to protocolTreasury) while the sponsor also reclaims the NFT.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: unverified-prize-delivery-payout | group_key: Raffle | releaseSponsorProceeds | unverified-prize-delivery-payout
smell: In Raffle.sol:388-395 and Raffle.sol:556-568, _settleWinningTicket credits 95% of unsettledPot to sponsorProceeds in Status.NftWon and releaseSponsorProceeds() releases that USDC to sponsorRecipient without requiring prizeClaimed == true (i.e., before redeemWinningTicket verifies that the untrusted prizeToken actually transfers prizeTokenId to the winner).
unverified: Whether malicious, pausable, or blocklisting ERC-721 prizeToken contracts are in-scope given the tension between DESIGN.md ("arbitrary prize contracts and ticket recipients are untrusted") and IRaffle.sol ("Supported prizes are honest, standards-compliant ERC-721s").
description: If an untrusted prizeToken permits escrow during createRaffle at t0 but reverts or blocks transfer to the winner at t2 in Status.NftWon, the sponsor can still settle and withdraw 95% of all buyers' canonical USDC via releaseSponsorProceeds() while the winner is permanently unable to redeem the NFT.
```
