# DAYBREAK-TOB final six-stage synthesis report

## Audit identity and disposition

| Item | Value |
|---|---|
| Audit lineage | `DAYBREAK-TOB`, attempt `03` |
| Frozen target commit | `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` |
| Runtime target | `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target` |
| Scope | Five production Solidity files, 31 reachable Solidity dependencies, and clean `DESIGN.md` |
| Pinned Trail of Bits method | Commit `82fe8226252622fa807643bdca1710901198553a` |
| Exact route tuple | `model=gpt-daybreak-blue-latest; cyber access program=daybreak_blue; reasoning effort=ultra; multi-agent=disabled; fallback=disabled` |
| Provider-returned identity | **Unknown.** The JSON evidence supplies no provider-returned model identity. The requested model selector above is route evidence, not a provider identity claim. |
| Cross-cell reconciliation | None |
| Campaign attempt 02 | Preserved, untouched, and not used |
| Production remediation | Not authorized and not performed |
| Live transactions, publishing, or purchases | None |
| Overall disposition | **Launch-blocking:** one unresolved Critical custody/trust-boundary defect permits buyer-funded proceeds to be released without a genuine prize. |

This synthesis used only the authorized same-cell evidence. It did not inspect another audit cell, campaign attempt 02, historical tests or audits, accepted-risk material, or reconciliation output. No new scanner or test campaign was run during synthesis.

## Executive risk summary

The canonical register contains seven consolidated dispositions:

| Class | Critical | High | Medium | Low | Informational/conditional | Total |
|---|---:|---:|---:|---:|---:|---:|
| Security/integration findings | 1 | 0 | 1 | 2 | 1 | 5 |
| Specification/documentation divergence | 0 | 0 | 0 | 1 | 0 | 1 |
| Out-of-scope/unverifiable compliance status | 0 | 0 | 0 | 0 | 1 | 1 |
| **Total** | **1** | **0** | **1** | **3** | **2** | **7** |

The four non-conditional code-security findings are:

1. An untrusted prize contract can fake both escrow and delivery while real quote-token proceeds are released.
2. Prize delivery bypasses contract-recipient acceptance.
3. Clone-destination isolation is incomplete across future and separate-factory clones.
4. Sponsor-selected prize code can purchase entries before canonical creation publication.

No source-first finding was dynamically refuted. S6 confirmed the two principal asset-handling findings and the pre-publication ordering behavior, demonstrated the conditional quote-token accounting assumption, and added a new cross-factory clone variant to the destination-isolation finding.

## Six-stage execution ledger

`R` below means the exact route tuple stated above, with provider-returned identity `unknown`.

| Stage | Exact native skill | Status and core inputs | Completion evidence | Report/dossier SHA-256 | Seal SHA-256 | Route | Adaptations and local incidents |
|---|---|---|---|---|---|---|---|
| S1 | `audit-context-building` | **Inherited, not rerun.** Validated byte-for-byte from the same-cell native execution. Inputs were the frozen production/dependency closure and design context. | [Dossier](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md); complete orientation; 12 native function records; 31 common files byte-identical. | `854e2abd2863adb63f553f1fd4ac1a5e3b81acae38d9bbb2d1733c8a0fb7e0af` | `e6957a73277fbea4b5d2c308024eb07eafa89454ced6daf40df4f10fec18c803` | R | The original outer controller exited `-15` only after the dossier existed. The original evidence was not rewritten. |
| S2 | `entry-point-analyzer` | Fresh same-cell source analysis using the frozen source closure and S1 context. | [Report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/REPORT.md); 19 recurring state-changing entry points and five deployment-time entries. | `e63757982fbe049fa6ac482a7c205c00160dd84003b78b727adac0f90391cfd0` | `de24917fb06493ea261bd9a471ddcb72b20fedfcc8e1a035d12883d7f153f516` | R | A first local wait-loop execution was preserved; a fresh local retry completed. Its internal `attempt-02` label is not campaign attempt 02. |
| S3 | `token-integration-analyzer` | Fresh review of ticket ERC-721, quote ERC-20, arbitrary prize ERC-721, wrapper integration, five production files, 31 dependencies, and all 24 weird-token patterns. | [Report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md) and sealed initial run. | `1f9e2cd0cc1e994b3f95771fede686bffb0fe8e027c98a70da06bac194d4189e` | `a5b53b1251469984c3ec9de9bbc3ce79cbd8eadd70b5eb3308077a756dfbac91` | R | No material local failure. No deployed token or wrapper identity was inferred. |
| S4 | `guidelines-advisor` | Fresh five-phase, eleven-area source review of all production and dependency files. | [Report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md); isolated compiler-only Forge build of 36 Solidity files succeeded. | `19b82b8743d9971337152299561b1b28e2d9426472fcb6f67494f07ff927d227` | `c154879ec5a56d565b5477470bd67491d18490da5524d296dfdb61f89d7f274c` | R | Build outputs and cache were redirected outside the target. This was not a test or scanner campaign. |
| S5 | `spec-to-code-compliance` | Fresh `DESIGN.md` extraction/alignment against the complete frozen source closure. | [Report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md); 56 requirements, 56 records, 56 analyses, 22 refutations. | `e2cdee01bc21252af38f022c23588b07bdfe1b2712cca64208872166afc74e72` | `750757807b9ae46806c0790ea937a691c353c22159ef8157da463f99223a0da7` | R | Controller processed all 56 properties instead of the workflow default cap of 30 while preserving Extract → Align → Verify → Report, reverse sweep, schemas, and two refuters per candidate. Schema, `xargs`, path-transcription, and report-context failures occurred before or around analysis and were repaired without changing the jobs or target. |
| S6 | `secure-workflow-guide` | Fresh isolated scanner, visualization, manual-review, Foundry, and Echidna work derived from the frozen source, `DESIGN.md`, and permitted S1 dossier. | [Report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/REPORT.md); 14-result Slither triage, ERC-721 check, three printers, 41-property matrix, Foundry and Echidna campaigns. | `3a4bc298016c621b17945828a2dacf3bf87c72079720aaca54fa31d0c3549d4e` | `fd043fd27bb990280b3b4079baba2f9f28f5a6cb0ca384205f668f5d99bfd496` | R | Explicit tool paths, Dockerized Echidna/Graphviz, table-to-DOT transcription, and test-harness-only repairs were required. All attempts were preserved; no production repair was made. |

