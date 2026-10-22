# Turn 6 — All four judging gates

Candidates are judged once, in lifecycle order. Each candidate receives Gate 1, Gate 2, Gate 3, then Gate 4 without reordering or revisiting. `UNCERTAIN` counts as `ALLOWS`.

## C-01 — `RaffleFactory::createRaffle()` / untrusted-prize self-attestation [lenses: 4]

Gate 1 — `ALLOWS` — The code/interface check, receipt callback, and `ownerOf` response all come from the same arbitrary prize contract; no independent allowlist, delivery prerequisite, or failed-delivery refund path interrupts the attack.

Gate 2 — `ALLOWS` — A sponsor can deploy or control the prize, set `reserveEntries = 1`, and wait for one victim-funded purchase at low cost; no privileged compromise or external market state is required.

Gate 3 — `ALLOWS` — Honest purchasers and the winning-ticket owner lose their paid USDC/prize claim while the malicious sponsor receives 95% of gross.

Gate 4 — `ALLOWS` — The path moves real canonical USDC and leaves the advertised NFT claim permanently unfulfillable with no refund transition.

Disposition: `FINDING`, High. Raw LEAD promoted because the full path is source-supported; multi-lens agreement is not treated as proof.

## C-02 — `Raffle::buyEntries()` / sponsor last-minute reserve crossing [lenses: 1]

Gate 1 — `ALLOWS` — All pre-close entries count toward `reserveEntries`, and no sponsor/sybil exclusion stops the described purchase.

Gate 2 — `ALLOWS` — The sponsor can fund a sybil entry at the fixed price and later receive the sponsor-side allocation if the result changes.

Gate 3 — `BLOCKS` — Before the advertised sale closes, the earlier buyer owns only entries in the final sale population, not a fixed cash-fallback entitlement; ordinary dilution does not transfer an accrued claim from a distinct victim.

Gate 4 — `BLOCKS` — No source-defined guarantee, unauthorized transfer, insolvency, or stuck-fund result was established beyond ordinary open-sale outcome selection.

Disposition: `REJECTED`; retained under Unverified leads so the raw function is not dropped.

## C-03 — `Raffle::requestDraw()` / timestamp downcast saturation [lenses: 1]

Gate 1 — `ALLOWS` — At a timestamp above `uint64.max`, the full-width request window can be open while the stored `uint64` request time wraps and makes the callback deadline appear expired.

Gate 2 — `BLOCKS` — The precondition requires the chain timestamp to reach the roughly 584.5-billion-year `uint64` horizon; no realistic supported-chain path was established.

Gate 3 — `BLOCKS` — The raw path establishes immediate refund availability, not uncompensated harm to a party other than the requester or a distinct victim class.

Gate 4 — `BLOCKS` — No real-value loss, permanent lock, or lasting core-function break was established; the quote pot remains refundable.

Disposition: `REJECTED`; retained under Unverified leads so the raw function is not dropped.

## C-04 — `Raffle::settleWinningTicket()` / storage-only NFT settlement [lenses: 2]

Gate 1 — `ALLOWS` — The entry point checks the historical winning range and one-shot flag but never attempts prize delivery; it can persist allocation even when inline redemption would revert on the hostile NFT transfer.

Gate 2 — `ALLOWS` — The sponsor controls the prize transfer switch and can call the permissionless settlement after a reserve-1 raffle receives a victim purchase.

Gate 3 — `ALLOWS` — The winning-ticket owner, not the sponsor, is left without the prize or refund while the sponsor collects buyer-funded proceeds.

Gate 4 — `ALLOWS` — The separated settlement enables a 95%-of-gross USDC extraction and a permanently unredeemable winner claim.

Disposition: `FINDING`, High.

## C-05 — `Raffle::_settleWinningTicket()` / premature NFT-result allocation [lenses: 2]

Gate 1 — `ALLOWS` — The `NftWon` branch clears the pot and creates sponsor/treasury liabilities before delivery; the one-shot and range checks do not test deliverability or provide a failure fallback.

Gate 2 — `ALLOWS` — A sponsor-controlled pausable, upgradeable, or selectively reverting prize can satisfy escrow and later block the outbound transfer without another external condition.

