## REQ-08 — one transferable range ticket per purchase

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Every successfully returning purchase must create exactly one ERC-721 token. That token ID must be bound to one interval whose endpoints are included, whose represented entry count equals the purchased `entryCount`, and whose entries have no gap within the interval. The resulting token must be movable through ERC-721 owner/operator transfer paths. A rejected or reverted purchase is not a successful purchase, but no path may return successfully after minting zero tickets or more than one ticket.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L236
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
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
}
```

- The only successful body is straight-line after its rejecting gates: it takes payment, assigns one new `ticketId`, writes one `TicketRange`, invokes `_safeMint` exactly once, and then emits the purchase event (`target/packages/contracts/src/Raffle.sol:L209-L236`).
- `entryCount` must be positive and must fit in the remaining `uint128` entry space (`target/packages/contracts/src/Raffle.sol:L218-L221`). With `firstEntry = oldTotal + 1` and `lastEntry = oldTotal + entryCount`, the inclusive length is `lastEntry - firstEntry + 1 = entryCount`; assigning `totalEntries = lastEntry` makes the next successful purchase begin immediately after this one (`target/packages/contracts/src/Raffle.sol:L226-L232`).
- The range is retrievable by the same ticket ID from the sole range mapping (`target/packages/contracts/src/Raffle.sol:L138-L139`, `L451-L455`).
- Its consumers use both endpoints inclusively: refunds count `lastEntry - firstEntry + 1`, while winner validation accepts equality at either endpoint and rejects only values below `firstEntry` or above `lastEntry` (`target/packages/contracts/src/Raffle.sol:L362-L364`, `L579-L584`).

The mint name is backed by the inherited implementation:

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

function _safeMint(address to, uint256 tokenId) internal {
    _safeMint(to, tokenId, "");
}

function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
    _mint(to, tokenId);
    ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
}
```

`Raffle._safeMint` therefore reaches one `_mint`, and `_mint` rejects both a zero recipient and any token ID that already had an owner (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289`). The virtual update passes through the raffle's destination screen and then the concrete ERC-721 ledger update:

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
    if (auth != address(0)) {
        _checkAuthorized(from, auth, tokenId);
    }
    if (from != address(0)) {
        _approve(address(0), tokenId, address(0), false);
        unchecked { _balances[from] -= 1; }
    }
    if (to != address(0)) {
        unchecked { _balances[to] += 1; }
    }
    _owners[tokenId] = to;
    emit Transfer(from, to, tokenId);
    return from;
}
```

On mint, `from` is zero, so the base update increments the recipient's balance, writes the owner, and emits the ERC-721 `Transfer` event before `_mint` verifies that the previous owner was zero (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L267`). `Raffle` inherits this ERC-721 implementation (`target/packages/contracts/src/Raffle.sol:L28`), and the base advertises both the ERC-721 and metadata interface IDs (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50`).

Transferability is implemented rather than merely declared:

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L135
function approve(address to, uint256 tokenId) public virtual {
    _approve(to, tokenId, _msgSender());
}

function setApprovalForAll(address operator, bool approved) public virtual {
    _setApprovalForAll(_msgSender(), operator, approved);
}

function transferFrom(address from, address to, uint256 tokenId) public virtual {
    if (to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    address previousOwner = _update(to, tokenId, _msgSender());
    if (previousOwner != from) {
        revert ERC721IncorrectOwner(from, tokenId, previousOwner);
    }
}

function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
    transferFrom(from, to, tokenId);
    ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
}
```

The public approval, operator, direct-transfer, and safe-transfer methods are inherited by `Raffle` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L135`; `target/packages/contracts/src/Raffle.sol:L28`). Transfer authorization is enforced inside `_update` through `_checkAuthorized` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L186`, `L216-L222`), while the raffle override adds only a destination screen before delegating to that ledger update and has no lifecycle-state branch (`target/packages/contracts/src/Raffle.sol:L491-L502`). The stored range is keyed by `ticketId`, not owner, so an ownership transfer does not alter which inclusive range the token represents (`target/packages/contracts/src/Raffle.sol:L138-L139`, `L451-L455`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`).

---

**Paths walked:**

