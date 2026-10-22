## REQ-33 — Exclusive draw-request deadline

> "Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days."
> — DESIGN.md:L2, sentence 10

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For this extracted record, the supplied checkable defines the property as: a request is time-eligible only while its timestamp is less than sale end plus two days, and it is rejected at or after that upper bound. The verbatim source phrase `"Request window [sale end, end+2days)"` also fixes sale end as the inclusive lower endpoint. The callback clause remains in the required verbatim quotation, but it is not used to broaden REQ-33 beyond its supplied request-window predicate.

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

- The request timeout is the fixed literal `2 days`; there is no mutable request-timeout state (`target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L36`).

```solidity
// target/packages/contracts/src/Raffle.sol:L458-L460
function drawRequestDeadline() public view override returns (uint256 deadline) {
    deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
}
```

- The deadline is calculated as sale end plus that fixed timeout. `endTime` is converted to `uint256` before addition (`target/packages/contracts/src/Raffle.sol:L458-L460`).

```solidity
// target/packages/contracts/src/Raffle.sol:L240-L247
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }
```

- The lower comparison rejects only `block.timestamp < endTime`, so a request at sale end passes this time gate. The upper comparison rejects `block.timestamp >= requestDeadline`, so a request one second below the deadline passes the time gate while a request exactly at or later than the deadline reverts (`target/packages/contracts/src/Raffle.sol:L240-L247`).
- The lifecycle and sold-entry checks are additional non-temporal prerequisites: `requestDraw` first requires `Active`, and zero sold entries revert independently of the window (`target/packages/contracts/src/Raffle.sol:L240-L247`; `target/packages/contracts/src/Raffle.sol:L571-L575`).

