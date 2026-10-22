## `enableRefunds()` in target/packages/contracts/src/Raffle.sol (L276-L301)

**Purpose:** Transitions an eligible `Active` or `Drawing` raffle into the `Refunding` state after the applicable caller or time condition, reclassifies the entire unsettled sales pot as aggregate refund liability, and announces the initial liability through `RefundsEnabled` (`target/packages/contracts/src/Raffle.sol:L276-L301`). `IRaffle` defines `Refunding` as the state in which full ticket refunds and sponsor prize recovery are available, and describes the sponsor-only early close and permissionless deadline paths (`target/packages/contracts/src/interfaces/IRaffle.sol:L20-L34`, `target/packages/contracts/src/interfaces/IRaffle.sol:L110-L113`, `target/packages/contracts/src/interfaces/IRaffle.sol:L322-L324`). `refundTickets` requires this state, while `releaseSponsorPrize` accepts it as a prize-return state (`target/packages/contracts/src/Raffle.sol:L349-L370`, `target/packages/contracts/src/Raffle.sol:L395-L405`).

---

**Inputs & Assumptions:**

- There are no explicit parameters or return values; the untrusted inputs are `msg.sender` and the transaction's `block.timestamp` (`target/packages/contracts/src/Raffle.sol:L276-L301`).
- Implicit storage inputs are `status`, `totalEntries`, `sponsor`, `endTime`, `drawRequestedAt`, and `unsettledPot`, declared at `target/packages/contracts/src/Raffle.sol:L61-L94` and `target/packages/contracts/src/Raffle.sol:L109-L124`.
- Entry requires `status` to be either `Active` or `Drawing`; every other status reverts before the liability writes (`target/packages/contracts/src/Raffle.sol:L279-L294`). The locked implementation itself starts in `Refunding`, while an initialized clone starts in `AwaitingPrize` and becomes `Active` only after the configured prize callback (`target/packages/contracts/src/Raffle.sol:L155-L166`, `target/packages/contracts/src/Raffle.sol:L176-L205`, `target/packages/contracts/src/Raffle.sol:L416-L430`).
- In `Active` with zero entries, `sponsor` may close immediately; every other caller must wait until `block.timestamp >= endTime` (`target/packages/contracts/src/Raffle.sol:L279-L285`). The factory supplies `sponsor = createRaffle`'s caller, and both interfaces describe that address as the pre-end empty-raffle authority (`target/packages/contracts/src/RaffleFactory.sol:L97-L120`, `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L53`, `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30-L34`).
- In `Active` with at least one entry, there is no sponsor exception: any caller must wait until `endTime + 2 days`, returned by `drawRequestDeadline()` (`target/packages/contracts/src/Raffle.sol:L285-L288`, `target/packages/contracts/src/Raffle.sol:L457-L460`, `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- In `Drawing`, any caller must wait until `drawRequestedAt + 2 days`, returned by `callbackDeadline()` (`target/packages/contracts/src/Raffle.sol:L289-L291`, `target/packages/contracts/src/Raffle.sol:L462-L465`, `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). `requestDraw` writes `status = Drawing` and `drawRequestedAt` before invoking the wrapper; a reverting request cannot persist those writes, while a completed request leaves both values recorded (`target/packages/contracts/src/Raffle.sol:L240-L260`).
- The callback deadline represents the full request timestamp only if the explicit `uint64(block.timestamp)` conversion in `requestDraw` preserves the timestamp (`target/packages/contracts/src/Raffle.sol:L252-L254`). No explicit bound at request time establishes this for all possible `uint256` block timestamps; established by: nothing found.
- On every source-reachable `Active` or `Drawing` entry, the pre-call `remainingRefundLiability` is zero. Its only positive assignment is paired with `status = Refunding` in this function, and its only decrement is gated by `Refunding`; no source transition returns from `Refunding` to `Active` or `Drawing` (`target/packages/contracts/src/Raffle.sol:L296-L299`, `target/packages/contracts/src/Raffle.sol:L349-L370`, `target/packages/contracts/src/Raffle.sol:L416-L430`, `target/packages/contracts/src/Raffle.sol:L509-L523`).
- The tracked `unsettledPot` corresponds to sold-entry face value: each successful purchase increases `totalEntries` by `entryCount` and `unsettledPot` by `entryCount * ENTRY_PRICE`, while the other zeroing path is settlement, which requires an already resolved `NftWon` or `CashWon` status (`target/packages/contracts/src/Raffle.sol:L215-L233`, `target/packages/contracts/src/Raffle.sol:L533-L555`). Consequently, the successful empty-raffle path records zero refund liability, while the sold paths record the tracked gross sales amount (`target/packages/contracts/src/Raffle.sol:L223-L233`, `target/packages/contracts/src/Raffle.sol:L473-L475`).
- Paying the resulting liability assumes `unsettledPot` is backed by an equal spendable quote-token balance. `SafeERC20.safeTransferFrom` establishes call/return success but does not measure the received balance delta (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46`, `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L212-L240`). The project instead establishes this through its canonical, standard, non-rebasing, fee-free USDC trust and deployment requirement (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`, `target/packages/contracts/src/RaffleFactory.sol:L58-L77`, `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7-L9`, `target/DESIGN.md:L2`).
- Interpreting `Refunding` as also enabling meaningful sponsor prize recovery assumes the configured ERC-721 continues to recognize the raffle's custody. The factory verifies ownership and `Active` status immediately after deposit, but this function performs no later custody query (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`, `target/packages/contracts/src/Raffle.sol:L276-L301`). Continued behavior of the untrusted prize contract after that point is established by: nothing found.

