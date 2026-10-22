## `requestDraw` in target/packages/contracts/src/Raffle.sol (L240-L273)

**Purpose:** Moves a sold, ended raffle from Active into the randomness-request lifecycle, funds one VRF word from the requester, records the request identity and returns unused native value. Subsequent callback acceptance and refund timing depend on the recorded request ID and request time (Raffle.sol L240-L273, L289-L291, L509-L523).

---

**Inputs & Assumptions:**

- No explicit arguments. `msg.sender` and `msg.value` are untrusted: any caller can enter, the caller funds the request and receives any excess (Raffle.sol L240, L250, L265-L269; IRaffle.sol L316-L320). No sponsor or ticket-ownership condition appears in the entry checks (Raffle.sol L241-L250).
- Persistent inputs are `status`, `endTime`, `totalEntries`, the immutable wrapper, and fixed callback parameters (Raffle.sol L47-L50, L82-L85, L124, L241-L257; VRFV2PlusWrapperConsumerBase.sol L35, L40-L47). The function needs Active, at least one entry, and `endTime <= block.timestamp < endTime + 2 days`; these are established locally and by `_requireStatus` and `drawRequestDeadline` (Raffle.sol L241-L247, L458-L460, L573-L575; RaffleConstants.sol L32-L36).
- Active is established by the configured prize receiver callback, and sold entries are recorded by `buyEntries`; requestDraw does not re-inspect prize ownership or quote balances (Raffle.sol L215-L236, L421-L428, L240-L273). The canonical factory checks the prize contract's ownership response and Active state before successful creation (RaffleFactory.sol L127-L134). These remain statements about those checks, not independent validation of an arbitrary prize token's honesty.
- The wrapper is trusted in the supplied orientation. Locally, the implementation pins its address through the consumer constructor; the factory verifies deployed code and `_validatedVrfWrapper` verifies nonzero address, but neither proves canonical service identity (Raffle.sol L155-L162, L610-L612; RaffleFactory.sol L65-L67, L183-L185; consumer base L43-L46). Authentic pricing, correctly associated request IDs, and eventual authenticated asynchronous fulfillment depend on the external service: **nothing found** in the available wrapper interface establishes them (IVRFV2PlusWrapper.sol L23-L33, L67-L79).
- Timestamp-to-`uint64` fidelity assumes the execution timestamp fits that width. The narrowing conversion itself has no explicit width assertion (Raffle.sol L253); **nothing found** establishes the full-width bound in this function. The configured sale end is `uint64`, and creation requires it to be future and within 30 days (IRaffle.sol L53; RaffleFactory.sol L99-L104; RaffleConstants.sol L29-L30).
- A caller receiving positive excess must accept an empty-calldata native transfer, or the entire operation reverts; acceptance is established only by the success bit returned from that particular external call (Raffle.sol L262-L269). Exact payment skips this interaction (L263).

---

**Outputs & Effects:**

- Returns the wrapper-provided `requestId`, records it in `vrfRequestId`, records the narrowed request timestamp, changes status to Drawing before requesting, and brackets the wrapper interaction with `_requestInFlight = true/false` (Raffle.sol L240, L252-L260).
- The adapter obtains a second price and sends exactly that amount to `requestRandomWordsInNative`; `paidPrice` is the adapter's price value, not an independently measured wrapper accounting delta (consumer base L76-L88). On successful execution `paidPrice <= msg.value` and `excess = msg.value - paidPrice` (Raffle.sol L258-L262).
- Any positive excess is transferred to the original caller. A failed refund reverts, and the final `DrawRequested` event is after refund success and contains the request ID, caller, paid price, excess, request time and callback deadline (Raffle.sol L263-L272; IRaffle.sol L82-L95). Under the supplied atomic execution assumption, any revert rolls back request storage, wrapper-side effects, value transfers and logs.
- Neither ticket ranges nor quote liabilities are directly changed by this function (Raffle.sol L240-L273). Successful initiation freezes further entry sales through the Active check in `buyEntries` (L215) and starts the Drawing timeout used by `enableRefunds` (L289-L291).
- Drawing is the state established before the wrapper request, not an unconditional assertion about all conceivable reentrant external behavior at return: `_requestInFlight` is cleared before the refund call, and a wrapper-authenticated matching callback is then governed by its own conditions rather than `nonReentrant` (Raffle.sol L259-L267, L509-L523; consumer base L101-L107). With the orientation's asynchronous service assumption, the normal returned state is Drawing.

