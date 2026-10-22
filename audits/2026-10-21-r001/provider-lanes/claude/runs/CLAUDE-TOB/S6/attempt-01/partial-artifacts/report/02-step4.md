
---

## Step 4: Security properties and testing

### 4.1 Documented security properties

All 32 properties derive from `DESIGN.md` plus the `IRaffle`/`IRaffleFactory` natspec. "Verified by" names the executable artifact(s):
- **I#**: global invariant in `RaffleHandler.checkInvariants`, checked by Echidna and Foundry.
- **model**: per-action oracle inside the handler (expected success or revert plus post-state).
- **A1–H6**: deterministic or fuzz test.
- **C#**: custom Slither check.

| ID | Property | Spec source | Verified by | Result |
|---|---|---|---|---|
| **State machine and lifecycle** | | | | |
| P1 | Only the transitions in the state diagram occur; `NftWon`, `CashWon`, and `Refunding` are terminal | lifecycle | model (all actions), I4, C4 | Holds |
| P2 | A clone is initialized exactly once, by the factory, atomically with escrow; the implementation is locked and inert | "immutable implementation", no admin | E1, E2, I10, `reinitialize` action | Holds |
| P3 | One VRF request per raffle. Foreign-id, wrong-length, late, replayed, and synchronous callbacks are ignored and never revert | "Callback records result only" | C1, C2, `fulfill` / `fulfillWrong` actions | Holds |
| P4 | Only the VRF wrapper can deliver randomness | trusted wrapper | C3 | Holds |
| **Timing** | | | | |
| P5 | Entries can be bought only while `now < endTime` | sale window | A1, `buy` model | Holds |
| P6 | Draw request only in `[endTime, endTime+2d)`, with ≥1 entry and a sufficient fee | "Request window [sale end, end+2days)" | A2, C6, `requestDraw` model | Holds |
| P7 | Callback accepted iff `now < drawRequestedAt + 2d` | "callback accepted strictly before request timestamp+2days" | A4, `fulfill` model | Holds |
| P8 | With entries, refunds open exactly at `endTime+2d` (no request) or `drawRequestedAt+2d` (pending request), and the windows never overlap | "Refunds open at deadline" | A3, A4, `enableRefunds` model | Holds |
| **Accounting** | | | | |
| P9 | Exact backing: `USDC.balanceOf(raffle) == accountedQuoteBalance() + unsolicited donations` | solvency | I1 | Holds |
| P10 | Conservation: lifetime inflows − outflows == `accountedQuoteBalance()` | "without loss" | I3 | Holds |
| P11 | `grossSales() == Σ purchases == totalEntries × 1,000,000` | "One entry costs 1,000,000 units" | I2, `buy` model | Holds |
| P12 | Liability buckets match status: open → only `unsettledPot`; `Refunding` → only refund liability; resolved → pot until settlement, then fee/sponsor/winner | lifecycle accounting | I4 | Holds |
| P13 | Settlement: fee = ⌊5% of gross⌋; `NftWon` sponsor 95%; `CashWon` winner 80% and sponsor 15%; sum = gross (no dust) | outcome splits, rounding rule | B1 (2,000 runs), settle model, M03 and M09 killed | Holds (proof below) |
| P14 | Refund = entries × 1e6; remaining liability == value of unrefunded tickets | "Refund outcome pays 100% per entry" | B2, I7, `refund` model | Holds |
| P15 | Entry arithmetic is safe up to `type(uint128).max` entries; overflow reverts cleanly | uint128 ranges | B3 | Holds |
| P16 | No ETH is retained; the excess fee is refunded; a failed refund reverts the request | native payment | I9, C5, C6 | Holds |
| **Ticket model** | | | | |
| P17 | Ticket ids are sequential; ranges are contiguous, disjoint, and exactly cover `[1, totalEntries]` | "contiguous inclusive range" | I7, `buy` model, M06 killed | Holds |
| P18 | Exactly one live ticket contains `winningEntry ∈ [1, totalEntries]`; `NftWon ⇔ totalEntries ≥ reserveEntries` | "Reserve met awards NFT" | I6, `fulfill` model, M09 killed | Holds |
| P19 | Refunded and redeemed tickets are burned; duplicate or foreign ids revert the whole batch | "burns claim atomically" | I7, B4, `refundDuplicate`, M04 killed | Holds |
| **Access control** | | | | |
| P20 | Only the *current* ticket owner can redeem or refund (approved operators cannot) | "redemption requires current ticket owner" | D1, B4, `redeem` / `refund` models, M07 killed | Holds |
| P21 | Settlement and releases are permissionless but pay only the fixed recipients | "Settlement is permissionless" | release models, I3 | Holds |
| P22 | Per-raffle configuration is write-once; the factory has no privileged or config entry point | "No administrator, mutable configuration" | C5, C6 | Holds |
| P23 | Empty raffle: the sponsor may cancel at any time, anyone from `endTime` (documented behavior only) | natspec (not in `DESIGN.md`) | G5, `enableRefunds` model | Holds as implemented; **spec gap (TOB‑S6‑4)** |
| **Custody** | | | | |
| P24 | The prize stays in escrow until exactly one claim: winner (`NftWon`) or `sponsorRecipient` (`CashWon` / `Refunding`) | outcome rules | I8, M05 and M11 killed | Holds |
| P25 | Escrow at creation is atomic and verified; a non-compliant prize is rejected | "escrowed atomically at creation" | H4, `createRaffle` model | Holds for honest ERC‑721s (see P31) |
| P26 | A delivery failure reverts every redemption effect, including inline settlement | "must revert all effects on delivery failure" | D2 | Holds |
| P27 | Assets never move between raffle clones: tickets, USDC, and the NFT are never owned by or paid to a registered raffle | "Never move assets between raffle clones" | I11, E4, `transferTicketToProtocol` | **Violated for not-yet-deployed clone addresses (TOB‑S6‑1, PoCs G1, G2)** |
| **External interactions** | | | | |
| P28 | Every state-changing entry point reachable from untrusted callbacks is `nonReentrant`, and re-entry is blocked | untrusted prizes and recipients | C1, F1, F2 | Holds |
| P29 | The VRF callback never reverts and stays far below the 300k gas limit | liveness | C2, C4, gas probe (23,652 gas cold) | Holds |
| P30 | USDC pause or blocklisting only delays flows; one party's blocklisting does not block others' claims | "claim independently" | D3, `toggleUsdcPaused` model | Holds (immutable-recipient caveat: TOB‑S6‑5) |
| P31 | A prize contract cannot affect other raffles or protocol state | "arbitrary prize contracts … are untrusted" | F2, model with frozen NFT | Holds across raffles; **within its own raffle a prize can deny or fake delivery (TOB‑S6‑3, PoCs G4, H5)** |
| **Standards** | | | | |
| P32 | The ticket conforms to ERC‑721 / ERC‑165; the quote token has exactly 6 decimals | ERC‑721 ticket, "six-decimal USDC" | `slither-check-erc`, H1 | Holds |

