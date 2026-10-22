# Deliverable 2: Architecture Analysis — `raffle-fun`

## Phase 3 & Deliverable 2: Architecture Analysis (Assessment Areas 2, 3, 4)

### 3.1 On-Chain vs Off-Chain Computation (Assessment Area 2)

#### Current Distribution Assessment
`raffle-fun` exemplifies Trail of Bits' *"prefer verifying results over computing them on-chain"* guideline across its three most gas-sensitive operations:

1. **Contiguous Range-Ticket Minting (`buyEntries` at [`Raffle.sol:209-237`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L209-L237))**:
   - Rather than minting `entryCount` individual ERC-721 tokens or populating an array of entry owners in an $O(N)$ loop, `Raffle` mints a single ERC-721 token `ticketId = ++ticketCount` and writes a single packed 32-byte storage slot `_ticketRanges[ticketId] = TicketRange({firstEntry: firstEntry, lastEntry: lastEntry})` (`uint128` + `uint128` in one `SSTORE`).
   - **Gas Impact**: Measured via `forge test --gas-report` (`scratch/tool-logs/forge-test-compat.log:339`), `buyEntries` costs between `103,892` gas (warm) and `189,392` gas (cold) regardless of whether the user buys 1 entry or 1,000,000 entries.

2. **Off-Chain Winning Ticket Lookup + $O(1)$ On-Chain Verification (`settleWinningTicket` / `_requireWinningTicket` at [`Raffle.sol:304-306, 535-565, 586-591`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L586-L591))**:
   - When Chainlink VRF fulfills the random word in `fulfillRandomWords` (`Raffle.sol:509-524`), the callback does **not** perform a binary search or linear scan over `_ticketRanges` inside the 300,000-gas VRF callback budget. Instead, it only computes `winningEntry = uint128((randomWords[0] % totalEntries) + 1)` (`Raffle.sol:516`) and records `status` (`22,574` gas total).
   - Anyone off-chain can identify the `ticketId` whose `[firstEntry, lastEntry]` range contains `winningEntry` and pass `ticketId` to `settleWinningTicket(ticketId)` or `redeemWinningTicket(ticketId)`.
   - On-chain, `_requireWinningTicket(ticketId)` (`Raffle.sol:586-591`) verifies the witness `ticketId` in $O(1)$ (a single `SLOAD` of `_ticketRanges[ticketId]`):
     ```solidity
     function _requireWinningTicket(uint256 ticketId) private view {
         (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
         uint128 selectedEntry = winningEntry;
         if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
             revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
         }
     }
     ```
   - Because purchased ticket ranges partition `[1, totalEntries]` into disjoint contiguous intervals (`firstEntry = totalEntries + 1`, `lastEntry = totalEntries + entryCount` at `Raffle.sol:224-226`), the `ticketId` satisfying `firstEntry <= winningEntry <= lastEntry` is mathematically unique.

3. **Bounded Batch Refund Processing (`refundTickets` at [`Raffle.sol:346-374`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L346-L374))**:
   - Enforces `1 <= ticketIds.length <= MAX_REFUND_TICKET_BATCH_SIZE (100)` (`Raffle.sol:349-352`) to prevent block-gas-limit DoS while aggregating USDC transfers into a single `_transferQuote(msg.sender, amount)` call at the end of the batch (`Raffle.sol:372`).

#### Identified Gas & Complexity Optimization Opportunities

