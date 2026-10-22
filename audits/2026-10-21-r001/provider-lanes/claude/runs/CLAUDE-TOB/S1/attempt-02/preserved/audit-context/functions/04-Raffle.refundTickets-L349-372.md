## `refundTickets` in packages/contracts/src/Raffle.sol (L349-L372)

Files cited (paths relative to `packages/contracts/`):

- `src/Raffle.sol`: bare `L###` citations refer to this file
- `src/libraries/RaffleConstants.sol`
- `src/interfaces/IRaffle.sol`, `src/interfaces/IRaffleFactory.sol`
- `src/RaffleFactory.sol`
- `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` (v5.6.0, L2)
- `node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` (v5.5.0)
- `node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` (v5.5.0)
- `node_modules/@openzeppelin/contracts/proxy/Clones.sol`
- `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`
- `DESIGN.md` (repo root)

```solidity
// L349-L372
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
    _requireStatus(Status.Refunding);
    uint256 ticketQuantity = ticketIds.length;
    if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
        revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
    }

    uint256 aggregateEntries = 0;
    for (uint256 index; index < ticketQuantity; ++index) {
        uint256 ticketId = ticketIds[index];
        address owner = ownerOf(ticketId);
        if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
        _burn(ticketId);
    }

    amount = aggregateEntries * ENTRY_PRICE;
    remainingRefundLiability -= amount;
    _transferQuote(msg.sender, amount);
    uint256 liabilityAfter = remainingRefundLiability;
    emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
}
```

**Purpose:**

This function turns live range tickets into USDC once the clone is in the terminal `Refunding` state.

- **The only way the refund liability shrinks.** `remainingRefundLiability` has two writers: `enableRefunds` sets it at L298, and this function debits it at L368. Nothing else lowers it.
- **The only USDC outflow while `Refunding`.** There are four `_transferQuote` sites: L342, L369, L380 and L390.
  - L342 (`redeemWinningTicket`) is gated to `NftWon|CashWon` at L312.
  - L380 needs `sponsorProceeds != 0` (L377) and L390 needs `protocolFees != 0` (L387). Those are written non-zero only at L554-L555, inside `_settleWinningTicket`, which is gated to `NftWon|CashWon` at L536.
  - That leaves L369 as the only site that can pay out in `Refunding`.
- **Without it, the refund pot has no exit.** `enableRefunds` moves the pot into `remainingRefundLiability` (L296-L298). The contract has no administrator and no rescue path (NatSpec L24-L25).
- **It carries the design's refund promise.** DESIGN.md:L2 says "Refund outcome pays 100% per entry". The payout is exactly `entries * ENTRY_PRICE` (L363, L367), with no fee and no rounding.

---

**Inputs & Assumptions:**

**Parameters and caller**

- `ticketIds` (`uint256[] calldata`): ticket IDs chosen by the caller. **Trust: untrusted.**
  - L352 bounds the length.
  - Each element is validated only by L359-L360.
  - Order is arbitrary. This function has no uniqueness or sortedness check; uniqueness falls out of the burn at L364 followed by `ownerOf` at L359 on the next iteration.
- `msg.sender`: **Trust: untrusted.**
  - It must be the current ERC-721 owner of every listed ID (strict equality, L360).
  - It is the only payee (L369); the caller cannot pick a different recipient.
  - Approved operators (`approve` / `setApprovalForAll`) cannot refund.

**Implicit state read**

- `status` (L124), read at L574.
- The ERC-721 ledger: `_owners` (ERC721.sol:L28), `_balances` (L30), `_tokenApprovals` (L32).
- `_ticketRanges` (L139).
- `remainingRefundLiability` (L94).
- `prizeToken` (L70), read at L565 and compared by address only.
- Immutables in the implementation bytecode, shared by every clone:
  - `factory` (L55, set at L161)
  - `quoteToken` (L58, set at L162)
  - `i_vrfV2PlusWrapper` (VRFV2PlusWrapperConsumerBase.sol:L35)
