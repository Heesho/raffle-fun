# Stage 3: Token Integration Analysis Report (`token-integration-analyzer`)

**Project:** `raffle.fun` (`Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`)  
**Tokens Analyzed:**
1. **Internal Token Implementation:** `Raffle.sol` ERC-721 Range Ticket (`raffle.fun Ticket` / `RAFFLE`)
2. **External ERC-20 Integration:** `quoteToken` (Immutable canonical 6-decimal USDC)
3. **External ERC-721 Integration:** `prizeToken` (Arbitrary sponsor-supplied ERC-721 prize per raffle clone)
4. **External VRF / Native Integration:** Native currency (`ETH`) & Chainlink `VRFV2PlusWrapper` (`i_linkToken`)

**Platform:** Solidity `0.8.36` (EVM target `cancun`, OpenZeppelin Contracts v5.5.0 / v5.6.0)

---

## Executive Summary

`raffle.fun` both **implements** an ERC-721 bearer-claim ticket token (`Raffle.sol`) and **integrates** with two external token classes: an immutable ERC-20 `quoteToken` (canonical 6-decimal USDC) and arbitrary sponsor-configured ERC-721 `prizeToken` contracts.

Overall, the token architecture demonstrates strong defensive engineering:
- **ERC-721 Ticket Implementation (`Raffle.sol`):** Uses OpenZeppelin v5.6.0 `ERC721` with `pure` overrides for `name()` and `symbol()` (preventing empty metadata in ERC-1167 clones), sequential 1-based `ticketId` minting via `_safeMint`, O(1) inclusive `[firstEntry, lastEntry]` range storage that persists after burns for historical reconstruction, and `_update` destination screening against protocol plumbing.
- **ERC-20 `quoteToken` Integration:** Validates contract code and `decimals() == 6` at factory construction, wraps all transfers in `SafeERC20`, uses internal liability accounting (`unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`) rather than `balanceOf(address(this))`, and isolates terminal claims into independent pull-payment functions so a USDC blocklist on one participant does not freeze other participants' claims. Furthermore, USDC-blacklisted ticket holders can transfer their bearer ERC-721 tickets to an unblacklisted address before redeeming or refunding.
- **ERC-721 `prizeToken` Integration:** Enforces atomic escrow during `createRaffle` via `safeTransferFrom` paired with a strict `onERC721Received` state transition (`AwaitingPrize -> Active`) and post-transfer `ownerOf` verification, and uses `transferFrom` + `ownerOf` verification on outbound prize delivery.

### Key Token Integration Findings & Risks Identified

| ID | Severity | Category | Title | Location |
|---|---|---|---|---|
| **TIA-01** | **Medium** | Arbitrary ERC-721 Integration / Economic Rug Vector | Unallowlisted `prizeToken` + decoupled `releaseSponsorProceeds` allows a malicious sponsor with a trap/pausable ERC-721 to claim 95% of USDC sales while blocking `NftWon` prize redemption | `RaffleFactory.sol:154-179`, `Raffle.sol:309-346, 375-382, 533-558` |
| **TIA-02** | **Low** | Protocol Destination Screening / Asset Isolation | `releaseSponsorPrize()` and `redeemWinningTicket()` (`NftWon`) omit runtime `_isProtocolDestination` checks, allowing an ERC-721 prize to be transferred into a later-deployed `Raffle` clone at a precomputed `CREATE` address | `Raffle.sol:193-206, 329-337, 395-407, 497-502, 564-567, 593-605` |
| **TIA-03** | **Low** | Weird ERC-20 (Blocklists) | Fixed `sponsorRecipient` and `protocolTreasury` have no fallback or recipient rotation if blacklisted by canonical USDC, permanently stranding their allocated USDC proceeds | `Raffle.sol:198-199, 375-392`, `RaffleFactory.sol:87` |
| **TIA-04** | **Informational** | Arbitrary ERC-721 Reentrancy / Event Ordering | Untrusted `prizeToken.safeTransferFrom` in `createRaffle` executes after `onERC721Received` sets `Status.Active` but before `RaffleCreated` is emitted, allowing `prizeToken` to call `buyEntries` and invert `TicketPurchased` / `RaffleCreated` event ordering | `RaffleFactory.sol:127-147`, `Raffle.sol:416-431` |
| **TIA-05** | **Informational** | ERC-721 / ERC-165 Conformity | `Raffle.sol` implements `IERC721Receiver` and `IRaffle` without advertising `type(IERC721Receiver).interfaceId` in `supportsInterface`, and `tokenURI()` always returns `""` | `Raffle.sol:28, 416-431`, `ERC721.sol:43-48, 74-88` |

---

## 1. General Considerations

- **Security Model & Trust Assumptions (`DESIGN.md:4-7`):**
  - `quoteToken` (canonical 6-decimal USDC) and `vrfWrapper` (Chainlink VRF v2.5 native direct-funding wrapper) are explicitly modeled as trusted canonical dependencies.
  - `prizeToken` (arbitrary ERC-721 contracts supplied by sponsors) and ticket recipients are explicitly modeled as untrusted.
  - Contracts are immutable and ownerless (`RaffleFactory` has no owner/admin; each `Raffle` is an ERC-1167 minimal proxy clone with no admin, pause, upgrade, or token rescue path).

---

## 2. Contract Composition

