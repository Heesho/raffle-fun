## REQ-34 — Half-open request and callback windows

> "Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days."
> — DESIGN.md:L2, sentence 10

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Let `endTime` be the exclusive sale end, `t_request` the timestamp recorded when the draw request is initiated, and `t_callback` the callback transaction's block timestamp. The request-time gate must admit no request before `endTime` or at/after `endTime + 2 days`. The supplied checkable callback property requires every callback that records a result to satisfy `t_callback < t_request + 2 days`; equality must take the rejection/ignore path.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L36
/// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;

/// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;
```

- The two relevant durations are each the Solidity literal `2 days` (`target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L36`).

```solidity
// target/packages/contracts/src/Raffle.sol:L240-L260
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
```

- The lower request boundary is inclusive because only `block.timestamp < endTime` reverts; the upper boundary is exclusive because `block.timestamp >= requestDeadline` reverts (`target/packages/contracts/src/Raffle.sol:L240-L247`). A returning request records its timestamp before calling the wrapper and persists the returned request ID before clearing the in-flight flag (`target/packages/contracts/src/Raffle.sol:L249-L260`).

```solidity
// target/packages/contracts/src/Raffle.sol:L458-L465
function drawRequestDeadline() public view override returns (uint256 deadline) {
    deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
}

function callbackDeadline() public view override returns (uint256 deadline) {
    if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
}
```

- The helpers derive the two exclusive deadlines from the stored sale end and stored request timestamp, respectively (`target/packages/contracts/src/Raffle.sol:L458-L465`).

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107
function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
  address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
  if (msg.sender != vrfWrapperAddr) {
    revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
  }
  fulfillRandomWords(_requestId, _randomWords);
}
```

