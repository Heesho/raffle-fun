## `requestDraw` in target/packages/contracts/src/Raffle.sol (L240-L273)

**Purpose:** Moves a sold raffle from `Active` into its one-request `Drawing` phase, pays the configured
Chainlink wrapper in native currency for one random word, persists the wrapper-returned request identifier and
request timestamp, and returns any value above the wrapper's second price calculation to the permissionless
requester (`target/packages/contracts/src/Raffle.sol:L240-L272`). The resulting request state is the complete
admission context later used by `fulfillRandomWords`, while its timestamp starts the callback/refund deadline
(`target/packages/contracts/src/Raffle.sol:L509-L523`, `L463-L465`; `target/packages/contracts/src/interfaces/IRaffle.sol:L316-L324`).

---

**Inputs & Assumptions:**

- There are no explicit parameters. `msg.sender` is an **untrusted** permissionless requester and
  `msg.value` is the requester-selected native funding amount; the interface expressly makes the call
  available to anyone in the request window (`target/packages/contracts/src/Raffle.sol:L240`,
  `target/packages/contracts/src/interfaces/IRaffle.sol:L316-L320`).
- Implicit state inputs are `status`, `endTime`, `totalEntries`, the immutable wrapper, and the fixed
  `callbackGasLimit`/`requestConfirmations` values (`target/packages/contracts/src/Raffle.sol:L46-L50`,
  `L81-L85`, `L123-L124`, `L240-L257`). `endTime` is supplied during one-time initialization after the
  factory has required a future end no more than 30 days away (`target/packages/contracts/src/Raffle.sol:L176-L205`;
  `target/packages/contracts/src/RaffleFactory.sol:L97-L104`).
- Implicit environment inputs are `block.timestamp`, the transaction's native value, and the behavior of the
  configured wrapper and refund recipient (`target/packages/contracts/src/Raffle.sol:L242-L272`).
- Precondition: lifecycle state is exactly `Active`. `_requireStatus` enforces this at L241 by comparing stored
  `status` and reverting otherwise (`target/packages/contracts/src/Raffle.sol:L241`, `L571-L575`). The normal
  clone lifecycle reaches `Active` only when the configured prize callback authenticates the token, token ID,
  sponsor, and factory operator (`target/packages/contracts/src/Raffle.sol:L416-L430`).