- The factory registry, read by STATICCALL: `raffleImplementation()` and `isRaffle()` (IRaffleFactory.sol:L130, L139, both `view`; storage at RaffleFactory.sol:L42, L54).
- `msg.sender.code.length` (L602).
- The reentrancy-guard slot (ReentrancyGuard.sol:L36-L37).
- The clone's USDC balance, held inside the quote-token contract.

**Clock**

- Not read. `block.timestamp` appears nowhere in L349-L372 or in any callee on this path, so refunds have no deadline.

**Preconditions, and what establishes each**

1. `status == Refunding`. Enforced here at L350.
2. `remainingRefundLiability == ENTRY_PRICE * (sum of entry counts of live tickets)` on entry. Established jointly by:
   - `buyEntries` L218-L233
   - `enableRefunds` L296-L298
   - the burn gating at L312 and L350

   The full derivation is under Invariant couplings.
3. The ranges of minted tickets partition `[1, totalEntries]`. Established by `buyEntries` L219-L232, which holds the only writers: `_ticketRanges` at L232, `totalEntries` at L230, `ticketCount` at L231. A grep of Raffle.sol finds no other assignment and no `delete`.
4. The clone's USDC balance is at least `remainingRefundLiability`. **Nothing found** on-chain. It rests on the trusted-USDC model (IRaffle.sol:L13-L14; Raffle L560-L561 NatSpec), which covers two things:
   - the inbound `safeTransferFrom` at L224 delivers exactly `grossAmount`;
   - no other USDC outflow can occur before or during `Refunding` (see Purpose).
5. `quoteToken.transfer(msg.sender, amount)` succeeds and moves exactly `amount`. **Nothing found.** The token is a black box whose issuer controls sit outside the system.

---

**Outputs & Effects:**

**Return value**

- `amount = aggregateEntries * ENTRY_PRICE` (L367).
- On any successful call, `amount >= 1_000_000`: L352 forces at least one ticket, and each live ticket contributes at least one entry (see L362-L363).

**Storage writes**

- Per listed ticket, via `_burn`:
  - `_tokenApprovals[id] = 0` (ERC721.sol:L398)
  - `_balances[msg.sender] -= 1`, unchecked (ERC721.sol:L229-L231)
  - `_owners[id] = 0` (ERC721.sol:L240)
- `remainingRefundLiability -= amount`, checked (L368).
- Guard slot set to ENTERED (ReentrancyGuard.sol:L99), then back to NOT_ENTERED (L105).
- **Not written:**
  - `_ticketRanges`, which are kept after the burn (L138)
  - `totalEntries`, `ticketCount`, `unsettledPot`, `status`
  - `_operatorApprovals`

**Events, as separate lines**

- `Transfer(msg.sender, address(0), id)` once per ticket, in array order (ERC721.sol:L242).
- No `Approval` event on burn, because `emitEvent=false` at ERC721.sol:L227.
- The quote token's own transfer event (black box).
- `TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter)` (L371).

**External interactions**

All of these happen after the function's last storage write (L368); only the guard reset follows them.

1. STATICCALL `factory.raffleImplementation()` (L601). It is skipped only when one of the address comparisons at L599-L600 matches.
2. STATICCALL `factory.isRaffle(msg.sender)` (L603), made only when `msg.sender` has code (L602).
3. CALL `quoteToken.transfer(msg.sender, amount)`, forwarding all remaining gas with zero value (SafeERC20.sol:L184).

There is no call to the prize contract and no native-value transfer.

**Postconditions on success**

- Every listed ID is nonexistent, so `ownerOf` now reverts for it.
- `remainingRefundLiability` is lower by exactly `amount`.
- The batch is atomic. A revert from any of the following undoes every burn and the debit:
  - ownership (L359-L360)
  - range arithmetic (L363)
  - the debit (L368)
  - the destination screen (L565)
  - the token call (SafeERC20.sol:L34-L36, L189-L191)

---

**Block-by-Block:**

