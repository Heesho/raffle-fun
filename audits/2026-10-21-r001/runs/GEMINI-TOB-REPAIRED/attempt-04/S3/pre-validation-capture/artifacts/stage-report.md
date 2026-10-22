#=== TOKEN INTEGRATION ANALYSIS REPORT ===

- **Project**: `raffle-fun` (`packages/contracts` & `DESIGN.md`)
- **Stage**: S3 — Trail of Bits `token-integration-analyzer` (Native Whole-Stage Execution)
- **Token Analyzed**:
  1. **Token Implementation**: `Raffle` (`packages/contracts/src/Raffle.sol`) — Custom ERC-721 sequential range-ticket token (`name: "raffle.fun Ticket"`, `symbol: "RAFFLE"`, inheriting OpenZeppelin Contracts v5.6.0 `ERC721`).
  2. **Token Integration — Quote Token (`quoteToken`)**: External ERC-20 token (`IERC20` / `IERC20Metadata`), designed for canonical 6-decimal USDC (`ENTRY_PRICE = 1_000_000`, `QUOTE_TOKEN_DECIMALS = 6`), integrated via OpenZeppelin `SafeERC20`.
  3. **Token Integration — Prize Token (`prizeToken`)**: External sponsor-supplied ERC-721 token (`IERC721` / `IERC165`) per raffle clone, escrowed via `safeTransferFrom` + `onERC721Received` and released via raw `transferFrom` + post-transfer `ownerOf` verification.
  4. **Token Integration — Chainlink VRF Wrapper & LINK (`i_vrfV2PlusWrapper`, `i_linkToken`)**: External `IVRFV2PlusWrapper` and `LinkTokenInterface` inherited via Chainlink `VRFV2PlusWrapperConsumerBase` (`vrfV2PlusWrapper.link()`); `Raffle` uses the native ETH direct-funding path (`requestRandomnessPayInNative` -> `requestRandomWordsInNative`) and never invokes the LINK `transferAndCall` path (`requestRandomness`).
- **Platform**: Ethereum / EVM, Solidity `0.8.36` (compiled with `solc 0.8.36+commit.bbd5677d.Darwin.appleclang`, EVM target `paris`, optimizer enabled with `200` runs).
- **Analysis Date**: October 21, 2026

---

## EXECUTIVE SUMMARY

- **Token Type**: ERC-721 Ticket Token Implementation (`Raffle`) + Protocol Integrating External ERC-20 (`quoteToken`), External ERC-721 (`prizeToken`), and Chainlink VRF v2.5 Wrapper (`vrfWrapper` / `i_linkToken`).
- **Overall Risk Level**: **MEDIUM** (Low risk under strictly canonical USDC and honest, standards-compliant ERC-721 prize tokens; High/Medium integration risks if untrusted/weird ERC-721 prize tokens or fee-bearing/rebasing/blocklisting ERC-20 tokens interact with the protocol).
- **Critical Issues**: 0
- **High Issues**: 1 (Architectural / Untrusted ERC-721 `prizeToken` Integration Risk)
- **Medium Issues**: 3
- **Low / Informational Issues**: 3

### Summary of Identified Findings

| ID | Severity | Category | Title | Primary Location |
| :--- | :--- | :--- | :--- | :--- |
| **TIA-01** | **High** | Cat. 8, 9, 10 (Prize ERC-721 Integration) | Decoupled `NftWon` Storage Settlement (`settleWinningTicket`) and Untrusted `prizeToken` Delivery (`redeemWinningTicket`) Allows Malicious/Pausable Prize Token Sponsor to Claim 95% USDC Proceeds While Blocking Winner NFT Redemption | `src/Raffle.sol:304-346`, `src/Raffle.sol:375-382`, `src/RaffleFactory.sol:124-175`, `DESIGN.md:9-19` |
| **TIA-02** | **Medium** | Cat. 8, 9, 10 (Prize ERC-721 Delivery) | Prize NFT Delivery in `redeemWinningTicket` and `releaseSponsorPrize` Uses Raw `IERC721.transferFrom` Instead of `safeTransferFrom`, Risking Locked NFTs in Non-`IERC721Receiver` Contract Recipients | `src/Raffle.sol:334-336`, `src/Raffle.sol:404-406`, `src/RaffleFactory.sol:124-175` |
| **TIA-03** | **Medium** | Cat. 3, 7.7, 7.8, 8 (Weird ERC-20 Blocklist / Pause) | Immutable `sponsorRecipient` and `protocolTreasury` Have No Rotation or Fallback Recipient If Blocklisted by `quoteToken` (USDC), Permanently Freezing `sponsorProceeds` or `protocolFees` | `src/Raffle.sol:50-55`, `src/Raffle.sol:198-199`, `src/Raffle.sol:375-393`, `src/RaffleFactory.sol:32` |
| **TIA-04** | **Medium** | Cat. 5, 7.3, 7.4, 8 (ERC-20 Balance Verification) | `buyEntries` Credits `unsettledPot` by Nominal `grossAmount` Without Before/After Balance Verification (`quoteToken` Fee-on-Transfer / Deflationary / Rebasing Incompatibility) | `src/Raffle.sol:223-234`, `src/RaffleFactory.sol:70-74` |
| **TIA-05** | **Low** | Cat. 4, 8 (ERC-20 Token Validation) | `RaffleFactory` Constructor Validates Only `quoteToken` Code Presence and `decimals() == 6`; Unsolicited Direct ERC-20 Transfers (`quoteToken` or `i_linkToken`) to `Raffle` Are Unrecoverable | `src/RaffleFactory.sol:70-74`, `src/Raffle.sol:469-477` |
| **TIA-06** | **Low** | Cat. 2, 9 (ERC-721 Implementation & Storage) | `Raffle` ERC-721 Ticket Implementation Leaves `tokenURI(ticketId)` Empty (`""`) and Inherits Redundant Unused `_name` and `_symbol` Storage Slots in Every Clone | `src/Raffle.sol:28`, `src/Raffle.sol:156`, `src/Raffle.sol:486-494` |
| **TIA-07** | **Informational** | Cat. 2, 8, 10 (Static Analysis / Gas & Loop Bounds) | `refundTickets` Loops Over `_burn` -> `_update` (`calls-loop` Detector) and Arithmetic-Driving Events Lack Indexed Parameters (`events-maths` Detector) | `src/Raffle.sol:349-372`, `src/Raffle.sol:497-501`, `src/interfaces/IRaffle.sol:221-289` |

---

## PHASE 1: CONTEXT DISCOVERY

### 1.1 Input Inventory & Integrity Verification

All 43 pristine project inputs and 5 pinned skill files were read directly and verified unmodified:
- **Pinned Skill Files (5)**:
  - `.agents/skills/token-integration-analyzer/SKILL.md`
  - `.agents/skills/token-integration-analyzer/resources/ASSESSMENT_CATEGORIES.md`
  - `.agents/skills/token-integration-analyzer/resources/REPORT_TEMPLATES.md`
  - `.agents/skills/token-integration-analyzer/agents/openai.yaml`
  - `.agents/skills/token-integration-analyzer/assets/trail-of-bits-mark.svg`
- **Owned Solidity Source Files (5)** (`packages/contracts/src/`):
  - [`src/Raffle.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol) (614 lines)
  - [`src/RaffleFactory.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol) (186 lines)
  - [`src/interfaces/IRaffle.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffle.sol) (521 lines)
  - [`src/interfaces/IRaffleFactory.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffleFactory.sol) (150 lines)
  - [`src/libraries/RaffleConstants.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/libraries/RaffleConstants.sol) (43 lines)
- **Local Dependency Solidity Files (31)** (`packages/contracts/node_modules/`):
  - 4 Chainlink Contracts v1.5.0 files (`VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`, `LinkTokenInterface.sol`).
  - 27 OpenZeppelin Contracts v5.6.0 files (`ERC721.sol`, `IERC721.sol`, `IERC721Metadata.sol`, `IERC721Receiver.sol`, `ERC721Utils.sol`, `SafeERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `IERC20Permit.sol`, `IERC1363.sol`, `Clones.sol`, `ReentrancyGuard.sol`, `StorageSlot.sol`, `Address.sol`, `Context.sol`, `Errors.sol`, `Strings.sol`, `ERC165.sol`, `IERC165.sol`, `draft-IERC6093.sol`, `IERC7913.sol`, `Math.sol`, `SafeCast.sol`, `SignedMath.sol`, `Panic.sol`, `Comparators.sol`, `SlotDerivation.sol`).
  - All 31 dependency files were verified byte-for-byte against [`dependency-hashes.json`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/dependency-hashes.json) via SHA-256 verification.
- **Specification & Configuration Files (7)**:
  - [`DESIGN.md`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md), `dependency-hashes.json`, `pnpm-lock.yaml`, `packages/contracts/foundry.toml`, `packages/contracts/hardhat.config.ts`, `packages/contracts/package.json`, `packages/contracts/remappings.txt`.

### 1.2 Analysis Context Determination

| Dimension | Classification | Evidence |
| :--- | :--- | :--- |
| **Token Implementation** | **Yes — Custom ERC-721 Ticket Token (`Raffle`)** | [`Raffle.sol:28`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L28) inherits OpenZeppelin `ERC721`. Each ERC-1167 clone represents one raffle whose tickets are sequential ERC-721 tokens (`ticketId = 1..ticketCount`) minted via `_safeMint` in `buyEntries` (`Raffle.sol:235`) and burned via `_burn` in `redeemWinningTicket` (`Raffle.sol:331`) or `refundTickets` (`Raffle.sol:361`). |
| **Token Integration (ERC-20)** | **Yes — External ERC-20 `quoteToken` & `i_linkToken`** | `quoteToken` is configured at factory deployment (`RaffleFactory.sol:70-74`) and passed to `Raffle` as an `immutable` `IERC20` (`Raffle.sol:58, 162`). Used in `buyEntries` (`quoteToken.safeTransferFrom`, `Raffle.sol:224`) and `_transferQuote` (`quoteToken.safeTransfer`, `Raffle.sol:566`). `i_linkToken` is inherited from `VRFV2PlusWrapperConsumerBase` (`VRFV2PlusWrapperConsumerBase.sol:34, 45`), though `Raffle` only invokes native ETH VRF requests (`Raffle.sol:257`). |
| **Token Integration (ERC-721)** | **Yes — External ERC-721 `prizeToken`** | Sponsors supply an external `prizeToken` and `prizeTokenId` per raffle (`RaffleFactory.sol:80-115`). Validated via `IERC165.supportsInterface(type(IERC721).interfaceId)` (`RaffleFactory.sol:167`), escrowed via `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:101`) + `onERC721Received` (`Raffle.sol:413-431`) + `prize.ownerOf` verification (`RaffleFactory.sol:102`), and delivered via `prizeToken.transferFrom` + `ownerOf` verification (`Raffle.sol:334-336, 404-406`). |
| **Platform** | **Ethereum / EVM (Solidity `0.8.36`)** | Exact pragma `pragma solidity 0.8.36;` across all 5 owned source files; `evm_version = "paris"` in `packages/contracts/foundry.toml:6`. |
| **Token Types** | **Both ERC-20 and ERC-721** | Implements ERC-721 (`Raffle` tickets); integrates ERC-20 (`quoteToken`, `i_linkToken`) and ERC-721 (`prizeToken`). |

---

## PHASE 2: SLITHER ANALYSIS & PROPERTY TESTING

All executable tooling was run against isolated workspace copies under `scratch/contracts-orig/` and `scratch/contracts-echidna/` without touching any protected input files.

### 2.1 Tool Versions & Execution Environment

- **Solidity Compiler**: `solc, the solidity compiler commandline interface Version: 0.8.36+commit.bbd5677d.Darwin.appleclang`
- **Slither**: `0.11.6` (`/opt/homebrew/Cellar/slither-analyzer/0.11.6/libexec/bin/slither`, `slither-check-erc`, `slither-prop`)
- **Foundry (`forge`)**: `forge Version: 1.7.1-v1.5.1`
- **Echidna**: `Echidna 2.3.3`

### 2.2 `slither-check-erc` Results

#### A. ERC-721 Conformity Check on `Raffle` (`scratch/logs/05_slither_check_erc721_orig.log`)

- **Command**: `slither-check-erc . Raffle --erc erc721` (executed in `scratch/contracts-orig`)
- **Result**: **PASS (13/13 functions, 3/3 events, 0 broken ERC-721 checks)**

