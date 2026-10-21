# Lens 5 Audit Report — Cross-Chain & Asynchronous State (`raffle.fun`)

**Single-Chain Scope Note:** `raffle.fun` (`Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`) is a single-chain protocol with no cross-chain messaging bridges (no LayerZero, CCIP, or Connext). Per Lens 5 rules, this audit focuses on the asynchronous two-transaction request/callback, escrow/activation, and settlement/redemption boundaries where state is written in one transaction and consumed in a later transaction.

---

## Reasoning Protocol & Lifecycle Traces

### 1. Factory Creation & Prize Escrow Boundary (`createRaffle` → `initialize` → `onERC721Received`)

`[Model: createRaffle]`
In `createRaffle`, a sponsor supplies a prize NFT contract and token ID, a sponsor recipient address, a minimum reserve entry count, and a sale end timestamp. The factory validates the parameters, increments `raffleCount`, deploys a new ERC-1167 minimal proxy clone of `raffleImplementation`, initializes the clone in `AwaitingPrize` status, registers the clone in `raffleById`, `idByRaffle`, and `isRaffle`, and pulls the prize NFT from the sponsor into the clone. The transfer callback transitions the clone to `Active`, and the factory verifies both NFT ownership and `Active` status before finishing.

`[Model: initialize]`
In `initialize`, called once by the factory on a newly deployed clone, the clone checks that the sponsor, sponsor recipient, protocol treasury, and prize token are non-zero and do not match known protocol addresses. It stores the raffle parameters and sets `status` to `AwaitingPrize`.

`[Model: onERC721Received]`
In `onERC721Received`, when the prize NFT contract executes the safe transfer callback during creation, the clone verifies that its status is `AwaitingPrize`, the caller is the configured `prizeToken`, the transferred token ID matches `prizeTokenId`, the previous owner is `sponsor`, and the transfer operator is `factory`. It then transitions `status` to `Active`.

`[Why: RaffleFactory.sol:125]`
Why does `RaffleFactory::createRaffle` set `isRaffle[raffle] = true` only after `IRaffle(raffle).initialize(...)` has already executed its `_isProtocolDestination` checks?
Because during `initialize`, `raffle` is already caught by `destination == address(this)` inside `_isProtocolDestination`, resting on the implicit belief that no address checked in `initialize` (or in earlier raffles) could become a registered raffle clone at a later point in time.

`[Why: RaffleFactory.sol:128-134]`
Why does `createRaffle` check both `prize.ownerOf(params.prizeTokenId) != raffle` and `IRaffle(raffle).status() != IRaffle.Status.Active` after `prize.safeTransferFrom`?
Because `params.prizeToken` is an arbitrary external contract: a non-compliant implementation could either skip the `onERC721Received` callback (leaving `status` in `AwaitingPrize`) or invoke `onERC721Received` without actually updating token ownership to `raffle`.

`[Defeat: createRaffle]`
1. Malicious `prizeToken` calls `raffle.onERC721Received(factory, sponsor, prizeTokenId, "")` during `safeTransferFrom` without transferring ownership of `prizeTokenId`: defeated at `RaffleFactory.sol:129` (`if (prize.ownerOf(params.prizeTokenId) != raffle) revert PrizeEscrowVerificationFailed(...)`).
2. Malicious `prizeToken` calls `raffle.onERC721Received(factory, sponsor, prizeTokenId, "")` (setting `status = Status.Active`) and then attempts to call `raffle.enableRefunds()` before `safeTransferFrom` returns: defeated because `enableRefunds()` before `endTime` requires `msg.sender == sponsor`, while `Raffle.sol:187` rejected `sponsor == prizeToken` during `initialize`, and `RaffleFactory.sol:132` verifies `status() == Status.Active` after `safeTransferFrom`.
3. Attacker calls `onERC721Received` directly on an active raffle with an unrelated NFT to overwrite prize state: defeated at `Raffle.sol:422` because `status != Status.AwaitingPrize` reverts with `UnexpectedPrize`.

---

### 2. Entry Purchase & Ticket Mint Boundary (`buyEntries` → `_safeMint` → `_update`)

