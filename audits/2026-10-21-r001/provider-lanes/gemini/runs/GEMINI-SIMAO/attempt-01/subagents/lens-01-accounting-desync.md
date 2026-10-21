## Working Notes & Mandatory Reasoning Protocol

### Phase 0 & Phase 1 — Protocol Vocabulary & Value-Moving Functions

`[Model: createRaffle]`
A sponsor supplies an NFT prize (`prizeToken`, `prizeTokenId`), a payout address (`sponsorRecipient`), a reserve entry threshold (`reserveEntries`), and a sale end timestamp (`endTime`). The factory increments `raffleCount`, deploys a new ERC-1167 clone of `raffleImplementation` using `CREATE`, initializes it, records `raffleById`, `idByRaffle`, and `isRaffle`, and transfers the prize NFT from the sponsor into the clone, activating the raffle (`Status.Active`).
*Spot where Solidity/EVM specifics matter*: `Clones.clone` uses `CREATE` (nonce-derived deterministic address), while `_validateCreateParams` and `_isProtocolDestination` only screen `isRaffle` on already-registered/deployed addresses (`destination.code.length != 0`).

`[Model: initialize]`
Called once on a freshly deployed raffle clone by the factory. Records `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime`, and sets `initialized = true` and `status = Status.AwaitingPrize` after screening `sponsor`, `protocolTreasury`, and `sponsorRecipient` against `_isProtocolDestination`.

`[Model: onERC721Received]`
When the configured `prizeToken` transfers `prizeTokenId` from `sponsor` into the raffle clone with `factory` as operator while `status == Status.AwaitingPrize`, the clone transitions `status` to `Status.Active`.

`[Model: buyEntries]`
A buyer pays `entryCount * 1,000,000` raw units of canonical 6-decimal USDC into the raffle before `endTime` while `status == Status.Active`. In return, ` recipient` receives one sequential ERC-721 ticket (`ticketId = ticketCount + 1`) representing the contiguous inclusive entry range `[totalEntries + 1, totalEntries + entryCount]`. Tracked totals updated: `totalEntries += entryCount`, `ticketCount += 1`, `_ticketRanges[ticketId] = {firstEntry, lastEntry}`, and `unsettledPot += entryCount * 1,000,000`.
*Spot where Solidity specifics matter*: `_safeMint(recipient, ticketId)` invokes `_update` (which checks `_isProtocolDestination(recipient, address(prizeToken))`) and only calls `onERC721Received` if `recipient.code.length > 0`.

`[Model: requestDraw]`
During `[endTime, endTime + 2 days)` when `status == Status.Active` and `totalEntries > 0`, any caller supplies native ETH covering the Chainlink VRF v2.5 wrapper fee. The raffle sets `status = Status.Drawing`, records `drawRequestedAt = block.timestamp` and `vrfRequestId`, pays `paidPrice` in native ETH to the wrapper, and refunds `msg.value - paidPrice` back to `msg.sender`.

`[Model: fulfillRandomWords]`
Before `drawRequestedAt + 2 days`, the Chainlink VRF wrapper delivers one random word for `vrfRequestId`. The raffle selects `winningEntry = (randomWords[0] % totalEntries) + 1`, sets `resolvedAt = block.timestamp`, and transitions `status` to `Status.NftWon` if `totalEntries >= reserveEntries` or `Status.CashWon` if `totalEntries < reserveEntries`. No quote-token or NFT liabilities are moved yet.

`[Model: enableRefunds]`
Transitions the raffle to `Status.Refunding` when: (a) `status == Status.Active && totalEntries == 0` (by `sponsor` before `endTime`, or anyone at `block.timestamp >= endTime`), (b) `status == Status.Active && totalEntries > 0 && block.timestamp >= endTime + 2 days`, or (c) `status == Status.Drawing && block.timestamp >= drawRequestedAt + 2 days`. Moves the entire `unsettledPot` into `remainingRefundLiability` and zeroes `unsettledPot`.

