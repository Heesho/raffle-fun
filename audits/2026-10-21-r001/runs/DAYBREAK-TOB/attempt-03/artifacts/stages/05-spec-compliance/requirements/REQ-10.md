## REQ-10 — Transferable ERC721 range ticket per purchase

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A successful purchase must create exactly one ERC721 token ID, bind that token ID to two included endpoints whose interval contains exactly the purchased entries, and expose working ERC721 ownership-transfer paths for the live ticket. Transferring the token must not detach or rewrite its represented range.

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
```

- The positive-count check and the pre-addition `uint128` bound make `firstEntry = prior totalEntries + 1` and `lastEntry = prior totalEntries + entryCount` valid. Thus both endpoints are included, the range length is `lastEntry - firstEntry + 1 == entryCount`, and a later purchase begins immediately after the prior `lastEntry` (`target/packages/contracts/src/Raffle.sol:L218-L232`). There is one range assignment and one `_safeMint` call on the successful purchase path (`target/packages/contracts/src/Raffle.sol:L232-L236`).
- The range getter returns the two stored endpoints without consulting or changing ERC721 ownership (`target/packages/contracts/src/Raffle.sol:L451-L455`).

```solidity
// target/packages/contracts/src/Raffle.sol:L28
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L49
function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
    return
        interfaceId == type(IERC721).interfaceId ||
        interfaceId == type(IERC721Metadata).interfaceId ||
        super.supportsInterface(interfaceId);
}
```

- `Raffle` directly inherits the ERC721 implementation, whose interface detection reports `IERC721` support (`target/packages/contracts/src/Raffle.sol:L28`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L49`). The factory deploys that implementation and creates fixed-target clones from it (`target/packages/contracts/src/RaffleFactory.sol:L85-L91`, `L97-L121`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135
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
```

- The inherited ABI exposes ordinary `transferFrom` and both safe-transfer overloads; both safe overloads converge on the same `transferFrom` ownership update before applying recipient acceptance (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`).

```solidity
// target/packages/contracts/src/Raffle.sol:L497-L502
function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    previousOwner = super._update(to, ticketId, auth);
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245
function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
    address from = _ownerOf(tokenId);

    // Perform (optional) operator check
    if (auth != address(0)) {
        _checkAuthorized(from, auth, tokenId);
    }

    // Execute the update
    if (from != address(0)) {
        // Clear approval. No need to re-authorize or emit the Approval event
        _approve(address(0), tokenId, address(0), false);

        unchecked {
            _balances[from] -= 1;
        }
    }

    if (to != address(0)) {
        unchecked {
            _balances[to] += 1;
        }
    }

    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);

    return from;
}
```

