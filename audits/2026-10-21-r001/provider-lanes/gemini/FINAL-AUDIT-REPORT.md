# Final Comprehensive Security Audit Report — Google Gemini Provider Lane (`r001`)

- **Audit Campaign**: `2026-10-21-r001`
- **Provider Lane**: Google Gemini (`gemini`)
- **Model Identifier**: `gemini-4-argon` (`Gemini 4 Argon (High)`)
- **Runner / Harness Host**: `/Applications/Antigravity.app/Contents/Resources/bin/language_server` (`hub-2.25.0`, Google Antigravity IDE)
- **Target Repository**: `/Users/hishamel-husseini/Documents/projects/raffle-fun`
- **Frozen Commit**: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Cold First-Pass Report**: `audits/2026-10-21-r001/provider-lanes/gemini/FIRST-PASS.md`
- **Cold First-Pass SHA-256**: `43a0a0efa35ae70f82b0311b29aea14a66aedf0b1f97d50f14e780d44ab5d3a3` (`sealed_at=2026-10-21T08:46:56Z`)
- **Final Report Timestamp (UTC)**: `2026-10-21T09:07:00Z`

---

## 1. Executive Summary

This report presents the final consolidated security audit of the `raffle.fun` smart contract protocol at frozen commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` conducted by the **Google Gemini (`gemini-4-argon`)** provider lane.

### 1.1 Two-Phase Audit Discipline

To ensure benchmark integrity and zero contamination from developer tests or historical audit reports during discovery, the audit was executed in two strictly separated phases:

1. **Phase 1 — Cold Source-Only Discovery (Sealed in `FIRST-PASS.md`)**:
   - An isolated clean-context workspace (`/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini/clean-context`) was populated with only the 5 in-scope Solidity production files, `DESIGN.md`, `foundry.toml`, `remappings.txt`, and external library interfaces (`@openzeppelin/contracts` v5.6.1 and `@chainlink/contracts` v1.5.0).
   - **30 independent read-only `research` subagents** (`gemini-4-argon`) were executed across `GEMINI-SIMAO` (12 0xSimao money-map lenses), `GEMINI-PASHOV` (9 specialist + 3 gap-hunter agents + upstream `assemble.sh`), and `GEMINI-TOB` (6 Trail of Bits security stages), alongside `GEMINI-GEBAL/attempt-01` (cold source-only snapshot `4d791fd1b91c282a49b1db1ec34fc406e11a75d7cb7fe4fea8a93c9b81d22ecb`) and `GEMINI-SUPPLEMENTARY/attempt-01`.
   - `FIRST-PASS.md` and `FIRST-PASS.md.sha256` (`43a0a0efa35ae70f82b0311b29aea14a66aedf0b1f97d50f14e780d44ab5d3a3`) were sealed at `2026-10-21T08:46:56Z` prior to any inspection of `packages/contracts/test/**` or `packages/contracts/audit/**`.
2. **Phase 2 — Post-Seal Dynamic Verification, Test-Inclusive Gebal Run, and Reconciliation**:
   - After sealing `FIRST-PASS.md`, we unpacked the full repository into an isolated validation workspace (`scratch/raffle-audit-r001-gemini/validation`), executed a custom Foundry PoC suite (`GeminiAuditPoC.t.sol`, **5/5 passing tests**) that dynamically proves every Medium and Low finding (`FP-M-01`, `FP-M-02`, `FP-L-01`, `FP-L-02`, `FP-L-03`), ran the repository's Foundry test suite (**79 passed, 0 failed, 1 skipped fork test**), Slither v0.11.6 (**46 contracts, 64 detectors, 0 static alerts**), Echidna v2.3.3 (**6/6 properties passed across 5,130 calls**), Python reference model tests (**11/11 passed**), and `GEMINI-GEBAL/attempt-02` (test-inclusive snapshot `3fd1f63658c7b24801622a8342c3d17453a39c67ccd21f8870f117257444e59a` + `gebal compare`).
   - Finally, we reconciled all cold findings against `packages/contracts/audit/**` and `packages/contracts/test/**` in `reconciliation/RECONCILIATION.md`.

### 1.2 Summary of Findings

| Final ID | Cold First-Pass ID | Severity | Title | Dynamic PoC Verification | Post-Seal Reconciliation Classification |
|---|---|---|---|---|---|
| **`GEMINI-M-01`** | `FP-M-01` | **Medium** | Predictable `CREATE` Clone Addresses Bypass `_isProtocolDestination` Before Deployment, Permanently Locking Quote Payouts and Allowing Cross-Clone ERC-721 Prize Transfers | `[PASS] testPoC_FPM01_FutureCloneCrossClonePrizeTransferAndLockedProceeds()` | **Confirmed True Positive** — Partially overlaps `FINDINGS.md` (`H-03`/`H-04`/`M-01`), `ES-01`, and `V12-243748..243750, 243759`, plus **novel untested vectors** (`sponsorRecipient = futureClone` locking `sponsorProceeds` and `releaseSponsorPrize` transferring NFTs into another Raffle clone in violation of `DESIGN.md`). |
| **`GEMINI-M-02`** | `FP-M-02` | **Medium** | Decoupled `releaseSponsorProceeds` in `Status.NftWon` Allows Sponsor to Extract 95% of Buyer USDC Even When `prizeToken` Delivery Fails in `redeemWinningTicket` | `[PASS] testPoC_FPM02_DecoupledSponsorProceedsWhenPrizeTransferBlocked()` | **Confirmed True Positive** — Matches `ES-03` (rated High in `ETHSKILLS-REVIEW-2026-08-13.md`); regressed in Ethereum v1 (`V12-243754`) when the delivery gate was removed while `RaffleFactory` remained permissionless on-chain. |
| **`GEMINI-L-01`** | `FP-L-01` | **Low** | Discontinuous Payout Cliff at `reserveEntries` and Unrestricted Single-Buyer Under-Target Draw Enable Sponsor Self-Purchase Arbitrage and 20% Fee Extraction | `[PASS] testPoC_FPL01_SponsorSelfPurchaseAndSingleBuyerExtraction()` | **Confirmed Novel True Positive** — Not documented in `packages/contracts/audit/**` or covered in `packages/contracts/test/**`. |
| **`GEMINI-L-02`** | `FP-L-02` | **Low** | Sponsor Pre-`endTime` Empty-Raffle Cancellation (`enableRefunds`) Can Be Front-Run by a 1-USDC `buyEntries` Transaction | `[PASS] testPoC_FPL02_FrontrunEmptyRaffleCancelWith1USDC()` | **Confirmed Novel True Positive** — Not documented in `packages/contracts/audit/**` or covered in `packages/contracts/test/**`. |
| **`GEMINI-L-03`** | `FP-L-03` | **Low** | Untrusted `prizeToken.safeTransferFrom` in `createRaffle` Activates the `Raffle` Clone Before `RaffleCreated` Is Emitted and Before Post-Transfer `ownerOf` Verification | `[PASS] testPoC_FPL03_MidEscrowBuyEntriesBeforeRaffleCreated()` | **Confirmed Novel True Positive** — Not documented in `packages/contracts/audit/**` or covered in `packages/contracts/test/**`. |
| **`GEMINI-I-01`** | `FP-I-01` | **Informational** | Unbounded `reserveEntries` Upper Limit, Unrestricted Secondary Ticket Transfers During `Status.Drawing` (`ES-02` Regression), and ERC-1167 `ReentrancyGuard` Cold-Slot Gas Overhead | Verified via state/gas analysis & test suite | **Confirmed True Positive** — Includes an undocumented regression from `ES-02` (where `Drawing` previously locked secondary ticket transfers) plus two novel defense-in-depth / gas optimizations. |

---

## 2. In-Scope Production Files & Cryptographic Hashes

All 5 mandatory production files were verified against the freeze manifest before, during, and after the audit:

| File Path | Lines | SHA-256 Digest |
|---|---:|---|
| `packages/contracts/src/Raffle.sol` | 608 | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| `packages/contracts/src/RaffleFactory.sol` | 194 | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| `packages/contracts/src/interfaces/IRaffle.sol` | 158 | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 48 | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 45 | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |

---

## 3. Benchmark Matrix & Harness Execution Summary

| Cell ID | Harness / Methodology | Pinned Upstream Commit | Mode | Status | Key Output Artifacts |
|---|---|---|---|---|---|
| `GEMINI-SIMAO` | `0xSimao/codex-audit-skill` | `041ff6d7637a9f3ee73f25a8f28853a63e833d28` | Cold Source-Only (Money Map + 12 Parallel Specialist Lenses + Turn 6 Adjudication) | **Completed** | `runs/GEMINI-SIMAO/attempt-01/REPORT.md`, `money-map.md`, `subagents/lens-01.md` .. `lens-12.md` |
| `GEMINI-PASHOV` | `pashov/skills` (`solidity-auditor`) | `dc16fa75ecfc6fcf5e7ec3fb5e29bbd39f89de88` | Cold Source-Only (9 Specialist Agents + 3 Gap Hunters + Turn 4 Dedup + Turn 5 `assemble.sh`) | **Completed** | `runs/GEMINI-PASHOV/attempt-01/REPORT.md`, `run-1.md`, `scope.tsv`, `subagents/agent-01.md` .. `agent-12.md` |
| `GEMINI-TOB` | `trailofbits/skills` (`building-secure-contracts`) | `82fe8226252622fa807643bdca1710901198553a` | Cold Source-Only (6 Sequential/Parallel Stages: Threat Model, Entry Points, Token Integration, Guidelines, Spec-to-Code, Code Maturity) | **Completed** | `runs/GEMINI-TOB/attempt-01/REPORT.md`, `subagents/stage-1-audit-context-building.md` .. `stage-6-secure-workflow-and-code-maturity.md` |
| `GEMINI-GEBAL` (`attempt-01`) | `enspyrco/gebal` (`v0.2.0`) | `b5a229d5e2bfbe253da6c3a4dc7fc331f0a69538` | Cold Source-Only (`runId: 9b66bccf-5138-42e3-911d-48da23cf375d`, `snapshotHash: 4d791fd1...`) | **Completed** | `runs/GEMINI-GEBAL/attempt-01/REPORT.md`, `report.json`, `report.html`, `report.sarif`, `findings.json` |
| `GEMINI-GEBAL` (`attempt-02`) | `enspyrco/gebal` (`v0.2.0`) | `b5a229d5e2bfbe253da6c3a4dc7fc331f0a69538` | Post-Seal Test-Inclusive (`runId: e9ac7aa6-401c-4083-8460-819838dc0eec`, `snapshotHash: 3fd1f636...`) + `gebal compare` | **Completed** | `runs/GEMINI-GEBAL/attempt-02/REPORT.md`, `report.json`, `report.html`, `report.sarif`, `compare-attempt01-vs-attempt02.json` |
| `GEMINI-OPENKRITT` (`attempt-01` & `attempt-02`) | `open-kritt/open-kritt` (`open_kritt_engine`) | `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` | Cold Source-Only (`external-flow-analysis` Depth 0: 19 entrypoints, Depth 1: 40 flows, Depth 2: 40 flow investigations + `dedupe` + `Blockchain security triage` ranker) | **Completed** | `runs/GEMINI-OPENKRITT/attempt-02/REPORT.md`, `step-results.json`, `vulnerabilities.json`, `post-processing.json`, `subagents/**` (plus CLI blocker provenance in `runs/GEMINI-OPENKRITT/attempt-01/BLOCKER.md`) |
| `GEMINI-SUPPLEMENTARY` | Native Adversarial Manual Review + Post-Seal Dynamic Verification (`forge`, `slither`, `echidna`, `python3`) | N/A | Cold Source-Only (`REPORT.md`) + Post-Seal PoC & Tool Suite | **Completed** | `runs/GEMINI-SUPPLEMENTARY/attempt-01/REPORT.md`, `GeminiAuditPoC.t.sol`, `forge-poc-tests.txt`, `forge-test-suite.txt`, `slither-output.txt`, `echidna-output.txt`, `python-model-tests.txt` |

### Cross-Harness Finding Attribution Matrix

| Final ID | Severity | `GEMINI-SIMAO` (12 Lenses) | `GEMINI-PASHOV` (12 Agents) | `GEMINI-TOB` (6 Stages) | `GEMINI-GEBAL` (`attempt-01` & `attempt-02`) | `GEMINI-OPENKRITT` (`attempt-02`) | `GEMINI-SUPPLEMENTARY` |
|---|---|---|---|---|---|---|---|
| **`GEMINI-M-01`** | Medium | `F-01` (Lenses 02, 04, 06, 09, 11, 12) | `[75]` & `[65]` (Agents 2, 4, 5, 7, 8, 9, 11, 12) | `TOB-M-01` (Stages 1, 2, 3, 5, 6) | Observation #1 (`accept`) | `OK-L-01` (Cluster `1:1` `[1,2,4]`, Flows 20, 23, 46) & `OK-L-02` (Cluster `1:3` `[3,5,6,7]`, Flows 25, 53, 55, 57) | `SUPP-M-01` + `testPoC_FPM01` |
| **`GEMINI-M-02`** | Medium | `F-02` (Lenses 02, 04, 06, 11, 12) | `[80]` (Agents 3, 4, 5, 6, 7, 8, 11, 12) | `TOB-M-02` (Stages 1, 3, 4, 5, 6) | Observation #2 (`accept`) | Traced in Flows 33, 36, 41 | `SUPP-M-02` + `testPoC_FPM02` |
| **`GEMINI-L-01`** | Low | `F-03` (Lenses 01, 03, 05, 08, 11) | `[75]` & `[60]` (Agents 1, 3, 7, 8, 9, 10) | `TOB-L-01` (Stages 1, 5, 6) | Observation #3 (`accept`) | Traced in Flows 25, 27, 33, 34 | `SUPP-L-01` + `testPoC_FPL01` |
| **`GEMINI-L-02`** | Low | `F-04` (Lenses 05, 06, 10, 12) | `[65]` (Agents 2, 3, 4, 8, 9, 12) | `TOB-L-02` (Stages 2, 4, 6) | Observation #4 (`accept`) | Traced in Flows 25, 29 | `SUPP-L-02` + `testPoC_FPL02` |
| **`GEMINI-L-03`** | Low | `L-01` (Lenses 06, 07, 10, 12) | `[60]` (Agents 4, 6, 11, 12) | `TOB-L-03` (Stages 2, 3, 4, 5) | Observation #5 (`accept`) | Traced in Flows 20, 48 | `SUPP-L-03` + `testPoC_FPL03` |
| **`GEMINI-I-01`** | Informational | `L-02`, `L-03`, `L-04` (Lenses 03, 05, 08, 09) | `[55]` & Leads 1–4 (Agents 3, 6, 8, 9, 10) | `TOB-I-01` (Stages 2, 3, 4, 5, 6) | Observation #6 (`accept`) | Traced in Flows 20, 51, 53, 55, 57 | `SUPP-I-01` |

---

## 4. Detailed Findings

---

### `[GEMINI-M-01]` (`FP-M-01`) Predictable `CREATE` Clone Addresses Bypass `_isProtocolDestination` Before Deployment, Permanently Locking Quote Payouts and Allowing Cross-Clone ERC-721 Prize Transfers

- **Severity**: Medium
- **Confidence**: High (Dynamically verified by Foundry PoC `testPoC_FPM01_FutureCloneCrossClonePrizeTransferAndLockedProceeds`)
- **Locations**:
  - `packages/contracts/src/RaffleFactory.sol:106-127` (`createRaffle`)
  - `packages/contracts/src/RaffleFactory.sol:159-168` (`_validateCreateParams`)
  - `packages/contracts/src/Raffle.sol:178-183` (`initialize`)
  - `packages/contracts/src/Raffle.sol:334-337` (`releaseSponsorProceeds`)
  - `packages/contracts/src/Raffle.sol:395-407` (`releaseSponsorPrize`)
  - `packages/contracts/src/Raffle.sol:497-502` (`_update`)
  - `packages/contracts/src/Raffle.sol:564-567` (`_deliverPrize`)
  - `packages/contracts/src/Raffle.sol:593-605` (`_isProtocolDestination`)

#### Root Cause
`RaffleFactory.createRaffle` deploys `Raffle` clones using `Clones.clone(raffleImplementation)` (`EVM CREATE` opcode), whose future addresses are deterministically computable from `(address(factory), factoryNonce)`. However, both `RaffleFactory._validateCreateParams` and `Raffle._isProtocolDestination` rely on runtime state (`destination.code.length != 0`, `canonicalFactory.isRaffle(destination)`) that is `false` for any not-yet-deployed clone `R_future`, and neither `Raffle.releaseSponsorPrize` nor `Raffle._deliverPrize` re-checks `_isProtocolDestination` before transferring the ERC-721 prize.

#### Pre-Conditions
- **Internal**: None. Any user can compute `R_future = computeCreateAddress(address(factory), nonce)` before `R_future` is deployed.
- **External**: None.

#### Concrete Exploitation / Failure Scenarios

1. **Permanent Lock of `sponsorProceeds` AND Cross-Clone ERC-721 Prize Transfer (Violating `DESIGN.md`)**:
   - At factory nonce 2, `sponsor1` creates Raffle #1 (`R_1`) with `sponsorRecipient = R_2` (where `R_2 = computeCreateAddress(address(factory), 3)` has `code.length == 0` and `isRaffle[R_2] == false`).
   - `sponsor2` creates Raffle #2, which deploys at `R_2` (`R_2.code.length == 45`, `isRaffle[R_2] = true`).
   - Raffle #1 resolves to `Status.CashWon` (or `Status.Refunding`) and `settleWinningTicket` is called:
     - `R_1.releaseSponsorProceeds()` calls `_transferQuote(R_2, amount)`, which re-evaluates `_isProtocolDestination(R_2) == true` and **permanently reverts with `InvalidQuoteDestination(R_2)`**, locking `sponsorProceeds` in `R_1` forever.
     - `R_1.releaseSponsorPrize()` omits `_isProtocolDestination(sponsorRecipient)` and executes `prizeToken.transferFrom(address(R_1), R_2, prizeTokenId)`. Because `transferFrom` does not invoke `onERC721Received`, **Raffle #1's prize NFT is transferred directly into Raffle #2 (`R_2`)**, directly violating `DESIGN.md`'s explicit invariant (*"Never move assets between raffle clones"*) and permanently stranding the NFT inside `R_2`.
2. **Permanent Lock of Winner Payouts / Ticket Refunds and Cross-Clone Winner NFT Transfer**:
   - A buyer purchases or transfers a ticket in `R_1` to `R_2` before `R_2` is deployed (passing `_update` and bypassing `checkOnERC721Received` because `R_2.code.length == 0`). Once `R_2` is deployed, `R_2` has no function to call `R_1.redeemWinningTicket` or `R_1.refundTickets`, permanently locking the 80% `winnerProceeds` (in `CashWon`), the prize NFT (in `NftWon`), or the buyer's refund (in `Refunding`).
3. **Delayed Factory-Wide DoS via `protocolTreasury`**:
   - If `protocolTreasury` is set in the `RaffleFactory` constructor to an uninitialized address that happens to equal a future clone `CREATE` address `R_k` (e.g., in multi-contract deterministic deployment scripts), `createRaffle` succeeds for raffles `1..k-1`, deploys `R_k` at `protocolTreasury`, and then **permanently bricks `RaffleFactory.createRaffle` for all future raffles `k+1..∞`** because `Raffle.initialize` checks `if (_isProtocolDestination(init.protocolTreasury)) revert UnsafeProtocolDestination(init.protocolTreasury)`.

#### Dynamic Foundry PoC (`testPoC_FPM01_FutureCloneCrossClonePrizeTransferAndLockedProceeds`)
Executed in `GeminiAuditPoC.t.sol` (`[PASS] (gas: 1114406)`):
```solidity
address predictedRaffle2 = vm.computeCreateAddress(address(factory), 3);
// Sponsor1 creates Raffle #1 with sponsorRecipient = predictedRaffle2
address raffle1Addr = factory.createRaffle(
    IRaffleFactory.CreateRaffleParams({
        prizeToken: address(nft),
        prizeTokenId: 1,
        sponsorRecipient: predictedRaffle2,
        reserveEntries: 100,
        endTime: uint64(block.timestamp + 1 days)
    })
);
// Buyer1 buys 10 entries in Raffle #1; Sponsor2 creates Raffle #2 at predictedRaffle2
// After Raffle #1 resolves to Status.CashWon and settles:
vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, predictedRaffle2));
raffle1.releaseSponsorProceeds(); // Permanently locked!

raffle1.releaseSponsorPrize();
assertEq(nft.ownerOf(1), raffle2Addr); // NFT #1 moved from Raffle #1 into Raffle #2!
```

#### Minimal Recommended Remediation
1. In `RaffleFactory.createRaffle`, replace `Clones.clone(raffleImplementation)` (`CREATE`) with `Clones.cloneDeterministic(raffleImplementation, salt)` (`CREATE2`) using a salt derived from `keccak256(abi.encode(msg.sender, params.prizeToken, params.prizeTokenId, params.sponsorRecipient, params.reserveEntries, params.endTime, raffles.length, block.prevrandao))`, preventing any caller from circularly embedding a future clone's address into an earlier raffle's `sponsorRecipient` or pre-deployment ticket recipient.
2. In `Raffle.releaseSponsorPrize` and `Raffle._deliverPrize`, add `if (_isProtocolDestination(destination)) revert UnsafeProtocolDestination(destination);` so ERC-721 prizes can never be transferred into a protocol contract under any circumstances.

---

### `[GEMINI-M-02]` (`FP-M-02`) Decoupled `releaseSponsorProceeds` in `Status.NftWon` Allows Sponsor to Extract 95% of Buyer USDC Even When `prizeToken` Delivery Fails in `redeemWinningTicket`

- **Severity**: Medium
- **Confidence**: High (Dynamically verified by Foundry PoC `testPoC_FPM02_DecoupledSponsorProceedsWhenPrizeTransferBlocked`)
- **Locations**:
  - `packages/contracts/src/Raffle.sol:329-339` (`releaseSponsorProceeds`)
  - `packages/contracts/src/Raffle.sol:375-382` (`redeemWinningTicket`)
  - `packages/contracts/src/Raffle.sol:533-558` (`_settleWinningTicket`)
  - `packages/contracts/src/RaffleFactory.sol:171-177` (`_validateCreateParams`)

#### Root Cause
In `Status.NftWon`, `_settleWinningTicket` credits `sponsorProceeds = (pot * 9500) / 10000` and `protocolFees = pot - sponsorProceeds` in storage without verifying that `prizeToken` can be transferred to the winner, and `Raffle.releaseSponsorProceeds()` does not require `prizeClaimed == true` when `status == Status.NftWon`.

#### Pre-Conditions
- **Internal**: A raffle resolves to `Status.NftWon` (`totalEntries >= reserveEntries`).
- **External**: The ERC-721 `prizeToken` (which is completely permissionless in `RaffleFactory.createRaffle` as long as it returns `true` for `IERC165` and `IERC721` interface IDs) is pausable, blacklist-enabled, soulbound-after-first-transfer, expiring, or controlled by the sponsor so that `prizeToken.transferFrom(address(this), owner, prizeTokenId)` reverts after escrow.

#### Concrete Exploitation / Failure Scenario
1. Sponsor creates a raffle with `reserveEntries = 10` using a pausable, blacklistable, or sponsor-controlled ERC-721 `prizeToken`.
2. Buyers purchase 10 entries ($10 USDC).
3. Draw fulfills (`totalEntries >= reserveEntries` $\rightarrow$ `Status.NftWon`).
4. `prizeToken` transfers are paused or restricted before the winner calls `redeemWinningTicket`.
5. Sponsor calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()`, extracting **95% of buyer USDC** (`9_500_000` units), while `releaseProtocolFees()` extracts the remaining 5%.
6. When the winner calls `redeemWinningTicket(winningTicketId)`, `_deliverPrize` reverts. Because `status` is already terminal (`Status.NftWon`), `enableRefunds()` also reverts with `InvalidStatus(Status.NftWon)`. The sponsor keeps 95% of the buyers' USDC while the winner receives neither the NFT nor a refund.

#### Post-Seal Reconciliation Note
In `ETHSKILLS-REVIEW-2026-08-13.md` (`ES-03`), this exact vulnerability was rated **High** and fixed by gating NFT-branch sponsor/treasury proceeds on verified prize delivery (`prizeClaimed == true`) with a 30-day fallback to `Status.Refunding`. In the subsequent Ethereum v1 redesign (`V12-REVIEW-2026-08-20.md` `243754`, `CURRENT-RESIDUAL-RISKS.md`), the team removed the delivery gate to simplify independent pull claims and reclassified hostile/broken `prizeToken` contracts as an off-chain collection admission concern. However, because `RaffleFactory.createRaffle` has no on-chain collection allowlist and `DESIGN.md` explicitly states that *"arbitrary prize contracts and ticket recipients are untrusted"*, leaving `releaseSponsorProceeds` ungated in `Status.NftWon` creates a direct on-chain rug vector for any permissionless caller interacting with `RaffleFactory`.

#### Dynamic Foundry PoC (`testPoC_FPM02_DecoupledSponsorProceedsWhenPrizeTransferBlocked`)
Executed in `GeminiAuditPoC.t.sol` (`[PASS] (gas: 781606)`):
```solidity
// Prize token becomes paused / transfer-restricted before winner redeems
nft.setTransfersBlocked(true);

// Sponsor settles and extracts 95% of buyer1's USDC!
uint256 sponsorBalBefore = usdc.balanceOf(sponsor1);
raffle.settleWinningTicket(1);
raffle.releaseSponsorProceeds();
assertEq(usdc.balanceOf(sponsor1) - sponsorBalBefore, 9_500_000);

// Winner cannot redeem the prize NFT and cannot enable refunds!
vm.prank(buyer1);
vm.expectRevert("PRIZE_PAUSED");
raffle.redeemWinningTicket(1);
```

#### Minimal Recommended Remediation
Either:
1. **On-Chain Delivery Gate (Minimal Change)**: In `Raffle.releaseSponsorProceeds()`, require `if (status == Status.NftWon && !prizeClaimed) revert NothingToClaim();` so a sponsor cannot extract 95% of buyer USDC while `prizeToken` blocks winner redemption, or
2. **Collection Allowlist**: Enforce an on-chain allowlist or curation registry of vetted ERC-721 `prizeToken` contracts in `RaffleFactory._validateCreateParams`.

---

### `[GEMINI-L-01]` (`FP-L-01`) Discontinuous Payout Cliff at `reserveEntries` and Unrestricted Single-Buyer Under-Target Draw Enable Sponsor Self-Purchase Arbitrage and 20% Fee Extraction

- **Severity**: Low (Economic / Game-Theoretic Design Vulnerability — **Novel Finding**)
- **Confidence**: High (Dynamically verified by Foundry PoC `testPoC_FPL01_SponsorSelfPurchaseAndSingleBuyerExtraction`)
- **Locations**:
  - `packages/contracts/src/Raffle.sol:209-236` (`buyEntries`)
  - `packages/contracts/src/Raffle.sol:243-248` (`requestDraw`)
  - `packages/contracts/src/Raffle.sol:519-550` (`_settleWinningTicket`)
  - `packages/contracts/src/RaffleFactory.sol:178-179` (`_validateCreateParams`)

#### Root Cause
1. **Discontinuous Reserve Cliff + 95% Sponsor Self-Purchase Rebate**: At `totalEntries == reserveEntries - 1` (`Status.CashWon`), the sponsor receives `15%` of the pot plus the returned NFT and buyers receive `80%` of the pot. At `totalEntries == reserveEntries` (`Status.NftWon`), the sponsor's cash payout jumps discontinuously from `15%` to `95%` of the entire pot while the buyer cash payout drops to `0%`. Because `buyEntries` does not restrict `sponsor` or `sponsorRecipient` (and Sybil addresses are permissionless), every entry the sponsor buys at or above `reserveEntries` receives a **95% self-rebate** via `sponsorProceeds` (costing the sponsor only **$0.05 net per $1.00 entry**).
2. **Single-Buyer (`ticketCount == 1`) Under-Target Draw Fee Extraction**: `requestDraw` only checks `totalEntries != 0` and does not require `ticketCount >= 2` when `totalEntries < reserveEntries`. When only a single buyer purchases entries in a raffle that fails to reach `reserveEntries`, there is zero multi-participant lottery competition (the sole buyer wins the cash pot with 100% probability), yet calling `requestDraw` transitions the raffle to `Status.CashWon`, extracting **15% `sponsorProceeds` + 5% `protocolFees` (20% total fee)** from the sole buyer's principal while returning the NFT to the sponsor.

#### Concrete Economic Proof & Dynamic Foundry PoC (`testPoC_FPL01_SponsorSelfPurchaseAndSingleBuyerExtraction`)
Let $R = 1{,}000$ USDC (`reserveEntries = 1,000`), NFT fair value $V = 200$ USDC, and external buyers purchase $E_{ext} = 500$ entries ($500 USDC):
- If the sponsor does nothing (`Status.CashWon`), the sponsor gets $0.15 \times 500 = 75$ USDC + NFT ($200) = **275 USDC**.
- If the sponsor buys the remaining $E_{self} = 500$ entries right before `endTime` (`totalEntries = 1,000 == reserveEntries`, triggering `Status.NftWon`):
  - Sponsor pays $500$ USDC into the pot, receives $0.95 \times 1{,}000 = 950$ USDC via `releaseSponsorProceeds` (**+450 USDC net cash profit** extracted from external buyers), AND wins back their own NFT with $\frac{500}{1000} = 50\%$ probability (expected value $450 + 0.50 \times 200 = \mathbf{550\text{ USDC}}$, a **+275 USDC risk-free expected profit** over doing nothing).
  - Executed in `GeminiAuditPoC.t.sol` (`[PASS] (gas: 825344)`): when the sponsor's ticket is drawn, the sponsor nets **+450 USDC** from `buyer1` AND retains the prize NFT (`assertEq(nft.ownerOf(10), sponsor1)`).

#### Minimal Recommended Remediation
1. In `Raffle.buyEntries`, reject direct self-purchases by `sponsor` and `sponsorRecipient`:
   ```solidity
   if (msg.sender == sponsor || msg.sender == sponsorRecipient || recipient == sponsor || recipient == sponsorRecipient) {
       revert InvalidTicketRecipient(recipient);
   }
   ```
2. When `totalEntries < reserveEntries` and `ticketCount == 1` at `endTime`, disallow `requestDraw` (routing to `Status.Refunding` so a sole buyer in an under-subscribed raffle is refunded 100% rather than taxed 20%).

---

### `[GEMINI-L-02]` (`FP-L-02`) Sponsor Pre-`endTime` Empty-Raffle Cancellation (`enableRefunds`) Can Be Front-Run by a 1-USDC `buyEntries` Transaction

- **Severity**: Low (**Novel Finding**)
- **Confidence**: High (Dynamically verified by Foundry PoC `testPoC_FPL02_FrontrunEmptyRaffleCancelWith1USDC`)
- **Locations**:
  - `packages/contracts/src/Raffle.sol:209-236` (`buyEntries`)
  - `packages/contracts/src/Raffle.sol:280-292` (`enableRefunds`)

#### Root Cause
`Raffle.enableRefunds()` allows the `sponsor` to cancel an `Active` raffle before `endTime` only if `totalEntries == 0`. Because `buyEntries` is permissionless while `block.timestamp < endTime` and requires a minimum purchase of only `1` entry (`1 USDC = 1_000_000`), any mempool observer can front-run the sponsor's `enableRefunds()` transaction with `buyEntries(attacker, 1)`.

#### Impact
1. The sponsor's `enableRefunds()` transaction reverts with `RefundsNotAvailable(endTime + DRAW_REQUEST_TIMEOUT, block.timestamp)`.
2. The sponsor's prize NFT is locked in the `Raffle` contract until `endTime` (up to `MAX_SALE_DURATION = 30 days`) plus `DRAW_REQUEST_TIMEOUT` (`2 days`, up to **32 days total**) at a cost to the attacker of only $0.20 (in `CashWon`, where the attacker gets $0.80 back) or $0.00 (if nobody calls `requestDraw` and the raffle enters `Refunding`).
3. If `reserveEntries == 1` (a 1-entry promotional raffle that the sponsor tried to cancel before `endTime`), the front-runner wins the sponsor's NFT outright with 100% probability for 1 USDC!

#### Dynamic Foundry PoC (`testPoC_FPL02_FrontrunEmptyRaffleCancelWith1USDC`)
Executed in `GeminiAuditPoC.t.sol` (`[PASS] (gas: 618983)`):
```solidity
// Buyer1 front-runs sponsor1's enableRefunds() with a 1-USDC purchase
vm.startPrank(buyer1);
usdc.approve(address(raffle), 1 * RaffleConstants.ENTRY_PRICE);
raffle.buyEntries(buyer1, 1);
vm.stopPrank();

// Sponsor1's enableRefunds() call now reverts with RefundsNotAvailable(endTime + DRAW_REQUEST_TIMEOUT, block.timestamp)
vm.prank(sponsor1);
vm.expectRevert(
    abi.encodeWithSelector(
        IRaffle.RefundsNotAvailable.selector,
        raffle.endTime() + RaffleConstants.DRAW_REQUEST_TIMEOUT,
        uint64(block.timestamp)
    )
);
raffle.enableRefunds();
```

#### Minimal Recommended Remediation
Document that sponsors canceling an empty raffle before `endTime` should submit `enableRefunds()` via a private transaction relay (e.g., Flashbots Protect), or enforce a minimum `reserveEntries >= 2` in `RaffleFactory._validateCreateParams` so a 1-USDC front-run can never trigger `Status.NftWon`.

---

### `[GEMINI-L-03]` (`FP-L-03`) Untrusted `prizeToken.safeTransferFrom` in `createRaffle` Activates the `Raffle` Clone Before `RaffleCreated` Is Emitted and Before Post-Transfer `ownerOf` Verification

- **Severity**: Low (**Novel Finding**)
- **Confidence**: High (Dynamically verified by Foundry PoC `testPoC_FPL03_MidEscrowBuyEntriesBeforeRaffleCreated`)
- **Locations**:
  - `packages/contracts/src/RaffleFactory.sol:128-147` (`createRaffle`)
  - `packages/contracts/src/Raffle.sol:416-431` (`onERC721Received`)

#### Root Cause
During `RaffleFactory.createRaffle`, `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` calls `Raffle.onERC721Received`, which immediately sets `status = Status.Active` and emits `PrizeDeposited` inside the callback. While `RaffleFactory.createRaffle` holds its own `nonReentrant` lock, the newly cloned `Raffle` contract's `ReentrancyGuard` is unentered during `createRaffle`. Consequently, a custom or hook-enabled `prizeToken` contract can call `Raffle(raffle).buyEntries(recipient, entryCount)` inside `safeTransferFrom` right after `onERC721Received` returns — before `RaffleFactory.createRaffle` verifies `prize.ownerOf(params.prizeTokenId) != raffle` and before `RaffleCreated` is emitted.

#### Impact
- Off-chain indexers and event consumers that rely on `RaffleCreated` being emitted before any `TicketPurchased` or ERC-721 ticket `Transfer` events for a raffle will encounter `TicketPurchased` events for a raffle address that has not yet emitted `RaffleCreated`.
- A sponsor using a custom ERC-721 contract can atomically pre-buy the initial ticket range `[1, entryCount]` inside `safeTransferFrom` before any external participant sees the raffle creation.

#### Dynamic Foundry PoC (`testPoC_FPL03_MidEscrowBuyEntriesBeforeRaffleCreated`)
Executed in `GeminiAuditPoC.t.sol` (`[PASS] (gas: 1671867)`):
```solidity
// Inside CallbackPrizeNFT.safeTransferFrom, immediately after onERC721Received returns:
usdc.approve(to, uint256(callbackEntries) * RaffleConstants.ENTRY_PRICE);
Raffle(payable(to)).buyEntries(callbackBuyer, callbackEntries);
boughtDuringSafeTransfer = true;
// Assertions after createRaffle returns:
assertTrue(cbNft.boughtDuringSafeTransfer());
assertEq(raffle.totalEntries(), 5);
assertEq(raffle.ownerOf(1), buyer1);
```

#### Minimal Recommended Remediation
Separate deposit receipt from activation: have `Raffle.onERC721Received` record a boolean `prizeReceived = true` while keeping `status == Status.Initialized`, and have `RaffleFactory.createRaffle` call `Raffle(payable(raffle)).activate()` only **after** `prize.safeTransferFrom` returns and `prize.ownerOf(params.prizeTokenId) == raffle` is verified.

---

### `[GEMINI-I-01]` (`FP-I-01`) Unbounded `reserveEntries` Upper Limit, Unrestricted Secondary Ticket Transfers During `Status.Drawing` (`ES-02` Regression), and ERC-1167 `ReentrancyGuard` Cold-Slot Gas Overhead

- **Severity**: Informational / Defense-in-Depth & Gas Optimization
- **Confidence**: High
- **Locations**:
  - `packages/contracts/src/RaffleFactory.sol:178-179` (`_validateCreateParams`)
  - `packages/contracts/src/Raffle.sol:497-502` (`_update`)
  - `packages/contracts/src/Raffle.sol:17` (`ReentrancyGuard` inheritance)
  - `packages/contracts/src/libraries/RaffleConstants.sol:32-42` (`VRF_CALLBACK_GAS_LIMIT`)

#### Description
1. **Unbounded `reserveEntries` (`uint128`)**: `RaffleFactory._validateCreateParams` only checks `params.reserveEntries == 0`, allowing `reserveEntries` up to `type(uint128).max` ($3.4 \times 10^{38}$ entries $\approx \$3.4 \times 10^{38}$ USDC, exceeding all USDC in existence). In such a raffle, `Status.NftWon` is mathematically unreachable, guaranteeing `Status.CashWon` (where the sponsor extracts 15% of buyer USDC and keeps the NFT). Adding a `MAX_RESERVE_ENTRIES` bound (e.g., `10_000_000` entries = \$10M USDC) prevents unreachable-reserve raffles.
2. **Unrestricted Secondary Ticket Transfers During `Status.Drawing` (`ES-02` Regression)**: In `ETHSKILLS-REVIEW-2026-08-13.md` (`ES-02`), the protocol team noted that secondary ticket transfers were locked once `Drawing` started. In the Ethereum v1 rewrite (`Raffle.sol:497-502`), `Raffle._update` no longer checks `status` during transfers, allowing tickets to be transferred during `Status.Drawing` and after draw resolution (`Status.NftWon` / `Status.CashWon`). If a ticket holder lists a ticket on an NFT marketplace or an attacker places a collection bid, a mempool searcher who observes the incoming Chainlink VRF `fulfillRandomWords` transaction can front-run the VRF callback to buy the winning ticket (or sell a losing ticket into a bid). Re-introducing `if (from != address(0) && to != address(0) && status == Status.Drawing) revert TransfersLockedDuringDraw();` eliminates mempool front-running during the VRF fulfillment window.
3. **ERC-1167 Clone `ReentrancyGuard` Cold-Slot Penalty & `VRF_CALLBACK_GAS_LIMIT`**: Because `Raffle` is deployed via `Clones.clone`, its storage slots start at `0` rather than `ReentrancyGuard`'s constructor-initialized `_NOT_ENTERED = 1`. The first caller to `buyEntries` pays a 20,000-gas `0 -> 1` `SSTORE` penalty. Switching to OpenZeppelin v5.6.1's `ReentrancyGuardTransient` (`TSTORE`/`TLOAD`, native on `evm_version = "cancun"`) saves ~15,000 gas on the first purchase and ~2,100 gas on subsequent calls. Additionally, `VRF_CALLBACK_GAS_LIMIT = 300_000` can be safely reduced to `100_000` (since `fulfillRandomWords` writes only 4 storage slots and uses `< 60,000` gas, as confirmed by `testBothCallbackBranchesStayBelowGasBudget`), reducing the native ETH fee paid by `requestDraw` callers by ~50–65%.

---

## 5. Verified Protocol Invariants & Security Strengths

Across all 30 cold specialist subagents, the 79 passing Foundry unit/fuzz/invariant/adversarial tests, Slither v0.11.6, Echidna v2.3.3 (5,130 calls across 6 properties), and the 11 Python protocol model tests, the following core properties of `raffle.fun` were proven sound:

1. **Exact Conservation of USDC Accounting (`echidna_sales_and_liabilities_are_exact` & `invariantQuoteAccountingAndSolvencyHold`)**:
   - In `NftWon`, `sponsorProceeds = (pot * 9500) / 10000` and `protocolFees = pot - sponsorProceeds` (`winnerProceeds = 0`).
   - In `CashWon`, `winnerProceeds = (pot * 8000) / 10000`, `sponsorProceeds = (pot * 1500) / 10000`, and `protocolFees = pot - winnerProceeds - sponsorProceeds`.
   - For every integer `pot`, the sum of allocated claims equals `pot` with zero rounding dust lost or created, and direct USDC donations to a `Raffle` clone do not inflate or brick internal claim accounting.
2. **Contiguous 1-Indexed Range Partitioning & Binary Search / O(1) Proof Verification (`echidna_ranges_partition_all_entries` & `invariantTicketRangesPartitionSoldEntries`)**:
   - Every `buyEntries` call mints a single sequential `ticketId` with `startEntry = totalEntries + 1` and `endEntry = totalEntries + entryCount`, forming a gapless, non-overlapping partition of `[1, totalEntries]`.
   - `settleWinningTicket(ticketId)` verifies `range.startEntry <= winningEntry && winningEntry <= range.endEntry` in $O(1)$ gas, eliminating unbounded iteration over receipts during settlement or VRF callbacks.
3. **Hardened Chainlink VRF v2.5 Direct Funding Integration (`VrfAdversarial.t.sol` & `echidna_draw_and_callback_deadlines_are_ordered`)**:
   - `requestDraw` enforces `[endTime, endTime + 2 days)`, sets `pendingRequestId = type(uint256).max` before the external call to `i_vrfV2PlusWrapper.requestRandomWordsInNative` to block synchronous reentrant callbacks (`testSynchronousWrongDuplicateAndValidCallbacksCannotResolveInFlightRequest`), and calculates native fee refunds against `balanceBefore = address(this).balance - msg.value` so forced ETH (`SELFDESTRUCT`) cannot be drained or used to misprice refunds (`testOfficialHelperCannotUseForcedNativeToSubsidizeQuoteDrift`).
   - `fulfillRandomWords` can only be invoked by `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords`), ignores stale/wrong `requestId` or malformed `randomWords.length != 1` without reverting, and enforces the strict deadline `block.timestamp < callbackDeadline` (`requestedAt + 2 days`).
4. **Guaranteed Liveness of `Status.Refunding` After VRF Request or Callback Timeout**:
   - If `requestDraw` is not called before `endTime + 2 days`, or if the VRF wrapper fails to fulfill strictly before `requestedAt + 2 days`, any caller can invoke `enableRefunds()` to transition to `Status.Refunding`, enabling 100% principal refunds via `refundTickets` and sponsor NFT recovery via `releaseSponsorPrize`.
5. **Implementation Contract & Clone Initialization Locking**:
   - The `Raffle` implementation contract sets `initialized = true` and `status = Status.Refunding` in its constructor (`Raffle.sol:124-126`), permanently preventing direct initialization or manipulation of the implementation contract.
