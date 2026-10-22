### Phase 0 & 1 — Vocabulary, Money Map & Asymmetry Analysis (Lens 6: Rounding, Precision & Scale)

#### Function Models (`[Model: ...]`)

[Model: RaffleFactory::createRaffle]
A sponsor gives one NFT prize (by approving the factory and calling `createRaffle` with a prize contract, token ID, reserve entry threshold, sale end timestamp, and sponsor payout address). In return, the factory increments the lifetime raffle counter (`raffleCount`), deploys a fresh clone of the raffle implementation, initializes its configuration, registers its ID and address in the factory's lookup tables (`raffleById`, `idByRaffle`, `isRaffle`), and transfers the sponsor's NFT into the clone, activating the raffle for ticket sales.

[Model: Raffle::initialize]
Called once by the factory on a newly deployed clone. No assets move yet; the clone records its immutable-per-raffle configuration (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`), marks `initialized = true`, and sets `status = Status.AwaitingPrize`.

[Model: Raffle::onERC721Received]
When the factory transfers the configured `prizeTokenId` from `sponsor` into the raffle clone while `status == Status.AwaitingPrize`, the clone accepts custody of the NFT and transitions `status` to `Status.Active`.

[Model: Raffle::buyEntries]
A buyer gives `entryCount * 1,000,000` raw units of 6-decimal USDC (`entryCount` whole USDC) before `endTime` while `status == Status.Active`. In return, `recipient` receives one sequential ERC-721 ticket (`ticketId = ticketCount + 1`) representing the contiguous inclusive entry range `[totalEntries + 1, totalEntries + entryCount]`. The tracked totals `totalEntries` (increased by `entryCount`), `ticketCount` (increased by `1`), `_ticketRanges[ticketId]`, and `unsettledPot` (increased by `entryCount * 1,000,000`) are updated.

[Model: Raffle::requestDraw]
Any caller gives native ETH (`msg.value >= quotedFee`) during `[endTime, endTime + 2 days)` when `status == Status.Active` and `totalEntries > 0`. The contract transitions `status` to `Status.Drawing`, records `drawRequestedAt = uint64(block.timestamp)` and `vrfRequestId`, pays `paidPrice` in native ETH to the Chainlink VRF v2.5 wrapper for 1 random word, and returns `excess = msg.value - paidPrice` in native ETH to `msg.sender`.

[Model: Raffle::fulfillRandomWords]
The Chainlink VRF wrapper delivers one 256-bit random word strictly before `drawRequestedAt + 2 days` while `status == Status.Drawing`. No assets move. The contract maps `randomWords[0]` onto a 1-based entry index `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`, records `resolvedAt = uint64(block.timestamp)`, and transitions `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`.

[Model: Raffle::enableRefunds]
When a raffle has no entries sold (callable by `sponsor` anytime or anyone at `block.timestamp >= endTime`), or when the 2-day draw request window expires (`status == Status.Active` and `block.timestamp >= endTime + 2 days`), or when the 2-day VRF callback window expires (`status == Status.Drawing` and `block.timestamp >= drawRequestedAt + 2 days`), the contract moves the entire `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, and sets `status = Status.Refunding`.

[Model: Raffle::_settleWinningTicket]
In `Status.NftWon` or `Status.CashWon`, any caller supplies `ticketId` whose stored `[firstEntry, lastEntry]` range contains `winningEntry`. No assets leave the contract. The contract zeroes `unsettledPot`, sets `settlementComplete = true` and `winningTicketId = ticketId`, allocates 5% of `grossPot` (rounded down via `Math.mulDiv(grossPot, 500, 10_000)`) to `protocolFees`, allocates 80% of `grossPot` (rounded down via `Math.mulDiv(grossPot, 8000, 10_000)`) to `winnerProceeds` if `status == Status.CashWon` (or `0` if `Status.NftWon`), and allocates the remaining `grossPot - protocolFee - cashAmount` to `sponsorProceeds`.

[Model: Raffle::redeemWinningTicket]
The current owner of `winningTicketId` calls `redeemWinningTicket(ticketId)` in `Status.NftWon` or `Status.CashWon` (auto-running `_settleWinningTicket(ticketId)` first if `settlementComplete == false`). The caller gives up their winning ticket (which is burned via `_burn(ticketId)`), `winnerRecipient = winner` and `winnerRedeemed = true` are recorded, and the caller receives either the escrowed NFT (`Status.NftWon`, setting `prizeClaimed = true`) or `winnerProceeds` in USDC (`Status.CashWon`, zeroing `winnerProceeds`).

[Model: Raffle::refundTickets]
In `Status.Refunding`, a ticket owner passes 1 to 100 `ticketIds` they own. Each ticket in the batch is burned (`_burn(ticketId)`), its entry count `lastEntry - firstEntry + 1` is summed into `aggregateEntries`, `remainingRefundLiability` is decreased by `amount = aggregateEntries * 1,000,000`, and `msg.sender` receives `amount` of USDC.

[Model: Raffle::releaseSponsorProceeds]
Any caller triggers payout of the full `sponsorProceeds` liability. `sponsorProceeds` is zeroed and that exact amount of USDC is transferred to `sponsorRecipient`.

[Model: Raffle::releaseProtocolFees]
Any caller triggers payout of the full `protocolFees` liability. `protocolFees` is zeroed and that exact amount of USDC is transferred to `protocolTreasury`.

[Model: Raffle::releaseSponsorPrize]
In `Status.CashWon` or `Status.Refunding`, when `prizeClaimed == false`, any caller triggers return of the escrowed NFT. `prizeClaimed` is set to `true` and `prizeTokenId` is transferred from the raffle clone to `sponsorRecipient`.

[Model: Raffle::_update]
On every ticket mint, transfer, or burn, if `to != address(0)`, the contract verifies `to` is not a prohibited protocol destination (`_isProtocolDestination(to, address(prizeToken))`) before updating ERC-721 ownership.

[Model: Raffle::_transferQuote]
Before sending `amount` of `quoteToken` to `to`, the contract verifies `to` is not a prohibited protocol destination (`_isProtocolDestination(to, address(prizeToken))`) and then transfers `amount` of USDC.

---

### Phase 2 — Drilling into Non-Obvious Lines & Guards (`[Why: ...]` & `[Defeat: ...]`)

[Why: packages/contracts/src/Raffle.sol:232]
Why does `buyEntries` check `if (entryCount > type(uint128).max - totalEntries)` in `uint128` before computing `grossAmount = uint256(entryCount) * ENTRY_PRICE`?
Because `totalEntries`, `firstEntry`, and `lastEntry` are packed as `uint128` inside `TicketRange`. The code rests on the belief that bounding `totalEntries + entryCount <= type(uint128).max` simultaneously prevents `uint128` overflow on `firstEntry = totalEntries + 1`, `lastEntry = totalEntries + entryCount`, `++ticketCount`, and `uint256` overflow on `uint256(entryCount) * ENTRY_PRICE` and `unsettledPot += grossAmount` (since `(2^128 - 1) * 1_000_000 < 2^148 < 2^256 - 1`).

[Defeat: Raffle::buyEntries]
1. **Move 1 (Boundary overflow on `firstEntry` / `lastEntry` / `ticketCount`):** Attacker `0xA11CE` attempts `buyEntries(0xA11CE, type(uint128).max)` when `totalEntries == 1`. At line 232, `type(uint128).max - 1 < type(uint128).max`, reverting with `TotalEntriesOverflow(1, type(uint128).max)`. If `totalEntries == 0` and `entryCount == type(uint128).max`, `firstEntry = 1`, `lastEntry = type(uint128).max`, `ticketCount = 1`, and `grossAmount = 340282366920938463463374607431768211455 * 1_000_000`, which does not overflow `uint256` and fails in `quoteToken.safeTransferFrom` due to insufficient USDC balance.
2. **Move 2 (Zero-cost ticket mint via truncation):** Attacker `0xA11CE` calls `buyEntries(0xA11CE, 0)` hoping `grossAmount = 0 * 1_000_000 = 0` mints a range ticket for free. Line 231 `if (entryCount == 0) revert ZeroEntryCount();` blocks `entryCount == 0`.
3. **Move 3 (Reentrancy via `_safeMint` ERC721Receiver callback to skew `totalEntries` vs `unsettledPot`):** Attacker contract `0xB0B` implements `onERC721Received` and calls `buyEntries(0xB0B, 10)`, attempting to re-enter `buyEntries` or `enableRefunds` during `_safeMint`. All state writes (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`) occur on lines 243–246 before `_safeMint` on line 248, and `nonReentrant` blocks re-entering any state-changing raffle function.

[Why: packages/contracts/src/Raffle.sol:267]
Why is `_requestInFlight = true` set before `requestRandomnessPayInNative` and cleared on line 273, while `fulfillRandomWords` ignores callbacks when `_requestInFlight == true`?
Because `vrfRequestId = requestId` is only assigned on line 272 after `requestRandomnessPayInNative` returns. If a malicious or synchronous VRF wrapper called `rawFulfillRandomWords` inside `requestRandomWordsInNative` before `vrfRequestId` was stored, `vrfRequestId` would still be `0`; if the wrapper also passed `requestId = 0`, `requestId == vrfRequestId` would pass prematurely. `_requestInFlight` enforces that fulfillment cannot occur synchronously during the request call.

[Defeat: Raffle::requestDraw]
1. **Move 1 (Underpaying VRF fee or exploiting `msg.value - paidPrice` underflow):** Attacker `0xA11CE` calls `requestDraw{value: quotedFee - 1}()`. Line 263 `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` reverts. Furthermore, `requestRandomnessPayInNative` calls `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` in the same transaction (same `tx.gasprice`), so `paidPrice == quotedFee <= msg.value`, and line 271 `if (paidPrice > msg.value)` also guards line 275 `msg.value - paidPrice`.
2. **Move 2 (Draining pre-existing forced ETH via `excess` refund):** Suppose `1 ether` was force-sent to `Raffle` via `selfdestruct` before `requestDraw`. Attacker `0xA11CE` calls `requestDraw{value: quotedFee}()`. Line 275 computes `excess = msg.value - paidPrice` (using `msg.value`, not `address(this).balance`), so `excess == 0` and the forced ETH cannot be extracted or cause accounting drift.
3. **Move 3 (Timestamp cast truncation on `drawRequestedAt = uint64(block.timestamp)`):** `requestDraw` can only be called when `block.timestamp < drawRequestDeadline() = uint256(endTime) + 2 days`, and `endTime` is `uint64` bounded at creation to `block.timestamp + 30 days`. Thus `block.timestamp` fits within `uint64` without truncation.

[Why: packages/contracts/src/Raffle.sol:531]
Why is `winningEntry` computed as `uint128((randomWords[0] % uint256(totalEntries)) + 1)`?
Because ticket entry ranges are 1-based inclusive intervals `[firstEntry, lastEntry]` partitioning `[1, totalEntries]`. Taking `% uint256(totalEntries)` yields an index in `[0, totalEntries - 1]`, and adding `1` shifts the range to `[1, totalEntries]`, which is guaranteed to fit in `uint128` without truncation because `1 <= totalEntries <= type(uint128).max`.

[Defeat: Raffle::fulfillRandomWords]
1. **Move 1 (Division/modulo by zero when `totalEntries == 0`):** Can `fulfillRandomWords` be reached when `totalEntries == 0`? No: `fulfillRandomWords` requires `status == Status.Drawing` (line 524), which is only reachable via `requestDraw()`, which reverts with `NoEntriesSold()` if `totalEntries == 0` (line 256).
2. **Move 2 (Overflow or truncation in `uint128((randomWords[0] % uint256(totalEntries)) + 1)`):** If `totalEntries == type(uint128).max` and `randomWords[0] % uint256(totalEntries) == type(uint128).max - 1`, adding `1` in `uint256` produces `uint256(type(uint128).max)`, which casts losslessly to `uint128`.
3. **Move 3 (Boundary race at `callbackDeadline()` between `fulfillRandomWords` and `enableRefunds`):** At `block.timestamp == callbackDeadline()`, line 525 checks `block.timestamp >= callbackDeadline()`, ignoring the callback and emitting `VrfCallbackIgnored`, while line 304 in `enableRefunds` allows transitioning to `Status.Refunding` at `block.timestamp >= callbackDeadline()`. Both functions use the exact same exclusive/inclusive boundary `callbackDeadline()`, preventing both a dead-zone gap and an overlap.

[Why: packages/contracts/src/Raffle.sol:553]
Why does `_settleWinningTicket` compute `protocolFee` and `cashAmount` independently via `Math.mulDiv(..., BPS)` and assign `sponsorAmount = grossPot - protocolFee - cashAmount` instead of computing `sponsorAmount` via `Math.mulDiv`?
To guarantee zero-dust conservation of `unsettledPot`: any downward rounding in `protocolFee` and `cashAmount` accrues to `sponsorAmount`, ensuring `protocolFees + winnerProceeds + sponsorProceeds == grossPot` always holds. Moreover, because `ENTRY_PRICE = 1_000_000` is an exact multiple of `BPS = 10_000` (`1_000_000 / 10_000 = 100`), `grossPot = totalEntries * 1_000_000` is always divisible by `10_000` with zero remainder.

[Defeat: Raffle::_settleWinningTicket]
1. **Move 1 (Drive `cashAmount` to zero in `Status.CashWon` so `redeemWinningTicket` reverts with `NoWinnerProceeds()`):** To enter `Status.Drawing` and resolve to `Status.CashWon`, `totalEntries` must be at least `1` (`NoEntriesSold` guard at line 256) and `reserveEntries >= 2`. With `totalEntries >= 1`, `grossPot = totalEntries * 1_000_000 >= 1_000_000`. Thus `cashAmount = Math.mulDiv(grossPot, 8000, 10_000) = totalEntries * 800_000 >= 800_000 > 0`. `winnerProceeds` can never be `0` in `Status.CashWon`.
2. **Move 2 (Settle with unminted `ticketId = 0` or `ticketId = ticketCount + 1`):** For any unminted `ticketId`, `_ticketRanges[ticketId]` is `(0, 0)`. Since `winningEntry >= 1`, `_requireWinningTicket` checks `selectedEntry < firstEntry || selectedEntry > lastEntry` (`selectedEntry > 0`), which is true and reverts with `TicketDoesNotContainWinningEntry(ticketId, selectedEntry)`.
3. **Move 3 (Settle via `settleWinningTicket(winningId)` first, then have winner call `redeemWinningTicket(winningId)`):** When `settleWinningTicket(winningId)` is called first, `_settleWinningTicket` sets `settlementComplete = true`, `winningTicketId = winningId`, and `winnerProceeds = cashAmount`. When the winner subsequently calls `redeemWinningTicket(winningId)`, line 327 sees `settlementComplete == true`, verifies `ticketId == winningTicketId`, reads `cashAmount = winnerProceeds` on line 352, zeroes `winnerProceeds = 0`, and transfers `cashAmount` to `winner`.

[Why: packages/contracts/src/Raffle.sol:375]
Why does `refundTickets` compute `aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1` without deleting `_ticketRanges[ticketId]`?
Because `_burn(ticketId)` on line 377 deletes ERC-721 ownership of `ticketId`, causing any subsequent `ownerOf(ticketId)` call (either in the same batch or a later `refundTickets` call) to revert with `ERC721NonexistentToken(ticketId)`. Preserving `_ticketRanges[ticketId]` allows off-chain indexers to query `ticketRange(ticketId)` historically without permitting double refunds.

[Defeat: Raffle::refundTickets]
1. **Move 1 (Pass duplicate ticket IDs `[1, 1]` in `ticketIds` to double-refund):** In loop iteration `0`, `_burn(1)` clears ownership of ticket `1`. In loop iteration `1`, `ownerOf(1)` on line 372 reverts with `ERC721NonexistentToken(1)`, reverting the entire transaction.
2. **Move 2 (Underflow `remainingRefundLiability -= amount` via rounding discrepancy):** Every ticket `i` was minted in `buyEntries` with `lastEntry_i - firstEntry_i + 1 == entryCount_i` and added `entryCount_i * ENTRY_PRICE` to `unsettledPot`. In `enableRefunds()`, `remainingRefundLiability = unsettledPot = Σ_i (entryCount_i * ENTRY_PRICE)`. In `refundTickets`, each ticket `i` can be burned at most once and deducts `entryCount_i * ENTRY_PRICE`, so the sum of all refunds equals the initial `remainingRefundLiability` with zero rounding error.
3. **Move 3 (Griefing a user with >100 tickets via `MAX_REFUND_TICKET_BATCH_SIZE = 100`):** A buyer who purchased 250 tickets cannot pass all 250 in one `refundTickets` call, but can call `refundTickets` three times (batches of 100, 100, and 50) to recover 100% of their USDC.

[Why: packages/contracts/src/RaffleFactory.sol:811]
Why does `_validateCreateParams` only check `if (params.reserveEntries == 0) revert ZeroReserveEntries();` without an upper bound on `params.reserveEntries`?
The code assumes any positive `uint128` is a valid reserve threshold because `totalEntries` is also a `uint128`, relying on buyers to inspect `reserveEntries` before purchasing entries.

---

### Phase 3 & 4 — Lifecycle & Last User Out Tests (`[LastOut: ...]`)

[LastOut: Lifecycle 1 — Creation & Empty-Raffle Refund (`createRaffle` → `enableRefunds` → `releaseSponsorPrize`)]
1. Sponsor `0x5P0N` creates a raffle with `prizeTokenId = 42`, `reserveEntries = 10`, `endTime = t0 + 1 days`. `totalEntries = 0`, `unsettledPot = 0`, `status = Active`.
2. Sponsor (or anyone at `block.timestamp >= endTime`) calls `enableRefunds()`. `remainingRefundLiability = 0`, `status = Refunding`.
3. Anyone calls `releaseSponsorPrize()`. `prizeClaimed` becomes `true` and `prizeTokenId = 42` is transferred to `sponsorRecipient`.
4. **Last User Out Check:** No USDC entered; the sole depositor (`sponsorRecipient`) recovers the exact escrowed NFT (`prizeTokenId = 42`). Protocol shortfall: `0`.

[LastOut: Lifecycle 2 & 3 & 4a — Reserve Met (`buyEntries` → `requestDraw` → `fulfillRandomWords` (`NftWon`) → `settleWinningTicket` → `redeemWinningTicket` / `releaseSponsorProceeds` / `releaseProtocolFees`)]
1. Buyer A buys `3` entries (`3,000,000` USDC, ticket `1`: `[1, 3]`). Buyer B buys `7` entries (`7,000,000` USDC, ticket `2`: `[4, 10]`). `totalEntries = 10 >= reserveEntries (10)`, `unsettledPot = 10,000,000` USDC, contract USDC balance = `10,000,000`.
2. At `endTime`, keeper calls `requestDraw{value: paidPrice}()`. Wrapper fulfills with `randomWords[0] = 5` -> `winningEntry = (5 % 10) + 1 = 6` (contained in ticket `2`), `status = Status.NftWon`.
3. `_settleWinningTicket(2)` sets `unsettledPot = 0`, `protocolFees = Math.mulDiv(10_000_000, 500, 10_000) = 500,000` USDC, `sponsorProceeds = 10_000_000 - 500,000 = 9,500,000` USDC, `winnerProceeds = 0`.
4. **Worst withdrawal order:**
   - First, `releaseProtocolFees()` pays `500,000` USDC to `protocolTreasury` (remaining USDC balance: `9,500,000`).
   - Second, `releaseSponsorProceeds()` pays `9,500,000` USDC to `sponsorRecipient` (remaining USDC balance: `0`).
   - Last, Buyer B calls `redeemWinningTicket(2)`, burning ticket `2` and receiving `prizeTokenId = 42`.
5. **Last User Out Check:** Every claimant (`protocolTreasury`, `sponsorRecipient`, and winning ticket owner Buyer B) is paid in full; `accountedQuoteBalance() == 0 == quoteToken.balanceOf(address(this))`. Protocol shortfall: `0`.

[LastOut: Lifecycle 4b — Reserve Missed (`buyEntries` → `requestDraw` → `fulfillRandomWords` (`CashWon`) → `settleWinningTicket` → `redeemWinningTicket` / `releaseSponsorProceeds` / `releaseProtocolFees` / `releaseSponsorPrize`)]
1. Suppose `reserveEntries = 10`, and Buyer A buys `1` entry (`1,000,000` USDC, ticket `1`: `[1, 1]`). `totalEntries = 1 < 10`, `unsettledPot = 1,000,000` USDC.
2. Draw is requested and fulfilled before `callbackDeadline()`: `winningEntry = 1`, `status = Status.CashWon`.
3. `_settleWinningTicket(1)` allocates:
   - `protocolFees = Math.mulDiv(1_000_000, 500, 10_000) = 50,000` USDC
   - `winnerProceeds = Math.mulDiv(1_000_000, 8000, 10_000) = 800,000` USDC
   - `sponsorProceeds = 1_000_000 - 50_000 - 800,000 = 150,000` USDC
   - Sum of liabilities: `50,000 + 800,000 + 150,000 = 1,000,000 == quoteToken.balanceOf(address(this))`.
4. **Worst withdrawal order:**
   - First, `releaseProtocolFees()` transfers `50,000` USDC to `protocolTreasury` (`950,000` USDC left).
   - Second, `releaseSponsorProceeds()` transfers `150,000` USDC to `sponsorRecipient` (`800,000` USDC left).
   - Third, `releaseSponsorPrize()` transfers `prizeTokenId` back to `sponsorRecipient`.
   - Last, Buyer A calls `redeemWinningTicket(1)`, burning ticket `1` and receiving `800,000` USDC (`0` USDC left).
5. **Last User Out Check:** The last claimant receives their full `800,000` USDC allocation and the contract ends with `0` liabilities and `0` balance. Protocol shortfall: `0`.

[LastOut: Lifecycle 5 — Full Refund After Timeout (`buyEntries` → `enableRefunds` → `refundTickets` + `releaseSponsorPrize`)]
1. Buyer A buys `1` entry (`1,000,000` USDC, ticket `1`: `[1, 1]`), Buyer B buys `5` entries (`5,000,000` USDC, ticket `2`: `[2, 6]`), Buyer C buys `13` entries (`13,000,000` USDC, ticket `3`: `[7, 19]`). `totalEntries = 19`, `unsettledPot = 19,000,000` USDC.
2. After `drawRequestDeadline()` (or after `callbackDeadline()` if `requestDraw` was called), `enableRefunds()` sets `unsettledPot = 0`, `remainingRefundLiability = 19,000,000`, `status = Status.Refunding`.
3. **Worst withdrawal order:**
   - First, `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`.
   - Second, Buyer C refunds ticket `3` (`7..19` -> `13` entries), receiving `13,000,000` USDC (`remainingRefundLiability = 6,000,000`, contract balance = `6,000,000`).
   - Third, Buyer B refunds ticket `2` (`2..6` -> `5` entries), receiving `5,000,000` USDC (`remainingRefundLiability = 1,000,000`, contract balance = `1,000,000`).
   - Last, Buyer A refunds ticket `1` (`1..1` -> `1` entry), receiving `1,000,000` USDC (`remainingRefundLiability = 0`, contract balance = `0`).
4. **Last User Out Check:** The last user out (Buyer A) receives 100% of their `1,000,000` USDC purchase price. Protocol shortfall: `0`.

---

### Phase 5 — Saturation Sweep Across All Arithmetic, Casts, Constants & Boundaries

Checking every arithmetic operation, scale constant, and cast across `Raffle.sol`, `RaffleFactory.sol`, and `RaffleConstants.sol`:
- **Divisions / Basis Points (`_settleWinningTicket` at `Raffle.sol:553, 559`):** Uses `Math.mulDiv(grossPot, ..., RaffleConstants.BPS)`. Since `ENTRY_PRICE = 1_000_000` and `BPS = 10_000`, every possible `grossPot = totalEntries * 1_000_000` is an exact multiple of `BPS = 10_000`. Neither `protocolFee` nor `cashAmount` ever truncates a fractional unit, and `sponsorAmount = grossPot - protocolFee - cashAmount` enforces exact conservation.
- **Casts (`Raffle.sol:236, 239-241, 266, 376, 472, 477, 487, 531, 533` & `RaffleFactory.sol:734`):**
  - `uint128` entry arithmetic in `buyEntries` is guarded by `if (entryCount > type(uint128).max - totalEntries)` (`Raffle.sol:232`).
  - `uint128((randomWords[0] % uint256(totalEntries)) + 1)` in `fulfillRandomWords` (`Raffle.sol:531`) is bounded to `[1, totalEntries]` where `totalEntries <= type(uint128).max`.
  - `uint64(block.timestamp)` in `requestDraw` (`Raffle.sol:266`) and `fulfillRandomWords` (`Raffle.sol:533`) is bounded by `endTime + 4 days` where `endTime` is a `uint64`.
- **Unbounded configuration parameter smell (`RaffleFactory.sol:811`):** While `saleDuration` is upper-bounded by `MAX_SALE_DURATION = 30 days` (`RaffleFactory.sol:735`), `params.reserveEntries` is only lower-bounded (`params.reserveEntries == 0` reverts at `RaffleFactory.sol:811`) and has no upper bound (`uint128` allows up to `3.4028e38` entries, far exceeding the total supply of 6-decimal USDC). Setting an unreachably high `reserveEntries` forces any resolved draw into the `Status.CashWon` branch (`Raffle.sol:534`), in which the sponsor retains 15% of `grossSales` (`sponsorProceeds`) and reclaims the NFT prize via `releaseSponsorPrize()`. Because `reserveEntries` is immutably published on-chain at creation before any buyer calls `buyEntries`, this is emitted as a calibrated `LEAD`.

---

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: precision-and-scale | group_key: RaffleFactory | createRaffle | precision-and-scale
smell: In RaffleFactory.sol:811, _validateCreateParams checks only `params.reserveEntries == 0` with no upper bound on `uint128 reserveEntries`, allowing a sponsor to configure `reserveEntries` up to `type(uint128).max` (3.4028e38 USDC, exceeding total canonical USDC supply) so that `totalEntries >= reserveEntries` in Raffle.sol:534 can never be reached and every resolved draw is forced into `Status.CashWon` (15% of gross sales plus the returned NFT to `sponsorRecipient`).
unverified: Because `reserveEntries` is publicly readable via `Raffle::reserveEntries()` and emitted in `RaffleCreated` before any buyer calls `buyEntries`, and `DESIGN.md` specifies that frontend discovery is advisory and callers must reread chain state, it cannot be established that an unreachable `reserveEntries` threshold exploits buyers who verify on-chain parameters.
description: Unbounded `uint128 reserveEntries` in `RaffleFactory::_validateCreateParams` allows creating raffles whose `Status.NftWon` threshold exceeds total USDC supply, guaranteeing the `Status.CashWon` fee split (15% sponsor cut + NFT returned) whenever a draw resolves.
```