- Every mint, transfer, and burn reaches the raffle override. For a nonzero transfer destination it rejects only the enumerated same-factory protocol destinations, then delegates to the ERC721 ledger; it contains no raffle-status branch (`target/packages/contracts/src/Raffle.sol:L491-L502`, `L593-L604`).
- The base update reads the current owner, checks `auth` when supplied, clears the per-token approval, adjusts the old and new balances, writes `_owners[tokenId] = to`, and emits `Transfer` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`). Authorization accepts the owner, an all-tokens operator, or the token-specific approved address and rejects all other callers (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L153-L186`).
- For safe transfers to code, the receiver must return the ERC721 acceptance selector; a wrong selector, missing implementation, or receiver revert aborts the transfer. An EOA takes the no-callback branch (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → `ERC721` base: the factory fixes the implementation at deployment (`target/packages/contracts/src/RaffleFactory.sol:L85-L91`), and `Raffle` inherits the ERC721 implementation (`target/packages/contracts/src/Raffle.sol:L28`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone` → `Raffle.initialize`: production raffles are fixed-target minimal proxies initialized before prize activation (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- `buyEntries` → range arithmetic/write → `_safeMint`: zero entries and overflowing totals revert; otherwise exactly one sequential ID receives exactly one `[firstEntry,lastEntry]` record and reaches one safe mint (`target/packages/contracts/src/Raffle.sol:L209-L236`). ✓
- `_safeMint` → `_mint` → `Raffle._update` → `ERC721._update`: mint uses `auth == address(0)`, requires the ID to have no prior owner, writes ownership, and then performs the safe-receiver check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`; `target/packages/contracts/src/Raffle.sol:L497-L502`). ✓
- Owner `transferFrom`: a nonzero, non-protocol destination reaches the shared update; owner authorization succeeds, balances and `_owners` change, and the caller-supplied `from` must equal the previous owner (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L125`, `L164-L186`, `L216-L245`; `target/packages/contracts/src/Raffle.sol:L497-L502`). ✓
- Token-approved `transferFrom` and all-tokens-operator `transferFrom`: both authorization alternatives are expressly included in `_isAuthorized` and converge on the same ownership write (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L111`, `L153-L186`, `L216-L245`). ✓
- Three-argument `safeTransferFrom` → four-argument `safeTransferFrom` → `transferFrom`: an EOA recipient needs no callback; a contract recipient must return the selector, and rejection reverts the ownership update (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L127-L135`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Lifecycle branch coverage: all external ERC721 transfer entrypoints use the same raffle `_update`, and that hook has no `Status` test, so an existing ticket is transferable in every raffle lifecycle state. Burns remain allowed because `to == address(0)` bypasses the destination screen; after a burn, the base ERC721 correctly treats the token as nonexistent (`target/packages/contracts/src/Raffle.sol:L491-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307`, `L426-L432`). ✓
- Downstream ownership consumers: winner redemption and refunds both query `ownerOf(ticketId)`, require the caller to be that current owner, and then burn, so a transferred owner—not the original purchaser—holds the live claim (`target/packages/contracts/src/Raffle.sol:L320-L325`, `L356-L365`). ✓
- Range preservation across transfer: ERC721 transfer updates approvals, balances, and `_owners` only (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`); the range remains in the ticket-ID-keyed mapping returned by `ticketRange` (`target/packages/contracts/src/Raffle.sol:L138-L139`, `L451-L455`). ✓

---

**Searched:**

- Scope inventory → all five production files and all 31 paths in `target/dependency-hashes.json` were read in full; an independent SHA-256 comparison returned `31/31 dependency hashes match`.
- `function (transferFrom|safeTransferFrom|approve|setApprovalForAll)\(` across the five production files → 0 hits; the functions are inherited, not re-declared by `Raffle`.
- The same function-declaration pattern across production plus the 31 dependencies → 15 hits: 10 relevant declarations/definitions in `IERC721.sol` and `ERC721.sol`, and 5 unrelated ERC20/LINK declarations.
- `function _update|function _safeMint|function _mint|function _burn` across the same scope → 6 hits: `Raffle._update` plus the five relevant ERC721 base definitions; all six were read.
- `_ticketRanges\s*\[` → 2 hits: the sole write at `Raffle.sol:L232` and the getter read at `Raffle.sol:L452`. Assignment/delete search → 1 assignment and 0 deletes.
- `_safeMint\(` → 4 hits: the purchase call, two overload definitions, and the one-argument overload's delegation. `checkOnERC721Received` → 4 hits: three ERC721 call sites and the utility definition.
- `_isAuthorized|_checkAuthorized|isApprovedForAll|_getApproved` → 12 hits, all confined to the IERC721 declaration and ERC721 authorization implementation/comments; the operative owner/operator/token-approval branches are at `ERC721.sol:L153-L186` and `L216-L221`.
- `nontransferable|non-transferable|soulbound|transferDisabled|transfersDisabled|lockTransfers|pauseTransfers|frozen` → 0 hits across the five production files and 31 dependencies.
- `Status|status|_requireStatus|paused|locked` within the complete `Raffle._update` body → 0 hits; its only pre-delegation branch is the destination screen at `Raffle.sol:L498-L500`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every successful purchase path reaches one range assignment and one safe mint, while every ordinary and safe ERC721 transfer path converges on the same authorization and ownership write. The common raffle hook has no lifecycle branch that disables a transfer, and transfers never modify the ticket-ID-keyed range. Unauthorized callers, zero recipients, known protocol destinations, rejected safe receivers, and already-burned IDs revert; those branches constrain invalid or deliberately screened transfers without removing the required ability for a live ticket's ownership to move. It is not `stronger-than-spec`: the extra protocol-destination screen does not strengthen the claimed property or replace it with a narrower state-machine guarantee; the demanded ERC721 ownership-transfer capability remains present on both ordinary and safe paths.

---

**Open questions:**

- None.
