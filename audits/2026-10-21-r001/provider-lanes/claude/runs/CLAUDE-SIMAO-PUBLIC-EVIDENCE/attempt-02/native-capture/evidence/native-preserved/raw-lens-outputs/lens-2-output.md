# Lens 2 — Shares, Exchange Rates & Redemption (0xSimao) — raffle.fun

Scope: `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`, `DESIGN.md`. Dependency lookups: OZ 5.6.1 `ERC721`, `ERC721Utils`, `ReentrancyGuard`, `Clones`; Chainlink 1.5.0 `VRFV2PlusWrapperConsumerBase` (node_modules). All line numbers are real file lines (`Raffle.sol` unless prefixed).

**Result: 0 FINDING, 3 LEAD.**

This lens covers three claim-to-value conversions: ticket range to refund (fixed 1e6 per entry), winning ticket to NFT or 80% cash, and pot to the sponsor/treasury split. In every terminal state each conversion conserves value exactly. Each receipt is spent at most once and no round trip makes a profit. There is no live-balance or donatable denominator. The three issues left over are economic or design-level, so they are reported as LEADs.

## FINDINGS

None survived verification.

## LEADS

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: sponsor-self-entry-rebate | group_key: Raffle | _settleWinningTicket | sponsor-self-entry-rebate
smell: The NftWon branch at Raffle.sol:543-544 (stored at :554) credits sponsorRecipient with 95% of grossPot, and grossPot includes entries the sponsor bought itself. buyEntries (Raffle.sol:209-237) accepts any payer. So a sponsor-funded entry costs the sponsor only 5% net, yet it has the same win probability as a buyer's entry that costs 100%, and it dilutes buyers' odds on the fixed-value NFT.
  (A) Reserve already met: R=1,000, buyers B=1,000 entries, NFT worth V=1,000 USDC. Honest result: sponsor gets 950 and buyers' EV is 1,000. A sybil sponsor buys k=1,000 entries in the last block before endTime (sales close at :216, so buyers cannot respond). Pot is 2,000, so sponsorProceeds=1,900 and protocolFees=100. Sponsor ends with 900 net cash plus a 50% chance the NFT comes back (EV 500), total 1,400 (+450). Buyers' EV falls to 500 (−500). Treasury gains 50. The optimum is k* = sqrt(20·V·B) − B ≈ 3,472: buyers lose ≈776 USDC of EV (77.6%) and the sponsor gains ≈603.
  (B) Reserve flip: R=1,000, V=500, B=500. Honestly this ends CashWon and the buyers' winner gets 400 USDC. The sponsor buys 500 entries, forcing NftWon. Sponsor gets 950−500=450 plus NFT EV 250, total 700 against 575 honest (+125). Buyers' EV falls from 400 to 250 (−150).
  In CashWon, sponsor entries do no harm: buyers' combined EV stays 0.8·B because the prize grows with the pot. The leak only exists in NftWon.
unverified: DESIGN.md neither forbids nor discloses sponsor participation, so it is unclear whether it is an accepted raffle trust assumption. Sponsor purchases cannot be told apart from sybil buyers, so no single code operation removes the root cause. Partial fix: cap sponsorProceeds at reserveEntries×ENTRY_PRICE×95% and send the surplus to the winner/cash pool. That removes variant A; variant B would still need disclosure.
description: The NftWon split rebates 95% of what the sponsor pays for its own entries back to sponsorRecipient, so the sponsor can buy odds on its own NFT at a 95% discount and shift expected value from ticket buyers to itself and the treasury.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: prize-leg-decoupled-payout | group_key: Raffle | releaseSponsorProceeds | prize-leg-decoupled-payout
smell: In NftWon, _settleWinningTicket (Raffle.sol:543-544, :554-555) makes 95% sponsorProceeds and 5% protocolFees releasable right away through releaseSponsorProceeds (:375-382) and releaseProtocolFees (:385-392). Neither depends on the winner's prize transfer in redeemWinningTicket (:329-337: prizeToken.transferFrom plus an ownerOf check) ever succeeding. DESIGN.md says prize contracts are untrusted. Suppose the prize contract stops honouring the clone's transfer after settlement, for example through a collection-admin pause, an ERC721C-style transfer-validator policy raised after deposit, or an upgradeable collection the sponsor controls. Then every redemption reverts. The winning ticket has no fallback claim: no conversion to CashWon, no refund, no timeout. The NFT is stranded in the clone after 100% of the pot has left.
  Example: 10,000 entries with R=10,000 gives NftWon. Settlement releases 9,500 to the sponsor and 500 to the treasury. Prize transfers then freeze, and the winning-ticket holder (from the buyer cohort that funded the pot) receives nothing.