- Precondition: the call occurs in the half-open interval `[endTime, endTime + 2 days)`. The lower bound is
  checked at L242; `drawRequestDeadline` derives the upper bound from `endTime` and
  `DRAW_REQUEST_TIMEOUT`, and L245-L247 rejects the deadline itself and later timestamps
  (`target/packages/contracts/src/Raffle.sol:L242-L247`, `L458-L460`;
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- Precondition: at least one entry has been sold. L243 enforces `totalEntries != 0`; after L252 changes status
  to `Drawing`, `buyEntries` can no longer pass its `Active` gate, so the positive entry count used by the
  later modulo selection cannot fall back to zero (`target/packages/contracts/src/Raffle.sol:L215-L216`,
  `L230`, `L243`, `L252`, `L518`).
- Precondition: `msg.value` covers the first wrapper quote. `getVrfRequestPrice` obtains that quote from the
  wrapper and L250 checks it (`target/packages/contracts/src/Raffle.sol:L249-L250`, `L435-L438`). The helper
  performs a second wrapper quote immediately before the paid request; the successful path additionally
  checks that second value, returned as `paidPrice`, against `msg.value` at L258
  (`target/packages/contracts/src/Raffle.sol:L256-L258`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`).
- Assumption: the configured address is the intended canonical wrapper and implements the declared pricing,
  request, identifier, and callback semantics. The target describes that dependency as trusted, while the
  factory's on-chain validation establishes only that the supplied address contains code; the implementation
  of the wrapper is not present in the target (`target/DESIGN.md:L2`;
  `target/packages/contracts/src/RaffleFactory.sol:L58-L67`, `L85-L91`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L23-L33`,
  `L67-L81`).
- Assumption: `block.timestamp` is representable in `uint64`, because L253 narrows it before the callback
  deadline is derived. Nothing in `requestDraw` checks that representability
  (`target/packages/contracts/src/Raffle.sol:L253`, `L463-L465`).
- Completion precondition when `excess != 0`: the requester accepts an empty-calldata native transfer. This is
  established dynamically by the call result; a false result is rejected at L269
  (`target/packages/contracts/src/Raffle.sol:L262-L270`).

---

**Outputs & Effects:**

- Returns the `requestId` returned by the configured wrapper's `requestRandomWordsInNative` call; the named
  return variable is assigned at L257 and is not otherwise transformed (`target/packages/contracts/src/Raffle.sol:L240`,
  `L257-L259`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L82-L88`).
- Persistent writes on success: `status = Drawing`, `drawRequestedAt = uint64(block.timestamp)`, and
  `vrfRequestId = requestId` (`target/packages/contracts/src/Raffle.sol:L252-L259`). `_requestInFlight` is set
  before encoding/request dispatch and cleared after the request ID is persisted, so its postcondition is
  `false` on a normal return (`target/packages/contracts/src/Raffle.sol:L254-L260`).
- Guard writes: the inherited modifier writes its fixed slot to `ENTERED` before the body and restores
  `NOT_ENTERED` after the body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`,
  `L94-L105`).
- External interactions: two native-price queries reach the wrapper (one through `getVrfRequestPrice`, one in
  `requestRandomnessPayInNative`), the second quoted amount is attached to
  `requestRandomWordsInNative`, and any excess is sent to `msg.sender` with empty calldata and all remaining
  gas (`target/packages/contracts/src/Raffle.sol:L249-L267`, `L435-L438`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L82-L88`).
- Emits `DrawRequested` only after the paid request, request-state persistence, and any excess return have
  succeeded. The event records the request ID, requester, second calculated price, returned excess, stored
  timestamp, and derived callback deadline (`target/packages/contracts/src/Raffle.sol:L272`;
  `target/packages/contracts/src/interfaces/IRaffle.sol:L82-L96`).
- Every explicit failure path is a revert: nested guarded entry, wrong lifecycle, early/late time, no entries,
  insufficient first or second fee, failed wrapper call, or failed excess return
  (`target/packages/contracts/src/Raffle.sol:L241-L250`, `L257-L269`;
  `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L100`).

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

- **What:** Opens a permissionless payable entrypoint, excludes nested guarded calls, and enforces lifecycle,
  lower-time, sold-entry, and exclusive upper-time gates (`target/packages/contracts/src/Raffle.sol:L240-L247`).
- **Why here:** All local admission checks precede pricing, persistent draw-state writes, and external value
  movement (`target/packages/contracts/src/Raffle.sol:L241-L257`).
- **Assumes:** `endTime` is the factory-validated initialized sale end and `block.timestamp` is the intended
  clock (`target/packages/contracts/src/Raffle.sol:L204`, `L242-L247`;
  `target/packages/contracts/src/RaffleFactory.sol:L99-L104`).
- **Establishes:** For the remaining path, the raffle is `Active`, at least one entry exists, and the timestamp
  lies in `[endTime, drawRequestDeadline())` (`target/packages/contracts/src/Raffle.sol:L241-L247`).
- **Depended on by:** The state transition at L252 and the later callback's modulo by `totalEntries` at L518
  (`target/packages/contracts/src/Raffle.sol:L252`, `L518`).

```solidity
// L249-L250
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);
```

- **What:** Reads a first native wrapper quote and rejects visibly underfunded calls
  (`target/packages/contracts/src/Raffle.sol:L249-L250`, `L435-L438`).
- **Why here:** It avoids committing draw state before this first external pricing check and value bound
  (`target/packages/contracts/src/Raffle.sol:L249-L254`).
- **Assumes:** The black-box wrapper's returned quote has the meaning declared by its interface; nothing in
  target source establishes the implementation's pricing behavior
  (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L23-L33`).