The six pinned skill files have these SHA-256 values:

| Skill | SHA-256 |
|---|---|
| `audit-context-building` | `33fa693dc6e166cfa4919e4373cb6578c009d296234c2ae7cb3cd4e79b443765` |
| `entry-point-analyzer` | `0d0e2956bdf9bf5be7efdfcefc754cabd2c1deb015731f3341f919eae2a0e3ca` |
| `token-integration-analyzer` | `4b7f5cb3c52f9b45e2216963a49458e1f23f5a279a0296e702fd9d8df268b301` |
| `guidelines-advisor` | `5bb8ba34d363c419e1769a59d0fcc7444a04dc6d9e59032cb93019befdc2e464` |
| `spec-to-code-compliance` | `eb0d91b50a9c06f50baf8763d1e23566897b9fa3e7ffcf13134eee4e1ccaefe5` |
| `secure-workflow-guide` | `7c0e7fb45f97c073ec9599cbe0b2acf44f31bbece38636bc5c3fcc9bc7703015` |

This is exactly the authorized six-skill aggregate, not a claim of completing the full Trail of Bits catalog.

## Source-first-pass exposure chronology

The separation between source judgment and dynamic evidence is intact:

1. S1–S5 were source-only, except for S4’s compiler-only isolated build.
2. S5 sealed at `2026-10-21T22:41:15Z`.
3. The unmodified source-only [FIRST-PASS.md](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/FIRST-PASS.md) sealed at `2026-10-21T22:52:38Z`.
4. Its SHA-256 is `981bea8dd6fe0e96328c38cf8375f93bc8bdf272476b4defcbeca71fdfdd9bc6`.
5. Its root [SEAL.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/SEAL.json) SHA-256 is `c7d730eb6687f33fbc6e10bc43671ad1975813a03e05d37cbb2d85b6ca2ba82b`.
6. The timestamp-file hash is `1bfda53a00a24ccb4cc22846ce04528841bb1fd59b82fc926ce1673d38298f6f`; the detached-hash-file hash is `98c8e9b8ec39f610fad3e04d27b829bd69ff222b722146506f73d15d7e3e4db9`.
7. S6 began at `2026-10-21T22:54:27Z`, 109 seconds after the first-pass seal, and sealed at `2026-10-21T23:31:49Z`.
8. S6’s seal embeds and revalidates the same first-pass report and seal hashes.

Accordingly, S6 evidence confirms, narrows, or adds to the source-first conclusions; it did not inform or retroactively alter them.

### Finding lineage across the boundary

| Final disposition | Source-first status | S6 status |
|---|---|---|
| `DAYBREAK-F-01` | `FP-SEC-01`, Critical; consolidated S3 H-01, S4 S4-SEC-01, and S5 F-01 | Dynamically confirmed by S6-01; S6 assigned High |
| `DAYBREAK-F-02` | `FP-SEC-02`, Medium | Dynamically confirmed by S6-02 |
| `DAYBREAK-F-03` | `FP-SEC-03`, Low, future same-factory clone | Same-factory future-address variant not reproduced; S6 newly found and reproduced the related cross-factory variant, S6-03 |
| `DAYBREAK-F-04` | S3 L-01 and the first pass’s secondary ordering consequence under FP-SEC-01 | Dynamically confirmed and separated as S6-04 |
| `DAYBREAK-F-05` | S3 M-01 and first-pass lead L-03; not a finding under canonical-USDC premise | Conditional counterexample confirmed as S6-05 |
| `DAYBREAK-DIV-01` | `FP-DIV-01`, Low | S6 confirmed the code’s intended sponsor authorization model; it did not resolve the conflict with `DESIGN.md` |
| `DAYBREAK-OOS-01` | `FP-OOS-01`, Informational | Remains unverifiable; no frontend artifact entered scope |

## Canonical final findings register

### DAYBREAK-F-01 — Critical — An untrusted prize can fake escrow and delivery while buyer-funded proceeds are released

**Confidence:** High.

**Affected code and functions:**

- [`RaffleFactory.createRaffle`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol:97), including prize transfer/postconditions at lines 127–147.
- [`RaffleFactory._validateCreateParams`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol:154).
- [`Raffle.onERC721Received`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:416).
- Prize delivery, settlement, and releases in [`Raffle.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:304).
- Conflicting trust statement in [`IRaffle.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/interfaces/IRaffle.sol:12).

**Lineage:** S3 H-01 and L-01; S4 S4-SEC-01; S5 F-01 covering REQ-14, REQ-48, and REQ-53; source-first `FP-SEC-01`; S6-01.

**Dynamic status:** Confirmed. `test_Evidence_MaliciousPrizeCanFakeEscrowAndDelivery` completed creation, purchase, draw, settlement, sponsor and treasury release, and purported delivery. The buyer became the prize’s reported owner while the mock’s separate actual owner remained the malicious sponsor. The desired negative property failed intentionally.

**Exploit and preconditions:** A malicious sponsor selects a contract that reports ERC-721 support, invokes the expected receiver callback without transferring a genuine asset, and lies through `ownerOf`. Entrants then pay real quote tokens. With a trivially met reserve, the raffle reaches `NftWon`; 95% can be released to the sponsor recipient and 5% to treasury before trustworthy prize delivery exists. The token may later revert forever or fabricate successful delivery.

