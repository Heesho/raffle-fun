## REQ-35 — Refund opening boundary

> "Refunds open at deadline."
> — DESIGN.md:L2, sentence 11

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** The supplied checkable formulation is: “Refund operations become available from the applicable deadline inclusively and remain unavailable before it.” Read with the surrounding specification text, “Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days. Refunds open at deadline.” (`DESIGN.md:L2`), this requires an unresolved sold raffle to permit the refund transition at `endTime + 2 days`, and a drawing raffle to permit it at `drawRequestedAt + 2 days`; each path must reject the transition at every strictly earlier timestamp. The unqualified quoted requirement does not state a before-deadline actor exception.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L36
/// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;

/// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;

// target/packages/contracts/src/Raffle.sol:L458-L465
function drawRequestDeadline() public view override returns (uint256 deadline) {
    deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
}

function callbackDeadline() public view override returns (uint256 deadline) {
    if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
}
```

- The two applicable liveness deadlines are computed by widening their stored `uint64` bases to `uint256` and adding the fixed two-day constants (`target/packages/contracts/src/Raffle.sol:L458-L465`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L36`).

```solidity
// target/packages/contracts/src/Raffle.sol:L276-L300
function enableRefunds() external override nonReentrant {
    uint256 deadline;

    if (status == Status.Active) {
        if (totalEntries == 0) {
            deadline = endTime;
            if (msg.sender != sponsor && block.timestamp < deadline) {
                revert RefundsNotAvailable(deadline, block.timestamp);
            }
        } else {
            deadline = drawRequestDeadline();
            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
        }
    } else if (status == Status.Drawing) {
        deadline = callbackDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    } else {
        revert InvalidStatus(status);
    }

    uint256 liability = unsettledPot;
    unsettledPot = 0;
    remainingRefundLiability = liability;
    status = Status.Refunding;
    emit RefundsEnabled(msg.sender, liability);
}
```

- On the sold `Active` branch, `block.timestamp < drawRequestDeadline()` reverts; equality and every later time reach the `Refunding` write (`target/packages/contracts/src/Raffle.sol:L285-L300`).
- On the `Drawing` branch, `block.timestamp < callbackDeadline()` reverts; equality and every later time reach the same write (`target/packages/contracts/src/Raffle.sol:L289-L300`).
- On the empty `Active` branch, the code assigns `endTime` as `deadline`, but the condition is conjunctive. When `msg.sender == sponsor`, the condition is false even when `block.timestamp < endTime`, so the sponsor reaches `status = Status.Refunding` before that assigned deadline (`target/packages/contracts/src/Raffle.sol:L279-L300`). This is the uncovered path.

The successful early transition has a concrete effect beyond the status name:

```solidity
// target/packages/contracts/src/Raffle.sol:L395-L406
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();

    address recipient = sponsorRecipient;
    prizeClaimed = true;
    prizeToken.transferFrom(address(this), recipient, prizeTokenId);
    if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
    emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
}
```

- Once the empty-raffle sponsor takes the early branch, `releaseSponsorPrize` accepts `Refunding` and returns the escrowed prize to `sponsorRecipient` (`target/packages/contracts/src/Raffle.sol:L395-L406`). The gap therefore does not rest on a promising function or state name.

The adjoining operations use complementary strictness at the same boundaries:

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

