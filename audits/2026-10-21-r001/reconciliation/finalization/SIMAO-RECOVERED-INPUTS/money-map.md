# Money Map — raffle.fun (`Raffle`, `RaffleFactory`, `RaffleConstants`, `IRaffle`, `IRaffleFactory`)

## 1. Assets

| Asset | Type / Standard | Enters Contract Via | Leaves Contract Via | Notes |
| --- | --- | --- | --- | --- |
| `quoteToken` | Canonical 6-decimal USDC (`IERC20`) | `Raffle::buyEntries` (`safeTransferFrom(msg.sender, address(this), grossAmount)` where `grossAmount = entryCount * 1_000_000`) | `Raffle::_transferQuote` (`safeTransfer(to, amount)`), called by `redeemWinningTicket` (`CashWon`), `refundTickets` (`Refunding`), `releaseSponsorProceeds`, `releaseProtocolFees` | Trusted non-rebasing, fee-free 6-decimal ERC-20. Never enters `RaffleFactory`. |
| `prizeToken` (`prizeTokenId`) | Untrusted standards-compliant `IERC721` | `RaffleFactory::createRaffle` (`prize.safeTransferFrom(msg.sender, raffle, prizeTokenId)`) → `Raffle::onERC721Received` | `Raffle::redeemWinningTicket` (`NftWon`: `prizeToken.transferFrom(address(this), winner, prizeTokenId)`), `Raffle::releaseSponsorPrize` (`CashWon` / `Refunding`: `prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId)`) | Untrusted contract. Verified post-transfer via `ownerOf(prizeTokenId)`. |
| Raffle Ticket (`Raffle` ERC-721) | Sequential bearer range NFT (`ERC721`) | Minted in `Raffle::buyEntries` (`_safeMint(recipient, ticketId)`) representing inclusive `[firstEntry, lastEntry]` | Burned in `Raffle::redeemWinningTicket` (`_burn(ticketId)`) or `Raffle::refundTickets` (`_burn(ticketId)` per batch item) | Transferable in all states via `ERC721::_update`, blocking `_isProtocolDestination`. |
| Native ETH | Chain native gas token | `Raffle::requestDraw` (`payable`, requires `msg.value >= getVrfRequestPrice()`) | `Raffle::requestDraw` pays `paidPrice` to `i_vrfV2PlusWrapper` via `requestRandomnessPayInNative` and refunds `excess = msg.value - paidPrice` to `msg.sender` via `call` | `receive()` reverts with `DirectNativeTransfer()` except if native ETH is force-sent (e.g., coinbase/selfdestruct). |

## 2. Tracked Totals & Accounting Variables