**Impact:** Direct, source-uncapped buyer loss and fraudulent raffle publication. There is no `NftWon` transition to refunds after proceeds have been released.

**Severity adjudication:** S3, S4, and S6 rated the issue High; S5 and the sealed source-first synthesis rated it Critical. The final rating is **Critical** because S6 confirmed the complete buyer-loss and proceeds-release sequence, while source imposes no pot cap. The malicious-sponsor and entrant-participation preconditions are retained rather than hidden.

**Remediation direction:**

- Enforce a deployment-specific allowlist or attested immutable collection registry, including upgrade/admin provenance.
- Alternatively custody prizes through a trusted adapter or vault whose ledger is authoritative independently of arbitrary collection self-reports.
- Do not represent arbitrary prize contracts as trustlessly verified.
- Gate sponsor/treasury release on successful delivery or a bounded delivery-failure resolution, while recognizing that this mitigates loss but does not make a malicious token truthful.
- Separate receipt from activation so the factory activates only after the external transfer and custody checks return.

Evidence: [source-first finding](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/FIRST-PASS.md), [S6 detailed finding](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/FINDINGS.md).

### DAYBREAK-F-02 — Medium — Prize delivery skips contract-recipient acceptance

**Confidence:** High.

**Affected code and functions:**

- [`redeemWinningTicket`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:304), especially lines 320–337.
- [`releaseSponsorPrize`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:395).
- ERC-721 safe/unsafe semantics in [`IERC721.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:42).

**Lineage:** S3 M-02; S4 contract-winner documentation gap; S5 U-10; source-first `FP-SEC-02`; S6-02.

**Dynamic status:** Confirmed. A contract accepted the safely minted raffle ticket but was intentionally incompatible with the prize. Redemption burned the ticket and transferred the prize without any prize receiver callback.

**Exploit and preconditions:** A contract-valued ticket owner or sponsor recipient can own the relevant claim but cannot accept or operate the prize NFT. Both outbound paths use `transferFrom`, so receiver rejection is never consulted.

**Impact:** A valuable NFT can become irrecoverably held by an incompatible contract even though the transaction reports successful delivery.

**Remediation direction:** Use `safeTransferFrom(address(this), recipient, prizeTokenId)` for winner delivery and sponsor return. Retain checks-effects-interactions and `nonReentrant` so callback rejection restores the ticket, flags, and custody atomically.

### DAYBREAK-F-03 — Low — Clone-destination isolation is incomplete

**Confidence:** High for the source paths; deployed incidence unknown.

**Affected code and functions:**

- [`RaffleFactory.createRaffle` and `_validateCreateParams`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol:97).
- [`Raffle.initialize`, `_update`, `_transferQuote`, `_isProtocolDestination`, and `releaseSponsorPrize`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:176).
- Ordinary CREATE clone deployment in [`Clones.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:47).

**Lineage:** S4 S4-SEC-02; S5 F-02/REQ-44/REQ-47; source-first `FP-SEC-03`; S6-03.

Two related variants are consolidated:

1. **Future same-factory clone:** a predicted, currently code-less clone address passes initial validation. After deployment and registration, quote release rechecks and becomes blocked, while prize return does not recheck and can move the NFT into the later clone.
2. **Other-factory clone:** `_isProtocolDestination` consults only the local factory registry, so a clone from another factory can receive tickets or other relationships.

**Dynamic status:** The cross-factory variant was reproduced by `test_Evidence_CrossFactoryRaffleDestinationIsAcceptedAndStrandsTicket`, and its desired negative property failed intentionally. The future same-factory variant remains source-established but was not dynamically reproduced; actual factory nonce, recipient state, and transaction ordering remain external leads. S6’s `DST-01` pass covered already registered local sinks and does not refute the future-address path.

**Impact:** Assets or claims can be stranded in a raffle clone outside its accounting. In the future-address variant, the selecting sponsor’s proceeds can become unclaimable while an NFT can be transferred between clones. A configured treasury equal to a future clone address could also make creation at the relevant nonce repeatedly revert.

**Severity adjudication:** S4 and the source-first synthesis rated the future-address issue Low; S5 rated it High; S6 rated the related cross-factory issue Low. The final rating is **Low** because exploitation generally requires deliberate recipient selection, nonce/order coordination or cross-deployment targeting, and no affected deployment was established. The literal invariant violation and potential asset loss are nevertheless retained.

**Remediation direction:**

- Use a shared canonical deployment registry if the no-clone-destination invariant is global.
- Recheck the current destination before prize return as well as quote transfer.
- Reject reserved or predicted factory clone addresses in deployment tooling.
- Provide a narrowly scoped, evented recovery or recipient-rotation mechanism for a destination that later becomes unsafe.
- If isolation is intentionally factory-local, narrow the design and API claim accordingly.

### DAYBREAK-F-04 — Low — Prize callback can create ticket state before canonical publication

**Confidence:** High.

**Affected code and functions:**

- Registry, external prize call, and event ordering in [`RaffleFactory.createRaffle`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol:123).
- Activation in [`Raffle.onERC721Received`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:416).
- [`Raffle.buyEntries`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:209).

**Lineage:** S3 L-01; S4 two-phase-activation recommendation; noted but folded into FP-SEC-01 in the source-first report; separated and reproduced as S6-04.

**Dynamic status:** Confirmed. `test_Evidence_PrizeCanBuyEntriesBeforeCreateRaffleReturns` created a paid entry and ticket from within the sponsor-selected prize transfer, before `RaffleCreated`.

**Exploit and preconditions:** The prize callback changes the clone to `Active` before the outer factory call completes. The factory’s reentrancy guard does not protect the clone’s separate guard slot, so the prize contract can call `buyEntries` during creation.

**Impact:** Sponsor-controlled code can preallocate paid tickets and shape apparent participation or reserve progress before canonical creation publication. The entry remains paid and visible once the transaction lands, limiting severity.

