# Security Review — raffle.fun

**Scope:** 5 files, 2 concrete contracts (`Raffle.sol`, `RaffleFactory.sol`), 2 interfaces (`IRaffle.sol`, `IRaffleFactory.sol`), 1 constants library (`RaffleConstants.sol`)
**Method:** accounting-first review across 12 attack lenses (`0xSimao` `solidity-auditor` @ `29fd7da75a13d34fc500912334603ff62dc15897`)
**Findings:** 0 High · 2 Medium · 3 Low · 3 Info

`raffle.fun` is a non-upgradeable ERC-721 prize raffle protocol where a sponsor escrows an ERC-721 NFT (`prizeToken`, `prizeTokenId`) into an EIP-1167 minimal proxy clone deployed by `RaffleFactory::createRaffle()`. Buyers purchase contiguous 1-indexed entry ranges `[startEntry, endEntry]` in `Raffle::buyEntries()` at a fixed price of `1e6` raw `quoteToken` (USDC) per entry (`RaffleConstants::ENTRY_PRICE`), which increments both `totalEntries` and `unsettledPot` and mints an ERC-721 ticket token representing that range. After `endTime`, `Raffle::requestDraw()` pays the native Chainlink VRF v2.5 Direct Funding wrapper fee and transitions the raffle to `Status.Drawing`; `Raffle::fulfillRandomWords()` selects a 1-indexed `winningEntry` in `[1, totalEntries]` and transitions to `Status.NftWon` (`totalEntries >= reserveEntries`) or `Status.CashWon` (`totalEntries < reserveEntries`), while missed draw/callback deadlines transition to `Status.Refunding` via `Raffle::enableRefunds()`. In `Raffle::_settleWinningTicket()`, `unsettledPot` is zeroed once and partitioned into pull-claim buckets (`95%` `sponsorProceeds` + `5%` `protocolFees` in `Status.NftWon`; `80%` `winnerProceeds` + `15%` `sponsorProceeds` + `5%` `protocolFees` in `Status.CashWon`, with integer division remainder retained in `sponsorProceeds`), while in `Status.Refunding`, `remainingRefundLiability` backs `1:1` ticket refunds in `Raffle::refundTickets()`.

### Systemic observations

Across multiple lenses (`accounting-desync`, `share-exchange-rate`, `temporal-cohort`, `ordering-mev`, `integration-assumptions`, `flow-completeness`), two systemic architectural seams emerged:
1. **Time-of-check vs. time-of-use (TOCTOU) and asymmetric sink screening in `Raffle::_isProtocolDestination()`**: `RaffleFactory::createRaffle()` uses `Clones.clone(raffleImplementation)` (`CREATE`), making future clone addresses deterministic from `(address(factory), nonce)` before any bytecode exists at those addresses. Because `Raffle::_isProtocolDestination()` gates `canonicalFactory.isRaffle(destination)` behind `destination.code.length != 0` (`Raffle.sol:L601`) and `Raffle::releaseSponsorPrize()` (`Raffle.sol:L404`) and `Raffle::redeemWinningTicket()` (`Raffle.sol:L334`) omit `_isProtocolDestination()` altogether, pre-deployment clone addresses bypass intake screening and later become active protocol clones.
2. **Decoupled storage settlement vs. untrusted external `prizeToken` delivery**: `Raffle::_settleWinningTicket()` (`Raffle.sol:L533-L558`) unconditionally credits `sponsorProceeds` (`95%` of `unsettledPot`) in `Status.NftWon` before `Raffle::redeemWinningTicket()` proves that the arbitrary ERC-721 `prizeToken` can still be transferred to the winner.

---

## M-1. `Raffle::_isProtocolDestination()` and `Raffle::releaseSponsorPrize()` allow precomputed future `Raffle` clone addresses (`CREATE`), permanently locking quote payouts and moving prize NFTs between clones

**Description:**