**Hand proof of P13 (substitute for symbolic verification).**
- `unsettledPot` only ever increases by `entryCount × 1,000,000` (`Raffle.sol:223,233`), so at settlement `gross = 10^6·N` with `1 ≤ N < 2^128`.
- Then `fee = ⌊10^6·N·500/10^4⌋ = 5·10^4·N` exactly, and `cash = ⌊10^6·N·8000/10^4⌋ = 8·10^5·N` exactly.
- So `sponsor = gross − fee − cash = 1.5·10^5·N` (`CashWon`), or `9.5·10^5·N` with `cash = 0` (`NftWon`).
- No rounding ever occurs. Hence the floor rule and the "remainder allocated without loss" rule hold trivially. `Math.mulDiv` cannot overflow because `10^6·N·8000 < 2^256`.
- B1 fuzzes `N ∈ [1, 10^12]` across both outcomes; B3 checks `N = 2^128−1`.

### 4.2 Testing infrastructure (built for this engagement, entirely outside `packages/`)

| Component | Path (under `tob-s6-artifacts/harness/`) | Purpose |
|---|---|---|
| Mocks | `src/mocks/MockUSDC.sol`, `MockVRFV2PlusWrapper.sol`, `MockPrizeNFT.sol`, `Actor.sol` | Six-decimal USDC with pause and blocklist; a VRF wrapper that delivers callbacks with exactly `callbackGasLimit` gas, as `VRFV2PlusWrapper._callWithExactGas` does, and can also call back synchronously, with wrong ids, or with wrong lengths; a freezable ERC‑721 prize; user proxies |
| Reference-model handler | `src/RaffleHandler.sol` | 22 actions, including multi-raffle creation, time warps, donations, and failure-mode toggles. Each action predicts success or revert from the spec, executes through an `Actor`, records any mismatch as a violation, and checks the post-state. `checkInvariants()` holds global invariants I1–I12. |
| Echidna entry points | `src/echidna/EchidnaRaffle.sol` | `EchidnaRaffle` exposes properties `echidna_no_spec_violation` and `echidna_global_invariants`. `EchidnaRaffleCanaries` holds 11 reachability canaries. |
| Echidna config | `echidna/echidna-final.yaml` (profile A), `echidna/echidna-final-B.yaml` (profile B) | property mode; `seqLen` 120; 4 workers; `deployContracts` to stay under the EIP‑3860 initcode limit; solc mode with project-identical compiler settings |
| Foundry invariant + canaries | `test/RaffleInvariant.t.sol`, `test/RaffleCanary.t.sol` | Same handler, Foundry `invariant_*` (`fail_on_revert = false`; violations are recorded, so reverts cannot hide them) |
| Unit, fuzz, and PoC tests | `test/RaffleUnit.t.sol` (A–G), `test/RaffleValidation.t.sol` (H), `test/HandlerSanity.t.sol`; probes in `../gas-probe/test/` | 40 + 5 tests: timing boundaries, economics, VRF, redemption, access control, reentrancy, finding PoCs, validation paths, oracle sanity |
| Custom Slither checks | `../bin/raffle_slither_checks.py` | C1–C8 project-specific checks (Section 4.6) |
| Mutation analysis | `../bin/make_mutants.py`, `../bin/run_mutants.sh` | 12 single-point specification violations in a *copy* of `Raffle.sol` |

