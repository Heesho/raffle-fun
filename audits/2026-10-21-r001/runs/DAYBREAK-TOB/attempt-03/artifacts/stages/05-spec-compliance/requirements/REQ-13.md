## REQ-13 — one purchase mints one inclusive range ticket

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A successfully completed purchase must create exactly one ERC-721
token whose stored entry interval is gap-free and includes both its first and last entry. Concretely, if `T` is
the sold-entry total before a purchase of positive count `n`, that ticket must represent every integer in
`[T + 1, T + n]`; its inclusive cardinality must therefore be `(T + n) - (T + 1) + 1 = n`. Moving the ERC-721
must move the claim without changing that stored interval.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L235
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
```

- `entryCount` is a `uint128`, zero is rejected, and a purchase that would make the `uint128` global endpoint
  overflow is rejected before either endpoint is computed (`Raffle.sol:L209-L220`). Thus, on every returning path,
  `firstEntry = T + 1`, `lastEntry = T + n`, and `n >= 1` (`Raffle.sol:L218-L227`). The interval is nonempty and
  its inclusive size is exactly `n`.
- The prior total is replaced by `lastEntry`, the ticket counter advances once, one range record is written, and
  one `_safeMint` call is made (`Raffle.sol:L228-L235`). Consequently the next returning purchase starts at the
  preceding ticket's `lastEntry + 1` (`Raffle.sol:L226-L232`).
- `totalEntries` and `ticketCount` are both `uint128` (`Raffle.sol:L84-L88`). Because their only mutations are the
  same purchase's `+ entryCount` and `+ 1`, and every returning purchase has `entryCount >= 1`, `ticketCount` cannot
  exceed `totalEntries` (`Raffle.sol:L218-L232`). The endpoint guard therefore also establishes
  `ticketCount <= type(uint128).max - 1` before the increment, so the new `ticketId` and `++ticketCount` cannot wrap
  (`Raffle.sol:L219-L231`).
- The range record has two `uint128` endpoints and is keyed by the ERC-721 token ID
  (`Raffle.sol:L33-L39,L138-L139`). Its getter returns those exact stored endpoints without transforming them
  (`Raffle.sol:L451-L455`).

The mint is enforcement rather than a promising name. `Raffle` inherits OpenZeppelin `ERC721`
(`Raffle.sol:L28`), and that base reports support for the `IERC721` and metadata interface IDs
(`ERC721.sol:L44-L50`). The called implementation is:

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

The virtual `_update` reached by `_mint` increments the recipient balance, writes `_owners[tokenId] = to`, and
emits the ERC-721 `Transfer` event (`ERC721.sol:L216-L245`). For a contract recipient, the safe-mint check either
obtains the receiver selector or reverts; EOAs take the no-callback branch (`ERC721Utils.sol:L25-L48`). Therefore
a purchase whose recipient cannot accept the ERC-721 does not return as a completed purchase.

Transferability is supplied by the inherited approval and transfer surface: `approve` and `setApprovalForAll`
are available (`ERC721.sol:L92-L111`), `transferFrom` invokes the authorization-aware `_update`, and both
`safeTransferFrom` overloads reach it, with the data overload additionally checking contract-recipient acceptance
(`ERC721.sol:L114-L135`). Authorization accepts the owner, an all-token operator, or the token-specific approved
address (`ERC721.sol:L157-L187`). `Raffle` overrides only the shared update hook:

```solidity
// target/packages/contracts/src/Raffle.sol:L491-L502
function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    previousOwner = super._update(to, ticketId, auth);
}
```

This hook applies a protocol-destination screen and otherwise delegates ownership movement to the
ERC-721 base (`Raffle.sol:L491-L502`). It does not write `_ticketRanges`; the sole range write is the purchase
assignment at `Raffle.sol:L232`. A transferred ticket therefore retains the same represented interval.

Both consumers of entry membership independently enforce inclusive endpoints:

```solidity
// target/packages/contracts/src/Raffle.sol:L362-L364
(uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
_burn(ticketId);

// target/packages/contracts/src/Raffle.sol:L580-L584
(uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
uint128 selectedEntry = winningEntry;
if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
    revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
}
```

Refund cardinality adds one after subtracting the endpoints, so both endpoints are counted
(`Raffle.sol:L362-L364`). Winning-ticket validation rejects only values strictly below the first endpoint or
strictly above the last endpoint, so equality with either endpoint is accepted (`Raffle.sol:L577-L584`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → `ERC721` base: the factory fixes one Raffle implementation
  (`RaffleFactory.sol:L85-L91`); `Raffle` inherits `ERC721` and invokes its constructor
  (`Raffle.sol:L28,L155-L166`). `createRaffle` deploys a fixed-target clone and initializes it before prize
  activation (`RaffleFactory.sol:L97-L134`). This is the implementation on which the purchase path executes. ✓
- `buyEntries` guard branches: wrong status, sale ended, zero recipient, zero count, and endpoint overflow all
  revert before the range write and mint (`Raffle.sol:L209-L220`). There is no branch around the arithmetic,
  range assignment, counter increment, or `_safeMint` on a returning call (`Raffle.sol:L223-L236`). ✓
- `buyEntries` → `SafeERC20.safeTransferFrom`: the quote-token call occurs before range creation
  (`Raffle.sol:L223-L227`); its wrapper reverts when the underlying transfer call is not accepted
  (`SafeERC20.sol:L39-L47,L212-L243`). A failed payment path cannot become a completed range-ticket purchase. ✓
- `buyEntries` → `nonReentrant`: the modifier enters before the function body and exits afterward
  (`ReentrancyGuard.sol:L69-L73,L88-L106`), so callbacks from the quote token or ticket receiver cannot enter a
  second guarded purchase while the first is in flight. Although a clone does not execute the implementation's
  guard constructor, an initial zero slot is not `ENTERED`; the first call accepts it and writes `ENTERED` before
  the body (`ReentrancyGuard.sol:L35-L60,L88-L100`; `RaffleFactory.sol:L105-L110`). ✓
- `_safeMint` → `_mint` → `Raffle._update` → `ERC721._update`: a fresh token ID receives one owner/balance update
  and one ERC-721 `Transfer` event (`ERC721.sol:L216-L245,L259-L289`; `Raffle.sol:L497-L502`). For a contract
  recipient, receiver rejection reverts rather than leaving a returning purchase without an accepted ticket
  (`ERC721Utils.sol:L25-L48`). ✓
- `transferFrom` and both `safeTransferFrom` overloads → `Raffle._update` → `ERC721._update`: owner/operator
  authorization is checked, the live owner changes, and the range mapping is untouched
  (`ERC721.sol:L114-L135,L157-L187,L216-L245`; `Raffle.sol:L497-L502`). The same transfer surface is available in
  every raffle lifecycle state because the only Raffle transfer hook checks the destination, not `status`
  (`Raffle.sol:L491-L502`). ✓
- `refundTickets` → `ticketRange`: `ownerOf` first excludes nonexistent or already-burned IDs, then the refund uses
  `lastEntry - firstEntry + 1` (`Raffle.sol:L356-L365`; `ERC721.sol:L60-L63,L426-L432`). Both endpoints contribute
  one entry. ✓
- `settleWinningTicket` / `redeemWinningTicket` → `_settleWinningTicket` → `_requireWinningTicket`: both public
  settlement routes converge on the same strict-outside range test (`Raffle.sol:L303-L318,L533-L539,L577-L584`).
  A winning entry equal to either endpoint passes. ✓
- Burn paths call the ERC-721 ownership update but do not delete the historical range
  (`Raffle.sol:L138-L139,L323-L325,L362-L365`; `ERC721.sol:L292-L308`). This does not create an alternate range or
  change what the ticket represented while live. ✓

---

**Searched:**

- `function buyEntries|buyEntries\(` across all five production files and all 31 dependency files → 2 hits:
  `Raffle.sol:L209` (the only implementation/entrypoint) and `IRaffle.sol:L314` (its declaration); no wrapper or
  in-scope caller.
- `\b(_safeMint|_mint)\s*\(` in production plus `ERC721.sol` → 6 hits: the sole production call at
  `Raffle.sol:L235`, the two base declarations at `ERC721.sol:L259,L279`, the forwarding call at L280, the
  data-overload declaration at L287, and its `_mint` call at L288. No second production mint path.
- `_ticketRanges` in production → 3 hits: declaration at `Raffle.sol:L139`, sole write at L232, and getter read at
  L452. `TicketRange`, `_ticketRanges`, `buyEntries`, `entryCount`, `firstEntry`, and `lastEntry` each produced 0
  hits across the 31 dependencies.
- Writer sweep `totalEntries = | ticketCount = | ++ticketCount | _ticketRanges[...] =` → exactly the three purchase
  mutations at `Raffle.sol:L230-L232`; `ticketCount =` had 0 hits and `++ticketCount` had 1. Equality checks were
  excluded from this writer search.
- Endpoint-consumption sweep `firstEntry = | lastEntry = | lastEntry\) - uint256\(firstEntry\) \+ 1 |
  selectedEntry < firstEntry | selectedEntry > lastEntry` → computations at `Raffle.sol:L226-L227`, inclusive
  refund arithmetic at L363, getter reads at L453-L454, and the strict-outside winner test at L582.
- Vocabulary sweep in production: `contigu` → 0 hits, `interval` → 0 hits, `inclusive` → 12 hits, `sequential` → 8
  hits, `range` → 30 hits. The verdict rests on the arithmetic and consumers above, not those names or comments.
- ERC-721 transfer/approval declaration sweep in `ERC721.sol` → 5 public hits: `approve` L93,
  `setApprovalForAll` L105, `transferFrom` L115, and the two `safeTransferFrom` overloads L128 and L133. The
  helper sweep also reached `_isAuthorized` L164, `_checkAuthorized` L179, `_update` L216, `_mint` L259, and both
  `_safeMint` overloads L279 and L287.
- `dependency-hashes.json` → 31 dependency entries. SHA-256 recomputation returned 31 matches and 0 mismatches;
  all 31 files were read. The directly reached base/modifier chain is `ERC721`/`IERC721`/`IERC721Metadata`/
  `IERC721Receiver`/`ERC721Utils`/`Context`/`ERC165`/`IERC165`/`draft-IERC6093` plus
  `ReentrancyGuard`/`StorageSlot`; no dependency owns a raffle-range identifier, writer, or alternate purchase
  entrypoint.

---

**How the verdict was reached:** The purchase formulas establish `[T + 1,T + n]` for every positive bounded
`n`, store it once under the one newly assigned ticket ID, and invoke exactly one read-through safe ERC-721 mint
(`Raffle.sol:L209-L235`). The two semantics-bearing consumers confirm inclusivity rather than merely naming it:
refunds count `last - first + 1`, and winner containment permits equality at both ends
(`Raffle.sol:L362-L364,L577-L584`). Inherited ERC-721 ownership and approval paths make the token transferable,
while Raffle's update hook preserves the range (`ERC721.sol:L92-L135,L157-L187,L216-L245`;
`Raffle.sol:L491-L502`).

This is `implemented`, not `partial`, because every branch that omits range creation or minting reverts and no
alternate successful purchase path exists (`Raffle.sol:L209-L236`). It is not `contradicted`: both endpoint
consumers use inclusive comparisons/arithmetic. The rejection of known protocol destinations does not negate
transferability—ordinary owner/approved transfers remain exposed—and it does not strengthen the endpoint
invariant being checked (`Raffle.sol:L491-L502`; `ERC721.sol:L92-L135`).

---

**Open questions:**

None for this requirement.
