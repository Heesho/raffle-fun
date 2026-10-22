# Lens 8: Denial of Service & Griefing (0xSimao), raffle.fun

Scope: `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`, `DESIGN.md`.
Cross-file context read (all under `packages/contracts/node_modules`): Chainlink `VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`; OpenZeppelin `ERC721.sol`, `ERC721Utils.sol`, `ReentrancyGuard.sol`, `SafeERC20.sol`.
Line numbers are source-file lines (`Raffle.sol` unless stated).

## Result

**0 FINDINGs, 5 LEADs** (3 inside this lens, 2 outside it and passed on to other lenses).

No third party can cheaply and permanently block any function that has to stay available:
- There is one loop (`refundTickets`). It is limited by the caller to at most 100 tickets the caller owns.
- Nothing is shared that one actor could fill up (no queue, cap or buffer).
- Each liability is zeroed and paid on its own path.
- Every Chainlink failure ends in `Refunding`, because the request, callback and refund windows have deadlines that do not overlap.

Value can be permanently trapped in one place only: the prize leg of `NftWon`. It depends on the untrusted prize contract and has no way out (LEAD 1).

## LEADs

```
LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: stuck-terminal-state | group_key: Raffle | redeemWinningTicket | stuck-terminal-state
smell: NftWon is a terminal state with no exit if the prize leg can never complete. In NftWon the NFT can only leave through prizeToken.transferFrom(address(this), winner, id) plus the ownerOf re-check (Raffle.sol:334-337). releaseSponsorPrize rejects NftWon (Raffle.sol:397-399). enableRefunds rejects every terminal status (Raffle.sol:279-293). No path turns an undeliverable prize into refunds or cash. Settlement, however, has already credited sponsorProceeds = grossPot - protocolFee (Raffle.sol:544, 554), and releaseSponsorProceeds pays it without checking prizeClaimed (Raffle.sol:375-382). Path: (1) sponsor S escrows token #1 of collection P via createRaffle with reserveEntries = 1,000; (2) buyers buy 1,000 entries = 1,000 USDC; (3) the VRF callback resolves NftWon (Raffle.sol:521); (4) anyone settles: sponsorProceeds = 950 USDC, protocolFees = 50 USDC; (5) anyone calls releaseSponsorProceeds and 950 USDC goes to sponsorRecipient; (6) P permanently blocks transfers out of the clone (admin pause, per-address blocklist, a transfer-validator policy that turns off owner-initiated transfers by contracts, or a sponsor-controlled P whose transferFrom reverts or whose ownerOf lies); (7) every redeemWinningTicket call reverts, which undoes the burn (Raffle.sol:325, 334-337). The winning ticket cannot be refunded either (Raffle.sol:350). Outcome: all 1,000 USDC from buyers is paid out (950 to the sponsor, 50 to the treasury). The winning-ticket holder keeps a claim that can never be redeemed, and the NFT is stuck in the clone with no recovery path.
unverified: (a) Whether the trust model makes this reportable. DESIGN.md says arbitrary prize contracts are untrusted, but it also says "Sponsor and treasury can claim independently after settlement", and IRaffle.sol:14-15 limits support to "honest, standards-compliant ERC-721s". (b) Whether blocking delivery adds any loss. If the sponsor controls P, blocking adds nothing over raffling a worthless token: the sponsor collects 950 either way. A sponsor also gains nothing by blocking a valuable token, because it is stuck for them too. Extra loss only appears when a third-party admin of a real collection permanently restricts transfers out of the clone. Working offline, I could not confirm any live collection that accepts the factory's inbound safeTransferFrom (RaffleFactory.sol:128) but later blocks the raffle's outbound transferFrom. (c) A temporary pause only delays the winner: there is no redemption deadline, so they can redeem after the unpause.
description: The NftWon branch ties a final state to a delivery made by an untrusted contract while paying the sponsor's 95% with no condition. The smallest code fix is to make releaseSponsorProceeds (Raffle.sol:375-382) require prizeClaimed when status == NftWon, or to add a fallback for failed delivery. Both conflict with DESIGN.md's "claim independently after settlement", and the first lets a winner who never redeems freeze the sponsor's share.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: external-dependency-dos | group_key: Raffle | requestDraw | external-dependency-dos
smell: The VRF wrapper can never change. RaffleFactory stores it as an immutable (RaffleFactory.sol:86), builds it into the single implementation (RaffleFactory.sol:89, inherited immutable i_vrfV2PlusWrapper), has no admin to repoint it, and createRaffle (RaffleFactory.sol:97-148) never checks that the wrapper still works. If the wrapper is disabled or unconfigured, getVrfRequestPrice and requestRandomnessPayInNative (Raffle.sol:249, 257) revert for every raffle. If the wrapper's subscription runs out of funds, a paid request is accepted but never fulfilled. After such an event, sponsors can still create raffles and buyers can still buy (Raffle.sol:209-237), but no raffle can ever resolve. Each one only moves to Refunding at endTime + 2d (Raffle.sol:286-287) or drawRequestedAt + 2d (Raffle.sol:290-291). Buyers' USDC and sponsors' NFTs are locked for up to 30d of sale + 2d (or + 4d). In the unfunded case, whoever requests the draw loses the native VRF fee.
unverified: The wrapper implementation is not in node_modules; only VRFV2PlusWrapperConsumerBase.sol and IVRFV2PlusWrapper.sol are. The disabled and unfunded behaviour therefore comes from public Chainlink v2.5 semantics, not from source in the repo. No principal is lost because the refund path stays intact. DESIGN.md treats the wrapper as a trusted canonical dependency and rules out mutable configuration, so this is probably accepted design. The impact is limited to time-bounded locking.
description: Because the wrapper is immutable and never checked, a deprecation on Chainlink's side puts every live and future raffle into a "lock, then refund" mode that only redeploying the factory can fix.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: griefing-cancel-block | group_key: Raffle | enableRefunds | griefing-cancel-block
smell: The sponsor can only cancel immediately while totalEntries == 0 (Raffle.sol:280-284), and any address can remove that option for 1 USDC. Path: (1) the sponsor creates a raffle with endTime = now + 30 days and reserveEntries = 500; (2) griefer G calls buyEntries(G, 1) and pays 1 USDC (Raffle.sol:209-237); (3) the sponsor's enableRefunds now reverts until drawRequestDeadline = endTime + 2 days (Raffle.sol:286-287); (4) the sponsor either pays the VRF fee to draw (CashWon: G gets 0.8 USDC, the sponsor gets 0.15 USDC and the NFT back through releaseSponsorPrize) or waits 32 days for refunds (G gets the 1 USDC back). G's cost: gas plus 1 USDC, fully recovered if refunds happen (0.2 USDC net if the sponsor draws). The sponsor's NFT stays locked for up to 32 days instead of being withdrawable at once.
unverified: It is unclear whether "closes an empty raffle immediately for the sponsor" (IRaffle.sol:323) was meant to give the sponsor a cancel right that survives a 1-USDC entry. The griefing purchase looks exactly like a real one, and the sponsor committed to endTime when creating the raffle, so this is probably accepted design. The lock is time-bounded and no principal is lost.
description: One 1-USDC entry locks the sponsor's NFT into the full sale window plus the 2-day request window, with no way back out.
```

