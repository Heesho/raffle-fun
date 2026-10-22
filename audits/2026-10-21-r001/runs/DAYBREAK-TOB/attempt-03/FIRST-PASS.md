# DAYBREAK-TOB immutable source-only first pass

## Freeze identity and decision boundary

This is the independent source-only first pass for frozen target SHA 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. It is frozen before any S6 test, scanner, printer, or cross-cell reconciliation exposure.

Exact route tuple: model=gpt-daybreak-blue-latest; cyber access program=daybreak_blue; reasoning effort=ultra; fallback=disabled; multi-agent=disabled. Provider-returned model identity and provider identity are unknown because no actual provider event supplied either value.

This report uses only the five sealed source stages in the DAYBREAK-TOB attempt-03 lineage, target/DESIGN.md, and source in that same frozen target. It does not claim dynamic reproduction. The one non-analysis execution already contained in the sealed lineage was S4's isolated compiler-only Forge build; it was not a test or scanner run and its outputs/cache were redirected outside the target.

The result is:

| ID | Class | Severity | Consolidated title |
| --- | --- | --- | --- |
| FP-SEC-01 | Exploitable security finding | Critical | An untrusted prize can self-attest escrow and delivery while buyer-funded proceeds are released |
| FP-SEC-02 | Security/integration finding | Medium | Unsafe outbound prize transfer can strand the NFT in a contract recipient |
| FP-SEC-03 | Security/invariant edge | Low | A deliberately selected future-clone address defeats destination invariants |
| FP-DIV-01 | Design-code divergence | Low | The sponsor can close an empty raffle before the documented deadline |
| FP-OOS-01 | Out-of-scope compliance status | Informational | Frontend fresh-state rereads cannot be verified from the contract-only target |

The three independent stage reports about malicious prize behavior are one root cause, FP-SEC-01, not three findings.

## Sealed lineage and provenance

The exact source artifacts are:

- S1 dossier: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md
- S1 seal: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/SEAL.json
- S2 report: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/REPORT.md
- S2 seal: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/SEAL.json
- S3 report: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md
- S3 seal: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/SEAL.json
- S4 report: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md
- S4 seal: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/SEAL.json
- S5 report: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md
- S5 summary: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/summary.json
- S5 report input: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/report-input.json
- S5 seal: /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/SEAL.json

S1 is validated same-cell inheritance from attempt-01: 12 native structured function records, their 12 prose analyses, and the dossier were inherited; 31 common files were byte-identical; and the original evidence was not rewritten. The original controller was terminated only after the dossier existed. S2 preserves its first local wait-loop attempt and completed a fresh local retry; the S2 seal names those local executions preserved_failed_attempt=attempt-01 and completed_attempt=attempt-02. Those local labels must not be confused with campaign attempt-02. Campaign attempt-02 remains preserved and unused by this first pass. S3 and S4 completed fresh initial runs. S4 used only an isolated compiler build. S5 checked all 56 extracted properties instead of stopping at the native MAX_LIMIT=30, while preserving Extract → Align → Verify → Report, the native schemas and evidence rules, the reverse sweep, and two independent refuters for each of the 11 initially non-implemented records.

### Stage coverage and seals

| Stage | Report SHA-256 | Sealed at | Source coverage and method | Remaining source-only limitation |
| --- | --- | --- | --- | --- |
| S1 audit context | 854e2abd2863adb63f553f1fd4ac1a5e3b81acae38d9bbb2d1733c8a0fb7e0af | 2026-10-21T18:41:02Z | Same-cell inherited dossier; 5/5 production files; 12/24 ranked candidates received native standalone records; context, invariants, assumptions, and 21 carried questions | Context stage, not a judgment pass; 12 candidates below the native record cut; deployed external code absent |
| S2 entry points | e63757982fbe049fa6ac482a7c205c00160dd84003b78b727adac0f90391cfd0 | 2026-10-21T17:53:04Z | Manual source enumeration over 5 production files plus the 31-file dependency closure; 19 recurring state-changing entry points and 5 deployment-time entries | Slither cross-check pending; external token, receiver, and wrapper implementations absent |
| S3 token integration | 1f9e2cd0cc1e994b3f95771fede686bffb0fe8e027c98a70da06bac194d4189e | 2026-10-21T18:06:48Z | Fresh manual review of ticket ERC-721, quote ERC-20, prize ERC-721, wrapper, all 24 weird-token patterns, 5 production files, and all 31 dependencies | No deployed identities, RPC, balances, scarcity, runtime token semantics, tests, or conformance tools |
| S4 guidelines | 19b82b8743d9971337152299561b1b28e2d9426472fcb6f67494f07ff927d227 | 2026-10-21T18:23:46Z | Fresh five-phase, eleven-area source review; 5 production files and 31 dependencies; isolated offline Forge compilation of 36 Solidity files succeeded | No tests or scanners; no Hardhat run, coverage, CI, dynamic traces, live deployment, or advisory lookup |
| S5 specification compliance | e2cdee01bc21252af38f022c23588b07bdfe1b2712cca64208872166afc74e72 | 2026-10-21T22:41:15Z | All 56 properties checked in fresh exact-route contexts; 45 initially implemented, 11 candidates, 22 refuters, 7 requirement-level survivors, 4 drops, 11 reverse-sweep behaviors | No dynamic corroboration, deployment provenance, live nonce/state, or frontend artifact |
| S6 | Deliberately pending | Not sealed | No S6 input was read or run | Tests, scanners, printers, dynamic reproduction, and cross-cell comparison remain behind this first-pass seal |

