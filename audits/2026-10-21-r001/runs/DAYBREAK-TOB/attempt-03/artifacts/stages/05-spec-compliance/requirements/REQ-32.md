## REQ-32 — Draw-request and callback time windows

> "Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days."
> — `DESIGN.md:L2`, sentence 10

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For an otherwise eligible raffle, the request-time predicate must be `block.timestamp >= endTime && block.timestamp < endTime + 2 days`: a request before the sale end must fail, one at the exact sale end must pass the time gates, and one at the exact request deadline must fail. For an otherwise current, authenticated callback, resolution must be possible only while `block.timestamp < drawRequestedAt + 2 days`; equality belongs to the closed side of the boundary. These are the half-open and strict boundaries stated in "Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days." (`DESIGN.md:L2`, sentence 10).

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L36
uint256 internal constant MAX_SALE_DURATION = 30 days;

/// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;

/// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;
```

- Both durations used by the enforcement are exactly `2 days` (`target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L36`).

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

- The lower comparison is `< endTime`, so equality is not rejected; the upper comparison is `>= requestDeadline`, so equality is rejected. No branch reaches the wrapper request at `L257` without first passing both comparisons (`target/packages/contracts/src/Raffle.sol:L240-L257`).
- `drawRequestedAt` is captured from the same transaction timestamp before the wrapper call, and the request identifier is recorded before the in-flight flag is cleared (`target/packages/contracts/src/Raffle.sol:L252-L260`).

```solidity
// target/packages/contracts/src/Raffle.sol:L458-L465
function drawRequestDeadline() public view override returns (uint256 deadline) {
    deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
}

function callbackDeadline() public view override returns (uint256 deadline) {
    if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
}
```

- `endTime` and `drawRequestedAt` are widened to `uint256` before the two-day additions (`target/packages/contracts/src/Raffle.sol:L458-L465`); the stored source types are `uint64` (`target/packages/contracts/src/Raffle.sol:L81-L82`, `L111-L115`).

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107
function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal virtual;

function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
  address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
  if (msg.sender != vrfWrapperAddr) {
    revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
  }
  fulfillRandomWords(_requestId, _randomWords);
}
```

