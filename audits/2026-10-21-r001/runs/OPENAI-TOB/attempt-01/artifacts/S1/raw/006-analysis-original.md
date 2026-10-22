## `refundTickets` in target/packages/contracts/src/Raffle.sol (L349-L372)

**Purpose:** Converts the current owner's selected ticket claims into a full quote-token refund, destroys those tickets, and reduces the outstanding refund liability in one transaction (Raffle.sol L349-L371). The refund unit is the inclusive entry range represented by each ticket, rather than one payment per ERC721 token (L362-L367); the fixed price is 1,000,000 raw units per entry (RaffleConstants.sol L20-L21).

---

**Inputs & Assumptions:**
- `ticketIds` is an untrusted `uint256[] calldata`; the external function accepts 1–100 IDs, enforces current ownership independently for each, and returns an aggregate amount (Raffle.sol L349-L367; RaffleConstants.sol L26-L27). Neither sorting nor a separate uniqueness proof is requested; duplicate IDs encounter a destroyed token on their second occurrence (Raffle.sol L359-L364; ERC721.sol L426-L431, L240).
- Implicit inputs are `msg.sender`, lifecycle `status`, the ERC721 ownership ledger, historical `_ticketRanges`, `remainingRefundLiability`, and immutable `quoteToken` (Raffle.sol L58, L94, L124, L139, L350-L369). There is no timestamp check in this function; entry into Refunding is supplied by `enableRefunds`, which performs its own Active/Drawing deadline checks before copying the pot to refund liability (L276-L300).
- Ticket existence is established by `ownerOf` → `_requireOwned` → `_ownerOf`, not by `ticketRange`. The latter only copies stored endpoints and has no existence/range validation (ERC721.sol L61-L63, L146-L148, L426-L431; Raffle.sol L451-L455). Valid ranges come from `buyEntries`, which requires positive `entryCount`, bounds cumulative entries, stores consecutive one-based ranges, and mints after storing them (L218-L235).
- The available refund liability is derived from actual credited purchases: `buyEntries` adds `entryCount * ENTRY_PRICE` to `unsettledPot`, and `enableRefunds` moves that total into `remainingRefundLiability` (Raffle.sol L223-L234, L296-L299). The checked subtraction in this function enforces sufficient recorded liability for this particular call (L368). Equal actual token backing assumes the stated canonical, non-rebasing, fee-free token semantics; nothing in the payout helper measures the recipient's balance change (L560-L566; SafeERC20.sol L176-L200).
- `_burn` does not authenticate the caller; owner-only authorization is established by the explicit comparison at Raffle.sol L359-L360. The guard precondition is established by inherited `nonReentrant`, which rejects the entered value before the body, writes entered, and restores not-entered after successful completion (ReentrancyGuard.sol L69-L73, L88-L118).

---

**Outputs & Effects:**
- The named return is the sum of represented entries times `ENTRY_PRICE` (Raffle.sol L349, L362-L367). Successful execution sets `remainingRefundLiability` to its previous value minus that amount (L368), then transfers that amount to `msg.sender` through `_transferQuote` (L369, L564-L566).
- Every burned ticket has its individual approval cleared, its former owner's balance decremented, ownership set to zero, and an ERC721 `Transfer` event emitted (ERC721.sol L216-L244, L383-L399). `_ticketRanges` are retained; the refund body does not delete them, consistent with their historical-storage declaration (Raffle.sol L138-L139, L349-L372).
- `TicketsRefunded` records caller, number of submitted tickets, aggregate entries, amount, and liability after payment (Raffle.sol L370-L371). The body does not change `ticketCount`, `totalEntries`, or lifecycle status (L349-L372).
- Burns and liability reduction precede external destination queries and token transfer. A rejection by those helpers or the token bubbles/reverts through the call; Solidity/EVM transaction rollback restores all earlier burns/accounting and logs in the same transaction (Raffle.sol L364-L369, L564-L566; SafeERC20.sol L33-L37, L184-L196). This uses the atomic-rollback execution assumption supplied in the request orientation.

---

**Block-by-Block:**

