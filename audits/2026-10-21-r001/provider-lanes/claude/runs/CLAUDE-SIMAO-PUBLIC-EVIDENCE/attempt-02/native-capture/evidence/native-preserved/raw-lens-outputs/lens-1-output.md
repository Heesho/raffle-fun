# Lens 1 — Accounting Desync — raffle.fun (Raffle clone + RaffleFactory)

**Scope:** `packages/contracts/src/{Raffle.sol, RaffleFactory.sol, interfaces/*, libraries/RaffleConstants.sol}` and `DESIGN.md`.
**Dependencies checked:** OZ 5.6.1 (`ERC721`, `ReentrancyGuard`, `Clones`) and Chainlink 1.5.0 (`VRFV2PlusWrapperConsumerBase`).
**Line references:** `Raffle.sol` unless marked `F:` (`RaffleFactory.sol`) or `I:` (`IRaffle.sol`).

## Verdict

**0 FINDINGs, 3 LEADs.**

- **USDC ledger:** exactly conserved in every reachable lifecycle.
- **Tracked totals:** each of `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds` and `protocolFees` has a matching credit and debit.
- **Split:** exact, with no dust.
- **No shortfall found:** no sequence makes recorded claims exceed the USDC held, and none leaves the last claimant short.
- **Only drift-shaped item (LEAD-1):** in `NftWon`, the sponsor's USDC payout does not depend on the NFT ever being delivered.