In `RaffleFactory::createRaffle()` ([`RaffleFactory.sol#L125`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L125)), each clone is deployed with `Clones.clone(raffleImplementation)` (`CREATE`), so the address of every future clone $R_k$ is deterministic from `(address(factory), k + 1)` before $R_k$ is deployed. Prior to deployment of $R_k$, `R_k.code.length == 0` and `canonicalFactory.isRaffle(R_k) == false`. Consequently:
1. `RaffleFactory::_validateCreateParams()` ([`RaffleFactory.sol#L166`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L166)) and `Raffle::_isProtocolDestination()` ([`Raffle.sol#L601`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L601)) return `false` for $R_k$ during `Raffle::initialize()` (when `sponsorRecipient == R_k`) and during `Raffle::_update()` ([`Raffle.sol#L498`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L498)) when minting or transferring a ticket to $R_k$.
2. `ERC721Utils.checkOnERC721Received` skips calling `R_k.onERC721Received` during `Raffle::buyEntries(R_k, entryCount)` because `R_k.code.length == 0`.
3. Once a subsequent `RaffleFactory::createRaffle()` deploys $R_k$, `R_k.code.length == 45` and `isRaffle[R_k] == true`:
   - In `Raffle::releaseSponsorProceeds()` ([`Raffle.sol#L380`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L380)), `Raffle::_transferQuote()` re-checks `_isProtocolDestination(R_k, address(prizeToken))` ([`Raffle.sol#L565`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L565)), which now evaluates to `true` and reverts with `InvalidQuoteDestination(R_k)` permanently, locking `sponsorProceeds` inside the first raffle.
   - In `Raffle::releaseSponsorPrize()` ([`Raffle.sol#L395-L407`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L395-L407)), `_isProtocolDestination` is omitted and `prizeToken.transferFrom(address(this), R_k, prizeTokenId)` transfers the first raffle's prize NFT directly into clone $R_k$ (without invoking `R_k.onERC721Received`), directly violating the `DESIGN.md` invariant *"Never move assets between raffle clones"* and permanently stranding the NFT in $R_k$.
   - Any ticket minted or transferred to $R_k$ before $R_k$'s deployment can never be redeemed or refunded because `Raffle` has no function to call `redeemWinningTicket` or `refundTickets`, permanently locking `winnerProceeds`, `remainingRefundLiability`, or the `Status.NftWon` prize NFT.

**Recommended Mitigation (Option A — deploy clones with caller-bound `CREATE2` salts and enforce `_isProtocolDestination` on prize transfers):**

```diff
--- a/packages/contracts/src/RaffleFactory.sol
+++ b/packages/contracts/src/RaffleFactory.sol
@@ -122,7 +122,8 @@ contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
         unchecked {
             raffleId = ++raffleCount;
         }
-        raffle = Clones.clone(raffleImplementation);
+        bytes32 salt = keccak256(abi.encode(msg.sender, raffleId, block.prevrandao));
+        raffle = Clones.cloneDeterministic(raffleImplementation, salt);
```

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -334,6 +334,9 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
             IERC721 deliveredPrizeToken = prizeToken;
             uint256 deliveredPrizeTokenId = prizeTokenId;
+            if (_isProtocolDestination(winner, address(deliveredPrizeToken))) {
+                revert UnsafeProtocolDestination(winner);
+            }
             deliveredPrizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
@@ -403,6 +406,9 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
         address recipient = sponsorRecipient;
+        if (_isProtocolDestination(recipient, address(prizeToken))) {
+            revert UnsafeProtocolDestination(recipient);
+        }
         prizeToken.transferFrom(address(this), recipient, prizeTokenId);
```

**Fix review:**

---

## M-2. `Raffle::releaseSponsorProceeds()` does not require `prizeClaimed` in `Status.NftWon`, allowing a sponsor with a reverting/paused `prizeToken` to extract 95% of buyer USDC without delivering the prize

**Description:**

`RaffleFactory::_validateCreateParams()` ([`RaffleFactory.sol#L171-L177`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L171-L177)) accepts any arbitrary contract that returns `true` for `IERC165.supportsInterface(0x80ac58cd)` as `prizeToken`, and `DESIGN.md` explicitly models arbitrary prize contracts as untrusted. However, when a raffle resolves to `Status.NftWon`, `Raffle::_settleWinningTicket()` ([`Raffle.sol#L533-L558`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L533-L558)) immediately moves `95%` of `unsettledPot` into `sponsorProceeds` without verifying that `prizeToken` can be transferred to the winner, and `Raffle::releaseSponsorProceeds()` ([`Raffle.sol#L375-L382`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L375-L382)) pays `sponsorProceeds` to `sponsorRecipient` without requiring `prizeClaimed == true`. If `prizeToken` is a custom, pausable, blacklist-enabled, or transfer-restricted ERC-721 contract that succeeds during `createRaffle` but reverts (or fails the post-transfer `ownerOf` check) in `Raffle::redeemWinningTicket()` ([`Raffle.sol#L334-L337`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L334-L337)), the sponsor extracts 95% of buyer USDC while the winner never receives the NFT and buyers can never transition `Status.NftWon` to `Status.Refunding`.

**Recommended Mitigation:**

