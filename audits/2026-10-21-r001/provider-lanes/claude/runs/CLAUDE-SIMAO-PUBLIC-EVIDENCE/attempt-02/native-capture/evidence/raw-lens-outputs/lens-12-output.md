# Lens 12: Flow Completeness & Symmetry (0xSimao), raffle.fun

**Scope:** `packages/contracts/src/{Raffle.sol, RaffleFactory.sol, interfaces/IRaffle.sol, interfaces/IRaffleFactory.sol, libraries/RaffleConstants.sol}` and `DESIGN.md`.

**Dependencies checked for cross-file lookups:**
- `@openzeppelin/contracts` 5.6.1: ERC721, ERC721Utils, ReentrancyGuard (5.5.0 header), Clones.
- `@chainlink/contracts` 1.5.0: VRFV2PlusWrapperConsumerBase, IVRFV2PlusWrapper, VRFV2PlusClient.

**Line numbers:** bare `:N` means `Raffle.sol`. `F:N` means `RaffleFactory.sol`.

## Result

- **FINDING blocks: 0.** Every pair in the money map closes: forward/inverse, sibling, branch and precondition. There is no missing decrement, no write in only one branch, and no stale read that leaves a third party with a loss.
- **LEAD blocks: 3.**
  - A trust-model gap in the NftWon flow.
  - One economic issue.
  - One low-impact missing re-route path.

## FINDING blocks

None.