---

**Block-by-Block:**

```solidity
// Raffle.sol L240-L247
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }
```

- **What:** Acquires the shared reentrancy guard and admits only sold Active raffles in the half-open request interval (Raffle.sol L240-L247).
- **Why here:** All lifecycle and time rejection occurs before quoting or paying the wrapper (L249-L257).
- **Assumes:** Execution supplies one transaction timestamp, per the supplied orientation. `_requireStatus` must enforce equality and the deadline helper must return the configured timeout; their only paths do so (L458-L460, L573-L575).
- **Establishes:** The draw cannot begin before endTime, with zero entries, or at/after the request deadline (L242-L247). The guard excludes nested entry into functions using the same guard: it rejects only ENTERED, sets ENTERED before the body, then restores NOT_ENTERED after success (ReentrancyGuard.sol L50-L51, L69-L73, L88-L117). Thus a clone's initially zero guard slot is accepted on first use; no constructor-populated slot is required by that predicate (L113).
- **Depended on by:** The callback's modulo uses a nonzero frozen entry count (Raffle.sol L518); timeout refunding switches eligibility exactly at the request boundary (L285-L287).

```solidity
// Raffle.sol L249-L250
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);
```

- **What:** Calls the wrapper's native-price view for 300,000 callback gas and one word, then checks the requester's payment against that quote (Raffle.sol L47, L249-L250, L436-L438; RaffleConstants.sol L38-L39).
- **Why here:** Rejects insufficient initial funding before the lifecycle writes and paid request (L252-L257).
- **Assumes:** Wrapper price-query availability and a decodable `uint256` result; implementation source is absent, so no source establishes honest pricing (IVRFV2PlusWrapper.sol L23-L33). A reverting or malformed response prevents progress at this call.
- **Establishes:** Only `msg.value >= quotedFee`; equality between this quote and the later adapter quote is not established and is not required by the later accounting checks (Raffle.sol L250, L258-L262; consumer base L82).
- **Depended on by:** Initial funding admission; final spend and refund use the later `paidPrice` instead (L258-L269).

