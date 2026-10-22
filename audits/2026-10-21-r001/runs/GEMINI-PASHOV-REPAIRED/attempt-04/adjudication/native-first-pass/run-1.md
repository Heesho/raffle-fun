# Run 1 — solidity-auditor

<!--RUN pass=1 of=1 stamp=2026-10-21-explicit-high-a04 sha=none agents=12/12-->

Pass 1 of 1 · 2026-10-21 · `none` · 12/12 agents returned.

## Findings

<!--F key=raffle|releasesponsorproceeds|premature-sponsor-payout conf=90 kind=FINDING agents=2-->

[90] **releaseSponsorProceeds pays the sponsor before redeemWinningTicket delivers the prize**

`Raffle.releaseSponsorProceeds` · Confidence: 90

**Description**
A sponsor whose prizeToken blocks transfers after escrow can call releaseSponsorProceeds to take 95% of the pot while redeemWinningTicket fails.

**Fix**

```diff
 function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);
     amount = sponsorProceeds;
     if (amount == 0) revert NoSponsorProceeds();
```

<!--/F-->

<!--F key=raffle|-settlewinningticket|premature-sponsor-proceeds-release conf=90 kind=FINDING agents=1-->

[90] **_settleWinningTicket allocates sponsorProceeds before the winner claims the prize**

`Raffle._settleWinningTicket` · Confidence: 90

**Description**
A sponsor can call settleWinningTicket and releaseSponsorProceeds to take the quote tokens even when prizeToken blocks the prize transfer in redeemWinningTicket.

**Fix**

```diff
 function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);
     amount = sponsorProceeds;
     if (amount == 0) revert NoSponsorProceeds();
     sponsorProceeds = 0;
     address recipient = sponsorRecipient;
     _transferQuote(recipient, amount);
     emit SponsorProceedsReleased(msg.sender, recipient, amount);
 }

 function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);
     amount = protocolFees;
     if (amount == 0) revert NoProtocolFees();
```

<!--/F-->

<!--F key=raffle|buyentries|sponsor-rebate-ticket-dilution conf=90 kind=FINDING agents=2-->

[90] **buyEntries lets the sponsor buy entries to dilute buyers or force NftWon**

`Raffle.buyEntries` · Confidence: 90

**Description**
The sponsor can call buyEntries to cross reserveEntries into NftWon and recover 95% through releaseSponsorProceeds, so the sponsor dilutes other buyers.

**Fix (Option A — restrict)**:

```diff
 if (entryCount == 0) revert ZeroEntryCount();
+if (msg.sender == sponsor || msg.sender == sponsorRecipient || recipient == sponsor || recipient == sponsorRecipient) {
+    revert InvalidRecipient();
+}
-if (entryCount > type(uint128).max - totalEntries) {
+if (entryCount > reserveEntries - totalEntries) {
     revert TotalEntriesOverflow(totalEntries, entryCount);
 }
```

**Fix (Option B — ban-path)**:

```diff
 if (recipient == address(0)) revert InvalidRecipient();
+if (msg.sender == sponsor || msg.sender == sponsorRecipient || recipient == sponsor || recipient == sponsorRecipient) {
+    revert InvalidRecipient();
+}
 if (entryCount == 0) revert ZeroEntryCount();
```

<!--/F-->

<!--F key=raffle|-settlewinningticket|sponsor-rebate-entry-dilution conf=90 kind=FINDING agents=1-->

[90] **_settleWinningTicket pays the sponsor 95% of entries bought above reserveEntries**

`Raffle._settleWinningTicket` · Confidence: 90

**Description**
The sponsor can buy entries in buyEntries and receive ninety-five percent back in _settleWinningTicket, so the sponsor dilutes other buyers at a five-percent cost.

**Fix**

```diff
 if (result == Status.NftWon) {
-    sponsorAmount = grossPot - protocolFee;
+    uint256 maxSponsorGross = Math.min(grossPot, uint256(reserveEntries) * ENTRY_PRICE);
+    protocolFee = grossPot - Math.mulDiv(maxSponsorGross, RaffleConstants.BPS - RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
+    sponsorAmount = grossPot - protocolFee;
 } else {
```

<!--/F-->

<!--F key=rafflefactory|createraffle|unbounded-reserve-entries conf=85 kind=FINDING agents=2-->

