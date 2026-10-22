# Separate test-exposed handler quality and bounded mutation campaign

## Scope and provenance

This follow-up started at 2026-10-21 07:53:13 UTC, after SUP-A1's source-only first pass was sealed. It intentionally reads existing tests, handlers, the Echidna harness, the standalone Python model, and historical mutation **configuration/runner code**. It is not an independent blind review and does not replace or modify `SUP-A1/attempt-01/FIRST-PASS.md` or its seal. No peer review, historical finding report, scanner result, or historical mutation result was read.

Input tests and production sources were copied from `validation/packages/contracts` into the private scratch root:

`/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/mutation-quality`

Each mutant has its own copied `src`, `test`, configuration, `out`, and `cache`. Only dependency and forge-std directories are shared through symlinks and were used read-only. No production source in the original checkout, validation copy, clean context, or other frozen snapshot was mutated. The five production-file hashes in validation and clean context were checked before and after the campaign and are identical. All production edits described below exist only in the four explicitly named disposable mutants.

The four mutation semantics were independently selected and committed to the campaign script before historical mutation definitions were inspected. Some naturally overlap historical configuration categories; they were not selected from historical results. A delegation attempt found no free agent slot, so the review and experiments were completed locally.

## Observed results

The unchanged baseline passed **70 unit/fuzz/security tests and 9 stateful invariants**. The short mutation campaign used 128 fuzz cases per fuzz test and 64 invariant runs of depth 64. Fork tests, Hardhat/TypeScript tests, full Python model tests, and Echidna execution were not included.

| Disposable mutant | Exact change | Short existing invariant suite | Existing unit/fuzz/security suite | Final classification |
| --- | --- | --- | --- | --- |
| M1-fee-400 | Protocol fee 500 → 400 bps | Survived: 9/9 passed, exit 0 | Killed: 9 failures, exit 1 | Killed; also killed by extended invariants |
| M2-owner-check-removed | Remove current-owner caller check from winning-ticket redemption | Survived: 9/9 passed, exit 0 | Killed: 3 failures, exit 1 | Killed; invariant actor coverage gap |
| M3-request-deadline-inclusive | Request deadline comparison `>=` → `>` | Survived: 9/9 passed, exit 0 | Killed: 3 failures, exit 1 | Killed; invariant action filter masks boundary |
| M4-purchase-always-reverts | Revert every otherwise valid purchase before quote transfer | Survived: 9/9 passed, exit 0 | Killed: 59 failures, exit 1 | Killed; invariant vacuity demonstrated |

All four mutants compiled. **There were no invalid mutants, compiler failures, or timeouts in these 14 Forge commands.** Compiler unreachable-code warnings for M4 do not make it invalid: it compiled and its behavior was exercised. Surviving one bounded suite does not mean an equivalent mutant or a permanent survivor. The overall existing deterministic/fuzz/security selection killed all four; a four-mutant selection is not a comprehensive mutation score.

Additional, separately logged diagnostics:

- **M1 at 512 invariant runs / depth 64:** killed by `invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund` after 120 runs / 7,680 calls. The assertion was `960000 != 900000`. Other eight invariants passed. This demonstrates a reachable, valid economic oracle whose short campaign missed the settled branch.
- **M4 under `audit_strict`, bounded to 16 runs / depth 64:** all nine invariants still passed, reporting zero handler reverts. `fail_on_revert=true` cannot see failures caught inside the handler.
- **Guided diagnostic test calling the existing handler and existing economic invariant:** buy 3 entries → end sale → request → fulfill → settle. It passed on the baseline and failed on M1 (`480000 != 450000`). This is a new test-only diagnostic, clearly separate from the original existing-suite results, and is retained as `ReachabilityProbe.t.sol`.

Example existing killers are `testCashSettlementLeavesBearerClaimAndOwnerRedeemsOnce`, `testOwnerCanSettleAndRedeemAtomicallyButApprovedOperatorCannot`, `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines`, `testFuzzCashSplitAlwaysConservesEightyFifteenFive`, and the valid-purchase journey tests. Full failure lists, exact commands, and process exits are retained in the logs.

