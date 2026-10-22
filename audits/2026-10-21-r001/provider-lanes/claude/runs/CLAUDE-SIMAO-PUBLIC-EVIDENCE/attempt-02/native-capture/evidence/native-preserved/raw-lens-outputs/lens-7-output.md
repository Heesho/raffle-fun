# Lens 7: Ordering, MEV & Price Manipulation (raffle.fun)

**In-scope files:** `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol` and `libraries/RaffleConstants.sol`.

**Out-of-scope lookups:**
- `@chainlink/contracts` 1.5.0: `VRFV2PlusWrapperConsumerBase.sol` and `IVRFV2PlusWrapper.sol`. The wrapper implementation itself is not vendored, so it stays a trusted external.
- OpenZeppelin 5.6.1: `ERC721` (`_update` clears approvals) and `Clones` (uses CREATE, so clone addresses can be predicted).

**Target chain:** Ethereum L1. `hardhat.config.ts` lists the mainnet network with chainId 1, so a public mempool exists.

**Line numbers:** "L" means `Raffle.sol`; "F:" means `RaffleFactory.sol`.

**Result: 0 FINDINGs, 4 LEADs.**

Most surfaces this lens covers are absent or closed:
- There are no swaps, no price or TWAP oracle, no signatures, and no initializer that anyone can call.
- The sale, draw-request, callback and refund windows never overlap in time.
- Winning the race on any one-shot permissionless action (`requestDraw`, `settleWinningTicket`, `enableRefunds`, `release*`) gains the caller nothing.

What remains are three exposures:
- an economic one: the sponsor's self-purchases are rebated;
- a reveal-timing one: tickets can be traded while the random result is visible but not yet recorded;
- a front-run that blocks the sponsor's cancel.

None of these has both a named victim and a small code fix, so each is reported as a LEAD. LEAD 4 is mainly another lens's territory and is flagged for that lens.

## LEADs

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: sponsor-self-purchase-rebate | group_key: Raffle | _settleWinningTicket | sponsor-self-purchase-rebate
smell: Raffle.sol:544 sets the NftWon sponsor share to `grossPot - protocolFee`. grossPot (L539) includes every purchase, whoever made it. Nothing in buyEntries (L209-237) or _update (L497-502) excludes the sponsor or sponsorRecipient as buyer or recipient. So under NftWon an entry the sponsor buys from any address nets out at 1,000,000 - 950,000 = 50,000 raw units (0.05 USDC), while every other buyer pays 1 USDC. Sales close at endTime (L216), so nobody can respond to a buy in the last block before it.
  (a) Dilution under NftWon. NFT worth 10,000 USDC, reserveEntries 8,000, buyers hold N = 10,000 entries.
      1. At endTime-1 the sponsor buys k = 90,000 entries from a fresh address, paying 90,000 USDC.
      2. Anyone calls requestDraw. L521 resolves NftWon with a pot of 100,000.
      3. The sponsor calls settleWinningTicket (permissionless), then releaseSponsorProceeds, and receives 95,000 (L554, L380). That is +5,000 cash plus a 90% chance of redeeming the NFT back.
      Expected values: sponsor 9,500 -> 14,000 (+4,500); buyers 10,000 -> 1,000 (-9,000); treasury 500 -> 5,000 (+4,500).
  (b) Reserve flip from CashWon to NftWon. reserveEntries 10,000, buyers hold N = 5,000, NFT worth 3,000.
      Without the flip (CashWon): buyers EV 4,000; sponsor 750 + NFT = 3,750; treasury 250.
      At endTime-1 the sponsor buys 5,000 entries, so L521 resolves NftWon instead.
      Result: sponsor 4,500 + 50% of the NFT = 6,000 (+2,250); buyers 1,500 (-2,500); treasury 500 (+250).
  Capital is locked only from endTime-1 until settlement plus releaseSponsorProceeds, i.e. minutes after the 30-confirmation VRF callback. All numbers were recomputed with the exact integer split (fee n*50,000; NftWon sponsor share n*950,000 raw units).
