## `requestDraw` in packages/contracts/src/Raffle.sol (L240-L273)

Citation key. Bare `Lnnn` means `packages/contracts/src/Raffle.sol`. Other files use these prefixes:

| Prefix | File (relative to `packages/contracts/`) |
| --- | --- |
| `RG` | `node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` |
| `VCB` | `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` |
| `VC` | `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` |
| `IW` | `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` |
| `E721` | `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` |
| `RC` | `src/libraries/RaffleConstants.sol` |
| `IR` | `src/interfaces/IRaffle.sol` |
| `RF` | `src/RaffleFactory.sol` |

```solidity
// L240-L273
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }

    uint256 quotedFee = getVrfRequestPrice();
    if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

    status = Status.Drawing;
    drawRequestedAt = uint64(block.timestamp);
    _requestInFlight = true;
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
    uint256 paidPrice;
    (requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
    if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
    vrfRequestId = requestId;
    _requestInFlight = false;

    uint256 excess = msg.value - paidPrice;
    if (excess != 0) {
        bool success;
        address refundRecipient = msg.sender;
        assembly ("memory-safe") {
            success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
        }
        if (!success) revert NativeRefundFailed(msg.sender, excess);
    }

    emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
}
```

**Purpose:** `requestDraw` is the only transition from `Active` to `Drawing`. L252 is the only line in the codebase that writes `Status.Drawing` (grep of `status\s*=` returns L165, L205, L252, L299, L428, L521). It does four things:

- Commits the raffle to exactly one Chainlink VRF v2.5 native-payment request.
- Records the request timestamp (`drawRequestedAt`, L253). That timestamp anchors the callback window used by `fulfillRandomWords` (L512) and by the `Drawing` branch of `enableRefunds` (L290).
- Records the request ID (`vrfRequestId`, L259). `fulfillRandomWords` matches incoming callbacks against it (L511).
- Makes the caller fund the native fee, returning any surplus to them.

Without this function a sold raffle has one path out of `Active`: `enableRefunds` once `block.timestamp >= endTime + 2 days` (L285-L288). `NftWon` and `CashWon` can only be reached after a successful `requestDraw`, because `fulfillRandomWords` resolves only while `status == Drawing` (L511).

---

**Inputs & Assumptions:**

- No parameters.
- `msg.value` (uint256): native wei attached by the caller. Trust: **untrusted** in size. The function treats it as the fee budget. It is compared against two separate wrapper quotes (L250, L258), and the remainder is returned (L262-L270).
- `msg.sender`: any EOA or contract. Trust: **untrusted** (system context, "Draw requester"). The function never checks the caller's identity. It is used as the refund recipient (L265), in the revert payload (L269) and in the event (L272).
- Implicit storage reads:
  - `status` (L241, via L573-L575).
  - `endTime` (L242; L459 via `drawRequestDeadline`). Its only writer is `initialize` at L204.
  - `totalEntries` (L243). Its only writer is `buyEntries` at L230.
  - `drawRequestedAt` (L272 and L464, after this function writes it at L253).
  - The ReentrancyGuard slot (`RG` L36-L37, L94-L106).
- Implicit environment:
  - `block.timestamp` (L242, L245, L253).
  - `tx.gasprice`. The wrapper's native price depends on it (`IW` L27-L28, L33), and the caller chooses it.
  - Remaining gas, forwarded in full to `msg.sender` at L267.
  - The clone's native balance. On entry it is `msg.value` plus any balance forced in earlier. `receive` always reverts (L171-L173) and there is no `fallback` (grep), so earlier balance can only come from forced sends.
- Implicit immutables:
  - `i_vrfV2PlusWrapper` (`VCB` L35, set at `VCB` L46). It is shared by every clone because it lives in the implementation bytecode.
  - `callbackGasLimit = 300_000` (L47, `RC` L39) and `requestConfirmations = 30` (L50, `RC` L42).