```text
# Check Raffle

## Check functions
[✓] balanceOf(address) is present
        [✓] balanceOf(address) -> (uint256) (correct return value)
        [✓] balanceOf(address) is view
[✓] ownerOf(uint256) is present
        [✓] ownerOf(uint256) -> (address) (correct return value)
        [✓] ownerOf(uint256) is view
[✓] safeTransferFrom(address,address,uint256,bytes) is present
        [✓] safeTransferFrom(address,address,uint256,bytes) -> () (correct return value)
[✓] safeTransferFrom(address,address,uint256) is present
        [✓] safeTransferFrom(address,address,uint256) -> () (correct return value)
[✓] transferFrom(address,address,uint256) is present
        [✓] transferFrom(address,address,uint256) -> () (correct return value)
[✓] approve(address,uint256) is present
        [✓] approve(address,uint256) -> () (correct return value)
[✓] setApprovalForAll(address,bool) is present
        [✓] setApprovalForAll(address,bool) -> () (correct return value)
[✓] getApproved(uint256) is present
        [✓] getApproved(uint256) -> (address) (correct return value)
        [✓] getApproved(uint256) is view
[✓] isApprovedForAll(address,address) is present
        [✓] isApprovedForAll(address,address) -> (bool) (correct return value)
        [✓] isApprovedForAll(address,address) is view
[✓] supportsInterface(bytes4) is present
        [✓] supportsInterface(bytes4) -> (bool) (correct return value)
        [✓] supportsInterface(bytes4) is view
[✓] name() is present
        [✓] name() -> (string) (correct return value)
        [✓] name() is view
[✓] symbol() is present
        [✓] symbol() -> (string) (correct return value)
        [✓] symbol() is view
[✓] tokenURI(uint256) is present
        [✓] tokenURI(uint256) -> (string) (correct return value)
        [✓] tokenURI(uint256) is view

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

#### B. ERC-20 Conformity Check on `Raffle` (`scratch/logs/06_slither_check_erc20_orig.log`)

- **Command**: `slither-check-erc . Raffle --erc erc20` (executed in `scratch/contracts-orig`)
- **Result**: Expectedly reports missing ERC-20 functions (`totalSupply`, `transfer`, `allowance`, `decimals`) and `Transfer`/`Approval` 3rd-parameter indexing differences because `Raffle` is an ERC-721 token, not an ERC-20 token. No owned contract implements an ERC-20 token.

### 2.3 `slither --print human-summary` Results (`scratch/logs/03_slither_human_summary_orig.log`)

- **Command**: `slither . --print human-summary`

```text
Compiled with Foundry
Total number of contracts in source files: 5
Total number of contracts in dependencies: 31
Source lines of code (SLOC) in source files: 710
Source lines of code (SLOC) in dependencies: 2220
Number of assembly lines: 0
Number of optimization issues: 0
Number of informational issues: 43
Number of low issues: 35
Number of medium issues: 24
Number of high issues: 0

ERCs: ERC721, ERC165