`[Model: _settleWinningTicket]`
In `Status.NftWon` or `Status.CashWon` when `!settlementComplete`, anyone supplies `ticketId` whose stored `_ticketRanges[ticketId]` contains `winningEntry`. Moves `unsettledPot` (`grossPot`) to `0`, sets `settlementComplete = true` and `winningTicketId = ticketId`, allocates `protocolFees = floor(grossPot * 500 / 10,000)`, and either allocates `sponsorProceeds = grossPot - protocolFees` (`NftWon`) or allocates `winnerProceeds = floor(grossPot * 8,000 / 10,000)` and `sponsorProceeds = grossPot - protocolFees - winnerProceeds` (`CashWon`).
*Spot where accounting drift occurs*: In `Status.NftWon`, `sponsorProceeds` (95% of buyer USDC) and `protocolFees` (5% of buyer USDC) are immediately credited and made withdrawable before verifying that the untrusted `prizeToken` can actually deliver `prizeTokenId` to the winner.

`[Model: redeemWinningTicket]`
In `Status.NftWon` or `Status.CashWon`, the current owner of `winningTicketId` (`msg.sender == ownerOf(ticketId)`) settles the ticket if not yet settled, records `winnerRecipient = winner` and `winnerRedeemed = true`, burns `ticketId`, and either sets `prizeClaimed = true` and transfers `prizeTokenId` to `winner` (`NftWon`) or zeroes `winnerProceeds` and transfers `winnerProceeds` USDC to `winner` (`CashWon`).

`[Model: refundTickets]`
In `Status.Refunding`, a ticket owner (`msg.sender == ownerOf(ticketId)`) burns a batch of 1 to 100 tickets, sums `lastEntry - firstEntry + 1` across the burned tickets, decrements `remainingRefundLiability` by `aggregateEntries * 1,000,000`, and receives that exact USDC amount.

`[Model: releaseSponsorProceeds]`
Anyone triggers payout of the current `sponsorProceeds` balance: zeroes `sponsorProceeds` and transfers that USDC amount to the immutable `sponsorRecipient` after checking `_isProtocolDestination(sponsorRecipient, address(prizeToken))`.

`[Model: releaseProtocolFees]`
Anyone triggers payout of the current `protocolFees` balance: zeroes `protocolFees` and transfers that USDC amount to the immutable `protocolTreasury` after checking `_isProtocolDestination(protocolTreasury, address(prizeToken))`.

`[Model: releaseSponsorPrize]`
In `Status.CashWon` or `Status.Refunding` when `!prizeClaimed`, anyone triggers return of the escrowed NFT: sets `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient` via `prizeToken.transferFrom`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.
*Spot where Solidity specifics matter*: Unlike `_transferQuote`, `releaseSponsorPrize` does NOT check `_isProtocolDestination(sponsorRecipient, address(prizeToken))` and uses unsafe `transferFrom` (not `safeTransferFrom`).

`[Model: _update]`
On every ticket mint, transfer, or burn, if `to != address(0)`, rejects `to` if `_isProtocolDestination(to, address(prizeToken))` returns `true`, then updates ERC-721 balances and ownership.

---

### Phase 2 & Phase 3 — Drilling Into Implicit Beliefs & Defeating Guards

`[Why: Raffle.sol:565]`
*Question*: Why does `_transferQuote` re-check `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` at payout time when `sponsorRecipient`, `protocolTreasury`, and every ticket `to` address were already screened by `_isProtocolDestination` in `initialize()` and `_update()`?
*Answer*: Because `_isProtocolDestination(destination, prizeToken_)` is NOT time-invariant! Specifically, `canonicalFactory.isRaffle(destination)` and `destination.code.length != 0` change over time as `RaffleFactory::createRaffle` deploys new clones. The code implicitly believes that re-checking `_isProtocolDestination` in `_transferQuote` safely prevents quote tokens from flowing into a newly created `Raffle` clone—failing to realize that (1) re-checking at payout time bricks an immutable `sponsorRecipient` or `protocolTreasury` and strands `sponsorProceeds`/`protocolFees` forever, and (2) `releaseSponsorPrize()` and `redeemWinningTicket()` omit this re-check entirely for the NFT prize!