unverified: Whether the design accepts sponsor participation. DESIGN.md does not forbid it, and the money map lists "may also buy entries" as a normal sponsor action. No identity check survives Sybil addresses, so there is no single small code fix. A design change such as capping the NftWon sponsor share at reserveEntries*ENTRY_PRICE, with the excess paid to the winner, fixes (a) but not (b). The losses are expected-value transfers, not deterministic theft.
description: Because L544 rebates 95% of the sponsor's own spend, a last-block dilution or reserve flip has positive expected value for the sponsor. Non-sponsor buyers carry the loss, and the treasury captures part of it.
```

```
LEAD | contract: Raffle | function: _update | bug_class: vrf-reveal-ticket-sniping | group_key: Raffle | _update | vrf-reveal-ticket-sniping
smell: Tickets stay transferable while status == Drawing and within the block that resolves the draw. _update (L497-502) only rejects protocol addresses (L599-604), and L491 says this is intended. On Ethereum L1 the Chainlink fulfillment transaction carries the VRF proof in the public mempool. A searcher can compute randomWords[0] % totalEntries + 1 (L518) and map it to a ticket with ticketRange (L451-455) before L521 executes.
  Setup: 10,000 entries, NftWon, NFT worth 20,000 USDC. Alice's ticket #57 covers 2,000 entries (EV 4,000) and has an open marketplace listing at 3,500.
  1. The searcher sees the pending fulfillment and decodes a winningEntry that falls inside #57.
  2. The searcher submits a bundle: fill Alice's listing (3,500 USDC), then the fulfillment, then redeemWinningTicket(57) (L309-346).
  3. The searcher receives the 20,000 NFT, and Alice is underpaid by 16,500.
  Mirror case: holders of losing tickets dump them into standing bids. Aggravating factor: tickets have no tokenURI and every clone returns the same name() and symbol() (L479-487), so a listing cannot show a ticket's range or the raffle's state.
unverified: That holders actually leave marketplace orders open across requestDraw. That the VRF node broadcasts publicly rather than through a private relay. Freezing transfers only during Drawing does not stop a same-block back-run of the fulfillment. The fix is therefore a design choice: block transfers other than mint and burn from requestDraw until block.timestamp > resolvedAt, and document that holders must cancel orders before the draw.
description: Because bearer tickets can be traded across a public randomness reveal, any searcher can snipe stale listings. The victims are ticket holders with open orders; the protocol's own accounting is unaffected.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: frontrun-cancel-grief | group_key: Raffle | enableRefunds | frontrun-cancel-grief
smell: The sponsor's discretionary early exit only works while totalEntries == 0 (L280-284).
  1. Before endTime, the sponsor submits enableRefunds() to withdraw an unpopular raffle.
  2. An attacker front-runs it with buyEntries(attacker, 1), paying 1 USDC.
  3. The sponsor's transaction now takes the L285-287 branch and reverts with RefundsNotAvailable(endTime + 2 days).
  The NFT stays escrowed until the VRF resolves after endTime, or until endTime + 2 days if nobody requests a draw (up to 32 days from creation).
  Attacker net cost: 0 if no draw happens (full refund), or 0.2 USDC under CashWon. If reserveEntries <= final totalEntries and nobody else buys, the attacker wins the NFT for 1 USDC plus the VRF fee.