```
LEAD | contract: Raffle | function: buyEntries | bug_class: reserve-self-dealing | group_key: Raffle | buyEntries | reserve-self-dealing
smell: (Outside the DoS lens; passed on to the economic/cross-cohort lens.) Only totalEntries >= reserveEntries decides the outcome (Raffle.sol:521), and nothing excludes entries the sponsor paid for. NftWon pays grossPot - fee back to the sponsor (Raffle.sol:544). So buying whatever is missing from the reserve costs the sponsor only the 5% fee on those entries, and lets it flip a raffle that missed its reserve after seeing demand. Path: reserve 10,000; organic buyers hold 2,000 entries (2,000 USDC) one block before endTime. The honest outcome would be CashWon: winner 1,600, sponsor 300 + NFT, treasury 100. Instead the sponsor buys 8,000 entries from a fresh address. The callback gives NftWon; settlement pays the sponsor 9,500 (net +1,500 on an 8,000 outlay), and the sponsor's address holds 80% of entries for its own NFT. With an NFT value V = 3,000 USDC, organic buyers' expected value falls from 1,600 to 600 (-1,000), the sponsor's rises from 3,300 to 3,900 (+600), and the treasury's from 100 to 500 (+400). These sum to zero.
unverified: This is not a DoS issue. It is unclear whether DESIGN.md means the reserve to protect only the sponsor, in which case a sponsor buying in is the same as having set a lower reserve. Addresses the sponsor controls cannot be identified on-chain, so any fix is at the design level.
description: Buyers rely on the 80% cash payout when the reserve is missed, but the sponsor can cancel it at 5% cost by buying in at the last moment, after seeing demand.
```