- **Establishes:** `msg.value >= quotedFee` for the rest of this execution; it does not establish equality with
  the second price read inside the request helper (`target/packages/contracts/src/Raffle.sol:L249-L250`,
  `L256-L258`).
- **Depended on by:** The decision to enter `Drawing` and attempt the paid wrapper request
  (`target/packages/contracts/src/Raffle.sol:L252-L257`).

```solidity
// L252-L255
status = Status.Drawing;
drawRequestedAt = uint64(block.timestamp);
_requestInFlight = true;
bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
```

- **What:** Closes the `Active` path, records the callback-clock origin, suppresses resolution during request
  dispatch, and encodes native-payment extra arguments (`target/packages/contracts/src/Raffle.sol:L252-L255`).
- **Why here:** These writes land before the state-changing wrapper call; a wrapper-authenticated synchronous
  callback reaches `fulfillRandomWords` but takes its `_requestInFlight` ignored path
  (`target/packages/contracts/src/Raffle.sol:L254`, `L509-L516`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).
- **Assumes:** Narrowing `block.timestamp` to `uint64` preserves the timestamp. Nothing in this function checks
  that assumption (`target/packages/contracts/src/Raffle.sol:L253`).
- **Establishes:** Sales and other `Active`-gated draw requests are closed, the callback/refund clock has a
  stored origin, and an authenticated synchronous callback during the paid request is ignored
  (`target/packages/contracts/src/Raffle.sol:L215`, `L241`, `L252-L255`, `L509-L515`).
- **Depended on by:** `enableRefunds` uses `Drawing` plus `callbackDeadline`, and `fulfillRandomWords` uses all
  three draw-coordination values (`target/packages/contracts/src/Raffle.sol:L289-L291`, `L509-L521`).

```solidity
// L256-L260
uint256 paidPrice;
(requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
vrfRequestId = requestId;
_requestInFlight = false;
```

- **What:** Obtains a second native quote, sends exactly that amount with a one-word request, receives the
  wrapper-returned ID, rejects an actual helper price above caller funding, persists the ID, and re-enables
  callback processing (`target/packages/contracts/src/Raffle.sol:L256-L260`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`).
- **Why here:** The ID is not made admissible to `fulfillRandomWords` until the wrapper request has returned;
  `_requestInFlight` is cleared only after `vrfRequestId` has been stored
  (`target/packages/contracts/src/Raffle.sol:L257-L260`, `L509-L516`).
- **Assumes:** A successful black-box request call means a request was accepted and its return value is the
  identifier that a later authenticated callback will carry. No wrapper implementation is present to
  establish nonzero, uniqueness, or delivery behavior; the local code stores the value without an additional
  identifier check (`target/packages/contracts/src/Raffle.sol:L257-L260`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L67-L81`).
- **Establishes:** On the continuing path, `paidPrice <= msg.value`, `vrfRequestId == requestId`, and
  `_requestInFlight == false` (`target/packages/contracts/src/Raffle.sol:L258-L260`).
- **Depended on by:** The subtraction at L262 and callback request-ID/in-flight gates at L511
  (`target/packages/contracts/src/Raffle.sol:L262`, `L509-L515`).

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

- **What:** Computes the exact difference from the second price and, when nonzero, calls the requester with
  that value, no calldata, no return buffer, and all remaining gas; a failed call rejects the execution
  (`target/packages/contracts/src/Raffle.sol:L262-L270`).
- **Why here:** The refund occurs after the request ID is persisted and `_requestInFlight` is cleared, but while
  the outer `nonReentrant` guard remains entered (`target/packages/contracts/src/Raffle.sol:L259-L267`;
  `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L94-L105`).
- **Assumes:** The untrusted requester executes arbitrary fallback/receive logic. Success is the only property
  checked; the call returns no data to interpret (`target/packages/contracts/src/Raffle.sol:L263-L269`).
- **Establishes:** Either no excess existed or the recipient call reported success; otherwise the function
  reverts at L269 (`target/packages/contracts/src/Raffle.sol:L262-L269`).