**Validating the harness itself.** A fuzzing campaign with no failures is only meaningful if the oracle is not vacuous. Four checks address that:
1. **Sanity tests** drive the handler through complete `CashWon`, `NftWon`, refund-timeout, empty-raffle, and failure-mode lifecycles. They require zero violations *and* that each branch counter is hit.
2. **Reachability canaries** are properties expected to *fail*. Falsifying them proves the fuzzer reaches every deep state. Echidna and Foundry each falsified all of theirs (Section 4.3).
3. **Mutation analysis** checks that the suite detects injected bugs (Section 4.5).
4. **Harness defects found and fixed during validation** (each affected only the harness, never the contracts):
   - The handler's 78.5 KB initcode exceeded the EIP‑3860 limit enforced by Echidna; I moved the factory deployment into a pre-deployed `FactoryDeployer`.
   - A refund caller that rarely owned tickets left the refund path unreached (Foundry canary not falsified); I targeted it at ticket owners.
   - With 3‑day random time jumps (`maxTimeDelay: 259200`), Echidna overshot the 2‑day windows and reached only 6 of 11 canaries in 300k calls. Profile A uses 12 h, which reached all 11 within 38,535 calls.
   - The first final Foundry run reported `reverts: 1` (1 of 13,603 `refund` calls). The cause was an arithmetic overflow in the harness's owner-targeting index, `callerSeed + k` with `callerSeed = 2^256−1`; it is reproduced as `Panic(0x11)` in `gas-probe/test/HandlerRevertRepro.t.sol` (Appendix F.7) and involves no protocol code. A reverted handler call changes no state, and both invariants are still checked on every reached state, so no property check was weakened. I fixed it by taking the modulo first, then re-ran the final Foundry campaign. Echidna profile A and the mutation analysis ran on the pre-fix handler; profile B and the repeated final Foundry run use the fixed one.

### 4.3 Fuzzing results
{{FUZZ_RESULTS}}

### 4.4 Deterministic, fuzz, and PoC tests

All 40 harness tests pass (`forge test --no-match-contract "RaffleInvariantTest|RaffleCanaryTest"`; raw output in Appendix F.1). Five protocol probe tests and one harness regression test in a separate project (`tob-s6-artifacts/gas-probe/`) also pass (Appendix F.6). The six `G_FindingsTest` PoCs, `test_H5`, and probe P1 *demonstrate* findings: each asserts the problematic behavior exists.