```solidity
// Raffle.sol L349-L354
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
    _requireStatus(Status.Refunding);
    uint256 ticketQuantity = ticketIds.length;
    if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
        revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
    }
```
- **What:** Acquires the guard, rejects the wrong lifecycle, and validates the bounded batch (Raffle.sol L349-L354; ReentrancyGuard.sol L69-L73).
- **Why here:** No ticket mutation occurs before these checks; the guard is already entered during all subsequent helper and token interactions (Raffle.sol L349-L369; ReentrancyGuard.sol L94-L105).
- **Assumes:** Refunding encodes the protocol's cancellation decision. For clones, `enableRefunds` establishes this after its deadline branch and liability migration (Raffle.sol L276-L300); the locked implementation also starts Refunding, with no ticket mint here (L164-L165).
- **Establishes / depended on by:** The loop operates with 1–100 items and the Refunding lifecycle; `_requireStatus` has only return-on-match and revert-on-mismatch paths (Raffle.sol L350-L357, L573-L575; RaffleConstants.sol L27).

```solidity
// Raffle.sol L356-L365
uint256 aggregateEntries = 0;
for (uint256 index; index < ticketQuantity; ++index) {
    uint256 ticketId = ticketIds[index];
    address owner = ownerOf(ticketId);
    if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
    _burn(ticketId);
}
```
- **What:** Resolves a live owner, requires that exact owner to be the caller, accumulates inclusive range length, and burns each item before proceeding (Raffle.sol L356-L365).
- **Why here:** Ownership is checked before use of the historical range, and the immediate burn makes duplicates fail on the next `ownerOf` lookup. Approved operators alone fail the explicit comparison (Raffle.sol L359-L364; ERC721.sol L426-L431).
- **Assumes:** Minted tickets have positive ordered ranges from `buyEntries` (Raffle.sol L218-L235). `ticketRange` does not establish that property itself (L451-L455). The unchecked balance decrement inside ERC721 depends on ownership/balance consistency; the ERC721 update path maintains both ownership and balances together (ERC721.sol L216-L244), while Raffle's override delegates to that path (Raffle.sol L497-L502).
- **Establishes:** For a successful iteration the claim has been counted once and ownership removed. `_burn` dispatches to `_update(address(0), ticketId, address(0))`: Raffle's destination condition short-circuits on zero, so there is no factory query during a burn. The base update skips authorization because `auth` is zero, clears approvals without emitting `Approval`, decrements the nonzero owner's balance, skips the recipient increment because `to` is zero, writes zero ownership, and emits `Transfer` (Raffle.sol L497-L502; ERC721.sol L216-L244, L303-L308, L383-L399).
- **Depended on by:** The final amount relies on these accumulated lengths; later refunds rely on missing ownership preventing reuse (Raffle.sol L359-L369; ERC721.sol L426-L431). Nonexistent or repeated IDs revert; there is no partial-success return (Raffle.sol L349-L372).

```solidity
// Raffle.sol L367-L371
amount = aggregateEntries * ENTRY_PRICE;
remainingRefundLiability -= amount;
_transferQuote(msg.sender, amount);
uint256 liabilityAfter = remainingRefundLiability;
emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
```
- **What:** Converts entries into raw token units, debits liability, pays the owner, and publishes the resulting accounting (Raffle.sol L367-L371).
- **Why here:** All selected tickets are consumed and liability is reduced before any payout interaction (L364-L369). Guarded entrypoints remain locked during those interactions (ReentrancyGuard.sol L69-L73, L94-L105).
- **Assumes:** The destination queries describe the canonical factory and the quote transfer has the stated economic semantics (Raffle.sol L560-L566, L598-L604). Actual transfer semantics are not established by return-data acceptance (SafeERC20.sol L184-L196).
- **Establishes / depended on by:** Success reports the charged aggregate and post-payout liability; subsequent refunds use the reduced liability. Checked arithmetic in the Solidity 0.8.36 body has no local unchecked block (Raffle.sol L2, L349-L372).

---

