# Anthropic lane — post-seal reconciliation (raffle.fun r001)

- Sealed first pass: `../FIRST-PASS.md`, sha256 `16cb0e68e79fba00c1ba91878e682184db08a175fbcf9164dd7b51cc469aefb2`, sealed 2026-10-21T09:19:07Z.
- Reconciliation started after the seal. It covers only this lane's own sealed outputs, this lane's tool campaigns, and the project's tests and historical audit notes, which were first read after the seal. No peer-provider output or coordinator reconciliation was read.
- Source revision: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Raffle.sol sha256 `6e4c9779…8617`, RaffleFactory.sol `d0e62b34…2ace`.
- Model agreement is not treated as proof. Every disposition below rests on source reading plus a lane reproduction (`tools/LANE-REPRO`, `harness-src/claude-harness/test/LaneRepro.t.sol`) or a stated reason.

Columns: **Lane severity** is the adjudicated severity. "Original IDs (severity as reported)" keeps every first-pass label unchanged.

## Summary

| ID | Root cause (one line) | Class | Lane severity | Confidence | Repro |
|---|---|---|---|---|---|
| CL-01 | NftWon pays sponsor/treasury regardless of prize deliverability; escrow and delivery are attested only by the untrusted prize contract | Design / integration risk (behaviour matches DESIGN; impact on buyers) | **Medium** (risk acceptance is an owner decision) | High | `test_RC3a`, `test_RC3b` PASS |
| CL-02 | Prize outflows (`releaseSponsorPrize`, NFT redeem) have no payout-time protocol-destination screen; creation-time screens ignore code-less (future-clone) addresses | Confirmed defect against "Never move assets between raffle clones" (self-inflicted) | **Low** | High | `test_RC1` PASS |
| CL-03 | Tickets remain transferable while `Drawing`, and the VRF word is readable from the pending fulfilment | Integration / market risk (bearer-ticket design) | **Low** | Medium (mempool exposure of fulfilment tx not verified) | `test_RC4` PASS (mechanism only) |
| CL-04 | Treasury equal to a future clone address bricks `createRaffle` at that nonce | Deployment configuration risk | **Informational** | High | `test_RC2` PASS |
| CL-05 | Sponsor can cancel an empty raffle before `endTime`; DESIGN.md says refunds open at the deadline and has no admin | Spec/documentation discrepancy (NatSpec documents the behaviour) | **Informational** | High | `test_RC5` PASS |
| CL-06 | Immutable USDC recipients have no recovery path from blocklisting/pause | Trusted-dependency / configuration risk | **Low** | High | reasoning (out-of-scope USDC behaviour) |
| CL-07 | Quote-token and VRF-wrapper identity are enforced only by deployment tooling | Configuration risk | **Informational** | High | reasoning |
| CL-08 | Sponsor (or a sponsor-controlled address) can buy entries to reach the reserve at a net 5% cost | Intended economic behaviour; aggravates CL-01 | **Informational** | High | reasoning |
| CL-09 | VRF liveness and configuration: fee paid by an arbitrary requester; `getVrfRequestPrice` depends on `tx.gasprice`; `requestConfirmations=30` must be inside the coordinator range | Configuration / liveness assumption | **Informational** | Medium | reasoning |
| CL-10 | Value sent outside protocol flows (forced ETH, stray NFTs, USDC surplus) is unrecoverable | Intended (documented in source) | **Informational** | High | reasoning |
| CL-11 | DESIGN.md is a single paragraph and contradicts NatSpec on prize trust ("untrusted" vs "honest, standards-compliant") | Documentation | **Informational** | High | text comparison |
| CL-12 | Hygiene: storage `ReentrancyGuard` on Cancun, inline-assembly refund, unreachable defensive checks, event ordering after hooks, identical ticket metadata across clones, `_safeMint` and EIP-7702 delegated EOAs | Informational / gas | **Informational** | High | reasoning |
| LEAD-1 | Reorg reordering two `createRaffle` calls can rebind a pending `buyEntries` to a different raffle at the same CREATE address | Unresolved lead | — | Low | not reproduced (needs a reorg model) |
| FP-1 | "Security tooling referenced by the package is absent" (TOB-S6-7) | False positive caused by clean-context exclusion | — | High | Post-seal: repo has test/echidna, medusa.json, Foundry/Hardhat suites (79 + 22 pass) |
| FP-2 | All Slither (12) and Aderyn (11 detector groups) lane observations | False positive or intended | — | High | `../TOOLS.md` |

