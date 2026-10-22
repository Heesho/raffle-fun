## REQ-40 — redemption restricted to the live ticket owner

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — `DESIGN.md:L2, sentence 13`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For this record's supplied access-control predicate, `redeemWinningTicket` may complete only when `msg.sender` is the ticket's current ERC-721 owner during that execution. A historical purchaser, prior owner, approved address, approved operator, or permissionless settler must not substitute for the live owner. The owner gate must cover both terminal outcomes and both the already-settled and settle-during-redemption paths.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L309-L325
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    if (!settlementComplete) {
        _settleWinningTicket(ticketId);
    } else if (ticketId != winningTicketId) {
        revert WinningTicketMismatch(ticketId, winningTicketId);
    }

    address winner = ownerOf(ticketId);
    if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

    winnerRecipient = winner;
    winnerRedeemed = true;
    _burn(ticketId);
```

- The live owner lookup and direct sender equality are in the only production implementation of `redeemWinningTicket`. The check occurs after optional settlement and before the redemption writes or burn (`target/packages/contracts/src/Raffle.sol:L309-L325`).
- The check is direct equality with the returned owner; it does not use ERC-721 approval or operator authorization. Approved operators are permitted by the inherited transfer authorization helper, but that helper is not called by redemption (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L187`; `target/packages/contracts/src/Raffle.sol:L320-L321`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63
function ownerOf(uint256 tokenId) public view virtual returns (address) {
    return _requireOwned(tokenId);
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L146-L148
function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
    return _owners[tokenId];
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L426-L431
function _requireOwned(uint256 tokenId) internal view returns (address) {
    address owner = _ownerOf(tokenId);
    if (owner == address(0)) {
        revert ERC721NonexistentToken(tokenId);
    }
    return owner;
}
```

- `Raffle` does not override `ownerOf` or `_ownerOf`. The inherited call therefore reads the ERC-721 `_owners` ledger and rejects a nonexistent or previously burned ticket (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63`, `L146-L148`, `L426-L431`).
- Ticket mint, transfer, and burn updates enter `Raffle._update` and delegate to `ERC721._update`; the base implementation reads the prior ledger owner and writes `_owners[tokenId] = to` (`target/packages/contracts/src/Raffle.sol:L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`). Thus `ownerOf` is a read of the ledger as updated by any earlier ticket transfer, not a purchase-time or settlement-time snapshot.
- After the owner read, no external call occurs before `_burn(ticketId)` (`target/packages/contracts/src/Raffle.sol:L320-L325`). The inherited burn routes through `_update(address(0), ticketId, address(0))` and rejects a nonexistent token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L292-L308`).
- The `nonReentrant` modifier enters the guard before the body and rejects an already-entered guarded call (`target/packages/contracts/src/Raffle.sol:L309`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`).

---

**Paths walked:**

- `redeemWinningTicket` with `winnerRedeemed == true` → reverts before settlement or ownership resolution (`target/packages/contracts/src/Raffle.sol:L309-L310`). ✓
- `redeemWinningTicket` in a nonterminal status → reverts; only `NftWon` and `CashWon` reach the owner gate (`target/packages/contracts/src/Raffle.sol:L311-L312`). ✓
- Unsettled redemption → `_settleWinningTicket(ticketId)` validates the winning range and allocates storage, then execution reads `ownerOf(ticketId)` and compares it to `msg.sender` (`target/packages/contracts/src/Raffle.sol:L314-L321`, `L533-L558`, `L579-L585`). The settlement helper contains no ticket-owner read, ownership write, or external asset transfer (`target/packages/contracts/src/Raffle.sol:L528-L558`). ✓
- Previously settled redemption with a different ID → reverts with `WinningTicketMismatch` before ownership resolution (`target/packages/contracts/src/Raffle.sol:L314-L318`). ✓
- Previously settled redemption with the recorded ID → reaches the same live `ownerOf` lookup and direct caller comparison (`target/packages/contracts/src/Raffle.sol:L314-L321`). ✓
- Nonexistent or already burned winning ticket → inherited `ownerOf` reaches `_requireOwned` and reverts because the ledger owner is zero (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63`, `L426-L431`). ✓
- Current owner, `NftWon` → passes the common owner gate, is recorded, and the ticket is burned before the NFT-delivery branch (`target/packages/contracts/src/Raffle.sol:L320-L337`). ✓
- Current owner, `CashWon` → passes the same common owner gate, is recorded, and the ticket is burned before the quote-token-delivery branch (`target/packages/contracts/src/Raffle.sol:L320-L325`, `L338-L343`). ✓
- Prior owner or approved operator after a transfer → `ERC721._update` has already replaced `_owners[ticketId]` with the transferee; redemption reads that address, and the direct equality check rejects any different caller (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`; `target/packages/contracts/src/Raffle.sol:L320-L321`). ✓
- Permissionless standalone settlement → `settleWinningTicket` only calls the private settlement helper and does not perform redemption (`target/packages/contracts/src/Raffle.sol:L303-L306`, `L533-L558`). A settler gains no redemption authority; the later redemption call still reaches the owner gate (`target/packages/contracts/src/Raffle.sol:L314-L321`). ✓
- Both outward-delivery branches occur after the same owner gate; neither branch has an alternate entry around it (`target/packages/contracts/src/Raffle.sol:L320-L345`). ✓

