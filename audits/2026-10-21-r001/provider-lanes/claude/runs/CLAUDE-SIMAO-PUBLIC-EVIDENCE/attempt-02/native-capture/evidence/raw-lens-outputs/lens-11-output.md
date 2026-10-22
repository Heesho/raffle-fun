# Lens 11: Edge and Terminal States (raffle.fun Raffle clone + RaffleFactory)

**Result: 0 FINDINGs, 4 LEADs.**

I walked the Lens 11 checklist against every stateful function in the money map. The checklist covers: zero/empty, one, first, last, expired, paused, cancelled/retried, maximum, threshold and reconfiguration.

- **Terminal states hold.** Refunding, NftWon, CashWon and the empty raffle all conserve exactly and pass the Last User Out test.
- **Time boundaries hold.** Every comparator is correct, and the sale, request, callback and refund windows are disjoint with no gap.
- **The leads sit at two edges:**
  - the prize-trust boundary (an NFT leg that is untrusted or can be frozen);
  - the reserve threshold.

Line numbers refer to `packages/contracts/src/Raffle.sol` unless prefixed `RaffleFactory.sol`.

---

## LEADs

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: terminal-state-no-fallback | group_key: Raffle | releaseSponsorProceeds | terminal-state-no-fallback
smell: In NftWon, `_settleWinningTicket` books 95% of the pot as `sponsorProceeds` (Raffle.sol:544, :554). `releaseSponsorProceeds` (Raffle.sol:375-381) pays it with no dependency on `prizeClaimed` or `winnerRedeemed`. The winner's only exit is `prizeToken.transferFrom(address(this), winner, prizeTokenId)` (Raffle.sol:334). NftWon is an absorbing state: `enableRefunds` reverts outside Active/Drawing (Raffle.sol:292-293), and `releaseSponsorPrize` excludes NftWon (Raffle.sol:397-398). If the prize becomes non-transferable out of the raffle after resolution, there is no cash or refund fallback. Concrete sequence:
  1. reserveEntries = 1,000. Buyers buy 2,000 entries (2,000 USDC). The VRF resolves NftWon and the winning entry is in Bob's ticket.
  2. The prize becomes undeliverable from the raffle. Examples: the admin pauses an ERC721Pausable collection; a transfer-validator policy change blocks contract-initiated owner transfers; an expiring registration such as an ENS .eth name passes its grace period.
  3. Anyone calls settleWinningTicket. sponsorRecipient calls releaseSponsorProceeds and receives 1,900 USDC. The treasury receives 100 USDC.
  4. Every redeemWinningTicket call by Bob reverts at Raffle.sol:334. No state transition is left.
  Who holds the loss: Bob, the winning-ticket holder, and ex ante every buyer whose USDC funded the 1,900. If the sponsor controls the collection's freeze switch, this is a rug.
unverified: It is unclear whether such a prize is in scope. DESIGN.md says "arbitrary prize contracts ... are untrusted", but IRaffle.sol:14-15 limits support to "honest, standards-compliant ERC-721s". DESIGN.md also asks that sponsor and treasury "claim independently after settlement", which this behaviour satisfies. The third-party collection behaviours above (pause, transfer-validator levels, ENS expiry and grace) are not vendored in this workspace and were not verified from source.
description: The NftWon terminal state releases the sponsor's 95% independently of an NFT leg that an untrusted or admin-controlled prize can freeze, and offers no path back to refunds. If this is in scope, the minimal fix is to gate NftWon `releaseSponsorProceeds` on `prizeClaimed == true`, plus a long winner-inactivity timeout so an absent winner cannot lock the sponsor forever.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: reserve-threshold-manipulation | group_key: Raffle | fulfillRandomWords | reserve-threshold-manipulation
smell: The outcome flips at `totalEntries >= reserveEntries` (Raffle.sol:521). Crossing the threshold moves the 80% cash leg owed to the winner (Raffle.sol:546-548) into the sponsor's 95% (Raffle.sol:544). `buyEntries` (Raffle.sol:209-237) does not restrict who buys. Because `sponsorProceeds` includes 95% of the sponsor's own purchases, the sponsor (or a Sybil wallet) can meet its own reserve for about 5% of the shortfall. Concrete sequence:
  1. reserveEntries = 1,000. Organic buyers hold 600 entries. The NFT's market value is 300 USDC.
  2. With no intervention the result is CashWon. The winning buyer gets 480 USDC, sponsorRecipient gets 90 USDC plus the NFT, and the treasury gets 30 USDC.
  3. Instead, the sponsor buys 400 entries at endTime - 1 for 400 USDC, giving NftWon.
  4. After settlement, sponsorRecipient gets 950 USDC (net +550 after the 400 paid), the treasury gets 50 USDC, and a buyer wins the NFT with probability 0.6.
  Effect on expected value: buyers fall from 480 to 180 (-300); the sponsor rises from 390 to 670 (+280). Here the sponsor gains whenever the NFT is worth less than about 767 USDC.