No Critical or High code defect was confirmed. No issue lets a third party take buyers' USDC, the sponsor's assets or protocol fees under the documented trust model (canonical USDC, official VRF wrapper, honest standards-compliant prize). The bounded campaigns and symbolic checks in `../TOOLS.md` found no solvency, conservation, split, refund, range-partition, timing-window or authorization violation. That is evidence, not proof.

---

## CL-01 — Untrusted prize vs NftWon payouts (Medium, design-level)
- **Original IDs:** Pashov F2 "`releaseSponsorProceeds` pays the sponsor before NFT delivery in `NftWon`" [75] plus leads "Settlement credits 95%…", "`createRaffle` trusts the prize contract to report the escrow", "`createRaffle` checks prize ownership only after the transfer". SUP-03 (Low). Gebal obs 1 (low/high). ToB S3 TIA-1 (**Medium**). ToB S4 GA-H1 (HIGH-priority recommendation). ToB S6 TOB-S6-3 (high-priority action). ToB S5 REQ-35 note and documentation problem 2.
- **Evidence:** `RaffleFactory.sol:127-134` (escrow verified via `prize.ownerOf` and the raffle's status flip). `Raffle.sol:416-431` (`onERC721Received` trusts `msg.sender == prizeToken`). `Raffle.sol:329-337` (delivery and `ownerOf` check). `Raffle.sol:543-555` (settlement allocates the sponsor's 95% in NftWon). `Raffle.sol:375-381` (release independent of delivery). `IRaffle.sol:14-15` vs DESIGN.md.
- **Violated property:** "Reserve met awards NFT" in substance. Buyers fund the pot expecting a deliverable prize.
- **Preconditions:** a prize contract that lies (sponsor-deployed) or becomes non-transferable after creation (pausable, upgradeable, validator-restricted or expiring collection admin). No privileged protocol role is involved.
- **Impact:** the NftWon winner receives nothing. Sponsor 95% + treasury 5% = 100% of the pot is still released. Reproduced: `test_RC3a_lyingPrizeSponsorPaidWinnerGetsNothing` (sponsor 4,750,000 + treasury 250,000 of a 5,000,000 pot; the winner's redeem reverts). `test_RC3b_pausedHonestPrize` (an honest OZ collection paused by its admin after creation).
- **Disposition:** the code matches DESIGN.md ("Sponsor and treasury can claim independently", "arbitrary prize contracts … are untrusted", delivery failure must revert). Historical project notes, read post-seal (`packages/contracts/audit/CURRENT-FINDINGS.md` "Accepted design and dependency risks"; `V12-REVIEW` 243747/243754), already list this as a retained risk. This lane does **not** treat those notes as owner acceptance for this round. It keeps CL-01 open as the most material design risk and rates it Medium for user impact.
- **Disagreement preserved:** severities range from Low (SUP, Gebal) to Medium (TIA) to "High priority" recommendations (GA, S6). The lane picks Medium because it is not a code defect against the written spec but has full-pot user impact when the prize admission control fails.
- **Remedy options (owner decision, not authorized here):** (A) keep the behaviour, and make collection admission and attestation plus explicit disclosure a launch control. (B) Gate NftWon `releaseSponsorProceeds` on `prizeClaimed`, with a long timeout. (C) Add a delivery-failure fallback to the cash split after a timeout, which implies (B). B and C change DESIGN.md.
- **Regression/property:** "In NftWon, no sponsor proceeds leave before the winner holds the prize or a timeout passes" (if B or C is adopted). Keep `test_RC3a/b` as expected-behaviour controls.

## CL-02 — Prize leg not re-screened at payout; counterfactual clone addresses (Low)
- **Original IDs:** SUP-01 (Low, PoC). Pashov leads "`_isProtocolDestination` treats every address with no code as safe" and "`releaseSponsorPrize` has no runtime check of the recipient". Gebal obs 3 (informational). ToB S3 TIA-5 (Informational). ToB S5 REQ-38 (partial, low). ToB S6 TOB-S6-1.
- **Evidence:** `Raffle.sol:395-407` (no screen before `transferFrom` at :404) vs `Raffle.sol:564-567` (USDC leg re-screens). `Raffle.sol:593-605` (`isRaffle` only queried when `code.length != 0`). `RaffleFactory.sol:106` (CREATE clones, predictable).
- **Reproduction:** `test_RC1_counterfactualCloneRecipient`. Prize #1 of raffle A ends up owned by clone B, and `releaseSponsorProceeds` reverts with `InvalidQuoteDestination(B)` forever. The winner and treasury legs are unaffected.
- **Impact:** only the party that chose the address loses (sponsor, or a ticket holder sending a ticket to a future clone). It technically breaks "Never move assets between raffle clones". There is no third-party gain.
- **Remedy:** apply `_isProtocolDestination` in `releaseSponsorPrize` (and in the NFT branch of `redeemWinningTicket` for symmetry). UI/SDK should reject code-less recipients that equal a predicted `CREATE(factory, n)`. Regression: `test_RC1` should then revert at `releaseSponsorPrize`.
- **Historical:** V12-REVIEW 243748/243749/243759 classify this as self-stranding. That agrees with the Low severity.

## CL-03 — Transfers while Drawing / fulfilment reveal (Low)
- **Original IDs:** Pashov F1 [75] plus lead "Mempool readers learn the winning entry…". SUP-04. Gebal obs 2. ToB S4 GA-M1 (Medium recommendation). ToB S6 TOB-S6-2.
- **Evidence:** `Raffle.sol:497-502` (`_update` allows transfers in all states). `Raffle.sol:518` (word → entry is public once the fulfilment tx is visible).
- **Impact:** value moves away from open listings and bids during the reveal window. The outcome itself cannot be changed. `test_RC4` demonstrates only the mechanism; whether mainnet fulfilments are publicly visible ahead of inclusion was not verified.
- **Disposition:** consistent with the bearer-ticket design (NatSpec "transferable in every lifecycle state"). Mitigate in marketplaces/frontends: no listings or bids during `Drawing`. A transfer lock during Drawing is a design change.

## CL-04 — Treasury = future clone bricks creation (Informational)
- **Original IDs:** SUP-02, TOB-S6-1 (deployment-script part). Historical V12 243750 agrees.
- **Evidence:** `RaffleFactory.sol:80-90` (treasury screened only against self, quote, wrapper and implementation). `Raffle.sol:190-192` rejects `treasury == address(this)` during `initialize`. **Reproduction:** `test_RC2` (both retries revert, `raffleCount == 0`).
- **Remedy:** a deployment validator must require an existing Safe/EOA treasury. Optionally, add a constructor check against the first few CREATE addresses.

## CL-05 — Empty-raffle sponsor cancellation vs DESIGN.md (Informational)
- **Original IDs:** Gebal obs 4. ToB S5 REQ-23 (contradicted, low; "most likely a documentation fix"). TOB-S6-4. ToB S2 key observation 2. SUP §6 lists it as intended.
- **Evidence:** `Raffle.sol:279-284`. `IRaffle.sol:37`, `:322-324` document a sponsor empty-raffle cancellation authority. **Reproduction:** `test_RC5`.
- **Disposition:** intended per NatSpec. A buyer racing the cancel reverts before USDC moves. Fix DESIGN.md.

## CL-06 … CL-12, LEAD-1
- **CL-06:** TIA-2 (Low), TOB-S6-5, SUP-06, Gebal gap 3. Recipients are immutable by design ("no mutable configuration"). A blocklisted sponsor recipient or treasury strands only that claim, while ticket holders can re-route by transferring tickets. Document it, and choose recoverable treasury custody.
- **CL-07:** TIA-4, SUP-06, GA-H3, S5 REQ-009/010 note. `RaffleFactory.sol:65-91` checks code presence and `decimals()==6` only. Pin and live-verify canonical USDC and the Chainlink native v2.5 wrapper in deployment tooling.
- **CL-08:** Pashov leads "sponsor buys entries toward the reserve", "reserve check counts the sponsor's own entries"; TIA-7; SUP §6. This is intended reserve semantics. Combined with CL-01, a hostile sponsor can force NftWon cheaply.
- **CL-09:** SUP-05/06, S6 §5.3, LEAD-1 of SUP. Verify the target chain's wrapper limits on release day. UIs should use `estimateVrfRequestPrice` and overpay (the excess is refunded).
- **CL-10:** TOB-S6-6, SUP §6. Documented at `Raffle.sol:409-411`.
- **CL-11:** GA-H2, S5 documentation problems 1–2, TOB-S6-4. Expand DESIGN.md (state machine, trust catalog, invariants) and resolve the prize-trust wording.
- **CL-12:** TOB-S6-8, GA low items, SUP §7, TIA-6, SUP-07. No security impact.
- **LEAD-1:** Pashov lead "Clone addresses depend only on the factory nonce". It needs a reorg; frontends should reread the clone's parameters immediately before buying (DESIGN: "transaction decisions must reread current chain state"). Not reproduced.

## Not carried as findings
- **Gebal gaps and the SUP/TIA "trusted dependency" assumptions** (USDC fee-free, VRF semantics). These are trust-model assumptions, recorded as proof obligations in the final report.
- **TIA-3** "Purchases are credited without balance verification" (Informational) is intended under the canonical-USDC trust root (`Raffle.sol:560-563` NatSpec). It is kept as an assumption, not a defect.
- **Scanner observations:** see `../TOOLS.md`. No true positive.

## Cross-check against lane property campaigns
| Property (lane harness) | Foundry 512×128 + 2000×256 | Echidna (attempt-05, 330k calls) | Medusa (attempt-02, 15 min) | Halmos |
|---|---|---|---|---|
| Solvency `balance ≥ accounted` | pass | pass | pass | settlementSplit TIMEOUT (open) |
| Conservation (in − out = accounted) | pass | pass | pass | — |
| Pot == gross sales pre-resolution | pass | pass | pass | — |
| Refund liability == live tickets | pass | pass | pass | refundExact PASS |
| Ranges partition [1,total] | pass | pass | pass | winnerInRange (general) TIMEOUT; fixed sizes PASS |
| Outcome consistent / winner range | pass | pass | pass | as above |
| Prize custody | pass | pass | pass | sponsorPrizeLocked PASS |
| Settlement totals == pot, 5%/80% floors | pass | pass | pass | TIMEOUT (open) |
| Timing windows / auth flags | pass | pass | pass | requestDrawWindow, callbackDeadline, enableRefundsFromDrawing, initializeOnlyFactory, fulfillOnlyWrapper, redeemOnlyOwner PASS |

Mutation (24 hand-picked semantic mutants): pass 1 killed 17/24. After four gap tests, 20/24. The survivors are M10 (redeem-once), M20 (initialize auth), M22 (prize claim-once) and M21 (in-flight guard). M10, M20 and M22 are defence-in-depth guards that other checks cover under standard ERC721 and atomic initialisation. M21 is a **lane property gap**: the project's own `testZeroRequestIdDoesNotMatchUntilRequestReturns` covers the zero-request-id synchronous case that the lane mock never generated.

---
## Appended 2026-10-22T00:50Z — OpenKritt-mod (post-seal, modified controller)
- `runs/CLAUDE-OPENKRITT-MOD/attempt-01`: 0 raw candidates and 0 findings across 193 completed attempts.
- No new root cause. No original ID is added to any CL item.
- The non-detection of CL-01 and CL-02 is consistent with the workflow's output contract: concrete attacker-controlled exploit paths only.