```
LEAD | contract: Raffle | function: _update | bug_class: vrf-input-after-request | group_key: Raffle | _update | vrf-input-after-request
smell: (Outside the DoS lens; passed on.) Tickets stay transferable while status == Drawing. Raffle.sol:497-502 only screens destinations, and Raffle.sol:491 says tickets are transferable "in every lifecycle state". So the input that decides who gets paid, ticket ownership, can change after the VRF request. The calldata of the coordinator's fulfillment fixes randomWords[0]. Anyone watching the mempool can therefore compute winningEntry = randomWords[0] % totalEntries + 1 (Raffle.sol:518) and the ticket that contains it before the callback lands. They can then trade ahead of it: buy the winning ticket from an open listing, or sell known losing tickets into open collection offers. Path: a CashWon raffle with 1,000 entries and a 1,000 USDC pot. Holder H has an open listing for ticket #7 (entries 101-110) at 9 USDC. The fulfillment transaction is pending, and its random word maps to entry 105. A bot fills H's listing at 9 USDC before the callback, then calls redeemWinningTicket(7) after resolution and receives 800 USDC (Raffle.sol:339-342). H gives up about 791 USDC of value.
unverified: I could not confirm offline whether Ethereum-mainnet VRF fulfillments go through the public mempool. Even if they do not, a back-run right after resolution sniping a stale listing causes the same loss to the seller. That makes the protocol's share of the blame small and mostly a question of listing hygiene. Chainlink advises against accepting inputs after a randomness request. The smallest change would be for _update to reject ticket transfers that are neither mints nor burns while status == Drawing, but that removes only the pre-resolution window.
description: Because tickets remain transferable during Drawing, anyone who reads the pending fulfillment can trade against counterparties who cannot see it.
```

## Public audit-evidence summaries

**[Model: buyEntries]** The buyer pays `entryCount × 1e6` USDC (224) and gets one ticket for the range `[totalEntries+1, totalEntries+entryCount]`. It writes `totalEntries` (230), `ticketCount` (231), `_ticketRanges` (232) and `unsettledPot += gross` (233). The recipient's mint hook runs only after all writes, under `nonReentrant` (235).

**[Model: enableRefunds]** Moves all of `unsettledPot` into `remainingRefundLiability` and sets `Refunding` (296-299). It can only be reached from `Active` or `Drawing` (279-293).

**[Model: _settleWinningTicket]** Splits the pot once and only in storage:
- fee = `pot×500/1e4` (540)
- `NftWon`: sponsor = `pot − fee` (544)
- `CashWon`: cash = `pot×8000/1e4`, sponsor = `pot − fee − cash` (546-548)
- `unsettledPot` is then zeroed (553).

**[Model: payouts]** Each claim is zeroed or flagged before its single transfer:
- `winnerProceeds` (341)
- `remainingRefundLiability -=` (368)
- `sponsorProceeds` (378)
- `protocolFees` (388)
- `prizeClaimed` (331 / 403)
- the winning ticket is burned before delivery (325).

**[Why: Raffle.sol:368]** This subtraction cannot underflow:
- The liability equals the sum of every purchase (233 → 298), which is the sum of all range lengths × 1e6.
- Ranges do not overlap, and each ticket burns once (364).
- So total refunds never exceed the liability, and they equal it once everyone has refunded.

**[Why: Raffle.sol:518]** The callback cannot revert or run out of gas:
- `totalEntries > 0` is guaranteed (243).
- `(x % totalEntries) + 1 ≤ 2^128 − 1`, so it fits in a `uint128`.
- It does a fixed amount of work, far below the 300,000 callback gas limit (RaffleConstants.sol:39).

**[Why: Raffle.sol:245 vs 287, 512 vs 291]** The request window and the refund window share one deadline, as do the callback window and the refund window. One side uses `<` and the other `>=`, so the windows cannot overlap and there is no race.

**[Why: Raffle.sol:254/260, 511]** `_requestInFlight` makes the contract ignore a callback that arrives synchronously during the request. It is never left `true`, because any revert undoes it.