- Preconditions and what establishes each:
  - Clone, not implementation. The implementation is locked at `Refunding` (L165), so L241 always reverts there. Established by L165 together with L241.
  - `status == Active`. Established by L241. A clone reaches `Active` only via `onERC721Received` L428, which is gated on `AwaitingPrize` and factory-operated delivery (L421-L426). That happens atomically inside `RaffleFactory.createRaffle` (`RF` L128-L134).
  - `endTime <= block.timestamp < endTime + 2 days`. Established by L242 and L244-L247.
  - `endTime >= 1`. Established by `RF` L100 (`params.endTime <= currentTime` reverts, so `endTime > creation timestamp >= 0`). L253/L464 depend on it to make `drawRequestedAt` non-zero.
  - `totalEntries >= 1`. Established by L243.
  - Fee coverage: `msg.value >= quotedFee` is established by L250, and `msg.value >= paidPrice` by L258.
  - `i_vrfV2PlusWrapper` is the canonical Chainlink VRF v2.5 native wrapper. Established only by the deployer's choice. On-chain checks are limited to: non-zero (`_validatedVrfWrapper`, L610-L613), contract code present at factory construction (`RF` L67, L183-L185), and a successful `link()` call in the base constructor (`VCB` L45). Nothing verifies its identity or behaviour.

---

**Outputs & Effects:**

- **Returns:** `requestId`, the raw value returned by `requestRandomWordsInNative` (`VCB` L84-L86) and assigned at L257. It is written on every non-reverting path.
- **Storage writes (all before the untrusted call at L267):**
  - `status = Drawing` (L252).
  - `drawRequestedAt = uint64(block.timestamp)` (L253). This narrowing conversion has no check.
  - `_requestInFlight = true` (L254), then `false` (L260). The net value after the transaction is `false`.
  - `vrfRequestId = requestId` (L259).
  - ReentrancyGuard slot: `ENTERED` (2) for the duration of the body, `NOT_ENTERED` (1) afterwards (`RG` L99, L105).
- **External interactions, in order:**
  1. STATICCALL `wrapper.calculateRequestPriceNative(300_000, 1)` via `getVrfRequestPrice` (L249 → L437). It is declared `view` at `IW` L33, so it is a static call.
  2. STATICCALL `wrapper.calculateRequestPriceNative(300_000, 1)` again, inside the base (`VCB` L82).
  3. CALL `wrapper.requestRandomWordsInNative{value: requestPrice}(300_000, 30, 1, extraArgs)` (`VCB` L84-L86). This is a state-changing call carrying value.
  4. Only if `excess != 0`: a raw CALL to `msg.sender` with value `excess`, all available gas, empty calldata, and no returndata copy (L267).
- **Events:**
  - `DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline())` (L272; declared at `IR` L89-L96). It is emitted after both external calls.
  - If the wrapper calls back synchronously during step 3, `VrfCallbackIgnored(requestId, 0, Drawing)` is emitted by `fulfillRandomWords` (L514) before `DrawRequested`.
- **Postconditions on success:**
  - `status == Drawing`.
  - `drawRequestedAt == block.timestamp`, which lies in `[endTime, endTime + 2 days)`.
  - `vrfRequestId == requestId`.
  - `_requestInFlight == false`.
  - `callbackDeadline() == drawRequestedAt + 2 days`, which lies in `[endTime + 2d, endTime + 4d)` (L464, `RC` L36).
  - `totalEntries >= 1`, with no further sales possible because `buyEntries` checks status at L215.
  - The clone's native balance is unchanged. All of `msg.value` leaves: `paidPrice` to the wrapper and `excess` to the caller.
- **Untouched:** `unsettledPot`, all quote-token accounting, the quote token, and the prize NFT. No quote-token or ERC-721 calls are made (L240-L273). The VRF fee is funded only by `msg.value` and never from the pot.
- **Atomicity:** every revert path (L241, L242, L243, L246, L250, wrapper reverts, L258, L269, or out-of-gas in the tail) rolls back all of the writes above. That includes `_requestInFlight`, so the flag cannot remain `true` after a transaction ends.

---

**Block-by-Block:**