## Handler and property assessment

Source references in this section resolve under the scratch `base/` test copy unless explicitly identified as historical runner code. These are test-assurance findings, not newly discovered production vulnerabilities.

### 1. Swallowed failures and no-op steps create a demonstrated vacuity gap

`test/foundry/invariant/RaffleHandler.sol:61-72` catches every purchase revert without recording unexpected failure. Similar catch-all patterns exist at `124-126`, `157-159`, `167-169`, `188-192`, `208-211`, and `219-227`. Many actions also return before calling production when their precondition is not met. The suite checks upper bounds on terminal event counts (`RaffleInvariant.t.sol:75-84`), but no lower bound or coverage requirement establishes that a purchase, draw, settlement, redemption, or refund actually succeeded.

The decisive demonstration is M4: valid purchases are completely disabled, yet every invariant passes. The M4 log reports hundreds of `buy` selector calls and zero handler reverts; those numbers do not represent successful purchases. `audit_strict` also passes because catch blocks prevent underlying reverts from escaping to Foundry. Keeping liabilities, entries, and winning markers at zero satisfies several otherwise useful properties.

**Priority:** Highest test-quality improvement. Add attempted/succeeded/unexpected-revert counters by meaningful operation; assert success for actions whose independently derived preconditions say they should succeed. Keep explicitly invalid-action handlers separate and assert their exact expected failures. Require campaign-level evidence of successful cash/NFT/refund settlement and final drains. Do not require every random sequence to visit every branch, which would itself cause false failures; use seeded fixtures or grouped coverage requirements.

### 2. Multi-actor state exists, but adversarial caller authority is filtered out

The Foundry handler has two ticket holders, the handler and `alternateOwner`, and transfers between them (`RaffleHandler.sol:18`, `75-83`). However, buys always use the handler as payer and recipient (`68`); the alternate owner's funded balance/approval is unused for purchase selection. Redemption and refunds deliberately `vm.prank(owner)` (`187-188`, `207-208`), so the stateful actions never challenge those owner checks. The sponsor, original buyer, and initial recipient are the same handler (`RaffleInvariant.t.sol:34-50`). There is one raffle and one honest prize/token pair.

M2 surviving the invariant suite is therefore a structural coverage gap, not evidence that owner authorization is unimportant. Existing deterministic tests correctly kill it with nonowner and approved-operator calls. The stateful suite lacks former-owner/nonowner/operator claim attempts, independently selected payer/recipient pairs, mixed-owner refund batches, and simultaneous multi-raffle ownership interactions.

**Priority:** Add explicit unauthorized-action handlers with independent caller choice, plus assertions that claims remain live and balances/ownership unchanged after rejection. Preserve the positive owner path. Use separate sponsor, buyer, recipient, keeper, approved operator, outsider, and treasury identities where their roles matter.

### 3. Deadline prefilters prevent the stateful engine from testing forbidden requests

`RaffleHandler.sol:115-126` refuses to call `requestDraw` before sale end or at/after the request deadline. The deadline property at `RaffleInvariant.t.sol:119-131` could detect an accepted out-of-window request, but the handler never produces that call. M3 therefore survives. The analogous Echidna prefilter is at `test/echidna/RaffleEchidna.sol:67-75`.

The handler does provide useful exact time jumps to sale end, last request second, request deadline, callback deadline, and a far-future time (`RaffleHandler.sol:86-113`). Nevertheless, reaching a timestamp and then filtering the invalid operation is not equivalent to checking the contract rejects it. Existing unit tests at `test/foundry/unit/Raffle.t.sol:970-983` directly test equality and kill M3.

**Priority:** Add a separate deadline-probe action that deliberately calls before/at/after each boundary and asserts the independently expected outcome. Keep the valid-action filter for ordinary lifecycle exploration if desired.

### 4. Exact economic oracle is useful, but short-run branch reachability is weak