unverified: The trust model conflicts. IRaffle.sol:14-15 says supported prizes are honest, standards-compliant ERC-721s, while DESIGN.md calls prize contracts untrusted. A fully malicious prize is economically just a worthless prize, which no escrow can protect against, so real impact depends on the case where a third party freezes the collection. DESIGN.md also requires sponsor and treasury to claim independently after settlement, so holding proceeds until delivery would conflict with the spec. Sibling: receipt-type prizes whose value a third party can drain while escrowed (e.g. cancelable stream NFTs) have the same decoupled payout.
description: NftWon pays the whole pot to sponsor and treasury whether or not the escrowed NFT can still be delivered, so if the prize contract later freezes the transfer, the winning ticket is left with a claim it cannot redeem and no cash or refund fallback.
```

```
LEAD | contract: Raffle | function: _update | bug_class: post-request-ticket-transfer | group_key: Raffle | _update | post-request-ticket-transfer
smell: _update (Raffle.sol:497-502) only screens destinations, so tickets can still move during Drawing: after requestDraw (:252) and before fulfillRandomWords (:509-524) records the result. winningEntry = randomWords[0] % totalEntries + 1 (:518) follows deterministically from the VRF proof in the pending Chainlink fulfillment transaction. A mempool observer can therefore know the winning ticket before the callback is included and act ahead of it: (a) fill standing collection-wide offers with tickets known to lose, or (b) buy the winning ticket from a pending listing. Chainlink's VRF guidance is to stop accepting inputs once randomness has been requested.
unverified: The VRF v2.5 coordinator is not vendored in node_modules, so I did not verify how the word is derived from the proof or whether fulfillments pass through the public mempool. Transferability in every state is an explicit design choice (Raffle.sol:25-29 NatSpec, DESIGN.md). Only secondary-market counterparties trading during Drawing can be hurt.
description: Tickets stay transferable while the draw outcome can be worked out publicly from the pending VRF fulfillment, so informed holders can offload losing tickets or snipe the winning ticket from counterparties who don't know the result.
```

## Public audit-evidence summaries

- **[Model: buyEntries]** The buyer pays `entryCount × 1e6` USDC (:223-224) and gets one ticket covering `[totalEntries+1, totalEntries+entryCount]` (:226-232). `unsettledPot += grossAmount` (:233). So before any terminal state, `unsettledPot == totalEntries × 1e6 == Σ ranges × 1e6`.
- **[Model: refundTickets]** The owner burns their own tickets (:359-364) and receives `Σ(last−first+1) × 1e6` (:367, :369). `remainingRefundLiability −= amount` (:368). The same fixed rate applies both ways, so a buy-then-refund round trip makes exactly zero.
- **[Model: _settleWinningTicket / redeemWinningTicket]** For pot P = n·1e6: fee = n·50,000 (:540). In NftWon the sponsor gets n·950,000 (:544). In CashWon the winner gets n·800,000 and the sponsor n·150,000 (:546-547). Each split sums to exactly P with no dust. The winner burns the ticket, then receives the NFT or cash (:323-342).
- **[Model: releaseSponsorProceeds / releaseProtocolFees / releaseSponsorPrize]** Each zeroes the balance or sets the flag before transferring to an immutable recipient (:376-380, :386-390, :400-405).
- **[Why: Raffle.sol:368]** The subtraction cannot underflow. The liability is set to `unsettledPot` (Σ of all ranges × 1e6) at :296-298. In Refunding no ticket has ever been burned: burns happen only in refund or winner redemption, and NftWon/CashWon cannot reach Refunding because `enableRefunds` only accepts Active or Drawing (:279-294).
- **[Why: Raffle.sol:518]** `totalEntries > 0` (requestDraw :243) and it is frozen once endTime passes (:216 against :242). So `winningEntry ∈ [1,totalEntries]`. Ranges are contiguous and disjoint (:226-227), so exactly one ticket contains the winning entry, and it is still unburned at settlement.
- **[Why: OZ ReentrancyGuard 5.6.1]** A clone's guard slot starts at 0, which is not ENTERED(2), so the guard works without the constructor running. Every value-moving raffle function is `nonReentrant`.
- **[Why: Raffle.sol:451-455]** Ranges stay readable after a burn, but every value path is gated on `ownerOf`, which reverts for burned IDs. A historical range therefore cannot be spent again.
- **[Defeat: refundTickets]** Tested: duplicate IDs (the second `ownerOf` reverts), foreign IDs, ID 0, IDs above `ticketCount`, and calls outside Refunding. All revert. The amount comes from immutable ranges, so burn order cannot change it. Guard holds.
- **[Defeat: redeemWinningTicket]** Tested: a second redemption (`winnerRedeemed` :310 and the burned ticket), a non-winning ticket (range check :538/:579-585, or mismatch :316), and a non-owner caller (:321). Redeeming NftWon after the sponsor has taken the prize is impossible because releaseSponsorPrize only runs in CashWon/Refunding (:397). A failed delivery reverts the burn (ownerOf check :335; SafeERC20). Guard holds.
- **[Defeat: enableRefunds / fulfillRandomWords]** The windows do not overlap, even at the exact boundaries. The callback is valid only while `now < drawRequestedAt+2d` (:512); refunds open when `now ≥` that deadline (:290-291). A draw can be requested while `endTime ≤ now < endTime+2d`; refunds open at `now ≥ endTime+2d`. No ticket can be both refundable and redeemable.
- **[Defeat: _transferQuote / _update screens (time-of-check vs time-of-use)]** `isRaffle` is only queried when `code.length != 0` (:602-604). The only way to exploit this is for a holder or sponsor to pick a factory clone address that is not yet deployed (it is predictable from the CREATE nonce) as a ticket recipient or sponsorRecipient. That only harms whoever made the choice. releaseSponsorPrize (:402-405) does not re-screen sponsorRecipient, so in that self-chosen case the NFT lands in another clone, against DESIGN.md's "Never move assets between raffle clones" rule. Only the sponsor loses, so it is not reported.
- **[Defeat: round trips]** Buying n entries and refunding them returns exactly n·1e6. There is no exchange rate, no `balanceOf` read and no donation surface: `accountedQuoteBalance` is a view and is never used for payouts. A sponsor buying its own entries in CashWon does no harm (sponsor EV is −0.05 per entry; buyers keep 0.8·B). NftWon is the only branch where it extracts value (LEAD 1).

## Closing tests

- **[LastOut: Refunding (L4/L5/L6)]** The liability equals P = Σ ranges × 1e6. Refunds in any order sum to P, and the last refunder's subtraction lands exactly on 0. The prize returns once through `releaseSponsorPrize`. **Pass.**
- **[LastOut: NftWon (L3)]** P splits into 0.05P for the treasury and 0.95P for the sponsor, each releasable on its own, summing to P. The NFT goes once to the current owner of the winning ticket. USDC conservation **passes**; the delivery gap is LEAD 2.
- **[LastOut: CashWon (L3)]** P splits into 0.8P for the winner, 0.15P for the sponsor and 0.05P for the treasury, each claimable on its own in any order. The NFT returns once to sponsorRecipient. **Pass.**
- **Saturation sweep:**
  - Shape "payout independent of the other leg": checked `releaseSponsorProceeds`, `releaseProtocolFees` (both in LEAD 2), `releaseSponsorPrize` (fine, because the CashWon cash leg uses trusted USDC) and the winner's cash leg (fine).
  - Shape "proceeds credited on the sponsor's own entries": checked the NftWon split (LEAD 1) and the CashWon split (harmless).
  - Shape "transfer while value hinges on pending information": only the Drawing state qualifies (LEAD 3). Before the request nothing is pending, and after the callback the result is public on-chain.
  - Shape "destination screen not re-run at payout": `_transferQuote` re-screens. `releaseSponsorPrize` and the NftWon delivery do not, but these only hurt the party who chose the address, so they are not reported.
  - Shape "spend without burn": none found. Every USDC or NFT outflow either burns a ticket or zeroes or flags a one-time claim before the transfer.
  - The factory holds no value and issues no claims, so nothing to sweep there.
- **Checked and not reported:**
  - `reserveEntries` has no upper bound (RaffleFactory.sol:178 only rejects 0). A sponsor could make NftWon impossible to reach, but the parameter is public on-chain and DESIGN.md treats the frontend as advisory, so it is a transparent setting rather than a bug.
  - Approved operators cannot redeem or refund (:321, :360). This is an intentional design limitation; the owner can transfer the ticket first, so nobody loses funds.
  - USDC blacklisting of a ticket owner can be worked around by transferring the ticket. A blacklisted sponsorRecipient or treasury only hurts the party who chose that address.
