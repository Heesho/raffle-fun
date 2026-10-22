## `fulfillRandomWords` in packages/contracts/src/Raffle.sol (L509-L524), reached via inherited `rawFulfillRandomWords` (VRFV2PlusWrapperConsumerBase.sol L101-L107)

Path abbreviations, all relative to `packages/contracts/`:
- `Raffle` = `src/Raffle.sol` (bare `Lnnn` means this file)
- `ConsumerBase` = `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`
- `Constants` = `src/libraries/RaffleConstants.sol`
- `IRaffle` = `src/interfaces/IRaffle.sol`
- `Factory` = `src/RaffleFactory.sol`
- `Clones` = `node_modules/@openzeppelin/contracts/proxy/Clones.sol`

**Purpose:** This is the only code that moves a raffle from `Drawing` to a winning result. It turns one VRF word
into a one-based global entry number in `[1,totalEntries]` (L518), and it picks `NftWon` or `CashWon` by comparing
`totalEntries` with `reserveEntries` (L521). It moves no assets and reads no ticket ownership: L509-L524 contain no
external call and no ERC-721 read. `_settleWinningTicket` (L533-L558), `redeemWinningTicket` (L309-L346) and
`releaseSponsorPrize` (L395-L407) consume what it writes.

L521 is the only line that writes `NftWon` or `CashWon`. The full list of `status` writers is L165, L205, L252,
L299, L428 and L521. Without this function, a `Drawing` raffle can leave only through `enableRefunds` at or after
`callbackDeadline()` (L289-L291, L299), and settlement (L536) and redemption (L312) are unreachable.

Correction to the selection summary that dispatched this analysis: the ignore path does not revert, but it is not
silent. It emits `VrfCallbackIgnored` (L514).

**Inputs & Assumptions:**
- `requestId` (uint256): the request identifier passed in by the address that clears ConsumerBase L103. The source
  is trusted (the wrapper), but the value is not taken on trust: it is compared with stored `vrfRequestId` (L511).
- `randomWords` (uint256[] memory): ABI-decoded from calldata at the external boundary (ConsumerBase L101).
  Malformed calldata reverts during decoding, before the body runs (NatSpec L505-L506). Its unpredictability is
  trusted, and nothing in the repo verifies it. Its length is checked (L511). Its content is not checked.
- Implicit inputs:
  - `msg.sender`, checked only at ConsumerBase L103.
  - `block.timestamp` (L512, L520).
  - Storage: `_requestInFlight` (L142), `status` (L124), `vrfRequestId` (L109), `drawRequestedAt` (L112, through
    `callbackDeadline()` at L464), `totalEntries` (L85), `reserveEntries` (L79).
  - The authenticating address `i_vrfV2PlusWrapper`, an immutable in the implementation bytecode (ConsumerBase
    L35, L46).
