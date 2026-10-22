## `buyEntries` in packages/contracts/src/Raffle.sol (L209-L237)

**Purpose:** Sells a positive number of fixed-price entries during the active sale window, pulls the corresponding quote-token payment (`entryCount * ENTRY_PRICE`) from `msg.sender`, records a contiguous 1-based inclusive entry range `[firstEntry, lastEntry]` under a new sequential `ticketId`, increments `totalEntries`, `ticketCount`, and `unsettledPot`, and safe-mints the representing ERC-721 range ticket to `recipient`. Every downstream draw request (`requestDraw`), randomness resolution (`fulfillRandomWords`), winning-ticket proof (`_requireWinningTicket`), settlement (`_settleWinningTicket`), and refund calculation (`enableRefunds`, `refundTickets`) depends on the contiguous range partition and pot accounting created here.

---

**Inputs & Assumptions:**
- `recipient` (`address`): Prospective owner of the newly minted ERC-721 range ticket. Trust: **untrusted** (supplied by an arbitrary external caller).
- `entryCount` (`uint128`): Number of raffle entries to purchase and assign to the minted ticket. Trust: **untrusted** (supplied by an arbitrary external caller).
- Implicit inputs:
  - `msg.sender` (`address`): Quote-token payer (`Raffle.sol:L224, L236`) and ERC-721 safe-mint `operator` (`ERC721.sol:L289`, `Context.sol:L17-L19`). Trust: **untrusted**.
  - `block.timestamp` (`uint256`): Current block timestamp compared against `endTime` (`Raffle.sol:L216`).
  - `status` (`IRaffle.Status`, `Raffle.sol:L124`): Current lifecycle status, required to be `Status.Active` (`Raffle.sol:L215, L573-L575`).
  - `endTime` (`uint64`, `Raffle.sol:L82`): Exclusive sale-end timestamp initialized once in `initialize` (`Raffle.sol:L204`).
  - `totalEntries` (`uint128`, `Raffle.sol:L85`): Cumulative entries sold across all prior purchases in this clone.
  - `ticketCount` (`uint128`, `Raffle.sol:L88`): Cumulative tickets minted across all prior purchases in this clone.
  - `unsettledPot` (`uint256`, `Raffle.sol:L91`): Cumulative raw quote-token units collected during `Status.Active`.
  - `quoteToken` (`IERC20`, immutable, `Raffle.sol:L58, L162`): Quote ERC-20 token contract pulled via `safeTransferFrom` (`Raffle.sol:L224`). Trust: **trusted** per system model (`RaffleFactory.sol:L59-L62`).
  - `prizeToken` (`IERC721`, `Raffle.sol:L70, L200`) and `factory` (`address`, immutable, `Raffle.sol:L55, L161`): Read during `_isProtocolDestination` when minting the ticket (`Raffle.sol:L498, L598-L604`).
  - `REENTRANCY_GUARD_STORAGE` (`bytes32`, `ReentrancyGuard.sol:L36-L37`): ERC-7201 storage slot checked and mutated by `nonReentrant` (`Raffle.sol:L212`, `ReentrancyGuard.sol:L69-L73`).