- The only external callback gateway in the declared dependency closure rejects non-wrapper callers and then dispatches to the overridden internal handler (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). The base constructor stores that wrapper as an immutable (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40-L47`), after `Raffle` passes its validated constructor argument into the base (`target/packages/contracts/src/Raffle.sol:L155-L166`, `L607-L613`).

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L523
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }

    uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
    winningEntry = resolvedEntry;
    resolvedAt = uint64(block.timestamp);
    status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

    emit RaffleResolved(requestId, resolvedEntry, status);
}
```

- A callback at or after `callbackDeadline()` takes the ignored-return branch. Reaching any result write therefore implies the negation of that guard term: `block.timestamp < callbackDeadline()` (`target/packages/contracts/src/Raffle.sol:L509-L523`). Equality is included in the ignored branch by `>=` (`target/packages/contracts/src/Raffle.sol:L510-L516`).

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `Raffle.initialize`: the factory rejects an `endTime` that is not after the creation timestamp and rejects a sale duration over 30 days, then passes the same `uint64 endTime` into the clone (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25`). `initialize` is one-time and factory-only and has the sole `endTime` assignment (`target/packages/contracts/src/Raffle.sol:L176-L205`).
- `requestDraw`, before sale end: `block.timestamp < endTime` reverts, so no request timestamp is recorded (`target/packages/contracts/src/Raffle.sol:L240-L243`).
- `requestDraw`, exactly at sale end: the strict lower comparison is false, so the temporal lower-bound gate permits the call (`target/packages/contracts/src/Raffle.sol:L240-L247`). The independent `Active`, nonzero-entry, and fee conditions remain conjunctive gates (`target/packages/contracts/src/Raffle.sol:L240-L250`).
- `requestDraw`, before versus at the upper request deadline: `drawRequestDeadline()` is `uint256(endTime) + 2 days`; a timestamp one second before can pass the temporal upper gate, while equality or later reverts because the comparison is `>=` (`target/packages/contracts/src/Raffle.sol:L244-L247`, `L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- `requestDraw` → native wrapper request → synchronous callback: the raffle changes to `Drawing`, records `drawRequestedAt`, and sets `_requestInFlight = true` before the wrapper call (`target/packages/contracts/src/Raffle.sol:L252-L257`). If the immutable wrapper calls the external gateway before that request call returns, the gateway reaches the override but `_requestInFlight` makes it emit `VrfCallbackIgnored` and return (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L516`).
- `rawFulfillRandomWords`, non-wrapper caller: the base contract reverts before the application handler (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L105`). `rawFulfillRandomWords`, configured wrapper caller: it has one dispatch, to the overridden `fulfillRandomWords` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`).
- `fulfillRandomWords`, any rejected branch: an in-flight request, non-`Drawing` status, mismatched request ID, word count other than one, or timestamp at/after the callback deadline all share the same ignored-return branch and perform none of the resolution writes at L518-L523 (`target/packages/contracts/src/Raffle.sol:L509-L523`).
- `fulfillRandomWords`, accepted branch: reaching `winningEntry`, `resolvedAt`, the terminal status assignment, and `RaffleResolved` requires every disjunct at L510-L513 to be false, including `block.timestamp >= callbackDeadline()`; the accepted timestamp is therefore strictly less than the computed deadline (`target/packages/contracts/src/Raffle.sol:L509-L523`).
- Exact callback deadline → callback/refund ordering: at equality the callback is ignored by `>=` (`target/packages/contracts/src/Raffle.sol:L509-L516`). In `Drawing`, `enableRefunds` rejects only while `block.timestamp < callbackDeadline()`, so equality can move status to `Refunding`; any callback after that also fails the handler's `status == Drawing` gate (`target/packages/contracts/src/Raffle.sol:L276-L300`, `L509-L516`).
- Duplicate or post-resolution callback: the first accepted callback writes `NftWon` or `CashWon`; a later callback sees a status other than `Drawing` and takes the ignored branch (`target/packages/contracts/src/Raffle.sol:L509-L523`). No other production assignment writes `winningEntry` or `resolvedAt` (`target/packages/contracts/src/Raffle.sol:L518-L520`).
- Constructors, clones, and wrapper identity: the factory checks that the wrapper has code, fixes its address, deploys one `Raffle` implementation with it, and clones that implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`, `L97-L106`). `Clones.clone` embeds the fixed implementation address in the proxy bytecode (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62`), while the inherited callback gateway checks the immutable wrapper recorded by the implementation constructor (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40-L47`, `L101-L107`). There is no derived override between that gateway and `Raffle.fulfillRandomWords` in the five production files (`target/packages/contracts/src/Raffle.sol:L28`, `L509-L523`).
- Type-bound edge: `drawRequestedAt` is `uint64` and is populated with `uint64(block.timestamp)` (`target/packages/contracts/src/Raffle.sol:L111-L112`, `L253`). `callbackDeadline` widens the stored value to `uint256` before adding two days, so the addition itself cannot overflow at the `uint64` horizon (`target/packages/contracts/src/Raffle.sol:L463-L465`). If a request were made after the `uint64` timestamp horizon in the small upper-window interval made possible by the `uint256` request-deadline calculation, truncation could make the stored callback deadline earlier and suppress otherwise timely callbacks; it cannot bypass the handler's `block.timestamp < callbackDeadline()` necessary condition or admit a callback at/after the actual request time plus two days (`target/packages/contracts/src/Raffle.sol:L244-L253`, `L458-L465`, `L509-L516`). The supplied checkable property is the one-way late-acceptance exclusion, not callback liveness at that horizon.

---

**Searched:**

- Full declared scope → read all five first-party production files and all 31 paths in `target/dependency-hashes.json`; `sha256sum -c` returned `OK` for 31/31 dependencies.
- `callbackDeadline|drawRequestedAt|DRAW_CALLBACK_TIMEOUT|block.timestamp` across the five production files and 31 dependencies → 25 hits. Enforcement is at `Raffle.sol:L240-L253`, `L458-L465`, and `L509-L520`, with the duration at `RaffleConstants.sol:L35-L36`; remaining hits are declarations, interface prose, the factory creation timestamp, or other lifecycle gates.
- `requestDraw|drawRequestDeadline|DRAW_REQUEST_TIMEOUT|RaffleNotEnded|DrawRequestWindowExpired` across the same scope → 14 hits. There is one implementation entrypoint (`Raffle.sol:L240`), one interface declaration (`IRaffle.sol:L320`), one deadline implementation (`Raffle.sol:L458-L460`), and no wrapper or base-contract request route.
- `rawFulfillRandomWords|fulfillRandomWords|VrfCallbackIgnored|RaffleResolved` across the same scope → 10 hits. The executable chain is the base external gateway at `VRFV2PlusWrapperConsumerBase.sol:L101-L107` and the Raffle override at `Raffle.sol:L509-L523`; the other hits are the abstract declaration, comments, and event declarations.
- `fulfillRandomWords\s*\(` → 3 hits: the abstract base declaration (`VRFV2PlusWrapperConsumerBase.sol:L99`), its sole dispatch (`L106`), and the Raffle override (`Raffle.sol:L509`). `rawFulfillRandomWords\s*\(` → 1 hit, the base gateway (`VRFV2PlusWrapperConsumerBase.sol:L101`).
- `(drawRequestedAt|vrfRequestId|_requestInFlight)\s*=|\b(drawRequestedAt|vrfRequestId|_requestInFlight)\b` → 16 hits. The only state writes are `Raffle.sol:L253-L260`; the rest are declarations, reads, an event argument, or interface descriptions/getters.
- Exact status-assignment search `status\s*=(?!=)` → 6 hits, all in `Raffle.sol:L165`, `L205`, `L252`, `L299`, `L428`, and `L521`. Only L521 records a successful callback result, and it is below the deadline guard.
- `(winningEntry|resolvedAt)\s*=` → 2 hits, both on the accepted callback path at `Raffle.sol:L519-L520`.
- Alternate timing vocabulary `expiry|expires|expiration|cutoff|grace` → 0 hits. Broader `deadline|timeout|late|window|fulfill|callback` hits reduced to the same request helper, callback helper/handler, interface declarations, and Chainlink base/interface paths described above; no alternate acceptance path was found.

---

**How the verdict was reached:** The request gate implements the quoted half-open interval with `< endTime` on the lower side and `>= endTime + 2 days` on the upper side (`target/packages/contracts/src/Raffle.sol:L240-L247`, `L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`). For callbacks, the only external gateway dispatches to the only override, and every state-recording callback path crosses the conjunctive guard whose final term ignores `block.timestamp >= drawRequestedAt + 2 days` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L463-L465`, `L509-L523`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). The exact deadline is rejected, not accepted. This is `implemented`, not `partial`, because no caller, modifier, base-contract branch, clone path, or alternate resolution writer bypasses the comparison. It is not `contradicted` because neither temporal boundary uses the inclusive operator in the wrong direction. The additional in-flight, status, request-ID, word-count, and wrapper-authentication predicates are independent callback-validity gates and do not create a late-acceptance path (`target/packages/contracts/src/Raffle.sol:L509-L516`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).

---

**Open questions:**

- None for the supplied checkable property. The declared wrapper dependency contains an interface and consumer base rather than the deployed wrapper implementation (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L4-L83`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L118`), but wrapper scheduling or liveness cannot bypass the local deadline predicate applied to every authenticated callback.
