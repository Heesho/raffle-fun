## `refundTickets` in `target/packages/contracts/src/Raffle.sol` (L349-L372)

**Purpose:** Converts one owner-selected batch of live ERC-721 range tickets into the tickets' full quote-token purchase value. On the successful path it consumes every submitted bearer claim by burning the ticket, reduces the aggregate refund liability by the same calculated amount, transfers that amount to the current owner/caller, and records the post-refund liability (`Raffle.sol:L349-L371`; `IRaffle.sol:L340-L344`). Without this operation, `enableRefunds` could allocate the refund liability but ticket owners could not consume their individual claims (`Raffle.sol:L296-L300`).

**Inputs & Assumptions:**

- `ticketIds` (`uint256[] calldata`): caller-selected ticket IDs. Trust: **untrusted**. The array may be empty, longer than the accepted bound, contain nonexistent or already-burned IDs, contain tickets owned by another address, or repeat an ID (`Raffle.sol:L349-L364`).
- `msg.sender`: untrusted external caller and the eventual quote-token recipient. It must be the exact current owner of every submitted ticket; an ERC-721 approval or operator approval is not consulted (`Raffle.sol:L359-L360`).
- Implicit persistent inputs are `status`, `remainingRefundLiability`, `_ticketRanges`, inherited ERC-721 owner/balance/approval state, the immutable `quoteToken` and `factory`, and the configured `prizeToken` used by destination screening (`Raffle.sol:L55-L70`, `L94`, `L124`, `L138-L142`, `L349-L369`).
- Implicit execution input is the shared `ReentrancyGuard` slot. The modifier rejects a call while that slot is `ENTERED`, sets it before the body, and restores it only after the body completes (`ReentrancyGuard.sol:L69-L73`, `L88-L105`).
- Precondition: lifecycle status is exactly `Refunding`. `_requireStatus(Status.Refunding)` enforces it at `Raffle.sol:L350`; `_requireStatus` compares the stored status and reverts on inequality (`Raffle.sol:L571-L575`). For a canonical initialized raffle with tickets, `enableRefunds` reaches this state from `Active` or `Drawing`, copies `unsettledPot` into `remainingRefundLiability`, zeros `unsettledPot`, and then changes status (`Raffle.sol:L276-L300`). The locked implementation also starts in `Refunding`, but its constructor creates no tickets (`Raffle.sol:L151-L166`).
- Precondition: the batch contains from one through 100 IDs inclusive. The function enforces the lower and upper bounds before doing ticket work (`Raffle.sol:L351-L354`; `RaffleConstants.sol:L26-L27`).
- Precondition, per element: the ID currently exists. `ownerOf` delegates to `_requireOwned`, which reads `_owners[tokenId]` and reverts when it is zero (`ERC721.sol:L60-L63`, `L146-L148`, `L420-L432`). This excludes never-minted and already-burned tickets before their range is used.
- Precondition, per element: `msg.sender` is the current owner. The explicit equality check establishes this; operator approvals do not satisfy it (`Raffle.sol:L359-L360`). Because ownership is read on each iteration, the check uses ownership at execution time rather than the original purchaser recorded in `TicketPurchased` (`Raffle.sol:L223-L236`; `ERC721.sol:L114-L125`).
- Assumption: every live raffle ticket has a nonzero, ordered, paid-for historical range. This is established by the only in-scope mint path: `buyEntries` rejects zero entry count and cumulative `uint128` overflow, derives `[totalEntries + 1, totalEntries + entryCount]`, stores it under a new sequential ticket ID, accounts the corresponding gross amount, and then mints that same ID (`Raffle.sol:L215-L235`). The range mapping is deliberately historical and is not deleted on burns (`Raffle.sol:L138-L139`, `L451-L455`).
- Assumption: `remainingRefundLiability` covers the sum represented by all still-refundable tickets. The source establishes the coupling by adding `entryCount * ENTRY_PRICE` to `unsettledPot` on every successful purchase (`Raffle.sol:L223-L235`), moving the entire pot into the refund liability at the refund transition (`Raffle.sol:L296-L300`), and burning each ticket before subtracting its claim during a refund (`Raffle.sol:L356-L368`). The subtraction itself is checked under Solidity 0.8.36 and reverts if the stored coupling does not hold (`Raffle.sol:L2`, `L368`).
- Assumption: the immutable quote token behaves as canonical, non-rebasing, fee-free six-decimal USDC, so a successful `transfer(msg.sender, amount)` reduces the raffle balance and increases the recipient balance by exactly `amount`. The trust model states this explicitly (`IRaffle.sol:L12-L15`; `Raffle.sol:L560-L566`). The factory checks deployed code and six-decimal metadata (`RaffleFactory.sol:L65-L78`), but the target contains only the ERC-20 interface for the concrete transfer. On-chain verification of exact token identity and balance deltas: **nothing found** (`IRaffleFactory.sol:L6-L9`; `IERC20.sol:L35-L41`).