- Preconditions:
  - Reentrancy lock is not currently in `ENTERED` (`2`) state. Enforced by `nonReentrant` (`Raffle.sol:L212` -> `ReentrancyGuard.sol:L88-L100, L112-L114`). On a fresh ERC-1167 clone, the slot is `0` (`!= ENTERED`), which passes `_reentrancyGuardEntered()` (`ReentrancyGuard.sol:L113`), transitions to `ENTERED` (`2`) during execution (`ReentrancyGuard.sol:L99`), and resets to `NOT_ENTERED` (`1`) afterward (`ReentrancyGuard.sol:L105`).
  - `status == Status.Active`. Enforced by `_requireStatus(Status.Active)` at `Raffle.sol:L215, L573-L575`.
  - `block.timestamp < endTime`. Enforced at `Raffle.sol:L216`.
  - `recipient != address(0)`. Enforced at `Raffle.sol:L217` (and redundantly in `ERC721._mint` at `ERC721.sol:L260-L262`).
  - `recipient` is not a rejected protocol address (`address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `address(prizeToken)`, `IRaffleFactory(factory).raffleImplementation()`, or any contract with `recipient.code.length != 0` where `IRaffleFactory(factory).isRaffle(recipient)` is true). Enforced during `_safeMint` via `Raffle._update` -> `Raffle._isProtocolDestination` (`Raffle.sol:L235, L498-L500, L593-L605`).
  - `entryCount > 0`. Enforced at `Raffle.sol:L218`.
  - `uint256(totalEntries) + uint256(entryCount) <= type(uint128).max`. Enforced by `entryCount <= type(uint128).max - totalEntries` at `Raffle.sol:L219-L221`.
  - `ticketCount < type(uint128).max` prior to `++ticketCount` at `Raffle.sol:L231`. Not checked directly on `ticketCount`, but established inductively because `ticketCount` and `totalEntries` both start at `0`, only `buyEntries` mutates either (`Raffle.sol:L230-L231`), each call requires `entryCount >= 1` (`Raffle.sol:L218`) so `ticketCount <= totalEntries` always holds, and `Raffle.sol:L219-L221` together with `entryCount >= 1` guarantees `totalEntries <= type(uint128).max - 1` before `L230-L231`.
  - `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` increases `quoteToken.balanceOf(address(this))` by at least `grossAmount` (`uint256(entryCount) * ENTRY_PRICE`) without transfer fees, rebasing, or balance loss. `RaffleFactory.constructor` only checks `_requireContract(quoteToken_)` and `IERC20Metadata(quoteToken_).decimals() == 6` (`RaffleFactory.sol:L66, L70-L78`); no on-chain balance delta check exists (`nothing found` in code; relies on trusted `quoteToken_` deployment input).

---

**Outputs & Effects:**
- Return value:
  - `ticketId` (`uint256`): Sequential 1-based identifier of the newly minted ticket, equal to the post-increment `uint256(ticketCount)` (`Raffle.sol:L228, L231`).
- State writes:
  - `totalEntries` (`Raffle.sol:L230`): Updated from prior `totalEntries` to `lastEntry = totalEntries + entryCount`.
  - `ticketCount` (`Raffle.sol:L231`): Incremented by `1` (`++ticketCount`).
  - `_ticketRanges[ticketId]` (`Raffle.sol:L232`): Set to `TicketRange({ firstEntry: totalEntries_before + 1, lastEntry: totalEntries_before + entryCount })`.
  - `unsettledPot` (`Raffle.sol:L233`): Incremented by `grossAmount = uint256(entryCount) * ENTRY_PRICE`.
  - `_balances[recipient]` (`ERC721.sol:L236` via `_safeMint` at `Raffle.sol:L235`): Incremented by `1` inside `unchecked` block (unless modified further during `recipient.onERC721Received`).
  - `_owners[ticketId]` (`ERC721.sol:L240` via `_safeMint` at `Raffle.sol:L235`): Set to `recipient` (unless transferred further during `recipient.onERC721Received`).
  - `REENTRANCY_GUARD_STORAGE` (`ReentrancyGuard.sol:L99, L105`): Set to `ENTERED` (`2`) on entry and `NOT_ENTERED` (`1`) on exit.
- External interactions:
  1. `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` (`Raffle.sol:L224` -> `SafeERC20.sol:L43-L47, L212-L244`): Low-level `call` to `quoteToken` with `IERC20.transferFrom.selector(msg.sender, address(this), grossAmount)`. Happens **before** `Raffle` state mutations (`L230-L233`) and ticket minting (`L235`), while `nonReentrant` is active.
  2. `IRaffleFactory(factory).raffleImplementation()` (`Raffle.sol:L601`) and conditionally `IRaffleFactory(factory).isRaffle(recipient)` (`Raffle.sol:L603`): `staticcall`s to immutable `factory` inside `_isProtocolDestination` during `Raffle._update` (`Raffle.sol:L498`).
  3. `IERC721Receiver(recipient).onERC721Received(msg.sender, address(0), ticketId, "")` (`ERC721Utils.sol:L33` via `ERC721._safeMint` at `Raffle.sol:L235`): External `call` to untrusted `recipient` if and only if `recipient.code.length > 0` (`ERC721Utils.sol:L32`). Happens **after** all storage writes (`Raffle.sol:L230-L233`, `ERC721.sol:L236, L240`) and the ERC-721 `Transfer` event (`ERC721.sol:L242`), and **before** `emit TicketPurchased(...)` (`Raffle.sol:L236`).
- Events emitted:
  - `IERC721.Transfer(address(0), recipient, ticketId)` (`ERC721.sol:L242`).
  - `IRaffle.TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount)` (`Raffle.sol:L236`).
- Postconditions (on non-reverting return):
  - `totalEntries == lastEntry >= firstEntry >= 1`.
  - `ticketId == uint256(ticketCount)` (for the state at the end of `_safeMint`).
  - `_ticketRanges[ticketId] == TicketRange({ firstEntry, lastEntry })` with `lastEntry - firstEntry + 1 == entryCount`.
  - `unsettledPot == uint256(totalEntries) * ENTRY_PRICE == grossSales()`.

---

**Block-by-Block:**

```solidity
// L209-L214
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
```
- **What:** Entrypoint declaration with the `nonReentrant` guard (`ReentrancyGuard.sol:L69-L73`).
- **Why here:** Acquires the reentrancy lock (`REENTRANCY_GUARD_STORAGE = ENTERED`) before any state read, external call to `quoteToken`, or callback to `recipient.onERC721Received`.
- **Assumes:** No `nonReentrant` function on this `Raffle` clone is currently on the call stack (`ReentrancyGuard.sol:L89-L90`).
- **Establishes:** None of the `nonReentrant` functions on this `Raffle` clone (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) can be re-entered until `buyEntries` finishes (`ReentrancyGuard.sol:L99, L105`). Does **not** block inherited `ERC721` functions (`transferFrom`, `safeTransferFrom`, `approve`, `setApprovalForAll`) which lack `nonReentrant` (`ERC721.sol:L93-L136`).
- **Depended on by:** External calls at `L224` (`quoteToken.safeTransferFrom`) and `L235` (`_safeMint` -> `onERC721Received`).

```solidity
// L215-L221
_requireStatus(Status.Active);
if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
if (recipient == address(0)) revert InvalidRecipient();
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}
```
- **What:** Validates lifecycle state, sale window, non-zero recipient, positive entry count, and `uint128` cumulative entry bound.
- **Why here:** Fail-fast validation before computing payment or performing the external `quoteToken` transfer.
- **Assumes:** `endTime` and `status` were set through `initialize` (`Raffle.sol:L204-L205`) and `onERC721Received` (`Raffle.sol:L428`).
- **Establishes:**
  - `status == Status.Active` (`L215`, `L573-L575`).
  - `block.timestamp < endTime` (`L216`).
  - `recipient != address(0)` (`L217`).
  - `entryCount >= 1` (`L218`).
  - `uint256(totalEntries) + uint256(entryCount) <= type(uint128).max` (`L219-L221`), which together with `entryCount >= 1` guarantees `totalEntries < type(uint128).max` prior to mutation.
- **Depended on by:** Arithmetic at `L223, L226-L233` and minting at `L235`.

```solidity
// L223-L224
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```
- **What:** Computes the raw 6-decimal quote-token cost (`entryCount * 1_000_000`) and pulls it from `msg.sender` into `address(this)`.
- **Why here:** Collects payment after input validation and before mutating raffle storage or minting the ticket.
- **Assumes:** `quoteToken` is a standard, non-rebasing, fee-free ERC-20 token whose `transferFrom` credits `address(this)` with `grossAmount` and does not execute untrusted hooks. `uint256(entryCount) * ENTRY_PRICE` cannot overflow `uint256` because `entryCount <= type(uint128).max` and `ENTRY_PRICE == 1_000_000` (`RaffleConstants.sol:L21`).
- **Establishes:** `quoteToken.transferFrom(msg.sender, address(this), grossAmount)` succeeded (and returned `true` or empty returndata on a contract with code, per `SafeERC20.sol:L227-L239`).
- **Depended on by:** `unsettledPot += grossAmount` at `L233`, and later payout solvency in `refundTickets` (`L367-L369`), `redeemWinningTicket` (`L339-L342`), `releaseSponsorProceeds` (`L376-L380`), and `releaseProtocolFees` (`L386-L390`).

```solidity
// L226-L233
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```
- **What:** Computes the 1-based inclusive `[firstEntry, lastEntry]` range and next sequential `ticketId`, then updates `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot`.
- **Why here:** All internal state mutations are committed before `_safeMint` invokes `onERC721Received` on an untrusted contract `recipient` at `L235`.
- **Assumes:**
  - `totalEntries + 1` and `totalEntries + entryCount` do not overflow `uint128` (established by `L218` and `L219-L221`).
  - `++ticketCount` does not overflow `uint128` (established inductively because `ticketCount <= totalEntries <= type(uint128).max - 1` prior to `L230-L231`).
  - `unsettledPot + grossAmount` does not overflow `uint256` (established because `unsettledPot == uint256(totalEntries) * ENTRY_PRICE <= uint256(type(uint128).max) * 1_000_000 < 2^148`).
- **Establishes:**
  - `1 <= firstEntry <= lastEntry == totalEntries` (`L226-L227, L230`).
  - `lastEntry - firstEntry + 1 == entryCount` (`L226-L227`).
  - `_ticketRanges[1..ticketCount]` partitions `[1, totalEntries]` into contiguous, disjoint inclusive ranges (`L226-L232`).
  - `unsettledPot == uint256(totalEntries) * ENTRY_PRICE` while in `Status.Active` (`L223, L230, L233`).
- **Depended on by:** `_safeMint(recipient, ticketId)` (`L235`), `requestDraw` (`L243`), `enableRefunds` (`L280, L296-L298`), `fulfillRandomWords` (`L518, L521`), `_requireWinningTicket` (`L580-L584`), `_settleWinningTicket` (`L538-L549`), and `refundTickets` (`L362-L368`).

```solidity
// L235-L236
_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```
- **What:** Mints `ticketId` to `recipient`, screens `recipient` against `_isProtocolDestination` in `Raffle._update`, invokes `IERC721Receiver(recipient).onERC721Received` if `recipient.code.length > 0`, and emits `TicketPurchased`.
- **Why here:** Placed after all state updates (`L230-L233`) so `recipient`'s `onERC721Received` callback observes consistent raffle accounting and ticket ownership.
- **Assumes:** `ticketId` has not previously been minted (`_owners[ticketId] == address(0)`, established because `ticketId = uint256(ticketCount) + 1` strictly increases and only `buyEntries` mints tickets).
- **Establishes:**
  - `recipient` is not a currently identifiable protocol destination (`Raffle.sol:L498-L500, L593-L605`).
  - `ticketId` is minted to `recipient` (`ERC721.sol:L236, L240`), although if `recipient.code.length > 0`, `recipient.onERC721Received` may transfer or approve `ticketId` (via `ERC721.transferFrom` / `safeTransferFrom` / `approve` / `setApprovalForAll`, which are not `nonReentrant`) before `TicketPurchased` is emitted at `L236`.
- **Depended on by:** `redeemWinningTicket` (`Raffle.sol:L320, L325`) and `refundTickets` (`Raffle.sol:L359, L364`), which check `ownerOf(ticketId)` and `_burn(ticketId)`.

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` / `_nonReentrantBefore` / `_nonReentrantAfter` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73, L88-L118` and `StorageSlot.sol:L93-L97`):**
  - Reads `StorageSlot.getUint256Slot(REENTRANCY_GUARD_STORAGE).value` and reverts with `ReentrancyGuardReentrantCall()` if the value equals `ENTERED` (`2`) (`ReentrancyGuard.sol:L89-L90, L113`).
  - Sets the slot to `ENTERED` (`2`) before the function body (`L99`) and to `NOT_ENTERED` (`1`) after (`L105`).
  - Because `Raffle` clones are created with `Clones.clone` (`RaffleFactory.sol:L106`), the slot starts at `0` rather than `NOT_ENTERED` (`1`), which still satisfies `value != ENTERED` (`0 != 2`) on the first call.
  - Guards only functions carrying `nonReentrant` on the same clone; does not guard `ERC721` transfer/approval functions (`ERC721.sol:L93-L136`) or calls to other clones.
- **Callee `Raffle._requireStatus` (internal, `packages/contracts/src/Raffle.sol:L573-L575`):**
  - Reverts with `InvalidStatus(status)` on the single path where `status != expected` (`L574`); returns on `status == Status.Active`.
- **Callee `SafeERC20.safeTransferFrom` / `_safeTransferFrom` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L47, L212-L244`) and `IERC20(quoteToken).transferFrom` (external-black-box, invoked at `SafeERC20.sol:L227`):**
  - Performs a low-level `call` to `quoteToken` with `IERC20.transferFrom(msg.sender, address(this), grossAmount)` (`SafeERC20.sol:L221-L227`).
  - Reverts on call failure (bubbling revert data at `L232-L235`) or if the call Neither returns `true` (`eq(mload(0x00), 1)` at `L230`) Nor returns empty data on an address with `extcodesize(token) > 0` (`L239`, reverting with `SafeERC20FailedOperation(address(token))` at `L45`).
  - Does not verify that `quoteToken.balanceOf(address(this))` increased by `grossAmount`; `buyEntries` relies on `quoteToken` being a standard, fee-free, non-rebasing token.
