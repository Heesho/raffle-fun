## `fulfillRandomWords` in target/packages/contracts/src/Raffle.sol (L509-L524)

**Purpose:** Converts an authenticated, timely callback for the recorded draw into a selected one-based entry and the reserve-dependent result. This is the write site for `winningEntry` and `resolvedAt`, and the transition from `Drawing` to `NftWon` or `CashWon`; settlement later consumes this result and winning-entry range proof (Raffle.sol:L509-L524, L533-L558, L579-L585). It does not select an owner or allocate balances itself (Raffle.sol:L518-L523).

---

**Inputs & Assumptions:**

- `requestId` (`uint256`) and `randomWords` (`uint256[] memory`) arrive from the wrapper through inherited `rawFulfillRandomWords`. Trust: trusted origin under the supplied canonical-wrapper orientation, with request association and word count independently checked here. The external entrypoint rejects any caller other than the immutable wrapper before dispatching to this override (VRFV2PlusWrapperConsumerBase.sol:L35, L101-L107; Raffle.sol:L509-L512).
- Implicit inputs are `_requestInFlight`, `status`, `vrfRequestId`, `drawRequestedAt` through the deadline getter, `totalEntries`, `reserveEntries`, and `block.timestamp` (Raffle.sol:L511-L521, L463-L465). The wrapper origin gate establishes identity, not the unpredictability or probability distribution of `randomWords[0]`; nothing found in that gate or this handler establishes those randomness properties (VRFV2PlusWrapperConsumerBase.sol:L101-L107; Raffle.sol:L511-L518). They remain assumptions of the supplied trusted-randomness-service model.
- Resolution requires positive `totalEntries`, although the handler does not check positivity immediately before modulo. `requestDraw` rejects zero entries before setting `Drawing`; purchases require `Active` and are the sole assignment to `totalEntries` in the inspected raffle source (Raffle.sol:L215-L232, L240-L260). Thus the reachable `Drawing` lifecycle supplies the divisor precondition. The local `uint128` type and purchase overflow check bound the divisor (Raffle.sol:L85, L219-L230).
- `reserveEntries` is supplied once during initialization and read for the result comparison; the handler does not separately validate that configuration (Raffle.sol:L176-L179, L203, L521).
- The time window comes from `callbackDeadline`, whose nonzero branch returns `uint256(drawRequestedAt) + 2 days`; its zero branch returns the default zero value (Raffle.sol:L463-L465; RaffleConstants.sol:L35-L36). The handler requires the current timestamp to be strictly below that returned deadline (Raffle.sol:L512).
- Exact preservation of a timestamp by the explicit `uint64` conversions depends on timestamp representability. Nothing found locally checks that bound before storing request or resolution time (Raffle.sol:L253, L520). The deadline getter widens the stored request time before addition (Raffle.sol:L464).

---

**Outputs & Effects:**

The function has no return values. A guard failure emits `VrfCallbackIgnored(requestId, vrfRequestId, status)` and returns without storage writes. The event contains received request ID, recorded request ID and current status; it does not identify which individual condition failed (Raffle.sol:L509-L516; IRaffle.sol:L98-L102). A valid resolution writes exactly `winningEntry`, `resolvedAt`, and `status`, then emits `RaffleResolved` containing the accepted request ID, computed entry and stored terminal result (Raffle.sol:L518-L523; IRaffle.sol:L104-L108).

There is no loop, ownership lookup, token/native transfer or external call in this handler; its only function call is the internal invocation of the public view getter `callbackDeadline` (Raffle.sol:L509-L524, L463-L465). Consequently no user receiver or prize-token behavior is needed to execute the result-writing path itself. The balance allocation and owner-authorized delivery steps reside in separate functions (Raffle.sol:L533-L558, L309-L345).