**[Defeat: requestDraw]** Inside `[endTime, endTime+2d)`, no third party can block it:
- Status leaves `Active` only through `requestDraw` itself or `enableRefunds` after the deadline.
- The fee quote and the payment use the same `tx.gasprice` (249, 257-258).
- Excess ETH is refunded to `msg.sender` (264-269), so a failing refund only hurts the caller.

**[Defeat: fulfillRandomWords]** Only the immutable wrapper can call it, through `rawFulfillRandomWords` in the consumer base. An attacker cannot trigger any of the ignore conditions (511-512).

**[Defeat: refundTickets]** A batch cannot be poisoned:
- A caller can only include tickets they own (359-360).
- A batch holds at most 100 tickets (352; RaffleConstants.sol:27).
- Duplicates only revert the caller's own transaction.
- A holder blacklisted by USDC can transfer the bearer ticket to another address and refund from there.

**[Defeat: redeem CashWon / releaseSponsorProceeds / releaseProtocolFees]** These claims do not depend on each other:
- A USDC blacklist on one recipient blocks only that recipient's own claim.
- The winner can move the ticket to another address and redeem from there.
- `sponsorRecipient` and the treasury are immutable, so a blacklist on them only hurts themselves or comes from outside.

**[Defeat: _update / _transferQuote / releaseSponsorPrize screens]** The registry check only runs for addresses with code (602-604). The only destination that passes at first and fails later is a code-less future factory CREATE address that later becomes a clone. Hitting it requires the owner or sponsor to send a ticket there or to set `sponsorRecipient` to it, so it is self-harm only. `releaseSponsorPrize` (404) does not re-screen `sponsorRecipient`. In that self-inflicted case the NFT would land in another clone, which breaks DESIGN.md's "never move assets between clones" but only affects the sponsor. Not reported, per the shared rules on self-harm.

**[Defeat: createRaffle]** It is atomic. Clone, initialize, register, escrow, the `ownerOf` check and the status check (RaffleFactory.sol:105-134) all revert together, so no `AwaitingPrize` state survives a failed escrow. A malicious prize contract can fake the escrow by calling `onERC721Received` itself with `operator = factory` and lying in `ownerOf`. That feeds LEAD 1; it does not block raffle creation.

**[Defeat: loops / shared resources]** The only loop is in `refundTickets`, capped at 100 caller-owned IDs. Purchases, the callback and settlement are O(1). The winning ticket is found off-chain by binary search over `ticketRange`. Raffles have no queue, cap, buffer or pause switch that one actor could fill or toggle. The approved-operator restriction on redeem and refund (321, 360) is avoided by transferring the ticket first.

**[LastOut: L3 NftWon]** With `pot = N·1e6`: fee = `N·5e4`, sponsor = `N·9.5e5`. They add up to the pot with no dust, and each release zeroes its claim. USDC is conserved. The NFT leg depends on the prize contract (LEAD 1).

**[LastOut: L3 CashWon]** Fee `N·5e4` + cash `N·8e5` + sponsor `N·1.5e5` = pot. The three claims are independent, and the prize goes back through `releaseSponsorPrize`. Pass.

**[LastOut: L4/L5 Refunding]** `remainingRefundLiability = N·1e6`. The last refunder's batch equals exactly the liability that remains, in any order. Pass.

**[LastOut: L6 Empty]** The liability is 0 and the prize goes back to `sponsorRecipient`. Pass.

## Closing tests

- **Last User Out.** Every USDC path passes in the worst order. The only gap is the NFT leg in `NftWon` (LEAD 1).
- **Saturation, LEAD 1 shape** (a final state that depends on an outside delivery and has no fallback):
  - `releaseSponsorPrize` in `CashWon`/`Refunding` only hurts the sponsor.
  - `releaseSponsorProceeds` and `releaseProtocolFees` only hurt their own immutable recipient.
  - `redeemWinningTicket` in `CashWon` and `refundTickets` can be re-routed by transferring the ticket.
  - Only `NftWon` redemption ties one group's payout to another's delivery.
- **Saturation, LEAD 2 shape** (an outside dependency covered by a timeout): every Chainlink failure mode ends in `Refunding` through the two deadlines. A USDC pause or blacklist is an event of a trusted dependency. The only other outside call is the factory registry, which belongs to the same deployment and is trusted.
- **Saturation, LEAD 3 shape** (a sponsor-only right that a third party can remove): the empty-raffle cancel is the only one.