`[Model: buyEntries]`
In `buyEntries`, while the raffle is `Active` and before `endTime`, a buyer specifies a recipient address and a positive number of entries. The raffle pulls `entryCount * 1,000,000` raw USDC units from the buyer, assigns the contiguous range `[totalEntries + 1, totalEntries + entryCount]` to sequential ticket `ticketCount + 1`, increments `totalEntries` by `entryCount`, increments `ticketCount` by 1, adds the USDC amount to `unsettledPot`, and mints the ERC-721 ticket to the recipient.

`[Why: Raffle.sol:235]`
Why is `_safeMint(recipient, ticketId)` executed after updating `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot`?
Because `_safeMint` invokes `onERC721Received` on contract recipients, which hands execution flow to an untrusted `recipient` contract; updating all state beforehand and guarding `buyEntries` with `nonReentrant` ensures the callback observes consistent state and cannot reenter state-modifying raffle functions.

`[Why: Raffle.sol:602]`
Why does `_isProtocolDestination` guard `canonicalFactory.isRaffle(destination)` behind `destination.code.length != 0`?
Because the code assumes that any `Raffle` clone that could ever be passed as a destination already has deployed bytecode at the moment `_isProtocolDestination` is called, overlooking that future `Raffle` clones deployed via `Clones.clone` (`CREATE`) have deterministic addresses with `code.length == 0` and `isRaffle == false` prior to their creation.

`[Defeat: buyEntries]`
1. Attacker calls `buyEntries(recipient, 0)` to mint a ticket at zero cost: defeated at `Raffle.sol:218` (`if (entryCount == 0) revert ZeroEntryCount()`).
2. Attacker calls `buyEntries(recipient, type(uint128).max)` to overflow `totalEntries`: defeated at `Raffle.sol:219` (`if (entryCount > type(uint128).max - totalEntries) revert TotalEntriesOverflow(...)`).
3. Malicious `recipient` contract transfers `ticketId` inside its `onERC721Received` callback during `_safeMint`: `ERC721::transferFrom` is not `nonReentrant`, so the transfer succeeds, but `ticketId` is already paid for and all accounting variables (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`) were already committed prior to `_safeMint`.

---

### 3. Asynchronous VRF Request & Callback Boundary (`requestDraw` → `rawFulfillRandomWords` → `fulfillRandomWords` / `enableRefunds`)

`[Model: requestDraw]`
In `requestDraw`, after `endTime` and before `endTime + 2 days` on an `Active` raffle with `totalEntries > 0`, any caller supplies native ETH to cover the Chainlink VRF v2.5 wrapper fee. The raffle sets `status = Status.Drawing`, records `drawRequestedAt = uint64(block.timestamp)`, sets `_requestInFlight = true`, pays the native wrapper fee to request 1 random word, records `vrfRequestId = requestId`, clears `_requestInFlight = false`, and refunds `msg.value - paidPrice` in native ETH back to `msg.sender`.

`[Model: fulfillRandomWords]`
In `fulfillRandomWords`, when the Chainlink VRF wrapper delivers randomness via `rawFulfillRandomWords`, the raffle verifies that `_requestInFlight` is false, `status` is `Drawing`, `requestId` matches `vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < callbackDeadline()`. If any check fails, it emits `VrfCallbackIgnored` and returns without reverting. Otherwise, it selects `winningEntry = (randomWords[0] % totalEntries) + 1`, records `resolvedAt = uint64(block.timestamp)`, and transitions `status` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`).

`[Model: enableRefunds]`
In `enableRefunds`, if the raffle is `Active` with `totalEntries == 0` (and called by `sponsor` before `endTime` or by anyone at/after `endTime`), or `Active` with `totalEntries > 0` at/after `endTime + 2 days`, or `Drawing` at/after `drawRequestedAt + 2 days`, the contract moves `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status = Status.Refunding`.

`[Why: Raffle.sol:254]`
Why does `requestDraw` set `_requestInFlight = true` around `requestRandomnessPayInNative` and check `_requestInFlight` in `fulfillRandomWords`?
Because `vrfRequestId` is only assigned after `requestRandomnessPayInNative` returns; if a wrapper implementation ever invoked `rawFulfillRandomWords` synchronously inside `requestRandomWordsInNative` with `requestId == 0`, `requestId == vrfRequestId` (`0 == 0`) would pass and resolve the raffle before `requestDraw` finished recording the request.

