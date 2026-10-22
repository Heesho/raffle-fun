# OPENAI-GEBAL — sealed original first pass

Timestamp: 2026-10-21T08:05:46.734Z

Target SHA (operator supplied): 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Gebal revision verified by local rev-parse: 9ad24645f92a3821ae4539db5f1be52b48ed379e. This is the disclosed replacement for unavailable historical revision 5c68ec0284dc642823abe81cbc0e02fcb080a69f; no remote checkout was attempted in this cell.

Native plan: 24050765-c24a-47a2-acad-dda90c3b0ada; plan hash c48deb23a0d85851f525fb722e53fce4f987a7e71c81bb00c17b3b5304f98057. Origin run: ee890df3-084f-4d28-91d5-fa29d8fe5b7f.

Snapshot hash: d0b726edfae0c24ed708c5c0f1908c40f4ab85da8d1708de38fe437a384dcc0a

Context hash: c5b7124850800b51b1a5b5346ac3abe133da1f07d34f2d0764eab305fbb6947d

Local selection: gpt-6-astra / model_reasoning_effort=ultra, highest requested local setting, no fallback. Root selection is operator supplied; explicit specialist selections were accepted by the collaboration API. Provider-returned model/effort: unknown. Access program, provider identity, usage and spend: unknown. This is provider-specific method execution, not provider-verified identity.

## Independence and native status at seal

Original root conclusions below use only the native exported context for assessed source and its clean DESIGN requirements. No historical reports, tests, scanner results, accepted risk lists, source git history, memory or peer findings were read. Two same-model cold specialists were instructed to withhold conclusions until this seal. Only operational Docker availability information was received. No target analysis tool output was exposed. Intake succeeded; this seal precedes review import and report export, which must be evidenced separately in stage-ledger.json. Intake alone is not completed model review.

## Requirements and assumptions before disposition

The required behavior is a fixed six-decimal canonical-USDC price, contiguous transferable range tickets, atomic one-prize escrow, exclusive request/callback deadlines, full refunds on timeout, storage-only permissionless settlement, current-owner atomic redemption, independent sponsor/treasury exits and no clone-to-clone asset movement. Economics require 95/5 for NFT, 80/15/5 for cash and 100% per-entry refunds. Canonical quote-token and wrapper behavior are trusted by DESIGN; prize contracts and ticket recipients are not. Standard EVM rollback and the selected dependency source semantics are assumed, without claiming a compiled build. No trust in arbitrary NFT honesty is silently added; that discrepancy is L-01. Deployment identity and the intended breadth of clone isolation remain unverified.

## Original conclusions

No confirmed security defect was established in the reviewed source. One informational source-supported trust-assumption observation is retained as LEAD L-01, and L-02 remains an unconfirmed integration lead. Neither is accepted on the owner's behalf. This is not a safety certificate.

### L-01 — prize honesty and permanent delivery failure

The clean requirements call arbitrary prize contracts untrusted, while IRaffle states that supported prizes are honest standards-compliant ERC721s. The factory checks self-reported ERC165 support, the receiver transition, and ownerOf after escrow; those checks cannot establish future transfer behavior. In a reserve-met result, settlement can allocate the full pot to sponsor and treasury independently of NFT delivery. If an admitted prize subsequently refuses transfer, redemption reverts atomically but NftWon has no refund transition. This is a concrete conditional liveness/trust-boundary path, not a demonstrated exploit or a finding against an honest compliant prize: no particular hostile prize implementation is present in the pinned context. Keep as a lead until the intended prize trust boundary and an applicable concrete prize behavior are established. Defensive obligation: state the supported prize trust assumptions explicitly and assess whether the intended winner exit must survive permanent prize-delivery failure.

References: IRaffle.sol 12–15; RaffleFactory.sol 127–134,171–177; Raffle.sol 279–294,329–342,375–391,533–555. Confidence is high in the observed assumption mismatch and conditional control flow, not in an unprovided hostile prize or an executed loss. Severity is informational pending that evidence.

### L-02 — scope of destination isolation

Known destinations are screened through the current immutable factory and its isRaffle registry (Raffle.sol 593–604; RaffleFactory.sol 154–168). Other-factory clones and future code-less addresses are not universally identified. This is a possible interpretation gap in “never move assets between raffle clones”; no third-party unauthorized loss is established. A sponsor/owner deliberately selecting an inaccessible address is not by itself promoted to a defect.

## Per-file coverage

