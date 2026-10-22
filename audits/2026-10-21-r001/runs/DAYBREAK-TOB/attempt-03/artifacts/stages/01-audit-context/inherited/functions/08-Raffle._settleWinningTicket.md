## `_settleWinningTicket` in `target/packages/contracts/src/Raffle.sol` (L533-L558)

**Purpose:** Proves that a caller-supplied historical ticket range contains the already selected winning entry, then performs the one-time, storage-only transformation of `unsettledPot` into terminal winner, sponsor, and protocol liabilities (`Raffle.sol:L528-L557`). It is the common allocation core for permissionless standalone settlement and settlement performed as the first part of winner redemption (`Raffle.sol:L304-L305`, `L309-L318`). It neither checks ticket ownership nor transfers an asset; ownership and delivery belong to the later portion of `redeemWinningTicket` (`Raffle.sol:L320-L345`).

**Inputs & Assumptions:**

- `ticketId` (`uint256`): a caller-selected ticket identifier. Trust: **untrusted**. It enters through either public `settleWinningTicket` (`Raffle.sol:L304-L305`) or public `redeemWinningTicket` (`Raffle.sol:L309-L315`).
- Implicit `msg.sender`: unrestricted caller identity. It does not authorize settlement and is used only as the `settler` field of `WinningTicketSettled` (`Raffle.sol:L557`; `IRaffle.sol:L115-L129`).
- Implicit persistent inputs: `settlementComplete`, `status`, `winningEntry`, `_ticketRanges[ticketId]`, and `unsettledPot` (`Raffle.sol:L91`, `L118-L127`, `L138-L139`, `L534-L540`, `L579-L584`).
- Precondition: terminal liabilities have not already been allocated. Established locally by the `settlementComplete` rejection at `Raffle.sol:L534`; only this function sets that flag (`Raffle.sol:L551`).
- Precondition: the raffle has a resolved economic result, exactly `NftWon` or `CashWon`. Established locally by `Raffle.sol:L535-L536`. Within this contract, those two values are written when an accepted callback derives `winningEntry` and then selects the result from `totalEntries >= reserveEntries` (`Raffle.sol:L509-L523`); the other status writes select `Refunding`, `AwaitingPrize`, `Drawing`, or `Active` (`Raffle.sol:L165`, `L205`, `L252`, `L299`, `L428`).
- Precondition: the supplied historical range contains `winningEntry`. Established by `_requireWinningTicket` (`Raffle.sol:L538`, `L579-L584`) after `ticketRange` loads the stored endpoints (`Raffle.sol:L451-L455`).
- Assumption: `unsettledPot` represents the recorded gross proceeds for every sold entry on a reachable terminal-result path. Each successful purchase computes `entryCount * ENTRY_PRICE`, transfers that amount in, advances the global range, and adds the same amount to `unsettledPot` (`Raffle.sol:L223-L233`). A draw requires at least one entry and moves the status out of `Active` (`Raffle.sol:L241-L253`), while purchases require `Active` (`Raffle.sol:L215`); therefore no later purchase changes the pot before the callback selects a terminal result (`Raffle.sol:L509-L523`). The one other pre-settlement consumer moves the pot to refunds and changes status to `Refunding`, which the local terminal-status guard rejects (`Raffle.sol:L296-L300`, `L535-L536`).
- Assumption: the recorded pot is backed one-for-one by the configured quote token. The purchase orders the token transfer before increasing the pot (`Raffle.sol:L223-L233`), and the interface explicitly trusts canonical, standard, fee-free, non-rebasing quote-token behavior (`IRaffle.sol:L12-L15`). This function does not query the token balance.

**Reachable range proof:**