- Preconditions, and what establishes each:
  - **P1. The caller is the genuine Chainlink VRF v2.5 wrapper.**
    - That `msg.sender` equals the immutable is established by ConsumerBase L103.
    - That the immutable is the genuine wrapper is established by **nothing found** on-chain. The only checks are
      non-zero (`_validatedVrfWrapper`, L611) and code presence (Factory L67).
    - Identity rests on deployer trust (Factory L63 NatSpec; DESIGN.md L2).
  - **P2. `totalEntries > 0` whenever `status == Drawing`.** Without it, the `%` at L518 panics.
    - Established by `requestDraw` L243, the only route into `Drawing` (L252).
    - `totalEntries` never decreases. Its only writer, L230, assigns `totalEntries + entryCount` with
      `entryCount >= 1` (L218) and overflow excluded (L219-L221).
  - **P3. `totalEntries` has not changed since L243.** The sole writer, `buyEntries` (L230), is gated two ways:
    - Status gate: `status == Active` (L215). `Drawing` is never followed by `Active`: the only writer of `Active`
      is L428, which requires `AwaitingPrize` (L422), and `AwaitingPrize` is written only once (L205, guarded by
      L177/L179).
    - Time gate: `block.timestamp < endTime` (L216). `Drawing` is entered only at `block.timestamp >= endTime`
      (L242). `endTime` has a single writer (L204).
    - Either gate alone freezes the value used at L518/L521.
  - **P4. `reserveEntries > 0`.** If it were 0, L521 would always yield `NftWon`.
    - Established only by `RaffleFactory._validateCreateParams` L178.
    - `Raffle.initialize` stores the value unchecked (L203). It relies on being callable only by the factory
      (L178).
  - **P5. `drawRequestedAt != 0` while `Drawing`.**
    - L253 writes `uint64(block.timestamp)` in the same transaction as L252.
    - That the timestamp is non-zero is a chain property, not a check.
    - The function fails closed here: a zero value makes `callbackDeadline()` return 0 (L464), and L512 then
      ignores the callback.
  - **P6. The callback's `requestId` equals the ID returned by `requestRandomWordsInNative` and stored at L259.**
    **Nothing found.** The wrapper source is not vendored.
  - **P7. The wrapper delivers exactly the one word requested (L257 passes `numWords = 1`).** **Nothing found.**
    A mismatch is not rejected with a revert; it lands on the ignore path (L511).
  - **P8. `randomWords[0]` is unpredictable before the fulfillment transaction and is not chosen by any party.**
    **Nothing found** in the repo. VRF proof verification happens in the Chainlink coordinator, outside the repo.
  - **P9. The callback gets enough gas.** **Nothing found** on how the wrapper forwards gas. The requested limit
    is 300_000 (Constants L39). The body costs a fixed amount (no loops, L509-L524).

**Outputs & Effects:**
- No return value (L509).
- **Ignore path (L510-L516):**
  - No storage write and no revert. It returns at L515.
  - It emits `VrfCallbackIgnored(requestId, vrfRequestId, status)` (L514). When the in-flight operand triggers
    the ignore, the second field is the pre-request `vrfRequestId`. IRaffle L100 documents this as "zero before
    request persistence".
- **Resolve path (L518-L523):**
  - Storage writes:
    - `winningEntry` (L519): its only writer.
    - `resolvedAt` (L520): its only writer.
    - `status` (L521).
  - Event: `RaffleResolved(requestId, resolvedEntry, status)` (L523). `status` is re-read after the write.
- No external interactions. `callbackDeadline()` at L512 is an internal call to the public view at L463-L465,
  which reads only `drawRequestedAt`.
- Not written on either path: `unsettledPot`, `totalEntries`, `_ticketRanges`, `vrfRequestId`, `drawRequestedAt`,
  `_requestInFlight` and the ERC-721 ledger.
- Postconditions on resolve:
  - `status ∈ {NftWon, CashWon}`.
  - `winningEntry ∈ [1,totalEntries]`.
  - `drawRequestedAt <= resolvedAt < drawRequestedAt + 2 days`.
  - Any later callback is ignored by the `status` operand (L511).

**Block-by-Block:**

```solidity
// ConsumerBase L101-L107 (inherited dispatcher)
function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
    address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
    if (msg.sender != vrfWrapperAddr) {
      revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
    }
    fulfillRandomWords(_requestId, _randomWords);
}
```
- **What:** Checks `msg.sender` against the immutable wrapper address, then dispatches to `Raffle.fulfillRandomWords`
  (L106).
- **Why here:** This is the only external entry. `fulfillRandomWords` is `internal` (L509), and L106 is its only
  call site: in Raffle.sol, the name appears only at its definition, L509.
- **Assumes:**
  - The immutable is the genuine wrapper (P1).
  - On a clone, the ERC-1167 runtime forwards calldata by `DELEGATECALL`. The packed runtime bytecode at Clones
    L54-L56 contains `5af4`, which is GAS DELEGATECALL. So `msg.sender` stays the wrapper, and
    `i_vrfV2PlusWrapper` is read from the implementation's code. Raffle L152 says clones "share these immutables
    but hold isolated storage". Every clone of one factory therefore authenticates the same wrapper (Factory
    L89).
- **Establishes:** `msg.sender == i_vrfV2PlusWrapper` on its only non-reverting path. Nothing else:
  - no `nonReentrant` (L101 has no modifier);
  - no status, ID or length checks;
  - arguments are forwarded unchanged.
