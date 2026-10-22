# Deliverable 4: Integration Safety Assessment

## Protocol Token Integration Analysis

### Current Implementation:

1. **Quote Token (`quoteToken` — ERC-20) Transfers**:
   ```solidity
   // packages/contracts/src/Raffle.sol:223-224
   uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
   quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

   // packages/contracts/src/Raffle.sol:564-567
   function _transferQuote(address to, uint256 amount) private {
       if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
       quoteToken.safeTransfer(to, amount);
   }
   ```
   - ✓ Uses OpenZeppelin v5.6.0 `SafeERC20` (`safeTransferFrom`, `safeTransfer`).
   - ✓ Protected by `ReentrancyGuard.nonReentrant` and strict CEI state updates.
   - ✓ Blocks transfers to protocol destinations (`_isProtocolDestination`).
   - ✗ Does not check `balanceBefore` / `balanceAfter` on `safeTransferFrom` (`TIA-04`).

2. **Prize Token (`prizeToken` — ERC-721) Escrow & Delivery**:
   ```solidity
   // packages/contracts/src/RaffleFactory.sol:101-106
   prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
   if (
       prize.ownerOf(params.prizeTokenId) != raffle
           || IRaffle(raffle).status() != IRaffle.Status.Active
   ) {
       revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
   }

   // packages/contracts/src/Raffle.sol:334-336
   prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
   if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
       revert PrizeDeliveryVerificationFailed(winner);
   }
   ```
   - ✓ Verifies `IERC165.supportsInterface(type(IERC721).interfaceId)` and post-transfer `ownerOf` on both escrow and delivery.
   - ✗ Decouples `settleWinningTicket` (unlocking `sponsorProceeds`) from `redeemWinningTicket` (delivering `prizeToken`) without a `prizeToken` allowlist (`TIA-01`).
   - ✗ Uses raw `transferFrom` instead of `safeTransferFrom` on prize delivery (`TIA-02`).

### Vulnerabilities Identified:
1. **`TIA-01` (High)**: Malicious or paused `prizeToken` allows sponsor to extract 95% of USDC pot via `settleWinningTicket` + `releaseSponsorProceeds` in `NftWon` while winner NFT redemption (`redeemWinningTicket`) reverts.
2. **`TIA-02` (Medium)**: Raw `prizeToken.transferFrom` in `redeemWinningTicket` and permissionless `releaseSponsorPrize` can lock NFTs in contract recipients (`sponsorRecipient` or contract `winner`) that do not support arbitrary ERC-721 tokens.
3. **`TIA-03` (Medium)**: Immutable `sponsorRecipient` and `protocolTreasury` cannot be rotated if blacklisted by USDC.
4. **`TIA-04` (Medium)**: Missing balance-delta check in `buyEntries` makes internal accounting vulnerable to fee-on-transfer or deflationary tokens.
