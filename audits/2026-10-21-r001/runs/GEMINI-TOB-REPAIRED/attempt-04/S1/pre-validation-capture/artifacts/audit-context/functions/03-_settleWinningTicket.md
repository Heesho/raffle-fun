## `_settleWinningTicket` in packages/contracts/src/Raffle.sol (L533-L558)

**Purpose:** Performs the one-time, storage-only terminal liability settlement for a resolved raffle (`Status.NftWon` or `Status.CashWon`). It verifies that the caller-supplied `ticketId` covers the VRF-selected `winningEntry`, records `winningTicketId`, zeroes `unsettledPot`, and partitions the gross pot without loss into `protocolFees`, `winnerProceeds` (for `Status.CashWon`), and `sponsorProceeds` (as the remainder). Without it, `winningTicketId` is never bound to `winningEntry`, and `winnerProceeds`, `sponsorProceeds`, and `protocolFees` remain zero, blocking `redeemWinningTicket` (on the `CashWon` path or when already settled), `releaseSponsorProceeds`, and `releaseProtocolFees`.

---

**Inputs & Assumptions:**
- `ticketId` (`uint256`): candidate winning ERC-721 ticket identifier whose stored entry range is checked against `winningEntry`. Trust: **untrusted** — supplied directly by any external caller via `Raffle.settleWinningTicket` (`packages/contracts/src/Raffle.sol:L304-L306`) or `Raffle.redeemWinningTicket` (`packages/contracts/src/Raffle.sol:L309-L315`).
- Implicit inputs:
  - `msg.sender` (`address`): untrusted caller address, used only as the indexed `settler` field in the `WinningTicketSettled` event (`packages/contracts/src/Raffle.sol:L557`).
  - `settlementComplete` (`bool`, `packages/contracts/src/Raffle.sol:L127`): storage flag guarding one-time settlement (`packages/contracts/src/Raffle.sol:L534`).
  - `status` (`IRaffle.Status`, `packages/contracts/src/Raffle.sol:L124`): current lifecycle state (`packages/contracts/src/Raffle.sol:L535`).
  - `winningEntry` (`uint128`, `packages/contracts/src/Raffle.sol:L118`): one-based global winning entry read inside `_requireWinningTicket` (`packages/contracts/src/Raffle.sol:L581`).
  - `_ticketRanges[ticketId]` (`TicketRange`, `packages/contracts/src/Raffle.sol:L139`): inclusive `[firstEntry, lastEntry]` range read inside `_requireWinningTicket` via `ticketRange(ticketId)` (`packages/contracts/src/Raffle.sol:L451-L455`, `L580`).
  - `unsettledPot` (`uint256`, `packages/contracts/src/Raffle.sol:L91`): accumulated gross quote-token proceeds from entry sales (`packages/contracts/src/Raffle.sol:L539`).
  - Constants from `RaffleConstants` (`packages/contracts/src/libraries/RaffleConstants.sol:L12-L18`): `BPS = 10_000` (`L12`), `PROTOCOL_FEE_BPS = 500` (`L14`), `CASH_WINNER_BPS = 8000` (`L18`).