- **Depended on by:** the whole of L509-L524, which performs no caller check of its own.

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
- **What:** Five conditions. If any holds, the function emits an event and returns without writing storage.
- **Why here:** All checks run before any write, so an ignored callback leaves storage unchanged. Every operand is
  a side-effect-free read, so `||` short-circuit order affects gas only.
- Per operand:
  - **`_requestInFlight`.**
    - It is true only between L254 and L260 of one `requestDraw` run. L258 is the only revert between them, and
      it reverts the whole transaction, so the flag cannot persist past a transaction.
    - Inside that window `status` is already `Drawing` (L252), and `vrfRequestId` still holds its pre-request
      value. Its only writer is L259, so that value is 0 on a clone.
    - The flag is the definitive guard against a callback arriving synchronously during the wrapper call at L257.
      Without the flag, the ID operand would still reject such a callback unless the wrapper's new ID equals the
      stale `vrfRequestId` (0).
    - `requestDraw` holds the reentrancy lock (L240), but neither this function nor its dispatcher takes it. So
      such a callback runs to the ignore path rather than reverting.
  - **`status != Status.Drawing`.**
    - Excludes `AwaitingPrize` and `Active` (no request yet).
    - Excludes the terminal `NftWon`, `CashWon` and `Refunding`, which covers duplicate callbacks and
      post-refund callbacks.
    - On the implementation instance, `status` is fixed at `Refunding` (L165), so every callback there is
      ignored.
  - **`requestId != vrfRequestId`.**
    - `vrfRequestId` is written at most once per clone. `requestDraw` requires `Active` (L241) and sets
      `Drawing` (L252), and `Active` is reachable at most once (L422/L428 after the one-shot L205). So at most
      one `requestDraw` succeeds.
    - A reverted `requestDraw` leaves no trace, in the raffle or in the wrapper, because the whole transaction
      reverts.
    - The operand rejects callbacks for any other request that are routed to this address.
  - **`randomWords.length != 1`.** Rejects empty arrays, which protects the `[0]` index at L518, and longer
    arrays. L257 requests one word.
  - **`block.timestamp >= callbackDeadline()`.**
    - `callbackDeadline()` returns `drawRequestedAt + 2 days` when `drawRequestedAt != 0`, otherwise 0 (L464;
      Constants L36). The accept window is therefore `[drawRequestedAt, drawRequestedAt + 2 days)`, which
      matches IRaffle L379-L381 ("exclusive deadline") and DESIGN.md L2.
    - The Drawing branch of `enableRefunds` reverts while `block.timestamp < callbackDeadline()` (L290-L291).
      The two predicates are complements over the same deadline function and the same block timestamp.
- **Assumes:** P5 (fails closed if violated). P6 and P7: when they fail, the callback is ignored, not rejected
  with a revert.
- **Establishes:** If execution passes L516, then all of the following hold:
  - not in flight;
  - `status == Drawing`;
  - `requestId == vrfRequestId`;
  - exactly one word;
  - `block.timestamp < drawRequestedAt + 2 days`.
- **Depended on by:** L518, which indexes `[0]` and divides by `totalEntries`, valid because `Drawing` implies P2.
  Also L519-L521, which rely on this executing at most once.
- **Liveness consequence:** An ignored callback for the live request leaves the raffle in `Drawing` until
  `enableRefunds` at `callbackDeadline()` (L289-L291, L299). That covers an in-flight, wrong-ID, wrong-length or
  late callback. Whether the wrapper ever re-delivers is an open question.
- **The window L260-L272:** Here `_requestInFlight` is false, `status == Drawing`, `vrfRequestId` holds the new ID,
  and `block.timestamp == drawRequestedAt < callbackDeadline()`. A callback carrying the new ID and one word
  clears all five operands.
  - L267 makes a full-gas `call` to the untrusted requester inside this window.
  - Reaching this function from there still requires `msg.sender == i_vrfV2PlusWrapper` (ConsumerBase L103).
  - Whether the wrapper can deliver a fulfillment for a request created in the same transaction depends on the
    coordinator's confirmation delay (30 requested, Constants L42). Nothing in the repo establishes it.
  - If such a callback did occur, `RaffleResolved` would be logged before `DrawRequested` (L272), and a failure
    at L269 would revert both.
