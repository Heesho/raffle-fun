> **Method variant disclosure (outside the native report body).** This report comes from the separately disclosed **CLAUDE-SIMAO-PUBLIC-EVIDENCE** method: `simao/0xsimao-ai` VERSION 1.0.0 with the public-evidence `shared-rules.md`, which replaces only the upstream private working-text request with concise, source-cited public evidence summaries. It is not an original, unmodified 0xSimao run. Turn 4 ran 12 independent foreground Opus 5.5 (max effort) lens agents in attempt-02, after the attempt-01 background children were system-killed at Turn 5. Raw lens outputs are in `evidence/raw-lens-outputs/`. The dedup and gate ledgers are in `evidence/turn6/`.

Completeness: 11 unique (Contract, function) in raw, 11 covered in final.

# Security Review — raffle.fun (Raffle clone + RaffleFactory)

**Scope:** 5 files, 2 contracts (`Raffle`, `RaffleFactory`; plus the `IRaffle`/`IRaffleFactory` interfaces, the `RaffleConstants` library, and `DESIGN.md` as the spec)
**Method:** accounting-first review across 12 attack lenses
**Findings:** 0 High · 5 Medium · 3 Low · 0 Info

Buyers pay 1 USDC (1,000,000 raw units) per entry and receive one transferable ERC-721 ticket per purchase, covering a contiguous range of entries. The sponsor escrows one ERC-721 prize when the raffle is created. After `endTime`, anyone can pay for one Chainlink VRF request. The callback picks a uniformly random winning entry and an outcome:

- `NftWon` when `totalEntries >= reserveEntries`: the NFT goes to the winning ticket, 95% of the pot to `sponsorRecipient` and 5% to the treasury.
- `CashWon` otherwise: 80% of the pot goes to the winning ticket, 15% plus the NFT back to `sponsorRecipient`, and 5% to the treasury.

If nobody requests the draw, or the callback does not arrive, within its 2-day window, the raffle moves to `Refunding`: every ticket is refunded 100% and the prize goes back to the sponsor. There is no yield. Because the pot is always a multiple of 1e6, every split is exact, and the Last-User-Out tests of all twelve lenses show the USDC ledger is conserved in every lifecycle. Losses therefore land on assets and groups of users, not on the ledger. In `NftWon`, the winner alone bears the risk that the prize cannot be delivered after the USDC has been paid out. Organic buyers bear the cost of sponsor-funded entries, which come back to the sponsor at 95%.

## Systemic observations

- **`NftWon` pays out USDC regardless of whether the prize is delivered.** This defect appears under three functions: M-1 (`releaseSponsorProceeds`, with the same gap in `releaseProtocolFees`), M-4 (`_settleWinningTicket`) and M-5 (`redeemWinningTicket`). All 12 lenses raised it. One change, M-1 Option A together with B or C, fixes all three.
- **The sponsor can trade against its own raffle using the 95% `NftWon` rebate.** This appears in M-2 (`buyEntries`, dilution), M-3 (`_settleWinningTicket`), L-2 (`fulfillRandomWords`, reserve flip) and L-3 (`buyEntries`, reserve flip). 9 lenses raised it.
- **Tickets can be traded while the VRF result is pending.** This appears in L-1 (`_update`) and the `fulfillRandomWords` lead. 8 lenses raised it.
- **Recipient checks happen only at configuration time, and recipients cannot be changed.** This covers the non-USDC payout in `releaseSponsorPrize` and the immutable `sponsorRecipient`/`protocolTreasury`. These remain leads because each case either harms only the party that chose the address or depends on a trusted dependency.

## M-1. `Raffle::releaseSponsorProceeds()` releases the `NftWon` 95% (and `releaseProtocolFees()` the 5%) without checking `prizeClaimed`, so a prize that stops transferring out of the clone leaves the winning-ticket holder with nothing after the whole pot is paid out [lenses: 9]

**Description:**