### Complexity & Structure
- **`Raffle.sol` (614 lines):** Combines the ERC-721 ticket implementation, prize NFT escrow receiver, VRF v2.5 consumer, and USDC pot/settlement/refund accounting in a single cloneable implementation contract.
- **`RaffleFactory.sol` (186 lines):** Minimal clone factory validating configuration parameters, deploying ERC-1167 clones via `Clones.clone`, initializing them, and atomically escrowing the prize NFT.
- **`RaffleConstants.sol` (43 lines):** Centralizes basis-point rates (`BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8000`), `ENTRY_PRICE = 1_000_000`, `QUOTE_TOKEN_DECIMALS = 6`, batch limits (`MAX_REFUND_TICKET_BATCH_SIZE = 100`), and timeouts (`30 days` max sale, `2 days` draw request, `2 days` callback).

### SafeMath & Arithmetic Safety
- Compiled with Solidity `0.8.36` (built-in overflow/underflow checks).
- No `unchecked` blocks exist in `Raffle.sol` or `RaffleFactory.sol`.
- Entry counts are bounded to `uint128` (`Raffle.sol:219-221`: `if (entryCount > type(uint128).max - totalEntries) revert TotalEntriesOverflow(totalEntries, entryCount)`), guaranteeing `uint256(entryCount) * ENTRY_PRICE` and `uint256(totalEntries) * ENTRY_PRICE` can never overflow `uint256`.
- Fee and payout calculations use `Math.mulDiv` (`Raffle.sol:540, 546`), preventing intermediate multiplication overflow and rounding down deterministically.

### Non-Token Functions & Single Address Entry Point
- Each `Raffle` clone is a standalone ERC-721 collection (`raffle.fun Ticket` / `RAFFLE`) with a single address entry point.
- The implementation contract (`raffleImplementation`) is locked in its constructor (`initialized = true; status = Status.Refunding;` at `Raffle.sol:164-165`), preventing direct initialization or ticket minting on the implementation address.

---

## 3. Owner Privileges

### Internal Token (`Raffle.sol` Ticket ERC-721)
- **Upgradeability:** None. Uses fixed-target ERC-1167 minimal proxies (`Clones.clone(raffleImplementation)` at `RaffleFactory.sol:106`).
- **Minting:** Strictly algorithmic inside `buyEntries` (`Raffle.sol:209-237`). Requires `status == Status.Active`, `block.timestamp < endTime`, and payment of `entryCount * 1,000,000` raw `quoteToken` units. Neither the sponsor nor the factory can mint free tickets.
- **Pausability / Blacklisting:** None on the `Raffle` contract itself. Tickets remain freely transferable across all raffle lifecycle states (`Raffle.sol:497-502`), except to addresses flagged by `_isProtocolDestination`.
- **Sponsor Privileges:** The `sponsor` has only one special privilege after creation: calling `enableRefunds()` prior to `endTime` if and only if `totalEntries == 0` (`Raffle.sol:280-284`). Once at least one entry is sold (`totalEntries > 0`), the sponsor cannot cancel the raffle early.

