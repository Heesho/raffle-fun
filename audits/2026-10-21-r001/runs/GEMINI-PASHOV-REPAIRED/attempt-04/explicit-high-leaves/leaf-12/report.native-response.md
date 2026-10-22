FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: unregistered-future-clone-sink | group_key: Raffle | _isProtocolDestination | unregistered-future-clone-sink
seam: three-way
trace: RaffleFactory.createRaffle / ERC721.transferFrom → Raffle._isProtocolDestination(nextRaffle) [nextRaffle.code.length == 0, returns false] → RaffleFactory.createRaffle [Clones.clone deploys nextRaffle, sets isRaffle[nextRaffle] = true] → Raffle.releaseSponsorProceeds / Raffle.releaseSponsorPrize / Raffle.redeemWinningTicket [payout reverts or prize / ticket is stranded in nextRaffle]
violated_principle: Known protocol sinks and same-factory Raffle clones must be rejected so they can never own a ticket, receive a prize, or strand a quote-token payout.
path: caller → Raffle.initialize / Raffle._update (with predicted CREATE address of a future Raffle clone) → RaffleFactory.createRaffle (registers that address in isRaffle) → Raffle.releaseSponsorProceeds / Raffle.releaseSponsorPrize / Raffle.redeemWinningTicket → permanent loss of quote tokens or prize NFT
proof:
1. `RaffleFactory` deploys clones via `Clones.clone(raffleImplementation)` (line 729), which uses `CREATE` from `address(factory)`. At factory nonce `2` (`raffleId = 1`), the address of the next clone at nonce `3` (`raffleId = 2`) is deterministically `nextRaffle = computeCreateAddress(factory, 3)`.
2. Before `raffleId = 2` is created, `nextRaffle.code.length == 0` and `isRaffle[nextRaffle] == false`.
3. In `Raffle #1`:
   - If `Raffle #1` is initialized with `params.sponsorRecipient = nextRaffle`, `RaffleFactory._validateCreateParams` (line 789) and `Raffle.initialize` (line 196) call `_isProtocolDestination(nextRaffle, prizeToken)` (lines 596-608), which returns `false` because `nextRaffle.code.length == 0`.
   - Alternatively, any ticket holder in `Raffle #1` calls `transferFrom(holder, nextRaffle, ticketId)`. `Raffle._update` (line 501) calls `_isProtocolDestination(nextRaffle, address(prizeToken))`, which returns `false`, setting `ownerOf(ticketId) = nextRaffle`.
4. When any user later calls `factory.createRaffle(...)`, `Raffle #2` is deployed at `nextRaffle` (`nextRaffle.code.length == 45`) and `isRaffle[nextRaffle]` is set to `true` (line 748).
5. In `Raffle #1`, `_isProtocolDestination(nextRaffle, address(prizeToken))` now evaluates `destination.code.length != 0 && canonicalFactory.isRaffle(destination)` to `true`:
   - `releaseSponsorProceeds()` (line 383) calls `_transferQuote(nextRaffle, amount)` (line 568), which reverts with `InvalidQuoteDestination(nextRaffle)` forever, locking `sponsorProceeds` in `Raffle #1`.
   - In `Status.CashWon` or `Status.Refunding`, `releaseSponsorPrize()` (lines 398-410) does not call `_isProtocolDestination` and executes `prizeToken.transferFrom(address(this), nextRaffle, prizeTokenId)`, transferring `Raffle #1`'s prize NFT into `Raffle #2` (`nextRaffle`), which has no function to transfer an unconfigured NFT out.
   - Any ticket owned by `nextRaffle` can never call `redeemWinningTicket` (line 324) or `refundTickets` (line 363), locking the winner claim or `remainingRefundLiability` forever.
description: A user can send a ticket or set sponsorRecipient to a next Raffle address before deployment, so no caller can withdraw the payout later.
fix: Deploy clones with Clones.cloneDeterministic, verify recipient support in _update and initialize, and check _isProtocolDestination in releaseSponsorPrize.

