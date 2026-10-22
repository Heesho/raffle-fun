# Turn 6 — Deduplication and completeness evidence

This is internal audit evidence, not the client-facing report.

## Runtime provenance

- Requested and accepted local model selection: `gpt-daybreak-blue-latest`
- Requested access program: `daybreak_blue`
- Reasoning effort: `ultra`
- Fallback/substitution: disabled; none used
- Provider-returned model: `unknown` (the provider returned no model identity)
- Provider-returned access program: `unknown` (the provider returned no program identity)
- Context: ephemeral; memory disabled

No identity is inferred from the requested alias, access-program request, or model self-report.

## Input accounting

- Complete specialist inputs read: 12/12
- Raw blocks parsed: 15 total — 10 `FINDING`, 5 `LEAD`
- Preserved money-map evidence read: `evidence/bundles-pre-cleanup/money-map.md`
- Specialist files with zero blocks: lenses 01, 06, and 07
- Historical reports, tests, scanner output, git history, proof output, and external reconciliation consulted: none

## Exact function inventory and coverage gate

| # | Raw `(Contract, function)` | Raw block count | Deduplicated candidates | Final disposition(s) |
| ---: | --- | ---: | --- | --- |
| 1 | `(RaffleFactory, createRaffle)` | 4 | C-01 | H-1 |
| 2 | `(Raffle, buyEntries)` | 1 | C-02 | Unverified lead 1 |
| 3 | `(Raffle, requestDraw)` | 1 | C-03 | Unverified lead 2 |
| 4 | `(Raffle, settleWinningTicket)` | 2 | C-04 | H-2 |
| 5 | `(Raffle, _settleWinningTicket)` | 2 | C-05 | H-3 |
| 6 | `(Raffle, releaseSponsorProceeds)` | 2 | C-06, C-07 | H-4, M-2 |
| 7 | `(Raffle, _transferQuote)` | 1 | C-08 | M-1 |
| 8 | `(Raffle, _isProtocolDestination)` | 2 | C-09 | Unverified lead 3 |

Completeness: 8 unique (Contract, function) in raw, 8 covered in final.

Function isolation was applied literally: `settleWinningTicket` and `_settleWinningTicket` remain separate, and neither was merged into `createRaffle` or `releaseSponsorProceeds`. The two `releaseSponsorProceeds` blocks remain separate candidates because they describe different bug classes and mitigations.

## Deduplicated candidates

### C-01 — `RaffleFactory::createRaffle()` accepts an untrusted prize's self-attestation [lenses: 4]

Merged synonymous raw classes: `untrusted-prize-escrow`, `untrusted-prize-self-attestation`, and `untrusted-prize-contract`. Raw sources: lenses 05, 09, 10, and 12.

Preserved mechanisms:

1. The arbitrary prize contract supplies its own ERC-165 answer.
2. The same contract can fabricate the expected receipt callback and the later `ownerOf` answer, so those checks are not independent proof of escrow.
3. A token that genuinely enters escrow can later pause, upgrade, blacklist, burn, or selectively reject outbound transfers.

Preserved mitigation changes:

- Option A — validate: add an immutable factory allowlist of vetted, behaviorally trusted, non-upgradeable prize implementations/collections.
- Option B — gate/fallback: keep NFT-result sponsor and protocol proceeds locked until successful delivery and convert the untouched pot to refunds after a fixed delivery deadline.

Disposition: promote the merged lead and findings to a High finding. The concrete path, not four-lens agreement, proves the result.

### C-02 — `Raffle::buyEntries()` permits sponsor-funded reserve crossing [lenses: 1]

Raw class: `sponsor-last-minute-reserve-manipulation`. Source: lens 03.

Mechanism preserved: a sponsor can use a sybil to buy the last entries before close, change the result from `CashWon` to `NftWon`, recycle 95% of gross through the sponsor recipient, and obtain additional winning chances.

Disposition: rejected by the harm/value gates. Before the still-open sale closes, an earlier buyer has no fixed cash-fallback entitlement; the supplied source defines the reserve over all entries and establishes no sybil-resistant prohibited cohort.

### C-03 — `Raffle::requestDraw()` narrows a post-`uint64` timestamp [lenses: 1]

Raw class: `timestamp-downcast-saturation`. Source: lens 11.

Mechanism preserved: at `block.timestamp == type(uint64).max + 1`, `drawRequestedAt` wraps to zero, making the callback deadline appear expired immediately; `resolvedAt` has the sibling narrowing.

Disposition: rejected as practically unreachable and without a source-supported value loss; retained as an unverified lead for completeness.

