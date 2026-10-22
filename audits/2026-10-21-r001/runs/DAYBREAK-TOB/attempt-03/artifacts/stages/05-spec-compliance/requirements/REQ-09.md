## REQ-09 — One transferable ERC-721 range ticket per purchase

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — DESIGN.md:L2, sentence 3

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Every successful purchase must create exactly one ERC-721 token. That token's ID must remain associated with one nonempty interval whose endpoints are consecutive global-entry numbers and are both included. While the token exists, ERC-721 ownership, per-token approval, operator approval, authorized transfer, safe transfer, and interface-discovery behavior must apply to it.

---

**Where enforcement lives:**

`Raffle` obtains its ticket ledger and public ERC-721 surface by inheriting the OpenZeppelin base (`target/packages/contracts/src/Raffle.sol:L28`):

```solidity
// target/packages/contracts/src/Raffle.sol:L28
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {
```

The only purchase implementation rejects a zero-sized range and a `uint128` endpoint overflow, derives the next interval from the prior global endpoint, advances the ticket counter once, stores one range under that ticket ID, and makes one `_safeMint` call (`target/packages/contracts/src/Raffle.sol:L209-L236`):

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L220
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
```

```solidity
// target/packages/contracts/src/Raffle.sol:L223-L236
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

Because `entryCount` is positive and the addition is bounded, `firstEntry = old totalEntries + 1` and `lastEntry = old totalEntries + entryCount` form a nonempty contiguous interval on every returning purchase path (`target/packages/contracts/src/Raffle.sol:L218-L232`). Both endpoints are included when the range is consumed: refunds count `lastEntry - firstEntry + 1` (`target/packages/contracts/src/Raffle.sol:L362-L364`), and winner validation rejects only values strictly below the first endpoint or strictly above the last (`target/packages/contracts/src/Raffle.sol:L579-L584`). The getter returns the same two fields stored under the ticket ID (`target/packages/contracts/src/Raffle.sol:L451-L455`).

The inherited safe-mint path calls `_mint`, which dispatches through `Raffle._update`, rejects an already-existing token ID, and then requires a contract recipient to accept the token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). Thus a successful call has one mint; an invalid token ID or rejecting receiver reverts the transaction rather than leaving a paid, unminted purchase.

The base advertises both ERC-721 and ERC-721 Metadata interface IDs (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50`), stores owner balances, token owners, token approvals, and operator approvals (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L28-L34`), and exposes the corresponding ownership and approval operations (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L52-L112`). `transferFrom` and both safe-transfer overloads are inherited (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`).

Authorization is substantive rather than nominal: an actor passes only when it is the owner, an approved operator, or the token-specific approved address, and an unauthorized or nonexistent-token path reverts (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L185`). The base update clears a token-specific approval on transfer, decrements and increments the respective balances, changes the owner, and emits `Transfer` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`).

`Raffle` overrides that common mint/transfer/burn hook, screens nonzero protocol destinations, and then delegates every permitted update to the base implementation (`target/packages/contracts/src/Raffle.sol:L497-L502`):

```solidity
// target/packages/contracts/src/Raffle.sol:L497-L502
function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    previousOwner = super._update(to, ticketId, auth);
}
```

The screened set is the raffle itself, its factory, its quote token, its VRF wrapper, its prize token, the shared implementation, and same-factory raffle clones (`target/packages/contracts/src/Raffle.sol:L593-L604`). The override contains no lifecycle/status branch and does not replace the base authorization or ledger mutation (`target/packages/contracts/src/Raffle.sol:L497-L502`).

---

**Paths walked:**