Gate `Raffle::releaseSponsorProceeds()` on `prizeClaimed` when `status == Status.NftWon` (or attempt prize delivery during settlement with a fallback to `Status.Refunding` if the untrusted `prizeToken` fails transfer):

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -375,6 +375,7 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
     /// @inheritdoc IRaffle
     function releaseSponsorProceeds() external nonReentrant {
+        if (status == Status.NftWon && !prizeClaimed) revert PrizeNotClaimed();
         uint256 amount = sponsorProceeds;
         if (amount == 0) revert NoSponsorProceeds();
```

**Fix review:**

---

## L-1. Discontinuous payout cliff at `totalEntries == reserveEntries` in `Raffle::fulfillRandomWords()` and `Raffle::_settleWinningTicket()` allows sponsor last-second self-purchase arbitrage and single-buyer `Status.CashWon` fee extraction

**Description:**

In `Raffle::fulfillRandomWords()` ([`Raffle.sol#L521`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L521)) and `Raffle::_settleWinningTicket()` ([`Raffle.sol#L539-L550`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L539-L550)), crossing `totalEntries == reserveEntries` switches the sponsor's share of the pot discontinuously from `15%` (`Status.CashWon`, where `80%` goes to `winnerProceeds`) to `95%` (`Status.NftWon`, where `0%` goes to `winnerProceeds`). Because neither `sponsor` nor `sponsorRecipient` is restricted in `Raffle::buyEntries()` ([`Raffle.sol#L209-L236`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L209-L236)), every entry purchased by the sponsor once `totalEntries >= reserveEntries` receives an immediate `95%` rebate via `sponsorProceeds` (a net cost of `$0.05` per `$1.00` entry). A sponsor can therefore buy the remaining shortfall `reserveEntries - E_honest` right before `endTime` to capture an extra `80%` of honest buyers' funds plus `(reserveEntries - E_honest) / reserveEntries` probability of winning back their own NFT. Conversely, if `totalEntries < reserveEntries` and only a single buyer (`ticketCount == 1`) participated, `Raffle::requestDraw()` ([`Raffle.sol#L243-L246`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L243-L246)) still permits the sponsor to trigger a draw at `endTime`, forcing `Status.CashWon` and extracting `20%` (`15%` `sponsorProceeds` + `5%` `protocolFees`) from the sole buyer while reclaiming the prize NFT.

**Recommended Mitigation:**

Reject `sponsor` and `sponsorRecipient` in `Raffle::_isProtocolDestination()`, and require at least two distinct tickets (`ticketCount >= 2`) when `totalEntries < reserveEntries` in `Raffle::requestDraw()`.

**Fix review:**

---

## L-2. `Raffle::enableRefunds()` pre-`endTime` empty-raffle cancellation can be front-run by a 1-USDC `Raffle::buyEntries()` call, locking the sponsor's prize NFT for up to 32 days

**Description:**

`Raffle::enableRefunds()` ([`Raffle.sol#L280-L285`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L280-L285)) allows `sponsor` to cancel a raffle before `endTime` only when `totalEntries == 0`. Because `Raffle::buyEntries()` ([`Raffle.sol#L209`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L209)) remains open until `endTime`, a mempool searcher can front-run the sponsor's `enableRefunds()` transaction with `buyEntries(attacker, 1)` for `1e6` USDC (`$1.00`). This sets `totalEntries = 1`, causing the sponsor's `enableRefunds()` call to enter the `else` branch and revert with `RefundsNotAvailable(endTime + 2 days, block.timestamp)`. The sponsor's NFT is locked until `endTime` (or `endTime + 2 days`, up to `32 days`), and if `reserveEntries == 1`, the attacker wins the NFT outright for `$1.00`.

**Recommended Mitigation:**

Allow the sponsor to cancel before `endTime` even if entries were sold (transitioning the raffle to `Status.Refunding` so buyers can reclaim 100% of their `quoteToken`), or add a short cancellation cooldown / `startTime` window.

**Fix review:**

---

## L-3. `Raffle::onERC721Received()` sets `Status.Active` during `prize.safeTransferFrom()` in `RaffleFactory::createRaffle()`, allowing an untrusted `prizeToken` to call `Raffle::buyEntries()` before `RaffleCreated` is emitted

**Description:**

In `RaffleFactory::createRaffle()` ([`RaffleFactory.sol#L139-L147`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L139-L147)), `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` triggers `Raffle::onERC721Received()` ([`Raffle.sol#L416-L431`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L416-L431)), which sets `status = Status.Active` before `safeTransferFrom` returns to `RaffleFactory`. Because only `RaffleFactory`'s `ReentrancyGuard` is entered (not the clone's own `ReentrancyGuard`), a custom `prizeToken` contract can invoke `raffle.buyEntries(recipient, entryCount)` after `onERC721Received` returns and before `RaffleFactory::createRaffle()` verifies `prize.ownerOf(params.prizeTokenId) == raffle` and emits `RaffleCreated`, inverting the expected `RaffleCreated` → `TicketPurchased` event order for off-chain indexers.

