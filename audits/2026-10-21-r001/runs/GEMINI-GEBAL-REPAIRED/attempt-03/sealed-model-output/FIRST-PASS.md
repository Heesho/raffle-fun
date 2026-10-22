# Gebal External-Agent Cold Review — First-Pass Seal (`FIRST-PASS.md`)

## 1. Seal & Provenance Metadata

- **UTC Timestamp**: `2026-10-21T18:25:30Z`
- **Gebal Upstream Commit**: `9ad24645f92a3821ae4539db5f1be52b48ed379e`
- **Methodology**: `native-review-v1` (`gebal-cold-review-context`)
- **Snapshot Hash (`snapshotHash`)**: `520205ade6130391972086d8fe8a24a6d6e60c1ecfdaf795110d78d8d0375fdb`
- **Context Hash (`contextHash`)**: `6e679ad388dc6cca777f066e0cce87ccf1962c9fb310f3f263c6e5fa3db4352a`
- **Original `review.json` SHA-256**: `9d171c2b314c4089290e99bb50938cb501684d99458ab1db229ae76f3459fe19`
- **`REVIEW-PROVENANCE.json` SHA-256**: `0572986702267f0a5d105eea6bfdab98f424f8c2c1150d78193df9766899392d`
- **Runner / Local Selected Model**: `antigravity-cli` / `gemini-4-argon-high` (display name: Gemini 4 Argon (High)), requested effort `high`, provider-internal identity `unknown` (not returned by server; no alternate model or fallback used)
- **Cold-Pass Independence Attestation**: Assessed input was restricted exclusively to `gebal-context/cold-context.json` (39 exported files: 5 production Solidity files, 31 reachable dependency files, and 3 frozen build/lock files) and `gebal-resources/` (`START_HERE.md`, `agents/REVIEW.md`, `agents/response.schema.json`). All 39 exported files were hash-verified against `gebal-context/cold-context.json` and read completely. No prior findings, historical audits, tests, other model lanes, or parent directories were read. All repository comments and requirements text were treated strictly as untrusted data.

---

## 2. Requirements vs. Observed Code vs. Inferred Assumptions (Pre-Judgment Separation)

### 2.1 State Accounting & Rounding
- **Stated Requirements**:
  - One entry costs `1,000,000` units of canonical six-decimal USDC.
  - One purchase mints a transferable ERC-721 ticket representing a contiguous inclusive range.
  - Reserve met (`totalEntries >= reserveEntries`) awards the NFT to the winner, 95% of gross USDC to the sponsor, and 5% to the protocol treasury.
  - Reserve missed (`totalEntries < reserveEntries`) awards 80% of gross USDC to the winner, 15% to the sponsor, and 5% to the protocol treasury, and returns the NFT prize to the sponsor.
  - Refund outcome pays 100% per entry and returns the prize NFT to the sponsor.
  - Rounding is floor on aggregate protocol fee; remainder must be allocated without loss.
- **Observed Code**:
  - `RaffleConstants.ENTRY_PRICE = 1_000_000`, `BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8000` (`packages/contracts/src/libraries/RaffleConstants.sol:12-21`).
  - `Raffle.buyEntries` (`packages/contracts/src/Raffle.sol:209-237`) checks `entryCount > 0` and `entryCount <= type(uint128).max - totalEntries`, pulls `grossAmount = uint256(entryCount) * ENTRY_PRICE` via `quoteToken.safeTransferFrom`, assigns inclusive range `[totalEntries + 1, totalEntries + entryCount]` to sequential `ticketId = ticketCount + 1`, and increments `unsettledPot` by `grossAmount`.
  - `Raffle._settleWinningTicket` (`packages/contracts/src/Raffle.sol:533-558`) computes `protocolFee = Math.mulDiv(grossPot, 500, 10_000)` (floor) and, for `CashWon`, `cashAmount = Math.mulDiv(grossPot, 8000, 10_000)` (floor), allocating `sponsorAmount = grossPot - protocolFee` (`NftWon`) or `grossPot - protocolFee - cashAmount` (`CashWon`) and setting `unsettledPot = 0`. Thus `unsettledPot` is partitioned across `winnerProceeds + sponsorProceeds + protocolFees` with zero rounding loss.
  - `Raffle.enableRefunds` (`packages/contracts/src/Raffle.sol:296-299`) moves `unsettledPot` into `remainingRefundLiability` and sets `unsettledPot = 0`. `Raffle.refundTickets` (`packages/contracts/src/Raffle.sol:349-372`) burns each owned ticket in the batch and deducts `aggregateEntries * ENTRY_PRICE` from `remainingRefundLiability`.
