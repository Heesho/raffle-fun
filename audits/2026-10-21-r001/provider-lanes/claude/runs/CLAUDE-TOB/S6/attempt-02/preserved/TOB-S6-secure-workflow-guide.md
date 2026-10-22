# TOB-S6 — Secure Development Workflow Report: raffle.fun `packages/contracts`

```
=== SECURE DEVELOPMENT WORKFLOW REPORT ===
Project:   raffle.fun — immutable RaffleFactory + ERC-1167 Raffle clones (USDC entries, Chainlink VRF v2.5, ERC-721 prize)
Platform:  Solidity 0.8.36 · EVM Cancun · optimizer 200 runs · via_ir false · Ethereum
Scope:     packages/contracts (5 production files) + reachable OZ 5.6.1 / Chainlink 1.5.0 dependencies + DESIGN.md
Workflow:  Trail of Bits building-secure-contracts:secure-workflow-guide (5 steps), pinned commit 82fe822
Date:      2026-10-21 (UTC) · Stage S6, attempt-02 — separately declared POST-SEAL continuation work
```

The original first-pass seal is immutable and was not touched. This session did not read prior audits, reports, test
suites, other attempts or other provider lanes; it saw only this work directory's clean context.

---

## 0. Identity, scope, isolation, integrity

### 0.1 Run identity (`evidence/00-identity/identity.txt`)

| Item | Value |
|---|---|
| Session / subagent model | `claude-opus-5-5` (Opus 5.5), as declared by the system prompt. **No subagents were spawned** (the loaded skill does not ask for delegation). |
| Requested local effort | max |
| Applied server effort | **unknown** (not echoed by the provider or harness in this session) |
| Skill | `building-secure-contracts:secure-workflow-guide`, plugin v1.2.2, repo commit `82fe8226252622fa807643bdca1710901198553a`; SKILL.md `7c0e7fb4…3015`, WORKFLOW_STEPS.md `8b048011…9291`, EXAMPLE_REPORT.md `c55fb9e5…f340` |
| Tools | Slither 0.11.6, crytic-compile 0.4.2, solc 0.8.36+commit.8a079791 (local solc-select artifact, sha256 `d4abcf0b…129d`), Forge 1.7.1 (`4072e487`), Echidna 2.3.3, Medusa 1.5.1, Halmos 0.3.3 (yices/z3 in its venv), Graphviz 14.1.3 as WASM (`@viz-js/viz` 3.25.0, copied locally), macOS `sips` |
| Not available | Manticore (not installed; offline install impossible) → **substituted by Halmos** symbolic execution (disclosed). Native Graphviz `dot` (not installed) → WASM build. |
| Network / chain | None. No RPC, fork, deployment, purchase or external message. Echidna always ran with `--disable-onchain-sources`; Forge with `FOUNDRY_OFFLINE=true`. |

### 0.2 Scope (all five mandatory production files analyzed)

| File | sha256 | Analyzed by |
|---|---|---|
| `src/Raffle.sol` | `6e4c9779…8617` | Slither, printers, ERC/upgradeability checks, custom checks, all test campaigns, manual review |
| `src/RaffleFactory.sol` | `d0e62b34…2ace` | same |
| `src/interfaces/IRaffle.sol` | `a43ede9e…b2dd` | Slither (naming-convention result), printers, ERC check inheritance, manual review (NatSpec trust statements) |
| `src/interfaces/IRaffleFactory.sol` | `747d238e…03cf` | Slither, printers, manual review, used by all harnesses |
| `src/libraries/RaffleConstants.sol` | `0893f1a7…ed54b6` | Slither, printers, economics (fee/price constants), manual review |

Slither's human summary confirms "Total number of contracts in source files: 5", 710 SLOC, plus 31 dependency
contracts (`evidence/03-visual/supplementary/print-human-summary.stderr.txt`). Reachable dependencies: the 31 files
listed in `dependency-hashes.json` (all verified, see 0.4). `DESIGN.md` (sha256 `25b4248a…cbba1`) was used as the
specification.

### 0.3 Isolation — generated scratch paths (all clearly generated; none are inputs)

| Path | Purpose |
|---|---|
| `_generated/harness/` | Byte-identical copy of `foundry.toml`, `remappings.txt`, `package.json`, `src/`, `node_modules/` for Slither, the checks and the printers. Original `foundry.toml` copied unmodified; local solc and offline mode supplied through env vars. |
| `_generated/harness-upgradeability-model/` | Same copy plus a GENERATED Solidity model of the ERC-1167 runtime (compatibility experiment for `--proxy-name`). |
| `_generated/harness-slither-prop/` | Same copy for slither-prop runs (keeps its outputs out of the main harness). |
| `_generated/harness-props/` | Property-testing project: byte-identical production copies + GENERATED `props/` (mocks, actors, Echidna/Medusa harness, Foundry scenarios, Halmos checks) and a GENERATED `foundry.toml` mirroring the original compiler settings (0.8.36 / cancun / optimizer 200 / via_ir false). |
| `_generated/run-echidna-property/`, `run-echidna-assertion/`, `run-medusa/`, `run-halmos/` | Per-campaign copies of `harness-props` so parallel campaigns cannot race on build directories. |
| `_generated/slither-custom/` | Project-specific Slither Python API checks. |
| `_generated/bin/`, `_generated/tools/viz/`, `_generated/render-tmp/` | Helper scripts (evidence recorder `rec.sh`, parsers, renderers, integrity checks), the copied Graphviz WASM package and intermediate 2× SVGs. |

Every tool invocation was recorded with `_generated/bin/rec.sh` → `<name>.meta.txt` (cwd, UTC start/end, exact argv,
environment overrides, exit code, byte counts), `<name>.stdout.txt`, `<name>.stderr.txt`.

Files written outside this work directory (disclosed):
- transient diff manifests `/tmp/s6a2_*.txt` created by the helper scripts;
- Halmos's automatic timeout-query dumps in the macOS temp folder (`/var/folders/…/check_*-timeout`), copied verbatim into
  `evidence/04-properties/halmos-timeout-queries/`.

Beyond these, nothing outside the work directory was intentionally written; tool-internal caches in the user profile were not inspected. The original inputs inside the work directory are verified unchanged (§0.4). No provider refusal occurred during this session.

### 0.4 Source integrity verification

A baseline sha256 manifest of **all 43 pre-existing files** in the work directory was taken before any tool ran
(2026-10-21T18:05:12Z, `evidence/99-integrity/baseline-sha256-all-original-files.txt`), together with a full tree
listing. The same checks were re-run mid-campaign (`midrun-integrity-check.txt`) and after every tool had finished
(`final-integrity-check.txt`, 2026-10-21T22:28:39Z):