## LEADs

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: sponsor-paid-before-prize-delivery | group_key: Raffle | _settleWinningTicket | sponsor-paid-before-prize-delivery
smell: In the NftWon branch, the full sale price for the NFT, sponsorAmount = grossPot - protocolFee (95%), is credited to sponsorProceeds at settlement (Raffle.sol:544, :554). releaseSponsorProceeds (:375-380) pays it with no check of prizeClaimed or winnerRedeemed, so the USDC leg is never tied to the NFT leg (redeemWinningTicket :334-336). No state turns an undeliverable prize into a cash or refund claim: releaseSponsorPrize is barred in NftWon (:397-398), enableRefunds is barred after resolution (:292-293), and there is no deadline or fallback.
unverified: Whether a prize that can refuse transferFrom(raffle, winner, id) after escrow is in the threat model. DESIGN.md says "arbitrary prize contracts ... are untrusted", but it also says "Sponsor and treasury can claim independently after settlement", and IRaffle.sol:14-15 says "Supported prizes are honest, standards-compliant ERC-721s". Against a fully malicious prize, coupling alone would not protect buyers either, because the contract could fake delivery. The defect bites hardest for collections that are honest but can restrict transfers (pause, creator transfer-approval hooks, transfer-validator level changes, migrations) and for owner-upgradeable prize contracts.
description: Concrete path. (1) Sponsor creates a raffle (reserveEntries = 1,000) whose prize is an owner-upgradeable ERC-721 that passes F:154-179 and the escrow checks at F:128-134. (2) Buyers buy 5,000 entries, so USDC held is 5,000e6. (3) VRF resolves to NftWon. (4) Sponsor upgrades the prize so transfers out of the raffle revert. (5) Anyone calls settleWinningTicket(w): sponsorProceeds = 4,750e6 and protocolFees = 250e6. (6) releaseSponsorProceeds sends 4,750 USDC to sponsorRecipient. (7) redeemWinningTicket(w) reverts at :334 forever. USDC is conserved (5,000 in = 4,750 + 250 out), but the winning-ticket holder is left holding the loss: no NFT and no USDC claim. With an upgradeable prize the sponsor can also recover the NFT. Minimal mitigation if in scope: in releaseSponsorProceeds, require prizeClaimed when status == NftWon. Trade-off: a winner who never redeems then also defers the sponsor's proceeds.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-payout-destination-screen | group_key: Raffle | releaseSponsorPrize | missing-payout-destination-screen
smell: All four USDC exits re-screen the payee at payout time via _transferQuote -> _isProtocolDestination (Raffle.sol:565). The NFT exit releaseSponsorPrize (:402-405) sends the prize to sponsorRecipient with no payout-time screen. sponsorRecipient is screened only once, at initialize (:193-195), and isRaffle is queried only when the address already has code (:602-603). F:166 likewise checks only raffles that are already registered.
unverified: Any victim other than the sponsor. The screen result can flip only if sponsorRecipient is a code-less address that later becomes a factory clone (the CREATE address keccak(rlp(factory, nonce)), via OZ Clones.clone). Only the sponsor chooses that address, so the harm found so far is self-inflicted.
description: If sponsorRecipient is set to the factory's future clone address, releaseSponsorPrize moves the prize into another raffle clone, where no path can release it. That violates DESIGN.md "Never move assets between raffle clones". The USDC sibling reverts instead (sponsorProceeds frozen). Minimal mitigation: in releaseSponsorPrize, revert if _isProtocolDestination(recipient, address(prizeToken)), mirroring _transferQuote.
```

```
LEAD | contract: Raffle | function: _update | bug_class: outcome-frontrun-ticket-transfer | group_key: Raffle | _update | outcome-frontrun-ticket-transfer
smell: Tickets stay freely transferable while status == Drawing (_update only screens destinations, Raffle.sol:497-502). The outcome winningEntry = randomWords[0] % totalEntries + 1 (:518) is a pure function of the pending VRF fulfillment's proof, because totalEntries is frozen once the sale ends (:216, :242).
unverified: Whether fulfillments on the target chain travel through a public mempool, and whether ticket bids or listings of meaningful size exist. This is a Phase-4 cross-time transfer of loss between ticket-market counterparties, not a protocol ledger drift. DESIGN.md's bearer-claim model and "transaction decisions must reread current chain state" may accept it.
description: A holder who computes that their ticket loses can sell into a standing bid, or a searcher can buy a listed winning ticket, in the block before the callback lands. The counterparty is left holding a zero-value ticket or loses the prize. Possible mitigation: block ticket transfers while status == Drawing.
```

## Public audit-evidence summaries

### Money model

- **[Model: buyEntries]** (`:209-237`)
  - The buyer pays `entryCount·1e6` USDC (`:223-224`) and gets one ticket covering `[totalEntries+1, totalEntries+entryCount]` (`:226-232`).
  - The same `grossAmount` drives every total: `totalEntries = lastEntry` (`:230`), `++ticketCount` (`:231`), `unsettledPot += grossAmount` (`:233`).
  - Before any terminal state: `unsettledPot == totalEntries·1e6 == Σ ranges·1e6`.
- **[Model: enableRefunds]** (`:276-301`)
  - Reachable only from `Active` or `Drawing` (`:279-293`).
  - Moves `unsettledPot` into `remainingRefundLiability` one-for-one (`:296-298`).
  - No ticket can be burned before this point, so the liability equals Σ unburned ranges·1e6.
- **[Model: refundTickets]** (`:349-372`)
  - Burns up to 100 owned tickets, with `amount = Σ(last−first+1)·1e6` (`:362-367`).
  - The same `amount` is subtracted from the liability (`:368`) and transferred (`:369`).
- **[Model: _settleWinningTicket]** (`:533-558`)
  - Splits the whole pot once and zeroes `unsettledPot` (`:553`).
  - NftWon: sponsor gets pot − fee (`:544`).
  - CashWon: winner gets cash = ⌊0.8·pot⌋ and sponsor gets pot − fee − cash (`:546-548`).
  - Because pot = k·1e6, fee = k·50,000 and cash = k·800,000 exactly.
  - Checked for k ∈ [1, 200,000]: 0 violations of `cash + sponsor + fee == pot`.
- **[Model: claims]** (`:309-392`)
  - Each claim is zeroed before it is paid: `winnerProceeds` (`:341`), `sponsorProceeds` (`:378`), `protocolFees` (`:388`).
  - The set-once flags `settlementComplete` (`:551`), `winnerRedeemed` (`:324`) and `prizeClaimed` (`:331`, `:403`) are never reset.
- **[Model: RaffleFactory.createRaffle]** (F:97-148)
  - No USDC moves.
  - The clone is registered (F:123-125) before the prize is escrowed (F:128), and the escrow is verified (F:129-134).
- **[Model: requestDraw (ETH)]** (`:240-273`)
  - The VRF fee comes from `msg.value` and the excess is returned (`:262-270`).
  - No ETH is retained.

### Assumptions checked

- **[Why: Raffle.sol:257-258]** VRF fee.
  - Chainlink's `requestRandomnessPayInNative` recomputes `calculateRequestPriceNative(callbackGasLimit, 1)` in the same transaction and forwards exactly that amount.
  - So `paidPrice == quotedFee` (`:249-250`).
  - `:258` ensures pre-existing (forced) ETH is never spent.
- **[Why: Raffle.sol:579-585]** `_requireWinningTicket` has no existence check. This is safe:
  - Tickets are burned only in `Refunding` (`:350`, `:364`) or after settlement (`:325`).
  - `NftWon`/`CashWon` can never reach `Refunding` (`:292-293`).
  - Never-minted IDs return (0,0) and fail because `winningEntry ≥ 1` (`:518`).
- **[Why: Raffle.sol:368]** The checked `-=` cannot underflow.
  - When refunds open, the liability equals Σ of all ranges.
  - Each range can be burned once at most: OZ `_burn` reverts on a nonexistent ID, and `ownerOf` reverts for burned or duplicate IDs.
- **[Why: OZ ReentrancyGuard 5.6.1 on clones]** The guard works on clones.
  - It uses a namespaced storage slot, which starts at 0 on a clone (not the ENTERED value).
  - All ledger mutators are `nonReentrant`.
  - Every point where outside code gets control comes after all accounting writes: `_safeMint` `:235`, prize `transferFrom` `:334`/`:404`, ETH refund `:267`.
- **[Why: no live-balance accounting]** Donations cannot inflate a claim.
  - No `balanceOf(this)` or `address(this).balance` feeds any total.
  - `accountedQuoteBalance` (`:468-470`) only sums tracked totals.

### Guards tested

- **[Defeat: refundTickets]** Every attempt reverts; the guard holds:
  - a duplicate ID in one batch;
  - a nonexistent ID;
  - a ticket owned by someone else, or a call by an approved operator (`:360`);
  - a call outside `Refunding` (`:350`).
- **[Defeat: settle/redeem]** Every attempt reverts:
  - settling twice (`:534`);
  - ticket 0 or an ID above `ticketCount` (`:582`);
  - a non-winning ticket after settlement (`:316-317`);
  - redeeming twice (`:310`);
  - a caller who is not the owner (`:321`).

  A CashWon redemption with zero proceeds is unreachable (cash ≥ 800,000).
- **[Defeat: enableRefunds vs fulfillRandomWords]** The time windows are disjoint, and terminal results never re-enter `Refunding`.
  - The callback is accepted only while `now < drawRequestedAt+2d` and the status is `Drawing` (`:510-513`); refunds open only at or after that time (`:290-291`).
  - `requestDraw` is allowed only before `endTime+2d` (`:244-246`); refunds open only at or after it (`:286-287`).
- **[Defeat: _update / _transferQuote screens]** Ticket recipients are screened on every mint and transfer (`:497-502`), and USDC payees are re-screened at payout (`:565`). The only time-of-check/time-of-use gap is a code-less address that later becomes a clone, which is self-harm only (LEAD-2).
- **[Defeat: onERC721Received]** A second deposit and a spoofed caller both revert (`:421-426`). Only a malicious prize contract can trigger it itself, which is the same trust root as LEAD-1.
- **[Defeat: join before the distribution]** Sales close at `endTime` (`:216`), before any draw request (`:242`), so nobody can buy after randomness is requested. The only cross-time window is the secondary ticket market (LEAD-3).

### Closing tests (Last User Out)

- **[LastOut: L3 NftWon]**
  - N entries means USDC held = N·1e6.
  - Settlement allocates sponsor 0.95N + treasury 0.05N (×1e6), which equals the balance.
  - After both releases, claims and balance are both 0.
  - The NFT leaves once, to the winner.
  - USDC is conserved. The only gap is the dependency on NFT delivery (LEAD-1).
- **[LastOut: L3 CashWon]**
  - Winner 0.80N + sponsor 0.15N + treasury 0.05N = N (×1e6).
  - The NFT goes once to `sponsorRecipient`.
  - Every order of the redeem and release calls leaves zero residue.
- **[LastOut: L4/L5 Refunding]**
  - The liability equals the balance, N·1e6.
  - Example: tickets [1,3], [4,4] and [5,10] total 10e6. Refunding #3 leaves 4e6, then #1 leaves 1e6, then #2 leaves 0.
  - A 2,000-trial randomized worst-order model (largest-first and random orders, batches of 1-100) always ended with 0 liability and 0 balance.
  - The last refunder is always paid in full.
- **[LastOut: L6 Empty]** No USDC and zero liability; the NFT returns once to `sponsorRecipient`.
- **[LastOut: untracked inflows]** USDC sent directly, forced ETH and unsafe-sent NFTs sit outside every total and stay stuck (NatSpec `:410-411`). They do not affect any claim, and only the sender loses, so they are not reported.

### Saturation sweep

- **Missing decrement:** all 4 USDC exits debit their own total before transferring (`:341`, `:368`, `:378`, `:388`), and both NFT exits set `prizeClaimed` (`:331`, `:403`). No sibling is missing.
- **One-sided branch:**
  - Each settlement branch allocates the full pot (`:543-548`).
  - In redeem, the NftWon branch sets `prizeClaimed` and the CashWon branch zeroes `winnerProceeds`.
  - The `fulfillRandomWords` early return writes nothing, and the refund timeout covers it.
- **Cross-asset coupling:** the NFT legs in CashWon and Refunding affect only the sponsor. NftWon is the only case where one party's payout ignores another party's delivery (LEAD-1).
- **Payout screen:** the 4 USDC exits are screened. Of the 2 NFT exits, redeem pays `msg.sender`, the ticket owner, which can never be protocol plumbing. `releaseSponsorPrize` is unscreened (LEAD-2), the only instance.
- **Reinitialization:** each of these happens only once:
  - `initialize` (`:177-179`), and the implementation is locked (`:164-165`);
  - clone deployment, since each clone is a fresh CREATE address;
  - settle, `enableRefunds` and `requestDraw`, enforced by status and flags.

### Not reported (outside this lens, or by design)

- The last buyer or the sponsor can push `totalEntries` across `reserveEntries`. This is a design choice of outcome ("Reserve met awards NFT"); the expected-value question belongs to the economic lens.
- The VRF requester and the settler are unpaid. That is a liveness incentive with no ledger effect, and the fallback is full refunds.