```solidity
// L349
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
```
- **What:** External entry point; `nonReentrant` takes the clone's single guard slot before the body runs.
- **Why here:** The guard covers the whole body, including the token CALL at L369, so it is held while external code runs.
- **Assumes:** The guard slot is not ENTERED.
  - In a fresh clone the slot is 0, because the ReentrancyGuard constructor (L58-L60) ran only in the implementation.
  - `_nonReentrantBeforeView` reverts only when the slot equals `ENTERED == 2` (ReentrancyGuard.sol:L88-L92, L51), so 0 counts as not-entered.
- **Establishes:** No other `nonReentrant` Raffle entry point can run nested inside this call. Those are L212, L240, L276, L304, L309, L349, L375, L385 and L395.
- **Depended on by:** L370. The re-read after the external call returns the L368 value because both writers of `remainingRefundLiability` (L298, L368) sit behind this guard.

```solidity
// L350
_requireStatus(Status.Refunding);
```
- **What:** Reverts with `InvalidStatus(status)` unless the status is `Refunding` (L573-L575, a single branch).
- **Why here:** It comes before any ticket read, so a call in any other state reverts without touching the ledger.
- **Assumes:** For a clone, `Refunding` is entered only at L299, which runs right after L298 initializes the liability in the same call. The full list of status writers:
  - L165: implementation constructor only
  - L205: `initialize`; L177 blocks a second run
  - L252: needs `Active` (L241)
  - L299: needs `Active` or `Drawing` (L279, L289)
  - L428: needs `AwaitingPrize` (L422)
  - L521: needs `Drawing` (L511)

  None of them leaves `Refunding`, so `Refunding` is terminal.
- **Establishes:** `status == Refunding` for the whole call.
  - The guarded writers are locked out by L349.
  - The unguarded writers, L428 (`onERC721Received`) and L521 (`rawFulfillRandomWords` → `fulfillRandomWords`, VRFV2PlusWrapperConsumerBase.sol:L101-L107), require other states.
- **Depended on by:**
  - L368: the liability being debited is the one set at L298.
  - The conservation argument: the only other burn site, L325, is unreachable in `Refunding` because of L312.
- **Note:** The implementation instance also passes this check, since its constructor sets `Refunding` at L165. It then reverts at L359 (see below).

```solidity
// L351-L354
uint256 ticketQuantity = ticketIds.length;
if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
    revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
}
```
- **What:** Bounds the batch to `[1, 100]` (RaffleConstants.sol:L27).
- **Why here:** It runs before the loop. It caps the iteration count and rejects an empty array, which would otherwise reach L368-L371 with `amount == 0` and emit a zero refund.
- **Assumes:** Nothing beyond the constant.
- **Establishes:**
  - 1 ≤ iterations ≤ 100.
  - Combined with L363, a successful call pays at least `ENTRY_PRICE`.
  - Overflow headroom for L363 and L367.
- **Depended on by:** The L357 loop bound and the arithmetic at L363 and L367.

```solidity
// L356-L358
uint256 aggregateEntries = 0;
for (uint256 index; index < ticketQuantity; ++index) {
    uint256 ticketId = ticketIds[index];
```
- **What:** Sets up the accumulator and loops over the calldata array. The compiler bounds-checks each element access. Nothing else happens here.

```solidity
// L359-L360
address owner = ownerOf(ticketId);
if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);
```
- **What:** Checks that the ticket exists and that the caller is its owner.
- **Why here:** It runs before the range read and the burn, and it is the **only existence check on this path**.
  - `ticketRange` (L451-L455) returns `(0,0)` for an ID that was never written (IRaffle.sol:L369).
  - L363 would turn `(0,0)` into one entry: `0 - 0 + 1`.
  - So only the `ownerOf` revert stops never-minted IDs (0, or anything above `ticketCount`) from counting.
- **Assumes:** `ownerOf` reverts for a nonexistent token, and it does.
  - Path: ERC721.sol:L61-L63 → `_requireOwned` L426-L432 → `ERC721NonexistentToken` when `_owners[id] == 0`.
  - Raffle does not override `ownerOf` or `_ownerOf`. The only inherited ERC-721 or VRF implementations it overrides are `name` (L479), `symbol` (L485), `_update` (L497) and `fulfillRandomWords` (L509); its other `override` functions implement IRaffle.
  - Raffle's own `ownerOf` calls are at L320 and L359. L335 and L405 call `prizeToken.ownerOf`, which is a different contract.