- Factory construction and cloning: the factory deploys the immutable `Raffle` implementation once (`target/packages/contracts/src/RaffleFactory.sol:L89-L91`), and `createRaffle` creates a fixed-target clone before calling `initialize` (`target/packages/contracts/src/RaffleFactory.sol:L105-L121`). The clone library's selected `clone` path installs the minimal-proxy bytecode targeting that implementation (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`). ✓
- `buyEntries` precondition/payment failures: wrong status, ended sale, zero recipient, zero entries, endpoint overflow, or quote-token transfer failure reverts before the mint; none is a successful purchase path (`target/packages/contracts/src/Raffle.sol:L209-L224`). ✓
- `buyEntries` returning path: one ticket ID is derived, `ticketCount` is incremented once, one range slot is written, and `_safeMint` is invoked once (`target/packages/contracts/src/Raffle.sol:L226-L236`). ✓
- `_safeMint` → `_mint` → `Raffle._update` → `ERC721._update`: an allowed EOA recipient gets one owner/balance update and a `Transfer` event; the EOA branch performs no receiver callback (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245,L259-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L32`). ✓
- `_safeMint` to a contract: the receiver must return the exact `IERC721Receiver` selector; a wrong selector, empty failure, or bubbled receiver revert unwinds the mint and all earlier purchase state (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L32-L48`). ✓
- `approve` and `setApprovalForAll`: token approval requires the owner or an operator-for-all, while operator approval records the caller-selected operator status; invalid approver/operator branches revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L112,L375-L418`). ✓
- `transferFrom` by owner, token-approved actor, or operator-for-all: `Raffle._update` reaches `super._update`; the base checks authorization, clears the token approval, moves balances and ownership, and emits `Transfer` (`target/packages/contracts/src/Raffle.sol:L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L185,L216-L245`). ✓
- Unauthorized or nonexistent-token transfer: base authorization reverts instead of mutating ownership (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L179-L185`). ✓
- Both `safeTransferFrom` overloads: they use the same authorized transfer and then enforce contract-recipient acceptance; receiver failure reverts the ownership update (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L127-L135`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Transfer in any live raffle lifecycle state: neither inherited transfer entrypoint nor the complete `Raffle._update` body reads `status`, so the same transfer path remains available until an internal redemption/refund path burns the ticket (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135`; `target/packages/contracts/src/Raffle.sol:L497-L502`; burn call sites at `target/packages/contracts/src/Raffle.sol:L320-L325,L357-L365`). ✓
- Transfer or mint to a known protocol destination: the raffle-specific hook reverts before the base ledger update (`target/packages/contracts/src/Raffle.sol:L497-L500,L593-L604`). This is a recipient-safety restriction; it does not bypass ownership, approval, or transfer checks for a ticket that is minted to an allowed recipient.
- Burn: `to == address(0)` bypasses only the nonzero-destination screen, then the base clears approval, balance, and ownership and emits the standard burn-shaped `Transfer` (`target/packages/contracts/src/Raffle.sol:L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245,L292-L308`). ✓

The `nonReentrant` modifier on `buyEntries` covers both the quote-token call and the safe-mint receiver callback (`target/packages/contracts/src/Raffle.sol:L209-L235`). Its inherited guard marks the call entered before the body and rejects a nested guarded purchase, then restores the guard after the body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72,L88-L105`), so neither external call can add a second nested purchase mint within the same raffle.

---

**Searched:**

- Full declared scope → read all five production files and all 31 files named by `target/dependency-hashes.json`; all 31 dependency SHA-256 values matched the manifest, with 0 missing files and 0 mismatches.
- `buyEntries(` across the five production files → 2 hits: the interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L314` and the sole implementation at `target/packages/contracts/src/Raffle.sol:L209`; no production caller or wrapper.
- `_safeMint(` or `_mint(` across the five production files → 1 hit, the `_safeMint` call at `target/packages/contracts/src/Raffle.sol:L235`; the inherited definitions/call chain are at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`.
- `_ticketRanges` across the five production files → 3 hits: declaration at `target/packages/contracts/src/Raffle.sol:L139`, sole write at `L232`, and getter read at `L452`; no alternate writer.
- `ticketCount` in `Raffle.sol` → declaration/getter at `target/packages/contracts/src/Raffle.sol:L88`, ticket-ID read at `L228`, and sole state write at `L231`; no second increment or mint branch.
- `function _update(` in `Raffle.sol` and the ERC-721 base → 2 hits: base implementation at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216` and raffle override at `target/packages/contracts/src/Raffle.sol:L497`; the override body has 0 `status`/`Status` references and one call to `super._update` at `L501`.
- ERC-721 public surface search (`supportsInterface`, `balanceOf`, `ownerOf`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`, and both `safeTransferFrom` overloads) → 10 implementation hits in `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L45-L133`; 0 first-party overrides of those functions.
- ERC-721 authorization/approval helper search (`_isAuthorized`, `_checkAuthorized`, both `_approve` overloads, `_setApprovalForAll`) → 5 implementation hits in `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L185,L375-L418`.
- Receiver-check definition/calls (`function checkOnERC721Received`, `ERC721Utils.checkOnERC721Received`) → 4 hits: the utility definition at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25` and base calls for public safe transfer, safe mint, and internal safe transfer at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L135,L289,L362`.

---

**How the verdict was reached:** This is `implemented` because the single successful purchase path performs exactly one safe mint after storing exactly one bounded interval, the interval's construction and later comparisons make both endpoints inclusive, and the minted token uses the read-through OpenZeppelin ownership, approval, authorization, transfer, safe-receiver, event, and interface-support machinery (`target/packages/contracts/src/Raffle.sol:L209-L236,L451-L455,L579-L584`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L50,L92-L135,L164-L185,L216-L290`). It is not `partial`: every branch that does not reach the mint reverts the purchase, and no returning purchase branch skips the range write or mint. The protocol-destination rejection narrows unsafe recipients but does not create a ticket lacking ERC-721 ownership, approval, or authorized transfer semantics; the requirement does not state that every nonzero address must be accepted. It is not `stronger-than-spec`: the implementation realizes the requested one-ticket, contiguous-inclusive-range, ERC-721 property rather than replacing it with a stricter range or ownership rule.

---

**Open questions:**

- None.