On successful resolution, `1 <= winningEntry <= totalEntries`, `status` is `NftWon` exactly when `totalEntries >= reserveEntries`, and otherwise it is `CashWon` (Raffle.sol:L518-L521). This describes the arithmetic mapping, not a guarantee of exact uniformity of every entry; the source uses a modulo reduction and no rejection-sampling branch (Raffle.sol:L518). A later callback cannot overwrite these values through this handler because terminal status fails the `Drawing` requirement (Raffle.sol:L511, L519-L521).

---

**Block-by-Block:**

```solidity
// Raffle.sol:L510-L516
if (
    _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
        || block.timestamp >= callbackDeadline()
) {
    emit VrfCallbackIgnored(requestId, vrfRequestId, status);
    return;
}
```

- **What:** Ignores callbacks during wrapper-request execution, outside `Drawing`, for another request, with any array length other than one, or at/after the computed callback deadline (Raffle.sol:L510-L516).
- **Why here:** All rejection branches precede the array read, modulo and result writes. In particular, the length check guards `randomWords[0]`, while the in-flight flag covers the interval in which `requestDraw` has already written `Drawing` but has not persisted the wrapper-returned request ID (Raffle.sol:L252-L260, L511-L518).
- **Assumes:** Wrapper authentication has already executed in the inherited external entrypoint; it is not duplicated here (VRFV2PlusWrapperConsumerBase.sol:L101-L107; Raffle.sol:L509-L516). The supplied array has already reached the Solidity function body; the source explicitly distinguishes ABI-decodable wrong lengths from malformed calldata rejected before the handler (Raffle.sol:L504-L509).
- **Establishes:** Fall-through has `_requestInFlight == false`, `status == Drawing`, matching request ID, exactly one word and a timestamp strictly less than `callbackDeadline()`. Each disqualifying condition takes the same event-and-return path (Raffle.sol:L510-L516).
- **Depended on by:** The subsequent array read and one-time terminal transition (Raffle.sol:L518-L523). Through the established `Drawing` lifecycle, the modulo also relies on the positive-entry precondition from `requestDraw` (Raffle.sol:L243, L252).

The `||` chain short-circuits, so `callbackDeadline` is needed only after the first four conditions pass. Its complete body is:

```solidity
// Raffle.sol:L463-L465
function callbackDeadline() public view override returns (uint256 deadline) {
    if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
}
```

- **What:** Returns the widened stored request timestamp plus the two-day constant if the stored timestamp is nonzero; otherwise returns zero (Raffle.sol:L463-L465; RaffleConstants.sol:L35-L36).
- **Why here:** The caller checks deadline after request context and payload shape, using the same helper that gates refunds from `Drawing` (Raffle.sol:L510-L512, L289-L291).
- **Assumes:** Its input timestamp has the meaning assigned by `requestDraw`; that setter stores `uint64(block.timestamp)` (Raffle.sol:L253).
- **Establishes:** It is side-effect free and makes no calls. It does not itself establish `Drawing`, a matching request ID, or a nonzero request time; those are distinct conditions, and the zero-time branch produces a deadline that cannot admit a nonnegative block timestamp (Raffle.sol:L463-L465, L511-L512).
- **Depended on by:** The caller's exclusive acceptance boundary and the complementary refund boundary (Raffle.sol:L512, L289-L291). With the fixed two-day constant and a widened `uint64` operand, the addition fits `uint256` (Raffle.sol:L112, L464; RaffleConstants.sol:L36).

```solidity
// Raffle.sol:L518-L521
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;
```