[85] **createRaffle accepts an unreachable reserveEntries that forces CashWon**

`RaffleFactory.createRaffle` · Confidence: 85

**Description**
A sponsor can set an unreachable reserveEntries in createRaffle, so the raffle resolves to CashWon and the sponsor takes 15% plus the prize.

**Fix (Option A — validate)**:

```diff
 if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
-if (params.reserveEntries == 0) revert ZeroReserveEntries();
+if (params.reserveEntries == 0 || params.reserveEntries > RaffleConstants.MAX_RESERVE_ENTRIES) {
+    revert ZeroReserveEntries();
+}
```

**Fix (Option B — restrict)**:

```diff
     cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
-    sponsorAmount = grossPot - protocolFee - cashAmount;
+    protocolFee = grossPot - cashAmount;
+    sponsorAmount = 0;
     winnerProceeds = cashAmount;
```

<!--/F-->

<!--F key=rafflefactory|-validatecreateparams|unbounded-reserve-entries conf=85 kind=FINDING agents=2-->

[85] **_validateCreateParams sets no upper limit on reserveEntries**

`RaffleFactory._validateCreateParams` · Confidence: 85

**Description**
A sponsor can set reserveEntries above the quoteToken supply, so Status.NftWon is impossible and the sponsor takes fifteen percent plus the prize.

**Fix**

```diff
 if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
-if (params.reserveEntries == 0) revert ZeroReserveEntries();
+if (params.reserveEntries == 0 || params.reserveEntries > RaffleConstants.MAX_RESERVE_ENTRIES) {
+    revert ZeroReserveEntries();
+}
```

<!--/F-->

<!--F key=raffle|enablerefunds|empty-raffle-cancel-block conf=75 kind=FINDING agents=4-->

[75] **enableRefunds reverts before endTime when an attacker buys one entry**

`Raffle.enableRefunds` · Confidence: 75

**Description**
An attacker can buy one entry before the sponsor calls enableRefunds, so enableRefunds fails and the contract holds the prize until the sale ends.

**Fix (Option A — allow-and-handle)**:

```diff
 if (status == Status.Active) {
-    if (totalEntries == 0) {
+    if (totalEntries == 0 || (msg.sender == sponsor && totalEntries < reserveEntries)) {
         deadline = endTime;
         if (msg.sender != sponsor && block.timestamp < deadline) {
             revert RefundsNotAvailable(deadline, block.timestamp);
         }
     } else {
```

**Fix (Option B — restrict)**:

```diff
 function buyEntries(address recipient, uint128 entryCount)
     external
     override
     nonReentrant
     returns (uint256 ticketId)
 {
     _requireStatus(Status.Active);
+    if (block.timestamp < startTime) revert InvalidStatus(status);
     if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
```

<!--/F-->

<!--F key=raffle|releasesponsorprize|unsafe-prize-nft-transfer conf=75 kind=FINDING agents=2-->

[75] **releaseSponsorPrize sends the prize via transferFrom without an ERC-721 receiver check**

`Raffle.releaseSponsorPrize` · Confidence: 75

**Description**
Any caller can call releaseSponsorPrize to send the prize via transferFrom to a contract sponsorRecipient that cannot transfer ERC-721 tokens.

**Fix**

```diff
 address recipient = sponsorRecipient;
 prizeClaimed = true;
-prizeToken.transferFrom(address(this), recipient, prizeTokenId);
+try prizeToken.safeTransferFrom(address(this), recipient, prizeTokenId) {} catch {
+    recipient = sponsor;
+    prizeToken.safeTransferFrom(address(this), recipient, prizeTokenId);
+}
 if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
```

<!--/F-->

<!--F key=raffle|requestdraw|uncompensated-vrf-fee-asymmetry conf=75 kind=FINDING agents=1-->

[75] **requestDraw charges the caller the VRF fee and allows CashWon draws**

`Raffle.requestDraw` · Confidence: 75

**Description**
The caller of requestDraw pays the VRF fee without reimbursement, so the sponsor can force CashWon or withhold the draw when the prize appreciates.

**Fix**

```diff
 if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
-if (totalEntries == 0) revert NoEntriesSold();
+if (totalEntries < reserveEntries) revert NoEntriesSold();
```

<!--/F-->

