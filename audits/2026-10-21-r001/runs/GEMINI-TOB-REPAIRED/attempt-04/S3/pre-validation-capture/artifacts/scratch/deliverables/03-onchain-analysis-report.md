# Deliverable 3: On-chain Analysis Report

## On-chain Token Analysis

**Contract Address**: N/A (Pre-deployment source codebase in `packages/contracts`; no deployed contract address or live RPC endpoint configured)
**Chain**: EVM-compatible target (`pragma solidity 0.8.36`, `evm_version = "paris"`)
**Block Number**: N/A (Offline static + local Foundry/Echidna EVM execution; coverage gap documented in `stage-report.md` Section 6.1)

### Supply Metrics (`Raffle` Ticket ERC-721 Model)
- Initial Supply per Raffle Clone: `0` tickets (`0` entries)
- Max Entries per Raffle Clone: `type(uint128).max` (`340,282,366,920,938,463,463,374,607,431,768,211,455` entries at `1_000_000` quote units per entry)
- Minting Mechanism: Permissionless during `Status.Active` prior to `endTime` (`buyEntries`), 1 sequential `ticketId` per purchase call covering `[firstEntry, lastEntry]`
- Burning Mechanism: Atomic burn in `redeemWinningTicket(ticketId)` (winning ticket in `NftWon` or `CashWon`) and `refundTickets(uint256[] ticketIds)` (all tickets in `Refunding`, up to `100` tickets per batch)

### Holder Distribution & Concentration Mechanics
- Concentration Impact: Winning probability (`winningEntry = (_randomWords[0] % totalEntries) + 1`) is strictly linear in entries purchased (`1_000_000` quote units per entry).
- Flash Loan / Flash Mint Resistance: **HIGH (Immune)** — Entry purchases lock `quoteToken` before `endTime`, whereas `requestDraw()` requires `block.timestamp >= endTime` and asynchronous Chainlink VRF v2.5 fulfillment (`requestConfirmations = 3`, `_requestInFlight` guard).
- Centralization Risk: **ZERO** on `Raffle` / `RaffleFactory` (no admin keys); **MODERATE** external dependency on Circle (`quoteToken` USDC blacklist/pause/upgradeability) and Chainlink VRF v2.5 Wrapper liveness (mitigated by `DRAW_CALLBACK_TIMEOUT = 1 days` fallback to `Status.Refunding` via `enableRefunds()`).