`[Why: Raffle.sol:602]`
*Question*: Why does `_isProtocolDestination` guard `canonicalFactory.isRaffle(destination)` behind `if (!unsafeDestination && destination.code.length != 0)`?
*Answer*: The code assumes an address with `code.length == 0` is an EOA and can never be a protocol contract. That assumption is false for future `Raffle` clones deployed by `RaffleFactory::createRaffle` via `Clones.clone(raffleImplementation)` (`CREATE`), whose addresses are 100% deterministic from `address(factory)` and `factory`'s nonce before they have code.

`[Why: Raffle.sol:404]`
*Question*: Why does `releaseSponsorPrize()` call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` without checking `_isProtocolDestination(recipient, address(prizeToken))` and without `safeTransferFrom`?
*Answer*: The author used `transferFrom` so a contract `sponsorRecipient` cannot grief prize release by reverting in `onERC721Received`, and assumed `sponsorRecipient` was already permanently validated during `initialize()`. Because `futureRaffle` passes `initialize()` when `code.length == 0`, `releaseSponsorPrize()` later forces the NFT directly into `futureRaffle` (bypassing `futureRaffle.onERC721Received`), where `Raffle.sol:410` states it can never be rescued.

`[Why: Raffle.sol:334]`
*Question*: Why does `redeemWinningTicket` execute `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` only when the winner calls `redeemWinningTicket`, while `_settleWinningTicket` and `releaseSponsorProceeds` allow the sponsor to withdraw 95% of buyer USDC before `prizeClaimed == true`?
*Answer*: The code assumes that once `prizeToken.safeTransferFrom(sponsor, raffle, prizeTokenId)` succeeded during `createRaffle`, `prizeToken.transferFrom(raffle, winner, prizeTokenId)` is guaranteed to succeed later in `Status.NftWon`. Under `DESIGN.md` ("arbitrary prize contracts and ticket recipients are untrusted"), this assumption fails whenever the untrusted `prizeToken` blocks, pauses, or reverts transfers out of `raffle` after escrow.

`[Why: Raffle.sol:375]`
*Question*: Why does `releaseSponsorProceeds()` not check `if (status == Status.NftWon && !prizeClaimed) revert ...`?
*Answer*: To let the sponsor claim proceeds independently of when the winning ticket holder redeems. However, because `prizeToken` is untrusted, allowing `releaseSponsorProceeds()` before `prizeClaimed == true` in `Status.NftWon` lets a malicious sponsor drain 95% of the USDC pot while `redeemWinningTicket()` permanently reverts for the winner.

`[Why: RaffleFactory.sol:106]`
*Question*: Why does `RaffleFactory::createRaffle` use `Clones.clone(raffleImplementation)` (`CREATE`) while relying on `isRaffle[addr]` mapping lookups to prevent cross-clone asset movement?
*Answer*: The code assumes `isRaffle` is the complete set of all raffle clones that could ever be referenced, forgetting that `CREATE` addresses for future `raffleId`s are trivially precomputed from `(address(factory), nonce)` before `isRaffle[futureRaffle]` is set to `true`.

`[Defeat: _isProtocolDestination]`
1. Precompute `futureRaffle = addressFrom(factory, nonce = raffleCount + 2)` (the `CREATE` address of the next raffle clone). While `futureRaffle.code.length == 0`, call `createRaffle` for Raffle 1 with `sponsorRecipient = futureRaffle`; `_isProtocolDestination(futureRaffle, prizeToken)` returns `false` at `Raffle.sol:602`.
2. While `futureRaffle.code.length == 0`, call `Raffle1.buyEntries(futureRaffle, 10)` (or `Raffle1.transferFrom(buyer, futureRaffle, ticketId)`); `_isProtocolDestination(futureRaffle, prizeToken)` at `Raffle.sol:498` returns `false` and `_safeMint` skips `onERC721Received` because `futureRaffle.code.length == 0`.
3. Call `createRaffle` to deploy Raffle 2 at `futureRaffle`. Now `futureRaffle.code.length == 45` and `isRaffle[futureRaffle] == true`, so `_isProtocolDestination(futureRaffle, prizeToken)` flips to `true` inside Raffle 1.

`[Defeat: _validateCreateParams]`
1. Pass `params.sponsorRecipient = futureRaffle` (predicted `CREATE` address for `raffleCount + 2`) when creating Raffle 1 (`raffleCount + 1`); `isRaffle[futureRaffle]` at `RaffleFactory.sol:166` is `false`, so validation passes.
2. Pass a malicious ERC-721 contract as `params.prizeToken` that returns `true` for `supportsInterface(0x80ac58cd)` and allows `safeTransferFrom` into `raffle`, but reverts on `transferFrom` when `msg.sender == raffle` and `to != sponsorRecipient`.
3. Pass `protocolTreasury_ = computeCreateAddress(factory, 2)` at `RaffleFactory` deployment; constructor checks at `RaffleFactory.sol:80-90` pass, and when `createRaffle` is later called at nonce 2, `Raffle::initialize` reverts with `UnsafeProtocolDestination(protocolTreasury)` forever.

`[Defeat: releaseSponsorPrize]`
1. Create Raffle 1 with `sponsorRecipient = futureRaffle` (nonce of Raffle 2), cancel Raffle 1 via `enableRefunds()`, then create Raffle 2 at `futureRaffle`. Call `Raffle1.releaseSponsorPrize()`; `Raffle.sol:404` transfers Raffle 1's NFT into Raffle 2 via unsafe `transferFrom`, bypassing `Raffle2.onERC721Received` and locking the NFT forever.
2. In a `Status.CashWon` raffle where `sponsorRecipient = futureRaffle` and Raffle 2 is now deployed at `futureRaffle`, anyone calls `Raffle1.releaseSponsorPrize()` to permanently trap the prize NFT in Raffle 2 while `Raffle1.releaseSponsorProceeds()` reverts with `InvalidQuoteDestination(futureRaffle)`.
3. Deploy an untrusted `prizeToken` that reverts when transferring to `sponsorRecipient` after `Refunding`, blocking `releaseSponsorPrize()` (self-inflicted if sponsor deployed `prizeToken`).

`[Defeat: redeemWinningTicket]`
1. Sponsor deploys a custom `prizeToken` where `transferFrom(raffle, winner, prizeTokenId)` reverts unless `winner == sponsor`. Raffle reaches `Status.NftWon`. Sponsor calls `settleWinningTicket` and `releaseSponsorProceeds` to take 95% of buyer USDC; winner calls `redeemWinningTicket` which permanently reverts.
2. Buyer mints or transfers `ticketId = 1` in Raffle 1 to `futureRaffle` before Raffle 2 (`futureRaffle`) is deployed. Raffle 1 resolves with `winningTicketId = 1`. Because `futureRaffle` is a `Raffle` clone with no arbitrary call function, `msg.sender == ownerOf(1)` at `Raffle.sol:322` can never be satisfied, permanently locking the NFT (`NftWon`) or `winnerProceeds` (`CashWon`) in Raffle 1.
3. If `winner` is USDC-blacklisted in `Status.CashWon`, `redeemWinningTicket` reverts in `quoteToken.safeTransfer`, which the ticket holder can defeat by calling `Raffle.transferFrom(winner, freshAddress, winningTicketId)` first.

`[Defeat: refundTickets]`
1. Mint or transfer `ticketId = 1` (`10 entries = 10,000,000 USDC`) in Raffle 1 to `futureRaffle` before Raffle 2 (`futureRaffle`) is created. Deploy Raffle 2 at `futureRaffle`. Enable refunds on Raffle 1. Every other user refunds, leaving `remainingRefundLiability == 10,000,000` permanently stuck in Raffle 1 because `futureRaffle` cannot call `refundTickets`.
2. Pass duplicate ticket IDs `[1, 1]` to `refundTickets`: defeated by `_burn(1)` in the first loop iteration causing `ownerOf(1)` in the second iteration to revert with `ERC721NonexistentToken(1)`.
3. Pass 101 tickets in a single call: reverts with `InvalidTicketBatchSize(101, 100)`, requiring multiple batched calls.

`[Defeat: requestDraw]`
1. Call `requestDraw()` with a contract `msg.sender` whose `receive()` reverts when `excess > 0`: transaction reverts with `NativeRefundFailed`, leaving `status == Status.Active` so another caller can still call `requestDraw()`.
2. Force ETH into the `Raffle` clone via `selfdestruct` before `requestDraw()`: `paidPrice` is still compared against `msg.value` (`if (paidPrice > msg.value) revert`), and `excess` is computed as `msg.value - paidPrice`, so pre-existing ETH does not corrupt `excess` or brick `requestDraw()`.
3. Call `requestDraw()` at `block.timestamp == endTime + 2 days`: reverts with `DrawRequestWindowExpired`, cleanly handing over to `enableRefunds()`.

---

### Phase 4 — Closing Tests (`[LastOut: <lifecycle>]`)

`[LastOut: Reserve Met (NftWon)]`
Suppose Raffle 1 has `reserveEntries = 10`, and 10 entries are sold (`unsettledPot = 10,000,000` USDC). VRF resolves to `Status.NftWon`.
- **Normal case**: `_settleWinningTicket` sets `unsettledPot = 0`, `protocolFees = 500,000`, `sponsorProceeds = 9,500,000`, `winnerProceeds = 0`. `releaseProtocolFees()` pays `500,000` USDC, `releaseSponsorProceeds()` pays `9,500,000` USDC (`500,000 + 9,500,000 == 10,000,000`), and `redeemWinningTicket()` transfers `prizeTokenId` to the winner. The last claimant out is paid in full with `0` shortfall.
- **Desync / Stuck case 1 (`sponsorRecipient == futureRaffle`)**: After Raffle 2 is deployed at `futureRaffle`, `releaseProtocolFees()` pays `500,000` USDC and `redeemWinningTicket()` delivers the NFT, but the last USDC claimant out (`releaseSponsorProceeds()`) reverts with `InvalidQuoteDestination(futureRaffle)` at `Raffle.sol:565`, leaving `9,500,000` USDC (`sponsorProceeds`) permanently locked in Raffle 1.
- **Desync / Stuck case 2 (Untrusted `prizeToken` reverts on delivery)**: `releaseProtocolFees()` pays `500,000` USDC and `releaseSponsorProceeds()` pays `9,500,000` USDC to the sponsor, leaving `0` USDC in Raffle 1 while the last claimant out—the winning ticket holder calling `redeemWinningTicket()`—permanently reverts on `prizeToken.transferFrom`, losing the NFT while all buyers lost `10,000,000` USDC.

`[LastOut: Reserve Missed (CashWon)]`
Suppose Raffle 1 has `reserveEntries = 10`, and 5 entries are sold (`unsettledPot = 5,000,000` USDC). VRF resolves to `Status.CashWon`.
- **Normal case**: `_settleWinningTicket` sets `unsettledPot = 0`, `protocolFees = 250,000` (5%), `winnerProceeds = 4,000,000` (80%), `sponsorProceeds = 750,000` (15%). Sum = `250,000 + 4,000,000 + 750,000 == 5,000,000`. Regardless of withdrawal order (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`), the last user out receives their exact allocation and `accountedQuoteBalance()` reaches `0`.
- **Desync / Stuck case (`sponsorRecipient == futureRaffle` or `winningTicketId` owned by `futureRaffle`)**: Once Raffle 2 is deployed at `futureRaffle`, `releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(futureRaffle)` (locking `750,000` USDC), `releaseSponsorPrize()` transfers the prize NFT into Raffle 2 via unsafe `transferFrom` (permanently locking the NFT inside Raffle 2), and if `winningTicketId` was minted/transferred to `futureRaffle` before Raffle 2 was deployed, `4,000,000` USDC (`winnerProceeds`) is permanently locked in Raffle 1 because `futureRaffle` cannot call `redeemWinningTicket`.