- Preconditions:
  - `settlementComplete == false`: enforced in-function at `packages/contracts/src/Raffle.sol:L534` (reverts with `SettlementAlreadyComplete`).
  - `status == Status.NftWon || status == Status.CashWon`: enforced in-function at `packages/contracts/src/Raffle.sol:L535-L536` (reverts with `InvalidStatus(result)`).
  - When `status` is `Status.NftWon` or `Status.CashWon`, `totalEntries >= 1` and `winningEntry` is in `[1, totalEntries]`: assumed by `_requireWinningTicket` (`packages/contracts/src/Raffle.sol:L580-L584`) so that unminted tickets (whose `_ticketRanges[ticketId]` default to `(0, 0)`) always fail `selectedEntry > lastEntry` (`winningEntry > 0`) and cannot match. Established by `Raffle.requestDraw` (`packages/contracts/src/Raffle.sol:L243`, `L252`) requiring `totalEntries != 0` before entering `Status.Drawing`, and `Raffle.fulfillRandomWords` (`packages/contracts/src/Raffle.sol:L511`, `L518-L521`) requiring `status == Status.Drawing` and writing `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)` when transitioning to `Status.NftWon` or `Status.CashWon`.
  - Minted ticket ranges in `_ticketRanges[1..ticketCount]` form contiguous, non-overlapping inclusive intervals `[firstEntry, lastEntry]` with `1 <= firstEntry <= lastEntry <= totalEntries` partitioning `[1, totalEntries]`, and unminted ticket IDs have `(0, 0)`: assumed so that `_requireWinningTicket` (`packages/contracts/src/Raffle.sol:L538`, `L579-L585`) uniquely identifies a single valid `ticketId`. Established by `Raffle.buyEntries` (`packages/contracts/src/Raffle.sol:L218-L232`), which is the sole writer to `totalEntries`, `ticketCount`, and `_ticketRanges`.
  - Prior to settlement in `Status.NftWon` or `Status.CashWon`, `winnerProceeds == 0`, `sponsorProceeds == 0`, `protocolFees == 0`, `remainingRefundLiability == 0`, and `unsettledPot == uint256(totalEntries) * ENTRY_PRICE >= ENTRY_PRICE` (`1_000_000`): assumed so that overwriting `winnerProceeds` (or leaving it untouched on the `NftWon` branch), `sponsorProceeds`, and `protocolFees` preserves `accountedQuoteBalance()` and produces a non-zero `winnerProceeds` (`>= 800_000`) on the `CashWon` path (required by `Raffle.redeemWinningTicket` at `packages/contracts/src/Raffle.sol:L340`). Established by single-settlement gating (`L534`), `Raffle.buyEntries` (`L223`, `L233`), `Raffle.requestDraw` (`L243`), and `Raffle.enableRefunds` (`L279-L299`, which only runs in `Status.Active` or `Status.Drawing` and transitions to `Status.Refunding`).
  - The contract holds at least `unsettledPot` raw units of `quoteToken`: assumed so that the liabilities recorded in `winnerProceeds`, `sponsorProceeds`, and `protocolFees` are backed by actual token balance when later claimed. Established by `Raffle.buyEntries` (`packages/contracts/src/Raffle.sol:L223-L224`, `L233`) under the system trust assumption that `quoteToken` is canonical non-rebasing, fee-free 6-decimal USDC.

---

**Outputs & Effects:**
- Return value:
  - `cashAmount` (`uint256`): `0` when `status == Status.NftWon` (default zero initialization of named return variable at `packages/contracts/src/Raffle.sol:L533`), or `Math.mulDiv(grossPot, 8000, 10_000)` when `status == Status.CashWon` (`packages/contracts/src/Raffle.sol:L546`).
- State writes:
  - `winnerProceeds = cashAmount` on the `Status.CashWon` branch only (`packages/contracts/src/Raffle.sol:L548`); left at `0` on the `Status.NftWon` branch.
  - `settlementComplete = true` (`packages/contracts/src/Raffle.sol:L551`).
  - `winningTicketId = ticketId` (`packages/contracts/src/Raffle.sol:L552`).
  - `unsettledPot = 0` (`packages/contracts/src/Raffle.sol:L553`).
  - `sponsorProceeds = sponsorAmount` (`packages/contracts/src/Raffle.sol:L554`).
  - `protocolFees = protocolFee` (`packages/contracts/src/Raffle.sol:L555`).
- Events:
  - `WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount)` (`packages/contracts/src/Raffle.sol:L557`).
- External interactions:
  - None. No external calls or asset transfers occur in `_settleWinningTicket` or its callees.
- Postconditions:
  - `settlementComplete == true` (`L551`), preventing any subsequent call to `_settleWinningTicket` from succeeding (`L534`).
  - `winningTicketId == ticketId` (`L552`), where `_ticketRanges[ticketId].firstEntry <= winningEntry <= _ticketRanges[ticketId].lastEntry` (`L538`, `L579-L585`).
  - `unsettledPot == 0` (`L553`).
  - `protocolFees + sponsorProceeds + winnerProceeds == grossPot` (the pre-call `unsettledPot`), conserving `accountedQuoteBalance()` (`packages/contracts/src/Raffle.sol:L468-L470`).

---

**Block-by-Block:**

```solidity
// L533-L536
    function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
        if (settlementComplete) revert SettlementAlreadyComplete();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```