S5's post-stage freeze verification was clean: ok=true, 435 files verified per root, 5 production files, and 31 dependency files. Its seal records ../../logs/freeze-after-s5.json as the verification record. No target, source, production, configuration, lock, freeze, or inherited-stage artifact was changed.

This aggregate is exactly five source stages/methods so far: S1 audit-context orientation and function analysis, S2 entry-point-analyzer, S3 token-integration-analyzer, S4 guidelines-advisor, and S5 spec-to-code-compliance. It is not the complete Trail of Bits catalog. In particular, secure-workflow-guide remains pending.

## Candidate reconciliation and severity decisions

| Candidate views | Consolidated disposition |
| --- | --- |
| S3 H-01 High; S4 S4-SEC-01 High; S5 F-01 Critical across REQ-14, REQ-48, and REQ-53 | One finding, FP-SEC-01, Critical. S3 and S4's High view is preserved. The final uplift follows the demonstrated no-cap consequence: an untrusted sponsor can set a trivially met reserve, sell entries for real trusted quote token, release 95% to its chosen recipient and 5% to treasury, and still withhold or fabricate the NFT. |
| S3 M-01 Medium, expressly conditional on noncanonical token behavior; S5 dropped REQ-06 after document refutation | Not a finding under the stated trusted canonical-USDC assumption. Nominal-versus-balance-delta accounting remains an S6 lead and deployment assumption because SafeERC20 proves call behavior, not amount moved. |
| S3 M-02 Medium; S4 treated contract-winner semantics as a documentation gap; S5 U-10 found the same behavior | FP-SEC-02, Medium. A standards-compliant token and an incompatible contract recipient are enough; a malicious token is not required. |
| S3 L-01 Low and S4's two-phase-activation recommendation | Folded into FP-SEC-01 rather than counted again. It is a secondary consequence of giving sponsor-selected prize code control after callback activation but before factory finalization. |
| S4 S4-SEC-02 Low; S5 F-02 High across REQ-44 and REQ-47 | FP-SEC-03, Low. S5's High minority view is preserved, but downgraded because exploitation requires deliberate future-address selection and nonce/order coordination, principally strands the selecting sponsor's entitlement or prize, and no affected deployment was established. |
| S5 F-03 Medium for REQ-35; S4/source interface describe the branch intentionally | FP-DIV-01, Low design-code divergence. It requires zero sold entries, so no ticket holder loses a refund; the demonstrated consequence is early cancellation and early return of the sponsor-controlled prize. |
| S5 F-04 Low for REQ-56 | FP-OOS-01, Informational. Absence of a frontend from a contract-only target is an evidence boundary, not proof of a vulnerable frontend. |

## Exploitable and security findings

### FP-SEC-01 — Critical — An untrusted prize can self-attest escrow and delivery while buyer-funded proceeds are released

Affected source:

- target/DESIGN.md:L2
- target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15
- target/packages/contracts/src/RaffleFactory.sol:L97-L147 and L154-L177
- target/packages/contracts/src/Raffle.sol:L329-L337, L375-L391, L416-L430, and L533-L557

Stage provenance:

- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md, H-01 and L-01
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md, S4-SEC-01
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, F-01 / REQ-14, REQ-48, and REQ-53

Documented requirement and disagreement: DESIGN.md:L2 says exactly one ERC-721 prize is atomically escrowed and says arbitrary prize contracts are untrusted. IRaffle.sol:L12-L15 instead assumes supported prizes are honest standards-compliant ERC-721s. The code implements the latter assumption.

Root cause: the sponsor-selected contract is the sole authority for every purported proof of prize semantics. It self-reports ERC-165 support at RaffleFactory.sol:L171-L177, runs its own safeTransferFrom at L127-L128, supplies the callback fields accepted at Raffle.sol:L416-L430, and answers the ownerOf postcondition at RaffleFactory.sol:L129-L134. Later, it again controls transferFrom and ownerOf at Raffle.sol:L329-L337. No observation is independent of that same untrusted contract, while NftWon settlement and the sponsor/treasury quote releases do not wait for prize redemption.

Reachable source sequence:

1. Any sponsor selects a code-bearing contract that returns true for the ERC-721 interface query.
2. During createRaffle, that contract invokes the expected receiver callback and reports the clone as owner, causing the clone to become Active and the factory to publish it.
3. Entrants buy tickets with the immutable quote token; Raffle.sol:L223-L235 records the full nominal pot.
4. The sponsor can choose reserveEntries=1, so any sold raffle resolves NftWon after a valid wrapper callback.
5. Permissionless settlement at Raffle.sol:L533-L557 records 95% sponsor proceeds and 5% protocol fees; the releases at L375-L391 can finalize in separate transactions.
6. The prize can then revert forever on winner transfer, or return successfully and lie through ownerOf. In the first case the winner cannot redeem and earlier quote releases remain final; in the second, the ticket burn and local delivery flags can commit without genuine durable ERC-721 delivery.

Secondary ordering consequence, not a second finding: onERC721Received sets Active at Raffle.sol:L428 before the outer sponsor-selected safeTransferFrom returns to RaffleFactory.sol:L128. The token can therefore make a fully funded call into the active clone before the factory performs its L129-L134 postconditions and emits RaffleCreated at L136-L147. This can produce TicketPurchased before RaffleCreated, although it does not produce free entries.

Consequence: arbitrary entrant value can be collected and 95% released to a malicious sponsor-selected recipient even though the protocol cannot enforce that a genuine NFT was escrowed or delivered. There is no NftWon transition to refunds at Raffle.sol:L276-L300. The amount is uncapped by source.

Preconditions: a malicious or mutable prize implementation; a sponsor willing to select it; entrants purchasing tickets; and a valid draw that selects NftWon. The finding does not assert that any deployed prize is malicious and was not dynamically reproduced.

Scoped remediation:

- If prizes are truly untrusted, admit only reviewed immutable collections/code hashes or trusted adapters, with upgrade/admin provenance in an authenticated registry.
- Otherwise change DESIGN.md and user-facing guarantees to state that prize authenticity, custody, and delivery are trusted/user-borne.
- Gate NftWon sponsor and treasury quote releases on successful winner redemption, and define a bounded delivery-failure fallback. This mitigates honest-but-paused/reverting prizes but cannot make a fully malicious token truthful.
- Separate receipt from activation: let the callback record receipt, then have the factory activate only after the outer transfer and custody checks return.
- Preserve atomic rollback and add adversarial prize behavior to S6; do not represent this first pass as dynamic proof.

### FP-SEC-02 — Medium — Unsafe outbound prize transfer can strand the NFT in a contract recipient

Affected source:

- target/packages/contracts/src/Raffle.sol:L235, L320-L337, and L395-L405
- target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L91
- target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135 and L269-L290
- target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48

Stage provenance:

- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md, M-02
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md, contract-winner documentation gap
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, U-10

Documented requirement: DESIGN.md:L2 treats ticket recipients as untrusted and requires redemption to revert all effects on delivery failure. IERC721.sol:L75-L91 expressly warns that transferFrom does not prove contract-recipient capability.

Root cause: both winner delivery and sponsor return use transferFrom and then check only ownerOf. Unlike safeTransferFrom, this invokes no IERC721Receiver acceptance callback. Ticket safe minting establishes acceptance of the raffle ticket contract, not acceptance or operability of an arbitrary prize contract.

Reachable source sequence:

1. A contract receives or owns a raffle ticket through the safe ticket path.
2. As current owner it calls redeemWinningTicket.
3. The raffle sets winnerRedeemed, burns the ticket, and calls the prize's transferFrom.
4. A standards-compliant prize transfers ownership without calling the recipient.
5. The post-transfer ownerOf check succeeds, so redemption commits even if the recipient would reject that prize or exposes no way to operate or recover it.

The same issue applies when sponsorRecipient is a contract and any caller invokes releaseSponsorPrize.

Consequence: a potentially valuable prize can become irrecoverably held by a contract that would have rejected safe delivery. This is a standards-compliant recipient-compatibility failure, distinct from FP-SEC-01's malicious-token behavior.

Preconditions: a standards-compliant prize; a contract-valued winner or sponsor recipient; and a recipient that can own/call as needed but cannot safely accept or later operate that prize. No such concrete recipient was supplied or dynamically exercised.

Scoped remediation: use safeTransferFrom for both outbound prize paths and retain the ownerOf postcondition. The surrounding entry points are already nonReentrant, and receiver rejection will revert the burn and flags atomically. If unsafe delivery is intentional, document it and require contract owners to provide an explicit prize-capable destination.

### FP-SEC-03 — Low — A deliberately selected future-clone address defeats destination invariants

Affected source:

- target/packages/contracts/src/RaffleFactory.sol:L105-L125 and L154-L169
- target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61
- target/packages/contracts/src/Raffle.sol:L181-L205, L375-L405, L560-L566, and L593-L604

Stage provenance:

- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md, S4-SEC-02, Low
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, F-02 / REQ-44 and REQ-47, High

Documented requirements: DESIGN.md:L2 says sponsor and treasury can claim independently and assets must never move between raffle clones.

Root cause: destination checks classify only fixed plumbing and currently deployed registered clones. A code-less future CREATE address passes creation and initialization. The quote path rechecks the stored recipient later, but the prize-return path does not.

Reachable source sequence:

1. A sponsor calculates the address expected for a later ordinary-CREATE clone and uses that currently code-less address as raffle A's sponsorRecipient.
2. The address passes RaffleFactory.sol:L154-L169 and Raffle.sol:L181-L205.
3. A later successful factory creation deploys and registers raffle B at that address.
4. After A settles, releaseSponsorProceeds reaches the current check at Raffle.sol:L564-L566 and reverts because B is now a registered raffle.
5. In CashWon or Refunding, releaseSponsorPrize skips that check and uses unsafe transferFrom at L395-L405, moving A's NFT into B outside B's accounting and without B's receiver callback.

Consequence: the selecting sponsor's quote entitlement can be stranded and A's prize can be placed irrecoverably in another clone. A separately noted treasury-at-future-clone misconfiguration could make creation at one nonce revert repeatedly, but that requires deployment-time misconfiguration and was not established in any deployment.

Preconditions: deliberate address precomputation, control of sponsorRecipient, the expected factory nonce and transaction order, successful later creation at that exact address, and a terminal state permitting the relevant release. Accidental collision is negligible. No deployed nonce or affected address was inspected.

Severity resolution: S5's High view rests on literal cross-clone transfer and loss. The final Low rating follows the deliberate coordination, self-directed entitlement/prize, and unverified deployment reachability. S4's Low minority view is therefore adopted, while S5's consequence analysis is retained.

Scoped remediation: reapply current destination screening before prize return; provide a narrowly scoped, evented recipient-rotation or recovery process for a recipient that later becomes unsafe; have deployment tooling reject predicted clone addresses for treasury and fixed recipients; and document counterfactual factory-clone addresses as invalid destinations.

## Design-code divergence

### FP-DIV-01 — Low — The sponsor can close an empty raffle before the documented deadline

Affected source:

- target/DESIGN.md:L2
- target/packages/contracts/src/interfaces/IRaffle.sol:L322-L324 and L410-L412
- target/packages/contracts/src/Raffle.sol:L275-L300 and L395-L406

Stage provenance:

- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, F-03 / REQ-35
- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md, lifecycle and documentation analysis

Documented requirement: DESIGN.md:L2 says refunds open at the deadline. The public interface separately documents immediate sponsor closure of an empty raffle.

Root cause: in the zero-entry Active branch, the pre-endTime rejection is conditional on msg.sender != sponsor. The sponsor falls through before the deadline.

Reachable source sequence: every activated raffle starts with totalEntries=0; before endTime, the sponsor calls enableRefunds; status becomes Refunding; any caller can then trigger releaseSponsorPrize to the fixed sponsorRecipient.

Consequence: an advertised but empty raffle can be cancelled and its prize returned before its published end. No existing ticket holder loses a refund because the branch requires zero sold entries. This bounded consequence is why the S5 Medium rating is reduced to Low.

Preconditions: Active status, zero entries, sponsor caller, and pre-endTime execution. No dynamic reproduction is claimed.

Scoped remediation: either remove the sponsor bypass so empty raffles close only at endTime, or amend DESIGN.md and product/frontend messaging to make the early-cancellation authority explicit.

## Out-of-scope compliance status

### FP-OOS-01 — Informational — Frontend fresh-state rereads cannot be verified from the contract-only target

Affected material:

- target/DESIGN.md:L2
- target/dependency-hashes.json:L2-L32
- target/packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149
- target/packages/contracts/src/Raffle.sol:L240-L250 and L309-L321

Stage provenance:

- /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md, F-04 / REQ-56

Documented requirement: the frontend must treat discovery as advisory and reread current chain state before transaction decisions.

Root cause/status: the frozen target contains five production Solidity files and a Solidity-only 31-file dependency closure. It supplies current-state getters and transaction-time revalidation, but no frontend consumer or frontend revision.

Assessment sequence: indexed discovery could feed a frontend decision and then a transaction; the middle frontend step is absent from scope. The contracts' own current-state checks reduce stale-state consequences but do not prove pre-decision UI behavior.

Consequence: system-wide compliance with REQ-56 is unverified. This is not evidence that an external frontend violates the requirement, so S5's Low rating is reduced to Informational.

Precondition: a claim that this contract-only target proves frontend compliance.

Scoped remediation: supply the exact production frontend repository and revision for review, verify fresh reads/simulation immediately before submission, or explicitly exclude REQ-56 from this target's compliance claim.

## S5 considered-and-dropped candidates: non-findings

All four S5 drops remain non-findings:

| Requirement | Why it was considered | Why it was dropped |
| --- | --- | --- |
| REQ-06 canonical USDC identity | On-chain construction checks only code and six decimals at RaffleFactory.sol:L65-L78 | DESIGN.md:L2 makes canonical quote-token identity a trusted deployment premise. IRaffleFactory.sol:L6-L9 explicitly assigns official-address verification to deployment tooling; source immutably propagates that choice. Deployment identity remains a lead, not a source divergence. |
| REQ-25 prize returned to depositor | sponsor and sponsorRecipient can differ at RaffleFactory.sol:L109-L128, and return goes to sponsorRecipient at Raffle.sol:L395-L405 | The verbatim design says the prize returns, not that it must return to the escrow-source address. The ABI expressly defines sponsorRecipient as the beneficiary. The undefined sponsor terminology is a documentation fix. |
| REQ-46 claim independence | A later-registered clone recipient can block sponsor release | Independent means separate buckets and order: settlement writes distinct balances and either release clears only its own at Raffle.sol:L375-L391 and L551-L555. The destination failure is retained under REQ-44/REQ-47 in FP-SEC-03, not counted again. |
| REQ-51 canonical wrapper identity | Constructor accepts any code-bearing wrapper | DESIGN.md:L2 treats canonical wrapper identity as a trusted deployment premise. The selected wrapper is immutable, receives every request, authenticates every callback, and has no replacement path. Concrete provenance remains a lead. |

## Documentation and operational fixes that are not additional findings

S5's reverse sweep found 11 consequential behaviors missing from DESIGN.md. They are retained here without inflating the security count:

| Item | Source | Disposition |
| --- | --- | --- |
| U-01 positive reserve and 30-day maximum sale | RaffleFactory.sol:L97-L104,L178-L179; RaffleConstants.sol:L29-L30 | Document creation bounds |
| U-02 depositor may nominate a different permanent beneficiary | RaffleFactory.sol:L97-L120,L154-L179; Raffle.sol:L197-L204,L375-L405 | Define sponsor versus sponsorRecipient |
| U-03 ticket destinations exclude more than clones | Raffle.sol:L491-L502,L587-L604 | Document all prohibited sinks |
| U-04 draw is caller-funded native payment with one word, 300,000 gas, 30 confirmations, and atomic excess refund | Raffle.sol:L43-L50,L170-L173,L240-L272; RaffleConstants.sol:L38-L42 | Keeper/deployment documentation |
| U-05 authenticated unusable callbacks emit and return rather than revert | Raffle.sol:L504-L516; VRFV2PlusWrapperConsumerBase.sol:L99-L107 | Document and add diagnostic reason codes |
| U-06 winning entry is randomWord modulo totalEntries plus one | Raffle.sol:L509-L523 | Specify the mapping |
| U-07 zero-entry early sponsor cancellation | Raffle.sol:L275-L300 | Consolidated as FP-DIV-01 |
| U-08 refund calls are capped at 100 ticket IDs | Raffle.sol:L348-L369; RaffleConstants.sol:L26-L27 | Document batching and gas expectations |
| U-09 quote and prize releases are permissionless pushes to fixed recipients | Raffle.sol:L374-L406 | Document caller-controlled timing |
| U-10 outbound prize delivery skips receiver acceptance | Raffle.sol:L329-L337,L395-L405 | Consolidated as FP-SEC-02 |
| U-11 unrelated NFTs sent by unsafe transferFrom are unrecoverable | Raffle.sol:L409-L425; IERC721.sol:L75-L91 | Document unsupported-asset policy |

Other documentation fixes preserved from S4/S5 are the direct DESIGN.md versus IRaffle prize-trust contradiction, the omitted empty-raffle exception, ambiguous use of sponsor, missing frontend revision, creation event ordering, ignored-callback reason opacity, complete inherited ABI publication, and migration/runoff and deployment-attestation procedures.

## Complete per-property compliance coverage

S5 checked every property in a fresh exact-route context. Final arithmetic is 49 Implemented, 6 Partial, and 1 Absent. Implemented after refutation marks a candidate that was considered and dropped, not a surviving divergence.

