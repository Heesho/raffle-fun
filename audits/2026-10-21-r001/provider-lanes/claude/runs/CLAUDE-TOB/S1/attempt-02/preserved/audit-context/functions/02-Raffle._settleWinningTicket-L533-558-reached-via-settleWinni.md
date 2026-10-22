## `_settleWinningTicket` in packages/contracts/src/Raffle.sol (L533-L558)

Reached through `settleWinningTicket` (L304-L306, call at L305) and `redeemWinningTicket` (L309-L346, call at L315).
A search of `packages/contracts` (excluding `node_modules`) finds exactly these two call sites. The function is
`private` (L533).

```solidity
// L533-L558
function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
    if (settlementComplete) revert SettlementAlreadyComplete();                                   // L534
    Status result = status;                                                                       // L535
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);       // L536

    _requireWinningTicket(ticketId);                                                              // L538
    uint256 grossPot = unsettledPot;                                                              // L539
    uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS); // L540
    uint256 sponsorAmount;                                                                        // L541

    if (result == Status.NftWon) {                                                                // L543
        sponsorAmount = grossPot - protocolFee;                                                   // L544
    } else {
        cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS); // L546
        sponsorAmount = grossPot - protocolFee - cashAmount;                                      // L547
        winnerProceeds = cashAmount;                                                              // L548
    }

    settlementComplete = true;                                                                    // L551
    winningTicketId = ticketId;                                                                   // L552
    unsettledPot = 0;                                                                             // L553
    sponsorProceeds = sponsorAmount;                                                              // L554
    protocolFees = protocolFee;                                                                   // L555

    emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount); // L557
}
```

**Purpose:** This is the only code that turns a resolved raffle's gross sale pot into its terminal quote-token
liabilities. It runs once per clone, after the VRF callback has set `status` to `NftWon` or `CashWon` (L521). It
does three things:

1. It proves that the stored range of a caller-named ticket contains `winningEntry`.
2. It records that ticket as `winningTicketId`.
3. It moves `unsettledPot` into `protocolFees` (5%, floor), `winnerProceeds` (80%, floor, `CashWon` only) and
   `sponsorProceeds`. The sponsor gets the remainder: 95% on `NftWon`, 15% on `CashWon`.

What breaks without it:
- `releaseSponsorProceeds` (L376-L377) and `releaseProtocolFees` (L386-L387) revert with
  `NoSponsorProceeds`/`NoProtocolFees` until it runs. It is the only nonzero writer of `sponsorProceeds` (L554) and
  `protocolFees` (L555).
- A cash winner cannot be paid. It is the only nonzero writer of `winnerProceeds` (L548), and `redeemWinningTicket`
  calls it inline (L315) when settlement has not happened yet.
- `settlementComplete` (L551) and `winningTicketId` (L552) have no other writer. `redeemWinningTicket` reads both
  (L314, L316).

Specification: DESIGN.md L2 says "Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. ... Rounding is floor on aggregate protocol fee; remainder must be
allocated without loss. ... Settlement is permissionless, storage-only". The NatSpec at L528-L530 describes the same
behavior.

---

**Inputs & Assumptions:**

- `ticketId` (uint256): the ticket claimed to contain the winning entry. Trust: **untrusted**.
  - Via `settleWinningTicket`, any caller chooses it (L304; no access control).
  - Via `redeemWinningTicket`, the redeemer chooses it. The ownership check that constrains the redeemer
    (L320-L321) runs *after* this function returns.
  - Inside this function, the only constraint on it is the range check at L538.
- Implicit inputs that are read:
  - `settlementComplete` (L127) at L534.
  - `status` (L124) at L535.
  - `winningEntry` (L118) at L581, inside the callee.
  - `_ticketRanges[ticketId]` (L139) at L452-L454, inside `ticketRange`.
  - `unsettledPot` (L91) at L539.
  - `msg.sender`, used only as the indexed `settler` field of the event at L557. It affects no amount and no stored
    value.
  - Constants: `BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8000` (RaffleConstants L12, L15, L18).