`[Why: Raffle.sol:515]`
Why does `fulfillRandomWords` emit `VrfCallbackIgnored` and `return` instead of reverting when a callback arrives at or after `callbackDeadline()`?
Because reverting inside the VRF callback would cause the Chainlink wrapper fulfillment transaction to fail or be retried unnecessarily, whereas returning cleanly preserves liveness while allowing `enableRefunds()` to transition the raffle to `Refunding`.

`[Defeat: requestDraw]`
1. Attacker force-sends 1 ETH to the `Raffle` clone (e.g. via `selfdestruct`) and calls `requestDraw()` hoping `excess` refunds the pre-existing balance: defeated at `Raffle.sol:262` because `excess` is computed strictly as `msg.value - paidPrice`, never from `address(this).balance`.
2. Attacker calls `requestDraw()` from a contract whose `receive()` reverts when receiving `excess` ETH to lock the raffle: the revert at `Raffle.sol:269` (`NativeRefundFailed`) rolls back the entire `requestDraw()` call, leaving `status == Status.Active` so any honest caller can call `requestDraw()`.
3. Attacker calls `requestDraw()` a second time while `status == Status.Drawing` to overwrite `vrfRequestId` and reset `drawRequestedAt`: defeated at `Raffle.sol:241` (`_requireStatus(Status.Active)`).

`[Defeat: fulfillRandomWords]`
1. Attacker calls `rawFulfillRandomWords` directly with a chosen `randomWords` array: defeated at `VRFV2PlusWrapperConsumerBase.sol:103` (`if (msg.sender != vrfWrapperAddr) revert OnlyVRFWrapperCanFulfill(...)`).
2. Wrapper delivers a duplicate callback after the raffle already resolved to `NftWon` or `CashWon`: defeated at `Raffle.sol:511` (`status != Status.Drawing` causes `fulfillRandomWords` to emit `VrfCallbackIgnored` and return without modifying `winningEntry` or `status`).
3. Wrapper delivers callback in the exact block where `block.timestamp == callbackDeadline()`: `fulfillRandomWords` requires `block.timestamp < callbackDeadline()` (`Raffle.sol:512`) while `enableRefunds` requires `block.timestamp >= callbackDeadline()` (`Raffle.sol:291`), so the two paths are mutually exclusive at every timestamp.

`[Defeat: enableRefunds]`
1. Non-sponsor calls `enableRefunds()` on an empty raffle (`totalEntries == 0`) at `block.timestamp == endTime - 1`: defeated at `Raffle.sol:282-284` (`revert RefundsNotAvailable(endTime, block.timestamp)`).
2. Attacker calls `enableRefunds()` on a sold raffle (`totalEntries > 0`) at `block.timestamp == endTime + 2 days - 1`: defeated at `Raffle.sol:287` (`revert RefundsNotAvailable(drawRequestDeadline(), block.timestamp)`).
3. Attacker calls `enableRefunds()` after `status` has already transitioned to `NftWon`, `CashWon`, or `Refunding`: defeated at `Raffle.sol:293` (`revert InvalidStatus(status)`).

---

### 4. Settlement, Redemption & Refund Boundaries (`_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `refundTickets`)

`[Model: _settleWinningTicket]`
In `_settleWinningTicket`, when the raffle is in `NftWon` or `CashWon` and `settlementComplete` is false, a caller supplies a candidate `ticketId`. The function verifies that `winningEntry` lies within `_ticketRanges[ticketId]`, reads `grossPot = unsettledPot`, computes `protocolFee = floor(grossPot * 500 / 10_000)`, and either allocates `sponsorAmount = grossPot - protocolFee` (in `NftWon`) or allocates `cashAmount = floor(grossPot * 8000 / 10_000)` to `winnerProceeds` and `sponsorAmount = grossPot - protocolFee - cashAmount` (in `CashWon`). It sets `settlementComplete = true`, records `winningTicketId = ticketId`, zeroes `unsettledPot`, and writes `sponsorProceeds` and `protocolFees`.

