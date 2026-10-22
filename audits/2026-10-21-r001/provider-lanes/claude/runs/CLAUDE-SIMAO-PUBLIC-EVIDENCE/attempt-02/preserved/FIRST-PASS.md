# FIRST-PASS — CLAUDE-SIMAO-PUBLIC-EVIDENCE · attempt-02 · raffle.fun (Raffle clone + RaffleFactory)

**Method (disclosed variant).** This run uses `simao/0xsimao-ai` VERSION 1.0.0 with the public-evidence `shared-rules.md`, which replaces only the upstream private working-text request with concise, source-cited public evidence summaries. All other lens, proof, severity, dedup and report rules are native.

**This is not an original, unmodified 0xSimao completion.**

**Orchestrator:** claude-opus-5-5 (Opus 5.5).
**Lenses:** 12 independent foreground Agent calls with `model=opus` (Opus 5.5) and `effort=max`.

## Status

| Attempt | Stage | Outcome |
|---|---|---|
| attempt-01 | Turns 0–3 (banner, discover, money map, bundles) | Completed. These are the frozen inputs to this attempt. |
| attempt-01 | Turn 4 (12 background lenses, launched 2026-10-21T18:35:22Z) | Launched. |
| attempt-01 | Turn 5 | **FAILED.** The parent ended while waiting, and the system killed all 12 background children. No lens report was completed and there was no Turn 6. This is preserved as a failure, not a completed review. Attempt-02 never read the attempt-01 sink `/tmp/simao-raw-k0z3mc`. |
| attempt-02 | Preflight | Passed (gates below). |
| attempt-02 | Turn 4: 12 lenses, one message, parallel, **foreground** (launched 2026-10-21T21:19:30Z) | **12/12 returned with output.** |
| attempt-02 | Turn 5 | Completed: 0 transport or setup failures, 0 re-runs, no background watcher, no polling. |
| attempt-02 | Turn 6: dedup, judge, promote/demote, report | Completed: `evidence/native-report.md`. |
| attempt-02 | Turn 6 step 5 auto-clean (`rm -rf ./.audit-simao-s29F2o`) | Attempted after a verified exact copy and **denied by the runtime permission layer**. It was not retried or circumvented. The bundle dir is retained, byte-identical to the recorded hashes. |

## Raw lens outputs (all 12; canonical files written by each lens, also returned as its final message)

| Lens | Raw output | FINDING | LEAD | sha256 |
|---|---|---|---|---|
| 1 accounting-desync | `evidence/raw-lens-outputs/lens-1-output.md` | 0 | 3 | `b212765f903e8868e2d2fccd3c5ac4874db8c2d82e8ccd4f95d454a39f564b56` |
| 2 share-exchange-rate | `evidence/raw-lens-outputs/lens-2-output.md` | 0 | 3 | `771315235de42b7cd41e337050cc3189647cb1c71a73351ee1aad77c799a9313` |
| 3 temporal-cohort | `evidence/raw-lens-outputs/lens-3-output.md` | 1 | 3 | `f59c9fa54a61667fea246dae8c454950164377490a793ef3f342b1d55e11ca30` |
| 4 liquidation-solvency | `evidence/raw-lens-outputs/lens-4-output.md` | 1 | 4 | `1b67c93d35d3773fd025ba4aaedaa4d7a3f72298864d95d8d8c7887bb1bea3b7` |
| 5 cross-chain-state | `evidence/raw-lens-outputs/lens-5-output.md` | 0 | 3 | `b30e559524d937004ff41e789db1c3dd350f6f40a5217e2f29a175be7ff88f6e` |
| 6 rounding-precision | `evidence/raw-lens-outputs/lens-6-output.md` | 0 | 2 | `cc984a6278db3d2ffd7c76de88aa20236c622d608b494b1a668ac0b920e0f851` |
| 7 ordering-mev | `evidence/raw-lens-outputs/lens-7-output.md` | 0 | 4 | `a36d02c78a23bf99bc9fc74e0cb5e7e7db427fb6181bf30a0ddc576893e12d9c` |
| 8 dos-griefing | `evidence/raw-lens-outputs/lens-8-output.md` | 0 | 5 | `60f829da08417bb080b07444ec134b5d37102ba57365234b8e76f92006330b53` |
| 9 access-trust | `evidence/raw-lens-outputs/lens-9-output.md` | 0 | 4 | `3960688f5df2b8d8a640ce9b5dd4325ae26fded74efa68ef7ed8329aa45d537d` |
| 10 integration-assumptions | `evidence/raw-lens-outputs/lens-10-output.md` | 1 | 2 | `97024d26d22377d975756bf1956a899c9098578b81de4dd7de07360c0dfef913` |
| 11 edge-states | `evidence/raw-lens-outputs/lens-11-output.md` | 0 | 4 | `3da184bf67e82e91d17b1dec1e37504534dc7bf2e8d12168c87aee5c4af9466d` |
| 12 flow-completeness | `evidence/raw-lens-outputs/lens-12-output.md` | 0 | 3 | `4120c650d065620b28a231b87ebbfe5e1e561ceca781ff716cda8470df0e47a1` |
| **Total** | | **3** | **40** | |