`[LastOut: Refund Path (Refunding)]`
Suppose 3 buyers purchase tickets of 1, 3, and 6 entries (`unsettledPot = 10,000,000` USDC). `enableRefunds()` sets `unsettledPot = 0` and `remainingRefundLiability = 10,000,000`.
- **Normal case**: Each ticket owner calls `refundTickets` in any order, burning their ticket and claiming `1,000,000`, `3,000,000`, and `6,000,000` USDC respectively. The last user out receives their full refund (`remainingRefundLiability` reaches `0`), and `releaseSponsorPrize()` returns the NFT to `sponsorRecipient`.
- **Desync / Stuck case (`sponsorRecipient == futureRaffle` or ticket owned by `futureRaffle`)**: Once Raffle 2 is deployed at `futureRaffle`, calling `releaseSponsorPrize()` transfers the prize NFT directly into Raffle 2 where it is permanently unrescuable, and any ticket minted/transferred to `futureRaffle` prior to Raffle 2's deployment can never call `refundTickets`, leaving its `remainingRefundLiability` permanently locked in Raffle 1.

---

FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: accounting-desync | group_key: Raffle | _settleWinningTicket | accounting-desync
root_cause: In `Raffle.sol:554` (`_settleWinningTicket`) and `Raffle.sol:375-382` (`releaseSponsorProceeds`), when `status == Status.NftWon`, `sponsorProceeds` (95% of `unsettledPot`) and `protocolFees` (5% of `unsettledPot`) are credited and made immediately withdrawable without requiring `prizeClaimed == true` (before verifying that the untrusted `prizeToken` actually delivers `prizeTokenId` to the winner in `redeemWinningTicket` at `Raffle.sol:334-337`).
internal_pre: None
external_pre: None
path:
  1. Malicious `sponsor` deploys an untrusted ERC-721 `prizeToken` (which `DESIGN.md` explicitly classifies as untrusted: "arbitrary prize contracts and ticket recipients are untrusted") where `transferFrom(from, to, tokenId)` succeeds when `to` is a `Raffle` clone (or `from == sponsor`), but reverts (or no-ops) when `from` is a `Raffle` clone and `to != sponsorRecipient`.
  2. `sponsor` calls `RaffleFactory::createRaffle` with `prizeToken`, `prizeTokenId = 1`, `reserveEntries = 10`, `endTime = block.timestamp + 1 days`. `prizeToken.safeTransferFrom(sponsor, raffle, 1)` succeeds and `raffle` enters `Status.Active`.
  3. Honest users call `buyEntries` to purchase 100 entries for `100,000,000` USDC (`100 USDC`), setting `totalEntries = 100` and `unsettledPot = 100,000,000`.
  4. At `endTime`, `requestDraw()` and `rawFulfillRandomWords()` execute; because `totalEntries (100) >= reserveEntries (10)`, `status` becomes `Status.NftWon`.
  5. `sponsor` immediately calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()`, withdrawing `95,000,000` USDC (`95%` of the pot), while `releaseProtocolFees()` withdraws `5,000,000` USDC (`5%` of the pot), reducing the raffle's USDC balance to `0`.
  6. The winning ticket owner calls `redeemWinningTicket(winningTicketId)`; `prizeToken.transferFrom(address(this), winner, 1)` at `Raffle.sol:334` (or `ownerOf` check at `Raffle.sol:335`) reverts. Because `status` is terminally fixed at `Status.NftWon`, `enableRefunds()` is unreachable.
impact: Ticket buyers lose 100% of their deposited USDC (`100,000,000` USDC in the example: `95,000,000` USDC stolen by the malicious `sponsor` and `5,000,000` USDC sent to `protocolTreasury`), and the winning ticket holder is left holding an unredeemable ticket with zero USDC and no NFT prize.
mitigation: In `Raffle::releaseSponsorProceeds` (`Raffle.sol:375`) and `Raffle::releaseProtocolFees` (`Raffle.sol:385`), require `if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);` so proceeds from an `NftWon` raffle cannot be swept until `redeemWinningTicket` has verified delivery of the untrusted `prizeToken` to the winner (or provide a timeout fallback to `Status.Refunding` if `prizeClaimed` remains `false`).

FINDING | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-check | group_key: Raffle | releaseSponsorPrize | missing-check
root_cause: In `Raffle.sol:602` (`_isProtocolDestination`) and `RaffleFactory.sol:166` (`_validateCreateParams`), `isRaffle` screening only checks already-deployed clones (`destination.code.length != 0`), while `RaffleFactory::createRaffle` (`RaffleFactory.sol:106`) deploys clones at deterministic `CREATE` addresses; furthermore, `Raffle::releaseSponsorPrize` (`Raffle.sol:404`) omits `_isProtocolDestination(recipient, address(prizeToken))` before calling `prizeToken.transferFrom(address(this), recipient, prizeTokenId)`.
internal_pre: None
external_pre: None
path:
  1. When `raffleCount == 0` (`RaffleFactory` nonce is 2), a sponsor computes the deterministic `CREATE` address for Raffle 2 at `RaffleFactory` nonce 3 (`futureRaffle`). Because `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false`, the sponsor creates Raffle 1 (deployed at nonce 2) with `sponsorRecipient = futureRaffle` and `prizeTokenId = 1`.Both `RaffleFactory::_validateCreateParams` and `Raffle::initialize` pass.
  2. Any user creates Raffle 2 via `RaffleFactory::createRaffle`, which deploys Raffle 2 at `futureRaffle` (nonce 3) and sets `isRaffle[futureRaffle] = true`.
  3. Raffle 1 resolves to `Status.CashWon` (e.g., 5 entries sold for `5,000,000` USDC when `reserveEntries = 10`) or enters `Status.Refunding`.
  4. Anyone calls permissionless `Raffle1.settleWinningTicket(winningTicketId)` and `Raffle1.releaseSponsorPrize()`. Because `Raffle1.releaseSponsorPrize()` (`Raffle.sol:404`) does not check `_isProtocolDestination(sponsorRecipient, address(prizeToken))` and uses unsafe `transferFrom`, `prizeTokenId = 1` is transferred directly from Raffle 1 into Raffle 2 (`futureRaffle`), bypassing `Raffle2.onERC721Received`.
  5. Anyone calls `Raffle1.releaseSponsorProceeds()`. `_transferQuote` (`Raffle.sol:565`) re-evaluates `_isProtocolDestination(futureRaffle, address(prizeToken))`, which now returns `true` because `futureRaffle.code.length != 0` and `isRaffle[futureRaffle] == true`, reverting with `InvalidQuoteDestination(futureRaffle)`.
impact: Violates `DESIGN.md` ("Never move assets between raffle clones"). The sponsor is left holding the loss: `prizeTokenId = 1` is transferred into Raffle 2 where it is permanently locked outside protocol accounting with no rescue path (`Raffle.sol:410`), and `sponsorProceeds` (`750,000` USDC in `CashWon`, or `95%` of the pot in `NftWon`) is permanently locked in Raffle 1 because `releaseSponsorProceeds()` always reverts, preventing `accountedQuoteBalance()` from ever reaching 0.
mitigation: In `Raffle::releaseSponsorPrize` (`Raffle.sol:403`) and `Raffle::redeemWinningTicket` (`Raffle.sol:334`), check `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` (or deploy clones via `Clones.cloneDeterministic` with a `keccak256(abi.encode(msg.sender, raffleId, block.timestamp, ...))` salt and require `sponsorRecipient` / ticket recipients not to be uncreated clones).

FINDING | contract: Raffle | function: _update | bug_class: accounting-desync | group_key: Raffle | _update | accounting-desync
root_cause: In `Raffle.sol:498` (`_update`) and `Raffle.sol:602` (`_isProtocolDestination`), `_isProtocolDestination(to, address(prizeToken))` skips `canonicalFactory.isRaffle(to)` when `to.code.length == 0`, allowing tickets to be minted (`buyEntries`) or transferred (`transferFrom`) to a deterministic future `Raffle` clone address (`CREATE` from `RaffleFactory`) before that clone is deployed.
internal_pre: None
external_pre: None
path:
  1. Raffle 1 is active (`raffleCount == 1`, `RaffleFactory` nonce is 2). Buyer computes `futureRaffle`, the deterministic `CREATE` address of `RaffleFactory` at nonce 3.
  2. Buyer calls `Raffle1.buyEntries(futureRaffle, 10)` paying `10,000,000` USDC (`10 USDC`). Because `futureRaffle.code.length == 0`, `_isProtocolDestination(futureRaffle, address(prizeToken))` returns `false` at `Raffle.sol:602` and `ERC721Utils.checkOnERC721Received` treats `futureRaffle` as an EOA, minting `ticketId = 1` (`[1, 10]`) to `futureRaffle`.
  3. A second sponsor calls `RaffleFactory::createRaffle`, deploying Raffle 2 at `futureRaffle` (nonce 3) and setting `isRaffle[futureRaffle] = true`.
  4. Raffle 1 resolves to `Status.NftWon`, `Status.CashWon`, or `Status.Refunding`. Because `ownerOf(1) == futureRaffle` (Raffle 2) and `Raffle` has no function to call `redeemWinningTicket` or `refundTickets` on another raffle, `msg.sender == ownerOf(1)` in `redeemWinningTicket` (`Raffle.sol:322`) and `refundTickets` (`Raffle.sol:361`) can never be satisfied.
impact: A canonical `Raffle` clone becomes the owner of a bearer ticket (`isRaffle[ownerOf(1)] == true`), breaking the invariant in `Raffle.sol:491` ("Known protocol sinks are rejected before their ownership could make a claim unreachable"). Depending on outcome, the ticket holder / Raffle 1 is left with `winnerProceeds` (`8,000,000` USDC in `CashWon`), the escrowed prize NFT (in `NftWon`), or `remainingRefundLiability` (`10,000,000` USDC in `Refunding`) permanently locked in Raffle 1, and `accountedQuoteBalance()` can never be settled to 0.
mitigation: Deploy clones in `RaffleFactory::createRaffle` (`RaffleFactory.sol:106`) using `Clones.cloneDeterministic` with a salt committing to `msg.sender` and creation parameters, or prevent `_isProtocolDestination` bypass by disallowing `CREATE`-predictable factory clone addresses.

LEAD | contract: RaffleFactory | function: constructor | bug_class: missing-check | group_key: RaffleFactory | constructor | missing-check
smell: `RaffleFactory::constructor` (`RaffleFactory.sol:80-90`) checks `protocolTreasury_` against `address(this)`, `quoteToken_`, `vrfWrapper_`, and `raffleImplementation`, but cannot check if `protocolTreasury_` collides with a future `CREATE` clone address of `RaffleFactory` (or a `prizeToken` used in a future raffle).
unverified: Requires the factory deployer to configure `protocolTreasury_` to an address that later collides with a `Clones.clone` address or a prospective `prizeToken`.
description: If `protocolTreasury` equals a future `RaffleFactory` `CREATE` address at nonce `k + 1`, all raffles `1..k-1` succeed until `raffleId = k` is reached, at which point `Raffle::initialize` (`Raffle.sol:190`) permanently reverts with `UnsafeProtocolDestination(protocolTreasury)` on every subsequent `createRaffle` call, bricking the factory.