- **Depended on by:** Final event emission and normal return occur only after this block completes
  (`target/packages/contracts/src/Raffle.sol:L269-L273`).

```solidity
// L272
emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
```

- **What:** Publishes the accepted request context and deadline (`target/packages/contracts/src/Raffle.sol:L272`;
  `target/packages/contracts/src/interfaces/IRaffle.sol:L82-L96`).
- **Why here:** Observers receive the event only after request dispatch, ID persistence, in-flight clearing,
  and successful excess handling (`target/packages/contracts/src/Raffle.sol:L257-L272`).
- **Assumes:** `drawRequestedAt` remained a nonzero, faithful timestamp so `callbackDeadline` returns it plus
  two days; `callbackDeadline` otherwise returns zero (`target/packages/contracts/src/Raffle.sol:L253`,
  `L463-L465`).
- **Establishes:** The successful transaction contains one `DrawRequested` log carrying the second calculated
  fee and returned excess (`target/packages/contracts/src/Raffle.sol:L272`).
- **Depended on by:** Off-chain request discovery described by the event declaration
  (`target/packages/contracts/src/interfaces/IRaffle.sol:L82-L96`).

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` path (internal, source available):** `_nonReentrantBeforeView` rejects
  only an `ENTERED` guard word; `_nonReentrantBefore` then writes `ENTERED`, and `_nonReentrantAfter` restores
  `NOT_ENTERED`. The slot helper maps the fixed `bytes32` to a `uint256` storage reference
  (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L35-L72`,
  `L88-L117`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L90-L97`).
  `requestDraw` depends on this path to exclude nested calls to every other `nonReentrant` entrypoint during
  both wrapper calls and the requester refund (`target/packages/contracts/src/Raffle.sol:L209-L212`, `L240`,
  `L276`, `L304`, `L309`, `L349`, `L375`, `L385`, `L395`).
- **Callee `_requireStatus` (internal, source available):** has one success path when stored status equals the
  expected value and one revert path otherwise; `requestDraw` relies on it to admit only `Active`
  (`target/packages/contracts/src/Raffle.sol:L241`, `L571-L575`).
- **Callee `drawRequestDeadline` (internal, source available):** always returns `uint256(endTime) + 2 days`;
  `requestDraw` relies on that value as its exclusive initiation deadline
  (`target/packages/contracts/src/Raffle.sol:L244-L247`, `L458-L460`;
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- **Callee `getVrfRequestPrice` (internal dispatch to external black box):** directly returns
  `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)`. The wrapper method is declared `view`,
  but only its interface is present, so revert and returned-value behavior are not established by target
  implementation source (`target/packages/contracts/src/Raffle.sol:L249-L250`, `L435-L438`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L23-L33`).
- **Callee `VRFV2PlusClient._argsToBytes` (internal, source available):** ABI-encodes the fixed V1 selector and
  `ExtraArgsV1{nativePayment: true}`; there are no branches
  (`target/packages/contracts/src/Raffle.sol:L255`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol:L5-L11`,
  `L22-L26`).
- **Callee `requestRandomnessPayInNative` (internal plus external black box):** reads
  `calculateRequestPriceNative` a second time, invokes `requestRandomWordsInNative` with exactly that value and
  the fixed `(callbackGasLimit, requestConfirmations, 1, extraArgs)` tuple, then returns the wrapper's ID and
  its own second price (`target/packages/contracts/src/Raffle.sol:L256-L258`;
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`).
  The wrapper implementation is absent, so the external call can revert, return any ABI-decodable ID, and
  execute calls back into the raffle before returning; the caller relies on successful return to mean the
  declared request occurred (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L67-L81`).
- **Potential callback path `rawFulfillRandomWords` -> `fulfillRandomWords` (external-source-available gateway,
  internal handler):** the inherited gateway rejects every caller except the immutable wrapper, then dispatches
  the supplied ID and words (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).
  The Raffle handler ignores and returns for in-flight, wrong-state, wrong-ID, wrong-length, or late callbacks;
  otherwise it selects an entry in `[1,totalEntries]`, records time, and chooses the terminal result
  (`target/packages/contracts/src/Raffle.sol:L509-L523`). A callback made synchronously during the paid request
  necessarily takes the `_requestInFlight` ignored path because L254 precedes L257 and L260 follows it
  (`target/packages/contracts/src/Raffle.sol:L254-L260`, `L511-L515`).
- **Callee `callbackDeadline` (internal, source available):** returns zero while `drawRequestedAt == 0`, otherwise
  returns the stored timestamp plus two days. `requestDraw` calls it after writing `drawRequestedAt` for its
  event; `fulfillRandomWords` and `enableRefunds` use the same value as the exclusive callback/refund boundary
  (`target/packages/contracts/src/Raffle.sol:L272`, `L289-L291`, `L463-L465`, `L511-L512`;
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`).
- **Callee `msg.sender` refund (external black box):** when `excess != 0`, assembly `call` sends `excess` with
  empty calldata and forwards `gas()`. The recipient can revert or execute arbitrary code; only the call's
  success bit is consumed (`target/packages/contracts/src/Raffle.sol:L262-L269`). The shared guard remains
  entered, while the callback-specific `_requestInFlight` flag has already been cleared
  (`target/packages/contracts/src/Raffle.sol:L259-L267`;
  `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`).