- **What:** Rejects execution if `settlementComplete` is already true or if `status` is neither `Status.NftWon` nor `Status.CashWon`, caching `status` in `result` and initializing the named return `cashAmount` to `0`.
- **Why here:** Must precede range validation and liability writes so settlement can occur at most once and only after `fulfillRandomWords` has resolved the raffle into a terminal win state.
- **Assumes:** `status` only reaches `Status.NftWon` or `Status.CashWon` via `Raffle.fulfillRandomWords` (`packages/contracts/src/Raffle.sol:L521`), and prior to the first `_settleWinningTicket` call, `winnerProceeds`, `sponsorProceeds`, and `protocolFees` are all `0`.
- **Establishes:** `settlementComplete == false` on entry, and `result` is either `Status.NftWon` or `Status.CashWon`.
- **Depended on by:** `_requireWinningTicket(ticketId)` at `L538` (which relies on `winningEntry` having been set at resolution), the branch `if (result == Status.NftWon)` at `L543`, and the one-time state assignments at `L548-L555`.

```solidity
// L538
        _requireWinningTicket(ticketId);
```
- **What:** Verifies that the stored inclusive entry range `[firstEntry, lastEntry]` for `ticketId` contains `winningEntry`, reverting with `TicketDoesNotContainWinningEntry(ticketId, selectedEntry)` otherwise.
- **Why here:** Validates the untrusted `ticketId` before recording `winningTicketId = ticketId` (`L552`) or committing settlement state.
- **Assumes:** `winningEntry >= 1` (established by `Raffle.fulfillRandomWords` at `L518-L519` after `Raffle.requestDraw` enforces `totalEntries != 0` at `L243`) and `_ticketRanges` maps unminted ticket IDs to `(0, 0)` and minted ticket IDs to disjoint ranges covering `[1, totalEntries]` (established by `Raffle.buyEntries` at `L226-L232`).
- **Establishes:** `_ticketRanges[ticketId].firstEntry <= winningEntry <= _ticketRanges[ticketId].lastEntry`, and `ticketId` is the unique minted ticket containing `winningEntry`.
- **Depended on by:** `winningTicketId = ticketId` at `L552` and downstream `Raffle.redeemWinningTicket` (`L314-L325`).

```solidity
// L539-L541
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 sponsorAmount;
```
- **What:** Loads `unsettledPot` into `grossPot` and computes `protocolFee = floor(grossPot * 500 / 10_000)` using `Math.mulDiv`.
- **Why here:** `protocolFee` (5% rounded down) is deducted in both the `Status.NftWon` and `Status.CashWon` branches before computing `sponsorAmount` and before zeroing `unsettledPot` at `L553`.
- **Assumes:** `RaffleConstants.BPS > 0` (`10_000` at `RaffleConstants.sol:L12`) and `RaffleConstants.PROTOCOL_FEE_BPS <= RaffleConstants.BPS` (`500 <= 10_000` at `RaffleConstants.sol:L14`).
- **Establishes:** `protocolFee == floor(grossPot * 500 / 10_000)` and `protocolFee <= grossPot / 20 <= grossPot`.
- **Depended on by:** `L544`, `L547`, `L555`, and `L557`.

```solidity
// L543-L549
        if (result == Status.NftWon) {
            sponsorAmount = grossPot - protocolFee;
        } else {
            cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            sponsorAmount = grossPot - protocolFee - cashAmount;
            winnerProceeds = cashAmount;
        }
```
- **What:** Partitions the post-fee pot according to `result`: for `Status.NftWon`, assigns the entire remainder `grossPot - protocolFee` to `sponsorAmount` while leaving `cashAmount` and `winnerProceeds` at `0`; for `Status.CashWon` (the `else` branch, since `L536` excluded all other statuses), computes `cashAmount = floor(grossPot * 8000 / 10_000)`, assigns the remainder `grossPot - protocolFee - cashAmount` to `sponsorAmount`, and writes `winnerProceeds = cashAmount`.
- **Why here:** Branches on the validated `result` after `protocolFee` is known and before writing the shared settlement storage fields at `L551-L555`.
- **Assumes:** `RaffleConstants.PROTOCOL_FEE_BPS + RaffleConstants.CASH_WINNER_BPS <= RaffleConstants.BPS` (`500 + 8000 = 8500 <= 10_000` at `RaffleConstants.sol:L12-L18`), so `protocolFee + cashAmount <= grossPot` and the checked subtractions at `L544` and `L547` never underflow; also assumes `winnerProceeds == 0` prior to settlement so leaving `winnerProceeds` unwritten on the `NftWon` branch leaves it at `0`.
- **Establishes:**
  - On `Status.NftWon`: `cashAmount == 0`, `winnerProceeds == 0`, and `protocolFee + sponsorAmount == grossPot`.
  - On `Status.CashWon`: `cashAmount == floor(grossPot * 8000 / 10_000)`, `winnerProceeds == cashAmount`, and `protocolFee + cashAmount + sponsorAmount == grossPot`.