- **Callee `ERC721._safeMint` -> `ERC721._mint` -> `Raffle._update` -> `Raffle._isProtocolDestination` -> `ERC721._update` -> `ERC721Utils.checkOnERC721Received` (internal & external-source-available, `ERC721.sol:L216-L245, L259-L267, L279-L290`, `Raffle.sol:L497-L502, L593-L605`, `ERC721Utils.sol:L25-L49`):**
  - `ERC721._mint` (`ERC721.sol:L259-L267`): Checks `to != address(0)` (`L260`), calls `Raffle._update(to, tokenId, address(0))` (`L263`), and verifies `previousOwner == address(0)` (`L264`).
  - `Raffle._update` (`Raffle.sol:L497-L502`): When `to != address(0)`, calls `_isProtocolDestination(to, address(prizeToken))` (`L498`) and reverts with `UnsafeProtocolDestination(to)` (`L499`) if true.
  - `Raffle._isProtocolDestination` (`Raffle.sol:L593-L605`): Checks `destination == address(this) || destination == factory || destination == address(quoteToken) || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_ || destination == canonicalFactory.raffleImplementation()` (`L599-L601`). Only when `!unsafeDestination && destination.code.length != 0` (`L602`) does it query `canonicalFactory.isRaffle(destination)` (`L603`). Note that an address with `code.length == 0` at the time of `buyEntries` (such as a not-yet-deployed counterfactual contract or future `CREATE` clone address of `RaffleFactory`) takes the `destination.code.length == 0` branch and is not rejected.
  - `ERC721._update` (`ERC721.sol:L216-L245`): Increments `_balances[to]` unchecked (`L236`), sets `_owners[tokenId] = to` (`L240`), and emits `Transfer(address(0), to, tokenId)` (`L242`).
  - `ERC721Utils.checkOnERC721Received` (`ERC721Utils.sol:L25-L49`): Two paths:
    1. `to.code.length == 0` (`L32`): Returns immediately without making an external call.
    2. `to.code.length > 0` (`L32-L48`): Calls untrusted `IERC721Receiver(to).onERC721Received(msg.sender, address(0), ticketId, "")` (`L33`) and requires the return value to equal `IERC721Receiver.onERC721Received.selector` (`L34-L36`). During this external call, untrusted code in `recipient` executes after all `buyEntries` state writes have landed (`Raffle.sol:L230-L233`, `ERC721.sol:L236, L240`) and while `nonReentrant` is active, but before `TicketPurchased` is emitted (`Raffle.sol:L236`).