- Not read: `block.timestamp`, `resolvedAt`, `totalEntries`, `reserveEntries`, `ownerOf`, `winnerRedeemed`,
  `prizeClaimed`, `remainingRefundLiability`, `quoteToken.balanceOf(this)`. The function has no deadline and does not
  look at who holds the ticket.

Preconditions and what establishes each:

| # | Precondition | Established by | Checked in this function |
|---|---|---|---|
| P1 | Settlement has not occurred yet | L534 | yes |
| P2 | `status ∈ {NftWon, CashWon}` | L535-L536 | yes |
| P3 | `winningEntry ∈ [1, totalEntries]` whenever P2 holds | `fulfillRandomWords` L518-L521, `requestDraw` L243, `buyEntries` L215, callback filter L510-L516 | no |
| P4 | Ticket ranges partition `[1, totalEntries]`; unminted IDs read `(0,0)`; ranges survive burns | `buyEntries` L218, L226-L232; sole range writer L232; sole `ticketCount` writer L231 | no |
| P5 | `unsettledPot == totalEntries * ENTRY_PRICE` on entry | L223/L230/L233 lockstep; L297 ruled out by P2; L553 ruled out by P1 | no |
| P6 | `winnerProceeds == sponsorProceeds == protocolFees == 0` on entry | sole nonzero writers L548/L554/L555 are in this function, plus P1 | no |
| P7 | `remainingRefundLiability == 0` while P2 holds | writers L298 (ends in `Refunding`, L299) and L368 (requires `Refunding`, L350) | no |
| P8 | Clone's USDC balance ≥ `grossPot` | **nothing found** | no |
| P9 | `status` encodes reserve met or missed | L521; `reserveEntries != 0` at RaffleFactory L178; upper bound: **nothing found** | no |
| P10 | No reentry while the function runs | no external call in L533-L558; both callers `nonReentrant` (L304, L309) | n/a |

- **P3.** `winningEntry` has one writer, L519. `NftWon`/`CashWon` have one writer, L521, which runs in the same call
  right after L519.
  - L518 computes `(randomWords[0] % uint256(totalEntries)) + 1` in uint256, which yields `[1, totalEntries]`.
    Since `totalEntries ≤ type(uint128).max` (L85, L219), the `uint128` cast does not truncate.
  - `totalEntries > 0`: `Drawing` is entered only at L252, behind `if (totalEntries == 0) revert` at L243.
  - `totalEntries` is frozen from then on. Its only writer is L230, inside `buyEntries`, which requires `Active`
    (L215).
  - Once `status != Drawing`, every callback takes the ignore branch (L510-L516), so neither `winningEntry` nor
    `status` is rewritten.
- **P4.** Each purchase sets `ticketId = ticketCount + 1` (L228), `firstEntry = totalEntries + 1` (L226) and
  `lastEntry = totalEntries + entryCount` (L227), with `entryCount ≥ 1` (L218). It then sets
  `totalEntries = lastEntry` (L230) and `++ticketCount` (L231).
  - So ticket k covers `[T(k-1)+1, T(k)]`, where T is strictly increasing from T(0) = 0. Every entry in
    `[1, totalEntries]` lies in exactly one ticket's range.
  - ID 0 and every ID above `ticketCount` read `(0, 0)` (IRaffle L369), which cannot contain an entry ≥ 1.
  - Ranges are never deleted: L232 is the only writer, and the L138 comment says they are kept after burns.
  - `buyEntries` is `nonReentrant` (L212). `_safeMint` mints and then calls the receiver (OZ ERC721 L287-L290); if
    that callback reverts, the range write at L232 is rolled back with it. A stored range therefore implies a mint.
- **Uniqueness.** P3 and P4 together mean exactly one `ticketId` passes L538. On every successful path, the caller's
  choice of `ticketId` has no freedom.