### External Token (`quoteToken` — Canonical USDC)
- Canonical USDC (`FiatTokenV2_2`) is **upgradeable** (via Circle's `FiatTokenProxy`), **pausable** (`Pauser` role), and has **address blacklisting** (`Blacklister` role). These centralized privileges of Circle directly impact raffle operations and are evaluated in Detail in Section 7 and Section 8.

### External Token (`prizeToken` — Arbitrary ERC-721)
- Because `RaffleFactory.createRaffle` is permissionless and accepts any contract reporting `supportsInterface(type(IERC721).interfaceId)` (`RaffleFactory.sol:171-177`), `prizeToken` may have arbitrary owner privileges (upgradeability, pausability, blacklisting, soulbound switches, admin burn/clawback, or malicious transfer logic). See **TIA-01**.

---

## 4. Part A: `Raffle.sol` ERC-721 Ticket Implementation Analysis (Categories 9 & 10)

### 4.1 ERC-721 Conformity Checklist (`Raffle.sol`)

| Check | Status | Code Evidence & Technical Details |
|---|---|---|
| Transfers to `0x0` revert | **PASS** | Inherited `ERC721.transferFrom` (`ERC721.sol:113-115`) reverts with `ERC721InvalidReceiver(address(0))`. `buyEntries` also explicitly reverts with `InvalidRecipient()` on `recipient == address(0)` (`Raffle.sol:217`). |
| `safeTransferFrom` implemented | **PASS** | Inherited from OpenZeppelin `ERC721.sol:125-133`, invoking `ERC721Utils.checkOnERC721Received`. |
| `name()` and `symbol()` present & clone-safe | **PASS** | Overridden as `pure` functions returning `"raffle.fun Ticket"` and `"RAFFLE"` (`Raffle.sol:479-487`), avoiding uninitialized storage slots in ERC-1167 clones after `ERC721("", "")` in the implementation constructor (`Raffle.sol:156`). |
| `tokenURI(uint256)` behavior | **NOTE** | Inherited from `ERC721.sol:74-80`. Reverts with `ERC721NonexistentToken(tokenId)` for unminted/burned tickets, and returns `""` (empty string) for all owned tickets because `_baseURI()` is not overridden (`TIA-05`). |
| `ownerOf(uint256)` reverts for invalid/burned tokens | **PASS** | Inherited `ERC721.ownerOf` calls `_requireOwned(tokenId)` (`ERC721.sol:59-61, 424-430`), reverting with `ERC721NonexistentToken(tokenId)` when `_owners[tokenId] == address(0)`. |
| Transfers clear single-token approvals | **PASS** | `ERC721._update` clears `_tokenApprovals[tokenId]` via `_approve(address(0), tokenId, address(0), false)` whenever `from != address(0)` (`ERC721.sol:222-225`). |
| Burning clears single-token approvals | **PASS** | `redeemWinningTicket` (`Raffle.sol:325`) and `refundTickets` (`Raffle.sol:364`) call `_burn(ticketId)`, which invokes `_update(address(0), ticketId, address(0))`, clearing `_tokenApprovals[tokenId]` and decrementing `_balances[from]` (`ERC721.sol:222-239, 301-306`). |
| Token IDs immutable during lifetime | **PASS** | Sequential 1-based `ticketId = uint256(ticketCount) + 1` assigned once at mint (`Raffle.sol:228-235`). |
| Safe minting to smart contracts | **PASS** | `buyEntries` uses `_safeMint(recipient, ticketId)` (`Raffle.sol:235`), verifying `onERC721Received` when `recipient.code.length > 0`. |
| `onERC721Received` callback reentrancy protected | **PASS** | `buyEntries` is `nonReentrant` (`Raffle.sol:212`) and updates `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` *before* calling `_safeMint(recipient, ticketId)` (`Raffle.sol:226-235`). |

### 4.2 Ticket Range Persistence, Redemption, and Batch Refund Mechanics
1. **Sequential Range Accounting (`Raffle.sol:226-232, 451-455`):**
   - Each ticket `ticketId` maps to `TicketRange({ firstEntry, lastEntry })` where `firstEntry = totalEntries + 1` and `lastEntry = totalEntries + entryCount`.
   - Ranges are contiguous, non-overlapping, and cover `[1, totalEntries]` without gaps.
   - When `_burn(ticketId)` is called during `redeemWinningTicket` (`Raffle.sol:325`) or `refundTickets` (`Raffle.sol:364`), `_ticketRanges[ticketId]` is preserved in storage (`Raffle.sol:139`). Note that `ticketRange(ticketId)` does not call `_requireOwned(ticketId)`, which is documented and intentional so historical entry coverage can be reconstructed after burns (`IRaffle.sol:369`).
2. **Duplicate Ticket ID Prevention in `refundTickets` (`Raffle.sol:348-372`):**
   - `refundTickets` accepts `1 <= ticketIds.length <= 100` (`RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE`).
   - Inside the `for` loop, `address owner = ownerOf(ticketId)` is checked and `_burn(ticketId)` is executed immediately (`Raffle.sol:359-364`).
   - Because `_burn(ticketId)` zeroes `_owners[ticketId]` in the same iteration, supplying duplicate `ticketId` values in `ticketIds[]` causes `ownerOf(ticketId)` on the duplicate entry to revert immediately with `ERC721NonexistentToken(ticketId)`. Double-refunding within a batch or across transactions is impossible.
3. **Strict Owner Requirement vs. Approved Operators (`Raffle.sol:320-321, 359-360`):**
   - Both `redeemWinningTicket` and `refundTickets` check `if (msg.sender != owner) revert NotTicketOwner(...)` rather than `_isAuthorized(owner, msg.sender, ticketId)`.
   - Approved ERC-721 operators (`approve` / `setApprovalForAll`) cannot burn a ticket on behalf of the owner; an operator would have to transfer the ticket first.
4. **Secondary Market Transferability After Settlement (`Raffle.sol:304-346, 497-502`):**
   - `settleWinningTicket(ticketId)` is permissionless and does not read `ownerOf(ticketId)` or lock transfers.
   - `redeemWinningTicket(ticketId)` pays the current `ownerOf(ticketId)` at the moment of redemption (`Raffle.sol:320`).
   - Note for secondary market buyers: if a winning ticket is traded on an NFT marketplace after resolution (`NftWon` / `CashWon`), the seller could front-run a pending marketplace purchase with `redeemWinningTicket(ticketId)`. Because `redeemWinningTicket` burns `ticketId`, the marketplace's subsequent `transferFrom` will revert with `ERC721NonexistentToken(ticketId)`, protecting the buyer from paying for an already-redeemed ticket.

---

## 5. Part B: External ERC-20 `quoteToken` Integration Analysis (Categories 4, 5, 7, 8)

### 5.1 Weird ERC-20 Checklist Evaluation for `quoteToken` (Canonical 6-Decimal USDC)

| # | Weird ERC-20 Pattern | Relevance to `quoteToken` | Risk / Handling in `raffle.fun` | Code Evidence |
|---|---|---|---|---|
| 7.1 | **Reentrant Calls (ERC-777 / Transfer Hooks)** | Canonical USDC has no transfer hooks; if deployed with a hook token, all state-changing entry points have `nonReentrant` and follow CEI (except `buyEntries` pulls `quoteToken` before minting, protected by `nonReentrant`). | **Mitigated** (`nonReentrant` on all state-mutating functions). | `Raffle.sol:212, 224, 309, 348, 375, 385` |
| 7.2 | **Missing Return Values (USDT, BNB, OMG)** | Canonical USDC returns `bool`; wrapped in OpenZeppelin `SafeERC20` which handles missing return data and `false` returns. | **Mitigated** (`SafeERC20.safeTransfer` / `safeTransferFrom`). | `Raffle.sol:29, 224, 566` |
| 7.3 | **Fee on Transfer (Deflationary / Future Fees)** | Canonical USDC is fee-free. `buyEntries` adds `grossAmount` directly to `unsettledPot` without checking `balanceAfter - balanceBefore`. If a fee-on-transfer token were used, `accountedQuoteBalance()` would exceed actual balance and cause late claims to revert. | **Trust Assumption** (explicitly documented in `IRaffle.sol:14` and `Raffle.sol:561`). | `Raffle.sol:223-233, 560-567` |
| 7.4 | **Balance Modifications Outside Transfers (Rebasing / Direct Transfers)** | `Raffle.sol` never reads `quoteToken.balanceOf(address(this))`. All accounting uses internal state variables (`unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`). Direct USDC transfers to a `Raffle` clone cannot break accounting (excess tokens are simply unclaimable). | **Mitigated** for direct transfers; rebasing negative tokens unsupported by design. | `Raffle.sol:233, 296-298, 468-470, 539-555` |
| 7.5 | **Upgradeable Tokens (USDC Proxy)** | Canonical USDC is an upgradeable proxy (`FiatTokenProxy`). `RaffleFactory` and `Raffle` hold an immutable reference to the proxy address. | **Accepted Dependency Risk** | `RaffleFactory.sol:33, 85`, `Raffle.sol:58, 162` |
| 7.6 | **Flash Mintable** | Even if `quoteToken` were flash-borrowed/minted to buy a huge number of entries in `buyEntries`, the buyer must leave the USDC escrowed in `Raffle` across transactions until after `endTime` and VRF callback fulfillment (`30` confirmations). Flash loans cannot span multiple blocks. | **Not Exploitable** | `Raffle.sol:216, 242`, `RaffleConstants.sol:42` |
| 7.7 | **Blocklists (USDC `isBlacklisted`)** | Canonical USDC can blacklist addresses. Pull-payment isolation prevents one blacklisted user from blocking others, and blacklisted ticket owners can transfer their ERC-721 ticket to an unblacklisted address. **However, `sponsorRecipient` and `protocolTreasury` are immutable per raffle with no fallback recipient (see TIA-03).** | **Partially Mitigated (Low Risk — TIA-03)** | `Raffle.sol:309-392, 497-502, 533-558` |
| 7.8 | **Pausable Tokens (USDC `whenNotPaused`)** | Canonical USDC can be paused by Circle. Crucially, `requestDraw()`, `rawFulfillRandomWords()`, `enableRefunds()`, and `settleWinningTicket()` perform **no `quoteToken` calls**, so time-sensitive liveness windows (`drawRequestDeadline`, `callbackDeadline`) are completely unaffected by a USDC pause! Claims have no deadline and can execute once USDC is unpaused. | **Well Mitigated** | `Raffle.sol:240-306, 509-558` |
| 7.9 | **Approval Race Protections** | `Raffle` never calls `quoteToken.approve(...)`. Buyers approve the individual `Raffle` clone externally. | **Not Applicable** | `Raffle.sol:224` |
| 7.10 | **Revert on Approval to Zero Address** | `Raffle` never calls `approve`. | **Not Applicable** | N/A |
| 7.11 | **Revert on Zero Value Approvals** | `Raffle` never calls `approve`. | **Not Applicable** | N/A |
| 7.12 | **Revert on Zero Value Transfers** | All 5 `quoteToken` transfer paths strictly forbid `0` amounts: `buyEntries` reverts on `entryCount == 0` (`grossAmount >= 1e6`); `redeemWinningTicket` reverts on `cashAmount == 0`; `refundTickets` requires `ticketIds.length >= 1` (`amount >= 1e6`); `releaseSponsorProceeds` and `releaseProtocolFees` revert when `amount == 0`. | **Fully Mitigated** | `Raffle.sol:218, 340, 352, 367, 377, 387` |
| 7.13 | **Multiple Token Addresses** | Single canonical USDC address verified at deployment and stored as `immutable`. | **Mitigated** | `RaffleFactory.sol:33, 85`, `Raffle.sol:58` |
| 7.14 | **Low Decimals (6 Decimals)** | `RaffleFactory` constructor enforces `IERC20Metadata(quoteToken_).decimals() == 6` (`RaffleFactory.sol:70-78`). Because `ENTRY_PRICE = 1_000_000` (`1e6`) is an exact multiple of `BPS = 10_000` (`1e4`), `Math.mulDiv(grossPot, 500, 10_000)` and `Math.mulDiv(grossPot, 8000, 10_000)` never lose precision or create rounding dust, and `sponsorAmount` absorbs the exact remainder. | **Fully Mitigated** | `RaffleFactory.sol:70-78`, `RaffleConstants.sol:12-24`, `Raffle.sol:540-547` |
| 7.15 | **High Decimals** | Rejected by `quoteDecimals != 6` check in `RaffleFactory` constructor. | **Mitigated** | `RaffleFactory.sol:76-78` |
| 7.16 | **`transferFrom` with `src == msg.sender`** | `buyEntries` calls `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` where `Raffle` is `msg.sender` to `quoteToken`, and the buyer is `from`. Standard ERC-20 allowance is spent. | **Mitigated** | `Raffle.sol:224` |
| 7.17 | **Non-string Metadata (`bytes32`)** | Neither `RaffleFactory` nor `Raffle` calls `quoteToken.name()` or `quoteToken.symbol()`. Only `decimals()` is called in `RaffleFactory` constructor. | **Mitigated** | `RaffleFactory.sol:71` |
| 7.18 | **Revert on Transfer to Zero Address** | `recipient`, `sponsorRecipient`, `protocolTreasury`, and `winner` (via `ownerOf`) can never be `address(0)`. | **Mitigated** | `Raffle.sol:181-186, 217, 320, 359` |
| 7.19 | **No Revert on Failure (Returns `false`)** | Handled by OpenZeppelin `SafeERC20` which checks return value and reverts with `SafeERC20FailedOperation`. | **Mitigated** | `Raffle.sol:224, 566`, `SafeERC20.sol:35-49` |
| 7.20 | **Revert on Large Approvals (`>= 2^96`)** | `Raffle` does not call `approve`. | **Not Applicable** | N/A |
| 7.21 | **Code Injection via Token Name** | On-chain contracts do not read `quoteToken.name()`. (For `prizeToken`, frontend discovery must sanitize untrusted ERC-721 metadata). | **Not Applicable On-Chain** | N/A |
| 7.22 | **Unusual Permit Function** | `Raffle` does not integrate `permit`. | **Not Applicable** | N/A |
| 7.23 | **Transfer Less Than Amount (`cUSDCv3`)** | Rejected by deployment verification of canonical USDC (`RaffleFactory.sol:60-61`). | **Mitigated by Configuration** | `RaffleFactory.sol:60-61` |
| 7.24 | **ERC-20 Native Currency Representation** | Native ETH is used only in `requestDraw()` to pay `i_vrfV2PlusWrapper.requestRandomWordsInNative` and refund excess `msg.value - paidPrice` via low-level `call`, with `nonReentrant` protection (`Raffle.sol:240-273`). `quoteToken` and native currency paths never overlap. | **Mitigated** | `Raffle.sol:171-173, 240-273` |

---

## 6. Part C: External ERC-721 `prizeToken` Integration Analysis

### 6.1 Prize Token Lifecycle & Defensive Controls
1. **Creation & Interface Validation (`RaffleFactory.sol:154-179`):**
   - `_requireContract(params.prizeToken)` ensures `params.prizeToken.code.length != 0`.
   - Screens `params.prizeToken` against protocol addresses (`address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, `isRaffle[params.prizeToken]`).
   - Calls `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` inside a `try/catch` block and reverts with `UnsupportedPrizeToken(params.prizeToken)` on failure or `false`.
2. **Atomic Deposit & Escrow Verification (`RaffleFactory.sol:127-134`, `Raffle.sol:416-431`):**
   - `Raffle` initializes in `Status.AwaitingPrize` (`Raffle.sol:205`).
   - `RaffleFactory` calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:128`).
   - `Raffle.onERC721Received` enforces all 5 invariants before transitioning `status` to `Status.Active`:
     1. `status == Status.AwaitingPrize`
     2. `msg.sender == address(prizeToken)`
     3. `tokenId == prizeTokenId`
     4. `from == sponsor`
     5. `operator == factory`
   - After `safeTransferFrom` returns, `RaffleFactory` verifies both `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active` (`RaffleFactory.sol:129-134`).
   - Any unsolicited NFT sent via `safeTransferFrom` outside this exact creation step is rejected with `UnexpectedPrize`.
3. **Outbound Prize Delivery (`Raffle.sol:329-337, 395-407`):**
   - Both `redeemWinningTicket` (`Status.NftWon`) and `releaseSponsorPrize` (`Status.CashWon` or `Status.Refunding`) use `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` followed immediately by `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);`.
   - Using `transferFrom` instead of `safeTransferFrom` on outbound delivery prevents a contract `sponsorRecipient` (or contract `winner`) that does not implement `IERC721Receiver` from bricking `releaseSponsorPrize` or `redeemWinningTicket`, while `ownerOf` verification protects against non-standard ERC-721 tokens that fail silently without reverting.

---

## 7. Detailed Findings

### [TIA-01] Medium: Arbitrary `prizeToken` Combined with Decoupled `releaseSponsorProceeds()` Allows a Malicious Sponsor to Claim 95% of USDC Sales While Blocking Winner NFT Redemption

- **Severity:** Medium
- **Category:** External ERC-721 Token Integration / Economic Security
- **Locations:**
  - `packages/contracts/src/RaffleFactory.sol:154-179` (`_validateCreateParams`)
  - `packages/contracts/src/Raffle.sol:309-346` (`redeemWinningTicket`)
  - `packages/contracts/src/Raffle.sol:375-382` (`releaseSponsorProceeds`)
  - `packages/contracts/src/Raffle.sol:533-558` (`_settleWinningTicket`)

#### Description
`RaffleFactory.createRaffle` is permissionless and accepts any contract address as `params.prizeToken` as long as it has deployed code and returns `true` from `supportsInterface(0x80ac58cd)` (`RaffleFactory.sol:171-177`). As noted in `DESIGN.md:5`, *"arbitrary prize contracts and ticket recipients are untrusted."*

When a raffle meets its reserve and resolves to `Status.NftWon`:
1. Permissionless settlement (`_settleWinningTicket`, `Raffle.sol:533-558`) allocates `95%` of `unsettledPot` to `sponsorProceeds` and `5%` to `protocolFees` without touching `prizeToken`:
   ```solidity
   // Raffle.sol:542-555
   if (result == Status.NftWon) {
       sponsorAmount = grossPot - protocolFee;
   }
   ...
   settlementComplete = true;
   winningTicketId = ticketId;
   unsettledPot = 0;
   sponsorProceeds = sponsorAmount;
   protocolFees = protocolFee;
   ```
2. `releaseSponsorProceeds()` (`Raffle.sol:375-382`) allows the sponsor's USDC proceeds (`95%` of gross sales) to be withdrawn immediately after `_settleWinningTicket`, **without requiring `prizeClaimed == true` or `winnerRedeemed == true`**:
   ```solidity
   // Raffle.sol:375-382
   function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
       amount = sponsorProceeds;
       if (amount == 0) revert NoSponsorProceeds();
       sponsorProceeds = 0;
       address recipient = sponsorRecipient;
       _transferQuote(recipient, amount);
       emit SponsorProceedsReleased(msg.sender, recipient, amount);
   }
   ```
3. Meanwhile, `redeemWinningTicket()` (`Raffle.sol:329-337`) requires `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` to succeed and `prizeToken.ownerOf(deliveredPrizeTokenId) == winner`.

#### Exploit / Failure Scenarios
1. **Malicious / Sponsor-Controlled `prizeToken` Rug:** A sponsor deploys or uses an ERC-721 contract where the sponsor controls pause, blacklist, transfer-validator (e.g., ERC-721C / custom operator filter), or conditional transfer logic. During `createRaffle`, `prizeToken.safeTransferFrom(sponsor, raffle, prizeTokenId)` succeeds. After users deposit USDC via `buyEntries` and the raffle resolves to `Status.NftWon`, the sponsor pauses/blocks outbound transfers from `raffle` on `prizeToken`, calls `settleWinningTicket` + `releaseSponsorProceeds()` to extract 95% of the USDC pot, and leaves the winner permanently unable to execute `redeemWinningTicket()`. Because `Status.NftWon` is terminal and `unsettledPot` is already distributed, ticket buyers cannot obtain refunds either.
2. **Legitimate ERC-721 with Pausability / Creator-Token Transfer Restrictions (e.g., ERC-721C):** Even with an honest sponsor, if the underlying NFT collection pauses transfers or updates its transfer security policy such that `raffle` (an unwhitelisted contract) cannot execute `transferFrom(raffle, winner, prizeTokenId)`, the sponsor can still claim 95% of the USDC proceeds while the winner's NFT remains locked in `raffle`. (Note: if only a specific `winner` address is blacklisted by `prizeToken`, the winner can bypass it by transferring the `Raffle` winning ticket ERC-721 to an unblacklisted address before calling `redeemWinningTicket`).

#### Recommendation
1. **If keeping decoupled settlement/claims (`DESIGN.md` requirement):** Explicitly warn integrators and frontends that on-chain validation (`supportsInterface`) cannot verify `prizeToken` honesty or transferability; frontends must enforce a curated allowlist of verified, non-restrictive ERC-721 collections.
2. **Optional on-chain hardening (if design permits):** In `Status.NftWon`, consider gating `releaseSponsorProceeds()` (and optionally `releaseProtocolFees()`) on `prizeClaimed == true`—or allowing `settleWinningTicket` / a permissionless delivery helper to push or escrow the NFT—if and only if the design can tolerate or prevent a winner from withholding redemption to delay sponsor payout.

---

### [TIA-02] Low: Missing Runtime `_isProtocolDestination` Check in `releaseSponsorPrize()` and `redeemWinningTicket()` (`NftWon`) Allows Transferring an ERC-721 Prize into a Later-Deployed `Raffle` Clone

- **Severity:** Low
- **Category:** Protocol Destination Screening / Cross-Clone Asset Isolation
- **Locations:**
  - `packages/contracts/src/Raffle.sol:193-206` (`initialize`)
  - `packages/contracts/src/Raffle.sol:329-337` (`redeemWinningTicket` — `NftWon` branch)
  - `packages/contracts/src/Raffle.sol:395-407` (`releaseSponsorPrize`)
  - `packages/contracts/src/Raffle.sol:497-502` (`_update`)
  - `packages/contracts/src/Raffle.sol:564-567` (`_transferQuote`)
  - `packages/contracts/src/Raffle.sol:593-605` (`_isProtocolDestination`)

#### Description
`DESIGN.md:5` mandates: **"Never move assets between raffle clones."**
To enforce this invariant, `Raffle.sol` defines `_isProtocolDestination(address destination, address prizeToken_)` (`Raffle.sol:593-605`):
```solidity
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```
Because `RaffleFactory.createRaffle` deploys clones using `Clones.clone(raffleImplementation)` (`CREATE` opcode, `RaffleFactory.sol:106`), future raffle clone addresses are deterministic from `address(factory)` and the factory's deployment nonce. Before a future clone `RaffleB` is deployed:
- `predictedRaffleB.code.length == 0`
- `canonicalFactory.isRaffle(predictedRaffleB) == false`

Consequently:
1. A sponsor can create `RaffleA` with `params.sponsorRecipient = predictedRaffleB` (passes `RaffleFactory._validateCreateParams` at `RaffleFactory.sol:163-169` and `Raffle.initialize` at `Raffle.sol:199-201`).
2. Or a buyer in `RaffleA` can call `buyEntries(predictedRaffleB, entryCount)` (or transfer a ticket to `predictedRaffleB`) before `RaffleB` is created. Because `predictedRaffleB.code.length == 0`, both `_isProtocolDestination` (`Raffle.sol:498`) and `_safeMint`'s `checkOnERC721Received` (`ERC721Utils.sol:25`) pass!
3. Once `RaffleB` is subsequently created via `RaffleFactory.createRaffle`, `canonicalFactory.isRaffle(RaffleB)` becomes `true`.

Notice the asymmetry in how `Raffle.sol` screens outbound asset transfers at claim time:
- **For `quoteToken` (USDC):** `_transferQuote(address to, uint256 amount)` (`Raffle.sol:564-567`) re-runs `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);` at the moment of payout, blocking any USDC transfer to `RaffleB`!
- **For `prizeToken` (ERC-721):** Neither `releaseSponsorPrize()` (`Raffle.sol:395-407`) nor the `NftWon` branch of `redeemWinningTicket()` (`Raffle.sol:329-337`) calls `_isProtocolDestination(recipient, address(prizeToken))`! Furthermore, because `releaseSponsorPrize()` uses `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (not `safeTransferFrom`), `RaffleB.onERC721Received` is bypassed and `RaffleA`'s prize NFT is transferred directly into `RaffleB`, violating cross-clone asset isolation and permanently locking the NFT inside `RaffleB`.

#### Recommendation
Add `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` (or a dedicated error) inside `releaseSponsorPrize()` and in the `NftWon` branch of `redeemWinningTicket()` before calling `prizeToken.transferFrom(...)`, matching the runtime check in `_transferQuote()`.

---

### [TIA-03] Low: Fixed `sponsorRecipient` and `protocolTreasury` Have No Fallback Mechanism if Blacklisted by Canonical USDC

- **Severity:** Low
- **Category:** Weird ERC-20 Pattern 7.7 (Blocklists)
- **Locations:**
  - `packages/contracts/src/Raffle.sol:198-199, 375-392` (`initialize`, `releaseSponsorProceeds`, `releaseProtocolFees`)
  - `packages/contracts/src/RaffleFactory.sol:87` (`protocolTreasury`)

#### Description
Canonical USDC implements a central blacklist (`isBlacklisted`). `Raffle.sol` mitigates blacklist contagion across participants by isolating payouts into separate pull functions (`redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`). Additionally, if a ticket owner (`winner` or refund claimant) is blacklisted by Circle, they can still transfer their `Raffle` ERC-721 ticket (`transferFrom`) to an unblacklisted address and claim their USDC from that address because `Raffle._update` does not interact with `quoteToken`.

However, `sponsorRecipient` and `protocolTreasury` are stored as fixed addresses in each `Raffle` clone (`Raffle.sol:198-199`) with no mechanism to transfer their claim or specify a fallback address.
- If `sponsorRecipient` is blacklisted by USDC between raffle creation and `releaseSponsorProceeds()`, `quoteToken.safeTransfer(sponsorRecipient, amount)` will permanently revert (unless Circle unblacklists the address), locking `sponsorProceeds` in the clone.
- If `protocolTreasury` (which is `immutable` in `RaffleFactory.sol:39, 87`) is ever blacklisted by USDC or compromised/deprecated, `releaseProtocolFees()` will revert across all raffles created by that factory.

#### Recommendation
This is an inherent trade-off of the immutable, adminless design (`DESIGN.md:5`). Document that `protocolTreasury` and `sponsorRecipient` should be multi-sig or smart account addresses capable of administrative recovery/compliance rather than disposable addresses, and note that their USDC claims are non-transferable.

---

### [TIA-04] Informational: Untrusted `prizeToken` Can Call `buyEntries` During `createRaffle` Callback Window Before `RaffleCreated` Is Emitted

- **Severity:** Informational
- **Category:** External ERC-721 Integration / Reentrancy & Event Ordering
- **Locations:**
  - `packages/contracts/src/RaffleFactory.sol:127-147` (`createRaffle`)
  - `packages/contracts/src/Raffle.sol:416-431` (`onERC721Received`)

#### Description
During `RaffleFactory.createRaffle(params)` (`RaffleFactory.sol:127-147`):
1. `RaffleFactory` registers the clone (`raffleById`, `idByRaffle`, `isRaffle`) and calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:128`).
2. Inside `safeTransferFrom`, `prizeToken` calls `raffle.onERC721Received(factory, sponsor, prizeTokenId, data)`, which transitions `raffle.status` from `Status.AwaitingPrize` to `Status.Active` and emits `PrizeDeposited` (`Raffle.sol:428-429`).
3. Before `safeTransferFrom` returns control to `RaffleFactory` (and therefore before `RaffleFactory` verifies `prize.ownerOf(params.prizeTokenId) == raffle` and emits `RaffleCreated` at `RaffleFactory.sol:129-147`), `raffle` is already in `Status.Active` and `Raffle`'s `ReentrancyGuard` is `NOT_ENTERED` (since `onERC721Received` is not `nonReentrant`).
4. If `prizeToken` is a custom/untrusted contract, it can call `raffle.buyEntries(...)` before returning from `safeTransferFrom`. While all state and escrow invariants still hold (because `RaffleFactory` verifies `ownerOf == raffle` and `status == Active` immediately after `safeTransferFrom` returns), off-chain indexers would observe `TicketPurchased` emitted *before* `RaffleCreated`.

