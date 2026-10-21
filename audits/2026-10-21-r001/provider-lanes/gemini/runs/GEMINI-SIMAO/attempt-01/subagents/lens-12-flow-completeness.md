# 0xSimao Audit — Lens 12 (Flow Completeness & Symmetry)

## Phase 0 & Phase 1 — Protocol Vocabulary, Money Map & Symmetry Analysis

### Forward / Inverse & Sibling Symmetry Tables

#### 1. Asset Custody & Outflow Symmetry (`Raffle.sol`, `RaffleFactory.sol`)

| Flow / Sibling | Entry / Allocation Check | Exit / Claim Check | Delivery Mechanism | Symmetry Gap |
|---|---|---|---|---|
| **Quote Token (`USDC`) — `buyEntries` vs `_transferQuote` (`redeemWinningTicket` in `CashWon`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`)** | `initialize` checks `_isProtocolDestination` on `sponsor`, `protocolTreasury`, `sponsorRecipient`; `_update` checks `_isProtocolDestination` on ticket `to`. | `_transferQuote` (`Raffle.sol:565`) re-checks `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` before `quoteToken.safeTransfer(to, amount)`. | `SafeERC20.safeTransfer` | `_isProtocolDestination` (`Raffle.sol:602-604`) only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`. Because `RaffleFactory` uses `Clones.clone` (`CREATE`, deterministic from factory nonce), a future clone address passes `initialize` and `_update` before deployment (`code.length == 0`, `isRaffle == false`), and then reverts at claim time in `_transferQuote` once deployed (`code.length != 0`, `isRaffle == true`), permanently locking USDC claims. |
| **Prize NFT (`prizeToken`) — `createRaffle` + `onERC721Received` vs `redeemWinningTicket` (`NftWon`) & `releaseSponsorPrize` (`CashWon` / `Refunding`)** | `RaffleFactory::createRaffle` checks `supportsInterface(IERC721)`, calls `prize.safeTransferFrom(msg.sender, raffle, prizeTokenId)`, `onERC721Received` sets `status = Active`, factory verifies `prize.ownerOf(prizeTokenId) == raffle` and `status == Active`. | `redeemWinningTicket` (`Raffle.sol:334`) and `releaseSponsorPrize` (`Raffle.sol:404`) check `!prizeClaimed`, set `prizeClaimed = true`, call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)`, and verify `prizeToken.ownerOf(prizeTokenId) == recipient`. | `IERC721.transferFrom` + `ownerOf` check (no `onERC721Received` callback). | 1. Neither `redeemWinningTicket` (`Raffle.sol:334`) nor `releaseSponsorPrize` (`Raffle.sol:404`) calls `_isProtocolDestination(recipient, address(prizeToken))`, unlike `_transferQuote` (`Raffle.sol:565`). If `recipient` is a future `Raffle` clone address deployed after `initialize`/`_update`, `transferFrom` bypasses `onERC721Received` and permanently locks the Prize NFT inside the other `Raffle` clone (violating `DESIGN.md`: *"Never move assets between raffle clones"*).<br>2. In `Status.NftWon`, `_settleWinningTicket` (`Raffle.sol:544, 554`) and `releaseSponsorProceeds` (`Raffle.sol:375`) allow the sponsor to withdraw 95% of user USDC without requiring `prizeClaimed == true` (i.e., before verifying that the untrusted `prizeToken` actually allowed the winner to claim the NFT). |
| **Reentrancy Guard Symmetry (`Raffle` vs `ERC721` vs `RaffleFactory`)** | `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize` have `nonReentrant`. | `ERC721::transferFrom`, `ERC721::safeTransferFrom`, `ERC721::approve`, `ERC721::setApprovalForAll`, and `Raffle::onERC721Received` do **not** have `nonReentrant`. | `_safeMint` in `buyEntries` calls `recipient.onERC721Received`; `createRaffle` calls `prize.safeTransferFrom`. | During `buyEntries`, `recipient.onERC721Received` can call `transferFrom` on the newly minted ticket before `TicketPurchased` is emitted. During `createRaffle`, `raffle.onERC721Received` sets `status = Active` before `prize.safeTransferFrom` returns to `RaffleFactory`. |

---

## Reasoning Protocol Walkthrough

`[Model: createRaffle]`
A sponsor supplies an NFT they own along with a sale end time, a reserve entry threshold, and a recipient address for their proceeds. The factory deploys a fresh raffle clone, initializes its configuration, registers it as a valid raffle, and moves the sponsor's NFT into the clone. Upon receiving the NFT, the clone switches its status from waiting-for-prize to active, and the factory confirms the clone now owns the NFT and is active. No USDC totals change yet; `raffleCount` increases by one and the clone's `status` becomes `Active`.

`[Why: RaffleFactory.sol:128]`
Why does `RaffleFactory::createRaffle` call `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` after setting `isRaffle[raffle] = true`, while `Raffle::onERC721Received` immediately sets `status = Status.Active` inside the callback before `safeTransferFrom` finishes?
Because `Raffle::onERC721Received` is the hook that transitions the clone from `AwaitingPrize` to `Active`. The implicit belief is that `prize.safeTransferFrom` will immediately return control to `RaffleFactory::createRaffle` after `raffle.onERC721Received` runs, or that lines 129-134 (`ownerOf` and `status` checks) prevent any state mutation on `raffle` before `createRaffle` finishes. However, `raffle`'s own `ReentrancyGuard` is not entered during `createRaffle`, so an untrusted `prizeToken` contract can call `raffle.buyEntries` after `onERC721Received` sets `status = Status.Active` and before `RaffleCreated` is emitted.

`[Defeat: createRaffle]`
1. Sponsor calls `createRaffle` with `sponsorRecipient` set to the precomputed `CREATE` address of the next clone `R_next = keccak256(rlp([address(factory), nonce + 1]))[12:]`. Because `R_next.code.length == 0` and `isRaffle[R_next] == false` at creation time, both `_validateCreateParams` (`RaffleFactory.sol:166`) and `Raffle::initialize` (`Raffle.sol:194`) pass.
2. Sponsor (or anyone) then calls `createRaffle` a second time, deploying the next raffle clone at `R_next` and setting `isRaffle[R_next] = true`.
3. When the first raffle finishes in `CashWon` or `Refunding`, calling `releaseSponsorPrize()` transfers the prize NFT via `prizeToken.transferFrom` directly into `R_next` (bypassing `R_next.onERC721Received`), permanently locking the NFT inside `R_next` and violating `DESIGN.md` ("Never move assets between raffle clones"), while `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(R_next)`.

`[Model: buyEntries]`
A buyer pays `entryCount * 1,000,000` USDC into the raffle while the raffle is active and before `endTime`. In return, the raffle assigns the next contiguous block of entry numbers `[totalEntries + 1, totalEntries + entryCount]` to a new sequential ticket ID `ticketCount + 1`, increments `totalEntries` by `entryCount`, increments `ticketCount` by 1, increases `unsettledPot` by the USDC amount paid, and mints the ERC-721 ticket to `recipient` (invoking `recipient.onERC721Received` if `recipient` is a contract).

`[Why: Raffle.sol:602]`
Why does `_isProtocolDestination` check `if (!unsafeDestination && destination.code.length != 0)` before calling `canonicalFactory.isRaffle(destination)`?
The code rests on the implicit belief that a protocol raffle clone always has `code.length != 0` at the moment its address is screened in `initialize` or `_update`. That belief fails for deterministic future `CREATE` addresses of `RaffleFactory`, which have `code.length == 0` (and `isRaffle == false`) when screened in `initialize` or `_update`, but acquire `code.length == 45` and `isRaffle == true` as soon as `RaffleFactory::createRaffle` reaches that nonce.

`[Defeat: buyEntries]`
1. Buyer calls `buyEntries(recipient, 5)` where `recipient` is a smart contract implementing `IERC721Receiver`. Inside `recipient.onERC721Received`, `Raffle`'s `nonReentrant` lock is held, blocking state-changing raffle functions, but `ERC721::transferFrom` has no `nonReentrant` modifier, allowing `recipient` to transfer `ticketId` to `0xBeef` before `TicketPurchased` is emitted.
2. Buyer calls `buyEntries(R_future, 10)` where `R_future` is the deterministic `CREATE` address of the next `RaffleFactory` clone (`nonce`-derived). Because `R_future.code.length == 0` prior to its deployment, `_isProtocolDestination(R_future, address(prizeToken))` in `_update` returns `false` and `ERC721Utils.checkOnERC721Received` skips the callback. Once `R_future` is deployed via `createRaffle`, `ticketId` is owned by a `Raffle` clone that has no function to transfer, redeem, or refund it.
3. Buyer attempts `buyEntries(recipient, type(uint128).max)` after 1 entry is already sold; line 219 (`if (entryCount > type(uint128).max - totalEntries)`) reverts with `TotalEntriesOverflow(1, type(uint128).max)`.

`[Model: requestDraw]`
After `endTime` and before `endTime + 2 days`, any caller on an active raffle with at least one sold entry sends native ETH to cover the Chainlink VRF wrapper fee. The raffle switches `status` to `Drawing`, records `drawRequestedAt = block.timestamp`, sets `_requestInFlight = true`, pays the VRF wrapper the exact `paidPrice` in native ETH for 1 random word, records `vrfRequestId`, clears `_requestInFlight`, and refunds `msg.value - paidPrice` in native ETH back to `msg.sender`. No USDC totals change.

`[Why: Raffle.sol:258]`
Why does `requestDraw` check `if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value)` at line 258 after already checking `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` at line 250?
Because `requestRandomnessPayInNative` calls `i_vrfV2PlusWrapper.calculateRequestPriceNative` a second time and sends `{value: requestPrice}` from `address(this).balance`. If ETH had been forced into `Raffle` via `selfdestruct` and the wrapper returned a higher `paidPrice` on the second call, the external call could succeed using the contract's forced ETH balance and then underflow `msg.value - paidPrice` at line 262.

`[Defeat: requestDraw]`
1. Caller invokes `requestDraw()` from a contract whose `fallback`/`receive` attempts to re-enter `Raffle` when receiving the `excess = msg.value - paidPrice` native refund at line 267; `nonReentrant` blocks re-entry into all raffle state transitions.
2. Malicious wrapper or synchronous callback attempts to call `rawFulfillRandomWords` inside `requestRandomnessPayInNative` before `vrfRequestId` is stored at line 259; `_requestInFlight == true` causes `fulfillRandomWords` at line 511 to emit `VrfCallbackIgnored` and return without resolving.
3. Caller sends exact `msg.value == quotedFee` from a contract that reverts on `receive()`; because `excess == 0`, line 263 skips the native transfer call so the draw request still succeeds.

`[Model: fulfillRandomWords]`
When the Chainlink VRF wrapper calls `rawFulfillRandomWords` while `status == Drawing`, `_requestInFlight == false`, `requestId == vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < drawRequestedAt + 2 days`, the raffle maps `randomWords[0]` uniformly into `[1, totalEntries]` to set `winningEntry`, records `resolvedAt = block.timestamp`, and sets `status` to `NftWon` if `totalEntries >= reserveEntries` or `CashWon` if `totalEntries < reserveEntries`.

`[Model: _settleWinningTicket]`
Once the raffle is in `NftWon` or `CashWon`, any caller supplies a `ticketId` whose `[firstEntry, lastEntry]` range contains `winningEntry`. The function reads `grossPot = unsettledPot`, sets `unsettledPot = 0`, marks `settlementComplete = true`, records `winningTicketId = ticketId`, allocates `protocolFees = floor(grossPot * 500 / 10000)` (5%), and in `NftWon` allocates the remaining 95% (`grossPot - protocolFee`) to `sponsorProceeds`, or in `CashWon` allocates `winnerProceeds = floor(grossPot * 8000 / 10000)` (80%) and the remaining 15% (`grossPot - protocolFee - cashAmount`) to `sponsorProceeds`.

`[Why: Raffle.sol:543]`
Why does `_settleWinningTicket` allocate `sponsorAmount = grossPot - protocolFee` (95% of the pot) to `sponsorProceeds` in `Status.NftWon` without requiring that the winner has received (or can receive) the NFT from `prizeToken`?
The code assumes `prizeToken` remains permanently honest and transferable after creation (`createRaffle`), so that `sponsorProceeds` can be settled and claimed independently of `redeemWinningTicket`. However, `createRaffle` is permissionless and accepts any contract that passes `supportsInterface(IERC721)` and an initial `safeTransferFrom(sponsor, raffle, prizeTokenId)`. If `prizeToken` is controlled by the sponsor (or is paused/blacklisted/upgraded after escrow) and reverts when `raffle` calls `prizeToken.transferFrom(address(this), winner, prizeTokenId)` in `redeemWinningTicket`, the sponsor still extracts 95% of all buyers' USDC via `settleWinningTicket` + `releaseSponsorProceeds` while the winner can never claim the NFT and buyers can never get a refund.

`[Model: redeemWinningTicket]`
The current owner of the winning ticket calls `redeemWinningTicket(ticketId)` in `NftWon` or `CashWon`. If settlement has not run yet, it settles `ticketId` first. It verifies `msg.sender == ownerOf(ticketId)`, records `winnerRecipient = winner`, sets `winnerRedeemed = true`, and burns `ticketId`. If `status == NftWon`, it sets `prizeClaimed = true`, transfers `prizeTokenId` to `winner` via `prizeToken.transferFrom`, and checks `prizeToken.ownerOf(prizeTokenId) == winner`. If `status == CashWon`, it zeroes `winnerProceeds` and transfers that USDC amount to `winner`.

`[Model: enableRefunds]`
If a raffle has 0 entries (callable by `sponsor` before `endTime` or anyone at/after `endTime`), or is still `Active` at `endTime + 2 days`, or is still `Drawing` at `drawRequestedAt + 2 days`, `enableRefunds` moves the entire `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and sets `status = Status.Refunding`.