| Variable | Contract | Type | `+` Writes (Increases / Allocations) | `-` Writes (Decreases / Releases) | Meaning |
| --- | --- | --- | --- | --- | --- |
| `totalEntries` | `Raffle` | `uint128` | `buyEntries`: `totalEntries = lastEntry` (`+ entryCount`) | None (lifetime counter) | Total entries sold across all tickets; defines `[1, totalEntries]` draw space and `grossSales()`. |
| `ticketCount` | `Raffle` | `uint128` | `buyEntries`: `++ticketCount` | None (lifetime counter) | Total sequential ERC-721 range tickets minted. |
| `_ticketRanges[ticketId]` | `Raffle` | `TicketRange` | `buyEntries`: sets `{firstEntry, lastEntry}` | None (persists after `_burn`) | Inclusive `[firstEntry, lastEntry]` range of size `entryCount` for `ticketId`. |
| `unsettledPot` | `Raffle` | `uint256` | `buyEntries`: `unsettledPot += grossAmount` | `enableRefunds`: `unsettledPot = 0`; `_settleWinningTicket`: `unsettledPot = 0` | Unallocated USDC collected from entry sales prior to settlement or refund transition. |
| `remainingRefundLiability` | `Raffle` | `uint256` | `enableRefunds`: `remainingRefundLiability = liability` (`unsettledPot`) | `refundTickets`: `remainingRefundLiability -= amount` | Unclaimed USDC owed to unburned tickets in `Status.Refunding`. |
| `winnerProceeds` | `Raffle` | `uint256` | `_settleWinningTicket` (`CashWon` only): `winnerProceeds = cashAmount` (80% of `grossPot`) | `redeemWinningTicket` (`CashWon` only): `winnerProceeds = 0` | Unclaimed USDC owed to the current owner of `winningTicketId` when reserve is missed. |
| `sponsorProceeds` | `Raffle` | `uint256` | `_settleWinningTicket`: `sponsorProceeds = sponsorAmount` (95% in `NftWon`, 15% remainder in `CashWon`) | `releaseSponsorProceeds`: `sponsorProceeds = 0` | Unclaimed USDC owed to immutable `sponsorRecipient`. |
| `protocolFees` | `Raffle` | `uint256` | `_settleWinningTicket`: `protocolFees = protocolFee` (5% of `grossPot`) | `releaseProtocolFees`: `protocolFees = 0` | Unclaimed USDC owed to immutable `protocolTreasury`. |
| `settlementComplete` | `Raffle` | `bool` | `_settleWinningTicket`: `settlementComplete = true` | None | One-way guard preventing double allocation of `unsettledPot`. |
| `winnerRedeemed` | `Raffle` | `bool` | `redeemWinningTicket`: `winnerRedeemed = true` | None | One-way guard preventing double redemption of `winningTicketId`. |
| `prizeClaimed` | `Raffle` | `bool` | `redeemWinningTicket` (`NftWon`) / `releaseSponsorPrize` (`CashWon`, `Refunding`): `prizeClaimed = true` | None | One-way guard preventing double delivery of escrowed `prizeTokenId`. |
| `raffleCount` | `RaffleFactory` | `uint256` | `createRaffle`: `++raffleCount` | None | Monotonic 1-based counter of created raffles; populates `raffleById`, `idByRaffle`, `isRaffle`. |

## 3. The Asymmetry Table

| Tracked Total / Resource | Asymmetry / Branch / Interaction | Candidate Failure Mode to Check |
| --- | --- | --- |
| `unsettledPot` → (`winnerProceeds`, `sponsorProceeds`, `protocolFees`) | In `_settleWinningTicket`, `NftWon` allocates `protocolFees` (5%) and `sponsorProceeds` (95%), leaving `winnerProceeds = 0`; `CashWon` allocates `protocolFees` (5%), `winnerProceeds` (80%), and `sponsorProceeds = grossPot - protocolFee - cashAmount` (15%). | Verify conservation of `unsettledPot` across both branches and check if `winnerProceeds == 0` in `CashWon` can ever revert `redeemWinningTicket` with `NoWinnerProceeds()`. |
| `totalEntries` vs `remainingRefundLiability` | `totalEntries` and `_ticketRanges[ticketId]` are never decremented/cleared in `refundTickets`, whereas `_burn(ticketId)` removes `ownerOf(ticketId)` and `remainingRefundLiability -= amount` decrements liability. | Check whether historical `_ticketRanges` or unchanged `totalEntries` can be reused after `_burn(ticketId)` in `refundTickets` or `redeemWinningTicket`. |
| Native ETH in `requestDraw` vs `VRFV2PlusWrapperConsumerBase` | `requestDraw` checks `msg.value >= quotedFee` and refunds `msg.value - paidPrice`, while inherited `requestRandomnessPayInNative` interacts with `i_vrfV2PlusWrapper` using native value. | Check whether `VRFV2PlusWrapperConsumerBase::requestRandomnessPayInNative` forwards `paidPrice` or `address(this).balance`, and what happens if forced ETH exists on `Raffle`. |
| `prizeToken` (untrusted ERC-721) vs `Raffle` / `RaffleFactory` | `createRaffle` uses `safeTransferFrom`; `redeemWinningTicket` and `releaseSponsorPrize` use `transferFrom` + `ownerOf` check; `_update` and `_transferQuote` call `_isProtocolDestination` which queries `factory`. | Check reentrancy, gas griefing, non-standard `ownerOf`/`transferFrom` behaviors, or callback manipulation from untrusted `prizeToken` or ticket recipients (`_safeMint`). |
| `Status.Drawing` callback window (`fulfillRandomWords` vs `enableRefunds`) | `fulfillRandomWords` ignores callbacks (returns without reverting) if `_requestInFlight`, `status != Status.Drawing`, `requestId != vrfRequestId`, `randomWords.length != 1`, or `block.timestamp >= callbackDeadline()`. | Check boundary at `block.timestamp == callbackDeadline()`, gas exhaustion inside `fulfillRandomWords` at `callbackGasLimit = 300_000`, and race between VRF fulfillment and `enableRefunds()`. |

