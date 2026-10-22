# Lens 9: Access, Authorization & Trust Boundaries. raffle.fun (Raffle clone + RaffleFactory)

Result: **0 FINDINGs, 4 LEADs.** Every entry point I listed enforces the right caller, owner, state and time checks. No path lets a third party take value from someone who did not opt into the risk. The leads are trust-boundary and design-tension issues where the victim's exposure depends on what they chose (the prize contract, open marketplace orders, the reserve design) or where only the actor harms itself.

Line references are `packages/contracts/src/Raffle.sol` unless prefixed `F:` (`RaffleFactory.sol`) or `I:` (`interfaces/IRaffle.sol`).

## FINDINGS

None survived. No unguarded, exploitable path with a named third-party victim was found.

## LEADS

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: untrusted-prize-delivery-decoupled | group_key: Raffle | releaseSponsorProceeds | untrusted-prize-delivery-decoupled
smell: In NftWon, _settleWinningTicket allocates 95% of the pot to sponsorProceeds (Raffle.sol:543-544, :554). releaseSponsorProceeds (Raffle.sol:375-382) pays it out with no dependency on the NFT leg. prizeClaimed is set only at :331, immediately before the delivery at :334-336. Whether the prize was escrowed and delivered is checked only by asking the prize contract itself: ownerOf at F:129 and Raffle.sol:335. Activation also trusts the operator/from arguments that this same contract passes to onERC721Received (Raffle.sol:422-428). DESIGN.md says "arbitrary prize contracts ... are untrusted". I:14-15 instead assumes "honest, standards-compliant ERC-721s".
unverified: Concrete only for a sponsor-controlled prize contract: (1) sponsor deploys a pausable ERC-721 and creates a raffle with reserve 10,000; (2) buyers buy 10,000 entries (10,000 USDC); (3) VRF resolves NftWon, anyone settles, releaseSponsorProceeds pays 9,500 USDC to sponsorRecipient and the treasury takes 500; (4) the sponsor pauses transfers, so redeemWinningTicket reverts at :334 forever. The winner, and every buyer whose USDC formed the pot, hold the loss. I could not show an honest-sponsor case where delivery fails permanently after payout: a third-party admin pause or ERC721C validator change can, and ENS expiry is recoverable by renewal during grace. DESIGN.md also says "Sponsor and treasury can claim independently after settlement", so gating sponsor proceeds on prizeClaimed would contradict the spec. No on-chain check can defend against a prize contract that lies in ownerOf.
description: The spec cannot both treat prize contracts as untrusted and release the sponsor's 95% independently of NFT delivery. The money map's cross-asset coupling is a real trust gap, bounded only by buyers vetting the prize contract.
```

```
LEAD | contract: Raffle | function: _update | bug_class: transfer-during-pending-randomness | group_key: Raffle | _update | transfer-during-pending-randomness
smell: _update (Raffle.sol:497-502) gates ticket transfers only on protocol destinations, never on status, so tickets keep trading while status == Drawing. The VRF v2.5 fulfillment transaction carries the proof in its calldata. Anyone who simulates it before inclusion can compute winningEntry = word % totalEntries + 1 (Raffle.sol:518), find the winning ticket via ticketRange, and act first: fill a standing marketplace sell order for the winning ticket at its pre-draw price, or dump a losing ticket into a standing bid. The victim is the holder with the open sell order or the bidder.
unverified: Needs an off-chain standing order that stays open through the roughly 30-confirmation callback window. Judges may treat this as ordinary MEV on user-chosen orders. The NatSpec (Raffle.sol:491, I:12-13) explicitly keeps tickets transferable "in every lifecycle state". Blocking transfers only during Drawing would also not protect listings left open after resolution.
description: Chainlink's guidance is to stop accepting user inputs once randomness is requested. Here ownership of the claim stays tradeable while the result sits in the mempool, so watchers can extract value from holders with open orders.
```

```
LEAD | contract: Raffle | function: buyEntries | bug_class: sponsor-self-dealing-reserve | group_key: Raffle | buyEntries | sponsor-self-dealing-reserve
smell: buyEntries (Raffle.sol:209-237) places no restriction on the sponsor or sponsorRecipient. The outcome is decided by totalEntries >= reserveEntries (Raffle.sol:521) over gross entries, including the sponsor's own. NftWon pays 95% of the gross pot to sponsorRecipient (Raffle.sol:543-544). So the sponsor can cross its own reserve at a net cost of 5% of the shortfall and flip a CashWon (80% cash to a buyer) into an NftWon (95% to itself).
unverified: Unclear whether this counts as a defect or as an accepted property of the reserve design. Sybil addresses make a msg.sender != sponsor check useless, so there is no minimal on-chain fix. Numbers: reserve 1,000; buyers hold 900 entries (900 USDC); NFT worth 300 USDC. Honest CashWon: winner 720, sponsor 135 + NFT, treasury 45. If the sponsor buys 100 entries just before endTime, the result is NftWon: sponsor receives 950 (net +850 after paying 100, plus a 10% chance at its own NFT); buyers' expected value falls from 720 to 0.9 x 300 = 270 (-450); sponsor gains about +445; treasury gains +5.
description: The reserve is meant to measure third-party demand, but the payee can satisfy it, letting the privileged sponsor turn buyers' cash-lottery expectation into its own proceeds.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-payout-time-destination-screen | group_key: Raffle | releaseSponsorPrize | missing-payout-time-destination-screen
smell: USDC payouts re-screen the recipient at payout time through _transferQuote (Raffle.sol:564-567). The two NFT payouts, releaseSponsorPrize (Raffle.sol:404) and redeemWinningTicket NftWon (Raffle.sol:334), do not. Two earlier screens both accept a not-yet-deployed CREATE address of the factory's next clone as sponsorRecipient: the init-time screen (Raffle.sol:193 via _isProtocolDestination, which skips the registry for code-less addresses at :602) and the factory screen (F:166, isRaffle mapping). Once a clone is created at that address, anyone can call releaseSponsorPrize and push the prize into another raffle clone. That breaks DESIGN.md "Never move assets between raffle clones", and the NFT cannot be recovered there (no rescue path, Raffle.sol:410-411). releaseSponsorProceeds meanwhile reverts with InvalidQuoteDestination forever.
unverified: No third-party victim: only the sponsor chooses sponsorRecipient, so the loss is self-inflicted, and the receiving clone's own accounting is unaffected. The ticket-side sibling (_update, Raffle.sol:498, same code-less gap) is also self-harm only.
description: The destination screen is applied unevenly across asset types and can be bypassed with counterfactual clone addresses, so the spec invariant is enforced for USDC but not for the prize NFT.
```

## Public audit-evidence summaries

### Model
- [Model: buyEntries] The buyer pays entryCount x 1,000,000 USDC from msg.sender (Raffle.sol:223-224). In return they get one ticket covering the contiguous range [totalEntries+1, totalEntries+entryCount] (:226-232). Writes totalEntries, ticketCount, _ticketRanges, and unsettledPot += gross (:233).
- [Model: _settleWinningTicket / redeemWinningTicket] Settlement splits unsettledPot into protocolFees (5%), winnerProceeds (80%, CashWon only) and sponsorProceeds (the remainder) (:539-555). Redemption burns the winning ticket and pays the current owner: the NFT for NftWon (:329-337) or winnerProceeds for CashWon (:338-342).
- [Model: enableRefunds / refundTickets] enableRefunds moves unsettledPot into remainingRefundLiability (:296-299). refundTickets burns caller-owned tickets and pays the sum of their ranges x 1e6, decrementing the liability (:356-369).
- [Model: release*] releaseSponsorProceeds, releaseProtocolFees and releaseSponsorPrize are permissionless pushes to immutable recipients (:375-406).
- [Model: createRaffle] The factory pulls exactly params.prizeTokenId from msg.sender into the clone (F:128), after initialize and the registry writes (F:110-125).

### Why
- [Why: Raffle.sol:178] Clone initialization requires msg.sender == the immutable factory and an unset `initialized` flag. The implementation locks itself in its constructor (:164-165). Clone creation and initialize happen atomically inside the nonReentrant createRaffle (F:97-125), so nobody can claim a predictable CREATE address first.
- [Why: VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords] Checks msg.sender == the immutable i_vrfV2PlusWrapper before forwarding to fulfillRandomWords (node_modules @chainlink/contracts 1.5.0).
- [Why: Raffle.sol:422-426] onERC721Received binds the call to msg.sender == prizeToken while status is AwaitingPrize. The operator and from values are reported by that sponsor-chosen contract itself, so activation is only as trustworthy as the prize contract (feeds LEAD 1).
- [Why: F:128 / Raffle.sol:224] Both token pulls use from = msg.sender. No function takes a caller-supplied from, token or target, so earlier approvals to the factory or a clone cannot be spent by a third party.
- [Why: OZ ReentrancyGuard 5.6.1] The guard uses a namespaced slot and only treats the value 2 (ENTERED) as locked. A clone's zeroed slot therefore reads as unlocked, so nonReentrant works on clones even though their constructor never runs.

### Defeat
- [Defeat: initialize] A non-factory caller gets OnlyFactory, and a second call gets AlreadyInitialized. A rogue ERC-1167 clone of the implementation deployed outside the factory can never be initialized and stays inert: prizeToken = 0, so onERC721Received reverts, and buyEntries needs Active.
- [Defeat: onERC721Received] Unrelated NFTs, re-deposits after activation, and a wrong id, from or operator all revert with UnexpectedPrize. Only the sponsor-chosen prize contract can spoof the call, and only while createRaffle is running.
- [Defeat: refundTickets] A foreign ticket gets NotTicketOwner (:360). A duplicate id fails on the second ownerOf because the ticket is already burned. Id 0 or an unminted id makes ownerOf revert. An approved operator must transfer the ticket to itself first. Refunds are impossible outside Refunding (:350).
- [Defeat: redeemWinningTicket] A non-owner gets NotTicketOwner (:321), which also reverts the inline settlement. A wrong ticket gets TicketDoesNotContainWinningEntry (:583) or WinningTicketMismatch (:317). A second redemption gets WinningTicketAlreadyRedeemed (:310). If a third party settles first, the owner can still redeem through the else-branch (:316-318).
- [Defeat: settleWinningTicket] Anyone can call it, but it only writes storage. Ranges are contiguous and disjoint (:226-232) and unminted ids read (0,0), so only the one ticket containing the winning entry passes (:579-585).
- [Defeat: enableRefunds] Every early call reverts (:280-294): a non-sponsor before endTime on an empty raffle, a sold raffle before endTime+2d, a Drawing raffle before drawRequestedAt+2d, and any terminal state. Someone can block the sponsor's early cancel of an empty raffle by buying 1 entry, but that only restores the endTime lock the sponsor chose, and the attacker's entry is refundable or returns 80%. No loss.
- [Defeat: requestDraw] Anyone may pay for the draw. Request timing cannot influence the VRF output. The excess refund goes only to msg.sender, so a reverting requester only fails its own transaction, and nonReentrant blocks reentry from the refund call (:264-270).
- [Defeat: release*] Recipients come from immutable storage and cannot be redirected by whoever triggers the release.
- [Defeat: createRaffle] Pulling a third party's approved NFT fails because from = msg.sender (ERC721IncorrectOwner). prizeToken cannot be the factory, USDC, the wrapper, the implementation or a registered raffle (F:157-162). It also cannot be a not-yet-deployed clone, because code is required (F:155).
- [Defeat: _update] Mints or transfers to this contract, the factory, USDC, the wrapper, prizeToken, the implementation or a registered raffle revert (:498-500, :599-604). Code-less counterfactual addresses pass, which is self-harm only (LEAD 4 sibling). The _safeMint callback (:235) runs after all state writes. The recipient can move the ticket before TicketPurchased (:236) is emitted, but that only affects off-chain event ordering, which DESIGN.md covers ("frontend discovery is advisory").
- [Defeat: fulfillRandomWords] A non-wrapper caller gets OnlyVRFWrapperCanFulfill. In-flight, wrong-id, wrong-length, late and post-Refunding callbacks are ignored (:510-516). The callback and refund windows do not overlap even at the exact boundary, because both comparisons use >=.

### LastOut
- [LastOut: L3 NftWon] With pot P = N x 1e6: fee = N x 50,000 and sponsor = N x 950,000, which sum to exactly P. Both can be released independently, and the NFT goes to whoever currently owns the winning ticket. The USDC side conserves exactly. The NFT side depends on the prize contract cooperating (LEAD 1).
- [LastOut: L3 CashWon] Winner N x 800,000 + sponsor N x 150,000 + fee N x 50,000 = P exactly, with no dust. The prize returns to sponsorRecipient. All four claims are independent. Holds.
- [LastOut: L4/L5 Refunding] remainingRefundLiability = P = the sum of all ranges x 1e6. Tickets are burned only by refund or redemption, and NftWon/CashWon can never reach Refunding (:289-294). So the last refunder is paid in full and the liability ends at 0. Holds.
- [LastOut: L6 Empty] P = 0, the liability is 0, and the prize is returned via releaseSponsorPrize. Holds.
- [LastOut: L7 Ticket market] Whoever owns the ticket at redeem or refund time is paid. No third party can force a ticket into custody it cannot leave, since only the owner or an approved operator can move it. Holds, apart from LEAD 2 (trading while randomness is pending).

### Saturation sweep
- Prize delivery decoupled from payouts (LEAD 1): NftWon is the only branch where a third party (the winner) can lose. The CashWon and Refunding prize returns (:404) only put the sponsor's own NFT at risk.
- No re-screen at payout time (LEAD 4): the _transferQuote sites :342, :369, :380 and :390 re-screen; the NFT sends at :334 and :404 do not. The code-less gap at :602 is reached from initialize (:187, :190, :193), _update (:498) and _transferQuote (:565), and the factory's mapping checks are at F:159 and F:166. Every instance is self-harm only.
- Transfers allowed in every status (LEAD 2): _update (:497) is the only transfer gate.
- Sponsor can buy entries (LEAD 3): buyEntries (:209) is the only function that changes totalEntries.
- Owner checks: only :321 and :360 act on other people's tickets, and both check the current owner. There are no other caller-supplied from, token or target parameters. createRaffle's prizeToken is validated at F:155-179.
