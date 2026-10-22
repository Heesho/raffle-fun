## `fulfillRandomWords` in packages/contracts/src/Raffle.sol (L509-L524)

**Purpose:** Consumes the wrapper-authenticated Chainlink VRF v2.5 callback to select the 1-based `winningEntry` in `[1, totalEntries]`, record `resolvedAt`, and transition the raffle from `Status.Drawing` into its terminal `Status.NftWon` or `Status.CashWon` state (or softly ignore out-of-window, duplicate, wrong-request, in-flight, or wrong-length callbacks without reverting). Without it, a raffle that enters `Status.Drawing` can never resolve to a winner and can only eventually transition to `Status.Refunding` after `callbackDeadline()`.

---

**Inputs & Assumptions:**
- `requestId` (`uint256`): VRF request identifier forwarded from `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101, L106`). Trust: **trusted** (authenticated as originating from `i_vrfV2PlusWrapper` at `VRFV2PlusWrapperConsumerBase.sol:L102-L105`).
- `randomWords` (`uint256[] memory`): ABI-decoded random words array forwarded from `rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:L101, L106`). Trust: **trusted** (authenticated as originating from `i_vrfV2PlusWrapper` at `VRFV2PlusWrapperConsumerBase.sol:L102-L105`).
- Implicit inputs:
  - Caller authentication via `msg.sender` in `rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:L102-L105`) against immutable `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L35, L46`; initialized via `Raffle.constructor` at `Raffle.sol:L157, L610-L613`).
  - Storage slots read: `_requestInFlight` (`Raffle.sol:L142, L511`), `status` (`Raffle.sol:L124, L511, L514, L523`), `vrfRequestId` (`Raffle.sol:L109, L511, L514`), `drawRequestedAt` (`Raffle.sol:L111` via `callbackDeadline()` at `L464, L512`), `totalEntries` (`Raffle.sol:L85, L518, L521`), and `reserveEntries` (`Raffle.sol:L79, L521`).
  - Block environment: `block.timestamp` (`Raffle.sol:L512, L520`).
- Preconditions and what establishes each:
  - Only `i_vrfV2PlusWrapper` can invoke `fulfillRandomWords`. Established by `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:L102-L105`), which reverts with `OnlyVRFWrapperCanFulfill` when `msg.sender != address(i_vrfV2PlusWrapper)`, combined with `internal` visibility on `fulfillRandomWords` (`Raffle.sol:L509`) and no other call sites in `Raffle` or its base contracts.
  - Incoming calldata to `rawFulfillRandomWords(uint256,uint256[])` is valid ABI encoding and fits within the callback gas budget during memory allocation/decoding before `L509` is reached. Established by: **nothing found** in repository source (depends on external `i_vrfV2PlusWrapper` behavior).
  - On the resolution path (`L518-L523`), `totalEntries > 0`. Established by `Raffle.requestDraw` (`Raffle.sol:L243`, `if (totalEntries == 0) revert NoEntriesSold();`) before `requestDraw` sets `status = Status.Drawing` (`Raffle.sol:L252`), which is the only site that transitions `status` to `Status.Drawing`, together with `Raffle.buyEntries` only ever increasing `totalEntries` (`Raffle.sol:L218-L230`).
  - On the resolution path (`L518-L523`), `drawRequestedAt != 0`. Established by `Raffle.requestDraw` setting `drawRequestedAt = uint64(block.timestamp)` (`Raffle.sol:L253`) when entering `Status.Drawing` (`Raffle.sol:L252`) after verifying `block.timestamp >= endTime` (`Raffle.sol:L242`), where `endTime > block.timestamp` at creation (`RaffleFactory.sol:L100`), and further enforced at `L512` because `drawRequestedAt == 0` makes `callbackDeadline()` return `0` (`Raffle.sol:L464`), causing `block.timestamp >= callbackDeadline()` to evaluate to `true` and return early.
  - On the resolution path (`L520`), `block.timestamp <= type(uint64).max` so `uint64(block.timestamp)` does not truncate. Established by `RaffleFactory.createRaffle` requiring `params.endTime > block.timestamp` with `params.endTime` typed as `uint64` (`RaffleFactory.sol:L100`) and `Raffle.requestDraw` / `Raffle.fulfillRandomWords` enforcing `drawRequestedAt < uint256(endTime) + 2 days` (`Raffle.sol:L245, L459`) and `block.timestamp < uint256(drawRequestedAt) + 2 days` (`Raffle.sol:L512, L464`), provided `params.endTime <= type(uint64).max - 4 days` (no explicit upper bound check on `uint256(params.endTime) + 4 days <= type(uint64).max` exists in code; `RaffleFactory.sol:L101-L104` bounds `uint256(params.endTime) - block.timestamp <= 30 days`).
  - `randomWords[0]` is uniformly distributed and unpredictable. Established by: **nothing found** in repository source (trusted external `i_vrfV2PlusWrapper` assumption).

