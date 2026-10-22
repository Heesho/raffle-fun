# Deliverable 3: Implementation Review — `raffle-fun`

## Phase 4 & Deliverable 3: Implementation Review (Assessment Areas 5–11)

### 4.1 Function Composition & Modularity Analysis (Assessment Area 5)

We extracted function-level metrics across `Raffle` and `RaffleFactory` using Slither's `function-summary`, `vars-and-auth`, and `require` printers (`scratch/tool-logs/slither-printers-summary.log:1700-1822`).

#### Complete Function Composition Table (`Raffle` & `RaffleFactory`)

| Contract | Function | Visibility | Modifiers | State Vars Written | External Calls | Cyclomatic Complexity | Line Range |
|---|---|---|---|---|---|---:|---|
| `Raffle` | `constructor(address,address)` | `public` | `ERC721`, `VRFV2PlusWrapperConsumerBase` | `factory` (imm), `quoteToken` (imm), `initialized`, `status` | `vrfV2PlusWrapper.link()` (via base) | 2 | `Raffle.sol:155-166` |
| `Raffle` | `receive()` | `external payable` | — | *(always reverts `DirectNativeTransfer`)* | — | 1 | `Raffle.sol:171-173` |
| `Raffle` | `initialize(RaffleInitParams)` | `external` | — | `initialized`, `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`, `status` | `canonicalFactory.raffleImplementation()`, `canonicalFactory.isRaffle()` (via `_isProtocolDestination`) | 7 | `Raffle.sol:176-206` |
| `Raffle` | `buyEntries(address,uint128)` | `external` | `nonReentrant` | `ticketCount`, `totalEntries`, `unsettledPot`, `_ticketRanges` (+ ERC-721 `_owners`, `_balances`) | `quoteToken.safeTransferFrom`, `_isProtocolDestination`, `ERC721Utils.checkOnERC721Received` | 5 | `Raffle.sol:209-237` |
| `Raffle` | `requestDraw()` | `external payable` | `nonReentrant` | `status`, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId` | `i_vrfV2PlusWrapper.calculateRequestPriceNative` (2x), `i_vrfV2PlusWrapper.requestRandomWordsInNative`, `refundRecipient.call{value: excess}` | 8 | `Raffle.sol:240-273` |
| `Raffle` | `enableRefunds()` | `external` | `nonReentrant` | `unsettledPot`, `remainingRefundLiability`, `status` | — | 7 | `Raffle.sol:276-301` |
| `Raffle` | `settleWinningTicket(uint256)` | `external` | `nonReentrant` | *(delegates to `_settleWinningTicket`)* | — | 1 | `Raffle.sol:304-306` |
| `Raffle` | `redeemWinningTicket(uint256)` | `external` | `nonReentrant` | `winnerRecipient`, `winnerRedeemed`, `prizeClaimed`, `winnerProceeds` (+ `_settleWinningTicket` & `_burn`) | `prizeToken.transferFrom`, `prizeToken.ownerOf`, `quoteToken.safeTransfer` | 10 | `Raffle.sol:309-343` |
| `Raffle` | `refundTickets(uint256[])` | `external` | `nonReentrant` | `remainingRefundLiability` (+ ERC-721 `_burn`) | `quoteToken.safeTransfer` | 4 | `Raffle.sol:346-374` |
| `Raffle` | `releaseSponsorProceeds()` | `external` | `nonReentrant` | `sponsorProceeds` | `quoteToken.safeTransfer`, `_isProtocolDestination` | 2 | `Raffle.sol:377-387` |
| `Raffle` | `releaseProtocolFees()` | `external` | `nonReentrant` | `protocolFees` | `quoteToken.safeTransfer`, `_isProtocolDestination` | 2 | `Raffle.sol:390-400` |
| `Raffle` | `releaseSponsorPrize()` | `external` | `nonReentrant` | `prizeClaimed` | `prizeToken.transferFrom`, `prizeToken.ownerOf` | 4 | `Raffle.sol:403-420` |
| `Raffle` | `onERC721Received(...)` | `external` | — | `status` | — | 2 | `Raffle.sol:423-437` |
| `Raffle` | `getVrfRequestPrice()` | `public view` | — | — | `i_vrfV2PlusWrapper.calculateRequestPriceNative` | 1 | `Raffle.sol:442-444` |
| `Raffle` | `estimateVrfRequestPrice(uint256)` | `public view` | — | — | `i_vrfV2PlusWrapper.estimateRequestPriceNative` | 1 | `Raffle.sol:447-449` |
| `Raffle` | `vrfWrapper()` | `public view` | — | — | — | 1 | `Raffle.sol:451-453` |
| `Raffle` | `ticketRange(uint256)` | `public view` | — | — | — | 1 | `Raffle.sol:455-458` |
| `Raffle` | `drawRequestDeadline()` | `public view` | — | — | — | 1 | `Raffle.sol:460-462` |
| `Raffle` | `callbackDeadline()` | `public view` | — | — | — | 2 | `Raffle.sol:464-466` |
| `Raffle` | `accountedQuoteBalance()` | `public view` | — | — | — | 1 | `Raffle.sol:468-471` |
| `Raffle` | `grossSales()` | `public view` | — | — | — | 1 | `Raffle.sol:473-475` |
| `Raffle` | `name()` / `symbol()` | `public pure` | — | — | — | 1 / 1 | `Raffle.sol:479-487` |
| `Raffle` | `_update(address,uint256,address)` | `internal` | — | ERC-721 `_owners`, `_balances`, `_tokenApprovals` | `_isProtocolDestination` (when `to != address(0)`) | 2 | `Raffle.sol:489-504` |
| `Raffle` | `fulfillRandomWords(uint256,uint256[])` | `internal` | — | `winningEntry`, `resolvedAt`, `status` | — | 2 | `Raffle.sol:509-524` |
| `Raffle` | `_settleWinningTicket(uint256)` | `private` | — | `unsettledPot`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `winningTicketId`, `settlementComplete` | — | 4 | `Raffle.sol:535-565` |
| `Raffle` | `_transferQuote(address,uint256)` | `private` | — | — | `_isProtocolDestination`, `quoteToken.safeTransfer` | 2 | `Raffle.sol:570-578` |
| `Raffle` | `_requireStatus(Status)` | `private view` | — | — | — | 2 | `Raffle.sol:581-583` |
| `Raffle` | `_requireWinningTicket(uint256)` | `private view` | — | — | — | 2 | `Raffle.sol:586-591` |
| `Raffle` | `_isProtocolDestination(address,address)` | `private view` | — | — | `canonicalFactory.raffleImplementation()`, `canonicalFactory.isRaffle(destination)` | 2 | `Raffle.sol:593-605` |
| `Raffle` | `_validatedVrfWrapper(address)` | `private pure` | — | — | — | 2 | `Raffle.sol:610-613` |
| `RaffleFactory` | `constructor(address,address,address)` | `public` | — | `quoteToken` (imm), `vrfWrapper` (imm), `protocolTreasury` (imm), `raffleImplementation` (imm) | `IERC20Metadata(quoteToken_).decimals()`, `new Raffle(...)` | 7 | `RaffleFactory.sol:74-93` |
| `RaffleFactory` | `createRaffle(CreateRaffleParams)` | `external` | `nonReentrant` | `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle` | `Clones.clone`, `IRaffle(raffle).initialize`, `prize.safeTransferFrom`, `prize.ownerOf`, `IRaffle(raffle).status` | 5 | `RaffleFactory.sol:97-148` |
| `RaffleFactory` | `_validateCreateParams(CreateRaffleParams)` | `private view` | — | — | `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` | 8 | `RaffleFactory.sol:154-180` |
| `RaffleFactory` | `_requireContract(address)` | `private view` | — | — | — | 2 | `RaffleFactory.sol:182-185` |

#### Function Composition Assessment
- **Strengths**:
  - Every function in `Raffle` and `RaffleFactory` is under 45 lines long; the longest function is `RaffleFactory.createRaffle` (51 lines including multi-line struct construction and event emission) and `Raffle.redeemWinningTicket` (35 lines).
  - Shared settlement logic between `settleWinningTicket(uint256)` and `redeemWinningTicket(uint256)` is cleanly factored into `_settleWinningTicket(uint256)` (`Raffle.sol:535-565`).
  - All 8 external post-initialization state-changing functions in `Raffle` and `createRaffle` in `RaffleFactory` carry the `nonReentrant` modifier.
- **Improvement Opportunity (`_isProtocolDestination` duplication across `Raffle` and `RaffleFactory`)**:
  - Destination validation logic in `Raffle._isProtocolDestination` (`Raffle.sol:593-605`) and `RaffleFactory._validateCreateParams` / `RaffleFactory.constructor` (`RaffleFactory.sol:84-92, 158-167`) duplicates the checks `destination == address(this) || destination == factory || destination == quoteToken || destination == vrfWrapper || destination == prizeToken || destination == raffleImplementation || isRaffle[destination]`. Factoring this into a single view helper on `RaffleFactory` (e.g., `factory.isProtocolAddress(address candidate)`) or storing `raffleImplementation` as an `immutable` in `Raffle` reduces code duplication and cross-contract calls.

---

### 4.2 Inheritance Structure Analysis (Assessment Area 6)

From Slither's `inheritance` printer (`scratch/tool-logs/slither-printers-summary.log:3640-3683`) and `scratch/diagrams/slither/inheritance-graph.dot`:

- **`Raffle` Linearized C3 Inheritance Chain**:
  `Raffle -> ERC721 -> Context, ERC165 -> IERC721Metadata -> IERC721 -> IERC165, IERC721Errors, ReentrancyGuard, VRFV2PlusWrapperConsumerBase, IERC721Receiver, IRaffle`
  - **Depth**: 2 levels (`Raffle -> ERC721 -> Context / ERC165`).
  - **Width**: 5 direct parents (`ERC721`, `ReentrancyGuard`, `VRFV2PlusWrapperConsumerBase`, `IERC721Receiver`, `IRaffle`).
  - **Diamond Inheritance**: Only on pure interface `IERC165` (`ERC721 -> ERC165 -> IERC165`, `ERC721 -> IERC721Metadata -> IERC721 -> IERC165`, `Raffle -> IERC721Receiver`). Zero state or implementation diamond conflicts.
- **`RaffleFactory` Linearized C3 Inheritance Chain**:
  `RaffleFactory -> ReentrancyGuard, IRaffleFactory` (Depth = 1, Width = 2).

#### Key Inheritance Finding: Unnecessary Attack/Failure Surface from `VRFV2PlusWrapperConsumerBase`
`Raffle` inherits Chainlink's `VRFV2PlusWrapperConsumerBase` (`node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:33-121`). Inspection of `VRFV2PlusWrapperConsumerBase.sol` reveals three issues when used with EIP-1167 clones that only pay in native ETH:
1. **Constructor External Call to `vrfV2PlusWrapper.link()` (`VRFV2PlusWrapperConsumerBase.sol:50`)**:
   ```solidity
   constructor(address _vrfV2PlusWrapper) {
     IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);
     i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
     i_vrfV2PlusWrapper = vrfV2PlusWrapper;
   }
   ```
   Even though `Raffle` exclusively uses native-token billing (`requestRandomnessPayInNative`) and never uses LINK billing, `VRFV2PlusWrapperConsumerBase`'s constructor unconditionally calls `vrfV2PlusWrapper.link()` and writes `i_linkToken` to storage slot 6 on the implementation. If `vrfWrapper_` is a custom or mock wrapper that does not implement `link()`, `new Raffle(...)` in `RaffleFactory`'s constructor reverts.
2. **Broken Clone Getter `getLinkToken()` (`VRFV2PlusWrapperConsumerBase.sol:118-120`)**:
   Because `i_linkToken` is a regular storage variable (slot 6) rather than an `immutable`, `raffle.getLinkToken()` returns `address(0)` on every `Raffle` clone, whereas it returns `vrfWrapper.link()` on `raffleImplementation`.
3. **Misleading Inherited `getBalance()` Function (`VRFV2PlusWrapperConsumerBase.sol:113-115`)**:
   Exposes `getBalance()` publicly on every `Raffle` clone, which returns `address(this).balance` (always `0` in `Raffle` because native overpayments are refunded atomically and `receive()` reverts) while carrying misleading NatSpec (`"Return the current LINK balance of the contract"`).
4. **Recommendation**: Replace inheritance of `VRFV2PlusWrapperConsumerBase` with a minimal 20-line internal base or direct `IVRFV2PlusWrapper public immutable vrfWrapper` integration in `Raffle` that implements `rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external` (checking `if (msg.sender != address(vrfWrapper)) revert OnlyVRFWrapperCanFulfill(msg.sender, address(vrfWrapper));`). This eliminates storage slot 6 (`i_linkToken`), removes the `vrfWrapper.link()` constructor call, and removes `getBalance()` / `getLinkToken()` from the public ABI.

---

### 4.3 Event Logging Analysis (Assessment Area 7)

#### Complete Event Coverage Matrix

| Contract / Interface | Event Declaration | Indexed Parameters (Count) | Emitting Function (`file:line`) | Coverage Assessment |
|---|---|---:|---|---|
| `IRaffleFactory` | `RaffleCreated(uint256 indexed raffleId, address indexed raffle, address indexed sponsor, address sponsorRecipient, address prizeToken, uint256 prizeTokenId, address quoteToken, address protocolTreasury, uint128 reserveEntries, uint64 endTime)` | 3 (`raffleId`, `raffle`, `sponsor`) | `RaffleFactory.createRaffle` (`RaffleFactory.sol:136-147`) | Complete factory creation telemetry |
| `IRaffle` | `PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor)` | 3 (`prizeToken`, `prizeTokenId`, `sponsor`) | `Raffle.onERC721Received` (`Raffle.sol:435`) | Complete escrow activation telemetry |
| `IRaffle` | `TicketPurchased(address indexed buyer, address indexed recipient, uint256 indexed ticketId, uint128 firstEntry, uint128 lastEntry, uint128 entryCount, uint256 grossAmount)` | 3 (`buyer`, `recipient`, `ticketId`) | `Raffle.buyEntries` (`Raffle.sol:235`) | Complete ticket purchase telemetry (in addition to ERC-721 `Transfer`) |
| `IRaffle` | `DrawRequested(uint256 indexed requestId, address indexed requester, uint256 fee, uint256 excessReturned, uint64 drawRequestedAt, uint64 callbackDeadline)` | 2 (`requestId`, `requester`) | `Raffle.requestDraw` (`Raffle.sol:271`) | Complete VRF request telemetry |
| `IRaffle` | `RaffleResolved(uint256 indexed requestId, uint128 indexed winningEntry, Status indexed result)` | 3 (`requestId`, `winningEntry`, `result`) | `Raffle.fulfillRandomWords` (`Raffle.sol:523`) | Complete VRF resolution telemetry |
| `IRaffle` | `WinningTicketSettled(uint256 indexed ticketId, address indexed settler, Status indexed result, uint256 cashAmount, uint256 protocolFee, uint256 sponsorAmount)` | 3 (`ticketId`, `settler`, `result`) | `Raffle._settleWinningTicket` (`Raffle.sol:563`) | Complete accounting split telemetry |
| `IRaffle` | `WinningTicketRedeemed(uint256 indexed ticketId, address indexed winner, Status indexed result, uint256 cashAmount, address prizeToken, uint256 prizeTokenId)` | 3 (`ticketId`, `winner`, `result`) | `Raffle.redeemWinningTicket` (`Raffle.sol:341`) | Complete winner payout telemetry |
| `IRaffle` | `RefundsEnabled(address indexed finalizer, uint256 remainingRefundLiability)` | 1 (`finalizer`) | `Raffle.enableRefunds` (`Raffle.sol:300`) | Complete refund activation telemetry |
| `IRaffle` | `TicketRefunded(uint256 indexed ticketId, address indexed owner, uint128 entryCount, uint256 amount)` | 2 (`ticketId`, `owner`) | `Raffle.refundTickets` (`Raffle.sol:368`) | Emitted per burned ticket in batch |
| `IRaffle` | `SponsorProceedsReleased(address indexed caller, address indexed recipient, uint256 amount)` | 2 (`caller`, `recipient`) | `Raffle.releaseSponsorProceeds` (`Raffle.sol:385`) | Complete sponsor payout telemetry |
| `IRaffle` | `ProtocolFeesReleased(address indexed caller, address indexed recipient, uint256 amount)` | 2 (`caller`, `recipient`) | `Raffle.releaseProtocolFees` (`Raffle.sol:398`) | Complete treasury fee telemetry |
| `IRaffle` | `SponsorPrizeReleased(address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId)` | 3 (`caller`, `recipient`, `prizeToken`) | `Raffle.releaseSponsorPrize` (`Raffle.sol:419`) | Complete sponsor NFT recovery telemetry |

#### Event Logging Gaps Identified
1. **Slither `events-maths` Finding on `Raffle.initialize` (`Raffle.sol:176-206`)**:
   - Slither reports (`scratch/tool-logs/slither-owned-only.log:10-15`):
     `Raffle.initialize(IRaffle.RaffleInitParams) (src/Raffle.sol#176-206) should emit an event for: prizeTokenId = params.prizeTokenId (src/Raffle.sol#201), reserveEntries = params.reserveEntries (src/Raffle.sol#203), endTime = params.endTime (src/Raffle.sol#204)`.
   - While `RaffleFactory.createRaffle` emits `RaffleCreated` from the factory address (`RaffleFactory.sol:136-147`), indexers watching logs emitted only by the `Raffle` clone address itself see `PrizeDeposited` (`Raffle.sol:435`) but no `RaffleInitialized` event containing `raffleId`, `sponsorRecipient`, `protocolTreasury`, `reserveEntries`, and `endTime`. Emitting a `RaffleInitialized` event inside `Raffle.initialize` satisfies Slither's `events-maths` check and makes each `Raffle` clone's event stream self-contained.
2. **Silent No-Op in `fulfillRandomWords` (`Raffle.sol:509-514`)**:
   - When `fulfillRandomWords` receives a late or mismatched VRF callback (`_requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1 || block.timestamp >= callbackDeadline()`), it silently `return;`s without emitting an event (so the VRF wrapper call does not revert). Emitting a diagnostic `FulfillmentIgnored(uint256 indexed requestId, Status status, uint256 timestamp)` event on that early-return branch costs ~1,500 gas (well within the 300,000-gas budget) and gives off-chain operators visibility into late or malformed VRF callbacks.

---

### 4.4 Common Pitfalls & Vulnerability Analysis (Assessment Area 8)

We systematically checked all Trail of Bits common pitfalls using both Slither (`scratch/tool-logs/slither-owned-only.log`) and manual line-by-line review + executable PoC tests in `scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol`:

#### Pitfall 1: Quote Token (USDC) Blacklist / Freeze Permanently Bricks `releaseSponsorProceeds` (`HIGH` / Design Risk)
- **Location**: [`Raffle.sol:198, 377-387`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L377-L387)
- **Analysis**:
  - `raffle-fun` rightly separates pull-payouts (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `refundTickets`) so that one party's failure or blacklist cannot block another party's claim (`DESIGN.md:107-108`).
  - However, while a ticket holder (`winner` or refund claimant) holds a transferable ERC-721 ticket and can transfer that ticket to an un-blacklisted address if their wallet is blacklisted by Circle (`USDC`)—and only `msg.sender` / `recipient` of `transfer` is checked by USDC when paying out later—`sponsorRecipient` is written once in `Raffle.initialize` (`Raffle.sol:198`) and **can never be updated** by `sponsor` or `sponsorRecipient`.
  - If `sponsorRecipient` is blacklisted by USDC (or is a smart contract wallet/split contract that becomes unpayable or reverts on USDC receipt), `releaseSponsorProceeds()` (`Raffle.sol:377-387`) will permanently revert (`quoteToken.safeTransfer(recipient, amount)`), locking `sponsorProceeds` (95% of the pot in `NftWon` or 15% in `CashWon`) in the `Raffle` clone forever.
  - **Executable Proof**: Verified in `test_BlacklistedSponsorRecipientLocksSponsorProceedsOnly()` (`scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol:339-363`, passing in `scratch/tool-logs/forge-test-compat.log:68`).
- **Recommendation**: Allow `sponsor` (or `sponsorRecipient`) to specify a `recipient` parameter in `releaseSponsorProceeds(address recipient)` when `msg.sender == sponsor || msg.sender == sponsorRecipient` (while preserving permissionless `releaseSponsorProceeds()` to the default `sponsorRecipient` for any third-party keeper caller), subject to `_isProtocolDestination(recipient, address(prizeToken)) == false`.

#### Pitfall 2: Secondary-Market Front-Running of Ticket Transfers During `Drawing` and Post-Resolution (`MEDIUM`)
- **Location**: [`Raffle.sol:321-330, 489-504`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L489-L504)
- **Analysis**:
  - Because `Raffle` is an ERC-721 contract, tickets can be listed on NFT marketplaces (OpenSea, Seaport, Blur, Reservoir).
  - `Raffle._update(address to, uint256 ticketId, address auth)` (`Raffle.sol:489-504`) only checks `_isProtocolDestination(to, address(prizeToken))` and **does not restrict transfers during `Status.Drawing`, `Status.NftWon`, or `Status.CashWon`**.
  - When the Chainlink VRF fulfillment transaction enters the public mempool (or immediately after `RaffleResolved` is emitted in `NftWon`/`CashWon`), an MEV bot or observer can compute `winningEntry = (randomWords[0] % totalEntries) + 1`, identify the winning `ticketId`, and fill any open marketplace listing (or front-run the seller's listing cancellation) before calling `redeemWinningTicket(ticketId)`.
  - Even worse, if someone calls `settleWinningTicket(ticketId)` first (`Raffle.sol:304-306`), `winningTicketId` is set on-chain while the ticket *still* remains unburned and transferable until `redeemWinningTicket` is called!
  - **Executable Proof**: Verified in `test_TicketTransferAfterResolutionChangesWinnerRecipient()` (`scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol:365-383`, passing in `scratch/tool-logs/forge-test-compat.log:74`).
- **Recommendation**: Either (a) freeze standard ERC-721 ticket transfers once `status == Status.Drawing` (or once `status == Status.NftWon || status == Status.CashWon`), or (b) snapshot the winning ticket owner inside `fulfillRandomWords` / `_settleWinningTicket`, or (c) if post-resolution ticket transferability is intentionally preserved for blacklisted-winner recovery, explicitly warn users and marketplace integrators in `DESIGN.md` and `IRaffle.sol` never to leave open marketplace listings active past `endTime`.

#### Pitfall 3: Inline Assembly Native Refund Forwards All Remaining Gas (`gas()`) (`LOW`)
- **Location**: [`Raffle.sol:264-270`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L264-L270)
- **Analysis**:
  ```solidity
  if (excess != 0) {
      bool success;
      address refundRecipient = msg.sender;
      assembly ("memory-safe") {
          success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
      }
      if (!success) revert NativeRefundFailed(msg.sender, excess);
  }
  ```
  - Using `call(..., 0, 0, 0, 0)` in inline assembly is a **good defense against returnbomb attacks** (verified in `test_ReturnBombCallerRefundSucceeds` at `scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol:325-337`), because it copies 0 bytes of return data into memory.
  - Because `requestDraw()` is `nonReentrant`, sets `_requestInFlight = false` and `vrfRequestId = requestId` *before* the assembly `call` (Checks-Effects-Interactions), and only calls `msg.sender` (`refundRecipient`), a malicious `msg.sender` cannot reenter `Raffle` or grief other callers.
  - However, Slither's `reentrancy-benign` detector (`scratch/tool-logs/slither-owned-only.log:30-36`) notes that `requestRandomnessPayInNative` is called at line 257 before `vrfRequestId = requestId` and `_requestInFlight = false` at lines 259-260. Because `_requestInFlight = true` is set *before* `requestRandomnessPayInNative` (at line 254) and checked in `fulfillRandomWords` (`if (_requestInFlight ...) return;` at line 511), synchronous callback reentrancy during `requestRandomnessPayInNative` is safely blocked.

#### Pitfall 4: Slither `calls-loop` Report on `refundTickets` (`LOW` / Static-Analysis False Positive)
- **Location**: [`Raffle.sol:354-370, 489-504, 593-605`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L489-L504)
- **Analysis**:
  - Slither's `calls-loop` detector (`scratch/tool-logs/slither-owned-only.log:17-28`) flags `Raffle.refundTickets(uint256[]) -> ERC721._burn(uint256) -> Raffle._update(address,uint256,address) -> Raffle._isProtocolDestination(address,address)` as making external calls (`canonicalFactory.raffleImplementation()` and `canonicalFactory.isRaffle(destination)`) inside a loop.
  - **Verification**: In OpenZeppelin `ERC721._burn(uint256 tokenId)` (`ERC721.sol:323`), `_burn` calls `_update(address(0), tokenId, address(0))` with `to == address(0)`. In `Raffle._update` (`Raffle.sol:495`):
    ```solidity
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    ```
    Because `to == address(0)` during `_burn`, Solidity's short-circuit evaluation of `&&` guarantees `_isProtocolDestination` is **never called** during `refundTickets`. Thus, zero external calls occur inside the `refundTickets` loop at runtime.

#### Pitfall 5: ERC-721 Prize Delivery Uses `transferFrom` Instead of `safeTransferFrom` (Intentional Design Trade-Off)
- **Location**: [`Raffle.sol:326-329, 412-415`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L326-L329)
- **Analysis**:
  - Both `redeemWinningTicket` and `releaseSponsorPrize` use `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` followed by `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);`.
  - Using `transferFrom` instead of `safeTransferFrom` prevents a smart-contract `sponsorRecipient` from rejecting `onERC721Received` when a third party calls `releaseSponsorPrize()`, and avoids reentrancy callbacks during NFT delivery. However, smart contract vaults/wallets that rely on `onERC721Received` accounting hooks when receiving ERC-721 tokens will not have their hook triggered. This trade-off is appropriate for permissionless `releaseSponsorPrize()`, and is documented in `DESIGN.md:109`.

---

### 4.5 Dependencies Review (Assessment Area 9)

#### 4.5.1 Vendored Solidity Libraries & Cryptographic Hash Verification
We verified all 31 local Solidity dependency files in `packages/contracts/node_modules/` against `dependency-hashes.json`:
- **Result**: `ALL 31 DEPENDENCY HASHES MATCH: True` (0 local modifications or code copying; all imports use `@openzeppelin/contracts/...` and `@chainlink/contracts/...` via `remappings.txt`).
- **OpenZeppelin Contracts (`@openzeppelin/contracts@5.6.1`, 27 files)**:
  - Well-audited, current v5.x release (`Clones.sol`, `SafeERC20.sol`, `ERC721.sol`, `ReentrancyGuard.sol`, `Math.sol`).
  - Uses ERC-7201 namespaced storage in `ReentrancyGuard.sol` (`slot 0x9b779b17...5f00`) and EIP-6093 custom errors (`draft-IERC6093.sol`).
- **Chainlink Contracts (`@chainlink/contracts@1.5.0`, 4 files)**:
  - Notice that all 3 VRF v2.5 files (`VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`) reside under `@chainlink/contracts/src/v0.8/vrf/dev/`.
  - Slither detectors on `@chainlink/contracts@1.5.0` (`scratch/tool-logs/slither-orig-0.8.36.log:33-36`) flag:
    - `unused-return`: `VRFV2PlusWrapperConsumerBase.requestRandomness` ignores the `bool` return value of `i_linkToken.transferAndCall(...)` (`VRFV2PlusWrapperConsumerBase.sol:69-71`). Because `Raffle` only calls `requestRandomnessPayInNative` (`Raffle.sol:257`) and never calls `requestRandomness`, this dead code path is unreached in `Raffle`.
    - Floating pragmas (`pragma solidity ^0.8.0;` and `^0.8.4;`).

#### 4.5.2 Critical Dependency Management & Lockfile Defects

1. **`pnpm-lock.yaml` `blockExoticSubdeps: true` Breaks `pnpm install` and `pnpm run` (`HIGH`)**:
   - In [`pnpm-lock.yaml:8`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/pnpm-lock.yaml#L8), `settings.blockExoticSubdeps` is set to `true`.
   - However, `@chainlink/contracts@1.5.0` declares an upstream transitive git dependency on `@zksync/contracts`.
   - When running any `pnpm run <script>` or `pnpm install` with `pnpm 11.25.0` (`package.json:4` `packageManager: "pnpm@11.25.0"`), `pnpm` aborts with (`scratch/tool-logs/package-scripts-orig.log:13-16`):
     ```text
     [WARN] Moving @chainlink/contracts that was installed by a different package manager to "node_modules/.ignored"
     [WARN] Moving @openzeppelin/contracts that was installed by a different package manager to "node_modules/.ignored"
     [ERR_PNPM_EXOTIC_SUBDEP] Exotic dependency "@zksync/contracts" (resolved via git-repository) is not allowed in subdependencies when blockExoticSubdeps is enabled
     This error happened while installing the dependencies of @chainlink/contracts@1.5.0
     ```
   - Worse yet, `pnpm`'s pre-install step moves the vendored `node_modules/@chainlink/contracts` and `node_modules/@openzeppelin/contracts` into `node_modules/.ignored` before failing, breaking subsequent `forge build` commands until `node_modules/` is restored!

2. **Missing `lib/forge-std` and Unpopulated `devDependencies` (`MEDIUM`)**:
   - [`packages/contracts/remappings.txt:3`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/remappings.txt#L3) maps `forge-std/=lib/forge-std/src/`, but `lib/` does not exist in the repository.
   - `packages/contracts/package.json:27-35` declares `hardhat`, `@nomicfoundation/hardhat-ignition`, `@nomicfoundation/hardhat-toolbox-viem`, `solhint`, `typescript`, `tsx`, and `viem`, none of which are installed in the vendored `packages/contracts/node_modules/`.

---

### 4.6 Testing & Verification Evaluation (Assessment Area 10)

#### 4.6.1 Pristine Repository Testing Status (`CRITICAL` Gap)
We audited the pristine repository for unit tests, integration tests, fuzz tests, invariant tests, deployment scripts, and CI/CD configurations:
- **Finding**: **Zero test files exist in the frozen workspace.**
- Although [`packages/contracts/foundry.toml:3`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/foundry.toml#L3) configures `test = "test/foundry"`, [`packages/contracts/hardhat.config.ts:27`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/hardhat.config.ts#L27) configures `tests: "./test/hardhat"`, and [`packages/contracts/package.json:9-22`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/package.json#L9-L22) defines `test:foundry`, `test:hardhat`, `coverage` (`node ./scripts/check-coverage.mjs`), `gas`, `lint`, `slither` (`--config-file slither.config.json`), `deploy:local`, and `deploy:base-sepolia`, **every single referenced directory and file (`test/`, `script/`, `scripts/`, `ignition/`, `slither.config.json`, `.github/workflows/`) is missing from the repository**.
- Running `forge test` on the pristine copy (`scratch/tool-logs/package-scripts-direct-orig.log:67-71`) outputs:
  ```text
  Compiling 36 files with Solc 0.8.36
  Solc 0.8.36 finished in 488.13ms
  Compiler run successful!
  No tests found in project! Forge looks for functions that start with `test`
  ```

#### 4.6.2 Executable Verification Suite Built & Run in `scratch/contracts-compat/`
Rather than merely recommending tests, we authored and executed a self-contained Foundry unit, fuzz, and stateful invariant test suite ([`scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol)) and an Echidna 2.3.3 property-based fuzzing harness ([`scratch/contracts-compat/src/EchidnaRaffleHarness.sol`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/contracts-compat/src/EchidnaRaffleHarness.sol)):

1. **Foundry Unit, Fuzz & Stateful Invariant Execution (`scratch/tool-logs/forge-test-compat.log`)**:
   - **8 Unit & Property-Fuzz Tests (`RaffleGuidelinesTest`)**:
     - `test_ImplementationIsLockedAndRefundMode()` (`PASS`, gas: `55,979`)
     - `test_FullNftWonLifecycleAndAccounting()` (`PASS`, gas: `1,775,160`)
     - `test_FullCashWonLifecycleAndSponsorPrizeReturn()` (`PASS`, gas: `1,591,275`)
     - `test_RefundPathsAndBatching()` (`PASS`, gas: `2,211,338`)
     - `test_ReturnBombCallerRefundSucceeds()` (`PASS`, gas: `1,191,483`)
     - `test_BlacklistedSponsorRecipientLocksSponsorProceedsOnly()` (`PASS`, gas: `1,402,868`)
     - `test_TicketTransferAfterResolutionChangesWinnerRecipient()` (`PASS`, gas: `1,290,864`)
     - `testFuzz_SettlementConservationAndSelection(uint32,uint32,uint32,uint32,uint256)` (`PASS`, `runs: 1000`, `μ: 1,758,453`, `~: 1,758,491`)
   - **3 Stateful Invariant Tests (`RaffleInvariantTest`, 256 runs / 16,384 calls each)**:
     - `invariant_QuoteBalanceConservation()` (`PASS`, `runs: 256`, `calls: 16384`)
     - `invariant_PrizeCustodyAndClaims()` (`PASS`, `runs: 256`, `calls: 16384`)
     - `invariant_TerminalStateExclusivity()` (`PASS`, `runs: 256`, `calls: 16384`)
   - **Coverage Achieved on Owned Contracts (`scratch/tool-logs/forge-coverage-compat.log:6570-6582`)**:
     - `src/Raffle.sol`: **86.64% Lines (`214/247`)**, **85.96% Statements (`251/292`)**, **41.38% Branches (`24/58`)**, **70.97% Functions (`22/31`)**
     - `src/RaffleFactory.sol`: **77.05% Lines (`47/61`)**, **81.48% Statements (`66/81`)**, **16.67% Branches (`3/18`)**, **100.00% Functions (`4/4`)**

2. **Echidna 2.3.3 Property-Based Campaign (`scratch/tool-logs/echidna-compat-0.8.36.log`)**:
   - Command: `echidna . --contract EchidnaRaffleHarness --test-limit 5000 --format text`
   - Results (`5,126` calls, `8` contracts, `9,083` unique EVM instructions, `Seed: 7130925245847831512`):
     - `echidna_quote_conservation`: **passing**
     - `echidna_prize_custody_valid`: **passing**
     - `echidna_settlement_mutually_exclusive_with_refunding`: **passing**

---

### 4.7 Platform-Specific Guidance (Solidity / EVM) (Assessment Area 11)

1. **Solidity Compiler Version Assessment**:
   - All 5 owned files use a fixed, locked pragma: `pragma solidity 0.8.36;` (`Raffle.sol:2`, `RaffleFactory.sol:2`, `IRaffle.sol:2`, `IRaffleFactory.sol:2`, `RaffleConstants.sol:2`), matching `foundry.toml:7` (`solc_version = "0.8.36"`) and `hardhat.config.ts:15` (`version: "0.8.36"`).
   - **Guideline Note**: Trail of Bits' `ASSESSMENT_AREAS.md` notes that projects should lock pragmas in deployable contracts (satisfied) and ensure compatibility with static analysis/fuzzing tools. On this host, `solc 0.8.36` is installed in `~/Library/Application Support/svm/0.8.36/solc-0.8.36` and works natively with Foundry `1.7.1`, Slither `0.11.6`, `slither-check-upgradeability`, and Echidna `2.3.3`.
   - `evm_version = "cancun"` (`foundry.toml:8`) is appropriate for Base mainnet (`8453`) and Base Sepolia (`84532`), which support Cancun opcodes (`MCOPY`, `TSTORE`, `TLOAD`, `BLOBBASEFEE`).

2. **Compiler & Linter Warnings (`forge build`)**:
   - `solc 0.8.36` emits **0 compiler warnings**.
   - Foundry's built-in linter (`forge-lint`) emits **7 `warning[block-timestamp]` diagnostics** on `src/Raffle.sol` (`lines 216, 242, 245, 282, 287, 291, 512`; logged in `scratch/tool-logs/forge-build-orig.log:44-99`).
   - **Assessment**: On Base (OP Stack L2), `block.timestamp` advances in 2-second L2 block intervals anchored to L1 timestamps. Because the protocol's timeouts are measured in days (`DRAW_REQUEST_TIMEOUT = 1 days`, `DRAW_CALLBACK_TIMEOUT = 2 days`, `MAX_SALE_DURATION = 30 days`), second-level timestamp drift does not compromise the raffle state machine.

3. **Inline Assembly Audit (`Raffle.sol:266-268`)**:
   - Only one inline assembly block exists in owned contracts (`Raffle.requestDraw` at [`Raffle.sol:266-268`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L266-L268)):
     ```solidity
     assembly ("memory-safe") {
         success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
     }
     ```
   - **Memory-Safety Verification**: The `call` opcode reads 0 bytes from memory (`argsOffset = 0, argsSize = 0`) and writes 0 bytes to memory (`retOffset = 0, retSize = 0`), mutating only the stack variable `success`. Therefore, the `"memory-safe"` annotation is strictly sound and safe under both legacy and `via_ir = true` compilation pipelines.

4. **Naming Convention Diagnostics (Slither `naming-convention`)**:
   - Slither flags `IRaffle.ENTRY_PRICE()` (`src/interfaces/IRaffle.sol:396`) for using `UPPER_CASE` on a function name (`scratch/tool-logs/slither-owned-only.log:74`). This is intentional so that `uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;` in `Raffle.sol:69` implements the interface getter.

---

