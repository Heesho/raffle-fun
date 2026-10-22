# Reconciliation addendum — sealed arrivals, final draft

Written 2026-10-21T18:04:44.806140+00:00. Frozen target: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

This is a post-seal cross-review supplement, not another independent source pass. The original register, report and seal are preserved byte-for-byte. No production code was edited and no new proof campaign was run. Every original attribution remains in the updated JSON. Owner acceptance was neither requested nor inferred.

## Verified inputs

| Input | Verified first-pass SHA256 | Scope |
|---|---|---|
| [DAYBREAK-SIMAO/attempt-03](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/FIRST-PASS.md) | `e44b2b1995fdf0410fc4608fbce64ba0fa28ae76e185564651468cad066a6f7c` | Source-only native judge, 9 candidates: 5 accepted High, 2 leads, 2 rejected. Follow-up proof files are not adopted here as sealed first-pass evidence. |
| [CLAUDE/consolidated-sealed-first-pass](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/claude/FIRST-PASS.md) | `16cb0e68e79fba00c1ba91878e682184db08a175fbcf9164dd7b51cc469aefb2` | Consolidated report includes source and tool-assisted cells; embedded ToB S6 is explicitly partial. Claimed PoCs are attributed report evidence, not newly independently rerun. |
| [GEMINI/consolidated-sealed-first-pass](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/gemini/FIRST-PASS.md) | `43a0a0efa35ae70f82b0311b29aea14a66aedf0b1f97d50f14e780d44ab5d3a3` | Consolidated first pass includes additional README/ARCHITECTURE/SECURITY context and different reported method pins; not identical clean input. Per-cell IDs preserved as reported, without adopting unsealed FINAL/HANDOFF files. |

Simao’s seal identifies the exact target commit and its checked source/dependency manifest. Claude’s sealed five production-file hashes match the clean target byte-for-byte. Gemini’s sealed report names the target commit, but used additional documentation and different reported harness pins; it is not an identical-context comparison. External FINAL/HANDOFF files have no corresponding seal here and their contents were not adopted. Running Daybreak Pashov/ToB outputs are excluded for later parent integration.

## Reconciled conclusions

**RF-001 remains one conditional economic root chain.** Admission trusts the selected prize’s ERC165, callback and ownerOf statements; later settlement and 95/5 releases do not require successful NFT delivery, and NftWon has no delivery-failure refund. A sponsor-controlled liar or later pause/revocation can defeat the advertised prize while quote liabilities remain internally correct. Daybreak Simao H-1 through H-5 (J-1/J-2/J-5/J-6/J-8) cover different functions of this chain, not five independent losses. Preserve its High judgment, Claude TIA-1/TOB-S6-3 and Gemini FP-M-02 Medium judgments, and Claude SUP-03’s Low integration/not-code-defect judgment. The original DESIGN untrusted-prize versus IRaffle honest-compliant-prize scope conflict remains unresolved. No amount of agreement establishes exploitability against an honest, continuously transferable collection.

**RF-002 remains Low, with sponsor-selected own loss.** The root’s honest ERC721 reproduction actually creates B after configuring its future address as A’s recipient, then returns A’s prize into B. B can only release its configured second prize. Source: RaffleFactory.sol:105–125,163–169; Raffle.sol:193–195,395–405,593–605. This is a demonstrated destination-invariant failure, not arbitrary EOA theft. Preserve Simao J-4 rejection as self-harm, Gemini FP-M-01 Medium, and Claude SUP-01 Low. Gemini’s winner-redemption-to-clone subclaim is not demonstrated: if clone B owns the ticket, B has no way to originate the owner-only call at Raffle.sol:320–321. Future ticket ownership itself can strand a claim. The treasury collision is separately CONFIG-001, because the capability and impact are deployment configuration and future creation failure.

## Newly separated observations and leads