- **Establishes:**
  - `owner == msg.sender`, `owner != 0`, and the ticket is live.
  - **Duplicates are rejected.** On a repeated ID, the earlier iteration's L364 has already zeroed `_owners[id]` (ERC721.sol:L240), so this line reverts with `ERC721NonexistentToken`, not `NotTicketOwner`.
- **Depended on by:** L364. **`_burn` does no authorization of its own.** It passes `auth = address(0)` (ERC721.sol:L304), so `_checkAuthorized` at ERC721.sol:L220-L222 is skipped. L360 is the only authorization for destroying the ticket.
- **Implementation instance:** No ticket can ever be minted there, so every call reverts at this line:
  - `buyEntries` requires `Active` (L215).
  - `Active` is entered only at L428, from `AwaitingPrize`.
  - `AwaitingPrize` needs `initialize` (L205), which reverts at L177 because the constructor set `initialized = true` (L164).

```solidity
// L362-L363
(uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
```
- **What:** Reads the stored inclusive range and adds its size to the accumulator, widened to `uint256` with checked arithmetic.
- **Why here:** After the existence and ownership check. Running before the burn does not change the value read: a burn never touches `_ticketRanges` (ERC721.sol:L216-L245 writes only ERC-721 mappings), and L138 documents that ranges are kept.
- **Assumes:** For every live ticket, `lastEntry >= firstEntry >= 1`, and the size equals the `entryCount` that was paid for. `buyEntries` establishes this:
  - `entryCount != 0` (L218).
  - `firstEntry = totalEntries + 1` and `lastEntry = totalEntries + entryCount` (L226-L227).
  - The range is written once (L232), before `_safeMint` (L235).
  - IDs are sequential and fresh (L228, L231). `_mint` would revert on an existing ID (ERC721.sol:L263-L266).
- **Establishes:**
  - `aggregateEntries` is the sum of the entry counts of the distinct tickets processed so far.
  - It cannot overflow: each term is at most 2^128 (`uint128` fields, L37-L38), and there are at most 100 terms (L352).
  - The subtraction cannot underflow for any ticket that passed L359.
- **Depended on by:** L367.

```solidity
// L364
_burn(ticketId);
```
- **What:** Destroys the ticket.
- **Why here:**
  - It sits inside the loop, before the next iteration's `ownerOf`. That ordering is what makes L359 a duplicate detector.
  - It sits before L369, so the effects land before the token call.
- **Assumes:** No external call happens between L359 and L364, and none happens inside `_burn`.
  - Between the two lines, `ticketRange` is an internal view.
  - In `Raffle._update`, the condition `to != address(0)` is evaluated first and short-circuits (L498). So `_isProtocolDestination` and its factory STATICCALLs do not run for burns.
  - `ERC721._update` (ERC721.sol:L216-L245) and `_approve` (L383-L399) only write storage and emit. With `emitEvent=false` and `auth=0`, the `_requireOwned` read is skipped as well.
- **Establishes:**
  - `_owners[id] = 0` and `_tokenApprovals[id] = 0`.
  - `_balances[msg.sender]` is decremented. The decrement is unchecked, but `msg.sender` owns this ID, so its balance is at least 1 (ERC721 balance invariant, ERC721.sol:L141-L145).
  - `_burn`'s own revert (`previousOwner == 0`, ERC721.sol:L305-L307) cannot trigger here, because L359 found a non-zero owner in the same iteration and nothing in between can change it.
- **Depended on by:**
  - L359 in later iterations (duplicate rejection).
  - The system-wide property that each ticket is refunded at most once.
  - Ticket transfers attempted later: `transferFrom` on a burned ID reverts, because `_checkAuthorized` with `owner == 0` reverts `ERC721NonexistentToken` (ERC721.sol:L181-L182).