## 4. Invariants

1. **Quote Solvency Invariant:** `accountedQuoteBalance() == unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees <= quoteToken.balanceOf(address(this))` at the end of every transaction.
2. **Sale Pot Conservation:** While `status == Status.Active` or `status == Status.Drawing`, `unsettledPot == uint256(totalEntries) * ENTRY_PRICE` and `remainingRefundLiability == winnerProceeds == sponsorProceeds == protocolFees == 0`.
3. **Partition of Entry Ranges:** Minted tickets `1 .. ticketCount` partition `[1, totalEntries]` into contiguous, non-overlapping inclusive intervals `[firstEntry_i, lastEntry_i]` where `firstEntry_1 == 1`, `lastEntry_{ticketCount} == totalEntries`, and `firstEntry_{i+1} == lastEntry_i + 1`.
4. **Settlement Conservation:** Immediately after `_settleWinningTicket`, `unsettledPot == 0` and `winnerProceeds + sponsorProceeds + protocolFees == uint256(totalEntries) * ENTRY_PRICE`.
5. **Refund Conservation:** Immediately after `enableRefunds()`, `unsettledPot == 0` and `remainingRefundLiability == Σ_{unburned ticket i} (lastEntry_i - firstEntry_i + 1) * ENTRY_PRICE`.
6. **Single Ticket Claim:** Each `ticketId` can be burned at most once — either in `refundTickets` (when `status == Status.Refunding`) or in `redeemWinningTicket` (when `ticketId == winningTicketId` and `status in {NftWon, CashWon}`).
7. **Single Prize Delivery:** The escrowed NFT (`prizeToken`, `prizeTokenId`) is transferred out of `Raffle` at most once (`prizeClaimed` transitions `false -> true`), either to `winner` in `Status.NftWon` or to `sponsorRecipient` in `Status.CashWon` / `Status.Refunding`.
8. **Outcome Threshold:** A valid VRF callback in `Status.Drawing` before `callbackDeadline()` sets `status = Status.NftWon` iff `totalEntries >= reserveEntries`, and `status = Status.CashWon` iff `0 < totalEntries < reserveEntries`.
9. **Destination Safety:** Neither tickets (`_update`) nor USDC payouts (`_transferQuote`) nor configured roles (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`) can be set to `address(this)`, `factory`, `quoteToken`, `vrfWrapper`, `prizeToken`, `raffleImplementation`, or any registered `isRaffle` clone.

## 5. Lifecycles

1. **Creation & Escrow (`RaffleFactory::createRaffle` → `Raffle::initialize` → `Raffle::onERC721Received`):**
   - Increments `raffleCount`, clones `raffleImplementation`, calls `initialize` (`initialized = true`, `status = AwaitingPrize`, sets config), registers clone in `raffleById`/`idByRaffle`/`isRaffle`, calls `prize.safeTransferFrom(msg.sender, raffle, prizeTokenId)` which triggers `onERC721Received` (`status = Active`), verifies `prize.ownerOf(prizeTokenId) == raffle` and `status == Active`.
2. **Entry Purchase (`Raffle::buyEntries`):**
   - Requires `status == Active` and `block.timestamp < endTime`. Pulls `grossAmount` USDC, updates `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`, and `_safeMint(recipient, ticketId)`.
3. **Draw & Resolution (`Raffle::requestDraw` → `Raffle::fulfillRandomWords`):**
   - In `[endTime, drawRequestDeadline())` with `totalEntries > 0`, sets `status = Drawing`, `drawRequestedAt = uint64(block.timestamp)`, `_requestInFlight = true`, calls `requestRandomnessPayInNative`, stores `vrfRequestId`, sets `_requestInFlight = false`, refunds excess ETH.
   - Before `callbackDeadline()`, `rawFulfillRandomWords` → `fulfillRandomWords` sets `winningEntry = uint128((randomWords[0] % totalEntries) + 1)`, `resolvedAt = uint64(block.timestamp)`, `status = totalEntries >= reserveEntries ? NftWon : CashWon`.
4. **Settlement & Claims (`settleWinningTicket` / `redeemWinningTicket` / `releaseSponsorProceeds` / `releaseProtocolFees` / `releaseSponsorPrize`):**
   - `_settleWinningTicket(ticketId)` verifies `winningEntry in [firstEntry, lastEntry]`, sets `settlementComplete = true`, `winningTicketId = ticketId`, zeroes `unsettledPot`, and populates `protocolFees`, `sponsorProceeds`, and (if `CashWon`) `winnerProceeds`.
   - `redeemWinningTicket(ticketId)` (auto-settles if needed) checks `msg.sender == ownerOf(ticketId)`, sets `winnerRecipient = winner`, `winnerRedeemed = true`, burns `ticketId`, and delivers either the NFT (`NftWon`, setting `prizeClaimed = true`) or `winnerProceeds` USDC (`CashWon`, zeroing `winnerProceeds`).
   - Independent pull functions release `sponsorProceeds`, `protocolFees`, and (in `CashWon` or `Refunding`) `prizeTokenId`.
5. **Refund Lifecycle (`enableRefunds` → `refundTickets` + `releaseSponsorPrize`):**
   - Triggered from `Active` (when `totalEntries == 0` by `sponsor` anytime or anyone at `>= endTime`, or when `totalEntries > 0` at `>= drawRequestDeadline()`) or from `Drawing` (at `>= callbackDeadline()`). Moves `unsettledPot` to `remainingRefundLiability` and sets `status = Refunding`.
   - Ticket owners call `refundTickets(ticketIds)` (1..100 tickets) to burn tickets, decrement `remainingRefundLiability`, and receive `1_000_000` USDC per entry; anyone calls `releaseSponsorPrize()` to return the NFT to `sponsorRecipient`.

## 6. Cohorts

| Cohort | Role & Capabilities | What They Are Owed |
| --- | --- | --- |
| **Sponsor (`sponsor` / `sponsorRecipient`)** | Escrows `prizeTokenId` via `createRaffle`; `sponsor` can cancel early if `totalEntries == 0`. | `NftWon`: 95% of `grossSales` (plus any rounding remainder). `CashWon`: 15% of `grossSales` (plus any rounding remainder) + returned `prizeTokenId`. `Refunding`: returned `prizeTokenId`. |
| **Ticket Buyers / Current Ticket Owners** | Buy entries via `buyEntries` or acquire ERC-721 tickets on secondary markets. | `NftWon`: owner of `winningTicketId` gets `prizeTokenId`; others get 0. `CashWon`: owner of `winningTicketId` gets 80% of `grossSales` (rounded down); others get 0. `Refunding`: every ticket owner gets 100% (`entryCount * 1e6` USDC). |
| **Draw Requester / Settler / Keepers** | Permissionlessly call `requestDraw` (paying native VRF fee), `settleWinningTicket`, `enableRefunds`, `release*`. | Draw requester gets `msg.value - paidPrice` native refund; no protocol fee/bounty is paid to callers of `requestDraw` or `settleWinningTicket`. |
| **Protocol Treasury (`protocolTreasury`)** | Immutable fee recipient configured on `RaffleFactory`. | 5% of `grossSales` (rounded down) in `NftWon` and `CashWon`; 0 in `Refunding`. |