- **Other untrusted code while `Drawing`:** ERC-721 receiver hooks run during ticket `safeTransferFrom`, because
  tickets are transferable in every state (`_update`, L497-L502, has no status gate). Those paths write only the
  OZ ERC-721 ledger. Each storage slot read at L511-L521 has its writers only at these Raffle lines:
  - `_requestInFlight`: L254, L260
  - `status`: L165, L205, L252, L299, L428, L521
  - `vrfRequestId`: L259
  - `drawRequestedAt`: L253
  - `totalEntries`: L230
  - `reserveEntries`: L203

  So a ticket transfer cannot change what this function computes, and entering this function from a hook again
  requires the wrapper as `msg.sender`.

```solidity
// L518
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
```
- **What:** Reduces the word modulo `totalEntries` and shifts the result to one-based.
- **Why here:** It runs after L511 guarantees that `[0]` exists and that `status == Drawing`, which implies
  `totalEntries > 0` (P2).
- **Assumes:**
  - P2, so there is no division-by-zero panic.
  - P3, so the modulus is the entry count frozen at request time.
  - P8, so the word is unpredictable.
- **Arithmetic:**
  - The `%` and `+ 1` run in uint256. The result lies in `[1, totalEntries]`, at most `type(uint128).max`
    because `totalEntries` is `uint128` (L85).
  - The explicit `uint128(...)` downcast would truncate silently, but no truncation occurs here.
  - The checked `+ 1` cannot overflow, since `% n` is at most `2^128 - 2`.
- **Distribution:** Reducing a 256-bit word modulo `n ≤ 2^128 - 1` gives each outcome a probability within
  `2^-256` of `1/n` in absolute terms. Each residue occurs `floor(2^256/n)` or `floor(2^256/n) + 1` times.
- **Establishes:** `resolvedEntry ∈ [1,totalEntries]`, and in particular `resolvedEntry >= 1`.
- **Depended on by:**
  - `_requireWinningTicket` (L579-L585), through `winningEntry` (L581).
  - A never-minted ticket ID, including 0, has range `(0,0)` (L451-L455; IRaffle L369). Because
    `winningEntry >= 1`, `selectedEntry > lastEntry` is true for every such ID (L582), so it is rejected. The
    `+ 1` is what excludes unminted IDs from settlement.
  - The upper bound `<= totalEntries` keeps the winning entry inside the minted ranges.

```solidity
// L519-L520
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
```
- **What:** Records the selected entry and the resolution time.
- **Assumes:** `uint64(block.timestamp)` does not truncate. **Nothing found** checks this explicit downcast; it
  has the same form as L253.
- **Establishes:**
  - `winningEntry != 0` exactly when the raffle is resolved. L519 is its only writer, and it always runs
    together with L521.
  - `resolvedAt` has no reader inside the contract; it is exposed only through the public getter (L115).
- **Depended on by:** `_requireWinningTicket` L581, reached from `_settleWinningTicket` L538, which
  `settleWinningTicket` (L305) and `redeemWinningTicket` (L315) both call.

```solidity
// L521
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;
```
- **What:** Selects `NftWon` when the reserve is met or exceeded, otherwise `CashWon`.
- **Why here:** It is the last storage write. There is no external call in the function, so write order inside the
  resolve path has no observable effect before the frame ends.
- **Assumes:**
  - P3: `totalEntries` equals the value used at L518.
  - P4: `reserveEntries > 0`.
  - The comparison operands are both `uint128` (L79, L85).
  - `>=` matches "met or exceeded" (IRaffle L43) and "Reserve met awards NFT" (DESIGN.md L2).
- **Establishes:**
  - `status` leaves `Drawing`. It is absorbing from here:
    - L299 needs `Active` or `Drawing` (L279, L289), otherwise it reverts at L293.
    - L252 needs `Active` (L241).
    - L428 needs `AwaitingPrize` (L422).
    - L205 is one-shot (L177/L179).
  - Any further callback is ignored at L511.
  - `enableRefunds` reverts at L293.
  - `buyEntries` and `requestDraw` revert at L215 and L241.
