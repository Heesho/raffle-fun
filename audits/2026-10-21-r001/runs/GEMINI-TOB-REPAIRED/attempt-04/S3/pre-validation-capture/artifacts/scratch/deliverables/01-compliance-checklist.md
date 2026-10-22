# Deliverable 1: Compliance Checklist

## Token Standards Compliance

### General Considerations
- [x] Specification & interface documentation present (`DESIGN.md`, `IRaffle.sol`, `IRaffleFactory.sol`)
- [x] Pinned dependency integrity verified (`dependency-hashes.json` — all 31 files match SHA-256)
- [ ] Security contact (`@custom:security-contact` / `SECURITY.md`) and security mailing list established

### Contract Composition
- [x] Avoids unnecessary complexity (`710` SLOC across 5 source files; max cyclomatic complexity `10` in `redeemWinningTicket`)
- [x] Uses Solidity `0.8.36` built-in overflow/underflow protection (`0` `unchecked` blocks in `src/`)
- [x] Single canonical ERC-1167 address entry point per raffle clone (`Clones.clone(raffleImplementation)`)
- [x] Bounded batch operations (`MAX_REFUND_TICKET_BATCH_SIZE = 100` in `refundTickets`)

### Owner Privileges
- [x] Non-upgradeable contracts (`RaffleFactory` and `Raffle` clones are immutable)
- [x] No privileged or arbitrary minting (`buyEntries` requires `entryCount * ENTRY_PRICE` in `quoteToken`)
- [x] No protocol-level pause or blacklist capable of trapping user tickets
- [x] Sponsor early cancellation restricted to `totalEntries == 0` (`Raffle.sol:280-284`)

### ERC20 Conformity (Integrated `quoteToken` — Canonical 6-Decimal USDC)
- [x] Transfer functions return `bool` or empty return data handled via OpenZeppelin `SafeERC20` (`Raffle.sol:224, 566`)
- [x] `decimals()` validated at factory construction (`IERC20Metadata(quoteToken_).decimals() == 6`, `RaffleFactory.sol:70-74`)
- [x] Contract code existence verified (`_requireContract(quoteToken_)`, `RaffleFactory.sol:66`)
- [x] No `approve()` calls made by `Raffle` or `RaffleFactory` (immune to approval race conditions on-contract)
- [x] Zero-value transfers prevented by non-zero guards across all entry points (`Raffle.sol:218, 339, 350, 378, 389`)

### ERC721 Conformity (`Raffle` Ticket Token Implementation & Integrated `prizeToken`)
- [x] `slither-check-erc . Raffle --erc erc721` passes 13/13 functions and 3/3 events (`scratch/logs/05_slither_check_erc721_orig.log`)
- [x] Transfers to `0x0` revert (`ERC721InvalidReceiver(address(0))`)
- [x] Transfers and mints to protocol plumbing revert (`_isProtocolDestination` in `Raffle._update`, `Raffle.sol:497-501`)
- [x] `safeTransferFrom` and `_safeMint` verify `onERC721Received` on contract recipients
- [x] `name()` (`"raffle.fun Ticket"`) and `symbol()` (`"RAFFLE"`) implemented as clone-safe pure overrides (`Raffle.sol:486-494`)
- [x] `ownerOf` reverts for invalid/burned token IDs (`ERC721NonexistentToken`)
- [x] Transfers and burns clear single-token approvals (`ERC721._update`)
- [x] Token IDs (`1..ticketCount`) and `_ticketRanges[ticketId]` are immutable once minted
- [ ] `tokenURI(uint256)` returns non-empty metadata (currently returns `""` — `TIA-06`)