```solidity
// target/packages/contracts/src/Raffle.sol:L249-L260
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

- All request creation occurs after the upper-bound comparison. The inherited helper then calls the configured wrapper's sole native request method; neither the helper nor the wrapper interface exposes another local route that bypasses `requestDraw`'s time gate (`target/packages/contracts/src/Raffle.sol:L249-L260`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L89`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L67-L81`).

---

**Paths walked:**

- Factory constructor → fixed implementation: the factory validates its dependencies, deploys one `Raffle` implementation, and stores that implementation immutably (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`). The implementation constructor locks its own storage in `Refunding`, so it cannot itself enter the `Active` request path (`target/packages/contracts/src/Raffle.sol:L151-L166`).
- `createRaffle` → clone → `initialize`: `createRaffle` requires a future `endTime` and a sale duration no greater than 30 days, creates the fixed-target clone, and passes the same `endTime` into initialization (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`). `initialize` is one-time and factory-only, and it is the sole writer of stored `endTime` (`target/packages/contracts/src/Raffle.sol:L176-L205`). No constructor or alternate initializer supplies a second deadline.
- Type bounds → deadline arithmetic: the creation ABI bounds `endTime` to `uint64` (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`), while `drawRequestDeadline` first widens it to `uint256` and adds the `uint256` two-day constant (`target/packages/contracts/src/Raffle.sol:L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L34`). Thus the request-deadline addition cannot overflow `uint256`: its largest input is `type(uint64).max`, far below `type(uint256).max` (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L19-L26`; `target/packages/contracts/src/Raffle.sol:L458-L460`).
- Before sale end: `block.timestamp < endTime` takes the `RaffleNotEnded` branch (`target/packages/contracts/src/Raffle.sol:L240-L243`). ✓
- At sale end: `block.timestamp < endTime` is false, and `endTime < endTime + 2 days`, so the request passes both time comparisons when the independent status, entry, and fee conditions hold (`target/packages/contracts/src/Raffle.sol:L240-L250`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L34`). ✓
- Inside the upper edge: any timestamp strictly below `drawRequestDeadline()` makes the `>=` condition false (`target/packages/contracts/src/Raffle.sol:L244-L247,L458-L460`). ✓
- At and after the upper edge: equality and every later timestamp make `block.timestamp >= requestDeadline` true and revert with `DrawRequestWindowExpired` before price lookup, state mutation, or the external wrapper request (`target/packages/contracts/src/Raffle.sol:L244-L249`). ✓
- Successful request → no repeat request: after the checks, a successful request writes `Status.Drawing` (`target/packages/contracts/src/Raffle.sol:L249-L260`). A subsequent `requestDraw` fails the leading `Active` status requirement, whose callee reverts on any unequal status (`target/packages/contracts/src/Raffle.sol:L240-L241,L571-L575`). This state branch cannot reopen the request window.
- Deadline → refunds branch: for a sold raffle still in `Active`, `enableRefunds` uses the same `drawRequestDeadline()` and rejects only while `block.timestamp < deadline`; at the exclusive request endpoint it can move the raffle to `Refunding` (`target/packages/contracts/src/Raffle.sol:L276-L300`). That complementary branch does not admit a late request because `requestDraw` independently rejects `>= requestDeadline` and also requires `Active` (`target/packages/contracts/src/Raffle.sol:L240-L247`).
- Modifier path: `requestDraw` is `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L240`). The modifier runs its guard before the body and restores it afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L105`); it does not skip or replace the deadline comparison.
- Callers: the only first-party production hits for `requestDraw` are its interface declaration and the external implementation (`target/packages/contracts/src/interfaces/IRaffle.sol:L316-L320`; `target/packages/contracts/src/Raffle.sol:L240-L273`). There is no in-scope wrapper or caller with a different request-time path.

---

**Searched:**

- Full allowed implementation inventory → read all five first-party production files and all 31 files named by `target/dependency-hashes.json`; recomputation produced `dependency_count=31 mismatches=0`.
- `DRAW_REQUEST_TIMEOUT|DRAW_CALLBACK_TIMEOUT` → 4 hits: request/callback deadline uses at `Raffle.sol:L459,L464` and the two fixed definitions at `RaffleConstants.sol:L33,L36`. For REQ-33, the request pair is the relevant pair.
- `drawRequestDeadline|callbackDeadline` → 12 hits: interface documentation/declarations and Raffle calls/definitions. The request deadline has one implementation at `Raffle.sol:L458-L460`; its state-changing consumers are `requestDraw` at L244-L247 and the sold-raffle refund branch at L286-L287.
- `requestDraw\(|requestRandomnessPayInNative|requestRandomWordsInNative` → 6 hits: the interface entrypoint, sole Raffle implementation, its inherited-helper call, the helper definition/call, and wrapper-interface declaration. No alternate request entrypoint was found.
- `.requestDraw\(|function requestDraw\(` over first-party production → 2 hits: `IRaffle.sol:L320` and `Raffle.sol:L240`; no caller-side bypass exists in scope.
- `\bendTime\s*=` → 1 hit, `Raffle.sol:L204`. `.initialize\(|function initialize\(` → 3 hits: interface declaration, factory call, and Raffle implementation (`IRaffle.sol:L308`, `RaffleFactory.sol:L110`, `Raffle.sol:L176`). No alternate deadline writer or initialization route was found.
- `block.timestamp|endTime|drawRequestedAt` → 42 hits across the allowed scope; request-relevant reads/writes resolve to factory validation at `RaffleFactory.sol:L99-L104`, initialization at `Raffle.sol:L204`, request comparisons at `Raffle.sol:L242-L247`, and deadline arithmetic at `Raffle.sol:L458-L460`.
- `nonReentrant` → the request entrypoint is guarded at `Raffle.sol:L240`, and the inherited modifier implementation is at `ReentrancyGuard.sol:L69-L105`; no modifier supplies an alternate body.
- Alternative request-timing vocabulary `expiry|expires|expiration|maxAge|ttl|gracePeriod|48 hours|172800` over the five production files → 0 hits. Alternative time sources `block.number|now` over those files → 0 hits. The request gate consistently uses `block.timestamp`.

---

**How the verdict was reached:** The supplied checkable is satisfied directly. The implementation derives an exclusive deadline as `uint256(endTime) + 2 days` (`target/packages/contracts/src/Raffle.sol:L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L34`) and rejects `block.timestamp >= requestDeadline` before any draw-request state change or wrapper call (`target/packages/contracts/src/Raffle.sol:L244-L260`). Therefore every timestamp at or after sale end plus two days is rejected. The adjacent lower comparison rejects only timestamps before sale end, making the source phrase `"[sale end, end+2days)"` exact at both endpoints (`target/packages/contracts/src/Raffle.sol:L240-L247`).

This is `implemented`, not `partial`, because there is only one request entrypoint and every path that reaches the wrapper request has already passed the same upper-bound comparison (`target/packages/contracts/src/interfaces/IRaffle.sol:L316-L320`; `target/packages/contracts/src/Raffle.sol:L240-L260`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L89`). It is not `stronger-than-spec` on the temporal dimension: the upper comparison is exactly `>= endTime + 2 days`, while status, sold-entry, and fee checks are orthogonal prerequisites rather than an earlier time cutoff (`target/packages/contracts/src/Raffle.sol:L240-L250,L458-L460`).

---

**Open questions:**

- None for the supplied request-window predicate.