unverified: Buyers would get the same outcome if an unrelated third party had bought the same 400 entries. So the "loss" is measured against a CashWon outcome that buyers were never guaranteed. Neither the design nor the NatSpec says whether the reserve is meant to protect buyers or is purely a sponsor option. No address-based check can stop Sybil self-purchase.
description: The reserve threshold acts as a cheap sponsor option (cost about 5% of the shortfall) to turn a buyer-favourable CashWon into an NftWon sale of an overvalued NFT. This is a design-economics lead, not a code defect.
```

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: spoofable-escrow-verification | group_key: RaffleFactory | createRaffle | spoofable-escrow-verification
smell: Escrow at creation is "verified" only through the prize contract's own answers.
  - During `prize.safeTransferFrom` (RaffleFactory.sol:128), the prize contract is msg.sender. It can call `raffle.onERC721Received(factory, sponsor, prizeTokenId, "")` directly.
  - The `operator` and `from` checks at Raffle.sol:421-423 compare arguments the caller supplies, so the call passes and sets `status = Active` (Raffle.sol:428) without any transfer.
  - The same contract answers the `ownerOf` check at RaffleFactory.sol:129 and the post-delivery checks at Raffle.sol:335 and :405.
  A hostile prize therefore produces a registered, Active raffle that looks escrowed but holds nothing. In NftWon the sponsor still collects 95% (Raffle.sol:544, :554).
unverified: This may add no risk beyond "the prize is worthless". A hostile contract at its own address is simply a worthless collection that buyers can inspect. Making a genuinely valuable collection behave this way would need a hostile upgrade or admin action, which the protocol cannot control. No on-chain check that only asks the prize contract can fix this.
description: The escrow checks cannot enforce DESIGN.md's "untrusted prize" stance; they hold only for honest ERC-721s, which is what IRaffle.sol:14-15 assumes. The recommendation is to document the prize trust boundary for buyers, not to change code.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: payout-screen-inconsistency | group_key: Raffle | releaseSponsorPrize | payout-screen-inconsistency
smell: The two payout paths screen differently:
  - USDC payouts re-check the destination at payout time (`_transferQuote`, Raffle.sol:565).
  - The NFT return `prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId)` (Raffle.sol:404) has no payout-time check.
  `initialize` does screen `sponsorRecipient` (Raffle.sol:193-195), but the registry lookup only runs for addresses that have code (Raffle.sol:602-603). `Clones.clone` deploys with CREATE, so clone addresses are predictable. A `sponsorRecipient` set to a not-yet-deployed clone address passes initialisation. Once that clone exists:
  - `releaseSponsorPrize` moves the NFT into another raffle clone, against DESIGN.md "Never move assets between raffle clones";
  - `releaseSponsorProceeds` reverts forever (Raffle.sol:565).
unverified: No third-party victim was found. The sponsor always chooses `sponsorRecipient`, so the only loser is that sponsor, and the NFT that lands in the other clone affects none of that clone's accounting. This is recorded to complete the saturation sweep of the payout-screen pattern, not as a reportable bug.
description: The gap between the code-gated `initialize` screen and the payout-time screen can only be reached by deliberate sponsor misconfiguration. Adding the same `_isProtocolDestination` check before Raffle.sol:404 would make the two payout paths consistent.
```

---

## Public audit-evidence summaries

