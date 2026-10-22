# Lens 4: Liquidation, Bad Debt & Solvency. raffle.fun (Raffle clone + RaffleFactory)

**How the lens maps here.** There is no lending, leverage or health factor in this protocol, so I worked the closest equivalents:
- **"Liquidation"** means the forced terminal exits: `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize` and `enableRefunds`.
- **"Bad debt"** means a liability that is recorded or owed but can never reach its rightful owner.
- **"Blocked liquidation"** means an untrusted hook that makes one terminal exit revert while the matching payment on the other side still goes out.

Line numbers refer to `packages/contracts/src/Raffle.sol` unless prefixed `F:` (`RaffleFactory.sol`) or `I:` (`interfaces/IRaffle.sol`).

**Result:** 1 FINDING, 4 LEADs. USDC accounting is exact and conserved in every lifecycle. The one way the solvency/liveness invariant breaks is through the NFT leg in `NftWon`.

---

## FINDINGS

```
FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payment-released-without-delivery | group_key: Raffle | releaseSponsorProceeds | payment-released-without-delivery
root_cause: Raffle.sol:375-378 `releaseSponsorProceeds()` pays out the NftWon sponsor allocation (95% of the pot). `_settleWinningTicket` makes that allocation claimable at settlement (Raffle.sol:543-544, 554). The only guard is `amount == 0` at :377. No `prizeClaimed` (delivery) check is performed. The same gap exists in `releaseProtocolFees()` at Raffle.sol:385-388 for the 5% fee. NftWon also has no way out to refunds: `enableRefunds` reverts for every status except Active and Drawing (Raffle.sol:292-293), and `releaseSponsorPrize` rejects NftWon (Raffle.sol:397-398). So payment and delivery are decoupled. If the prize contract stops honouring the clone's own `transferFrom(raffle -> winner)` at Raffle.sol:334, or the `ownerOf` re-check at :335 fails, every redemption reverts. Meanwhile the sponsor and the treasury are paid in full.
internal_pre: Raffle resolved as NftWon (totalEntries >= reserveEntries when the sale ends; Raffle.sol:521).
external_pre: After escrow, the prize ERC-721 refuses or redirects the clone's transfer of the prize. Possible causes: the collection admin pauses transfers, applies a transfer restriction (operator, owner-initiated or account freeze that hits the clone), or upgrades the collection. A third possibility is a sponsor-controlled collection whose admin seizes or locks the token. DESIGN.md: "arbitrary prize contracts ... are untrusted". The pause and transfer-restriction behaviours are general ERC-721 ecosystem facts, not code vendored in this repo.
path:
  1. Sponsor S calls F:createRaffle for X#42, where S either is the admin of collection X or holds a token in a pausable or transfer-restricted collection. reserveEntries = 10,000, endTime = T. The escrow checks at F:128-134 pass because X behaves normally at deposit time.
  2. Buyers buy 12,000 entries for 12,000 USDC. Alice holds ticket #57, covering entries 6,001-7,000. unsettledPot = 12,000e6.
  3. At T anyone calls requestDraw (Raffle.sol:240). The callback sets winningEntry = 6,500 and status = NftWon (Raffle.sol:518-521).
  4. X#42 becomes non-transferable out of the clone: S's admin seizes or locks it, or X is paused or restricted. S can do this right after T, before the draw. Once the sale has ended with totalEntries >= reserve, NftWon is already certain. Buyers cannot reach refunds before T+2d (Raffle.sol:286-287), and anyone, including S, can request the draw in [T, T+2d).
  5. Anyone calls settleWinningTicket(57). This sets sponsorProceeds = 11,400e6 and protocolFees = 600e6 (Raffle.sol:540-555).
  6. Anyone calls releaseSponsorProceeds(), which pays 11,400 USDC to S's sponsorRecipient. releaseProtocolFees() pays 600 USDC to the treasury.
  7. Alice calls redeemWinningTicket(57). prizeToken.transferFrom(raffle, Alice, 42) reverts, or the ownerOf check at :335 fails, so the whole call reverts. enableRefunds() reverts with InvalidStatus(NftWon) and releaseSponsorPrize() reverts with SponsorPrizeUnavailable(NftWon). Nothing can ever be paid to Alice.
impact: The winning-ticket holder bears the whole loss. That is Alice, or anyone who bought the winning ticket on the secondary market at roughly the NFT's value. The NFT she won can never be delivered, and NftWon is terminal with no refund or cash fallback. Meanwhile 100% of the buyers' 12,000 USDC has already gone out: 11,400 to the sponsor recipient and 600 to the treasury. In the seize variant, where S controls the prize contract, S keeps both the NFT and the 11,400 USDC. This breaks money-map invariants 7 (the prize leaves exactly once, to the winner in NftWon) and 15 (every claimant can eventually collect). Suggested severity: Medium, because it depends on an external pre-condition on the prize contract.
mitigation: In releaseSponsorProceeds(), and likewise in releaseProtocolFees(), add `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();` so the NftWon allocation is paid only against actual delivery. Optionally pair this with an NftWon delivery deadline that turns an undeliverable prize into refunds, so the gated pot cannot be stranded either.
```

