# Trail of Bits 5-Step Secure Development Workflow Report (`raffle-fun`)

**Project**: `raffle-fun` (`packages/contracts` & `DESIGN.md`)  
**Skill Executed**: `secure-workflow-guide` (`.agents/skills/secure-workflow-guide/SKILL.md` & `resources/WORKFLOW_STEPS.md`)  
**Solidity Compiler**: `solc 0.8.36` (exact version across all 5 owned source files)  
**Stage**: S6 Whole-Stage Native Execution  

---

## Executive Summary

We executed the complete 5-step Trail of Bits **Secure Workflow Guide** end-to-end on the frozen `raffle-fun` smart contract codebase (`packages/contracts` and `DESIGN.md`). All 43 pristine project inputs (5 owned Solidity files, 31 local dependency Solidity files, `DESIGN.md`, `dependency-hashes.json`, and 4 package/build configuration files including `packages/contracts/foundry.toml`) and all 5 skill resource files were preserved completely unmodified (verified via SHA-256 checksums before and after execution). All tool runs, diagrams, harnesses, and test suites were executed in isolated working directories under `scratch/`.

### High-Level Workflow Results

| Workflow Step | Tooling Executed | Key Outcome | Status |
|---|---|---|---|
| **Step 1: Known Security Issues** | `slither . --exclude-dependencies` (Slither `0.11.6`, 102 detectors, 36 contracts) | **0 High, 0 Medium, 11 Low, 3 Informational** findings across 6 detector types (`events-maths`, `calls-loop`, `reentrancy-benign`, `timestamp`, `assembly`, `pragma`, `naming-convention`). All 14 findings triaged with exact `file:line` references. | Complete |
| **Step 2: Special Features** | Codebase applicability searches + `slither-check-upgradeability` (8 & 22 checks) + `slither-check-erc` (`erc721`, `erc165`) + `slither-prop` attempt | **ERC-721 & ERC-165 conformance: 100% PASS** (all 13 functions + 3 events). Clone initialization & storage architecture audited (`pure` `name()`/`symbol()` overrides, `ReentrancyGuard` clone slot behavior). Token integration & `slither-prop` Foundry coverage gap documented. | Complete |
| **Step 3: Visual Security Inspection** | `slither . --print inheritance-graph`, `function-summary`, `vars-and-auth` + `render_diagrams.py` (`.dot`, `.svg`, `.png`, `.pdf`) | Generated and inspected all **3 visual security diagrams** (`inheritance-graph`, `function-summary`, `vars-and-auth` in `.svg`, `.png`, `.pdf`). Confirmed **zero state variable shadowing** across all 9 inheritance bases of `Raffle` and strict access/status controls on all 33 state variables. | Complete |
| **Step 4: Security Properties & Fuzzing** | 20 formal security properties + **Echidna 2.3.3** (25,070 calls) + **Foundry Invariant/Fuzz** (35,768 calls) + **Custom Slither Python API** (5 checks) + `manticore` attempt | **11/11 Echidna invariants PASSED** (after Echidna caught a 0-indexed vs 1-indexed entry range spec assumption on run #1); **6/6 Foundry invariant & fuzz suites PASSED**; **5/5 Custom Slither API checks PASSED**; Manticore unavailability documented as a tool gap. | Complete |
| **Step 5: Manual Review Areas** | Codebase pattern searches (`manual-review-searches.log`) + manual audit across Privacy, Front-Running/MEV, Cryptography, and External/DeFi Integrations | Audited 8 concrete architectural/manual risk areas (`MR-01` to `MR-08`), including secondary-market ticket transfers during `Drawing`/post-resolution (`MR-02`), late-sale reserve sniping (`MR-01`), VRF wrapper dual price evaluation (`MR-06`), and USDC blacklist isolation (`MR-08`). | Complete |

---

## Environment, Tooling & Input Integrity Record

### Tool Versions Used
- **Solidity Compiler (`solc`)**: `0.8.36+commit.8a97fa7a.Darwin.appleclang` (`/Users/hishamel-husseini/.solc-select/artifacts/solc-0.8.36/solc-0.8.36`)
- **Foundry (`forge`)**: `1.7.1-v1.5.1` (`/Users/hishamel-husseini/.foundry/bin/forge`)
- **Slither (`slither`)**: `0.11.6` (`/opt/homebrew/Cellar/slither-analyzer/0.11.6/libexec/bin/slither`), including `slither-check-upgradeability`, `slither-check-erc`, `slither-prop`, and Python `slither` API
- **Echidna (`echidna`)**: `2.3.3` (`/opt/homebrew/bin/echidna`)
- **Python (`python3`)**: `3.14.6` (`/opt/homebrew/bin/python3`)
- **Unavailable System Tools (Recorded Coverage Gaps)**:
  - `manticore`: Not installed (`zsh: command not found: manticore`; Manticore does not support Python 3.14 / macOS arm64 / Solidity 0.8.36). Compensated via Echidna stateful property fuzzing, Foundry stateful invariant fuzzing, and custom Slither Python API checks.
  - `dot` (Graphviz CLI): Not installed (`zsh: command not found: dot`). Compensated via `scratch/step3-diagrams/render_diagrams.py`, which parses Slither's `.dot` and printer outputs and renders valid vector (`.svg`, `.pdf`) and raster (`.png`, verified via `/usr/bin/sips`) diagrams.
  - `slither-prop`: Installed (`/opt/homebrew/Cellar/slither-analyzer/0.11.6/libexec/bin/slither-prop`), executed against `Raffle`, and exited with `ERROR:root:Foundry not yet supported by slither-prop` (recorded in `scratch/step2-special-features/slither-prop-raffle.log`).

### Scope & Codebase Summary
The owned codebase (`packages/contracts/src/`) consists of 5 Solidity files compiled under exact pragma `0.8.36`:
1. [`packages/contracts/src/Raffle.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol) (617 lines): Autonomous single-prize NFT raffle deployed once as a master implementation by `RaffleFactory` and cloned via EIP-1167 (`Clones.clone`). Inherits `IRaffle`, `ERC721`, `ReentrancyGuard`, `IERC721Receiver`, and `VRFV2PlusWrapperConsumerBase`.
2. [`packages/contracts/src/RaffleFactory.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/RaffleFactory.sol) (186 lines): Factory that deploys the master `Raffle` implementation in its constructor and creates/initializes/escrows ERC-1167 raffle clones in `createRaffle`.
3. [`packages/contracts/src/interfaces/IRaffle.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/interfaces/IRaffle.sol) (521 lines): Interface defining the 6-state `Status` enum (`AwaitingPrize`, `Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`), structs, events, custom errors, and external functions.
4. [`packages/contracts/src/interfaces/IRaffleFactory.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/interfaces/IRaffleFactory.sol) (136 lines): Interface for `RaffleFactory`.
5. [`packages/contracts/src/libraries/RaffleConstants.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/libraries/RaffleConstants.sol) (41 lines): Protocol-wide constants (`ENTRY_PRICE = 1e6`, `PROTOCOL_FEE_BPS = 100`, `CASH_WINNER_BPS = 5_000`, `BPS = 10_000`, `MAX_SALE_DURATION = 30 days`, `DRAW_REQUEST_TIMEOUT = 2 days`, `DRAW_CALLBACK_TIMEOUT = 2 days`, `MAX_REFUND_TICKET_BATCH_SIZE = 100`, `VRF_CALLBACK_GAS_LIMIT = 300_000`, `VRF_REQUEST_CONFIRMATIONS = 30`).

---

## Step 1: Check for Known Security Issues (Slither Security Scan)

### Execution Details
- **Working Copy**: `scratch/contracts-exact` (unmodified copy of `packages/contracts`, including unmodified `foundry.toml` with `gas_reports = ["RaffleFactory", "Raffle"]`)
- **Commands Executed**:
  ```bash
  cd scratch/contracts-exact
  forge build
  slither . --exclude-dependencies --json ../step1-slither/slither-results.json
  ```
- **Raw Output Logs**:
  - [`scratch/raw-outputs/forge-build-unmodified.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/raw-outputs/forge-build-unmodified.log)
  - [`scratch/raw-outputs/slither-unmodified.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/raw-outputs/slither-unmodified.log)
  - [`scratch/step1-slither/slither-results.json`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step1-slither/slither-results.json)

### Summary of Slither Findings (36 Contracts Analyzed, 102 Detectors, 14 Total Results)

| ID | Detector | Impact | Confidence | Location (`file:line`) | Triage Verdict |
|---|---|---|---|---|---|
| **SL-01** | `events-maths` | Low | Medium | [`src/Raffle.sol:176-206`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L176-L206) (`Raffle.initialize`) | **Benign / Covered by Factory Event** (`RaffleFactory.createRaffle` atomically emits `RaffleCreated` and `onERC721Received` emits `PrizeDeposited`) |
| **SL-02** | `calls-loop` | Low | Medium | [`src/Raffle.sol:587-601`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L587-L601) (`_isProtocolDestination` -> `canonicalFactory.raffleImplementation()`) | **False Positive** (`_burn` calls `_update(address(0), ...)`, which short-circuits `if (to != address(0) && ...)` before calling `_isProtocolDestination`) |
| **SL-03** | `calls-loop` | Low | Medium | [`src/Raffle.sol:587-601`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L587-L601) (`_isProtocolDestination` -> `canonicalFactory.isRaffle(destination)`) | **False Positive** (same short-circuit in `_update` when `to == address(0)` during `_burn` in `refundTickets`) |
| **SL-04** | `reentrancy-benign` | Low | Medium | [`src/RaffleFactory.sol:97-148`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/RaffleFactory.sol#L97-L148) (`RaffleFactory.createRaffle`) | **Intentional By Design** (`createRaffle` is `nonReentrant`, and `raffle` is an freshly cloned trusted `raffleImplementation`) |
| **SL-05** | `reentrancy-benign` | Low | Medium | [`src/Raffle.sol:242-275`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L242-L275) (`Raffle.requestDraw`) | **Intentional Defense-in-Depth** (`_requestInFlight = true` guards against synchronous callbacks during `requestRandomnessPayInNative`) |
| **SL-06** | `timestamp` | Low | Medium | [`src/RaffleFactory.sol:97-148`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/RaffleFactory.sol#L97-L148) (`RaffleFactory.createRaffle`) | **Acceptable / Expected** (`endTime > block.timestamp` and `saleDuration <= 30 days`) |
| **SL-07** | `timestamp` | Low | Medium | [`src/Raffle.sol:214-240`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L214-L240) (`Raffle.buyEntries`) | **Acceptable / Expected** (`block.timestamp >= endTime` sale cutoff check) |
| **SL-08** | `timestamp` | Low | Medium | [`src/Raffle.sol:242-275`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L242-L275) (`Raffle.requestDraw`) | **Acceptable / Expected** (`[endTime, endTime + 2 days)` draw request window) |
| **SL-09** | `timestamp` | Low | Medium | [`src/Raffle.sol:278-296`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L278-L296) (`Raffle.enableRefunds`) | **Acceptable / Expected** (`2 days` timeout windows far exceed ~12s validator drift) |
| **SL-10** | `timestamp` | Low | Medium | [`src/Raffle.sol:464-466`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L464-L466) (`Raffle.callbackDeadline`) | **Acceptable / Expected** (`drawRequestedAt == 0 ? 0 : drawRequestedAt + 2 days`) |
| **SL-11** | `timestamp` | Low | Medium | [`src/Raffle.sol:509-531`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L509-L531) (`Raffle.fulfillRandomWords`) | **Acceptable / Expected** (`block.timestamp > callbackDeadline()` check on 2-day window) |
| **SL-12** | `assembly` | Informational | High | [`src/Raffle.sol:266-268`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L266-L268) (`Raffle.requestDraw`) | **Intentional Security Hardening** (Returnbomb-safe native excess refund via `call(gas(), refundRecipient, excess, 0, 0, 0, 0)`) |
| **SL-13** | `pragma` | Informational | High | `src/*.sol` (`0.8.36`) vs `node_modules/**/*.sol` | **Benign Dependency Variance** (All 5 owned files use exact locked `pragma solidity 0.8.36;`) |
| **SL-14** | `naming-convention` | Informational | High | [`src/interfaces/IRaffle.sol:431`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/interfaces/IRaffle.sol#L431) (`IRaffle.ENTRY_PRICE()`) | **Intentional Interface Getter** (Matches `uint256 public constant override ENTRY_PRICE` in `Raffle.sol:44`) |

### Detailed Explanation & Triage of Step 1 Findings

#### 1. `SL-01` (`events-maths`): Missing Event Emission Inside `Raffle.initialize`
- **File Reference**: [`packages/contracts/src/Raffle.sol:176-206`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L176-L206)
- **Explanation**: Slither flags that `Raffle.initialize` writes `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime` without emitting an event inside `initialize`.
- **Triage**: Benign. `Raffle.initialize` can only be called by `factory` (`if (msg.sender != factory) revert UnauthorizedInitializer(msg.sender)` at line 178) inside `RaffleFactory.createRaffle` (`src/RaffleFactory.sol:109-147`), which atomically escrows the prize (emitting `PrizeDeposited` from `Raffle.onERC721Received`) and emits `RaffleCreated(raffleId, raffle, msg.sender, params.sponsorRecipient, params.prizeToken, params.prizeTokenId, quoteToken, protocolTreasury, params.reserveEntries, params.endTime)`.
- **Optional Recommendation**: Emit a `RaffleInitialized` event in `Raffle.initialize` or add `// slither-disable-next-line events-maths` if clone-local indexing is not needed.

#### 2. `SL-02` & `SL-03` (`calls-loop`): Staticcalls in `_isProtocolDestination` Reached from `refundTickets`
- **File Reference**: [`packages/contracts/src/Raffle.sol:346-374`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L346-L374), [`packages/contracts/src/Raffle.sol:495-502`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L495-L502), and [`packages/contracts/src/Raffle.sol:587-601`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L587-L601)
- **Explanation**: `refundTickets` loops over `ticketIds` (bounded by `MAX_REFUND_TICKET_BATCH_SIZE = 100`) and calls `_burn(ticketId)`, which invokes `Raffle._update(address to, uint256 ticketId, address auth)`:
  ```solidity
  function _update(address to, uint256 ticketId, address auth) internal override returns (address from) {
      if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
          revert UnsafeProtocolDestination(to);
      }
      from = super._update(to, ticketId, auth);
  }
  ```
- **Triage**: **False Positive**. During `_burn(ticketId)`, OpenZeppelin `ERC721._burn` passes `to = address(0)`. Because Solidity evaluates `&&` with short-circuiting, `to != address(0)` is `false` and `_isProtocolDestination` is **never executed** during `refundTickets`! Even if it were called, `canonicalFactory` is the immutable trusted `RaffleFactory` contract.

#### 3. `SL-04` & `SL-05` (`reentrancy-benign`): Benign State Updates AfterTrusted External Calls
- **File Reference**: [`packages/contracts/src/RaffleFactory.sol:109-125`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/RaffleFactory.sol#L109-L125) and [`packages/contracts/src/Raffle.sol:255-260`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L255-L260)
- **Triage**:
  1. In `RaffleFactory.createRaffle`, `IRaffle(raffle).initialize(...)` is called on a newly cloned `raffleImplementation` inside a `nonReentrant` function before recording `raffleById[raffleId] = raffle`, `idByRaffle[raffle] = raffleId`, and `isRaffle[raffle] = true` (`lines 123-125`). The target is deterministic trusted code (`Clones.clone(raffleImplementation)`), and `initialize` makes only `view` staticcalls back to `factory` (`_isProtocolDestination`).
  2. In `Raffle.requestDraw`, `status = Status.Drawing`, `drawRequestedAt = uint64(currentTime)`, and `_requestInFlight = true` are set **before** calling `requestRandomnessPayInNative` on the immutable `i_vrfV2PlusWrapper` (`lines 253-257`), and `vrfRequestId = requestId` and `_requestInFlight = false` are written immediately upon return (`lines 259-260`). This ordering is essential because `requestId` is the return value of `requestRandomnessPayInNative`, and `_requestInFlight = true` prevents any synchronous callback during the request from being accepted (`src/Raffle.sol:511`).

#### 4. `SL-06` through `SL-11` (`timestamp`): Block Timestamp Comparisons
- **File Reference**: [`src/RaffleFactory.sol:100`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/RaffleFactory.sol#L100), [`src/Raffle.sol:215,244,246,283,288,465,512`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L215)
- **Triage**: Expected time-based state machine transitions. Liveness timeout windows (`DRAW_REQUEST_TIMEOUT = 2 days`, `DRAW_CALLBACK_TIMEOUT = 2 days`) are orders of magnitude larger than ~12-second block timestamp drift.

#### 5. `SL-12` (`assembly`), `SL-13` (`pragma`), and `SL-14` (`naming-convention`)
- **`SL-12` (`src/Raffle.sol:266-268`)**: Memory-safe inline assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` intentionally avoids copying returndata (`outsize = 0`) when refunding native ETH excess in `requestDraw()`, neutralizing returnbombing griefing.
- **`SL-13`**: All 5 owned files use exact `pragma solidity 0.8.36;`; floating pragmas appear only in third-party `@openzeppelin` and `@chainlink` dependencies.
- **`SL-14` (`src/interfaces/IRaffle.sol:431`)**: `ENTRY_PRICE()` in `IRaffle` is the interface getter matching `uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;` in `Raffle.sol:44`.

---

## Step 2: Check Special Features

### 2.0 Codebase Applicability Search Record
Before running or skipping any Step 2 special feature check, we executed explicit codebase searches across `packages/contracts/src/` and `DESIGN.md` (saved in [`scratch/step2-special-features/applicability-search.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/applicability-search.log)):

| Feature Area | Search Patterns Executed | Codebase Matches Found | Applicability Verdict |
|---|---|---|---|
| **Upgradeability / Clones / Initializers** | `Clones\|clone\|delegatecall\|implementation\|initialize\|Initializable\|upgrade\|proxy` | `RaffleFactory.sol:4` (`import { Clones }`), `RaffleFactory.sol:38` (`raffleImplementation`), `RaffleFactory.sol:106` (`Clones.clone(raffleImplementation)`), `Raffle.sol:124` (`bool public override initialized`), `Raffle.sol:176` (`function initialize(...)`) | **APPLICABLE (EIP-1167 Minimal Proxy Clone + Custom Initializer)** -> Executed `slither-check-upgradeability` |
| **ERC Standards (`ERC721`, `ERC165`, `ERC20`)** | `ERC721\|IERC721\|ERC20\|IERC20\|ERC165\|supportsInterface\|onERC721Received` | `Raffle` inherits `ERC721` (which inherits `ERC165`, `IERC721`, `IERC721Metadata`) and `IERC721Receiver` (`onERC721Received`) | **APPLICABLE (`ERC721` & `ERC165`)** -> Executed `slither-check-erc` for `erc721` and `erc165` |
| **Token Integration (`USDC` & Prize `ERC721`)** | `safeTransfer\|transferFrom\|quoteToken\|prizeToken\|decimals` | `RaffleFactory.sol:68` (`IERC20Metadata(quoteToken_).decimals() != 6`), `Raffle.sol:224` (`quoteToken.safeTransferFrom`), `Raffle.sol:334,404` (`prizeToken.transferFrom`), `Raffle.sol:566` (`quoteToken.safeTransfer`) | **APPLICABLE** -> Audited ERC-20 (`quoteToken`) and ERC-721 (`prizeToken`) integration patterns |
| **ERC-20 Property Generation (`slither-prop`)** | `ERC20` inheritance check | `Raffle` is an `ERC721` contract (not `ERC20`), though we still executed `slither-prop . --contract Raffle` to record actual tool output | **EXECUTED & DOCUMENTED COVERAGE GAP** (`ERROR:root:Foundry not yet supported by slither-prop`) |

---

### 2.1 Upgradeability & EIP-1167 Clone Checks (`slither-check-upgradeability`)
- **Commands Executed**:
  ```bash
  cd scratch/contracts-exact
  slither-check-upgradeability . Raffle > ../step2-special-features/slither-check-upgradeability-raffle.log 2>&1
  slither-check-upgradeability . Raffle --new-contract-name Raffle > ../step2-special-features/slither-check-upgradeability-raffle-self.log 2>&1
  ```
- **Raw Output Logs**:
  - [`scratch/step2-special-features/slither-check-upgradeability-raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/slither-check-upgradeability-raffle.log)
  - [`scratch/step2-special-features/slither-check-upgradeability-raffle-self.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/slither-check-upgradeability-raffle-self.log)
- **Results & Clone Storage Analysis**:
  - `slither-check-upgradeability` ran 8 detectors (single contract) and 22 detectors (with `--new-contract-name Raffle` layout self-check), reporting zero storage layout collisions, zero variable order mismatches, and two informational notices on `Raffle.initialize`:
    - `init-missing`: `Raffle` uses its own explicit `bool public override initialized` state variable (`src/Raffle.sol:124`) rather than inheriting an `Initializable` base contract.
    - `initialize-target`: `Raffle` has an `initialize(IRaffle.RaffleInitParams)` function (`src/Raffle.sol:176-206`).
  - **Master Implementation Lock Verification (`src/Raffle.sol:155-167`)**:
    In the `Raffle` constructor (`Raffle.sol:164-165`), `initialized = true;` and `status = Status.Refunding;` are set on the master implementation contract, permanently locking `raffleImplementation` against direct `initialize()`, `buyEntries()`, `requestDraw()`, or `onERC721Received()` calls.
  - **ERC-1167 Clone Constructor State Audit**:
    1. **ERC-721 `_name` and `_symbol` (`src/Raffle.sol:479-487`)**: OpenZeppelin's `ERC721` constructor writes `_name` and `_symbol` to implementation storage, which is not copied to EIP-1167 clones. `Raffle` explicitly overrides both `name()` and `symbol()` as `pure` functions returning `"raffle.fun Ticket"` and `"RAFFLE"`, ensuring clones never read uninitialized string storage.
    2. **OpenZeppelin `ReentrancyGuard` Slot in Clones (`node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:58-76`)**: `ReentrancyGuard` sets `_status = NOT_ENTERED (1)` in its constructor, so in a fresh EIP-1167 clone that storage slot starts at `0`. Because `_reentrancyGuardEntered()` checks `_status == ENTERED (2)`, the initial `0` value safely passes the entry check, sets `_status = 2` during execution, and writes `_status = 1` (`NOT_ENTERED`) on exit (incurring a one-time cold zero-to-non-zero SSTORE gas cost on the clone's first `nonReentrant` call).

---

### 2.2 ERC Conformance Validation (`slither-check-erc`)
- **Commands Executed**:
  ```bash
  cd scratch/contracts-exact
  slither-check-erc . Raffle --erc erc721 > ../step2-special-features/slither-check-erc721-raffle.log 2>&1
  slither-check-erc . Raffle --erc erc165 > ../step2-special-features/slither-check-erc165-raffle.log 2>&1
  ```
- **Raw Output Logs**:
  - [`scratch/step2-special-features/slither-check-erc721-raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/slither-check-erc721-raffle.log)
  - [`scratch/step2-special-features/slither-check-erc165-raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/slither-check-erc165-raffle.log)
- **Results**:
  - **`erc721` Check**: **100% PASS** across all 13 functions (`balanceOf`, `ownerOf`, `safeTransferFrom(address,address,uint256,bytes)`, `safeTransferFrom(address,address,uint256)`, `transferFrom`, `approve`, `setApprovalForAll`, `getApproved`, `isApprovedForAll`, `supportsInterface`, `name`, `symbol`, `tokenURI`) and all 3 events (`Transfer`, `Approval`, `ApprovalForAll`).
  - **`erc165` Check**: **100% PASS** (`supportsInterface(bytes4)` present, `view`, returns `bool`).

---

### 2.3 Token Integration Analysis (`USDC` Quote Token & `ERC721` Prize Token)
- **Quote Token (`IERC20 quoteToken`)**:
  - Validated as a deployed contract with `IERC20Metadata(quoteToken_).decimals() == 6` in `RaffleFactory` constructor (`src/RaffleFactory.sol:63-70`).
  - All inbound and outbound transfers use OpenZeppelin `SafeERC20` (`quoteToken.safeTransferFrom` at `src/Raffle.sol:224` and `quoteToken.safeTransfer` at `src/Raffle.sol:566`).
  - Accounting uses internal state variables (`unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`), never raw `quoteToken.balanceOf(address(this))`, so unsolicited USDC transfers to a raffle clone cannot corrupt settlement math or status transitions.
- **Prize Token (`IERC721 prizeToken`)**:
  - Validated at raffle creation via `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` inside a `try/catch` block (`src/RaffleFactory.sol:174-180`).
  - Escrowed atomically via `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` followed by post-condition checks `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active` (`src/RaffleFactory.sol:128-134`).
  - Released via non-callback `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` followed by `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient)` (`src/Raffle.sol:334-337`, `src/Raffle.sol:404-407`), preventing malicious `onERC721Received` callbacks during prize claiming.

---

### 2.4 `slither-prop` Execution & Coverage Gap
- **Command Executed**:
  ```bash
  cd scratch/contracts-exact
  slither-prop . --contract Raffle > ../step2-special-features/slither-prop-raffle.log 2>&1
  ```
- **Raw Output** ([`scratch/step2-special-features/slither-prop-raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step2-special-features/slither-prop-raffle.log)):
  ```text
  WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
  ERROR:root:Foundry not yet supported by slither-prop
  ```
- **Coverage Gap Explanation**: `slither-prop` only supports legacy Truffle ERC-20 projects and does not support Foundry or ERC-721 raffle contracts. We addressed this in Step 4 by writing a custom 11-property Echidna harness (`RaffleEchidnaTest.sol`) and a 6-test Foundry stateful invariant & fuzz suite (`RaffleWorkflowInvariants.t.sol`).

---

## Step 3: Visual Security Inspection

### Execution & Generated Diagram Files
We executed all three Slither visual inspection printers on `scratch/contracts-exact` and rendered visual `.svg`, `.png`, and `.pdf` diagrams via [`scratch/step3-diagrams/render_diagrams.py`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/render_diagrams.py) (recording in [`scratch/step3-diagrams/graphviz-dot-attempt.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/graphviz-dot-attempt.log) that Graphviz `dot` CLI is not installed on the host):

1. **Diagram 1 — Inheritance Graph**:
   - Raw DOT & Printer Log: [`scratch/step3-diagrams/inheritance-graph.dot`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/inheritance-graph.dot), [`scratch/step3-diagrams/inheritance-graph-printer.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/inheritance-graph-printer.log)
   - Rendered Visual Outputs: [`scratch/step3-diagrams/inheritance-graph.png`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/inheritance-graph.png) (`1280 x 760` RGB PNG), [`scratch/step3-diagrams/inheritance-graph.svg`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/inheritance-graph.svg), [`scratch/step3-diagrams/inheritance-graph.pdf`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/inheritance-graph.pdf)
2. **Diagram 2 — Function Summary**:
   - Raw Printer Log & Owned Table: [`scratch/step3-diagrams/function-summary-printer.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/function-summary-printer.log), [`scratch/step3-diagrams/owned-function-summary.txt`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/owned-function-summary.txt)
   - Rendered Visual Outputs: [`scratch/step3-diagrams/function-summary.png`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/function-summary.png) (`3702 x 6281` RGB PNG), [`scratch/step3-diagrams/function-summary.svg`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/function-summary.svg), [`scratch/step3-diagrams/function-summary.pdf`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/function-summary.pdf)
3. **Diagram 3 — Variables and Authorization**:
   - Raw Printer Log & Owned Table: [`scratch/step3-diagrams/vars-and-auth-printer.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/vars-and-auth-printer.log), [`scratch/step3-diagrams/owned-vars-and-auth.txt`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/owned-vars-and-auth.txt)
   - Rendered Visual Outputs: [`scratch/step3-diagrams/vars-and-auth.png`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/vars-and-auth.png) (`1866 x 3486` RGB PNG), [`scratch/step3-diagrams/vars-and-auth.svg`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/vars-and-auth.svg), [`scratch/step3-diagrams/vars-and-auth.pdf`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step3-diagrams/vars-and-auth.pdf)

### Security Review of the 3 Diagrams

#### 3.1 Inheritance Graph Review (`inheritance-graph.dot` / `inheritance-graph.png`)
```mermaid
flowchart TD
    Raffle["Raffle (src/Raffle.sol)"] -->|"1"| IRaffle["IRaffle"]
    Raffle -->|"2"| ERC721["ERC721 (OZ v5.1.0)"]
    Raffle -->|"3"| ReentrancyGuard["ReentrancyGuard (OZ v5.1.0)"]
    Raffle -->|"4"| IERC721Receiver["IERC721Receiver"]
    Raffle -->|"5"| VRFBase["VRFV2PlusWrapperConsumerBase"]
    ERC721 -->|"1"| Context["Context"]
    ERC721 -->|"2"| ERC165["ERC165 -> IERC165"]
    ERC721 -->|"3,4,5"| IERC721Meta["IERC721 / IERC721Metadata / IERC721Errors"]
    RaffleFactory["RaffleFactory (src/RaffleFactory.sol)"] -->|"1"| IRaffleFactory["IRaffleFactory"]
    RaffleFactory -->|"2"| ReentrancyGuard
```
- **C3 Linearization & Shadowing Check**: `Raffle` inherits from 5 direct bases (`IRaffle`, `ERC721`, `ReentrancyGuard`, `IERC721Receiver`, `VRFV2PlusWrapperConsumerBase`). Slither's `inheritance-graph.dot` shows **zero red/shadowed state variables or functions**. The four orange-highlighted functions in `Raffle` (`name()`, `symbol()`, `_update(address,uint256,address)`, `fulfillRandomWords(uint256,uint256[])`) are intentional overrides of `ERC721` and `VRFV2PlusWrapperConsumerBase`.
- `RaffleFactory` inherits only `IRaffleFactory` and `ReentrancyGuard`, with a flat, unambiguous hierarchy.

#### 3.2 Function Summary Review (`owned-function-summary.txt` / `function-summary.png`)
- **Visibility Verification**: Internal helpers (`_settleWinningTicket`, `_transferQuote`, `_requireStatus`, `_requireWinningTicket`, `_isProtocolDestination`, `_validatedVrfWrapper` in `Raffle`; `_validateCreateParams`, `_requireContract` in `RaffleFactory`) are all strictly `private` or `internal`.
- **Reentrancy & Modifier Verification**: Every user-callable mutating function on `Raffle` (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) and `RaffleFactory` (`createRaffle`) carries `nonReentrant`.

#### 3.3 Variables and Authorization Review (`owned-vars-and-auth.txt` / `vars-and-auth.png`)
Reviewing the `State variables written` and `Conditions on msg.sender` columns of `owned-vars-and-auth.txt`:
- **Configuration Variables (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`)**: Written **exclusively** in `Raffle.initialize` under `msg.sender == factory` and `!initialized`.
- **VRF Resolution Variables (`resolvedAt`, `status`, `winningEntry`)**: Written in `rawFulfillRandomWords -> fulfillRandomWords` under `msg.sender == address(i_vrfV2PlusWrapper)`, `!_requestInFlight`, `status == Status.Drawing`, `requestId == vrfRequestId`, and `block.timestamp <= callbackDeadline()`.
- **Settlement & Claim Variables (`settlementComplete`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `winningTicketId`, `winnerRedeemed`, `winnerRecipient`, `prizeClaimed`)**:
  - Notice that `settleWinningTicket(uint256)` (`Raffle.sol:299-302`), `releaseSponsorProceeds()` (`Raffle.sol:377-385`), `releaseProtocolFees()` (`Raffle.sol:388-396`), and `releaseSponsorPrize()` (`Raffle.sol:399-408`) have `Conditions on msg.sender: []` (permissionless).
  - **Why this is safe**: `releaseSponsorProceeds()`, `releaseProtocolFees()`, and `releaseSponsorPrize()` transfer assets strictly to the pre-configured `sponsorRecipient` or `protocolTreasury` (not `msg.sender`), and `settleWinningTicket(ticketId)` validates `_requireWinningTicket(ticketId)` before computing deterministic splits. By contrast, `redeemWinningTicket(ticketId)` enforces `msg.sender == _requireOwned(ticketId)` (`winner`) and `refundTickets(ticketIds)` enforces `msg.sender == _requireOwned(ticketId)` (`owner`).

---

## Step 4: Document Security Properties & Testing Setup

### 4.1 Documented Security Properties
Full specification: [`scratch/step4-properties/SECURITY_PROPERTIES.md`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/SECURITY_PROPERTIES.md)

| ID | Category | Security Property | Verification Method |
|---|---|---|---|
| **SM-01** | State Machine | Master `raffleImplementation` is permanently locked (`initialized == true`, `status == Status.Refunding`). | `echidna_implementation_locked`, Foundry Invariant |
| **SM-02** | State Machine | Clones initialize once (`msg.sender == factory`) into `AwaitingPrize` and transition to `Active` only upon atomic prize deposit in `createRaffle`. | `echidna_status_transitions_valid`, Custom Slither Check 3 & 4 |
| **SM-03** | State Machine | `status` transitions follow the strict DAG (`AwaitingPrize -> Active -> Drawing -> {NftWon, CashWon}` or `{Active, Drawing} -> Refunding`); `NftWon`, `CashWon`, and `Refunding` are terminal. | `echidna_status_transitions_valid`, `invariant_ticketRangesAndStatusLifecycle` |
| **SM-04** | State Machine | `fulfillRandomWords` ignores callbacks (emitting `VrfCallbackIgnored`) if `_requestInFlight`, `status != Drawing`, `requestId != vrfRequestId`, `randomWords.length != 1`, or `block.timestamp > callbackDeadline()`. | `test_protocolDestinationGuardsAndCallbackIgnore` |
| **AC-01** | Access Control | Only `factory` can call `Raffle.initialize` (`Raffle.sol:178`). | Custom Slither Check 1 & 4 |
| **AC-02** | Access Control | Only `i_vrfV2PlusWrapper` can call `rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:95`). | Step 3 `vars-and-auth`, Custom Slither Check 1 |
| **AC-03** | Access Control | `onERC721Received` only accepts `prizeTokenId` from `msg.sender == address(prizeToken)` with `from == sponsor` and `operator == factory` while `status == AwaitingPrize` (`Raffle.sol:368-378`). | Step 3 `vars-and-auth`, Custom Slither Check 3 |
| **AC-04** | Access Control | Only the current ERC-721 owner of `ticketId` can call `redeemWinningTicket(ticketId)` or `refundTickets([ticketId])`. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_refundPathsAndSponsorPrizeReclaim` |
| **AC-05** | Access Control | Protocol destinations (`factory`, `raffleImplementation`, any raffle clone, `quoteToken`, `vrfWrapper`, `prizeToken`) cannot hold tickets or be configured as payout recipients (`_isProtocolDestination`). | `echidna_no_protocol_destination_holds_tickets`, `test_protocolDestinationGuardsAndCallbackIgnore`, Custom Slither Check 2 |
| **AR-01** | Arithmetic & Solvency | `quoteToken.balanceOf(raffle) >= raffle.accountedQuoteBalance()` and `accountedQuoteBalance() == unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees`. | `echidna_quote_solvency`, `invariant_quoteSolvencyAndAccounting` |
| **AR-02** | Arithmetic & Solvency | `grossSales() == totalEntries * ENTRY_PRICE` (`1e6`), and while in `AwaitingPrize`/`Active`/`Drawing`, `unsettledPot == grossSales()`. | `echidna_entry_accounting`, `invariant_quoteSolvencyAndAccounting` |
| **AR-03** | Arithmetic & Solvency | Ticket entry ranges are 1-indexed (`ticketRange(1).startEntry == 1`), contiguous (`startEntry_i == endEntry_{i-1} + 1`), and span `1..totalEntries`. | `echidna_ticket_ranges_contiguous`, `invariant_ticketRangesAndStatusLifecycle` |
| **AR-04** | Arithmetic & Solvency | When `settlementComplete == true`, `unsettledPot == 0` and `(winnerProceeds + sponsorProceeds + protocolFees) + totalClaimedQuote == grossSales()` (no dust trapped). | `echidna_settlement_conservation`, `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |
| **AR-05** | Arithmetic & Solvency | In `Refunding`, `unsettledPot == 0` and `remainingRefundLiability + totalRefundedQuote == grossSales()`. | `echidna_refund_liability_conservation`, `testFuzz_refundPathsAndSponsorPrizeReclaim` |
| **AR-06** | Arithmetic & Solvency | When `settlementComplete == true`, `1 <= winningTicketId <= ticketCount` and `startEntry <= winningEntry <= endEntry`. | `echidna_winning_ticket_bounds`, `invariant_ticketRangesAndStatusLifecycle` |
| **EX-01** | External Safety | All 9 external user mutating entry points on `Raffle` and `createRaffle` on `RaffleFactory` enforce `nonReentrant`. | Custom Slither Check 1 |
| **EX-02** | External Safety | Outbound prize NFT transfers use `transferFrom` + `ownerOf(prizeTokenId) == recipient` verification (`Raffle.sol:334-337, 404-407`), preventing `onERC721Received` callback griefing. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |
| **EX-03** | External Safety | Excess native ETH refund in `requestDraw` uses zero-returndata inline assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` (`Raffle.sol:267`). | Step 1 Slither `assembly` & Step 5 Manual Review |
| **EX-04** | External Safety | Winner, sponsor, and protocol payouts are isolated pull claims. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |
| **SC-01 / SC-02** | Standards & Registry | Full ERC-721/ERC-165 conformance and bijective `RaffleFactory` registry (`raffleById`, `idByRaffle`, `isRaffle`). | Step 2 `slither-check-erc`, `echidna_factory_registry_bijection` |

---

### 4.2 Echidna Property-Based Fuzzing Execution (`echidna 2.3.3`)
- **Harness & Config Files**:
  - [`scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol)
  - [`scratch/step4-properties/contracts-fuzz/echidna.yaml`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/echidna.yaml)
- **Command Executed** (with zero modifications required to `foundry.toml`):
  ```bash
  cd scratch/step4-properties/contracts-fuzz
  echidna . --contract RaffleEchidnaTest --config echidna.yaml
  ```
- **Notable Discovery During Initial Run** ([`scratch/step4-properties/echidna-run-initial-0indexed-spec.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/echidna-run-initial-0indexed-spec.log)):
  On our first Echidna run, Echidna falsified `echidna_ticket_ranges_contiguous` with a 1-step shrunk counterexample (`RaffleEchidnaTest.action_buyActor1(0)`) showing `ticketRange(1) -> (1, 1)`, demonstrating that entry numbers in `Raffle.sol` (`lines 219-222`) are **1-indexed** (`startEntry = 1`, `endEntry = totalEntries`), not 0-indexed.
- **Final Echidna Results** ([`scratch/step4-properties/echidna-run.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/echidna-run.log)):
  ```text
  echidna_prize_custody_consistency: passing
  echidna_refund_liability_conservation: passing
  echidna_quote_solvency: passing
  echidna_winning_ticket_bounds: passing
  echidna_settlement_conservation: passing
  echidna_implementation_locked: passing
  echidna_factory_registry_bijection: passing
  echidna_no_protocol_destination_holds_tickets: passing
  echidna_ticket_ranges_contiguous: passing
  echidna_entry_accounting: passing
  echidna_status_transitions_valid: passing

  Unique instructions: 15068
  Unique codehashes: 11
  Corpus size: 29
  Seed: 6260699388564689083
  Total calls: 25070
  ```

---

### 4.3 Foundry Stateful Invariant & Stateless Fuzz Testing (`forge test`)
- **Test Suite**: [`scratch/step4-properties/contracts-fuzz/test/foundry/RaffleWorkflowInvariants.t.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/test/foundry/RaffleWorkflowInvariants.t.sol)
- **Command Executed**:
  ```bash
  cd scratch/step4-properties/contracts-fuzz
  forge test -vv
  ```
- **Raw Output** ([`scratch/step4-properties/forge-test-run.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/forge-test-run.log)):
  ```text
  Ran 6 tests for test/foundry/RaffleWorkflowInvariants.t.sol:RaffleWorkflowInvariantsTest
  [PASS] invariant_quoteSolvencyAndAccounting() (runs: 256, calls: 16384, reverts: 14)
  [PASS] invariant_ticketRangesAndStatusLifecycle() (runs: 256, calls: 16384, reverts: 14)
  [PASS] testFuzz_cashWonSettlementAndClaims(uint128,uint128,uint256) (runs: 1000, μ: 567041, ~: 567051)
  [PASS] testFuzz_nftWonSettlementAndClaims(uint128,uint128,uint256) (runs: 1000, μ: 628688, ~: 627199)
  [PASS] testFuzz_refundPathsAndSponsorPrizeReclaim(uint128,uint128,bool) (runs: 1000, μ: 407181, ~: 363486)
  [PASS] test_protocolDestinationGuardsAndCallbackIgnore() (gas: 315784)
  Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 16.85s (28.87s CPU time)
  ```