**[Model: buyEntries]**
- The buyer pays `entryCount * 1e6` USDC (Raffle.sol:223-224) and receives ticket `ticketCount + 1` with range `[totalEntries + 1, totalEntries + entryCount]` (Raffle.sol:226-232).
- `unsettledPot += grossAmount` is written in the same call (Raffle.sol:233).
- Until a terminal transition, therefore, `unsettledPot == totalEntries * 1e6 == sum of ranges * 1e6`.

**[Model: enableRefunds]**
- It moves the entire `unsettledPot` into `remainingRefundLiability` and sets Refunding (Raffle.sol:296-299).
- It can only be called from Active or Drawing (Raffle.sol:279-294). It reverts in every other state, so NftWon and CashWon can never become Refunding.

**[Model: _settleWinningTicket]**
- `fee = pot * 500 / 1e4`. NftWon: `sponsor = pot - fee`. CashWon: `cash = pot * 8000 / 1e4` and `sponsor = pot - fee - cash` (Raffle.sol:539-555).

**[Model: refundTickets / redeemWinningTicket]**
- Refund burns each owned ticket, pays `sum of ranges * 1e6`, and debits `remainingRefundLiability` by the same amount (Raffle.sol:356-369).
- Redeem burns the winning ticket, then delivers the NFT (NftWon) or pays and zeroes `winnerProceeds` (CashWon) (Raffle.sol:320-343).
- In both, the burn and the delivery happen in one transaction.

**[Why: Raffle.sol:540-547]**
- The split is exact. The pot is always `n * 1e6`, so `fee = n * 5e4` and `cash = n * 8e5` with no rounding.
- `cash + sponsor + fee == pot` with zero dust. DESIGN.md's "remainder allocated without loss" holds.

**[Why: Raffle.sol:368]**
- `remainingRefundLiability -= amount` cannot underflow:
  - In Refunding, only `refundTickets` burns tickets; redeem requires NftWon or CashWon (Raffle.sol:311-312).
  - No ticket can be minted outside Active (Raffle.sol:215).
  - A duplicate ID in a batch reverts at `ownerOf` because the token was already burned (OZ 5.6.1 `_requireOwned`).

**[Why: Raffle.sol:518, :582]**
- `winningEntry = rand % totalEntries + 1`, so it always lies in `[1, totalEntries]`. Ranges are contiguous and disjoint, so exactly one minted ticket contains the winning entry.
- A never-minted ID has range (0,0) and fails `_requireWinningTicket` (Raffle.sol:579-585).
- In NftWon and CashWon, the winning ticket can only be burned by redeem, so it is always unburned at settlement.

**[Why: ReentrancyGuard in clones]**
- OZ 5.6.1 keeps the guard in a namespaced slot (`0x9b77...5f00`).
- A clone's slot starts at 0, which is not ENTERED (2), so `nonReentrant` works even though the constructor never ran in the clone (node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol).

**[Defeat: time windows]** Exact-boundary tests:
- At `t = endTime`: buyEntries reverts (Raffle.sol:216). requestDraw (Raffle.sol:242) and public refunds on an empty raffle (Raffle.sol:282) are both allowed.
- At `t = endTime + 2d`: requestDraw reverts (Raffle.sol:245) and refunds open for a sold Active raffle (Raffle.sol:287).
- At `t = drawRequestedAt + 2d`: the callback is ignored (Raffle.sol:512) and refunds open for Drawing (Raffle.sol:291).
- The windows are disjoint and leave no gap, even when a callback and `enableRefunds` land in the same block.
- Late, duplicate, wrong-ID, wrong-length and post-Refunding callbacks are all ignored (Raffle.sol:511-512).

**[Defeat: enableRefunds, empty-raffle cancel]**
- The sponsor can cancel at any time only while `totalEntries == 0` (Raffle.sol:280-284).
- A buyer who front-runs the cancel with one entry pushes the raffle onto the sold branch (deadline `endTime + 2d`). That locks the NFT for at most the remaining sale (up to 30d), plus 2d to request a draw, plus 2d for the callback.
- This matches the documented "empty raffle" semantics, and the buyer's 1 USDC stays refundable. It is intended behaviour, so it is not raised as a lead.