FINDING | contract: Raffle | function: enableRefunds | bug_class: sponsor-cancel-frontrun-lock | group_key: Raffle | enableRefunds | sponsor-cancel-frontrun-lock
seam: three-way
trace: attacker calls Raffle.buyEntries(attacker, 1) [quoteToken.safeTransferFrom pays 1e6, sets totalEntries = 1] → sponsor calls Raffle.enableRefunds() [totalEntries == 0 branch skipped, reverts with RefundsNotAvailable] → at endTime, Raffle.requestDraw() + fulfillRandomWords() resolves to Status.CashWon → attacker calls redeemWinningTicket(1) [recovers 800,000 USDC]
violated_principle: The sponsor can cancel an unsold raffle before endTime to recover the escrowed prize NFT without waiting for the sale window and draw timeouts.
path: attacker → Raffle.buyEntries(attacker, 1) → sponsor's Raffle.enableRefunds() reverts → prize NFT locked until after endTime and VRF resolution or draw timeout
proof:
1. Sponsor creates a raffle with `reserveEntries = 1_000` (`1,000 USDC`) and `endTime = uint64(block.timestamp + 30 days)`.
2. While `totalEntries == 0` and `block.timestamp < endTime`, the sponsor submits `enableRefunds()` to cancel the raffle and call `releaseSponsorPrize()` (lines 282-287, 398-410).
3. An attacker front-runs `enableRefunds()` with `buyEntries(attacker, 1)` (lines 212-240), paying `1_000_000` raw USDC (`1 USDC`) and setting `totalEntries = 1` and `unsettledPot = 1_000_000`.
4. The sponsor's `enableRefunds()` call now hits the `else` branch at lines 288-291 (`deadline = drawRequestDeadline() = endTime + 2 days`) and reverts with `RefundsNotAvailable(deadline, block.timestamp)`.
5. The sponsor's NFT remains locked in `Raffle` for up to `30 days` until `endTime`. After `endTime`, because `totalEntries = 1 < reserveEntries (1_000)`, if `requestDraw()` is called and VRF resolves to `Status.CashWon`, `_settleWinningTicket(1)` allocates `cashAmount = Math.mulDiv(1_000_000, 8000, 10_000) = 800_000` (`0.80 USDC`) to the attacker (line 549), so the attacker locks the prize NFT for up to 30 days at a net cost of `200_000` raw USDC (`$0.20`).
description: An attacker can buy one entry before the sponsor calls enableRefunds, so enableRefunds fails and the contract holds the prize until the sale ends.
fix: Allow the sponsor to cancel the raffle and refund all sold tickets before the sale ends if totalEntries is below reserveEntries.

FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: premature-sponsor-proceeds-release | group_key: Raffle | _settleWinningTicket | premature-sponsor-proceeds-release
seam: three-way
trace: VRF callback sets status = Status.NftWon → anyone calls Raffle.settleWinningTicket(ticketId) [sets sponsorProceeds = 95% of grossPot without checking or transferring prizeToken] → Raffle.releaseSponsorProceeds() transfers 95% USDC to sponsorRecipient → winner calls Raffle.redeemWinningTicket(ticketId) → prizeToken.transferFrom reverts
violated_principle: In an NftWon outcome, the sponsor exchanges the escrowed prize NFT for 95% of gross ticket sales and must not collect the proceeds if the prize NFT cannot be delivered to the winner.
path: caller → Raffle.settleWinningTicket → Raffle.releaseSponsorProceeds → sponsor receives 95% of unsettledPot while Raffle.redeemWinningTicket reverts on prizeToken.transferFrom
proof:
1. Sponsor creates a raffle with `prizeToken` (e.g., an ERC-721 collection with pausable transfers, transfer validator rules such as ERC-721C, or admin transfer restrictions) and `reserveEntries = 100`.During `createRaffle`, `prize.safeTransferFrom(sponsor, raffle, prizeTokenId)` succeeds (line 751).
2. Buyers purchase `100` entries for `100_000_000` raw USDC (`100 USDC`). After `endTime`, `fulfillRandomWords` sets `status = Status.NftWon` (line 524).
3. Before the winner redeems, `settleWinningTicket(winningTicketId)` is called (line 307). `_settleWinningTicket` (lines 536-561) does not transfer `prizeToken`; it sets `protocolFees = 5_000_000` (`5 USDC`) and `sponsorProceeds = 95_000_000` (`95 USDC`).
4. `releaseSponsorProceeds()` (lines 378-385) immediately transfers `95_000_000` raw USDC to `sponsorRecipient`.
5. When the winning ticket owner calls `redeemWinningTicket(winningTicketId)` (lines 311-349), `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` (line 337) reverts (because transfers from `address(this)` are paused or blocked by `prizeToken`). Because `status` is already terminal (`Status.NftWon`) and `unsettledPot == 0`, the winner can neither receive the NFT nor recover their USDC, while the sponsor keeps the `95 USDC`.
description: A sponsor can call settleWinningTicket and releaseSponsorProceeds to take the quote tokens even when prizeToken blocks the prize transfer in redeemWinningTicket.
fix: Require prizeClaimed to be true before releaseSponsorProceeds and releaseProtocolFees can pay out when status is Status.NftWon.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: unbounded-reserve-entries | group_key: RaffleFactory | _validateCreateParams | unbounded-reserve-entries
seam: three-way
trace: sponsor calls RaffleFactory.createRaffle with reserveEntries = type(uint128).max → _validateCreateParams checks only reserveEntries != 0 → users call Raffle.buyEntries → Raffle.fulfillRandomWords evaluates totalEntries >= reserveEntries as false → Status.CashWon allocates 15% of pot to sponsor and returns NFT
violated_principle: Every active raffle must have a reachable reserve threshold under which the escrowed NFT can be won by entry buyers.
path: sponsor → RaffleFactory.createRaffle(reserveEntries = type(uint128).max) → Raffle.fulfillRandomWords always resolves to Status.CashWon → sponsor claims 15% of grossPot via releaseSponsorProceeds and reclaims the NFT via releaseSponsorPrize
proof:
1. `RaffleFactory._validateCreateParams` (line 801) validates `reserveEntries` only with `if (params.reserveEntries == 0) revert ZeroReserveEntries();`.
2. A sponsor calls `createRaffle` with `params.reserveEntries = type(uint128).max` (`340,282,366,920,938,463,463,374,607,431,768,211,455`).
3. Meeting `reserveEntries` in `Raffle.buyEntries` (line 226) requires transferring `uint256(type(uint128).max) * 1_000_000 = 340,282,366,920,938,463,463,374,607,431,768,211,455,000,000` raw USDC (`$3.40e38` USDC), which is impossible given canonical USDC supply.
4. When the raffle resolves in `fulfillRandomWords` (line 524), `totalEntries >= reserveEntries` is always `false`, forcing `status = Status.CashWon`.
5. In `_settleWinningTicket` (lines 549-550), the sponsor is allocated `sponsorProceeds = grossPot - Math.mulDiv(grossPot, 500, 10_000) - Math.mulDiv(grossPot, 8000, 10_000) = 15%` of `grossPot` and reclaims the NFT via `releaseSponsorPrize()` (line 398) with zero risk of losing the NFT.
description: A sponsor can set reserveEntries above the quoteToken supply, so Status.NftWon is impossible and the sponsor takes fifteen percent plus the prize.
fix: Enforce a maximum reserveEntries constant in RaffleFactory._validateCreateParams so every created raffle has a reachable reserve threshold.