`[Model: refundTickets]`
In `Status.Refunding`, a ticket owner passes 1 to 100 `ticketIds` they own. For each ticket, the function verifies `msg.sender == ownerOf(ticketId)`, adds `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns the ticket. It then computes `amount = aggregateEntries * ENTRY_PRICE`, decrements `remainingRefundLiability` by `amount`, and transfers `amount` USDC to `msg.sender`.

`[Model: releaseSponsorProceeds]`
After settlement, anyone calls `releaseSponsorProceeds()`, which reads `amount = sponsorProceeds`, reverts if 0, sets `sponsorProceeds = 0`, and transfers `amount` USDC to `sponsorRecipient` (after checking `_isProtocolDestination`).

`[Model: releaseProtocolFees]`
After settlement, anyone calls `releaseProtocolFees()`, which reads `amount = protocolFees`, reverts if 0, sets `protocolFees = 0`, and transfers `amount` USDC to `protocolTreasury` (after checking `_isProtocolDestination`).

`[Model: releaseSponsorPrize]`
In `Status.CashWon` or `Status.Refunding`, anyone calls `releaseSponsorPrize()`, which checks `!prizeClaimed`, sets `prizeClaimed = true`, transfers `prizeTokenId` from `address(this)` to `sponsorRecipient` via `prizeToken.transferFrom`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

`[Why: Raffle.sol:404]`
Why does `releaseSponsorPrize()` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` directly without checking `_isProtocolDestination(recipient, address(prizeToken))`, whereas `releaseSponsorProceeds()` right above it calls `_transferQuote(recipient, amount)` which checks `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)`?
Because the author assumed `recipient` (`sponsorRecipient`) was already validated once in `initialize()` and forgot both (a) to include the runtime `_isProtocolDestination` check in `releaseSponsorPrize()` and `redeemWinningTicket()` (`NftWon`), and (b) that `transferFrom` (unlike `safeTransferFrom`) does not trigger `Raffle::onERC721Received` when `recipient` is a `Raffle` clone.