---

**Outputs & Effects:**
- Returns: none (`void`).
- State writes:
  - Early-return path (`L510-L516`): none.
  - Resolution path (`L518-L523`):
    - `winningEntry = resolvedEntry` (`L519`), setting a 1-based entry index in `[1, totalEntries]`.
    - `resolvedAt = uint64(block.timestamp)` (`L520`).
    - `status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon` (`L521`).
- Events:
  - Early-return path: `emit VrfCallbackIgnored(requestId, vrfRequestId, status)` (`L514`).
  - Resolution path: `emit RaffleResolved(requestId, resolvedEntry, status)` (`L523`).
- External interactions: none.
- Postconditions:
  - On the early-return path (`L510-L516`), all storage slots are unchanged and execution returns normally without reverting.
  - On the resolution path (`L518-L523`), `1 <= winningEntry <= totalEntries`, `resolvedAt == uint64(block.timestamp)`, and `status` is permanently `Status.NftWon` (when `totalEntries >= reserveEntries`) or `Status.CashWon` (when `totalEntries < reserveEntries`).

---

**Block-by-Block:**

```solidity
// L510-L516
if (
    _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
        || block.timestamp >= callbackDeadline()
) {
    emit VrfCallbackIgnored(requestId, vrfRequestId, status);
    return;
}
```
- **What:** Guards resolution against synchronous in-flight callbacks, non-`Drawing` lifecycle states, mismatched `requestId`s, word counts other than `1`, and callbacks arriving at or after `callbackDeadline()`, emitting `VrfCallbackIgnored` and returning without reverting if any check fails.
- **Why here:** Must precede all state writes and `randomWords[0]` array indexing (`L518`). Short-circuit evaluation ensures `_requestInFlight` (`L511`) rejects a synchronous callback during `requestDraw` (`L254-L260`) before `vrfRequestId` is written at `L259`, and `randomWords.length != 1` (`L511`) guards the `randomWords[0]` read at `L518`. Returning instead of reverting allows the VRF wrapper transaction to succeed on late or duplicate deliveries while preserving the refund transition at `enableRefunds` (`L289-L291`).
- **Assumes:** `callbackDeadline()` (`L462-L465`) returns the exclusive expiration timestamp `uint256(drawRequestedAt) + 2 days` whenever `status == Status.Drawing`.
- **Establishes:** For `L518-L523`: `_requestInFlight == false`, `status == Status.Drawing` (and therefore `totalEntries > 0` via `L243, L252`), `requestId == vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < callbackDeadline()` (so `drawRequestedAt != 0` and `block.timestamp < uint256(drawRequestedAt) + 2 days`).
- **Depended on by:** `L518-L523`, as well as `enableRefunds` (`L289-L291`), `_settleWinningTicket` (`L535-L538`), `redeemWinningTicket` (`L311-L318`), and `releaseSponsorPrize` (`L396-L399`).