#### Recommendation
Consider either documenting for off-chain indexers that `PrizeDeposited` / `TicketPurchased` may precede `RaffleCreated` in transaction logs within the creation transaction, or activating the raffle via a factory-only step after `ownerOf` verification.

---

### [TIA-05] Informational: `Raffle.sol` Implements `IERC721Receiver` Without Advertising It in `supportsInterface` and Returns Empty `tokenURI`

- **Severity:** Informational
- **Category:** ERC-721 / ERC-165 Conformity
- **Locations:**
  - `packages/contracts/src/Raffle.sol:28, 416-431`
  - `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:43-48, 74-88`

#### Description
1. `Raffle` inherits `IERC721Receiver` (`Raffle.sol:28`) and implements `onERC721Received` (`Raffle.sol:416-431`), but does not override `supportsInterface(bytes4)` to return `true` for `type(IERC721Receiver).interfaceId` (`0x150b7a02`) or `type(IRaffle).interfaceId`. While standard EIP-721 implementations only invoke `onERC721Received` directly without querying ERC-165 for `0x150b7a02`, any non-standard `prizeToken` that checks `IERC165(to).supportsInterface(type(IERC721Receiver).interfaceId)` during `safeTransferFrom` will fail to escrow into `Raffle`.
2. `Raffle` does not override `_baseURI()` or `tokenURI(uint256)`, so `tokenURI(ticketId)` returns `""` for all existing tickets (`ERC721.sol:74-88`).