`[LastOut: Reserve Met (NftWon)]`
Suppose `reserveEntries = 100`. Buyer 1 buys 60 entries (`60,000,000` USDC, `ticketId = 1`, `[1, 60]`) and Buyer 2 buys 40 entries (`40,000,000` USDC, `ticketId = 2`, `[61, 100]`). `unsettledPot = 100,000,000` USDC. Draw resolves to `winningEntry = 75` (`ticketId = 2`, `status = NftWon`). `_settleWinningTicket(2)` sets `unsettledPot = 0`, `protocolFees = 5,000,000`, `sponsorProceeds = 95,000,000`, `winnerProceeds = 0`.
1. `releaseProtocolFees()` pays `5,000,000` USDC to `protocolTreasury` (`5,000,000` out, `95,000,000` remaining).
2. `releaseSponsorProceeds()` pays `95,000,000` USDC to `sponsorRecipient` (`95,000,000` out, `0` remaining, `accountedQuoteBalance() == 0`).
3. Buyer 2 calls `redeemWinningTicket(2)` and receives `prizeTokenId` (`prizeClaimed = true`).
Wait — if `prizeToken` is a malicious or paused/restricted ERC-721 that reverts in `prizeToken.transferFrom(address(this), winner, prizeTokenId)`, steps 1 and 2 STILL succeed and drain 100% of the `100,000,000` USDC from the contract (95% to `sponsorRecipient`, 5% to `protocolTreasury`), while Buyer 2 (the last user out in `redeemWinningTicket(2)`) reverts forever and receives neither the NFT nor a USDC refund!