`[Model: redeemWinningTicket]`
In `redeemWinningTicket`, when `status` is `NftWon` or `CashWon` and `winnerRedeemed` is false, the current owner of the winning ticket calls the function (settling the ticket first if `settlementComplete` is false, or checking `ticketId == winningTicketId` if already settled). It verifies `msg.sender == ownerOf(ticketId)`, records `winnerRecipient = winner` and `winnerRedeemed = true`, and burns `ticketId`. If `status == NftWon`, it sets `prizeClaimed = true` and transfers the prize NFT to `winner` (verifying `prizeToken.ownerOf(prizeTokenId) == winner`); if `status == CashWon`, it zeroes `winnerProceeds` and transfers that USDC amount to `winner`.

`[Model: releaseSponsorProceeds]`
In `releaseSponsorProceeds`, any caller triggers the withdrawal of `sponsorProceeds` (reverting if zero), zeroes `sponsorProceeds`, and transfers the USDC amount to `sponsorRecipient`.

`[Model: releaseProtocolFees]`
In `releaseProtocolFees`, any caller triggers the withdrawal of `protocolFees` (reverting if zero), zeroes `protocolFees`, and transfers the USDC amount to `protocolTreasury`.

`[Model: releaseSponsorPrize]`
In `releaseSponsorPrize`, when `status` is `CashWon` or `Refunding` and `prizeClaimed` is false, any caller sets `prizeClaimed = true` and transfers the escrowed prize NFT back to `sponsorRecipient`, verifying `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

`[Model: refundTickets]`
In `refundTickets`, while `status == Status.Refunding`, a ticket owner passes a batch of 1 to 100 `ticketIds`. For each ticket, the function verifies `msg.sender == ownerOf(ticketId)`, adds `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns the ticket. It then computes `amount = aggregateEntries * 1,000,000`, decrements `remainingRefundLiability` by `amount`, and transfers `amount` USDC to `msg.sender`.

`[Why: Raffle.sol:565]`
Why does `_transferQuote` re-check `_isProtocolDestination(to, address(prizeToken))` at payout time when `sponsorRecipient`, `protocolTreasury`, and ticket owners were already screened during `initialize` or `_update`?
Because `isRaffle(to)` inside `_isProtocolDestination` is mutable over time: an address that had `code.length == 0` when stored in `initialize` or `_update` can become a registered `Raffle` clone before `_transferQuote` executes. However, re-checking `_isProtocolDestination` only inside `_transferQuote` causes USDC claims to revert while `releaseSponsorPrize` and `redeemWinningTicket` (in `NftWon`) lack the same check and transfer the ERC-721 prize directly into the clone.

`[Defeat: redeemWinningTicket]`
1. Non-owner calls `settleWinningTicket(winningTicketId)` first to front-run the winner's `redeemWinningTicket(winningTicketId)`: `settleWinningTicket` only allocates storage liabilities without reading ownership, and `redeemWinningTicket` subsequently takes the `else if (ticketId != winningTicketId)` branch and still pays `ownerOf(winningTicketId)`.
2. Attacker passes `ticketId = 0` (unminted ticket) to `settleWinningTicket(0)`: `_ticketRanges[0]` is `(0, 0)` while `winningEntry >= 1`, so `_requireWinningTicket(0)` reverts with `TicketDoesNotContainWinningEntry(0, winningEntry)`.
3. Winner transfers `winningTicketId` after `settleWinningTicket(winningTicketId)` has completed: `_settleWinningTicket` does not snapshot `ownerOf(winningTicketId)`, so the new owner of `winningTicketId` can call `redeemWinningTicket(winningTicketId)` and receive the prize.

`[Defeat: refundTickets]`
1. Attacker passes duplicate `ticketId`s `[1, 1]` in the `ticketIds` array to double-claim a refund: the first iteration calls `_burn(1)`, so the second iteration's `ownerOf(1)` call reverts with `ERC721NonexistentToken(1)`.
2. Attacker passes a burned winning ticket in `refundTickets`: `refundTickets` requires `status == Status.Refunding`, which is mutually exclusive with `NftWon` and `CashWon`.
3. Attacker mints 10,000 entries in a single ticket to exceed the batch limit on refund: `MAX_REFUND_TICKET_BATCH_SIZE = 100` bounds the number of ERC-721 tickets per call, not the entry count per ticket, so 1 ticket representing 10,000 entries refunds in O(1) gas.

---

### 5. Last User Out Tests

