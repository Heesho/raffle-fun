# Deliverable 4: Prioritized Recommendations — `raffle-fun`

## Phase 5 & Deliverable 4: Prioritized Recommendations & Path to Production

### CRITICAL Priority (Address Immediately Before Any Deployment)

#### 1. Restore the Missing Test Suite, Coverage Script, Slither Config, and Deployment Scripts in the Repository
- **Impact**: `packages/contracts` currently ships with **0 test files** (`test/foundry/` and `test/hardhat/` are absent), missing `lib/forge-std`, missing `scripts/check-coverage.mjs`, missing `slither.config.json`, and missing `script/` / `ignition/`. Every quality gate in `package.json` (`test`, `coverage`, `gas`, `lint`, `typecheck`, `slither`) fails out of the box (`scratch/tool-logs/package-scripts-orig.log`, `scratch/tool-logs/package-scripts-direct-orig.log`).
- **Actionable Fix**:
  1. Commit the Foundry unit, fuzz, and stateful invariant test suite (`scratch/contracts-compat/test/foundry/RaffleGuidelines.t.sol`) and Echidna property suite (`scratch/contracts-compat/src/EchidnaRaffleHarness.sol`) into `packages/contracts/test/foundry/`.
  2. Add `slither.config.json` with `"filter_paths": "node_modules|test"` so `pnpm run slither` analyzes owned contracts cleanly without failing on OpenZeppelin `Math.mulDiv` xor false positives (`scratch/tool-logs/package-scripts-direct-orig.log:908-941`).
  3. Restore `scripts/check-coverage.mjs` and CI workflow enforcement.

#### 2. Fix `pnpm-lock.yaml` `blockExoticSubdeps: true` Conflict with `@chainlink/contracts@1.5.0`
- **Impact**: Running `pnpm install` or any `pnpm run <script>` fails with `ERR_PNPM_EXOTIC_SUBDEP` on `@zksync/contracts` (`pnpm-lock.yaml:8`) and moves `node_modules/@chainlink/contracts` and `node_modules/@openzeppelin/contracts` into `node_modules/.ignored`, breaking compilation (`scratch/tool-logs/package-scripts-orig.log:3-16`).
- **Actionable Fix**:
  - Either allow or stub/exclude `@zksync/contracts` via `pnpm.overrides` / `packageExtensions` in the root `package.json`, or vendor the 4 Chainlink VRF interface/base files directly under `packages/contracts/lib/` so `pnpm` does not pull `@chainlink/contracts@1.5.0`'s transitive `@zksync/contracts` git dependency.

---

### HIGH Priority (Address Before Mainnet Launch)

#### 3. Prevent Permanent Lock of `sponsorProceeds` When `sponsorRecipient` is Blacklisted by USDC or Unpayable
- **Location**: [`Raffle.sol:198, 377-387`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L377-L387)
- **Impact**: Unlike ticket holders (who can transfer their ERC-721 ticket to an un-blacklisted address prior to calling `redeemWinningTicket` or `refundTickets`), `sponsorRecipient` is fixed at initialization (`Raffle.sol:198`). If `sponsorRecipient` is blacklisted by Circle (USDC) or is a contract that reverts on USDC receipt, `releaseSponsorProceeds()` permanently reverts and 95% (in `NftWon`) or 15% (in `CashWon`) of the USDC pot is permanently locked (`test_BlacklistedSponsorRecipientLocksSponsorProceedsOnly`).
- **Actionable Fix**:
  Add an overloaded `releaseSponsorProceedsTo(address alternateRecipient)` callable only by `sponsor` or `sponsorRecipient` (validated against `alternateRecipient != address(0)` and `!_isProtocolDestination(alternateRecipient, address(prizeToken))`), while keeping the permissionless `releaseSponsorProceeds()` sending to the default `sponsorRecipient`.