+-------------------+------------------+---------------+--------------------+--------------+---------------+
| Name              | # functions      | ERCs          | ERC20 info         | Complex code | Features      |
+-------------------+------------------+---------------+--------------------+--------------+---------------+
| Raffle            | 144              | ERC165, ERC721|                    | Yes          | Receive ETH   |
|                   |                  |               |                    |              | Send ETH      |
|                   |                  |               |                    |              | Tokens        |
|                   |                  |               |                    |              | Interaction   |
|                   |                  |               |                    |              | Assembly      |
| RaffleFactory     | 22               |               |                    | No           | Tokens        |
|                   |                  |               |                    |              | Interaction   |
| RaffleConstants   | 1                |               |                    | No           |               |
+-------------------+------------------+---------------+--------------------+--------------+---------------+
```

### 2.4 `slither --print contract-summary` Results (`scratch/logs/04_slither_contract_summary_orig.log`)

- **Command**: `slither . --print contract-summary`
- **Owned Contracts Summary**:
  - **`Contract Raffle`** (`ERC721`, `IERC721Receiver`, `VRFV2PlusWrapperConsumerBase`, `ReentrancyGuard`, `IRaffle`):
    - **External/Public State-Changing Functions**: `constructor(address,address)`, `receive()`, `initialize(IRaffle.RaffleInitParams)`, `buyEntries(address,uint128)`, `requestDraw()`, `enableRefunds()`, `settleWinningTicket(uint256)`, `redeemWinningTicket(uint256)`, `refundTickets(uint256[])`, `releaseSponsorProceeds()`, `releaseProtocolFees()`, `releaseSponsorPrize()`, `onERC721Received(address,address,uint256,bytes)`, `rawFulfillRandomWords(uint256,uint256[])`, `approve(address,uint256)`, `setApprovalForAll(address,bool)`, `transferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)`.
    - **External/Public View/Pure Functions**: `getVrfRequestPrice()`, `estimateVrfRequestPrice(uint256)`, `vrfWrapper()`, `ticketRange(uint256)`, `drawRequestDeadline()`, `callbackDeadline()`, `accountedQuoteBalance()`, `grossSales()`, `name()`, `symbol()`, `tokenURI(uint256)`, `balanceOf(address)`, `ownerOf(uint256)`, `getApproved(uint256)`, `isApprovedForAll(address,address)`, `supportsInterface(bytes4)`, `getLinkToken()`, plus 29 public state/immutable/constant getters.
    - **Internal/Private Functions (`Raffle.sol`)**: `_update(address,uint256,address)`, `fulfillRandomWords(uint256,uint256[])`, `_settleWinningTicket(uint256)`, `_transferQuote(address,uint256)`, `_requireStatus(IRaffle.Status)`, `_requireWinningTicket(uint256)`, `_isProtocolDestination(address,address)`, `_validatedVrfWrapper(address)`.
  - **`Contract RaffleFactory`** (`ReentrancyGuard`, `IRaffleFactory`):
    - **External/Public State-Changing Functions**: `constructor(address,address,address)`, `createRaffle(IRaffleFactory.CreateRaffleParams)`.
    - **External/Public View/Pure Functions**: `quoteToken()`, `vrfWrapper()`, `protocolTreasury()`, `callbackGasLimit()`, `requestConfirmations()`, `raffleImplementation()`, `raffleCount()`, `isRaffle(address)`, `raffleById(uint256)`, `idByRaffle(address)`.
    - **Private Functions**: `_validateCreateParams(IRaffleFactory.CreateRaffleParams)`, `_requireContract(address)`.
  - **`Contract RaffleConstants`**:
    - Defines 11 protocol constants (`BPS`, `PROTOCOL_FEE_BPS`, `CASH_WINNER_BPS`, `ENTRY_PRICE`, `QUOTE_TOKEN_DECIMALS`, `MAX_REFUND_TICKET_BATCH_SIZE`, `MAX_SALE_DURATION`, `DRAW_REQUEST_TIMEOUT`, `DRAW_CALLBACK_TIMEOUT`, `VRF_CALLBACK_GAS_LIMIT`, `VRF_REQUEST_CONFIRMATIONS`).

### 2.5 Slither Detector Triage on Owned Contracts (`scratch/logs/02_slither_detectors_orig.log`)

Running `slither .` produced 102 total detector results across 36 contracts (the vast majority inside `node_modules/@openzeppelin` and `node_modules/@chainlink` libraries such as `Strings`, `Math`, `Clones`, `StorageSlot`). Below is the complete triage of every Slither detector triggered on the 5 owned contracts (`src/`):

| Slither Detector | Impact / Confidence | Location | Triage & Security Assessment |
| :--- | :--- | :--- | :--- |
| `events-maths` | Low / Medium | `IRaffle.sol:221-289` (`TicketPurchased`, `DrawRequested`, `WinningTicketSettled`, `WinnerClaimed`, `TicketsRefunded`, `SponsorProceedsClaimed`, `ProtocolFeesClaimed`) | **Informational (`TIA-07`)**: Custom lifecycle events do not mark address/ID parameters as `indexed`. Does not affect on-chain execution, only off-chain topic filtering. |
| `calls-loop` | Low / Medium | `Raffle.sol:349-372` (`refundTickets`), `Raffle.sol:580-591` (`_isProtocolDestination`) | **Informational (`TIA-07` / Benign at runtime)**: `refundTickets` bounds `ticketIds.length <= MAX_REFUND_TICKET_BATCH_SIZE` (`100`) and calls `_burn(ticketId)` -> `Raffle._update(address(0), ticketId, address(0))`. Because `Raffle._update` (`Raffle.sol:498`) short-circuits `if (to != address(0) && _isProtocolDestination(...))`, no external call is actually made inside the burn loop at runtime. |
| `reentrancy-benign` | Low / Medium | `Raffle.sol:209-237` (`buyEntries`), `Raffle.sol:240-273` (`requestDraw`), `RaffleFactory.sol:80-115` (`createRaffle`) | **Benign / Mitigated**: All three functions are protected by OpenZeppelin `nonReentrant`. In `buyEntries`, `quoteToken` is canonical USDC (`safeTransferFrom` before state update, followed by `_safeMint` after state update). In `requestDraw`, `_requestInFlight = true` explicitly blocks synchronous VRF fulfillment during `requestRandomnessPayInNative`. In `createRaffle`, `idByRaffle`/`isRaffle`/`raffleById` are written only after `prize.safeTransferFrom` and escrow verification succeed. |
| `timestamp` | Low / Medium | `Raffle.sol:216, 242, 245, 290, 315, 513, 520, 524`, `RaffleFactory.sol:86` | **Expected Design**: Raffle windows (`MAX_SALE_DURATION = 30 days`, `DRAW_REQUEST_TIMEOUT = 1 days`, `DRAW_CALLBACK_TIMEOUT = 1 days`) operate on day-scale durations where validator timestamp drift (~12s) is negligible. |
| `assembly` | Informational / High | `Raffle.sol:266-268` (`requestDraw`) | **Audited / Safe**: Uses `assembly ("memory-safe") { success := call(gas(), refundRecipient, excess, 0, 0, 0, 0) }` to refund excess native ETH without copying arbitrary return data (preventing return-bomb gas griefing), after `nonReentrant` and after `_requestInFlight = false`. |
| `naming-convention` | Informational / High | `Raffle.sol:31, 34, 37`, `RaffleFactory.sol:20, 23` | **Informational**: `ENTRY_PRICE` (uppercase immutable getter matching `IRaffle.ENTRY_PRICE()`) vs. `callbackGasLimit` and `requestConfirmations` (mixedCase constants matching `IRaffle` interface getters). |

### 2.6 `slither-prop` Attempt, Coverage Gap, and Compensatory Property Testing

#### A. Raw `slither-prop` Execution & Coverage Gap (`scratch/logs/07_slither_prop_orig.log`, `scratch/logs/08_slither_prop_solc.log`)

1. **Attempt 1 (Default Foundry detection)**:
   - **Command**: `slither-prop . --contract Raffle`
   - **Raw Output**:
     ```text
     WARNING:CryticCompile:Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
     ERROR:root:Foundry not yet supported by slither-prop.
     ```
2. **Attempt 2 (Forcing direct `solc` compilation with remappings)**:
   - **Command**:
     ```bash
     slither-prop src/Raffle.sol --contract Raffle --compile-force-framework solc --solc-remaps "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/ @chainlink/contracts/=node_modules/@chainlink/contracts/"
     ```
   - **Raw Output**:
     ```text
     Raffle is not ERC20 compliant. Consider checking the contract with slither-check-erc
     ```
3. **Unresolved Tooling Coverage Gap Identification**:
   - `slither-prop` (`0.11.6`) only supports generating Truffle/Echidna ERC-20 property suites (`ERC20` scenarios: `Transferable`, `Pausable`, `NotMintable`, `NotMintableNotBurnable`, `Burnable`, `Allowance`) and rejects non-ERC-20 contracts (`Raffle` is an ERC-721 contract, and `RaffleFactory` is a factory contract).

#### B. Compensatory Property & Fuzz Testing (`forge test` & `echidna`)

To close the `slither-prop` coverage gap with actual executable property verification, two custom property test suites were authored and executed in isolated scratch workspaces:
1. **Foundry Property & Fuzz Suite (`scratch/contracts-orig/test/foundry/TokenIntegrationProperties.t.sol`, logged in `scratch/logs/12_forge_test_properties.log`)**:
   - **Command**: `forge test -vv --match-contract TokenIntegrationPropertiesTest`
   - **Result**: **9 passed, 0 failed** (including 3,000 fuzz runs across parameterized properties):
     - `[PASS] testProperty_ERC721MetadataAndInterfaces()` (gas: 631,393)
     - `[PASS] testProperty_SequentialTicketsAndContiguousRanges(uint8,uint8,uint8)` (runs: 1000, μ: 819,587)
     - `[PASS] testProperty_ERC721ProtocolDestinationGuardsAndApprovalClearing()` (gas: 1,047,157)
     - `[PASS] testProperty_QuoteTokenConservation_NftWon(uint8,uint8,uint256)` (runs: 1000, μ: 899,337)
     - `[PASS] testProperty_QuoteTokenConservation_CashWon(uint8,uint8,uint256)` (runs: 1000, μ: 917,252)
     - `[PASS] testProperty_FeeOnTransferQuoteTokenCreatesDeficit()` (gas: 676,891)
     - `[PASS] testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot()` (gas: 1,656,647)
     - `[PASS] testProperty_DecoupledSettlementAllowsSponsorProceedsWhenPrizeTokenPauses()` (gas: 833,794)
     - `[PASS] testProperty_PrizeDeliveryUsesTransferFromWithoutReceiverHook()` (gas: 957,107)
2. **Echidna Property-Based Fuzzing Suite (`scratch/contracts-echidna/src/RaffleEchidnaProperties.sol`, logged in `scratch/logs/13_echidna_properties.log`)**:
   - **Command**: `echidna . --contract RaffleEchidnaProperties --test-limit 5000`
   - **Result**: **5/5 invariants passing across 5,214 calls (8,507 unique instructions covered)**:
     - `echidna_gross_sales_consistency: passing`
     - `echidna_erc721_interfaces_supported: passing`
     - `echidna_no_protocol_destination_ticket_owner: passing`
     - `echidna_quote_balance_conservation: passing`
     - `echidna_erc721_balance_sum_matches_ticket_count: passing`

---

## PHASE 3: COMPREHENSIVE 10-CATEGORY CODE ASSESSMENT

### 1. GENERAL CONSIDERATIONS

- **Security Reviews & Specification Maturity**:
  - The repository includes a concise specification ([`DESIGN.md`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md)) and comprehensive NatSpec interfaces ([`IRaffle.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffle.sol), [`IRaffleFactory.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffleFactory.sol)) plus pinned dependency SHA-256 hashes ([`dependency-hashes.json`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/dependency-hashes.json)).
  - **Spec vs. Implementation Assumption Tension**: [`DESIGN.md:19`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md#L19) states: *"Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."* However, [`IRaffle.sol:17`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffle.sol#L17) and [`IRaffleFactory.sol:11`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffleFactory.sol#L11) state: *"Supported prizes are honest, standards-compliant ERC-721s; fee-taking, self-moving, or control-hijacking NFTs are out of scope."* Because `RaffleFactory.createRaffle` is permissionless and has no prize collection allowlist, this assumption discrepancy directly leads to **TIA-01**.
- **Team Transparency & Security Contacts**:
  -✗ No `@custom:security-contact` NatSpec tag, `SECURITY.md`, or security mailing list is present in `packages/contracts/`.

---

### 2. CONTRACT COMPOSITION

#### 2.1 Complexity Analysis (`slither --print human-summary` & `function-summary`)

- **Source Lines of Code (SLOC)**: `710` SLOC across 5 owned source files (`2,220` SLOC across 31 dependency files).
- **Inheritance Hierarchy** (`scratch/logs/11_slither_inheritance.log`):
  - `Raffle` -> `ERC721` (`Context`, `ERC165`, `IERC165`, `IERC721`, `IERC721Metadata`, `IERC721Errors`), `IERC721Receiver`, `VRFV2PlusWrapperConsumerBase`, `ReentrancyGuard`, `IRaffle`.
  - `RaffleFactory` -> `ReentrancyGuard`, `IRaffleFactory`.
- **Cyclomatic Complexity of Owned Functions** (`scratch/logs/09_slither_function_summary.log`):

| Contract | Function | Visibility | Modifiers | Cyclomatic Complexity | Assessment |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Raffle` | `redeemWinningTicket(uint256)` | `external` | `nonReentrant` | **10** | Moderate-high (branches on `NftWon` vs `CashWon`, auto-settlement, ownership, and delivery verification) |
| `Raffle` | `requestDraw()` | `external` | `nonReentrant` | **8** | Moderate (status, deadlines, fee checks, VRF call, excess ETH refund) |
| `Raffle` | `initialize(IRaffle.RaffleInitParams)` | `external` | — | **7** | Moderate (one-time guard, factory check, 4 zero-address checks, 3 destination checks) |
| `Raffle` | `enableRefunds()` | `external` | `nonReentrant` | **7** | Moderate (branches on `Active` with 0 entries vs `Active` expired vs `Drawing` expired) |
| `Raffle` | `buyEntries(address,uint128)` | `external` | `nonReentrant` | **5** | Low |
| `Raffle` | `refundTickets(uint256[])` | `external` | `nonReentrant` | **4** | Low |
| `Raffle` | `releaseSponsorPrize()` | `external` | `nonReentrant` | **4** | Low |
| `Raffle` | `_settleWinningTicket(uint256)` | `private` | — | **4** | Low |
| `Raffle` | All other functions (`_update`, `fulfillRandomWords`, `_transferQuote`, `_isProtocolDestination`, `onERC721Received`, `releaseSponsorProceeds`, `releaseProtocolFees`, views) | `external` / `public` / `internal` / `private` | — | **1–2** | Minimal |
| `RaffleFactory` | `_validateCreateParams(CreateRaffleParams)` | `private` | — | **8** | Moderate (validates addresses, contract code, protocol destinations, ERC-165) |
| `RaffleFactory` | `constructor(address,address,address)` | `public` | — | **7** | Moderate (validates `quoteToken`, `vrfWrapper`, `protocolTreasury`, deploys `Raffle`) |
| `RaffleFactory` | `createRaffle(CreateRaffleParams)` | `external` | `nonReentrant` | **5** | Low |
| `RaffleFactory` | `_requireContract(address)` | `private` | — | **2** | Minimal |

#### 2.2 SafeMath / Arithmetic Protection

- ✓ All owned contracts use exact `pragma solidity 0.8.36;` with built-in overflow/underflow checks.
- ✓ Zero `unchecked` blocks exist in any of the 5 owned Solidity files (`src/`).
- ✓ Explicit domain bound checks protect narrowing casts and multiplications:
  - `buyEntries` (`Raffle.sol:219-221`): checks `if (entryCount > type(uint128).max - totalEntries) revert TotalEntriesOverflow(totalEntries, entryCount);` before adding `uint128` entries and computing `uint256(entryCount) * ENTRY_PRICE`.
  - `fulfillRandomWords` (`Raffle.sol:524`): `uint128((_randomWords[0] % uint256(soldEntries)) + 1)` safely fits in `uint128` since `soldEntries` is `uint128` (`>= 1`).
  - `_settleWinningTicket` (`Raffle.sol:546-555`): `protocolFee = (grossPot * RaffleConstants.PROTOCOL_FEE_BPS) / RaffleConstants.BPS` and `winnerShare = (grossPot * RaffleConstants.CASH_WINNER_BPS) / RaffleConstants.BPS` cannot overflow `uint256` because `grossPot <= uint256(type(uint128).max) * 1e6`.

#### 2.3 Non-Token Functions in `Raffle`

Because `Raffle` combines an ERC-721 ticket token with the raffle escrow and settlement state machine in a single contract (`src/Raffle.sol`), it exposes 12 non-ERC-721 state-changing functions (`initialize`, `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `onERC721Received`, `rawFulfillRandomWords`) plus 1 (`receive`).
- **Assessment**: While coupling the ERC-721 ticket ledger with the raffle state machine increases contract surface area compared to a standalone token, all state-changing external entry points (except one-time `initialize`, restricted `onERC721Received`, and VRF-gated `rawFulfillRandomWords`) are protected by `nonReentrant`, and `_update` enforces `_isProtocolDestination` across all mints and transfers.

#### 2.4 Address Entry Points

- ✓ Each raffle is a standalone ERC-1167 minimal proxy clone (`Clones.clone(raffleImplementation)`) with a single canonical address registered in `RaffleFactory` (`isRaffle`, `raffleById`, `idByRaffle`).
- ✓ No double-entry proxy or token migration mechanism exists.
- ✓ The shared `raffleImplementation` constructor (`Raffle.sol:164-165`) sets `initialized = true` and `status = Status.Refunding`, preventing direct initialization or use of the implementation contract itself.

---

### 3. OWNER PRIVILEGES

#### 3.1 Upgradeability

- ✓ **Not Upgradeable**: Neither `RaffleFactory` nor `Raffle` uses an upgradeable proxy (`UUPS`, `TransparentUpgradeableProxy`, or `BeaconProxy`). `RaffleFactory` deploys immutable ERC-1167 minimal proxy clones (`Clones.clone(raffleImplementation)`, `RaffleFactory.sol:83`) pointing to a fixed `raffleImplementation` deployed in the factory constructor (`RaffleFactory.sol:76`).

#### 3.2 Minting Capabilities (`Raffle` ERC-721 Tickets)

- ✓ **No Privileged or Free Minting**: Neither the `sponsor`, `factory`, nor `protocolTreasury` can mint tickets without paying `uint256(entryCount) * ENTRY_PRICE` in `quoteToken`.
- ✓ Tickets can only be minted in `buyEntries(address recipient, uint128 entryCount)` (`Raffle.sol:209-237`) while `status == Status.Active` and `block.timestamp < endTime`.

#### 3.3 Pausability & Blacklisting (`Raffle` Implementation vs. External Tokens)

- ✓ **`Raffle` / `RaffleFactory`**: Have no owner, admin, pause function, or blacklist function (`vars-and-auth` confirms zero `onlyOwner` modifiers).
- ✓ **Sponsor Early Refund Power (`enableRefunds`)**: In `Raffle.enableRefunds()` (`Raffle.sol:276-301`), the `sponsor` can transition a raffle to `Status.Refunding` before `drawRequestDeadline()` **only if `totalEntries == 0`** (`Raffle.sol:280-284`). Once a single entry is sold (`totalEntries > 0`), the sponsor cannot cancel the raffle early; `enableRefunds()` can only be called after `drawRequestDeadline()` (in `Active`) or `callbackDeadline()` (in `Drawing`).
- ⚠ **External Token Centralization (`quoteToken` = USDC)**: Canonical USDC is upgradeable (`FiatTokenProxy`), pausable, and has a centralized `blacklist` (see **TIA-03** and Category 7 below).

---

### 4. ERC20 CONFORMITY CHECKS

#### 4.1 Token Implementation Scope

- **N/A for Owned Contracts**: Neither `Raffle` nor `RaffleFactory` implements an ERC-20 token (`Raffle` is an ERC-721 token; confirmed by `slither-check-erc . Raffle --erc erc20`).

#### 4.2 Integrated ERC-20 Token (`quoteToken`) Validation & Conformity Handling

| ERC-20 Check | How `RaffleFactory` & `Raffle` Handle `quoteToken` | Status / Risk |
| :--- | :--- | :--- |
| **Contract Code Existence** | `RaffleFactory.constructor` (`RaffleFactory.sol:66`) calls `_requireContract(quoteToken_)` (`quoteToken_.code.length == 0` reverts with `NotContract`). | ✓ Verified at factory deployment |
| **`decimals()` Presence & Value** | `RaffleFactory.constructor` (`RaffleFactory.sol:70-74`) calls `IERC20Metadata(quoteToken_).decimals()` inside a `try/catch` and requires `quoteDecimals == 6` (`RaffleConstants.QUOTE_TOKEN_DECIMALS`), reverting with `UnsupportedQuoteToken` or `InvalidQuoteTokenDecimals(quoteDecimals, 6)`. | ✓ Enforces 6 decimals (`ENTRY_PRICE = 1_000_000`) |
| **`transfer` / `transferFrom` Return Values** | `Raffle.buyEntries` (`Raffle.sol:224`) uses `quoteToken.safeTransferFrom` and `Raffle._transferQuote` (`Raffle.sol:566`) uses `quoteToken.safeTransfer` from OpenZeppelin v5.6.0 `SafeERC20`. `SafeERC20._callOptionalReturn` accepts both `returns (bool true)` and empty return data (`returndatasize() == 0` if target has code), and reverts with `SafeERC20FailedOperation` on `false` or revert. | ✓ Compatible with missing return values (e.g., USDT) |
| **`name()` / `symbol()` Metadata** | Never queried on-chain by `Raffle` or `RaffleFactory`. | ✓ Immune to `bytes32` metadata (e.g., MKR) or name injection |
| **`approve()` Race Condition** | Neither `Raffle` nor `RaffleFactory` ever calls `quoteToken.approve(...)` or `SafeERC20.forceApprove(...)`; `Raffle` only pulls via `safeTransferFrom` and pushes via `safeTransfer`. | ✓ Not affected on-contract |

---

### 5. ERC20 EXTENSION RISKS

1. **External Calls in Transfers (ERC-777 / ERC-1363 Hooks)**:
   - `Raffle.buyEntries`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, and `releaseProtocolFees` are all protected by OpenZeppelin `ReentrancyGuard.nonReentrant`.
   - Furthermore, all payout functions follow strict Checks-Effects-Interactions (CEI):
     - `redeemWinningTicket` (`Raffle.sol:323-342`): sets `winnerRedeemed = true`, `winnerRecipient = winner`, `winnerProceeds = 0`, and `_burn(ticketId)` **before** calling `_transferQuote(winner, cashAmount)`.
     - `refundTickets` (`Raffle.sol:355-369`): burns each ticket (`_burn(ticketId)`, removing ownership so duplicate IDs in `ticketIds` revert with `ERC721NonexistentToken`) and decrements `remainingRefundLiability -= amount` **before** calling `_transferQuote(msg.sender, amount)`.
     - `releaseSponsorProceeds` (`Raffle.sol:377-380`): sets `sponsorProceeds = 0` **before** `_transferQuote`.
     - `releaseProtocolFees` (`Raffle.sol:388-391`): sets `protocolFees = 0` **before** `_transferQuote`.
2. **Transfer Fees / Deflationary Tokens (`TIA-04`)**:
   - ⚠ `Raffle.buyEntries` (`Raffle.sol:223-234`) transfers `grossAmount` via `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` and increments `unsettledPot += grossAmount` without measuring `quoteToken.balanceOf(address(this))` before and after the transfer.
   - If `quoteToken` charges a transfer fee (or if a 6-decimal token with a dormant fee switch such as USDT activates fees), `unsettledPot` exceeds the actual token balance held by `Raffle`, causing the last claimant(s) in `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, or `releaseProtocolFees` to revert with insufficient balance (verified by `testProperty_FeeOnTransferQuoteTokenCreatesDeficit`).
3. **Rebasing / Yield-Bearing / Deflationary Balance Modifications Outside Transfers (`TIA-04`, `TIA-05`)**:
   - ⚠ `Raffle` tracks liabilities purely via internal state variables (`unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, summed in `accountedQuoteBalance()` at `Raffle.sol:469-477`).
   - Negative rebases would render the contract insolvent for final claimants; positive rebases, yield, or accidental direct `quoteToken.transfer(raffle, amount)` transfers are permanently locked inside the `Raffle` clone because there is no sweep or rescue function.

---

### 6. TOKEN SCARCITY & ON-CHAIN ANALYSIS (PHASE 4)

#### 6.1 Unresolved Coverage Gap: Live On-Chain Querying

- **Status**: **Not Applicable / Coverage Gap Documented**.
- **Reason**: `raffle-fun` in this workspace is a pre-deployment source repository (`packages/contracts`). No deployed contract addresses, chain IDs, or live RPC endpoints are present in [`DESIGN.md`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md), `foundry.toml`, `hardhat.config.ts`, or `package.json`. Therefore, live on-chain queries (`totalSupply()`, holder distribution, CEX/DEX liquidity pools) could not be executed against a live network.

#### 6.2 Off-Chain Scarcity, Supply Distribution, and Flash Loan / Flash Mint Mechanics Analysis

1. **Ticket Supply & Holder Concentration (`Raffle` ERC-721)**:
   - Each raffle clone starts with `ticketCount = 0` and `totalEntries = 0`.
   - A single buyer (or whale) can purchase a large fraction of `totalEntries` up to `type(uint128).max - totalEntries` (`Raffle.sol:219`) before `endTime`. Because each entry costs `1_000_000` (1 USDC) and the probability of winning is strictly proportional to entries purchased (`winningEntry = (_randomWords[0] % totalEntries) + 1`, `Raffle.sol:524`), buying $k$ of $N$ entries gives an exact $k/N$ probability of winning while contributing $k$ USDC to the pot (of which 5% goes to `protocolTreasury` and 95% to `sponsorRecipient` in `NftWon`, or 5% to `protocolTreasury`, 65% to `sponsorRecipient`, and 30% to the winner in `CashWon`).
2. **Flash Loan / Flash Mint Attack Resistance**:
   - ✓ **Immune to Flash Loan / Flash Mint Manipulation**:
     - Buying entries in `buyEntries` (`Raffle.sol:209-237`) requires locking `quoteToken` into the `Raffle` contract while `block.timestamp < endTime`.
     - Randomness cannot be requested until `block.timestamp >= endTime` (`requestDraw`, `Raffle.sol:242`), and is fulfilled asynchronously by Chainlink VRF v2.5 after `requestConfirmations = 3` blocks (`RaffleConstants.sol:42`).
     - Furthermore, `_requestInFlight` (`Raffle.sol:254, 260, 511`) explicitly prevents synchronous fulfillment within the `requestDraw` transaction.
     - Consequently, an attacker cannot flash-loan or flash-mint `quoteToken`, buy entries, resolve the raffle, and repay the flash loan within a single transaction.
3. **Sponsor Self-Dealing / Wash-Buying Analysis**:
   - Note that `Raffle.buyEntries` (`Raffle.sol:209-237`) does **not** prohibit `sponsor` or `sponsorRecipient` from buying entries in their own raffle. If a raffle is near `reserveEntries`, a sponsor can buy the remaining entries to push `totalEntries >= reserveEntries` (switching the outcome from `CashWon` where the sponsor pays 35% of the pot to winner+protocol, to `NftWon` where the sponsor receives 95% of all entries including their own, net of the 5% protocol fee, plus a proportional chance of winning back their own NFT). This is an economic property of reserve-based raffles rather than a token standard bug, as the protocol still collects the 5% `PROTOCOL_FEE_BPS` on all entries.
4. **Refund Batching & Griefing Resistance**:
   - Because each `buyEntries` call mints a single ERC-721 ticket covering a contiguous `[firstEntry, lastEntry]` range (`TicketRange`), a user who buys 10,000 entries in one transaction receives 1 ticket (`ticketId`) and can refund all 10,000 entries in a single `refundTickets` call (`Raffle.sol:349-372`). If a user mints many separate tickets, `refundTickets` processes up to `MAX_REFUND_TICKET_BATCH_SIZE = 100` tickets per transaction (`Raffle.sol:351`).
5. **Entry Count Cap (`uint128`) vs. USDC Total Supply**:
   - `totalEntries` is `uint128` (`max = 3.4028e38`), which at `1e6` per entry corresponds to `3.4028e44` base units (`3.4e38` USDC), orders of magnitude larger than global USDC supply (`~1e11` USDC), so `TotalEntriesOverflow` cannot be used to grief legitimate buyers under canonical USDC.

---

### 7. WEIRD ERC20 PATTERNS (ALL 24 PATTERNS ANALYZED)

Below is the systematic evaluation of all 24 weird ERC-20 patterns from Trail of Bits' `ASSESSMENT_CATEGORIES.md` (`#7-weird-erc20-patterns`) against `RaffleFactory` and `Raffle`:

| # | Weird ERC-20 Pattern | Examples | Applicable to Canonical USDC? | Protocol Handling & Code Citation | Risk Level |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **7.1** | **Reentrant Calls (ERC-777 / Transfer Hooks)** | ERC-777 (`tokensToSend`, `tokensReceived`), Amp | No | All `quoteToken` entry points (`buyEntries`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`) use `ReentrancyGuard.nonReentrant` and strict CEI state updates (`Raffle.sol:209, 309, 349, 375, 386`). | **LOW (Mitigated)** |
| **7.2** | **Missing Return Values** | USDT, BNB, OMG | No (USDC returns `bool`), Yes for USDT | `Raffle.sol:224` (`quoteToken.safeTransferFrom`) and `Raffle.sol:566` (`quoteToken.safeTransfer`) use OpenZeppelin v5.6.0 `SafeERC20`, which accepts both empty return data and `true`. | **NONE (Handled)** |
| **7.3** | **Fee on Transfer** | STA, PAXG, USDT (dormant fee switch) | No (USDC has no fee), Yes if non-USDC 6-decimal token | `Raffle.buyEntries` (`Raffle.sol:223-233`) credits `unsettledPot += grossAmount` without checking `balanceAfter - balanceBefore`. Any transfer fee creates an immediate solvency deficit (`TIA-04`, verified by `testProperty_FeeOnTransferQuoteTokenCreatesDeficit`). | **MEDIUM (If non-USDC / fee switch)** |
| **7.4** | **Balance Modifications Outside Transfers (Rebasing / Yield)** | Ampleforth (AMPL), Compound, stETH | No | `Raffle` uses internal accounting (`unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `Raffle.sol:469-477`). Negative rebases cause insolvency; positive rebases/yield remain permanently trapped (`TIA-04`, `TIA-05`). | **MEDIUM (If rebasing token)** |
| **7.5** | **Upgradable Tokens** | USDC (`FiatTokenProxy`), USDT, TUSD | **YES (Canonical USDC is upgradeable)** | `quoteToken` is `immutable` (`RaffleFactory.sol:26`, `Raffle.sol:58`). If Circle upgrades USDC logic, all existing and future raffles inherit the upgraded implementation behavior. | **LOW (Accepted Canonical Dependency)** |
| **7.6** | **Flash Mintable Tokens** | DAI, ERC-3156 tokens | No (USDC is not flash-mintable) | Even if a 6-decimal token is flash-borrowed/minted, `buyEntries` occurs before `endTime` while `requestDraw` + VRF fulfillment occur after `endTime` + `3` confirmations (`Raffle.sol:216, 242, 257`), preventing single-block flash attacks. | **NONE (Mitigated)** |
| **7.7** | **Blocklists (Blacklists)** | **USDC**, USDT | **YES (Canonical USDC has `blacklist`)** | Pull-based claims (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`) prevent a blacklisted address from blocking other claimants. Moreover, a blacklisted ticket holder can transfer their `RAFFLE` ERC-721 ticket to an un-blacklisted address because `_update` (`Raffle.sol:497-501`) permits ticket transfers in all statuses (`testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot`). **However**, `sponsorRecipient` and `protocolTreasury` are immutable and have no fallback recipient (`TIA-03`). | **MEDIUM (`TIA-03`)** |
| **7.8** | **Pausable Tokens** | **USDC**, USDT, BNB, ZIL | **YES (Canonical USDC is `Pausable`)** | If USDC is paused globally: (a) during `Active`, `buyEntries` reverts; (b) in `CashWon` / `Refunding`, `redeemWinningTicket` / `refundTickets` / `releaseSponsorProceeds` / `releaseProtocolFees` revert until unpaused; (c) in `NftWon`, `settleWinningTicket` and `redeemWinningTicket` (NFT transfer) still succeed even while USDC is paused! | **LOW (Temporary Liveness Delay)** |
| **7.9** | **Approval Race Protections** | USDT, KNC | No | Neither `Raffle` nor `RaffleFactory` ever calls `quoteToken.approve(...)`. Users approve individual `Raffle` clone addresses directly off-chain. | **NONE (Not Applicable)** |
| **7.10** | **Revert on Approval to Zero Address** | OpenZeppelin ERC-20 | Yes | Contracts never call `quoteToken.approve(address(0), ...)`. | **NONE (Not Applicable)** |
| **7.11** | **Revert on Zero Value Approvals** | BNB | No | Contracts never call `quoteToken.approve(..., 0)`. | **NONE (Not Applicable)** |
| **7.12** | **Revert on Zero Value Transfers** | LEND | No | Every `quoteToken` transfer in `Raffle` is strictly non-zero: `buyEntries` requires `entryCount > 0` (`grossAmount >= 1e6`, `Raffle.sol:218, 223`); `redeemWinningTicket` (`CashWon`) requires `cashAmount > 0` (`NoWinnerProceeds`, `Raffle.sol:339`); `refundTickets` requires `ticketIds.length > 0` and each ticket has `>= 1` entry (`Raffle.sol:350-366`); `releaseSponsorProceeds` requires `amount > 0` (`NoSponsorProceeds`, `Raffle.sol:378`); `releaseProtocolFees` requires `amount > 0` (`NoProtocolFees`, `Raffle.sol:389`). | **NONE (Protected by Non-Zero Guards)** |
| **7.13** | **Multiple Token Addresses** | Proxies / Bridged dual-entry tokens | No (on single-entry canonical USDC) | `_isProtocolDestination` (`Raffle.sol:582`) compares `destination == address(quoteToken)`. If a token had a secondary entry point address `quoteTokenAlt`, sending tickets or prizes to `quoteTokenAlt` would not be caught by `destination == address(quoteToken)`. | **LOW (Single-entry USDC)** |
| **7.14** | **Low Decimals** | **USDC (6)**, USDT (6), GUSD (2) | **YES (USDC has 6 decimals)** | Intentionally designed for 6 decimals: `RaffleConstants.QUOTE_TOKEN_DECIMALS = 6`, `ENTRY_PRICE = 1_000_000` (`RaffleConstants.sol:22-25`), enforced in `RaffleFactory.sol:70-74`. BPS math (`PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 3000` on multiples of `1_000_000`) produces exact integer shares (`50_000` and `300_000` per `1_000_000` entry) with **zero rounding dust**! | **NONE (Exact Integer Precision)** |
| **7.15** | **High Decimals** | YAM-V2 (24) | No | Rejected by `RaffleFactory.constructor` (`RaffleFactory.sol:73-74`), which reverts with `InvalidQuoteTokenDecimals(quoteDecimals, 6)` for any `decimals() != 6`. | **NONE (Rejected at Deployment)** |
| **7.16** | **`transferFrom` with `src == msg.sender`** | DSToken | No | `Raffle.buyEntries` (`Raffle.sol:224`) calls `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` where `address(this)` is the `Raffle` clone and `msg.sender != address(this)` (enforced by `_isProtocolDestination` on `recipient` and because `Raffle` cannot call `buyEntries` on itself). | **NONE (Not Applicable)** |
| **7.17** | **Non-String Metadata (`bytes32`)** | MKR | No | Neither `RaffleFactory` nor `Raffle` calls `quoteToken.name()` or `quoteToken.symbol()`. | **NONE (Handled)** |
| **7.18** | **No Revert on Failure (Returns `false`)** | ZRX, EURS | No | Handled by OpenZeppelin `SafeERC20` (`safeTransferFrom`, `safeTransfer`), which checks return values and reverts with `SafeERC20FailedOperation(address(token))` if `false` is returned (`SafeERC20.sol:124-138`). | **NONE (Handled)** |
| **7.19** | **Revert on Large Approvals (`>= 2^96`)** | UNI, COMP | No | Contracts do not call `approve`. Users approve exact or bounded amounts for `buyEntries`. | **NONE (Not Applicable)** |
| **7.20** | **Code Injection via Token Name** | Malicious ERC-20 / ERC-721 metadata | No (for USDC); **Possible for untrusted `prizeToken`** | `Raffle` ticket `name()` and `symbol()` are hardcoded constants `"raffle.fun Ticket"` and `"RAFFLE"` (`Raffle.sol:487, 493`). However, off-chain indexers displaying `prizeToken.name()`, `symbol()`, or `tokenURI()` must sanitize untrusted ERC-721 metadata. | **INFORMATIONAL (Off-chain UI)** |
| **7.21** | **Unusual Permit Function** | DAI, RAI, GLM | Yes (USDC supports EIP-2612) | Contracts do not integrate or call `permit()` on `quoteToken`. | **NONE (Not Applicable)** |
| **7.22** | **Transfer Less Than Amount (`uint256.max`)** | cUSDCv3 | No | `buyEntries` computes `grossAmount = uint256(entryCount) * ENTRY_PRICE` (`<= type(uint128).max * 1e6 << type(uint256).max`). | **NONE (Not Applicable)** |
| **7.23** | **Revert on Transfer to Zero Address** | OpenZeppelin ERC-20, USDC | **YES (USDC reverts on `to == address(0)`)** | All `quoteToken` recipient addresses (`sponsorRecipient`, `protocolTreasury`, `winner`, `msg.sender`) are validated non-zero at initialization (`Raffle.sol:181-185`, `RaffleFactory.sol:61-65`) and cannot be `address(0)` (since `ownerOf(ticketId)` reverts if `address(0)`). | **NONE (Protected)** |
| **7.24** | **ERC-20 Representation of Native Currency** | Celo, Polygon (`0x1010`), zkSync Era | No (when deployed with canonical USDC) | `Raffle.requestDraw()` handles native ETH for VRF fees (`msg.value`) and refunds `excess` native ETH before any `quoteToken` interaction occurs (`Raffle.sol:240-273`). `buyEntries` is not `payable` and never touches `address(this).balance`. | **NONE (Separated Paths)** |

---

### 8. TOKEN INTEGRATION SAFETY

#### 8.1 Safe Transfer Patterns (`SafeERC20`)

- ✓ `Raffle.sol:13` declares `using SafeERC20 for IERC20;`.
- ✓ All ERC-20 transfers go through `quoteToken.safeTransferFrom` (`Raffle.sol:224`) and `quoteToken.safeTransfer` (`Raffle.sol:566`).
- ✓ No raw `IERC20.transfer` or `IERC20.transferFrom` calls exist anywhere in `src/`.

#### 8.2 Balance Verification Before/After Transfers

- ✗ ** ERC-20 (`quoteToken`)**: Not implemented in `buyEntries` (`Raffle.sol:224`) or `_transferQuote` (`Raffle.sol:566`). See **TIA-04**.
- ✓ **ERC-721 (`prizeToken`)**: Explicitly verifies ownership after every transfer:
  - In `RaffleFactory.createRaffle` (`RaffleFactory.sol:101-106`): calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` and then verifies both `prize.ownerOf(params.prizeTokenId) != raffle` and `IRaffle(raffle).status() != IRaffle.Status.Active` (ensuring `Raffle.onERC721Received` was invoked and verified the deposit).
  - In `Raffle.redeemWinningTicket` (`Raffle.sol:334-336`): calls `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` and then verifies `if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner);`.
  - In `Raffle.releaseSponsorPrize` (`Raffle.sol:404-406`): calls `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` and then verifies `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);`.

#### 8.3 Token Allowlists & Destination Hygiene

- **Quote Token**: Fixed at factory deployment (`immutable quoteToken`).
- **Prize Token (`prizeToken`)**: **No allowlist** (`RaffleFactory._validateCreateParams`, `RaffleFactory.sol:124-175`). Only checks `_requireContract(params.prizeToken)`, protocol destination exclusions, and `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)`. See **TIA-01**.
- **Protocol Destination Hygiene (`_isProtocolDestination`)**:
  - Both `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:132-154`) and `Raffle._isProtocolDestination` (`Raffle.sol:575-591`) prevent `sponsor`, `sponsorRecipient`, `protocolTreasury`, ticket recipients (`_update`), and quote token recipients (`_transferQuote`) from being any protocol plumbing address: `address(this)`, `factory`, `raffleImplementation`, `quoteToken`, `vrfWrapper`, `prizeToken`, or any clone where `factory.isRaffle(destination) == true`.
  - Note: `_isProtocolDestination` does **not** include `address(i_linkToken)` (`vrfWrapper.link()`), though transferring tickets or USDC to the LINK token contract is only a user self-footgun rather than a protocol accounting hazard.

---

### 9. ERC721 CONFORMITY CHECKS

#### 9.1 `Raffle` Ticket Token Implementation (`src/Raffle.sol`)

| ERC-721 Requirement | Implementation in `Raffle` (`OpenZeppelin ERC721 v5.6.0`) | Status |
| :--- | :--- | :--- |
| **Transfer to `0x0` reverts** | `ERC721.transferFrom` (`ERC721.sol:113-115`) checks `if (to == address(0)) revert ERC721InvalidReceiver(address(0));`. | ✓ PASS |
| **`safeTransferFrom` implemented & checks `onERC721Received`** | Inherited from `ERC721.sol:123-132` -> `ERC721Utils.checkOnERC721Received` (`ERC721Utils.sol:26-49`), verifying `retval == IERC721Receiver.onERC721Received.selector` when `to.code.length > 0`. | ✓ PASS |
| **`name()` and `symbol()` implemented** | Overridden in `Raffle.sol:486-494` to return `"raffle.fun Ticket"` and `"RAFFLE"`. | ✓ PASS |
| **`decimals()` not present** | Not present on `Raffle` (`slither-check-erc` verified). | ✓ PASS |
| **`ownerOf(tokenId)` reverts for invalid / burned IDs** | `ERC721.ownerOf` (`ERC721.sol:55-57`) calls `_requireOwned(tokenId)`, reverting with `ERC721NonexistentToken(tokenId)` when `_ownerOf(tokenId) == address(0)` (before mint or after `_burn`). | ✓ PASS |
| **Transfers clear single-token approvals** | `ERC721._update` (`ERC721.sol:167`) calls `_approve(address(0), tokenId, address(0), false)` whenever `from != address(0)` (on both transfers and burns; verified by `testProperty_ERC721ProtocolDestinationGuardsAndApprovalClearing`). | ✓ PASS |
| **Token ID immutability** | `ticketId = uint256(ticketCount) + 1` (`Raffle.sol:228-232`) is assigned once in `buyEntries`; `_ticketRanges[ticketId]` is never modified or reused after `_burn(ticketId)`. | ✓ PASS |
| **`tokenURI(uint256)` behavior** | Inherited from `ERC721.sol:76-81`. Because `_baseURI()` returns `""`, `tokenURI(ticketId)` returns `""` for every existing ticket (`TIA-06`). | ⚠ Low (`TIA-06`) |

---

### 10. ERC721 COMMON RISKS

1. **`onERC721Received` Callback Reentrancy**:
   - **When `Raffle` Mints Tickets (`buyEntries -> _safeMint`)**:
     - `buyEntries` (`Raffle.sol:209-237`) is `nonReentrant` and updates all state variables (`totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, `unsettledPot`) **before** calling `_safeMint(recipient, ticketId)` on line 235.
     - During the recipient's `onERC721Received` callback, `ReentrancyGuard` blocks re-entering `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, and `releaseSponsorPrize`.
     - Even if the recipient transfers the newly minted ticket inside `onERC721Received` via `transferFrom`, `_ticketRanges[ticketId]` and `_owners[ticketId]` are already finalized before `checkOnERC721Received` runs (`ERC721.sol:189-192`).
   - **When `Raffle` Receives the Prize NFT (`Raffle.onERC721Received`)**:
     - `Raffle.onERC721Received` (`Raffle.sol:413-431`) strictly requires:
       ```solidity
       if (
           status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
               || from != sponsor || operator != factory
       ) {
           revert UnexpectedPrize(msg.sender, tokenId, from, operator);
       }
       status = Status.Active;
       ```
     - Because `status` immediately transitions from `AwaitingPrize` to `Active` on line 429, a malicious `prizeToken` cannot call `onERC721Received` a second time, and any unsolicited `safeTransferFrom` of any other ERC-721 token to `Raffle` always reverts with `UnexpectedPrize`.
