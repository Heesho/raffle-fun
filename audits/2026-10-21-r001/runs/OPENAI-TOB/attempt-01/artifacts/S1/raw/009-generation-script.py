from pathlib import Path
import json, os
root=Path('.')
out=Path('audit/S1/audit-context/functions/08-enableRefunds.md')
out.parent.mkdir(parents=True,exist_ok=True)
prose=r'''## `enableRefunds` in target/packages/contracts/src/Raffle.sol (L276-L301)

**Purpose:** Moves an unresolved raffle into its full-refund lifecycle once an empty-sale cancellation or the applicable draw timeout permits it. The function reallocates the whole recorded unsettled pot to ticket-refund liability; ticket owners claim through `refundTickets`, and the sponsor prize is separately releasable through `releaseSponsorPrize` (Raffle.sol L279-L300, L349-L371, L395-L406). It performs the lifecycle transition and accounting allocation, with no asset delivery in this invocation (L276-L301).

All unqualified line citations below refer to `target/packages/contracts/src/Raffle.sol`. Dependency citations use the following exact files: `Constants` = `target/packages/contracts/src/libraries/RaffleConstants.sol`; `Guard` = `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol`; `Slots` = `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol`; `Interface` = `target/packages/contracts/src/interfaces/IRaffle.sol`.

---

**Inputs & Assumptions:**

- There are no explicit arguments and no return value; this is an external, nonpayable, `nonReentrant` entrypoint (L276). `msg.sender` is untrusted. The sole sender-dependent permission is the sponsor exemption for an Active raffle with zero entries before sale end; all other successful paths are permissionless after their respective deadlines (L279-L293).
- Persistent inputs are `status`, `totalEntries`, `sponsor`, `endTime`, `drawRequestedAt` through `callbackDeadline`, and `unsettledPot` (L279-L296, L458-L465). Sponsor and end time come from one-time, factory-only initialization (L176-L179, L197-L205). `totalEntries` and `unsettledPot` are incremented together for successful purchases (L223-L235). These facts establish configuration provenance and accounting history, rather than granting trust to callers.
- `block.timestamp` is the implicit clock used in every timing check (L282-L291). The supplied orientation trusts chain execution and atomic rollback. This function does not obtain an independent clock or authenticate time beyond using that environment value (L276-L301).
- Entry requires a guard storage value other than `ENTERED`. The inherited modifier checks this before the body; it does not require the previous value to equal `NOT_ENTERED`, so a fresh clone's default-zero guard also passes (Guard L50-L51, L69-L73, L88-L105, L112-L118). The slot accessor returns a reference to the designated storage word without any external call (Slots L93-L97).
- For accounting conservation, the preexisting refund liability must be zero when entering from Active or Drawing, because L298 assigns rather than adds. This follows from fresh-clone zero initialization, the declaration without an initializer (L94), refund enabling being restricted to Active/Drawing (L279-L294), and refund consumption requiring Refunding (L349-L368). Initialization moves to AwaitingPrize, prize reception to Active, request initiation to Drawing, and successful randomness to a winner state; none is a Refunding-to-Active/Drawing return path in the normal initialized lifecycle (L176-L205, L421-L428, L240-L260, L509-L523). No independent `remainingRefundLiability == 0` assertion is made here (L276-L301).
- Actual asset backing is separate from recorded accounting. `enableRefunds` reads no quote-token balance and does not validate transfer semantics (L276-L301). Purchases credit the recorded pot after `safeTransferFrom` (L223-L233), while the source explicitly assumes canonical, non-rebasing, fee-free quote-token transfers (L560-L566; Interface L12-L15). Nothing in this function establishes those external token semantics.

---

**Outputs & Effects:**

- On success: `unsettledPot == 0`, `remainingRefundLiability == old(unsettledPot)`, and `status == Refunding` (L296-L299). No percentage fee or winner/sponsor cash allocation is computed on this path (L296-L300); those allocations belong to winner settlement (L533-L555).
- Emits `RefundsEnabled(msg.sender, liability)` after the accounting and lifecycle writes (L300). The interface defines the indexed finalizer and initial refund-liability fields (Interface L110-L113).
- The modifier writes its guard to `ENTERED` before the body and `NOT_ENTERED` afterward (Guard L69-L73, L94-L105). A revert from timing, status, or guard validation aborts the transaction under the supplied atomic-execution assumption (L283, L287, L291, L293; Guard L88-L99).
- The body changes no ticket ownership, stored ranges, entry totals, request identifier, prize claim flag, or result fields; it contains no external interaction and no loop (L276-L301). Ticket burning and transfers are deferred to the separately callable claim paths (L349-L371, L395-L406).
- Repetition fails because Refunding falls into the invalid-status branch (L279-L294, L299). Purchases and new requests require Active, settlement/redemption require a winner state, and randomness ignores a state other than Drawing (L215, L241, L311-L312, L511-L515, L535-L536).

---

**Block-by-Block:**

```solidity
// L276-L277
function enableRefunds() external override nonReentrant {
    uint256 deadline;
```

- **What:** Enters the shared reentrancy guard and creates a local deadline accumulator (L276-L277; Guard L69-L73).
- **Why here:** The lock is acquired before reading lifecycle/accounting state, so nested entry from another guarded operation is rejected before the body (Guard L88-L99).
- **Assumes:** The inherited guard slot is reserved for the guard. Its exact constant is defined in Guard L35-L37 and returned in Guard L116-L118; the storage accessor directly selects that slot (Slots L93-L97).
- **Establishes:** The shared guard equals `ENTERED` while the body runs (Guard L99).
- **Depended on by:** The whole decision and mutation sequence (L279-L300). There is no external callback point inside this body; the guard also bars entry while `buyEntries` or `requestDraw` is already executing under that same guard (L209-L224, L240-L257; Guard L69-L73, L88-L99).

```solidity
// L279-L284
if (status == Status.Active) {
    if (totalEntries == 0) {
        deadline = endTime;
        if (msg.sender != sponsor && block.timestamp < deadline) {
            revert RefundsNotAvailable(deadline, block.timestamp);
        }
```

- **What:** Uses sale end as the empty-sale deadline, exempting the configured sponsor from waiting (L279-L284).
- **Why here:** The exemption is nested inside the zero-entry check, so it cannot authorize early cancellation once any entries are sold (L280-L287).
- **Assumes:** `totalEntries` records successful purchases. Its only increment in the reviewed source accompanies range creation and recorded payment (L223-L235); refund execution does not reduce this historical count (L349-L371).
- **Establishes:** For this branch, success means `msg.sender == sponsor` or `block.timestamp >= endTime` (L282-L284). At exact sale end, any caller passes. The comparison uses `sponsor`, not `sponsorRecipient` (L282; their distinct assignments are L197-L198).
- **Depended on by:** The terminal allocation at L296-L300 and the prize-return eligibility it creates (L395-L398). Zero entries cannot enter `requestDraw` (L243).

```solidity
// L285-L288
    } else {
        deadline = drawRequestDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    }
```

- **What:** For an Active raffle with entries, requires the draw-request deadline to have arrived (L285-L288).
- **Why here:** A sold raffle receives a draw-request window after sale end, regardless of caller identity (L285-L287; L241-L247).
- **Assumes:** The helper supplies the intended deadline. Its full body unconditionally returns `uint256(endTime) + DRAW_REQUEST_TIMEOUT` (L458-L460), and that constant is two days (Constants L32-L33). It has no additional branch, external call, or validation.
- **Establishes:** `block.timestamp >= uint256(endTime) + 2 days`. Equality permits refunds exactly when `requestDraw` rejects the request window as expired (L245-L247, L287).
- **Depended on by:** The no-request timeout transition at L296-L300. Sponsor identity grants no exception in this branch (L285-L288).

```solidity
// L289-L294
} else if (status == Status.Drawing) {
    deadline = callbackDeadline();
    if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
} else {
    revert InvalidStatus(status);
}
```

- **What:** A Drawing raffle waits until its callback deadline; every other lifecycle state is rejected (L289-L294).
- **Why here:** Once a request exists, the timeout uses the request timestamp instead of the sale-end timestamp (L290, L463-L465).
- **Assumes:** `callbackDeadline` is interpreted with both of its paths. If `drawRequestedAt != 0`, it returns `uint256(drawRequestedAt) + 2 days`; otherwise its named return stays zero (L463-L465; Constants L35-L36). It does not validate Drawing status or assert that the request timestamp is nonzero. `requestDraw` writes Drawing and `uint64(block.timestamp)` before the wrapper request (L252-L257); this records the normal timestamp anchor but is not a nonzero assertion in the helper.
- **Establishes:** Success requires `block.timestamp >= callbackDeadline()`. With a zero helper result this timing comparison imposes no positive waiting period; that is the literal helper/caller behavior, not a claim that such a Drawing state occurs in canonical execution (L290-L291, L463-L465).
- **Depended on by:** Mutually exclusive callback/refund eligibility at the boundary: `fulfillRandomWords` ignores callbacks at or after the same deadline, and ignores them after status has become Refunding (L511-L515). Before the deadline a valid callback can instead commit a winner state, which this function rejects (L289-L294, L518-L521).

```solidity
// L296-L301
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
emit RefundsEnabled(msg.sender, liability);
}
```

- **What:** Copies the old pot into refund liability, clears the pot, commits Refunding, and emits the exact liability allocated (L296-L300).
- **Why here:** All authorization, lifecycle, and deadline checks finish before economic state changes. The event follows the complete transition, and there is no transfer between these writes (L279-L300).
- **Assumes:** Preexisting refund liability is zero in the ordinary lifecycle, as established above. This assignment does not preserve an arbitrary preexisting liability (L298).
- **Establishes:** The old unsettled pot is fully represented in `remainingRefundLiability`. Given zero preexisting refund liability, `accountedQuoteBalance()` is unchanged because it adds both buckets and the three untouched proceeds buckets (L296-L299, L468-L470). No assertion equates that sum to the external token balance.
- **Depended on by:** `refundTickets` subtracts the represented entries times `ENTRY_PRICE` before paying the owner (L356-L369), while `releaseSponsorPrize` accepts Refunding independently of remaining quote liability (L395-L405). Returning the prize does not wait for every ticket refund in these source checks (L395-L405).

---

**Cross-Function Dependencies:**

- **Direct internal callee `drawRequestDeadline`:** Read in full at L458-L460. One path, widening a uint64 end time before adding the two-day uint256 constant. The maximum uint64 input plus this constant fits uint256 (L82, L459; Constants L33). No status checks or caller checks are delegated to it.
- **Direct internal callee `callbackDeadline`:** Read in full at L463-L465. Nonzero request timestamp yields timestamp plus two days; zero yields zero. All paths and the caller's interpretation of zero are described above. Its uint64 input is likewise widened before addition (L112, L464; Constants L36).
- **Modifier/internal guard chain:** `nonReentrant` calls `_nonReentrantBefore`, then the body, then `_nonReentrantAfter` (Guard L69-L73). Before-entry calls `_nonReentrantBeforeView`, which reverts only when `_reentrancyGuardEntered` returns true; otherwise `_nonReentrantBefore` writes `ENTERED` (Guard L88-L100). The successful exit writes `NOT_ENTERED` (Guard L102-L106). `_reentrancyGuardEntered` compares the chosen word exactly to `ENTERED`; `_reentrancyGuardStorageSlot` unconditionally returns the constant; `StorageSlot.getUint256Slot` unconditionally creates the storage reference using `r.slot := slot` (Guard L112-L118; Slots L93-L97). There are no external calls or adversarial return values in this call tree.
- **Callers:** External callers reach L276 directly. No internal call to this function exists in the reviewed Raffle source. Their entitlement to trigger a transition depends only on the state/time matrix and the empty-sale sponsor exception (L279-L294); the caller receives no funds here (L296-L300).
- **Shared state:** `initialize` supplies sponsor/end time and AwaitingPrize (L197-L205); `onERC721Received` supplies Active (L421-L428); `buyEntries` grows entries and pot (L226-L235); `requestDraw` supplies Drawing and the request timestamp (L252-L260); `fulfillRandomWords` supplies the winner result or preserves state on ignored callbacks (L509-L523); settlement consumes the pot in winner states (L533-L555); refunds consume only the separate refund liability in Refunding (L349-L368). These state gates separate refund accounting from winner allocations.
- **Invariant couplings:** Full refunds depend on the correspondence between paid entry ranges and the recorded pot, established at purchase (L223-L235), then reclassified here (L296-L299), and consumed using the same price during refund (L362-L369; Constants L20-L21). Ticket ownership at claim time is checked by the refund function rather than this transition (L359-L364). Deadline exclusivity couples this function to request initiation and callback acceptance at their exact boundary comparisons (L245-L247, L287, L291, L511-L515).

---

**Open Questions:**

No unresolved source-control-flow questions remain for this function or its direct helper/modifier call tree. Canonical token transfer semantics and chain timestamp/rollback behavior remain explicit environment assumptions, rather than properties established by `enableRefunds` (L276-L301; L560-L566; Interface L12-L15).
'''
out.write_text(prose)
Path('audit/S1/raw/009-analysis-original.md').write_text(prose)
record={
 'function':'enableRefunds','file':'target/packages/contracts/src/Raffle.sol','lines':'L276-L301','analysisFile':str(out),
 'invariants':[
 {'claim':'Successful entry is from Active or Drawing only; zero-entry Active allows the sponsor before sale end and everyone at/after sale end.','evidence':'Raffle.sol L279-L294'},
 {'claim':'Sold Active raffles require timestamp >= endTime + 2 days; Drawing requires timestamp >= callbackDeadline(), whose zero-timestamp branch returns zero.','evidence':'Raffle.sol L285-L291, L458-L465; RaffleConstants.sol L32-L36'},
 {'claim':'On success unsettledPot is zero, remainingRefundLiability equals the old unsettledPot, and status is Refunding.','evidence':'Raffle.sol L296-L300'},
 {'claim':'At their exact deadlines, requests/callbacks stop being eligible while the corresponding refund transition becomes eligible.','evidence':'Raffle.sol L245-L247, L287, L291, L511-L515'},
 {'claim':'The transition makes no external calls or asset transfers; guarded nested entry is rejected before the body.','evidence':'Raffle.sol L276-L301; ReentrancyGuard.sol L69-L73, L88-L105'}],
 'assumptions':[
 {'claim':'Preexisting refund liability is zero before this first Active/Drawing-to-Refunding transition; otherwise the assignment replaces it.','establishedBy':'Fresh-clone zero storage; Raffle.sol L94, L176-L205, L279-L299, L349-L368, L421-L428, L509-L523. No independent zero-liability check at L298.'},
 {'claim':'Recorded purchase amounts correspond to actual quote-token backing under canonical non-rebasing, fee-free transfer semantics.','establishedBy':'Raffle.sol L223-L233 credits after safeTransferFrom; trusted-token assumption explicitly documented at L560-L566 and IRaffle.sol L12-L15. Nothing in enableRefunds L276-L301 verifies external balance or semantics.'},
 {'claim':'The callback deadline uses the request timestamp recorded by requestDraw; a nonzero timestamp is not asserted by the deadline helper.','establishedBy':'Raffle.sol L252-L253 writes uint64(block.timestamp); L463-L465 returns zero when that field is zero. The caller only compares against the returned deadline at L290-L291.'},
 {'claim':'Block timestamp and transaction rollback follow the trusted chain execution model in the supplied orientation.','establishedBy':'Supplied 009-request.json orientation; source consumes block.timestamp at Raffle.sol L282-L291 and uses reverts at L283, L287, L291, L293.'}],
 'calls':[
 {'callee':'drawRequestDeadline','kind':'internal','propagates':'Raffle.sol L458-L460 unconditionally returns uint256(endTime) + two-day DRAW_REQUEST_TIMEOUT (RaffleConstants.sol L33); no status or sender validation.'},
 {'callee':'callbackDeadline','kind':'internal','propagates':'Raffle.sol L463-L465 returns drawRequestedAt + two-day timeout only if nonzero, otherwise zero; enableRefunds L290-L291 accepts timestamp >= that result.'},
 {'callee':'ReentrancyGuard.nonReentrant / _nonReentrantBefore / _nonReentrantBeforeView','kind':'internal','propagates':'ReentrancyGuard.sol L69-L73, L88-L100 rejects ENTERED before body and otherwise writes ENTERED. Initial zero is accepted, not just NOT_ENTERED.'},
 {'callee':'ReentrancyGuard._nonReentrantAfter','kind':'internal','propagates':'ReentrancyGuard.sol L102-L106 writes NOT_ENTERED after successful body; a body revert rolls back transaction state under the supplied execution model.'},
 {'callee':'ReentrancyGuard._reentrancyGuardEntered / _reentrancyGuardStorageSlot','kind':'internal','propagates':'ReentrancyGuard.sol L112-L118 reads the constant slot and compares exactly with ENTERED; slot constant at L35-L37.'},
 {'callee':'StorageSlot.getUint256Slot','kind':'internal','propagates':'StorageSlot.sol L93-L97 directly binds returned storage reference to the supplied slot using assembly; no branch or external interaction.'}],
 'callers':['External callers at Raffle.sol L276; sponsor-only early empty-sale exception at L280-L284; other eligible paths permissionless at L285-L291.'],
 'sharedState':['status: initialize L205, onERC721Received L428, requestDraw L252, fulfillRandomWords L521, enableRefunds L299; state gates L215, L241, L312, L350, L397, L536.','totalEntries/unsettledPot: buyEntries L230-L233; enableRefunds L296-L298; winner settlement L539-L555.','remainingRefundLiability: enableRefunds L298; refundTickets L368; accountedQuoteBalance L469.','sponsor/endTime: initialize L197/L204; drawRequestedAt: requestDraw L253; helpers L458-L465.','Guard storage shared across nonReentrant operations: ReentrancyGuard.sol L35-L37, L69-L73, L88-L118.'],
 'openQuestions':[]}
raw=Path('audit/S1/raw/009-response-original.json')
b=(json.dumps(record,indent=2)+'\n').encode()
raw.write_bytes(b)
completion={'analysisFile':str(out),'responseFile':'audit/S1/native/009-response.json','resourcesFile':'audit/S1/raw/009-resources.json','originalAnalysisFile':'audit/S1/raw/009-analysis-original.md','originalResponseFile':str(raw)}
Path('audit/S1/raw/009-completion.json').write_text(json.dumps(completion,separators=(',',':'))+'\n')
req=json.loads(Path('audit/S1/native/009-request.json').read_text())
assert all(k in record for k in req['options']['schema']['required'])
assert out.exists() and Path('audit/S1/raw/009-resources.json').exists()
assert len(b)>0 and prose.endswith('\n')
tmp=Path('audit/S1/native/009-response.json.tmp')
tmp.write_bytes(b)
os.replace(tmp,'audit/S1/native/009-response.json')
assert Path('audit/S1/native/009-response.json').read_bytes()==raw.read_bytes()
print(json.dumps(completion,separators=(',',':')))