| Group | Tests | What is asserted |
|---|---|---|
| A: timing | A1–A4 | Exact `t−1` / `t` boundaries for sale end, request window, refund opening, and callback deadline |
| B: economics | B1 (fuzz, 2,000 runs), B2 (fuzz, 2,000 runs), B3, B4 | Exact 95/5 and 80/15/5 splits with no dust; 100% refunds; prize return; uint128 extremes; batch bounds, duplicates, foreign ids |
| C: VRF | C1–C6 | Synchronous callback ignored; wrong id, length, or replay ignored without reverting; wrapper-only delivery; callback gas; excess-fee refund and refund-failure atomicity; insufficient fee |
| D: redemption | D1–D4 | Current-owner-only redemption; delivery failure reverts burn and inline settlement; independent claims under blocklisting; wrong-ticket settlement |
| E: access | E1–E4 | Locked implementation; no re-initialization; factory parameter validation; tickets cannot reach protocol plumbing |
| F: reentrancy | F1, F2 | A ticket recipient re-entering 9 entry points and a prize re-entering 5 are all blocked by `ReentrancyGuardReentrantCall` |
| G: finding PoCs | G1–G6 | TOB‑S6‑1 (×2), TOB‑S6‑2, TOB‑S6‑3, TOB‑S6‑4, TOB‑S6‑6 |
| H: validation | H1–H6 | Constructor validation; prize-as-sponsor rejection; unsolicited deposit rejection; escrow verification; lying-prize PoC (TOB‑S6‑3); double claims and wrong-state claims |
| Sanity | 4 | Oracle validation (Section 4.2) |
| Probes (separate project) | cold-gas probe, P1–P4 | Callback gas with cold storage (23,652); treasury-at-future-clone bricks the factory (TOB‑S6‑1 deployment variant); a silent no-op `transferFrom` is caught by the `ownerOf` check; missing or false ERC‑165 is rejected; an empty raffle forces non-sponsors to wait for `endTime` |

Coverage of the in-scope contracts by these 40 tests (`forge coverage --ir-minimum`, run in a byte-identical copy because `forge coverage` cannot resolve relative imports of sources outside the project root):

{{COVERAGE_TABLE}}

### 4.5 Mutation analysis

Each mutant is a copy of the in-scope sources with one specification-violating edit in `Raffle.sol`. The suite run against each is all deterministic and fuzz tests except the PoCs, plus the Foundry invariant campaign (120 runs × 100 depth per mutant). Every mutant project's compiler cache confirms that the *mutant* source was compiled.

{{MUTATION_TABLE}}

### 4.6 Custom Slither checks (business logic)

`tob-s6-artifacts/bin/raffle_slither_checks.py` uses the Slither API (raw output in Appendix D):

| Check | Result | Meaning |
|---|---|---|
| C1: every state-changing `Raffle` entry point with external calls is `nonReentrant` | PASS | Exemptions are justified: `initialize` (factory-only, static calls), `onERC721Received` and `rawFulfillRandomWords` (no external calls), and the ERC‑721 transfer functions (reach only factory views and the recipient hook) |
| C2: every outgoing USDC transfer goes through `_transferQuote` | PASS | The single site is `_transferQuote` (`L566`), whose callers are `redeemWinningTicket`, `refundTickets`, `releaseProtocolFees`, and `releaseSponsorProceeds`. The single incoming site is `buyEntries` (`L224`). |
| C3: every prize-NFT outflow re-screens its destination at transfer time | **FLAG** | `redeemWinningTicket@L334` and `releaseSponsorPrize@L404` lack the runtime screen. This is the root of TOB‑S6‑1. |
| C4: `status` writers are exactly constructor / `initialize` / `onERC721Received` / `requestDraw` / `enableRefunds` / `fulfillRandomWords` | PASS | |
| C5: per-raffle configuration is written only in `initialize` | PASS | |
| C6: the factory has exactly one state-changing entry point | PASS | `createRaffle` |
| C7: no `delegatecall`, `callcode`, or `selfdestruct` in the implementation | PASS | |
| C8: inventory of `block.timestamp` readers | info | `buyEntries`, `createRaffle`, `enableRefunds`, `fulfillRandomWords`, `requestDraw`: deadlines only |

### 4.7 Symbolic execution (Manticore)

Manticore, and Halmos as an alternative, are not available in this environment. As substitutes:
- P13 was proven by hand (Section 4.1);
- the time-window properties P5–P8 are pinned by exact boundary tests (A1–A4) and boundary mutants (M01, M02, M08);
- all properties were fuzzed statefully.

Recommendation: add Halmos `check_*` versions of P8, P13, P17, and P18 in CI. They are small, arithmetic, and state-local, which suits SMT solving.