2. **Safe Minting vs. Delivery (`_safeMint` vs. `transferFrom`)**:
   - `Raffle` uses `_safeMint(recipient, ticketId)` when minting tickets (`Raffle.sol:235`).
   - However, when delivering the `prizeToken` in `redeemWinningTicket` (`Raffle.sol:334`) and `releaseSponsorPrize` (`Raffle.sol:404`), `Raffle` uses raw `prizeToken.transferFrom(...)` rather than `safeTransferFrom(...)` (see **TIA-02** below).
3. **Burning Tokens Clears Approvals**:
   - `Raffle.redeemWinningTicket` (`Raffle.sol:331`) and `Raffle.refundTickets` (`Raffle.sol:361`) call OpenZeppelin `ERC721._burn(ticketId)`, which calls `_update(address(0), ticketId, address(0))` and clears `_tokenApprovals[ticketId]`.

---

## PHASE 5: RISK ASSESSMENT & DETAILED FINDINGS

> **Distinction Between Executed Verification and Recommendations**: All behavioral claims below were verified by source inspection, Slither static analysis (`0.11.6`), Foundry property tests (`forge 1.7.1`), and Echidna property fuzzing (`2.3.3`). Proposed code changes are clearly labeled under **Defensive Recommendation**.

---

### [TIA-01] HIGH: Decoupled `NftWon` Storage Settlement (`settleWinningTicket`) and Untrusted `prizeToken` Delivery (`redeemWinningTicket`) Allows Malicious/Pausable Prize Token Sponsor to Claim 95% USDC Proceeds While Blocking Winner NFT Redemption

