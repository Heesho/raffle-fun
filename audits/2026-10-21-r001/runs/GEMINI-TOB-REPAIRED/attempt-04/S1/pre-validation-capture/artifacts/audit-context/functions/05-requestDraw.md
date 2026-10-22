## `requestDraw` in packages/contracts/src/Raffle.sol (L240-L273)

**Purpose:** Permissionlessly transitions a sold active raffle after `endTime` and before `drawRequestDeadline()` into `Status.Drawing`, pays the Chainlink VRF v2.5 native wrapper using caller-supplied ETH to request one random word, records the resulting `vrfRequestId` and `drawRequestedAt` timestamp while guarding against synchronous callback resolution via `_requestInFlight`, and refunds any excess `msg.value` to `msg.sender`. Without this function, a raffle with sold entries (`totalEntries > 0`) cannot enter `Status.Drawing` or receive randomness to resolve into `Status.NftWon` or `Status.CashWon`, and can only eventually transition to `Status.Refunding` via `enableRefunds()` at or after `drawRequestDeadline()` (`packages/contracts/src/Raffle.sol:L285-L288`).

---

**Inputs & Assumptions:**
- Explicit parameters: None (`packages/contracts/src/Raffle.sol:L240`).
- Implicit inputs:
  - `msg.sender` (`address`): Draw requester and recipient of any excess native ETH refund (`packages/contracts/src/Raffle.sol:L265,L269,L272`). Trust: **untrusted** (permissionless external caller).
  - `msg.value` (`uint256`): Native ETH attached to the call to fund the Chainlink VRF v2.5 wrapper fee (`packages/contracts/src/Raffle.sol:L250,L258,L262`). Trust: **untrusted**.
  - `block.timestamp` (`uint256`): Current EVM block timestamp used to validate the `[endTime, drawRequestDeadline())` request window (`packages/contracts/src/Raffle.sol:L242,L245`) and persisted as `uint64(block.timestamp)` in `drawRequestedAt` (`packages/contracts/src/Raffle.sol:L253`). Trust: **trusted** (EVM environment).
  - Storage read:
    - `status` (`IRaffle.Status`, `packages/contracts/src/Raffle.sol:L124`), read via `_requireStatus(Status.Active)` (`packages/contracts/src/Raffle.sol:L241,L572`).
    - `endTime` (`uint64`, `packages/contracts/src/Raffle.sol:L82`), read at `packages/contracts/src/Raffle.sol:L242` and via `drawRequestDeadline()` at `packages/contracts/src/Raffle.sol:L244,L459`.
    - `totalEntries` (`uint128`, `packages/contracts/src/Raffle.sol:L85`), read at `packages/contracts/src/Raffle.sol:L243`.
    - `drawRequestedAt` (`uint64`, `packages/contracts/src/Raffle.sol:L111`), written at `packages/contracts/src/Raffle.sol:L253` and read at `packages/contracts/src/Raffle.sol:L272` and via `callbackDeadline()` (`packages/contracts/src/Raffle.sol:L464`).
    - `REENTRANCY_GUARD_STORAGE` (`0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`), read and written by `nonReentrant` (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L36-L37,L69-L73,L88-L106`).
  - Immutables and constants read:
    - `i_vrfV2PlusWrapper` (`IVRFV2PlusWrapper`, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L35`), read in `getVrfRequestPrice()` (`packages/contracts/src/Raffle.sol:L437`) and `requestRandomnessPayInNative()` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L82,L84`). Trust: **trusted**.
    - `callbackGasLimit` (`uint32 = 300_000`, `packages/contracts/src/Raffle.sol:L47`, `packages/contracts/src/libraries/RaffleConstants.sol:L39`).
    - `requestConfirmations` (`uint16 = 30`, `packages/contracts/src/Raffle.sol:L50`, `packages/contracts/src/libraries/RaffleConstants.sol:L42`).
    - `RaffleConstants.DRAW_REQUEST_TIMEOUT` (`uint256 = 2 days`, `packages/contracts/src/libraries/RaffleConstants.sol:L33`).
    - `RaffleConstants.DRAW_CALLBACK_TIMEOUT` (`uint256 = 2 days`, `packages/contracts/src/libraries/RaffleConstants.sol:L36`).
- Preconditions and assumptions:
  - **Precondition:** The call is not a nested re-entry into a `nonReentrant` function on this clone. Established by `nonReentrant` (`packages/contracts/src/Raffle.sol:L240`, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L100`).
  - **Precondition:** `status == Status.Active`. Established by `_requireStatus(Status.Active)` (`packages/contracts/src/Raffle.sol:L241,L571-L573`). Because the shared implementation constructor sets `status = Status.Refunding` (`packages/contracts/src/Raffle.sol:L165`) and a clone only enters `Status.Active` in `onERC721Received` (`packages/contracts/src/Raffle.sol:L428`), this also establishes that the target is an initialized clone holding the escrowed prize.
  - **Precondition:** `block.timestamp >= endTime`. Established by `if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp)` (`packages/contracts/src/Raffle.sol:L242`).
  - **Precondition:** `totalEntries > 0`. Established by `if (totalEntries == 0) revert NoEntriesSold()` (`packages/contracts/src/Raffle.sol:L243`).
  - **Precondition:** `block.timestamp < uint256(endTime) + 2 days`. Established by `if (block.timestamp >= requestDeadline) revert DrawRequestWindowExpired(requestDeadline, block.timestamp)` (`packages/contracts/src/Raffle.sol:L244-L247`, `packages/contracts/src/Raffle.sol:L458-L460`).
  - **Precondition:** `msg.value >= quotedFee` and `msg.value >= paidPrice`. Established by `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` (`packages/contracts/src/Raffle.sol:L250`) and `if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value)` (`packages/contracts/src/Raffle.sol:L258`).
  - **Assumption:** `block.timestamp` fits within `uint64` without high-bit truncation when cast via `drawRequestedAt = uint64(block.timestamp)` (`packages/contracts/src/Raffle.sol:L253`), and `uint64(block.timestamp) != 0` so `callbackDeadline()` (`packages/contracts/src/Raffle.sol:L463-L465`) does not take its `drawRequestedAt == 0` branch and return `0`.
    - Lower bound `block.timestamp >= 1`: Established by `if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime)` in `packages/contracts/src/RaffleFactory.sol:L100` (which enforces `endTime >= 1` since `currentTime` is `uint256`) together with `if (block.timestamp < endTime) revert RaffleNotEnded(...)` at `packages/contracts/src/Raffle.sol:L242`.
    - Upper bound `block.timestamp <= type(uint64).max`: `packages/contracts/src/Raffle.sol:L244-L247` bounds `block.timestamp < uint256(endTime) + 2 days` where `endTime` is `uint64`; if `endTime > type(uint64).max - 2 days`, `uint256(endTime) + 2 days` exceeds `type(uint64).max`. Non-overflow of `uint64(block.timestamp)` is established by `nothing found` in contract code (relies on chain clock remaining below `2^64`).
  - **Assumption:** `i_vrfV2PlusWrapper` implements `calculateRequestPriceNative` and `requestRandomWordsInNative` without reverting for `callbackGasLimit = 300_000`, `requestConfirmations = 30`, `numWords = 1`, and `ExtraArgsV1({ nativePayment: true })`, accepts `requestPrice` wei matching the price returned by `calculateRequestPriceNative` at `VRFV2PlusWrapperConsumerBase.sol:L82`, and returns a `requestId` that it will later supply to `rawFulfillRandomWords`.
    - Non-zero address and non-empty code at deployment: Established by `_validatedVrfWrapper` (`packages/contracts/src/Raffle.sol:L157,L610-L613`), `_requireContract(vrfWrapper_)` (`packages/contracts/src/RaffleFactory.sol:L67,L183-L185`), and `vrfV2PlusWrapper.link()` in `VRFV2PlusWrapperConsumerBase.constructor` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L45`).
    - Runtime wrapper liveness, parameter acceptance (e.g., wrapper `maxNumWords`, `maxGasLimit`, or confirmation bounds vs. `300_000` gas and `30` confirmations), and price consistency: Established by `nothing found` in repository source (external contract `i_vrfV2PlusWrapper` is outside the repository).
  - **Assumption:** When `excess = msg.value - paidPrice > 0`, `msg.sender` accepts a native ETH transfer via `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` (`packages/contracts/src/Raffle.sol:L267`) without reverting or exhausting gas. Established by `if (!success) revert NativeRefundFailed(msg.sender, excess)` (`packages/contracts/src/Raffle.sol:L269`), which reverts the transaction if `msg.sender` rejects the refund.

---

**Outputs & Effects:**
- Return value: `uint256 requestId`, the identifier returned by `i_vrfV2PlusWrapper.requestRandomWordsInNative` (`packages/contracts/src/Raffle.sol:L240,L257`, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L84-L86`).
- State writes:
  - `REENTRANCY_GUARD_STORAGE` slot set to `ENTERED` (`2`) on entry and `NOT_ENTERED` (`1`) on exit (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L99,L105`).
  - `status = Status.Drawing` (`packages/contracts/src/Raffle.sol:L252`).
  - `drawRequestedAt = uint64(block.timestamp)` (`packages/contracts/src/Raffle.sol:L253`).
  - `_requestInFlight` set to `true` at `packages/contracts/src/Raffle.sol:L254` and reset to `false` at `packages/contracts/src/Raffle.sol:L260` (net change after exit: remains `false`).
  - `vrfRequestId = requestId` (`packages/contracts/src/Raffle.sol:L259`).
- External interactions:
  1. `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (`STATICCALL`) via `getVrfRequestPrice()` (`packages/contracts/src/Raffle.sol:L249,L437`).
  2. `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (`STATICCALL`) inside `requestRandomnessPayInNative()` (`packages/contracts/src/Raffle.sol:L257`, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L82`).
  3. `i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(callbackGasLimit, requestConfirmations, 1, extraArgs)` (`CALL` with `requestPrice` wei) inside `requestRandomnessPayInNative()` (`packages/contracts/src/Raffle.sol:L257`, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L84-L86`).
  4. `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` (`CALL` with `excess = msg.value - paidPrice` wei and empty calldata to `msg.sender`) when `excess != 0` (`packages/contracts/src/Raffle.sol:L263-L270`).
- Events emitted:
  - `DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline())` (`packages/contracts/src/Raffle.sol:L272`).
- Postconditions on success:
  - `status == Status.Drawing` (unless `i_vrfV2PlusWrapper` was triggered during the `L267` refund call to synchronously fulfill `requestId`; see Block-by-Block for `L262-L270`).
  - `drawRequestedAt == uint64(block.timestamp)` and `callbackDeadline() == uint256(drawRequestedAt) + 2 days`.
  - `vrfRequestId == requestId` and `_requestInFlight == false`.
  - Net native ETH retained by `address(this)` from `msg.value` is `0` (`paidPrice` sent to `i_vrfV2PlusWrapper`, `msg.value - paidPrice` returned to `msg.sender`).

---

**Block-by-Block:**

```solidity
// L240-L247
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }
```
- **What:** Acquires the reentrancy lock and enforces that the raffle is in `Status.Active`, at least one entry has been sold, and `block.timestamp` lies in `[endTime, drawRequestDeadline())`.
- **Why here:** Fail-fast lifecycle and window validation before any external calls or storage writes.
- **Assumes:** `endTime` was initialized to a valid timestamp and `uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT` (`drawRequestDeadline()`, `packages/contracts/src/Raffle.sol:L458-L460`) does not overflow `uint256` (guaranteed because `endTime` is `uint64`).
- **Establishes:** `status == Status.Active`, `totalEntries >= 1`, and `endTime <= block.timestamp < uint256(endTime) + 2 days`.
- **Depended on by:** `fulfillRandomWords` (`packages/contracts/src/Raffle.sol:L518`), which divides modulo `uint256(totalEntries)` and relies on `totalEntries > 0`; `enableRefunds` (`packages/contracts/src/Raffle.sol:L285-L288`), which is mutually exclusive with this window when `status == Status.Active` and `totalEntries > 0`.

```solidity
// L249-L250
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);
```
- **What:** Queries `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` via `getVrfRequestPrice()` (`packages/contracts/src/Raffle.sol:L436-L438`) and reverts with `InsufficientVrfFee` if `msg.value < quotedFee`.
- **Why here:** Rejects underfunded calls with a typed `InsufficientVrfFee` error before mutating state or attempting the payable call inside `requestRandomnessPayInNative` (which would otherwise fail with a generic EVM out-of-balance revert if `address(this).balance < requestPrice`, or consume pre-existing ETH force-sent to `address(this)`).
- **Assumes:** `i_vrfV2PlusWrapper.calculateRequestPriceNative(300_000, 1)` does not revert.
- **Establishes:** `msg.value >= quotedFee` for the first price quote. Because `i_vrfV2PlusWrapper` is an external contract queried a second time inside `requestRandomnessPayInNative`, this check alone does not establish `msg.value >= paidPrice`; `L258` enforces the post-call bound.
- **Depended on by:** `L257` (`requestRandomnessPayInNative`), ensuring `address(this).balance >= msg.value >= quotedFee` when `quotedFee == paidPrice`.

```solidity
// L252-L260
status = Status.Drawing;
drawRequestedAt = uint64(block.timestamp);
_requestInFlight = true;
bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
uint256 paidPrice;
(requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
vrfRequestId = requestId;
_requestInFlight = false;
```
- **What:** Sets `status = Status.Drawing`, records `drawRequestedAt`, sets `_requestInFlight = true`, encodes VRF v2.5 native-payment `extraArgs`, calls `requestRandomnessPayInNative` to pay the wrapper and obtain `(requestId, paidPrice)`, verifies `paidPrice <= msg.value`, stores `vrfRequestId = requestId`, and clears `_requestInFlight = false`.
- **Why here:** `status`, `drawRequestedAt`, and `_requestInFlight = true` are written *before* the external payable call to `i_vrfV2PlusWrapper.requestRandomWordsInNative` inside `requestRandomnessPayInNative` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L84-L86`). Because `vrfRequestId` cannot be known until `requestRandomWordsInNative` returns (`L257,L259`) and `rawFulfillRandomWords` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`) is not `nonReentrant`, setting `_requestInFlight = true` at `L254` forces `fulfillRandomWords` (`packages/contracts/src/Raffle.sol:L510-L516`) to ignore any synchronous callback from the wrapper during `L257` (when `vrfRequestId` is still `0`).
- **Assumes:**
  - `block.timestamp` fits in `uint64` at `L253` (established by `nothing found` in contract code beyond `block.timestamp < uint256(endTime) + 2 days` at `L245`).
  - `i_vrfV2PlusWrapper` accepts the request and returns `(requestId, paidPrice)`.
- **Establishes:**
  - `status == Status.Drawing` (`L252`).
  - `drawRequestedAt == uint64(block.timestamp) >= 1` (`L253`, given `block.timestamp >= endTime >= 1` from `packages/contracts/src/RaffleFactory.sol:L100` and `packages/contracts/src/Raffle.sol:L242` assuming no `uint64` wrap).
  - `paidPrice <= msg.value` (`L258`), ensuring the caller's `msg.value` alone funded `paidPrice` and that `msg.value - paidPrice` at `L262` cannot underflow.
  - `vrfRequestId == requestId` (`L259`) and `_requestInFlight == false` (`L260`).
- **Depended on by:** `L262` (underflow-free subtraction `msg.value - paidPrice`), `L272` (`callbackDeadline()` reading `drawRequestedAt`), `fulfillRandomWords` (`packages/contracts/src/Raffle.sol:L510-L516` reading `_requestInFlight`, `status`, `vrfRequestId`, and `callbackDeadline()`), and `enableRefunds` (`packages/contracts/src/Raffle.sol:L289-L291` reading `status == Status.Drawing` and `callbackDeadline()`).

```solidity
// L262-L270
uint256 excess = msg.value - paidPrice;
if (excess != 0) {
    bool success;
    address refundRecipient = msg.sender;
    assembly ("memory-safe") {
        success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
    }
    if (!success) revert NativeRefundFailed(msg.sender, excess);
}
```
- **What:** Computes `excess = msg.value - paidPrice` and, if non-zero, returns `excess` wei to `msg.sender` via a low-level `call` with empty calldata and zero output buffer, reverting with `NativeRefundFailed(msg.sender, excess)` if the call fails.
- **Why here:** Placed after all state updates (`status`, `drawRequestedAt`, `vrfRequestId`, `_requestInFlight`) and after `paidPrice` has been paid to the wrapper (`L257`) and validated against `msg.value` (`L258`). Using `0, 0` for return data in assembly avoids copying arbitrary return data into memory from an untrusted `msg.sender`.
- **Assumes:** When `excess != 0`, `msg.sender` does not revert or exhaust gas on receiving native ETH (enforced by `L269`, which reverts `msg.sender`'s own transaction if `!success`). Note that at `L267`, `_requestInFlight` has already been reset to `false` (`L260`), `status` is `Status.Drawing` (`L252`), and `vrfRequestId` is set (`L259`), while `nonReentrant` remains `ENTERED`; no `nonReentrant` function on `Raffle` can be re-entered during `L267`, while `rawFulfillRandomWords` is restricted to `msg.sender == address(i_vrfV2PlusWrapper)` (`VRFV2PlusWrapperConsumerBase.sol:L103`).
- **Establishes:** All excess native ETH from `msg.value` above `paidPrice` has been transferred out of `address(this)` to `msg.sender`.
- **Depended on by:** `L272`, which records `excess` as `excessReturned` in `DrawRequested`.

```solidity
// L272-L273
    emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
}
```
- **What:** Emits `DrawRequested` with the wrapper `requestId`, `msg.sender`, `paidPrice`, `excess`, `drawRequestedAt`, and `callbackDeadline()`, and returns `requestId`.
- **Why here:** Emitted only after the VRF request and any native refund have succeeded.
- **Assumes:** `drawRequestedAt != 0` so `callbackDeadline()` (`packages/contracts/src/Raffle.sol:L463-L465`) returns `uint256(drawRequestedAt) + 2 days`.
- **Establishes:** Off-chain indexers observe the recorded request parameters and callback deadline.
- **Depended on by:** Off-chain callers and indexers tracking the draw lifecycle.

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` (`_nonReentrantBefore` / `_nonReentrantAfter`, internal, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L106`):**
  - Reads `REENTRANCY_GUARD_STORAGE` (`0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`), reverts with `ReentrancyGuardReentrantCall()` if the value equals `ENTERED` (`2`, `L89-L91,L113`), writes `ENTERED` (`2`, `L99`) before the body, and writes `NOT_ENTERED` (`1`, `L105`) after the body.
  - On a fresh ERC-1167 clone (`packages/contracts/src/RaffleFactory.sol:L106`), the slot value is initially `0` (since `ReentrancyGuard.constructor` at `L58-L60` ran on the implementation contract, not the clone); because `_reentrancyGuardEntered()` checks `value == ENTERED` (`2`), `0` is treated as not entered on the first call and set to `NOT_ENTERED` (`1`) upon completion.
  - Protects all `nonReentrant` entrypoints on `Raffle`, but does not apply to `rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:L101`), `onERC721Received` (`Raffle.sol:L416`), `initialize` (`Raffle.sol:L176`), or ERC-721 transfer/approval functions (`ERC721.sol`).
- **Callee `Raffle._requireStatus` (internal, `packages/contracts/src/Raffle.sol:L571-L573`):**
  - Single path: reverts with `InvalidStatus(status)` if `status != expected` (`L572`); returns otherwise.
- **Callee `Raffle.drawRequestDeadline` (internal, `packages/contracts/src/Raffle.sol:L458-L460`):**
  - Single path: returns `uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT` (`L459`, where `DRAW_REQUEST_TIMEOUT = 2 days` at `packages/contracts/src/libraries/RaffleConstants.sol:L33`).
- **Callee `Raffle.getVrfRequestPrice` (internal, `packages/contracts/src/Raffle.sol:L436-L438`):**
  - Single path: returns `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (`L437`).
- **Callee `VRFV2PlusClient._argsToBytes` (internal, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol:L22-L26`):**
  - Single path: returns `abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs)` (`L25`), where `EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"))` (`L7`).
- **Callee `VRFV2PlusWrapperConsumerBase.requestRandomnessPayInNative` (internal, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L89`):**
  - Calls `requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords)` (`L82`) and then calls `i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(_callbackGasLimit, _requestConfirmations, _numWords, extraArgs)` (`L84-L86`), returning `(requestId, requestPrice)`.
  - Does not check that `requestPrice <= msg.value` (it transfers `requestPrice` from `address(this).balance`); `requestDraw` establishes `paidPrice <= msg.value` immediately after at `packages/contracts/src/Raffle.sol:L258`.
- **Callee `IVRFV2PlusWrapper.calculateRequestPriceNative` & `IVRFV2PlusWrapper.requestRandomWordsInNative` (external-black-box, `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L33,L74-L79`):**
  - Target is `i_vrfV2PlusWrapper` (immutable set in `VRFV2PlusWrapperConsumerBase.constructor`, `L46`).
  - `calculateRequestPriceNative(300_000, 1)` is invoked twice via `STATICCALL` (`Raffle.sol:L437` and `VRFV2PlusWrapperConsumerBase.sol:L82`).
  - `requestRandomWordsInNative{value: requestPrice}(300_000, 30, 1, extraArgs)` is invoked via `CALL` (`VRFV2PlusWrapperConsumerBase.sol:L84-L86`).
  - Unexcluded black-box outcomes: revert (which aborts `requestDraw`), returning a `requestPrice` higher than `quotedFee` (caught by `Raffle.sol:L258` if `paidPrice > msg.value`), returning an arbitrary `requestId` (stored directly in `vrfRequestId` at `Raffle.sol:L259`), or synchronously calling `rawFulfillRandomWords` before returning (ignored by `Raffle.fulfillRandomWords` at `Raffle.sol:L511` because `_requestInFlight == true`).
- **Callee `msg.sender` via `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` (external-black-box, `packages/contracts/src/Raffle.sol:L266-L268`):**
  - Invoked only when `excess = msg.value - paidPrice != 0` (`L263`).
  - Sends `excess` wei with empty calldata and all remaining gas to `msg.sender`.
  - Unexcluded black-box outcomes: revert or out-of-gas in `msg.sender` (caught by `if (!success) revert NativeRefundFailed(msg.sender, excess)` at `L269`, which rolls back the entire `requestDraw` call), or re-entering non-`nonReentrant` functions on `Raffle` (ERC-721 ticket transfers or view functions).
- **Callee `Raffle.callbackDeadline` (internal, `packages/contracts/src/Raffle.sol:L463-L465`):**
  - Two paths:
    1. When `drawRequestedAt != 0` (`L464`): returns `uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT` (`drawRequestedAt + 2 days`).
    2. When `drawRequestedAt == 0` (`L464` branch skipped): returns `0`.
  - In `requestDraw` (`L272`), `drawRequestedAt` was written at `L253` as `uint64(block.timestamp)` where `block.timestamp >= endTime >= 1` (`RaffleFactory.sol:L100`, `Raffle.sol:L242`), taking path 1 assuming `uint64(block.timestamp) != 0`.
- **Callers:** None internal; external permissionless entrypoint (`packages/contracts/src/Raffle.sol:L240`).
- **Shared state:**
  - `status`: shared with `constructor` (`L165`), `initialize` (`L205`), `buyEntries` (`L215`), `enableRefunds` (`L279,L289,L299`), `redeemWinningTicket` (`L311`), `refundTickets` (`L350`), `releaseSponsorPrize` (`L396`), `onERC721Received` (`L422,L428`), `fulfillRandomWords` (`L511,L521`), `_settleWinningTicket` (`L535`).
  - `endTime`: shared with `initialize` (`L204`), `buyEntries` (`L216`), `enableRefunds` (`L281`), `drawRequestDeadline` (`L459`).
  - `totalEntries`: shared with `buyEntries` (`L219,L226,L227,L230`), `enableRefunds` (`L280`), `grossSales` (`L474`), `fulfillRandomWords` (`L518,L521`).
  - `drawRequestedAt`: shared with `callbackDeadline` (`L464`), which is called by `enableRefunds` (`L290`) and `fulfillRandomWords` (`L512`).
  - `_requestInFlight`: shared with `fulfillRandomWords` (`L511`).
  - `vrfRequestId`: shared with `fulfillRandomWords` (`L511,L514`).
- **Invariant couplings:**
  - **Lifecycle partitioning (`Active` -> `Drawing` vs. `Refunding`):** For a raffle with `totalEntries > 0`, `buyEntries` is restricted to `block.timestamp < endTime` (`L216`), `requestDraw` is restricted to `endTime <= block.timestamp < drawRequestDeadline()` (`L242,L245`), and `enableRefunds` from `Status.Active` is restricted to `block.timestamp >= drawRequestDeadline()` (`L286-L287`). Once `requestDraw` sets `status = Status.Drawing` (`L252`), `requestDraw` can never be called again (`L241`), and the raffle can exit `Status.Drawing` only via `fulfillRandomWords` before `callbackDeadline()` (`L511-L512`) or via `enableRefunds` at or after `callbackDeadline()` (`L289-L291`).
  - **In-flight callback guard (`_requestInFlight` and `vrfRequestId`):** `fulfillRandomWords` (`L511`) checks `_requestInFlight || status != Status.Drawing || requestId != vrfRequestId`. Because `vrfRequestId` is `0` prior to `L259` and `status` becomes `Status.Drawing` at `L252`, `_requestInFlight = true` (`L254-L260`) bridges the window during `requestRandomnessPayInNative` (`L257`) before `vrfRequestId` is written at `L259`.
  - **Positive entry count for modulo resolution:** `if (totalEntries == 0) revert NoEntriesSold()` (`L243`) establishes `totalEntries >= 1` for every raffle that reaches `Status.Drawing`, which `fulfillRandomWords` (`L518`) relies on when computing `(randomWords[0] % uint256(totalEntries)) + 1`.
  - **Native ETH conservation:** `receive()` always reverts (`L171-L173`), and `requestDraw` requires `paidPrice <= msg.value` (`L258`), forwards `paidPrice` to `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L84`), and refunds `msg.value - paidPrice` to `msg.sender` (`L262-L270`), leaving `0` net native ETH from the call in `address(this)`.

---

**Open Questions:**
- unclear; need to inspect the deployed target-chain `i_vrfV2PlusWrapper` implementation to verify that `VRF_CALLBACK_GAS_LIMIT = 300_000` (`packages/contracts/src/libraries/RaffleConstants.sol:L39`) and `VRF_REQUEST_CONFIRMATIONS = 30` (`packages/contracts/src/libraries/RaffleConstants.sol:L42`) lie within the wrapper's and underlying VRF coordinator's configured `[minRequestConfirmations, maxRequestConfirmations]` and `maxGasLimit` bounds on the target chain.