### C-04 — `Raffle::settleWinningTicket()` exposes storage-only NFT settlement [lenses: 2]

Merged synonymous raw classes: `untrusted-prize-payout-theft` and `prize-delivery-decoupling`. Sources: lenses 08 and 11.

Preserved mechanism: the public settlement entry point lets a sponsor persist the NFT-result allocation in a transaction that never attempts prize delivery. By contrast, inline settlement during `redeemWinningTicket` rolls back when the hostile NFT transfer fails.

Preserved mitigation changes:

- Option A — reorder: make NFT-result settlement atomic with successful prize delivery and add a fixed refund fallback.
- Option B — validate/gate: gate both quote releases on `winnerRedeemed`/verified prize ownership and transition an undelivered result to refunds.

Disposition: High finding.

### C-05 — `Raffle::_settleWinningTicket()` allocates the pot before NFT delivery [lenses: 2]

Merged synonymous raw classes: `premature-proceeds-release` and `unbacked-prize-settlement`. Sources: lenses 02 and 04.

Preserved mechanisms:

1. The `NftWon` branch clears `unsettledPot` and creates immediately releasable 95% sponsor and 5% treasury claims without moving the prize.
2. There is no recovery transition if later prize delivery fails permanently.

Preserved mitigation changes:

- Option A — reorder/fallback: keep the pot uncommitted until successful prize delivery and route it to refunds after bounded failure.
- Option B — validate: admit only immutable allowlisted/code-hash-allowlisted prize implementations that are audited, non-upgradeable, and non-pausable.

Disposition: High finding.

### C-06 — `Raffle::releaseSponsorProceeds()` releases consideration before prize delivery [lenses: 1]

Raw class: `premature-proceeds-release`. Source: lens 03.

Preserved mechanisms: the sponsor exit at lines 375–381 and sibling treasury exit at lines 385–391 both omit an `NftWon` successful-delivery condition. Either can execute before `winnerRedeemed`, and together they can empty all sale USDC.

Preserved mitigation: reject both quote releases while `status == NftWon && !winnerRedeemed`; retain the pot and provide a bounded refund transition if delivery remains impossible.

Disposition: High finding.

### C-07 — `Raffle::releaseSponsorProceeds()` fixes a potentially deny-listed USDC recipient [lenses: 1]

Raw class: `usdc-denylisted-fixed-recipient`. Source: lens 10.

Preserved mechanisms: sponsor proceeds can only target immutable `sponsorRecipient`; the sibling fee claim can only target immutable `protocolTreasury`. Canonical USDC can reject either recipient, and repeated release attempts use the same address.

Preserved mitigation: add separately authorized sponsor-beneficiary and treasury redirection paths that reject protocol destinations.

Disposition: Medium finding. Reachability is issuer-controlled and therefore uncertain, which counts as allowed; the specific named-token integration condition lowers severity.

### C-08 — `Raffle::_transferQuote()` has no recovery if USDC deny-lists the clone [lenses: 1]

Raw class: `usdc-denylist-escrow-lock`. Source: lens 10.

Preserved mechanism: every winner, refund, sponsor, and treasury quote exit funnels through the same clone sender; a sender deny-list blocks all exits, and moving a ticket cannot change the sender.

Preserved mitigation: use a quote asset without sender freezing or make Circle unfreezing/remediation an explicit operational recovery requirement.

Disposition: Medium finding. Reachability is issuer-controlled and therefore uncertain, which counts as allowed; a named-token-specific external condition lowers severity.

### C-09 — `Raffle::_isProtocolDestination()` misses future and foreign clones [lenses: 2]

Merged synonymous raw classes: `counterfactual-clone-destination` and `incomplete-protocol-destination-screening`. Sources: lenses 10 and 12.

Preserved mechanisms:

1. A predictable future same-factory clone has no code and is not yet registered, so it passes before deployment.
2. An already deployed clone from a different factory has code but is absent from the canonical factory registry, so it also passes.

Disposition: rejected by the third-party-harm gate. Every source-supported path requires the affected ticket owner, approved operator, or sponsor to direct its own claim to the sink; no distinct victim-funded path was established. Retained as an unverified lead.

## Composite-chain check

`Chain: H-1 + H-2 + H-3 + H-4` crosses the factory-to-raffle trust boundary: admission of the hostile prize enables separate settlement, premature allocation, and premature release. No additional chain finding is created because the raw paths for each function-isolated finding already establish the same full 95%-of-gross extraction and winner loss; combining them does not establish a greater impact.