- **Severity**: **High**
- **Category**: Category 8 (Token Integration Safety), Category 9 & 10 (ERC-721 Conformity & Integration Risks)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:304-346`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L304-L346) (`settleWinningTicket`, `redeemWinningTicket`)
  - [`packages/contracts/src/Raffle.sol:375-382`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L375-L382) (`releaseSponsorProceeds`)
  - [`packages/contracts/src/Raffle.sol:537-562`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L537-L562) (`_settleWinningTicket`)
  - [`packages/contracts/src/RaffleFactory.sol:124-175`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol#L124-L175) (`_validateCreateParams`)
  - [`DESIGN.md:9-19`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md#L9-L19)

#### Executed Analysis & Evidence

[`DESIGN.md:19`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md#L19) explicitly defines the trust model:
> *"Quote token and Chainlink wrapper are trusted canonical dependencies; **arbitrary prize contracts and ticket recipients are untrusted**."*

And [`DESIGN.md:11`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/DESIGN.md#L11) specifies:
> *"Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure. Sponsor and treasury can claim independently after settlement."*

In `RaffleFactory._validateCreateParams` (`src/RaffleFactory.sol:167`), any contract implementing `IERC165.supportsInterface(type(IERC721).interfaceId)` can be used as `prizeToken`; there is no collection allowlist. When a raffle resolves to `Status.NftWon`:
1. `settleWinningTicket(ticketId)` (`src/Raffle.sol:304-306` -> `_settleWinningTicket`, `src/Raffle.sol:537-562`) performs storage-only accounting: it sets `settlementComplete = true`, `unsettledPot = 0`, `sponsorProceeds = grossPot - protocolFee` (95% of the pot), and `protocolFees = protocolFee` (5% of the pot), **without verifying that `prizeToken` can actually be delivered to the winner**.
2. Immediately after `settleWinningTicket(ticketId)`, `releaseSponsorProceeds()` (`src/Raffle.sol:375-382`) allows `sponsorRecipient` to withdraw 95% of the USDC pot (`sponsorProceeds`).
3. When the winner calls `redeemWinningTicket(ticketId)` (`src/Raffle.sol:309-346`), lines 334–336 execute:
   ```solidity
   prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
   if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
       revert PrizeDeliveryVerificationFailed(winner);
   }
   ```
4. If the untrusted `prizeToken` pauses transfers, blocklists the winner, enforces creator-controlled transfer restrictions (e.g., ERC-721C transfer validator), or is a sponsor-deployed ERC-721 that reverts on `transferFrom` once `raffle.status() == Status.NftWon`, then `redeemWinningTicket` permanently reverts while the sponsor has already extracted 95% of all buyers' USDC via `settleWinningTicket` + `releaseSponsorProceeds`!
5. This exact behavior was verified by `testProperty_DecoupledSettlementAllowsSponsorProceedsWhenPrizeTokenPauses()` in `scratch/logs/12_forge_test_properties.log`.

#### Defensive Recommendation

1. **Enforce a Prize Token Allowlist or Gate `sponsorProceeds` on Winner Prize Delivery**:
   - **Option A (Protocol-Level Fix — Gate `sponsorProceeds` in `NftWon` on Prize Delivery)**: In `Status.NftWon`, do not allow `releaseSponsorProceeds()` until `prizeClaimed == true` (i.e., after the prize NFT has been successfully delivered to the winner in `redeemWinningTicket`), or allow `redeemWinningTicket` / a fallback timeout to convert an undeliverable `NftWon` raffle into `Refunding` / `CashWon` if `prizeToken.transferFrom` fails.
   - **Option B (Factory-Level Fix — Curated Prize Collection Allowlist)**: If `settleWinningTicket` and `releaseSponsorProceeds` must remain decoupled from `redeemWinningTicket` per `DESIGN.md:11` (so a winner who refuses to redeem cannot lock `sponsorProceeds`), then `prizeToken` **cannot** be untrusted: `RaffleFactory` should enforce an allowlist of verified, non-pausable, standards-compliant ERC-721 prize contracts (reconciling `DESIGN.md:19` with `IRaffle.sol:17`).

---

### [TIA-02] MEDIUM: Prize NFT Delivery in `redeemWinningTicket` and `releaseSponsorPrize` Uses Raw `IERC721.transferFrom` Instead of `safeTransferFrom`, Risking Locked NFTs in Non-`IERC721Receiver` Contract Recipients

- **Severity**: **Medium**
- **Category**: Category 8 (Token Integration Safety), Category 9 & 10 (ERC-721 Conformity & Common Risks)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:334-336`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L334-L336) (`redeemWinningTicket`)
  - [`packages/contracts/src/Raffle.sol:404-406`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L404-L406) (`releaseSponsorPrize`)
  - [`packages/contracts/src/RaffleFactory.sol:124-175`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol#L124-L175) (`_validateCreateParams`)

#### Executed Analysis & Evidence

While `RaffleFactory.createRaffle` uses `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`src/RaffleFactory.sol:101`) to escrow the prize NFT and `Raffle.buyEntries` uses `_safeMint(recipient, ticketId)` (`src/Raffle.sol:235`) to mint tickets, both outbound prize delivery functions in `Raffle.sol` use raw `transferFrom`:
```solidity
// src/Raffle.sol:334 (redeemWinningTicket)
prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);