```solidity
// L518-L521
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;
```
- **What:** Maps `randomWords[0]` into a 1-based entry index `resolvedEntry` in `[1, totalEntries]`, records `winningEntry` and `resolvedAt`, and transitions `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` otherwise.
- **Why here:** Executes only after `L510-L516` establishes `status == Status.Drawing` (hence `totalEntries > 0`) and `randomWords.length == 1`. Performs storage-only resolution with no loops or external calls so callback gas usage is O(1) and independent of `ticketCount` or `totalEntries`.
- **Assumes:** `totalEntries > 0` (established at `L243` before `L252`) so `% uint256(totalEntries)` does not panic with division by zero (`Panic(0x12)`) and `(randomWords[0] % uint256(totalEntries)) + 1 <= uint256(totalEntries) <= type(uint128).max` so the `uint128` cast does not truncate; `block.timestamp <= type(uint64).max` so `uint64(block.timestamp)` does not truncate.
- **Establishes:** `1 <= winningEntry <= totalEntries`; `resolvedAt == uint64(block.timestamp)`; `status` is `Status.NftWon` iff `totalEntries >= reserveEntries` and `Status.CashWon` iff `totalEntries < reserveEntries`; `status != Status.Drawing` so any subsequent callback to `fulfillRandomWords` takes the early return at `L511-L515` and `enableRefunds` can no longer transition the raffle to `Status.Refunding` (`L279-L294`).
- **Depended on by:** `L523` (emits `resolvedEntry` and `status`), `_requireWinningTicket` (`L579-L585`, reads `winningEntry`), `_settleWinningTicket` (`L535-L549`, branches on `status` and calls `_requireWinningTicket`), `redeemWinningTicket` (`L311-L343`, branches on `status`), and `releaseSponsorPrize` (`L396-L399`, permits sponsor prize recovery when `status == Status.CashWon`).

```solidity
// L523
emit RaffleResolved(requestId, resolvedEntry, status);
```
- **What:** Emits `RaffleResolved` with `requestId`, `resolvedEntry`, and the terminal `status`.
- **Why here:** After all resolution storage writes (`L519-L521`) are committed.
- **Assumes:** Nothing beyond `L518-L521`.
- **Establishes:** Off-chain event log of resolution parameters.
- **Depended on by:** Off-chain indexers and callers discovering the winning entry and outcome.

---

**Cross-Function Dependencies:**
- **Callee `callbackDeadline` (`internal` / `public view`, `packages/contracts/src/Raffle.sol:L462-L465`):**
  - Read in full. Has two paths:
    1. When `drawRequestedAt != 0` (`L464`): returns `uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT` (`uint256(drawRequestedAt) + 2 days`, `RaffleConstants.sol:L36`). Since `drawRequestedAt` is `uint64`, the `uint256` addition cannot overflow.
    2. When `drawRequestedAt == 0` (`L464`): returns the default `deadline = 0`.
  - `fulfillRandomWords` calls `callbackDeadline()` at `L512` only after short-circuit checks confirm `status == Status.Drawing` (`L511`). `status == Status.Drawing` is only set in `requestDraw` (`L252`), which sets `drawRequestedAt = uint64(block.timestamp)` at `L253`. Furthermore, even on the `drawRequestedAt == 0` path where `callbackDeadline()` returns `0`, `block.timestamp >= 0` at `L512` is unconditionally `true`, so `fulfillRandomWords` still takes the early-return ignore branch (`L514-L515`).
- **Callers:**
  - `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`): the sole caller (`L106`). It enforces `if (msg.sender != vrfWrapperAddr) revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);` (`L103-L105`), where `vrfWrapperAddr = address(i_vrfV2PlusWrapper)` (`L102`), and forwards `_requestId` and `_randomWords` unchanged.
