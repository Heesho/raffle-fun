## REQ-11 — one purchase mints one transferable inclusive-range ticket

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The quoted requirement demands that each successful purchase create one ERC-721 token and associate that token with both endpoints of one gap-free, inclusive entry interval. The supplied checkable criterion is: "Each ticket stores or deterministically identifies the entry-range endpoints represented by that ticket." Concretely, for the pre-purchase sold-entry total `T` and positive purchase quantity `N`, the new ticket must identify `[T + 1, T + N]`; its range must remain associated with the same token ID when ERC-721 ownership changes.

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

- A zero-sized interval is rejected, and the explicit `uint128` headroom check makes both endpoint additions safe on every successful path (`target/packages/contracts/src/Raffle.sol:L218-L227`). If the old `totalEntries` is `T` and `entryCount` is `N`, these assignments produce `firstEntry = T + 1` and `lastEntry = T + N`; because `N > 0`, the inclusive interval is nonempty and has exactly `lastEntry - firstEntry + 1 = N` entries (`target/packages/contracts/src/Raffle.sol:L218-L227`).
- The function advances `totalEntries` to the new last endpoint, advances the sequential ticket counter once, stores both endpoints under the new ticket ID once, and invokes `_safeMint` once (`target/packages/contracts/src/Raffle.sol:L228-L235`). Therefore the next successful purchase starts at the prior range's `lastEntry + 1` (`target/packages/contracts/src/Raffle.sol:L226-L232`).

```solidity
// target/packages/contracts/src/Raffle.sol:L33-L39
    /// @notice Inclusive global entry-number range represented by one sequential ERC-721 ticket.
    /// @param firstEntry First represented one-based global entry.
    /// @param lastEntry Last represented one-based global entry.
    struct TicketRange {
        uint128 firstEntry;
        uint128 lastEntry;
    }

// target/packages/contracts/src/Raffle.sol:L138-L139
    /// @dev Historical ticket ranges remain stored after burns so indexers and callers can reconstruct entry coverage.
    mapping(uint256 ticketId => TicketRange range) private _ticketRanges;

// target/packages/contracts/src/Raffle.sol:L451-L455
    function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
        TicketRange storage range = _ticketRanges[ticketId];
        firstEntry = range.firstEntry;
        lastEntry = range.lastEntry;
    }
```

- The representation is two `uint128` endpoints stored in `_ticketRanges[ticketId]`, and `ticketRange` returns those exact fields (`target/packages/contracts/src/Raffle.sol:L33-L39`, `L138-L139`, `L451-L455`).
- The two consumers use inclusive semantics rather than merely carrying suggestive names: refund accounting computes `lastEntry - firstEntry + 1` (`target/packages/contracts/src/Raffle.sol:L362-L364`), and winner proof accepts both endpoints by rejecting only values strictly below the first or strictly above the last (`target/packages/contracts/src/Raffle.sol:L577-L584`).

```solidity
// target/packages/contracts/src/Raffle.sol:L28
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
```

- `Raffle` actually inherits the inspected OpenZeppelin `ERC721` implementation, and that base reports the `IERC721` interface ID (`target/packages/contracts/src/Raffle.sol:L28`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
    }
```

- The callee behind `_safeMint` was followed: it reaches `_mint`, rejects a zero recipient, requires the token ID to have had no previous owner, and records ownership through the virtual `_update` chain before applying the contract-recipient acceptance check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`). The receiver utility calls `onERC721Received` only for a code-bearing recipient and reverts for an invalid selector or failed empty-reason call (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

// target/packages/contracts/src/Raffle.sol:L497-L502
    function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
        if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
            revert UnsafeProtocolDestination(to);
        }
        previousOwner = super._update(to, ticketId, auth);
    }
