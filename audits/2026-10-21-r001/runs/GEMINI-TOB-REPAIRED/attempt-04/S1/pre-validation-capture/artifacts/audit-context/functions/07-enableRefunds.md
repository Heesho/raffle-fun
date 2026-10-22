## `enableRefunds` in packages/contracts/src/Raffle.sol (L276-L301)

**Purpose:** Transitions an active or drawing raffle into the terminal `Status.Refunding` state once its applicable liveness deadline has been reached (or prior to `endTime` if called by `sponsor` while `totalEntries == 0`), and moves `unsettledPot` into `remainingRefundLiability`. Without this function, buyer quote tokens in `unsettledPot` and the sponsor's escrowed prize NFT (`prizeToken`, `prizeTokenId`) would remain permanently locked whenever a raffle sells zero entries, fails to receive a `requestDraw` call before `drawRequestDeadline()`, or fails to receive a valid VRF callback before `callbackDeadline()`.

---

**Inputs & Assumptions:**
- Explicit parameters: None (`L276`).
- Implicit inputs:
  - `msg.sender` (`address`): external caller. Trust: **untrusted** — permissionless for all deadline-expiry paths (`L282`, `L287`, `L291`), or checked against `sponsor` for pre-`endTime` empty-raffle cancellation (`L282`).
  - `block.timestamp` (`uint256`): current block Unix timestamp in seconds (`L282`, `L287`, `L291`). Trust: **trusted** (EVM environment clock).
  - `status` (`IRaffle.Status`, `packages/contracts/src/Raffle.sol:L124`): current lifecycle state read at `L279`, `L289`, and `L293`.
  - `totalEntries` (`uint128`, `packages/contracts/src/Raffle.sol:L85`): cumulative sold entry count read at `L280`.
  - `endTime` (`uint64`, `packages/contracts/src/Raffle.sol:L82`): exclusive sale-end timestamp read directly at `L281` and via `drawRequestDeadline()` at `L286` (`L459`).
  - `sponsor` (`address`, `packages/contracts/src/Raffle.sol:L61`): raffle creator address read at `L282`.
  - `drawRequestedAt` (`uint64`, `packages/contracts/src/Raffle.sol:L112`): VRF request timestamp read via `callbackDeadline()` at `L290` (`L464`).
  - `unsettledPot` (`uint256`, `packages/contracts/src/Raffle.sol:L91`): unallocated quote-token proceeds read at `L296`.
  - `REENTRANCY_GUARD_STORAGE` (`bytes32`, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L36-L37`): reentrancy lock slot read and written by the `nonReentrant` modifier (`L69-L73`, `L88-L106`).
- Preconditions:
  - Reentrancy lock is not in the `ENTERED` (`2`) state. Enforced at entry by `ReentrancyGuard.nonReentrant` (`ReentrancyGuard.sol:L69-L73`, `L88-L100`).
  - `status` is either `Status.Active` or `Status.Drawing`. Enforced at `L279-L294`; any other status reverts with `InvalidStatus(status)` at `L293`.
  - Depending on state, the applicable time or caller gate holds:
    - If `status == Status.Active` and `totalEntries == 0`: `msg.sender == sponsor || block.timestamp >= endTime`. Enforced at `L280-L284`.
    - If `status == Status.Active` and `totalEntries != 0`: `block.timestamp >= drawRequestDeadline()`. Enforced at `L285-L288`.
    - If `status == Status.Drawing`: `block.timestamp >= callbackDeadline()`. Enforced at `L289-L291`.
  - Assumption: Whenever `status == Status.Drawing`, `drawRequestedAt != 0`, so that `callbackDeadline()` (`L462-L465`) takes its `drawRequestedAt != 0` branch (`L464`) and returns `uint256(drawRequestedAt) + 2 days` rather than its default-initialized `0` return value (which would make `block.timestamp < deadline` false for all timestamps at `L291`). Established by `Raffle.requestDraw` (`L252-L253`), the sole writer of `status = Status.Drawing`, which atomically writes `drawRequestedAt = uint64(block.timestamp)` after checking `block.timestamp >= endTime` (`L242`), where `endTime > currentTime` was validated in `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L99-L100`) and stored in `Raffle.initialize` (`Raffle.sol:L204`).
  - Assumption: `block.timestamp` when `requestDraw` executes fits in `uint64` (`block.timestamp <= type(uint64).max`), so the `uint64(block.timestamp)` cast at `Raffle.sol:L253` does not wrap to `0` or a truncated timestamp when computing `callbackDeadline()` (`L464`). Established by EVM chain clock scale (`uint64` max is ~584 billion years); no explicit check in code (`nothing found` in contract source).
  - Assumption: `remainingRefundLiability == 0` upon entry to `enableRefunds`, so that assigning `remainingRefundLiability = liability` (`L298`) does not overwrite a non-zero balance. Established by zero-initialized clone storage, the fact that only `enableRefunds` (`L298`) and `refundTickets` (`L368`, gated by `_requireStatus(Status.Refunding)` at `L350`) write `remainingRefundLiability`, and the rejection of `Status.Refunding` at `L292-L294`.
  - Assumption: `unsettledPot == uint256(totalEntries) * ENTRY_PRICE` upon entry to `enableRefunds`, and the contract's actual `quoteToken` balance covers `unsettledPot`. Established across `Raffle.buyEntries` (`L223-L234`), which increments `totalEntries` by `entryCount` and `unsettledPot` by `uint256(entryCount) * ENTRY_PRICE` while pulling `grossAmount` via `quoteToken.safeTransferFrom` (`L224`), coupled with the fact that no function decrements `unsettledPot` or transfers `quoteToken` out prior to `Status.NftWon`, `Status.CashWon`, or `Status.Refunding`. That `quoteToken.safeTransferFrom` delivers exact fee-free, non-rebasing balances is an external token assumption (`nothing found` on-chain beyond the six-decimal check in `RaffleFactory.sol:L70-L78`).

---

**Outputs & Effects:**
- Return values: None (`L276`).
- State writes:
  - `unsettledPot = 0` (`L297`).
  - `remainingRefundLiability = liability` (set to the pre-call value of `unsettledPot`, `L296`, `L298`).
  - `status = Status.Refunding` (`L299`).
  - Transiently sets `REENTRANCY_GUARD_STORAGE` slot to `ENTERED` (`2`) before execution and back to `NOT_ENTERED` (`1`) after execution (`ReentrancyGuard.sol:L99`, `L105`).
- Events emitted:
  - `RefundsEnabled(msg.sender, liability)` (`L300`).
- External interactions: None (no external calls; all callees are internal functions).
- Postconditions:
  - `status == Status.Refunding` (`L299`).
  - `unsettledPot == 0` (`L297`).
  - `remainingRefundLiability` equals the prior `unsettledPot` (`L296-L298`).
  - `accountedQuoteBalance()` (`L468-L470`) is unchanged because `unsettledPot + remainingRefundLiability` is conserved and `winnerProceeds`, `sponsorProceeds`, and `protocolFees` are untouched.
  - Subsequent calls to `enableRefunds`, `buyEntries`, `requestDraw`, `settleWinningTicket`, and `redeemWinningTicket` revert due to `status == Status.Refunding`, and any late `fulfillRandomWords` callback is ignored (`L511-L515`).
  - `refundTickets` (`L349-L372`) and `releaseSponsorPrize` (`L395-L407`) become callable.

---

**Block-by-Block:**

```solidity
// L276-L277
function enableRefunds() external override nonReentrant {
    uint256 deadline;
```
- **What:** Enters the `nonReentrant` guard and declares the stack variable `deadline` (`0` by default).
- **Why here:** Establishes the reentrancy lock before reading or mutating contract state and prepares `deadline` for the state-dispatch branches.
- **Assumes:** `REENTRANCY_GUARD_STORAGE` is not `ENTERED` (`2`).
- **Establishes:** `REENTRANCY_GUARD_STORAGE == ENTERED` for the duration of the call (`ReentrancyGuard.sol:L99`).
- **Depended on by:** State reads and writes in `L279-L300`.

```solidity
// L279-L284
if (status == Status.Active) {
    if (totalEntries == 0) {
        deadline = endTime;
        if (msg.sender != sponsor && block.timestamp < deadline) {
            revert RefundsNotAvailable(deadline, block.timestamp);
        }
```
- **What:** Handles an active raffle with zero sold entries, allowing `sponsor` to cancel immediately at any timestamp and allowing any other caller to enable refunds once `block.timestamp >= endTime`.
- **Why here:** Separates the zero-entry case from the sold-entry case in `Status.Active`, because a raffle with `totalEntries == 0` cannot call `requestDraw` (`L243` reverts with `NoEntriesSold`) and therefore has no post-sale draw-request window to wait for.
- **Assumes:** `sponsor` and `endTime` were initialized by `Raffle.initialize` (`L197`, `L204`).
- **Establishes:** On this path, `status == Status.Active`, `totalEntries == 0`, and `msg.sender == sponsor || block.timestamp >= endTime`. Because `totalEntries == 0` and only `buyEntries` writes `totalEntries` (`L230`) and `unsettledPot` (`L233`), `unsettledPot == 0` on this path.
- **Depended on by:** The liability transfer and status transition at `L296-L300`, and subsequently `releaseSponsorPrize` (`L395-L407`) which requires `Status.Refunding` to return the NFT to `sponsorRecipient`.

```solidity
// L285-L288
    } else {
        deadline = drawRequestDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    }
```
- **What:** Handles an active raffle with at least one sold entry (`totalEntries > 0`), requiring `block.timestamp >= drawRequestDeadline()` (`uint256(endTime) + 2 days`) for any caller (including `sponsor`).
- **Why here:** Enforces that once at least one ticket has been sold, the raffle cannot enter `Status.Refunding` until the exclusive draw-request window `[endTime, drawRequestDeadline())` has expired without a successful `requestDraw` call.
- **Assumes:** `drawRequestDeadline()` (`L458-L460`) computes `uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT` without overflow.
- **Establishes:** On this path, `status == Status.Active`, `totalEntries > 0`, and `block.timestamp >= uint256(endTime) + 2 days`.
- **Depended on by:** Mutual exclusion with `requestDraw` (`L244-L247`), and the liability reallocation at `L296-L300`.

```solidity
// L289-L294
} else if (status == Status.Drawing) {
    deadline = callbackDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
} else {
    revert InvalidStatus(status);
}
```
- **What:** In `Status.Drawing`, requires `block.timestamp >= callbackDeadline()`; in any status other than `Status.Active` or `Status.Drawing`, reverts with `InvalidStatus(status)`.
- **Why here:** Prevents enabling refunds while the VRF callback window `[drawRequestedAt, callbackDeadline())` is still open, and rejects calls in `Status.AwaitingPrize` or terminal states (`Status.NftWon`, `Status.CashWon`, `Status.Refunding`).
- **Assumes:** `callbackDeadline()` (`L462-L465`) returns `uint256(drawRequestedAt) + 2 days` rather than `0`, which requires `drawRequestedAt != 0` whenever `status == Status.Drawing` (established by `requestDraw` at `L252-L253`).
- **Establishes:** Either `status` was `Status.Active` or `Status.Drawing` and its respective deadline condition passed, or execution reverted. In particular, `enableRefunds` cannot execute a second time once `status` is set to `Status.Refunding`.
- **Depended on by:** Mutual exclusion with `fulfillRandomWords` (`L510-L516`), and one-time execution of `L296-L300`.

```solidity
// L296-L300
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
emit RefundsEnabled(msg.sender, liability);
```
- **What:** Moves `unsettledPot` into `remainingRefundLiability`, transitions `status` to `Status.Refunding`, and emits `RefundsEnabled`.
- **Why here:** Runs only after all status and deadline checks have succeeded, converting the unallocated sale pot into the refund liability pool before any `refundTickets` call can occur.
- **Assumes:** `remainingRefundLiability == 0` before this write, and `unsettledPot == uint256(totalEntries) * ENTRY_PRICE`.
- **Establishes:** `unsettledPot == 0`, `remainingRefundLiability == liability`, and `status == Status.Refunding`.
- **Depended on by:** `refundTickets` (`L350`, `L368`), `releaseSponsorPrize` (`L397`), `accountedQuoteBalance` (`L469`), and `fulfillRandomWords` (`L511`).

---

**Cross-Function Dependencies:**
- **Callee `ReentrancyGuard._nonReentrantBefore` / `_nonReentrantAfter` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L118`):**
  - Read in full. `_nonReentrantBefore` checks `_reentrancyGuardEntered()` (`StorageSlot.getUint256Slot(REENTRANCY_GUARD_STORAGE).value == ENTERED` at `L113`) and reverts with `ReentrancyGuardReentrantCall()` (`L90`) if `value == 2`, otherwise sets `value = ENTERED` (`2`, `L99`). `_nonReentrantAfter` sets `value = NOT_ENTERED` (`1`, `L105`).
- **Callee `drawRequestDeadline` (internal, `packages/contracts/src/Raffle.sol:L458-L460`):**
  - Read in full. Single execution path: returns `uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT` (`2 days`, `RaffleConstants.sol:L33`). Because `endTime` is `uint64`, the addition in `uint256` cannot overflow. `enableRefunds` depends on this returning the exact threshold checked by `requestDraw` at `L244-L246`.
- **Callee `callbackDeadline` (internal, `packages/contracts/src/Raffle.sol:L462-L465`):**
  - Read in full. Contains two paths:
    1. When `drawRequestedAt != 0` (`L464`): returns `uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT` (`2 days`, `RaffleConstants.sol:L36`).
    2. When `drawRequestedAt == 0` (`L464`): does not assign `deadline` and returns `0`.
  - `enableRefunds` at `L290-L291` checks `if (block.timestamp < deadline) revert`. It therefore depends on `callbackDeadline()` taking path 1 whenever `status == Status.Drawing`; if path 2 were ever taken in `Status.Drawing`, `block.timestamp < 0` would evaluate to `false` and `enableRefunds` would succeed immediately without waiting for any timeout. Path 1 is established by `requestDraw` (`L252-L253`), which sets `drawRequestedAt = uint64(block.timestamp)` whenever it sets `status = Status.Drawing`.
- **Callers:**
  - External entrypoint (`L276`); no internal callers in `Raffle.sol` or `RaffleFactory.sol`.
  - Reachable by `sponsor` prior to `endTime` when `status == Status.Active && totalEntries == 0` (`L280-L284`), and by any external caller at or after the applicable deadline in `Status.Active` or `Status.Drawing` (`L282`, `L287`, `L291`).
- **Shared state:**
  - `status`: written by `Raffle.constructor` (`L165`), `Raffle.initialize` (`L205`), `Raffle.onERC721Received` (`L428`), `Raffle.requestDraw` (`L252`), `Raffle.enableRefunds` (`L299`), and `Raffle.fulfillRandomWords` (`L521`); read by `buyEntries` (`L215`), `requestDraw` (`L241`), `enableRefunds` (`L279`, `L289`, `L293`), `redeemWinningTicket` (`L311`), `refundTickets` (`L350`), `releaseSponsorPrize` (`L396`), `onERC721Received` (`L422`), `fulfillRandomWords` (`L511`), and `_settleWinningTicket` (`L535`).
  - `unsettledPot`: written by `buyEntries` (`L233`), `enableRefunds` (`L297`), and `_settleWinningTicket` (`L553`); read by `enableRefunds` (`L296`), `accountedQuoteBalance` (`L469`), and `_settleWinningTicket` (`L539`).
  - `remainingRefundLiability`: written by `enableRefunds` (`L298`) and `refundTickets` (`L368`); read by `refundTickets` (`L370`) and `accountedQuoteBalance` (`L469`).
  - `totalEntries`, `endTime`, `sponsor`, `drawRequestedAt`: written in `initialize` (`L197`, `L204`), `buyEntries` (`L230`), and `requestDraw` (`L253`); read by `enableRefunds` (`L280-L282`, `L286`, `L290`).
- **Invariant couplings:**
  - **Window partitioning with `requestDraw` and `fulfillRandomWords`:** `requestDraw` reverts when `block.timestamp >= drawRequestDeadline()` (`L245`), whereas `enableRefunds` in `Status.Active` (with `totalEntries > 0`) reverts when `block.timestamp < drawRequestDeadline()` (`L287`). Likewise, `fulfillRandomWords` ignores callbacks when `block.timestamp >= callbackDeadline()` (`L512`), whereas `enableRefunds` in `Status.Drawing` reverts when `block.timestamp < callbackDeadline()` (`L291`).
  - **One-way terminal accounting:** `enableRefunds` moves the entire `unsettledPot` to `remainingRefundLiability` once (`L296-L298`) and sets `status = Status.Refunding` (`L299`). Because `Status.Refunding` is rejected on re-invocation (`L293`), a second call cannot overwrite a partially refunded `remainingRefundLiability` with `unsettledPot` (`0`).
  - **Refund solvency coupling with `buyEntries` and `refundTickets`:** Every ticket minted in `buyEntries` adds `(lastEntry - firstEntry + 1) * ENTRY_PRICE` to `unsettledPot` (`L223-L233`). `enableRefunds` copies `unsettledPot` into `remainingRefundLiability` (`L296-L298`), and `refundTickets` subtracts `aggregateEntries * ENTRY_PRICE` from `remainingRefundLiability` using checked arithmetic (`L367-L368`) as each ticket is burned (`L364`).

---

**Open Questions:**
- None; all paths through `enableRefunds` and its internal/inherited callees (`drawRequestDeadline`, `callbackDeadline`, `ReentrancyGuard`) are present in the workspace and fully traced above.
