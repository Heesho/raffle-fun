# Trail of Bits Stage 1 — Audit Context Building (`audit-context-building`)

## Phase 1 — Initial Orientation & Architectural Overview

### Scope Inventory (Frozen Commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`)
1. `packages/contracts/src/Raffle.sol` (614 lines, `pragma solidity 0.8.36`, `cancun`): Per-raffle EIP-1167 clone implementation inheriting `IRaffle`, `ERC721`, `IERC721Receiver`, `VRFV2PlusWrapperConsumerBase`, and `ReentrancyGuard`.
2. `packages/contracts/src/RaffleFactory.sol` (186 lines, `pragma solidity 0.8.36`): Non-upgradeable factory deploying `Raffle` clones via `Clones.clone(raffleImplementation)`, recording registry mappings (`raffleById`, `idByRaffle`, `isRaffle`), and escrowing the prize NFT via `safeTransferFrom`.
3. `packages/contracts/src/interfaces/IRaffle.sol` (521 lines): External interface, lifecycle state enum (`Uninitialized`, `Initialized`, `Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`), custom errors, events, and function specifications.
4. `packages/contracts/src/interfaces/IRaffleFactory.sol` (150 lines): Factory interface, `CreateRaffleParams` struct, errors, events, and view specifications.
5. `packages/contracts/src/libraries/RaffleConstants.sol` (43 lines): Protocol-wide constants (`ENTRY_PRICE = 1_000_000`, `QUOTE_DECIMALS = 6`, `BPS_DENOMINATOR = 10_000`, `NFT_WON_SPONSOR_BPS = 9_500`, `CASH_WON_WINNER_BPS = 8_000`, `CASH_WON_SPONSOR_BPS = 1_500`, `PROTOCOL_FEE_BPS = 500`, `MAX_SALE_DURATION = 30 days`, `DRAW_REQUEST_TIMEOUT = 2 days`, `DRAW_CALLBACK_TIMEOUT = 2 days`, `VRF_CALLBACK_GAS_LIMIT = 300_000`, `VRF_REQUEST_CONFIRMATIONS = 3`, `VRF_NUM_WORDS = 1`).

---

## Phase 2 — Ultra-Granular Function Micro-Analysis

### `RaffleFactory::constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_)` (`RaffleFactory.sol:L68-L103`)
- **Purpose**: Validates immutable factory parameters (`quoteToken`, `vrfWrapper`, `protocolTreasury`), checks `quoteToken.decimals() == 6` via `staticcall`, verifies `vrfWrapper.link() != address(0)`, and deploys the singleton `raffleImplementation = address(new Raffle(vrfWrapper_))` at factory nonce `1`.
- **Risk Seams**:
  - `protocolTreasury_` is checked against `address(0)`, `address(this)`, `quoteToken_`, `vrfWrapper_`, and `raffleImplementation`, and checked for `!isRaffle[protocolTreasury_]` (`L165`). However, if `protocolTreasury_` equals a future clone `CREATE` address $R_k = 	ext{CREATE}(	ext{factory}, k+1)$, `createRaffle` will revert permanently at clone $k$ when `Raffle::initialize` checks `_isProtocolDestination`.