**Remediation direction:** Keep the clone in `AwaitingPrize` during the callback. Let only the factory perform a separate final activation after custody checks, with explicitly documented event ordering.

### DAYBREAK-F-05 — Informational/conditional — Nominal quote accounting depends on official fee-free token behavior

**Confidence:** High for the conditional behavior; applicability to deployment is unverified.

**Affected code and functions:**

- Quote-token constructor validation in [`RaffleFactory.constructor`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol:58).
- Nominal purchase accounting in [`Raffle.buyEntries`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:209).
- Payout helper in [`Raffle._transferQuote`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:560).

**Lineage:** S3 M-01; S5’s dropped REQ-06 candidate; source-first lead L-03; S6-05.

**Dynamic status:** A fee-on-transfer mock confirmed the assumption boundary: buying ten entries recorded 10,000,000 units while custody increased by 9,900,000. This is not evidence that official USDC behaves that way.

**Impact:** A fee-on-transfer, rebasing, no-op, or malicious six-decimal token can make recorded liabilities exceed custody.

**Severity adjudication:** S3 rated the issue Medium conditionally. S5 correctly rejected a requirement for on-chain canonical-address attestation because `DESIGN.md` treats the token as a trusted deployment dependency. S6 classified it Informational/conditional. The final result adopts **Informational/conditional**: the code path is demonstrated, but deployment data identifying the actual quote token is absent.

**Remediation direction:** Pin chain ID, official token address, runtime code, proxy implementation/admin, and expected transfer behavior in deployment automation and post-deployment assertions. If arbitrary quote tokens are supported later, account from observed balance deltas and separately address rebasing and callbacks.

## Specification and documentation divergences

### DAYBREAK-DIV-01 — Low — Sponsor-only early closure of an empty raffle is absent from `DESIGN.md`

**Confidence:** High.