// src/Raffle.sol:404 (releaseSponsorPrize)
prizeToken.transferFrom(address(this), recipient, prizeTokenId);
```
This creates two concrete integration hazards (verified by `testProperty_PrizeDeliveryUsesTransferFromWithoutReceiverHook`):
1. **Unvalidated `sponsorRecipient` Contract**: `RaffleFactory.createRaffle` allows `params.sponsorRecipient` to be an arbitrary smart contract (such as a revenue-split vault created for USDC `sponsorProceeds`) without checking whether `sponsorRecipient` can handle ERC-721 tokens. Because `releaseSponsorPrize()` (`src/Raffle.sol:396-409`) is **permissionless** (`external nonReentrant`) in `CashWon` and `Refunding`, anyone can call `releaseSponsorPrize()` and force the prize NFT into `sponsorRecipient` via raw `transferFrom`, permanently freezing the NFT if `sponsorRecipient` only supports ERC-20 withdrawals!
2. **Smart Contract Ticket Holders Requiring `onERC721Received`**: A smart contract `winner` that acquired a ticket (either via `buyEntries` by implementing `IERC721Receiver` only for `RAFFLE` tickets, or via secondary `transferFrom`) may rely on `onERC721Received` callbacks to track or custody incoming ERC-721 assets. Delivering `prizeToken` via raw `transferFrom` bypasses `onERC721Received`.

#### Defensive Recommendation

- Separate `sponsorProceedsRecipient` (for USDC) from `sponsorPrizeRecipient` (or default prize return to `sponsor`, who originally held and transferred the `prizeToken` in `createRaffle`), or allow `redeemWinningTicket(uint256 ticketId, address recipient)` / `safeTransferFrom` with an optional recipient parameter so contract winners and sponsors can direct the NFT to an ERC-721-capable address without enabling third-party callback griefing.

---

### [TIA-03] MEDIUM: Immutable `sponsorRecipient` and `protocolTreasury` Have No Rotation or Fallback Recipient If Blocklisted by `quoteToken` (USDC), Permanently Freezing `sponsorProceeds` or `protocolFees`

- **Severity**: **Medium**
- **Category**: Category 3 (Owner Privileges), Category 7.7 & 7.8 (Blocklists & Pausable Tokens), Category 8 (Token Integration Safety)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:50-55`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L50-L55), [`src/Raffle.sol:198-199`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L198-L199), [`src/Raffle.sol:375-393`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L375-L393)
  - [`packages/contracts/src/RaffleFactory.sol:32`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol#L32)

#### Executed Analysis & Evidence

Canonical USDC (`quoteToken`) implements a centralized `blacklist` (`notBlacklisted(msg.sender)`, `notBlacklisted(from)`, `notBlacklisted(to)`).
- **Positive Finding for Ticket Holders**: Because `Raffle` decouples claims into pull functions (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`) and `Raffle._update` (`src/Raffle.sol:497-501`) allows ERC-721 ticket transfers in **every** raffle status (including `CashWon` and `Refunding`), a ticket holder who becomes blacklisted by USDC can still transfer their `RAFFLE` ERC-721 ticket to an un-blacklisted address and claim their refund or cash prize (verified by `testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot`).
- **Vulnerability for `sponsorRecipient` and `protocolTreasury`**: Unlike ticket holders, `sponsorRecipient` (`src/Raffle.sol:50, 198`) and `protocolTreasury` (`src/RaffleFactory.sol:32`, `src/Raffle.sol:54, 199`) are locked at initialization with no setter or fallback recipient parameter in `releaseSponsorProceeds()` (`src/Raffle.sol:375-382`) or `releaseProtocolFees()` (`src/Raffle.sol:386-393`). If `sponsorRecipient` or `protocolTreasury` is blacklisted by Circle (or is a compromised/bricked contract that cannot receive USDC), `sponsorProceeds` or `protocolFees` in that raffle (and for `protocolTreasury`, across **all future raffles created by `RaffleFactory`**) are permanently unclaimable unless a new `RaffleFactory` is deployed.

#### Defensive Recommendation

- Allow `sponsor` to specify a recipient address when calling `releaseSponsorProceeds(address to)` (or keep the permissionless `releaseSponsorProceeds()` sending to `sponsorRecipient` while allowing `msg.sender == sponsor` to redirect to an alternate valid destination), and consider allowing `protocolTreasury` to be updated in `RaffleFactory` for future raffles.

---

### [TIA-04] MEDIUM: `buyEntries` Credits `unsettledPot` by Nominal `grossAmount` Without Before/After Balance Verification (`quoteToken` Fee-on-Transfer / Deflationary / Rebasing Incompatibility)

- **Severity**: **Medium**
- **Category**: Category 5 (ERC-20 Extension Risks), Category 7.3 & 7.4 (Fee-on-Transfer & Rebasing Tokens), Category 8 (Token Integration Safety)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:223-234`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L223-L234) (`buyEntries`)
  - [`packages/contracts/src/RaffleFactory.sol:70-74`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol#L70-L74) (`constructor`)

#### Executed Analysis & Evidence

In `Raffle.buyEntries` (`src/Raffle.sol:223-234`):
```solidity
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
...
unsettledPot += grossAmount;
```
The contract does not measure `quoteToken.balanceOf(address(this))` before and after `safeTransferFrom`. While canonical USDC does not currently charge transfer fees, `RaffleFactory.constructor` (`src/RaffleFactory.sol:70-74`) accepts **any** contract whose `decimals()` returns `6` (including USDT, which has 6 decimals and an on-chain fee switch `maximumFee` / `basisPointsRate`, or fee-bearing 6-decimal tokens). As demonstrated in `testProperty_FeeOnTransferQuoteTokenCreatesDeficit`, if any fee is deducted on transfer, `accountedQuoteBalance()` exceeds `quoteToken.balanceOf(address(this))`, causing the final refund or settlement claimant to revert with insufficient balance and permanently locking the remaining balance in the contract.

#### Defensive Recommendation

- Measure the exact received balance in `buyEntries` and revert if it is less than `grossAmount`:
  ```solidity
  uint256 balanceBefore = quoteToken.balanceOf(address(this));
  quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
  uint256 received = quoteToken.balanceOf(address(this)) - balanceBefore;
  if (received != grossAmount) revert UnexpectedQuoteAmountReceived(grossAmount, received);
  ```

---

### [TIA-05] LOW: `RaffleFactory` Constructor Validates Only `quoteToken` Code Presence and `decimals() == 6`; Unsolicited Direct ERC-20 Transfers (`quoteToken` or `i_linkToken`) to `Raffle` Are Unrecoverable

- **Severity**: **Low**
- **Category**: Category 4 (ERC-20 Conformity), Category 8 (Token Integration Safety)
- **Locations**:
  - [`packages/contracts/src/RaffleFactory.sol:70-74`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/RaffleFactory.sol#L70-L74)
  - [`packages/contracts/src/Raffle.sol:469-477`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L469-L477) (`accountedQuoteBalance`)
  - [`packages/contracts/src/Raffle.sol:575-591`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L575-L591) (`_isProtocolDestination`)

#### Executed Analysis & Evidence

1. **Direct ERC-20 Transfers Trapped**: While `Raffle.receive()` (`src/Raffle.sol:171-173`) rejects direct native ETH transfers (`revert DirectNativeTransfer()`) and `Raffle.onERC721Received` (`src/Raffle.sol:413-431`) rejects unsolicited ERC-721 safe transfers (`revert UnexpectedPrize(...)`), standard ERC-20 `transfer(raffle, amount)` has no receiver hook. Any `quoteToken` sent directly to `Raffle` outside `buyEntries` is excluded from `accountedQuoteBalance()` (`unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees`) and cannot be swept. Similarly, if any LINK (`i_linkToken`) or unrelated ERC-20 is sent to `Raffle` or `RaffleFactory`, there is no rescue mechanism.
2. **`i_linkToken` Omitted from `_isProtocolDestination`**: `Raffle` inherits `i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link())` from `VRFV2PlusWrapperConsumerBase` (`VRFV2PlusWrapperConsumerBase.sol:45`), but `_isProtocolDestination` (`src/Raffle.sol:575-591`) checks `vrfWrapper` without checking `address(i_linkToken)`.

#### Defensive Recommendation

- Consider adding a permissionless excess-sweep function on `Raffle` that transfers `quoteToken.balanceOf(address(this)) - accountedQuoteBalance()` (and any non-`quoteToken` ERC-20 tokens) to `protocolTreasury`, and include `address(i_linkToken)` in `_isProtocolDestination`.

---

### [TIA-06] LOW: `Raffle` ERC-721 Ticket Implementation Leaves `tokenURI(ticketId)` Empty (`""`) and Inherits Redundant Unused `_name` and `_symbol` Storage Slots in Every Clone

- **Severity**: **Low**
- **Category**: Category 2 (Contract Composition), Category 9 (ERC-721 Conformity)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:28`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L28), [`src/Raffle.sol:156`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L156), [`src/Raffle.sol:486-494`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L486-L494)

#### Executed Analysis & Evidence

`Raffle` inherits OpenZeppelin `ERC721("", "")` (`src/Raffle.sol:156`) and overrides `name()` (`"raffle.fun Ticket"`) and `symbol()` (`"RAFFLE"`) as `pure` functions (`src/Raffle.sol:486-494`), which correctly makes `name()` and `symbol()` work across ERC-1167 minimal proxy clones (where constructor storage is not copied). However:
1. `Raffle` does not override `_baseURI()` or `tokenURI(uint256)` (`ERC721.sol:76-90`). Consequently, calling `tokenURI(ticketId)` on any valid minted ticket returns `""` (empty string), verified by `testProperty_ERC721MetadataAndInterfaces`. Wallets and NFT marketplaces querying `IERC721Metadata.tokenURI` receive no metadata, ticket range (`[firstEntry, lastEntry]`), or raffle ID information.
2. Storage slots 0 and 1 in every clone remain reserved for OpenZeppelin `ERC721`'s private `_name` and `_symbol` strings, which are never read or written.

#### Defensive Recommendation

- Override `tokenURI(uint256 ticketId)` in `Raffle.sol` (calling `_requireOwned(ticketId)` first per ERC-721 specification) to return an on-chain `data:application/json;base64,...` payload or a deterministic URI incorporating `address(this)`, `raffleId`, `ticketId`, and `ticketRange(ticketId)`.

---

### [TIA-07] INFORMATIONAL: `refundTickets` Loops Over `_burn` -> `_update` (`calls-loop` Detector) and Arithmetic-Driving Events Lack Indexed Parameters (`events-maths` Detector)

- **Severity**: **Informational**
- **Category**: Category 2 (Contract Composition), Category 10 (ERC-721 Common Risks)
- **Locations**:
  - [`packages/contracts/src/Raffle.sol:349-372`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L349-L372), [`src/Raffle.sol:497-501`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/Raffle.sol#L497-L501)
  - [`packages/contracts/src/interfaces/IRaffle.sol:221-289`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffle.sol#L221-L289)
  - [`packages/contracts/src/interfaces/IRaffleFactory.sol:74-83`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/packages/contracts/src/interfaces/IRaffleFactory.sol#L74-L83)

#### Executed Analysis & Evidence

1. **`calls-loop` in `refundTickets`**: Slither flags `Raffle.refundTickets` (`src/Raffle.sol:349-372`) because the `for` loop calls `_burn(ticketId)` -> `Raffle._update(address(0), ticketId, address(0))`, and `_update` contains a call to `_isProtocolDestination` (`src/Raffle.sol:498`), which makes external `STATICCALL`s (`canonicalFactory.raffleImplementation()`, `canonicalFactory.isRaffle(destination)`). At runtime, `if (to != address(0) && _isProtocolDestination(...))` short-circuits when `to == address(0)` (burn), so no external calls occur during `_burn`, and the loop is capped at `MAX_REFUND_TICKET_BATCH_SIZE = 100`. However, during normal ticket transfers (`to != address(0)`), `Raffle._update` makes up to 2 external `STATICCALL`s to `factory` on every transfer.
2. **Unindexed Custom Events (`events-maths`)**: None of the custom events in `IRaffle.sol` (`TicketPurchased`, `DrawRequested`, `RaffleResolved`, `RefundsEnabled`, `WinningTicketSettled`, `WinnerClaimed`, `TicketsRefunded`, `SponsorProceedsClaimed`, `ProtocolFeesClaimed`, `SponsorPrizeReleased`) or `IRaffleFactory.sol` (`RaffleCreated`) declare `indexed` parameters (e.g., `indexed buyer`, `indexed recipient`, `indexed ticketId`, `indexed raffleId`, `indexed raffle`).

#### Defensive Recommendation

- Cache `raffleImplementation` as an `immutable` or `address(this)` in `Raffle` constructor to eliminate the `canonicalFactory.raffleImplementation()` external call in `_isProtocolDestination`, and add `indexed` keywords to primary key parameters (`raffleId`, `raffle`, `ticketId`, `buyer`, `recipient`) on custom events in `IRaffle.sol` and `IRaffleFactory.sol`.

---

## NATIVE SKILL DELIVERABLES (`REPORT_TEMPLATES.md`)

### Deliverable 1: Compliance Checklist

```markdown
## Token Standards Compliance

### General Considerations
- [x] Specification & interface documentation present (`DESIGN.md`, `IRaffle.sol`, `IRaffleFactory.sol`)
- [x] Pinned dependency integrity verified (`dependency-hashes.json` — all 31 files match SHA-256)
- [ ] Security contact (`@custom:security-contact` / `SECURITY.md`) and security mailing list established

### Contract Composition
- [x] Avoids unnecessary complexity (`710` SLOC across 5 source files; max cyclomatic complexity `10` in `redeemWinningTicket`)
- [x] Uses Solidity `0.8.36` built-in overflow/underflow protection (`0` `unchecked` blocks in `src/`)
- [x] Single canonical ERC-1167 address entry point per raffle clone (`Clones.clone(raffleImplementation)`)
- [x] Bounded batch operations (`MAX_REFUND_TICKET_BATCH_SIZE = 100` in `refundTickets`)

### Owner Privileges
- [x] Non-upgradeable contracts (`RaffleFactory` and `Raffle` clones are immutable)
- [x] No privileged or arbitrary minting (`buyEntries` requires `entryCount * ENTRY_PRICE` in `quoteToken`)
- [x] No protocol-level pause or blacklist capable of trapping user tickets
- [x] Sponsor early cancellation restricted to `totalEntries == 0` (`Raffle.sol:280-284`)

### ERC20 Conformity (Integrated `quoteToken` — Canonical 6-Decimal USDC)
- [x] Transfer functions return `bool` or empty return data handled via OpenZeppelin `SafeERC20` (`Raffle.sol:224, 566`)
- [x] `decimals()` validated at factory construction (`IERC20Metadata(quoteToken_).decimals() == 6`, `RaffleFactory.sol:70-74`)
- [x] Contract code existence verified (`_requireContract(quoteToken_)`, `RaffleFactory.sol:66`)
- [x] No `approve()` calls made by `Raffle` or `RaffleFactory` (immune to approval race conditions on-contract)
- [x] Zero-value transfers prevented by non-zero guards across all entry points (`Raffle.sol:218, 339, 350, 378, 389`)

### ERC721 Conformity (`Raffle` Ticket Token Implementation & Integrated `prizeToken`)
- [x] `slither-check-erc . Raffle --erc erc721` passes 13/13 functions and 3/3 events (`scratch/logs/05_slither_check_erc721_orig.log`)
- [x] Transfers to `0x0` revert (`ERC721InvalidReceiver(address(0))`)
- [x] Transfers and mints to protocol plumbing revert (`_isProtocolDestination` in `Raffle._update`, `Raffle.sol:497-501`)
- [x] `safeTransferFrom` and `_safeMint` verify `onERC721Received` on contract recipients
- [x] `name()` (`"raffle.fun Ticket"`) and `symbol()` (`"RAFFLE"`) implemented as clone-safe pure overrides (`Raffle.sol:486-494`)
- [x] `ownerOf` reverts for invalid/burned token IDs (`ERC721NonexistentToken`)
- [x] Transfers and burns clear single-token approvals (`ERC721._update`)
- [x] Token IDs (`1..ticketCount`) and `_ticketRanges[ticketId]` are immutable once minted
- [ ] `tokenURI(uint256)` returns non-empty metadata (currently returns `""` — `TIA-06`)
```

---

### Deliverable 2: Weird Token Pattern Analysis

```markdown
## Weird ERC20 & ERC721 Pattern Detection

### Patterns Present / Relevant in Target Context:
1. **Blocklists (Pattern 7.7 — USDC `blacklist`)**
   - Location: `src/Raffle.sol:50-55, 198-199, 323-393`
   - Risk Level: **MEDIUM (`TIA-03`)**
   - Mitigation: Pull-based payout functions isolate claimants, and `Raffle._update` allows blacklisted ticket holders to transfer `RAFFLE` tickets in `CashWon`/`Refunding` to an un-blacklisted address (`testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot`). However, `sponsorRecipient` and `protocolTreasury` are immutable and have no fallback recipient if blacklisted.

2. **Pausable & Upgradeable Quote Token (Patterns 7.5, 7.8 — USDC `FiatTokenProxy` / `Pausable`)**
   - Location: `src/RaffleFactory.sol:26, 70-74`, `src/Raffle.sol:58, 224, 566`
   - Risk Level: **LOW**
   - Mitigation: Accepted canonical dependency per `DESIGN.md:19`. `NftWon` winner NFT redemption (`redeemWinningTicket`) does not touch `quoteToken` and succeeds even if USDC is paused.

3. **Fee-on-Transfer & Rebasing Quote Tokens (Patterns 7.3, 7.4)**
   - Location: `src/Raffle.sol:223-234` (`buyEntries`), `src/Raffle.sol:469-477` (`accountedQuoteBalance`)
   - Risk Level: **MEDIUM (`TIA-04` — if deployed with a fee-bearing 6-decimal token or if a 6-decimal token activates a fee switch)**
   - Mitigation: Currently relies on deployment configuration using canonical fee-free USDC; lacks on-chain `balanceAfter - balanceBefore == grossAmount` assertion in `buyEntries`.

4. **Low Decimals (Pattern 7.14 — 6 Decimals)**
   - Location: `src/libraries/RaffleConstants.sol:13-25`, `src/RaffleFactory.sol:70-74`
   - Risk Level: **NONE (Properly Handled)**
   - Mitigation: `ENTRY_PRICE = 1_000_000` and `QUOTE_TOKEN_DECIMALS = 6` are enforced in `RaffleFactory.constructor`. Because `1_000_000` is divisible by `BPS = 10_000`, all fee (`500` bps) and cash-winner (`3_000` bps) splits are exact integers with zero rounding dust.

5. **Untrusted / Pausable / Restrictive ERC-721 `prizeToken` (Category 8 & 10 Extension)**
   - Location: `src/Raffle.sol:304-346, 375-382`, `src/RaffleFactory.sol:124-175`
   - Risk Level: **HIGH (`TIA-01`) / MEDIUM (`TIA-02`)**
   - Mitigation: Escrow deposit (`createRaffle`) and outbound deliveries (`redeemWinningTicket`, `releaseSponsorPrize`) verify `prizeToken.ownerOf(prizeTokenId)`. However, decoupling storage-only `settleWinningTicket` (which unlocks `sponsorProceeds`) from `redeemWinningTicket` allows a malicious/pausable `prizeToken` to block winner NFT redemption after the sponsor claims 95% of the USDC pot (`TIA-01`), and outbound delivery uses raw `transferFrom` instead of `safeTransferFrom` (`TIA-02`).

### Relevant External Integrations:
- If integrating with arbitrary ERC-20 tokens beyond canonical USDC: add balance-delta verification in `buyEntries` (`TIA-04`).
- If integrating with arbitrary sponsor-supplied ERC-721 `prizeToken` contracts: either gate `releaseSponsorProceeds` in `NftWon` on `prizeClaimed == true` or restrict `prizeToken` to an allowlist of verified ERC-721 contracts (`TIA-01`).
```

---

### Deliverable 3: On-chain Analysis Report

```markdown
## On-chain Token Analysis

**Contract Address**: N/A (Pre-deployment source codebase in `packages/contracts`; no deployed contract address or live RPC endpoint configured)
**Chain**: EVM-compatible target (`pragma solidity 0.8.36`, `evm_version = "paris"`)
**Block Number**: N/A (Offline static + local Foundry/Echidna EVM execution; coverage gap documented in Section 6.1)

### Supply Metrics (`Raffle` Ticket ERC-721 Model)
- Initial Supply per Raffle Clone: `0` tickets (`0` entries)
- Max Entries per Raffle Clone: `type(uint128).max` (`340,282,366,920,938,463,463,374,607,431,768,211,455` entries at `1_000_000` quote units per entry)
- Minting Mechanism: Permissionless during `Status.Active` prior to `endTime` (`buyEntries`), 1 sequential `ticketId` per purchase call covering `[firstEntry, lastEntry]`
- Burning Mechanism: Atomic burn in `redeemWinningTicket(ticketId)` (winning ticket in `NftWon` or `CashWon`) and `refundTickets(uint256[] ticketIds)` (all tickets in `Refunding`, up to `100` tickets per batch)

### Holder Distribution & Concentration Mechanics
- Concentration Impact: Winning probability (`winningEntry = (_randomWords[0] % totalEntries) + 1`) is strictly linear in entries purchased (`1_000_000` quote units per entry).
- Flash Loan / Flash Mint Resistance: **HIGH (Immune)** — Entry purchases lock `quoteToken` before `endTime`, whereas `requestDraw()` requires `block.timestamp >= endTime` and asynchronous Chainlink VRF v2.5 fulfillment (`requestConfirmations = 3`, `_requestInFlight` guard).
- Centralization Risk: **ZERO** on `Raffle` / `RaffleFactory` (no admin keys); **MODERATE** external dependency on Circle (`quoteToken` USDC blacklist/pause/upgradeability) and Chainlink VRF v2.5 Wrapper liveness (mitigated by `DRAW_CALLBACK_TIMEOUT = 1 days` fallback to `Status.Refunding` via `enableRefunds()`).
```

---

### Deliverable 4: Integration Safety Assessment

```markdown
## Protocol Token Integration Analysis

### Current Implementation:

1. **Quote Token (`quoteToken` — ERC-20) Transfers**:
   ```solidity
   // packages/contracts/src/Raffle.sol:223-224
   uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
   quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

   // packages/contracts/src/Raffle.sol:564-567
   function _transferQuote(address to, uint256 amount) private {
       if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
       quoteToken.safeTransfer(to, amount);
   }
   ```
   - ✓ Uses OpenZeppelin v5.6.0 `SafeERC20` (`safeTransferFrom`, `safeTransfer`).
   - ✓ Protected by `ReentrancyGuard.nonReentrant` and strict CEI state updates.
   - ✓ Blocks transfers to protocol destinations (`_isProtocolDestination`).
   - ✗ Does not check `balanceBefore` / `balanceAfter` on `safeTransferFrom` (`TIA-04`).

2. **Prize Token (`prizeToken` — ERC-721) Escrow & Delivery**:
   ```solidity
   // packages/contracts/src/RaffleFactory.sol:101-106
   prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
   if (
       prize.ownerOf(params.prizeTokenId) != raffle
           || IRaffle(raffle).status() != IRaffle.Status.Active
   ) {
       revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
   }

   // packages/contracts/src/Raffle.sol:334-336
   prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
   if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
       revert PrizeDeliveryVerificationFailed(winner);
   }
   ```
   - ✓ Verifies `IERC165.supportsInterface(type(IERC721).interfaceId)` and post-transfer `ownerOf` on both escrow and delivery.
   - ✗ Decouples `settleWinningTicket` (unlocking `sponsorProceeds`) from `redeemWinningTicket` (delivering `prizeToken`) without a `prizeToken` allowlist (`TIA-01`).
   - ✗ Uses raw `transferFrom` instead of `safeTransferFrom` on prize delivery (`TIA-02`).

### Vulnerabilities Identified:
1. **`TIA-01` (High)**: Malicious or paused `prizeToken` allows sponsor to extract 95% of USDC pot via `settleWinningTicket` + `releaseSponsorProceeds` in `NftWon` while winner NFT redemption (`redeemWinningTicket`) reverts.
2. **`TIA-02` (Medium)**: Raw `prizeToken.transferFrom` in `redeemWinningTicket` and permissionless `releaseSponsorPrize` can lock NFTs in contract recipients (`sponsorRecipient` or contract `winner`) that do not support arbitrary ERC-721 tokens.
3. **`TIA-03` (Medium)**: Immutable `sponsorRecipient` and `protocolTreasury` cannot be rotated if blacklisted by USDC.
4. **`TIA-04` (Medium)**: Missing balance-delta check in `buyEntries` makes internal accounting vulnerable to fee-on-transfer or deflationary tokens.
```

---

### Deliverable 5: Prioritized Recommendations

```markdown
## Recommendations

### Critical / High Priority (Fix Before Launch)
1. **Resolve Untrusted `prizeToken` Settlement vs. Redemption Decoupling (`TIA-01`)**
   - **Impact**: Prevents a malicious sponsor (or a sponsor whose `prizeToken` collection becomes paused/restricted) from claiming 95% of buyers' USDC in `NftWon` while the winner is permanently unable to redeem the prize NFT.
   - **Action**:
     - Either require `prizeClaimed == true` before `releaseSponsorProceeds()` can be called in `Status.NftWon` (and provide a timeout path to transition to `Refunding` if `prizeToken.transferFrom` reverts), **or**
     - Add an allowlist of vetted ERC-721 `prizeToken` contracts in `RaffleFactory` if `settleWinningTicket` and `releaseSponsorProceeds` must remain independent of `redeemWinningTicket`.

### Medium Priority (Address Before Mainnet / Multi-Token Expansion)
2. **Protect Contract Recipients During Prize NFT Delivery (`TIA-02`)**
   - **Impact**: Prevents permanent loss of prize NFTs when `sponsorRecipient` is a USDC revenue-split contract that cannot handle ERC-721 tokens, or when a contract `winner` requires `onERC721Received` callbacks.
   - **Action**: Separate `sponsorPrizeRecipient` (or return the prize to `sponsor` by default) from `sponsorRecipient`, or allow `winner` / `sponsor` to specify a receiver-checked destination address when claiming the prize NFT.

3. **Add Balance-Delta Verification in `buyEntries` (`TIA-04`)**
   - **Impact**: Guarantees `accountedQuoteBalance() <= quoteToken.balanceOf(address(this))` even if deployed with a fee-capable 6-decimal token.
   - **Action**: Record `uint256 balanceBefore = quoteToken.balanceOf(address(this))` before `safeTransferFrom` and require `quoteToken.balanceOf(address(this)) - balanceBefore == grossAmount`.

4. **Add Fallback Recipient Flexibility for Blacklisted `sponsorRecipient` / `protocolTreasury` (`TIA-03`)**
   - **Impact**: Prevents permanent freezing of `sponsorProceeds` or `protocolFees` if Circle blacklists `sponsorRecipient` or `protocolTreasury`.
   - **Action**: Allow `sponsor` to pass an alternate recipient address to `releaseSponsorProceeds`, and allow `protocolTreasury` to rotate its address for future raffles.

### Low / Informational Priority (Best-Practice Hardening)
5. **Implement `tokenURI(uint256)` on `Raffle` Tickets (`TIA-06`)**
   - **Action**: Override `tokenURI(uint256 ticketId)` in `Raffle.sol` to return on-chain JSON metadata containing `raffleId`, `ticketId`, and `ticketRange(ticketId)`.

6. **Index Custom Event Parameters & Include `i_linkToken` in `_isProtocolDestination` (`TIA-05`, `TIA-07`)**
   - **Action**: Mark `raffleId`, `raffle`, `ticketId`, `buyer`, and `recipient` as `indexed` in `IRaffle.sol` and `IRaffleFactory.sol`, add `address(i_linkToken)` to `_isProtocolDestination`, and cache `raffleImplementation` in `Raffle` to avoid an external `STATICCALL` in `_isProtocolDestination`.
```

---

## APPENDIX: COMPLETE RAW TOOLING COMMANDS & LOG ARTIFACTS

All raw outputs are preserved in full under `scratch/logs/`:

| Log File | Command Executed | Exit Code & Summary |
| :--- | :--- | :--- |
| [`scratch/logs/01_forge_build_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/01_forge_build_orig.log) | `forge build` | Exit `0` — Compiled 36 files with `Solc 0.8.36` (7 `block-timestamp` lint notes on `src/Raffle.sol`). |
| [`scratch/logs/02_slither_detectors_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/02_slither_detectors_orig.log) | `slither .` | Exit `0` — 36 contracts analyzed, 102 total detector results (all owned contract findings triaged in Section 2.5). |
| [`scratch/logs/03_slither_human_summary_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/03_slither_human_summary_orig.log) | `slither . --print human-summary` | Exit `0` — 5 source contracts (`710` SLOC), 31 dependency contracts (`2,220` SLOC). |
| [`scratch/logs/04_slither_contract_summary_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/04_slither_contract_summary_orig.log) | `slither . --print contract-summary` | Exit `0` — Full contract & function visibility breakdown. |
| [`scratch/logs/05_slither_check_erc721_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/05_slither_check_erc721_orig.log) | `slither-check-erc . Raffle --erc erc721` | Exit `0` — All 13 ERC-721 functions and 3 events passed `[✓]`. |
| [`scratch/logs/06_slither_check_erc20_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/06_slither_check_erc20_orig.log) | `slither-check-erc . Raffle --erc erc20` | Exit `0` — Confirmed `Raffle` is ERC-721, not ERC-20. |
| [`scratch/logs/07_slither_prop_orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/07_slither_prop_orig.log) | `slither-prop . --contract Raffle` | Documented coverage gap (`ERROR:root:Foundry not yet supported by slither-prop.`). |
| [`scratch/logs/08_slither_prop_solc.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/08_slither_prop_solc.log) | `slither-prop src/Raffle.sol --contract Raffle --compile-force-framework solc ...` | Documented coverage gap (`Raffle is not ERC20 compliant. Consider checking the contract with slither-check-erc`). |
| [`scratch/logs/09_slither_function_summary.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/09_slither_function_summary.log) | `slither . --print function-summary` | Exit `0` — Complete cyclomatic complexity, read/write, and internal/external call tables. |
| [`scratch/logs/10_slither_vars_and_auth.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/10_slither_vars_and_auth.log) | `slither . --print vars-and-auth` | Exit `0` — State variables written and `msg.sender` auth conditions per function. |
| [`scratch/logs/11_slither_inheritance.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/11_slither_inheritance.log) | `slither . --print inheritance` | Exit `0` — Inheritance trees for all 36 contracts. |
| [`scratch/logs/12_forge_test_properties.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/12_forge_test_properties.log) | `forge test -vv --match-contract TokenIntegrationPropertiesTest` | Exit `0` — `9 passed; 0 failed` (including 3,000 fuzz runs). |
| [`scratch/logs/13_echidna_properties.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S3/work/scratch/logs/13_echidna_properties.log) | `echidna . --contract RaffleEchidnaProperties --test-limit 5000` | Exit `0` — `5/5` Echidna properties passing across `5,214` calls (`8,507` unique instructions). |