- Canonical deployment path: the factory constructor deploys one `Raffle` implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`); `createRaffle` creates a fixed-target clone and calls its one-time initializer (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`); initialization leaves it awaiting the prize (`target/packages/contracts/src/Raffle.sol:L176-L205`); the exact prize callback moves it to `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). The implementation contract itself is locked in `Refunding`, and `buyEntries` requires `Active`, so it cannot furnish a separate successful purchase path (`target/packages/contracts/src/Raffle.sol:L155-L166`, `L215-L216`). ✓
- Successful EOA-recipient purchase: `buyEntries` passes the status, time, recipient, positive-count, and type-bound gates; `SafeERC20.safeTransferFrom` must return successfully; the range/counters are written; the single `_safeMint` reaches one owner update; and the receiver utility does nothing when the recipient has no code (`target/packages/contracts/src/Raffle.sol:L209-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46`, `L212-L243`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L49`). ✓
- Successful contract-recipient purchase: the same mint happens before the acceptance callback. A wrong selector, an empty failure, or a bubbled receiver revert makes the call revert; only an accepted callback can return through `buyEntries` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L287-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L47`). The `nonReentrant` modifier is already entered around the whole purchase, so that callback cannot make a nested successful call to another protected `buyEntries` path on this raffle (`target/packages/contracts/src/Raffle.sol:L209-L213`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`). ✓
- Transfer path after mint: an owner or approved operator calls `transferFrom` or either `safeTransferFrom` overload; the call reaches `Raffle._update`, then the base authorization and owner/balance mutation. Safe transfer additionally requires contract-recipient acceptance (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`, `L164-L186`, `L216-L245`; `target/packages/contracts/src/Raffle.sol:L491-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L49`). ✓
- Range-use paths: `refundTickets` derives the represented entry quantity from the stored range with an inclusive `+ 1`, and winning-ticket settlement validates containment against both stored endpoints (`target/packages/contracts/src/Raffle.sol:L349-L369`, `L533-L558`, `L577-L584`). Both consumers therefore interpret the minted token as the same contiguous inclusive interval. ✓
- Rejected purchase branches: inactive/ended sales, zero recipients, zero counts, range overflow, failed quote transfer, unsafe protocol destinations, duplicate token IDs, and rejecting contract recipients all revert before `buyEntries` can return (`target/packages/contracts/src/Raffle.sol:L215-L224`, `L235`; `target/packages/contracts/src/Raffle.sol:L497-L501`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L32-L47`). None is a successful zero-ticket or multi-ticket purchase. ✓

---

**Searched:**

- Full allowed implementation closure → read all five first-party production files and all 31 files named by `target/dependency-hashes.json`; all 31 SHA-256 checks returned `OK`.
- `function buyEntries|buyEntries\(` across those 36 files → 2 hits: the external interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L314` and the implementation definition at `target/packages/contracts/src/Raffle.sol:L209`; no in-scope caller, wrapper, or second purchase implementation.
- Case-insensitive function names containing `buy`, `purchase`, `acquire`, or `mint` across the 36 files → 5 hits: the two `buyEntries` declarations plus the internal `_mint` and two `_safeMint` overloads in `ERC721.sol:L259`, `L279`, and `L287`; no alternative public purchase/mint entrypoint. `mintTicket|createTicket|issueTicket|acquireEntries|purchaseEntries` → 0 hits.
- `_safeMint\(|_mint\(` across the 36 files → 6 hits: the one raffle call at `Raffle.sol:L235`, the three base definitions at `ERC721.sol:L259`, `L279`, and `L287`, and the two calls connecting those overloads at `ERC721.sol:L280` and `L288`. A narrower `_safeMint\(` search → 4 hits, with only `Raffle.sol:L235` outside the base implementation.
- First-party definitions of `_ownerOf`, `_increaseBalance`, `_mint`, or `_safeMint` → 0 hits; the raffle does not replace the inherited mint/ownership machinery. `function _update\(|super._update\(` → 3 hits: the base update at `ERC721.sol:L216` and the raffle override/delegation at `Raffle.sol:L497`, `L501`.
- `_ticketRanges|TicketRange|ticketRange\(` → 8 hits: the struct, mapping, one purchase write, two consumers, the getter definition/read, and the interface declaration (`target/packages/contracts/src/Raffle.sol:L36`, `L139`, `L232`, `L362`, `L451-L452`, `L580`; `target/packages/contracts/src/interfaces/IRaffle.sol:L373`). `TicketPurchased` → 2 hits: its declaration and the single purchase emission (`target/packages/contracts/src/interfaces/IRaffle.sol:L72`; `target/packages/contracts/src/Raffle.sol:L236`).
- Exact state-mutation search for `totalEntries`, `ticketCount`, and `_ticketRanges` → 3 hits, all adjacent in the purchase body at `target/packages/contracts/src/Raffle.sol:L230-L232`; there is no other writer in the allowed closure.
- `function (safeTransferFrom|transferFrom|approve|setApprovalForAll)\(` → 15 declarations across the closure, including the five ERC-721 interface declarations at `IERC721.sol:L55-L118` and all five concrete public ERC-721 methods at `ERC721.sol:L93-L135`; the remaining five hits are ERC-20/Chainlink declarations or `SafeERC20` and do not move tickets.
- `new Raffle\(|Clones.clone\(|function createRaffle\(` in first-party production → 4 hits: the factory interface declaration, factory implementation definition, fixed implementation deployment, and clone creation (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`; `target/packages/contracts/src/RaffleFactory.sol:L89`, `L97`, `L106`). No alternate raffle implementation or construction path was found.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every branch that can return successfully from the sole purchase entrypoint converges on the same one `_safeMint` call, and the actual inherited callee performs exactly one ERC-721 ownership update. Every path that does not reach or complete that mint reverts rather than returning a successful purchase. It is not `contradicted`: the stored endpoint arithmetic makes the ticket's inclusive range exactly `entryCount` entries long and adjacent to the previously sold interval, and the inherited owner/operator transfer functions operate on the same token ID while leaving that range binding unchanged. It is not `stronger-than-spec`: safe-receiver validation and the protocol-destination screen constrain which attempted operations succeed, but a successful purchase still has exactly the documented one ticket, range, and ERC-721 transfer capability; the quoted requirement does not promise successful transfer to every possible address. Confidence is high because the production files, complete hash-pinned dependency closure, modifier, constructor/clone route, mint callees, receiver branch, update override, and inherited transfer methods were all read.

---

**Open questions:** None for this requirement.
