# Anthropic lane — tool campaigns (validation copy only)

- **Validation copy:** `RT/validation/snapshot`, extracted from `target.tar.gz` (sha256 `67d554df…6aae1d`). Dependencies were installed with pnpm 11.18.0 / node 22.23.2 using the frozen lockfile and an isolated store. Dependency hashes 31/31 OK, freeze files 435/435 OK.
- **Lane harness projects:** `RT/validation/claude-harness*`. Each holds byte-identical copies of the five production files with the frozen compiler profile (solc 0.8.36, cancun, optimizer 200, via_ir false). Sources are in `harness-src/`.
- **Raw outputs:** `tools/<CAMPAIGN>[-attempt-NN-reason]/` (command.txt, version.txt, output, exit.txt). Superseded attempts are kept, not deleted.
- **Caveat:** a bounded campaign that finds no counterexample is not a proof. A timeout is not a pass.

| Campaign | Version | Result | Status |
|---|---|---|---|
| Slither detectors + 7 printers | 0.11.6 / crytic-compile 0.4.2 | attempt-01 **invalid**: it auto-loaded the project `slither.config.json` and the `slither.db.json` triage DB (0 results). attempt-02 used an empty config and a fresh triage DB: **12 observations, all FP/intended** (below) | COMPLETE |
| Aderyn | 0.6.8 (release sha256 624c6652…) | 2 "high" groups (3 instances) + 6 low groups. **All FP/intended** (below) | COMPLETE |
| Foundry stateful invariants (lane) | forge 1.7.1 | attempt-01: `noFlags` failed because of a **harness bug** (it compared `winnerProceeds` after an atomic settle+redeem). Fixed. attempt-02: 9 properties pass at 512 runs×128 depth (65,536 calls each) and 2,000×256 (512,000 calls each), seeds 0x434c41554445 / 0x41554449545f, 0 reverts | COMPLETE (bounded) |
| Echidna (lane) | 2.3.3 | attempts 01–03: the deployment failed. Two causes: `balanceContract` funding a non-payable constructor (decisive), and the 51,776-byte initcode being over the EIP-3860 limit (fixed with a predeployed `LaneFactoryDeployer`). attempt-04: 9/9 passing over 606,812 calls, but coverage showed **no resolution** (7-day default time jumps outran the 2-day callback window), so the post-draw half was **vacuous**. attempt-05 (fuzz2 variant: handler pays the VRF fee; `maxTimeDelay` 3600): **9/9 passing, 330,205 calls, seed 20261021, 1,215 s**. Coverage reaches draw, resolve, settle, NFT and cash redeem, refunds and every release | COMPLETE (bounded) |
| Medusa (lane) | 1.5.1 (built from source, isolated GOPATH) | attempt-01: 9/9 passed, but lcov shows `requestDraw`/`fulfillRandomWords` **never executed** (vacuous for the draw phase). attempt-02 (fuzz2 variant, 900 s, 4 workers): **9/9 passed**. Line hits: requestDraw 3,803, resolution 1,603, settle 987, NFT redeem 453, cash redeem 275, refunds 1,155 | COMPLETE (bounded) |
| Halmos (lane symbolic) | 0.3.3, z3 4.12.6 / yices | attempt-01: the command never ran (shell quoting). attempt-02: **7 PASS** (callbackDeadline, enableRefundsFromDrawing, initializeOnlyFactory, redeemOnlyOwner, refundExact, requestDrawWindow, sponsorPrizeLocked), **2 TIMEOUT** (settlementSplit, winnerInRange; 600 s), 1 FAIL from a **harness bug** (`vm.assume(caller != wrapper)` ran before deployment). attempt-03: fulfillOnlyWrapper **PASS**, winnerInRangeFixedSizes (symbolic word, 3+5 entries) **PASS**, settlementSplit **TIMEOUT at 1,800 s** | PARTIAL; open proof obligations listed in the final report |
| SMTChecker (CHC) | solc 0.8.36 | attempt-01: no Horn solver. attempt-02: a z3 dylib on DYLD path was not used. attempt-03: z3 4.12.6 binary on PATH (SMT-LIB2 interface), CHC on Raffle + RaffleFactory, targets underflow/overflow/divByZero/assert/constantCondition/outOfBounds/balance, 120 s per query. **TIMEOUT**: still running after about 92 min (08:13Z–09:45Z), so the controller stopped it at the pre-set budget; standard-json returns nothing until completion, so there is **no CHC verdict** | TIMEOUT (3/3 setup attempts used) |
| Mutation (lane, hand-picked semantic) | lane script `mutate.py` | 24 mutants. Pass 1: **17/24 killed**. Pass 2 with 4 gap tests: **20/24**. Survivors: M10, M20, M22 (guards that other checks cover) and M21 (lane property gap; the project test covers it) | COMPLETE |
| Project Foundry suite | forge 1.7.1 | build OK. `forge test` (fork tests excluded, no RPC) **79/79**. FOUNDRY_PROFILE=ci **79/79**. `forge fmt --check src` OK (no rewrite). `forge snapshot --check` **61 OK**. Coverage Raffle 99.60% lines / 89.66% branches, Factory 100% / 94.44%. Sizes: Raffle runtime 15,947 B; Factory initcode 21,870 B | COMPLETE |
| Project Hardhat | hardhat 3.11.1 | compile OK (21 files, solc 0.8.36 cancun). `hardhat test nodejs` **22 passing** | COMPLETE |
| Dependency / supply chain | pnpm 11.18.0 audit | Every @openzeppelin advisory hits only transitive 4.7.3/4.8.3 copies under @chainlink > @arbitrum/nitro-contracts, which are not compiled. Others are web/tooling. See `tools/LANE-DEPENDENCIES/DISPOSITION.md` | COMPLETE |
| Fork / Anvil against real USDC + VRF | — | No RPC use was authorized or justified for this lane; the project's fork tests were excluded | NOT_RUN |
| Certora | — | Requires the hosted prover and a key; purchase is not authorized | NOT_RUN (unavailable) |
| Lane reproductions | forge 1.7.1 | `LaneReproTest` 6/6 PASS (RC1–RC5). `LaneGapTests` 4/4 PASS | COMPLETE |