- **P5.** `unsettledPot` has three writers: L233 (`+=`), L297 (`= 0`) and L553 (`= 0`).
  - L233 adds `grossAmount = uint256(entryCount) * ENTRY_PRICE` (L223) in the same call that advances `totalEntries`
    by `entryCount` (L230).
  - L297 runs only in `enableRefunds`, which then sets `Refunding` (L299). None of the six status writers (L165,
    L205, L252, L299, L428, L521) runs from `Refunding`, so P2 rules out L297.
  - L553 is paired with L551 in the same call, so P1 rules it out.
  - Hence `grossPot = totalEntries * 1_000_000`. This equals `grossSales()` (L473-L475), which the function does
    not call.
- **P6.** The only nonzero writers of `winnerProceeds`, `sponsorProceeds` and `protocolFees` are L548, L554 and L555,
  all in this function. Their other writers set them to zero (L341, L378, L388). With P1, all three are zero on
  entry. This matters because L548/L554/L555 assign (`=`) rather than add (`+=`).
- **P8.** No `balanceOf` call exists anywhere in `src` (grep). This function allocates from the accounting variable
  only.
  - The only inflow is `buyEntries`, which calls `safeTransferFrom(msg.sender, this, grossAmount)` (L224) before
    crediting at L233.
  - The assumption that the clone receives exactly `grossAmount` rests on the quote-token trust statement (IRaffle
    L13-L14; Raffle L560-L561).
  - USDC sent to the clone outside `buyEntries` is never allocated, because L539 reads `unsettledPot`, not the
    balance.
- **P9.** The branch at L543 depends only on `status`, which L521 fixes as
  `totalEntries >= reserveEntries ? NftWon : CashWon`.
  - The sponsor supplies `reserveEntries` (RaffleFactory L118), and `_validateCreateParams` rejects only zero
    (RaffleFactory L178).
  - No upper bound appears in RaffleFactory L154-L179, in IRaffleFactory (L18, L39) or in DESIGN.md.
  - This function does not re-derive the outcome; it trusts `status`.
- **P10.** The callees are an internal view and an internal pure library function, so no external call happens and
  no reentry window opens.
  - Both callers are `nonReentrant` (L304, L309; OZ ReentrancyGuard L69-L73).
  - `rawFulfillRandomWords` (VRFV2PlusWrapperConsumerBase L101-L107) has no guard. It still cannot interleave,
    because there is no external call here, and after resolution it changes no state (L510-L516).

---

**Outputs & Effects:**

- **Return `cashAmount`.** On `NftWon` it is `0`: the named return is never assigned on that branch. On `CashWon` it
  is `floor(grossPot·8000/10_000)` (L546). `settleWinningTicket` returns it (L305). `redeemWinningTicket` discards it
  (L315) and reads `winnerProceeds` at L339 instead.
- **Storage writes.** All of them happen after every revert point:
  - L548 `winnerProceeds = cashAmount` (`CashWon` only)
  - L551 `settlementComplete = true`
  - L552 `winningTicketId = ticketId`
  - L553 `unsettledPot = 0`
  - L554 `sponsorProceeds = sponsorAmount`
  - L555 `protocolFees = protocolFee`
- **Not written:**
  - `status`, which stays `NftWon`/`CashWon`; both are terminal.
  - `winningEntry`, `resolvedAt`, `winnerRedeemed`, `prizeClaimed`, `remainingRefundLiability`.
  - The ticket ledger. Tickets remain transferable after settlement, because `_update` (L497-L502) has no status
    gate.
- **Event, L557.** `WinningTicketSettled(ticketId, settler = msg.sender, result, cashAmount, protocolFee,
  sponsorAmount)`, with `ticketId`, `settler` and `result` indexed (IRaffle L122-L129). This is the only on-chain
  record of who settled.
- **External interactions.** None: no token transfer, and no call to the prize contract, the VRF wrapper or the
  factory.
- **Revert surface.**
  - L534 `SettlementAlreadyComplete()`
  - L536 `InvalidStatus(result)`
  - L583 `TicketDoesNotContainWinningEntry(ticketId, winningEntry)`, reached through L538

  Nothing after L538 can revert:
  - `Math.mulDiv` takes its non-panicking path for every reachable input.
  - The checked subtractions at L544 and L547 cannot underflow (both shown in the Block-by-Block section).

  Out-of-gas is the only remaining failure.