**Outputs & Effects:**

- Returns `amount = aggregateEntries * ENTRY_PRICE` on success (`Raffle.sol:L367-L372`). For source-created live tickets, each range contributes its original `entryCount`, because `[T+1,T+entryCount]` has inclusive length `entryCount` (`Raffle.sol:L218-L227`, `L362-L363`).
- Burns every supplied ticket. Each burn clears its token approval, decrements the owner's ERC-721 balance, sets its owner to zero, and emits the ERC-721 `Transfer(owner,address(0),ticketId)` event (`ERC721.sol:L216-L245`, `L292-L307`; `Raffle.sol:L364`).
- Leaves `_ticketRanges[ticketId]`, `totalEntries`, and `ticketCount` unchanged. These are lifetime/historical records; this function has no writes to them, and the mapping is documented to survive burns (`Raffle.sol:L85-L89`, `L138-L139`, `L349-L372`).
- Decrements `remainingRefundLiability` by exactly the returned amount before transferring quote tokens (`Raffle.sol:L367-L369`). Consequently, `accountedQuoteBalance()` loses the same liability component that the trusted quote-token transfer removes from the actual token balance (`Raffle.sol:L468-L470`).
- Calls the immutable quote-token contract to transfer `amount` to `msg.sender`, after destination screening (`Raffle.sol:L564-L567`, `L369`). The quote-token implementation is not present in the target; revert, `false`, malformed return data, an empty successful return, and re-entry are handled or assumed as described under Cross-Function Dependencies.
- Emits `TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, remainingRefundLiability)` only after the transfer returns successfully (`Raffle.sol:L369-L371`; `IRaffle.sol:L147-L159`).
- Any failure in batch validation, an iteration, liability subtraction, destination screening, or token transfer reverts the complete call. Thus a later invalid/duplicate ID or a failed final transfer does not leave earlier burns or the liability decrement committed (`Raffle.sol:L349-L371`; `IRaffle.sol:L340-L344`).

---

**Block-by-Block:**

```solidity
// Raffle.sol:L349-L350
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
    _requireStatus(Status.Refunding);
```

- **What:** Opens an external, guarded claim path and immediately gates it on the refund lifecycle.
- **Why here:** No ticket ownership, range, burn, or accounting work can occur outside `Refunding`; the reentrancy guard is active before even this status read (`Raffle.sol:L349-L350`; `ReentrancyGuard.sol:L69-L72`, `L94-L100`).
- **Assumes:** The state transition into `Refunding` also allocated the correct liability. For ticket-bearing canonical clones, `enableRefunds` establishes that link at `Raffle.sol:L296-L300`.
- **Establishes:** `status == Status.Refunding` for the remainder of the body unless an external call later changes it. The body makes no external call until after all burns and the liability write, and the final call is made while `nonReentrant` remains entered (`Raffle.sol:L350-L369`).
- **Depended on by:** Every ticket burn and the use of `remainingRefundLiability` as the active claim pool (`Raffle.sol:L356-L369`).

```solidity
// Raffle.sol:L351-L354
uint256 ticketQuantity = ticketIds.length;
if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
    revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
}
```

- **What:** Snapshots the calldata length and accepts only 1 through `MAX_REFUND_TICKET_BATCH_SIZE` (100) elements (`RaffleConstants.sol:L26-L27`).
- **Why here:** It rejects an empty no-op and bounds all later per-ticket storage reads and writes before the loop starts.
- **Assumes:** The fixed cap is the intended execution bound; the source defines the cap by ticket count, while one ticket may represent any `uint128` entry count (`RaffleConstants.sol:L26-L27`).
- **Establishes:** `1 <= ticketQuantity <= 100` at loop entry.
- **Depended on by:** Loop termination and arithmetic bounds at `Raffle.sol:L357-L367`.

```solidity
// Raffle.sol:L356-L360
uint256 aggregateEntries = 0;
for (uint256 index; index < ticketQuantity; ++index) {
    uint256 ticketId = ticketIds[index];
    address owner = ownerOf(ticketId);
    if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);
```

