# Deliverable 5: Prioritized Recommendations

## Recommendations

### Critical / High Priority (Fix Before Launch)
1. **Resolve Untrusted `prizeToken` Settlement vs. Redemption Decoupling (`TIA-01`)**
   - **Impact**: Prevents a malicious sponsor (or a sponsor whose `prizeToken` collection becomes paused/restricted) from claiming 95% of buyers' USDC in `NftWon` while the winner is permanently unable to redeem the prize NFT.
   - **Action**:
     - Either require `prizeClaimed == true` before `releaseSponsorProceeds()` can be called in `Status.NftWon` (and provide a timeout path to transition to `Refunding` if `prizeToken.transferFrom` reverts), **or**
     - Add an allowlist of vetted ERC-721 `prizeToken` contracts in `RaffleFactory` if `settleWinningTicket` and `releaseSponsorProceeds` must remain independent of `redeemWinningTicket`.

### Medium Priority (Address Before Mainnet / Multi-Token Expansion)
2. **Protect Contract Recipients During Prize NFT Delivery (`TIA-02`)**
   - **Impact**: Prevents permanent loss of prize NFTs when `sponsorRecipient` is a USDC revenue-split contract that cannot handle ERC-721 tokens, or when a contract `winner` requires `onERC721Received` callbacks.
   - **Action**: Separate `sponsorPrizeRecipient` (or return the prize to `sponsor` by default) from `sponsorRecipient`, or allow `winner` / `sponsor` to specify a receiver-checked destination address when claiming the prize NFT.

3. **Add Balance-Delta Verification in `buyEntries` (`TIA-04`)**
   - **Impact**: Guarantees `accountedQuoteBalance() <= quoteToken.balanceOf(address(this))` even if deployed with a fee-capable 6-decimal token.
   - **Action**: Record `uint256 balanceBefore = quoteToken.balanceOf(address(this))` before `safeTransferFrom` and require `quoteToken.balanceOf(address(this)) - balanceBefore == grossAmount`.

4. **Add Fallback Recipient Flexibility for Blacklisted `sponsorRecipient` / `protocolTreasury` (`TIA-03`)**
   - **Impact**: Prevents permanent freezing of `sponsorProceeds` or `protocolFees` if Circle blacklists `sponsorRecipient` or `protocolTreasury`.
   - **Action**: Allow `sponsor` to pass an alternate recipient address to `releaseSponsorProceeds`, and allow `protocolTreasury` to rotate its address for future raffles.

### Low / Informational Priority (Best-Practice Hardening)
5. **Implement `tokenURI(uint256)` on `Raffle` Tickets (`TIA-06`)**
   - **Action**: Override `tokenURI(uint256 ticketId)` in `Raffle.sol` to return on-chain JSON metadata containing `raffleId`, `ticketId`, and `ticketRange(ticketId)`.

6. **Index Custom Event Parameters & Include `i_linkToken` in `_isProtocolDestination` (`TIA-05`, `TIA-07`)**
   - **Action**: Mark `raffleId`, `raffle`, `ticketId`, `buyer`, and `recipient` as `indexed` in `IRaffle.sol` and `IRaffleFactory.sol`, add `address(i_linkToken)` to `_isProtocolDestination`, and cache `raffleImplementation` in `Raffle` to avoid an external `STATICCALL` in `_isProtocolDestination`.
