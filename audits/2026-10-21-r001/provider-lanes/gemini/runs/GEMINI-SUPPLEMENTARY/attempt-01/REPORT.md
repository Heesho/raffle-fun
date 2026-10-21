# Gemini 4 Argon (High) — Supplementary Cold Adversarial Security Review (`GEMINI-SUPPLEMENTARY`)

- **Cell ID**: `GEMINI-SUPPLEMENTARY` (`attempt-01`, Cold Source-Only Review)
- **Provider / Model**: Google Gemini (`gemini-4-argon`, Gemini 4 Argon (High))
- **Runner**: `/Applications/Antigravity.app/Contents/Resources/bin/language_server` (`hub-2.25.0`)
- **Frozen Target Commit**: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Scope**:
  - `packages/contracts/src/Raffle.sol` (`6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617`)
  - `packages/contracts/src/RaffleFactory.sol` (`d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace`)
  - `packages/contracts/src/interfaces/IRaffle.sol` (`a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd`)
  - `packages/contracts/src/interfaces/IRaffleFactory.sol` (`747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf`)
  - `packages/contracts/src/libraries/RaffleConstants.sol` (`0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6`)

---

## Executive Summary & Cold Invariant Verification Matrix

We performed a zero-trust, line-by-line state-machine, arithmetic, reentrancy, access-control, and economic mechanism review of all five production contracts prior to inspecting any test files, historical audit artifacts, or peer lanes.

| Invariant / Property | Status | Verification Summary |
|---|---|---|
| **I-1: Pot & Liability Conservation** (`unsettledPot + winnerProceeds + sponsorProceeds + protocolFees + remainingRefundLiability <= quoteToken.balanceOf(raffle)`) | **Holds Arithmetic / Violated on Liveness (`GEMINI-01`)** | In `_settleWinningTicket` (`Raffle.sol:L533-L558`), `feeAmount + sponsorAmount == grossPot` in `NftWon` and `feeAmount + winnerAmount + sponsorAmount == grossPot` in `CashWon` (since `sponsorAmount = grossPot - feeAmount - winnerAmount`). However, if a recipient is a precomputed future `Raffle` clone address, `_transferQuote` permanently reverts after that clone is deployed, stranding the bucket. |
| **I-2: Cross-Clone Asset Isolation** (*"Never move assets between raffle clones"*, `DESIGN.md`) | **VIOLATED (`GEMINI-01`)** | `RaffleFactory.createRaffle` uses `Clones.clone` (`CREATE`, deterministic from `(factory, nonce)`). Setting `sponsorRecipient` (or ticket owner) to a future clone address $R_{\text{future}}$ before its deployment bypasses `_validateCreateParams` and `_isProtocolDestination`. Once $R_{\text{future}}$ is deployed, `releaseSponsorPrize()` (`Raffle.sol:L404`) and `redeemWinningTicket()` (`Raffle.sol:L334`) omit `_isProtocolDestination` and call `prizeToken.transferFrom(address(this), R_future, prizeTokenId)`, moving the NFT directly into clone $R_{\text{future}}$. |
| **I-3: Atomic Fair Exchange in `Status.NftWon`** | **VIOLATED (`GEMINI-02`)** | `_settleWinningTicket` credits `sponsorProceeds = 95%` without verifying `prizeToken` transferability, and `releaseSponsorProceeds` (`Raffle.sol:L375-L382`) does not require `prizeClaimed == true`. If an arbitrary/pausable/restricted `prizeToken` reverts in `redeemWinningTicket`, the sponsor extracts 95% of buyer USDC while the winner gets nothing. |
| **I-4: Contiguous 1-Indexed Entry Range Partitioning & Binary Search** | **Holds** | Ticket $k \in [1, \text{ticketCount}]$ spans $[\text{startEntry}_k, \text{endEntry}_k]$ with $\text{startEntry}_1 = 1$, $\text{startEntry}_{k} = \text{endEntry}_{k-1} + 1$, and $\text{endEntry}_{\text{ticketCount}} = \text{totalEntries}$. `ticketIdForEntry` (`Raffle.sol:L455-L473`) uses overflow-safe `mid = low + ((high - low) / 2)` and terminates in $\le 128$ iterations. |
| **I-5: VRF Request & Callback Window Exclusivity** | **Holds** | `requestDraw` requires `status == Status.Active && block.timestamp >= endTime && block.timestamp < endTime + 2 days`. `fulfillRandomWords` returns `false` without reverting if `status != Status.Drawing || requestId != drawRequestId || _requestInFlight || _randomWords.length == 0 || block.timestamp >= callbackDeadline()`. At `block.timestamp == callbackDeadline()`, `fulfillRandomWords` returns `false` while `enableRefunds` succeeds (`<` vs `>=` partition). |

