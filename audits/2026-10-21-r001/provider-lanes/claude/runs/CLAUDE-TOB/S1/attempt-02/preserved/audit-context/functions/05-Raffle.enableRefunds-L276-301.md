## `enableRefunds` in packages/contracts/src/Raffle.sol (L276-L301)

```solidity
// L276-L301
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

**Purpose:** This is the only way a clone enters `Status.Refunding`. L299 is the only `status = Status.Refunding`
write that runs in a clone. The other one, L165, runs only in the implementation's constructor. The function is
the liveness backstop for every non-terminal state after escrow:

- an empty `Active` raffle: the sponsor can call at any time, anyone else from `endTime`;
- a sold `Active` raffle that nobody drew: anyone from `endTime + 2 days`;
- a `Drawing` raffle whose VRF callback did not land in its window: anyone from `drawRequestedAt + 2 days`.

It moves the gross sale pot into the refund liability that `refundTickets` (L349-L372) draws down. It also opens
the `Refunding` arm of `releaseSponsorPrize` (L397). Without it, a raffle that misses its draw or callback window
has no way out: tickets cannot be refunded and the prize cannot be returned.

---

**Inputs & Assumptions:**

- No parameters.
- Implicit: `msg.sender`. It is compared with `sponsor` at L282 and emitted at L300. Trust: untrusted. Being equal
  to `sponsor` unlocks the untimed branch.
- Implicit: `block.timestamp`, read at L282, L283, L287 and L291. The configured networks are Ethereum L1 mainnet
  and Sepolia (`hardhat.config.ts` L44-L57, `chainType: "l1"`).
- Implicit storage reads:
  - `status` (L279, L289, L293)
  - `totalEntries` (L280)
  - `endTime` (L281, and through `drawRequestDeadline` at L459)
  - `sponsor` (L282)
  - `drawRequestedAt` (through `callbackDeadline` at L464)
  - `unsettledPot` (L296)
- Implicit: the reentrancy guard slot `0x9b779b17…5f00` (`ReentrancyGuard.sol` L36-L37), read and written by the
  modifier.

Preconditions, and what establishes each:

- **Status is `Active` or `Drawing`.** Checked in this function (L279, L289, L293).
- **`endTime` is nonzero, at most 30 days after creation, and never changes.**
  - Nonzero and within 30 days: `RaffleFactory.createRaffle` L100-L104.
  - Never changes: written only at Raffle L204, inside `initialize`, which can run once (L177-L179).
- **`sponsor` is nonzero, never changes, and is the `createRaffle` caller.**
  - Set by `initialize` (L182, L197) from `RaffleFactory` L112 (`sponsor: msg.sender`).
  - Nothing in source establishes who controls that address. The sponsor is a semi-trusted actor, and its account
    type (EOA, smart wallet, relay contract) is unconstrained.
- **If `totalEntries == 0`, then `unsettledPot == 0` and `ticketCount == 0`.** `buyEntries` establishes this.
  - It requires `entryCount > 0` (L218).
  - It raises `totalEntries` (L230), `ticketCount` (L231) and `unsettledPot` (L233) in the same call.
  - L233 is the only increment of `unsettledPot`.
- **`unsettledPot == totalEntries * ENTRY_PRICE` while `Active` or `Drawing`.** `buyEntries` establishes this at
  L223 and L230-L233. The only other writer, `_settleWinningTicket` (L553), can run only in `NftWon`/`CashWon`
  (L536).
- **If status is `Drawing`, then `drawRequestedAt != 0`.**
  - `requestDraw` L252-L253 writes `status = Drawing` and `drawRequestedAt = uint64(block.timestamp)` in the same
    call. A later revert in `requestDraw` (L258, L269) undoes both.
  - The result is nonzero only because `block.timestamp` is in (0, 2^64) on the configured chains.
  - Nothing in `enableRefunds` checks it.
- **`remainingRefundLiability == 0` on entry.** L298 overwrites the value; it does not add to it. This holds for
  two reasons. First, this function can succeed only once: L293 rejects `Refunding`, and nothing writes `status`
  out of `Refunding`. Second, the only other writer, L368, is gated to `Refunding` by L350.
- **The clone holds at least `unsettledPot` USDC.**
  - `buyEntries` L224 pulls exactly `grossAmount` before crediting it at L233.
  - This relies on the trusted quote token being fee-free and non-rebasing (IRaffle L13-L14, Raffle L560-L561).
  - In `Active`/`Drawing` there is no USDC outflow. Every `_transferQuote` call site is gated:
    `redeemWinningTicket` (L312), `refundTickets` (L350), `releaseSponsorProceeds` (L377, nonzero only after L554),
    and `releaseProtocolFees` (L387, nonzero only after L555).
  - Nothing on chain compares the actual balance to the accounted balance.

---

**Outputs & Effects:**

- Returns nothing.
- Storage writes, on the success path only:
  - `unsettledPot = 0` (L297)
  - `remainingRefundLiability = liability`, the previous `unsettledPot` (L298)
  - `status = Status.Refunding` (L299)
- Guard slot: set to ENTERED (2) at `ReentrancyGuard.sol` L99, then restored to NOT_ENTERED (1) at L105.
- Event: `RefundsEnabled(address indexed finalizer = msg.sender, uint256 remainingRefundLiability = liability)`
  at L300; declared at IRaffle L113. The liability is 0 on the empty-raffle branch.
- Reverts:
  - `ReentrancyGuardReentrantCall` (`ReentrancyGuard.sol` L90) when the guard slot is 2.
  - `RefundsNotAvailable(deadline, block.timestamp)` at L283, L287 and L291.
  - `InvalidStatus(status)` at L293.
- No external calls. No token movement, no ticket mint, burn or transfer, and no change to prize custody.
- Left untouched: `vrfRequestId` (L109), `drawRequestedAt` (L112), `_requestInFlight` (L142), `winningEntry`,
  `totalEntries`, `ticketCount` and `_ticketRanges`.
- Postconditions:
  - `status == Refunding`.
  - `unsettledPot == 0`.
  - `remainingRefundLiability == totalEntries * ENTRY_PRICE`.
  - `accountedQuoteBalance()` (L469) has the same value as before the call.

**Window map.** E = `endTime`, R = `drawRequestedAt`, t = `block.timestamp`, and `2d` = 172,800 s. Both timeouts
equal 2 days (RaffleConstants L33, L36).

| State on entry | Caller | `enableRefunds` passes when | Competing operation and its open window | Boundary shared? |
| --- | --- | --- | --- | --- |
| `Active`, `totalEntries == 0` | `sponsor` | always (L282 short-circuits) | `buyEntries`: `Active` (L215) and t < E (L216) | No time boundary. Exclusion is by state (see L279-L284). |
| `Active`, `totalEntries == 0` | anyone else | t ≥ E (L281-L283) | `buyEntries`: t < E (L216) | Yes, at E. `buyEntries` reverts and `enableRefunds` passes. |
| `Active`, `totalEntries > 0` | anyone | t ≥ E + 2d (L286-L287, L459) | `requestDraw`: E ≤ t < E + 2d (L242, L244-L245) | Yes, at E + 2d. Both read `drawRequestDeadline()`. |
| `Drawing` | anyone | t ≥ R + 2d (L290-L291, L464) | callback accepted when t < R + 2d (L512) | Yes, at R + 2d. Both read `callbackDeadline()`. |
| `AwaitingPrize`, `NftWon`, `CashWon`, `Refunding` | anyone | never (L293) | none | n/a |

Each timed check is the exact complement of the competing window's check. Both sides compare the same
`block.timestamp` with the same deadline function, so a block lands on exactly one side of each boundary, and
same-block ordering cannot change the outcome at that instant. For `Drawing`, R lies in [E, E + 2d) because of
L242, L245 and L253. The `Drawing` refund deadline therefore lies in [E + 2d, E + 4d).

---

**Block-by-Block:**

```solidity
// L276
function enableRefunds() external override nonReentrant {
```
- **What:** An external entry point with no parameters, wrapped in OZ `nonReentrant`.
- **Why here:** The guard runs before any state is read. The body makes no external call, so the guard never
  protects `enableRefunds` from re-entry into itself. Its only effect is to reject `enableRefunds` while another
  guarded function on the same clone is in the middle of an external call.
- **Assumes:** The guard slot is not 2 (ENTERED) on entry. A fresh clone's slot is 0, and
  `_reentrancyGuardEntered` (`ReentrancyGuard.sol` L112-L114) compares only against 2, so slot 0 counts as
  not entered.
- **Establishes:** `enableRefunds` cannot run inside these external-call windows:
  - `buyEntries`: L224 (quote pull) and L235 (`_safeMint` receiver callback);
  - `requestDraw`: L257 (wrapper request) and L267 (full-gas excess refund);
  - the other guarded functions' transfers: L334-L335, L342, L369, L380, L390, L404-L405.
- **The time checks alone would also reject most of these windows:**
  - Inside the `_safeMint` callback (L235), `totalEntries` is already above zero (L230) and t < E, so the call
    takes the L285-L288 branch and reverts.
  - Inside both `requestDraw` calls (L257, L267), status is already `Drawing` and R equals the current time
    (L252-L253). L291 then sees a deadline of t + 2d and reverts.
  - The exception is a sponsor-originated call during the first purchase's quote pull (L224). There
    `totalEntries` is still 0, so L282 would pass, and the guard is the only barrier. A non-sponsor call there
    reverts at L283 because t < E. That window is reachable only if the trusted quote token calls back into the
    clone.
- **Unguarded call windows:**
  - In `RaffleFactory.createRaffle`, the prize contract's `safeTransferFrom` (`RaffleFactory.sol` L128) runs
    arbitrary code before and after it invokes the clone's unguarded `onERC721Received` (L416-L431). After L428
    sets `Active`, `enableRefunds` is reachable from that code; see Callers.
  - A ticket `safeTransferFrom` (`ERC721.sol` L133-L136) calls the recipient's `onERC721Received` at L135 without
    a guard. `enableRefunds` is reachable from there. Ticket transfers do not touch any state it reads.
  - `rawFulfillRandomWords` (consumer base L101-L107) is unguarded. `fulfillRandomWords` (L509-L524) makes no
    external call, so it opens no window.
- **Depended on by:** none of the body's checks. The guard is an additional layer on top of the state ordering
  above.

```solidity
// L277
uint256 deadline;
```
- **What:** A local that carries the applicable deadline into the revert data only. On the sponsor short-circuit
  it is assigned (L281) and never used. It is not emitted.

```solidity
// L279-L284
if (status == Status.Active) {
    if (totalEntries == 0) {
        deadline = endTime;
        if (msg.sender != sponsor && block.timestamp < deadline) {
            revert RefundsNotAvailable(deadline, block.timestamp);
        }
```
- **What:** In an `Active` raffle with no sold entries, the sponsor passes unconditionally. Anyone else passes
  once t ≥ `endTime`.
- **Why here:** The zero-entries test is evaluated against storage when the transaction executes, not when it is
  submitted.
- **Assumes:**
  - `totalEntries == 0` implies the liability moved at L296 is 0 and no tickets exist. `buyEntries` establishes
    this: L218 requires `entryCount > 0`, L223/L230/L233 update the counters together, and L228/L231 assign
    ticket IDs.
  - `sponsor` is the authority for the untimed path. It is the `createRaffle` caller (`RaffleFactory.sol` L112),
    set once (L197), and it is not `sponsorRecipient`.
  - Authentication is plain `msg.sender` equality (L282). `tx.origin` is not used. Nothing in source restricts
    what kind of account `sponsor` is.
- **Establishes:** For non-sponsor callers, t ≥ E. That is the exact complement of `buyEntries` (L216 reverts when
  `block.timestamp >= endTime`). At t == E, `buyEntries` reverts and this branch passes.
- **How the sponsor path is excluded from `buyEntries`:** The sponsor path has no time bound, so in time it
  overlaps the whole `buyEntries` window. The two are kept apart by state instead:
  1. After this function succeeds, status is `Refunding` and `buyEntries` reverts at L215.
  2. After any successful `buyEntries`, `totalEntries > 0` (L230). L230 is its only writer, and every write raises
     it because L218 forces `entryCount > 0`. Every later call to this function therefore takes the L285-L288
     branch, which requires t ≥ E + 2d.
  3. Within one block, whichever transaction executes first decides the outcome. Either order leaves consistent
     state: either `Refunding` with no tickets and zero liability, or `Active` and sold.
- **Also:** For an empty raffle, `requestDraw` is permanently unavailable (L243). `totalEntries` stops changing once
  t ≥ E (L216). So from E onward, this branch is the empty raffle's only way out.
- **Depended on by:** L296-L299, which move a liability of 0 here.

```solidity
// L285-L288
} else {
    deadline = drawRequestDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
}
```
- **What:** In a sold `Active` raffle, meaning no draw request has been accepted, anyone passes once
  t ≥ `endTime + 2 days`.
- **Why here:** `requestDraw` closes its window with the same function, `drawRequestDeadline()` (L244-L245).
- **Assumes:** `endTime` has not changed since `requestDraw` could have read it. It is written only at L204, and
  `initialize` can run once (L177).
- **Establishes:**
  - t ≥ `drawRequestDeadline()`, the exact complement of `requestDraw`'s L245
    (`block.timestamp >= requestDeadline` → revert). At t == E + 2d, `requestDraw` reverts and this branch passes.
  - Because t > E, `buyEntries` is closed (L216), so the pot read at L296 can no longer grow.
  - The branch treats the sponsor like anyone else; it never reads `msg.sender`.
  - Whether the reserve was met is not consulted. Sold raffles that were never drawn always go to `Refunding`.
- **Depended on by:** L296-L298, which move the final, frozen pot.

```solidity
// L289-L291
} else if (status == Status.Drawing) {
    deadline = callbackDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
```
- **What:** After an accepted draw request, anyone passes once t ≥ `drawRequestedAt + 2 days`.
- **Why here:** `fulfillRandomWords` ignores callbacks with the same function, `callbackDeadline()`, at L512
  (`block.timestamp >= callbackDeadline()` → ignore).
- **Assumes:** `drawRequestedAt != 0`. `callbackDeadline()` has two paths (L464). When `drawRequestedAt == 0`, the
  named return is never written and is 0, so `block.timestamp < 0` is false and this branch would pass at once.
  In that same state, L512 would ignore every callback.
  - Nothing in `enableRefunds` checks for this.
  - `requestDraw` L252-L253 establishes it, together with `block.timestamp` lying in (0, 2^64) on the configured
    chains. The `uint64(...)` cast at L253 truncates silently, and a truncated value of 0 needs a timestamp that
    is a multiple of 2^64.
  - L253 is the only writer of `drawRequestedAt`. L252 is the only write of `Status.Drawing`.
- **Establishes:**
  - t ≥ `callbackDeadline()`, the exact complement of callback acceptance at L512. At t == R + 2d, a callback is
    ignored (event `VrfCallbackIgnored`, L514) and this branch passes. Ordering within that block does not matter.
  - Below R + 2d, a valid callback moves status to `NftWon`/`CashWon` (L521), and this function then reverts at
    L293.
- **Not done:** The function does not cancel the outstanding VRF request, clear `vrfRequestId`, or return the
  native fee the requester paid at L257. A later callback is ignored because `status != Drawing` (L511).
- **Depended on by:** L296-L299.

```solidity
// L292-L294
} else {
    revert InvalidStatus(status);
}
```
- **What:** Rejects `AwaitingPrize`, `NftWon`, `CashWon` and `Refunding`.
- **Establishes:**
  - **Single execution:** `Refunding` is rejected, and no `status` writer moves a clone out of it. Each writer is
    gated on a different source state:
    - L165: constructor, implementation only;
    - L205: `initialize`, once per clone (L177);
    - L252: requires `Active` (L241);
    - L299: this function, requires `Active` or `Drawing`;
    - L428: requires `AwaitingPrize` (L422);
    - L521: requires `Drawing` (L511).

    So `enableRefunds` succeeds at most once per clone.
  - **Resolved raffles stay resolved:** `NftWon`/`CashWon` cannot be turned into refunds. In the other direction,
    `fulfillRandomWords` will not resolve a `Refunding` raffle (L511).
  - **Implementation is locked:** the implementation instance has status `Refunding` (L165), so it always reverts
    here.
  - **Clones created outside the factory are locked:** their zeroed status is `AwaitingPrize`, so they revert
    here.

```solidity
// L296-L299
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
```
- **What:** Moves the whole pot into the refund liability and enters terminal `Refunding`.
- **Why here:** These writes come after all gating. The function makes no external call, so no intermediate state
  can be observed.
- **Assumes:**
  - `unsettledPot == totalEntries * ENTRY_PRICE`, which equals the sum over minted tickets of
    `(lastEntry − firstEntry + 1) * ENTRY_PRICE`. `buyEntries` L226-L233 makes the ranges contiguous from 1 and
    disjoint, and they are kept after burn (L138).
  - `remainingRefundLiability == 0` beforehand, so the overwrite at L298 (rather than `+=`) loses nothing. This
    follows from single execution (L293) and from L368 being gated by L350.
  - `winnerProceeds`, `sponsorProceeds` and `protocolFees` are 0. They are written only in
    `_settleWinningTicket` (L548, L554, L555), which requires L536.
  - The USDC balance is at least `liability`. See the precondition above: L224 establishes it under the trusted
    token model, and nothing checks it.
- **Establishes:**
  - `accountedQuoteBalance()` (L469) is unchanged: (P, 0) becomes (0, P).
  - `remainingRefundLiability` equals the sum of every refund that `refundTickets` can ever subtract (L363,
    L367-L368).
    - Each ticket can be refunded once. It is burned at L364, and `ownerOf` reverts on burned IDs
      (`ERC721.sol` L61-L63, L426-L432).
    - So the checked subtraction at L368 stays non-negative, and reaches 0 once every ticket is refunded.
  - `status == Refunding`, which is the gate for:
    - `refundTickets` (L350), now open;
    - `releaseSponsorPrize` (L397), now open;
    - `buyEntries` (L215) and `requestDraw` (L241), now reverting;
    - `redeemWinningTicket` (L312) and `_settleWinningTicket` (L536), now reverting;
    - `fulfillRandomWords`, which now ignores callbacks (L511).
- **Depended on by:** `refundTickets` L368, and the `releaseSponsorPrize` gate at L397.

```solidity
// L300
emit RefundsEnabled(msg.sender, liability);
```
- **What:** A log only. The second field is named `remainingRefundLiability` in IRaffle L112-L113. It is 0 for
  empty raffles.

---

**Cross-Function Dependencies:**

- **Callee `nonReentrant` (OZ `ReentrancyGuard`, external-source-available, `ReentrancyGuard.sol` L69-L106; read in
  full).** Two paths:
  - Slot == 2: revert `ReentrancyGuardReentrantCall` (L88-L92).
  - Otherwise: write 2 (L99), run the body, write 1 (L105). A revert in the body undoes the L99 write.
  - A fresh clone's slot 0 takes the second path.
  - `enableRefunds` depends on it only to exclude the guarded external-call windows listed under L276.
- **Callee `drawRequestDeadline()` (internal, L458-L460; read in full).** One path:
  `uint256(endTime) + DRAW_REQUEST_TIMEOUT`.
  - `endTime` is widened from `uint64` to `uint256` before the checked addition, so it cannot overflow.
  - It has no zero guard. `endTime > 0` comes from `RaffleFactory` L100.
  - `requestDraw` L244 uses the same function, which is why the L245/L287 boundary is shared exactly.
- **Callee `callbackDeadline()` (internal, L463-L465; read in full).** Two paths:
  - `drawRequestedAt != 0`: returns `uint256(drawRequestedAt) + DRAW_CALLBACK_TIMEOUT`.
  - `drawRequestedAt == 0`: the named return is never written and is 0.
  - The `Drawing` branch depends on the first path. It is established only by `requestDraw` L252-L253 plus a
    nonzero chain timestamp.
  - `fulfillRandomWords` L512 and the `DrawRequested` event at L272 use the same function, which is why the
    L291/L512 boundary is shared exactly.
- **Constants:** `RaffleConstants.DRAW_REQUEST_TIMEOUT` and `DRAW_CALLBACK_TIMEOUT`, both `2 days` (L33, L36).
- **Callers:**
  - External only. There are no internal call sites; L276 is the only occurrence in `src/`.
  - The sponsor calls it for an early close of an empty raffle.
  - Permissionless keepers call it after the deadlines.
  - It is also reachable during `RaffleFactory.createRaffle`, after `onERC721Received` sets `Active` (Raffle L428)
    and while control is still inside the prize contract's `safeTransferFrom` (`RaffleFactory.sol` L128). The
    clone guard is not engaged there.
    - Any non-sponsor call reverts at L283, because `endTime > block.timestamp` (`RaffleFactory.sol` L100).
    - A sponsor call succeeds. `RaffleFactory.sol` L132 (`status() != Active` → revert) then reverts the whole
      creation.
    - So the factory, not this function, ensures every registered raffle starts `Active`.
  - It is reachable from a ticket recipient's `onERC721Received` during an unguarded ticket `safeTransferFrom`
    (`ERC721.sol` L135).
- **Shared state:**
  - `status`
    - Written: L165, L205, L252, L299, L428, L521.
    - Read: L215, L241, L311-L312, L350, L396-L397, L422, L511, L535-L536, and `RaffleFactory` L132.
  - `unsettledPot`
    - Written: L233, L297, L553.
    - Read: L296, L469, L539.
  - `remainingRefundLiability`
    - Written: L298, L368.
    - Read: L370, L469.
  - `totalEntries`
    - Written: L230.
    - Read: L219, L226-L227, L243, L280, L474, L518, L521.
  - `endTime`
    - Written: L204.
    - Read: L216, L242, L281, L459.
  - `drawRequestedAt`
    - Written: L253.
    - Read: L272 and L464.
  - `sponsor`
    - Written: L197.
    - Read: L282, L423.
  - Reentrancy guard slot: every guarded function of the clone.
- **Invariant couplings:**
  1. **The timeline is divided between operations.** In an `Active` sold raffle the phases are: buy [creation, E),
     request [E, E + 2d), refunds [E + 2d, ∞). In `Drawing`: callback [R, R + 2d), refunds [R + 2d, ∞). Each
     handoff uses one shared deadline function on both sides (L216/L282, L245/L287, L512/L291). The sponsor's
     empty-raffle path is the only part that overlaps another window in time, and it is separated by state.
  2. **Value is conserved.** `accountedQuoteBalance()` (L469) is unchanged by this function.
  3. **Refunds sum to the liability.** The sum of per-ticket refunds equals the liability set at L298. This rests
     on `buyEntries` producing contiguous, disjoint ranges (L226-L232) and on the 1:1 pairing of
     `ENTRY_PRICE` at L223 and L367.
  4. **Terminal states are final.** `Refunding`, `NftWon` and `CashWon` are absorbing. This function and
     `fulfillRandomWords` each reject the other's target state (L293, L511).
  5. **The prize has one destination.** Once `Refunding`, the only path that moves the prize is
     `releaseSponsorPrize` (L395-L407) to `sponsorRecipient`, because `redeemWinningTicket` rejects `Refunding`
     (L312).
  6. **Liveness needs a caller.** Every state after escrow and before a terminal state has a finite time after
     which any caller can trigger refunds: E, E + 2d, or below E + 4d. Nothing moves the raffle automatically.
     Until someone calls, `refundTickets` (L350) and `releaseSponsorPrize` (L397) stay unavailable.
- **Documentation alignment:**
  - DESIGN.md L2 says "Request window [sale end, end+2days); callback accepted strictly before request
    timestamp+2days. Refunds open at deadline." This matches L245/L287 and L512/L291.
  - IRaffle L322-L323 says refunds are enabled "after" the deadlines. The code admits callers at the deadline, as
    IRaffle L243 describes ("at which refunds become available").
  - IRaffle L410 and IRaffleFactory L33 call the sponsor the "pre-end empty-raffle refund authority". The code at
    L282 gives the sponsor the untimed path at any time while the raffle is empty. After E this coincides with the
    path open to anyone.

---

**Open Questions:**

- Unclear; need to inspect the deployed Chainlink VRFV2PlusWrapper and coordinator. The repo vendors only
  `IVRFV2PlusWrapper.sol` and `VRFV2PlusWrapperConsumerBase.sol`. Two things are unknown:
  - whether a request left outstanding when this function runs from `Drawing` can still be fulfilled later;
  - whether the native fee paid at L257 is ever returned.

  Raffle ignores any such callback (L511). No Raffle code path reimburses the requester.
- Unclear; need to inspect intended off-chain operations to know who is expected to call `enableRefunds` once a
  deadline passes. The repo has no keeper or operations material beyond DESIGN.md. No on-chain incentive or
  automatic transition exists, so `refundTickets` (L350) and `releaseSponsorPrize` (L397) stay unavailable until
  someone calls.