- **What:** Iterates the bounded array, proves that the current ID exists, and requires exact caller ownership before consuming its claim.
- **Why here:** `ownerOf` is intentionally before `ticketRange`; `ticketRange` alone returns zeroes for an ID never minted, whereas `ownerOf` reverts for zero ownership (`Raffle.sol:L451-L455`; `IRaffle.sol:L368-L373`; `ERC721.sol:L420-L432`). The ownership equality is before both accounting and burn.
- **Assumes:** Inherited ERC-721 ownership is the authoritative bearer-claim registry. Tickets remain transferable through inherited `transferFrom`/`safeTransferFrom`, whose updates reach the Raffle `_update` override (`ERC721.sol:L114-L136`; `Raffle.sol:L491-L502`).
- **Establishes:** For this iteration, the token is live and `msg.sender` is its current owner. Approval alone is insufficient because no authorization helper is called at `Raffle.sol:L359-L360`.
- **Depended on by:** Reading the corresponding range and calling the unauthenticated internal `_burn` (`Raffle.sol:L362-L364`; `ERC721.sol:L292-L307`).

```solidity
// Raffle.sol:L362-L364
(uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
_burn(ticketId);
```

- **What:** Loads the immutable historical range, adds its inclusive length, and burns the claim.
- **Why here:** Range accounting occurs while the token is still proven live; burn immediately follows it, preventing the same ID from completing a second iteration. Both endpoints are widened to `uint256` before subtraction (`Raffle.sol:L362-L364`).
- **Assumes:** A live token's stored range was created by `buyEntries` and satisfies `1 <= firstEntry <= lastEntry <= totalEntries`. `entryCount > 0`, the cumulative overflow check, the sequential formulas, and the mapping write establish this on the mint path (`Raffle.sol:L218-L232`).
- **Establishes:** On this iteration's continuing path, the aggregate includes this ticket exactly once and the ticket has no owner. `_burn` routes through the Raffle `_update(address(0),ticketId,address(0))`; the zero destination skips protocol-destination queries, while the ERC-721 base clears approval, decrements balance, zeros ownership, and emits `Transfer` (`Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`, `L303-L307`).
- **Depended on by:** The final amount calculation assumes each completed iteration corresponds to one consumed ticket claim (`Raffle.sol:L367-L368`).
- **Loop paths:**
  - A nonexistent or previously burned ID reverts in `ownerOf` before range/accounting work (`ERC721.sol:L426-L431`).
  - A foreign-owned ID reaches the explicit `NotTicketOwner` revert before range/accounting work (`Raffle.sol:L359-L360`).
  - A duplicate ID can pass its first occurrence, but its later occurrence sees the owner set to zero and reverts in `ownerOf`; transaction rollback restores the earlier burn (`Raffle.sol:L357-L364`; `ERC721.sol:L240`, `L426-L431`).
  - A source-created live ticket has an ordered range. Were an unordered range present, checked subtraction at `Raffle.sol:L363` would revert; no range-writing path other than `buyEntries` appears in the target (`Raffle.sol:L226-L235`, `L451-L455`).
  - No external call occurs in an iteration: `ownerOf` and `ticketRange` are internal view dispatches, and a burn's zero recipient bypasses `_isProtocolDestination` before using the base ERC-721 storage update (`Raffle.sol:L359-L364`, `L451-L455`, `L497-L502`).

```solidity
// Raffle.sol:L367-L368
amount = aggregateEntries * ENTRY_PRICE;
remainingRefundLiability -= amount;
```

- **What:** Prices the consumed entries at the fixed one-USDC raw-unit price and removes the resulting claim from the aggregate liability (`RaffleConstants.sol:L20-L21`).
- **Why here:** Every ticket has already been validated and burned, but the external quote-token interaction has not started. The accounting state therefore reflects the consumed claims during that interaction (`Raffle.sol:L356-L369`).
- **Assumes:** `remainingRefundLiability >= amount`. Purchase accounting, refund activation, and prior burn-before-decrement refunds establish this system coupling (`Raffle.sol:L223-L235`, `L296-L300`, `L356-L368`).
- **Establishes:** The recorded liability is reduced by the exact amount about to leave. If the assumption does not hold, Solidity's checked subtraction reverts before the external transfer (`Raffle.sol:L2`, `L368`).
- **Arithmetic bounds:** Each range length fits within `uint128`; at most 100 such lengths fit comfortably in `uint256`, and multiplying that upper bound by `1_000_000` also fits in `uint256` (`Raffle.sol:L36-L39`, `L351-L367`; `RaffleConstants.sol:L20-L27`). Source-created distinct tickets further constrain the aggregate to the lifetime `uint128 totalEntries` (`Raffle.sol:L79-L88`, `L218-L232`).
- **Depended on by:** `_transferQuote` and the returned `amount` (`Raffle.sol:L369-L372`).