Tools run *inside* harness cells (ToB S2–S6 Slither/Echidna/Foundry; Pashov/SUP scratch `forge`) are part of those cells' declared methods and are reported in `FIRST-PASS.md`, not here.

## Slither triage (attempt-02, 12 observations)
| # | Detector | Location | Disposition |
|---|---|---|---|
| 1 | events-maths | `Raffle.initialize` | Intended: the factory emits `RaffleCreated` with every parameter; the clone emits `PrizeDeposited` |
| 2–3 | calls-loop | `_isProtocolDestination` via `refundTickets→_burn→_update` | FP: on burns `to == address(0)` short-circuits before any external call (`Raffle.sol:498`); the batch is bounded at 100 |
| 4 | reentrancy-benign | `RaffleFactory.createRaffle` | Intended: `initialize` on a fresh trusted clone, `nonReentrant`, registry written before the untrusted prize call |
| 5–10 | timestamp | buy / request / refunds / fulfil / factory | Intended: day-scale windows; boundaries match DESIGN.md (Halmos/Foundry edge tests) |
| 11 | assembly | `requestDraw` native refund | Intended: memory-safe `call` with the result checked |
| 12 | naming-convention | `IRaffle.ENTRY_PRICE()` | Informational |

## Aderyn triage
| Detector | Location | Disposition |
|---|---|---|
| contract-locks-ether (H) | `Raffle` | FP: `requestDraw` forwards the price and refunds the excess; `receive` reverts; only forced ETH can remain (documented) |
| reentrancy-state-change (H) | `RaffleFactory` ctor :71, `createRaffle` :109 | FP/intended: `decimals()` read in the constructor; trusted fresh-clone `initialize` under `nonReentrant` |
| costly-loop / require-revert-in-loop | `refundTickets` :357 | Intended: all-or-nothing batch bounded at 100 |
| large-numeric-literal | `RaffleConstants` | Style |
| state-change-without-event | `initialize` | See Slither #1 |
| unchecked-return | `redeemWinningTicket` :315 | FP: the settled amount is re-read from storage (`winnerProceeds`) |
| uninitialized-local-variable | `refundTickets` :357 loop index | FP: zero default is intended |
