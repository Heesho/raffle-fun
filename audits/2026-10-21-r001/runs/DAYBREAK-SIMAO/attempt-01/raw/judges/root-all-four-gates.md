# Native Turn 6 — Four-gate judge record

Timestamp: 2026-10-21T08:17:49Z

The gates were committed in order for each function-isolated candidate. `UNCERTAIN` is treated as `ALLOWS`. Lens agreement was not used as proof.

## J-01 — `RaffleFactory::createRaffle` / untrusted-prize self-attestation

- Gate 1: **ALLOWS** — ERC-165, the receiver callback, and `ownerOf` are all supplied by the same sponsor-selected contract; no independent guard stops a token that accepts ingress and refuses egress.
- Gate 2: **ALLOWS** — a sponsor can deploy a pausable, upgradeable, selective-revert, or fully fabricated ERC-721 and choose reserve one at low cost.
- Gate 3: **ALLOWS** — unrelated entrants and the winning ticket owner fund the sponsor and receive no deliverable prize or refund.
- Gate 4: **ALLOWS** — 95% of the entrant pot is extractable by the sponsor and the remaining 5% by the treasury while the winner's asset claim is permanently unpayable.
- Verdict: **PROMOTE / HIGH**. The complete path is present in the raw source analysis; multi-lens agreement is corroborative only.

## J-02 — `Raffle::settleWinningTicket` / public settlement decouples prize delivery

- Gate 1: **ALLOWS** — result, winning-range, and one-shot guards hold, but none attempts prize delivery or gates the resulting quote claims on it.
- Gate 2: **ALLOWS** — the malicious sponsor creates the prize behavior and reserve-one state; any caller can settle the publicly derivable winning range.
- Gate 3: **ALLOWS** — the honest ticket owner loses the paid consideration and the advertised prize.
- Gate 4: **ALLOWS** — the sponsor can extract 95% and the terminal state has no refund transition.
- Verdict: **HIGH**.

## J-03 — `Raffle::_settleWinningTicket` / internal allocation creates unbacked terminal claims

- Gate 1: **ALLOWS** — the helper zeroes `unsettledPot` and credits sponsor/fee claims before any NFT transfer; no `winnerRedeemed` or `prizeClaimed` precondition intervenes.
- Gate 2: **ALLOWS** — the attacker can create all internal preconditions with its own prize contract; no external condition is required.
- Gate 3: **ALLOWS** — entrants and the winning owner, not the sponsor-attacker, hold the undeliverable side of the exchange.
- Gate 4: **ALLOWS** — the full buyer-funded pot can leave and the one-NFT obligation remains unpayable.
- Verdict: **HIGH**.

## J-04 — `Raffle::releaseSponsorProceeds` / release precedes NFT delivery

- Gate 1: **ALLOWS** — the positive-claim and destination checks do not require `winnerRedeemed`; reentrancy and checks-effects-interactions do not restore cross-transaction atomicity.
- Gate 2: **ALLOWS** — after attacker-created prize refusal and ordinary settlement, the release is permissionless and pays the attacker's fixed recipient.
- Gate 3: **ALLOWS** — the current winning-ticket owner is left without prize or refund.
- Gate 4: **ALLOWS** — 95% of gross sales is direct attacker profit in the reserve-one path.
- Verdict: **HIGH**.

## J-05 — `Raffle::_transferQuote` / canonical USDC denylist locks clone-held claims

- Gate 1: **ALLOWS** — `SafeERC20` correctly reverts, but the immutable clone exposes no migration or alternate settlement route.
- Gate 2: **UNCERTAIN** — Circle can denylist a contract under the named canonical-USDC integration, although entrants cannot force or clear that external action. Per the native rule this counts as `ALLOWS`.
- Gate 3: **ALLOWS** — clean ticket owners, winner, sponsor recipient, and treasury can all be distinct from the conduct that causes a compliance freeze.
- Gate 4: **ALLOWS** — the balance remains backed but inaccessible for as long as the sender freeze persists, disabling every quote exit for that raffle.
- Verdict: **MEDIUM** because loss requires a specific external issuer action rather than an attacker-created protocol state.

## J-06 — `Raffle::releaseSponsorProceeds` / immutable recipient becomes denylisted

- Gate 1: **ALLOWS** — rollback preserves the claim but every retry uses the same immutable destination; there is no beneficiary-authorized redirection.
- Gate 2: **UNCERTAIN** — a post-initialization Circle recipient freeze is a real named integration behavior but is not under an ordinary attacker or claimant's control. It counts as `ALLOWS`.
- Gate 3: **ALLOWS** — the fixed sponsor beneficiary or treasury is the affected claimant; the freeze need not be caused by that claimant.
- Gate 4: **ALLOWS** — the recorded claim remains inaccessible indefinitely while other cohorts may settle.
- Verdict: **MEDIUM** because it requires a specific external issuer action and affects one fixed claim rather than draining the raffle.

## J-07 — `Raffle::buyEntries` / sponsor last-minute reserve manipulation

- Gate 1: **ALLOWS** — sponsor-funded entries count like every other entry and can cross the reserve immediately before the still-open sale closes.
- Gate 2: **ALLOWS** — the sponsor can use a fresh address and pay the fixed entry price.
- Gate 3: **UNCERTAIN** — earlier entrants experience changed odds/outcome, but their source-defined claim remains participation in an open sale whose final count is not fixed until closing.
- Gate 4: **BLOCKS** — no source-backed entitlement excludes sponsor purchases or guarantees the cash branch before sale close; the sequence demonstrates ordinary dilution under the specified rules, not a concrete unauthorized loss.
- Verdict: **UNVERIFIED LEAD / REJECTED AS FINDING**.

## J-08 — `Raffle::requestDraw` / `uint64` timestamp saturation

- Gate 1: **ALLOWS** — the narrowing cast can wrap after `uint64.max`, and the full-width deadline calculation does not prevent the inconsistent stored timestamp.
- Gate 2: **BLOCKS** — the precondition requires a chain timestamp beyond `uint64.max` seconds, with no practically reachable supported execution environment established.
- Gate 3: **IRRELEVANT** — not reached after Gate 2 blocks.
- Gate 4: **IRRELEVANT** — not reached after Gate 2 blocks.
- Verdict: **UNVERIFIED LEAD / REJECTED AS FINDING**.

## J-09 — `Raffle::_isProtocolDestination` / future or foreign raffle destination

- Gate 1: **ALLOWS** — the predicate recognizes only fixed plumbing and currently registered same-factory clones; code-less future clones and foreign-factory clones pass.
- Gate 2: **ALLOWS** — deterministic addresses can be predicted and foreign clones can exist.
- Gate 3: **BLOCKS** — every concrete path requires the ticket owner, buyer-selected recipient, or sponsor to direct its own claim to the sink; no distinct victim-funded redirection was established.
- Gate 4: **IRRELEVANT** — the hard self-harm gate already rejects the finding.
- Verdict: **UNVERIFIED LEAD / REJECTED AS FINDING**.