- A purchase requires a positive `entryCount` and rejects any addition beyond `uint128` (`Raffle.sol:L218-L221`). From previous `totalEntries = T`, it records `[T+1, T+entryCount]`, assigns the next sequential ticket ID, then advances `totalEntries` to the new last entry (`Raffle.sol:L226-L233`). Consequently, successful purchases create nonempty, adjacent, non-overlapping historical ranges covering `1..totalEntries`.
- Draw initiation rejects `totalEntries == 0` (`Raffle.sol:L241-L244`). An accepted callback computes `(randomWord % totalEntries) + 1`, so the selected entry is in `1..totalEntries`, stores it, and only then writes a terminal status (`Raffle.sol:L509-L523`).
- `ticketRange` returns the mapping endpoints, including `(0,0)` for an identifier never written (`Raffle.sol:L451-L455`; `IRaffle.sol:L368-L373`). Since a terminal-path `winningEntry` is at least one, the inclusive comparison rejects that zero range (`Raffle.sol:L580-L584`). Because the purchase ranges are disjoint, exactly one recorded range can pass for the selected entry.
- Ticket transfers route through `_update` but do not change `_ticketRanges` (`Raffle.sol:L497-L502`); the mapping is only written during purchase (`Raffle.sol:L232`). Refund burns are restricted to `Refunding` (`Raffle.sol:L349-L365`), a status rejected here, and a redemption burn happens only after this helper returns (`Raffle.sol:L314-L325`). Thus standalone settlement intentionally proves the range without depending on current ownership.

**Reachable amount bounds and allocation math:**

- `ENTRY_PRICE` is `1,000,000`, and `totalEntries` is bounded by `type(uint128).max` through the purchase check (`RaffleConstants.sol:L20-L21`; `Raffle.sol:L219-L230`). On an eligible path, `grossPot = totalEntries * ENTRY_PRICE`, so `0 < grossPot <= (2^128 - 1) * 1,000,000 < 2^148`. Multiplying it by either rate remains below `2^161`, so the products fit in `uint256`.
- `Math.mulDiv` computes floor division with full precision (`Math.sol:L199-L206`); for the reachable products its `high == 0` path returns `low / denominator` (`Math.sol:L208-L216`). `BPS` is nonzero `10,000`, the protocol rate is `500`, and the cash-winner rate is `8,000` (`RaffleConstants.sol:L11-L18`).
- Let `G = grossPot`, `F = floor(G * 500 / 10,000)`, and, on `CashWon`, `W = floor(G * 8,000 / 10,000)`. The NFT branch assigns `S = G - F`; the cash branch assigns `S = G - F - W` (`Raffle.sol:L540-L548`). Since the rates sum to at most `8,500 / 10,000`, both checked subtractions are in range. Both branches conserve the pot exactly: NFT `F + S = G`; cash `F + W + S = G`.
- Reachable `G` is a multiple of `ENTRY_PRICE`, and `1,000,000` is divisible by `10,000` (`RaffleConstants.sol:L11-L21`; `Raffle.sol:L223-L233`). Therefore the reachable allocations have no fractional raw-unit remainder: per sold entry the protocol allocation is `50,000`, the cash-winner allocation is `800,000` on `CashWon`, and sponsor allocation is respectively `950,000` on `NftWon` or `150,000` on `CashWon`. The sponsor is nevertheless coded as the residual claimant (`Raffle.sol:L543-L548`), so the conservation equations also hold for any integer `G` for which the function executes.

---

**Outputs & Effects:**

- Returns `cashAmount = 0` on `NftWon`, because the named return value is never assigned on that branch (`Raffle.sol:L533`, `L543-L545`). Returns `floor(grossPot * 8,000 / 10,000)` on `CashWon` (`Raffle.sol:L545-L549`).
- On `CashWon`, writes `winnerProceeds = cashAmount`; on `NftWon`, it does not write `winnerProceeds` (`Raffle.sol:L543-L549`).
- On either success branch, writes `settlementComplete = true`, records `winningTicketId = ticketId`, clears `unsettledPot`, and assigns the complete sponsor and protocol liabilities (`Raffle.sol:L551-L555`).
- Emits `WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount)` after every storage write (`Raffle.sol:L557`; `IRaffle.sol:L115-L129`).
- Does not change `status`, `winningEntry`, any ticket range, or ERC-721 ownership (`Raffle.sol:L533-L558`).
- Makes no external call and transfers no ERC-20 or ERC-721 asset (`Raffle.sol:L533-L558`). The resulting liabilities are consumed later by `redeemWinningTicket`, `releaseSponsorProceeds`, and `releaseProtocolFees` (`Raffle.sol:L339-L342`, `L375-L391`).
- Postcondition: exactly one of the following liability identities replaces `unsettledPot`: `protocolFees + sponsorProceeds = grossPot` for `NftWon`, or `winnerProceeds + sponsorProceeds + protocolFees = grossPot` for `CashWon` (`Raffle.sol:L543-L555`). This preserves the total reported by `accountedQuoteBalance` across the allocation step (`Raffle.sol:L468-L470`).
- Every rejection occurs before the success-path writes: already settled at `L534`, nonterminal status at `L535-L536`, or range mismatch inside `L538` / `L579-L584`.