[`Raffle.enableRefunds`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol:275) lets the sponsor move an `Active`, zero-entry raffle into `Refunding` before `endTime`; [`IRaffle.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/interfaces/IRaffle.sol:322) documents that behavior. `DESIGN.md` only says refunds open at the deadline.

S5 rated this Medium under REQ-35. The source-first report reduced it to Low, and the final judgment retains **Low as a design-code divergence**, not a hidden access-control vulnerability: the branch requires zero sold entries, so no ticket holder loses a refund. S6’s AUTH-05 pass confirms that the code follows its interface-level sponsor authorization; it does not reconcile the design prose.

Remediation is to remove the early bypass or explicitly disclose sponsor cancellation and early prize return in the design, frontend, and product terms.

### DAYBREAK-OOS-01 — Informational — Frontend current-state rereads are unverifiable

`DESIGN.md` requires discovery data to remain advisory and the frontend to reread current chain state before transaction decisions. The frozen audit target contains no frontend revision. Contract getters and transaction-time checks reduce stale-state consequences but cannot prove frontend pre-decision behavior.

This is not evidence that a deployed frontend violates the requirement. Supply the exact frontend/indexer/keeper repository and revision for review, or explicitly exclude this requirement from the contract target’s compliance claim.

### Other documentation gaps

S5’s 11 reverse-sweep behaviors remain documented without inflating the finding count:

| ID | Omitted behavior |
|---|---|
| U-01 | Positive reserve and 30-day maximum sale duration |
| U-02 | Depositor and immutable `sponsorRecipient` may differ |
| U-03 | Ticket destinations exclude several protocol addresses, not only clones |
| U-04 | Draw requests are caller-funded native-token operations with one word, 300,000 callback gas, 30 confirmations, and an atomic excess refund |
| U-05 | Authenticated but unusable callbacks emit and return rather than reverting |
| U-06 | Winning entry is `(randomWord % totalEntries) + 1` |
| U-07 | Zero-entry sponsor cancellation before deadline |
| U-08 | Refund calls accept at most 100 ticket IDs |
| U-09 | Releases are permissionless pushes to fixed recipients |
| U-10 | Outbound prize delivery skips receiver acceptance |
| U-11 | Unsolicited NFTs sent with unsafe `transferFrom` can be stranded without rescue |

Additional documentation defects are the direct `DESIGN.md`/`IRaffle.sol` prize-trust contradiction, ambiguous use of “sponsor,” absence of a named frontend revision, creation-event ordering, ignored-callback reason opacity, and missing deployment-attestation and migration/runoff procedures.

### S5 candidates correctly dropped after refutation

- REQ-06: canonical USDC identity is a deployment premise, not an on-chain identity-attestation requirement.
- REQ-25: the design says the prize returns but does not require return to the depositor rather than `sponsorRecipient`.
- REQ-46: claim independence concerns separate buckets and ordering; the destination issue remains under REQ-44/REQ-47.
- REQ-51: canonical wrapper identity is a deployment premise; the configured address is immutable and uniquely authenticates callbacks.

## S5 method accounting

S5 completed:

- 56 extracted requirements.
- 56 records.
- 56 full analyses.
- 45 initially implemented.
- 11 initially nonimplemented candidates.
- 22 independent refutations.
- 7 surviving requirement-level divergences.
- 4 dropped candidates.
- 11 undocumented consequential behaviors.
- 0 unchecked, failed, unreadable, or unverified properties.

After refutation, the final property arithmetic was 49 Implemented, 6 Partial, and 1 Absent:

- Partial: REQ-14, REQ-35, REQ-44, REQ-47, REQ-48, REQ-53.
- Absent from the supplied artifact: REQ-56.
- Implemented after refutation: REQ-06, REQ-25, REQ-46, REQ-51.

The complete evidence is in [requirements.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/requirements.json), [records-index.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/records-index.json), [refutations-index.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/refutations-index.json), and [undocumented.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/undocumented.json).

## Function-analysis depth

### S1 native records

S1 contains all 12 native standalone function records:

1. `RaffleFactory.createRaffle`
2. `Raffle.requestDraw`
3. `Raffle.buyEntries`
4. `Raffle.fulfillRandomWords`
5. `Raffle.redeemWinningTicket`
6. `Raffle.enableRefunds`
7. `Raffle.refundTickets`
8. `Raffle._settleWinningTicket`
9. `Raffle.onERC721Received`
10. `Raffle.initialize`
11. `Raffle._update`
12. `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords`

The remaining ranked candidates were encountered during complete file/callee review but did not receive separate S1 micro-analysis records:

`releaseSponsorPrize`, `_validateCreateParams`, `_isProtocolDestination`, `_transferQuote`, `ERC721.transferFrom`, four-argument `safeTransferFrom`, `_requireWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `RaffleFactory.constructor`, `Raffle.constructor`, and the `nonReentrant` path.

That native record cut must not be described as exhaustive formal function proof.

### S2 entry-point depth gaps

S2 found 19 recurring state-changing entries: 10 public, six role-restricted, and three contract-only. Local branches were traced, but these external or environmental gaps remained:

| Entry | Remaining gap |
|---|---|
| `receive` | None; always reverts |
| `initialize` | Concrete deployment provenance for the immutable factory |
| `buyEntries` | Actual quote-token and recipient callback behavior |
| `requestDraw` | Wrapper pricing/request behavior and native-refund recipient fallback |
| `enableRefunds` | Environmental timestamp behavior |
| `settleWinningTicket` | No supplied-source gap |
| `redeemWinningTicket` | Concrete prize or quote delivery behavior |
| `refundTickets` | Concrete quote transfer behavior |
| `releaseSponsorProceeds` | Concrete quote transfer behavior |
| `releaseProtocolFees` | Concrete quote transfer behavior |
| `releaseSponsorPrize` | Concrete prize transfer and ownership reporting |
| `onERC721Received` | Prize transfer ordering and callback-field provenance |
| `approve` | No supplied-source gap |
| `setApprovalForAll` | No supplied-source gap |
| `transferFrom` | Same-factory registry traced; external destination context remains |
| Three-argument `safeTransferFrom` | Destination receiver implementation |
| Four-argument `safeTransferFrom` | Destination receiver implementation |
| `rawFulfillRandomWords` | Wrapper identity, scheduling, binding, randomness, and retry behavior |
| `createRaffle` | Sponsor-selected prize behavior and deployed dependency identities |

## S6 tools, tests, and local repairs

### Toolchain

| Tool | Version/result |
|---|---|
| Slither / `slither-check-erc` | 0.11.6 |
| Forge | 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Solidity | 0.8.36 |
| Echidna | 2.3.3 |
| Graphviz | 2.43.0 in a disposable Debian container |
| Docker | Client/server 29.8.2 |
| Echidna image | Digest `sha256:80f90c3a727986fc31380a509a87fe0a14cdbda13f4ead102b2d7ffaff285261` |

### Slither and all 14 results

Slither compiled 36 contracts, ran 102 detectors, emitted 14 results, and exited 255 because detector results existed. The structured rerun also exited 255 with valid JSON. No High- or Medium-impact detector result was emitted.

| # | Detector | Tool rating | Final triage |
|---:|---|---|---|
| 1 | Missing local events for initializer arithmetic/configuration writes | Low/Medium | Informational/contextual false positive; atomic factory creation and later events publish the values |
| 2 | External call in refund loop via `raffleImplementation()` | Low/Medium | False positive; burn has `to == address(0)`, short-circuiting `_isProtocolDestination` |
| 3 | External call in refund loop via `isRaffle()` | Low/Medium | False positive for the same short-circuit reason |
| 4 | Wrapper call before request-ID writes | Low/Medium | Conditional/mitigated; guarded and `_requestInFlight` blocks synchronous resolution; wrapper remains trusted |
| 5 | Clone initialization before registry writes | Low/Medium | False positive for the reported call; the distinct later prize interaction produced DAYBREAK-F-04 |
| 6 | Timestamp use in `enableRefunds` | Low/Medium | Required lifecycle behavior; boundaries tested |
| 7 | Timestamp use in `createRaffle` | Low/Medium | Required future-end and 30-day-bound enforcement |
| 8 | Timestamp use in callback filter | Low/Medium | Required exclusive callback deadline |
| 9 | Timestamp use in purchase cutoff | Low/Medium | Required exclusive sale end |
| 10 | Timestamp use in `callbackDeadline` | Low/Medium | False positive; `drawRequestedAt != 0` is a presence check |
| 11 | Timestamp use in draw window | Low/Medium | Required `[endTime,endTime+2 days)` behavior |
| 12 | Assembly native refund | Informational/High | Reviewed zero-calldata value refund under `nonReentrant`; failure atomically reverts |
| 13 | Compatible pragma constraints | Informational/High | Informational; complete graph compiled under 0.8.36 |
| 14 | `ENTRY_PRICE` naming convention | Informational/High | Intentional false positive for an all-caps constant getter |

These warnings were not converted into false vulnerabilities. The material findings came from manual trust-boundary analysis and adversarial properties.

### ERC-721, proxies, `slither-prop`, and visualization

- `slither-check-erc . Raffle --erc ERC721` exited 0. It found the required transfer, approval, ownership, metadata, interface, and event surfaces. Runtime clone testing supplemented the implementation-level check.
- Proxy/upgrade searches found fixed-target ERC-1167 clones only. There is no UUPS, transparent, beacon, diamond, ERC-1967 admin slot, mutable implementation pointer, upgrader, or upgrade entry point. An upgradeability checker was therefore inapplicable.
- `slither-prop . --contract Raffle` exited 0 but reported `Foundry not yet supported by slither-prop`. It was also semantically inapplicable because `Raffle` consumes ERC-20 but is not an ERC-20 implementation. No generated property was assumed.
- All three required printers succeeded:

| View | DOT | PNG | PDF |
|---|---|---|---|
| Inheritance | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.dot) | [PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.pdf) |
| Function summary | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.dot) | [PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.pdf) |
| Variables/auth | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.dot) | [PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.pdf) |