- **Depended on by:**
  - `_settleWinningTicket` L535-L536 (gate) and L543-L549, which splits the pot:
    - `NftWon`: sponsor gets gross minus fee.
    - `CashWon`: winner gets 80%, sponsor gets the remainder after fee.
  - `redeemWinningTicket` L311-L312 (gate) and L329-L343 (NFT or cash branch).
  - `releaseSponsorPrize` L396-L398, which allows only `CashWon` or `Refunding`.
  - This one value decides where the prize NFT goes: to the winning ticket owner (`NftWon`, L329-L337) or to
    `sponsorRecipient` (`CashWon`, L397-L405). The shared `prizeClaimed` flag (L330-L331, L400-L403) records
    which of the two deliveries happened.

```solidity
// L523
emit RaffleResolved(requestId, resolvedEntry, status);
```
- **What:** Logs the accepted request ID, the entry, and the stored status just written.
- **Depended on by:** off-chain indexers. Frontends are advisory (DESIGN.md L2).

**Cross-Function Dependencies:**

- **Callee `Raffle.callbackDeadline` (internal, L463-L465):** read in full.
  - Path 1: `drawRequestedAt != 0` returns `uint256(drawRequestedAt) + 2 days`. The uint64 is widened, so the add
    cannot overflow.
  - Path 2: `drawRequestedAt == 0` leaves `deadline` at its default, 0. At L512, `block.timestamp >= 0` is then
    true, so the ignore path is forced.
  - Both paths are view-only, and the call is an internal jump, not a `CALL`.
  - What this function depends on it for: the exclusive upper bound of the accept window, the same bound that
    `enableRefunds` uses as its inclusive lower bound (L290-L291).
- **Inherited dispatcher `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` (external-source-available,
  ConsumerBase L101-L107):** read in full; its block appears above. It establishes caller identity (L103) and
  nothing else. It is the only path into this function (L106).
  - ConsumerBase's constructor makes an external `link()` call (L45) at implementation deployment. This affects
    deployability only, not this function.
- **Upstream invoker: Chainlink VRF v2.5 wrapper and coordinator (external-black-box).** It is not called here; it
  is the `msg.sender`. The repo vendors only `IVRFV2PlusWrapper.sol`, `VRFV2PlusWrapperConsumerBase.sol`,
  `VRFV2PlusClient.sol` and `LinkTokenInterface.sol` under `node_modules/@chainlink`.
  - What this function relies on it for:
    - P6, request-ID consistency with L259;
    - routing each callback only to the consumer that requested it;
    - at-most-once delivery;
    - P7, word count;
    - P8, unpredictability;
    - P9, gas forwarding.
  - Outcomes not excluded:
    1. No callback at all.
    2. A callback after `callbackDeadline()`.
    3. A callback with a different ID.
    4. A callback with a different array length.
    5. A synchronous callback during L257.
    6. A matching callback inside L262-L272.
  - Outcomes 1-5 land on the ignore path or never arrive. In each case `Drawing` ends only through
    `enableRefunds` at `callbackDeadline()` (L289-L291).
  - Outcome 6 resolves the raffle inside `requestDraw`.
  - A hostile word value cannot be distinguished from a fair one. L518 accepts any `uint256`.
- **Callers:**
  - `rawFulfillRandomWords` (ConsumerBase L106) is the only call site.
  - The immutable wrapper is the only `msg.sender` that clears ConsumerBase L103.
  - The selection summary assumed "wrapper authentication". It is established at L103 for address equality. The
    identity of that address rests on deployer trust (P1).