#### Recommendation
Optionally override `supportsInterface` in `Raffle.sol` to include `type(IERC721Receiver).interfaceId` (and `type(IRaffle).interfaceId`).

---

## 8. Deliverables Summary & Compliance Checklists

### 8.1 Compliance Checklist

**Contract Composition:**
- [x] Avoids unnecessary complexity
- [x] Uses Solidity `0.8.36` built-in overflow checks + `Math.mulDiv`
- [x] Minimal, well-scoped non-token lifecycle functions
- [x] Single address entry point per clone (`raffleImplementation` locked in constructor)

**Owner Privileges (`Raffle.sol`):**
- [x] Not upgradeable (immutable ERC-1167 clones)
- [x] No privileged minting (entries minted strictly on USDC payment in `buyEntries`)
- [x] Not pausable
- [x] No token-level user blacklist (only `_isProtocolDestination` plumbing filter)

**ERC-721 Conformity (`Raffle.sol` Ticket Token):**
- [x] Transfers to `0x0` revert (`ERC721InvalidReceiver(address(0))` / `InvalidRecipient()`)
- [x] `safeTransferFrom` implemented via OpenZeppelin `ERC721`
- [x] Metadata functions `name()` and `symbol()` implemented as clone-safe `pure` overrides
- [x] `ownerOf` reverts for invalid/burned tokens (`ERC721NonexistentToken`)
- [x] Transfers clear single-token approvals
- [x] Token IDs immutable during lifetime (`1..ticketCount`)
- [x] `onERC721Received` protected against unauthorized prizes and reentrancy
- [x] Safe minting (`_safeMint`) used in `buyEntries`
- [x] Burning (`_burn`) clears single-token approvals while preserving historical `_ticketRanges`