---

### 4.4 Custom Slither Python API Business-Logic Verification
- **Script & Logs**:
  - [`scratch/step4-properties/custom_slither_checks.py`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/custom_slither_checks.py)
  - [`scratch/step4-properties/custom-slither-checks.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/custom-slither-checks.log)
  - [`scratch/step4-properties/custom-slither-checks.json`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/custom-slither-checks.json)
- **Summary of Automated Check Results**:
  - **Check 1 (`reentrancy-guard-coverage`)**: Confirmed `nonReentrant` on all 9 external user mutating functions of `Raffle` and `RaffleFactory.createRaffle`, and verified custom guards on `initialize`, `onERC721Received`, and `rawFulfillRandomWords`.
  - **Check 2 (`protocol-destination-guard`)**: Confirmed `_isProtocolDestination` enforcement on `initialize`, `_update`, and `_transferQuote`. Also identified that `RaffleFactory._validateCreateParams` checks `sponsorRecipient` and `prizeToken`, while `msg.sender` (`sponsor`) is validated inside `Raffle.initialize` via `_isProtocolDestination(params.sponsor, params.prizeToken)`.
  - **Check 3 (`status-machine-guards`)**: Confirmed that every lifecycle entry point checks `status` or `_requireStatus` before mutating state, while pull-claim functions (`releaseSponsorProceeds`, `releaseProtocolFees`) are gated by non-zero `sponsorProceeds` / `protocolFees` balances (which can only become non-zero inside `_settleWinningTicket` when `status` is `NftWon` or `CashWon`).
  - **Check 4 (`clone-storage-initialization-safety`)**: Confirmed all 22 constructor-written variables vs 12 clone `initialize()`-written variables (`endTime`, `initialized`, `prizeToken`, `prizeTokenId`, `protocolTreasury`, `raffleId`, `reserveEntries`, `sponsor`, `sponsorRecipient`, `status`), 4 immutables (`factory`, `i_linkToken`, `i_vrfV2PlusWrapper`, `quoteToken`), and 3 constants (`ENTRY_PRICE`, `callbackGasLimit`, `requestConfirmations`).
  - **Check 5 (`accounting-writers-verification`)**: Confirmed exact writer sets for all 9 accounting variables (`totalEntries`, `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `settlementComplete`, `winnerRedeemed`, `prizeClaimed`).