The function-summary and vars-and-auth printers emit tables rather than DOT, so their preserved raw tables were transcribed into supplemental DOT views.

### Foundry, Echidna, and coverage

| Campaign | Final result |
|---|---|
| Unit/fuzz | 21 passed, 0 failed, 0 skipped; two fuzz properties at 10,000 cases each; deterministic seed `0x53365f46494e414c5f46555a5a5f53454544` |
| Invariants | Three passed; 256 runs × depth 128 each; 32,768 calls/property, 98,304 total; 0 reverts, 0 discards; seed `0x53365f46494e414c5f494e56415249414e54` |
| Intentional negative properties | Two failed as expected; command exit 1; seed `0x53365f4b4e4f574e5f56494f4c4154494f4e` |
| Echidna | Four properties passed; 20,007 calls; sequence length 64; seed `1396142931`; 8,879 unique instructions; eight code hashes; corpus size eight |
| Unexpected final failures | None |

The two intentional failures were:

- `test_Property_AllRaffleClonesAreRejectedDestinations`
- `test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody`

They are counterexample evidence, not unexpected campaign failures.

Measured Forge coverage, excluding the known-violation contract:

| File | Lines | Statements | Branches | Functions |
|---|---:|---:|---:|---:|
| `Raffle.sol` | 87.04% (215/247) | 83.22% | 34.48% | 87.10% |
| `RaffleFactory.sol` | 78.69% (48/61) | 81.48% | 16.67% | 100.00% |

Coverage is supplemental evidence, not formal proof.

### Material S6 repairs

- Slither received an explicit PATH so it could find Forge; no compiler, remapping, source, or configuration repair was needed.
- Unit attempt 1 produced 16 passes and five harness failures: four partial-vs-exact custom-error expectations and one fixture destination. Only the harness was corrected.
- Unit attempt 2 produced 20 passes and one failure because a getter consumed a “next call must revert” expectation. A verbose trace identified the ordering mistake; the getter was moved before the expectation.
- Invariant attempt 1 lacked the `targetContract` cheatcode in the minimal local interface. The harness exposed a Foundry-discoverable `targetContracts()` array instead.
- Host Echidna was absent. Docker was used; the first direct `--version` invocation failed because of image entrypoint semantics, then the explicit `echidna-test --version` form succeeded. Solidity 0.8.36 was installed/selected inside the container.
- The Echidna image emitted a non-blocking ARM64/QEMU warning; compilation and both campaigns completed.
- Host Graphviz was absent. A direct bind mount failed, and a first `docker cp` render was rejected after shell interpolation produced `dot: can't open .dot`. A corrected isolated container rendered all nine DOT/PNG/PDF artifacts.
- No production source was edited to make a property pass.

## Complete S6 property matrix

The authoritative matrix is [SECURITY_PROPERTIES.md](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SECURITY_PROPERTIES.md).

| ID | Result | Coverage/disposition |
|---|---|---|
| LIF-01 | Pass | Factory-only, one-time initialization |
| LIF-02 | Pass | Locked implementation; clone begins awaiting prize |
| LIF-03 | Pass | Exact prize callback tuple and no-callback rollback |
| LIF-04 | **Fail** | Fake custody; DAYBREAK-F-01 |
| LIF-05 | Pass | Active-only sales and exclusive `endTime` |
| LIF-06 | Pass | Sold-entry requirement and exact draw window |
| LIF-07 | Pass locally | Caller/ID/shape/state/in-flight/deadline checks; wrapper implementation external |
| LIF-08 | Pass | Refund and late-callback boundary |
| LIF-09 | Pass | Duplicate/wrong callbacks cannot rewrite result |
| AUTH-01 | Pass | Current winning-ticket owner only |
| AUTH-02 | Pass | ERC-721 owner/operator authorization |
| AUTH-03 | Pass with qualifications | Fixed claim destinations; subject to destination findings |
| AUTH-04 | Pass locally | Immutable wrapper caller authentication |
| AUTH-05 | Pass | Sponsor-only early empty cancellation; deadline paths permissionless |
| ACC-01 | Pass | Sequential range partition in fuzz, invariants, and Echidna |
| ACC-02 | Pass | Active-sale pot/gross/entry accounting |
| ACC-03 | Conditional pass | Custody equals liabilities for canonical fee-free token |
| ACC-04 | Pass | Full refund conservation |
| ACC-05 | Pass | Terminal buckets sum to gross |
| ACC-06 | Pass | Exact reachable fee arithmetic, 10,000 cases |
| ACC-07 | Pass with qualification | Clear-before-transfer and rollback for standard tokens |
| ACC-08 | **Conditional fail** | Fee token creates deficit; DAYBREAK-F-05 |
| ACC-09 | Pass | No terminal liabilities during active sales |
| TKT-01 | Pass | Incompatible ticket recipient atomically rolls back |
| TKT-02 | Pass | Claim consumption burns ticket |
| TKT-03 | Pass | Historical ranges do not authorize a second claim |
| ERC-01 | Pass | Static ERC-721 ABI/events/indexing |
| ERC-02 | Pass | Runtime clone interfaces, balances, approvals, transfers, and receiver rollback |
| RE-01 | Pass | Quote/ticket callbacks cannot reenter purchase |
| RE-02 | Pass | Synchronous wrapper callback ignored before ID persistence |
| RE-03 | **Fail** | Pre-publication mutation; DAYBREAK-F-04 |
| RE-04 | Pass | No external call inside refund burn loop |
| PRIZE-01 | Pass | Missing prize callback rolls creation back |
| PRIZE-02 | **Fail** | Same root cause as LIF-04; DAYBREAK-F-01 |
| PRIZE-03 | **Fail** | Missing prize-recipient acceptance; DAYBREAK-F-02 |
| DST-01 | Pass | Already-known same-factory/local protocol sinks rejected |
| DST-02 | **Fail** | Other-factory clone accepted; DAYBREAK-F-03 |
| DST-03 | Pass | Permissionless caller cannot redirect fixed proceeds |
| VRF-01 | Pass locally | Caller, request ID, word count, state, and time binding |
| VRF-02 | **Unresolved external assumption** | Deployed wrapper identity, request binding, word quality, retry, and upgrade authority absent |
| VRF-03 | Pass | Modulo result always in range; theoretical bias below roughly `2^-128` at maximum domain |