**Token Integration Safety (`quoteToken` & `prizeToken`):**
- [x] `SafeERC20` used for all `quoteToken` transfers
- [x] Internal liability accounting prevents donation/direct-transfer manipulation
- [x] Pull-payment isolation prevents a single blacklisted recipient from blocking other claims
- [x] Zero-value ERC-20 transfers prevented across all code paths
- [x] `decimals() == 6` verified on `quoteToken` in `RaffleFactory` constructor
- [x] `ownerOf` verified after every `prizeToken` transfer (`createRaffle`, `redeemWinningTicket`, `releaseSponsorPrize`)
- [ ] Runtime `_isProtocolDestination` check on outbound `prizeToken` transfers (Missing in `releaseSponsorPrize` and `redeemWinningTicket` — see **TIA-02**)
- [ ] Protection against unallowlisted/restrictive `prizeToken` blocking `NftWon` redemption after sponsor claims USDC proceeds (see **TIA-01**)

### 8.2 Prioritized Recommendations

1. **[MEDIUM — TIA-01] Mitigate Unallowlisted `prizeToken` + Decoupled Sponsor Payout Risk:**
   - Enforce a strict off-chain/frontend allowlist of verified, non-pausable, standard ERC-721 contracts for `prizeToken`, and/or gate `releaseSponsorProceeds()` in `Status.NftWon` on successful prize delivery if compatible with the protocol's liveness design.
2. **[LOW — TIA-02] Enforce Runtime `_isProtocolDestination` Screening on Outbound NFT Transfers:**
   - Add `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` in `releaseSponsorPrize()` (`Raffle.sol:402`) and `redeemWinningTicket()` (`Raffle.sol:333`) so a prize NFT can never be transferred to a `Raffle` clone deployed at a precomputed `CREATE` address after initialization.
3. **[LOW — TIA-03] Operational Guidance for `protocolTreasury` and `sponsorRecipient`:**
   - Ensure `protocolTreasury` and `sponsorRecipient` are configured as compliant, recoverable accounts since USDC blacklist events on those fixed addresses cannot be rerouted on-chain.
4. **[LOW / INFO — TIA-04 & TIA-05] Minor Hardening & ERC-165 Completeness:**
   - Advertise `type(IERC721Receiver).interfaceId` in `Raffle.supportsInterface`, and ensure off-chain indexers do not assume `RaffleCreated` always precedes `TicketPurchased` within the same transaction if indexing unverified `prizeToken` contracts.