- **Postconditions.**
  - **Q1.** `settlementComplete == true` permanently. L551 is its only writer and nothing resets it, so every later
    call reverts at L534.
  - **Q2.** `winningTicketId` is the unique ticket whose stored range contains `winningEntry` (P3, P4, and L538
    running before L552).
  - **Q3.** `protocolFee + sponsorAmount + cashAmount == grossPot` exactly, because `sponsorAmount` is computed as
    the remainder (L544, L547).
  - **Q4.** `accountedQuoteBalance()` (L469) is the same before and after the call.
    - Before, it equals `grossPot`, using P5-P7.
    - After, it equals `0 + 0 + cashAmount + sponsorAmount + protocolFee = grossPot`.
  - **Q5.** With `n = totalEntries ≥ 1` and `grossPot = n·1_000_000`:
    - `grossPot·500/10_000 = 50_000·n` and `grossPot·8000/10_000 = 800_000·n` are both integers, so neither floor
      discards anything.
    - `protocolFee = 50_000·n`.
    - On `NftWon`: `sponsorAmount = 950_000·n` and `cashAmount = 0`.
    - On `CashWon`: `cashAmount = 800_000·n` and `sponsorAmount = 150_000·n`.

    Every allocated amount is strictly positive.
- **Documentation consistency.** The documents describe rounding differently:
  - DESIGN.md L2 mentions flooring only on the protocol fee.
  - IRaffle L328 mentions flooring only on the cash-winner amount.
  - RaffleConstants L7-L8 and the code (L540, L546) floor both.

  Given Q5, the difference has no numeric effect for any reachable `grossPot`.

---

**Block-by-Block:**

```solidity
// L534
if (settlementComplete) revert SettlementAlreadyComplete();
```
- **What:** One-shot guard.
- **Why here:** It comes before every read and write. A second settlement therefore never reaches the plain
  assignments at L548, L554 and L555, which would otherwise overwrite balances that a release (L378, L388) or a
  redemption (L341) may already have zeroed and paid out.
- **Assumes:** `settlementComplete` has one writer (L551) and nothing resets it (grep).
- **Establishes:** P1; the body runs at most once per clone.
- **Depended on by:** P5, P6, Q4, and `redeemWinningTicket`'s branch at L314-L318. On the redeem path the guard is
  redundant, because L314 has already established `!settlementComplete`. It only fires on the
  `settleWinningTicket` path.

```solidity
// L535-L536
Status result = status;
if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```
- **What:** Restricts execution to the two resolved outcomes and caches which one applies.
- **Why here:** Every later line either branches on the outcome or emits it. The check also excludes:
  - `Refunding`, where the pot has already moved into `remainingRefundLiability` (L296-L298);
  - `AwaitingPrize`, `Active` and `Drawing`, where `winningEntry == 0`;
  - the implementation instance, whose constructor sets `status = Refunding` (L165).
- **Assumes:** `NftWon`/`CashWon` are written only at L521, immediately after L519. Both are terminal, because none
  of the status writers runs from them:
  - L205 sits behind the `initialized` lock (L177).
  - L252 requires `Active` (L241).
  - L299 requires `Active` or `Drawing` (L279-L294).
  - L428 requires `AwaitingPrize` (L422).
  - L521 requires `Drawing` (L511).
- **Establishes:** P2. `result` stays accurate for the rest of the call, since no external call intervenes.
- **Depended on by:** the L543 branch, the L557 event, P3, P5, P7.

```solidity
// L538  ->  _requireWinningTicket L579-L585  ->  ticketRange L451-L455
_requireWinningTicket(ticketId);
```
- **What:** Reverts unless `firstEntry ≤ winningEntry ≤ lastEntry` for `_ticketRanges[ticketId]` (L582-L584).
- **Why here:** It must run before `winningTicketId` is written at L552. It is the only link between the stored
  winner and the randomness.