| ID | Disposition | Practical implication |
|---|---|---|
| LEAD-001 | Low/Informational conditional; not confirmed deployed-market exploit — retained_external_preconditions_unproved | Potential secondary-market adverse selection; no demonstrated manipulation of winningEntry, primary-sale price, or custody authorization. |
| CLOSED-004 | Not a security finding — closed_expected_open_sale_behavior | Sponsor can no longer withdraw an already offered prize early; entrants retain documented draw/refund rights. This is ordinary ordering of two valid competing state transitions, not unauthorized asset loss. |
| OBS-006 | Informational — source_confirmed_no_asset_loss_shown | TicketPurchased may precede RaffleCreated in one successful transaction. The separate factory guard does not lock the clone. Paid accounting remains intact; final failed escrow checks roll back all effects. |
| CONFIG-001 | Informational; deployer-controlled self-lock — source_confirmed_configuration_path | Future creation stops; previously deployed raffles and unrelated recipient claims are not drained. |
| OBS-007 | Informational — source_confirmed_integration_requirement | Confusing display or phishing surface; no new ability to bypass ERC721 authorization demonstrated. |
| LEAD-002 | Unrated lead — retained_reorg_and_integration_preconditions_unproved | Potential purchase against unintended prize/sponsor, contingent on chain/finality and client behavior absent from this source review. |
| CONFIG-002 | Informational; intended parameter semantics — closed_no_supply_bound_requirement | Buyers receive configured cash-branch economics; no promise of feasible NFT threshold is enforced beyond nonzero reserve. |
| OBS-008 | Informational; intended with bounded refunds — source_confirmed_bounded_liveness | Possible refund rather than draw; not indefinite custody lock under functioning quote token. Fixed callback gas may overcharge relative to minimal mocks but requires real-wrapper measurement. |
| ADVISORY-001 | No security severity assigned — advisory_not_production_defect | Process recommendations preserve original IDs; their HIGH/MEDIUM/LOW headings are work priorities, not confirmed vulnerability severities. |

LEAD-001 requires real executable market orders, pending fulfillment visibility and ordering. No deployed-market exploit or randomness manipulation was established. Simao J-3, Claude Pashov #1/Gebal observation/SUP-04 and Gemini FP-I-01 are preserved. LEAD-002 is Claude’s unnumbered reorganization/address-binding concern; no client/chain demonstration was supplied.

Gemini FP-L-02 is closed as normal execution ordering: a paid valid pre-end purchase removes the empty-raffle cancellation condition. Gemini FP-L-03 is a reachable cross-contract callback ordering issue, not a free purchase: clone activation occurs before the factory’s final event, but the purchase pays USDC and a failing final custody/status check rolls back the entire transaction. An indexer must handle TicketPurchased before RaffleCreated. Gemini FP-L-01’s sponsor top-up, reserve cliff and single-buyer cash outcome remain configured economics under CLOSED-002.

CLAUDE GA-H/M/L labels are recommendation priorities, not automatically security severities. TIA-1..7, GA-H1..4/GA-V1/GA-M1..4/GA-L1..9/GA-I1..6, REQ-23/38, TOB-S6-1..8, SUP-01..07, LEAD-1..3 and all reported Gemini native-cell finding IDs are retained in the machine-readable attribution map. Unnumbered observations receive clearly labeled synthetic local identifiers without pretending the source assigned them.

## Proof and rejection boundaries

The earlier root honest-ERC721 future-clone test and earlier sealed fabrication mock retain their original executed-proof status. Incoming Claude PoC statements are report claims, not independently rerun tests in this addendum. Simao attempt-03’s post-seal follow-up proof is not covered by its FIRST-PASS seal and is not promoted here. No claim is made that an arbitrary ownerOf check establishes externally meaningful custody.

