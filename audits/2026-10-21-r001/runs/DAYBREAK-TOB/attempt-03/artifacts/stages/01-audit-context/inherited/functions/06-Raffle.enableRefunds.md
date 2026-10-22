## `Raffle.enableRefunds` in packages/contracts/src/Raffle.sol (L276-L301)

**Purpose:** This permissionless lifecycle finalizer moves an unresolved raffle into `Refunding` when the
deadline appropriate to its current state has arrived. It also gives the configured sponsor an immediate
empty-raffle cancellation path before the sale ends. On success it reallocates the entire unallocated sale
pot to the ticket-refund liability; it does not transfer either the quote token or the prize
(`packages/contracts/src/Raffle.sol:L276-L301`; `packages/contracts/src/interfaces/IRaffle.sol:L322-L324`).

---

**Inputs & Assumptions:**

- There are no explicit parameters. `msg.sender` is untrusted in general. Any address may finalize after an
  applicable deadline; equality with the stored `sponsor` grants the only pre-deadline path, and only while
  the raffle is `Active` with zero sold entries (`packages/contracts/src/Raffle.sol:L279-L291`).
- `block.timestamp` is the implicit clock input. All three checks use an exclusive-open-window convention:
  they revert while `block.timestamp < deadline`, so the transition is available at equality
  (`packages/contracts/src/Raffle.sol:L282-L287`, `L290-L291`).
- The persistent inputs are `status`, `totalEntries`, `sponsor`, `endTime`, `drawRequestedAt`, and
  `unsettledPot` (`packages/contracts/src/Raffle.sol:L61-L94`, `L109-L124`).
- `sponsor` is assigned once during factory-only initialization (`packages/contracts/src/Raffle.sol:L176-L205`).
  The factory supplies the `createRaffle` caller as that sponsor (`packages/contracts/src/RaffleFactory.sol:L97-L120`),
  and prize receipt activates the raffle only when `from == sponsor` and `operator == factory`
  (`packages/contracts/src/Raffle.sol:L416-L430`). `sponsorRecipient` is a distinct field and receives no
  authority in this function (`packages/contracts/src/Raffle.sol:L61-L64`, `L282`).
- `endTime` is set at initialization (`packages/contracts/src/Raffle.sol:L197-L205`). The canonical factory
  requires it to be after creation time and no more than 30 days later
  (`packages/contracts/src/RaffleFactory.sol:L97-L104`); the two-day request timeout is fixed
  (`packages/contracts/src/libraries/RaffleConstants.sol:L29-L36`).
- `totalEntries` is a lifetime counter. The only writer before terminal handling is `buyEntries`, which adds
  a positive count, records the matching ticket range, and increases `unsettledPot` by
  `entryCount * ENTRY_PRICE` (`packages/contracts/src/Raffle.sol:L215-L235`). Therefore the zero-entry branch
  corresponds to no completed purchase, while the nonzero branch corresponds to at least one purchased
  entry.
- On the `Drawing` path, this function relies on `requestDraw` being the sole transition into `Drawing` and
  having recorded `drawRequestedAt`. That predecessor requires `Active`, a time at or after `endTime`, at
  least one sold entry, and a time before the request deadline, then writes `status = Drawing` and
  `drawRequestedAt = block.timestamp` (`packages/contracts/src/Raffle.sol:L240-L260`).
- Full refund coverage assumes the quote-token balance credited by purchases tracks `unsettledPot`.
  `SafeERC20` establishes call success, but the target explicitly trusts canonical, fee-free, non-rebasing
  six-decimal USDC semantics (`packages/contracts/src/interfaces/IRaffle.sol:L12-L15`); the factory itself
  checks only contract code and six-decimal metadata (`packages/contracts/src/RaffleFactory.sol:L58-L78`).