```

- Both ordinary and safe transfer entrypoints reach the raffle override, which rejects only its enumerated protocol destinations and otherwise delegates to the parent update (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`; `target/packages/contracts/src/Raffle.sol:L497-L502`, `L593-L604`). The parent update checks owner/operator authorization, clears the prior approval, adjusts balances, writes `_owners[tokenId] = to`, and emits `Transfer` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L244`). It never receives or mutates a range endpoint; the only `_ticketRanges` write in the complete scoped corpus is the purchase assignment at `Raffle.sol:L232`, while its only direct read is the getter at `Raffle.sol:L452`.
- Single-token and all-token approval entrypoints feed that authorization path (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L111`, `L164-L187`). Thus ownership can change while the ticket ID continues to resolve to the same stored endpoints (`target/packages/contracts/src/Raffle.sol:L451-L455`).

---

**Paths walked:**

- Deployment/constructor path: `RaffleFactory.constructor` deploys one `Raffle` implementation and records it (`target/packages/contracts/src/RaffleFactory.sol:L89-L91`); the `Raffle` constructor invokes the ERC-721 base constructor and fixes its immutable dependencies (`target/packages/contracts/src/Raffle.sol:L155-L166`). `createRaffle` embeds that implementation in the clone, initializes the fresh clone, and does not supply or alter ticket counters or ranges (`target/packages/contracts/src/RaffleFactory.sol:L105-L121`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62`; `target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- Successful purchase path: `buyEntries` passes the Active/status, time, recipient, positive-count, and `uint128`-headroom gates; performs the quote-token call; derives both endpoints and one sequential ticket ID; commits the counters and mapping; then calls `_safeMint` exactly once (`target/packages/contracts/src/Raffle.sol:L209-L236`). ✓
- Reentrant purchase path through either the quote token or a ticket receiver: `buyEntries` has `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L209-L213`); the modifier checks and sets the shared guard before the body and restores it afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`). A nested protected purchase cannot add another ticket to the same successful top-level purchase. ✓
- EOA recipient branch: `_safeMint` records the new owner, and `ERC721Utils` skips the receiver call when `to.code.length == 0` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Contract recipient branch: the same mapping write and mint occur before `checkOnERC721Received`; an accepting callback leaves that one ticket live, while an invalid selector or rejected callback reverts rather than producing a successful purchase without an accepted ERC-721 (`target/packages/contracts/src/Raffle.sol:L230-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L287-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Direct and safe transfer branches: owner or approved-operator authorization reaches `Raffle._update`, then the parent ownership-ledger update; the safe branch additionally checks a contract receiver (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L164-L187`, `L216-L244`; `target/packages/contracts/src/Raffle.sol:L497-L502`). Neither branch changes `_ticketRanges` (`target/packages/contracts/src/Raffle.sol:L138-L139`, `L451-L455`). ✓
- Protocol-destination branch: mint or transfer to `address(this)`, the factory, quote token, wrapper, prize token, implementation, or another registered same-factory raffle reverts before `super._update`; every other destination reaches the ordinary ERC-721 update (`target/packages/contracts/src/Raffle.sol:L497-L502`, `L593-L604`). This restriction does not remove the ticket's transfer path. ✓
- Consumption branches: refund reads the stored endpoints, counts the inclusive range, and then burns the ticket (`target/packages/contracts/src/Raffle.sol:L356-L365`); winning settlement reads the same endpoints and uses inclusive containment (`target/packages/contracts/src/Raffle.sol:L577-L584`). The inherited burn removes ownership through `_update(address(0), ...)` but does not receive the range mapping (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307`; `target/packages/contracts/src/Raffle.sol:L497-L502`). ✓
- Failure branches: invalid status, closed sale, zero recipient, zero count, and insufficient `uint128` headroom all revert before endpoint storage or mint (`target/packages/contracts/src/Raffle.sol:L215-L220`). The SafeERC20 wrapper reverts when its transfer-from call is not accepted (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46`, `L212-L243`), and duplicate-token or receiver-rejection paths revert inside the mint chain (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). None is a successful purchase missing its range ticket. ✓

---

**Searched:**

- Scoped file enumeration → exactly 5 production Solidity files under `target/packages/contracts/src` and exactly 31 Solidity dependencies under `target/packages/contracts/node_modules`; all 31 dependency bytes matched `target/dependency-hashes.json` (`shasum -a 256 -c`: 31 `OK`). All 36 files were read in full.
- `\b(TicketRange|ticketRange|_ticketRanges)\b` across all 36 scoped files → 8 hits: `Raffle.sol:L36`, `L139`, `L232`, `L362`, `L451`, `L452`, `L580`; `IRaffle.sol:L373`.
- `\b(firstEntry|lastEntry|entryCount|totalEntries|ticketCount)\b` across all 36 scoped files → 50 hits; the executable endpoint construction/storage cluster is `Raffle.sol:L218-L236`, retrieval is `L451-L455`, inclusive consumers are `L362-L364` and `L580-L584`, and the remaining hits are declarations, events, getters, or uses of the resulting totals.
- `\b(range|interval|span|endpoint|bounds?)\b` across all 36 scoped files → 35 hits; 17 are the relevant `Raffle.sol`/`IRaffle.sol` range semantics and 18 are unrelated generic library bounds/interval references.
- `\bbuyEntries\s*\(` across all 36 scoped files → 2 hits: the external implementation at `Raffle.sol:L209` and interface declaration at `IRaffle.sol:L314`; no in-scope wrapper or caller provides an alternate purchase path.
- `\b(_safeMint|_mint)\s*\(` across all 36 scoped files → 6 hits: the sole application call at `Raffle.sol:L235` and the complete overload/call chain at `ERC721.sol:L259`, `L279`, `L280`, `L287`, `L288`.
- Writer search `\b(totalEntries|ticketCount)\s*(=(?!=)|\+=|-=|\+\+|--)|\+\+\s*(totalEntries|ticketCount)|--\s*(totalEntries|ticketCount)` → exactly 2 hits, both in the purchase path: `Raffle.sol:L230-L231`.
- Mutation search `delete\s+_ticketRanges|_ticketRanges\s*=|_ticketRanges\[[^]]+\]\s*=` → exactly 1 hit, the range assignment at `Raffle.sol:L232`; no delete, replacement mapping assignment, transfer-time rewrite, or burn-time rewrite was found. Direct access search `_ticketRanges\[` → exactly 2 hits: that write at `L232` and the getter read at `L452`.
- ERC-721 transfer-surface search `function (transferFrom|safeTransferFrom|approve|setApprovalForAll|_update)\b` limited to `Raffle.sol` plus its `ERC721.sol` base → 7 hits: the raffle override at `Raffle.sol:L497` and the base approval/transfer/update functions at `ERC721.sol:L93`, `L105`, `L115`, `L128`, `L133`, `L216`.
- Construction/inheritance search `contract Raffle\b|ERC721\("", ""\)|Clones\.clone\b|new Raffle\b|contract ERC721\b` → 5 hits: `Raffle.sol:L28`, `L156`; `RaffleFactory.sol:L89`, `L106`; `ERC721.sol:L19`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every successful branch of the only purchase entrypoint computes and stores both endpoints before its single mint, while every examined failure branch reverts instead of returning a ticket without a range (`target/packages/contracts/src/Raffle.sol:L209-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`). The EOA and contract-recipient branches differ only in receiver acceptance after the same storage/mint path, and both direct and safe ownership transfers preserve the ticket-ID-to-range mapping (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`; `target/packages/contracts/src/Raffle.sol:L451-L455`, `L497-L502`). It is not merely nominal ERC-721 evidence: the inherited interface support, mint implementation, authorization checks, ownership writes, approvals, and transfer entrypoints were read through their callees (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50`, `L93-L135`, `L164-L187`, `L216-L290`). The protocol-destination screen narrows unsafe recipients but still delegates allowed transfers to the full ERC-721 ledger path, so it does not contradict the quoted statement that the ticket is transferable (`target/packages/contracts/src/Raffle.sol:L497-L502`, `L593-L604`). The implementation does not impose a tighter range than the quoted requirement; it realizes exactly the positive contiguous inclusive interval determined by the purchase quantity, so `stronger-than-spec` is not the better category (`target/packages/contracts/src/Raffle.sol:L218-L232`).

---

**Open questions:**

- None.