- **Assumes:**
  - P3: `winningEntry ≥ 1`. This is what makes unminted IDs, which read `(0,0)`, fail.
  - P4: ranges are disjoint, which makes the passing ID unique.
  - It does not check that the ticket exists, that it has not been burned, or who owns it. It needs none of these to
    identify the winner, because ranges outlive burns (L138, IRaffle L369).
- **Establishes:** Q2.
- **Depended on by:**
  - L552.
  - `redeemWinningTicket` L316-L317, where later redemptions compare against the stored ID.
  - `redeemWinningTicket` L320. On the inline-settlement path, its `ownerOf(ticketId)` depends on `ticketId` having
    just been proven here.

```solidity
// L539-L541
uint256 grossPot = unsettledPot;
uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
uint256 sponsorAmount;
```
- **What:** Snapshots the pot and computes `protocolFee = floor(grossPot·500/10_000)`.
- **Why here:** The fee is computed once, on the whole pot rather than per ticket, which matches the "aggregate
  protocol fee" wording in DESIGN.md L2.
- **Assumes:** P5, so `grossPot = n·10^6`. `Math.mulDiv` takes its `high == 0` path (see the callee notes).
- **Establishes:** `protocolFee = 50_000·n ≤ grossPot`.
- **Depended on by:** L544, L547, L555, L557.

```solidity
// L543-L549
if (result == Status.NftWon) {
    sponsorAmount = grossPot - protocolFee;
} else {
    cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
    sponsorAmount = grossPot - protocolFee - cashAmount;
    winnerProceeds = cashAmount;
}
```
- **What:**
  - `NftWon`: the sponsor gets the remainder, 95%.
  - `CashWon`: the winner gets `floor(grossPot·80%)`, the sponsor gets the remainder (15%), and the winner liability
    is recorded.
- **Why here:** The sponsor share is computed last, as the remainder. That makes the three shares sum to `grossPot`
  exactly, whatever the floors discard.
- **Assumes:**
  - Arithmetic is checked: pragma `0.8.36` at L2, and no `unchecked` block exists in `src` (grep).
  - Underflow is impossible. `protocolFee ≤ 0.05·grossPot` and `cashAmount ≤ 0.8·grossPot`, so their sum is at most
    `0.85·grossPot`. The rates come from RaffleConstants L15 and L18 over L12.
  - The `else` branch can only mean `CashWon`, because of L536.
  - P6: `winnerProceeds` is 0 beforehand, since L548 assigns rather than adds.
- **Establishes:** Q3.
  - On `CashWon`, `winnerProceeds = 800_000·n > 0`.
  - On `NftWon`, `winnerProceeds` and `cashAmount` stay 0.
- **Depended on by:**
  - `redeemWinningTicket` L339-L342, which reads, zeroes and pays `winnerProceeds`. Its `NoWinnerProceeds` revert
    (L340) cannot fire on the first redemption after a `CashWon` settlement, because `n ≥ 1`.
  - L554, L557.

```solidity
// L551-L555
settlementComplete = true;
winningTicketId = ticketId;
unsettledPot = 0;
sponsorProceeds = sponsorAmount;
protocolFees = protocolFee;
```
- **What:** Closes settlement, records the winning ticket, empties the pot, and records the sponsor and treasury
  liabilities.
- **Why here:** These writes come after every check. The function makes no external call, so their order does not
  matter for reentrancy.
- **Assumes:**
  - P6: assigning to a zero balance is the same as crediting it.
  - P7: `remainingRefundLiability` is 0, so Q4 holds.
- **Establishes:** Q1, Q2, Q4. It also makes `releaseSponsorProceeds` and `releaseProtocolFees` callable exactly
  once each:
  - Both gate only on `amount != 0` (L377, L387).
  - Both zero the amount before transferring (L378 before L380, L388 before L390).
  - Nothing credits either amount again.