Exact copies are kept in `evidence/native-preserved/raw-lens-outputs/` (12/12 identical).

Per-lens agent IDs, durations, tokens and write times are in `evidence/ledger/attempt-02-stage-ledger.md` and `METHOD-STAGES.json`.

## Gates actually run

### Integrity gates (preflight, after the lenses, and final)

| Gate | Preflight | After lenses (21:41:40Z) | Final (22:00:43Z) |
|---|---|---|---|
| 43 original input files vs `baseline-input-hashes.sha256` | OK 43/43, file set identical | OK 43/43, file set identical | OK 43/43, file set identical |
| `dependency-hashes.json` (31 deps) | OK 31/31 | — | — |
| Recorded bundle hashes (12 bundles + money map + source) | OK 14/14 | OK 14/14 | OK 14/14 |
| Each bundle == `cat source.md money-map.md simao-method.md <lens>.md shared-rules.md` | **12/12 EXACT** (the first checker run printed a false MISMATCH caused by zsh's 1-indexed arrays; corrected and re-run) | — | — |
| `source.md` embedded blocks == on-disk files | 6/6 EXACT | — | — |
| Preserved copy == originals | — | — | bundles 14/14, raw outputs 12/12 |

### Native Turn 6 gates

- **Dedup.** 43 raw items (3 FINDING, 40 LEAD) became 15 groups. Every raw item is in exactly one group (43/43).
- **Function isolation (HARD).** PASS. A machine check confirms no group spans two `function:` fields.
- **Mechanism preservation.** Every distinct mechanism is listed per group (`evidence/turn6/dedup-ledger.md`).
- **Mitigation preservation.** Mitigations are grouped by the actual change. All 37 quoted mitigations and cautions were machine-checked as verbatim substrings of their raw blocks. Groups with 2 or more distinct mitigations are presented as Options: M-1 A/B/C, M-5 A/B, L-1 A/B/C.
- **Completeness gate.** `Completeness: 11 unique (Contract, function) in raw, 11 covered in final.`
- **Severity gates.** G1–G4 from `severity-calibration.md`, one line each, in a single pass in fixed order. `UNCERTAIN` = `ALLOWS`. Ledger: `evidence/turn6/gate-ledger.md`.

| Group | (Contract, function) | Lenses | G1 | G2 | G3 | G4 | Promotion / demotion | Final |
|---|---|---|---|---|---|---|---|---|
| D01 | RaffleFactory::createRaffle | 1 | ALLOWS | ALLOWS | UNCERTAIN | BLOCKS | not promoted | Lead-1 |
| D02 | Raffle::buyEntries (dilution) | 1 | ALLOWS | ALLOWS | ALLOWS | ALLOWS | raw FINDING kept | **M-2 Medium** |
| D03 | Raffle::buyEntries (reserve flip) | 2 | ALLOWS | ALLOWS | ALLOWS | UNCERTAIN | promoted ([lenses: 2]) | **L-3 Low** |
| D04 | Raffle::requestDraw | 2 | BLOCKS | BLOCKS | UNCERTAIN | BLOCKS | demoted (G1 code path) | Lead-2 |
| D05 | Raffle::_settleWinningTicket (rebate) | 3 | ALLOWS | ALLOWS | ALLOWS | ALLOWS | promoted ([lenses: 3] + full path) | **M-3 Medium** |
| D06 | Raffle::_settleWinningTicket (no delivery dependency) | 2 | ALLOWS | ALLOWS | ALLOWS | ALLOWS | promoted ([lenses: 2] + full path) | **M-4 Medium** |
| D07 | Raffle::enableRefunds | 3 | ALLOWS | ALLOWS | ALLOWS | BLOCKS | demoted (G4) | Lead-3 |
| D08 | Raffle::redeemWinningTicket | 1 | ALLOWS | ALLOWS | ALLOWS | ALLOWS | promoted (full path in source) | **M-5 Medium** |
| D09 | Raffle::releaseSponsorProceeds (delivery decoupling) | 9 | ALLOWS | ALLOWS | ALLOWS | ALLOWS | 2 raw FINDINGs + 7 LEADs | **M-1 Medium** |
| D10 | Raffle::releaseSponsorProceeds (immutable recipient) | 1 | ALLOWS | BLOCKS | BLOCKS | ALLOWS | not promoted | Lead-4 |
| D11 | Raffle::releaseProtocolFees | 1 | ALLOWS | BLOCKS | BLOCKS | ALLOWS | not promoted | Lead-5 |
| D12 | Raffle::releaseSponsorPrize | 5 | ALLOWS | ALLOWS | BLOCKS | ALLOWS | demoted (G3 self-harm) | Lead-6 |
| D13 | Raffle::_update | 7 | ALLOWS | UNCERTAIN | ALLOWS | UNCERTAIN | promoted ([lenses: 7]) | **L-1 Low** |
| D14 | Raffle::fulfillRandomWords (reserve flip) | 4 | ALLOWS | ALLOWS | ALLOWS | UNCERTAIN | promoted ([lenses: 4]) | **L-2 Low** |
| D15 | Raffle::fulfillRandomWords (VRF preview) | 1 | ALLOWS | UNCERTAIN | ALLOWS | UNCERTAIN | not promoted | Lead-7 |

**Composite chain:** [L-2] + [M-1] (also L-3). This is annotated on those findings rather than reported separately, because the sponsor controls both legs.

## Result (native report: `evidence/native-report.md`)

**Findings: 0 High · 5 Medium · 3 Low · 0 Info · 7 unverified leads · 0 rejected.**

- **M-1** `Raffle::releaseSponsorProceeds()` releases the `NftWon` 95% without checking `prizeClaimed`; `releaseProtocolFees()` does the same with the 5%. If the prize stops transferring out of the clone, the winning-ticket holder gets nothing after the whole pot is paid out. [lenses: 9]
- **M-2** `Raffle::buyEntries()` lets the sponsor buy entries that come back 95% rebated, diluting buyers' odds on the NFT. [lenses: 1]
- **M-3** `Raffle::_settleWinningTicket()` computes the `NftWon` sponsor share over the gross pot, including entries the sponsor funded. [lenses: 3]
- **M-4** `Raffle::_settleWinningTicket()` books the `NftWon` split with no dependency on NFT delivery. This is the same family as M-1. [lenses: 2]
- **M-5** `Raffle::redeemWinningTicket()` has no fallback when `NftWon` prize delivery fails. This is the same family as M-1. [lenses: 1]
- **L-1** `Raffle::_update()` keeps tickets transferable while the VRF result is pending, so stale listings can be sniped. [lenses: 7]
- **L-2** `Raffle::fulfillRandomWords()` counts sponsor-funded entries toward the reserve, so the sponsor can flip `CashWon` to `NftWon`. [lenses: 4]
- **L-3** `Raffle::buyEntries()` lets the sponsor fill the reserve shortfall at about 5% net cost. [lenses: 2]
- **Unverified leads:** `RaffleFactory::createRaffle`, `Raffle::requestDraw`, `Raffle::enableRefunds`, `Raffle::releaseSponsorProceeds` (immutable recipient), `Raffle::releaseProtocolFees`, `Raffle::releaseSponsorPrize`, `Raffle::fulfillRandomWords`.

All twelve lenses' Last-User-Out tests found the USDC ledger exactly conserved, and no lens reported a missing decrement.

## Artifacts

| Artifact | Path | sha256 |
|---|---|---|
| Native report | `evidence/native-report.md` | `d4a0adaf00ecda7dbbb86267bd9613dfe634f78bc19e86c4ab6a2dfcb85750da` |
| Dedup ledger | `evidence/turn6/dedup-ledger.md` | `9aab0d68c582ee2e554f2237d7eef0df4dc6565323ee1cb228402f236a9b22b0` |
| Gate ledger | `evidence/turn6/gate-ledger.md` | `3a6aeeef04252b83d672b47b191fc973d26bdc0e9755f76292e0ee429957da4a` |
| Judgement data | `evidence/turn6/turn6-judgement-spec.json` | `2bda7a9094356f01eb22259318306d66060478a68d73c5f542ed0401e63cdbad` |
| Validated groups + checks | `evidence/turn6/turn6-groups.json` | `f4c9551e6547c080dfa8c77b33b1d6daec6dd800d23ff97e79251d018c232471` |
| Mechanical raw extraction | `evidence/turn6/raw-items.json` | `d6e8cf842c785886c33a6a61b8994e00108fecfaece5d08a6909c01496eacd5f` |
| Method stages | `METHOD-STAGES.json` | `1a04d35e6dac841e78ddd2e8879fe99d55c56c9195b2cde2263177e76cbce8af` |
| Stage ledger, attempt-02 | `evidence/ledger/attempt-02-stage-ledger.md` | `9e3d630b309b686ebc0794e469d6358ff7cf39956323e20293a1a00ebda48918` |
| Stage ledger, attempt-01 (unchanged) | `evidence/ledger/stage-ledger.md` | `f6dbe2d6404cba004b580cef52792f1535222ee6fd4b3168c68cad84c74bb374` |
| Turn 4 prompts | `evidence/ledger/turn4-prompts/lens-{1..12}-prompt.txt` + `turn4-prompt-appendix.txt` | (in METHOD-STAGES.json) |
| Preserved bundles + raw outputs | `evidence/native-preserved/` | hash list `evidence/ledger/native-preserved-hashes.sha256` |

## Deviations (all disclosed)

1. **Public-evidence variant.** No private reasoning was requested or evaluated.
2. **Model selection.** Turn 1b was skipped. The user pinned the lens model and effort to Opus 5.5 at max.
3. **Foreground Turn 4.** Lenses ran in the foreground (`run_in_background=false`) instead of in the background, after the attempt-01 background children were killed. This changed runtime waiting only.
4. **Prompt appendix.** An engagement-constraints appendix and a preservation write were added to the verbatim native prompt template. `{bundle_dir}` was given as an absolute path.
5. **Raw output location.** Each lens wrote its raw output inside the workspace as its last action. Independence was enforced by instruction and timing; the lens transcripts were not audited.
6. **Fresh context for Turn 6.** The money map and source were re-read for Turn 6.
7. **Gated leads kept.** Promoted leads that failed a gate were kept as surviving leads. This is required by the mandatory completeness gate.
8. **Report output.** The report was written to a file, as requested; the chat print is condensed.
9. **Auto-clean.** The auto-clean was denied, so the bundle dir was retained. A verified exact copy is preserved.

## Constraints observed

- Source, build and lock bytes are unchanged (43/43, final check).
- No remediation, deployment, live RPC, transactions, credentials, purchases or messages.
- Reads were limited to this workspace and the trusted plugin resources.
