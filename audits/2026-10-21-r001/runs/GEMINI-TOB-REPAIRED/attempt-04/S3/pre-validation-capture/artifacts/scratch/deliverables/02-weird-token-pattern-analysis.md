# Deliverable 2: Weird Token Pattern Analysis

## Weird ERC20 & ERC721 Pattern Detection

### Patterns Present / Relevant in Target Context:
1. **Blocklists (Pattern 7.7 — USDC `blacklist`)**
   - Location: `src/Raffle.sol:50-55, 198-199, 323-393`
   - Risk Level: **MEDIUM (`TIA-03`)**
   - Mitigation: Pull-based payout functions isolate claimants, and `Raffle._update` allows blacklisted ticket holders to transfer `RAFFLE` tickets in `CashWon`/`Refunding` to an un-blacklisted address (`testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot`). However, `sponsorRecipient` and `protocolTreasury` are immutable and have no fallback recipient if blacklisted.

2. **Pausable & Upgradeable Quote Token (Patterns 7.5, 7.8 — USDC `FiatTokenProxy` / `Pausable`)**
   - Location: `src/RaffleFactory.sol:26, 70-74`, `src/Raffle.sol:58, 224, 566`
   - Risk Level: **LOW**
   - Mitigation: Accepted canonical dependency per `DESIGN.md:19`. `NftWon` winner NFT redemption (`redeemWinningTicket`) does not touch `quoteToken` and succeeds even if USDC is paused.

3. **Fee-on-Transfer & Rebasing Quote Tokens (Patterns 7.3, 7.4)**
   - Location: `src/Raffle.sol:223-234` (`buyEntries`), `src/Raffle.sol:469-477` (`accountedQuoteBalance`)
   - Risk Level: **MEDIUM (`TIA-04` — if deployed with a fee-bearing 6-decimal token or if a 6-decimal token activates a fee switch)**
   - Mitigation: Currently relies on deployment configuration using canonical fee-free USDC; lacks on-chain `balanceAfter - balanceBefore == grossAmount` assertion in `buyEntries`.

4. **Low Decimals (Pattern 7.14 — 6 Decimals)**
   - Location: `src/libraries/RaffleConstants.sol:13-25`, `src/RaffleFactory.sol:70-74`
   - Risk Level: **NONE (Properly Handled)**
   - Mitigation: `ENTRY_PRICE = 1_000_000` and `QUOTE_TOKEN_DECIMALS = 6` are enforced in `RaffleFactory.constructor`. Because `1_000_000` is divisible by `BPS = 10_000`, all fee (`500` bps) and cash-winner (`3_000` bps) splits are exact integers with zero rounding dust.

5. **Untrusted / Pausable / Restrictive ERC-721 `prizeToken` (Category 8 & 10 Extension)**
   - Location: `src/Raffle.sol:304-346, 375-382`, `src/RaffleFactory.sol:124-175`
   - Risk Level: **HIGH (`TIA-01`) / MEDIUM (`TIA-02`)**
   - Mitigation: Escrow deposit (`createRaffle`) and outbound deliveries (`redeemWinningTicket`, `releaseSponsorPrize`) verify `prizeToken.ownerOf(prizeTokenId)`. However, decoupling storage-only `settleWinningTicket` (which unlocks `sponsorProceeds`) from `redeemWinningTicket` allows a malicious/pausable `prizeToken` to block winner NFT redemption after the sponsor claims 95% of the USDC pot (`TIA-01`), and outbound delivery uses raw `transferFrom` instead of `safeTransferFrom` (`TIA-02`).

### Relevant External Integrations:
- If integrating with arbitrary ERC-20 tokens beyond canonical USDC: add balance-delta verification in `buyEntries` (`TIA-04`).
- If integrating with arbitrary sponsor-supplied ERC-721 `prizeToken` contracts: either gate `releaseSponsorProceeds` in `NftWon` on `prizeClaimed == true` or restrict `prizeToken` to an allowlist of verified ERC-721 contracts (`TIA-01`).