---

**Searched:**

- Complete allowed code surface → read all five production files and every one of the 31 files named by `target/dependency-hashes.json` in full; 31 hashes checked, 0 mismatches.
- `redeemWinningTicket` across the 36-file production/dependency surface → 2 hits: the interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L338` and the implementation at `target/packages/contracts/src/Raffle.sol:L309`; 0 caller or wrapper invocations.
- `ownerOf(ticketId)|NotTicketOwner|msg.sender != winner` across the same surface → 5 hits: the decisive lookup/comparison at `target/packages/contracts/src/Raffle.sol:L320-L321`, the error declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L274`, and the separate refund ownership checks at `target/packages/contracts/src/Raffle.sol:L359-L360`.
- `function ownerOf|function _ownerOf|function _requireOwned|_owners[tokenId]` across the same surface → 6 hits, all in `IERC721.sol` or `ERC721.sol`: declaration, implementation, ledger read, ledger write, and existence helper (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L39`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61`, `L146-L147`, `L240`, `L426`). No first-party ownership override was found.
- `function _update(` across the same surface → 2 definitions: `Raffle._update` at `target/packages/contracts/src/Raffle.sol:L497` and `ERC721._update` at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216`.
- `settleWinningTicket|_settleWinningTicket` across the same surface → 5 hits: interface declaration, external implementation, its call, redemption's call, and the private helper (`target/packages/contracts/src/interfaces/IRaffle.sol:L331`; `target/packages/contracts/src/Raffle.sol:L304-L305`, `L315`, `L533`).
- `approv|operator|auth` within the complete redemption body at `target/packages/contracts/src/Raffle.sol:L309-L346` → 0 hits. Redemption does not extend access to ERC-721-approved callers.
- `transfer|call{|safeTransfer|.call|delegatecall|staticcall` before the owner read, within `target/packages/contracts/src/Raffle.sol:L309-L320` → 0 hits. The unsettled branch's private callees were read separately through `_settleWinningTicket` and `_requireWinningTicket` (`target/packages/contracts/src/Raffle.sol:L533-L558`, `L579-L585`).
- Redemption/claim/release-like production function signatures → the only winning-ticket redemption signature is `redeemWinningTicket` (`target/packages/contracts/src/Raffle.sol:L309`; `target/packages/contracts/src/interfaces/IRaffle.sol:L338`). The other matches are sponsor/protocol release functions with fixed destinations, not ticket-redemption wrappers (`target/packages/contracts/src/Raffle.sol:L374-L407`).
- Modifier/base/constructor/type review → redemption is `external nonReentrant` on a contract inheriting `ERC721` and `ReentrancyGuard` (`target/packages/contracts/src/Raffle.sol:L28`, `L309`); the constructors configure the implementation and base contracts but expose no alternate redemption route (`target/packages/contracts/src/Raffle.sol:L151-L166`; `target/packages/contracts/src/RaffleFactory.sol:L65-L92`).

---

**How the verdict was reached:** `implemented`, rather than `partial`, because every executable redemption route—settle-now or already-settled, and NFT or cash—converges on the same live `ownerOf(ticketId)` read and exact `msg.sender` comparison before the outcome branches (`target/packages/contracts/src/Raffle.sol:L309-L345`). It is not `stronger-than-spec`: refusing approved operators is exactly what “requires current ticket owner” demands. Confidence is high because the sole entrypoint, private settlement path, inherited ownership ledger, update/burn path, modifier, constructors, and the full manifest-listed dependency surface were read, and the caller/vocabulary searches found no alternate redemption route.

---

**Open questions:**

- None for the supplied checkable access-control predicate.