**[Defeat: redeemWinningTicket]** Three single-payout bypasses were tested and all fail:
- Redeeming twice is blocked by `winnerRedeemed` (Raffle.sol:310).
- Settling again with a different ticket is blocked by `settlementComplete` (Raffle.sol:534) and the range check (Raffle.sol:582).
- Refunding the winning ticket is impossible because NftWon and CashWon cannot reach Refunding (Raffle.sol:292-293).
- Burn and delivery are atomic, so a failed delivery also reverts the burn.

**[Defeat: releaseSponsorPrize]** The prize leaves the raffle at most once:
- NftWon is excluded (Raffle.sol:397).
- `prizeClaimed` is set before the external transfer, inside `nonReentrant` (Raffle.sol:403).
- In NftWon, `prizeClaimed` is written only by redeem, behind the `winnerRedeemed` guard (Raffle.sol:330-331).

**[Defeat: onERC721Received / implementation lock]**
- For honest ERC-721s, AwaitingPrize exists only inside `createRaffle` (RaffleFactory.sol:109-134), and any receive after Active reverts. A hostile prize can forge the receive; see the RaffleFactory | createRaffle lead.
- The implementation contract is constructed with `initialized = true` and `status = Refunding` (Raffle.sol:164-165). Every state-changing entry point then reverts:
  - most need a status the implementation never has, or a ticket that cannot exist;
  - `releaseSponsorPrize` calls `transferFrom` on `prizeToken = address(0)`, which has no code and reverts.
- The implementation is inert.

**[Defeat: VRF liveness]**
- Third parties cannot force a resolvable request into refunds:
  - the callback gas limit is the constant 300,000 (RaffleConstants.sol);
  - the callback has no loops, user calls or transfers;
  - `rawFulfillRandomWords` accepts only the wrapper (VRFV2PlusWrapperConsumerBase.sol).
- Every non-resolving case (wrapper disabled, coordinator migration, request never fulfilled) falls back to refunds through the deadlines.

**[Defeat: payout destinations]**
- Ticket moves and USDC payouts are screened by `_isProtocolDestination` (Raffle.sol:497-502, :565).
- A destination can only become unsafe after the fact if it is a code-less future CREATE clone address. That requires the payee's own choice, which is self-inflicted. See the releaseSponsorPrize lead.

**[Defeat: maximum / zero / threshold]**
- The entryCount overflow guard allows exactly `uint128.max` (Raffle.sol:219).
- `aggregateEntries * 1e6` cannot overflow uint256 even for 100 maximal ranges.
- Refund batches of 0 or more than 100 tickets revert; exactly 100 is allowed (Raffle.sol:352).
- `reserveEntries = 0` is rejected (RaffleFactory.sol:178).
- The reserve counts as met at equality (Raffle.sol:521), matching the NatSpec "met or exceeded".
- A single-entry raffle resolves to entry 1.
- Factory sale duration: exactly 30 days is allowed, and `endTime <= now` reverts (RaffleFactory.sol:100-103).

**[LastOut: Refunding (L4, L5, L6)]**
- `remainingRefundLiability = unsettledPot = sum of unburned ranges * 1e6` (Raffle.sol:296-298).
- Each refund subtracts exactly the ranges it burns. The last refunder, in any order, is paid in full and the liability ends at 0.
- The prize returns once through `releaseSponsorPrize`. An empty raffle has liability 0 and returns the prize.
- Every claimant is paid in full. The only residual is tickets sent to holders that cannot call refund, which is self-inflicted.

**[LastOut: NftWon]**
- The pot splits into 95% sponsor and 5% treasury, exactly. Both are released independently, and the winner receives the NFT.
- In any order, the accounted USDC ends at 0.
- Gap: the NFT leg has no fallback (lead 1).

**[LastOut: CashWon]**
- The pot splits into 80% winner, 15% sponsor and 5% treasury, exactly. The NFT returns to sponsorRecipient once.
- In any order, the accounted USDC ends at 0, and all four claims are independent.

**[LastOut: requestDraw native ETH]**
- The requester pays the wrapper's actual fee. Any excess `msg.value - paidPrice` is returned in the same transaction (Raffle.sol:262-270).
- Forced ETH, USDC sent directly, and NFTs sent with unsafe transfers stay untracked by design and affect no claim.
- No claim deadline exists for the winner, sponsor or treasury, so an absent claimant affects only their own claim.