```solidity
// L240
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
```
- **What:** declares a permissionless, payable, guarded external entry point with a named return.
- **Guard mechanics (`RG`, read in full):**
  - `_nonReentrantBefore` (`RG` L94-L100) reverts if the slot equals `ENTERED` (2) (`RG` L88-L92, L112-L114), then writes 2.
  - `_nonReentrantAfter` (`RG` L102-L106) writes 1 unconditionally after the body.
  - In a fresh clone the slot is 0, because the guard constructor (`RG` L58-L60) runs only for the implementation. That still counts as not-entered, since the comparison is `== ENTERED` (`RG` L113).
  - The slot lives in each clone's own storage. Raffle does not override `_reentrancyGuardStorageSlot` (grep).
- **Why here:** the body makes two non-static calls: `VCB` L84 to the wrapper and L267 to `msg.sender`. While either is in progress, all eight other guarded functions on this clone revert: `buyEntries` L212, `enableRefunds` L276, `settleWinningTicket` L304, `redeemWinningTicket` L309, `refundTickets` L349, `releaseSponsorProceeds` L375, `releaseProtocolFees` L385 and `releaseSponsorPrize` L395. A nested `requestDraw` also reverts.
- **Not covered by the guard:**
  - `rawFulfillRandomWords` (`VCB` L101-L107), which leads into `fulfillRandomWords` L509.
  - `onERC721Received` (L416-L431).
  - `initialize` (L176).
  - `receive` (L171).
  - ERC-721 `approve` / `setApprovalForAll` / `transferFrom` / `safeTransferFrom` (`E721` L93, L105, L115, L128, L133).
  - All views.
- **Establishes:** on entry, no guarded function of this clone is on the call stack. Until the function returns, none can run.
- **Depended on by:** the "after the call" logic in L258-L272. In particular, L267 hands control to an untrusted address while this guard is held.

```solidity
// L241
_requireStatus(Status.Active);
```
- **What:** reverts with `InvalidStatus(status)` unless `status == Active`. `_requireStatus` (L573-L575) has a single branch.
- **Why here:** it is the first check, so the implementation (status `Refunding`, L165) and every non-`Active` clone fail before any time arithmetic or external call.
- **Establishes:** `status == Active` on entry. Combined with L252, which leaves `Active`, `requestDraw` can succeed **at most once per clone**. The only write of `Active` is L428, gated on `status == AwaitingPrize` (L422). The only write of `AwaitingPrize` is L205 in one-shot `initialize` (L177, L179). No path returns a clone to `Active` after L252.
- **Depended on by:** the uniqueness of `vrfRequestId` and `drawRequestedAt` (single writer, single successful execution).

```solidity
// L242
if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
```
- **What:** inclusive lower bound of the request window.
- **Why here:** sales end exclusively at `endTime`: `buyEntries` reverts when `block.timestamp >= endTime` (L216). L242 uses the complementary comparison, so `requestDraw` and `buyEntries` are never both available at the same timestamp.
- **Assumes:** `endTime` was written by `initialize` (L204) and is bounded by the factory to `(createTime, createTime + 30 days]` (`RF` L100-L104).
- **Establishes:** `block.timestamp >= endTime >= 1`. This is the basis for `drawRequestedAt != 0` at L253.
- **Depended on by:** L253 and L464. `callbackDeadline()` takes its non-zero branch only when `drawRequestedAt != 0`.

```solidity
// L243
if (totalEntries == 0) revert NoEntriesSold();
```
- **What:** requires at least one sold entry.
- **Why here:** before the fee quote and any writes. An empty raffle never enters `Drawing`; it can only reach `Refunding` through `enableRefunds` (L280-L284).
- **Establishes:** `totalEntries >= 1` on entry to `Drawing`. This persists for the life of the clone:
  - The only writer, `buyEntries`, sets `totalEntries = totalEntries + entryCount` (L227, L230) with `entryCount >= 1` (L218), so the value never decreases.
  - After L252, `buyEntries` is blocked by its status gate (L215).
  - Between L243 and L252 the only external interaction is a STATICCALL (L249), so nothing can change `totalEntries` in between.
- **Depended on by:**
  - `fulfillRandomWords` L518, `randomWords[0] % uint256(totalEntries)`. Its guard condition (L510-L513) does not check `totalEntries`. The non-zero divisor is established here, at the sole entry into `Drawing`, and nowhere else.
  - The outcome classification at L521 (`totalEntries >= reserveEntries`) reads the same frozen value.