Foundry's 17 selectors include five time-jump operations (`RaffleInvariant.t.sol:53-70`). The setup uses reserve 50; a purchase adds at most 10 entries and the handler caps entries at 100 (`RaffleHandler.sol:13`, `61-66`). Early time jumps can end sales after few or no purchases, and early empty cancellation can terminate the scenario. A full economic check additionally requires request, valid fulfillment, and selection of the winning range for settlement.

The fee-mutant result demonstrates the distinction: the 64-run economic invariant passed despite a wrong nonzero fee in every settled outcome; a 512-run campaign reached the bad state at run 120. The guided test proved the same existing property immediately detects the wrong split once settlement is forced. This supports increasing and measuring meaningful path coverage, rather than claiming the oracle lacks exact fee checks.

**Priority:** Use multiple initial scenarios or staged handlers seeded with Active sold, Drawing, CashWon, NftWon, and Refunding states. Record branch success counts and keep boundary/transfer exploration after each seed. Separate terminal-drain actions can exercise the last claimant without depending on long random discovery chains.

### 5. Reference accounting is partly independent; some ghosts merely echo contract outputs

The Foundry branch-economic property hard-codes specification rates 500/8000/1500 (`RaffleInvariant.t.sol:148-170`) rather than importing mutable production fee constants. The fuzz split test independently computes expected values and checks actual recipient balance deltas (`test/foundry/fuzz/RaffleFuzz.t.sol:146-175`). This is a useful oracle, as M1 proves.

By contrast, `ghostGrossPaid` is the difference of the contract's own `grossSales()` values (`RaffleHandler.sol:67-70`), and payout ghosts add contract return values (`188-191`, `208-210`, `219-226`). The equality of grossSales to that ghost alone is not independent confirmation of payment. The separate quote-token balance identity at `RaffleInvariant.t.sol:134-145` supplies an important independent check, so the overall property is not purely self-referential.

**Priority:** Record intended purchase entries and price before the call; snapshot actual buyer/raffle/recipient quote balance deltas for successful operations; compare both to expected amounts. Keep the existing independent rate formulas. This makes a wrong return amount or coordinated ledger/reporting bug easier to distinguish from a real transfer failure.

### 6. Echidna has narrower actors and lacks an explicit per-beneficiary split property

The Echidna harness was inspected, not executed. All ticket purchases and claims are made by the harness contract. It has no ticket-transfer action or nonowner/operator action (`RaffleEchidna.sol:53-155`). Refunds are single-ticket only. The reserve-1 `RaffleNftEchidna` variant (`215-216`) is useful for making NFT outcomes easier to reach than the reserve-25 base variant.

Its accounting property (`171-176`) checks gross, summed liabilities, solvency, and total payouts. It does not check the 80/15/5 or 95/5 recipient split. A fee reduction compensated by a sponsor increase preserves those totals. This is a source-derived blind spot, not an observed Echidna survivor from this campaign. `echidna.yaml` allows time delays up to seven days, which can skip the two-day request window; there is no deliberate exact-boundary action in the harness. Empty cancellation and swallowed reverts also allow sequences with little economic activity.

**Priority:** Add explicit per-beneficiary allocation and paid-out ghosts, ticket transfer/adversarial actor helpers, action-success counters, and deterministic lifecycle seeds. Retain both reserve variants. Do not count external fuzz senders as different protocol actors when all underlying calls originate from the same harness.

### 7. Standalone Python model does not roll back rejected lazy redemption

`test/models/current_protocol_model.py:166-177` invokes `settle_winner` before checking the caller is the ticket owner. That method mutates the Python object at `155-163`; raising `ValueError` later does not undo the mutation. A read-only probe of the model showed:

| State | Before unauthorized call | After `ValueError("not owner")` |
| --- | ---: | ---: |
| settlement_complete | false | true |
| unsettled | 1,000,000 | 0 |
| sponsor_claim | 0 | 150,000 |
| treasury_claim | 0 | 50,000 |
| winner_cash | 0 | 800,000 |