// target/packages/contracts/src/Raffle.sol:L509-L516
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }
```

- A draw request is rejected at and after its deadline (`target/packages/contracts/src/Raffle.sol:L240-L247`), while the sold-raffle refund branch rejects only timestamps before that deadline (`target/packages/contracts/src/Raffle.sol:L285-L288`).
- A callback is ignored at and after its deadline (`target/packages/contracts/src/Raffle.sol:L509-L516`), while the drawing refund branch rejects only timestamps before it (`target/packages/contracts/src/Raffle.sol:L289-L292`). Thus equality belongs to refunds on both normal liveness paths.
- Actual ticket payout cannot bypass the transition: `refundTickets` first requires `Status.Refunding`, then burns owner-held tickets, consumes `remainingRefundLiability`, and transfers the calculated amount (`target/packages/contracts/src/Raffle.sol:L349-L371`).

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `Clones.clone` → `Raffle.initialize` → prize callback: the factory requires `params.endTime > block.timestamp`, creates and initializes the clone, then escrows the prize and verifies `Active` (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`). Initialization records `sponsor` and `endTime` and selects `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`); the exact prize callback selects `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). The factory has one `Clones.clone` call and one `initialize` call in scope (`target/packages/contracts/src/RaffleFactory.sol:L106-L121`).
- Fresh empty `Active` raffle → sponsor calls `enableRefunds` while `block.timestamp < endTime`: `totalEntries == 0`, `deadline = endTime`, and `msg.sender != sponsor` is false, so execution skips the only pre-deadline revert and writes `Refunding` (`target/packages/contracts/src/Raffle.sol:L279-L300`). The sponsor can then trigger prize return (`target/packages/contracts/src/Raffle.sol:L395-L406`). ✗
- Empty `Active` raffle → non-sponsor calls before `endTime`: the same branch reverts with `RefundsNotAvailable`; at exact equality, `<` is false and the transition succeeds (`target/packages/contracts/src/Raffle.sol:L279-L300`). ✓
- Sold `Active` raffle → `enableRefunds`: a purchase is the only production write that increases `totalEntries` and `unsettledPot` (`target/packages/contracts/src/Raffle.sol:L223-L233`). With `totalEntries != 0`, the transition rejects every timestamp below `endTime + 2 days` and accepts equality (`target/packages/contracts/src/Raffle.sol:L285-L300`, `L458-L460`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`). ✓
- Sold `Active` raffle → `requestDraw` → `Drawing` → `enableRefunds`: `requestDraw` selects `Drawing` and records `drawRequestedAt` before invoking the wrapper (`target/packages/contracts/src/Raffle.sol:L240-L260`). In `Drawing`, refunds reject every timestamp below `drawRequestedAt + 2 days` and accept equality (`target/packages/contracts/src/Raffle.sol:L289-L300`, `L463-L465`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). ✓
- Configured wrapper → `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: the base contract admits only the immutable wrapper and then calls the overridden handler (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). The handler ignores equality and later times (`target/packages/contracts/src/Raffle.sol:L509-L516`), so it cannot take the result branch at the same timestamp at which `enableRefunds` becomes available. ✓
- Pre-refund ticket owner → `refundTickets`: `_requireStatus(Status.Refunding)` rejects the payout while an unresolved sold raffle remains `Active` or `Drawing`; after the transition, there is no later time ceiling (`target/packages/contracts/src/Raffle.sol:L349-L371`, `L573-L575`). ✓
- `enableRefunds` → inherited `nonReentrant`: the modifier performs only the shared entered-state check around the function body and adds no timestamp comparison, role check, or alternate refund path (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`).
- Implementation constructor versus clone construction: the implementation is deliberately locked with `initialized = true` and `Status.Refunding` (`target/packages/contracts/src/Raffle.sol:L151-L166`); the factory's operational raffles are minimal proxies immediately passed through `initialize` and prize activation (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`). The locked implementation has no configured raffle deadline or factory-escrowed ticket/prize state and does not cure or create the clone-specific sponsor bypass.
- Type bounds: `endTime` and `drawRequestedAt` are stored as `uint64` (`target/packages/contracts/src/Raffle.sol:L82-L83`, `L111-L113`), and both additions widen before adding two days (`target/packages/contracts/src/Raffle.sol:L458-L465`), so the additions cannot approach `uint256` overflow. `requestDraw` records the environment timestamp with a direct narrowing cast (`target/packages/contracts/src/Raffle.sol:L252-L254`); no production call uses the pinned dependency's checked `toUint64` helper (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol:L431-L446`).

---

**Searched:**