```solidity
// L244-L247
uint256 requestDeadline = drawRequestDeadline();
if (block.timestamp >= requestDeadline) {
    revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
}
```
- **What:** exclusive upper bound of the request window.
- **Callee `drawRequestDeadline` (L458-L460):** single path, `uint256(endTime) + 2 days` (`RC` L33). It cannot revert: a `uint64` widened to `uint256` plus 172,800.
- **Why here:** `enableRefunds` uses the **same** function with the complementary comparison for a sold `Active` raffle (L285-L288: `block.timestamp < deadline` reverts). For `Active` with `totalEntries > 0`, the timeline splits cleanly: `[endTime, endTime + 2d)` belongs to `requestDraw` only, and `[endTime + 2d, ∞)` belongs to `enableRefunds` only.
- **Establishes:** `block.timestamp < endTime + 2 days`. Hence `drawRequestedAt ∈ [endTime, endTime + 2d)`.
- **Depended on by:** the range of `callbackDeadline()` (see the postconditions).

```solidity
// L249-L250
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);
```
- **What:** gets the wrapper's current native price for one word at a 300,000 callback gas limit and requires `msg.value` to cover it.
- **Callee `getVrfRequestPrice` (L436-L438):** single path, `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)`.
  - The interface declares it `view` (`IW` L33), so it compiles to STATICCALL and the wrapper cannot change state here.
  - Possible outcomes: a value, a revert that bubbles up, or short returndata that fails ABI decoding.
  - The price depends on `tx.gasprice` (`IW` L27-L28), which the caller controls. `IR` L360 documents that the quote "may change before request inclusion".
- **Why here:** before any storage write and before the payable call. An unavailable wrapper or an underfunded call reverts cheaply, without reaching `requestRandomWordsInNative`.
- **Establishes:** `msg.value >= quotedFee`. This is **not** the binding fee check, because the amount actually sent is quoted a second time inside the base (`VCB` L82). See L258.
- **Assumes:** nothing about equality with the second quote. The two quotes are separate STATICCALLs. They return the same value only if the wrapper's price is constant within a transaction, and nothing in the repository establishes that (see Open Questions).

```solidity
// L252-L254
status = Status.Drawing;
drawRequestedAt = uint64(block.timestamp);
_requestInFlight = true;
```
- **What:** commits the state transition and opens the in-flight window **before** the wrapper call.
- **Why here:** anything that re-enters during `VCB` L84 sees `Drawing` with the request marked in flight.
  - Re-entry into `requestDraw` (L241) or `buyEntries` (L215) also fails on status, in addition to the guard.
  - A wrapper callback is ignored because `_requestInFlight` is `true` (L511). It also fails `requestId != vrfRequestId` for any non-zero `requestId`, since `vrfRequestId` is still 0: it is written only at L259, and the single successful execution makes 0 its prior value.
- **Assumes:** `uint64(block.timestamp)` does not truncate. Explicit narrowing conversions do not revert. Nothing enforces this; it holds for timestamps below 2^64.
- **Establishes:**
  - `status == Drawing` (sole write of `Drawing`).
  - `drawRequestedAt` (sole writer, L253), which is `>= endTime >= 1` by L242 and `RF` L100.
  - `callbackDeadline()` (L463-L465) now returns `drawRequestedAt + 2 days` (`RC` L36), not 0.
- **Depended on by:**
  - `fulfillRandomWords` (L511-L512): status gate and deadline.
  - The `Drawing` branch of `enableRefunds` (L289-L291).
  - The event at L272.

```solidity
// L255-L257
bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
uint256 paidPrice;
(requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
```
- **What:** encodes native-payment extra args and makes the paid request.
- **Callee `VRFV2PlusClient._argsToBytes` (`VC` L22-L26), read in full:** pure, single path. It returns `abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs)`, where the tag is `bytes4(keccak256("VRF ExtraArgsV1"))` (`VC` L7) and the struct is a single `bool` (`VC` L9-L11). The result is a 4-byte tag followed by one 32-byte word encoding `true`. There is no failure path.
- **Callee `requestRandomnessPayInNative` (`VCB` L76-L89), read in full.** Internal, inherited:
  - `VCB` L82: `requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords)`. This is a second STATICCALL quote with the same arguments as L437.
  - `VCB` L84-L86: `i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(...)`. This is a non-static CALL that forwards all gas except the EIP-150 reserve. The value comes from the clone's balance, which is `msg.value` plus any forced balance.
  - `VCB` L83-L88: a single `return (requestId, requestPrice)`.
