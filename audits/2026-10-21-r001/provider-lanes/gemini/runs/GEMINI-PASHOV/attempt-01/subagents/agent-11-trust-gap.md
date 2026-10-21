FINDING | contract: Raffle | function: buyEntries | bug_class: sponsor-self-purchase-rebate | group_key: Raffle | buyEntries | sponsor-self-purchase-rebate
seam: three-way
actor: sponsor / sponsorRecipient
path: sponsor → Raffle.buyEntries(sponsor, entryCount) → totalEntries >= reserveEntries → Raffle.fulfillRandomWords (Status.NftWon) → Raffle._settleWinningTicket → Raffle.releaseSponsorProceeds / Raffle.redeemWinningTicket
proof:
1. In `Raffle.buyEntries` (lines 222-250) and `Raffle._isProtocolDestination` (lines 606-618), neither `sponsor` nor `sponsorRecipient` is blocked from buying or holding tickets, and `totalEntries` has no raffle-specific cap below `type(uint128).max`.
2. In `Raffle.fulfillRandomWords` (line 534) and `Raffle._settleWinningTicket` (lines 553-562), crossing `totalEntries >= reserveEntries` switches the outcome from `Status.CashWon` (`winnerProceeds = 80%`, `sponsorProceeds = 15%`, `protocolFees = 5%`) to `Status.NftWon` (`winnerProceeds = 0`, `sponsorProceeds = 95%`, `protocolFees = 5%`).
3. Because `sponsorRecipient` receives 95% (`950,000` USDC units) of every `1,000,000` USDC entry bought when `result == Status.NftWon`, the sponsor pays a net cost of `50,000` USDC units ($0.05) per entry while other buyers pay `1,000,000` USDC units ($1.00) per entry.
4. Concrete trace (flipping `CashWon` to `NftWon`):
   - `reserveEntries = 100` (`100,000,000` USDC). Honest buyers purchase `20` entries (`totalEntries = 20`, `unsettledPot = 20,000,000`). Under `CashWon`, buyers would receive `winnerProceeds = 16,000,000` and sponsor would receive `sponsorProceeds = 3,000,000`.
   - Right before `endTime`, `sponsor` calls `buyEntries(sponsor, 80)` and pays `80,000,000` USDC (`totalEntries = 100 == reserveEntries`, `unsettledPot = 100,000,000`).
   - VRF resolves to `Status.NftWon`. `_settleWinningTicket` sets `sponsorProceeds = 95,000,000` and `winnerProceeds = 0`.
   - `sponsor` calls `releaseSponsorProceeds()` and receives `95,000,000` USDC, netting `95,000,000 - 80,000,000 = +15,000,000` USDC in guaranteed cash from the buyers' `20,000,000` USDC deposit (an extra `+12,000,000` USDC over `CashWon`) plus an `80 / 100 = 80%` probability of winning back the escrowed NFT via `redeemWinningTicket`.