Gate 3 — `ALLOWS` — Honest entrants fund the allocation and the winning owner bears the undelivered-prize loss.

Gate 4 — `ALLOWS` — All buyer-funded USDC can leave while the raffle remains liable for a prize it cannot deliver and cannot replace with refunds.

Disposition: `FINDING`, High.

## C-06 — `Raffle::releaseSponsorProceeds()` / release before prize delivery [lenses: 1]

Gate 1 — `ALLOWS` — A positive sponsor bucket is sufficient; neither this exit nor the sibling treasury exit requires `winnerRedeemed` or `prizeClaimed` in `NftWon`.

Gate 2 — `ALLOWS` — After controlling an admitted prize and obtaining one victim purchase in a reserve-1 raffle, the sponsor can call settlement and this permissionless release at negligible additional cost.

Gate 3 — `ALLOWS` — The current winning-ticket owner loses the advertised NFT and has no USDC fallback; the sponsor is the recipient of the victim-funded 95% payment.

Gate 4 — `ALLOWS` — The release transfers real USDC and can be followed by the treasury release, leaving no sale balance available to repair failed prize delivery.

Disposition: `FINDING`, High.

## C-07 — `Raffle::releaseSponsorProceeds()` / deny-listed fixed recipient [lenses: 1]

Gate 1 — `ALLOWS` — Transfer failure rolls the bucket zeroing back, but all retries target the same immutable sponsor recipient; the sibling fee path likewise cannot replace the immutable treasury.

Gate 2 — `UNCERTAIN` — Only Circle controls the canonical USDC deny-list, but deny-listing is a concrete behavior of the named dependency and the raw path supplies no in-contract assumption that prevents it; `UNCERTAIN` counts as `ALLOWS`.

Gate 3 — `ALLOWS` — The fixed sponsor beneficiary or treasury, rather than a caller triggering release, loses access to its backed claim.

Gate 4 — `ALLOWS` — The recorded USDC remains in the raffle but the affected claim cannot settle while the listing persists, a real integration-specific lock.

Disposition: `FINDING`, Medium. The issuer-controlled external condition lowers severity.

## C-08 — `Raffle::_transferQuote()` / deny-listed clone sender [lenses: 1]

Gate 1 — `ALLOWS` — Every quote exit uses the same clone as USDC sender, and the code has no migration or alternate settlement route after sender-side denial.

Gate 2 — `UNCERTAIN` — Only Circle controls the canonical USDC deny-list, but deny-listing is a concrete behavior of the named dependency and no source guard rules out the clone being listed; `UNCERTAIN` counts as `ALLOWS`.

Gate 3 — `ALLOWS` — Ticket owners, the cash winner, sponsor beneficiary, and treasury can all lose access through an event none of those claimants must cause.

Gate 4 — `ALLOWS` — The full sale balance can remain present but unreachable from every intended exit, a real named-token integration failure.

Disposition: `FINDING`, Medium. The issuer-controlled external condition lowers severity.

## C-09 — `Raffle::_isProtocolDestination()` / future and foreign clone gaps [lenses: 2]

Gate 1 — `ALLOWS` — The predicate skips registry checks for code-less future addresses and recognizes only clones registered by the canonical factory, so both stated sink classes pass.

Gate 2 — `ALLOWS` — A ticket owner, approved operator, or sponsor can select a predictable future clone or a foreign clone without privileged access.

Gate 3 — `BLOCKS` — Every source-supported path strands only the selector's own bearer or sponsor claim, or relies on ordinary ERC-721 authority already granted by that owner; no unrelated victim was established.

Gate 4 — `ALLOWS` — The selected ticket, quote claim, or prize can become genuinely inaccessible, but that real loss remains self-directed and is therefore killed by Gate 3.

Disposition: `REJECTED`; retained under Unverified leads so neither raw mechanism nor function is dropped.

## Final gate totals

- Deduplicated candidates judged: 9/9
- Candidates receiving all four gates: 9/9
- Accepted: 6 findings — 4 High, 2 Medium
- Rejected/unverified: 3
- Unique raw `(Contract,function)` tuples covered by an accepted finding or explicit unverified disposition: 8/8