---

## LEADS

```
LEAD | contract: Raffle | function: _update | bug_class: informed-ticket-trading-during-draw | group_key: Raffle | _update | informed-ticket-trading-during-draw
smell: Tickets stay transferable in Drawing. `_update` (Raffle.sol:497-502) screens only the destination, never the status. The VRF callback (Raffle.sol:518-521) is the only state change between "random word exists" and "winner recorded". Anyone who can read a pending fulfillment can compute winningEntry = word % totalEntries + 1 before it lands. They can then buy the winning ticket from an open listing, taking the prize from the seller, or sell losing tickets into open collection offers, passing the loss to the bidder. This is the Phase-4 pattern of joining just before a distribution or leaving just before a loss.
unverified: Two things are unverified. First, whether VRF v2.5 fulfillment transactions on the target chain are visible in a public mempool before inclusion; the wrapper/coordinator source is not vendored under packages/contracts. Second, whether ticket listings or offers exist on any marketplace during Drawing.
description: If fulfillment calldata is public before inclusion, a searcher can bundle a fill of the listed winning ticket ahead of the callback and take the NFT or the 80% cash from the seller. Blocking ticket transfers while status == Drawing would close the window.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: reserve-flip-by-sponsor-top-up | group_key: Raffle | fulfillRandomWords | reserve-flip-by-sponsor-top-up
smell: The outcome predicate `totalEntries >= reserveEntries` (Raffle.sol:521) counts the sponsor's own entries. In NftWon the sponsor gets back 95% of whatever it paid in (Raffle.sol:544). So the sponsor can meet its own reserve at about 5% cost and turn a CashWon (80% of the pot to a buyer) into an NftWon whenever the NFT is worth less than the cash prize. Worked example (arithmetic checked): reserve 1,000; buyers hold 900 entries; the NFT is worth 500 USDC. If the sponsor buys 100 entries before endTime, the sponsor's expected value rises by 265 USDC, the buyers' falls by 270 USDC and the treasury gains 5.
unverified: Whether this is an accepted mechanism-design property. The reserve is public, any party can push the total over it, and the sponsor can buy from fresh addresses, so there is no on-chain fix.
description: Buying the reserve shortfall with the sponsor's own money lets the sponsor pick the outcome branch that is worse for buyers. This is probably accepted design and is reported only for calibration.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: codeless-destination-screen-bypass | group_key: Raffle | releaseSponsorPrize | codeless-destination-screen-bypass
smell: `_isProtocolDestination` only queries `isRaffle` when `destination.code.length != 0` (Raffle.sol:602-604). Clones are deployed with CREATE from the factory (OZ Clones.clone), so their addresses are predictable from the factory nonce. A sponsorRecipient set to a not-yet-deployed clone address therefore passes F:_validateCreateParams (F:163-169) and initialize (Raffle.sol:193-195). The same applies to a ticket sent to such an address. Once that clone exists, releaseSponsorProceeds reverts with InvalidQuoteDestination forever (Raffle.sol:565). releaseSponsorPrize has no runtime screen at all, so it moves the prize into the other clone via transferFrom (Raffle.sol:402-405). This contradicts DESIGN.md: "Never move assets between raffle clones".
unverified: Any victim other than the party that chose the address. The recipient is chosen by the sponsor and ticket transfers are started by the owner, so every path found is self-harm.
description: Informational only; no third-party loss path was found. Calling `_isProtocolDestination(recipient, address(prizeToken))` in releaseSponsorPrize would match the check `_transferQuote` already makes.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: empty-raffle-cancel-griefing | group_key: Raffle | enableRefunds | empty-raffle-cancel-griefing
smell: The sponsor can only cancel early while `totalEntries == 0` (Raffle.sol:280-284). Anyone can front-run the cancel with buyEntries(griefer, 1) for 1 USDC. After that, the call requires now >= endTime + 2 days (Raffle.sol:286-287).
unverified: Material loss. The griefer's 1 USDC comes back in full (refund) or 80% (CashWon). The sponsor's NFT stays escrowed only within a window the sponsor chose (at most 30 days plus 2), so the harm is opportunity cost.
description: Low-impact denial of the sponsor's early-exit right at the cost of gas. Noted for completeness.
```