**Root cause.** In `NftWon`, `Raffle::_settleWinningTicket()` books `sponsorProceeds = grossPot - protocolFee` and `protocolFees` ([Raffle.sol:543-555](../packages/contracts/src/Raffle.sol#L543-L555)). `releaseSponsorProceeds()` and `releaseProtocolFees()` then pay these out with no check other than `amount == 0` ([Raffle.sol:375-392](../packages/contracts/src/Raffle.sol#L375-L392)).

**Why the winner cannot recover.** The prize has only one way out: `prizeToken.transferFrom(address(this), winner, prizeTokenId)` plus an `ownerOf` re-check in `redeemWinningTicket()` ([Raffle.sol:329-337](../packages/contracts/src/Raffle.sol#L329-L337)). `NftWon` is also terminal:
- `enableRefunds()` rejects it ([Raffle.sol:292-293](../packages/contracts/src/Raffle.sol#L292-L293)).
- `releaseSponsorPrize()` excludes it ([Raffle.sol:397-398](../packages/contracts/src/Raffle.sol#L397-L398)).

**How it is reached.** The factory accepts any ERC-165 ERC-721 ([RaffleFactory.sol:154-179](../packages/contracts/src/RaffleFactory.sol#L154-L179)), and `DESIGN.md` treats prize contracts as untrusted. A collection whose admin can block transfers can therefore make every redemption revert after settlement. Examples are OZ `ERC721Pausable`, a Manifold approve-transfer hook, an ERC721-C validator or freeze, or an upgradeable proxy.

**Example (lens 4).** 12,000 entries resolve to `NftWon`. Anyone then settles and releases 11,400 USDC to `sponsorRecipient` and 600 USDC to the treasury. After that, `redeemWinningTicket(57)` reverts forever.

**Sponsor-controlled variants (lenses 7 and 10).** `totalEntries >= reserveEntries` is fixed at `endTime`, so a sponsor that administers the collection knows the outcome before the draw. It can set up the block in advance, then settle and take 95%. If the prize is upgradeable or seizable, the sponsor can also pull the NFT back. The owner of the winning ticket bears the loss.

**Likelihood.** It depends on the prize contract. An honest ERC-721 without transfer restrictions cannot trigger this, and a transfer block is visible on-chain before anyone buys. `IRaffle.sol:14-15` assumes "honest, standards-compliant" prizes, but the code does not enforce this and `DESIGN.md` says the opposite.

**Chain: [L-2] + [M-1].** When organic demand is below the reserve, the sponsor can first force `NftWon` with its own entries (L-2/L-3).

**Recommended Mitigation (Option A — validate):**

In releaseSponsorProceeds(), and likewise in releaseProtocolFees(), add `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();` so the NftWon allocation is paid only against actual delivery.

```diff
 function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();
     amount = sponsorProceeds;
```

**Recommended Mitigation (Option B — add-missing-path):**

Optionally pair this with an NftWon delivery deadline that turns an undeliverable prize into refunds, so the gated pot cannot be stranded either.

**Recommended Mitigation (Option C — add-missing-path):**

“…plus a long winner-inactivity timeout so an absent winner cannot lock the sponsor forever.”

Option A narrows `DESIGN.md`'s "Sponsor and treasury can claim independently after settlement" for `NftWon`. Lenses 3, 6, 9 and 10 flag this trade-off: a winner who never redeems would hold back the sponsor's proceeds. B and C address that.

**Fix review:**

## M-2. `Raffle::buyEntries()` lets the sponsor buy entries that `NftWon` rebates at 95%, so a last-block sponsor purchase dilutes earlier buyers' odds on the NFT at 5% of the entry price [lenses: 1]

**Description:**

**Root cause.** In `NftWon`, `_settleWinningTicket()` pays `sponsorRecipient` `grossPot - protocolFee` ([Raffle.sol:544](../packages/contracts/src/Raffle.sol#L544), [:554](../packages/contracts/src/Raffle.sol#L554)). `grossPot` includes entries the sponsor bought from any address. `buyEntries()` ([Raffle.sol:215-221](../packages/contracts/src/Raffle.sol#L215-L221)) does not cap sales once `reserveEntries` is met, and it has no way to tell a sponsor-controlled buyer apart. Each sponsor entry therefore costs 0.05 USDC net but counts fully in the uniform draw ([Raffle.sol:518](../packages/contracts/src/Raffle.sol#L518)).

**Earlier buyers cannot exit.** Sales close at `endTime` ([:216](../packages/contracts/src/Raffle.sol#L216)) and the draw can be requested from the same second ([:242](../packages/contracts/src/Raffle.sol#L242)). Refunds only open at `endTime + 2 days` ([:286-287](../packages/contracts/src/Raffle.sol#L286-L287)).

**Example (lens 3).** The reserve is 5,000 entries and the NFT is worth 10,000 USDC.
- Alice buys 10,000 entries.
- At `endTime - 12s` the sponsor buys 90,000 entries from a fresh address.
- `NftWon` pays the sponsor 95,000 USDC, a net gain of +5,000. The sponsor's ticket wins with probability 0.9.
- Alice's expected value falls from 10,000 to 1,000 USDC. The sponsor gains 4,500 and the treasury gains 4,500.

The top-up that maximises the sponsor's expected value (about 34,721 entries) costs Alice about 7,764 USDC of expected value. Organic buyers bear the loss. The transfer is in expectation only, which is why this is Medium rather than High.

**Recommended Mitigation:**

Stop the sale at the reserve in buyEntries (`if (lastEntry > reserveEntries) revert ...`), so no sponsor-rebated entries can be minted after organic demand meets the reserve.

```diff
     uint128 lastEntry = totalEntries + entryCount;
+    if (lastEntry > reserveEntries) revert ...; // sale closes once the reserve is reached
```

This caps the pot at the reserve. A sponsor topping up to the reserve from below is still possible (L-3).

**Fix review:**

## M-3. `Raffle::_settleWinningTicket()` computes the `NftWon` sponsor share over the gross pot, including sponsor-funded entries, so the sponsor can buy odds on its own NFT at a 95% discount [lenses: 3]

**Description:**

`sponsorAmount = grossPot - protocolFee` ([Raffle.sol:544](../packages/contracts/src/Raffle.sol#L544)) counts every purchase, whoever made it. In `NftWon`, sponsor-funded entries therefore come back at 95% while counting fully in the draw. Lenses 2, 7 and 12 report two forms:

- **(A) Dilution after the reserve is met.** The reserve is 1,000 entries, buyers hold 1,000 entries, and the NFT is worth 1,000 USDC. The sponsor adds 1,000 entries at `endTime - 1`. Expected values change by: sponsor +450, buyers −500, treasury +50.
- **(B) Reserve flip from `CashWon` to `NftWon`.** See L-2 and L-3.

This is the same root cause as M-2. It is reported separately because the native dedup never merges across functions. Organic buyers bear the loss.

**Recommended Mitigation:**

Partial fix: cap sponsorProceeds at reserveEntries×ENTRY_PRICE×95% and send the surplus to the winner/cash pool. That removes variant A; variant B would still need disclosure.

Lens 7 proposes the same cap at `reserveEntries*ENTRY_PRICE`, with the excess paid to the winner.

**Fix review:**

## M-4. `Raffle::_settleWinningTicket()` books the `NftWon` 95%/5% split with no dependency on NFT delivery, so an undeliverable prize strands the winner once everyone else is paid [lenses: 2]

**Description:**

The `NftWon` branch ([Raffle.sol:543-555](../packages/contracts/src/Raffle.sol#L543-L555)) makes 95% payable to `sponsorRecipient` and 5% to the treasury right away. Neither settlement nor the release functions ([:375-392](../packages/contracts/src/Raffle.sol#L375-L392)) check `prizeClaimed`. No state turns an undeliverable `NftWon` prize into refunds ([:292-293](../packages/contracts/src/Raffle.sol#L292-L293), [:397](../packages/contracts/src/Raffle.sol#L397)).

**Example (lenses 1 and 12).** A sponsor that administers an upgradeable collection raffles token #1 with a reserve of 1,000 entries. Buyers pay 5,000 USDC, and settlement releases 4,750 USDC to the sponsor and 250 USDC to the treasury. The sponsor then upgrades the collection so that any transfer from the raffle reverts, and `redeemWinningTicket()` reverts forever.

This is the same family as M-1, kept separate by function isolation. The winning-ticket holder bears the loss.

**Recommended Mitigation:**

Minimal mitigation if in scope: in releaseSponsorProceeds, require prizeClaimed when status == NftWon.

Lens 1 notes the trade-off: "a winner who never redeems then also defers the sponsor's proceeds".

**Fix review:**

## M-5. `Raffle::redeemWinningTicket()` is the only exit from the terminal `NftWon` state and has no fallback when prize delivery fails, permanently stranding the winning ticket [lenses: 1]

**Description:**

**Root cause.** In `NftWon`, the NFT can only leave through `prizeToken.transferFrom(address(this), winner, prizeTokenId)` and the `ownerOf` re-check ([Raffle.sol:334-337](../packages/contracts/src/Raffle.sol#L334-L337)). Any revert also undoes the burn ([:325](../packages/contracts/src/Raffle.sol#L325)). There is no deadline, no conversion to refunds ([:292-293](../packages/contracts/src/Raffle.sol#L292-L293)) and no return to the sponsor ([:397-399](../packages/contracts/src/Raffle.sol#L397-L399)).

**Example (lens 8).** The reserve is 1,000 entries, buyers pay 1,000 USDC, and the outcome is `NftWon`. 950 USDC is released to the sponsor and 50 USDC to the treasury. The prize contract then permanently blocks transfers out of the clone, for example through:
- an admin pause;
- a per-address blocklist;
- a transfer-validator policy;
- a sponsor-controlled contract.

From then on every redemption reverts.

**Likelihood.** A temporary pause only delays the winner, because there is no redemption deadline. A permanent loss needs a permanent block. This is the same family as M-1.

**Recommended Mitigation (Option A — validate):**

“…make releaseSponsorProceeds (Raffle.sol:375-382) require prizeClaimed when status == NftWon…”

**Recommended Mitigation (Option B — add-missing-path):**

“…or to add a fallback for failed delivery.”

**Fix review:**

## L-1. `Raffle::_update()` keeps tickets transferable while the VRF result is pending, so anyone reading the fulfillment can snipe stale listings of the winning ticket or dump losing tickets into standing bids [lenses: 7]

**Description:**

**Root cause.** `_update()` only screens destinations ([Raffle.sol:497-502](../packages/contracts/src/Raffle.sol#L497-L502)), and by design tickets stay tradeable through `Drawing` and the resolution block ([:491](../packages/contracts/src/Raffle.sol#L491)).

**Attack.** `winningEntry = randomWords[0] % totalEntries + 1` ([:518](../packages/contracts/src/Raffle.sol#L518)) is fixed by the fulfillment's proof. A watcher can map the result to a ticket via `ticketRange()` ([:451-455](../packages/contracts/src/Raffle.sol#L451-L455)) before `fulfillRandomWords` executes, and then either:
- fill a stale listing of the winning ticket. In lens 7's example, with 10,000 entries and an NFT worth 20,000 USDC, ticket #57 is listed at 3,500, so the seller is underpaid by 16,500;
- sell losing tickets into standing bids.

Tickets have no `tokenURI`, and every clone reports the same `name()`/`symbol()` ([:479-487](../packages/contracts/src/Raffle.sol#L479-L487)), so listings cannot show what they are selling.

**Likelihood.** This needs a stale open order and a fulfillment that is visible before inclusion, which could not be verified offline. The protocol's accounting is unaffected, and the victims are secondary-market counterparties.

**Recommended Mitigation (Option A — restrict):**

Possible mitigation: block ticket transfers while status == Drawing.

**Recommended Mitigation (Option B — restrict):**

“…block transfers other than mint and burn from requestDraw until block.timestamp > resolvedAt, and document that holders must cancel orders before the draw.”

**Recommended Mitigation (Option C — restrict):**

The only robust fix, blocking operator-initiated transfers from requestDraw onward, conflicts with the documented bearer-claim design.

Lens 9 adds a caution: "Blocking transfers only during Drawing would also not protect listings left open after resolution."

**Fix review:**

## L-2. `Raffle::fulfillRandomWords()` counts sponsor-funded entries toward `reserveEntries`, so the sponsor can flip a `CashWon` raffle to `NftWon` for about 5% of the shortfall [lenses: 4]

**Description:**

**Root cause.** The outcome check `totalEntries >= reserveEntries` ([Raffle.sol:521](../packages/contracts/src/Raffle.sol#L521)) includes entries the sponsor bought itself, and `NftWon` rebates those at 95% ([:544](../packages/contracts/src/Raffle.sol#L544)). When organic demand N is below the reserve R, the sponsor can buy the missing R−N entries at `endTime - 1`. This replaces the buyers' 80% cash outcome with a chance at an NFT worth less.

**Example (lens 3).** R = 1,000, N = 900, and the NFT is worth 500 USDC. Buyers' expected value falls from 720 to 450 (−270). The sponsor gains 265 and the treasury gains 5.

**Why Low.** The flip only pays when the NFT is worth less than about 0.8× the pot. Buyers were also never guaranteed `CashWon`, since any third party that pushes entries past the reserve has the same effect.

**Chain: [L-2] + [M-1].** After forcing `NftWon`, a sponsor that administers the prize can also block delivery and keep 95% of the buyers' pot.

**Recommended Mitigation:**

None on-chain. Lens 3: "There is no sybil-proof code fix: the sale cap proposed for the dilution FINDING does not close this gap." Disclose in `DESIGN.md` and the frontend that sponsor-funded entries count toward the reserve and are rebated at 95% under `NftWon`.

**Fix review:**

## L-3. `Raffle::buyEntries()` lets the sponsor fill the reserve shortfall at about 5% net cost after seeing demand, cancelling buyers' 80% cash outcome [lenses: 2]

**Description:**

`buyEntries()` ([Raffle.sol:209-237](../packages/contracts/src/Raffle.sol#L209-L237)) places no restriction on sponsor-controlled buyers, and the reserve test ([:521](../packages/contracts/src/Raffle.sol#L521)) counts their entries.

**Example (lens 9).** The reserve is 1,000 entries, buyers hold 900, and the NFT is worth 300 USDC. Under the honest `CashWon` outcome, the winning buyer gets 720 USDC. Instead, the sponsor buys 100 entries just before `endTime`, so the raffle resolves `NftWon`. The sponsor receives 950 USDC (+850 net), and buyers' expected value falls from 720 to 270 (−450).

This is the same root cause as L-2, seen at the entry point, and it is Low for the same reasons.

**Recommended Mitigation:**

None on-chain. Lens 9: "Sybil addresses make a msg.sender != sponsor check useless, so there is no minimal on-chain fix." Disclose this behaviour as described in L-2.

**Fix review:**

## Unverified leads

- `RaffleFactory::createRaffle` — The escrow check relies entirely on the prize contract's own `onERC721Received` call and `ownerOf` answer ([RaffleFactory.sol:128-134](../packages/contracts/src/RaffleFactory.sol#L128-L134), [Raffle.sol:421-428](../packages/contracts/src/Raffle.sol#L421-L428)), so a hostile prize can fake the escrow. — No loss beyond the risk of a worthless prize, which buyers can see, was established. [lenses: 1]
- `Raffle::requestDraw` — The Chainlink wrapper is immutable and has no migration path, so if it is deprecated every raffle is forced into refunds, and a draw requester can lose their fee. — The trigger is a trusted dependency, and the refund deadlines ([Raffle.sol:286-291](../packages/contracts/src/Raffle.sol#L286-L291)) prevent any loss of principal. Demoted from [lenses: 2].
- `Raffle::enableRefunds` — A 1-entry front-run removes the sponsor's option to cancel an empty raffle ([Raffle.sol:280-287](../packages/contracts/src/Raffle.sol#L280-L287)). — No value is lost beyond the sale window the sponsor chose. Demoted from [lenses: 3].
- `Raffle::releaseSponsorProceeds` — `sponsorRecipient` is immutable and cannot be redirected if USDC blacklists it ([Raffle.sol:564-567](../packages/contracts/src/Raffle.sol#L564-L567)). — No attacker path; only the chosen recipient loses. [lenses: 1]
- `Raffle::releaseProtocolFees` — `protocolTreasury` is immutable and shared by the whole factory, so a USDC blacklist would freeze every raffle's fee ([Raffle.sol:385-390](../packages/contracts/src/Raffle.sol#L385-L390)). — No attacker path; only the treasury loses. [lenses: 1]
- `Raffle::releaseSponsorPrize` — The NFT return is not re-checked at payout ([Raffle.sol:402-405](../packages/contracts/src/Raffle.sol#L402-L405)), and the init-time check skips addresses with no code ([:602](../packages/contracts/src/Raffle.sol#L602)). A `sponsorRecipient` set to a future clone address therefore moves the prize into another clone, against `DESIGN.md` "Never move assets between raffle clones". — Only the sponsor who chose that address loses. Demoted from [lenses: 5].
- `Raffle::fulfillRandomWords` — The outcome can be derived from the pending fulfillment while tickets are still tradeable ([Raffle.sol:518-521](../packages/contracts/src/Raffle.sol#L518-L521)). — Mempool visibility and coordinator semantics were not verified. Same mechanism as L-1. [lenses: 1]