FINDING | contract: Raffle | function: releaseSponsorPrize | bug_class: unsafe-prize-nft-transfer | group_key: Raffle | releaseSponsorPrize | unsafe-prize-nft-transfer
seam: periphery×first-principles
trace: sponsor calls RaffleFactory.createRaffle with contract sponsorRecipient → raffle ends in Status.CashWon or Status.Refunding → any caller calls Raffle.releaseSponsorPrize() → prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId) bypasses onERC721Received → prize NFT is stranded in sponsorRecipient
violated_principle: Escrowed prize NFTs must be delivered only to recipients that can handle ERC-721 tokens and must not be stranded by coupling USDC and ERC-721 recipient configuration to raw transferFrom.
path: caller → Raffle.releaseSponsorPrize / Raffle.redeemWinningTicket → prizeToken.transferFrom(address(this), recipient, prizeTokenId) without onERC721Received check → NFT locked in contract recipient
proof:
1. `IRaffleFactory.CreateRaffleParams` (lines 1362-1368) defines a single `sponsorRecipient` address for both USDC payouts (`releaseSponsorProceeds`, line 383) and ERC-721 returns (`releaseSponsorPrize`, line 407).
2. Neither `RaffleFactory._validateCreateParams` (lines 777-802) nor `Raffle.initialize` (lines 179-209) checks whether a contract `sponsorRecipient` implements `IERC721Receiver`.
3. When the raffle enters `Status.CashWon` or `Status.Refunding`, `releaseSponsorPrize()` (lines 398-410) is callable by anyone and executes `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` instead of `safeTransferFrom` (and `redeemWinningTicket` at line 337 likewise executes `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`).
4. If `sponsorRecipient` is a USDC treasury or splitter contract that cannot transfer ERC-721 tokens, or an ERC-721 vault contract that records deposits inside `onERC721Received`, `prizeToken.transferFrom` bypasses `onERC721Received` while `prizeToken.ownerOf(prizeTokenId) == recipient` passes (line 408), permanently stranding the NFT inside `sponsorRecipient`.
description: Any caller can call releaseSponsorPrize to send the prize via transferFrom to a contract sponsorRecipient that cannot transfer ERC-721 tokens.
fix: Separate the quote-token recipient from the prize recipient, or use safeTransferFrom with a fallback address for prize delivery.

LEAD | contract: Raffle | function: requestDraw | bug_class: premature-in-flight-flag-reset | group_key: Raffle | requestDraw | premature-in-flight-flag-reset
seam: execution×periphery
code_smells: Raffle.requestDraw sets _requestInFlight to false on line 263 before the low-level native refund call to msg.sender on line 270, while rawFulfillRandomWords has no nonReentrant modifier.
description: An attacker can revert inside the native refund call if a wrapper callback fulfills during requestDraw after _requestInFlight becomes false. We did not verify a production wrapper that fulfills in the same transaction.