## LEAD blocks

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: missing-fallback-undeliverable-prize | group_key: Raffle | _settleWinningTicket | missing-fallback-undeliverable-prize
smell: In the NftWon branch, Raffle.sol:544 (`sponsorAmount = grossPot - protocolFee`) and :554-555 make 95% of the pot payable to sponsorRecipient and 5% to the treasury. Neither depends on the NFT being delivered. `releaseSponsorProceeds` (:375-382) has no `prizeClaimed`/delivery gate. The only way the NFT leaves is `redeemWinningTicket` (:334-337). It reverts entirely if the prize contract refuses `transferFrom(raffle, ...)` or misreports `ownerOf`. No state converts an undeliverable NftWon prize into cash or refunds: NftWon can never reach Refunding, and `releaseSponsorPrize` is barred in NftWon (:397). The escrow proof at creation also comes from the same untrusted contract: the prize contract can call `onERC721Received` (:421-428) directly, and the factory trusts its `ownerOf` (F:128-132). Trail: (1) a sponsor that administers an upgradeable ERC-721 collection raffles token #1 with reserve 1,000; (2) buyers purchase 5,000 entries (5,000 USDC); (3) VRF resolves NftWon and anyone settles, giving sponsorProceeds = 4,750 USDC (4,750,000,000 raw) and protocolFees = 250 USDC; (4) the sponsor calls releaseSponsorProceeds and receives 4,750 USDC; (5) the sponsor upgrades the collection so any transfer whose `from` is the raffle reverts; (6) every `redeemWinningTicket` by the winning-ticket owner now reverts forever.
unverified: Whether sponsor-controlled or admin-mutable prize contracts are in the threat model. DESIGN.md says "arbitrary prize contracts ... are untrusted", but IRaffle.sol:14-15 says "Supported prizes are honest, standards-compliant ERC-721s". DESIGN.md also says "Sponsor and treasury can claim independently after settlement", so the independence is deliberate. Any delivery gate must still handle a winner who never redeems, because there is no redemption deadline. A fully malicious prize can fake both escrow and delivery, so no on-chain change protects against it. The gap is concrete only for admin-mutable collections (upgradeable, pausable or blocklisting).
description: The NftWon branch pays the sponsor and treasury for a prize whose delivery depends only on the untrusted prize contract, so a prize that becomes non-transferable after settlement leaves the winning-ticket owner, and the buyers who funded the pot, holding the entire loss.
```

```
LEAD | contract: Raffle | function: _settleWinningTicket | bug_class: sponsor-self-entry-rebate | group_key: Raffle | _settleWinningTicket | sponsor-self-entry-rebate
smell: In NftWon, `sponsorAmount = grossPot - protocolFee` (Raffle.sol:544) is computed on the gross pot. That pot includes entries the sponsor bought itself, from any address. So each sponsor-funded entry costs the sponsor 5% net, while every other entrant pays 100%. Because buyEntries (:209-237) stays open until endTime, the sponsor can watch demand and shill-enter in the last block, diluting buyers' odds and keeping its NFT. Numbers: the NFT is worth 10,000 USDC and the reserve is 2,000. Buyers purchase 2,000 entries (2,000 USDC). Just before endTime the sponsor buys 18,000 entries from a fresh address. NftWon with a pot of 20,000 gives sponsorProceeds 19,000 and fee 1,000. The sponsor ends +1,000 USDC net and keeps the NFT with probability 0.9. Buyers' expected value drops from 10,000 to 1,000 USDC (-9,000). The sponsor gains +8,100 and the treasury +900 (checked arithmetically). This is profitable whenever the NFT is worth more than 5% of the final pot. In CashWon a self-entry nets -5% (0.80 winner share + 0.15 sponsor share), so only NftWon is exposed.
unverified: Whether sponsor participation is an accepted design risk. The money map says the sponsor "may also buy entries" and DESIGN.md is silent. Excluding addresses is defeated by Sybil addresses, so there is no one-line mitigation. This is an economic/game-theory issue at the edge of the flow-symmetry lens.
description: The 95% sponsor share refunds the sponsor's own entries, so a sponsor can shill-enter at a 5% cost to win back its prize with high probability, and honest entrants hold the loss.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: immutable-recipient-no-reroute | group_key: Raffle | releaseSponsorProceeds | immutable-recipient-no-reroute
smell: `releaseSponsorProceeds` (Raffle.sol:375-382), `releaseProtocolFees` (:385-392) and `releaseSponsorPrize` (:402-405) can only pay the recipients fixed at initialize (:198-199); the treasury is also a factory immutable. Ticket-backed claims (`refundTickets`, `redeemWinningTicket`) have an escape: the holder can transfer the bearer ticket to a clean address. The sponsor and treasury claims have no such path. If USDC blacklists `sponsorRecipient` after settlement, or blacklists the factory-wide `protocolTreasury` at any time, `_transferQuote` -> `safeTransfer` (:564-567) reverts permanently. The allocated USDC is then locked in the clone forever, and for the treasury this hits every raffle from the factory.
unverified: Whether recipient-level USDC blacklisting is in scope for a "trusted canonical dependency". The loss falls only on the sponsor or the protocol, never on buyers, so this is likely Low/Info.
description: Sibling asymmetry: ticket claims can be re-routed by transferring the bearer ticket, but sponsor and treasury claims are pinned to immutable recipients with no fallback, so a USDC freeze on a recipient strands those funds permanently.
```

## Public audit-evidence summaries

### Lens tables

**Forward / inverse**

| Forward (state written) | Inverse (state unwritten) | Unmatched | Verdict |
|---|---|---|---|
| `buyEntries` :209-237: USDC in (:224), `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot +=` (:233), mint | `refundTickets` :349-372: burn (:364), `remainingRefundLiability -=` (:368), USDC out (:369). The pot becomes the refund liability once, in `enableRefunds` :296-299 | `totalEntries`, `ticketCount`, `_ticketRanges` are never unwritten | Intended lifetime/historical counters. Nothing reads them after a terminal state |
| Prize in: `onERC721Received` :416-431 (AwaitingPrize -> Active) | Prize out: `redeemWinningTicket` NftWon branch :329-337, or `releaseSponsorPrize` :395-407 (`prizeClaimed`) | none | Closes. Each terminal status has exactly one exit |
| `requestDraw` :240-273: Drawing, `drawRequestedAt`, `_requestInFlight` set/cleared, `vrfRequestId`, ETH out | `fulfillRandomWords` :509-524, or the Drawing branch of `enableRefunds` :289-291 | VRF fee not reimbursed. `vrfRequestId`/`drawRequestedAt` not reset | By design. Terminal statuses make stale IDs inert (:511) |
| `_settleWinningTicket` :533-558: pot -> `protocolFees` + `sponsorProceeds` + `winnerProceeds` | `redeemWinningTicket` cash branch :338-342, `releaseSponsorProceeds` :375-382, `releaseProtocolFees` :385-392 | none | Closes |
| F:`createRaffle`: registry writes F:123-125 | none (no deregistration) | `isRaffle` only ever grows | Intended |

**Sibling (payout family)**

| Function | Status gate | Caller gate | One-shot guard | Recipient screened at payout time |
|---|---|---|---|---|
| `refundTickets` | Refunding | `ownerOf == msg.sender` | burn | `_transferQuote` :565 |
| `redeemWinningTicket` (cash) | NftWon/CashWon | `ownerOf == msg.sender` | `winnerRedeemed` + burn | `_transferQuote` |
| `redeemWinningTicket` (NFT) | NftWon | `ownerOf == msg.sender` | `winnerRedeemed` + `prizeClaimed` + burn | none (`_update` :497-502 screened the owner at mint/transfer) |
| `releaseSponsorPrize` | CashWon/Refunding | anyone | `prizeClaimed` | none (recipient screened at init :193 and F:163-169) |
| `releaseSponsorProceeds` / `releaseProtocolFees` | none (amount > 0) | anyone | balance zeroed before paying | `_transferQuote` |

The only asymmetry is that the NFT legs are not re-screened at payout time. That is reachable only through the gap for addresses with no code yet, and it only harms the person who chose the address (see "Assessed and excluded").

**Branch**
- `enableRefunds` (:276-301): all three branches write the same set: `unsettledPot = 0`, `remainingRefundLiability`, `status`.
- `fulfillRandomWords`: the ignore branch writes nothing. The resolve branch writes `winningEntry`, `resolvedAt`, `status`.
- `_settleWinningTicket`: the NftWon branch leaves `winnerProceeds = 0`, as intended. Both branches write the shared settlement set (:551-555).
- `redeemWinningTicket` (:314-318): the settle branch and the match branch both end with a validated `winningTicketId`.
- `requestDraw`: when `excess == 0`, the only thing skipped is the refund call.

**Precondition**
- There is no index or accrual state.
- The time-based terminal transitions need an explicit `enableRefunds` before `refundTickets` or `releaseSponsorPrize` will work. This covers Active past `endTime + 2d` and Drawing past `drawRequestedAt + 2d`. `enableRefunds` is permissionless and cannot be blocked, so no flow is stranded.
- `redeemWinningTicket` settles the raffle itself if needed (:314-315).
- `releaseSponsorProceeds` and `releaseProtocolFees` revert while their balance is zero, before settlement. They become payable as soon as anyone settles.

### [Model]

- **[Model: buyEntries]** The buyer pays `entryCount x 1e6` USDC (:224) and gets one ticket covering `[totalEntries+1, totalEntries+entryCount]`. `unsettledPot` grows by the same amount (:233). Ranges are sequential, disjoint and contiguous.
- **[Model: enableRefunds]** Moves the whole `unsettledPot` into `remainingRefundLiability` (:296-299). Three branches lead here: empty raffle cancelled by the sponsor, sold raffle with no draw, and draw timeout.
- **[Model: _settleWinningTicket]** Splits `unsettledPot` into:
  - `protocolFees` (5%);
  - `sponsorProceeds` (95% NftWon, 15% CashWon);
  - `winnerProceeds` (0 NftWon, 80% CashWon).

  It runs once (`settlementComplete`) and only writes storage (:539-555).
- **[Model: refundTickets]** Burns up to 100 tickets owned by the caller and pays Σ(last-first+1) x 1e6. It reduces the liability by exactly that amount (:356-369).
- **[Model: redeemWinningTicket]** Settles if needed and requires the current owner. It then burns the ticket and either delivers the NFT (with an `ownerOf` check afterwards) or pays `winnerProceeds` (:309-346).
- **[Model: release*]** Each zeroes its balance and then pays the full amount to its immutable recipient. `releaseSponsorPrize` returns the NFT in CashWon/Refunding.
- **[Model: createRaffle]** Deploys a clone with CREATE, initializes it and registers it (F:123-125). It escrows the prize with `safeTransferFrom(msg.sender, ...)` (F:128), then checks `ownerOf` and `status` (F:129-132).

### [Why]

- **[Why: Raffle.sol:540-547]** The split is exact. The pot is always n x 1e6, so fee = n x 5e4, cash = n x 8e5, and the remainder is n x 1.5e5 (CashWon) or n x 9.5e5 (NftWon). There is no dust. Checked numerically for n <= 200,000 with 0 violations.
- **[Why: Raffle.sol:359-364]** A duplicate or already-burned ID reverts the whole batch, because OZ 5.6.1 `ownerOf` calls `_requireOwned`, which reverts for burned tokens.
- **[Why: Raffle.sol:216/242/245/287/291/512]** All windows are disjoint, even at the boundary second:
  - buying needs `< endTime`; the draw needs `>= endTime`;
  - the draw needs `< endTime + 2d`; refunds open at `>= endTime + 2d`;
  - the callback needs `< drawRequestedAt + 2d`; refunds open at `>=` that same deadline.
- **[Why: OZ ReentrancyGuard 5.5.0]** The guard lives in an ERC-7201 storage slot. In a clone that slot starts at 0, which is not ENTERED, so `nonReentrant` works even though the implementation's constructor only wrote its own storage.
- **[Why: OZ Clones.sol:57]** Clones are deployed with CREATE, so future clone addresses are predictable. That is why skipping the registry check for addresses with no code (:602, documented at :589) is a time-of-check gap, but only for addresses a user picks themselves.
- **[Why: VRFV2PlusWrapperConsumerBase]** `rawFulfillRandomWords` requires `msg.sender == wrapper`. `requestRandomnessPayInNative` pays `calculateRequestPriceNative` from the raffle's balance in the same transaction. So `paidPrice == quotedFee` (same `tx.gasprice`) and the excess refund cannot underflow.

### [Defeat]

- **[Defeat: refundTickets]** Can `remainingRefundLiability -= amount` (:368) underflow? I tried four ways; all failed:
  - (a) Refund the same ticket twice: the burn plus the `ownerOf` revert stop it.
  - (b) Mint a ticket after refunds open: `buyEntries` requires Active.
  - (c) Burn a ticket through another path first: only redeem burns, and it needs NftWon/CashWon, which can never reach Refunding.
  - (d) Snapshot the liability below the sum of ranges: the snapshot is `unsettledPot`, which equals the sum of all purchases.

  The last refunder is always paid in full.
- **[Defeat: redeemWinningTicket / settleWinningTicket]**
  - Double payout is blocked by `settlementComplete` (:534), `winnerRedeemed` (:310) and the burn.
  - A second ticket containing `winningEntry` cannot exist because ranges are disjoint.
  - Unminted or zero IDs return a (0,0) range and revert (:582).
  - In NftWon the sponsor cannot take the NFT (:397).
  - Refund plus win is impossible because the terminal statuses are exclusive.
- **[Defeat: enableRefunds]** The sponsor cannot cancel once any entry exists (:281-287). A buy and a cancel in the same block resolve consistently in either order. NftWon/CashWon have no route to Refunding (:292-293).
- **[Defeat: fulfillRandomWords]** Callers other than the wrapper revert in the base contract. Callbacks are ignored if they have the wrong ID, are late or duplicated, arrive after Refunding, or arrive during the request (:510-516). There is no re-request path, so no re-roll.
- **[Defeat: onERC721Received]** It requires `msg.sender == prizeToken`, the exact token ID, `from == sponsor`, `operator == factory` and AwaitingPrize (:421-425). Only the prize contract itself can trigger it outside the factory flow, which feeds LEAD 1.
- **[Defeat: _isProtocolDestination / _update / _transferQuote]** The fixed sinks are always blocked: this contract, the factory, USDC, the wrapper, the prize and the implementation. Registered clones are blocked once they have code. A third party cannot later make a victim's fixed address match the screen, because only `create(factory, nonce)` addresses ever join `isRaffle`.
- **[Defeat: requestDraw]**
  - A second request is blocked by status.
  - Underpayment is checked twice (:250, :258).
  - The excess refund is sent only after all state is final. While the guard is held, the recipient can only reach unguarded ticket transfers, which does no harm.
- **[Defeat: createRaffle]**
  - The escrow always pulls from `msg.sender` (F:128), so approvals other users gave the factory cannot be abused.
  - Raffles and the implementation are rejected as prizes (F:157-162).
  - `reserveEntries == 0`, a past end time and a sale longer than 30 days are all rejected (F:100-104, F:178).

### [LastOut]

- **[LastOut: L4/L5 Refunding]** The liability equals the sum of all unburned ranges x 1e6. Settlement never ran, so no other USDC claim is non-zero. Refunds in any order end at exactly 0, and the last refunder is paid in full.
- **[LastOut: L3 NftWon]** Fee + sponsor share = pot exactly, and both can be released independently. The NFT can only go to the winning-ticket owner. This holds as long as the prize contract still allows the transfer (LEAD 1).
- **[LastOut: L3 CashWon]** Fee + cash + sponsor share = pot exactly. The NFT can only go back to `sponsorRecipient`. All three USDC claims can be paid independently.
- **[LastOut: L6 Empty]** The liability is 0 and the prize is returned. No USDC is owed.
- **Solvency:** `balanceOf(raffle) >= accountedQuoteBalance()` holds at every step. Donated USDC and forced ETH are untracked surplus, by design.

### Saturation sweep

- **"A claim is paid out regardless of the leg it pays for":** the only pair that crosses both parties and assets is NftWon {`sponsorProceeds`, `protocolFees`} vs NFT -> winner (LEAD 1). In CashWon the cash is fully backed by USDC, and the NFT goes back to the party it came from. In Refunding the refunds are backed by USDC and the NFT return is independent.
- **"A payout refunds the payer's own contribution":** only the NftWon sponsor share makes this profitable (LEAD 2). A CashWon self-entry nets -5%, and the treasury does not take part.
- **"Immutable recipient with no re-route":** `sponsorRecipient` (USDC and NFT) and `protocolTreasury` (USDC), covered in LEAD 3. Ticket claims can be re-routed by transferring the ticket.
- **"No recipient screen at payout time":** the NFT legs at :334 and :404 skip `_isProtocolDestination`, while every USDC leg runs it (:565). See "Assessed and excluded".
- **"Proof that comes from an untrusted contract":** the factory's `ownerOf` check (F:129), `onERC721Received` (:421-428), and the delivery `ownerOf` checks (:335, :405). All are folded into LEAD 1.

### Assessed and excluded

These have no third-party victim or are by design.

- **Addresses with no code skip the registry check (:602), and clone addresses are predictable.** A user can mint or transfer a ticket to a clone address that is not yet deployed, or set `sponsorRecipient` to one. Screening passes at that time. Once the clone exists, USDC payouts to that address revert (:565). The NFT legs (:334, :404) are not re-screened, so they would move the NFT into another raffle clone. This is documented at :589, and every route requires the claimant to pick that address themselves, so only they are harmed.
- **The winner never redeems.** The NFT or the 80% cash stays locked forever, with no deadline or fallback. This follows from the bearer-claim design, and only the winner loses.
- **The VRF request is one-shot.** If the callback fails or is ignored, the raffle moves to full refunds and buyers are made whole. The requester's native fee is their own risk, under the trusted wrapper.
- **A sponsor's cancellation of an empty raffle can be front-run by a 1-entry buy.** That is a legitimate purchase during the sale window and it can be refunded, so the only effect is delay.
- **`totalEntries` and `_ticketRanges` are never decremented on refund or burn.** These are intended lifetime counters, and nothing reads them after a terminal state.