---

## Detailed Cold Findings

### [GEMINI-01] (Medium) Predictable `CREATE` Clone Addresses Bypass `_isProtocolDestination` Before Deployment, Permanently Locking USDC Claims/Tickets and Allowing Cross-Clone ERC-721 Prize Transfers

- **Locations**:
  - [`RaffleFactory.sol#L125`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L125) (`raffle = Clones.clone(raffleImplementation);`)
  - [`RaffleFactory.sol#L165-L167`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L165-L167) (`isRaffle[params.sponsorRecipient]`)
  - [`Raffle.sol#L593-L605`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L593-L605) (`_isProtocolDestination`)
  - [`Raffle.sol#L395-L407`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L395-L407) (`releaseSponsorPrize`)
  - [`Raffle.sol#L333-L339`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L333-L339) (`redeemWinningTicket`)
  - [`Raffle.sol#L497-L502`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L497-L502) (`_update`)
  - [`Raffle.sol#L564-L567`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L564-L567) (`_transferQuote`)
- **Root Cause**:
  1. `RaffleFactory.createRaffle` deploys clones using `Clones.clone(raffleImplementation)` (`CREATE`), whose address is purely a function of `(address(factory), factoryNonce)`. Before future clone $R_{\text{future}}$ is deployed, `R_future.code.length == 0` and `isRaffle[R_future] == false`.
  2. `Raffle._isProtocolDestination(destination, prizeAsset)` only checks `canonicalFactory.isRaffle(destination)` if `destination.code.length != 0`, and `ERC721Utils.checkOnERC721Received` only invokes `onERC721Received` if `to.code.length > 0`.
  3. While `_transferQuote` re-runs `_isProtocolDestination` at claim time, `releaseSponsorPrize` and `redeemWinningTicket` (in `Status.NftWon`) omit `_isProtocolDestination` and use `prizeToken.transferFrom` instead of `safeTransferFrom`.
- **Exploit / Failure Paths**:
  - **Path A (Cross-Clone Prize Transfer & Locked Sponsor Proceeds)**: Sponsor creates Raffle #1 (`nonce = 2`) with `sponsorRecipient = R_2 = computeCreateAddress(factory, 3)`. Both `_validateCreateParams` and `Raffle.initialize` pass. Once Raffle #2 is created at `R_2`, `isRaffle[R_2] = true` and `R_2.code.length == 45`. If Raffle #1 settles, `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(R_2)`. If Raffle #1 resolves to `CashWon` or `Refunding`, `releaseSponsorPrize()` transfers Raffle #1's prize NFT into Raffle #2 (`R_2`), violating `DESIGN.md` (*"Never move assets between raffle clones"*) and locking the NFT inside `R_2` forever.
  - **Path B (Unclaimable Ticket Ownership by a Later Clone)**: A caller calls `R_1.buyEntries(R_2, N)` (or transfers a ticket to `R_2`) before `R_2` is created. Once `R_2` is deployed, `R_2` owns the ticket in `R_1` and has no function to call `redeemWinningTicket` or `refundTickets`, permanently locking the `Status.NftWon` prize NFT, `Status.CashWon` `winnerProceeds`, or `Status.Refunding` `remainingRefundLiability`.
  - **Path C (Factory-Wide DoS at Clone $k$ via `protocolTreasury`)**: If `protocolTreasury` in `RaffleFactory`'s constructor is set to a future clone address $R_k$, `createRaffle` works for clones $1 \dots k-1$ and permanently reverts with `UnsafeProtocolDestination(R_k)` at clone $k$.