### 4.5 Manticore Symbolic Execution Attempt (Documented Coverage Gap)
- **Command Executed**: `manticore --version` -> [`scratch/step4-properties/manticore-attempt.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/manticore-attempt.log) (`zsh: command not found: manticore`).
- **Coverage Gap Analysis**: Manticore is not installed on the macOS arm64 / Python 3.14 environment and does not support Solidity `0.8.36` Shanghai/Cancun opcodes (`PUSH0`, `MCOPY`). The symbolic arithmetic properties (`AR-01` through `AR-06`) were instead verified across 25,070 Echidna calls and 35,768 Foundry invariant/fuzz calls.

---

## Step 5: Manual Review Areas

Full report and raw grep logs:
- [`scratch/step5-manual-review/MANUAL_REVIEW.md`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step5-manual-review/MANUAL_REVIEW.md)
- [`scratch/step5-manual-review/manual-review-searches.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step5-manual-review/manual-review-searches.log)

### Summary of Manual Security Review Findings

| ID | Review Area | Severity | Location (`file:line`) | Description & Impact |
|---|---|---|---|---|
| **MR-01** | Front-Running / MEV | Low (Architectural) | [`src/Raffle.sol:214-240`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L214-L240) | **Late-Sale Entry Sniping & Reserve-Threshold Visibility**: `totalEntries` and `reserveEntries` are transparent on-chain up to `endTime`. Late buyers can observe whether a raffle will clear `reserveEntries` (`NftWon` vs `CashWon`) and purchase large entry batches immediately before `endTime`, or a sponsor can self-buy remaining entries to cross `reserveEntries`. |
| **MR-02** | Front-Running / MEV | Low (Operational) | [`src/Raffle.sol:495-502`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L495-L502) | **Secondary Market Ticket Transfers During `Drawing` or Post-Resolution**: `Raffle._update` allows ERC-721 ticket transfers across all statuses (`Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`) until burned. If a user leaves a secondary market sale order open into `Drawing`, an MEV searcher observing `rawFulfillRandomWords` in the mempool can snipe the winning ticket or dump a losing ticket into a stale bid. Furthermore, `settleWinningTicket` does not lock `winnerRecipient` until `redeemWinningTicket` burns the ticket. |
| **MR-03** | Front-Running / Ordering | Informational | [`src/Raffle.sol:242-302`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L242-L302) | **Permissionless Keeper Race Conditions (`requestDraw`, `settleWinningTicket`, `enableRefunds`)**: Safe against front-running griefing; excess ETH in `requestDraw` is refunded to `msg.sender`, and `_requireWinningTicket` ensures only the true winning ticket ID can settle. |
| **MR-04** | Cryptography / Randomness | Verified Safe | [`src/Raffle.sol:509-531`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L509-L531) | **Chainlink VRF v2.5 Direct Funding & Modulo Bias Bound**: Uses `requestConfirmations = 30` (`RaffleConstants.VRF_REQUEST_CONFIRMATIONS`) and `randomWords[0] % uint256(totalEntries) + 1`. Because `totalEntries` is `uint128`, modulo bias is $< 2^{-128}$ (negligible). |
| **MR-05** | Cryptography / Randomness | Verified Safe | [`src/Raffle.sol:255-260, 511-516`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L255-L260) | **Synchronous Callback & Late/Duplicate Callback Guard**: `_requestInFlight` blocks reentrant synchronous callbacks before `vrfRequestId` is stored; late or duplicate callbacks emit `VrfCallbackIgnored` and return cleanly without reverting. |
| **MR-06** | External / DeFi Integration | Low (Integration) | [`src/Raffle.sol:253-257`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L253-L257) | **Dual `calculateRequestPriceNative` Evaluation in `requestDraw`**: `getVrfRequestPrice()` calls `calculateRequestPriceNative` once at line 253, and `VRFV2PlusWrapperConsumerBase.requestRandomnessPayInNative` calls it a second time before forwarding `{value: requestPrice}`. Safe for standard Chainlink wrappers where `calculateRequestPriceNative` is deterministic within a transaction. |
| **MR-07** | External / DeFi Integration | Low (Integration) | `VRFV2PlusWrapperConsumerBase.sol:45` | **Wrapper `link()` Dependency at Construction**: Even though `Raffle` only uses native ETH payment for VRF, `VRFV2PlusWrapperConsumerBase`'s constructor calls `vrfWrapper.link()`, so the configured wrapper must implement `link()` at `RaffleFactory` deployment time. |
| **MR-08** | External / DeFi Integration | Low (Liveness) | [`src/Raffle.sol:334, 404, 566`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L334) | **USDC Blacklisting Isolation & Non-Callback NFT Delivery**: Pull claims isolate USDC blacklisting per recipient; transferable ERC-721 tickets allow a blacklisted ticket holder to transfer their ticket to a non-blacklisted address before claiming; `prizeToken.transferFrom` + `ownerOf` check prevents `onERC721Received` griefing. |
| **PRIV-01** | Privacy | Verified Safe | [`src/Raffle.sol:139-142`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/packages/contracts/src/Raffle.sol#L139-L142) | **No On-Chain Secrets**: Only `_ticketRanges` (exposed via `ticketRange()`) and `_requestInFlight` (transient boolean) are `private`; no sensitive data is stored on-chain. |

---

## Prioritized Action Plan

### Critical / High Priority
- None (0 Critical and 0 High severity vulnerabilities identified across automated and manual workflow steps).

### Medium / Low Priority (Hardening & Integration Safeguards)
- [ ] **[Low — `MR-02`] Document or Restrict Ticket Transfers During `Drawing` / Post-Resolution**: Warn marketplace/frontend integrators that secondary market orders for `raffle.fun` tickets must expire before `endTime` (`src/Raffle.sol:495-502`), or optionally restrict non-mint/non-burn transfers in `Raffle._update` while `status == Status.Drawing` to eliminate mempool front-running of VRF fulfillment against open NFT marketplace listings. (Effort: 1-2 hours)
- [ ] **[Low — `Check-2` / `RaffleFactory._validateCreateParams`] Fail-Fast Sponsor Validation in `RaffleFactory`**: Add `params.sponsor` (`msg.sender`) validation directly in `RaffleFactory._validateCreateParams` (`src/RaffleFactory.sol:154-180`) alongside `sponsorRecipient` so an invalid sponsor address reverts before deploying the EIP-1167 clone rather than inside `Raffle.initialize` (`src/Raffle.sol:187`). (Effort: 30 minutes)
- [ ] **[Informational — `SL-01`..`SL-05`] Annotate Benign Slither Findings & Keep CI Gates Active**: Retain `RaffleEchidnaTest.sol`, `RaffleWorkflowInvariants.t.sol`, and `custom_slither_checks.py` in the CI pipeline so all 20 security properties and 5 custom Slither checks run on every check-in. (Effort: 1 hour)

---

## Workflow Checklist

- [x] **Step 1: Clean/Triaged Slither Report** (`0 High, 0 Medium, 11 Low, 3 Informational`; all 14 detector outputs explained and triaged in `scratch/raw-outputs/slither-unmodified.log` and `scratch/step1-slither/slither-results.json`)
- [x] **Step 2: Special Features Validated** (Recorded applicability searches in `scratch/step2-special-features/applicability-search.log`; executed `slither-check-upgradeability`, `slither-check-erc` for `erc721` & `erc165`, token integration review, and documented `slither-prop` Foundry gap)
- [x] **Step 3: Visual Inspection Complete** (Executed `inheritance-graph`, `function-summary`, and `vars-and-auth` Slither printers and generated `.svg`, `.png`, and `.pdf` diagrams in `scratch/step3-diagrams/`)
- [x] **Step 4: Security Properties Documented & Tested** (20 properties documented in `scratch/step4-properties/SECURITY_PROPERTIES.md`; 11/11 Echidna invariants passed across 25,070 calls; 6/6 Foundry stateful invariant and fuzz suites passed; 5/5 custom Slither Python API checks passed; Manticore coverage gap documented)
- [x] **Step 5: Manual Review Done** (Privacy, Front-Running/MEV, Cryptography/Randomness, and External/DeFi Integrations analyzed with codebase searches in `scratch/step5-manual-review/`)


---

## Appendix: Complete Verbatim Raw Tool Outputs

### Step 1 — Forge Build Output (`scratch/raw-outputs/forge-build-unmodified.log`)

```text
Compiling 36 files with Solc 0.8.36
Solc 0.8.36 finished in 598.67ms
Compiler run successful!
warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:216:13
    │
216 │         if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    │             ━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:242:13
    │
242 │         if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    │             ━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:245:13
    │
245 │         if (block.timestamp >= requestDeadline) {
    │             ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:282:46
    │
282 │                 if (msg.sender != sponsor && block.timestamp < deadline) {
    │                                              ━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:287:21
    │
287 │                 if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    │                     ━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:291:17
    │
291 │             if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    │                 ━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp

warning[block-timestamp]: usage of `block.timestamp` in a comparison may be manipulated by validators
    ╭▸ src/Raffle.sol:512:20
    │
512 │                 || block.timestamp >= callbackDeadline()
    │                    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    ╰ help: https://book.getfoundry.sh/reference/forge/forge-lint#block-timestamp
```

### Step 1 — Slither Security Scan Output (`scratch/raw-outputs/slither-unmodified.log`)

```text
Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
'forge clean' running (wd: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/contracts-exact)
'forge config --json' running
'forge build --build-info --deny never --skip ./test/foundry/** ./script/** --force' running (wd: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/contracts-exact)
INFO:Detectors:
Detector: events-maths
Raffle.initialize(IRaffle.RaffleInitParams) (src/Raffle.sol#176-206) should emit an event for: 
	- prizeTokenId = params.prizeTokenId (src/Raffle.sol#201) 
	- reserveEntries = params.reserveEntries (src/Raffle.sol#203) 
	- endTime = params.endTime (src/Raffle.sol#204) 
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-events-arithmetic
INFO:Detectors:
Detector: calls-loop
Raffle._isProtocolDestination(address,address) (src/Raffle.sol#593-605) has external calls inside a loop: unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken) || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_ || destination == canonicalFactory.raffleImplementation() (src/Raffle.sol#599-601)
	Calls stack containing the loop:
		Raffle.refundTickets(uint256[])
		ERC721._burn(uint256)
		Raffle._update(address,uint256,address)
Raffle._isProtocolDestination(address,address) (src/Raffle.sol#593-605) has external calls inside a loop: unsafeDestination = canonicalFactory.isRaffle(destination) (src/Raffle.sol#603)
	Calls stack containing the loop:
		Raffle.refundTickets(uint256[])
		ERC721._burn(uint256)
		Raffle._update(address,uint256,address)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop
INFO:Detectors:
Detector: reentrancy-benign
Reentrancy in RaffleFactory.createRaffle(IRaffleFactory.CreateRaffleParams) (src/RaffleFactory.sol#97-148):
	External calls:
	- IRaffle(raffle).initialize(IRaffle.RaffleInitParams({sponsor:msg.sender,sponsorRecipient:params.sponsorRecipient,protocolTreasury:protocolTreasury,prizeToken:params.prizeToken,prizeTokenId:params.prizeTokenId,raffleId:raffleId,reserveEntries:params.reserveEntries,endTime:params.endTime})) (src/RaffleFactory.sol#109-121)
	State variables written after the call(s):
	- idByRaffle[raffle] = raffleId (src/RaffleFactory.sol#124)
	- raffleById[raffleId] = raffle (src/RaffleFactory.sol#123)
Reentrancy in Raffle.requestDraw() (src/Raffle.sol#240-273):
	External calls:
	- (requestId,paidPrice) = requestRandomnessPayInNative(callbackGasLimit,requestConfirmations,1,extraArgs) (src/Raffle.sol#257)
		- (i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(_callbackGasLimit,_requestConfirmations,_numWords,extraArgs),requestPrice) (node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol#83-88)
	State variables written after the call(s):
	- _requestInFlight = false (src/Raffle.sol#260)
	- vrfRequestId = requestId (src/Raffle.sol#259)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
INFO:Detectors:
Detector: timestamp
Raffle.buyEntries(address,uint128) (src/Raffle.sol#209-237) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp >= endTime (src/Raffle.sol#216)
Raffle.requestDraw() (src/Raffle.sol#240-273) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp < endTime (src/Raffle.sol#242)
	- block.timestamp >= requestDeadline (src/Raffle.sol#245)
Raffle.enableRefunds() (src/Raffle.sol#276-301) uses timestamp for comparisons
	Dangerous comparisons:
	- msg.sender != sponsor && block.timestamp < deadline (src/Raffle.sol#282)
	- block.timestamp < deadline (src/Raffle.sol#287)
	- block.timestamp < deadline (src/Raffle.sol#291)
Raffle.callbackDeadline() (src/Raffle.sol#463-465) uses timestamp for comparisons
	Dangerous comparisons:
	- drawRequestedAt != 0 (src/Raffle.sol#464)
Raffle.fulfillRandomWords(uint256,uint256[]) (src/Raffle.sol#509-524) uses timestamp for comparisons
	Dangerous comparisons:
	- _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1 || block.timestamp >= callbackDeadline() (src/Raffle.sol#511-512)
RaffleFactory.createRaffle(IRaffleFactory.CreateRaffleParams) (src/RaffleFactory.sol#97-148) uses timestamp for comparisons
	Dangerous comparisons:
	- params.endTime <= currentTime (src/RaffleFactory.sol#100)
	- saleDuration > RaffleConstants.MAX_SALE_DURATION (src/RaffleFactory.sol#102)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
INFO:Detectors:
Detector: assembly
Raffle.requestDraw() (src/Raffle.sol#240-273) uses assembly
	- INLINE ASM (src/Raffle.sol#266-268)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#assembly-usage
INFO:Detectors:
Detector: pragma
9 different versions of Solidity are used:
	- Version constraint ^0.8.0 is used by:
		-^0.8.0 (node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol#2)
		-^0.8.0 (node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol#2)
		-^0.8.0 (node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol#2)
	- Version constraint ^0.8.4 is used by:
		-^0.8.4 (node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol#2)
	- Version constraint >=0.6.2 is used by:
		->=0.6.2 (node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol#4)
		->=0.6.2 (node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol#4)
		->=0.6.2 (node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol#4)
		->=0.6.2 (node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol#4)
	- Version constraint >=0.4.16 is used by:
		->=0.4.16 (node_modules/@openzeppelin/contracts/interfaces/IERC165.sol#4)
		->=0.4.16 (node_modules/@openzeppelin/contracts/interfaces/IERC20.sol#4)
		->=0.4.16 (node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol#4)
		->=0.4.16 (node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol#4)
	- Version constraint >=0.8.4 is used by:
		->=0.8.4 (node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol#4)
	- Version constraint ^0.8.20 is used by:
		-^0.8.20 (node_modules/@openzeppelin/contracts/proxy/Clones.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Context.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Create2.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Errors.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Panic.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/StorageSlot.sol#5)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/math/Math.sol#4)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol#5)
		-^0.8.20 (node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol#4)
	- Version constraint ^0.8.24 is used by:
		-^0.8.24 (node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol#4)
		-^0.8.24 (node_modules/@openzeppelin/contracts/utils/Bytes.sol#4)
		-^0.8.24 (node_modules/@openzeppelin/contracts/utils/Strings.sol#4)
	- Version constraint >=0.5.0 is used by:
		->=0.5.0 (node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol#4)
	- Version constraint 0.8.36 is used by:
		-0.8.36 (src/Raffle.sol#2)
		-0.8.36 (src/RaffleFactory.sol#2)
		-0.8.36 (src/interfaces/IRaffle.sol#2)
		-0.8.36 (src/interfaces/IRaffleFactory.sol#2)
		-0.8.36 (src/libraries/RaffleConstants.sol#2)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#different-pragma-directives-are-used
INFO:Detectors:
Detector: naming-convention
Function IRaffle.ENTRY_PRICE() (src/interfaces/IRaffle.sol#396) is not in mixedCase
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions
INFO:Slither:. analyzed (36 contracts with 102 detectors), 14 result(s) found
```

### Step 2 — Applicability Search Output (`scratch/step2-special-features/applicability-search.log`)

```text
=== Step 2 Applicability Search: Upgradeability / Clones / Proxies / Initializers ===
src/RaffleFactory.sol:4:import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
src/RaffleFactory.sol:19:///      factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.
src/RaffleFactory.sol:106:        raffle = Clones.clone(raffleImplementation);
src/RaffleFactory.sol:107:        // The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
src/RaffleFactory.sol:110:            .initialize(
src/interfaces/IRaffle.sol:22:        /// @notice The clone is initialized and waiting for the factory to escrow the configured prize.
src/interfaces/IRaffle.sol:308:    function initialize(RaffleInitParams calldata params) external;
src/interfaces/IRaffle.sol:406:    /// @notice Returns the immutable factory authorized to initialize this implementation's clones.
src/interfaces/IRaffle.sol:519:    /// @return complete True for the locked implementation and every initialized clone.
src/interfaces/IRaffle.sol:520:    function initialized() external view returns (bool complete);
src/interfaces/IRaffleFactory.sol:7:/// @dev The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration. Deployment tooling must
src/interfaces/IRaffleFactory.sol:30:    /// @notice Emitted after a raffle clone is initialized, registered, funded, and active.
src/interfaces/IRaffleFactory.sol:101:    /// @notice Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.
src/Raffle.sol:24:///      owners burn them for redemption or refund. Each raffle is a fixed, non-upgradeable ERC-1167 clone with no
src/Raffle.sol:136:    bool public override initialized;
src/Raffle.sol:152:    /// @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
src/Raffle.sol:164:        initialized = true;
src/Raffle.sol:176:    function initialize(RaffleInitParams calldata params) external override {
src/Raffle.sol:177:        if (initialized) revert AlreadyInitialized();
src/Raffle.sol:179:        initialized = true;
src/Raffle.sol:607:    /// @dev Validates the wrapper before passing it to the inherited constructor initializer.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:2:// OpenZeppelin Contracts (last updated v5.5.0) (proxy/Clones.sol)
node_modules/@openzeppelin/contracts/proxy/Clones.sol:20:library Clones {
node_modules/@openzeppelin/contracts/proxy/Clones.sol:29:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:30:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:37:     * @dev Same as {xref-Clones-clone-address-}[clone], but with a `value` parameter to send native currency
node_modules/@openzeppelin/contracts/proxy/Clones.sol:41:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:42:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:72:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:73:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:80:     * @dev Same as {xref-Clones-cloneDeterministic-address-bytes32-}[cloneDeterministic], but with
node_modules/@openzeppelin/contracts/proxy/Clones.sol:84:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:85:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:112:     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:132:     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:149:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:150:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:157:     * @dev Same as {xref-Clones-cloneWithImmutableArgs-address-bytes-}[cloneWithImmutableArgs], but with a `value`
node_modules/@openzeppelin/contracts/proxy/Clones.sol:161:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:162:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:194:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:195:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:206:     * @dev Same as {xref-Clones-cloneDeterministicWithImmutableArgs-address-bytes-bytes32-}[cloneDeterministicWithImmutableArgs],
node_modules/@openzeppelin/contracts/proxy/Clones.sol:210:     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
node_modules/@openzeppelin/contracts/proxy/Clones.sol:211:     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:227:     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
node_modules/@openzeppelin/contracts/proxy/Clones.sol:240:     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:6:import {StorageSlot} from "./StorageSlot.sol";
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:33:    using StorageSlot for bytes32;
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:42:    // back. This is the compiler's defense against contract upgrades and
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:59:        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:99:        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:105:        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:113:        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:116:    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:2:// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:3:// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:10: * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:17: * contract ERC1967 {
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:22: *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:27: *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:34:library StorageSlot {
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:73:    /// @dev Performs a Solidity function call using a low level `delegatecall` and ignoring the return data.
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:74:    function delegatecallNoReturn(address target, bytes memory data) internal returns (bool success) {
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:76:            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:80:    /// @dev Performs a Solidity function call using a low level `delegatecall` and returns the first 64 bytes of the result
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:85:    function delegatecallReturn64Bytes(
node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:90:            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
=== Step 2 Applicability Search: ERC Standards & Token Interactions ===
src/RaffleFactory.sol:5:import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
src/RaffleFactory.sol:6:import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
src/RaffleFactory.sol:8:import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
src/RaffleFactory.sol:59:    /// @dev The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code.
src/RaffleFactory.sol:71:        try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
src/RaffleFactory.sol:72:            quoteDecimals = decimals_;
src/RaffleFactory.sol:127:        IERC721 prize = IERC721(params.prizeToken);
src/RaffleFactory.sol:128:        prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
src/RaffleFactory.sol:129:        if (prize.ownerOf(params.prizeTokenId) != raffle) {
src/RaffleFactory.sol:172:        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
src/interfaces/IRaffle.sol:5:import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
src/interfaces/IRaffle.sol:6:import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
src/interfaces/IRaffle.sol:10:/// @notice Defines one autonomous NFT raffle using fixed-price USDC entries and one transferable ERC-721 ticket per
src/interfaces/IRaffle.sol:12:/// @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable
src/interfaces/IRaffle.sol:14:///      canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest,
src/interfaces/IRaffle.sol:201:    /// @param operator Address identified as the transfer operator.
src/interfaces/IRaffle.sol:266:    /// @notice Raised when initialization or a ticket transfer targets known protocol plumbing.
src/interfaces/IRaffle.sol:299:    /// @notice Raised when the prize token does not report the expected owner after transfer.
src/interfaces/IRaffle.sol:327:    /// @dev Anyone may execute; ownership is not read, the ticket remains transferable, and no external asset transfer
src/interfaces/IRaffle.sol:424:    function quoteToken() external view returns (IERC20 token);
src/interfaces/IRaffle.sol:432:    function prizeToken() external view returns (IERC721 token);
src/Raffle.sol:7:import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
src/Raffle.sol:8:import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
src/Raffle.sol:9:import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
src/Raffle.sol:10:import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
src/Raffle.sol:11:import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
src/Raffle.sol:21:/// @notice Escrows one NFT and sells fixed-price USDC entries through one transferable ERC-721 ticket per purchase.
src/Raffle.sol:23:///      callbacks, and winner proofs are O(1) in entry count. Tickets remain transferable bearer claims until their
src/Raffle.sol:28:contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {
src/Raffle.sol:29:    using SafeERC20 for IERC20;
src/Raffle.sol:58:    IERC20 public immutable override quoteToken;
src/Raffle.sol:70:    IERC721 public override prizeToken;
src/Raffle.sol:156:        ERC721("", "")
src/Raffle.sol:162:        quoteToken = IERC20(quoteToken_);
src/Raffle.sol:170:    /// @notice Rejects direct native-token transfers that are not attached to `requestDraw`.
src/Raffle.sol:200:        prizeToken = IERC721(params.prizeToken);
src/Raffle.sol:224:        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
src/Raffle.sol:235:        _safeMint(recipient, ticketId);
src/Raffle.sol:320:        address winner = ownerOf(ticketId);
src/Raffle.sol:334:            prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
src/Raffle.sol:335:            if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
src/Raffle.sol:342:            _transferQuote(winner, cashAmount);
src/Raffle.sol:359:            address owner = ownerOf(ticketId);
src/Raffle.sol:369:        _transferQuote(msg.sender, amount);
src/Raffle.sol:380:        _transferQuote(recipient, amount);
src/Raffle.sol:390:        _transferQuote(treasury, amount);
src/Raffle.sol:404:        prizeToken.transferFrom(address(this), recipient, prizeTokenId);
src/Raffle.sol:405:        if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
src/Raffle.sol:410:    /// @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be
src/Raffle.sol:412:    /// @param operator ERC-721 transfer operator, which must be the canonical factory.
src/Raffle.sol:416:    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
src/Raffle.sol:430:        selector = IERC721Receiver.onERC721Received.selector;
src/Raffle.sol:491:    /// @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected
src/Raffle.sol:494:    /// @param ticketId Ticket being minted, transferred, or burned.
src/Raffle.sol:504:    /// @dev Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer
src/Raffle.sol:528:    /// @dev Validates the winning range once and allocates all terminal quote-token liabilities without transferring
src/Raffle.sol:560:    /// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
src/Raffle.sol:561:    ///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
src/Raffle.sol:563:    /// @param amount Raw six-decimal USDC units transferred.
src/Raffle.sol:564:    function _transferQuote(address to, uint256 amount) private {
src/Raffle.sol:566:        quoteToken.safeTransfer(to, amount);
=== Step 2 Applicability Search: Truffle / Test files ===
```

### Step 2 — `slither-check-upgradeability` Output (`scratch/step2-special-features/slither-check-upgradeability-raffle.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
INFO:Slither:
Detector: init-missing
Initializable contract not found, the contract does not follow a standard initalization schema.
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initializable-is-missing
INFO:Slither:
Detector: initialize-target
Raffle (src/Raffle.sol#28-614) needs to be initialized by Raffle.initialize(IRaffle.RaffleInitParams) (src/Raffle.sol#176-206).
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initialize-function
INFO:Slither:2 findings, 8 detectors run
```

### Step 2 — `slither-check-upgradeability --new-contract-name Raffle` Output (`scratch/step2-special-features/slither-check-upgradeability-raffle-self.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
INFO:Slither:
Detector: init-missing
Initializable contract not found, the contract does not follow a standard initalization schema.
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initializable-is-missing
INFO:Slither:
Detector: initialize-target
Raffle (src/Raffle.sol#28-614) needs to be initialized by Raffle.initialize(IRaffle.RaffleInitParams) (src/Raffle.sol#176-206).
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initialize-function
INFO:Slither:
Detector: init-missing
Initializable contract not found, the contract does not follow a standard initalization schema.
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initializable-is-missing
INFO:Slither:
Detector: initialize-target
Raffle (src/Raffle.sol#28-614) needs to be initialized by Raffle.initialize(IRaffle.RaffleInitParams) (src/Raffle.sol#176-206).
Reference: https://github.com/crytic/slither/wiki/Upgradeability-Checks#initialize-function
INFO:Slither:4 findings, 22 detectors run
```

### Step 2 — `slither-check-erc` ERC-721 Output (`scratch/step2-special-features/slither-check-erc721-raffle.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
# Check Raffle

## Check functions
[✓] balanceOf(address) is present
	[✓] balanceOf(address) -> (uint256) (correct return type)
	[✓] balanceOf(address) is view
[✓] ownerOf(uint256) is present
	[✓] ownerOf(uint256) -> (address) (correct return type)
	[✓] ownerOf(uint256) is view
[✓] safeTransferFrom(address,address,uint256,bytes) is present
	[✓] safeTransferFrom(address,address,uint256,bytes) -> () (correct return type)
	[✓] Transfer(address,address,uint256) is emitted
[✓] safeTransferFrom(address,address,uint256) is present
	[✓] safeTransferFrom(address,address,uint256) -> () (correct return type)
	[✓] Transfer(address,address,uint256) is emitted
[✓] transferFrom(address,address,uint256) is present
	[✓] transferFrom(address,address,uint256) -> () (correct return type)
	[✓] Transfer(address,address,uint256) is emitted
[✓] approve(address,uint256) is present
	[✓] approve(address,uint256) -> () (correct return type)
	[✓] Approval(address,address,uint256) is emitted
[✓] setApprovalForAll(address,bool) is present
	[✓] setApprovalForAll(address,bool) -> () (correct return type)
	[✓] ApprovalForAll(address,address,bool) is emitted
[✓] getApproved(uint256) is present
	[✓] getApproved(uint256) -> (address) (correct return type)
	[✓] getApproved(uint256) is view
[✓] isApprovedForAll(address,address) is present
	[✓] isApprovedForAll(address,address) -> (bool) (correct return type)
	[✓] isApprovedForAll(address,address) is view
[✓] supportsInterface(bytes4) is present
	[✓] supportsInterface(bytes4) -> (bool) (correct return type)
	[✓] supportsInterface(bytes4) is view
[✓] name() is present
	[✓] name() -> (string) (correct return type)
	[✓] name() is view
[✓] symbol() is present
	[✓] symbol() -> (string) (correct return type)
[✓] tokenURI(uint256) is present
	[✓] tokenURI(uint256) -> (string) (correct return type)

## Check events
[✓] Transfer(address,address,uint256) is present
	[✓] parameter 0 is indexed
	[✓] parameter 1 is indexed
	[✓] parameter 2 is indexed
[✓] Approval(address,address,uint256) is present
	[✓] parameter 0 is indexed
	[✓] parameter 1 is indexed
	[✓] parameter 2 is indexed
[✓] ApprovalForAll(address,address,bool) is present
	[✓] parameter 0 is indexed
	[✓] parameter 1 is indexed
```

### Step 2 — `slither-check-erc` ERC-165 Output (`scratch/step2-special-features/slither-check-erc165-raffle.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
# Check Raffle

## Check functions
[✓] supportsInterface(bytes4) is present
	[✓] supportsInterface(bytes4) -> (bool) (correct return type)
	[✓] supportsInterface(bytes4) is view
```

### Step 2 — `slither-prop` Attempt Output (`scratch/step2-special-features/slither-prop-raffle.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
ERROR:root:Foundry not yet supported by slither-prop
```

### Step 3 — Graphviz `dot` CLI Attempt (`scratch/step3-diagrams/graphviz-dot-attempt.log`)

```text
zsh:3: command not found: dot
```

### Step 4 — Echidna Initial Run (0-Indexed vs 1-Indexed Discovery) (`scratch/step4-properties/echidna-run-initial-0indexed-spec.log`)

```text
[2026-10-21 14:20:50.42] Compiling `.`... Done! (3.272105s)
Analyzing contract: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol:RaffleEchidnaTest
[2026-10-21 14:20:54.00] Running slither on `.`... Done! (3.202573s)
[2026-10-21 14:20:57.49] [Worker 3] New coverage: 11131 instr, 11 contracts, 1 seqs in corpus
[2026-10-21 14:20:57.53] [Worker 2] New coverage: 11131 instr, 11 contracts, 2 seqs in corpus
[2026-10-21 14:20:57.53] [Worker 1] New coverage: 11131 instr, 11 contracts, 3 seqs in corpus
[2026-10-21 14:20:57.63] [Worker 0] New coverage: 11131 instr, 11 contracts, 4 seqs in corpus
[2026-10-21 14:20:57.86] [Worker 3] New coverage: 11137 instr, 11 contracts, 5 seqs in corpus
[2026-10-21 14:20:57.88] [Worker 0] New coverage: 11137 instr, 11 contracts, 6 seqs in corpus
[2026-10-21 14:20:59.22] [Worker 2] New coverage: 11182 instr, 11 contracts, 7 seqs in corpus
[2026-10-21 14:21:00.29] [status] tests: 0/11, fuzzing: 2632/25000, values: [], cov: 11182, corpus: 7, gas/s: 52192311
[2026-10-21 14:21:01.09] [Worker 0] New coverage: 11211 instr, 11 contracts, 8 seqs in corpus
[2026-10-21 14:21:02.32] [Worker 1] New coverage: 11244 instr, 11 contracts, 9 seqs in corpus
[2026-10-21 14:21:02.72] [Worker 3] Test echidna_ticket_ranges_contiguous falsified!
  Call sequence:
RaffleEchidnaTest.action_settleWinningTicket(257) Time delay: 56 seconds Block delay: 17
RaffleEchidnaTest.action_refundTicket(114392082198915324596904551309716141691634371938068005600052768142791264214697) Time delay: 10 seconds Block delay: 41786
RaffleEchidnaTest.action_buyActor1(97687163678247553333359877090891262391159256122597678153457798188368898705784) Time delay: 1 seconds Block delay: 23840

[2026-10-21 14:21:03.01] [Worker 3] New coverage: 14834 instr, 11 contracts, 10 seqs in corpus
[2026-10-21 14:21:03.29] [status] tests: 1/11, fuzzing: 5348/25000, values: [], cov: 14834, corpus: 10, shrinking: W3:105/2000(1), gas/s: 55952570
[2026-10-21 14:21:04.08] [Worker 0] New coverage: 14865 instr, 11 contracts, 11 seqs in corpus
[2026-10-21 14:21:04.33] [Worker 0] New coverage: 14899 instr, 11 contracts, 12 seqs in corpus
[2026-10-21 14:21:04.54] [Worker 0] New coverage: 14935 instr, 11 contracts, 13 seqs in corpus
[2026-10-21 14:21:05.86] [Worker 0] New coverage: 14938 instr, 11 contracts, 14 seqs in corpus
[2026-10-21 14:21:06.29] [status] tests: 1/11, fuzzing: 7676/25000, values: [], cov: 14938, corpus: 14, shrinking: W3:1457/2000(1), gas/s: 49375789
[2026-10-21 14:21:06.83] [Worker 0] New coverage: 14958 instr, 11 contracts, 15 seqs in corpus
[2026-10-21 14:21:08.03] [Worker 1] New coverage: 15041 instr, 11 contracts, 16 seqs in corpus
[2026-10-21 14:21:09.29] [status] tests: 1/11, fuzzing: 10667/25000, values: [], cov: 15041, corpus: 16, gas/s: 64268171
[2026-10-21 14:21:12.04] [Worker 3] New coverage: 15044 instr, 11 contracts, 17 seqs in corpus
[2026-10-21 14:21:12.30] [status] tests: 1/11, fuzzing: 12992/25000, values: [], cov: 15044, corpus: 17, gas/s: 49595065
[2026-10-21 14:21:15.31] [status] tests: 1/11, fuzzing: 15027/25000, values: [], cov: 15044, corpus: 17, gas/s: 43170300
[2026-10-21 14:21:15.76] [Worker 2] New coverage: 15047 instr, 11 contracts, 18 seqs in corpus
[2026-10-21 14:21:16.49] [Worker 3] New coverage: 15067 instr, 11 contracts, 19 seqs in corpus
[2026-10-21 14:21:16.53] [Worker 1] New coverage: 15070 instr, 11 contracts, 20 seqs in corpus
[2026-10-21 14:21:18.31] [status] tests: 1/11, fuzzing: 17071/25000, values: [], cov: 15070, corpus: 20, gas/s: 43860851
[2026-10-21 14:21:21.31] [status] tests: 1/11, fuzzing: 19253/25000, values: [], cov: 15070, corpus: 20, gas/s: 46318360
[2026-10-21 14:21:22.93] [Worker 1] New coverage: 15073 instr, 11 contracts, 21 seqs in corpus
[2026-10-21 14:21:24.31] [status] tests: 1/11, fuzzing: 21290/25000, values: [], cov: 15073, corpus: 21, gas/s: 42441941
[2026-10-21 14:21:25.27] [Worker 1] New coverage: 15086 instr, 11 contracts, 22 seqs in corpus
[2026-10-21 14:21:25.55] [Worker 0] New coverage: 15089 instr, 11 contracts, 23 seqs in corpus
[2026-10-21 14:21:27.31] [status] tests: 1/11, fuzzing: 23080/25000, values: [], cov: 15089, corpus: 23, gas/s: 35560400
[2026-10-21 14:21:27.95] [Worker 1] Test limit reached. Stopping.
[2026-10-21 14:21:28.65] [Worker 0] Test limit reached. Stopping.
[2026-10-21 14:21:29.25] [Worker 2] New coverage: 15092 instr, 11 contracts, 24 seqs in corpus
[2026-10-21 14:21:29.25] [Worker 2] Test limit reached. Stopping.
[2026-10-21 14:21:30.31] [status] tests: 1/11, fuzzing: 24552/25000, values: [], cov: 15092, corpus: 24, gas/s: 29309000
[2026-10-21 14:21:33.03] [Worker 3] Test limit reached. Stopping.
[2026-10-21 14:21:33.03] [status] tests: 1/11, fuzzing: 25095/25000, values: [], cov: 15092, corpus: 24, gas/s: 10555929
echidna_prize_custody_consistency: passing
echidna_refund_liability_conservation: passing
echidna_quote_solvency: passing
echidna_winning_ticket_bounds: passing
echidna_settlement_conservation: passing
echidna_implementation_locked: passing
echidna_factory_registry_bijection: passing
echidna_no_protocol_destination_holds_tickets: passing
echidna_ticket_ranges_contiguous: failed!💥  
  Reason: ReturnFalse
  Call sequence:
    RaffleEchidnaTest.action_buyActor1(0)

Traces: 
call 0x30c8860f6a38819B59E1255A499A10bCBF4Ee747::ticketCount() (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol:435)
 ├╴delegatecall 0x9bcE6EF7cc06197d5aa59E288313BbDaF5A32f05::ticketCount() <no source map>
 │  └╴← (1)
 └╴← (1)
call 0x30c8860f6a38819B59E1255A499A10bCBF4Ee747::totalEntries() (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol:436)
 ├╴delegatecall 0x9bcE6EF7cc06197d5aa59E288313BbDaF5A32f05::totalEntries() <no source map>
 │  └╴← (1)
 └╴← (1)
call 0x30c8860f6a38819B59E1255A499A10bCBF4Ee747::ticketRange(1) (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol:442)
 ├╴delegatecall 0x9bcE6EF7cc06197d5aa59E288313BbDaF5A32f05::ticketRange(1) <no source map>
 │  └╴← (1, 1)
 └╴← (1, 1)

echidna_entry_accounting: passing
echidna_status_transitions_valid: passing

Unique instructions: 15092
Unique codehashes: 11
Corpus size: 24
Seed: 5956616321439916292
Total calls: 25095
```

### Step 4 — Echidna Final Run (11/11 Passing Properties) (`scratch/step4-properties/echidna-run.log`)

```text
[2026-10-21 14:26:28.43] Compiling `.`... Done! (4.956639s)
Analyzing contract: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/contracts-fuzz/src/echidna/RaffleEchidnaTest.sol:RaffleEchidnaTest
[2026-10-21 14:26:33.81] Running slither on `.`... Done! (3.278264s)
[2026-10-21 14:26:37.41] [Worker 0] New coverage: 11131 instr, 11 contracts, 1 seqs in corpus
[2026-10-21 14:26:37.45] [Worker 3] New coverage: 11131 instr, 11 contracts, 2 seqs in corpus
[2026-10-21 14:26:37.46] [Worker 2] New coverage: 11131 instr, 11 contracts, 3 seqs in corpus
[2026-10-21 14:26:37.47] [Worker 1] New coverage: 11131 instr, 11 contracts, 4 seqs in corpus
[2026-10-21 14:26:38.16] [Worker 0] New coverage: 11134 instr, 11 contracts, 5 seqs in corpus
[2026-10-21 14:26:38.42] [Worker 0] New coverage: 11175 instr, 11 contracts, 6 seqs in corpus
[2026-10-21 14:26:38.54] [Worker 1] New coverage: 11178 instr, 11 contracts, 7 seqs in corpus
[2026-10-21 14:26:39.70] [Worker 1] New coverage: 11181 instr, 11 contracts, 8 seqs in corpus
[2026-10-21 14:26:40.18] [status] tests: 0/11, fuzzing: 2896/25000, values: [], cov: 11181, corpus: 8, gas/s: 58271564
[2026-10-21 14:26:40.72] [Worker 2] New coverage: 11184 instr, 11 contracts, 9 seqs in corpus
[2026-10-21 14:26:40.85] [Worker 1] New coverage: 11187 instr, 11 contracts, 10 seqs in corpus
[2026-10-21 14:26:41.91] [Worker 3] New coverage: 11221 instr, 11 contracts, 11 seqs in corpus
[2026-10-21 14:26:43.19] [status] tests: 0/11, fuzzing: 5612/25000, values: [], cov: 11221, corpus: 11, gas/s: 55732218
[2026-10-21 14:26:43.60] [Worker 1] New coverage: 11224 instr, 11 contracts, 12 seqs in corpus
[2026-10-21 14:26:46.19] [status] tests: 0/11, fuzzing: 7880/25000, values: [], cov: 11224, corpus: 12, gas/s: 48923373
[2026-10-21 14:26:48.44] [Worker 0] New coverage: 11227 instr, 11 contracts, 13 seqs in corpus
[2026-10-21 14:26:49.19] [status] tests: 0/11, fuzzing: 10076/25000, values: [], cov: 11227, corpus: 13, gas/s: 44955395
[2026-10-21 14:26:49.75] [Worker 2] New coverage: 14395 instr, 11 contracts, 14 seqs in corpus
[2026-10-21 14:26:50.01] [Worker 3] New coverage: 14448 instr, 11 contracts, 15 seqs in corpus
[2026-10-21 14:26:51.36] [Worker 0] New coverage: 14468 instr, 11 contracts, 16 seqs in corpus
[2026-10-21 14:26:51.90] [Worker 1] New coverage: 14515 instr, 11 contracts, 17 seqs in corpus
[2026-10-21 14:26:52.21] [status] tests: 0/11, fuzzing: 11882/25000, values: [], cov: 14515, corpus: 17, gas/s: 39418098
[2026-10-21 14:26:54.86] [Worker 0] New coverage: 14550 instr, 11 contracts, 18 seqs in corpus
[2026-10-21 14:26:55.21] [status] tests: 0/11, fuzzing: 13582/25000, values: [], cov: 14572, corpus: 18, gas/s: 36476578
[2026-10-21 14:26:55.47] [Worker 3] New coverage: 14572 instr, 11 contracts, 19 seqs in corpus
[2026-10-21 14:26:58.22] [status] tests: 0/11, fuzzing: 15035/25000, values: [], cov: 14572, corpus: 19, gas/s: 31952670
[2026-10-21 14:26:58.42] [Worker 2] New coverage: 14575 instr, 11 contracts, 20 seqs in corpus
[2026-10-21 14:26:59.92] [Worker 1] New coverage: 14578 instr, 11 contracts, 21 seqs in corpus
[2026-10-21 14:27:01.25] [status] tests: 0/11, fuzzing: 16739/25000, values: [], cov: 14578, corpus: 21, gas/s: 37272765
[2026-10-21 14:27:02.64] [Worker 3] New coverage: 14598 instr, 11 contracts, 22 seqs in corpus
[2026-10-21 14:27:02.89] [Worker 2] New coverage: 14601 instr, 11 contracts, 23 seqs in corpus
[2026-10-21 14:27:04.30] [status] tests: 0/11, fuzzing: 18283/25000, values: [], cov: 14601, corpus: 23, gas/s: 35137973
[2026-10-21 14:27:07.23] [Worker 3] New coverage: 14621 instr, 11 contracts, 24 seqs in corpus
[2026-10-21 14:27:07.30] [status] tests: 0/11, fuzzing: 20109/25000, values: [], cov: 14621, corpus: 24, gas/s: 41228848
[2026-10-21 14:27:07.81] [Worker 2] New coverage: 14634 instr, 11 contracts, 25 seqs in corpus
[2026-10-21 14:27:08.59] [Worker 0] New coverage: 14654 instr, 11 contracts, 26 seqs in corpus
[2026-10-21 14:27:09.12] [Worker 1] New coverage: 14677 instr, 11 contracts, 27 seqs in corpus
[2026-10-21 14:27:10.30] [status] tests: 0/11, fuzzing: 22021/25000, values: [], cov: 14677, corpus: 27, gas/s: 42833166
[2026-10-21 14:27:10.56] [Worker 0] New coverage: 14697 instr, 11 contracts, 28 seqs in corpus
[2026-10-21 14:27:13.30] [status] tests: 0/11, fuzzing: 24272/25000, values: [], cov: 15068, corpus: 28, gas/s: 49641982
[2026-10-21 14:27:13.35] [Worker 2] New coverage: 15068 instr, 11 contracts, 29 seqs in corpus
[2026-10-21 14:27:13.57] [Worker 0] Test limit reached. Stopping.
[2026-10-21 14:27:13.94] [Worker 1] Test limit reached. Stopping.
[2026-10-21 14:27:14.19] [Worker 3] Test limit reached. Stopping.
[2026-10-21 14:27:14.21] [Worker 2] Test limit reached. Stopping.
[2026-10-21 14:27:14.21] [status] tests: 0/11, fuzzing: 25070/25000, values: [], cov: 15068, corpus: 29, gas/s: 52928345
echidna_prize_custody_consistency: passing
echidna_refund_liability_conservation: passing
echidna_quote_solvency: passing
echidna_winning_ticket_bounds: passing
echidna_settlement_conservation: passing
echidna_implementation_locked: passing
echidna_factory_registry_bijection: passing
echidna_no_protocol_destination_holds_tickets: passing
echidna_ticket_ranges_contiguous: passing
echidna_entry_accounting: passing
echidna_status_transitions_valid: passing

Unique instructions: 15068
Unique codehashes: 11
Corpus size: 29
Seed: 6260699388564689083
Total calls: 25070
```

### Step 4 — Foundry Stateful Invariant & Stateless Fuzz Suite (`scratch/step4-properties/forge-test-run.log`)

```text
Compiling 2 files with Solc 0.8.36
Solc 0.8.36 finished in 2.16s
Compiler run successful!
2026-10-21T21:25:58.192430Z  WARN forge::test: failed calling "targetArtifactSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193021Z  WARN forge::test: failed calling "targetArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193039Z  WARN forge::test: failed calling "excludeArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193096Z  WARN forge::test: failed calling "targetSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.193110Z  WARN forge::test: failed calling "excludeSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.192375Z  WARN forge::test: failed calling "targetArtifactSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193195Z  WARN forge::test: failed calling "targetArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193212Z  WARN forge::test: failed calling "excludeArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193246Z  WARN forge::test: failed calling "targetSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.193258Z  WARN forge::test: failed calling "excludeSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.193441Z  WARN forge::test: failed calling "excludeContracts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193452Z  WARN forge::test: failed calling "excludeContracts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193522Z  WARN forge::test: failed calling "targetInterfaces()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.193523Z  WARN forge::test: failed calling "targetInterfaces()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.193545Z  WARN forge::test: failed calling "targetSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193553Z  WARN forge::test: failed calling "targetSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193559Z  WARN forge::test: failed calling "excludeSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.193567Z  WARN forge::test: failed calling "excludeSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232623Z  WARN forge::test: failed calling "targetArtifactSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232644Z  WARN forge::test: failed calling "targetArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232657Z  WARN forge::test: failed calling "excludeArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232687Z  WARN forge::test: failed calling "targetSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.232700Z  WARN forge::test: failed calling "excludeSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.232722Z  WARN forge::test: failed calling "excludeContracts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232741Z  WARN forge::test: failed calling "targetInterfaces()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.232751Z  WARN forge::test: failed calling "targetSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.232761Z  WARN forge::test: failed calling "excludeSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243461Z  WARN forge::test: failed calling "targetArtifactSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243484Z  WARN forge::test: failed calling "targetArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243499Z  WARN forge::test: failed calling "excludeArtifacts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243538Z  WARN forge::test: failed calling "targetSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.243551Z  WARN forge::test: failed calling "excludeSenders()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.243577Z  WARN forge::test: failed calling "excludeContracts()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243595Z  WARN forge::test: failed calling "targetInterfaces()": execution reverted: EvmError: Revert (gas: 21251)
2026-10-21T21:25:58.243606Z  WARN forge::test: failed calling "targetSelectors()": execution reverted: EvmError: Revert (gas: 21272)
2026-10-21T21:25:58.243615Z  WARN forge::test: failed calling "excludeSelectors()": execution reverted: EvmError: Revert (gas: 21272)

Ran 6 tests for test/foundry/RaffleWorkflowInvariants.t.sol:RaffleWorkflowInvariantsTest
[PASS] invariant_quoteSolvencyAndAccounting() (runs: 256, calls: 16384, reverts: 14)

╭-----------------------+----------------------------+-------+---------+----------╮
| Contract              | Selector                   | Calls | Reverts | Discards |
+=================================================================================+
| StatefulRaffleHandler | step_buy1                  | 1561  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_buy2                  | 1446  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_claimProceedsAndPrize | 1401  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_enableRefunds         | 1489  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_fulfillDraw           | 1465  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_redeemWinning         | 1437  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_refundTicket          | 1550  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_requestDraw           | 1523  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_settleExact           | 1531  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_transfer              | 1469  | 14      | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_warp                  | 1512  | 0       | 0        |
╰-----------------------+----------------------------+-------+---------+----------╯

[PASS] invariant_ticketRangesAndStatusLifecycle() (runs: 256, calls: 16384, reverts: 14)

╭-----------------------+----------------------------+-------+---------+----------╮
| Contract              | Selector                   | Calls | Reverts | Discards |
+=================================================================================+
| StatefulRaffleHandler | step_buy1                  | 1561  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_buy2                  | 1446  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_claimProceedsAndPrize | 1401  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_enableRefunds         | 1489  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_fulfillDraw           | 1465  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_redeemWinning         | 1437  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_refundTicket          | 1550  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_requestDraw           | 1523  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_settleExact           | 1531  | 0       | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_transfer              | 1469  | 14      | 0        |
|-----------------------+----------------------------+-------+---------+----------|
| StatefulRaffleHandler | step_warp                  | 1512  | 0       | 0        |
╰-----------------------+----------------------------+-------+---------+----------╯

[PASS] testFuzz_cashWonSettlementAndClaims(uint128,uint128,uint256) (runs: 1000, μ: 567041, ~: 567051)
[PASS] testFuzz_nftWonSettlementAndClaims(uint128,uint128,uint256) (runs: 1000, μ: 628688, ~: 627199)
[PASS] testFuzz_refundPathsAndSponsorPrizeReclaim(uint128,uint128,bool) (runs: 1000, μ: 407181, ~: 363486)
[PASS] test_protocolDestinationGuardsAndCallbackIgnore() (gas: 315784)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 16.85s (28.87s CPU time)

Ran 1 test suite in 16.85s (16.85s CPU time): 6 tests passed, 0 failed, 0 skipped (6 total tests)
```

### Step 4 — Custom Slither Python API Checks (`scratch/step4-properties/custom-slither-checks.log`)

```text
WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
================================================================================
CUSTOM SLITHER PYTHON API CHECKS: raffle-fun (Solidity 0.8.36)
Target workspace: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/contracts-exact
================================================================================

[Check 1] ReentrancyGuard (`nonReentrant`) Coverage on External/Public Mutating Functions
  - Raffle.rawFulfillRandomWords(uint256,uint256[]): modifiers=[] -> PASS (documented custom guard)
  - Raffle.approve(address,uint256): modifiers=[] -> PASS (documented custom guard)
  - Raffle.setApprovalForAll(address,bool): modifiers=[] -> PASS (documented custom guard)
  - Raffle.transferFrom(address,address,uint256): modifiers=[] -> PASS (documented custom guard)
  - Raffle.safeTransferFrom(address,address,uint256): modifiers=[] -> PASS (documented custom guard)
  - Raffle.safeTransferFrom(address,address,uint256,bytes): modifiers=[] -> PASS (documented custom guard)
  - Raffle.initialize(IRaffle.RaffleInitParams): modifiers=[] -> PASS (documented custom guard)
  - Raffle.buyEntries(address,uint128): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.requestDraw(): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.enableRefunds(): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.settleWinningTicket(uint256): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.redeemWinningTicket(uint256): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.refundTickets(uint256[]): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.releaseSponsorProceeds(): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.releaseProtocolFees(): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.releaseSponsorPrize(): modifiers=['nonReentrant'] -> PASS (nonReentrant)
  - Raffle.onERC721Received(address,address,uint256,bytes): modifiers=[] -> PASS (documented custom guard)
  - RaffleFactory.createRaffle(IRaffleFactory.CreateRaffleParams): modifiers=['nonReentrant'] -> PASS (nonReentrant)

[Check 2] Protocol Destination Guard (`_isProtocolDestination`) Coverage
  - Raffle._update(address,uint256,address): calls _isProtocolDestination = False
  - Raffle.initialize(IRaffle.RaffleInitParams): calls _isProtocolDestination = True
  - Raffle.buyEntries(address,uint128): calls _isProtocolDestination = False
  - Raffle._update(address,uint256,address): calls _isProtocolDestination = True
  - Raffle._transferQuote(address,uint256): calls _isProtocolDestination = True
  - RaffleFactory._validateCreateParams reads state vars: ['isRaffle', 'quoteToken', 'raffleImplementation', 'vrfWrapper']
  - Observation: RaffleFactory._validateCreateParams validates sponsorRecipient and prizeToken,
    while msg.sender (sponsor) is validated inside Raffle.initialize via _isProtocolDestination(params.sponsor, params.prizeToken).

[Check 3] Lifecycle Status Machine Guard Verification on Raffle Entry Points
  - Raffle.rawFulfillRandomWords(uint256,uint256[]): reads_status=True, calls_requireStatus=False
  - Raffle.approve(address,uint256): reads_status=False, calls_requireStatus=False
  - Raffle.setApprovalForAll(address,bool): reads_status=False, calls_requireStatus=False
  - Raffle.transferFrom(address,address,uint256): reads_status=False, calls_requireStatus=False
  - Raffle.safeTransferFrom(address,address,uint256): reads_status=False, calls_requireStatus=False
  - Raffle.safeTransferFrom(address,address,uint256,bytes): reads_status=False, calls_requireStatus=False
  - Raffle.receive(): reads_status=False, calls_requireStatus=False
  - Raffle.initialize(IRaffle.RaffleInitParams): reads_status=False, calls_requireStatus=False
  - Raffle.buyEntries(address,uint128): reads_status=True, calls_requireStatus=True
  - Raffle.requestDraw(): reads_status=True, calls_requireStatus=True
  - Raffle.enableRefunds(): reads_status=True, calls_requireStatus=False
  - Raffle.settleWinningTicket(uint256): reads_status=True, calls_requireStatus=False
  - Raffle.redeemWinningTicket(uint256): reads_status=True, calls_requireStatus=False
  - Raffle.refundTickets(uint256[]): reads_status=True, calls_requireStatus=True
  - Raffle.releaseSponsorProceeds(): reads_status=False, calls_requireStatus=False
  - Raffle.releaseProtocolFees(): reads_status=False, calls_requireStatus=False
  - Raffle.releaseSponsorPrize(): reads_status=True, calls_requireStatus=False
  - Raffle.onERC721Received(address,address,uint256,bytes): reads_status=True, calls_requireStatus=False

[Check 4] ERC-1167 Clone Constructor State vs Clone Initializer Audit
  - Constructor state variables written (affect implementation only, unless immutable): ['_name', '_symbol', 'factory', 'i_linkToken', 'i_vrfV2PlusWrapper', 'initialized', 'quoteToken', 'status']
  - Immutables (embedded in bytecode, shared by ERC-1167 clones): ['factory', 'i_linkToken', 'i_vrfV2PlusWrapper', 'quoteToken']
  - Constants: ['ENTRY_PRICE', 'callbackGasLimit', 'requestConfirmations']
  - initialize() state variables written (in clone storage): ['endTime', 'initialized', 'prizeToken', 'prizeTokenId', 'protocolTreasury', 'raffleId', 'reserveEntries', 'sponsor', 'sponsorRecipient', 'status']
  - Verification: ERC721 `_name` and `_symbol` are written in constructor, but Raffle overrides `name()` and `symbol()` as `pure` functions.
  - Verification: ReentrancyGuard writes `_status = 1` in constructor; in clones slot starts at 0 (which != ENTERED(2)) and sets to 1 after first nonReentrant call.

[Check 5] Quote Accounting State Variable Writers & Solvency Invariant Audit
  - totalEntries: written only by ['buyEntries(address,uint128)']
  - unsettledPot: written only by ['_settleWinningTicket(uint256)', 'buyEntries(address,uint128)', 'enableRefunds()']
  - remainingRefundLiability: written only by ['enableRefunds()', 'refundTickets(uint256[])']
  - winnerProceeds: written only by ['_settleWinningTicket(uint256)', 'redeemWinningTicket(uint256)']
  - sponsorProceeds: written only by ['_settleWinningTicket(uint256)', 'releaseSponsorProceeds()']
  - protocolFees: written only by ['_settleWinningTicket(uint256)', 'releaseProtocolFees()']
  - settlementComplete: written only by ['_settleWinningTicket(uint256)']
  - winnerRedeemed: written only by ['redeemWinningTicket(uint256)']
  - prizeClaimed: written only by ['redeemWinningTicket(uint256)', 'releaseSponsorPrize()']

Saved structured custom check report to /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S6/work/scratch/step4-properties/custom-slither-checks.json
```

### Step 4 — Manticore Symbolic Execution Attempt (`scratch/step4-properties/manticore-attempt.log`)

```text
zsh:5: command not found: manticore
```
