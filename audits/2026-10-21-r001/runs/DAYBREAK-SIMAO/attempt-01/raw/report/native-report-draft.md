Completeness: 8 unique (Contract, function) in raw, 8 covered in final.

# Security Review — raffle.fun

**Scope:** 6 files, 2 contracts
**Method:** accounting-first review across 12 attack lenses
**Findings:** 4 High · 2 Medium · 0 Low · 0 Info
**Local runtime selection:** `gpt-daybreak-blue-latest`; reasoning effort `ultra`; access program `daybreak_blue`; no fallback
**Provider-returned model:** unknown
**Provider-returned access program:** unknown

A sponsor escrows one ERC-721 prize, entrants pay fixed-price canonical USDC for transferable range tickets, and a Chainlink VRF result selects one paid entry after sales close. Refund and cash-result accounting conserves the complete quote pot: each ticket refund consumes its represented value, while cash settlement fixes disjoint winner, sponsor, and treasury buckets. In the NFT-result branch, however, an arbitrary sponsor-selected prize contract is treated as trustworthy and the buyer-funded pot becomes releasable before the prize reaches the winner. The winning-ticket owner absorbs that cross-asset shortfall; separately, canonical USDC's deny-list behavior can make otherwise fully backed claims unreachable under issuer-controlled conditions.

## Systemic observations

The same untrusted-prize failure spans four function-isolated sites: admission at `RaffleFactory::createRaffle()`, storage-only execution at `Raffle::settleWinningTicket()`, premature allocation at `Raffle::_settleWinningTicket()`, and value exit at `Raffle::releaseSponsorProceeds()` with the sibling treasury release. These are distinct mechanisms and fixes even though a single exploit exercises them in sequence. `Chain: H-1 + H-2 + H-3 + H-4`.

## H-1. `RaffleFactory::createRaffle()` trusts prize self-attestation, allowing a sponsor to sell an unbacked raffle and take buyer funds

**Description:**

`RaffleFactory::createRaffle()` accepts an arbitrary token after validation beginning at [RaffleFactory.sol:154](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/RaffleFactory.sol:154), then relies on that same token's transfer behavior and `ownerOf` response at [RaffleFactory.sol:128](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/RaffleFactory.sol:128). The token can report ERC-721 support, fabricate the expected callback, and report the raffle as owner without independent backing; alternatively, it can accept genuine escrow and later pause, upgrade, blacklist, burn, or selectively reject outbound transfers. With a reserve of one, an honest purchase can therefore fund an `NftWon` result in which the sponsor receives 95% of gross while the winning-ticket owner receives neither the advertised NFT nor a refund.

**Recommended Mitigation (Option A — validate):**

Add an immutable factory-level allowlist check in `_validateCreateParams` and accept only vetted, behaviorally trusted, non-upgradeable ERC-721 prize implementations; arbitrary adversarial token contracts cannot be made safe by asking the same contract to attest interface support, custody, or delivery.

**Recommended Mitigation (Option B — gate/fallback):**

In an NFT result, keep sponsor and protocol quote proceeds locked until the NFT is successfully delivered; add a fixed delivery deadline after which an undelivered result atomically recombines those untouched proceeds into `remainingRefundLiability` and enters `Refunding`.

**Fix review:**

## H-2. `Raffle::settleWinningTicket()` persists settlement without prize delivery, letting a hostile sponsor bypass redemption rollback

**Description:**

The public `Raffle::settleWinningTicket()` path persists the allocation performed at [Raffle.sol:543](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:543) without attempting prize delivery. If the winner instead calls `redeemWinningTicket()` first, a hostile NFT transfer failure rolls its inline settlement back; the sponsor can call the separate settlement entry point, preserve the sponsor and treasury buckets, withdraw them, and leave the winner's later redemption permanently reverting. The range and one-shot checks validate the ticket but do not interrupt this cross-transaction path.

**Recommended Mitigation (Option A — reorder):**

Make NFT-result settlement atomic with successful prize delivery: do not create or release sponsor/treasury proceeds until the NFT transfer and ownership verification succeed, and if delivery has not succeeded by a fixed deadline, move the still-unallocated pot to `Refunding` so every ticket can recover its purchase price.

**Recommended Mitigation (Option B — gate/fallback):**

In `NftWon`, gate both sponsor and treasury quote releases on successful `winnerRedeemed`/prize ownership verification; if permanently failed prize delivery must be tolerated, transition the still-held sale pot to ticket refunds instead of ever releasing it.