**Cross-Function Dependencies:**
- `nonReentrant` (internal): `_nonReentrantBefore` calls `_nonReentrantBeforeView`, which rejects only the entered value; `_reentrancyGuardEntered` reads the chosen storage slot. On success before the body it writes 2, afterward 1. `StorageSlot.getUint256Slot` returns the requested slot through assembly; there is no external call in this chain (ReentrancyGuard.sol L50-L51, L69-L73, L88-L118; StorageSlot.sol L93-L97). A clone's initial zero slot is accepted by the equality-to-entered test (ReentrancyGuard.sol L112-L114). This guard constrains only methods that apply the modifier, not every inherited ERC721 method (Raffle.sol L349; ERC721.sol L61-L63).
- `_requireStatus` (internal): rejects unless `status == expected`, with no additional state change (Raffle.sol L573-L575).
- `ownerOf` → `_requireOwned` → `_ownerOf` (internal): reads the mapping and rejects zero ownership. This is the actual existence check that makes a stale historical range insufficient to claim (ERC721.sol L61-L63, L146-L148, L426-L431).
- `ticketRange` (internal): copies endpoints without validation or deletion (Raffle.sol L451-L455). The claim relies on prior successful mint/range creation at L218-L235.
- `_burn` → Raffle `_update` → ERC721 `_update` → `_ownerOf` and `_approve` (internal): burn passes zero destination and zero auth; no destination screening or authorization subcall occurs on that path. `_burn` rejects zero previous ownership after update; transaction rollback removes that unsuccessful update (ERC721.sol L303-L308; Raffle.sol L497-L502). `_approve` takes `(zero, id, zero, false)`, so its owner/authorization/event branch is skipped, but the approval mapping write runs (ERC721.sol L227, L383-L399).
- `_transferQuote` → `_isProtocolDestination` (internal): rejects caller destinations equal to this raffle, factory, quote token, wrapper, prize token, or factory implementation. The OR expression short-circuits; only if earlier equalities fail does it call `raffleImplementation`. If still safe and destination has code it calls `isRaffle`; code-less destinations skip that query (Raffle.sol L564-L566, L598-L604).
- Factory `raffleImplementation()` and `isRaffle(destination)` (external-source-available): generated view getters read the immutable and registry respectively. The implementation is set at deployment and registration is written before prize transfer in creation (RaffleFactory.sol L42, L54, L89-L91, L123-L128; IRaffleFactory.sol L130-L139). This path depends on canonical deployment binding `factory` to the deployer (Raffle.sol L159-L162; RaffleFactory.sol L89).
- `SafeERC20.safeTransfer` → `_safeTransfer` (internal) and `quoteToken.transfer` (external-black-box): helper sends zero native value and calldata `transfer(msg.sender, amount)` to the immutable quote token, forwarding gas (Raffle.sol L566; SafeERC20.sol L176-L184). A failed low-level call bubbles revert data; success with a first return word equal to 1 is accepted; otherwise only successful empty returndata from an address with code is accepted. A false helper result becomes `SafeERC20FailedOperation` (SafeERC20.sol L33-L37, L184-L199). The helper does not establish actual transferred value. Unknown token implementation could revert, return a hostile result, change its own ledger unexpectedly, or attempt callbacks; the local ordering and entered guard are already in place (Raffle.sol L364-L369; ReentrancyGuard.sol L94-L105).
- **Callers:** Public external callers supply the batch; the interface describes owner-selected full refunds and batch-wide failure for duplicates/nonexistent/foreign tickets (Raffle.sol L349; IRaffle.sol L340-L344).
- **Shared state and couplings:** `buyEntries` establishes ranges and pot backing; `enableRefunds` migrates that pot into liability; this function decrements liability while removing ticket ownership (Raffle.sol L223-L235, L296-L299, L359-L369). Retained ranges alone do not confer claim authority (L359-L362, L451-L455). ERC721 ownership is transferable before claiming through the inherited ledger, and the explicit caller comparison makes the current owner the payout recipient (ERC721.sol L216-L244; Raffle.sol L359-L369).

---

**Open Questions:**
- unclear; need to inspect the concrete canonical quote-token implementation/configuration to establish actual token delivery, pause/restriction behavior, and callback behavior. Only its interface, the SafeERC20 return-handling path, and the declared trust assumption were available in this function review (IERC20.sol L35-L41; SafeERC20.sol L176-L200; Raffle.sol L560-L566).