- **Shared state:**
  - `_requestInFlight` (`Raffle.sol:L142`): written in `requestDraw` (`L254, L260`); read in `fulfillRandomWords` (`L511`).
  - `status` (`Raffle.sol:L124`): written in `constructor` (`L165`), `initialize` (`L205`), `onERC721Received` (`L428`), `requestDraw` (`L252`), `enableRefunds` (`L299`), and `fulfillRandomWords` (`L521`); read in `buyEntries` (`L215` via `_requireStatus`), `requestDraw` (`L241` via `_requireStatus`), `enableRefunds` (`L279, L289`), `redeemWinningTicket` (`L311`), `refundTickets` (`L350` via `_requireStatus`), `releaseSponsorPrize` (`L396`), `onERC721Received` (`L422`), `fulfillRandomWords` (`L511, L514, L523`), and `_settleWinningTicket` (`L535`).
  - `vrfRequestId` (`Raffle.sol:L109`): written in `requestDraw` (`L259`); read in `fulfillRandomWords` (`L511, L514`).
  - `drawRequestedAt` (`Raffle.sol:L111`): written in `requestDraw` (`L253`); read in `callbackDeadline` (`L464`), which is called by `requestDraw` (`L272`), `enableRefunds` (`L290`), and `fulfillRandomWords` (`L512`).
  - `totalEntries` (`Raffle.sol:L85`): written in `buyEntries` (`L230`); read in `buyEntries` (`L219, L226, L227`), `requestDraw` (`L243`), `enableRefunds` (`L280`), `grossSales` (`L474`), and `fulfillRandomWords` (`L518, L521`).
  - `reserveEntries` (`Raffle.sol:L79`): written in `initialize` (`L203`); read in `fulfillRandomWords` (`L521`).
  - `winningEntry` (`Raffle.sol:L118`): written in `fulfillRandomWords` (`L519`); read in `_requireWinningTicket` (`L580`), which is called by `_settleWinningTicket` (`L538`).
  - `resolvedAt` (`Raffle.sol:L115`): written in `fulfillRandomWords` (`L520`); not read internally by any contract function.
- **Invariant couplings:**
  - *Entry coverage partition & winner existence (`1 <= winningEntry <= totalEntries`):* `buyEntries` (`L226-L232`) partitions `[1, totalEntries]` into contiguous, non-overlapping inclusive ranges `[firstEntry, lastEntry]` stored in `_ticketRanges[ticketId]` for `ticketId` in `[1, ticketCount]`. Because `fulfillRandomWords` requires `status == Status.Drawing` (`L511`)—which `requestDraw` only enters when `totalEntries > 0` (`L243, L252`)—and computes `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)` (`L518-L519`), `winningEntry` is guaranteed to lie in `[1, totalEntries]` and therefore within the stored range of exactly one minted `ticketId` when `_requireWinningTicket` (`L579-L585`) checks `selectedEntry >= firstEntry && selectedEntry <= lastEntry`.
  - *Mutual exclusion of resolution (`NftWon` / `CashWon`) and `Refunding`:* In `Status.Drawing`, `fulfillRandomWords` resolves only when `block.timestamp < callbackDeadline()` (`L512`), whereas `enableRefunds` transitions `Status.Drawing` to `Status.Refunding` only when `block.timestamp >= callbackDeadline()` (`L289-L291`). Once either function mutates `status` out of `Status.Drawing` (`L521` or `L299`), the other function's `status == Status.Drawing` check (`L511` or `L289`) prevents it from executing its state transition.
  - *In-flight synchronous callback exclusion:* In `requestDraw` (`L252-L260`), `status` becomes `Status.Drawing` at `L252` before `vrfRequestId` is assigned at `L259`. Setting `_requestInFlight = true` at `L254` before calling `requestRandomnessPayInNative` (`L257`) and clearing it at `L260` after `vrfRequestId = requestId` (`L259`) ensures that `_requestInFlight` at `L511` blocks any synchronous callback during `L257` from matching a pre-assignment `vrfRequestId` (`0`).

---

**Open Questions:**
- None within the repository's Solidity sources; `i_vrfV2PlusWrapper` internal fulfillment implementation is external to the repository (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L4-L83`).