- The inherited `nonReentrant` modifier rejects an entry while the shared guard is already entered, marks it
  entered for the body, and restores it afterward
  (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`).

The complete eligibility matrix is:

| Entry state | Entry count | Caller and time | Result from the eligibility checks |
| --- | ---: | --- | --- |
| `Active` | `0` | `msg.sender == sponsor`, any time | Eligible; the conjunctive rejection condition is false (`Raffle.sol:L279-L284`). |
| `Active` | `0` | non-sponsor before `endTime` | Reverts `RefundsNotAvailable(endTime, block.timestamp)` (`Raffle.sol:L280-L284`). |
| `Active` | `0` | any caller at or after `endTime` | Eligible (`Raffle.sol:L280-L284`). |
| `Active` | `> 0` | any caller, including sponsor, before `endTime + 2 days` | Reverts `RefundsNotAvailable` (`Raffle.sol:L285-L288`, `L458-L460`; `RaffleConstants.sol:L32-L33`). |
| `Active` | `> 0` | any caller at or after `endTime + 2 days` | Eligible (`Raffle.sol:L285-L288`). |
| `Drawing` | necessarily `> 0` on the canonical path | any caller before `drawRequestedAt + 2 days` | Reverts `RefundsNotAvailable` (`Raffle.sol:L289-L291`, `L463-L465`; `RaffleConstants.sol:L35-L36`). |
| `Drawing` | necessarily `> 0` on the canonical path | any caller at or after `drawRequestedAt + 2 days` | Eligible (`Raffle.sol:L289-L291`). |
| Any other status | any | any caller/time | Reverts `InvalidStatus(status)` (`Raffle.sol:L292-L294`). |

---

**Outputs & Effects:**

- Returns no value. Reverting paths make no raffle-state change (`packages/contracts/src/Raffle.sol:L276-L301`).
- On every successful path, snapshots the old `unsettledPot`, zeroes that bucket, assigns the snapshot to
  `remainingRefundLiability`, and sets `status = Refunding`
  (`packages/contracts/src/Raffle.sol:L296-L299`).
- Emits `RefundsEnabled(msg.sender, liability)` after the state transition, identifying the permissionless
  finalizer and the initial refund liability (`packages/contracts/src/Raffle.sol:L296-L300`;
  `packages/contracts/src/interfaces/IRaffle.sol:L110-L113`).
- Makes no external call and performs no asset transfer. Ticket ownership and ranges, `totalEntries`, the
  stored request identifiers/timestamps, and prize-accounting fields are unchanged by this function
  (`packages/contracts/src/Raffle.sol:L276-L301`).
- `remainingRefundLiability` is zero on every canonical `Active`/`Drawing` entry path: it begins at the
  storage default, is first assigned only here, and can thereafter only be decreased by `refundTickets`,
  which requires `Refunding` (`packages/contracts/src/Raffle.sol:L296-L299`, `L349-L370`). No transition out
  of `Refunding` exists among the status writers (`packages/contracts/src/Raffle.sol:L205`, `L252`, `L299`,
  `L428`, `L521`). Thus the successful assignment moves, rather than duplicates, the tracked amount, and
  preserves `accountedQuoteBalance = unsettledPot + remainingRefundLiability + winnerProceeds +
  sponsorProceeds + protocolFees` (`packages/contracts/src/Raffle.sol:L468-L470`).
- The resulting state enables ticket owners to burn tickets for their full range value and decrement the
  new liability (`packages/contracts/src/Raffle.sol:L349-L371`), and enables permissionless return of the
  prize to `sponsorRecipient` (`packages/contracts/src/Raffle.sol:L395-L406`). Calls that require `Active`,
  `Drawing`, `NftWon`, or `CashWon` no longer pass their status checks
  (`packages/contracts/src/Raffle.sol:L215-L216`, `L241-L243`, `L310-L318`, `L533-L537`).

---

**Block-by-Block:**

```solidity
// L276-L277
function enableRefunds() external override nonReentrant {
    uint256 deadline;
```

- **What:** Opens a parameterless external entrypoint under the contract-wide reentrancy guard and allocates
  a memory variable for whichever deadline applies.
- **Why here:** The guard covers eligibility reads and all accounting/status writes. Each successful branch
  assigns `deadline` before using it (`packages/contracts/src/Raffle.sol:L279-L291`).
- **Assumes:** The inherited guard's shared slot is not already entered; otherwise it reverts before the
  function body (`ReentrancyGuard.sol:L69-L72`, `L88-L100`).
- **Establishes:** No nested `nonReentrant` entrypoint can execute during this body
  (`ReentrancyGuard.sol:L94-L105`).
- **Depended on by:** The state transition at `Raffle.sol:L296-L300` executes as one guarded operation.

```solidity
// L279-L284
if (status == Status.Active) {
    if (totalEntries == 0) {
        deadline = endTime;
        if (msg.sender != sponsor && block.timestamp < deadline) {
            revert RefundsNotAvailable(deadline, block.timestamp);
        }
```

- **What:** Selects the empty-active path. The sponsor bypasses the time check; every other caller waits
  until the exclusive sale end.
- **Why here:** Entry count is tested before the generic sold-raffle deadline because empty raffles have no
  ticket claims and the sponsor has a separate cancellation authority
  (`packages/contracts/src/interfaces/IRaffle.sol:L322-L324`).
- **Assumes:** `totalEntries == 0` faithfully denotes no completed ticket purchase; `buyEntries` is its only
  writer and requires a positive `entryCount` (`packages/contracts/src/Raffle.sol:L215-L232`). The privileged
  identity is the stored sponsor established by factory creation (`RaffleFactory.sol:L97-L120`).
- **Establishes:** Passing this block means either the caller is the sponsor or `block.timestamp >= endTime`.
- **Depended on by:** The refund transition at L296-L300; in this branch its liability is zero under the
  purchase-accounting invariant (`Raffle.sol:L223-L233`).

```solidity
// L285-L288
    } else {
        deadline = drawRequestDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    }
```

- **What:** Applies the draw-request timeout to an active raffle with one or more sold entries.
- **Why here:** Until this deadline, `requestDraw` has the non-overlapping interval
  `[endTime, drawRequestDeadline())` (`packages/contracts/src/Raffle.sol:L240-L247`). At exact equality,
  `requestDraw` rejects because it uses `>=`, while this block accepts because it uses `<`.
- **Assumes:** `drawRequestDeadline` returns the intended end-time-derived boundary. Its complete body is
  `uint256(endTime) + DRAW_REQUEST_TIMEOUT` (`packages/contracts/src/Raffle.sol:L458-L460`), and the constant
  is two days (`packages/contracts/src/libraries/RaffleConstants.sol:L32-L33`).
- **Establishes:** Passing this block means the raffle is sold, still unresolved in `Active`, and
  `block.timestamp >= endTime + 2 days`.
- **Depended on by:** L296-L300 uses that elapsed request window to select refunds instead of creating a draw.

```solidity
// L289-L291
} else if (status == Status.Drawing) {
    deadline = callbackDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
```

- **What:** Applies the callback timeout after a draw request has been accepted.
- **Why here:** `fulfillRandomWords` accepts a matching callback only while
  `block.timestamp < callbackDeadline()` and ignores one at or after equality
  (`packages/contracts/src/Raffle.sol:L509-L523`). This block uses the complementary boundary.
- **Assumes:** `Drawing` came from `requestDraw`, which set `drawRequestedAt` in the same transaction as the
  status (`packages/contracts/src/Raffle.sol:L240-L260`). `callbackDeadline` otherwise has a zero-return path
  when `drawRequestedAt == 0`; on the canonical `Drawing` path it returns
  `drawRequestedAt + DRAW_CALLBACK_TIMEOUT` (`packages/contracts/src/Raffle.sol:L463-L465`).
- **Establishes:** Passing this block means the authenticated callback window has closed.
- **Depended on by:** L296-L300 moves the unresolved request's raffle into `Refunding`. Later authenticated
  callbacks observe `status != Drawing` and are ignored (`Raffle.sol:L509-L515`).

```solidity
// L292-L294
} else {
    revert InvalidStatus(status);
}
```

- **What:** Rejects `AwaitingPrize`, both resolved result states, and `Refunding`.
- **Why here:** It makes the transition available only from the two unresolved active lifecycle states and
  prevents repeating the liability assignment after entry into `Refunding`.
- **Assumes:** `status` is the authoritative lifecycle field, as declared by the interface
  (`packages/contracts/src/interfaces/IRaffle.sol:L20-L33`, `L502-L504`).
- **Establishes:** Reaching L296 implies the prior status was exactly `Active` or `Drawing` and its relevant
  eligibility test passed.
- **Depended on by:** The direct assignment to `remainingRefundLiability` at L298 relies on this being the
  first refund transition.

```solidity
// L296-L300
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
emit RefundsEnabled(msg.sender, liability);
```

- **What:** Reclassifies the whole unallocated pot as ticket-refund liability, commits the terminal refund
  status, and publishes the transition.
- **Why here:** All lifecycle and time checks precede mutation. The amount is copied before the source bucket
  is zeroed; the event follows the final state. There is no external interaction between these writes.
- **Assumes:** The old `unsettledPot` equals the aggregate purchase value represented by outstanding tickets.
  `buyEntries` creates both sides together (`packages/contracts/src/Raffle.sol:L223-L235`), and no ticket-burn
  path is available while status remains `Active` or `Drawing` (`packages/contracts/src/Raffle.sol:L304-L371`).
  Actual balance equivalence additionally rests on the documented canonical quote-token assumption.
- **Establishes:** `unsettledPot == 0`, `remainingRefundLiability == old(unsettledPot)`, and
  `status == Refunding`; the event carries the same liability value.
- **Depended on by:** `refundTickets`, `releaseSponsorPrize`, `accountedQuoteBalance`, and the callback status
  gate (`packages/contracts/src/Raffle.sol:L349-L371`, `L395-L406`, `L468-L470`, `L509-L515`).

---

**Cross-Function Dependencies:**

- **Callee `drawRequestDeadline` (internal, source available, `Raffle.sol:L458-L460`):** has one path and
  returns `uint256(endTime) + 2 days`. The active-sold branch depends on this exact exclusive boundary.
- **Callee `callbackDeadline` (internal, source available, `Raffle.sol:L463-L465`):** returns zero before a
  request and `drawRequestedAt + 2 days` afterward. The drawing branch depends on the nonzero path, established
  by `requestDraw` at `Raffle.sol:L252-L254`.
- **Modifier `ReentrancyGuard.nonReentrant` (internal, vendored source available,
  `ReentrancyGuard.sol:L69-L105`):** rejects nested guarded entry, brackets the body with guard writes, and
  restores the guard after completion.
- **Lifecycle predecessors:** `RaffleFactory.createRaffle` fixes sponsor/end-time inputs and atomically
  deposits the prize (`RaffleFactory.sol:L97-L147`); `initialize` stores them and enters `AwaitingPrize`
  (`Raffle.sol:L176-L205`); `onERC721Received` enters `Active` (`Raffle.sol:L416-L430`); `buyEntries` creates
  entry ranges and the pot (`Raffle.sol:L209-L237`); `requestDraw` enters `Drawing` and sets its clock
  (`Raffle.sol:L240-L272`).
- **Competing terminal predecessor:** an authenticated, matching, in-window callback changes `Drawing` to
  `NftWon` or `CashWon` (`Raffle.sol:L509-L523`), after which `enableRefunds` rejects via L292-L294. The
  inherited callback entrypoint restricts dispatch to the configured wrapper
  (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).
- **Callers:** no target function calls `enableRefunds`; it is directly external and declared permissionless
  except for the branch-specific sponsor/time predicates (`IRaffle.sol:L322-L324`; `Raffle.sol:L276-L294`).
- **Shared state:** `status` couples every lifecycle operation; `totalEntries` and `unsettledPot` are written
  together by purchases; `endTime` and `sponsor` are fixed during initialization; `drawRequestedAt` is fixed
  by the accepted request; and `remainingRefundLiability` is consumed by ticket refunds
  (`Raffle.sol:L176-L205`, `L209-L235`, `L240-L260`, `L296-L299`, `L349-L370`).
- **Invariant coupling:** under the declared quote-token trust model, every successful purchase adds the same
  `entryCount * ENTRY_PRICE` to represented ticket value and `unsettledPot` (`Raffle.sol:L223-L233`). This
  function preserves the amount while changing its accounting bucket, and `refundTickets` removes ticket
  value and the same amount of liability together (`Raffle.sol:L356-L370`).

---

**Open Questions:**

- unclear; need to inspect deployment configuration and the deployed quote-token implementation to establish
  the declared canonical, fee-free, non-rebasing USDC assumption. Target code checks code presence and six
  decimals, not token identity or transfer deltas (`packages/contracts/src/RaffleFactory.sol:L58-L78`;
  `packages/contracts/src/interfaces/IRaffle.sol:L12-L15`).