- Scope coverage → read all five production files under `target/packages/contracts/src` and every one of the 31 files named by `target/dependency-hashes.json`; all 31 actual SHA-256 values matched the manifest.
- `refund|reimburse|rebate|repay|restitution|cancel` → 62 case-insensitive hits in the scoped files. Relevant executable refund hits reduce to `Raffle.enableRefunds`, `Raffle.refundTickets`, the `Refunding` state, its liability writes, and sponsor-prize release; four dependency hits in `ReentrancyGuard.sol:L46-L49,L103` refer only to gas refunds. `reimburse|reimbursement`, `rebate`, `repay|repayment`, and `restitution` each returned 0 hits.
- `enableRefunds\s*\(` → 2 hits: `IRaffle.sol:L324` and `Raffle.sol:L276`; no in-scope wrapper or caller. `refundTickets\s*\(` → 2 hits: `IRaffle.sol:L344` and `Raffle.sol:L349`; no alternate payout entrypoint.
- `deadline|timeout|expir|window` → 36 hits. Executable timing logic is confined to the two constants (`RaffleConstants.sol:L33,L36`), the two deadline getters (`Raffle.sol:L458-L465`), request/callback closure (`Raffle.sol:L244-L246,L512`), and the three `enableRefunds` comparisons (`Raffle.sol:L281-L291`); the other hits are declarations and NatSpec.
- Timestamp-comparison sweep (`block.timestamp` on either side of `<`, `<=`, `>`, or `>=`) → 7 hits, all in `Raffle.sol:L216,L242,L245,L282,L287,L291,L512`. No `<=` refund guard exists; the refund guards use `<`, while request/callback closure uses `>=`.
- `status\s*=` → 8 hits, all in `Raffle.sol:L165,L205,L252,L279,L289,L299,L428,L521`: six assignments and the two `==` branch comparisons at `L279,L289`. The narrower `status\s*=\s*Status\.Refunding` search returned only `L165` and `L299`; `L165` locks the implementation constructor, so the only operational clone write to `Refunding` is `enableRefunds` at `L299`.
- `Status\.Refunding|remainingRefundLiability` → 14 hits: interface/event/getter declarations plus `Raffle.sol:L94,L165,L298-L299,L350,L368,L370,L397,L469`. This found the ticket-payout gate and sponsor-prize consequence of the early transition.
- `nonReentrant|modifier` → 33 hits. `enableRefunds` and `refundTickets` each have only `nonReentrant`; reading `ReentrancyGuard.sol:L69-L105` found no hidden deadline enforcement.
- `function initialize|.initialize`, `Clones.clone`, and `rawFulfillRandomWords|fulfillRandomWords` → respectively 3, 1, and 6 hits. These covered the factory caller, clone creation, callback base contract, and override; none adds a pre-call refund deadline check.
- Checked-cast spellings `SafeCast.toUint64` and `.toUint64(` → 0 production calls. Direct `uint64(block.timestamp)` → 2 hits at `Raffle.sol:L253,L520`; the first supplies the callback-deadline base.

---

**How the verdict was reached:** This is `partial`, not `implemented`, because the sold-`Active` and `Drawing` branches implement the intended half-open handoff exactly—`< deadline` blocks refunds and `>= deadline` blocks the competing draw/callback operation—but the reachable empty-`Active` sponsor branch bypasses its assigned `endTime` check and enters the same `Refunding` state early (`target/packages/contracts/src/Raffle.sol:L279-L300`). It is not `contradicted`: both economically relevant ticket-refund liveness branches, plus the empty non-sponsor branch, honor the inclusive boundary. The exception is nevertheless real rather than nominal because it enables return of the escrowed prize before `endTime` (`target/packages/contracts/src/Raffle.sol:L395-L406`). The absence of an empty-sponsor exception from “Refunds open at deadline.” (`DESIGN.md:L2, sentence 11`) prevents treating that path as compliant or as stronger-than-spec.

---

**Open questions:**

- No open question can change the `partial` category: the empty-sponsor bypass is source-visible and reachable through the canonical factory path. Separately, the target does not establish an environmental bound proving that every future `block.timestamp` fits `uint64`; `requestDraw` narrows it directly at `target/packages/contracts/src/Raffle.sol:L253`. An external Ethereum timestamp-width guarantee would close that type-bound question, while its absence could add another late-time callback-deadline gap; neither outcome removes the earlier sponsor bypass.
