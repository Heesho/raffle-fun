# Run 1 — solidity-auditor

<!--RUN pass=1 of=1 stamp=20261021-005946 sha=9238b6c agents=12/12-->

Pass 1 of 1 · 2026-10-21 · `9238b6c` · 12/12 agents returned.

## Findings

<!--F key=rafflefactory|createraffle|fake-prize-escrow conf=90 kind=FINDING agents=8-->

[90] **1. A false prize contract fabricates escrow and delivery**

`RaffleFactory.createRaffle` · Confidence: 90

**Description**
A sponsor can fake prize custody, reject or fake delivery, take 95% of sales, and leave the winner without a transferable NFT.

**Fix**

```diff
diff --git a/target/packages/contracts/src/RaffleFactory.sol b/target/packages/contracts/src/RaffleFactory.sol
--- a/target/packages/contracts/src/RaffleFactory.sol
+++ b/target/packages/contracts/src/RaffleFactory.sol
@@
     /// @inheritdoc IRaffleFactory
     address public immutable override raffleImplementation;
 
+    mapping(address prizeToken => bool allowed) private _prizeAllowlist;
+
     /// @inheritdoc IRaffleFactory
     uint256 public override raffleCount;
@@
-    constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
+    constructor(
+        address quoteToken_,
+        address vrfWrapper_,
+        address protocolTreasury_,
+        address[] memory prizeAllowlist_
+    ) {
         _requireContract(quoteToken_);
         _requireContract(vrfWrapper_);
         if (protocolTreasury_ == address(0)) revert ZeroAddress();
@@
         quoteToken = quoteToken_;
         vrfWrapper = vrfWrapper_;
         protocolTreasury = protocolTreasury_;
 
+        uint256 allowedPrizeCount = prizeAllowlist_.length;
+        for (uint256 index; index < allowedPrizeCount; ++index) {
+            address allowedPrize = prizeAllowlist_[index];
+            _requireContract(allowedPrize);
+            _prizeAllowlist[allowedPrize] = true;
+        }
+
         address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
@@
     function _validateCreateParams(CreateRaffleParams calldata params) private view {
         _requireContract(params.prizeToken);
+        if (!_prizeAllowlist[params.prizeToken]) revert UnsupportedPrizeToken(params.prizeToken);
         if (params.sponsorRecipient == address(0)) revert ZeroAddress();
```

<!--/F-->

<!--F key=raffle|releasesponsorproceeds|payout-before-prize-delivery conf=90 kind=FINDING agents=9-->

[90] **2. The raffle exposes sponsor proceeds before prize delivery**

`Raffle.releaseSponsorProceeds` · Confidence: 90

**Description**
A sponsor can use a prize that accepts escrow but rejects delivery, then take 95% and leave the winner without an NFT or refund.

**Fix (Option A — gate the sponsor payout)**:

```diff
diff --git a/target/packages/contracts/src/Raffle.sol b/target/packages/contracts/src/Raffle.sol
--- a/target/packages/contracts/src/Raffle.sol
+++ b/target/packages/contracts/src/Raffle.sol
@@
     /// @notice Raised when native currency is sent outside the payable draw-request path.
     error DirectNativeTransfer();
 
+    error PrizeNotDelivered();
+
@@
     function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !winnerRedeemed) revert PrizeNotDelivered();
         amount = sponsorProceeds;
```

**Fix (Option B — gate both payouts)**:

```diff
diff --git a/target/packages/contracts/src/Raffle.sol b/target/packages/contracts/src/Raffle.sol
--- a/target/packages/contracts/src/Raffle.sol
+++ b/target/packages/contracts/src/Raffle.sol
@@
     /// @notice Raised when native currency is sent outside the payable draw-request path.
     error DirectNativeTransfer();
 
+    error PrizeNotDelivered();
+
@@
     function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !winnerRedeemed) revert PrizeNotDelivered();
         amount = sponsorProceeds;
@@
     function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !winnerRedeemed) revert PrizeNotDelivered();
         amount = protocolFees;
```

**Fix (Option C — hold payouts and open refunds)**:

```diff
diff --git a/target/packages/contracts/src/libraries/RaffleConstants.sol b/target/packages/contracts/src/libraries/RaffleConstants.sol
--- a/target/packages/contracts/src/libraries/RaffleConstants.sol
+++ b/target/packages/contracts/src/libraries/RaffleConstants.sol
@@
     /// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
     uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;
 
+    /// @notice Maximum time allowed for delivery of an NFT prize after resolution.
+    uint256 internal constant PRIZE_DELIVERY_TIMEOUT = 2 days;
+
diff --git a/target/packages/contracts/src/Raffle.sol b/target/packages/contracts/src/Raffle.sol
--- a/target/packages/contracts/src/Raffle.sol
+++ b/target/packages/contracts/src/Raffle.sol
@@
     /// @notice Raised when native currency is sent outside the payable draw-request path.
     error DirectNativeTransfer();
 
+    error PrizeNotDelivered();
+
@@
     function enableRefunds() external override nonReentrant {
+        Status currentStatus = status;
         uint256 deadline;
 
-        if (status == Status.Active) {
+        if (currentStatus == Status.Active) {
             if (totalEntries == 0) {
                 deadline = endTime;
                 if (msg.sender != sponsor && block.timestamp < deadline) {
@@
-        } else if (status == Status.Drawing) {
+        } else if (currentStatus == Status.Drawing) {
             deadline = callbackDeadline();
             if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
+        } else if (currentStatus == Status.NftWon && !winnerRedeemed) {
+            deadline = uint256(resolvedAt) + RaffleConstants.PRIZE_DELIVERY_TIMEOUT;
+            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
         } else {
-            revert InvalidStatus(status);
+            revert InvalidStatus(currentStatus);
         }
 
-        uint256 liability = unsettledPot;
-        unsettledPot = 0;
+        uint256 liability;
+        if (currentStatus == Status.NftWon) {
+            liability = sponsorProceeds + protocolFees;
+            sponsorProceeds = 0;
+            protocolFees = 0;
+        } else {
+            liability = unsettledPot;
+            unsettledPot = 0;
+        }
         remainingRefundLiability = liability;
         status = Status.Refunding;
@@
     function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !winnerRedeemed) revert PrizeNotDelivered();
         amount = sponsorProceeds;
@@
     function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !winnerRedeemed) revert PrizeNotDelivered();
         amount = protocolFees;
```

<!--/F-->

## Leads