- **Depended on by:** `L554`, `L557`, `Raffle.redeemWinningTicket` (`L339-L342`), and `Raffle.releaseSponsorProceeds` (`L376-L380`).

```solidity
// L551-L557
        settlementComplete = true;
        winningTicketId = ticketId;
        unsettledPot = 0;
        sponsorProceeds = sponsorAmount;
        protocolFees = protocolFee;

        emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
```
- **What:** Marks `settlementComplete = true`, stores `winningTicketId = ticketId`, zeroes `unsettledPot`, writes `sponsorProceeds` and `protocolFees`, and emits `WinningTicketSettled`.
- **Why here:** Finalizes all storage state changes and emits the settlement event at the end of the function; there are no external calls anywhere in `_settleWinningTicket`.
- **Assumes:** `sponsorProceeds == 0` and `protocolFees == 0` before this write (established by `if (settlementComplete) revert SettlementAlreadyComplete()` at `L534`, as `_settleWinningTicket` is the only writer to `settlementComplete` and the only writer that sets positive values to `sponsorProceeds` and `protocolFees`).
- **Establishes:** `settlementComplete == true`, `winningTicketId == ticketId`, `unsettledPot == 0`, `sponsorProceeds == sponsorAmount`, `protocolFees == protocolFee`, and `accountedQuoteBalance()` equals its pre-call value `grossPot`.
- **Depended on by:** `Raffle.redeemWinningTicket` (`L314-L318`, `L339-L342`), `Raffle.releaseSponsorProceeds` (`L376-L380`), and `Raffle.releaseProtocolFees` (`L386-L390`).

---

**Cross-Function Dependencies:**

- **Callee `_requireWinningTicket` (`internal`, `packages/contracts/src/Raffle.sol:L579-L585`):**
  - Reads `(uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId)` (`L580`) and `uint128 selectedEntry = winningEntry` (`L581`).
  - Two paths:
    1. Revert path (`L582-L584`): when `selectedEntry < firstEntry || selectedEntry > lastEntry`, reverts with `TicketDoesNotContainWinningEntry(ticketId, selectedEntry)`.
    2. Return path (`L582`): when `firstEntry <= selectedEntry <= lastEntry`, returns normally.
  - What `_settleWinningTicket` depends on it to establish: that `ticketId` is a minted ticket whose stored range contains `winningEntry`. Note that `_requireWinningTicket` does not explicitly check `firstEntry != 0` or `ticketId <= ticketCount`; excluding unminted tickets (`firstEntry == 0, lastEntry == 0`) depends on `winningEntry >= 1` having been established by `Raffle.fulfillRandomWords` (`L518-L519`).

- **Callee `ticketRange` (`internal` call to `public view`, `packages/contracts/src/Raffle.sol:L451-L455`):**
  - Single path: reads `_ticketRanges[ticketId]` from storage and returns `(range.firstEntry, range.lastEntry)` without validation. For any `ticketId` not yet written by `buyEntries`, returns `(0, 0)`.

- **Callee `Math.mulDiv` (`external-source-available`, `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L206-L277`):**
  - Calls `Math.mul512(x, y)` (`Math.sol:L37-L46`, `L208`).
  - Three paths:
    1. `high == 0` (`Math.sol:L211-L216`): returns `low / denominator` (reverts if `denominator == 0` via Solidity checked division inside `unchecked` block). Because `unsettledPot == uint256(totalEntries) * 1_000_000 <= type(uint128).max * 1_000_000 < 2^148` and `y <= 8000 < 2^13`, `x * y < 2^161 < 2^256`, so `high == 0` always holds for reachable `unsettledPot` values and `denominator = 10_000`.
    2. `high != 0 && denominator <= high` (`Math.sol:L219-L221`): calls `Math.ternary` (`Math.sol:L143-L150`, which calls `SafeCast.toUint` at `SafeCast.sol:L1157-L1161`) and `Panic.panic` (`Panic.sol:L50-L56`) to revert with `0x12` (`DIVISION_BY_ZERO`) or `0x11` (`UNDER_OVERFLOW`). Unreachable when `y < denominator` (`500 < 10_000` and `8000 < 10_000`) because `high < y < denominator` for all `uint256` values of `x`.
    3. `0 < high < denominator` (`Math.sol:L228-L275`): performs 512-by-256 Newton-Raphson exact floor division and returns `floor(x * y / denominator)`.
  - What `_settleWinningTicket` depends on it to establish: exact floor division `floor(grossPot * bps / 10_000)` without intermediate multiplication overflow, bounded by `grossPot * bps / 10_000` so subsequent subtractions `grossPot - protocolFee` (`L544`) and `grossPot - protocolFee - cashAmount` (`L547`) cannot underflow.

