## REQ-12 — one purchase produces one transferable contiguous range ticket

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The quoted requirement demands that each successfully completed purchase create exactly one ERC-721 ticket, that the ticket's represented entries be every integer from its first endpoint through its last endpoint (both included), and that ERC-721 ownership of that same ticket can later move. A reverting attempt is not a completed purchase.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L218-L236
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}

uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;

_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```

- `entryCount` must be positive and must fit when added to the `uint128 totalEntries`; therefore `firstEntry = oldTotalEntries + 1`, `lastEntry = oldTotalEntries + entryCount`, and `lastEntry - firstEntry + 1 = entryCount` on every successful purchase (`target/packages/contracts/src/Raffle.sol:L85`, `L209-L220`, `L226-L232`). The next purchase starts at the preceding `lastEntry + 1` because `totalEntries` is set to the current `lastEntry` (`target/packages/contracts/src/Raffle.sol:L226-L232`).
- The function performs one `_ticketRanges[ticketId]` assignment and one `_safeMint(recipient, ticketId)` call, with no branch around either operation (`target/packages/contracts/src/Raffle.sol:L226-L236`).

`Raffle` inherits the concrete OpenZeppelin `ERC721` implementation (`target/packages/contracts/src/Raffle.sol:L28`). The mint name is backed by the following implementation:

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289
function _mint(address to, uint256 tokenId) internal {
    if (to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    address previousOwner = _update(to, tokenId, address(0));
    if (previousOwner != address(0)) {
        revert ERC721InvalidSender(address(0));
    }
}

function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
    _mint(to, tokenId);
    ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
}
```

The virtual `_update` dispatch first reaches `Raffle._update`, which screens known protocol destinations and then delegates to `super._update` (`target/packages/contracts/src/Raffle.sol:L491-L502`). The base implementation checks authorization when requested, adjusts the old and new owners' balances, writes `_owners[tokenId] = to`, and emits `Transfer(from, to, tokenId)` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`). During mint, `_mint` also requires that the prior owner was zero, so the call creates one new ERC-721 ownership record rather than overwriting an existing token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L267`). A contract recipient must accept the safe mint or the call reverts (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L287-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`).

The stored endpoints are returned unchanged, and both consumers interpret them as a fully populated inclusive interval:

```solidity
// target/packages/contracts/src/Raffle.sol:L451-L455
function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
    TicketRange storage range = _ticketRanges[ticketId];
    firstEntry = range.firstEntry;
    lastEntry = range.lastEntry;
}

// target/packages/contracts/src/Raffle.sol:L579-L584
function _requireWinningTicket(uint256 ticketId) private view {
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    uint128 selectedEntry = winningEntry;
    if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
        revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
    }
}
```

The winner check rejects only values below `firstEntry` or above `lastEntry`, so every integer between the endpoints, including both endpoints, is accepted as belonging to the ticket (`target/packages/contracts/src/Raffle.sol:L579-L584`). The refund path independently counts the represented entries as `lastEntry - firstEntry + 1`, the cardinality of that same inclusive interval (`target/packages/contracts/src/Raffle.sol:L349-L369`).