| File | Source coverage | Conclusion / limits |
|---|---|---|
| Raffle.sol, 1–615 | Full manual read | Lifecycle, claims, accounting, callbacks, destinations and inherited surface examined; L-01/L-02 remain leads. |
| RaffleFactory.sol, 1–187 | Full manual read | Constructor checks, immutable implementation, validation, registry ordering and atomic escrow examined. |
| libraries/RaffleConstants.sol, 1–44 | Full manual read | Rates, entry price, 100-ticket bound, sale limit and deadlines agree with implementation. |
| interfaces/IRaffle.sol, 1–522 | Full manual read | All types, events, errors, methods/getters included; honest-prize assumption differs from clean DESIGN. |
| interfaces/IRaffleFactory.sol, 1–151 | Full manual read | Full declared API and atomic-creation expectations compared to implementation. |
| foundry.toml, remappings.txt, package.json | Full manual read | Compiler 0.8.36 / Cancun, rates/dependency versions pinned; native gas_reports diagnosis unsupported; no script executed. |
| pnpm-lock.yaml | Full snapshot; selected semantic excerpts | Contracts importer and Chainlink/OpenZeppelin entries reviewed; no registry lookup or whole monorepo dependency audit. |
| 31 dependency files | Full native snapshot; reachable behavior review | VRF base/interface/client, ERC721, reentrancy, SafeERC20, clone creation, multiplication and supporting paths reviewed to spans in coverage.original.json. Other utilities not exhaustively audited. |

Every selected file and its SHA256 is in coverage.original.json and the authoritative context. This table describes manual source review, not statement/branch/test coverage.

## Per-property coverage

### P01 — Fixed configuration and initialization

Reviewed: implementation initialized/Refunding; factory immutable; clone storage initialized once by that factory; no mutable configuration or upgrade path.

Source: Raffle.sol 151-206; RaffleFactory.sol 65-92,97-125. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P02 — Atomic prize escrow / registry

Reviewed: create, init, registry, safe transfer, ownership and Active checks are one transaction. Receiver matches token/id/from/operator. Honest asset semantics remain a trust limit (L-01).

Source: RaffleFactory.sol 97-147,154-178; Raffle.sol 416-430. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P03 — Entry price / contiguous ranges / bounds

Reviewed: positive uint128 entry count, bounded sum, one ticket per purchase, exact entryCount*1,000,000. ticketCount cannot exceed totalEntries; pot multiplication is within uint256.

Source: Raffle.sol 209-237; RaffleConstants.sol 20-27. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P04 — Purchase callback / ticket transfer

Reviewed: payment and range/liability effects precede safe-mint callback; guarded economic methods cannot be reentered; ordinary authorized ERC721 transfers preserve range claims.

Source: Raffle.sol 209-237,497-502; ERC721.sol 115-136,216-307. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P05 — Request window and fee handling

Reviewed: [end,end+2days), requires positive entries, native fee paid once, request ID persisted, excess refund failure reverts transaction. No repeated accepted request.

Source: Raffle.sol 240-273,458-465; VRFV2PlusWrapperConsumerBase.sol 76-88. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P06 — Randomness authentication and callback bounds

Reviewed: wrapper-only entry, Drawing/request-ID/one-word/in-flight/deadline guards; winner in [1,totalEntries]; no asset transfer or unbounded search in callback. Gas not measured.

Source: Raffle.sol 509-524; VRFV2PlusWrapperConsumerBase.sol 101-107. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P07 — Refund eligibility and boundary races

Reviewed: refunds at request/callback deadline inclusive, callbacks strictly before; empty raffle early sponsor cancellation or post-end permissionless cancellation; terminal branches do not revert to Drawing.

Source: Raffle.sol 276-301,458-465. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P08 — Permissionless storage-only settlement

Reviewed: winning range proven without owner call, unknown IDs yield zero range and cannot contain positive winning entry, one-time allocation with no external asset transfer. Burned-refund ticket cannot enter win branch.

Source: Raffle.sol 304-306,533-558,579-585. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P09 — Conservation / fee rounding

Reviewed: settled liabilities sum to gross pot; fee floor(5% gross), cash winner floor(80%), sponsor residual. At fixed price all percentage amounts are integral raw units. Donations stay outside accounting.

Source: Raffle.sol 223-234,296-299,468-474,539-555; Math.sol 206-277. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P10 — Winner authority and atomic delivery

Reviewed: current owner only, implicit settlement rollback on unauthorized call, burn and flags before transfer, transfer failure or ownership-check mismatch reverts all effects. L-01 limits permanent delivery liveness.

Source: Raffle.sol 309-346; ERC721.sol 303-307. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P11 — Refund exactness / duplicates / bounded batch