---

**Block-by-Block:**

```solidity
// Raffle.sol:L534-L536
if (settlementComplete) revert SettlementAlreadyComplete();
Status result = status;
if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```

- **What:** Enforces one-time allocation and snapshots a permitted terminal result.
- **Why here:** Both checks precede the ticket proof, arithmetic, state writes, and event, so rejected calls have no settlement effect (`Raffle.sol:L534-L557`). The snapshot is then used consistently for the branch and event (`Raffle.sol:L543`, `L557`).
- **Assumes:** terminal status was paired with a valid `winningEntry` by callback resolution.
- **Established by:** the accepted-callback path writes `winningEntry` before terminal `status` (`Raffle.sol:L518-L523`), and no other status assignment writes `NftWon` or `CashWon` (`Raffle.sol:L165`, `L205`, `L252`, `L299`, `L428`).
- **Depended on by:** the economic branch at `L543-L549`, the permanent completion mark at `L551`, and the emitted `result` at `L557`.

```solidity
// Raffle.sol:L538
_requireWinningTicket(ticketId);
```

- **What:** Requires the candidate ticket's inclusive historical range to contain the selected entry.
- **Why here:** It rejects an incorrect proof before reading and reallocating the pot (`Raffle.sol:L538-L555`).
- **Assumes:** `ticketRange(ticketId)` reflects the sequential purchase ledger and `winningEntry` belongs to the covered global entry domain.
- **Established by:** positive, overflow-bounded purchases write sequential ranges (`Raffle.sol:L218-L233`), while the accepted callback chooses `winningEntry` in `1..totalEntries` (`Raffle.sol:L518-L523`).
- **Depended on by:** `winningTicketId = ticketId` at `L552`, and the later redemption equality/ownership path at `L314-L325`.

The complete callee path is:

```solidity
// Raffle.sol:L579-L585
function _requireWinningTicket(uint256 ticketId) private view {
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    uint128 selectedEntry = winningEntry;
    if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
        revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
    }
}
```

`ticketRange` performs only a mapping read and returns both stored endpoints (`Raffle.sol:L451-L455`). The helper's single success path establishes the inclusive predicate `firstEntry <= winningEntry <= lastEntry`; its mismatch path reverts (`Raffle.sol:L579-L584`). It does not establish current ownership or ERC-721 existence, and its caller does not depend on either property during allocation (`Raffle.sol:L528-L532`).

```solidity
// Raffle.sol:L539-L541
uint256 grossPot = unsettledPot;
uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
uint256 sponsorAmount;
```

- **What:** Snapshots the complete unallocated pot and computes the floor-rounded 5% protocol liability.
- **Why here:** Validation is complete before accounting begins; the shared `protocolFee` is computed once for both result branches (`Raffle.sol:L534-L547`).
- **Assumes:** the pot is the backed gross-sale liability and `Math.mulDiv` returns the floor without reverting for these operands.
- **Established by:** the purchase/status flow described above (`Raffle.sol:L215-L233`, `L241-L253`, `L509-L523`), the quote-token trust model (`IRaffle.sol:L12-L15`), fixed nonzero denominator/rate constants (`RaffleConstants.sol:L11-L18`), and the vendored full-precision implementation (`Math.sol:L199-L220`).
- **Depended on by:** both sponsor-remainder formulas (`Raffle.sol:L543-L547`) and `protocolFees = protocolFee` (`Raffle.sol:L555`).

```solidity
// Raffle.sol:L543-L549
if (result == Status.NftWon) {
    sponsorAmount = grossPot - protocolFee;
} else {
    cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
    sponsorAmount = grossPot - protocolFee - cashAmount;
    winnerProceeds = cashAmount;
}
```