Transferability is implemented by inherited ERC-721 entrypoints. `transferFrom` sends the same `tokenId` through virtual `_update` after caller authorization, and both safe-transfer overloads add recipient acceptance without changing the token ID (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`, `L157-L187`; `target/packages/contracts/src/Raffle.sol:L497-L502`). Approvals and operator approvals are also exposed by the inherited implementation (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L112`). No transfer path writes `_ticketRanges`, so moving ownership preserves the token ID's stored endpoints (`target/packages/contracts/src/Raffle.sol:L139`, `L232`, `L451-L455`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` fixes the concrete implementation, and `createRaffle` → `Clones.clone` → `Raffle.initialize` creates and initializes the fresh clone before prize escrow activates it (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`, `L97-L134`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`; `target/packages/contracts/src/Raffle.sol:L176-L205`, `L416-L430`). `buyEntries` first requires `Active`, so the locked implementation and inactive clones cannot reach range creation (`target/packages/contracts/src/Raffle.sol:L155-L166`, `L209-L216`).
- `buyEntries` failure branches: wrong status, ended sale, zero recipient, zero count, or a `uint128` total overflow all revert before any range or mint write (`target/packages/contracts/src/Raffle.sol:L209-L221`). A failed quote-token call also reverts before those writes (`target/packages/contracts/src/Raffle.sol:L223-L224`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L47`, `L212-L244`).
- `buyEntries` success branch: payment returns, the endpoints and sequential ticket ID are computed, the new total/count/range are stored, and the sole production `_safeMint` call executes (`target/packages/contracts/src/Raffle.sol:L223-L236`). There is no success return before the range write or mint.
- `_safeMint` → `_mint` → `Raffle._update` → `ERC721._update`: an unsafe destination, an already-owned ID, or a rejecting contract recipient reverts; otherwise one ownership record for the computed `ticketId` is created (`target/packages/contracts/src/Raffle.sol:L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L267`, `L279-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`).
- `nonReentrant` wraps `buyEntries`; it marks the guard entered before the function body and restores it afterward, so quote-token or receiver callbacks cannot successfully enter a second `buyEntries` while the first is executing (`target/packages/contracts/src/Raffle.sol:L209-L213`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`). A receiver may use the unguarded inherited ERC-721 transfer entrypoints during its callback, but such a transfer moves the already minted `ticketId` through `_update` and does not alter its range (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`; `target/packages/contracts/src/Raffle.sol:L139`, `L232`, `L497-L502`).
- `transferFrom` / `safeTransferFrom` → `Raffle._update` → `ERC721._update`: owner or approved-operator authority is checked, the owner ledger for the same token ID changes, and the range mapping is untouched (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`, `L157-L187`, `L216-L245`; `target/packages/contracts/src/Raffle.sol:L497-L502`).
- `settleWinningTicket` → `_settleWinningTicket` → `_requireWinningTicket` → `ticketRange` applies the inclusive containment comparison to the stored endpoints (`target/packages/contracts/src/Raffle.sol:L303-L306`, `L533-L538`, `L577-L584`, `L451-L455`). `refundTickets` → `ticketRange` uses inclusive interval length before burning the claim (`target/packages/contracts/src/Raffle.sol:L349-L369`). The two burn call sites consume a winning or refunded ticket but do not delete or rewrite its historical range (`target/packages/contracts/src/Raffle.sol:L309-L345`, `L349-L369`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L292-L308`).
- Callers and wrappers: `buyEntries(` has two in-scope hits—the external implementation and its interface declaration—so no production wrapper introduces an alternate purchase branch (`target/packages/contracts/src/Raffle.sol:L209-L237`; `target/packages/contracts/src/interfaces/IRaffle.sol:L310-L314`).

---

**Searched:**

- Frozen scope → read all five first-party production files and all 31 files named by `target/dependency-hashes.json`; recomputed SHA-256 values matched 31/31 manifest entries.
- `_ticketRanges` → 3 hits: declaration at `target/packages/contracts/src/Raffle.sol:L139`, sole assignment at `L232`, and getter read at `L452`; no delete or second assignment.
- `\b(firstEntry|lastEntry|entryCount|totalEntries|ticketCount)\b` → 50 hits across the exact scope; operative range construction is at `target/packages/contracts/src/Raffle.sol:L218-L232`, inclusive refund counting at `L362-L363`, and containment at `L580-L583`.
- `\b(_safeMint|_mint)\s*\(` → 6 hits: the only production call is `target/packages/contracts/src/Raffle.sol:L235`; the other five are OpenZeppelin definitions/delegation at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289`.
- `function (safeTransferFrom|transferFrom|approve|setApprovalForAll)` plus `function _update` → 17 hits; the relevant concrete ERC-721 entrypoints are `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L135`, its base update is `L216-L245`, and the only application override is `target/packages/contracts/src/Raffle.sol:L497-L502`.
- `buyEntries\s*\(` → 2 hits: implementation at `target/packages/contracts/src/Raffle.sol:L209` and interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L314`; no in-scope caller or wrapper.
- `(?i)\b(contiguous|inclusive|range|ranges|gap|gaps|interval|coverage)\b` → 28 hits; relevant implementation/interface hits describe or consume the stored range at `target/packages/contracts/src/Raffle.sol:L22-L39`, `L138-L139`, `L451-L455`, `L528-L531`, `L577-L584`, and `target/packages/contracts/src/interfaces/IRaffle.sol:L10-L15`, `L64-L80`, `L310-L314`, `L368-L373`; remaining hits are unrelated utility prose.
- `_owners[`, `_ownerOf`, and `ownerOf` → 5 hits; the concrete ownership read and sole ledger write are in `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63`, `L146-L148`, and `L240`.
- `_burn(` or `delete _ticketRanges` → 3 hits: the inherited burn definition and the redemption/refund calls; `delete _ticketRanges` returned 0 hits (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307`; `target/packages/contracts/src/Raffle.sol:L325`, `L364`).

---

**How the verdict was reached:** This is `implemented`, not merely suggested by names. On every successfully returning `buyEntries` path, a positive, bounded count produces endpoints whose inclusive cardinality equals the purchased count, one mapping entry is stored, and one concrete ERC-721 safe mint executes (`target/packages/contracts/src/Raffle.sol:L218-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`). The only implementation-side interpretations of membership use inclusive endpoint comparison or inclusive interval cardinality, so there is no representable hole between the endpoints (`target/packages/contracts/src/Raffle.sol:L362-L363`, `L579-L584`). The inherited authorized transfer paths move the same token ID while the range remains keyed to that ID (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`, `L216-L245`; `target/packages/contracts/src/Raffle.sol:L139`, `L232`, `L451-L455`, `L497-L502`). It is not `partial` because every precondition or downstream failure reverts rather than returning a purchase without the range or ticket, and no alternate production purchase path exists. The protocol-destination screen narrows unsafe recipients but does not remove the ERC-721 ownership-transfer mechanism or change the represented interval (`target/packages/contracts/src/Raffle.sol:L497-L502`, `L593-L604`).

---

**Open questions:** None for this requirement. The range arithmetic, storage, mint, ownership, transfer, receiver, modifier, clone, and consuming paths are all present in the frozen source and pinned dependencies.