| Check | Result |
|---|---|
| All 43 original files vs baseline (sources, `foundry.toml`, `remappings.txt`, `package.json`, `hardhat.config.ts`, `node_modules`, `DESIGN.md`, `pnpm-lock.yaml`, `dependency-hashes.json`) | **byte-identical** — `final-vs-baseline.diff` is empty (0 bytes) |
| Original tree listing (74 entries) | **unchanged** — `final-tree-vs-baseline.diff` empty; no `out/`, `cache/`, `lib/` or other new paths in `packages/contracts` |
| `dependency-hashes.json` (31 dependency files) | 31/31 OK, 0 mismatches, 0 unlisted files (baseline and final) |
| Production sources + dependencies in all 8 scratch copies (`harness`, `harness-upgradeability-model`, `harness-slither-prop`, `harness-props`, `run-echidna-property`, `run-echidna-assertion`, `run-medusa`, `run-halmos`) | **byte-identical to the originals** (36 files each) |
| `packages/contracts/foundry.toml` | `0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50` (unchanged) |

Final sha256 of the five production files:

```
6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617  packages/contracts/src/Raffle.sol
d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace  packages/contracts/src/RaffleFactory.sol
a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd  packages/contracts/src/interfaces/IRaffle.sol
747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf  packages/contracts/src/interfaces/IRaffleFactory.sol
0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6  packages/contracts/src/libraries/RaffleConstants.sol
```

Compiler settings actually used, as confirmed from Forge build-info (`evidence/01-slither/01-forge-build.*`, `00-forge-config.*`):
solc 0.8.36, `evmVersion: cancun`, optimizer enabled with 200 runs, `viaIR: false`.

---

## Executive summary

The complete five-step workflow ran offline on all five mandatory production files, with every raw command and result
preserved. The original inputs stayed byte-identical: verified by hash at baseline, mid-run and at the end (§0.4).

- **Step 1 — Slither.** No High or Medium results in production code. All 14 Low/Informational results and the one
  inline-suppressed Medium are triaged with file:line and evidence. The `calls-loop` result is a false positive, proven at
  runtime. Dependency High/Medium results are known OpenZeppelin false positives or unreachable Chainlink code.
- **Step 2 — Special features.**
  - The ticket is **fully ERC-721/ERC-165 conformant**.
  - The ERC-1167 clone and one-shot initializer pattern passes the upgradeability checks (Informational only), including
    against a generated 1167 proxy model.
  - There is no upgrade path.
  - `slither-prop` does not apply (verified by search and by the tool); `token-integration-analyzer` is recommended.
- **Step 3 — Diagrams.** All three generated, rendered (SVG/PNG) and reviewed. They confirm clone-safe constructors,
  `nonReentrant` on every value-moving entry point, and only four authorization roles. A Slither printer defect was found
  and worked around.
- **Step 4 — Properties and testing.** 45 security properties are documented and encoded in runnable generated
  infrastructure. Within the bounds, **no property was violated**:
  - Echidna property and assertion modes (2 × 400k calls);
  - Medusa (3.1M calls);
  - 20 Foundry tests, including 2 × 2,000 full-domain fuzz runs;
  - 9 Halmos checks;
  - 12 custom Slither checks.

  Halmos verified 7 of 9 checks over all inputs within its bounds. The 2 arithmetic-heavy checks hit solver timeouts
  (unknown, no counterexample). Two follow-ups also ended undecided: z3 run directly on the saved queries (30 min each) and uint32-bounded variants (20 min each). These two properties therefore rest on the full-domain concrete fuzzing and the short hand derivation in 4.3, not on a symbolic result.
- **Step 5 — Manual review.** The core accounting and state machine held up. The material risks sit in the economic and
  trust model:
  - **S6-F5 (Medium):** a sponsor-controlled purchase just before `endTime` flips a cash raffle into an NFT raffle for
    about 5% of the reserve shortfall. Measured: the sponsor's USDC payout rises from 135 to 850 net, and buyers lose a
    720 USDC cash prize.
  - **S6-F2 (Medium):** sponsor proceeds don't depend on the NFT being deliverable. A sponsor-controlled or pausable
    collection lets the sponsor take 95% while the winner can never redeem.
  - **S6-F1 (Low):** tickets stay tradeable while the VRF answer is visible but not yet included.
  - **S6-F3 (Low):** escrow verification trusts the prize contract.
  - **S6-F4, S6-F6, S6-F7, S6-F8:** Informational.

**Bottom line:** no critical issue and no code-level fund-loss bug was found within the bounded analysis. Before
deployment, the project should settle the S6-F5 and S6-F2 design questions and decide on S6-F1 (see Action plan).

---

## Step 1 — Check for known security issues (Slither)

**Command (skill canonical):** `slither . --exclude-dependencies` in `_generated/harness`
(`evidence/01-slither/03-slither-canonical-exclude-dependencies.*`). Companion runs: JSON (`04-…json`), checklist (`07-…`),
`--show-ignored-findings` (`05-…json`), full run including dependencies (`06-…json`), per-detector summary (`08-…txt`),
detector list (`02-…`). Slither exit code 255 = "results present" (not a crash); 36 contracts × 102 detectors.

**Status: ✓ documented triages, no production High/Medium, no fix required by Slither results.**