Reviewed: 1..100 tickets, owner checks, historical inclusive ranges, burn then exact liability deduction and transfer. Duplicate/foreign/burned IDs revert atomically.

Source: Raffle.sol 349-372; RaffleConstants.sol 26-27. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P12 — Independent sponsor / treasury exits

Reviewed: independently zeroed liabilities before safe transfer; sponsor prize return in CashWon/Refunding only; no need for winning owner to participate in settlement.

Source: Raffle.sol 375-407. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P13 — Clone isolation and destination screening

Reviewed for same-factory known addresses; clone delegatecall storage independent and no shared pot. Universal cross-factory/future-address interpretation unresolved (L-02).

Source: Raffle.sol 187-195,497-502,564-567,593-604; RaffleFactory.sol 154-168. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P14 — Dependencies and configuration

Reviewed selected reachable dependency behavior; pinned package declarations/lockfile; zero-initialized clone reentrancy slot still locks because only ENTERED is rejected. Compilation and complete library audit unavailable.

Source: Context files plus native diagnosis. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

### P15 — Interface conformance / external integration

Full manual comparison of enum, parameters, events, errors, functions/getters and lifecycle comments. Honest-prize comment differs from DESIGN. ABI compilation and frontend live rereads not verified.

Source: IRaffle.sol 1-522; IRaffleFactory.sol 1-151; implementations. Status: MANUAL_SOURCE_REVIEWED; execution: NOT_RUN.

## Incomplete checks and proof obligations

- Source-only review: no compilation, tests, fuzzing, invariant execution, gas measurements, static analyzer execution, symbolic execution or formal proof was performed. Manual property coverage is not measured executable coverage.
- Native diagnosis is unsupported because foundry.toml profile.default contains gas_reports. Compiler metadata is 0.8.36 / Cancun; runtime compatibility and deployed bytecode remain unverified.
- Existing tests are excluded by explicit sourceOnly=true, existingTests=false scope. Docker daemon is unavailable and no pinned local tool image was verified, so the separately conditional test-inclusive plan is blocked and no host-tool fallback is authorized.
- All five production files including IRaffle.sol and IRaffleFactory.sol were reviewed in full from this exact context. Dependencies were snapshotted in full; manual semantic review focused on reachable ERC721 ownership/mint/burn, SafeERC20 transfer, clone creation, reentrancy storage, Math.mulDiv and VRF base/authentication. Remaining library utility text was not exhaustively audited.
- Root pnpm-lock.yaml is fully pinned; only the relevant contracts importer and Chainlink/OpenZeppelin resolution entries were semantically inspected. Package declarations identify @chainlink/contracts 1.5.0 and @openzeppelin/contracts 5.6.1. No registry provenance or deployed canonical address was verified.
- L-02 (unconfirmed integration lead): destination checks recognize the current factory and its already registered clones, not every other-factory or not-yet-created clone. Raffle.sol 593-604 and RaffleFactory.sol 154-168 need a precise interpretation of never move assets between raffle clones. No unauthorized victim-loss path is established; deliberate selection or transfer to an unreachable address is not promoted to a vulnerability.
- USDC administrative freeze/blacklisting and a permanently non-cooperating prize can obstruct their respective transfers; transaction atomicity preserves recorded claims on revert but cannot guarantee delivery by a third-party asset contract.
- NFT payout uses transferFrom plus ownerOf verification, not a receiver hook. This avoids a receiver veto but relies on the owner-selected or immutable recipient being capable of managing the received NFT; no unsupported claim that every contract recipient can recover it is made.
- No frontend, deployed contract state, production credentials, historical report, scanner result, prior test source, memory or peer conclusion was used for this original pass. Target SHA is operator-supplied and exact selected bytes are bound by the native snapshot; source git history was not inspected.
- Local model selection is gpt-6-astra with ultra effort as provided by the active runner instruction; provider-returned model and effort fields are unknown. No provider adapter or fallback was used. External usage, cost and provider identity are not independently verified by Gebal.

Before stronger assurance: compile this exact snapshot under the stated toolchain; execute authorized existing tests and bounded independent properties only in a verified pinned sandbox; measure callback/batch gas; establish deployment dependency identity; resolve prize trust assumptions and the scope of cross-clone destinations. These are obligations, not completed work. The Docker daemon is unavailable and no existing pinned image was verified; the conditional deterministic test-inclusive plan must remain BLOCKED.

## Sealing

This original report, review.original.json, coverage.original.json and context.json are sealed by SEAL.json before peer reconciliation. Corrections must be appended in separate artifacts, never overwrite this report or its review.