- **Callers:**
  - External entrypoint (`Raffle.sol:L209`); no internal callers within `Raffle` or `RaffleFactory`.
- **Shared State:**
  - `status` (`Raffle.sol:L124`): Written by `constructor` (`L165`), `initialize` (`L205`), `onERC721Received` (`L428`), `requestDraw` (`L252`), `enableRefunds` (`L299`), and `fulfillRandomWords` (`L521`); read by `buyEntries` (`L215` via `_requireStatus`).
  - `endTime` (`Raffle.sol:L82`): Written by `initialize` (`L204`); read by `buyEntries` (`L216`), `requestDraw` (`L242`), `enableRefunds` (`L281`), and `drawRequestDeadline` (`L459`).
  - `totalEntries` (`Raffle.sol:L85`): Written only by `buyEntries` (`L230`); read by `buyEntries` (`L219, L226-L227`), `requestDraw` (`L243`), `enableRefunds` (`L280`), `grossSales` (`L474`), and `fulfillRandomWords` (`L518, L521`).
  - `ticketCount` (`Raffle.sol:L88`): Written only by `buyEntries` (`L231`); read by `buyEntries` (`L228`).
  - `_ticketRanges` (`Raffle.sol:L139`): Written only by `buyEntries` (`L232`); read by `ticketRange` (`L452-L454`), which is called by `refundTickets` (`L362`) and `_requireWinningTicket` (`L580`).
  - `unsettledPot` (`Raffle.sol:L91`): Incremented by `buyEntries` (`L233`); zeroed and moved into `remainingRefundLiability` by `enableRefunds` (`L296-L298`) or into `winnerProceeds` / `sponsorProceeds` / `protocolFees` by `_settleWinningTicket` (`L539-L555`); read by `accountedQuoteBalance` (`L469`).
  - `ERC721._owners` and `ERC721._balances` (`ERC721.sol:L28-L30`): Written by `ERC721._update` (`ERC721.sol:L230, L236, L240`) during `buyEntries` (`Raffle.sol:L235`), `redeemWinningTicket` (`Raffle.sol:L325`), `refundTickets` (`Raffle.sol:L364`), and ERC-721 transfers (`ERC721.sol:L115-L136`).