| # | Location (`file:line`) | Current On-Chain Behavior | Optimization Opportunity | Estimated Gas Savings |
|---|---|---|---|---|
| G-1 | [`Raffle.sol:593-605`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L593-L605) (`_isProtocolDestination`) | Calls `canonicalFactory.raffleImplementation()` via external `STATICCALL` up to 3 times in `initialize()` and once in every `buyEntries()`, ERC-721 transfer, and `_transferQuote()`. | Store `raffleImplementation = address(this)` as an `immutable` in `Raffle`'s constructor (`Raffle.sol:155-166`). Because the `Raffle` constructor runs when deploying the master implementation (`RaffleFactory.sol:89`), `address(this)` in `Raffle`'s constructor IS `raffleImplementation`! Comparing against an `immutable` replaces an external `STATICCALL` (`~271` gas each, called 3x in `initialize`) with a 3-gas `PUSH20` and eliminates an external call edge for static analyzers. | ~800 gas in `createRaffle`; ~260 gas per `buyEntries`, ticket transfer, and payout |
| G-2 | [`Raffle.sol:599-604`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L599-L604) (`_isProtocolDestination`) | Evaluates `destination == canonicalFactory.raffleImplementation()` *before* checking `if (destination.code.length == 0) return false;` (`line 602`). For EOA buyers/recipients (`destination.code.length == 0`), it still performs the external `STATICCALL` to `canonicalFactory.raffleImplementation()`. | Check `if (destination == address(this)) return true; if (destination.code.length == 0) return false;` first (since all protocol contracts—`factory`, `quoteToken`, `vrfWrapper`, `prizeToken`, `raffleImplementation`, and other raffles—have `code.length > 0`, except `address(this)` during `initialize` only if `clone` wasn't deployed yet, and EIP-1167 clones already have 45 bytes of runtime code before `initialize()` is called!). | Eliminates all external `STATICCALL`s to `factory` for EOA users |
| G-3 | [`Raffle.sol:244-257`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L244-L257) (`requestDraw`) | Calls `getVrfRequestPrice()` (`i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)`) at line 249, and then `requestRandomnessPayInNative` (`VRFV2PlusWrapperConsumerBase.sol:81`) calls `i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords)` a second time on line 81. | Removing the redundant pre-check in `requestDraw()` (or calling `i_vrfV2PlusWrapper` directly without `VRFV2PlusWrapperConsumerBase`'s duplicate call) avoids calling `calculateRequestPriceNative` twice per draw request. | ~2,500–5,000 gas per `requestDraw` |

---

### 3.2 Upgradeability Review (Assessment Area 3)

#### Current Approach: Explicitly Non-Upgradeable (Immutable Architecture)
We verified both `DESIGN.md` and the complete codebase for any explicit or implicit upgradeability mechanisms:
- **Specification**: `DESIGN.md:19` states *"Immutable contracts. There is no owner, pause switch, fee switch, wrapper setter, treasury setter, or upgrade hook"*, and `DESIGN.md:134` states *"No administrative rescue path, upgradeability, or mutable configuration after deployment."*
- **Codebase Verification**:
  - `RaffleFactory.sol` stores `quoteToken`, `vrfWrapper`, `protocolTreasury`, and `raffleImplementation` as `immutable` variables (`RaffleFactory.sol:45-54`). There are no setter functions, no `Ownable` / `AccessControl` inheritance, and no `UUPSUpgradeable` / `TransparentUpgradeableProxy` / `Beacon` patterns.
  - Each `Raffle` clone is deployed via `Clones.clone(raffleImplementation)` (`RaffleFactory.sol:105`), which embeds the 20-byte `raffleImplementation` address directly into the clone's 45-byte EIP-1167 runtime bytecode (`0x363d3d373d3d3d363d73<raffleImplementation>5af43d82803e903d91602b57fd5bf3` at `Clones.sol:54`). Neither the factory nor the clone can change the target implementation address after deployment.
  - Neither `Raffle` nor `RaffleFactory` contains `selfdestruct` or arbitrary `delegatecall`.

#### Migration vs. Upgradeability Trade-Off Assessment (Trail of Bits Guidelines)
Following Trail of Bits' *Upgradeability* guidelines:
1. **Why Non-Upgradeability Fits `raffle-fun`**: Each `Raffle` instance has a bounded lifecycle (`MAX_SALE_DURATION = 30 days` + `DRAW_REQUEST_TIMEOUT = 1 days` + `DRAW_CALLBACK_TIMEOUT = 2 days` = at most 33 days from creation to terminal state). Because individual raffles are short-lived escrow contracts, immutability eliminates proxy-upgrade rug risks, storage layout collision hazards across versions, and admin key compromise risks.
2. **Operational Consequence / Migration Path**: If a bug is discovered, or if Chainlink deprecates the configured `vrfWrapper` (`IVRFV2PlusWrapper`), or if `protocolTreasury` needs to be rotated:
   - Existing active/drawing raffles whose VRF wrapper stops responding will deterministically expire after `DRAW_REQUEST_TIMEOUT` (1 day) or `DRAW_CALLBACK_TIMEOUT` (2 days) and transition via `enableRefunds()` to `Refunding`, allowing 100% USDC ticket refunds and sponsor NFT recovery.
   - New raffles must be directed to a newly deployed `RaffleFactory`.
3. **Documentation Recommendation**: Document a formal **Factory Migration & Incident Runbook** specifying how off-chain indexers and the frontend transition from an old `RaffleFactory` to a new `RaffleFactory` while continuing to service claims (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) on existing clones of the old factory.

---

### 3.3 Delegatecall Proxy Pattern & Storage Layout Security Review (Assessment Area 4)

Even though `raffle-fun` is not upgradeable, **it uses `delegatecall` via OpenZeppelin's EIP-1167 Minimal Proxy (`Clones.clone`)**. In accordance with Trail of Bits' *Delegatecall Proxy Pattern* guidelines (and avoiding the rationalization *"No upgrades detected, skip proxy analysis"*), we audited the EIP-1167 clone architecture, storage layout, initialization atomicity, and `slither-check-upgradeability` output.

#### 3.3.1 Complete Storage Layouts (`forge inspect <Contract> storageLayout`)

##### `Raffle` Storage Layout (`scratch/tool-logs/forge-storage-layout-Raffle.log`)

| Slot | Byte Offset | Size (Bytes) | Type | Variable | Contract Origin | Clone Initialization / Usage |
|---:|---:|---:|---|---|---|
| `0` | `0` | `32` | `string` | `_name` | `ERC721` | **Unused in clones** (`Raffle.name()` is a `pure` override at `Raffle.sol:479-481`; set to `""` on implementation in constructor) |
| `1` | `0` | `32` | `string` | `_symbol` | `ERC721` | **Unused in clones** (`Raffle.symbol()` is a `pure` override at `Raffle.sol:485-487`; set to `""` on implementation in constructor) |
| `2` | `0` | `32` | `mapping(uint256 => address)` | `_owners` | `ERC721` | Populated on `_safeMint` / cleared on `_burn` |
| `3` | `0` | `32` | `mapping(address => uint256)` | `_balances` | `ERC721` | Updated on `_safeMint` / `_update` / `_burn` |
| `4` | `0` | `32` | `mapping(uint256 => address)` | `_tokenApprovals` | `ERC721` | Standard ERC-721 per-ticket approvals |
| `5` | `0` | `32` | `mapping(address => mapping(address => bool))` | `_operatorApprovals` | `ERC721` | Standard ERC-721 operator approvals |
| `6` | `0` | `20` | `contract LinkTokenInterface` | `i_linkToken` | `VRFV2PlusWrapperConsumerBase` | **Unused in clones** (set on implementation in `VRFV2PlusWrapperConsumerBase` constructor at line 50; never written in `Raffle.initialize`, so always `address(0)` in clones!) |
| `6` | `20` | `12` | *(unallocated padding)* | — | — | `i_vrfV2PlusWrapper` is `immutable` (in bytecode), so 12 bytes remain in slot 6 |
| `7` | `0` | `20` | `address` | `sponsor` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:197`) |
| `8` | `0` | `20` | `address` | `sponsorRecipient` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:198`) |
| `9` | `0` | `20` | `address` | `protocolTreasury` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:199`) |
| `10` | `0` | `20` | `contract IERC721` | `prizeToken` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:200`) |
| `11` | `0` | `32` | `uint256` | `prizeTokenId` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:201`) |
| `12` | `0` | `32` | `uint256` | `raffleId` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:202`) |
| `13` | `0` | `16` | `uint128` | `reserveEntries` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:203`) |
| `13` | `16` | `8` | `uint64` | `endTime` | `Raffle` | Initialized in `Raffle.initialize` (`Raffle.sol:204`) |
| `14` | `0` | `16` | `uint128` | `totalEntries` | `Raffle` | Updated in `buyEntries` (`Raffle.sol:227`) |
| `15` | `0` | `32` | `uint256` | `ticketCount` | `Raffle` | Updated in `buyEntries` (`Raffle.sol:219`) |
| `16` | `0` | `32` | `uint256` | `unsettledPot` | `Raffle` | Updated in `buyEntries`, `enableRefunds`, `_settleWinningTicket` |
| `17` | `0` | `32` | `uint256` | `remainingRefundLiability` | `Raffle` | Set in `enableRefunds`, decremented in `refundTickets` |
| `18` | `0` | `20` | `address` | `winnerRecipient` | `Raffle` | Set in `redeemWinningTicket` (`Raffle.sol:330`) |
| `19` | `0` | `32` | `uint256` | `winnerProceeds` | `Raffle` | Set in `_settleWinningTicket`, zeroed in `redeemWinningTicket` |
| `20` | `0` | `32` | `uint256` | `sponsorProceeds` | `Raffle` | Set in `_settleWinningTicket`, zeroed in `releaseSponsorProceeds` |
| `21` | `0` | `32` | `uint256` | `protocolFees` | `Raffle` | Set in `_settleWinningTicket`, zeroed in `releaseProtocolFees` |
| `22` | `0` | `32` | `uint256` | `vrfRequestId` | `Raffle` | Set in `requestDraw` (`Raffle.sol:259`) |
| `23` | `0` | `8` | `uint64` | `drawRequestedAt` | `Raffle` | Set in `requestDraw` (`Raffle.sol:253`) |
| `23` | `8` | `8` | `uint64` | `resolvedAt` | `Raffle` | Set in `fulfillRandomWords` (`Raffle.sol:519`) |
| `23` | `16` | `16` | `uint128` | `winningEntry` | `Raffle` | Set in `fulfillRandomWords` (`Raffle.sol:518`) |
| `24` | `0` | `32` | `uint256` | `winningTicketId` | `Raffle` | Set in `_settleWinningTicket` (`Raffle.sol:560`) |
| `25` | `0` | `1` | `enum IRaffle.Status` | `status` | `Raffle` | Packed with 5 booleans in slot 25 (`6 / 32` bytes used) |
| `25` | `1` | `1` | `bool` | `settlementComplete` | `Raffle` | Packed in slot 25 |
| `25` | `2` | `1` | `bool` | `winnerRedeemed` | `Raffle` | Packed in slot 25 |
| `25` | `3` | `1` | `bool` | `prizeClaimed` | `Raffle` | Packed in slot 25 |
| `25` | `4` | `1` | `bool` | `initialized` | `Raffle` | Packed in slot 25 |
| `25` | `5` | `1` | `bool` | `_requestInFlight` | `Raffle` | Packed in slot 25 |
| `26` | `0` | `32` | `mapping(uint256 => struct IRaffle.TicketRange)` | `_ticketRanges` | `Raffle` | Maps `ticketId` -> packed `(uint128 firstEntry, uint128 lastEntry)` |
| `ERC-7201` | `0` | `32` | `uint256` | `REENTRANCY_GUARD_STORAGE` (`0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`) | `ReentrancyGuard` | Namespaced slot (`ReentrancyGuard.sol:33`) |

##### `RaffleFactory` Storage Layout (`scratch/tool-logs/forge-storage-layout-RaffleFactory.log`)

| Slot | Byte Offset | Size (Bytes) | Type | Variable | Contract Origin |
|---:|---:|---:|---|---|---|
| `0` | `0` | `32` | `uint256` | `raffleCount` | `RaffleFactory` |
| `1` | `0` | `32` | `mapping(uint256 => address)` | `raffleById` | `RaffleFactory` |
| `2` | `0` | `32` | `mapping(address => uint256)` | `idByRaffle` | `RaffleFactory` |
| `3` | `0` | `32` | `mapping(address => bool)` | `isRaffle` | `RaffleFactory` |
| `ERC-7201` | `0` | `32` | `uint256` | `REENTRANCY_GUARD_STORAGE` (`0x9b779b17...5f00`) | `ReentrancyGuard` |

#### 3.3.2 Proxy & Clone Security Checks (`slither-check-upgradeability` & Manual Audit)

We executed `slither-check-upgradeability . Raffle --proxy-filename src/RaffleFactory.sol --proxy-name RaffleFactory` (`scratch/tool-logs/slither-check-upgradeability-Raffle.log`) and audited all proxy/clone security invariants:

1. **Master Implementation Locking**:
   - In `Raffle.constructor` (`Raffle.sol:155-166`), the master implementation sets `initialized = true;` and `status = Status.Refunding;`.
   - Any attempt to call `initialize(...)` on `raffleImplementation` immediately reverts with `AlreadyInitialized()` (`Raffle.sol:177`), verified by `test_ImplementationIsLockedAndRefundMode` (`scratch/tool-logs/forge-test-compat.log:71`).
   - Because `status == Status.Refunding` and `ticketCount == 0` / `prizeToken == address(0)` on `raffleImplementation`, all state-changing functions (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) revert if called directly on `raffleImplementation`.

2. **Atomic Clone Deployment & Initialization**:
   - In `RaffleFactory.createRaffle` (`RaffleFactory.sol:105-121`), `raffle = Clones.clone(raffleImplementation)` and `IRaffle(raffle).initialize(...)` occur atomically within the same `nonReentrant` transaction before any external call to untrusted contracts (`prize.safeTransferFrom` happens at line 127 *after* `initialize()` and *after* registry mappings `raffleById`, `idByRaffle`, and `isRaffle` are populated at lines 123-125).
   - Furthermore, `Raffle.initialize` checks `if (msg.sender != factory) revert OnlyFactory();` (`Raffle.sol:178`), where `factory` is an `immutable` set to `address(RaffleFactory)` in `Raffle`'s constructor (`Raffle.sol:81, 161`). Because `immutable` values are stored in the implementation's runtime bytecode (and therefore read by clones during `delegatecall`), even if someone manually deployed their own EIP-1167 clone pointing to `raffleImplementation`, they could never call `initialize()` on it because `msg.sender != factory`.

3. **Three Subtle Constructor vs. Clone Semantics Identified**:
   - **Quirk 1 — `VRFV2PlusWrapperConsumerBase.i_linkToken` is a Storage Variable (`slot 6`), Not an `immutable`**:
     In `@chainlink/contracts@1.5.0` (`VRFV2PlusWrapperConsumerBase.sol:35-38`), `i_vrfV2PlusWrapper` is declared `immutable`, but `LinkTokenInterface internal i_linkToken;` (`line 38`) is a **regular storage variable** (despite its `i_` prefix!) that is only assigned in `VRFV2PlusWrapperConsumerBase.constructor` (`i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());` at line 50). Consequently, in every `Raffle` clone, `i_linkToken` (and `raffle.getLinkToken()`) is `address(0)`! Because `Raffle` only uses `requestRandomnessPayInNative` (which uses `i_vrfV2PlusWrapper`, an `immutable`) and never uses `requestRandomness` (LINK payment), this does not break native VRF drawing, but calling the inherited public getter `raffle.getLinkToken()` on any clone returns `address(0)` while calling it on `raffleImplementation` returns `vrfWrapper.link()`.
   - **Quirk 2 — `ReentrancyGuard` UninitializedERC-7201 Slot in Clones**:
     OpenZeppelin's `ReentrancyGuard.constructor` (`ReentrancyGuard.sol:51-53`) sets `REENTRANCY_GUARD_STORAGE` (`0x9b779b17...5f00`) to `NOT_ENTERED (1)` on the implementation contract. In a newly cloned `Raffle`, that namespaced storage slot starts at `0`. Because `_reentrancyGuardEntered()` checks `== ENTERED (2)` (`ReentrancyGuard.sol:84`), the guard still functions properly in clones, **but** the first `nonReentrant` call on every clone (`buyEntries` or `enableRefunds`) pays a 20,000-gas cold `0 -> 2` `SSTORE` and only receives a 4,200-gas refund when resetting `2 -> 1` in `_nonReentrantAfter()`.
   - **Quirk 3 — Unused `ERC721` Storage Slots 0 and 1 (`_name`, `_symbol`) and Storage Packing**:
     `ERC721("", "")` reserves slots 0 and 1 for `_name` and `_symbol`, which `Raffle` never uses because `name()` and `symbol()` are `pure` overrides (`Raffle.sol:479-487`). Additionally, in `Raffle.sol:85-103`, `sponsor` (20B, slot 7), `sponsorRecipient` (20B, slot 8), `protocolTreasury` (20B, slot 9), `prizeToken` (20B, slot 10), `endTime` (8B in slot 13 alongside 16B `reserveEntries`, leaving 8B unused), and `totalEntries` (16B alone in slot 14, leaving 16B unused) could pack `endTime` (8B) with `sponsor` (20B) or `prizeToken` (20B) and pack `reserveEntries` (16B) with `totalEntries` (16B) into a single slot, saving 1 `SSTORE` during `initialize` and warming `reserveEntries`/`totalEntries` together.

---