- **Depended on by:** L314 and L316 in `redeemWinningTicket`, L376-L380, L386-L390, and `accountedQuoteBalance()`
  (L469).

```solidity
// L557
emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
```
- **What:** Publishes the allocation.
- **Why here:** It comes after all writes, so the emitted values are the stored values.
- **Assumes:** nothing beyond the blocks above.
- **Establishes:** The off-chain record. `settler` is the redeemer on the redeem path and any caller on the settle
  path.
- **Depended on by:** indexers and frontends, which DESIGN.md L2 treats as advisory.

---

**Cross-Function Dependencies:**

Callees:

- **`_requireWinningTicket` (internal, Raffle.sol L579-L585).** Read in full; it has one path.
  - It reads `(firstEntry, lastEntry)` through `ticketRange` (L580) and `winningEntry` (L581). It reverts when
    `selectedEntry < firstEntry || selectedEntry > lastEntry` (L582-L584).
  - All three operands are `uint128`, so no width conversion happens.
  - What the caller relies on: it binds `ticketId` to `winningEntry`.
  - What it does **not** check: `ownerOf`, `ticketId ≤ ticketCount`, or `winningEntry != 0`.
  - Rejecting unminted IDs therefore rests entirely on P3, which is established at L518, outside both functions. If
    `winningEntry` were 0, every unminted ID (including ID 0) would pass, since `0 ≤ 0 ≤ 0`. That state cannot occur
    behind the L536 gate: `winningEntry` is 0 only before L519 runs, and L521 runs right after it.
- **`ticketRange` (internal call to a `public view`, Raffle.sol L451-L455).** Read in full.
  - It is a plain storage read with no revert path.
  - It returns `(0,0)` for IDs that were never written (IRaffle L369) and the historical range for burned IDs.
  - Its only writer is L232.
  - It is not `virtual`, and no contract in `src` derives from Raffle, so the call binds to this body.
- **`Math.mulDiv(uint256,uint256,uint256)` (external-source-available).** OpenZeppelin Contracts v5.6.0,
  `node_modules/@openzeppelin/contracts/utils/math/Math.sol` L206-L277, resolved through
  `packages/contracts/remappings.txt` L1. Read in full. It has three paths:
  - (a) `high == 0`: returns `low / denominator` (L211-L216). The division is checked, so it panics on a zero
    denominator even inside `unchecked` (comment at L212-L214).
  - (b) `denominator ≤ high`: panics (L219-L221).
  - (c) Otherwise: full 512-by-256 division (L228-L276).

  For both calls here:
  - `x = grossPot ≤ (2^128 − 1)·10^6 < 2^148`, `y ∈ {500, 8000} < 2^13`, and `denominator = 10_000`.
  - So `x·y < 2^161`, `mul512` (L37-L46) returns `high = 0`, and only path (a) runs. Paths (b) and (c) cannot be
    reached with these inputs.

  What the caller relies on: the result is `floor(x·y/10_000)`, which is at most `x·y/10_000` and therefore less
  than `x`. That bound is what keeps the checked subtractions at L544 and L547 from underflowing.
- **No external-black-box callees.** The function sends no calldata and no value to any address.

Callers:

- **`settleWinningTicket` (L304-L306).** `external`, `nonReentrant`, permissionless, with no checks of its own.
  - It relies on this function for every guard (P1, P2 and the range check), passes `ticketId` through unchanged,
    and returns `cashAmount`.
  - Who calls it changes no stored value, only the event's `settler`, because the only free input has exactly one
    accepted value (P3, P4).
