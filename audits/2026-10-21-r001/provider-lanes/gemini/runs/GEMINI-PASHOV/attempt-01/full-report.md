# 🔐 Security Review — raffle-fun

---

## Scope

|  |  |
| --- | --- |
| **Mode** | default |
| **Files reviewed** | `packages/contracts/src/Raffle.sol` · `packages/contracts/src/RaffleFactory.sol` · `packages/contracts/src/interfaces/IRaffle.sol`<br>`packages/contracts/src/interfaces/IRaffleFactory.sol` · `packages/contracts/src/libraries/RaffleConstants.sol` |
| **Confidence threshold (1-100)** | 75 |

---

## Findings

[95] **1. Future clone address bypasses destination check and locks quote payouts or tickets**

`Raffle._isProtocolDestination` · Confidence: 95

**Description**
A caller can pass a future clone address to `initialize`, `buyEntries`, or `transferFrom` before deployment, which permanently locks quote payouts, winning prizes, or refunds once `createRaffle` deploys that clone.

**Fix (Option A — deploy clones with caller-bound deterministic salts)**:

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

**Fix (Option B — require code-less or registered non-clone recipient at claim time with fallback)**:

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -601,7 +601,7 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
-        if (!unsafeDestination && destination.code.length != 0) {
+        if (!unsafeDestination) {
             unsafeDestination = canonicalFactory.isRaffle(destination);
         }
```

---

[92] **2. Missing destination check in `releaseSponsorPrize` transfers prize NFT into a later raffle clone**

`Raffle.releaseSponsorPrize` · Confidence: 92

**Description**
A sponsor can set `sponsorRecipient` to the next clone address before deployment, so `releaseSponsorPrize` skips `_isProtocolDestination` and transfers the prize NFT into that second clone forever.

**Fix**

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -403,6 +403,9 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
         prizeClaimed = true;
 
         address recipient = sponsorRecipient;
+        if (_isProtocolDestination(recipient, address(prizeToken))) {
+            revert UnsafeProtocolDestination(recipient);
+        }
         prizeToken.transferFrom(address(this), recipient, prizeTokenId);
         if (prizeToken.ownerOf(prizeTokenId) != recipient) {
             revert PrizeTransferFailed(address(prizeToken), prizeTokenId, address(this), recipient);
```

---

[85] **3. Sponsor claims 95% of buyer quote tokens in `Status.NftWon` before prize NFT delivery is verified**

`Raffle.releaseSponsorProceeds` · Confidence: 85

**Description**
A sponsor who supplies a `prizeToken` that blocks transfers after escrow can call `settleWinningTicket` and `releaseSponsorProceeds` in `Status.NftWon` to take 95% of the pot while `redeemWinningTicket` reverts for the winner.

**Fix**

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

---

[82] **4. Sponsor buys entries at a 95% rebate to cross `reserveEntries` and take 80% of buyer funds**

`Raffle.buyEntries` · Confidence: 82

**Description**
The sponsor can call `buyEntries` right before `endTime` to cross `reserveEntries`, switch settlement from `Status.CashWon` to `Status.NftWon`, and take 95% of all ticket payments through `sponsorProceeds`.

**Fix**

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -595,6 +595,8 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
         bool unsafeDestination = destination == address(this) ||
             destination == address(canonicalFactory) ||
+            destination == sponsor ||
+            destination == sponsorRecipient ||
             destination == canonicalFactory.raffleImplementation() ||
```

---

[80] **5. Attacker front-runs `enableRefunds` with a 1-USDC purchase to lock the sponsor prize until `endTime`**

`Raffle.enableRefunds` · Confidence: 80

**Description**
An attacker can buy one entry before the sponsor's `enableRefunds` transaction runs, which makes `enableRefunds` revert and locks the sponsor's prize NFT until `endTime + 2 days`.

**Fix**

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -280,7 +280,7 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
         uint64 deadline;
-        if (totalEntries == 0) {
+        if (totalEntries == 0 || msg.sender == sponsor) {
             deadline = endTime;
```

---

[78] **6. Sponsor calls `requestDraw` when one buyer holds all entries below `reserveEntries` to take 15% of the pot**

`Raffle.requestDraw` · Confidence: 78

**Description**
The sponsor can call `requestDraw` below `reserveEntries` when one buyer owns all entries to force `Status.CashWon`, take 15% of the sole buyer's deposit, and keep the prize NFT.

**Fix**

```diff
--- a/packages/contracts/src/Raffle.sol
+++ b/packages/contracts/src/Raffle.sol
@@ -243,6 +243,7 @@ contract Raffle is IRaffle, ERC721, IERC721Receiver, VRFV2PlusWrapperConsumerBas
         if (status != Status.Active) revert InvalidStatus(status);
         if (totalEntries == 0) revert NoEntriesSold();
+        if (totalEntries < reserveEntries && ticketCount < 2) revert InsufficientParticipants();
```

---

[76] **7. Untrusted `prizeToken` calls `buyEntries` during `safeTransferFrom` before `RaffleCreated` emits**

`RaffleFactory.createRaffle` · Confidence: 76

**Description**
A `prizeToken` contract can call `buyEntries` on the clone inside `safeTransferFrom` in `createRaffle` after `onERC721Received` sets `status` to `Status.Active`, so `TicketPurchased` emits before `RaffleCreated`.

**Fix**

```diff
--- a/packages/contracts/src/RaffleFactory.sol
+++ b/packages/contracts/src/RaffleFactory.sol
@@ -136,11 +136,11 @@ contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
         raffleById[raffleId] = raffle;
         idByRaffle[raffle] = raffleId;
         isRaffle[raffle] = true;
 
+        emit RaffleCreated(raffleId, raffle, msg.sender, params.prizeToken, params.prizeTokenId, params.endTime, params.reserveEntries);
         prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
         if (prize.ownerOf(params.prizeTokenId) != raffle) {
             revert PrizeEscrowFailed(params.prizeToken, params.prizeTokenId, raffle);
         }
```

---

[75] **8. Setting `protocolTreasury` to a future clone `CREATE` address bricks `createRaffle` at that nonce**

`RaffleFactory.constructor` · Confidence: 75

**Description**
A deployer who sets `protocolTreasury` to the `CREATE` address of future clone `k` makes `Raffle.initialize` revert with `UnsafeProtocolDestination` for every `createRaffle` call once `raffleCount` reaches `k`.

**Fix**

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

---

Findings List

| # | Confidence | Title |
|---|---|---|
| 1 | [95] | Future clone address bypasses destination check and locks quote payouts or tickets |
| 2 | [92] | Missing destination check in `releaseSponsorPrize` transfers prize NFT into a later raffle clone |
| 3 | [85] | Sponsor claims 95% of buyer quote tokens in `Status.NftWon` before prize NFT delivery is verified |
| 4 | [82] | Sponsor buys entries at a 95% rebate to cross `reserveEntries` and take 80% of buyer funds |
| 5 | [80] | Attacker front-runs `enableRefunds` with a 1-USDC purchase to lock the sponsor prize until `endTime` |
| 6 | [78] | Sponsor calls `requestDraw` when one buyer holds all entries below `reserveEntries` to take 15% of the pot |
| 7 | [76] | Untrusted `prizeToken` calls `buyEntries` during `safeTransferFrom` before `RaffleCreated` emits |
| 8 | [75] | Setting `protocolTreasury` to a future clone `CREATE` address bricks `createRaffle` at that nonce |

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **Contract recipient in `buyEntries` can transfer the minted ticket inside `onERC721Received` before `TicketPurchased` emits** — `Raffle.buyEntries` — Code smells: `_safeMint` runs before `emit TicketPurchased` and `ERC721.transferFrom` has no `nonReentrant` modifier — A contract recipient can re-enter `transferFrom` during `_safeMint` so the secondary `Transfer` event precedes `TicketPurchased`.
- **Synchronous VRF callback during `requestDraw` is ignored because `_requestInFlight` is true** — `Raffle.fulfillRandomWords` — Code smells: `requestDraw` sets `_requestInFlight = true` before calling `requestRandomWordsInNative` and `fulfillRandomWords` returns early when `_requestInFlight` is true — A wrapper that fulfills synchronously in the same transaction leaves the raffle in `Status.Drawing`, though Chainlink VRF v2.5 fulfills asynchronously.
- **Prize delivery in `redeemWinningTicket` and `releaseSponsorPrize` uses `transferFrom` instead of `safeTransferFrom`** — `Raffle.redeemWinningTicket` — Code smells: `prizeToken.transferFrom` does not invoke `onERC721Received` on contract recipients — A contract recipient that relies on `onERC721Received` to record NFT deposits does not run its hook when claiming a prize.
- **Caller submits `requestDraw` with low gas price to delay VRF callback past `callbackDeadline`** — `Raffle.requestDraw` — Code smells: Permissionless `requestDraw` uses `tx.gasprice` inside `calculateRequestPriceNative` — An attacker calls `requestDraw` with a low gas price so VRF fulfillment arrives after `callbackDeadline`, though wrapper gas pricing is outside scope.

---

> ⚠️ This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)