| Requirement | Final status | Consolidated cross-reference |
| --- | --- | --- |
| REQ-01 | Implemented | NFT raffle path; FP-SEC-01 qualifies untrusted prize semantics |
| REQ-02 | Implemented | Immutable factory logic |
| REQ-03 | Implemented | ERC-1167 factory clones |
| REQ-04 | Implemented | Fixed clone target |
| REQ-05 | Implemented | 1,000,000 nominal units per entry |
| REQ-06 | Implemented after refutation | Non-finding; deployed token identity lead |
| REQ-07 | Implemented | Six-decimal gate and raw-unit price |
| REQ-08 | Implemented | One ticket per successful purchase |
| REQ-09 | Implemented | ERC-721 ticket semantics |
| REQ-10 | Implemented | Transferable ticket ownership |
| REQ-11 | Implemented | Stored range endpoints |
| REQ-12 | Implemented | Contiguous range |
| REQ-13 | Implemented | Inclusive endpoints |
| REQ-14 | Partial | FP-SEC-01 |
| REQ-15 | Implemented | Scalar ERC-721 prize path; external conformance assumed |
| REQ-16 | Implemented | Deposit before createRaffle returns |
| REQ-17 | Implemented | Transaction atomicity for conforming prize |
| REQ-18 | Implemented | NftWon delivery path; FP-SEC-01 and FP-SEC-02 qualify semantics |
| REQ-19 | Implemented | NFT result sponsor remainder |
| REQ-20 | Implemented | NFT result 5% protocol fee |
| REQ-21 | Implemented | Cash result 80% winner |
| REQ-22 | Implemented | Cash result 15% sponsor on reachable pots |
| REQ-23 | Implemented | Cash result 5% treasury |
| REQ-24 | Implemented | Full per-entry refund |
| REQ-25 | Implemented after refutation | Non-finding; beneficiary terminology fix |
| REQ-26 | Implemented | Aggregate fee calculation |
| REQ-27 | Implemented | Floor rounding |
| REQ-28 | Implemented | Lossless remainder allocation |
| REQ-29 | Implemented | No administrator |
| REQ-30 | Implemented | Configuration fixed at creation |
| REQ-31 | Implemented | No logic-upgrade path |
| REQ-32 | Implemented | Request opens at sale end |
| REQ-33 | Implemented | Exclusive request upper bound |
| REQ-34 | Implemented | Strict callback upper bound |
| REQ-35 | Partial | FP-DIV-01 |
| REQ-36 | Implemented | Valid callback persists result |
| REQ-37 | Implemented | Callback performs no settlement/delivery |
| REQ-38 | Implemented | Permissionless settlement |
| REQ-39 | Implemented | Storage-only settlement |
| REQ-40 | Implemented | Current-owner redemption |
| REQ-41 | Implemented | Successful redemption consumes ticket |
| REQ-42 | Implemented | Same-transaction claim and delivery |
| REQ-43 | Implemented under observable delivery failure | FP-SEC-01 and FP-SEC-02 qualify malicious reports and receiver acceptance |
| REQ-44 | Partial | FP-SEC-03 |
| REQ-45 | Implemented | Complete treasury entitlement |
| REQ-46 | Implemented after refutation | Non-finding; separate buckets/order |
| REQ-47 | Partial | FP-SEC-03 |
| REQ-48 | Partial | FP-SEC-01 |
| REQ-49 | Implemented | One immutable quote-token target |
| REQ-50 | Implemented | Wrapper-only callback authority |
| REQ-51 | Implemented after refutation | Non-finding; deployed wrapper provenance lead |
| REQ-52 | Implemented | No prize allowlist |
| REQ-53 | Partial | FP-SEC-01 |
| REQ-54 | Implemented for ticket-recipient callback containment | FP-SEC-02 qualifies outbound prize acceptance |
| REQ-55 | Implemented | Contract decisions use current state |
| REQ-56 | Absent from supplied artifact | FP-OOS-01 |

## Production-file and dependency-closure coverage

### Five production files

| File | SHA-256 | Direct coverage |
| --- | --- | --- |
| target/packages/contracts/src/Raffle.sol:L1-L614 | 6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617 | Lifecycle, ticket ledger, quote custody/accounting, draw, callbacks, settlement, refunds, releases, prize handling, destination checks |
| target/packages/contracts/src/RaffleFactory.sol:L1-L186 | d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace | Constructor trust anchors, implementation deployment, clone creation/registry, validation, escrow, publication |
| target/packages/contracts/src/interfaces/IRaffle.sol:L1-L521 | a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd | ABI, events, errors, lifecycle, operation contracts, explicit dependency assumptions |
| target/packages/contracts/src/interfaces/IRaffleFactory.sol:L1-L150 | 747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf | Creation ABI, registry, beneficiary semantics, deployment-tooling responsibility |
| target/packages/contracts/src/libraries/RaffleConstants.sol:L1-L43 | 0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6 | Rates, entry price, bounds, timeouts, batch limit, wrapper parameters |

### Explicit 31-file reachable dependency closure

All 31 files were read by the sealed source stages and matched target/dependency-hashes.json:L2-L32. No dependency disappears from coverage.