---

**Outputs & Effects:**

- Returns no value and makes no external call or asset transfer (`target/packages/contracts/src/Raffle.sol:L276-L301`). The in-body callees are source-available view helpers, and the inherited modifier operates only on the guard storage slot (`target/packages/contracts/src/Raffle.sol:L286-L290`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`).
- On success, `unsettledPot` becomes zero, `remainingRefundLiability` becomes the exact pre-call `unsettledPot`, and `status` becomes `Refunding` (`target/packages/contracts/src/Raffle.sol:L296-L299`).
- Given the source-reachable precondition that `remainingRefundLiability` was zero, the reclassification preserves `accountedQuoteBalance`, whose sum includes both the unsettled and refund buckets (`target/packages/contracts/src/Raffle.sol:L296-L299`, `target/packages/contracts/src/Raffle.sol:L467-L470`).
- Other accounting buckets, entry counts, ticket ranges, and prize custody are unchanged because they are not written in the function (`target/packages/contracts/src/Raffle.sol:L276-L301`).
- Emits `RefundsEnabled(msg.sender, liability)` only after all three state writes; the event records the finalizer and initial aggregate refund liability defined by the interface (`target/packages/contracts/src/Raffle.sol:L296-L300`, `target/packages/contracts/src/interfaces/IRaffle.sol:L110-L113`).
- Every rejection branch precedes the liability and lifecycle writes, so an ineligible invocation reaches none of `L296-L300` (`target/packages/contracts/src/Raffle.sol:L279-L300`).

---

**Block-by-Block:**

```solidity
// target/packages/contracts/src/Raffle.sol:L276-L277
function enableRefunds() external override nonReentrant {
    uint256 deadline;
```

- **What:** Exposes a parameterless external entry point, enters the shared reentrancy guard, and allocates a local deadline value (`target/packages/contracts/src/Raffle.sol:L276-L277`).
- **Why here:** The modifier executes its entry check before any lifecycle read or write and resets the guard after the body completes (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L94-L105`).
- **Assumes:** The namespaced guard slot is used consistently by all inherited `nonReentrant` entry points; `StorageSlot.getUint256Slot` binds the declared constant to that exact slot (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L35-L37`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L112-L117`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L90-L97`).
- **Establishes:** During body execution the guard slot equals `ENTERED`; any pre-state other than exact `ENTERED` passes the check, and successful exit writes `NOT_ENTERED` (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L50-L51`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L105`).
- **Depended on by:** This invocation and every other `nonReentrant` raffle entry point share the same guard slot, including `buyEntries` and `requestDraw`, which contain external dependency calls (`target/packages/contracts/src/Raffle.sol:L209-L224`, `target/packages/contracts/src/Raffle.sol:L239-L260`).

```solidity
// target/packages/contracts/src/Raffle.sol:L279-L285
if (status == Status.Active) {
    if (totalEntries == 0) {
        deadline = endTime;
        if (msg.sender != sponsor && block.timestamp < deadline) {
            revert RefundsNotAvailable(deadline, block.timestamp);
        }
```

- **What:** Selects the empty active-raffle path and permits either the stored sponsor at any time or any caller at or after the exclusive sale end (`target/packages/contracts/src/Raffle.sol:L279-L285`).
- **Why here:** Checking `totalEntries` before applying the sponsor exception prevents that exception from being used after any successful purchase has incremented the sold-entry count (`target/packages/contracts/src/Raffle.sol:L219-L233`, `target/packages/contracts/src/Raffle.sol:L279-L285`).
- **Assumes:** `totalEntries == 0` faithfully means that no protocol-accounted entry purchase completed; `buyEntries` is its sole writer and rejects zero-count purchases (`target/packages/contracts/src/Raffle.sol:L85-L88`, `target/packages/contracts/src/Raffle.sol:L215-L231`).
- **Establishes:** Before `endTime`, only `msg.sender == sponsor` proceeds; at `endTime` and later, every caller proceeds (`target/packages/contracts/src/Raffle.sol:L281-L284`).
- **Depended on by:** The later accounting block relies on this branch to authorize an early empty-raffle transition without granting the sponsor an early sold-raffle transition (`target/packages/contracts/src/Raffle.sol:L285-L300`).

```solidity
// target/packages/contracts/src/Raffle.sol:L285-L288
    } else {
        deadline = drawRequestDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    }
```

- **What:** For a sold active raffle, derives the exclusive draw-request deadline and permits refunds only at or after it (`target/packages/contracts/src/Raffle.sol:L285-L288`).
- **Why here:** The branch is reached only after `totalEntries != 0`, matching `requestDraw`'s requirement that at least one entry exist (`target/packages/contracts/src/Raffle.sol:L243-L247`, `target/packages/contracts/src/Raffle.sol:L279-L288`).
- **Assumes:** `drawRequestDeadline()` returns the intended `endTime + 2 days`; its complete body performs exactly that uint256 addition using the fixed timeout (`target/packages/contracts/src/Raffle.sol:L457-L460`, `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- **Establishes:** The draw-request and refund windows meet at one exclusive boundary: `requestDraw` rejects `block.timestamp >= deadline`, while this branch rejects only `block.timestamp < deadline` (`target/packages/contracts/src/Raffle.sol:L244-L247`, `target/packages/contracts/src/Raffle.sol:L285-L288`).
- **Depended on by:** The accounting transition at `L296-L300` relies on the draw-initiation window having ended for a sold raffle (`target/packages/contracts/src/Raffle.sol:L296-L300`).

```solidity
// target/packages/contracts/src/Raffle.sol:L289-L294
} else if (status == Status.Drawing) {
    deadline = callbackDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
} else {
    revert InvalidStatus(status);
}
```

- **What:** Allows a drawing raffle to enter refunds at or after the callback deadline and rejects every other lifecycle state (`target/packages/contracts/src/Raffle.sol:L289-L294`).
- **Why here:** The `Drawing` check follows the complete `Active` handling, while the final `else` prevents refund accounting from overwriting resolved, already-refunding, awaiting-prize, or implementation-lock state (`target/packages/contracts/src/interfaces/IRaffle.sol:L20-L34`, `target/packages/contracts/src/Raffle.sol:L279-L294`).
- **Assumes:** `drawRequestedAt` is the accepted request time and is nonzero in the practical timestamp domain; `requestDraw` assigns it alongside `status = Drawing`, while `callbackDeadline()` returns zero only when that stored value is zero (`target/packages/contracts/src/Raffle.sol:L252-L260`, `target/packages/contracts/src/Raffle.sol:L462-L465`). Exact preservation by the uint64 cast is the separately recorded unenforced timestamp-range assumption (`target/packages/contracts/src/Raffle.sol:L253`).
- **Establishes:** Callback acceptance and refund activation meet at the same exclusive boundary: `fulfillRandomWords` ignores callbacks at `block.timestamp >= callbackDeadline()`, while this branch permits refunds at that point (`target/packages/contracts/src/Raffle.sol:L509-L516`, `target/packages/contracts/src/Raffle.sol:L289-L291`).
- **Depended on by:** A successful transition causes any later authenticated callback to take the `status != Drawing` ignored path instead of resolving the raffle (`target/packages/contracts/src/Raffle.sol:L299`, `target/packages/contracts/src/Raffle.sol:L509-L516`). The inherited external callback entry point permits only the immutable wrapper to reach that handler (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).

```solidity
// target/packages/contracts/src/Raffle.sol:L296-L300
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
emit RefundsEnabled(msg.sender, liability);
```

- **What:** Snapshots the complete unallocated pot, moves that accounting amount into the refund bucket, publishes the new lifecycle state, and emits the transition event (`target/packages/contracts/src/Raffle.sol:L296-L300`).
- **Why here:** All authorization, status, and deadline checks finish before accounting changes; the snapshot precedes zeroing, and the event follows the complete state transition (`target/packages/contracts/src/Raffle.sol:L279-L300`).
- **Assumes:** The tracked pot is backed by the trusted canonical quote token and the preexisting refund bucket is zero on eligible states, as established or qualified above (`target/packages/contracts/src/Raffle.sol:L223-L233`, `target/packages/contracts/src/Raffle.sol:L296-L299`, `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`).
- **Establishes:** `unsettledPot == 0`, `remainingRefundLiability == pre(unsettledPot)`, and `status == Refunding`; the event's amount equals the new aggregate liability (`target/packages/contracts/src/Raffle.sol:L296-L300`).
- **Depended on by:** `refundTickets` burns owner-selected tickets, subtracts their face value from `remainingRefundLiability`, and transfers the corresponding quote amount; `releaseSponsorPrize` uses `Refunding` as an allowed prize-return state (`target/packages/contracts/src/Raffle.sol:L349-L370`, `target/packages/contracts/src/Raffle.sol:L395-L405`).

---

**Cross-Function Dependencies:**

- **Callee `drawRequestDeadline()` (internal, source available):** Its only path returns `uint256(endTime) + DRAW_REQUEST_TIMEOUT`; the timeout is exactly two days (`target/packages/contracts/src/Raffle.sol:L457-L460`, `target/packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`). `enableRefunds` depends on that value matching the deadline used by `requestDraw` (`target/packages/contracts/src/Raffle.sol:L244-L247`, `target/packages/contracts/src/Raffle.sol:L285-L288`).
- **Callee `callbackDeadline()` (internal, source available):** It returns zero when `drawRequestedAt == 0` and otherwise returns the stored request time plus the fixed two-day timeout (`target/packages/contracts/src/Raffle.sol:L462-L465`, `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`). `enableRefunds` depends on the `Drawing` state transition having populated `drawRequestedAt` (`target/packages/contracts/src/Raffle.sol:L252-L260`, `target/packages/contracts/src/Raffle.sol:L289-L291`).
- **Callee chain from `nonReentrant` (internal, source available):** The modifier calls `_nonReentrantBefore`, executes the body, and calls `_nonReentrantAfter`; the entry chain reads the namespaced slot, rejects exact `ENTERED`, then writes `ENTERED`, and the successful exit writes `NOT_ENTERED` (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L117`). `StorageSlot.getUint256Slot` uses memory-safe assembly only to bind the storage reference to that slot and has no external path (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L90-L97`).
- **External calls:** None occur in `enableRefunds`, its deadline helpers, or its modifier chain (`target/packages/contracts/src/Raffle.sol:L276-L301`, `target/packages/contracts/src/Raffle.sol:L457-L465`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L117`). Therefore this execution introduces no external revert, hostile return, external state change, or call-driven re-entry point.
- **Earlier quote-token dependency:** `buyEntries` calls the configured token before increasing the pot (`target/packages/contracts/src/Raffle.sol:L223-L233`). A revert or rejected return prevents that purchase from completing through `SafeERC20`, while an accepted return does not itself prove a fee-free balance delta (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46`, `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L212-L240`). The canonical quote-token trust model supplies the stronger transfer semantics consumed by refund accounting (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`, `target/DESIGN.md:L2`).
- **Callers:** Any EOA or contract may invoke the external interface entry point; authorization is path-dependent rather than globally permissioned (`target/packages/contracts/src/interfaces/IRaffle.sol:L322-L324`, `target/packages/contracts/src/Raffle.sol:L279-L294`). The exact stored sponsor alone has the pre-end empty-raffle path (`target/packages/contracts/src/Raffle.sol:L280-L284`).
- **Shared state:** `status` is read and changed here and is also changed by initialization, prize deposit, draw initiation, and accepted fulfillment (`target/packages/contracts/src/Raffle.sol:L176-L205`, `target/packages/contracts/src/Raffle.sol:L252-L260`, `target/packages/contracts/src/Raffle.sol:L289-L299`, `target/packages/contracts/src/Raffle.sol:L416-L430`, `target/packages/contracts/src/Raffle.sol:L509-L523`). `totalEntries` and `unsettledPot` are coupled by purchases (`target/packages/contracts/src/Raffle.sol:L223-L233`). `drawRequestedAt` is written by `requestDraw` and read through `callbackDeadline` (`target/packages/contracts/src/Raffle.sol:L252-L260`, `target/packages/contracts/src/Raffle.sol:L462-L465`). `remainingRefundLiability` is initialized here and consumed by `refundTickets` (`target/packages/contracts/src/Raffle.sol:L296-L299`, `target/packages/contracts/src/Raffle.sol:L349-L370`).
- **Invariant coupling:** At the sale end, `buyEntries` rejects timestamps at or after `endTime`, while the empty-raffle branch becomes permissionless at that same boundary (`target/packages/contracts/src/Raffle.sol:L215-L216`, `target/packages/contracts/src/Raffle.sol:L280-L284`). At the sold-raffle request deadline and drawing callback deadline, the preceding operation rejects the boundary timestamp and `enableRefunds` accepts it (`target/packages/contracts/src/Raffle.sol:L244-L247`, `target/packages/contracts/src/Raffle.sol:L285-L291`, `target/packages/contracts/src/Raffle.sol:L509-L516`).
- **Invariant coupling:** Reclassifying the two accounting buckets preserves their contribution to `accountedQuoteBalance`, and subsequent refunds reduce `remainingRefundLiability` by the amount transferred (`target/packages/contracts/src/Raffle.sol:L296-L299`, `target/packages/contracts/src/Raffle.sol:L367-L370`, `target/packages/contracts/src/Raffle.sol:L467-L470`).

---

**Open Questions:**

- None within the permitted source scope; the quote-token backing, uint64 timestamp range, and continued prize behavior are recorded above as explicit trust or unenforced assumptions rather than silently resolved.