- **What:** Maps the one supplied word into the one-based sold-entry interval, stores it with resolution time, and selects the economic result by comparing sales count with the configured reserve (Raffle.sol:L518-L521).
- **Why here:** These writes occur only after every callback guard passes, with no intervening external interaction (Raffle.sol:L510-L521).
- **Assumes:** Positive and fixed `totalEntries` comes from the request and purchase lifecycle, not from a fresh local check (Raffle.sol:L215-L232, L241-L260). Exact timestamp storage assumes `uint64` representability; nothing found locally enforces that conversion bound (Raffle.sol:L520).
- **Establishes:** Modulo produces a value below the positive `uint128` total; adding one remains within `uint128`, so the entry cast preserves that result. Equality with the reserve takes the NFT branch; falling below it takes the cash branch (Raffle.sol:L85, L518-L521).
- **Depended on by:** Winning-range validation uses `winningEntry`; settlement and redemption require one of these result statuses; sponsor prize release permits the cash result (Raffle.sol:L579-L585, L535-L548, L311-L315, L395-L399).

```solidity
// Raffle.sol:L523
emit RaffleResolved(requestId, resolvedEntry, status);
```

- **What:** Publishes the accepted request, chosen entry and terminal result (Raffle.sol:L523; IRaffle.sol:L104-L108).
- **Why here:** The event is emitted after all three result writes, using the stored result status (Raffle.sol:L519-L523).
- **Assumes:** Earlier guard and lifecycle preconditions admitted a valid resolution (Raffle.sol:L510-L521).
- **Establishes:** A completed result-writing path emits this event, while rejected callbacks emit the distinct ignored event (Raffle.sol:L514-L515, L523).
- **Depended on by:** Event consumers receive the exact request/entry/result fields declared in the interface; the event contains no winning ticket ID or owner (IRaffle.sol:L104-L108).

---

**Cross-Function Dependencies:**

- **Callee `callbackDeadline` (internal invocation of public view):** Read in full, including its zero-input branch. Propagates either zero or the widened stored request timestamp plus two days, without independently checking lifecycle or request identity (Raffle.sol:L463-L465; RaffleConstants.sol:L35-L36). There are no nested calls in that helper and no external calls from the analyzed handler (Raffle.sol:L463-L465, L509-L524).
- **Caller `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords`:** Its authentication failure reverts before dispatch; its authenticated path passes both inputs unchanged and performs no post-handler state change. It relies on this override for request matching, payload-length checks, timing, and the result transition (VRFV2PlusWrapperConsumerBase.sol:L101-L107; Raffle.sol:L510-L523).
- **Request setup:** `requestDraw` checks nonempty sales, enters `Drawing`, records request time, holds `_requestInFlight` across the wrapper request, then stores the returned request ID before clearing the flag (Raffle.sol:L243, L252-L260). The handler depends on this exact ordering to ignore synchronous callbacks before request persistence (Raffle.sol:L511). The parent request can still revert on a failed excess refund; its refund step follows flag clearing (Raffle.sol:L262-L270).
- **Shared state:** Purchases establish the entry count and inclusive ranges; initialization establishes the reserve; request setup establishes the request ID/time and in-flight marker; the handler establishes the selected entry, result and resolution time; refund activation can instead move `Drawing` to `Refunding` (Raffle.sol:L203, L215-L235, L252-L260, L289-L300, L518-L521).
- **Deadline coupling:** At the exact callback deadline, this handler takes the ignored branch while `enableRefunds` permits its `Drawing` timeout transition. After a successful terminal result, `enableRefunds` rejects that status, and after refunds are enabled this handler rejects the non-`Drawing` state (Raffle.sol:L289-L300, L511-L515, L521).
- **Resolution/settlement separation:** Result resolution leaves `unsettledPot`, `winningTicketId`, `settlementComplete` and payout liabilities untouched. Settlement later checks the result, proves the entry interval and writes those allocations; redemption then uses current ticket ownership (Raffle.sol:L518-L523, L533-L558, L579-L585, L320-L342).

---

**Open Questions:**

None for the bounded handler and its sole callee after reading both complete bodies. The trusted-service randomness properties and timestamp-representation assumption remain explicitly identified above, rather than inferred from the authentication or deadline logic (VRFV2PlusWrapperConsumerBase.sol:L101-L107; Raffle.sol:L253, L518-L520).