| Impact | Production results | Verdicts |
|---|---|---|
| High | 0 | — |
| Medium | 0 (+1 inline-suppressed `reentrancy-no-eth`, triaged as justified) | — |
| Low | 11 — calls-loop ×2, events-maths ×1, reentrancy-benign ×2, timestamp ×6 | calls-loop: **false positive, proven at runtime**; timestamp: accepted (day-scale windows, exact DESIGN boundaries; one is a zero-sentinel FP); reentrancy-benign: accepted (trusted callees, `nonReentrant`, in-flight guard); events-maths: accepted (factory emits `RaffleCreated` in the same tx) |
| Informational | 3 — assembly, pragma, naming-convention | accepted (memory-safe zero-copy refund call; deps' pragmas; constant getter) |

Highlights of the triage (full table with IDs, lines and evidence: `evidence/01-slither/09-slither-triage.md`):

- **calls-loop (Raffle.sol:593-605 via `refundTickets → _burn → _update`)** — false positive: `_update` evaluates
  `to != address(0) && _isProtocolDestination(...)` (Raffle.sol:498) and burns pass `to == 0`. Proven at runtime with
  `vm.expectCall(..., count = 1)`: a 6-ticket refund queries the factory registry exactly once (from `_transferQuote`
  after the loop) — `test_callsLoop_isFalsePositive_registryQueriedOncePerRefundTx`.
- **reentrancy-benign (Raffle.sol:240-273)** — `vrfRequestId`/`_requestInFlight` written after the trusted wrapper
  call by design; a synchronous callback is neutralized by `_requestInFlight` (exercised by a mock wrapper mode in
  Foundry, Echidna and Medusa).
- **Suppressed reentrancy-no-eth (RaffleFactory.sol:108)** — justified: the unregistered clone is screened by
  `destination == address(this)`; the only untrusted non-view call (`prize.safeTransferFrom`) occurs after registration; `supportsInterface`/`ownerOf` are view interface calls (STATICCALL)
  (custom Slither check C10).
- **Dependencies:** OZ `Math.mulDiv` incorrect-exp/divide-before-multiply are known false positives; Chainlink
  `requestRandomness` unused-return is unreachable (Raffle only calls `requestRandomnessPayInNative` — source search).

---

## Step 2 — Check special features (only what applies)

Applicability decided from recorded source searches (`evidence/02-special-features/00-applicability-source-searches.txt`);
summary `evidence/02-special-features/09-step2-summary.md`.

| Feature | Applies? | Command / evidence | Result |
|---|---|---|---|
| Upgradeability | **Yes — ERC-1167 clones + custom `initialize`; no upgrade path** (no `delegatecall`/UUPS/ERC1967/Beacon/`selfdestruct` in src) | `slither-check-upgradeability . Raffle` (`04-check-upgradeability-Raffle-impl.*`, 8 detectors) | 2 Informational: `init-missing` (custom initializer, not OZ `Initializable`), `initialize-target` — both handled: factory initializes atomically (RaffleFactory.sol:106-121), `initialize` is factory-only/one-shot (Raffle.sol:176-179), implementation self-locks (Raffle.sol:164-165) |
| Proxy ↔ implementation | Yes | compatibility experiment with a GENERATED 1167 model: `--proxy-name MinimalProxyModel` (`05-…`, 12 detectors) | no function-id collision, no shadowing, no storage-order issues |
| ERC conformance | **Yes — the ticket is an ERC-721** | `slither-check-erc . Raffle --erc erc721` (`01-…`), `--erc erc165` (`02-…`) | **fully conformant** (all functions, return types, view-ness, events; JSON `erc-conformance: {}`) |
| ERC20 implementation / `slither-prop` | **No** (no ERC20 implemented; no Truffle) | `slither-prop` (`06-…`, `07-…`; solc-platform retry `08-…`) | tool verdict "Raffle is not ERC20 compliant" — non-applicability confirmed |
| Token integration | **Yes** — canonical USDC + arbitrary untrusted ERC-721 prizes; ticket integrated by marketplaces | skill: *recommend* `token-integration-analyzer` | **Recommended** (scope listed in 09-step2-summary.md); key integration risks surfaced in S6-F2/F3/F7/F8 |

---

## Step 3 — Visual security inspection

All three skill printers executed and rendered (review notes: `evidence/03-visual/09-diagram-review.md`).

| Diagram | Command | Visual output |
|---|---|---|
| Inheritance graph | `slither . --print inheritance-graph` (+ `--include-interfaces`) | `evidence/03-visual/png/inheritance-graph.png`, `png/inheritance-graph.include-interfaces.png` (+ SVG, DOT) |
| Function summary | `slither . --print function-summary` | `evidence/03-visual/png/function-summary-access-map.png` (derived from the printer + transitive interactions) |
| Variables & authorization | `slither . --print vars-and-auth` | `evidence/03-visual/png/vars-and-auth-map.png`, `png/factory-vars-and-auth-map.png` |

Supplementary: C3 linearization, storage layout, call graphs (`png/supplementary/`), entry points, modifiers, selectors.

**Tool defect found:** Slither 0.11.6 `inheritance_graph.py:111-113` draws `RaffleFactory → IRaffleFactory` (undeclared
node) and drops `RaffleFactory → ReentrancyGuard` when interfaces are hidden (visible in `png/inheritance-graph.png`).
The `--include-interfaces` variant, the text `inheritance` printer and `c3-linearization` are correct and were used.

**Review conclusions**
- Shallow hierarchy (concrete depth 3), unambiguous C3 order; overrides are `name/symbol` (pure constants), `_update`
  (destination screen), `fulfillRandomWords`. No shadowing.
- **Clone safety (revealed by the constructor order):** no constructor runs for clones; each constructor writes either
  immutables (shared through the implementation's code) or implementation-only storage that clones must not inherit
  (`initialized=true`, `status=Refunding`, dead ERC721 name strings, a reentrancy slot whose 0 value is safe). All clone
  state comes from the factory's atomic `initialize`.
- Every value-moving/untrusted-calling Raffle entry point is `nonReentrant`; the only roles are factory (init), VRF
  wrapper (callback), sponsor (close an EMPTY raffle) and ticket owners (redeem/refund).
- Two diagram-driven leads for Step 5: the transfer hook gates destinations but not lifecycle state (→ S6-F1), and
  sponsor proceeds are allocated/released independently of NFT deliverability (→ S6-F2); outcome type depends only on
  `totalEntries` vs `reserveEntries` (→ S6-F5).

---

## Step 4 — Document security properties and set up testing

### 4.1 Properties (independently derived)

Full catalogue with source anchors and test mapping: **`evidence/04-properties/00-security-properties.md`** —
12 state-machine (SM-1…12), 9 accounting (A-1…9), 5 ticket-ledger (T-1…5), 7 access-control (AC-1…7), 4 arithmetic
(AR-1…4), 5 external-interaction (EI-1…5) and 3 standards (ST-1…3) properties. Core invariants:

1. **Exact solvency/conservation:** `USDC.balanceOf(raffle) == accountedQuoteBalance() + donations` and
   `paidOut + accountedQuoteBalance() == totalEntries × 1e6` (accounting never reads balances).
2. **Lifecycle:** only `AwaitingPrize→Active→{Drawing|Refunding}`, `Drawing→{NftWon|CashWon|Refunding}`; terminal
   states absorbing; windows `[endTime, endTime+2d)` (request), `< drawRequestedAt+2d` (callback), refunds at the
   deadlines — disjoint at every boundary.
3. **Split exactness:** fee ⌊5%⌋, cash ⌊80%⌋, sponsor remainder; fee+cash+sponsor == gross; exact for 1e6-unit entries.
4. **Ticket ledger:** ranges partition `[1,totalEntries]`; refund liability = price × live entries; no ticket owned
   by protocol plumbing.
5. **Prize custody:** escrowed until exactly one release (winner in NftWon; `sponsorRecipient` in CashWon/Refunding).
6. **Callback liveness:** authenticated callbacks never revert, use ≪ 300k gas, and resolve only when valid.

### 4.2 Runnable testing infrastructure (generated, in `_generated/harness-props/`)

| Component | File(s) | Notes |
|---|---|---|
| Mocks | `props/mocks/MockUSDC.sol` (6-dec ERC-20 with flow counters + optional blocklist), `MockVRFWrapper.sol` (validates `ExtraArgsV1{nativePayment:true}` like the real `checkPaymentMode`, exact 300k callback gas, never bubbles consumer reverts, optional synchronous-callback mode), `MockPrizeNFTs.sol` (honest, pausable/admin, lying ERC-721s) | forge-std is not in the inputs → local cheatcode interfaces |
| Echidna/Medusa harness | `props/RaffleProperties.sol` (`RafflePropertiesHarness`, `RaffleAssertionHarness`), `props/Actor.sol` | Real factory + clones, 4 actor contracts, up to 2 raffles; 23 actions incl. adversarial ones (re-init, direct fulfill, spoofed prize hook, direct ETH, transfers to plumbing, duplicate/foreign/nonexistent refunds, wrong/late/duplicate VRF callbacks, donations, boundary warps); every action predicts the spec outcome before the call and checks success/revert agreement + postconditions; 9 global `echidna_*` invariants |
| Configs | `echidna-property.yaml`, `echidna-assertion.yaml`, `run-medusa/medusa.json` | fixed seeds; `codeSize` lifted only because the generated harness exceeds EIP-170 (production contracts are within limits: Raffle 15,947 B runtime, factory 21,870 B initcode) |
| Foundry suite | `props/foundry/RaffleScenarios.t.sol`, `RaffleEconomics.t.sol`, `HarnessReplay.t.sol` | lifecycles, exact timing boundaries, VRF edge cases, finding demonstrations, Slither-triage evidence, 2 fuzz tests (2,000 runs each) |
| Symbolic (Manticore substitute) | `props/halmos/RaffleSymbolic.t.sol`, `props/halmos/RaffleSymbolicBounded.t.sol` | 9 `check_*` properties with symbolic entry counts, timestamps, words, callers and destinations, plus 2 uint32-bounded variants of the arithmetic checks (separate experiment) |
| Custom Slither checks | `_generated/slither-custom/raffle_custom_checks.py` | 12 business-logic checks (C1–C12) |

Reproduce (from `_generated/harness-props`, with `FOUNDRY_SOLC=<local solc 0.8.36>` and `FOUNDRY_OFFLINE=true`):
`echidna . --contract RafflePropertiesHarness --config echidna-property.yaml --disable-onchain-sources`;
`echidna . --contract RaffleAssertionHarness --config echidna-assertion.yaml --disable-onchain-sources`;
`medusa fuzz --config medusa.json` (in a copy containing it); `forge test --match-path 'props/foundry/*' --code-size-limit 200000`;
`halmos --root . --contract RaffleSymbolicTest --function check --loop 3 --solver-timeout-assertion 600000`;
`<slither venv python> -I _generated/slither-custom/raffle_custom_checks.py <harness> <out.json>`.

### 4.3 Results (bounded evidence, not proofs)

| Campaign | Bound | Result | Raw evidence |
|---|---|---|---|
| Custom Slither checks (C1–C12) | static, all functions | **12/12 PASS**. A first run reported a C1 failure that was an artifact of the check itself (constructors counted as entry points), recorded and then fixed. | `evidence/04-properties/10-custom-slither-checks.*` (+ `-run1-constructor-artifact`) |
| Foundry scenarios + fuzz | 18 deterministic tests + 2 fuzz tests × 2,000 runs (full uint128 entry domain for the split) | **20/20 PASS** | `evidence/04-properties/33-forge-test-all-final.*`; F5 quantification `evidence/05-manual/10-forge-test-F5-economics.*` |
| Echidna — property mode (`RafflePropertiesHarness`) | 400,073 calls in 2,332 s, seqLen 100, seed 6206211 | **9/9 invariants passing**:<br>• `echidna_solvency_and_conservation`<br>• `echidna_status_bucket_shape`<br>• `echidna_ticket_ranges_partition`<br>• `echidna_refund_liability_matches_live_tickets`<br>• `echidna_prize_custody`<br>• `echidna_resolution_well_formed`<br>• `echidna_no_ticket_owned_by_protocol`<br>• `echidna_no_eth_and_inert_implementation`<br>• `echidna_no_action_violations`<br><br>27/27 depth probes executed. Harness hash per `30-…`; the later assertion-only constructor fix does not touch this contract. | `evidence/04-properties/40-echidna-campaign-property.*`, `43-echidna-property-depth-coverage.txt` |
| Echidna — assertion mode (`RaffleAssertionHarness`) | 400,047 calls in 797 s, seed 9917731 | **38/38 passing** (all 23 actions, the 14 public getters and the `AssertionFailed` event); 27/27 depth probes executed | `evidence/04-properties/41-echidna-campaign-assertion.*`, `42-echidna-assertion-depth-coverage.txt` |
| Medusa (`RaffleAssertionHarness`) | 30 min, 4 workers, 3,116,102 calls, 3,284 branches | **46/46 passed, 0 failed** (37 assertion tests + 9 property tests). Line coverage: Raffle.sol 243/262 (92.7%), RaffleFactory.sol 65/79 (82.3%); every Raffle.sol depth probe was hit ≥ 644 times, and the factory probes at lines 105 and 128 were hit 60,804 times each. | `evidence/04-properties/51-medusa-campaign.*`, `52-medusa-depth-coverage.txt`, `medusa-coverage/` |
| Halmos (Manticore substitute) | loop 3, yices, 600 s per assertion query | **7/9 PASS** with every path verified:<br>• `check_requestDraw_iff_inside_window`<br>• `check_enableRefunds_sold_iff_after_request_deadline`<br>• `check_enableRefunds_empty`<br>• `check_callback_window_and_refund_handoff`<br>• `check_redeem_only_current_owner`<br>• `check_ticket_transfer_destination_screen`<br>• `check_winning_entry_in_range`<br><br>**2/9 TIMEOUT** (solver "unknown", **no counterexample**): `check_split_exact_symbolic_entries` (70 paths, 2 queries) and `check_refund_conservation` (16 paths, 1 query). | `evidence/04-properties/60-halmos-symbolic.{meta,stdout,stderr}.txt`, `60-halmos-symbolic.json` (num_models = 0 for all), `halmos-timeout-queries/` |
| z3 re-solve of the 3 timed-out queries (separate experiment) | z3 4.12.6, 1,800 s per query, run directly on the saved SMT-LIB files | **all 3 `timeout`** (1,801 s each). Still undecided: the 256-bit `bvudiv`/`bvmul` equalities defeat both yices and z3 at these budgets. No counterexample. | `evidence/04-properties/62-z3-*.{meta,stdout,stderr}.txt` |
| Halmos uint32-bounded variants (separate experiment) | `check_split_exact_u32_entries`, `check_refund_conservation_u32`; yices, 1,200 s per assertion query | **both TIMEOUT** (64 and 17 paths; `num_models = 0`, no counterexample). Narrowing the inputs to 32 bits does not help: the bottleneck is the 256-bit `bvudiv`/`bvmul` circuitry, not the input width. | `evidence/04-properties/63-halmos-bounded-u32.{meta,stdout,stderr}.txt`, `63-halmos-bounded-u32.json`, `63-halmos-bounded-source-sha256.txt`, `halmos-timeout-queries/*u32*` (hashes in `64-halmos-timeout-queries-sha256.txt`) |

**Manual arithmetic argument for the two timed-out properties (reasoning, not tool output).**
- *Split (A-5).* With n entries, `gross = 10⁶·n` and n ≤ 2¹²⁸−1, so `gross·8000 < 2¹⁶¹` and `Math.mulDiv` takes its
  `high == 0` branch, returning the floor of the exact quotient:
  - `fee = ⌊10⁶·n·500/10⁴⌋ = 50,000·n` (exact);
  - `cash = ⌊10⁶·n·8000/10⁴⌋ = 800,000·n` (exact);
  - `sponsor = gross − fee − cash` = 950,000·n (NftWon) or 150,000·n (CashWon), with no residue and no underflow.
- *Refund conservation (A-4/A-7).* `enableRefunds` sets `remainingRefundLiability = unsettledPot = 10⁶·N`. Ticket ranges
  partition `[1,N]` (T-1, fuzz-verified), and each ticket can be refunded at most once because the refund burns it. So
  the total of all refunds is exactly `10⁶·N`; the checked subtraction can neither underflow nor leave a residue.

These match the concrete evidence:
- the full-domain Foundry fuzz test `testFuzz_settlementSplitExact_fullDomain` (2,000 runs over uint128);
- `testFuzz_refundConservation`;
- the Echidna/Medusa `buyHuge` and refund actions.

**Depth / non-vacuity.** Echidna's coverage files and Medusa's lcov show that every lifecycle branch probe was executed:
- settle-on-redeem, NFT delivery and cash delivery;
- WinningTicketMismatch;
- refund accumulation and liability decrement;
- the three `enableRefunds` branches;
- the excess-ETH refund;
- VRF resolution and ignored callbacks;
- both settlement splits;
- the `_transferQuote` screen and the registry query.

**Harness validation.** One Echidna counterexample appeared during a smoke run (`24-echidna-smoke3-property.*`). A
deterministic Foundry replay (`25-forge-replay-smoke3-before-fix.*`) identified the failing expectation as
`A-5 cash floor(80%) or 0`. When settlement runs inside `redeemWinningTicket`, the contract has already paid and zeroed
`winnerProceeds`, which the harness had not modeled. This was a **harness bug, not a production defect**: the
delivered-cash check passed. It was fixed (`26-forge-replay-smoke3-after-fix.*`) before the bounded campaigns. A first
assertion-campaign launch failed to deploy because the derived harness had a non-payable default constructor. The
failure is preserved as `41-…-attempt1-nonpayable-deploy-failure.*`; it was fixed and relaunched.

**Not triggered:** the defensive revert branches `PrizeDeliveryVerificationFailed` (Raffle.sol:335-336 and the
single-line check at 405, whose condition is evaluated but never true) and `PrizeEscrowVerificationFailed`
(RaffleFactory.sol:130, 133). They require a prize that moves the token but misreports `ownerOf`. The unreachable-with-a-consistent-wrapper `paidPrice > msg.value` branch (Raffle.sol:258) was not exercised
either: a real wrapper quotes from `tx.gasprice`, which is constant inside a transaction.

---

## Step 5 — Manual review areas

Recorded searches: `evidence/05-manual/00-step5-source-searches.txt`; full analysis tables:
`evidence/05-manual/01-manual-review.md`. Every non-applicability below was verified by search.

| Area | Verdict |
|---|---|
| **Privacy** | No on-chain secrets; all raffle state is intentionally public; randomness needs no user commit–reveal (VRF). The VRF answer is public one block before inclusion → S6-F1. |
| **Front-running / MEV** | Two real ordering risks: pending-VRF ticket trading (**S6-F1**) and the sponsor-controlled reserve flip at sale end (**S6-F5**). No price slippage (fixed price); odds/outcome slippage folded into S6-F5. Sponsor-cancel vs first-buyer race, permissionless draw/settle/release, `createRaffle` approvals: safe. |
| **Cryptography** | No weak randomness, signatures, `ecrecover`, `encodePacked` collisions (search + custom check C9). VRF v2.5 usage sound (wrapper-only callback, ignore-don't-revert, 30 confirmations, 1 word, native payment encoding validated). Modulo bias ≤ 2^-128. Predictable CREATE clone addresses enable **S6-F4**. |
| **DeFi** | No price oracle, no AMM/flash-loan surface (entries cannot be refunded within a transaction; accounting is balance-independent and donation-proof). Trusted-dependency liveness (USDC pause/blocklist, VRF wrapper availability) → **S6-F8**. Untrusted prize contracts → **S6-F2**, **S6-F3**. |

### Findings

| ID | Severity | Difficulty | Title | Demonstration |
|---|---|---|---|---|
| S6-F5 | **Medium** | Low | Reserve outcome can be flipped by a last-moment sponsor-controlled purchase at ~5% cost | `test_F5_sponsorSybilCrossesReserve_flipsOutcome` |
| S6-F2 | **Medium** | High | Sponsor proceeds are released independently of prize deliverability (prize-contract honesty is load-bearing) | `test_F2_sponsorControlledPrize_collectsProceeds_while_winnerCannotRedeem` |
| S6-F1 | Low | Medium | Tickets remain tradeable while the VRF answer is pending; the winner is knowable one block early | `test_F1_ticketsTradeableWhileDrawing_pendingWordDeterminesWinner` |
| S6-F3 | Low | Medium | Escrow verification trusts the prize contract (fake custody possible) | `test_F3_dishonestPrize_activatesRaffle_without_custody` |
| S6-F4 | Informational | High | Code-less (future-clone) addresses pass destination screening; NFT path lacks the runtime re-screen | `test_F4_…`, `test_F4b_…` |
| S6-F6 | Informational | — | Unredeemed claims and stray assets are locked forever (no deadline, no rescue) | source review |
| S6-F7 | Informational | — | All ticket collections share name/symbol and have no metadata (spoofable/indistinguishable) | source review |
| S6-F8 | Informational | — | Liveness depends on trusted USDC (pause/blocklist) and VRF wrapper availability; requester-paid VRF fee | `test_blocklistedParties_liveness` |

#### S6-F5 — Reserve outcome can be flipped by a last-moment sponsor-controlled purchase (Medium / Low)
*Where:* `Raffle.sol:521` (outcome = `totalEntries >= reserveEntries`), `Raffle.sol:543-544` (NftWon sponsor receives
`gross − fee`, i.e. 95% including its own purchases), `Raffle.sol:209-237` (anyone can buy until `endTime`).
*Issue:* Because 95% of any purchase flows back to the sponsor in NftWon, a sponsor (through any fresh address) can top
the raffle up to the reserve immediately before `endTime` at a net cost of 5% of the shortfall, converting a cash outcome
(sponsor 15% + keeps NFT; winner 80%) into an NFT outcome (sponsor 95%). Buyers committed under the cash expectation
cannot exit (no refunds before the deadlines).
*Measured:* reserve 1,000; buyers 900 USDC → baseline sponsor 135 USDC + NFT, winner 720 USDC. With a 100-entry
sponsor-controlled buy at `endTime − 1`: sponsor 950 USDC gross (850 net), flip cost 5 USDC, buyers' cash prize 0 (one buyer
gets the NFT). With NFT value V, the flip pays for the sponsor when 850 + 0.1·V > 135 + V, i.e. V < ≈794 USDC (≈715 USDC if its own 10% of entries never win the NFT back) — precisely the regime in which buyers are harmed.
*Recommendation:* Short term: disclose that the reserve is not binding against the sponsor and display the flip cost
(5% of the shortfall). Long term: redesign so crossing the reserve cannot be bought at the fee rate — e.g. fix the
outcome type at creation, or snapshot reserve status before a final no-sales window, or cap NftWon sponsor proceeds
relative to pre-cutoff sales — and document the residual sybil (shill-buying) risk of any reserve design.

#### S6-F2 — Sponsor proceeds are independent of prize deliverability (Medium / High)
*Where:* `Raffle.sol:304-306,533-558` (permissionless, storage-only settlement allocates 95% to the sponsor),
`Raffle.sol:375-382` (permissionless release), `Raffle.sol:329-337` (the only NFT delivery path, via the prize contract).
DESIGN.md calls prize contracts untrusted, while `IRaffle.sol:14-15` assumes "Supported prizes are honest".
*Issue:* If the prize collection can block or redirect transfers (sponsor-controlled, pausable, upgradeable, admin
transfer, blocklist), the winner can never redeem, yet anyone can settle and release the sponsor's 95%.
*Demonstrated:* sponsor deploys a pausable collection, reaches NftWon, pauses → redemption reverts; settlement + release
pay the sponsor 95 USDC of 100; the sponsor then admin-transfers the NFT back. Buyers receive nothing.
*Recommendation:* Short term: curated prize allowlist in the frontend (non-upgradeable, non-pausable, no admin
transfer/burn), consistent trust statement in DESIGN.md/NatSpec, explicit UI warning. Long term: consider gating NftWon
sponsor proceeds on successful delivery (`prizeClaimed`) with a documented fallback for unresponsive winners, accepting
the liveness trade-off.

#### S6-F1 — Tickets tradeable while the VRF answer is pending (Low / Medium)
*Where:* `Raffle.sol:497-502` (`_update` screens destinations only), `Raffle.sol:518` (deterministic word→entry).
*Issue:* The coordinator's fulfillment transaction reveals the word before inclusion; anyone can compute the winning
entry and, ahead of the fulfillment, buy the winning ticket from standing marketplace orders (or dump losing tickets into
standing bids). No protocol funds are at risk; secondary-market participants are.
*Recommendation:* Block non-burn ticket transfers while `status == Drawing` (no claim can be exercised in Drawing, so the
freeze costs little and lifts automatically at resolution or refund), or document this for marketplace integrators
(cancel/expire orders at `requestDraw`).

#### S6-F3 — Escrow verification trusts the prize contract (Low / Medium)
*Where:* `RaffleFactory.sol:127-134` (`ownerOf` + clone `status` checks), `Raffle.sol:416-431` (accepts the hook from
`msg.sender == prizeToken`). A dishonest ERC-721 can call the hook with the expected tuple and lie in `ownerOf`, producing
an `Active` raffle with no custody. *Recommendation:* same allowlist/UX controls as S6-F2; document that escrow
verification cannot be trustless for arbitrary prize contracts.

#### S6-F4 — Code-less future clone addresses pass destination screening (Informational / High)
*Where:* `Raffle.sol:602` (registry queried only when `code.length != 0`), `Raffle.sol:395-407` (`releaseSponsorPrize`
has no runtime re-screen, unlike `_transferQuote` at `Raffle.sol:564-567`), predictable CREATE clone addresses.
*Issue:* A sponsor can set `sponsorRecipient` to the factory's next clone address; after that clone exists, the prize is
moved into another raffle clone (stranded) — contrary to DESIGN.md "Never move assets between raffle clones" — and USDC
proceeds become unclaimable. Self-inflicted, but an invariant violation. *Recommendation:* re-screen the recipient in
`releaseSponsorPrize` exactly like `_transferQuote`; document the immutable-recipient consequence.

#### S6-F6 / S6-F7 / S6-F8 — Informational
- **S6-F6:** no redemption deadline and no rescue path (Raffle.sol:19-27, 409-411): a lost winning ticket locks the NFT
  or cash forever; unsolicited NFTs/USDC stay outside accounting. Document; intended bearer semantics.
- **S6-F7:** `name()`/`symbol()` constant for every clone and empty `tokenURI` (Raffle.sol:479-487): collections are
  indistinguishable and easy to spoof. Add metadata (raffleId, range, status) and require integrators to verify
  `factory.isRaffle(collection)`.
- **S6-F8:** USDC pause/blocklist can freeze a raffle's claims (blocklisted winners/refunders can move their ticket;
  immutable sponsor recipient/treasury cannot); VRF wrapper disablement/underfunding defers to refunds after timeouts;
  the `requestDraw` caller pays the VRF fee unreimbursed. Document and monitor.

---

## Action plan

No code issue requires an emergency fix: there are no production High/Medium Slither results, and no bounded campaign
violated an invariant. The priorities below are design decisions and hardening steps specific to raffle.fun. Effort
figures are rough engineering estimates.

### Critical (fix before deployment)
- *(none identified)*

### High priority — decide before deployment (design level)
1. **S6-F5 reserve flip.** Choose and implement a reserve design where crossing the reserve can't be bought at the 5% fee rate:
   - fix the outcome type at creation, or
   - snapshot reserve status before a final no-sales window, or
   - cap NftWon sponsor proceeds against pre-cutoff sales.

   Otherwise, disclose the flip cost in the product. Re-run the Step 4 suite afterwards.
   *Effort: 1–2 days design + 1–3 days code/tests.*
2. **S6-F2 / S6-F3 prize-contract trust.**
   - Reconcile DESIGN.md ("untrusted") with `IRaffle.sol:14-15` ("honest").
   - Ship a curated prize allowlist and warnings in the frontend.
   - Evaluate gating NftWon `sponsorProceeds` on `prizeClaimed`, with an explicit fallback.

   *Effort: 1–2 days docs/UI; 2–3 days if the contract option is taken.*
3. **S6-F1 pending-VRF trading.** Add a `status != Drawing` gate for non-burn transfers in `_update` (Raffle.sol:497-502), or publish
   marketplace guidance (cancel/expire orders at `requestDraw`). *Effort: 0.5 day + tests.*

### Medium priority — before an external audit / release candidate
4. **S6-F4.** Re-screen `sponsorRecipient` with `_isProtocolDestination` in `releaseSponsorPrize` (Raffle.sol:395-407),
   mirroring `_transferQuote`. *Effort: 0.5 day.*
5. **Adopt the generated Step 4 suite.** The clean context ships no tests. Port `props/` into the repository's `test/` tree and run it in CI:
   - Echidna/Medusa harness with its 9 invariants and 23 checked actions;
   - the 20 Foundry tests;
   - the 9 Halmos checks;
   - the 12 custom Slither checks.

   *Effort: 1–2 days.*
6. **Slither configuration.**
   - Add the `slither.config.json` that `package.json` references but that is absent, encoding the triage in `evidence/01-slither/09-slither-triage.md`.
   - Use `--include-interfaces` for inheritance graphs until the Slither 0.11.6 printer bug (`inheritance_graph.py:111-113`) is fixed upstream.

   *Effort: 0.5 day.*
7. **Longer and more realistic campaigns.**
   - Echidna/Medusa for ≥24 h on the saved corpus.
   - Halmos with larger solver budgets.
   - A fork test against the real Chainlink VRF v2.5 wrapper and canonical USDC. This needs RPC, which was not permitted here.

   *Effort: 1–2 days, mostly machine time.*

### Low priority
8. **S6-F7.** Add `tokenURI` metadata (raffleId, range, status) and document `factory.isRaffle` verification for integrators. *Effort: 0.5–1 day.*
9. **Slither events-maths.** Optionally emit a clone-local initialization event. *Effort: 0.25 day.*
10. **S6-F6 / S6-F8 runbooks.** Document:
    - no-rescue / no-deadline semantics;
    - USDC pause/blocklist effects;
    - VRF wrapper monitoring;
    - who pays for draws.

    *Effort: 0.5 day.*
11. **Token integration.** Run `token-integration-analyzer` (skill recommendation) on USDC and on the prize-collection allowlist policy. *Effort: 0.5–1 day.*

## Workflow checklist

- [x] **Step 1 — Slither:** canonical scan executed. 0 High / 0 Medium in production; all 14 Low/Informational results,
  the 1 suppressed result and the dependency High/Medium results are triaged, with runtime proof for the calls-loop false positive.
- [x] **Step 2 — Special features:**
  - upgradeability checks run on the clone implementation and on a generated 1167 proxy model;
  - ERC-721 and ERC-165 fully conformant;
  - `slither-prop` non-applicability confirmed by search and by the tool;
  - `token-integration-analyzer` recommended with scope.
- [x] **Step 3 — Visual inspection:** all three printers executed, rendered (SVG + PNG) and reviewed. Supplementary C3,
  layout and call graphs produced; Slither printer defect documented.
- [x] **Step 4 — Properties:** 45 properties documented. Runnable infrastructure built and executed:
  - Echidna in property and assertion modes, and Medusa;
  - Foundry scenarios and fuzzing;
  - Halmos;
  - 12 custom Slither checks.

  No violation found within bounds. Two Halmos arithmetic checks remain undecided after three solver attempts (yices, z3, and uint32-bounded), with no counterexample (see 4.3).
- [x] **Step 5 — Manual review:** privacy, front-running, cryptography and DeFi each analyzed, with recorded searches.
  8 findings (2 Medium, 2 Low, 4 Informational); the Medium and Low findings have executable demonstrations.
- [ ] **Project follow-up (open):** design decisions on S6-F5, S6-F2/F3 and S6-F1; S6-F4 hardening; CI adoption of the
  suite; longer campaigns and a fork test against the real wrapper and USDC.

## Per-step completion evidence

| Step | Skill requirement | Completion evidence (content checks, not just exit codes) |
|---|---|---|
| 1 | Run Slither; parse by severity; explain with file refs; recommend fixes; triage FPs | Canonical command output present: 36 contracts / 102 detectors / 14 results (`03-…stderr.txt` last line). JSON parsed into a per-detector table (`08-…`). Each of the 14 IDs triaged with file:line (`09-slither-triage.md`). The suppressed finding was surfaced and triaged (`05-…json`). The calls-loop FP has a runtime proof (`test_callsLoop_isFalsePositive_…` PASS in `33-…stdout.txt`). |
| 2 | Detect applicable features; run only applicable checks; verify N/A with searches | Recorded searches (`00-applicability-source-searches.txt` §A–§E). check-erc JSON `erc-conformance: {}` for ERC-721 and ERC-165. Upgradeability: 8 detectors on the implementation, 12 with the 1167 model, both 2 Informational. slither-prop's verdict "not ERC20 compliant" (`08-…stdout.txt`). Token-integration recommendation recorded (`09-step2-summary.md`). |
| 3 | Generate 3 diagrams (inheritance, function summary, vars-and-auth); review each | DOT files and printer text/JSON preserved. All 7 PNGs viewed in-session: inheritance canonical, inheritance with interfaces, function-summary access map, vars-and-auth map and factory vars-and-auth in `png/`, plus the 2 call graphs in `png/supplementary/`. The 4744×16448 Raffle call graph was checked for completeness at reduced scale; its full-resolution PNG and SVG are preserved. Review notes with findings in `09-diagram-review.md`. Printer defect reproduced from source (`inheritance_graph.py:111-113`). |
| 4 | Document properties; set up Echidna (and Manticore); custom Slither checks | `00-security-properties.md` (45 properties with anchors and test mapping). Harness sources hashed at campaign start (`30-…`, `32-…`). Smoke runs showed depth growth before the campaigns (`22–27-*`). Campaign results in 4.3 with raw logs. Depth-probe coverage files `42-`, `43-`, `52-`. Halmos JSON with per-check exit codes. Custom checks 12/12 PASS (`10-…stdout.txt`). |
| 5 | Analyze privacy, front-running, cryptography, DeFi; search the codebase; flag risks | `00-step5-source-searches.txt` (224 lines, every search recorded with its command); analysis tables in `01-manual-review.md`. Findings demonstrated by PASSing tests: F1, F2, F3, F4, F4b, F5, blocklist liveness. |
| Final | Project-specific action plan and checklist | "Action plan" and "Workflow checklist" above reference concrete file:line locations, findings and test names. |

## Remaining coverage limitations

1. **Bounded evidence, not proofs.** Every campaign was bounded: Echidna 2 × 400k calls, Medusa 30 minutes, Foundry
   fuzzing 2 × 2,000 runs, and Halmos with loop bound 3 and a 10-minute per-assertion solver budget (see 4.3 for each
   check's outcome). "No violation found" means none within those bounds. Two symbolic arithmetic checks (A-5 split, A-4/A-7 refund conservation) stayed **undecided** after yices (10 min), z3 (30 min) and uint32-bounded (20 min) attempts. They are supported only by concrete full-domain fuzzing and the hand derivation in 4.3.
2. **Mocked dependencies.** Canonical USDC (FiatTokenV2: upgradeable, pausable, blocklist), the real Chainlink
   VRFV2PlusWrapper/coordinator (gas-price quoting, subscription balance, proof verification, `_callWithExactGas`) and real
   NFT collections were represented by generated mocks. The mocks reproduce the observable interface and the paths the
   contracts depend on, including `checkPaymentMode` and non-bubbling callbacks, but not Chainlink's operational behavior.
   No fork or RPC test was possible (network prohibited).
3. **Harness bounds.** The fuzzing harness covers at most 2 raffles, 4 actor users, 1–25 entries per normal purchase
   (plus unbounded `buyHuge`), and refund batches of up to 8 owned IDs plus a corrupted ID. The 100-ticket batch cap and
   batches above 100 were not exercised by the fuzzers (the cap is a single source comparison at Raffle.sol:352). Time
   advances were capped at 12 h per transaction, plus explicit warps of up to 3 days and boundary warps.
4. **Manticore was not run.** It is not installed and cannot be installed offline; Halmos was used as the
   symbolic-execution substitute.
5. **Compiler binary authenticity.** The local solc 0.8.36 binary's sha256 and commit (`8a079791`) are recorded, but they
   could not be compared offline with the official release list.
6. **Tool limitations observed.**
   - Slither 0.11.6's inheritance-graph printer drops a real edge when interfaces are hidden (worked around and documented).
   - The function-summary printer's JSON omits the function tables, so these were parsed from the raw text output.
   - `forge build --sizes` exits 1 solely because of the generated harness's size.
7. **Out of scope or not provided.**
   - Frontend, deployment scripts (`ignition/` and `scripts/` are referenced in `package.json` but absent), `slither.config.json` (referenced, absent), and any off-chain keeper or indexer.
   - Economic analysis (S6-F5) quantifies one representative scenario under a rational-sponsor assumption.
   - `token-integration-analyzer` was recommended, not run, as the skill instructs.
8. **Timing semantics.** The analysis assumes Ethereum PoS slot timestamps. The behavior of the VRF fulfillment
   mempool (public vs private submission) is an external assumption underlying S6-F1.

## Evidence index

All paths are relative to this work directory. `*.meta.txt` holds the exact argv, cwd, environment overrides,
UTC timestamps and exit code; `*.stdout.txt` / `*.stderr.txt` hold the complete raw output.

| Area | Paths |
|---|---|
| Identity | `evidence/00-identity/identity.txt`, `run-start-utc.txt`, `viz-js-3.25.0-copied-files-sha256.txt` |
| Integrity | `evidence/99-integrity/`:<br>• baseline: `baseline-sha256-all-original-files.txt`, `baseline-tree-listing.txt`, `baseline-dependency-hash-verification.txt`<br>• copies and checks: `harness-copy-sha256.txt`, `midrun-integrity-check.txt`, `final-integrity-check.txt`<br>• final state: `final-sha256-all-original-files.txt`, `final-vs-baseline.diff`, `final-tree-vs-baseline.diff`, `final-dependency-hash-verification.txt` |
| Step 1 | `evidence/01-slither/`:<br>• compile and config: `00-forge-config.*`, `00-forge-remappings.*`, `01-forge-build.*`<br>• detector list: `02-slither-list-detectors.*`<br>• scans: `03-slither-canonical-exclude-dependencies.*`, `04-slither-exclude-deps(-json).*`, `05-slither-show-ignored(.json)`, `06-slither-full-including-deps(.json)`, `07-slither-checklist.*`<br>• analysis: `08-slither-json-summary.txt`, **`09-slither-triage.md`** |
| Step 2 | `evidence/02-special-features/`:<br>• `00-applicability-source-searches.txt`<br>• ERC checks: `01-check-erc-erc721-Raffle.*`, `02-check-erc-erc165-Raffle.*`<br>• upgradeability: `03-…list`, `04-check-upgradeability-Raffle-impl.*`, `05-check-upgradeability-Raffle-with-1167-proxy-model.*`<br>• slither-prop: `06-slither-prop-list-scenarios.*`, `07-slither-prop-Raffle.*`, `08-slither-prop-Raffle-solc-platform.*`<br>• **`09-step2-summary.md`** |
| Step 3 | `evidence/03-visual/`:<br>• printers: `01-print-inheritance-graph.*`, `02-print-function-summary.*`, `03-print-vars-and-auth.*`, `04-print-inheritance-graph-include-interfaces.*`, `05-print-inheritance-text.*`<br>• graphs: `inheritance-graph.dot`, `inheritance-graph.include-interfaces.dot`, `derived-dot/*.dot`<br>• parsed tables: `06-parsed-printer-tables.{json,md}`<br>• render/raster logs: `07…14-*` render and raster logs<br>• images: `rendered/*.svg`, **`png/*.png`**, `png/supplementary/*.png`, `png/superseded-quicklook-cropped/`<br>• `supplementary/print-*.{meta,stdout,stderr}.txt`, `supplementary/call-graph-dot/`<br>• **`09-diagram-review.md`** |
| Step 4 | `evidence/04-properties/`:<br>• **`00-security-properties.md`**<br>• custom checks: `10-custom-slither-checks(.json/-run1-constructor-artifact)`<br>• builds: `20-forge-build-harness*`, `21-…plain`<br>• smoke runs: `22–24,27-echidna-smoke*`<br>• replays: `25/26-forge-replay-smoke3-*`<br>• hashes: `30/32-harness-source-sha256-*`<br>• Foundry: `31-forge-test-scenarios-run1.*`, **`33-forge-test-all-final.*`**<br>• Echidna: **`40-echidna-campaign-property.*`**, **`41-echidna-campaign-assertion.*`** (+ `-attempt1-nonpayable-deploy-failure`), `42/43-*depth-coverage.txt`, `echidna-*-coverage/`<br>• Medusa: `50-medusa-init.*`, **`51-medusa-campaign.*`**, `medusa.json.used`<br>• Halmos: **`60-halmos-symbolic.*`**, `60-halmos-symbolic.json`, `halmos-timeout-queries/`<br>• symbolic follow-ups: `62-z3-split-q10.*`, `62-z3-split-q60.*`, `62-z3-refund-q14.*`, `63-halmos-bounded-u32.*` (+ `.json`, `-source-sha256.txt`), `64-halmos-timeout-queries-sha256.txt` |
| Step 5 | `evidence/05-manual/`: `00-step5-source-searches.txt`, **`01-manual-review.md`**, `10-forge-test-F5-economics.*` |
| Generated code | `_generated/harness-props/props/**` (test code, mocks, harnesses), `_generated/slither-custom/raffle_custom_checks.py`, `_generated/bin/*` (recorder, parsers, renderers, integrity scripts) |

---
Trail of Bits Secure Development Workflow (building-secure-contracts:secure-workflow-guide v1.2.2) — S6 attempt-02.