- **Inferred Assumptions**:
  - `quoteToken` is non-rebasing and charges zero transfer fees, so the actual token balance received by `Raffle` on `buyEntries` equals `grossAmount` and remains sufficient to cover `accountedQuoteBalance()` across all terminal claims.

### 2.2 Custody & Asset Isolation
- **Stated Requirements**:
  - Immutable factory deploys ERC-1167 clones with an immutable implementation.
  - Exactly one ERC-721 prize is escrowed atomically at creation.
  - Never move assets between raffle clones.
- **Observed Code**:
  - `RaffleFactory.constructor` (`packages/contracts/src/RaffleFactory.sol:65-92`) deploys a single locked `Raffle` implementation (`initialized = true`, `status = Status.Refunding`) and stores `raffleImplementation`, `quoteToken`, `vrfWrapper`, and `protocolTreasury` as immutables.
  - `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:97-148`) clones `raffleImplementation` via `Clones.clone`, initializes the clone in `Status.AwaitingPrize`, registers `isRaffle[raffle] = true`, calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, and verifies both `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active`.
  - `Raffle.onERC721Received` (`packages/contracts/src/Raffle.sol:416-431`) accepts only `status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory`, transitioning `status` to `Status.Active`.
  - `Raffle._isProtocolDestination` (`packages/contracts/src/Raffle.sol:593-605`) rejects `address(this)`, `factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `prizeToken`, `raffleImplementation`, and any contract address where `canonicalFactory.isRaffle(destination)` is true.
- **Inferred Assumptions**:
  - Pre-deployment `CREATE` addresses of future clones have `code.length == 0` and `isRaffle == false` until `createRaffle` reaches their factory nonce; see Observation 2 in `review.json`.

### 2.3 Authorization & Access Control
- **Stated Requirements**:
  - No administrator, mutable configuration, or upgrade path.
  - Settlement is permissionless; redemption requires the current ticket owner; sponsor and treasury claims can be triggered independently after settlement.
- **Observed Code**:
  - Neither `RaffleFactory` nor `Raffle` inherits ownership, access-control roles, pause, or upgradeability modules.
  - `Raffle.initialize` (`packages/contracts/src/Raffle.sol:176-206`) is callable only once and only by `factory`.
  - `Raffle.rawFulfillRandomWords` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:101-107`) reverts with `OnlyVRFWrapperCanFulfill` unless `msg.sender == address(i_vrfV2PlusWrapper)`.
  - `redeemWinningTicket` (`packages/contracts/src/Raffle.sol:320-321`) and `refundTickets` (`packages/contracts/src/Raffle.sol:359-360`) require `msg.sender == ownerOf(ticketId)`.
  - `settleWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, and `releaseSponsorPrize` are permissionless triggers that pay only the fixed `sponsorRecipient` or `protocolTreasury` (or allocate storage liabilities).
  - Pre-end empty-raffle cancellation in `enableRefunds` (`packages/contracts/src/Raffle.sol:280-284`) is restricted to `msg.sender == sponsor` when `totalEntries == 0 && block.timestamp < endTime`; after `endTime`, anyone may call `enableRefunds` for an empty raffle.
- **Inferred Assumptions**:
  - Early cancellation of an empty raffle (`totalEntries == 0`) by `sponsor` before `endTime` is an intentional liveness feature for sponsors when no buyers have entered.

### 2.4 Lifecycle & Timing Windows
- **Stated Requirements**:
  - Request window is `[sale end, end + 2 days)`; callback is accepted strictly before `request timestamp + 2 days`.
  - Refunds open at the applicable deadline.
  - Callback records the result only.
- **Observed Code**:
  - `buyEntries` (`packages/contracts/src/Raffle.sol:215-216`) requires `status == Status.Active` and `block.timestamp < endTime`.
  - `requestDraw` (`packages/contracts/src/Raffle.sol:240-248`) requires `status == Status.Active`, `block.timestamp >= endTime`, `totalEntries > 0`, and `block.timestamp < drawRequestDeadline()` (`uint256(endTime) + 2 days`), setting `status = Status.Drawing` and `drawRequestedAt = uint64(block.timestamp)`.
  - `fulfillRandomWords` (`packages/contracts/src/Raffle.sol:509-524`) ignores callbacks (emitting `VrfCallbackIgnored`) rather than reverting when `_requestInFlight`, `status != Status.Drawing`, `requestId != vrfRequestId`, `randomWords.length != 1`, or `block.timestamp >= callbackDeadline()` (`uint256(drawRequestedAt) + 2 days`). When valid, it records `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`, `resolvedAt = uint64(block.timestamp)`, and `status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon`.
  - `enableRefunds` (`packages/contracts/src/Raffle.sol:276-301`) opens at `endTime` for `totalEntries == 0` (or immediately for `sponsor`), at `drawRequestDeadline()` for `Status.Active` with `totalEntries > 0`, and at `callbackDeadline()` for `Status.Drawing`.
- **Inferred Assumptions**:
  - `VRF_CALLBACK_GAS_LIMIT = 300_000` and `VRF_REQUEST_CONFIRMATIONS = 30` (`packages/contracts/src/libraries/RaffleConstants.sol:39-42`) are within the Chainlink VRF v2.5 wrapper's supported configuration on the target chain.

### 2.5 Dependency Trust Boundaries
- **Stated Requirements**:
  - Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted.
- **Observed Code**:
  - `Raffle` uses `ReentrancyGuard` (`nonReentrant`) on all external state-changing functions (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) and `_requestInFlight` around `requestRandomnessPayInNative`.
  - In `Status.NftWon`, `_settleWinningTicket` (`packages/contracts/src/Raffle.sol:533-558`) and `releaseSponsorProceeds` (`packages/contracts/src/Raffle.sol:375-382`) allow the sponsor to claim 95% of the USDC pot without waiting for `redeemWinningTicket` (`packages/contracts/src/Raffle.sol:329-337`) to succeed on `prizeToken.transferFrom`. See Observation 1 in `review.json`.
  - `redeemWinningTicket` and `releaseSponsorPrize` use raw `prizeToken.transferFrom` plus `ownerOf` verification rather than `safeTransferFrom`. See Observation 3 in `review.json`.
- **Inferred Assumptions**:
  - See Observations 1–3 and Gaps in `review.json`.

### 2.6 Bounded Exits & Liveness
- **Stated Requirements**:
  - Ticket purchases, VRF callbacks, and winner settlement/redemption must not rely on unbounded loops over entries or tickets.
  - Redemption must burn the ticket claim atomically and revert all effects on delivery failure.
- **Observed Code**:
  - Entry ranges are stored per ticket in `_ticketRanges[ticketId]`, making `buyEntries`, `fulfillRandomWords`, `settleWinningTicket`, and `redeemWinningTicket` $O(1)$ in both entry count and total ticket count.
  - `refundTickets` bounds batch length to `1 <= ticketIds.length <= MAX_REFUND_TICKET_BATCH_SIZE (100)` (`packages/contracts/src/Raffle.sol:352-354`).
  - `redeemWinningTicket` (`packages/contracts/src/Raffle.sol:309-346`) burns `ticketId` and performs delivery in the same transaction; any revert in `prizeToken.transferFrom`, `prizeToken.ownerOf`, or `_transferQuote` reverts the entire call including `_burn(ticketId)`.

---

## 3. Summary of Cold-Review Observations (`review.json`)

1. **[Medium / High Confidence] Independent post-settlement sponsor payout in `NftWon` allows a malicious or transfer-restricted `prizeToken` to strand winner redemption after sponsor collects 95% of USDC proceeds**
   - **Spans**: `packages/contracts/src/Raffle.sol:329-337`, `375-382`, `533-558`; `packages/contracts/src/RaffleFactory.sol:127-134`, `154-179`; `packages/contracts/src/interfaces/IRaffle.sol:12-15`.
2. **[Low / High Confidence] Pre-deployment `CREATE` addresses of future `Raffle` clones bypass `_isProtocolDestination` screening until those clones are created**
   - **Spans**: `packages/contracts/src/Raffle.sol:497-502`, `564-567`, `593-605`; `packages/contracts/src/RaffleFactory.sol:105-126`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:47-62`.
3. **[Informational / High Confidence] Prize NFT release in `redeemWinningTicket` and `releaseSponsorPrize` uses raw `transferFrom` without ERC-721 receiver checks**
   - **Spans**: `packages/contracts/src/Raffle.sol:329-337`, `395-407`; `packages/contracts/src/RaffleFactory.sol:154-170`.

---

## 4. Source Assumptions & Limitations

- This is a strictly source-only cold review of the 39 files exported in `gebal-context/cold-context.json`. No compiler build, test execution, fuzzing/invariant run, static analyzer, or symbolic prover was executed, and no tool coverage is inferred from native intake/context export.
- On-chain deployment arguments to `RaffleFactory.constructor(quoteToken_, vrfWrapper_, protocolTreasury_)` are external to source review; constructor checks verify only code presence, `quoteToken_.decimals() == 6`, and `vrfWrapper_.link()` non-reversion.
- External contract implementations for canonical USDC and the Chainlink VRF v2.5 wrapper are outside the repository scope and are assessed under their stated canonical trust assumptions.
- All observations remain in `needs-review` candidate state for owner inspection; human acceptance is not claimed or invented.