OpenKritt’s separate independent validator `supp_whole` was **rejected by the OpenAI provider**, according to the parent’s explicit report; it stopped after partial candidate work and was not retried. This is not a completed independent validation. Its sealed native workflow is a different artifact: verified OPENAI native-results has zero candidate records; verified DAYBREAK native-results has #1 paused-prize/payout, #2 future-clone recipient, #3 forged escrow and #4 a native duplicate of #3. All four IDs and native canonical IDs are retained. Native workflow completion is not proof of independent validation completion. This addendum inspected seal-bound native records; it does not claim inspection of the rejection error log or execution of the partial native proof scripts.

The six original test assurance issues are unchanged: all four temporary mutants compiled and deterministic tests killed them, but bounded invariant runs survived due to reachability or handler restrictions; the fee mutant died only at the larger recorded campaign. Owner-only caller selection, exact-deadline filtering, swallowed failures/no-op paths, stale historical mutation targets and Python’s missing transaction rollback remain assurance gaps. They are separate from production defects. Source-only exclusion of tests is not evidence that tests are absent from the full repository.

## Practical remediation order and re-audit

### P0: RF-001

Resolve the promised prize guarantee and scope conflict before any fix. Choose enforceable supported collection semantics/trust policy or a specified funded failure fallback. Retain all money required for any refund, including the 5% protocol leg. Gating sponsor payout alone cannot make an arbitrary lying ownerOf truthful.

Re-audit: Fake callback/ownerOf, paused or revoked custody after genuine escrow, independent payout ordering, timeout/fallback, every claim permutation, atomic rollback and no cross-raffle loss.

### P1: RF-002, CONFIG-001, OBS-004

Make outbound NFT destination policy explicit and consistent at transfer time; runtime refusal prevents cross-clone movement but does not restore an immutable stranded claim. Specify any recovery authority separately. Validate treasury and recipient custody at deployment and creation.

Re-audit: Honest ERC721 future-clone sponsor return; own/same/foreign factory sinks; counterfactual ticket custody; recipient becomes unusable; existing liabilities and unrelated claims remain safe.

### P1: AQ-001, AQ-002, AQ-003, AQ-004, AQ-005, AQ-006, AQ-007

Improve handler success reachability, adversarial callers, exact boundary attempts and independent reference rollback; repair stale mutation targets and run meaningful positive and negative transitions.

Re-audit: All four valid temporary mutants must be killed by intended properties at recorded bounds; compare success/revert/no-op action counts and branch/actor coverage. Python unauthorized lazy redemption must roll back as Solidity does.

### P2: LEAD-001, LEAD-002, OBS-006, OBS-007, CONFIG-002, OBS-008, EVIDENCE-001

Integrate canonical claim-aware UX, robust log indexing, confirmed deployment binding, marketplace pending-randomness policy and actual-chain dependency/fee checks.

Re-audit: Use real intended wrapper, quote token, deployment configuration and marketplace behavior. Treat unresolved environment leads as unresolved until demonstrated.

A runtime NFT destination check can prevent prohibited transfer while leaving the original immutable claim stranded; it is containment, not recovery. Arbitrary rescue, mutable recipients or a changed payout schedule require an explicit design choice. CREATE2/prevrandao address changes alone are not a complete fix. A delivery fallback must retain all funds it promises to pay and cannot trust a malicious token to honestly certify delivery.

Donation custody remains separate from liabilities: unsolicited ERC20/NFT/ETH may be intentionally unrescuable, while tracked claims can still be exact. Recipient blacklisting, quote freeze/upgrade and unsupported fee/rebase behavior remain conditional dependency/configuration risks. Existing scope and severity disagreements are retained; none was resolved by inferring owner acceptance.

## Artifacts and checks

Updated register: [findings-register-final-draft.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/reconciliation/findings-register-final-draft.json). It contains 21 findings/observations, 7 assurance issues and 190 attribution records. Counts include accepted, rejected, informational and advisory items; they are not a vulnerability count.

The companion ADDENDUM-SEAL.json records hashes for this supplement, the updated register, the reproducible generation script and the unchanged original files. No original seal is overwritten.