```solidity
// L367
amount = aggregateEntries * ENTRY_PRICE;
```
- **What:** Converts entries into USDC base units: `ENTRY_PRICE = 1_000_000` (L44; RaffleConstants.sol:L21).
  - The multiplication is checked.
  - The worst case, 100 × 2^128 × 10^6, is below 2^256.
- **Why here:** One multiplication per batch. Integer distributivity, `sum(c_k) * P == sum(c_k * P)`, makes the batch debit equal to the sum of the per-purchase amounts credited at L223/L233. The refund path has no rounding.
- **Establishes:** `amount >= ENTRY_PRICE`.
- **Depended on by:** L368, L369, L371, and the return value.

```solidity
// L368
remainingRefundLiability -= amount;
```
- **What:** A checked debit. The pragma is 0.8.36 (L2) and there is no `unchecked` block, so `amount > remainingRefundLiability` reverts with `Panic(0x11)`.
- **Why here:** After every burn, before the token call.
- **Assumes:** The liability was set at L298 to `totalEntries * ENTRY_PRICE`, and since then it has been debited only for burned tickets (derivation under Invariant couplings). Given that, the subtraction cannot underflow. It is a backstop, not the mechanism that caps payouts; the cap comes from the partition plus single-burn.
- **Establishes:** `remainingRefundLiability == ENTRY_PRICE * (sum of entry counts of still-live tickets)`.
- **Depended on by:**
  - L370-L371
  - `accountedQuoteBalance()` (L469)
  - later `refundTickets` calls

```solidity
// L369
_transferQuote(msg.sender, amount);
```
- **What:** Screens the payee, then transfers USDC.
- **Why here:** It is the last state-changing step. Every burn and the debit are already committed, so anything that ran during the call would see consistent state, and a revert here undoes every effect of the call.
- **Assumes:**
  - (a) `msg.sender` is not a protocol destination. L565 enforces this now.
    - Ticket ownership was screened with the same predicate at mint and transfer time (L498-L500).
    - The predicate has inputs that change over time: `msg.sender.code.length` (L602) and `factory.isRaffle` (L603).
    - The two evaluations therefore happen at different moments.
  - (b) The token transfer succeeds and moves exactly `amount`. **Nothing found** checks the balance change. SafeERC20 looks only at the call's success flag and return data (SafeERC20.sol:L187-L196).
  - (c) The clone's USDC balance is at least `amount`. **Nothing found** on-chain.
- **Establishes:** On success, the token contract has credited `msg.sender`. On failure the whole batch reverts.
- **Depended on by:** Only the event after it.

```solidity
// L370-L371
uint256 liabilityAfter = remainingRefundLiability;
emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
```
- **What:** Re-reads the liability after the external call, then emits the event.
- **Why here / Assumes:** The re-read returns exactly the value written at L368. The only writers are L298 and L368, both `nonReentrant` (L276, L349), and the guard is still held.
- **Establishes:**
  - `ticketQuantity` equals the number of distinct tickets burned, since duplicates revert at L359.
  - `amount == aggregateEntries * ENTRY_PRICE`, which matches the event's NatSpec (IRaffle.sol:L151).

---

**Cross-Function Dependencies:**

Each callee below was read on all of its paths.

- **`nonReentrant`** (external-source-available; ReentrancyGuard.sol:L69-L73, L88-L106)
  - Paths:
    1. Slot `== 2`: reverts `ReentrancyGuardReentrantCall` (L89-L91).
    2. Otherwise: sets 2 (L99), runs the body, sets 1 (L105).
  - Any revert in the body also undoes the slot write.
  - One slot is shared by every `nonReentrant` entry point in the clone.
  - Entry points it does not cover:
    - ERC-721 `transferFrom`, `safeTransferFrom`, `approve`, `setApprovalForAll`
    - `onERC721Received` (L416)
    - `rawFulfillRandomWords` (VRFV2PlusWrapperConsumerBase.sol:L101)
    - `receive` (L171, always reverts)
    - views
  - None of those writes `remainingRefundLiability`.