### [GEMINI-02] (Medium) Decoupled `releaseSponsorProceeds` in `Status.NftWon` Allows Sponsor to Extract 95% of Buyer USDC When Untrusted/Restricted `prizeToken` Fails Delivery in `redeemWinningTicket`

- **Locations**: [`Raffle.sol#L329-L339`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L329-L339), [`Raffle.sol#L375-L382`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L375-L382), [`Raffle.sol#L533-L558`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L533-L558), [`RaffleFactory.sol#L171-L177`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L171-L177)
- **Root Cause**: `_settleWinningTicket` credits `sponsorProceeds = 95%` in storage without delivering `prizeToken`, and `releaseSponsorProceeds()` does not require `prizeClaimed == true` when `status == Status.NftWon`.
- **Impact**: If an untrusted, pausable, blacklist-enabled, or transfer-restricted `prizeToken` reverts during `redeemWinningTicket`, the sponsor still claims 95% of buyer USDC while the winner cannot claim the NFT and the raffle cannot enter `Status.Refunding`.

### [GEMINI-03] (Low) Discontinuous Payout Cliff at `reserveEntries` and Single-Buyer Under-Target Draw Enable Sponsor Self-Purchase Arbitrage and 20% Fee Extraction

- **Locations**: [`Raffle.sol#L209-L236`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L209-L236), [`Raffle.sol#L243-L248`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L243-L248), [`Raffle.sol#L521`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L521), [`Raffle.sol#L539-L550`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L539-L550)
- **Root Cause**: Neither `sponsor` nor `sponsorRecipient` is blocked from calling `buyEntries`, and `requestDraw` allows drawing below `reserveEntries` even when `ticketCount == 1`.

### [GEMINI-04] (Low) Pre-`endTime` Empty-Raffle Cancellation (`enableRefunds`) Can Be Front-Run by a 1-USDC `buyEntries` Call

- **Locations**: [`Raffle.sol#L209`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L209), [`Raffle.sol#L280-L285`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L280-L285)
- **Root Cause**: `enableRefunds()` only permits `sponsor` to cancel before `endTime` when `totalEntries == 0`, which an attacker can invalidate in the mempool for `1e6` USDC (`$1.00`).

### [GEMINI-05] (Low) `Raffle.onERC721Received` Activates the Clone Inside `prize.safeTransferFrom` Before `RaffleCreated` Is Emitted

- **Locations**: [`RaffleFactory.sol#L139-L147`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L139-L147), [`Raffle.sol#L416-L431`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L416-L431)
- **Root Cause**: `onERC721Received` sets `status = Status.Active` before `prize.safeTransferFrom` returns to `RaffleFactory.createRaffle` while the clone's `ReentrancyGuard` is unentered, allowing a custom `prizeToken` to call `raffle.buyEntries` before `RaffleCreated` is emitted.

### [GEMINI-06] (Informational) Missing `reserveEntries` Upper Bound, Unrestricted Secondary Ticket Transfers During `Status.Drawing`, and ERC-1167 `ReentrancyGuard` / `VRF_CALLBACK_GAS_LIMIT` Overhead

- **Locations**: [`RaffleFactory.sol#L178`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L178), [`Raffle.sol#L497-L502`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L497-L502), [`RaffleConstants.sol#L39`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/libraries/RaffleConstants.sol#L39)