```solidity
// Raffle.sol L252-L260
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

- **What:** Establishes Drawing and request time, marks the request in flight, encodes native-payment arguments, requests one word with 30 confirmations, and records the returned request ID (Raffle.sol L252-L260; RaffleConstants.sol L38-L42).
- **Why here:** Lifecycle writes and the in-flight marker precede the external request. The marker remains set until after the returned ID is installed, so a callback during the request cannot resolve against an unset or stale ID (Raffle.sol L254-L260, L511-L515).
- **Assumes:** The wrapper's request method associates the returned ID with this consumer and eventually supplies the promised word; **nothing found** beyond interface documentation establishes that behavior (IVRFV2PlusWrapper.sol L67-L79). Revert, adversarial return ID and synchronous callback attempts are not excluded by the interface. The local handler explicitly ignores a synchronous callback while the marker is true, without making the request fail merely because that callback was ignored (Raffle.sol L511-L515).
- **Establishes:** `_argsToBytes` emits the V1 selector plus the boolean struct; its only path is ABI encoding (VRFV2PlusClient.sol L7-L10, L22-L26). The adapter requotes and forwards exactly its quote, returning that price and the external request ID on its only normal path (consumer base L76-L88). A larger actual price is rejected even if pre-existing native balance allowed the external payment to execute first (Raffle.sol L258; consumer base L82-L88). After acceptance, the recorded ID equals the adapter result and the marker is false (Raffle.sol L259-L260).
- **Depended on by:** Callback identity matching and callback-window calculation use those stored fields (L463-L465, L511-L512). No check here rejects zero or any particular numerical request ID; identity validity is a wrapper assumption (L257-L259).

```solidity
// Raffle.sol L262-L272
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
```

- **What:** Computes the unused portion of this call's payment, conditionally sends it to the caller, and reports accepted request metadata (Raffle.sol L262-L272).
- **Why here:** ID recording and in-flight clearance precede caller-controlled execution. The nonReentrant modifier still encloses the refund and event (Raffle.sol L240-L273; ReentrancyGuard.sol L69-L73).
- **Assumes:** The arbitrary refund receiver may reject, consume gas or attempt reentry. No receiver implementation is supplied. Success is required only for the positive-excess path (Raffle.sol L263-L269). The low-level call provides empty input, no return-data buffer and requested `gas()`; no receiver return value is decoded beyond the call success bit (L266-L269).
- **Establishes:** The subtraction is bounded by the prior `paidPrice <= msg.value` check; positive excess must transfer successfully before the event is emitted (L258, L262-L272). No guarantee that arbitrary unguarded entrypoints are excluded follows from the guard; the authenticated callback has its own checks and no guard modifier (consumer base L101-L107; Raffle.sol L509-L515).
- **Depended on by:** Requesters rely on all-or-revert excess return; indexers receive the post-refund event with the stored request time and deadline (IRaffle.sol L82-L95, L316-L320; Raffle.sol L272).

---

**Cross-Function Dependencies:**

- `nonReentrant` → `_nonReentrantBefore` → `_nonReentrantBeforeView` → `_reentrancyGuardEntered`, and `_nonReentrantAfter` (internal): establishes shared guarded-function exclusion through a fixed storage slot; failure is a revert, normal completion restores NOT_ENTERED (ReentrancyGuard.sol L69-L73, L88-L117). `_reentrancyGuardStorageSlot` returns its fixed constant and `StorageSlot.getUint256Slot` aliases exactly the supplied slot using memory-safe assembly (ReentrancyGuard.sol L35-L37, L116-L118; StorageSlot.sol L93-L97).
- `_requireStatus` (internal): its normal path establishes `status == Active`, otherwise reverts (Raffle.sol L573-L575).
- `drawRequestDeadline` (internal): unconditionally computes widened `endTime + 2 days` (Raffle.sol L458-L460; RaffleConstants.sol L32-L33).
- `getVrfRequestPrice` (internal) → wrapper `calculateRequestPriceNative` (external black box): forwards fixed gas and one-word parameters, with no local price interpretation beyond the returned number and funding comparison (Raffle.sol L436-L438, L249-L250; IVRFV2PlusWrapper.sol L23-L33).
- `VRFV2PlusClient._argsToBytes` (internal): returns selector-tagged native-payment encoding; no external interaction or additional path (client L7-L10, L22-L26).
- `requestRandomnessPayInNative` (internal): obtains its own wrapper quote then calls wrapper `requestRandomWordsInNative` with exactly that value, callback gas, confirmations, word count and encoded arguments; returns its quoted price with the external ID, with no source branch that independently validates that ID (consumer base L76-L88). Both wrapper calls are black boxes because only their interface is available (IVRFV2PlusWrapper.sol L33, L74-L79); the source lookup errors are preserved with this record.
- Low-level native refund call (external black box): can invoke arbitrary recipient code; its successful outcome is required only when excess is nonzero (Raffle.sol L263-L269).
- `callbackDeadline` (internal): returns zero when `drawRequestedAt == 0`; otherwise widened request time plus two days (Raffle.sol L463-L465; RaffleConstants.sol L35-L36). Thus a positive timeout depends on a nonzero stored timestamp, not just the helper's name.
- Callers: public ABI callers supply payment; authorization is permissionless within lifecycle/time bounds (Raffle.sol L240-L250; IRaffle.sol L316-L320).
- Shared state and invariant coupling: `initialize` sets `endTime` and AwaitingPrize; prize receipt activates; purchases update entries and unsettled pot only while Active; requesting moves to Drawing; callback resolution records winner and result; timeouts move to Refunding and convert the pot into refund liability (Raffle.sol L197-L205, L215-L236, L252-L260, L279-L300, L421-L428, L509-L523). The sold-entry denominator survives initiation unchanged (L240-L273), and the callback rejects in-flight, non-Drawing, wrong-ID, wrong-length or late deliveries (L511-L515).

---

**Open Questions:**

- unclear; need to inspect the configured canonical wrapper implementation and chain-specific configuration to establish fee calculation, request-ID guarantees, callback scheduling and service availability; available code provides only the interface and consumer adapter (IVRFV2PlusWrapper.sol L23-L33, L67-L79; consumer base L76-L88).
- unclear; need to inspect an individual contract caller's receive/fallback behavior to determine whether its positive-excess refund succeeds; no arbitrary caller implementation is part of this target (Raffle.sol L263-L269).