- **What:** For `NftWon`, assigns all non-fee quote proceeds to the sponsor. For `CashWon`, additionally assigns the floor-rounded 80% winner liability and gives the sponsor the residual.
- **Why here:** The mutually exclusive terminal result fixes which liability set is created, while residual calculation makes the allocated values sum to the original pot (`Raffle.sol:L543-L548`).
- **Assumes:** the protocol and cash rates together do not exceed the denominator.
- **Established by:** `500 + 8,000 <= 10,000` in the fixed constants (`RaffleConstants.sol:L11-L18`) and floor semantics of `Math.mulDiv` (`Math.sol:L199-L206`).
- **Establishes:** `cashAmount == 0` with no winner-liability write for `NftWon`; for `CashWon`, `winnerProceeds == cashAmount`; and in both cases the branch allocations plus the protocol fee equal `grossPot` (`Raffle.sol:L543-L549`).
- **Depended on by:** redemption's cash read/zero/transfer (`Raffle.sol:L339-L342`), sponsor release (`Raffle.sol:L375-L381`), and the terminal writes/event below (`Raffle.sol:L551-L557`).

```solidity
// Raffle.sol:L551-L555
settlementComplete = true;
winningTicketId = ticketId;
unsettledPot = 0;
sponsorProceeds = sponsorAmount;
protocolFees = protocolFee;
```

- **What:** Commits proof identity, closes repeat settlement, removes the unallocated bucket, and publishes the two common liabilities.
- **Why here:** All reverting validation and arithmetic precede the commit (`Raffle.sol:L534-L549`); after these writes, no external interaction occurs in this function (`Raffle.sol:L551-L558`).
- **Assumes:** no previous allocation exists; this was enforced at `L534`.
- **Establishes:** `settlementComplete == true`, a durable winning-ticket ID, `unsettledPot == 0`, and terminal liability buckets whose sum replaces the pot (`Raffle.sol:L551-L555`).
- **Depended on by:** redemption either skips repeat settlement or rejects a different ID (`Raffle.sol:L314-L318`), and the three independent claim paths consume their corresponding buckets (`Raffle.sol:L339-L342`, `L375-L391`).

```solidity
// Raffle.sol:L557
emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
```

- **What:** Records the proven ID, permissionless settler, terminal result, and all three computed amounts.
- **Why here:** The log is emitted only after every settlement storage write (`Raffle.sol:L551-L557`).
- **Assumes:** event consumers interpret `cashAmount == 0` as the NFT branch, matching the interface declaration (`IRaffle.sol:L115-L129`).
- **Establishes:** an observable record matching the values assigned in this transaction (`Raffle.sol:L543-L557`).
- **Depended on by:** off-chain consumers; no on-chain function reads the event.

---

**Cross-Function Dependencies:**