| # | Dependency and lines | Reachability/disposition |
| ---: | --- | --- |
| 1 | @openzeppelin/contracts/token/ERC721/IERC721.sol:L1-L135 | Prize/ticket interface and safe-versus-unsafe transfer contract |
| 2 | @openzeppelin/contracts/utils/introspection/IERC165.sol:L1-L25 | Prize interface self-report boundary |
| 3 | @openzeppelin/contracts/token/ERC20/IERC20.sol:L1-L79 | External quote-token ABI |
| 4 | @chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L1-L83 | External wrapper pricing/request boundary |
| 5 | @openzeppelin/contracts/utils/math/Math.sol:L1-L763 | Full-precision aggregate allocation |
| 6 | @openzeppelin/contracts/utils/math/SafeCast.sol:L1-L1162 | Transitive math/string casts; timestamp casts do not use it |
| 7 | @openzeppelin/contracts/utils/Panic.sol:L1-L57 | Math panic support |
| 8 | @openzeppelin/contracts/utils/ReentrancyGuard.sol:L1-L119 | Shared guard and clone zero-slot behavior |
| 9 | @openzeppelin/contracts/utils/StorageSlot.sol:L1-L143 | Guard storage backing |
| 10 | @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol:L1-L28 | Prize/ticket receiver ABI |
| 11 | @openzeppelin/contracts/token/ERC721/ERC721.sol:L1-L433 | Ticket ownership, approvals, transfer, mint, burn, safe receiver path |
| 12 | @openzeppelin/contracts/interfaces/draft-IERC6093.sol:L1-L162 | Standard token errors |
| 13 | @openzeppelin/contracts/utils/introspection/ERC165.sol:L1-L25 | Ticket ERC-165 implementation |
| 14 | @openzeppelin/contracts/utils/Strings.sol:L1-L532 | ERC-721 metadata support |
| 15 | @openzeppelin/contracts/utils/Bytes.sol:L1-L332 | Transitive Strings utility |
| 16 | @openzeppelin/contracts/utils/math/SignedMath.sol:L1-L68 | Transitive formatting helper |
| 17 | @openzeppelin/contracts/utils/Context.sol:L1-L28 | ERC-721 sender abstraction |
| 18 | @openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L1-L50 | Safe recipient acceptance and revert bubbling |
| 19 | @openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol:L1-L27 | Ticket metadata interface |
| 20 | @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L1-L280 | Quote transfer call/return handling, not balance-delta proof |
| 21 | @openzeppelin/contracts/interfaces/IERC1363.sol:L1-L86 | Transitive SafeERC20 extension interface; unused by first party |
| 22 | @openzeppelin/contracts/interfaces/IERC165.sol:L1-L6 | Import-forwarding unit |
| 23 | @openzeppelin/contracts/interfaces/IERC20.sol:L1-L6 | Import-forwarding unit |
| 24 | @chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol:L1-L27 | Native-payment extra-argument encoding |
| 25 | @chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L1-L118 | Immutable wrapper, native request helper, authenticated callback gateway |
| 26 | @chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol:L1-L31 | Base-constructor LINK interface; LINK request helper unused |
| 27 | @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol:L1-L26 | Six-decimal constructor query |
| 28 | @openzeppelin/contracts/proxy/Clones.sol:L1-L294 | Fixed ERC-1167 ordinary-CREATE deployment |
| 29 | @openzeppelin/contracts/utils/Errors.sol:L1-L34 | Clone/Create2 errors |
| 30 | @openzeppelin/contracts/utils/Create2.sol:L1-L91 | Transitive alternate clone support; production uses CREATE |
| 31 | @openzeppelin/contracts/utils/LowLevelCall.sol:L1-L127 | Transitive utility; generic delegatecall helpers have no first-party call site |

## Entry-point and function-depth coverage

### S2 recurring surface

S2 found 19 recurring state-changing entry points: 10 Public, 6 Role-Restricted, 0 Review Required, and 3 Contract-Only. The canonical clone contributes 12 direct Raffle entries, 5 inherited ERC-721 entries, and 1 inherited VRF gateway, for 18; RaffleFactory contributes 1.

| Category | IDs and entries |
| --- | --- |
| Public, 10 | EP-01 receive; EP-03 buyEntries; EP-04 requestDraw; EP-05 enableRefunds; EP-06 settleWinningTicket; EP-09 releaseSponsorProceeds; EP-10 releaseProtocolFees; EP-11 releaseSponsorPrize; EP-14 setApprovalForAll; EP-19 createRaffle |
| Role-Restricted, 6 | EP-07 redeemWinningTicket; EP-08 refundTickets; EP-13 approve; EP-15 transferFrom; EP-16 safeTransferFrom without data; EP-17 safeTransferFrom with data |
| Contract-Only, 3 | EP-02 initialize; EP-12 onERC721Received; EP-18 rawFulfillRandomWords |

Constructors are reported separately and are not included in 19: D-01 RaffleFactory, D-02 Raffle, D-03 inherited ERC721, D-04 inherited ReentrancyGuard, and D-05 inherited VRFV2PlusWrapperConsumerBase. ERC-1167 clones execute no Solidity constructor.

### S2 per-entry depth gaps

Every entry was complete locally. The remaining gaps are external boundaries, not untraced local branches.

| ID | Remaining depth/property gap |
| --- | --- |
| EP-01 | None; always reverts |
| EP-02 | Concrete deployment provenance for immutable factory absent |
| EP-03 | Concrete quote transfer behavior and ticket-recipient callback absent |
| EP-04 | Wrapper price/request behavior and native-refund recipient fallback absent |
| EP-05 | No external-code gap; timestamp is environmental |
| EP-06 | None in supplied source |
| EP-07 | Concrete prize or quote delivery behavior absent by branch |
| EP-08 | Concrete quote transfer behavior absent |
| EP-09 | Concrete quote transfer behavior absent |
| EP-10 | Concrete quote transfer behavior absent |
| EP-11 | Concrete prize transfer and ownership reporting absent |
| EP-12 | Prize transfer ordering and callback-field provenance absent |
| EP-13 | None in supplied ERC-721 |
| EP-14 | None in supplied ERC-721 |
| EP-15 | Same-factory registry path traced; no additional local gap |
| EP-16 | Destination contract receiver implementation absent |
| EP-17 | Destination contract receiver implementation absent |
| EP-18 | Wrapper identity, scheduling, request binding, randomness, and retries absent |
| EP-19 | Sponsor-selected prize behavior and deployed dependency identities absent |