---

## Public audit-evidence summaries

### Value flows and tracked totals (Model)
- **[Model: buyEntries]** The buyer pays `entryCount × 1e6` USDC (Raffle.sol:223-224) and gets one ticket for `[totalEntries+1, totalEntries+entryCount]` (:226-232). `unsettledPot += grossAmount` (:233) is the only pot increase and uses the same amount as the only USDC inflow.
- **[Model: enableRefunds]** Moves the whole pot into `remainingRefundLiability` and sets status to Refunding (:296-299). No assets move.
- **[Model: _settleWinningTicket]** Splits the pot once and only in storage:
  - fee = pot·500/1e4;
  - NftWon: sponsor = pot − fee;
  - CashWon: cash = pot·8000/1e4, and the sponsor gets the remainder.
  - It then zeroes `unsettledPot` (:539-555).
- **[Model: refundTickets]** Burns 1–100 tickets owned by the caller and pays Σ(range)·1e6. `remainingRefundLiability` drops by exactly the amount paid (:357-369).
- **[Model: redeemWinningTicket]** The current owner of the winning ticket burns it and receives the NFT (NftWon, :329-337) or `winnerProceeds` (CashWon, :339-342). It settles first if needed (:314-318).
- **[Model: release functions]** `releaseSponsorProceeds` and `releaseProtocolFees` pay the full current balance to recipients that cannot change (:375-392). `releaseSponsorPrize` returns the NFT in CashWon or Refunding (:395-406).

### Assumptions checked (Why)
- **[Why: Raffle.sol:540-547]** The split is exact. The pot is always n·1e6, so:
  - fee = n·50,000;
  - cash = n·800,000;
  - sponsor = n·150,000 in CashWon, or n·950,000 in NftWon.
  - The parts always sum to the pot.
  - I checked n = 1..200,000 plus 2^64, 2^100 and 2^128−1 with 0 violations. There is no dust and no rounding leak.
- **[Why: Raffle.sol:368]** `remainingRefundLiability -= amount` cannot underflow:
  - The liability equals totalEntries·1e6, which equals the sum of all ticket ranges ×1e6, because ranges are contiguous and disjoint (:226-232).
  - Each ticket burns at most once. `ownerOf` reverts on burned or duplicate IDs in OZ 5.6.1.
  - No ticket can burn before Refunding: only redeem burns, and NftWon/CashWon can never reach Refunding (:292-293).
- **[Why: Raffle.sol:521 vs :539-547]** The outcome predicate and the split read the same frozen numbers. Once status leaves Active, buyEntries is closed (:215), so totalEntries and unsettledPot = totalEntries·1e6 cannot change between the callback and settlement.
- **[Why: VRFV2PlusWrapperConsumerBase.requestRandomnessPayInNative]** The fee is recomputed with `calculateRequestPriceNative` in the same transaction at the same `tx.gasprice`. The `paidPrice > msg.value` guard (:258) stops the raffle spending ETH forced into it. Any excess goes back to the caller (:262-270).
- **[Why: I:14-15 vs DESIGN.md]** The trust statements conflict.
  - I:14-15 says supported prizes are "honest, standards-compliant ERC-721s".
  - DESIGN.md says "arbitrary prize contracts ... are untrusted".
  - The finding's non-malicious triggers (admin pause or transfer restriction) are behaviours a compliant ERC-721 can have, so the finding holds under either statement.
  - DESIGN.md also says "Sponsor and treasury can claim independently after settlement". I read that as "independently of each other". The proposed delivery gate conflicts with it only if it means "independently of delivery".

### Guards and adversarial cases tested (Defeat)
- **[Defeat: enableRefunds]** For a sold raffle in Active, refunds open at exactly endTime+2d, the same instant requestDraw closes (:245 vs :286-287). In Drawing, refunds open at drawRequestedAt+2d, the same instant callbacks start being ignored (:512 vs :290-291). NftWon, CashWon and Refunding revert (:292-293). The windows neither overlap nor leave a gap, so front-running cannot change the outcome.
- **[Defeat: fulfillRandomWords]** In-flight, wrong-status, wrong-id, wrong-length and late callbacks are ignored (:510-516). The callback never reverts, because totalEntries > 0 is guaranteed by :243. Its cost is a few SSTOREs plus an event, far under the 300k gas limit. A failed wrapper delivery leaves Drawing, which reaches refunds after 2 days. No timer can be reset by a user.
- **[Defeat: refundTickets]**
  - A duplicate ID in a batch fails the second `ownerOf`.
  - A foreign ID fails with NotTicketOwner.
  - A nonexistent ID fails with ERC721NonexistentToken.
  - Batches are limited to 1–100 tickets (:352-353).
  - An approved operator cannot refund (:360).