- **Paths through the base function:**
  - (a) Both calls succeed. **Both outputs are written**, because the single return statement is the only exit. No path returns with an output left unwritten.
  - (b) `VCB` L82 reverts or returns short data: the revert bubbles up.
  - (c) `VCB` L84 reverts, including when `requestPrice` exceeds the clone's balance or returndata is under 32 bytes: the revert bubbles up.
- **What the caller depends on:**
  - `paidPrice` is **exactly the wei sent**: the same local `requestPrice` is used as `{value:}` at `VCB` L84 and returned at `VCB` L87. It is the base's own second quote. It is not a figure the wrapper reports back as consumed.
  - `requestId` is whatever `requestRandomWordsInNative` returned (`VCB` L84). Neither the base nor Raffle checks it for being non-zero, unique, or bound to this clone.
  - The native path uses the direct return value, not `lastRequestId()`. The LINK path does use `lastRequestId()` (`VCB` L72), and the interface warns it is valid only within the same transaction (`IW` L6-L7). The native path does not depend on that.
- **Wrapper calls (black box):** the system context trusts the wrapper, but its source is **not in the repository**. Only `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol` and `VRFV2PlusWrapperConsumerBase.sol` exist under `@chainlink/contracts/src/v0.8/vrf` (glob). `package.json` L28 pins `@chainlink/contracts` 1.5.0.
  - **Sent:** `requestPrice` wei, `_callbackGasLimit = 300_000`, `_requestConfirmations = 30`, `_numWords = 1`, and the 36-byte `extraArgs`.
  - **Outcomes Raffle does not exclude:**
    - A revert, which blocks the draw for this transaction and, if persistent, for the whole window.
    - Any `requestPrice` up to `msg.value`; L258 bounds it only afterwards.
    - Any `requestId` value, including 0 or a value already in use.
    - A synchronous `rawFulfillRandomWords` into this clone, which passes the `msg.sender == wrapper` check at `VCB` L103 and is then ignored at L511.
    - An attempt to send value back to the clone. That would hit `receive()` and revert (L171-L173); there is no `fallback`.
- **What the wrapper sees during the call:** guard held; `status == Drawing`; `drawRequestedAt` set; `_requestInFlight == true`; `vrfRequestId == 0`.
- **Establishes:** `requestId` and `paidPrice`, where `paidPrice` is the wei that left the clone.
- **Depended on by:** L258, L259, L262 and L272.

```solidity
// L258
if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
```
- **What:** the binding fee check, against the value actually sent.
- **Why here:** `paidPrice` exists only after the base has quoted and paid in one internal function (`VCB` L82-L86). The check therefore has to come after the CALL, and a revert here undoes the transfer.
- **Establishes:**
  - `paidPrice <= msg.value`, so the subtraction at L262 cannot underflow.
  - Any balance the clone held before this call is never spent on a successful path. If `requestPrice > msg.value` but forced balance made the CALL at `VCB` L84 succeed, L258 reverts the whole transaction.
- **Note:** L250 and L258 revert with the same error type, `InsufficientVrfFee`. Only the first argument (`quotedFee` vs `paidPrice`) shows which check fired.
- **Depended on by:** L262 and the native-balance-neutrality postcondition.

```solidity
// L259-L260
vrfRequestId = requestId;
_requestInFlight = false;
```
- **What:** records the request ID and closes the in-flight window.
- **Why here:** after the wrapper returns and before the untrusted refund call. All of `requestDraw`'s storage writes are complete before L267.
- **Establishes:** `vrfRequestId` (sole writer, L259), which `fulfillRandomWords` matches at L511 and emits at L514. From L260 on, `fulfillRandomWords` would accept a wrapper-delivered callback carrying `(requestId, [one word])`, because every condition in L510-L513 is false:
  - `_requestInFlight` is `false` (L260).
  - `status == Drawing` (L252).
  - `requestId == vrfRequestId` (L259).
  - The array has length 1.
  - `block.timestamp < drawRequestedAt + 2 days`, since `block.timestamp == drawRequestedAt` (L253).