The actual Solidity owner check is inside an EVM transaction; a rejected lazy redemption restores the in-call settlement. The production unit test `testOwnerCanSettleAndRedeemAtomicallyButApprovedOperatorCannot` explicitly checks that rollback (`Raffle.t.sol:803-825`) and passed on baseline. Thus this is a **reference-model semantic mismatch**, not a production rollback defect. The Python model's math uses separate `5 // 100` and `80 // 100` formulas (`27-37`), but the shown Python tests exercise the model itself, not a differential execution against Solidity.

**Priority:** Prevalidate every condition before mutating the model, or wrap modeled actions in explicit snapshot/restore semantics. Add a regression that compares the complete model state before and after every rejected action. Do not present successful standalone model tests as differential contract verification.

### 8. Historical mutation definitions need current-source applicability checks

After independently selecting/running this campaign, historical `audit/current-mutations.json` and `scripts/current_mutation.py` were inspected. Of 52 definitions, **11 have zero matches** in the frozen current production source: M-07, M-12, M-24, M-26, M-27, M-28, M-37, M-39, M-43, M-51, M-52. These are invalid definitions for this snapshot, not surviving or killed mutants. The remaining 41 had a unique textual match; their compilability or detection was not tested here.

The historical runner correctly checks unique occurrence and reports `invalid-definition` (`scripts/current_mutation.py:181-193`). Its generic classification treats any other nonzero subprocess exit as killed after checking two compiler-error strings (`43-47`). That can conflate infrastructure/runtime failures with assertion kills unless the logs are reviewed. The runner captures tails and has no subprocess timeout in its helper. Historical result files were not read, and no statement about historical detection scores is made.

**Priority:** Validate all definitions against the exact frozen snapshot first, preserve full logs/diffs, distinguish test assertion failure from compiler/tool/timeout failures, and report the denominator of valid mutants explicitly. This follow-up uses separate logs and a 150-second per-command limit (90 seconds for additional probes).

## Existing strengths and explicit limits

- Deterministic tests directly cover unauthorized redemption, approved operators, exact request/callback boundaries, current-owner transfers, delivery rollback, maximum entry bounds, duplicate/mixed-owner refund batches, adversarial callbacks/tokens, and independent proceeds release. The four selected regressions were caught without changing those tests.
- The stateful suite checks range partition, sequence IDs, balance solvency, exact branch splits, terminal markers, and prize custody. Its weaknesses here are action generation, independent activity evidence, and scenario reachability; the exact fee assertion is sound when visited.
- Default, CI, audit, strict, and release profiles use different run/depth settings. Results here are explicitly bounded; no claim is made that 64 runs represent the full configured release campaign or that a short survivor survives more exhaustive runs.
- `fail_on_revert=true` only changes treatment of reverts that escape the handler. It is not evidence that guarded financial calls succeeded.
- No production remediation or test-suite edit was made in the original/validation/clean trees. The only newly authored Solidity test is the disposable diagnostic probe, copied into this artifact directory.

## Reproduction and artifact map

The complete commands and environments are in `results.json`, `additional-probes-results.json`, and the first lines of each `.log`. The scripts below are copied from the scratch campaign into this directory:

- `run_mutations.py`: independently selected four mutations, isolated copies, baseline + eight mutant runs, exact diffs, exits, bounded timeouts, frozen-source checks.
- `additional_probes.py`: 512-run fee follow-up, strict no-purchase follow-up, baseline/fee guided probe.
- `context_probes.py`: historical definition applicability and the standalone Python-model rollback demonstration.
- `ReachabilityProbe.t.sol`: new diagnostic test source; distinct from original existing-suite results.
- `M1-*.diff` through `M4-*.diff`: exact production-source edits in disposable variants only.
- `baseline-*.log`, `M1-*.log` through `M4-*.log`, `base-guided-probe.log`: full Forge output with commands and exits in the adjacent JSON records.
- `historical-config-applicability.json`, `python-model-rollback-probe.json`: current-source configuration and model diagnostics.
- `frozen-input-hashes-before.json`, `frozen-input-hashes-after.json`: five-source-file identity checks for validation and clean context.
- `RESULTS-SUMMARY.json`: normalized killed/surviving/invalid/timeout classifications for this bounded experiment.

These test-exposed findings are supplementary assurance evidence and remain separate from the previously sealed independent source review.
