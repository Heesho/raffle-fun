# Turn 6 gate ledger — CLAUDE-SIMAO-PUBLIC-EVIDENCE attempt-02 (public-evidence method variant)

Native `severity-calibration.md` gates, one line each, single pass in fixed order (constructor/initialize → setters → deposit → accrue → borrow → liquidate → withdraw → cross-chain receive; mapped to this protocol as createRaffle → (none) → buyEntries → requestDraw/_settleWinningTicket → (none) → enableRefunds → redeem/release/_update → fulfillRandomWords async callback). `UNCERTAIN` = `ALLOWS`. Committed; not revisited.

Lead promotion/demotion (SKILL.md Turn 6 step 3): LEAD → FINDING if the full path exists in source or [lenses: 2+]; [lenses: 2+] does not override a code path that interrupts the attack (demote). A promoted group that fails a gate is not reported as a finding and is kept as a surviving LEAD (never silently dropped; it remains in the report's Unverified leads, which the completeness gate requires).

| Group | (Contract, function) | Stage | Lenses | Raw kinds | G1 | G2 | G3 | G4 | Decision | Severity | Report id |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D01 | RaffleFactory::createRaffle | constructor/initialize | 1 | LEAD | ALLOWS | ALLOWS | UNCERTAIN | BLOCKS | LEAD | — | Lead-1 |
| D02 | Raffle::buyEntries | deposit | 1 | FINDING | ALLOWS | ALLOWS | ALLOWS | ALLOWS | FINDING | Medium | M-2 |
| D03 | Raffle::buyEntries | deposit | 2 | LEAD | ALLOWS | ALLOWS | ALLOWS | UNCERTAIN | FINDING | Low | L-3 |
| D04 | Raffle::requestDraw | accrue (draw request) | 2 | LEAD | BLOCKS | BLOCKS | UNCERTAIN | BLOCKS | LEAD | — | Lead-2 |
| D05 | Raffle::_settleWinningTicket | accrue (settlement) | 3 | LEAD | ALLOWS | ALLOWS | ALLOWS | ALLOWS | FINDING | Medium | M-3 |
| D06 | Raffle::_settleWinningTicket | accrue (settlement) | 2 | LEAD | ALLOWS | ALLOWS | ALLOWS | ALLOWS | FINDING | Medium | M-4 |
| D07 | Raffle::enableRefunds | liquidate (forced-exit analogue) | 3 | LEAD | ALLOWS | ALLOWS | ALLOWS | BLOCKS | LEAD | — | Lead-3 |
| D08 | Raffle::redeemWinningTicket | withdraw | 1 | LEAD | ALLOWS | ALLOWS | ALLOWS | ALLOWS | FINDING | Medium | M-5 |
| D09 | Raffle::releaseSponsorProceeds | withdraw | 9 | FINDING/LEAD | ALLOWS | ALLOWS | ALLOWS | ALLOWS | FINDING | Medium | M-1 |
| D10 | Raffle::releaseSponsorProceeds | withdraw | 1 | LEAD | ALLOWS | BLOCKS | BLOCKS | ALLOWS | LEAD | — | Lead-4 |
| D11 | Raffle::releaseProtocolFees | withdraw | 1 | LEAD | ALLOWS | BLOCKS | BLOCKS | ALLOWS | LEAD | — | Lead-5 |
| D12 | Raffle::releaseSponsorPrize | withdraw | 5 | LEAD | ALLOWS | ALLOWS | BLOCKS | ALLOWS | LEAD | — | Lead-6 |
| D13 | Raffle::_update | withdraw (ticket transfer) | 7 | LEAD | ALLOWS | UNCERTAIN | ALLOWS | UNCERTAIN | FINDING | Low | L-1 |
| D14 | Raffle::fulfillRandomWords | cross-chain receive (async VRF callback analogue) | 4 | LEAD | ALLOWS | ALLOWS | ALLOWS | UNCERTAIN | FINDING | Low | L-2 |
| D15 | Raffle::fulfillRandomWords | cross-chain receive (async VRF callback analogue) | 1 | LEAD | ALLOWS | UNCERTAIN | ALLOWS | UNCERTAIN | LEAD | — | Lead-7 |

## D01 — `RaffleFactory | createRaffle | spoofable-escrow-verification` [lenses: 1]

- G1: `ALLOWS` — F:129/F:132 and Raffle.sol:421-426 verify escrow only through calls and answers of the prize contract itself, so a hostile prize can forge onERC721Received and ownerOf.
- G2: `ALLOWS` — Any sponsor can deploy a hostile ERC-165 contract at zero cost; F:155-177 checks only code presence, protocol plumbing and supportsInterface.
- G3: `UNCERTAIN` — Buyers of that raffle are not the sponsor, but they opted into an unvetted prize contract; the harm equals entering a raffle for a worthless prize.
- G4: `BLOCKS` — No incremental loss is established beyond the buyer-visible worthless-prize risk, and no check that only queries the prize contract can remove it.
- Promotion/demotion: Not promoted: [lenses: 1], and the full loss path beyond worthless-prize equivalence does not exist in source (G4 BLOCKS).
- Final: LEAD → Lead-1

## D02 — `Raffle | buyEntries | sponsor-rebated-late-dilution` [lenses: 1]

- G1: `ALLOWS` — buyEntries (:215-221) checks only status, sale time, recipient, count and overflow; it has no cap once the reserve is met and no exclusion of sponsor-controlled buyers. _update (:497-502) screens only protocol plumbing.
- G2: `ALLOWS` — Sponsor capital is locked only from endTime-1 until settle plus release (minutes to hours), and 95% comes back in NftWon. It is not flash-loanable, but the attack pays whenever NFT value > 5% of the final pot; sybil purchases cannot be told apart from real ones.
- G3: `ALLOWS` — Victims are the organic ticket holders who bought before the sale closed: their odds of winning the NFT are diluted while their USDC goes to sponsorRecipient and the treasury.
- G4: `ALLOWS` — Expected value moves between cohorts. R07 example: Alice -9,000 USDC EV, sponsor +4,500, treasury +4,500.
- Promotion/demotion: Raw FINDING; all gates ALLOWS.
- Severity: **Medium** — The loss is a probabilistic transfer of expected value between cohorts with no insolvency. I was torn with High because the sponsor creates every precondition, and chose the lower.
- Final: FINDING → M-2

## D03 — `Raffle | buyEntries | reserve-self-dealing` [lenses: 2]

- G1: `ALLOWS` — Nothing in buyEntries (:209-237) excludes sponsor-funded entries from the reserve test at :521.
- G2: `ALLOWS` — The sponsor buys the shortfall just before endTime, and 95% of it comes back under NftWon.
- G3: `ALLOWS` — Victims are under-reserve organic buyers, whose CashWon expected value (80% of the pot) is replaced by a smaller chance at the NFT.
- G4: `UNCERTAIN` — The expected-value transfer is real only when the NFT is worth less than about 0.8x the pot, and buyers were never guaranteed CashWon: any third party crossing the reserve gives the same outcome.
- Promotion/demotion: Promoted: [lenses: 2]; no code path interrupts the path.
- Severity: **Low** — Torn between Medium and Low; chose Low because the flip only pays for an over-priced reserve and CashWon is not a buyer entitlement. No sybil-resistant code fix exists.
- Final: FINDING → L-3

## D04 — `Raffle | requestDraw | immutable-vrf-wrapper-dependency` [lenses: 2]

- G1: `BLOCKS` — enableRefunds (:286-291) guarantees 100% refunds after endTime+2d or drawRequestedAt+2d, so no principal can be lost. Only time and the requester's own fee remain at risk.
- G2: `BLOCKS` — The trigger is Chainlink, a trusted canonical dependency under DESIGN.md, disabling or migrating the wrapper; no attacker can create it.
- G3: `UNCERTAIN` — Buyers and sponsors are delayed. The fee loss falls on whoever chose to request the draw.
- G4: `BLOCKS` — Funds are locked only for a bounded time and then refunded in full; nothing is lost.
- Promotion/demotion: Demoted: [lenses: 2] does not override a code path (the refund deadlines, G1 BLOCKS) that interrupts loss before harm. Kept as a surviving LEAD.
- Final: LEAD → Lead-2

## D05 — `Raffle | _settleWinningTicket | sponsor-self-entry-rebate` [lenses: 3]

- G1: `ALLOWS` — :544 computes the NftWon sponsor share over the gross pot, with no exclusion or cap for sponsor-funded entries.
- G2: `ALLOWS` — Same as D02: the sponsor's capital is short-lived and 95% of it is rebated.
- G3: `ALLOWS` — Victims are the organic buyers (variant A) and the under-reserve buyers (variant B).
- G4: `ALLOWS` — Expected value moves between cohorts (variant A examples above).
- Promotion/demotion: Promoted: [lenses: 3], and the full path with numbers exists in source.
- Severity: **Medium** — Same as D02 (variant A drives the severity). Torn with High and chose the lower because the loss is a transfer of expected value.
- Final: FINDING → M-3

## D06 — `Raffle | _settleWinningTicket | nftwon-split-without-delivery` [lenses: 2]

- G1: `ALLOWS` — The NftWon split (:543-555) has no delivery dependency. Both release functions (:375-392) check only amount != 0, NftWon has no route to Refunding (:292-293), and releaseSponsorPrize excludes NftWon (:397-398).
- G2: `ALLOWS` — A sponsor-administered upgradeable or pausable collection passes F:154-179 and the escrow checks at F:128-134, and DESIGN.md calls prize contracts untrusted.
- G3: `ALLOWS` — The victim is the winning-ticket holder (buyer cohort).
- G4: `ALLOWS` — The prize can never be delivered after 100% of the pot is paid out.
- Promotion/demotion: Promoted: [lenses: 2], and the full path exists in source (R01 steps 1-7).
- Severity: **Medium** — Same family and reasoning as M-1: it needs a prize whose transfers an admin can gate (an external condition). Reported separately because function isolation never merges across functions.
- Final: FINDING → M-4

## D07 — `Raffle | enableRefunds | empty-raffle-cancel-griefing` [lenses: 3]

- G1: `ALLOWS` — Once totalEntries > 0 the sponsor's early path at :280-284 is gone, and nothing prevents a 1-entry front-run.
- G2: `ALLOWS` — Costs 1 USDC plus gas, which is refundable.
- G3: `ALLOWS` — The victim is the sponsor, a third party to the griefer.
- G4: `BLOCKS` — No value is lost: the NFT stays escrowed only for the sale window the sponsor chose. The sponsor can draw at endTime and recover the prize through CashWon and releaseSponsorPrize, and the documented empty-raffle semantics (I:322-323) still hold.
- Promotion/demotion: Demoted: [lenses: 3] meets the promotion criterion, but G4 BLOCKS (no real value lost). Kept as a surviving LEAD.
- Final: LEAD → Lead-3

## D08 — `Raffle | redeemWinningTicket | stuck-terminal-state` [lenses: 1]

- G1: `ALLOWS` — The NftWon branch (:329-337) has one delivery path, and any revert undoes the burn. There is no alternative exit: enableRefunds rejects NftWon (:292-293), releaseSponsorPrize rejects it (:397-398), and there is no deadline.
- G2: `ALLOWS` — The factory accepts admin-gated or sponsor-controlled prize collections (R25 step 6).
- G3: `ALLOWS` — The victim is the winning-ticket holder.
- G4: `ALLOWS` — The pot is paid out (950/50) while the prize can never be delivered.
- Promotion/demotion: Promoted: [lenses: 1], but the full path exists in source (R25 steps 1-7, with the external pre-condition stated).
- Severity: **Medium** — Same family as M-1: it needs an external condition on the prize contract. It is listed separately under function isolation because its distinct fix is a delivery fallback.
- Final: FINDING → M-5

## D09 — `Raffle | releaseSponsorProceeds | payout-decoupled-from-prize-delivery` [lenses: 9]

- G1: `ALLOWS` — :375-382 checks only amount != 0 and the _transferQuote destination screen; there is no status or prizeClaimed check, and releaseProtocolFees (:385-392) is identical. NftWon has no exit to refunds (:292-293) or to prize return (:397-398). Redeem (:334-337) reverts atomically, which strands the winner rather than protecting them.
- G2: `ALLOWS` — internal_pre NftWon is the normal reserve-met state. The external_pre (prize transfers out of the clone blocked after escrow) costs nothing for a sponsor who administers the collection, and happens with no attacker for third-party-administered collections. The factory accepts any ERC-165 ERC-721 (F:155-177), and DESIGN.md calls prize contracts untrusted; the code does not enforce the 'honest' assumption at IRaffle.sol:14-15.
- G3: `ALLOWS` — The victim is the owner of the winning ticket (buyer cohort, including secondary-market purchasers).
- G4: `ALLOWS` — The prize is never delivered while 100% of the buyers' pot is paid out (R11: 11,400 + 600 USDC). In the upgrade/seize variant the sponsor keeps both the NFT and 95%.
- Promotion/demotion: Raw FINDINGs (R11, R34) plus 7 LEADs; [lenses: 9]; all gates ALLOWS.
- Severity: **Medium** — It needs an external condition on the prize contract: an admin-controlled transfer gate, visible on-chain before buying. Profit beyond the honest outcome exists only in the upgrade/seize variant. Torn with High (permanently stuck prize) and chose the lower.
- Final: FINDING → M-1

## D10 — `Raffle | releaseSponsorProceeds | immutable-recipient-no-reroute` [lenses: 1]

- G1: `ALLOWS` — sponsorRecipient is written once at :198, and there is no claim-to or redirect path.
- G2: `BLOCKS` — Requires Circle (trusted canonical USDC under DESIGN.md) to blacklist the recipient; there is no attacker path.
- G3: `BLOCKS` — Only the recipient the sponsor chose loses.
- G4: `ALLOWS` — The funds would be permanently stuck.
- Promotion/demotion: Not promoted: [lenses: 1], and there is no attacker path (G2/G3 BLOCK).
- Final: LEAD → Lead-4

## D11 — `Raffle | releaseProtocolFees | usdc-blacklist-immutable-recipient` [lenses: 1]

- G1: `ALLOWS` — protocolTreasury is immutable, and there is no redirect path.
- G2: `BLOCKS` — Requires Circle to blacklist the treasury; there is no attacker path.
- G3: `BLOCKS` — Only the protocol treasury loses.
- G4: `ALLOWS` — The fees would be stuck factory-wide.
- Promotion/demotion: Not promoted: [lenses: 1], and there is no attacker path (G2/G3 BLOCK).
- Final: LEAD → Lead-5

## D12 — `Raffle | releaseSponsorPrize | missing-payout-time-destination-screen` [lenses: 5]

- G1: `ALLOWS` — :402-405 makes no payout-time _isProtocolDestination check. The init-time screen skips the registry for code-less addresses (:602), and F:166 only sees clones that are already registered.
- G2: `ALLOWS` — Reachable only by the sponsor deliberately choosing a future clone CREATE address as sponsorRecipient.
- G3: `BLOCKS` — Self-harm only: the sponsor who chose the address is the only party that loses, and the receiving clone's accounting is unaffected.
- G4: `ALLOWS` — The NFT is permanently stranded in another clone.
- Promotion/demotion: Demoted: [lenses: 5], but G3 BLOCKS (self-harm only, excluded from findings by the shared rules). Kept as a surviving LEAD.
- Final: LEAD → Lead-6

## D13 — `Raffle | _update | ticket-transfer-during-pending-vrf` [lenses: 7]

- G1: `ALLOWS` — _update (:497-502) screens destinations but never status, so tickets move freely in Drawing and in the resolution block.
- G2: `UNCERTAIN` — Needs pre-inclusion visibility of the VRF fulfillment (not verified offline) plus a stale open order on a secondary market.
- G3: `ALLOWS` — Victims are counterparties with open sell listings or bids (third parties).
- G4: `UNCERTAIN` — Real value moves (R22: seller under-paid 16,500 USDC), but this is close to standard MEV on user-chosen open orders.
- Promotion/demotion: Promoted: [lenses: 7]; no code path interrupts the path.
- Severity: **Low** — Highly constrained (needs a stale order and a fulfillment visible before inclusion), with protocol accounting unaffected and bearer transferability documented (:491). Torn with Medium, chose the lower.
- Final: FINDING → L-1

## D14 — `Raffle | fulfillRandomWords | sponsor-reserve-flip` [lenses: 4]

- G1: `ALLOWS` — :521 compares totalEntries, which includes sponsor-funded entries, with reserveEntries; nothing excludes them.
- G2: `ALLOWS` — The sponsor buys the shortfall at endTime-1, and 95% of it comes back under NftWon.
- G3: `ALLOWS` — Victims are the under-reserve buyers.
- G4: `UNCERTAIN` — Expected value moves only when the NFT is worth less than about 0.8x the pot (R08 example above).
- Promotion/demotion: Promoted: [lenses: 4]; no code path interrupts the path.
- Severity: **Low** — Same as D03: torn between Medium and Low, and chose Low because the flip only pays for an over-priced reserve and CashWon is not a buyer entitlement.
- Final: FINDING → L-2

## D15 — `Raffle | fulfillRandomWords | vrf-result-preview-ticket-sniping` [lenses: 1]

- G1: `ALLOWS` — The outcome at :518 is deterministic, and transfers are open (:497-502).
- G2: `UNCERTAIN` — Mempool visibility and the coordinator's delivery semantics are not verified (wrapper and coordinator are not vendored).
- G3: `ALLOWS` — Victims are holders with resting orders.
- G4: `UNCERTAIN` — Close to generic stale-order NFT MEV.
- Promotion/demotion: Not promoted: [lenses: 1], and the external path is unverified. Same mechanism as L-1 (Raffle::_update), kept separate by function isolation.
- Final: LEAD → Lead-7

## Totals

- Findings: 0 High · 5 Medium · 3 Low · 0 Info
- Surviving leads: 7 (Lead-1=D01, Lead-2=D04, Lead-3=D07, Lead-4=D10, Lead-5=D11, Lead-6=D12, Lead-7=D15)
- Rejected (excluded from report): 0
- Completeness: 11 unique (Contract, function) in raw, 11 covered in final.