#### 4. Protect Ticket Buyers & Sellers Against Post-Draw / Mempool Ticket Transfer Front-Running
- **Location**: [`Raffle.sol:489-504`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L489-L504)
- **Impact**: Because `_update` allows ERC-721 ticket transfers in `Drawing`, `NftWon`, and `CashWon` states (`test_TicketTransferAfterResolutionChangesWinnerRecipient`), any ticket left listed on an NFT marketplace after `endTime` can be sniped by an MEV bot as soon as the Chainlink VRF fulfillment transaction is observed.
- **Actionable Fix**:
  Restrict non-mint/non-burn transfers in `Raffle._update` (`from != address(0) && to != address(0)`) when `status == Status.Drawing` (or after `endTime`), or require explicit opt-in transfer after resolution, and document marketplace listing expiration rules (`listing.expiration <= raffle.endTime()`) in `DESIGN.md` and `IRaffle.sol`.

---

### MEDIUM Priority (Address for Production Quality)

#### 5. Replace `VRFV2PlusWrapperConsumerBase` Inheritance with Direct `IVRFV2PlusWrapper` Integration
- **Location**: [`Raffle.sol:7, 65, 157`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L65) & `VRFV2PlusWrapperConsumerBase.sol:38, 50, 62-73, 113-120`
- **Impact**: Inheriting `VRFV2PlusWrapperConsumerBase` wastes storage slot 6 (`i_linkToken`, which is `address(0)` on all clones), forces the `Raffle` constructor to call `vrfWrapper_.link()` even though LINK billing is never used, calls `calculateRequestPriceNative` twice on every `requestDraw()`, and exposes undocumented `getBalance()` and `getLinkToken()` functions on every `Raffle` clone.
- **Actionable Fix**: Store `IVRFV2PlusWrapper public immutable override vrfWrapper;` directly in `Raffle` and implement `rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external` directly on `Raffle`.

#### 6. Store `raffleImplementation = address(this)` as an `immutable` in `Raffle` and Short-Circuit EOA Checks in `_isProtocolDestination`
- **Location**: [`Raffle.sol:593-605`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L593-L605)
- **Impact**: `_isProtocolDestination` currently makes an external `STATICCALL` to `canonicalFactory.raffleImplementation()` before checking `destination.code.length == 0`. Storing `address internal immutable _raffleImplementation = address(this);` in `Raffle.constructor` and checking `if (destination == address(this)) return true; if (destination.code.length == 0) return false;` first eliminates external calls to `RaffleFactory` for all EOA users and saves gas on `initialize`, `buyEntries`, ticket transfers, and payouts.

#### 7. Emit `RaffleInitialized` in `Raffle.initialize` and `FulfillmentIgnored` on Ignored VRF Callbacks
- **Location**: [`Raffle.sol:176-206, 509-515`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L176-L206)
- **Impact**: Resolves Slither's `events-maths` finding on `Raffle.initialize` and provides off-chain observability if a Chainlink VRF callback arrives after `callbackDeadline()`.

---

### LOW Priority (Best-Practice Polish)