**Recommended Mitigation:**

Emit `RaffleCreated` before calling `prize.safeTransferFrom`, or keep the clone in `Status.Initialized` during `onERC721Received` and activate it via an explicit factory call after `prize.ownerOf(params.prizeTokenId) == raffle` is verified.

**Fix review:**

---

## I-1. `RaffleFactory::_validateCreateParams()` enforces no upper bound on `reserveEntries`, allowing raffles where `Status.NftWon` is mathematically unreachable

**Description:**

`RaffleFactory::_validateCreateParams()` ([`RaffleFactory.sol#L178`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L178)) only checks `if (params.reserveEntries == 0) revert ZeroReserveEntries();` and allows `params.reserveEntries` up to `type(uint128).max` ($pprox 3.4 	imes 10^{38}$ entries), which far exceeds total USDC supply and guarantees `totalEntries < reserveEntries` (`Status.CashWon`).

**Recommended Mitigation:**

Enforce a protocol constant upper bound `MAX_RESERVE_ENTRIES` in `RaffleFactory::_validateCreateParams()`.

---

## I-2. `Raffle::_update()` allows secondary ERC-721 ticket transfers during `Status.Drawing` and after draw resolution, exposing open secondary-market orders to VRF fulfillment front-running

**Description:**

`Raffle::_update()` ([`Raffle.sol#L497-L502`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/Raffle.sol#L497-L502)) checks `_isProtocolDestination` on non-burn transfers but does not restrict transfers when `status != Status.Active`. Once the Chainlink VRF callback transaction is visible in the mempool, a seller can accept a stale bid on a losing ticket or cancel a listing on the winning ticket before `fulfillRandomWords` executes.

**Recommended Mitigation:**

Restrict non-mint, non-burn transfers in `Raffle::_update()` to `status == Status.Active` (or document that off-chain marketplaces must set order expiration timestamps at or before `endTime`).

---

## I-3. `Raffle` inherits storage-backed `ReentrancyGuard` on ERC-1167 clones (charging the first buyer a 20,000-gas cold `0 -> 1` SSTORE) and sets `VRF_CALLBACK_GAS_LIMIT = 300_000`

**Description:**

Because `Raffle` is deployed as an ERC-1167 minimal proxy clone ([`RaffleFactory.sol#L125`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/RaffleFactory.sol#L125)), its `ReentrancyGuard` `_status` slot starts at `0` rather than `NOT_ENTERED = 1`, so the first caller to `buyEntries` pays a 20,000-gas `0 -> 1` SSTORE penalty. In addition, `RaffleConstants::VRF_CALLBACK_GAS_LIMIT = 300_000` ([`RaffleConstants.sol#L39`](file:///Users/hishamel-husseini/Documents/projects/raffle-fun/packages/contracts/src/libraries/RaffleConstants.sol#L39)) over-provisions callback gas by ~5-6x for `Raffle::fulfillRandomWords()`, increasing the native VRF fee paid by `requestDraw` callers.

**Recommended Mitigation:**

Use OpenZeppelin's `ReentrancyGuardTransient` (supported on `evm_version = "cancun"`) and reduce `VRF_CALLBACK_GAS_LIMIT` to ~`100_000`.

---

## Unverified leads

- `RaffleFactory::constructor` — `protocolTreasury` set to a future clone `CREATE` address $R_k$ causes `createRaffle` to revert with `UnsafeProtocolDestination` from clone $k$ onward — requires deployer to pass a precomputed clone address at factory construction.
- `Raffle::releaseSponsorProceeds` — immutable `sponsorRecipient` blacklisted by USDC permanently locks `sponsorProceeds` inside `Raffle` — requires Circle blacklist action on `sponsorRecipient` after raffle creation.
- `Raffle::requestDraw` — permissionless `requestDraw` prices native VRF fee using caller's `tx.gasprice` — low-gas-price griefing depends on external Chainlink VRF v2.5 wrapper mempool fulfillment policy.
- `Raffle::releaseSponsorPrize` / `Raffle::redeemWinningTicket` — uses `prizeToken.transferFrom` instead of `safeTransferFrom` — contract recipients that rely on `onERC721Received` callbacks do not receive the hook.