- **Shared state:**
  - `status` (L124): written at L165, L205, L252, L299, L428 and L521.
  - `_requestInFlight` (L142): written by `requestDraw` at L254 and L260.
  - `vrfRequestId` (L109): written once, by `requestDraw` at L259.
  - `drawRequestedAt` (L112): written by `requestDraw` at L253. Read through `callbackDeadline` (L464) here and in
    `enableRefunds` (L290), and in the `requestDraw` event (L272).
  - `totalEntries` (L85): written only by `buyEntries` (L230). Read by `requestDraw` L243, `enableRefunds` L280
    and `grossSales` L474.
  - `reserveEntries` (L79): written only by `initialize` (L203).
  - `winningEntry` (L118): written only here (L519). Read only by `_requireWinningTicket` (L581).
  - `resolvedAt` (L115): written only here (L520). No reader inside the contract.
- **Invariant couplings:**
  1. **Range partition with `buyEntries`.**
     - `buyEntries` assigns each new ticket `[totalEntries+1, totalEntries+entryCount]` with `entryCount >= 1`
       (L218, L226-L232). Ranges are therefore non-empty, contiguous and disjoint, and together cover
       `[1,totalEntries]`.
     - This function produces `winningEntry ∈ [1,totalEntries]` over the frozen `totalEntries` (L518).
     - Together, exactly one minted ticket ID contains `winningEntry`, and `_requireWinningTicket` (L579-L585)
       accepts only that ID.
     - Ranges persist after burns (L138). No burns can happen while `Drawing`: `refundTickets` needs `Refunding`
       (L350) and `redeemWinningTicket` needs a result state (L312).
  2. **Time partition with `enableRefunds`.**
     - The accept predicate is `block.timestamp < callbackDeadline()` (L512). The Drawing-refund predicate is
       `block.timestamp >= callbackDeadline()` (L291).
     - Both use the same block timestamp and `drawRequestedAt`, so at most one is open in any block.
     - Ordering inside a block cannot make both succeed. If resolution lands first, `enableRefunds` reverts at
       L293. If the deadline has passed, resolution is ignored at L511-L512.
  3. **One request, one resolution.** At most one `requestDraw` succeeds (L241, L252, L422/L428, L177-L179), so
     `vrfRequestId` is written once (L259). At most one callback can match, and L521 runs at most once.
  4. **The pot is untouched.**
     - This function does not write `unsettledPot`. While `Active` or `Drawing`, its only writer is L233
       (`+= entryCount * ENTRY_PRICE`).
     - The other writers, L297 and L553, run only on the way to `Refunding` or after resolution.
     - `_settleWinningTicket` later reads it at L539 and splits it according to the `status` chosen at L521.
  5. **The outcome routes the assets.** L521 alone decides between the NFT going to the winner (L329-L337) and the
     NFT returning to the sponsor (L397-L405), and between the 95/5 and 80/15/5 splits (L543-L549).

**Open Questions:**
- unclear; need to inspect the deployed Chainlink `VRFV2PlusWrapper` and coordinator source, which is not vendored.
  `node_modules/@chainlink` holds only the four interface, base and library files listed above. Five properties
  need confirming:
  - the ID returned by `requestRandomWordsInNative` (stored at L259) equals the ID later passed to
    `rawFulfillRandomWords`;
  - IDs are non-zero and unique across consumers;
  - callbacks are routed only to the requesting consumer;
  - delivery happens at most once;
  - the delivered array length equals the requested `numWords` (1).
- unclear; need to inspect the wrapper and coordinator for two timing questions:
  - Can a callback arrive synchronously inside `requestRandomWordsInNative` (L257), or between L260 and L272 of
    the same `requestDraw`?
  - Is a request whose callback this function ignored ever re-delivered? If not, an ignored live callback leaves
    the raffle in `Drawing` until `callbackDeadline()` and then `Refunding`.
- unclear; need to inspect the wrapper's callback gas forwarding (exact-gas or not) and how it handles a consumer
  revert or out-of-gas. This would confirm that the 300_000 limit (Constants L39) is the gas this body receives.
- unclear; need to inspect whether the wrapper's owner can disable the wrapper or change its coordinator after a
  request is accepted. That decides whether a `Drawing` raffle can be forced onto the refund path from outside the
  system.
- unclear; need to inspect the target chain's block-timestamp rules. The block producer's timestamp decides which
  side of the L512/L291 boundary a fulfillment lands on.

---