- **Callers:** `requestDraw` is an `external payable` entrypoint reachable by any account or contract; the only
  source-visible ABI declaration likewise imposes no caller role, and no first-party contract call site is
  present (`target/packages/contracts/src/Raffle.sol:L240`;
  `target/packages/contracts/src/interfaces/IRaffle.sol:L316-L320`).
- **Shared state — lifecycle:** the implementation constructor starts its own storage in `Refunding`, clone
  initialization writes `AwaitingPrize`, the authenticated prize callback writes `Active`, `requestDraw` writes
  `Drawing`, and either the callback writes `NftWon`/`CashWon` or `enableRefunds` later writes `Refunding`
  (`target/packages/contracts/src/Raffle.sol:L164-L165`, `L176-L205`, `L421-L429`, `L252`, `L276-L300`,
  `L509-L523`).
- **Shared state — entry count:** only `buyEntries` advances `totalEntries`, and it requires `Active` before
  sale end; request admission requires the count to be nonzero, then `Drawing` closes further purchases. The
  callback relies on the frozen positive value for modulo selection and reserve comparison
  (`target/packages/contracts/src/Raffle.sol:L215-L216`, `L226-L233`, `L243`, `L252`, `L518-L521`).
- **Shared state — draw coordination:** only `requestDraw` writes `vrfRequestId`, `drawRequestedAt`, and
  `_requestInFlight`; `callbackDeadline`, `enableRefunds`, and `fulfillRandomWords` consume those values
  (`target/packages/contracts/src/Raffle.sol:L108-L112`, `L141-L142`, `L252-L260`, `L289-L291`, `L463-L465`,
  `L509-L515`).
- **Invariant coupling:** a successful request couples `status == Drawing`, a frozen positive `totalEntries`, a
  persisted request ID, and a timestamp-derived deadline. Resolution requires that exact ID, one word, the
  `Drawing` state, no in-flight request, and a timestamp strictly before the deadline; once the deadline is
  reached, `enableRefunds` can move the same `Drawing` raffle into `Refunding`
  (`target/packages/contracts/src/Raffle.sol:L252-L260`, `L289-L300`, `L509-L523`).

---

**Open Questions:**

- unclear; need to inspect the deployed Chainlink wrapper implementation to establish all successful and
  reverting paths of `calculateRequestPriceNative` and `requestRandomWordsInNative`, including intra-transaction
  quote stability, request-ID guarantees, and callback/re-entry behavior; the target contains only the
  interface (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L23-L33`,
  `L67-L81`).
- unclear; need to inspect deployment configuration or deployment records to establish that `vrfWrapper_` is
  the intended canonical wrapper; target source requires contract code but does not perform an identity check
  (`target/packages/contracts/src/RaffleFactory.sol:L58-L67`, `L85-L91`).