```solidity
// Raffle.sol:L369-L371
_transferQuote(msg.sender, amount);
uint256 liabilityAfter = remainingRefundLiability;
emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
```

- **What:** Screens the current owner/caller as a payout destination, invokes the quote-token transfer, snapshots the already-updated liability, and emits the aggregate refund record.
- **Why here:** Ticket and liability effects precede the external token call. The event follows successful return, so its `remainingRefundLiability` field is the persisted post-transfer value (`Raffle.sol:L367-L371`).
- **Assumes:** The quote token honors successful ERC-20 transfer semantics exactly; this is the declared canonical-USDC trust boundary rather than a property proven from concrete token source (`IRaffle.sol:L12-L15`; `Raffle.sol:L560-L566`).
- **Establishes:** On return, SafeERC20 accepted the call outcome and the event exposes the batch quantity, entry quantity, paid amount, and remaining claim pool (`SafeERC20.sol:L30-L37`, `L176-L200`; `IRaffle.sol:L147-L159`).
- **Depended on by:** The caller uses the function return and token balance; indexers use `TicketsRefunded` together with the per-ticket ERC-721 burn events (`Raffle.sol:L369-L372`; `ERC721.sol:L240-L244`).

---

**Cross-Function Dependencies:**

- **Modifier `nonReentrant` (inherited, source available; `ReentrancyGuard.sol:L69-L73`, `L88-L105`):** Before the body it rejects only the `ENTERED` state and then records `ENTERED`; after a successful body it records `NOT_ENTERED`. The final quote-token call therefore cannot re-enter `refundTickets` or any other Raffle entry point carrying the same modifier. Inherited ERC-721 transfer and approval entry points do not carry this modifier (`ERC721.sol:L92-L136`).
- **Callee `_requireStatus` (private; `Raffle.sol:L571-L575`):** It has one continuing path (`status == expected`) and one reverting path. `refundTickets` depends on the continuing path to establish `Refunding` before touching claims.
- **Callee `ownerOf` -> `_requireOwned` -> `_ownerOf` (inherited, source available; `ERC721.sol:L60-L63`, `L146-L148`, `L426-L432`):** It returns the current `_owners[ticketId]` entry only when nonzero; otherwise it reverts. `refundTickets` depends on this for both existence and current bearer identity. No external call occurs on either path.
- **Callee `ticketRange` (public/internal source available; `Raffle.sol:L451-L455`):** It copies the stored `uint128` endpoints without validating existence or ordering. The caller's immediately preceding `ownerOf` check establishes existence; the `buyEntries` mint path establishes ordering and provenance (`Raffle.sol:L218-L235`). Historical values remain after a burn (`Raffle.sol:L138-L139`).
- **Callee `_burn` -> Raffle `_update` -> ERC-721 `_update` (inherited/override, source available; `ERC721.sol:L303-L307`; `Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`):** `_burn` supplies `to = address(0)` and `auth = address(0)`. The Raffle override therefore skips destination screening, and the base update skips operator authorization, clears approval, decrements the prior owner's balance, clears ownership, and emits `Transfer`. `_burn` then reverts if the prior owner was zero. `refundTickets` supplies its own stricter exact-owner check just before this call (`Raffle.sol:L359-L364`).
- **Callee `_transferQuote` (private; `Raffle.sol:L560-L567`):** It first calls `_isProtocolDestination(to,address(prizeToken))` and reverts for a recognized protocol sink, then invokes `quoteToken.safeTransfer(to,amount)`. `refundTickets` passes the exact current owner/caller and depends on this helper to reject same-factory plumbing before transferring the claim.
- **Callee `_isProtocolDestination` (private with external source-available factory reads; `Raffle.sol:L587-L605`):** It treats this raffle, its factory, quote token, VRF wrapper, prize token, factory implementation, and registered same-factory raffles as unsafe. It always may read `raffleImplementation()` after earlier equality checks fail, and for a destination with code may also read `isRaffle(destination)` (`Raffle.sol:L598-L604`). In the canonical construction path, the factory deployed the implementation and exposes an immutable implementation getter plus a registry written at raffle creation (`RaffleFactory.sol:L42-L54`, `L89-L92`, `L123-L125`). These view calls can revert the payout if their ABI call fails; no state-changing factory path is invoked.
- **Callee `SafeERC20.safeTransfer` -> `_safeTransfer` -> `quoteToken.transfer` (library plus external black box; `SafeERC20.sol:L30-L37`, `L168-L200`; `IERC20.sol:L35-L41`):** The library bubbles a token-call revert. It accepts a returned word equal to `true`, or a successful empty return only when the token address has code; otherwise it raises `SafeERC20FailedOperation`. It does not compare balances or enforce fee-free/non-rebasing behavior. The target does not include the concrete quote-token implementation, so a successful-but-hostile return, unexpected token state change, or callback into this contract is not excluded by the callee source. The active guard excludes nested guarded Raffle operations; the canonical-USDC trust assumption is what excludes the other hostile-token behaviors (`Raffle.sol:L28-L29`, `L349`, `L560-L566`).
- **State producer `buyEntries` (`Raffle.sol:L209-L237`):** It is the only in-scope ticket mint/range-write path. It bounds cumulative entries to `uint128`, collects `entryCount * ENTRY_PRICE`, creates a contiguous range and sequential ID, increments lifetime counters, stores the range, adds the gross amount to `unsettledPot`, and safe-mints the ticket. `refundTickets` depends on all of those writes having committed together.
- **State producer `enableRefunds` (`Raffle.sol:L275-L301`):** From `Active`, it permits an empty raffle at the specified sponsor/end-time paths or a sold raffle after the draw-request deadline; from `Drawing`, it permits the transition after the callback deadline. Its continuing path moves the whole unallocated pot into `remainingRefundLiability` and sets `Refunding`. `refundTickets` depends on that allocation and makes no independent recomputation from `totalEntries`.
- **Callers:** No internal caller appears in the target. This is an external interface entry point available to any address, while the body narrows successful callers to exact current owners of every submitted ID (`Raffle.sol:L349-L360`; `IRaffle.sol:L340-L344`).
- **Shared state — `status`:** Written by initialization/prize receipt/draw request/refund activation/randomness resolution and read here as the lifecycle gate (`Raffle.sol:L176-L205`, `L240-L260`, `L276-L300`, `L416-L430`, `L509-L523`).
- **Shared state — ERC-721 ownership, balances, approvals:** Created by `buyEntries`, transferable through inherited ERC-721 entry points in every lifecycle state, burned by winner redemption or this refund function, and updated through the Raffle sink-screening override (`Raffle.sol:L235`, `L320-L325`, `L349-L365`, `L491-L502`; `ERC721.sol:L92-L136`, `L216-L245`). Because redemption accepts only `NftWon`/`CashWon`, its burn path does not run in `Refunding` (`Raffle.sol:L309-L325`).
- **Shared state — `_ticketRanges`, `totalEntries`, `ticketCount`:** Purchases append ranges and advance the lifetime counters; refund reads but does not shrink them, leaving reconstruction data available after burns (`Raffle.sol:L85-L89`, `L138-L139`, `L226-L235`, `L451-L455`).
- **Shared state — `remainingRefundLiability` and quote balance:** `enableRefunds` initializes the liability, each successful refund decrements it, and `accountedQuoteBalance` includes it alongside other outstanding liabilities (`Raffle.sol:L296-L300`, `L367-L370`, `L468-L470`). The actual quote balance is increased by purchases and decreased here through the external token (`Raffle.sol:L223-L224`, `L369`).
- **Invariant coupling:** In the refund branch, the initial liability equals the accumulated purchase pot; each completed ticket contributes its original inclusive range length exactly once because it is burned; and each decrement and transfer use the same fixed-price amount (`Raffle.sol:L223-L235`, `L296-L300`, `L356-L369`). This is the coupling on which both checked subtraction and quote-token solvency rely.

---

**Open Questions:**

- Unclear; need the deployed quote-token bytecode and deployment configuration to establish that the configured address is official USDC and that a successful transfer moves exactly `amount` without rebasing, fee, callback, or fabricated success. The target establishes code presence and six decimals but explicitly delegates identity verification to deployment tooling (`RaffleFactory.sol:L65-L78`; `IRaffleFactory.sol:L6-L9`).
- Unclear; need the concrete deployed factory provenance if this analysis is applied outside the canonical `RaffleFactory` construction path. `Raffle` records its constructor caller as `factory` and later ABI-calls that address as `IRaffleFactory` (`Raffle.sol:L155-L162`, `L598-L604`); the canonical source path satisfies that dependency by deploying the implementation at `RaffleFactory.sol:L89-L92`.