- **Callers:**
  - `Raffle.settleWinningTicket(uint256 ticketId)` (`packages/contracts/src/Raffle.sol:L304-L306`): external, `nonReentrant`, permissionless entrypoint that returns `_settleWinningTicket(ticketId)` directly.
  - `Raffle.redeemWinningTicket(uint256 ticketId)` (`packages/contracts/src/Raffle.sol:L309-L346`, call at `L315`): external, `nonReentrant` entrypoint that calls `_settleWinningTicket(ticketId)` when `!settlementComplete` (`L314-L315`), discarding the return value and later reading `winnerProceeds` from storage (`L339`) when `result == Status.CashWon`.

- **Shared state:**
  - `settlementComplete` (`L127`): written here (`L551`); read here (`L534`) and in `Raffle.redeemWinningTicket` (`L314`).
  - `status` (`L124`): read here (`L535`); written in `Raffle.constructor` (`L165`), `Raffle.initialize` (`L205`), `Raffle.onERC721Received` (`L428`), `Raffle.requestDraw` (`L252`), `Raffle.enableRefunds` (`L299`), and `Raffle.fulfillRandomWords` (`L521`).
  - `winningEntry` (`L118`): read via `_requireWinningTicket` (`L581`); written in `Raffle.fulfillRandomWords` (`L519`).
  - `_ticketRanges` (`L139`): read via `_requireWinningTicket` -> `ticketRange` (`L452`); written in `Raffle.buyEntries` (`L232`).
  - `unsettledPot` (`L91`): read (`L539`) and zeroed (`L553`) here; incremented in `Raffle.buyEntries` (`L233`), zeroed in `Raffle.enableRefunds` (`L297`), and read in `Raffle.accountedQuoteBalance` (`L469`).
  - `winningTicketId` (`L121`): written here (`L552`); read in `Raffle.redeemWinningTicket` (`L316-L317`).
  - `winnerProceeds` (`L100`): written here (`L548` on `Status.CashWon`); read and zeroed in `Raffle.redeemWinningTicket` (`L339-L341`), and read in `Raffle.accountedQuoteBalance` (`L469`).
  - `sponsorProceeds` (`L103`): written here (`L554`); read and zeroed in `Raffle.releaseSponsorProceeds` (`L376-L378`), and read in `Raffle.accountedQuoteBalance` (`L469`).
  - `protocolFees` (`L106`): written here (`L555`); read and zeroed in `Raffle.releaseProtocolFees` (`L386-L388`), and read in `Raffle.accountedQuoteBalance` (`L469`).

- **Invariant couplings:**
  - **Quote-token liability conservation (`accountedQuoteBalance()`):** `unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees` (`packages/contracts/src/Raffle.sol:L469`) is preserved across `_settleWinningTicket` because `unsettledPot` (`grossPot`) is replaced by `protocolFees + sponsorProceeds + winnerProceeds == grossPot` (`L543-L555`).
  - **Single-winner binding:** Because `_ticketRanges` intervals are disjoint over `[1, totalEntries]` (`Raffle.buyEntries`, `L226-L232`) and `winningEntry` is fixed in `[1, totalEntries]` (`Raffle.fulfillRandomWords`, `L518-L519`), `_requireWinningTicket` (`L538`, `L579-L585`) ensures that regardless of which permissionless caller invokes `settleWinningTicket`, `winningTicketId` (`L552`) can only ever be bound to the unique ticket whose range covers `winningEntry`.
  - **Decoupling of settlement from ownership and external transfers:** `_settleWinningTicket` does not read ERC-721 ownership (`ownerOf`) or perform external token calls, ensuring permissionless settlement cannot be blocked by prize token behavior, recipient blacklisting, or ticket transfers.

---

**Open Questions:**
- None; all callees, callers, and state writers in `Raffle.sol`, `RaffleConstants.sol`, and OpenZeppelin `Math.sol` were inspected in full.