- **Window:** `_requestInFlight` covers only L254-L260, which is the wrapper call at `VCB` L84. It does **not** cover the refund call at L267. This matches its declaration comment, "True only while the wrapper request call is executing" (L141). During L267, nothing in Raffle prevents a callback from resolving the raffle. The only barrier is that `rawFulfillRandomWords` requires `msg.sender == i_vrfV2PlusWrapper` (`VCB` L103), so the barrier lies entirely with the black-box wrapper and coordinator. Recorded as an unenforced assumption.

```solidity
// L262
uint256 excess = msg.value - paidPrice;
```
- **What:** the surplus to return. Checked arithmetic; L258 already guarantees no underflow.
- **Establishes:** `paidPrice + excess == msg.value`.

```solidity
// L263-L270
if (excess != 0) {
    bool success;
    address refundRecipient = msg.sender;
    assembly ("memory-safe") {
        success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
    }
    if (!success) revert NativeRefundFailed(msg.sender, excess);
}
```
- **What:** returns the surplus to the immediate caller with a raw CALL.
  - Gas is `gas()`, i.e. everything except the EIP-150 retained 1/64.
  - Value is `excess`; there is no calldata.
  - Returndata is not copied (out offset and size are 0), and the code never uses `returndatacopy`, so the recipient's return size does not affect memory.
  - On failure the whole transaction reverts (L269), including the wrapper request and the state transition.
- **Why here:** after every storage write (L252-L260) and before only the event (L272) and the guard reset. The function follows checks-effects-interactions with respect to its own state.
- **Recipient:** always `msg.sender` (L265). There is no parameter, so the refund always goes back to whoever made the call. It is **not** screened by `_isProtocolDestination`, unlike quote-token payouts (`_transferQuote` L565). The call is skipped entirely when `excess == 0` (L263), so a caller who pays exactly `paidPrice` never receives a call.
- **Re-entry surface during L267 (untrusted callee, guard held):**
  - Every guarded Raffle function on this clone reverts (`RG` L89-L91).
  - `rawFulfillRandomWords` reverts unless the caller is the wrapper (`VCB` L103-L105).
  - `onERC721Received` reverts because `status != AwaitingPrize` (L421-L426).
  - `receive` reverts (L172).
  - `initialize` reverts (L177).
  - ERC-721 `transferFrom` / `safeTransferFrom` / `approve` / `setApprovalForAll` (`E721` L93-L136) remain callable for tickets the recipient owns or is approved for. They write only the ticket ledger, through `_update` (L497-L502). `_update` makes STATICCALLs to the factory (L598-L603), and `safeTransferFrom` calls the ticket recipient's `onERC721Received`.
  - Other clones are unaffected by this clone's guard and storage.
- **State visible to the recipient:** `status == Drawing`, `drawRequestedAt == now`, `vrfRequestId == requestId`, `_requestInFlight == false`.
- **Outcomes not excluded:**
  - The recipient reverts. That reverts this call only.
  - The recipient burns all forwarded gas. L269, L272 and the guard reset (`RG` L105) must then fit in the retained 1/64. Nothing in the function checks this. A shortfall reverts only the caller's own transaction.
  - A wrapper-delivered callback arrives in this window. It would be accepted (see L259-L260).
- **Establishes:** `msg.sender` has received `excess`. The clone's native balance is back to its value before the call.

```solidity
// L272
emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
```
- **What:** records the accepted request.
- **Callee `callbackDeadline` (L463-L465):** two paths. It returns 0 when `drawRequestedAt == 0`, otherwise `drawRequestedAt + 2 days`. The non-zero path is taken here because L253 wrote a value `>= endTime >= 1`.
- **Why here:** last, after both external calls.
  - `drawRequestedAt` is re-read from storage, both directly and through `callbackDeadline()`. Its only writer, L253, is inside this guarded function, so it cannot change during L267.
  - `status` is **not** re-read after L267. The event is emitted whatever status holds at that point.
  - Log ordering: any event emitted during `VCB` L84 (for example `VrfCallbackIgnored` from a synchronous callback, L514) or during L267 (ticket `Transfer`/`Approval` events, or events from other contracts) appears **before** `DrawRequested` in the transaction's logs.
