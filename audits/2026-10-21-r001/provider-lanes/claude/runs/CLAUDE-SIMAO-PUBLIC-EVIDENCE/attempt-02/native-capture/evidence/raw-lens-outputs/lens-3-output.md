# Lens 3 — Temporal Cohorts & Distribution Fairness — raffle.fun

Scope: `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `interfaces/*`, `libraries/RaffleConstants.sol`, `DESIGN.md`. Line numbers refer to the real source files (`Raffle.sol` unless prefixed).

Lens surface: this protocol has no cumulative index, reward rate, share price, or pro-rata payout among a changing set of holders. The closest analogues, and the ones worked here, are:
- the uniform draw over entries (the only pro-rata distribution: each entry's win odds are `1/totalEntries`);
- the reserve-threshold regime switch (`NftWon` vs `CashWon`);
- the fixed-BPS split of the pot;
- the secondary-market ticket "join/leave" path.

---

## Findings and leads

```
FINDING | contract: Raffle | function: buyEntries | bug_class: sponsor-rebated-late-dilution | group_key: Raffle | buyEntries | sponsor-rebated-late-dilution
root_cause: Raffle.sol:544 (`sponsorAmount = grossPot - protocolFee`, with grossPot = unsettledPot at :539, credited at :554) pays the sponsor 95% of the whole pot, including entries the sponsor bought through any address. `buyEntries` (Raffle.sol:215-233) has no entry cap once `reserveEntries` is met and does not exclude the rebated party. Each sponsor-funded entry therefore costs the sponsor only 5% of ENTRY_PRICE but carries full weight in the uniform draw (Raffle.sol:518). This breaks DESIGN.md's uniform "one entry costs 1,000,000 units" for exactly one cohort. Earlier buyers cannot exit after the sponsor's late purchase: refunds open only at endTime+2d (Raffle.sol:286-287), and anyone, including the sponsor, can draw at endTime (Raffle.sol:242).
internal_pre: The raffle resolves NftWon (totalEntries >= reserveEntries, Raffle.sol:521). The sponsor controls or colludes with sponsorRecipient, which is the default setup. The attack pays off whenever the NFT value V > 0.05 * organic entries N.
external_pre: The sponsor has k USDC available from the last block before endTime until releaseSponsorProceeds, typically minutes: requestDraw at endTime, then 30 confirmations, then settle and release. 95% of it comes back. A flash loan does not work because entries lock funds across transactions.
path:
  1. Sponsor S calls RaffleFactory.createRaffle for an NFT worth 10,000 USDC with reserveEntries = 5,000, sponsorRecipient = S, endTime = T.
  2. Alice calls buyEntries(alice, 10,000) and pays 10,000 USDC. Ticket #1 = [1, 10,000], unsettledPot = 10,000e6, and the reserve is met. Honest outcome: Alice wins the NFT with probability 1 and S nets 9,500 USDC.
  3. In the last block before T (timestamp T-12), S's fresh address S' calls buyEntries(S', 90,000) and pays 90,000 USDC. Ticket #2 = [10,001, 100,000]; totalEntries = 100,000; unsettledPot = 100,000e6. Nothing blocks it: Raffle.sol:215-221 checks only status, time, recipient and count.
  4. At T, S calls requestDraw. The VRF callback sets winningEntry uniform on [1, 100,000] and status = NftWon (Raffle.sol:518-521).
  5. settleWinningTicket sets protocolFees = 5,000 USDC and sponsorProceeds = 95,000 USDC (Raffle.sol:540, 544, 554). releaseSponsorProceeds then pays S 95,000, so S's net cash = 95,000 - 90,000 = +5,000 USDC.
  6. With probability 0.9, ticket #2 holds winningEntry, and S' calls redeemWinningTicket(2) to take the NFT back (Raffle.sol:329-337).
impact: The cohort of organic ticket holders who bought before the sale closed is left holding the loss.
  - k = 90,000: Alice's prize EV falls from 10,000 to 1,000 USDC (-9,000) for the same 10,000 USDC paid. S's EV rises from 9,500 to 14,000 (+4,500). The treasury takes +4,500 in fees on S's own entries.
  - EV-optimal k ≈ 34,721 (N + k = sqrt(20*V*N)): S gains about +6,028 and Alice loses about 7,764.
  - Under-subscribed raffle (Alice 100 entries, V = 10,000): S needs about 4,372 USDC of short-lived capital to cut Alice's prize EV from 10,000 to about 224 (S +9,558 EV).
mitigation: Stop the sale at the reserve in buyEntries (`if (lastEntry > reserveEntries) revert ...`), so no sponsor-rebated entries can be minted after organic demand meets the reserve. A buyer blocklist on sponsor/sponsorRecipient alone is not enough, because purchases are permissionless (sybil). A sponsor fill of the gap below the reserve remains possible; it is tracked as a separate lead.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: sponsor-reserve-flip | group_key: Raffle | fulfillRandomWords | sponsor-reserve-flip
smell: The NftWon/CashWon regime check (Raffle.sol:521) counts sponsor-bought entries, which are rebated 95% through sponsorProceeds (Raffle.sol:544). When organic demand N < reserve R, the sponsor can fill R-N in the last block before endTime at a 5% cost. That turns a CashWon raffle (buyers' EV 0.8 USDC per entry) into NftWon. Example with R = 1,000, N = 900, NFT worth V = 500 USDC: honest CashWon gives buyers 720 USDC EV and the sponsor 135 USDC + the NFT (635). If the sponsor buys 100 entries, the raffle becomes NftWon: sponsor = 950 - 100 + 0.1*500 = 900 (+265); buyers' EV = 0.9*500 = 450 (-270); treasury +5.
unverified: (1) Whether under-reserve buyers are entitled to expect CashWon. The reserve may be meant only as sponsor protection, and organic demand reaching R gives the same regime. (2) The flip pays only when V is below roughly 0.8*R (an overpriced reserve); with V = 900 in the example it is unprofitable and helps buyers. (3) There is no sybil-proof code fix: the sale cap proposed for the dilution FINDING does not close this gap.
description: A sponsor-funded fill of the gap below the reserve in the last block lets the sponsor choose the payout regime after seeing demand, at a 5% cost, and moves EV from under-reserve buyers to the sponsor.
```

```
LEAD | contract: Raffle | function: _update | bug_class: vrf-outcome-frontrun-ticket-trade | group_key: Raffle | _update | vrf-outcome-frontrun-ticket-trade
smell: _update (Raffle.sol:497-502) allows ticket transfers in every status, including Drawing (the NatSpec at Raffle.sol:491 says so deliberately). The pending VRF fulfillment (wrapper -> rawFulfillRandomWords -> Raffle.sol:518) lets any mempool observer work out winningEntry before it executes. The observer can fill a stale marketplace listing of the winning ticket, or sell a losing ticket into a standing collection bid, ahead of or bundled right after the callback. Example: Alice lists ticket #7 (500 of 1,000 entries; NFT worth 2,000 USDC) at 900 USDC. Bob simulates the pending fulfillment, sees that entry 742 (in #7) wins, fills the listing first, and redeems the NFT. Alice's EV falls from about 1,000 to about 450.
unverified: (1) Whether Chainlink's mainnet VRF fulfillments go through the public mempool. (2) Whether any fillable marketplace order exists at fulfillment time. (3) A Drawing-only transfer lock can be bypassed by bundling [fulfillment, fill], because status becomes NftWon mid-bundle. The only robust fix, blocking operator-initiated transfers from requestDraw onward, conflicts with the documented bearer-claim design. Victims are external order makers; the protocol's own accounting is unaffected.
description: Tickets stay tradeable while the draw result can be derived publicly but is not yet on-chain, which allows trades against stale secondary-market orders by someone who already knows the result.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-decoupled-from-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-decoupled-from-prize-delivery
smell: In NftWon, settlement allocates 95% of the buyers' pot to sponsorProceeds (Raffle.sol:544, 554). releaseSponsorProceeds (Raffle.sol:375-382) pays it out whether or not the NFT leg (redeemWinningTicket, Raffle.sol:329-337) ever succeeds. There is no redemption timeout and no fallback to refunds. If the prize collection blocks transfers out of the raffle after creation (an admin-pausable, upgradeable or transfer-validator-gated collection, or a sponsor-controlled contract), the winner can never redeem, while the sponsor keeps 95% and the treasury 5%.
unverified: (1) Whether such prizes are in scope. DESIGN.md says arbitrary prize contracts are untrusted, but IRaffle.sol:14-15 says supported prizes are honest, standards-compliant ERC-721s, and DESIGN.md explicitly lets sponsor and treasury claim independently after settlement. (2) Gating sponsor proceeds on prizeClaimed would swap this for a sponsor-side stuck-funds risk if the winner never redeems. This belongs mainly to the trust/integration lens and is recorded here as a split-between-cohorts symptom.
description: The sponsor is paid from the pot regardless of whether the buyers' prize can actually be delivered, so a transfer freeze on the prize after creation leaves the winning cohort with nothing.
```

---

## Public audit-evidence summaries

### Money model

- **[Model: buyEntries]** The buyer pays `entryCount * 1e6` USDC (Raffle.sol:223-224) and receives one transferable ticket for range `[totalEntries+1, totalEntries+entryCount]` (:226-235). Totals updated: `totalEntries` (:230), `ticketCount` (:231), `_ticketRanges` (:232), `unsettledPot += grossAmount` (:233). The pot inflow and the tracked increase are the same amount.
- **[Model: fulfillRandomWords]** The callback records only `winningEntry = word % totalEntries + 1` (uniform over sold entries, :518), `resolvedAt`, and the regime `totalEntries >= reserveEntries ? NftWon : CashWon` (:521). No value moves.
- **[Model: _settleWinningTicket]** This is the one-time split of `unsettledPot` (:539):
  - fee: 5% (:540)
  - NftWon: sponsor gets 95% (:544)
  - CashWon: winner gets 80% (:546-548) and the sponsor gets 15% as the remainder (:547)
  - afterwards `unsettledPot` is set to 0 (:553)

  This is a fixed-BPS split to three parties, not a pro-rata split among holders.
- **[Model: enableRefunds/refundTickets]** `unsettledPot` moves to `remainingRefundLiability` (:296-298). Each refund burns the owner's tickets and decrements by range × 1e6 (:360-368).

### Assumptions

- **[Why: Raffle.sol:216 / :242]** The sale closes strictly before the draw window opens: `buyEntries` needs `now < endTime`, and `requestDraw` needs `now >= endTime`. No entry can be minted once randomness is requested, so a late entrant cannot join after the outcome is known.
- **[Why: Raffle.sol:544]** The sponsor's NftWon share is computed on the gross pot whoever bought the entries. This is the rebate behind the FINDING.
- **[Why: RaffleConstants BPS]** The pot is always `n * 1e6`, so the 5%, 80%, 15% and 95% shares are exact. Checked arithmetically for every n ≤ 200,000: no dust and no rounding drift between cohorts.
- **[Why: VRF consumer base]** `rawFulfillRandomWords` is callable only by the immutable wrapper (node_modules/@chainlink/.../VRFV2PlusWrapperConsumerBase.sol). The wrapper implementation is not vendored. I assumed the standard Chainlink v2.5 behaviour (single delivery, no retry after a consumer failure), which is a trusted dependency per DESIGN.md.

### Adversarial tests

- **[Defeat: buyEntries late-join]**
  - A non-sponsor late buyer pays full price, and EV per entry is the same for everyone (V/N in NftWon, 0.8 USDC in CashWon), so they get no share they did not pay for.
  - A sponsor late buyer pays an effective 0.05 USDC per entry, which gives the FINDING.
  - Joining after randomness is blocked by :216 / :242.
- **[Defeat: CashWon sibling of the rebate]** Sponsor purchases in CashWon leave buyers' EV per entry at exactly 0.8 (checked with N = 1,000 and k = 0 or 9,000). The sponsor's own entries have EV of -0.05 per entry. Not exploitable.
- **[Defeat: treasury sibling]** The treasury gets 5%, so its own entries cost it 95%. It has no edge.
- **[Defeat: fulfillRandomWords]** These callbacks are ignored without reverting (:510-516): duplicates, late ones, wrong request IDs, wrong lengths, and in-flight ones. A late callback and `enableRefunds` use the same boundary, `drawRequestedAt + 2d` (:463-465, :289-291). There is no resolution after refunds, no double resolution, and no re-roll option.
- **[Defeat: _settleWinningTicket]** Settlement cannot be faked:
  - ticket 0 or a nonexistent ID has range (0,0), which cannot contain `winningEntry >= 1`;
  - `settlementComplete` makes it single-use (:534, :551);
  - in NftWon/CashWon no ticket can be burned before settlement, because refunds are blocked by status and redemption settles first (:314-315).
- **[Defeat: refundTickets]** A duplicate ID in a batch reverts at `ownerOf` after the first burn. Refund and winning redemption require different statuses. The `-=` cannot underflow, because the liability equals Σ unburned ranges × 1e6.
- **[Defeat: consumed flags (claim-twice shape)]** Each claim can be taken once, and the flags survive ticket transfers: `winnerRedeemed` (:310, :324), `prizeClaimed` (:330-331, :400-403), `settlementComplete`, zeroing of `winnerProceeds`, `sponsorProceeds` and `protocolFees` (:341, :378, :388), and ticket burns (:325, :364).
- **[Defeat: enableRefunds empty-cancel race]** If the sponsor's cancel and the first purchase race, either the purchase reverts with no funds moved, or the cancel reverts and the sale continues as intended. Nobody loses.

### Last User Out

- **[LastOut: L3 NftWon]** Pot 10e6 → fee 0.5e6 + sponsor 9.5e6 = pot. Both releases are independent and leave the USDC balance at exactly 0. The NFT goes to the current owner of the winning ticket.
- **[LastOut: L3 CashWon]** Pot 10e6 → winner 8e6 + sponsor 1.5e6 + fee 0.5e6 = pot. The balance ends at 0, and the prize goes back to `sponsorRecipient` once (:395-407).
- **[LastOut: L4/L5 Refunding]** Liability = Σ ticket ranges × 1e6 = `totalEntries * 1e6`. Refunding in any order pays the last refunder exactly, and the balance ends at 0.
- **[LastOut: L6 Empty]** Liability is 0, and the prize is returned.
- **[LastOut: holder-side gap]** There is no redemption deadline, so a winning claim held by an address that never calls `redeemWinningTicket` stays stranded. This only harms that holder; no other party's claim depends on it.

### Saturation sweep (sponsor-rebate shape)

- **Pot recipients:**
  - sponsor in NftWon: the FINDING;
  - sponsor in CashWon: no harm;
  - treasury: no edge;
  - CashWon winner: an ordinary lottery.
- **Join paths:** `buyEntries` is the only mint path, and `_safeMint` for another recipient goes through it. Ticket transfers are the "join/leave" path covered by the `_update` lead.
- **Regime threshold (:521):** the sponsor-reserve-flip lead.
- **Not present in this code:** cumulative indexes, rates, compounding paths, and pro-rata reward queues.