5. Concrete trace (diluting `NftWon` after reserve is met):
   - Honest buyers purchase `100` entries (`100,000,000` USDC) meeting `reserveEntries = 100` for an NFT worth `100,000,000` USDC.
   - Right before `endTime`, `sponsor` calls `buyEntries(sponsor, 900)` paying `900,000,000` USDC (`totalEntries = 1,000`, `unsettledPot = 1,000,000,000`).
   - Upon `NftWon` settlement, `sponsorProceeds = 950,000,000` USDC (`95,000,000` from honest buyers + `855,000,000` rebate on the sponsor's own purchase). For a net cost of `45,000,000` USDC, the sponsor captures `900 / 1,000 = 90%` probability of winning back the `100,000,000` USDC NFT while still keeping `95,000,000` USDC from honest buyers.
description: The sponsor can call buyEntries to cross reserveEntries and take 95% of all ticket payments through sponsorProceeds.
fix: Reject sponsor and sponsorRecipient in _isProtocolDestination, and cap totalEntries at a fixed maximum in buyEntries.

FINDING | contract: Raffle | function: requestDraw | bug_class: single-buyer-cash-draw-fee-extraction | group_key: Raffle | requestDraw | single-buyer-cash-draw-fee-extraction
seam: access×economics
actor: sponsor
path: sponsor → RaffleFactory.createRaffle (high/unbounded reserveEntries) → buyer → Raffle.buyEntries → sponsor → Raffle.requestDraw → Raffle.fulfillRandomWords (Status.CashWon) → Raffle.releaseSponsorProceeds + Raffle.releaseSponsorPrize
proof:
1. `RaffleFactory._validateCreateParams` (line 811) only checks `if (params.reserveEntries == 0) revert ZeroReserveEntries();` and enforces no upper bound on `reserveEntries` (allowing values up to `type(uint128).max`, which exceeds total USDC supply and makes `Status.NftWon` unreachable).
2. `Raffle.requestDraw` (line 256) only checks `if (totalEntries == 0) revert NoEntriesSold();` and allows any caller (including `sponsor`) to trigger a VRF draw even when `ticketCount == 1` (only a single ticket exists) and `totalEntries < reserveEntries`.
3. For any buyer owning `e_i` of `N` total entries when `N < reserveEntries`, expected payout in `Status.CashWon` is `(e_i / N) * 0.80 * N * ENTRY_PRICE = 0.80 * e_i * ENTRY_PRICE`, which is strictly less than the buyer's `1.00 * e_i * ENTRY_PRICE` claim in `Status.Refunding`.
4. Concrete trace:
   - Sponsor calls `createRaffle` with `reserveEntries = 100` (or `type(uint128).max`).
   - One buyer calls `buyEntries(buyer, 50)`, paying `50,000,000` USDC (`ticketCount = 1`, `totalEntries = 50 < reserveEntries`). No other buyer participates before `endTime`.
   - Although `ticketCount == 1` (so there is only one participant and no draw uncertainty over which ticket contains `winningEntry` in `[1, 50]`), `sponsor` calls `requestDraw()` at `endTime`.
   - `fulfillRandomWords` sets `status = Status.CashWon`. `_settleWinningTicket(1)` allocates `winnerProceeds = 40,000,000`, `sponsorProceeds = 7,500,000`, and `protocolFees = 2,500,000`.
   - `sponsor` claims `7,500,000` USDC (15% of the sole buyer's deposit) via `releaseSponsorProceeds()` and reclaims the prize NFT via `releaseSponsorPrize()`, while the sole buyer loses `10,000,000` USDC (20%).
description: The sponsor can call requestDraw below reserveEntries when one buyer owns all entries to take 15% of the pot and keep the prize.
fix: Require at least two tickets or totalEntries at least reserveEntries in requestDraw, and bound reserveEntries in _validateCreateParams.

FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: unregistered-future-clone-destination | group_key: Raffle | _isProtocolDestination | unregistered-future-clone-destination
seam: access×asymmetry
actor: sponsor / ticket buyer / ticket owner
path: caller → RaffleFactory.createRaffle (or Raffle.buyEntries / ERC721.transferFrom) with precomputed next CREATE clone address R2 → RaffleFactory.createRaffle deploys R2 (isRaffle[R2] = true) → Raffle.releaseSponsorProceeds / Raffle.refundTickets / Raffle.redeemWinningTicket reverts while Raffle.releaseSponsorPrize transfers NFT into R2
proof:
1. `RaffleFactory.createRaffle` (line 739) deploys clones via `Clones.clone(raffleImplementation)`, which uses the `CREATE` opcode (`create(value, 0x09, 0x37)` in `Clones.sol` line 1987). The address of the next raffle clone `R2` is deterministic from `address(factory)` and the factory nonce before `R2` is deployed.
2. Before `R2` is deployed, `R2.code.length == 0` and `canonicalFactory.isRaffle(R2) == false`. Therefore:
   - `Raffle._isProtocolDestination(R2, prizeToken)` (lines 606-618) returns `false` during `R1.initialize`, `R1.buyEntries`, and `R1._update`.
   - `ERC721Utils.checkOnERC721Received` (line 3112) checks `if (to.code.length > 0)` and skips `onERC721Received` when `R1.buyEntries(R2, entryCount)` mints a ticket to `R2`.
3. Once any sponsor calls `RaffleFactory.createRaffle` to deploy `R2`, `R2.code.length == 45` and `isRaffle[R2] == true`, so `R1._isProtocolDestination(R2, prizeToken)` becomes `true`.
4. Asymmetric settlement/claim behavior in `R1` after `R2` is deployed:
   - If `R1.sponsorRecipient == R2`: `R1.releaseSponsorProceeds()` calls `_transferQuote(R2, amount)` (line 578), which re-checks `_isProtocolDestination(R2, address(prizeToken))` and reverts permanently with `InvalidQuoteDestination(R2)`, locking `sponsorProceeds` in `R1`. Meanwhile, `R1.releaseSponsorPrize()` (lines 408-420) omits `_isProtocolDestination` and calls `prizeToken.transferFrom(R1, R2, prizeTokenId)`, transferring `R1`'s prize NFT directly into clone `R2` where it cannot be recovered.
   - If a ticket `ticketId` in `R1` was minted or transferred to `R2` before `R2` was deployed: if `R1` enters `Status.Refunding`, `remainingRefundLiability` for `ticketId` can never be claimed; if `ticketId` wins `R1`, `settleWinningTicket(ticketId)` succeeds (paying `sponsorProceeds` and `protocolFees`), but `redeemWinningTicket(ticketId)` can never be called by `R2`, permanently locking the prize NFT (`Status.NftWon`) or `winnerProceeds` (`Status.CashWon`) in `R1`.
description: A caller can pass a future clone address before deployment, so later registration blocks quote payouts and sends the prize into that clone.
fix: Check _isProtocolDestination in releaseSponsorPrize and redeemWinningTicket, and deploy clones with cloneDeterministic and a caller-bound salt.

FINDING | contract: Raffle | function: enableRefunds | bug_class: empty-raffle-cancellation-frontrun | group_key: Raffle | enableRefunds | empty-raffle-cancellation-frontrun
seam: access×asymmetry
actor: ticket buyer
path: sponsor submits Raffle.enableRefunds() → attacker front-runs with Raffle.buyEntries(attacker, 1) → totalEntries becomes 1 → sponsor's Raffle.enableRefunds() reverts with RefundsNotAvailable → prize NFT locked until endTime + 2 days
proof:
1. `Raffle.enableRefunds` (lines 292-301) grants `sponsor` pre-end cancellation authority only when `totalEntries == 0`:
   ```solidity
   if (totalEntries == 0) {
       deadline = endTime;
       if (msg.sender != sponsor && block.timestamp < deadline) {
           revert RefundsNotAvailable(deadline, block.timestamp);
       }
   } else {
       deadline = drawRequestDeadline();
       if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
   }
   ```
2. While `status == Status.Active` and `block.timestamp < endTime`, `Raffle.buyEntries` (lines 222-250) permits any caller to buy `entryCount = 1` entry for `ENTRY_PRICE = 1,000,000` (1 USDC).
3. Concrete trace:
   - Sponsor creates a raffle with `endTime = block.timestamp + 30 days` and `reserveEntries = 1,000`.
   - While `totalEntries == 0`, sponsor broadcasts `enableRefunds()` to cancel the raffle and recover the prize NFT via `releaseSponsorPrize()`.
   - An attacker front-runs `enableRefunds()` with `buyEntries(attacker, 1)`, paying `1,000,000` USDC.
   - `totalEntries` becomes `1`, so the sponsor's `enableRefunds()` call takes the `else` branch and reverts with `RefundsNotAvailable(endTime + 2 days, block.timestamp)`.
   - The sponsor's prize NFT remains locked in `Raffle` for up to 32 days (`MAX_SALE_DURATION + DRAW_REQUEST_TIMEOUT`), and if no party pays the VRF fee at `endTime`, the attacker calls `enableRefunds()` and `refundTickets([1])` at `endTime + 2 days` to recover the full `1,000,000` USDC (0 USDC net cost).
description: An attacker can buy one entry before enableRefunds runs, which makes enableRefunds revert and locks the prize of the sponsor until endTime.
fix: Add a startTime delay before buyEntries accepts purchases so the sponsor can call enableRefunds before sales open.

LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: untrusted-prize-transfer-restriction | group_key: Raffle | redeemWinningTicket | untrusted-prize-transfer-restriction
code_smells: _settleWinningTicket allocates sponsorProceeds before redeemWinningTicket calls prizeToken.transferFrom, so a sponsor who controls prizeToken can block prize delivery after taking 95% of the pot.
description: The sponsor can claim sponsorProceeds after settleWinningTicket even when prizeToken blocks transferFrom in redeemWinningTicket. We could not verify this on an honest ERC721 contract.