### `RaffleFactory::createRaffle(CreateRaffleParams calldata params)` (`RaffleFactory.sol:L106-L150`)
- **Purpose**: Validates `params`, increments `raffleCount`, deploys a minimal proxy clone via `Clones.clone(raffleImplementation)`, initializes the clone, updates registry mappings (`raffleById`, `idByRaffle`, `isRaffle`), transfers the NFT via `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, verifies `prize.ownerOf(params.prizeTokenId) == raffle`, and emits `RaffleCreated`.
- **Risk Seams**:
  - **Predictable `CREATE` clone address**: `Clones.clone` uses `CREATE`, making future clone addresses predictable before deployment (`code.length == 0`, `isRaffle == false`).
  - **Mid-escrow activation**: `Raffle::onERC721Received` sets `status = Status.Active` inside `prize.safeTransferFrom` before `createRaffle` verifies `ownerOf` or emits `RaffleCreated`. Since the clone's own `ReentrancyGuard` is not entered during `createRaffle`, an untrusted `prizeToken` can call `raffle.buyEntries` before `RaffleCreated` is emitted.

### `Raffle::initialize(...)` (`Raffle.sol:L176-L206`) & `Raffle::_isProtocolDestination(address destination, address prizeAsset)` (`Raffle.sol:L593-L605`)
- **Purpose**: One-time clone initializer restricted to `msg.sender == factory`. Validates destinations via `_isProtocolDestination` and sets `status = Status.Initialized`.
- **Risk Seams**:
  - `_isProtocolDestination` only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0` (`Raffle.sol:L601`). A precomputed future clone address $R_{	ext{future}}$ has `code.length == 0` and `isRaffle == false` prior to deployment, bypassing `_isProtocolDestination` in `initialize`, `buyEntries`, and `_update`.

### `Raffle::buyEntries(address recipient, uint128 entryCount)` (`Raffle.sol:L209-L236`) & `Raffle::_update(address to, uint256 tokenId, address auth)` (`Raffle.sol:L497-L502`)
- **Purpose**: Accepts `entryCount * ENTRY_PRICE` in `quoteToken` via `safeTransferFrom`, increments `totalEntries`, `unsettledPot`, and `ticketCount`, records `TicketRange(startEntry, endEntry)`, and mints sequential `ticketId` via `_safeMint(recipient, ticketId)`.
- **Risk Seams**:
  - Neither `sponsor` nor `sponsorRecipient` is blocked from buying tickets, enabling a 95% self-purchase rebate once `totalEntries >= reserveEntries`.
  - `_update` does not block secondary ticket transfers during `Status.Drawing` or after draw fulfillment.

### `Raffle::requestDraw()` (`Raffle.sol:L243-L273`), `Raffle::fulfillRandomWords(...)` (`Raffle.sol:L509-L530`), & `Raffle::enableRefunds()` (`Raffle.sol:L276-L303`)
- **Purpose**: Manages VRF v2.5 native-funded randomness request (`[endTime, endTime + 2 days)`), callback fulfillment (`[drawRequestedAt, drawRequestedAt + 2 days)`), and timeout/empty-raffle refund activation.
- **Risk Seams**:
  - `enableRefunds()` allows pre-`endTime` cancellation by `sponsor` only when `totalEntries == 0` (`Raffle.sol:L281`), which can be front-run by a 1-USDC `buyEntries` call.
  - `requestDraw()` allows drawing when `totalEntries < reserveEntries` even if `ticketCount == 1` (single buyer), letting the sponsor force `Status.CashWon` and extract 20% (`15%` sponsor + `5%` treasury) from the sole buyer.

### `Raffle::settleWinningTicket(uint256 ticketId)` (`Raffle.sol:L306-L308`), `Raffle::_settleWinningTicket(uint256 ticketId)` (`Raffle.sol:L533-L558`), `Raffle::redeemWinningTicket(uint256 ticketId)` (`Raffle.sol:L311-L346`), `Raffle::releaseSponsorProceeds()` (`Raffle.sol:L375-L382`), `Raffle::releaseProtocolFees()` (`Raffle.sol:L385-L392`), & `Raffle::releaseSponsorPrize()` (`Raffle.sol:L395-L407`)
- **Purpose**: Storage-only pot settlement and independent pull claims for winner, sponsor, and treasury.
- **Risk Seams**:
  - `_settleWinningTicket` credits `sponsorProceeds = 95%` in `Status.NftWon` without verifying `prizeToken` delivery, and `releaseSponsorProceeds()` does not require `prizeClaimed == true`.
  - `releaseSponsorPrize()` (`Raffle.sol:L404`) and `redeemWinningTicket()` (`Raffle.sol:L334`) omit `_isProtocolDestination`, allowing prize NFTs to be transferred into a later `Raffle` clone if `sponsorRecipient` or `winner` was set to a precomputed clone address before that clone's deployment.