#### 8. Complete Missing NatSpec Tags in `RaffleConstants.sol` and `Raffle.sol`
- **Location**: [`RaffleConstants.sol:10-42`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/libraries/RaffleConstants.sol#L10-L42), [`Raffle.sol:69-77, 478-487`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L69-L77)
- **Actionable Fix**: Add `@notice` comments to all 11 constants in `RaffleConstants.sol`, add `/// @inheritdoc IRaffle` to `ENTRY_PRICE`, `callbackGasLimit`, and `requestConfirmations` in `Raffle.sol`, and add `@return` tags to `Raffle.name()` and `Raffle.symbol()`.

#### 9. Pack `Raffle` Storage Variables (`reserveEntries` + `totalEntries`, `sponsor` + `endTime`)
- **Location**: [`Raffle.sol:85-106`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/packages/contracts/src/Raffle.sol#L85-L106)
- **Actionable Fix**: Pack `address sponsor` (20B) with `uint64 endTime` (8B) into a single 32-byte slot, and pack `uint128 reserveEntries` (16B) with `uint128 totalEntries` (16B) into a single 32-byte slot, reducing `Raffle`'s storage footprint by 1 slot and saving a cold `SSTORE` during `initialize()`.

---

### Clarifying Questions for the Engineering Team

1. **Post-Draw Ticket Transferability (`Raffle._update`)**: Is the ability to transfer ERC-721 tickets during `Status.Drawing` and after `RaffleResolved` (`Status.NftWon` / `Status.CashWon`) intentionally required so a blacklisted winner can transfer the winning ticket to an un-blacklisted recovery wallet, or should ticket transfers be frozen once `requestDraw()` is called (or once `RaffleResolved` is emitted) to prevent NFT marketplace sniping?
2. **Sponsor Recipient Recovery (`releaseSponsorProceeds`)**: Would you prefer adding an authenticated `updateSponsorRecipient(address newRecipient)` function callable by `sponsor`, or an overloaded `releaseSponsorProceeds(address recipient)` callable by `sponsor` / `sponsorRecipient`, to protect against USDC blacklisting or smart-contract wallet breakage?
3. **Prize Delivery Hook (`transferFrom` vs `safeTransferFrom`)**: `redeemWinningTicket` and `releaseSponsorPrize` use `prizeToken.transferFrom` + an `ownerOf` check rather than `safeTransferFrom`. Should `redeemWinningTicket` (which is always called by `msg.sender == winner`) offer an optional `safeRedeemWinningTicket` variant for smart-contract winners that require `onERC721Received` callbacks?

---

## Appendix: Preserved Raw Tool Logs & Verification Artifacts in `scratch/`

All raw tool outputs, DOT graphs, and executable verification harnesses are preserved in `scratch/`:
- [`scratch/tool-logs/pristine-inputs-sha256.txt`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/pristine-inputs-sha256.txt) — Baseline SHA-256 digests of all 43 pristine workspace files and 6 pinned skill files.
- [`scratch/tool-logs/forge-build-orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-build-orig.log) & [`scratch/tool-logs/forge-build-comparison.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-build-comparison.log) — `forge build --sizes` raw outputs for `default` (`via_ir = false`) and `comparison` (`via_ir = true`) profiles.
- [`scratch/tool-logs/slither-orig-0.8.36.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-orig-0.8.36.log) & [`scratch/tool-logs/slither-owned-only.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-owned-only.log) — Complete Slither 0.11.6 detector runs on `Solc 0.8.36`.
- [`scratch/tool-logs/slither-printers-summary.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-printers-summary.log) & [`scratch/tool-logs/slither-data-dependency.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-data-dependency.log) — Slither printer outputs (`contract-summary`, `function-summary`, `vars-and-auth`, `human-summary`, `require`, `loc`, `variable-order`, `constructor-calls`, `inheritance`, `data-dependency`).
- [`scratch/diagrams/slither/`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/diagrams/slither/inheritance-graph.dot) — 25 Slither-generated `.dot` inheritance and call graphs.
- [`scratch/tool-logs/forge-storage-layout-Raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-storage-layout-Raffle.log) & [`scratch/tool-logs/forge-storage-layout-RaffleFactory.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-storage-layout-RaffleFactory.log) — Complete storage layouts.
- [`scratch/tool-logs/slither-check-upgradeability-Raffle.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-check-upgradeability-Raffle.log) & [`scratch/tool-logs/slither-check-upgradeability-RaffleFactory.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/slither-check-upgradeability-RaffleFactory.log) — `slither-check-upgradeability` outputs.
- [`scratch/tool-logs/package-scripts-orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/package-scripts-orig.log) & [`scratch/tool-logs/package-scripts-direct-orig.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/package-scripts-direct-orig.log) — Raw outputs of all `package.json` scripts on the pristine copy.
- [`scratch/tool-logs/forge-test-compat.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-test-compat.log), [`scratch/tool-logs/forge-coverage-compat.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/forge-coverage-compat.log), & [`scratch/tool-logs/echidna-compat-0.8.36.log`](file:///Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/gemini-native-repairs/TOB/attempt-04/S4/work/scratch/tool-logs/echidna-compat-0.8.36.log) — Executable Foundry unit/fuzz/invariant and Echidna 2.3.3 fuzzing logs.