- **`_requireStatus`** (internal; L573-L575)
  - Two paths: a mismatch reverts with `InvalidStatus(status)`; a match returns.
  - The caller relies on it for `status == Refunding`.

- **`RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE`** (internal constant; RaffleConstants.sol:L27) = 100. It is the loop bound.

- **`ERC721.ownerOf` → `_requireOwned` → `_ownerOf`** (external-source-available; ERC721.sol:L61-L63, L426-L432, L146-L148)
  - Two paths: `_owners[id] == 0` reverts with `ERC721NonexistentToken(id)`; otherwise it returns the non-zero owner.
  - Both never-minted IDs and burned IDs have `_owners == 0` (L240 writes `to = 0` on a burn).
  - The caller depends on it for:
    - ticket existence, which keeps the `(0,0)` default range away from L363;
    - duplicate rejection across iterations.

- **`ticketRange`** (internal; L451-L455)
  - A single path: one packed-slot read.
  - No existence check; returns zeros for keys that were never written.
  - The caller depends on `buyEntries` L232 having written a non-degenerate range for every ID that L359 accepts.

- **`ERC721._burn` → `Raffle._update` override → `ERC721._update` → `ERC721._approve`** (L497-L502 is internal; ERC721.sol:L303-L308, L216-L245, L383-L399 are external-source-available)
  - `Raffle._update` (L497-L502): `to == 0`, so the screen at L498 short-circuits, then it calls `super._update`.
  - `ERC721._update`, step by step:
    - `from = _owners[id]` (L217).
    - `auth == 0`, so the authorization check is skipped (L220-L222).
    - `from != 0`, so `_approve(0, id, 0, false)` runs (L227). With `emitEvent=false` and `auth=0` it skips the owner read (L385) and sets `_tokenApprovals[id] = 0` (L398).
    - `_balances[from] -= 1`, unchecked (L229-L231).
    - `to == 0`, so there is no balance increment (L234-L238).
    - `_owners[id] = 0` (L240).
    - `emit Transfer` (L242).
    - Returns `from` (L244).
  - Back in `_burn`: the `previousOwner == 0` revert (L305-L307) cannot trigger after L359.
  - The caller depends on it for:
    - zeroing ownership, which is the duplicate guard;
    - **no external call and no authorization**, the latter supplied only by L360.

- **`_transferQuote`** (internal; L564-L567)
  - Path 1: `_isProtocolDestination(to, prizeToken)` is true, so it reverts with `InvalidQuoteDestination(to)`.
  - Path 2: `quoteToken.safeTransfer(to, amount)`.
  - The caller relies on it to screen the payee and to revert on a failed transfer.

- **`_isProtocolDestination`** (internal; L593-L605)
  - Path a: any comparison at L599-L600 matches (this contract, the factory, quoteToken, the VRF wrapper, prizeToken). Returns true with no external call.
  - Path b: otherwise, a STATICCALL to `raffleImplementation()` (L601) and a comparison.
  - Path c: if still false and `destination.code.length != 0` (L602), a STATICCALL to `isRaffle(destination)` (L603).
  - Code-less destinations are never checked against the registry.
  - The caller relies on it to keep USDC away from protocol plumbing and other raffle clones, as DESIGN.md:L2 requires: "Never move assets between raffle clones".

- **`IRaffleFactory.raffleImplementation()` / `isRaffle(address)`** (external-source-available; RaffleFactory.sol:L42 immutable set at L91, and L54 mapping set at L125; both `view` per IRaffleFactory.sol:L130, L139, so they are STATICCALLs)
  - Trusted factory.
  - `isRaffle` changes from false to true when a new clone is registered.