A passing generated campaign is not formal proof over all EVM states or absent external implementations.

## Per-file coverage

### Five production files

| File | SHA-256 | Coverage |
|---|---|---|
| [`Raffle.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/Raffle.sol) | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` | Full 614-line manual review; scanners/printers/ERC check; Foundry and Echidna runtime; 87.04% measured executable-line coverage |
| [`RaffleFactory.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/RaffleFactory.sol) | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` | Full 186-line review; creation/registry/adversarial runtime; 78.69% lines and 100% functions |
| [`IRaffle.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/interfaces/IRaffle.sol) | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` | Full 521-line ABI, event, error, lifecycle, and trust-assumption review |
| [`IRaffleFactory.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/interfaces/IRaffleFactory.sol) | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` | Full 150-line creation/registry/deployment-responsibility review |
| [`RaffleConstants.sol`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/packages/contracts/src/libraries/RaffleConstants.sol) | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` | Full 43-line economics, timing, bounds, batch, and VRF-parameter review |

`DESIGN.md` remained unchanged at SHA-256 `25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1`.

### Thirty-one reachable dependencies

All 31 files were read, compiled under Solidity 0.8.36, and matched [dependency-hashes.json](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target/dependency-hashes.json), whose SHA-256 is `1447879cda291c3f34ffde9ab85a3fc094e49688fc90ecda0a858df6048d1141`.

| # | Dependency | Individual coverage |
|---:|---|---|
| 1 | `@openzeppelin/contracts/token/ERC721/IERC721.sol` | Full ABI/event and safe-versus-unsafe delivery review |
| 2 | `@openzeppelin/contracts/utils/introspection/IERC165.sol` | Prize interface self-report boundary |
| 3 | `@openzeppelin/contracts/token/ERC20/IERC20.sol` | Quote-token transfer/approval/balance interface |
| 4 | `@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` | Price, estimate, request, ID, and `link()` interface; implementation absent |
| 5 | `@openzeppelin/contracts/utils/math/Math.sol` | Selected `mulDiv` reviewed and fuzzed |
| 6 | `@openzeppelin/contracts/utils/math/SafeCast.sol` | Full source read; compiled transitive dependency |
| 7 | `@openzeppelin/contracts/utils/Panic.sol` | Full source read; transitive arithmetic support |
| 8 | `@openzeppelin/contracts/utils/ReentrancyGuard.sol` | Namespaced slot and clone zero-slot behavior reviewed and exercised |
| 9 | `@openzeppelin/contracts/utils/StorageSlot.sol` | Full source read; no first-party mutable implementation/admin slot |
| 10 | `@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` | Prize/ticket callbacks exercised with multiple receiver behaviors |
| 11 | `@openzeppelin/contracts/token/ERC721/ERC721.sol` | Ownership, approval, mint, burn, transfer, metadata, and receiver paths exercised |
| 12 | `@openzeppelin/contracts/interfaces/draft-IERC6093.sol` | Error interfaces reviewed; relevant ERC-721 errors exercised |
| 13 | `@openzeppelin/contracts/utils/introspection/ERC165.sol` | Interface support and invalid-ID runtime checks |
| 14 | `@openzeppelin/contracts/utils/Strings.sol` | Full source read; metadata support |
| 15 | `@openzeppelin/contracts/utils/Bytes.sol` | Full source read; transitive utility |
| 16 | `@openzeppelin/contracts/utils/math/SignedMath.sol` | Full source read; transitive formatting helper |
| 17 | `@openzeppelin/contracts/utils/Context.sol` | `_msgSender` reached through ERC-721 authorization |
| 18 | `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` | Receiver acceptance and revert bubbling exercised |
| 19 | `@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` | Metadata interface and runtime support |
| 20 | `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | Selected safe transfers and false-return rollback exercised |
| 21 | `@openzeppelin/contracts/interfaces/IERC1363.sol` | Full source read; extended helpers not selected |
| 22 | `@openzeppelin/contracts/interfaces/IERC165.sol` | Full import-forwarding interface read |
| 23 | `@openzeppelin/contracts/interfaces/IERC20.sol` | Full import-forwarding interface read |
| 24 | `@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` | Native-payment extra-argument encoding exercised |
| 25 | `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` | Constructor binding, request helper, gateway authentication, and dispatch exercised |
| 26 | `@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` | Full interface read; LINK payment path unused |
| 27 | `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` | Six-decimal query exercised |
| 28 | `@openzeppelin/contracts/proxy/Clones.sol` | Full clone review; ordinary `clone`/CREATE executed |
| 29 | `@openzeppelin/contracts/utils/Errors.sol` | Clone and low-level supporting errors reviewed |
| 30 | `@openzeppelin/contracts/utils/Create2.sol` | Full source read; deterministic variants not selected |
| 31 | `@openzeppelin/contracts/utils/LowLevelCall.sol` | Full source read; generic low-level/delegatecall helpers unreachable from first-party paths |

## Unresolved external and deployment leads

1. The actual Chainlink wrapper address, implementation, proxy/admin state, request-ID binding, pricing behavior, retry policy, liveness, and word provenance were not supplied.
2. The actual chain ID and quote-token address, implementation, proxy/admin state, and official-USDC provenance were not supplied.
3. No claim is made that any deployed prize contract is malicious; DAYBREAK-F-01 establishes a permitted source path and an isolated reproduction.
4. No deployed factory nonce, transaction order, recipient, or affected future-clone address was checked.
5. The precise frontend/indexer/keeper revision remains absent.
6. `uint64(block.timestamp)` narrowing at draw request and resolution lacks an explicit range guard; this is a far-future representation lead.
7. Concrete contract-recipient capabilities beyond `IERC721Receiver` remain deployment-specific.
8. Chain-specific timestamp/sequencer behavior and live wrapper transactions were not exercised.

## Limitations

- No formal verification was performed.
- Generated fuzz, invariant, and Echidna success is evidence over the executed models, not proof over every EVM state.
- S6 branch coverage was materially lower than line coverage because it prioritized lifecycle, trust-boundary, and adversarial properties over exhaustive error enumeration.
- External token and wrapper implementations cannot be proven from interfaces.
- No RPC state, live balances, deployed bytecode, deployment transaction, or scarcity information was available.
- No production fixes were applied or assessed.
- No historical test corpus was consulted.

## Prioritized actions

1. Resolve DAYBREAK-F-01 before launch by enforcing a trustworthy prize/custody model.
2. Replace both outbound prize `transferFrom` calls with receiver-checked transfers.
3. Move sale activation after factory custody verification and define event ordering.
4. Define whether clone isolation is global or factory-local, then enforce the chosen boundary consistently.
5. Pin and attest official quote-token and Chainlink wrapper deployments by chain.
6. Reconcile `DESIGN.md` with the early empty-raffle close and the actual prize trust model.
7. Supply and review the production frontend revision for fresh-state reread compliance.
8. Retain the S6 unit, fuzz, invariant, negative-property, ERC-conformance, and Echidna campaigns as remediation regression tests.
9. Perform non-production-fork integration tests against the concrete wrapper and quote token before deployment.

## Integrity and completeness

- Freeze after S5: 435 files verified per root; five production files; 31 dependencies; zero errors.
- Freeze before S6: the same clean result.
- Freeze after S6: the same clean result.
- S6 isolated-original verification: 43 checked, zero mismatches.
- Production source, dependencies, configuration, lockfiles, freeze material, stage reports, stage seals, `FIRST-PASS.md`, and the root first-pass seal were not modified.
- No production remediation or live transaction occurred.
- Campaign attempt 02 remains preserved and unused.
- No cross-cell reconciliation occurred.

### Exact six-skill completeness checklist

- [x] S1 `audit-context-building`: inherited same-cell dossier validated byte-for-byte; 12 native records present; not rerun.
- [x] S2 `entry-point-analyzer`: recurring and deployment-time surfaces enumerated with depth gaps retained.
- [x] S3 `token-integration-analyzer`: all four token/wrapper roles and 24 weird-token patterns reviewed.
- [x] S4 `guidelines-advisor`: five-phase, eleven-area review complete; compiler-only build preserved.
- [x] S5 `spec-to-code-compliance`: all 56 properties processed with native phases and refuters.
- [x] S6 `secure-workflow-guide`: scanners, printers, properties, Foundry, Echidna, manual special-area review, and coverage complete.

## Final artifact hashes

| Artifact | SHA-256 |
|---|---|
| [Immutable source-first report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/FIRST-PASS.md) | `981bea8dd6fe0e96328c38cf8375f93bc8bdf272476b4defcbeca71fdfdd9bc6` |
| [Immutable source-first root seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/SEAL.json) | `c7d730eb6687f33fbc6e10bc43671ad1975813a03e05d37cbb2d85b6ca2ba82b` |
| [S1 dossier](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md) | `854e2abd2863adb63f553f1fd4ac1a5e3b81acae38d9bbb2d1733c8a0fb7e0af` |
| [S1 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/SEAL.json) | `e6957a73277fbea4b5d2c308024eb07eafa89454ced6daf40df4f10fec18c803` |
| [S2 report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/REPORT.md) | `e63757982fbe049fa6ac482a7c205c00160dd84003b78b727adac0f90391cfd0` |
| [S2 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/02-entry-point/SEAL.json) | `de24917fb06493ea261bd9a471ddcb72b20fedfcc8e1a035d12883d7f153f516` |
| [S3 report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/REPORT.md) | `1f9e2cd0cc1e994b3f95771fede686bffb0fe8e027c98a70da06bac194d4189e` |
| [S3 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/03-token-integration/SEAL.json) | `a5b53b1251469984c3ec9de9bbc3ce79cbd8eadd70b5eb3308077a756dfbac91` |
| [S4 report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/REPORT.md) | `19b82b8743d9971337152299561b1b28e2d9426472fcb6f67494f07ff927d227` |
| [S4 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/04-guidelines/SEAL.json) | `c154879ec5a56d565b5477470bd67491d18490da5524d296dfdb61f89d7f274c` |
| [S5 report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/REPORT.md) | `e2cdee01bc21252af38f022c23588b07bdfe1b2712cca64208872166afc74e72` |
| [S5 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/05-spec-compliance/SEAL.json) | `750757807b9ae46806c0790ea937a691c353c22159ef8157da463f99223a0da7` |
| [S6 report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/REPORT.md) | `3a4bc298016c621b17945828a2dacf3bf87c72079720aaca54fa31d0c3549d4e` |
| [S6 seal](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/SEAL.json) | `fd043fd27bb990280b3b4079baba2f9f28f5a6cb0ca384205f668f5d99bfd496` |
| [S6 stage manifest](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/STAGE-MANIFEST.sha256) | `f7b510e132e53099848fc379e780e2fade7577f4a920c7c3bd35787a3a8f4084` |