## Leads

<!--F key=raffle|-isprotocoldestination|future-clone-sink-bypass kind=LEAD agents=8-->

- **_isProtocolDestination accepts a future clone address before deployment** — `Raffle._isProtocolDestination` — Code smells: _isProtocolDestination checks destination.code.length and isRaffle only at call time, while releaseSponsorPrize skips _isProtocolDestination. — A caller can pass a future clone address before createRaffle deploys that clone, so _transferQuote later reverts. We did not find a path that harms another user.

<!--/F-->

<!--F key=raffle|requestdraw|premature-in-flight-flag-reset kind=LEAD agents=2-->

- **requestDraw clears _requestInFlight before the native refund call** — `Raffle.requestDraw` — Code smells: requestDraw sets _requestInFlight to false before the low-level native refund call to msg.sender, and rawFulfillRandomWords has no reentrancy lock. — The function clears _requestInFlight before the refund call, so a callback in that call can resolve the draw early. We did not verify a synchronous wrapper.

<!--/F-->

<!--F key=raffle|requestdraw|single-shot-vrf-request kind=LEAD agents=1-->

- **requestDraw allows only one VRF request without a retry path** — `Raffle.requestDraw` — Code smells: requestDraw sets status to Status.Drawing with no retry path if the wrapper misses callbackDeadline, and the caller loses the native fee. — A caller who pays for requestDraw loses the native fee if the wrapper misses callbackDeadline. We did not find a way for an attacker to force this timeout.

<!--/F-->

<!--F key=raffle|releasesponsorproceeds|immutable-recipient-usdc-blacklist kind=LEAD agents=1-->

- **releaseSponsorProceeds sends funds only to the immutable sponsorRecipient** — `Raffle.releaseSponsorProceeds` — Code smells: sponsorRecipient and protocolTreasury are immutable and have no fallback recipient if quoteToken blocks them. — The quoteToken issuer can block the immutable sponsorRecipient or protocolTreasury and lock those payouts forever. This path requires an external action by the token issuer.

<!--/F-->

<!--F key=raffle|fulfillrandomwords|synchronous-vrf-callback-ignored kind=LEAD agents=1-->

- **fulfillRandomWords ignores a synchronous callback while _requestInFlight is true** — `Raffle.fulfillRandomWords` — Code smells: requestDraw sets _requestInFlight to true before requestRandomnessPayInNative, and fulfillRandomWords returns early without a revert while _requestInFlight is true. — A VRF wrapper that calls rawFulfillRandomWords inside requestRandomnessPayInNative leaves the raffle in Status.Drawing. The production Chainlink wrapper fulfills in a later block.

<!--/F-->

<!--F key=raffle|getvrfrequestprice|zero-gasprice-quote-mismatch kind=LEAD agents=1-->

- **getVrfRequestPrice returns a zero-gas quote in off-chain view calls** — `Raffle.getVrfRequestPrice` — Code smells: getVrfRequestPrice calls calculateRequestPriceNative with tx.gasprice, which is zero in an off-chain view call and positive inside requestDraw. — An integrator that reads getVrfRequestPrice with a zero gas price sends too little value to requestDraw, so the call reverts. Callers can use estimateVrfRequestPrice instead.

<!--/F-->

<!--F key=raffle|initialize|asymmetric-input-validation kind=LEAD agents=1-->

- **initialize checks _isProtocolDestination on sponsor unlike _validateCreateParams** — `Raffle.initialize` — Code smells: _validateCreateParams checks only prizeToken and sponsorRecipient, while initialize also runs _isProtocolDestination on sponsor. — The initialize function applies _isProtocolDestination to sponsor and rejects a prizeToken contract as sponsor. We did not find a path that harms active raffles.

<!--/F-->

<!--F key=rafflefactory|constructor|future-clone-treasury-collision kind=LEAD agents=1-->

- **RaffleFactory constructor does not check protocolTreasury against future clone addresses** — `RaffleFactory.constructor` — Code smells: The constructor checks protocolTreasury_ against address(this), quoteToken_, vrfWrapper_, and raffleImplementation, but it does not check future CREATE clone addresses. — A deployer who sets protocolTreasury_ to a future clone address makes createRaffle revert when the factory nonce reaches that address. This requires a bad deployment input.

<!--/F-->