- **Establishes:** an off-chain record of `fee = paidPrice` and `excessReturned = excess`, matching `IR` L85-L86.

---

**Cross-Function Dependencies:**

- **Callee `nonReentrant` (external-source-available, `RG` L69-L73, L94-L106):** read in full. Two paths in `_nonReentrantBefore`: revert when the slot is 2, otherwise write 2. `_nonReentrantAfter` writes 1 unconditionally. `requestDraw` depends on it to block every other guarded function on this clone while the wrapper call and the refund call run. It does not block `rawFulfillRandomWords`, `onERC721Received`, `initialize` or the ERC-721 transfer and approval functions.
- **Callee `_requireStatus` (internal, L573-L575):** one branch. Establishes `status == Active` or reverts.
- **Callee `drawRequestDeadline` (internal, L458-L460):** one path, no revert. Shared with `enableRefunds` (L286), which gives the complementary window.
- **Callee `getVrfRequestPrice` (internal, L436-L438):** one path. Wraps a black-box STATICCALL. Establishes nothing on its own beyond the `quotedFee` lower bound used at L250.
- **Callee `VRFV2PlusClient._argsToBytes` (external-source-available, `VC` L22-L26):** pure, one path. Produces a native-payment tag plus `true`.
- **Callee `requestRandomnessPayInNative` (external-source-available, `VCB` L76-L89):** one non-reverting path, which writes both outputs. `paidPrice` equals the wei sent by construction (`VCB` L82, L84, L87). `requestId` passes through unvalidated.
- **Callee `IVRFV2PlusWrapper.calculateRequestPriceNative` (external-black-box, L437 and `VCB` L82):** two STATICCALLs. The second decides how much of `msg.value` leaves the clone, bounded afterwards by L258.
- **Callee `IVRFV2PlusWrapper.requestRandomWordsInNative` (external-black-box, `VCB` L84):** a value-carrying CALL. `requestDraw` depends on it to:
  - accept exactly `requestPrice` without sending value back;
  - return a request ID that the wrapper will later pass to this clone's `rawFulfillRandomWords`;
  - not deliver that callback within this transaction after L260.

  The repository establishes none of these.
- **Callee: raw CALL to `msg.sender` (external-black-box, L267):** untrusted. `requestDraw` depends on it only to return successfully when `excess != 0`. Failure reverts the entire request.
- **Callee `callbackDeadline` (internal, L463-L465):** two paths. The non-zero path is guaranteed at L272 by L242, L253 and `RF` L100.
- **Re-entrant path, not a direct call: `rawFulfillRandomWords` → `fulfillRandomWords` (`VCB` L101-L107 → L509-L524).** During `VCB` L84 it is neutralised by `_requestInFlight` (L511). During L267 it is not neutralised by anything in Raffle.
- **Callers:** external only, any EOA or contract. There is no in-repo caller: grep for `requestDraw` outside `node_modules` finds only `IR` L320 and the definition at L240, with no scripts, tests or frontend code. Callers rely on `IR` L316-L318: callable only in `[endTime, drawRequestDeadline())` after at least one sale, with the surplus above the wrapper's actual fee returned atomically. L242-L247, L243 and L258-L270 implement this.
- **Shared state:**
  - `status`: written here (L252) and at L165, L205, L299, L428, L521. Read by `fulfillRandomWords` (L511), `enableRefunds` (L279, L289) and others.
  - `drawRequestedAt`: written only here (L253). Read through `callbackDeadline` (L464) by `enableRefunds` (L290), `fulfillRandomWords` (L512) and L272.
  - `vrfRequestId`: written only here (L259). Read by `fulfillRandomWords` (L511, L514).
  - `_requestInFlight`: written only here (L254, L260). Read only by `fulfillRandomWords` (L511).
  - `totalEntries`: read here (L243). Written only by `buyEntries` (L230). Also read by `fulfillRandomWords` (L518, L521), `enableRefunds` (L280) and `grossSales` (L474).
  - `endTime`: read here (L242, L459). Written only by `initialize` (L204). Also read by `buyEntries` (L216) and `enableRefunds` (L281).
  - ReentrancyGuard slot: shared with all nine guarded Raffle functions.
  - Clone native balance: transiently `+msg.value`, then `-paidPrice` (`VCB` L84) and `-excess` (L267).