- **`redeemWinningTicket` (L309-L346).** `external`, `nonReentrant`.
  - Before calling, it checks `!winnerRedeemed` (L310) and the status (L311-L312, duplicating L535-L536).
  - It calls this function only when `!settlementComplete` (L314-L315). Otherwise it requires
    `ticketId == winningTicketId` (L316-L318). Either way, the `ticketId` that reaches L320 is the unique winning
    ticket.
  - It relies on this function for two things: the range proof of `ticketId` before the `ownerOf` check
    (L320-L321), and `winnerProceeds` being set on `CashWon` before L339 reads it.
  - It discards the return value at L315.
  - If any later step reverts, the inline settlement reverts with it. Those steps are the ownership check (L321),
    the burn (L325), NFT delivery (L334-L337), and `_transferQuote` (L342, including its destination screen at
    L565).
  - `winnerRedeemed` implies `settlementComplete`, because L324 can only be reached after L314-L318. This function
    therefore needs no `winnerRedeemed` check of its own.

Shared state:

| Variable | Read here | Written here | Other writers / readers |
|---|---|---|---|
| `settlementComplete` | L534 | L551 (sole writer) | read L314 |
| `status` | L535 | — | written L165, L205, L252, L299, L428, L521 |
| `winningEntry` | L581 (callee) | — | sole writer L519 |
| `_ticketRanges` | L452 (callee) | — | sole writer L232; read L362 (refunds) |
| `unsettledPot` | L539 | L553 | L233 (`+=`), L296-L297, L469 |
| `winnerProceeds` | — | L548 (sole nonzero writer) | L339-L341, L469 |
| `sponsorProceeds` | — | L554 (sole nonzero writer) | L376-L378, L469 |
| `protocolFees` | — | L555 (sole nonzero writer) | L386-L388, L469 |
| `winningTicketId` | — | L552 (sole writer) | read L316-L317 |

Invariant couplings:

- **Conservation (`accountedQuoteBalance()`, L469).** Settlement only reclassifies the pot; the total does not change
  (Q4). After settlement the total falls only through three payouts: L341/L342, L378/L380 and L388/L390. Each zeroes
  its variable before paying.
- **Balance coverage.** The system context expects `quoteToken.balanceOf(clone) ≥ accountedQuoteBalance()`.
  Settlement neither reads nor moves the token balance, and nothing on-chain enforces the relation (P8).
- **Releases happen exactly once.** The release functions are not status-gated. They become callable only because
  L554 and L555 write nonzero values, and those writes happen once (L534/L551). In `Refunding`, neither variable is
  ever credited.
- **Winner claim path.**
  - After a `CashWon` settlement, `winnerProceeds` has one consumer: `redeemWinningTicket` L339-L342. It pays
    whoever is `ownerOf(winningTicketId)` at redemption time (L320).
  - There is no deadline and no other claimant.
  - Settlement records a ticket, not an address, and the ticket stays transferable until it is burned (L497-L502,
    L325).
- **Prize custody.** Settlement does not touch `prizeClaimed`.
  - On `NftWon`, only `redeemWinningTicket` releases the prize, because `releaseSponsorPrize` rejects `NftWon`
    (L397).
  - On `CashWon`, `releaseSponsorPrize` works before or after settlement (L397). The two are independent.
- **Outcome selection.** The 95/5 or 80/15/5 split is chosen by `status` (L543). L521 fixes `status` from the
  sponsor-chosen `reserveEntries` (no upper bound found) and the buyer-driven `totalEntries`.
- **VRF callback.** `rawFulfillRandomWords` is not `nonReentrant`. Once the raffle is resolved, though, it returns
  through L510-L516 without writing anything. Every input to settlement (`winningEntry`, `status`, `totalEntries`,
  ticket ranges) is therefore frozen by the time settlement becomes callable.
- **Implementation instance.** Its `status` is `Refunding` (L165), so the call always reverts at L536 there.

---

**Open Questions:**

- unclear; need to inspect the deployed canonical USDC (the proxy and its current implementation) to confirm that
  the clone's real balance matches `unsettledPot` at L539. Settlement allocates from the accounting variable only;
  no code in `src` reads `balanceOf`, and nothing compares the two.
- unclear; need to inspect product requirements for an intended upper bound on `reserveEntries`. Only `!= 0` is
  enforced (RaffleFactory L178), and DESIGN.md L2 does not mention one. As it stands, the sponsor decides at creation
  whether the `NftWon` branch at L543 can ever be reached.