**Fix review:**

## H-3. `Raffle::_settleWinningTicket()` allocates all buyer funds before NFT delivery, leaving the winner without a backed fallback

**Description:**

In the `NftWon` branch at [Raffle.sol:543](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:543), `Raffle::_settleWinningTicket()` clears `unsettledPot` and creates immediately releasable 95% sponsor and 5% treasury liabilities before the only NFT-delivery attempt at [Raffle.sol:334](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:334). A sponsor-controlled prize can accept escrow and later refuse the outbound transfer; after the quote buckets leave, the winning ticket remains unredeemable and `NftWon` exposes no refund transition.

**Recommended Mitigation (Option A — reorder/fallback):**

Do not make the `NftWon` sponsor and treasury balances releasable until successful prize delivery; keep that pot uncommitted and route it to ticket refunds after a bounded delivery failure instead.

**Recommended Mitigation (Option B — validate):**

Enforce an immutable factory allowlist (or immutable code-hash allowlist) of audited, non-upgradeable, non-pausable prize-token implementations; an arbitrary ERC-721 cannot be made economically trustworthy by querying its own interface and ownership methods.

**Fix review:**

## H-4. `Raffle::releaseSponsorProceeds()` omits the NFT-delivery gate, allowing consideration to leave before the winner receives the prize

**Description:**

`Raffle::releaseSponsorProceeds()` at [Raffle.sol:375](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:375) pays a nonzero sponsor bucket without requiring `winnerRedeemed` or `prizeClaimed` in `NftWon`; `releaseProtocolFees()` repeats the mechanism at [Raffle.sol:385](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:385). A malicious sponsor can withdraw 95% of buyer-funded USDC before its controlled prize rejects winner delivery, and the treasury release can remove the remaining 5%, leaving the winner without either asset or refund backing.

**Recommended Mitigation:**

In both sponsor and protocol quote-release paths, reject release while `status == NftWon && !winnerRedeemed`; keep the sale pot unavailable to those recipients until successful prize delivery (and, if undeliverable prizes are to remain supported, add a bounded transition that converts the retained pot to ticket refunds).

**Fix review:**

## M-1. `Raffle::_transferQuote()` cannot route around a USDC sender deny-list, locking every quote claim in the clone

**Description:**

Every cash redemption, ticket refund, sponsor payment, and treasury payment exits through `Raffle::_transferQuote()` at [Raffle.sol:564](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:564). If Circle deny-lists the raffle clone as a canonical USDC sender, each transfer reverts and retrying or transferring a ticket cannot change the blocked sender; the full backed balance can remain inaccessible. This is Medium because it depends on a specific issuer-controlled external condition, not one an ordinary attacker can reliably create.

**Recommended Mitigation:**

No contract path can move USDC after its sender is deny-listed; either use a quote asset without sender freezing or explicitly make Circle unfreezing/remediation an operational recovery requirement of the USDC trust model.

**Fix review:**

## M-2. `Raffle::releaseSponsorProceeds()` fixes the USDC recipient, stranding a claim if that address is deny-listed

**Description:**

The exits at [Raffle.sol:375](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:375) can pay sponsor proceeds only to immutable `sponsorRecipient`; the sibling fee exit can pay only immutable `protocolTreasury`. If Circle deny-lists either fixed address after initialization, the transfer and preceding zeroing revert, and every retry targets the same blocked recipient. This is Medium because the backed claim becomes unreachable only under the named token's issuer-controlled deny-list condition.

**Recommended Mitigation:**

Add a claim-redirection function authorized by the current sponsor beneficiary (or stored sponsor) and by the current treasury respectively, so each can select a non-protocol replacement destination before the transfer.

**Fix review:**

## Unverified leads

- `Raffle::buyEntries()` — a sponsor can buy the final entries before close, cross the reserve, recycle 95% of gross, and gain winning chances — no pre-close cash-fallback entitlement or source-defined prohibition on sponsor-funded entries was established, so the third-party-harm and real-impact gates block promotion.
- `Raffle::requestDraw()` — narrowing a timestamp above `uint64.max` can make the callback deadline immediately expired — the roughly 584.5-billion-year precondition and a real value loss on a supported chain were not established.
- `Raffle::_isProtocolDestination()` — future same-factory clone addresses and already deployed foreign-factory clones can pass the sink predicate — all source-supported paths require the affected owner, operator, or sponsor to direct its own claim there, so distinct-victim harm was not established.