`[LastOut: NftWon]`
Suppose Buyers 1..N purchase `totalEntries >= reserveEntries` for `grossPot = totalEntries * 1,000,000` USDC. After VRF resolution to `Status.NftWon` and `_settleWinningTicket`, `protocolFees = floor(grossPot * 500 / 10_000)` and `sponsorProceeds = grossPot - protocolFees`. Because `1,000,000` is a multiple of `10,000`, both allocations are exact integers summing to `grossPot`. Regardless of the order in which `redeemWinningTicket`, `releaseSponsorProceeds`, and `releaseProtocolFees` are called, the last user out is paid in full with 0 shortfall and 0 dust left behind.

`[LastOut: CashWon]`
Suppose Buyers 1..N purchase `0 < totalEntries < reserveEntries` for `grossPot = totalEntries * 1,000,000` USDC. After VRF resolution to `Status.CashWon` and `_settleWinningTicket`, `protocolFees = floor(grossPot * 500 / 10_000)`, `winnerProceeds = floor(grossPot * 8000 / 10_000)`, and `sponsorProceeds = grossPot - protocolFees - winnerProceeds`. Because `protocolFees + winnerProceeds + sponsorProceeds == grossPot`, in every withdrawal order across the cash winner, `sponsorRecipient` (for both USDC and returned NFT), and `protocolTreasury`, the last claimant out is paid in full with 0 shortfall.

`[LastOut: Refunding]`
Suppose Buyers 1..N purchase `ticketCount` tickets partitioning `[1, totalEntries]` for `unsettledPot = totalEntries * 1,000,000` USDC, and `enableRefunds()` transitions the raffle to `Status.Refunding` with `remainingRefundLiability = unsettledPot`. Because `_ticketRanges[1..ticketCount]` is an exact contiguous partition of `[1, totalEntries]` and each ticket is burned once in `refundTickets`, the sum of `(lastEntry - firstEntry + 1) * 1,000,000` across all tickets equals `remainingRefundLiability`. Regardless of the order in which ticket holders call `refundTickets` and `releaseSponsorPrize` is called, the last ticket holder out is paid 100% of their refund in full, reducing `remainingRefundLiability` and the contract's USDC balance to 0.

---

## Findings & Leads

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: async-destination-screening-drift | group_key: Raffle | _isProtocolDestination | async-destination-screening-drift
smell: In Raffle.sol:602-604 and RaffleFactory.sol:166, _isProtocolDestination and _validateCreateParams only reject addresses where canonicalFactory.isRaffle(destination) is already true at the time of the check, allowing a precomputed future Raffle clone address (deterministic CREATE address from RaffleFactory's nonce) to be set as sponsorRecipient, protocolTreasury, or ticket owner before that clone is deployed, after which _transferQuote reverts with InvalidQuoteDestination while releaseSponsorPrize/redeemWinningTicket transfers the ERC-721 prize into the other Raffle clone.
unverified: Whether an honest sponsor, buyer, or factory deployer would ever supply a precomputed future CREATE address of RaffleFactory without self-inflicted misconfiguration.
description: Because RaffleFactory deploys clones deterministically via CREATE, an address that passes _isProtocolDestination at initialization or ticket transfer time with code.length == 0 can become a registered Raffle clone before settlement/claim time, permanently locking USDC payouts in _transferQuote and allowing releaseSponsorPrize to move the prize NFT into another Raffle clone.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: decoupled-settlement-prize-delivery | group_key: Raffle | releaseSponsorProceeds | decoupled-settlement-prize-delivery
smell: In Raffle.sol:375-382 and Raffle.sol:533-558, settleWinningTicket and releaseSponsorProceeds allocate and pay out 95% of the USDC pot to sponsorRecipient in Status.NftWon without requiring prizeClaimed == true (or verifying that prizeToken.transferFrom to the winner succeeds).
unverified: Under IRaffle.sol's assumption that supported prizes are honest, standards-compliant ERC-721s, prizeToken.transferFrom will not revert; a loss to buyers only occurs under DESIGN.md's broader statement that arbitrary prize contracts are untrusted (e.g., a malicious, pausable, or transfer-restricted ERC-721 that blocks transferFrom after escrow).
description: If an escrowed prizeToken reverts or blocks transfers when redeemWinningTicket is called in Status.NftWon, the decoupled storage-only settlement still allows the sponsor to withdraw 95% of the buyers' USDC via releaseSponsorProceeds while the winner cannot redeem the prize NFT.
```

