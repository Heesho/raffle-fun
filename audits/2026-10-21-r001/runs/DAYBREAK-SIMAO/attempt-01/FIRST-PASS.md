# Security Review — Raffle

**Timestamp (UTC):** 2026-10-21T08:17:49Z  
**Declared target SHA:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`  
**Scope:** 5 production Solidity files, 2 contracts, plus `DESIGN.md`  
**Method:** accounting-first review across 12 independent attack lenses  
**Findings:** 4 High · 2 Medium · 0 Low · 0 Info  
**Reconciliation state:** Original first-pass conclusions; no proof result, historical report, scanner result, peer conclusion, accepted-risk list, or external finding corpus was consulted.

Completeness: 8 unique (Contract, function) in raw, 8 covered in final.

Entrants pay a fixed one-USDC price for transferable range tickets. At timeout, every live range is worth a full refund; after a cash result, gross sales split 80%/15%/5% between the winning bearer, sponsor, and treasury; after an NFT result, the sponsor and treasury receive 95%/5% while the winning bearer receives the prize. The quote-token ledger conserves every raw USDC unit and worst-order exits pay the last quote claimant under the trusted-token assumption. The material shortfall instead crosses assets: an arbitrary sponsor-controlled prize can accept escrow and later refuse delivery after buyer-funded proceeds have become independently releasable.

## Systemic observations

The High-severity items below are function-isolated components of one composite chain, retained separately because the native workflow forbids merging different `function:` fields: `RaffleFactory::createRaffle()` admits attacker-supplied prize semantics; `Raffle::settleWinningTicket()` and `Raffle::_settleWinningTicket()` allocate the pot without delivery; `Raffle::releaseSponsorProceeds()` releases the attacker's share before delivery. Fixing only one component should be evaluated against the whole chain. Separately, immutable per-raffle USDC sender and recipient addresses create issuer-freeze integration risks without an on-chain recovery route.

## H-1. `RaffleFactory::createRaffle()` accepts prize custody attestations from the adversarial prize itself, admitting unbacked raffles `[lenses: 4]`

**Description:**

[`RaffleFactory::createRaffle()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/RaffleFactory.sol:128) accepts an arbitrary sponsor-selected contract after that same contract reports ERC-721 support, fabricates or performs the receiver callback, and answers `ownerOf`. A sponsor can therefore use a token that accepts the inbound transfer while enabled and permanently rejects transfers from the raffle later. With reserve one and one honest 1-USDC entry, an NFT result lets the sponsor ultimately receive 0.95 USDC and the treasury 0.05 USDC while the winner can receive neither the prize nor a refund.

Chain: H-1 + H-2 + H-3 + H-4.

**Recommended Mitigation (Option A — restrict):**

Restrict prize tokens to an immutable allowlist or code-hash set of vetted, non-upgradeable implementations whose transfer behavior is part of the trust model.

**Recommended Mitigation (Option B — reorder/fallback):**

If arbitrary prizes must remain supported, keep all NFT-result quote proceeds locked until successful prize delivery and add a bounded failure transition that restores the untouched pot as ticket refunds.

**Fix review:**

## H-2. `Raffle::settleWinningTicket()` permits terminal allocation without delivering the untrusted prize `[lenses: 2]`

**Description:**

[`Raffle::settleWinningTicket()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:304) is permissionless and can complete settlement after `NftWon` while a sponsor-controlled prize is already paused or configured to reject outbound transfers. The range and one-shot guards are sound, but settlement does not move the NFT or prove it is deliverable; it makes 95%/5% quote claims available in a terminal state with no refund transition. The attacker can withdraw its 95% share while the winning ticket remains permanently unredeemable.

Chain: H-1 + H-2 + H-3 + H-4.

**Recommended Mitigation:**

Do not expose standalone NFT-result settlement as a proceeds-enabling transition. Couple allocation to successful prize delivery, or preserve the pot for a bounded refund fallback until delivery succeeds.

**Fix review:**

## H-3. `Raffle::_settleWinningTicket()` zeroes the pot and creates releasable claims before prize delivery `[lenses: 2]`

**Description:**

In the `NftWon` branch, [`Raffle::_settleWinningTicket()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:528) sets `unsettledPot` to zero and credits the sponsor and treasury from the entire gross pot before the only prize-delivery attempt. It requires neither `winnerRedeemed` nor `prizeClaimed`. For 100 entries, the contract can pay 95 USDC to the malicious sponsor and 5 USDC to the treasury while the last claimant is short one NFT and has no substitute quote liability.

Chain: H-1 + H-2 + H-3 + H-4.

**Recommended Mitigation (Option A — reorder):**

Keep NFT-result proceeds unallocated or non-releasable until the transfer and ownership verification complete, and add a deadline that converts the retained pot to `remainingRefundLiability` if delivery never succeeds.

**Recommended Mitigation (Option B — restrict):**

Restrict supported prize implementations so a sponsor cannot pause, upgrade, selectively revert, or counterfeit custody after escrow.

**Fix review:**

## H-4. `Raffle::releaseSponsorProceeds()` pays the sponsor before the NFT winner is made whole `[lenses: 1]`

**Description:**

