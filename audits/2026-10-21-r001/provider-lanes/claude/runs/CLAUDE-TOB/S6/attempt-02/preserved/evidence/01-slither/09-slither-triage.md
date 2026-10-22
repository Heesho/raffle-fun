# Step 1 — Slither findings triage (raffle.fun, packages/contracts)

Canonical command (WORKFLOW_STEPS.md Step 1), run in the isolated byte-identical harness `_generated/harness`
(FOUNDRY_SOLC=solc 0.8.36 local binary, FOUNDRY_OFFLINE=true; Cancun, optimizer 200, via_ir=false):

    slither . --exclude-dependencies

Raw: `03-slither-canonical-exclude-dependencies.{meta,stdout,stderr}.txt` (exit 255 = "findings present", not a crash),
JSON: `04-slither-exclude-deps.json`, checklist: `07-slither-checklist.stdout.txt`, suppressed: `05-slither-show-ignored.json`,
including dependencies: `06-slither-full-including-deps.json`, summary: `08-slither-json-summary.txt`.
Result: 36 contracts analyzed with 102 detectors; **14 production results: 0 High, 0 Medium, 11 Low, 3 Informational.**

Verdict legend: **FP** false positive · **TP-benign** true pattern, no security impact · **TP-accepted** true, intentional
design with documented rationale. No production finding requires a code change.

| # | Detector (impact/conf.) | Location | Verdict | Triage rationale and evidence |
|---|---|---|---|---|
| 1 | events-maths (Low/Med) id 85cca564 | Raffle.sol:176-206 (`initialize` writes prizeTokenId/reserveEntries/endTime) | TP-accepted | Same transaction always emits `RaffleCreated` from the factory with every parameter (RaffleFactory.sol:136-147) and `PrizeDeposited` from the clone (Raffle.sol:429). Optional: emit a clone-local `Initialized` event for raffle-only indexers. |
| 2 | calls-loop (Low/Med) id 0d442678 | Raffle.sol:593-605 via refundTickets→_burn→_update | **FP** | `_update` evaluates `to != address(0) && _isProtocolDestination(...)` (Raffle.sol:498); burns pass `to == 0`, so the short-circuit skips every factory call inside the loop. Runtime proof: `test_callsLoop_isFalsePositive_registryQueriedOncePerRefundTx` asserts with `vm.expectCall(..., count=1)` that a 6-ticket refund queries `raffleImplementation()` and `isRaffle()` exactly once (from `_transferQuote` after the loop). Evidence: `../04-properties/33-forge-test-all-final.stdout.txt`. Even if reached, the callee is the trusted immutable factory (view). |
| 3 | calls-loop (Low/Med) id 283434d6 | Raffle.sol:603 (`isRaffle`) same path | **FP** | As #2. |
| 4 | reentrancy-benign (Low/Med) id 221acba9 | Raffle.sol:240-273 (`vrfRequestId`, `_requestInFlight` written after wrapper call) | TP-accepted | Wrapper is a trusted canonical dependency; `requestDraw` is `nonReentrant`; a synchronous callback during the call is deliberately neutralized by `_requestInFlight` (Raffle.sol:254,511). Exercised by `test_syncCallback_inFlightGuard_then_asyncResolution` and the Echidna/Medusa `toggleSyncCallback` mode (callback ignored, never reverts, later async word resolves). |
| 5 | reentrancy-benign (Low/Med) id 52208546 | RaffleFactory.sol:97-148 (`raffleById`, `idByRaffle` after `initialize`) | TP-benign | Callee is the fresh fixed-target clone (protocol code); `createRaffle` is `nonReentrant`; during `initialize` the clone only performs view calls back to the factory. Registration completes before the only untrusted non-view call (`prize.safeTransferFrom`, line 128; `supportsInterface`/`ownerOf` are STATICCALLs) — verified by custom Slither check C10 (`../04-properties/10-custom-slither-checks.stdout.txt`). |
| 6 | timestamp (Low/Med) id 15f6492c | Raffle.sol:276-301 (`enableRefunds`) | TP-accepted | Day-scale windows (2 days); PoS slot timestamps are not meaningfully manipulable. Boundaries match DESIGN.md exactly (refunds open AT the deadline). Proved for all t symbolically (`check_enableRefunds_*`) and at ±1 s (`test_refundPath_…`, `test_timingWindows_…`). |
| 7 | timestamp (Low/Med) id 6935b73f | RaffleFactory.sol:97-104 (endTime > now, ≤ 30 days) | TP-accepted | Creation-time bounds only. `test_factory_rejects_protocol_plumbing_and_bad_params` covers endTime==now and now+30d+1. |
| 8 | timestamp (Low/Med) id 97a32216 | Raffle.sol:509-524 (callback deadline) | TP-accepted | Callback accepted strictly before `drawRequestedAt + 2 days` (DESIGN.md). Symbolic `check_callback_window_and_refund_handoff`; Foundry boundary test. |
| 9 | timestamp (Low/Med) id 98eca243 | Raffle.sol:209-216 (sale end) | TP-accepted | Exclusive sale end; see SM-4. |
| 10 | timestamp (Low/Med) id 9ec05bc5 | Raffle.sol:463-465 (`drawRequestedAt != 0`) | **FP** | Sentinel comparison against zero, not a time comparison. |
| 11 | timestamp (Low/Med) id a49e42ba | Raffle.sol:240-247 (request window) | TP-accepted | `[endTime, endTime+2d)` exactly as DESIGN.md; symbolic `check_requestDraw_iff_inside_window`. |
| 12 | assembly (Info/High) id 90beae51 | Raffle.sol:266-268 | TP-accepted | Memory-safe `call` refunding excess VRF fee to `msg.sender` with zero return-data copy (no return-bomb); result checked; state already final; function `nonReentrant`. EI-4 exercised in all fuzz campaigns (`excess refunded`, `no ETH retained`). |
| 13 | pragma (Info/High) id a3415992 | all files | TP-accepted | Production files pin `0.8.36`; the different constraints come from OZ/Chainlink dependencies. |
| 14 | naming-convention (Info/High) id 206c18a5 | IRaffle.sol:396 `ENTRY_PRICE()` | TP-accepted | Constant-style getter of a public constant; intentional. |