- **[Defeat: settleWinningTicket]**
  - A wrong ticket, ID 0, or an ID that was never minted fails the range check (:582-583, since winningEntry >= 1).
  - Settling twice fails with SettlementAlreadyComplete.
  - Front-running the winner's redeem with a settle is harmless, because :316-317 accepts the same ID.
- **[Defeat: redeemWinningTicket]**
  - Only the owner can redeem (:321).
  - Burn and payout happen in the same call, and any failure reverts both.
  - In NftWon, `ownerOf` is re-checked after the transfer (:335).
  - In CashWon, `winnerProceeds` is at least 800,000 because totalEntries >= 1.
  - Gap: if delivery fails permanently, nothing can redeem it (FINDING).
- **[Defeat: requestDraw]** Third parties cannot block it: it is permissionless, and an unavailable wrapper leads to refunds after endTime+2d. A failed excess-ETH refund reverts only the caller's own transaction.
- **[Defeat: _isProtocolDestination]** The registry lookup is skipped for addresses with no code (:602). This can only hurt the party that chose the address (LEAD 3).
- **[Defeat: F:createRaffle]**
  - Registration happens before escrow (F:125, then F:128), so tickets of other raffles cannot be sent to the new clone during the prize hook.
  - `nonReentrant` blocks nested creation.
  - The deposit is verified with `ownerOf` and `status` (F:129-134).
  - A prize contract can pass all of these honestly at deposit and turn hostile later; that is the basis of the FINDING.

### Last-user-out per lifecycle (LastOut)
- **[LastOut: L3 NftWon]** USDC is split into the 95% and 5% claims, each released in full, so the balance ends at 0. The winning-ticket owner is the only NFT claimant. If the prize contract blocks the clone's transfer, that winner is last out and receives nothing, while all the USDC has already left (FINDING). A winner who never redeems strands only their own NFT (self-harm).
- **[LastOut: L3 CashWon]** The 80/15/5 split is exact, and each of the three independent claims drains to 0. The NFT goes back to the sponsor on its own path. Everyone is paid.
- **[LastOut: L4/L5 Refunding]** At every step `remainingRefundLiability` equals the unburned tickets ×1e6. Refunds in the worst order still leave exactly the last refunder's amount. The prize return is independent. Everyone is paid.
- **[LastOut: L6 Empty]** The liability is 0 and no tickets exist. The prize is returned. Nothing is stranded.
- **[LastOut: Native ETH]** msg.value = paidPrice + excess, so no ETH is owed after the call. ETH forced into the contract is untracked and never spent.
- **Not owed to anyone:** USDC, ETH or NFTs sent directly to a clone are stuck by design, since there is no sweep function.

### Saturation sweep
- **Pattern 1: payment released while the asset can still fail to deliver.**
  - `releaseSponsorProceeds` in NftWon: affected; this is where the FINDING is rooted.
  - `releaseProtocolFees` in NftWon: affected; same root cause, reported in the same block.
  - `redeemWinningTicket` in CashWon vs `releaseSponsorPrize`: not affected. These are separate entitlements of different parties, and a failed NFT return hurts only the sponsor who chose the prize.
  - `refundTickets` vs `releaseSponsorPrize` in Refunding: not affected; the two are independent.
  - `requestDraw` ETH payment: not affected; it is atomic and reverts on failure.
  - `F:createRaffle` deposit: not affected; it is atomic and verified.
- **Pattern 2: payout screen differs from the entry screen.**
  - `_transferQuote` (:565) re-checks the destination at payout.
  - `releaseSponsorPrize` (:402-405) does not.
  - In NftWon, `redeemWinningTicket` pays `msg.sender`, which cannot be a clone.
  - This is LEAD 3.
- **Pattern 3: terminal state with no exit.**
  - NftWon has no fallback when the prize cannot be delivered (FINDING).
  - CashWon and Refunding have independent exits.
  - Drawing exits through the callback or through refunds.
  - Active exits through a draw or through refunds.