[`Raffle::releaseSponsorProceeds()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:375) checks only that the sponsor claim is nonzero. In an NFT result it does not require `winnerRedeemed`, so the sponsor can collect 95% of gross sales in an earlier transaction even though its prize contract permanently rejects the winner's later transfer. Reverting the redemption restores only that transaction's ticket and flags; it cannot claw back the sponsor or treasury payments.

Chain: H-1 + H-2 + H-3 + H-4.

**Recommended Mitigation:**

Reject both sponsor and protocol quote releases while `status == NftWon && !winnerRedeemed`; if delivery remains incomplete at a fixed deadline, make the retained gross pot refundable to ticket holders.

**Fix review:**

## M-1. `Raffle::_transferQuote()` has no recovery path if canonical USDC freezes the raffle sender `[lenses: 1]`

**Description:**

Every quote exit funnels through [`Raffle::_transferQuote()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:564). If Circle freezes a raffle clone after it holds sales proceeds, USDC reverts every refund, cash redemption, sponsor payment, and fee payment. `SafeERC20` correctly preserves the recorded claims, but tickets cannot change the blocked sender and the immutable clone exposes no migration route. This requires a specific external issuer action, so severity is Medium rather than High.

**Recommended Mitigation:**

Either use a quote asset without sender freezing, or document and operationalize Circle remediation/unfreezing as an explicit trust dependency; an on-chain function cannot transfer USDC while its sender is frozen.

**Fix review:**

## M-2. `Raffle::releaseSponsorProceeds()` cannot redirect a claim after its fixed USDC recipient is frozen `[lenses: 1]`

**Description:**

The sponsor recipient and treasury are immutable, and [`Raffle::releaseSponsorProceeds()`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO/target/packages/contracts/src/Raffle.sol:375) always pays the stored address. If Circle freezes that recipient after initialization, the payment reverts and rollback preserves the claim, but every retry targets the same blocked address. The affected fixed claimant can remain unable to access a fully backed 95% sponsor claim; the sibling treasury mechanism can strand the 5% fee. This requires a named external issuer action and is therefore Medium.

**Recommended Mitigation:**

Allow the stored sponsor (for sponsor proceeds) and an appropriately authenticated treasury authority (for fees) to redirect an outstanding claim to a non-protocol replacement address before transfer.

**Fix review:**

## Unverified leads

- `Raffle::buyEntries()` — a sponsor can buy the reserve-crossing entries just before close and recycle 95% of the combined pot, but the source defines an open sale in which all paid entries count; no protected pre-close cash-outcome entitlement or sybil-resistant minimal fix was established.
- `Raffle::requestDraw()` — narrowing timestamps to `uint64` wraps beyond `uint64.max` and can make a new callback immediately late, but the required timestamp is not practically reachable on a supported chain.
- `Raffle::_isProtocolDestination()` — future same-factory clone addresses and foreign clones evade the current predicate, but every concrete loss requires the affected owner or sponsor to direct its own claim to that sink; no distinct victim was established.

## Per-file coverage

| File | Coverage | Result |
| --- | --- | --- |
| `Raffle.sol` | Full file; initialization, purchases, ticket movement, draw request/callback, timeouts, settlement, winner/refund/sponsor/fee exits, destination screening, arithmetic and reentrancy | Covered; H-2/H-3/H-4, M-1/M-2, and three leads arise here |
| `RaffleFactory.sol` | Full file; constructor trust configuration, clone creation/registration, parameter checks, ERC-721 escrow and post-checks | Covered; H-1 |
| `libraries/RaffleConstants.sol` | Full file; prices, percentages, timeouts, callback settings | Covered; constants reconcile with source arithmetic |
| `interfaces/IRaffle.sol` | Full explicit interface, including status, structs, errors, events, getters and mutators | Covered; no interface/implementation mismatch promoted |
| `interfaces/IRaffleFactory.sol` | Full explicit interface, including create parameters, registry getters, errors and events | Covered; no interface/implementation mismatch promoted |
| `DESIGN.md` | Full design, accounting model, lifecycle, invariants and trust boundaries | Covered; untrusted-prize boundary is central to the High chain |

## Per-property coverage

| Property | Coverage/result |
| --- | --- |
| Quote conservation and aggregate writers | Covered; holds for intended canonical-USDC flows |
| Ticket-range uniqueness and one-time consumption | Covered; holds |
| State-machine one-way transitions | Covered; holds, but `NftWon` lacks an undeliverable-prize fallback |
| Deadline complementarity | Covered at `endTime`, request deadline and callback deadline; holds at practical timestamps |
| VRF caller/request/word/deadline binding | Covered; holds under the trusted wrapper assumption |
| Bearer ownership across transfer, settlement, refund and redemption | Covered; holds |
| Prize custody and terminal delivery | Covered; fails against sponsor-controlled transfer revocation/self-attestation |
| Same-factory destination isolation | Covered; current clones blocked, future/foreign cases retained as self-harm lead |
| Reentrancy and external-call rollback | Covered; local atomicity holds but does not restore value released in earlier transactions |
| Bounds, decimals, percentages and rounding | Covered through `uint128` saturation and worst-order exits; exact at the 1,000,000-unit price |
| Last user out | Covered for NFT, cash, refund, draw-fee and empty-cancel lifecycles; NFT winner loses in the High chain |
| Named integrations | Covered for canonical USDC, Chainlink wrapper and arbitrary ERC-721 prizes; USDC freeze risks are M-1/M-2 |

## Native-stage note

All 12 lens responses were completed and preserved before this report. Deduplication used hard function isolation, all four judge gates were recorded for every candidate, and no finding was promoted merely because multiple models agreed.