- **Callee `_requireWinningTicket` (internal, `Raffle.sol:L579-L585`):** Read in full. It depends on `ticketRange` to return stored endpoints, then establishes only that `winningEntry` lies inclusively between them (`Raffle.sol:L580-L584`). It does not check ownership, mint status, or ticket existence.
- **Callee `ticketRange` (internal call to public source-available function, `Raffle.sol:L451-L455`):** Read in full. It returns `_ticketRanges[ticketId]` without validation. An unwritten ID returns zero endpoints per the interface contract (`IRaffle.sol:L368-L373`), which the terminal winning entry cannot satisfy (`Raffle.sol:L518`, `L582-L584`).
- **Callee `Math.mulDiv` (external-source-available vendored library, `Math.sol:L199-L277`):** Read through every path. It computes floor `x*y/denominator` using a 512-bit product, directly divides when the high limb is zero, and otherwise performs exact 512-by-256 division after rejecting a zero denominator or an overflowing result (`Math.sol:L206-L276`). This caller supplies a fixed nonzero denominator and reachable products below `2^256`, so it depends on the direct floor-division behavior (`RaffleConstants.sol:L11-L18`; `Math.sol:L208-L216`). It is called once on `NftWon` and twice on `CashWon` (`Raffle.sol:L540`, `L543-L547`).
- **Caller `settleWinningTicket` (`Raffle.sol:L304-L306`):** Any external caller reaches the private helper through a `nonReentrant` wrapper and receives its returned `cashAmount`. The wrapper adds no authorization or validation.
- **Caller `redeemWinningTicket` (`Raffle.sol:L309-L346`):** A caller in a terminal status invokes this helper only while `settlementComplete == false` (`Raffle.sol:L310-L315`). After it returns, redemption resolves `ownerOf(ticketId)` and requires the caller to be that owner (`Raffle.sol:L320-L321`), then burns and delivers the appropriate claim (`Raffle.sol:L323-L345`). If any later ownership or delivery step reverts, the earlier settlement writes and event in the same transaction also revert. If settlement was already complete, redemption instead requires `ticketId == winningTicketId` (`Raffle.sol:L314-L318`).
- **Upstream callback `fulfillRandomWords` (`Raffle.sol:L509-L524`):** Supplies the terminal-state/selected-entry pairing this function consumes. Its external inherited gateway accepts calls only from the configured wrapper (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`), and the handler accepts only the recorded request in `Drawing`, with one word, before the deadline, and outside the request call (`Raffle.sol:L509-L516`). Its success path bounds and stores the entry before storing the outcome (`Raffle.sol:L518-L523`).
- **Upstream purchase `buyEntries` (`Raffle.sol:L209-L237`):** Establishes the contiguous historical range ledger and the pot/entry-count relation used by the proof and arithmetic. It validates status, time, nonzero quantity, and `uint128` capacity before computing, transferring, and recording (`Raffle.sol:L215-L235`).
- **Shared state — `status`:** This function reads but does not write it (`Raffle.sol:L535-L536`). Callback resolution writes the eligible terminal values (`Raffle.sol:L518-L523`); redemption and sponsor-prize release use those values to select claim behavior (`Raffle.sol:L311-L312`, `L329-L343`, `L395-L405`).
- **Shared state — `winningEntry` and `_ticketRanges`:** Callback resolution writes `winningEntry` (`Raffle.sol:L518-L520`); purchases write ranges (`Raffle.sol:L226-L233`); this function reads both through the proof helper (`Raffle.sol:L538`, `L579-L584`). Ticket transfers and burns do not delete the historical range mapping (`Raffle.sol:L138-L139`, `L497-L502`).
- **Shared state — `unsettledPot`:** Purchases add gross amounts (`Raffle.sol:L223-L233`); refunds activation can move the whole value to `remainingRefundLiability` (`Raffle.sol:L296-L299`); this function instead moves it into terminal allocations (`Raffle.sol:L539-L555`). `accountedQuoteBalance` includes all of these buckets (`Raffle.sol:L468-L470`).
- **Shared state — `settlementComplete` and `winningTicketId`:** Only this function writes them (`Raffle.sol:L551-L552`). Redemption reads them to decide whether to call this helper and to bind later redemptions to the recorded ID (`Raffle.sol:L314-L318`).
- **Shared state — `winnerProceeds`:** The cash branch writes it (`Raffle.sol:L545-L549`); successful cash redemption reads, clears, and transfers it (`Raffle.sol:L338-L343`); the accounting view includes it (`Raffle.sol:L468-L470`).
- **Shared state — `sponsorProceeds`:** Both success branches assign it (`Raffle.sol:L543-L554`); `releaseSponsorProceeds` reads and clears it before payment (`Raffle.sol:L375-L381`); the accounting view includes it (`Raffle.sol:L468-L470`).
- **Shared state — `protocolFees`:** Both success branches assign it (`Raffle.sol:L540-L555`); `releaseProtocolFees` reads and clears it before payment (`Raffle.sol:L385-L391`); the accounting view includes it (`Raffle.sol:L468-L470`).
- **Invariant coupling:** On a terminal result before settlement, the recorded pot is the sole terminal quote liability. A successful call clears that bucket and creates claims summing to the identical amount (`Raffle.sol:L539-L555`). The release/redemption functions subsequently clear one claim before its external transfer (`Raffle.sol:L339-L342`, `L375-L390`), while `accountedQuoteBalance` reports the sum of the still-live buckets (`Raffle.sol:L468-L470`).

---

**Open Questions:**

- None within the permitted source scope. The quote token's fee-free, non-rebasing transfer behavior is an explicit trusted dependency rather than a property established by this function (`IRaffle.sol:L12-L15`; `Raffle.sol:L223-L233`).