### S1 native function-candidate cut

S1's native workflow gave standalone records to 12 of 24 ranked candidates. The 12-record set covered RaffleFactory.createRaffle; Raffle.requestDraw; Raffle.buyEntries; Raffle.fulfillRandomWords; Raffle.redeemWinningTicket; Raffle.enableRefunds; Raffle.refundTickets; Raffle.onERC721Received; Raffle.initialize; VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords; Raffle._settleWinningTicket; and Raffle._update.

The 12 candidates below the standalone-record cut were, in the dossier's rank order:

13. Raffle.releaseSponsorPrize
14. RaffleFactory._validateCreateParams
15. Raffle._isProtocolDestination
16. Raffle._transferQuote
17. ERC721.transferFrom
18. ERC721.safeTransferFrom(address,address,uint256,bytes)
19. Raffle._requireWinningTicket
20. Raffle.releaseSponsorProceeds
21. Raffle.releaseProtocolFees
22. RaffleFactory.constructor
23. Raffle.constructor
24. ReentrancyGuard.nonReentrant path

Below-cut means no separate S1 micro-analysis, not unread source: these functions were encountered through complete production-file reading or followed as callees. S2-S5 later covered them in their respective scopes.

## Assumptions and unresolved leads reserved for S6

These are leads, not additional findings. There are eight consolidated leads.

| Lead | Status and exact question for later work |
| --- | --- |
| L-01 concrete malicious prize behavior | Corroborate FP-SEC-01 with controlled prize contracts that lie about ERC-165, callback fields, ownerOf, custody, and delivery; exercise reverting and false-success paths. Source establishes reachability but no concrete deployment was tested. |
| L-02 standard ERC-721 contract-recipient delivery | Exercise a standards-compliant prize and contract ticket owner that accepts the ticket but rejects or cannot operate the prize; confirm safeTransferFrom remediation and rollback for FP-SEC-02. |
| L-03 nominal versus balance-delta quote accounting | Under the documented trusted canonical-USDC assumption, determine whether hard balance-delta enforcement is desired. Raffle.sol:L223-L235 credits grossAmount without balance reads, while SafeERC20.sol:L176-L244 checks call/return behavior only. Fee, rebase, no-op, pause, and blocklist mocks are assumption tests, not proof that canonical USDC violates the premise. |
| L-04 callback/request ordering | Inspect the concrete wrapper for two price observations, synchronous callback policy, returned-ID uniqueness/binding, retry behavior, and the fact that Raffle.sol:L252-L260 records the ID only after the external request while ignoring in-flight callbacks at L509-L515. |
| L-05 future-clone destination reachability | Determine actual factory nonce/order and whether any stored recipient or treasury equals a future clone address. FP-SEC-03 is source-reachable, but no live address or transaction ordering was checked. |
| L-06 timestamp-width edge | Raffle.sol:L253 and L520 narrow block.timestamp to uint64 without SafeCast; establish target-chain lifetime assumptions. This is a far-horizon representation lead, not a present demonstrated exploit. |
| L-07 deployed address and provenance | Obtain chain ID, factory/implementation addresses, constructor arguments, quote-token and wrapper proxy/implementation/admin provenance, treasury, bytecode hashes, deployment transactions, and upgrade controls. Provider identity remains unknown. |
| L-08 frontend revision | Supply the exact production frontend/indexer/keeper revision and verify fresh state reads, simulations, reorg handling, canonical-factory discovery, prize-risk display, and transaction construction for FP-OOS-01. |

The principal documented assumptions are: exact fee-free non-rebasing canonical USDC behavior at IRaffle.sol:L12-L15 and Raffle.sol:L560-L566; canonical wrapper identity plus correct pricing/request-ID/randomness/retry semantics; and standards-compliant prize behavior in IRaffle.sol, which conflicts with DESIGN.md's untrusted-prize requirement and is therefore elevated to FP-SEC-01 rather than left merely as an assumption.

## Source-only completeness and freeze statement

- No tests were read or run.
- No security scanner, Slither output, printer output, visual analyzer output, or historical finding was read or run.
- No other cell, root campaign output, attempt-02 content, accepted-risk list, historical audit, peer finding, or cross-cell reconciliation was read.
- No RPC query, live transaction, deployed-state query, scarcity analysis, balance query, or dynamic reproduction was performed.
- No target, production source, configuration, lockfile, freeze record, or sealed source artifact was modified.
- S4's isolated compiler-only build is the sole execution in S1-S5 and did not expose tests or scanner results.
- S5 reports no unchecked, failed, unreadable, or unverified property and a clean post-S5 freeze.
- S6 is intentionally pending behind this report. Any later test/scanner evidence must be reconciled against this immutable source-only baseline rather than silently changing it.