- **Invariant Couplings:**
  - **Range partition invariant:** `fulfillRandomWords` selects `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)` in `[1, totalEntries]` (`Raffle.sol:L518`). Existence and uniqueness of a `ticketId` satisfying `_requireWinningTicket` (`selectedEntry >= firstEntry && selectedEntry <= lastEntry`, `Raffle.sol:L580-L584`) depends directly on `buyEntries` partitioning `[1, totalEntries]` into contiguous, non-overlapping, non-empty intervals `[firstEntry, lastEntry]` (`Raffle.sol:L218, L226-L232`).
  - **Quote-token solvency invariant:** `enableRefunds` sets `remainingRefundLiability = unsettledPot` (`Raffle.sol:L296-L298`), and `refundTickets` pays `(uint256(lastEntry) - uint256(firstEntry) + 1) * ENTRY_PRICE` per burned ticket while decrementing `remainingRefundLiability` (`Raffle.sol:L362-L368`). Solvency of all ticket refunds and terminal settlements (`_settleWinningTicket` at `Raffle.sol:L539-L555`) depends on `buyEntries` adding `uint256(entryCount) * ENTRY_PRICE == (uint256(lastEntry) - uint256(firstEntry) + 1) * ENTRY_PRICE` to `unsettledPot` (`Raffle.sol:L223, L226-L227, L233`) and on `quoteToken.safeTransferFrom` (`Raffle.sol:L224`) delivering that exact balance to `address(this)`.

---

**Open Questions:**
- None; all callees and state couplings in scope have been inspected in source (`quoteToken` and `recipient` runtime code are external to the repository and documented under assumptions and external calls).