## Inline-suppressed result (surfaced with `--show-ignored-findings`)

| Detector | Location | Verdict | Rationale |
|---|---|---|---|
| reentrancy-no-eth (Medium/Medium) | RaffleFactory.sol:97-148 (`isRaffle[raffle] = true` after `initialize`), suppressed by `// slither-disable-next-line reentrancy-no-eth` at RaffleFactory.sol:108 | TP-benign (suppression justified) | During `initialize` the not-yet-registered clone is protected by the `destination == address(this)` check (Raffle.sol:599), so the stale `isRaffle[raffle] == false` cannot be abused; the factory is `nonReentrant`; the only untrusted non-view prize call happens after registration (custom check C10). |

## Dependency-only results (`slither .` without `--exclude-dependencies`, 102 results total)

| Detector | Location | Verdict |
|---|---|---|
| incorrect-exp (High) | OZ `Math.mulDiv` `inverse = (3 * denominator) ^ 2` | FP — intentional XOR seed of the Newton–Raphson modular inverse. |
| divide-before-multiply ×9 (Medium) | OZ `Math.mulDiv` / `Math.invMod` | FP — intentional 512-bit algorithm steps. Production calls only take the `high == 0` path (gross < 2^157). |
| unused-return (Medium) | Chainlink `VRFV2PlusWrapperConsumerBase.requestRandomness` (LINK `transferAndCall`) | Not reachable — Raffle calls only `requestRandomnessPayInNative` (source search `../02-special-features/00-applicability-source-searches.txt` §D). |
| assembly ×53, naming-convention ×9, solc-version ×7, too-many-digits ×8 (Info) | OZ/Chainlink libraries | Informational, dependency code, no action. |

Goal check (skill Step 1 "Clean Slither report or documented triages"): **met — all 14 production results, the 1
suppressed result and all dependency High/Medium results are triaged above; none requires a fix.**