- **`SafeERC20.safeTransfer` → `_safeTransfer(bubble=true)`** (external-source-available; SafeERC20.sol:L33-L37, L176-L200)

  | Token call behaviour | Result |
  | --- | --- |
  | Succeeds and the first returned word `== 1` | Success |
  | Reverts | Revert data bubbled (L189-L191) |
  | Succeeds and returns data that is not `true` | Not successful → `SafeERC20FailedOperation` (L34-L36) |
  | Succeeds with empty return data, token has code | Success (L196) |
  | Succeeds with empty return data, token has no code | Not successful → `SafeERC20FailedOperation` |

  - What the caller can rely on: if it does not revert, the token call did not revert and returned true or nothing.
  - What the caller cannot rely on: that the balance actually moved by `amount`.

- **`quoteToken.transfer(msg.sender, amount)`** (external-black-box; canonical USDC, a trusted actor)
  - What is sent: the `transfer(address,uint256)` selector, `(msg.sender, amount)`, all remaining gas, zero value.
  - Outcomes the code does not rule out:
    - a revert (insufficient balance, blacklisted sender or recipient, pause)
    - a `false` return
    - a successful return that moves a different amount
  - If USDC (which is trusted) did call back into the clone:
    - Every `nonReentrant` entry point reverts.
    - The unguarded entry points cannot reach the state touched here:
      - Ticket transfers of burned IDs revert (ERC721.sol:L181-L182).
      - `onERC721Received` needs `AwaitingPrize` (L422).
      - `fulfillRandomWords` ignores calls outside `Drawing` (L511).

**Callers:**

- Nothing calls it internally. `refundTickets` appears only at Raffle.sol L349 and IRaffle.sol:L344, and RaffleFactory.sol does not call it.
- It is reached externally by any EOA or contract that currently owns every listed ticket.
- Callers rely on three things:
  - the batch is atomic (IRaffle.sol:L341);
  - each entry is paid at full value;
  - the payout goes to the caller.

**Shared state:**

- `remainingRefundLiability`
  - Written at L298 (`enableRefunds`) and L368 (here).
  - Read by `accountedQuoteBalance()` (L469) and at L370.
- ERC-721 ledger (`_owners`, `_balances`, `_tokenApprovals`)
  - Written by `buyEntries` via `_safeMint` (L235) and by `redeemWinningTicket` via `_burn` (L325).
  - Written by the inherited `transferFrom` / `safeTransferFrom` / `approve`, with every non-zero recipient screened at L498.
  - Written by `_burn` here.
- `_ticketRanges`
  - Written only at L232.
  - Read here at L362 and by `_requireWinningTicket` at L580, which runs only in `NftWon|CashWon` (L536).
- `status`: read at L350; writers listed under L350.
- The clone's USDC balance (inside the quote-token contract)
  - Credited at L224.
  - Debited at L342, L369, L380, L390. Only L369 is reachable in `Refunding`.
  - Also credited by unsolicited third-party transfers, which create no liability and have no exit.
- The reentrancy-guard slot, shared with every `nonReentrant` entry point.
- The factory registry (`isRaffle`, `raffleImplementation`), read through L565.

**Invariant couplings:**

1. **Refund conservation.** Each ingredient, with where it is established:
   - (a) Ticket `k` covers `[T_{k-1}+1, T_{k-1}+c_k]` with `c_k >= 1`, and IDs are sequential.
     - `T_k` is `totalEntries` after purchase `k`.
     - Evidence: L218, L226-L227, L230, L228, L231, L232.
     - `buyEntries` holds `nonReentrant` (L212) and writes all state (L230-L233) before the `_safeMint` callback (L235), so purchases cannot interleave.
     - Overflow of `totalEntries` is blocked at L219-L220.
   - (b) While `Active` or `Drawing`, `unsettledPot == totalEntries * ENTRY_PRICE`.
     - Evidence: L223, L230, L233.
     - `unsettledPot` has two other writers: L297 moves the clone into `Refunding`, and L553 requires `NftWon|CashWon` (L536).
   - (c) `remainingRefundLiability := unsettledPot`, exactly once (L296-L298). A second `enableRefunds` reverts in `Refunding` (L292-L293).
   - (d) No ticket is burned before `Refunding`.
     - Burn sites: L325 is gated to `NftWon|CashWon` (L312); L364 is gated to `Refunding` (L350).
     - `NftWon|CashWon` can never move to `Refunding` (L292-L293).
   - (e) Each ticket is burned at most once (L364, then L359).
   - (f) Each ticket's refund term equals `c_k` (L363), and the batch debit is `sum(c_k) * P` (L367).

   Together these give `remainingRefundLiability == P * sum over live tickets of c_k` after every successful call. The liability reaches 0 exactly when all tickets are burned, and L368 cannot underflow.

   The premise "ranges partition `[1, totalEntries]`" is established by `buyEntries` alone. A grep finds no other writer of `_ticketRanges`, `totalEntries` or `ticketCount`, and no `delete`.