unverified: Whether this matters. The sponsor had already committed the NFT until endTime, and the "empty raffles only" cancel rule is documented (IRaffle.sol:323). The sponsor can defend by requesting the draw, or by buying entries at the 5% effective cost described in LEAD 1.
description: A near-free 1-entry front-run removes the sponsor's only cancellation right. The impact is a longer NFT lock-up and a lost option, not theft.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: proceeds-released-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | proceeds-released-before-prize-delivery
smell: Cross-lens: this is mainly an integration/trust issue, with an ordering angle. In NftWon, permissionless settlement (L533-558) credits 95% of the pot to sponsorProceeds. releaseSponsorProceeds (L375-382) and its sibling releaseProtocolFees (L385-392) pay out without checking winnerRedeemed or prizeClaimed. The winner's side (L334-337) depends on the sponsor-chosen prize contract, which DESIGN.md calls untrusted. totalEntries is frozen at endTime, so the outcome branch at L521 is known before the VRF runs.
  1. The prize is the sponsor's own pausable or upgradeable ERC-721, and the raffle sells at least reserveEntries.
  2. After endTime, knowing the result will be NftWon, the sponsor arms a transfer block on the NFT contract.
  3. The fulfillment lands. The sponsor follows it with settleWinningTicket(w) and releaseSponsorProceeds() and receives 95% of the pot.
  4. The winner's redeemWinningTicket(w) reverts permanently at L334 or L335. No state turns this into refunds.
  Buyers lose the whole pot: 95% to the sponsor and 5% to the treasury.