`[LastOut: Reserve Missed (CashWon)]`
Suppose `reserveEntries = 10`. Buyer 1 buys 1 entry (`1,000,000` USDC, `ticketId = 1`, `[1, 1]`). Draw resolves to `winningEntry = 1`, `status = CashWon`. `_settleWinningTicket(1)` sets `unsettledPot = 0`, `protocolFees = 50,000`, `winnerProceeds = 800,000`, `sponsorProceeds = 150,000`.
1. `releaseProtocolFees()` pays `50,000` USDC to `protocolTreasury` (`950,000` remaining).
2. `releaseSponsorProceeds()` pays `150,000` USDC to `sponsorRecipient` (`800,000` remaining).
3. `redeemWinningTicket(1)` pays `800,000` USDC to Buyer 1 (`0` remaining, `accountedQuoteBalance() == 0`).
4. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
Because `ENTRY_PRICE = 1_000_000` is a multiple of `BPS = 10_000` and `sponsorProceeds = grossPot - protocolFee - cashAmount`, the last claimant gets paid in full with zero shortfall (unless `sponsorRecipient` or Buyer 1's ticket owner is a future `Raffle` clone address that was deployed after `initialize`/`_update`, in which case `_transferQuote` reverts with `InvalidQuoteDestination`).

`[LastOut: Refund (Refunding)]`
Suppose Buyer 1 buys 3 entries (`3,000,000` USDC, `ticketId = 1`, `[1, 3]`) and Buyer 2 buys 7 entries (`7,000,000` USDC, `ticketId = 2`, `[4, 10]`). At `drawRequestDeadline()`, `enableRefunds()` sets `unsettledPot = 0` and `remainingRefundLiability = 10,000,000`.
1. Buyer 2 calls `refundTickets([2])`, burning `ticketId = 2` and receiving `7 * 1,000,000 = 7,000,000` USDC (`remainingRefundLiability = 3,000,000`).
2. Buyer 1 (last user out) calls `refundTickets([1])`, burning `ticketId = 1` and receiving `3 * 1,000,000 = 3,000,000` USDC (`remainingRefundLiability = 0`, `accountedQuoteBalance() == 0`).
3. `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
Every ticket holder gets paid 100% in full with zero shortfall.

---

## Findings & Leads

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: missing-precondition-check | group_key: Raffle | releaseSponsorProceeds | missing-precondition-check
root_cause: In `Raffle.sol:375` (`releaseSponsorProceeds`) and `Raffle.sol:543-554` (`_settleWinningTicket`), `sponsorProceeds` (95% of `unsettledPot`) is allocated and released to `sponsorRecipient` in `Status.NftWon` without checking `prizeClaimed` (i.e. without requiring that `prizeToken.transferFrom(address(this), winner, prizeTokenId)` in `redeemWinningTicket` has succeeded).
internal_pre: None
external_pre: None
path:
  1. Malicious sponsor deploys an ERC-721 contract `MaliciousPrize` (or uses an ERC-721 with a pause/blocklist/transfer restriction they control) that returns `true` for `supportsInterface(0x80ac58cd)` and allows `safeTransferFrom` when `from == sponsor`, but reverts inside `transferFrom` when `from != sponsor`.
  2. Sponsor calls `RaffleFactory::createRaffle` with `prizeToken = address(MaliciousPrize)`, `prizeTokenId = 1`, `reserveEntries = 100`, `sponsorRecipient = sponsor`. `createRaffle` escrows token ID 1 into the new `Raffle` clone and activates it (`status = Status.Active`).
  3. Honest buyers purchase 100 entries via `buyEntries` for `100,000,000` USDC (`100 USDC`, `totalEntries = 100 == reserveEntries`).
  4. After `endTime`, `requestDraw()` is called and Chainlink VRF fulfills randomness, setting `status = Status.NftWon`.
  5. Sponsor calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()`, withdrawing `95,000,000` USDC (`95 USDC`) to `sponsorRecipient` while `protocolTreasury` receives `5,000,000` USDC (`5 USDC`).
  6. When the winning ticket owner calls `redeemWinningTicket(winningTicketId)`, `prizeToken.transferFrom(address(this), winner, 1)` at `Raffle.sol:334` reverts, and `enableRefunds()` is permanently unreachable because `status == Status.NftWon`.
impact: Ticket buyers lose 100% of their entry funds (`100 USDC`, with `95 USDC` taken by the sponsor and `5 USDC` to `protocolTreasury`), and the winning ticket owner is left holding an unredeemable ticket with neither the NFT prize nor any USDC payout.
mitigation: In `Raffle::releaseSponsorProceeds()` (`Raffle.sol:375`), require `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();` (or deliver the NFT to `ownerOf(winningTicketId)` during `_settleWinningTicket` when `status == Status.NftWon` since `prizeToken.transferFrom` does not invoke receiver callbacks on the winner) before releasing `sponsorProceeds`.

FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: incomplete-destination-check | group_key: Raffle | _isProtocolDestination | incomplete-destination-check
root_cause: In `Raffle.sol:602-604`, `_isProtocolDestination` only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`, failing to reject precomputed `CREATE` addresses of future `Raffle` clones at `initialize`/`_update` time, while `releaseSponsorPrize` (`Raffle.sol:404`) and `redeemWinningTicket` (`Raffle.sol:334`) omit the `_isProtocolDestination` check that `_transferQuote` (`Raffle.sol:565`) performs.
internal_pre: None
external_pre: None
path:
  1. When `RaffleFactory` is at nonce `k` (e.g. `raffleCount == 0`, nonce `k = 2`), the deterministic `CREATE` address of the `(k)`-th deployment (`raffleId = 2`, deployed at factory nonce `3`) is `R2 = address(uint160(uint256(keccak256(rlp([address(factory), 3])))))`. At this moment, `R2.code.length == 0` and `factory.isRaffle(R2) == false`.
  2. Sponsor creates Raffle #1 (`raffleId = 1` at nonce `2`) with `sponsorRecipient = R2` (or a buyer calls `buyEntries(R2, 10)` in Raffle #1 for `10,000,000` USDC). Both `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:166`) and `Raffle::_isProtocolDestination` (`Raffle.sol:194, 498, 602`) pass because `R2.code.length == 0` and `isRaffle[R2] == false`, and `_safeMint` skips `onERC721Received` because `R2.code.length == 0`.
  3. Any user subsequently calls `RaffleFactory::createRaffle` to create Raffle #2, which `Clones.clone` deploys at `R2` with `R2.code.length == 45` and `factory.isRaffle(R2) = true`.
  4. When Raffle #1 resolves to `CashWon` or `Refunding`, calling permissionless `releaseSponsorPrize()` (`Raffle.sol:404`) executes `prizeToken.transferFrom(address(this), R2, prizeTokenId)` without checking `_isProtocolDestination` and without triggering `R2.onERC721Received`, moving the Prize NFT into Raffle #2 (`R2`) where it is permanently unrecoverable (violating `DESIGN.md`: "Never move assets between raffle clones").
  5. Simultaneously, `releaseSponsorProceeds()` (or `redeemWinningTicket` / `refundTickets` for a ticket owned by `R2`) calls `_transferQuote(R2, amount)` (`Raffle.sol:565`), which now sees `R2.code.length != 0 && canonicalFactory.isRaffle(R2) == true` and permanently reverts with `InvalidQuoteDestination(R2)`.
impact: The Prize NFT transferred via `releaseSponsorPrize()` (or `redeemWinningTicket` in `NftWon`) is moved into another `Raffle` clone (`R2`) and permanently frozen there, and the corresponding USDC claim (`sponsorProceeds`, `winnerProceeds`, or `remainingRefundLiability`) is permanently locked in Raffle #1 so `accountedQuoteBalance()` can never reach 0.
mitigation: In `Raffle::releaseSponsorPrize()` (`Raffle.sol:401`) and `Raffle::redeemWinningTicket()` (`Raffle.sol:331`), check `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` before calling `prizeToken.transferFrom`, and switch `RaffleFactory::createRaffle` to `Clones.cloneDeterministic` with a salt commitment (`keccak256(abi.encode(msg.sender, raffleId, block.timestamp, params))`) so future clone addresses cannot be precomputed as EOA-like addresses before creation.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: reentrancy-state-exposure | group_key: RaffleFactory | createRaffle | reentrancy-state-exposure
smell: In `RaffleFactory.sol:128`, `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` triggers `Raffle::onERC721Received` (`Raffle.sol:428`), which sets `raffle.status = Status.Active` while `raffle`'s own `ReentrancyGuard` is `NOT_ENTERED` and before `RaffleFactory::createRaffle` verifies `prize.ownerOf(params.prizeTokenId) == raffle` (`RaffleFactory.sol:129`) or emits `RaffleCreated` (`RaffleFactory.sol:136`).
unverified: Because `RaffleFactory::createRaffle` checks `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active` immediately after `safeTransferFrom` returns (`RaffleFactory.sol:129-134`), a reentrant call from `prizeToken` cannot leave `raffle` in `Active` without holding the NFT, though it can execute `raffle.buyEntries` and emit `TicketPurchased` before `RaffleCreated` is emitted.
description: An untrusted `prizeToken` contract can re-enter `raffle.buyEntries` during `prize.safeTransferFrom` inside `createRaffle` as soon as `onERC721Received` sets `status = Status.Active`, before `RaffleFactory` completes post-transfer custody verification and emits `RaffleCreated`.

LEAD | contract: Raffle | function: _update | bug_class: missing-reentrancy-guard | group_key: Raffle | _update | missing-reentrancy-guard
smell: `Raffle::buyEntries` (`Raffle.sol:235`) is `nonReentrant` and calls `_safeMint(recipient, ticketId)` before emitting `TicketPurchased` (`Raffle.sol:236`), while `ERC721::transferFrom`, `ERC721::safeTransferFrom`, and `Raffle::_update` (`Raffle.sol:497`) do not check `_reentrancyGuardEntered()`.
unverified: Because `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are updated before `_safeMint`, re-entering `transferFrom` inside `recipient.onERC721Received` does not corrupt accounting totals, and only inverts event ordering (`Transfer(recipient, newOwner, ticketId)` is emitted before `TicketPurchased(buyer, recipient, ticketId, ...)`).
description: A contract `recipient` in `buyEntries` can re-enter `Raffle::transferFrom` inside `onERC721Received` to transfer the newly minted ticket before `buyEntries` emits `TicketPurchased`.