- **Invariant couplings:**
  - **Time partition with `enableRefunds`.** For sold `Active` raffles, `requestDraw` requires `t < endTime + 2d` (L245) and `enableRefunds` requires `t >= endTime + 2d` (L286-L287). For `Drawing`, `fulfillRandomWords` requires `t < drawRequestedAt + 2d` (L512) and `enableRefunds` requires `t >= drawRequestedAt + 2d` (L290-L291). `requestDraw` sets the anchor for the second pair.
  - **Sales vs draw.** `buyEntries` requires `t < endTime` (L216) and `status == Active` (L215). `requestDraw` requires `t >= endTime` (L242) and leaves `Active` (L252). The sold-entry count used for winner selection (L518) and outcome classification (L521) is therefore the count present at L243.
  - **`unsettledPot == totalEntries * ENTRY_PRICE` while `Active` or `Drawing` (system context).** Preserved, because `requestDraw` writes neither variable.
  - **"Clone native balance only transient inside `requestDraw`" (system context).** Holds on every successful path: everything that arrives leaves (L258, L262, L267, `VCB` L84). Any pre-existing forced balance stays untouched.
  - **Single VRF request per raffle.** Holds because L241 combined with L252 makes success one-shot, and `vrfRequestId` and `drawRequestedAt` each have a single writer.
  - **Synchronous-callback protection.** Holds for the wrapper call (L254, L260, L511). It does not extend to the refund call at L267, which runs after `_requestInFlight` is cleared and `vrfRequestId` is set.

---

**Open Questions:**

- unclear; need to inspect the deployed `VRFV2PlusWrapper` and `VRFCoordinatorV2_5` source and configuration for the target chains (`hardhat.config.ts` L38-L57 lists sepolia and mainnet). Their source is not vendored: only `IW`, `VC` and `VCB` exist under `@chainlink/contracts/src/v0.8/vrf`. The goal is to confirm that `rawFulfillRandomWords` for a given `requestId` cannot reach the consumer within the request transaction after L260, in particular during the L267 call to `msg.sender`. `_requestInFlight` does not cover that window, and L510-L513 would accept such a callback.
- unclear; need to inspect the wrapper source to confirm that `requestRandomWordsInNative` returns a non-zero `requestId` that is unique and bound to `msg.sender` (the clone). Raffle stores it unvalidated at L259, and `IR` L100 and L484 use 0 to mean "no request persisted".
- unclear; need to inspect whether `calculateRequestPriceNative` returns the same value at L437 and at `VCB` L82 within one transaction. A divergence changes only which `InsufficientVrfFee` check fires and the size of `excess`, because L258 is the binding bound.
- unclear; need to inspect whether the wrapper keeps exactly `msg.value == requestPrice` or tries to send any value back. The clone's `receive()` reverts (L171-L173) and there is no `fallback`, so such a send would fail inside `VCB` L84.
- unclear; need to inspect the wrapper and coordinator configuration bounds: maximum callback gas including wrapper overhead, minimum and maximum confirmations, maximum `numWords`, and the disabled or unconfigured flags. If they reject the fixed parameters (300,000 gas from `RC` L39, 30 confirmations from `RC` L42, 1 word, native extra args), `requestDraw` reverts for the entire `[endTime, endTime + 2d)` window, and a sold raffle can only move to `Refunding` (L285-L288).
- unclear; need to inspect whether the oracle network fulfils requests priced at an arbitrary caller-chosen `tx.gasprice` (`IW` L27-L28) within `DRAW_CALLBACK_TIMEOUT` (`RC` L36). Raffle sets no fee floor beyond the wrapper's own quote (L250, L258), and the requester alone chooses the gas price.