- The inherited external callback gateway has one dispatch path: it authenticates the immutable wrapper and then invokes the raffle override (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107`).

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

- An otherwise valid callback at or after `callbackDeadline()` takes the ignore branch and cannot execute the resolution writes at `L518-L523`; an otherwise valid callback strictly before it falls through to those writes (`target/packages/contracts/src/Raffle.sol:L509-L523`).

---

**Paths walked:**

- Canonical configuration: `createRaffle` requires the supplied `uint64 endTime` to be after the creation timestamp, caps the sale duration, creates the clone, and passes that same value to `initialize` (`target/packages/contracts/src/RaffleFactory.sol:L97-L120`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L19-L25`). `initialize` is one-shot and factory-only, then stores `params.endTime` without another writer (`target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- Locked implementation: its constructor fixes `initialized = true` and `status = Refunding`, while `requestDraw` first requires `Active`; direct calls to the implementation therefore do not form an alternate request path (`target/packages/contracts/src/Raffle.sol:L151-L166`, `L240-L242`, `L571-L575`). ✓
- Active clone, `t < endTime`: `_requireStatus(Status.Active)` is followed by `block.timestamp < endTime`, which reverts before pricing or the wrapper call (`target/packages/contracts/src/Raffle.sol:L240-L249`). ✓
- Active clone, `t == endTime`: the lower comparison is false, while `drawRequestDeadline()` is `endTime + 2 days`; therefore the two time checks permit the exact sale-end timestamp (`target/packages/contracts/src/Raffle.sol:L242-L247`, `L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`). Independent entry, fee, and lifecycle conditions remain, as the requirement's `checkable` field asks for time eligibility rather than unconditional success (`target/packages/contracts/src/Raffle.sol:L241-L250`). ✓
- Active clone, `endTime < t < endTime + 2 days`: both time comparisons pass and execution can reach the native-funded wrapper request (`target/packages/contracts/src/Raffle.sol:L242-L257`). ✓
- Active clone, `t == endTime + 2 days` or later: `block.timestamp >= requestDeadline` reverts before the wrapper request (`target/packages/contracts/src/Raffle.sol:L244-L257`). ✓
- Request call and modifier: `requestDraw` has only the inherited `nonReentrant` modifier (`target/packages/contracts/src/Raffle.sol:L240`); that modifier runs its pre-check, executes the function body once, and resets afterward, without a branch around the body's timing checks (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). ✓
- Authenticated callback, current request, one word, `t < drawRequestedAt + 2 days`: the inherited gateway reaches the raffle override, every disqualifying term at `L511-L512` is false, and resolution falls through at `L518-L523` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Callback at `t == drawRequestedAt + 2 days` or later: the `>= callbackDeadline()` term is true, so the handler emits `VrfCallbackIgnored` and returns without changing the result (`target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Synchronous, wrong-state, wrong-ID, or wrong-shape callbacks share the same ignore branch; those are callback-validity gates rather than alternate time paths (`target/packages/contracts/src/Raffle.sol:L504-L516`). The external gateway separately rejects a caller other than the configured wrapper (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). ✓
- Refund transition: a sold `Active` raffle cannot enter `Refunding` before `drawRequestDeadline()`, and a `Drawing` raffle cannot enter it before `callbackDeadline()`; equality is allowed in both branches because each guard is `< deadline` (`target/packages/contracts/src/Raffle.sol:L276-L299`). This is complementary to request rejection and callback ignoring at the two exact deadlines. ✓
- Timestamp widths: `endTime` is already `uint64`, and the request deadline widens it before addition (`target/packages/contracts/src/Raffle.sol:L81-L82`, `L458-L460`). `drawRequestedAt` is assigned with an explicit `uint64` conversion (`target/packages/contracts/src/Raffle.sol:L111-L112`, `L253`). For timestamps representable in that declared field, the callback deadline is exactly the request timestamp plus two days (`target/packages/contracts/src/Raffle.sol:L463-L465`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). A hypothetical execution timestamp above `type(uint64).max` would narrow the stored value and make the callback cutoff earlier, not permit a callback at or after the actual request timestamp plus two days; it does not create a late-acceptance path against the quoted strict upper bound (`target/packages/contracts/src/Raffle.sol:L253`, `L463-L465`, `L509-L515`). ✓

---

**Searched:**

- Scope integrity: all five production files under `target/packages/contracts/src` and all 31 paths in `target/dependency-hashes.json` were included; SHA-256 recomputation produced 31 matches and zero mismatches.
- `requestDraw\s*\(|\.requestDraw\s*\(` → 2 hits: the interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L320` and the implementation at `target/packages/contracts/src/Raffle.sol:L240`; no in-scope caller or wrapper bypass.
- `drawRequestDeadline|DRAW_REQUEST_TIMEOUT|RaffleNotEnded|DrawRequestWindowExpired` → 11 hits, all in `Raffle.sol`, `IRaffle.sol`, and `RaffleConstants.sol`; enforcement resolves to `Raffle.sol:L240-L247`, `L458-L460`, and `RaffleConstants.sol:L32-L33`.
- `drawRequestedAt|callbackDeadline|DRAW_CALLBACK_TIMEOUT` → 15 hits, all in `Raffle.sol`, `IRaffle.sol`, and `RaffleConstants.sol`; the relevant writer/calculation/filter is `Raffle.sol:L253`, `L463-L465`, `L509-L515`.
- `rawFulfillRandomWords|fulfillRandomWords` → 6 textual hits: the Chainlink base's abstract hook and sole external gateway at `VRFV2PlusWrapperConsumerBase.sol:L99-L107`, plus the raffle override at `Raffle.sol:L509-L523`; no second callback entrypoint.
- `enableRefunds|RefundsNotAvailable` → 6 hits: interface/error declarations and the single implementation at `Raffle.sol:L276-L299`; the sold-Active and Drawing branches use the same two deadlines.
- `uint64(block.timestamp)|toUint64|type(uint64).max` → 4 hits across the complete scope: two raw timestamp conversions in `Raffle.sol:L253,L520`, and OpenZeppelin's checked `SafeCast.toUint64` definition at `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol:L441-L445`; `SafeCast`/`toUint64` has 0 hits in the five production files.
- `expiry|expires|48 hours|172800` → 0 hits. The implementation expresses the durations with Solidity's `2 days` unit instead (`target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L36`).
- State-writer follow-up for `endTime`, `drawRequestedAt`, `vrfRequestId`, `_requestInFlight`, and `status` → `endTime` is written during initialization (`Raffle.sol:L204`); the request coordination fields are written only in `requestDraw` (`Raffle.sol:L252-L260`); terminal status is written only after the callback filter (`Raffle.sol:L518-L523`).
- Constructors, clone path, modifiers, and base contracts → factory clone creation/initialization at `RaffleFactory.sol:L97-L121`, implementation lock at `Raffle.sol:L151-L166`, ERC-1167 fixed-target deployment at `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`, `nonReentrant` at `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`, and wrapper callback dispatch at `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107`. None supplies an alternate timing path.

---

**How the verdict was reached:** The request lower bound is enforced with `< endTime`, so the exact sale-end timestamp is time-eligible, and the request upper bound is enforced with `>= endTime + 2 days`, so the exact deadline is excluded (`target/packages/contracts/src/Raffle.sol:L240-L247`, `L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`). The sole authenticated callback path uses the same exclusive form, `block.timestamp >= drawRequestedAt + 2 days`, before any resolution write (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L463-L465`, `L509-L523`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). It is therefore `implemented`, not `partial`: no in-scope request branch bypasses either request comparison, and no callback branch performs resolution at or after its deadline. It is not `stronger-than-spec`: the status, sold-entry, fee, caller, request-ID, word-count, and in-flight checks are independent validity conditions and do not move either stated time boundary (`target/packages/contracts/src/Raffle.sol:L240-L260`, `L509-L516`). Refund eligibility begins at the same exclusive endpoints rather than opening a gap or overlap (`target/packages/contracts/src/Raffle.sol:L276-L299`).

---

**Open questions:**

- None material to this requirement. The target contains the consumer-side wrapper interface and authenticated callback gateway, but not the deployed wrapper implementation; request-ID provenance is external to the target. That does not affect the consumer's locally enforced request or callback timestamp comparisons (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L67-L81`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L515`).