2. **Solvency in `Refunding`.**
   - In this state `accountedQuoteBalance()` (L469) reduces to `remainingRefundLiability`:
     - `unsettledPot` was zeroed at L297.
     - `winnerProceeds`, `sponsorProceeds` and `protocolFees` are set non-zero only at L548, L554 and L555, behind L536.
   - The USDC backing it comes from L224, whose balance change is not checked.
   - Solvency therefore rests on the trusted fee-free, non-rebasing USDC model. No on-chain comparison of balance against liability exists.

3. **Liability that is never claimed.**
   - `remainingRefundLiability` falls only at L368, and only when `msg.sender` is the current owner (L360).
   - There is no deadline (no timestamp read) and no sweep or admin path (L24-L25).
   - A ticket whose holder never calls `refundTickets` leaves its `c_k * P` outstanding indefinitely, with the matching USDC held by the clone. Two kinds of holder visible in the code:
     - Contracts that received tickets through `_safeMint` or `safeTransferFrom` and have no code path that calls `refundTickets` or transfers the ticket on.
     - An address that received a ticket while it had no code and later became a registered clone:
       - `_isProtocolDestination` skips the registry query for code-less addresses (L602).
       - Clones are deployed with CREATE (Clones.sol:L57) by the factory (RaffleFactory.sol:L106) and registered at RaffleFactory.sol:L125.
       - Raffle code contains no call to another raffle's `refundTickets`.

4. **Payout screen versus ownership screen.**
   - The same predicate runs at mint/transfer time (L498) and at payout (L565).
   - To pass L360 but fail L565, `msg.sender` would have to own a ticket and be a protocol destination right now.
   - The prize token can never own a ticket:
     - It is compared on every `_update` with a non-zero recipient (L600).
     - It is set at L200, before any mint is possible.
   - The other protocol addresses never call `refundTickets`:
     - The factory, the implementation and the clones are in-repo, and none contains a call to it (RaffleFactory.sol:L97-L148; Raffle.sol has no self-call).
     - quoteToken and the VRF wrapper are trusted actors.
   - On this path, L565 is a backstop.

5. **`releaseSponsorPrize`** (L395-L407) can also be called in `Refunding` (L397).
   - It calls the untrusted prize contract (L404-L405) while holding the same guard, so a re-entrant `refundTickets` from that call reverts at L349.
   - The prize contract cannot pass L360 in a separate call either, because it can never own a ticket (point 4).
   - Prize return and refunds share no state other than the guard: `prizeClaimed` on one side, the ticket ledger and the liability on the other.

6. **Transferability.**
   - `_update` (L497-L502) has no status gate, so tickets stay transferable during `Refunding` until they are burned.
   - The right to refund belongs to whoever owns the ticket at L359, when the call executes.
   - An approved operator can move a ticket to itself and then refund as the owner.

---

**Open Questions:**

- unclear; need to inspect the target chain's USDC implementation (not in this repository) to know when `transfer(msg.sender, amount)` reverts or returns false: blacklist of the sender or the recipient, pause, or anything else.
  - Any such outcome at L369 either bubbles up (SafeERC20.sol:L189-L191) or reverts with `SafeERC20FailedOperation` (L34-L36).
  - Either way, the burns at L364 roll back.
  - The holder's only on-chain alternative is to transfer the ticket to another address (`_update` L497-L502 does not gate on status) and refund from there.