unverified: The documented trust model contradicts itself. IRaffle.sol:14-15 says "Supported prizes are honest, standards-compliant ERC-721s", while DESIGN.md says "arbitrary prize contracts ... are untrusted". This is outside this lens's core scope and is flagged for the integration lens.
description: NftWon USDC payouts are released independently of NFT delivery, so a sponsor-controlled prize contract can collect the pot and block the winner. The sponsor has a timing advantage because the outcome class is known at endTime.
```

## Public audit-evidence summaries

### Value flows
- `[Model: buyEntries]` A buyer pays entryCount*1e6 USDC (L224) and receives one ticket covering entries [totalEntries+1, totalEntries+entryCount] (L226-235). The call adds the payment to unsettledPot (L233) and advances totalEntries, ticketCount and _ticketRanges. The price is fixed and USDC is pulled only from msg.sender.
- `[Model: requestDraw]` The requester pays the wrapper's native fee, priced from their own tx.gasprice (L249-258); any excess goes back to msg.sender (L262-270). The call sets status to Drawing and records drawRequestedAt and vrfRequestId. No USDC moves.
- `[Model: _settleWinningTicket]` Splits unsettledPot once (L539-555).
  - NftWon: fee n*50,000; sponsor n*950,000.
  - CashWon: winner n*800,000; sponsor n*150,000; fee n*50,000.
  - The pot is always a multiple of 1e6, so there is no rounding dust.
- `[Model: enableRefunds/refundTickets]` unsettledPot moves in full to remainingRefundLiability (L296-299). Each refund burns the caller's tickets and pays (entries in range)*1e6 (L349-372).

### Assumptions checked
- `[Why: Raffle.sol:216/242/245]` The sale window [creation, endTime) and the draw-request window [endTime, endTime+2d) do not overlap. No entry can be bought after randomness is requested, which matches Chainlink's "no new inputs after the request" guidance.
- `[Why: Raffle.sol:512 + 290-291]` The callback is accepted only while block.timestamp < drawRequestedAt+2d, and refunds open from Drawing only once block.timestamp >= drawRequestedAt+2d. In any one block only one of them can succeed, and a late callback is ignored instead of racing the refund.
- `[Why: Raffle.sol:177-179, 164; RaffleFactory.sol:106-121]` Each clone is created and initialized in the same nonReentrant transaction. The implementation is locked by its constructor, and the factory address is fixed in the implementation bytecode.
- `[Why: Raffle.sol:544]` The NftWon sponsor share is computed over all purchases, whoever the buyer is. This is the basis of LEAD 1.
- `[Why: Raffle.sol:491-502]` Ticket transfers are deliberately allowed in every state. This is the basis of LEAD 2.

### Adversarial checks
- `[Defeat: initialize]` A non-factory caller gets OnlyFactory (L178), and the implementation gets AlreadyInitialized (L177). If a third party clones the implementation itself, the clone can never be initialized. It stays in AwaitingPrize with prizeToken = 0, so onERC721Received can never succeed. There is no initialization race.
- `[Defeat: onERC721Received]` Requires AwaitingPrize, msg.sender == prizeToken, the configured tokenId, from == sponsor and operator == factory (L421-426). AwaitingPrize only exists inside createRaffle, so only the sponsor's own prize contract could fake the deposit. That is a sponsor-side problem (see LEAD 4).
- `[Defeat: createRaffle]` The NFT is pulled from msg.sender (F:128), so third parties cannot abuse a sponsor's standing approval to the factory. A front-run only changes the raffleId and the clone address. isRaffle is set before the untrusted prize code runs (F:125), which only tightens address screening. The validation calls are read-only.
- `[Defeat: buyEntries]` The price is fixed, the call takes an entry count (not shares), and there is no approval-window or slippage exposure. The only ordering lever left is a purchase at endTime-1 that crosses the reserve (LEAD 1).
- `[Defeat: requestDraw]` One-shot. Winning the race only means paying the fee. paidPrice and quotedFee use the same tx.gasprice within one transaction. ETH forced into a clone is never spent (L258). The excess-refund recipient can only re-enter unguarded ticket transfers, which leave the accounting untouched. Nobody is likely to skip the draw for lack of a paid requester, because the sponsor (15% or 95%) and the treasury (5%) both gain from it.
- `[Defeat: fulfillRandomWords/enableRefunds]` The windows never overlap, so callbacks and refunds cannot race. Residual risk: if a fulfillment arrives within a few blocks of drawRequestedAt+2d, a block builder could censor it to force refunds. That needs both an extreme VRF delay and builder collusion, so it falls under the trusted-dependency assumption.
- `[Defeat: settleWinningTicket/redeemWinningTicket]` Ticket ranges are contiguous and never overlap. IDs that were never minted read as (0,0), and winningEntry >= 1, so exactly one ticket can settle. If someone front-runs the settlement, redemption still works (L314-318). Redemption is owner-only (L320-321) and burns the ticket before delivery (L325), so a redeemed or refunded ticket cannot be resold.
- `[Defeat: releaseSponsorProceeds/releaseProtocolFees/releaseSponsorPrize]` These are permissionless with fixed recipients, so the caller gains nothing from timing.
- `[Defeat: _isProtocolDestination TOCTOU]` Only a future clone address (predictable from the factory nonce) can pass the address screen and later be rejected. That only happens if the victim picks such an address themselves, which is self-harm; a third party cannot force it on someone.

### Last-user-out tests
- `[LastOut: L3 NftWon]` n*50,000 + n*950,000 = pot. Both claims are zeroed when released, and the last claimant is paid in full. This holds for USDC; whether the NFT can actually be delivered depends on the prize contract (LEAD 4).
- `[LastOut: L3 CashWon]` n*800,000 + n*150,000 + n*50,000 = pot. Each claim is zeroed before its transfer, and the prize goes back to sponsorRecipient. The raffle stays solvent.
- `[LastOut: L4/L5 Refunding]` remainingRefundLiability = n*1e6 = the sum of unburned ticket ranges times 1e6. Tickets are burned before payment, and ownerOf reverts on burned IDs, so no ticket can be refunded twice. The last refunder is paid exactly and the subtraction never underflows.
- `[LastOut: L6 Empty]` No USDC is held, and the prize goes back through releaseSponsorPrize.

### Saturation sweep
- 95% rebate (LEAD 1): sponsor/sponsorRecipient is the only party whose own spending flows back to them. The treasury's 5% share gives it no dilution advantage. In CashWon, a sponsor purchase costs the sponsor 5% net but does not hurt other buyers, because the cash prize grows with the pot. Only NftWon and the CashWon-to-NftWon flip are harmful.
- Reveal timing (LEAD 2): the VRF fulfillment is the only state change based on hidden information. Whether the reserve is met at endTime, and when refunds open, are public and predictable.
- Front-run blocking (LEAD 3): the sponsor's cancel of an empty raffle is the only discretionary privileged action. Every other one-shot action is permissionless.
- Payouts not tied to delivery (LEAD 4): the sibling releaseProtocolFees (L385-392) has the same independence from NFT delivery. releaseSponsorPrize (L395-407) only puts the sponsor's own NFT at risk.
