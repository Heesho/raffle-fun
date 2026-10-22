### Phase 0–4 — Money Map, Lifecycles, and Lens 8 (Denial of Service & Griefing) Working Analysis

---

#### Lifecycle 1: Creation & Escrow (`RaffleFactory::createRaffle` → `Raffle::initialize` → `Raffle::onERC721Received`)

`[Model: RaffleFactory::createRaffle]`
A sponsor supplies an NFT prize they currently own, a payout recipient address, a minimum entry threshold (`reserveEntries`), and a sale end timestamp. The factory increments its lifetime raffle counter (`raffleCount`) by 1, deploys a new raffle clone, configures it, records the clone in its directory (`raffleById`, `idByRaffle`, `isRaffle`), moves the sponsor's NFT into the new raffle clone, and checks that the raffle clone now holds the NFT and is in the active state. In return, the sponsor receives a live raffle contract that will either pay them 95% of ticket sales (if the reserve is met) or return their NFT (plus 15% of ticket sales if a draw occurred below the reserve).

`[Model: Raffle::initialize]`
The factory passes the new raffle clone its fixed configuration: sponsor address, sponsor payout recipient, protocol treasury recipient, prize NFT contract and token ID, raffle identifier, reserve threshold, and sale end time. Nothing of monetary value moves yet; the clone marks itself initialized (`initialized = true`) and enters the waiting-for-prize state (`status = AwaitingPrize`).

`[Model: Raffle::onERC721Received]`
When the prize NFT arrives at the raffle clone from the sponsor via the factory while the raffle is waiting for its prize (`status == AwaitingPrize`), the raffle accepts the NFT and switches its state to active (`status = Active`) so entry purchases can begin.

`[Why: Raffle.sol:177-178]`
Why does the `Raffle` implementation constructor set `initialized = true` and `status = Status.Refunding` on the implementation contract itself?
If someone called `initialize` directly on the implementation contract, they would become the `sponsor` of the implementation; setting `initialized = true` blocks that, and setting `status = Status.Refunding` ensures the implementation cannot accept entries (`buyEntries`), draw requests (`requestDraw`), or prize deposits (`onERC721Received`), while `refundTickets` and `releaseSponsorPrize` revert because no tickets or prize exist on the implementation. The implicit belief is that no state-changing function on the implementation can ever succeed in `Status.Refunding` when `ticketCount == 0` and `prizeToken == address(0)`.

`[Why: RaffleFactory.sol:742-758]`
Why does `RaffleFactory::createRaffle` call `IRaffle(raffle).initialize(...)` before setting `isRaffle[raffle] = true` at line 758?
Because `createRaffle` initializes the clone before registering it in the factory mappings. The implicit belief is that `Raffle::initialize` does not need `isRaffle[raffle]` to be `true` during initialization because `_isProtocolDestination` explicitly checks `destination == address(this)`, and that no future raffle clone address (`raffleById[k]` for `k > raffleId`) could be passed as `sponsor`, `sponsorRecipient`, or `protocolTreasury`.

`[Why: Raffle.sol:615-617]`
Why does `_isProtocolDestination` only query `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0`?
Because the code assumes a raffle clone only exists as a dangerous destination after `Clones.clone` has deployed bytecode at `destination` and `RaffleFactory` has set `isRaffle[destination] = true`. The implicit belief is that an address with `code.length == 0` today can never become a registered `isRaffle` clone later — which overlooks that `Clones.clone` uses `CREATE` from `RaffleFactory`, making every future raffle clone address deterministically computable (`keccak256(rlp([factory, nonce]))`) while its `code.length` is still `0`.

`[Why: RaffleFactory.sol:761-767]`
Why does `createRaffle` check both `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active` after `prize.safeTransferFrom`?
Because `params.prizeToken` is an untrusted contract that could either return without transferring ownership, or transfer ownership without invoking `onERC721Received` (leaving `status == Status.AwaitingPrize`), or re-enter `raffle` during `safeTransferFrom` (for example, having `sponsor` call `enableRefunds()` while `totalEntries == 0`, transitioning `status` to `Status.Refunding`). The implicit belief is that verifying ownership and `status == Status.Active` at the end of `createRaffle` guarantees the NFT can later be transferred out via `transferFrom` when the raffle ends.

`[Defeat: RaffleFactory::createRaffle]`
1. Attacker `0xbad1` deploys an ERC-721 contract `MaliciousPrize` at `0x9001` that returns `true` for `supportsInterface(0x80ac58cd)`, and inside `safeTransferFrom(0xbad1, raffle, 1)` calls `RaffleFactory.createRaffle` again to desynchronize `raffleCount` — blocked by `nonReentrant` on `RaffleFactory::createRaffle`.
2. Attacker `0xbad1` has `MaliciousPrize.safeTransferFrom` call `raffle.onERC721Received(address(factory), 0xbad1, 1, "")` (setting `status = Active`) and then immediately call `raffle.enableRefunds()` from `0xbad1` (`sponsor`) while `totalEntries == 0` (setting `status = Refunding`) and `raffle.releaseSponsorPrize()` to take the NFT back within `createRaffle` — blocked by `if (prize.ownerOf(params.prizeTokenId) != raffle)` at line 762 and `if (IRaffle(raffle).status() != IRaffle.Status.Active)` at line 765.
3. Sponsor `0xbad1` computes the deterministic `CREATE` address of the next raffle clone (`futureRaffle = computeCreateAddress(factory, raffleCount + 3)`) and calls `createRaffle` for Raffle #1 with `params.sponsorRecipient = futureRaffle`. Because `futureRaffle.code.length == 0` and `isRaffle[futureRaffle] == false` during Raffle #1 creation, both `_validateCreateParams` (`RaffleFactory.sol:800`) and `Raffle::initialize` (`Raffle.sol:206`) allow `sponsorRecipient = futureRaffle`. Once Raffle #2 is created at `futureRaffle`, `isRaffle[futureRaffle]` becomes `true`, causing `releaseSponsorProceeds()` in Raffle #1 to permanently revert with `InvalidQuoteDestination(futureRaffle)` and `releaseSponsorPrize()` in Raffle #1 to transfer Raffle #1's prize NFT into Raffle #2 (`futureRaffle`), permanently locking it.

`[Defeat: Raffle::initialize]`
1. Attacker `0xbad2` calls `raffleImplementation.initialize(...)` directly to take control of the implementation — blocked by `if (initialized) revert AlreadyInitialized()` at `Raffle.sol:190` since the constructor sets `initialized = true`.
2. Attacker `0xbad2` deploys their own clone of `raffleImplementation` via `Clones.clone(raffleImplementation)` and calls `initialize` on it — blocked by `if (msg.sender != factory) revert OnlyFactory()` at `Raffle.sol:191`.
3. Sponsor `0xbad2` calls `createRaffle` with `params.prizeToken = protocolTreasury` (assuming `protocolTreasury` is a contract that supports ERC-721) to make `releaseProtocolFees()` revert via `_isProtocolDestination` — blocked by `if (_isProtocolDestination(params.protocolTreasury, params.prizeToken))` at `Raffle.sol:203` because `_isProtocolDestination` checks `destination == prizeToken_`.

`[Defeat: Raffle::onERC721Received]`
1. Attacker `0xbad3` calls `raffle.onERC721Received(address(factory), sponsor, prizeTokenId, "")` directly before the factory transfers the NFT — impossible because `createRaffle` is atomic (`initialize` and `safeTransferFrom` run in the same transaction) and `msg.sender != address(prizeToken)` reverts with `UnexpectedPrize`.
2. Attacker `0xbad3` safe-transfers an unrelated NFT `(otherToken, 99)` to an active `raffle` clone — reverts with `UnexpectedPrize` at `Raffle.sol:438` because `status != Status.AwaitingPrize` and `msg.sender != address(prizeToken)`.
3. Malicious `prizeToken` calls `raffle.onERC721Received(address(factory), sponsor, prizeTokenId, "")` twice during `createRaffle` — the second call reverts with `UnexpectedPrize` because the first call already transitioned `status` from `Status.AwaitingPrize` to `Status.Active`.

`[LastOut: Creation & Escrow]`
If a raffle is created (`prizeTokenId` escrowed in `Raffle`, `totalEntries == 0`, `unsettledPot == 0`) and no entries are ever purchased, `enableRefunds()` transitions `status` to `Status.Refunding` with `remainingRefundLiability = 0`, and `releaseSponsorPrize()` transfers `prizeTokenId` back to `sponsorRecipient`. Provided `sponsorRecipient` is not a subsequently deployed `Raffle` clone and `prizeToken` is a compliant ERC-721, the sole depositor (`sponsorRecipient`) recovers 100% of their escrowed NFT with zero shortfall.

---

#### Lifecycle 2: Entry Purchase (`Raffle::buyEntries` & `Raffle::_update`)

`[Model: Raffle::buyEntries]`
While the raffle is active and before `endTime`, a buyer specifies a recipient address and a positive number of entries `entryCount`. The buyer pays `entryCount * 1,000,000` units of USDC into the raffle. The raffle increases `totalEntries` by `entryCount`, increments `ticketCount` by 1, records the inclusive entry range `[oldTotalEntries + 1, oldTotalEntries + entryCount]` for the new `ticketId`, adds the USDC payment to `unsettledPot`, and mints the ERC-721 ticket `ticketId` to `recipient`.

`[Model: Raffle::_update]`
Whenever a ticket is minted, transferred, or burned, `_update` checks that a non-zero destination address `to` is not a restricted protocol address (`_isProtocolDestination`), then updates the ticket ownership and per-address ticket counts. No USDC totals or entry ranges change.

`[Why: Raffle.sol:511-513]`
Why does `_update` check `if (to != address(0) && _isProtocolDestination(to, address(prizeToken)))` on every mint and transfer, but skips the check when `to == address(0)`?
Because burning a ticket in `redeemWinningTicket` or `refundTickets` passes `to = address(0)`, whereas minting or transferring to a known protocol sink would trap the bearer claim inside a contract that has no mechanism to redeem or refund it. The implicit belief is that `_isProtocolDestination` catches all protocol contracts at the moment of transfer — which fails if `to` is the precomputed `CREATE` address of a not-yet-created `Raffle` clone.

`[Defeat: Raffle::buyEntries]`
1. Attacker `0xbad4` calls `buyEntries(attackerContract, 1)` where `attackerContract.onERC721Received` re-enters `buyEntries`, `enableRefunds`, or `requestDraw` — blocked by `nonReentrant` on `buyEntries`, `enableRefunds`, and `requestDraw`.
2. Attacker `0xbad4` calls `buyEntries(attackerContract, 1)` where `attackerContract.onERC721Received` calls `raffle.transferFrom(attackerContract, otherUser, ticketId)` (which is not `nonReentrant`) during `_safeMint` — `_mint` has already updated `_owners[ticketId] = attackerContract`, `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` before `checkOnERC721Received` runs, so transferring `ticketId` during the callback preserves all accounting invariants.
3. Attacker `0xbad4` calls `buyEntries(0xbad4, type(uint128).max)` to overflow `totalEntries` or `unsettledPot` — if `entryCount > type(uint128).max - totalEntries` it reverts with `TotalEntriesOverflow`, and `uint256(entryCount) * 1_000_000` cannot overflow `uint256` while `quoteToken.safeTransferFrom` reverts on insufficient USDC balance.

`[Defeat: Raffle::_update]`
1. Ticket holder `0xbad5` calls `transferFrom(0xbad5, address(raffle), 1)` or `transferFrom(0xbad5, address(factory), 1)` — reverts with `UnsafeProtocolDestination` at `Raffle.sol:512`.
2. Ticket holder `0xbad5` computes `futureRaffle = computeCreateAddress(factory, raffleCount + 2)` (before the next raffle is created) and calls `transferFrom(0xbad5, futureRaffle, 1)`. Because `futureRaffle.code.length == 0`, `_isProtocolDestination(futureRaffle, address(prizeToken))` returns `false` and the transfer succeeds. Once `RaffleFactory::createRaffle` deploys the next raffle at `futureRaffle`, ticket `1` is owned by a `Raffle` clone that has no function to transfer, redeem, or refund it.
3. Ticket holder `0xbad5` transfers `winningTicketId` to a new EOA `0xbeef` after `settleWinningTicket(winningTicketId)` has already been called, then `0xbeef` calls `redeemWinningTicket(winningTicketId)` — succeeds cleanly because `_settleWinningTicket` does not snapshot `ownerOf(winningTicketId)`, and `redeemWinningTicket` pays the current owner (`0xbeef`).

`[LastOut: Entry Purchase]`
During `Status.Active`, after $N$ purchases of $e_1, e_2, \dots, e_N$ entries, `totalEntries` equals $\sum_{i=1}^N e_i$, `unsettledPot` equals $\sum_{i=1}^N e_i \times 10^6$, `quoteToken.balanceOf(address(this))` equals `unsettledPot`, and `_ticketRanges[1..N]` partitions $[1, \text{totalEntries}]$ without gaps or overlaps. No withdrawals occur in `Status.Active`, and 100% of deposits are backed 1-to-1 in `unsettledPot`.

---

#### Lifecycle 3: Draw & Resolution (`Raffle::requestDraw` → `Raffle::fulfillRandomWords`)

`[Model: Raffle::requestDraw]`
After `endTime` and before `endTime + 2 days`, on a raffle with at least one sold entry, any caller sends native ETH to cover the Chainlink VRF request price. The raffle switches `status` from `Active` to `Drawing`, records the request timestamp `drawRequestedAt` and the returned `vrfRequestId`, pays `paidPrice` in native ETH to the Chainlink VRF wrapper, and refunds any excess native ETH (`msg.value - paidPrice`) back to the caller. No USDC totals change.

`[Model: Raffle::fulfillRandomWords]`
When the Chainlink VRF wrapper delivers one random word for `vrfRequestId` while `status == Status.Drawing` and before `drawRequestedAt + 2 days`, the raffle selects a winning entry number in `[1, totalEntries]`, records `winningEntry` and `resolvedAt`, and switches `status` to `NftWon` (if `totalEntries >= reserveEntries`) or `CashWon` (if `totalEntries < reserveEntries`). No assets move and no USDC liabilities are split yet.

`[Why: Raffle.sol:267-273]`
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and clear `_requestInFlight = false` after assigning `vrfRequestId = requestId`?
Because `vrfRequestId` is `0` in storage until `requestRandomnessPayInNative` returns `requestId`. If the VRF wrapper executed a synchronous callback with `requestId = 0` during `requestRandomnessPayInNative`, `requestId == vrfRequestId` (`0 == 0`) would pass inside `fulfillRandomWords` before `requestDraw` finished. The implicit belief is that Chainlink VRF fulfillment is always asynchronous (30 confirmations) and any synchronous callback during `requestRandomnessPayInNative` is invalid.

`[Why: Raffle.sol:523-529]`
Why does `fulfillRandomWords` emit `VrfCallbackIgnored` and `return` without reverting when `status != Status.Drawing` or `block.timestamp >= callbackDeadline()`?
Because Chainlink VRF v2.5 Wrapper tracks whether consumer callbacks revert. Returning cleanly without reverting ensures late or duplicate callbacks after `enableRefunds()` has transitioned the raffle to `Status.Refunding` do not revert the VRF wrapper transaction or alter the finalized `Status.Refunding` state.

`[Defeat: Raffle::requestDraw]`
1. Attacker `0xbad6` deploys a contract with a reverting `receive()` function and calls `requestDraw()` sending `msg.value = quotedFee + 1 wei` to brick `requestDraw()` — the `NativeRefundFailed` revert at `Raffle.sol:282` rolls back the entire transaction of `0xbad6`, leaving `status == Status.Active` so any honest caller can call `requestDraw()`.
2. Attacker `0xbad6` force-sends `1 ether` to `address(raffle)` via `selfdestruct` before `requestDraw()`, hoping `requestDraw()` miscalculates the refund or reverts — `requestDraw()` computes `excess = msg.value - paidPrice` using `msg.value` rather than `address(this).balance`, so forced native ETH has no effect on `requestDraw()`.
3. Honest keeper simulates `raffle.getVrfRequestPrice()` off-chain via `eth_call` without setting a transaction gas price (`tx.gasprice == 0`), gets the base wrapper fee without the gas-price-dependent execution fee, and submits `requestDraw{value: simulatedFee}()` on-chain where `tx.gasprice > 0` — on-chain `getVrfRequestPrice()` returns a higher `quotedFee` and `requestDraw` reverts with `InsufficientVrfFee(quotedFee, msg.value)`.

`[Defeat: Raffle::fulfillRandomWords]`
1. Attacker `0xbad7` calls `rawFulfillRandomWords(vrfRequestId, [0])` directly on `raffle` — reverts with `OnlyVRFWrapperCanFulfill` at `VRFV2PlusWrapperConsumerBase.sol:104`.
2. Attacker `0xbad7` buys millions of entries across 50,000 tickets so `fulfillRandomWords` runs out of the `300_000` `callbackGasLimit` — `fulfillRandomWords` does not iterate over tickets (`O(1)` modulo computation on `totalEntries`), using < 30,000 gas regardless of `ticketCount`.
3. At `block.timestamp == callbackDeadline()`, both `enableRefunds()` and `rawFulfillRandomWords()` are submitted in the same block — whichever order they execute in, `block.timestamp >= callbackDeadline()` is `true`, so `fulfillRandomWords` ignores the callback (`VrfCallbackIgnored`) and `enableRefunds()` succeeds.

`[LastOut: Draw & Resolution]`
In `requestDraw`, the caller pays `msg.value`, `paidPrice` goes to `i_vrfV2PlusWrapper`, and `msg.value - paidPrice` is returned atomically to `msg.sender` in the same transaction. `unsettledPot` remains untouched at `totalEntries * 1,000,000` until settlement or refund activation.

---

#### Lifecycle 4: Settlement & Claims (`settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`)

`[Model: Raffle::_settleWinningTicket]`
Once the raffle is in `NftWon` or `CashWon`, any caller supplies the `ticketId` whose stored `[firstEntry, lastEntry]` range contains `winningEntry`. The raffle marks `settlementComplete = true`, records `winningTicketId = ticketId`, sets `unsettledPot = 0`, allocates 5% of the pot (rounded down) to `protocolFees`, allocates 80% of the pot (rounded down) to `winnerProceeds` if `status == CashWon` (or 0 if `status == NftWon`), and allocates the remaining pot (`grossPot - protocolFee - cashAmount`) to `sponsorProceeds`. No tokens or NFTs are transferred during settlement.

`[Model: Raffle::redeemWinningTicket]`
The current owner of `winningTicketId` calls `redeemWinningTicket(winningTicketId)` (which also runs `_settleWinningTicket` if not yet settled). The raffle verifies `msg.sender` owns `winningTicketId`, records `winnerRecipient = winner` and `winnerRedeemed = true`, burns `winningTicketId`, and either transfers `prizeTokenId` to `winner` (when `status == NftWon`, setting `prizeClaimed = true`) or zeroes `winnerProceeds` and transfers that USDC amount to `winner` (when `status == CashWon`).

`[Model: Raffle::releaseSponsorProceeds]`
Anyone calls `releaseSponsorProceeds()` after settlement; the raffle reads `sponsorProceeds`, sets `sponsorProceeds = 0`, and transfers that USDC amount to `sponsorRecipient`.

`[Model: Raffle::releaseProtocolFees]`
Anyone calls `releaseProtocolFees()` after settlement; the raffle reads `protocolFees`, sets `protocolFees = 0`, and transfers that USDC amount to `protocolTreasury`.

`[Model: Raffle::releaseSponsorPrize]`
When `status` is `CashWon` or `Refunding` and `prizeClaimed` is `false`, anyone calls `releaseSponsorPrize()`; the raffle sets `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient`, and verifies `prizeToken.ownerOf(prizeTokenId) == sponsorRecipient`.

`[Why: Raffle.sol:327-331]`
Why does `redeemWinningTicket` check `if (!settlementComplete) _settleWinningTicket(ticketId); else if (ticketId != winningTicketId) revert WinningTicketMismatch(...)`?
Because `settleWinningTicket` can be called permissionlessly by anyone before `redeemWinningTicket` (so the sponsor and protocol treasury can claim their USDC shares without waiting for the winner), or `redeemWinningTicket` can perform both steps in one transaction. The implicit belief is that `winningEntry` falls into exactly one ticket's `[firstEntry, lastEntry]` range, so no third party can settle a wrong `ticketId` to front-run and block the true winner.

`[Why: Raffle.sol:559-560]`
Why is `sponsorAmount` computed as `grossPot - protocolFee - cashAmount` rather than `Math.mulDiv(grossPot, 1500, 10_000)`?
To guarantee exact conservation (`protocolFee + cashAmount + sponsorAmount == grossPot`) with zero unallocated dust left in `Raffle`. Moreover, because `ENTRY_PRICE = 1_000_000` is a multiple of `BPS = 10_000`, `grossPot` is always an exact multiple of `10_000`, so `Math.mulDiv` never produces rounding dust in v1.

`[Why: Raffle.sol:578]`
Why does `_transferQuote` re-check `if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to)` at payout time even though `sponsorRecipient`, `protocolTreasury`, and ticket owners were already screened by `_isProtocolDestination` at `initialize` and `_update` time?
Because the author added a defense-in-depth destination check at the USDC transfer sink. However, the implicit belief is that `_isProtocolDestination(to, address(prizeToken))` is time-invariant — in reality, if `to` was a precomputed future `Raffle` clone address whose clone was created after `initialize` or `_update`, `_isProtocolDestination(to, ...)` flips from `false` to `true`, causing `_transferQuote` to revert and permanently trap the USDC liability inside `Raffle`.

`[Why: Raffle.sol:415-418]`
Why does `releaseSponsorPrize` NOT call `_isProtocolDestination(recipient, address(prizeToken))` before transferring `prizeTokenId` to `sponsorRecipient`, unlike `_transferQuote`?
Because `releaseSponsorPrize` assumes `sponsorRecipient` was already permanently validated in `initialize`. As a result, if `sponsorRecipient` is a future `Raffle` clone that gets deployed before `releaseSponsorPrize` runs, `releaseSponsorPrize` transfers `prizeTokenId` into that `Raffle` clone (violating `"Never move assets between raffle clones"`), whereas `releaseSponsorProceeds` reverts on `_isProtocolDestination`.

`[Defeat: Raffle::_settleWinningTicket]`
1. Attacker `0xbad8` calls `settleWinningTicket(0)` (an unminted ticket ID) hoping `(0, 0)` matches `winningEntry` — since `totalEntries >= 1`, `winningEntry = (randomWords[0] % totalEntries) + 1 >= 1 > 0`, so `_requireWinningTicket(0)` reverts with `TicketDoesNotContainWinningEntry(0, winningEntry)`.
2. Attacker `0xbad8` calls `settleWinningTicket(nonWinningTicketId)` to lock in the wrong `winningTicketId` — `_requireWinningTicket` reverts because `_ticketRanges` intervals are disjoint and only the single ticket containing `winningEntry` passes `selectedEntry >= firstEntry && selectedEntry <= lastEntry`.
3. Attacker `0xbad8` calls `settleWinningTicket(winningTicketId)` before the winner calls `redeemWinningTicket(winningTicketId)` — `settlementComplete` becomes `true` and `winningTicketId` is recorded, and when the winner subsequently calls `redeemWinningTicket(winningTicketId)`, it takes the `else if (ticketId != winningTicketId)` branch (which does not revert because `ticketId == winningTicketId`) and redeems normally.

`[Defeat: Raffle::redeemWinningTicket]`
1. In `Status.CashWon` with `totalEntries = 1` (`grossPot = 1,000,000`), attacker checks if `winnerProceeds == 0` can trigger `NoWinnerProceeds()` at `Raffle.sol:353` — `cashAmount = 1_000_000 * 8000 / 10_000 = 800_000 > 0`, so `winnerProceeds` is at least `800_000` for any valid `CashWon` raffle.
2. In `Status.NftWon`, `winner` is a smart contract that reverts in `onERC721Received` — `redeemWinningTicket` uses `prizeToken.transferFrom` rather than `safeTransferFrom`, so standard ERC-721 contracts do not invoke `onERC721Received` on `winner`.
3. In `Status.NftWon`, a malicious or pausable `prizeToken` reverts inside `prizeToken.transferFrom(address(this), winner, prizeTokenId)` (or refuses to update `ownerOf` to `winner`) when `winner` calls `redeemWinningTicket`, while `sponsor` still calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()` to withdraw 95% of `unsettledPot` in USDC because `releaseSponsorProceeds()` does not require `prizeClaimed == true`.

`[Defeat: Raffle::releaseSponsorProceeds]`
1. Attacker `0xbad9` calls `releaseSponsorProceeds()` before `sponsor` does — `releaseSponsorProceeds()` always sends `sponsorProceeds` to the immutable `sponsorRecipient`, so calling it permissionlessly only delivers the funds to `sponsorRecipient`.
2. `sponsorRecipient` is blacklisted by USDC (`quoteToken`) — `releaseSponsorProceeds()` reverts when transferring USDC to `sponsorRecipient`, but because claims are isolated in separate functions, `redeemWinningTicket`, `releaseProtocolFees`, and `releaseSponsorPrize` remain completely unaffected.
3. `sponsorRecipient` was configured at Raffle #1 creation to the deterministic `CREATE` address of Raffle #2 (`futureRaffle`), and Raffle #2 has since been created — `releaseSponsorProceeds()` in Raffle #1 permanently reverts at `_transferQuote` (`Raffle.sol:578`) with `InvalidQuoteDestination(sponsorRecipient)`.

`[Defeat: Raffle::releaseProtocolFees]`
1. Attacker `0xbadA` calls `releaseProtocolFees()` before `settleWinningTicket` — `protocolFees == 0`, so it reverts with `NoProtocolFees()`.
2. Attacker `0xbadA` calls `releaseProtocolFees()` twice after settlement — the first call zeroes `protocolFees` and transfers 5% of `grossPot` to `protocolTreasury`; the second call reverts with `NoProtocolFees()`.
3. `protocolTreasury` is blacklisted by USDC — only `releaseProtocolFees()` reverts; `redeemWinningTicket` and `releaseSponsorProceeds` succeed independently.

`[Defeat: Raffle::releaseSponsorPrize]`
1. Attacker `0xbadB` calls `releaseSponsorPrize()` in `Status.NftWon` to steal the NFT back for the sponsor — reverts with `SponsorPrizeUnavailable(Status.NftWon)` at `Raffle.sol:411`.
2. Attacker `0xbadB` calls `releaseSponsorPrize()` twice in `Status.CashWon` — the first call sets `prizeClaimed = true` and transfers `prizeTokenId` to `sponsorRecipient`; the second call reverts with `PrizeAlreadyClaimed()`.
3. `sponsorRecipient` was set to `futureRaffle` (Raffle #2's precomputed `CREATE` address) in Raffle #1, and Raffle #2 is now deployed — in `Status.CashWon` or `Status.Refunding`, `releaseSponsorPrize()` does not call `_isProtocolDestination` and transfers `prizeTokenId` into Raffle #2, where it is permanently trapped.

`[LastOut: Settlement & Claims]`
Suppose $totalEntries = E \ge 1$, so $unsettledPot = E \times 1,000,000$ USDC is held by `Raffle`.
- **Branch A (`Status.NftWon`)**: `_settleWinningTicket` sets `unsettledPot = 0`, `protocolFees = (E * 1,000,000 * 500) / 10,000 = E * 50,000`, `sponsorProceeds = E * 1,000,000 - E * 50,000 = E * 950,000`, and `winnerProceeds = 0`. In any withdrawal order among (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`), `winner` receives `prizeTokenId`, `sponsorRecipient` receives $E \times 950,000$ USDC, and `protocolTreasury` receives $E \times 50,000$ USDC. Total USDC paid out is $E \times 1,000,000 == \text{initial balance}$, leaving `accountedQuoteBalance() == 0` and `quoteToken.balanceOf(address(this)) == 0`. The last claimant is paid in full with 0 shortfall.
- **Branch B (`Status.CashWon`)**: `_settleWinningTicket` sets `unsettledPot = 0`, `protocolFees = E * 50,000`, `winnerProceeds = E * 800,000`, and `sponsorProceeds = E * 1,000,000 - E * 50,000 - E * 800,000 = E * 150,000`. In any withdrawal order among (`redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`), `winner` receives $E \times 800,000$ USDC, `sponsorRecipient` receives $E \times 150,000$ USDC and `prizeTokenId`, and `protocolTreasury` receives $E \times 50,000$ USDC. Total USDC paid out is $E \times (800,000 + 150,000 + 50,000) = E \times 1,000,000 == \text{initial balance}$, leaving 0 shortfall for the last user out.

---

#### Lifecycle 5: Refund Lifecycle (`enableRefunds` → `refundTickets` + `releaseSponsorPrize`)

`[Model: Raffle::enableRefunds]`
When a raffle with zero sold entries is cancelled by the sponsor (or by anyone at or after `endTime`), or when a raffle with sold entries reaches `endTime + 2 days` without a draw request, or when a draw request reaches `drawRequestedAt + 2 days` without a VRF callback, `enableRefunds` moves the entire `unsettledPot` into `remainingRefundLiability`, sets `unsettledPot = 0`, and sets `status = Refunding`.

`[Model: Raffle::refundTickets]`
In `Status.Refunding`, a ticket owner submits an array of 1 to 100 `ticketIds` they currently own. For each ticket in the batch, the raffle verifies `msg.sender` is the current owner, adds the ticket's entry count (`lastEntry - firstEntry + 1`) to `aggregateEntries`, and burns the ticket. The raffle then subtracts `amount = aggregateEntries * 1,000,000` from `remainingRefundLiability` and transfers `amount` of USDC to `msg.sender`.

`[Why: Raffle.sol:293-297]`
Why does `enableRefunds` allow `msg.sender == sponsor` to enable refunds before `endTime` only when `totalEntries == 0`?
Because once at least one ticket has been sold (`totalEntries > 0`), the protocol does not allow the sponsor to unilaterally cancel the raffle before `endTime` when buyers have active entries. However, the implicit belief is that a sponsor who wishes to cancel an empty raffle (`totalEntries == 0`) can reliably call `enableRefunds()` — whereas `buyEntries` is simultaneously open in `Status.Active`, allowing anyone to front-run `sponsor`'s `enableRefunds()` with a 1-entry (`1 USDC`) purchase and block cancellation until `endTime + 2 days`.

`[Defeat: Raffle::enableRefunds]`
1. Sponsor calls `enableRefunds()` before `endTime` on an empty raffle (`totalEntries == 0`) to cancel and withdraw `prizeTokenId`; attacker `0xbadC` front-runs with `buyEntries(0xbadC, 1)` for `1,000,000` USDC (`1 USDC`). `totalEntries` becomes `1`, causing the sponsor's `enableRefunds()` call to hit the `else` branch at `Raffle.sol:298-300` and revert with `RefundsNotAvailable(drawRequestDeadline(), block.timestamp)`. After `endTime + 2 days` with no draw requested, `0xbadC` calls `enableRefunds()` and `refundTickets([1])`, recovering the entire `1 USDC` after locking the sponsor's NFT for up to 32 days.
2. Attacker `0xbadC` calls `enableRefunds()` on an active raffle with `totalEntries == 0` before `endTime` while `0xbadC != sponsor` — reverts with `RefundsNotAvailable(endTime, block.timestamp)` at `Raffle.sol:296`.
3. Attacker `0xbadC` calls `enableRefunds()` while `status == Status.Drawing` at `block.timestamp == callbackDeadline() - 1` — reverts with `RefundsNotAvailable(callbackDeadline(), block.timestamp)` at `Raffle.sol:304`.

`[Defeat: Raffle::refundTickets]`
1. Attacker `0xbadD` passes duplicate ticket IDs `[1, 1]` to `refundTickets` to double-claim a refund — on index `0`, `_burn(1)` clears `_owners[1] = address(0)`; on index `1`, `ownerOf(1)` reverts with `ERC721NonexistentToken(1)`, rolling back the transaction.
2. Attacker `0xbadD` passes a burned `ticketId` (whose `_ticketRanges[ticketId]` still remains in storage after `_burn`) to `refundTickets` — `ownerOf(ticketId)` runs before `ticketRange(ticketId)` at `Raffle.sol:372` and reverts with `ERC721NonexistentToken(ticketId)`.
3. Attacker `0xbadD` mints 500 single-entry tickets to victim `0xbeef` hoping to exceed `MAX_REFUND_TICKET_BATCH_SIZE = 100` and block `0xbeef` from refunding — `refundTickets` accepts caller-selected slices of up to 100 ticket IDs per call, so `0xbeef` can refund all 500 tickets in 5 transactions (and keep `0xbadD`'s 500 USDC).

`[LastOut: Refund Lifecycle]`
Suppose $K$ tickets were minted with entry counts $e_1, e_2, \dots, e_K$ and $\sum_{i=1}^K e_i = E = \text{totalEntries}$. During `buyEntries`, `unsettledPot` accumulated $\sum_{i=1}^K e_i \times 10^6 = E \times 10^6$ USDC. When `enableRefunds()` runs, `remainingRefundLiability` is set to `unsettledPot = E * 10^6` and `unsettledPot` is zeroed. Each ticket $i \in \{1, \dots, K\}$ can be burned at most once in `refundTickets`, withdrawing $(lastEntry_i - firstEntry_i + 1) \times 10^6 = e_i \times 10^6$ USDC and decrementing `remainingRefundLiability` by the exact same amount, while `releaseSponsorPrize()` returns `prizeTokenId` to `sponsorRecipient`. Regardless of the permutation or batching order in which the $K$ tickets are refunded, the $K$-th (last) ticket holder receives their full $e_K \times 10^6$ USDC, reducing `remainingRefundLiability` and the contract's accounted USDC balance to exact `0` with zero shortfall.

---

### Leads

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-dos | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-dos
smell: In Raffle.sol:615-617 and RaffleFactory.sol:792,800, destination screening only checks canonicalFactory.isRaffle(destination) for already-created clones (destination.code.length != 0), while Clones.clone(raffleImplementation) at RaffleFactory.sol:739 uses CREATE with predictable sequential nonces; additionally, releaseSponsorPrize at Raffle.sol:408-420 omits _isProtocolDestination(recipient, address(prizeToken)) while _transferQuote at Raffle.sol:578 re-checks it at claim time.
unverified: No path exists for an attacker to force an honest sponsor's sponsorRecipient or an honest buyer's ticket ownership to be set to a precomputed future Raffle clone address without the sponsor or ticket holder choosing that recipient address themselves.
description: Setting sponsorRecipient or a ticket recipient to a deterministic future Raffle clone address passes creation/transfer checks before that clone is deployed, but once the clone is created isRaffle becomes true, permanently reverting _transferQuote with InvalidQuoteDestination, allowing releaseSponsorPrize to transfer the prize NFT into another Raffle clone, and stranding any ticket owned by the clone.
```

```
LEAD | contract: Raffle | function: enableRefunds | bug_class: empty-raffle-cancellation-griefing | group_key: Raffle | enableRefunds | empty-raffle-cancellation-griefing
smell: In Raffle.sol:293-297, the sponsor's pre-endTime cancellation path in enableRefunds() requires totalEntries == 0 while buyEntries() at Raffle.sol:222 is simultaneously open in Status.Active with a 1-entry (1 USDC) minimum purchase.
unverified: Purchasing 1 entry in Status.Active is valid user participation by design, and recovering the 1 USDC after locking the sponsor's NFT until drawRequestDeadline() (up to 32 days) requires that no party calls requestDraw() during the 2-day draw window.
description: An attacker can front-run a sponsor's pre-endTime enableRefunds() cancellation transaction with buyEntries(attacker, 1) for 1 USDC, flipping totalEntries from 0 to 1 so enableRefunds() reverts with RefundsNotAvailable and locking the escrowed prize NFT until endTime + 2 days (or forcing the draw if reserveEntries was misconfigured low).
```

```
LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: untrusted-prize-token-settlement-asymmetry | group_key: Raffle | redeemWinningTicket | untrusted-prize-token-settlement-asymmetry
smell: In Raffle.sol:546-571 and Raffle.sol:388-395, _settleWinningTicket and releaseSponsorProceeds allow the sponsor to withdraw 95% of unsettledPot in Status.NftWon without requiring prizeClaimed == true, whereas redeemWinningTicket at Raffle.sol:347-350 reverts if prizeToken.transferFrom(address(this), winner, prizeTokenId) reverts or fails to update ownerOf.
unverified: IRaffle.sol scopes supported prizes to honest, standards-compliant ERC-721 contracts, and decoupling permissionless settlement from winner redemption is an intentional design requirement in DESIGN.md.
description: If an untrusted, pausable, or blacklisted prizeToken escrowed at creation later reverts or blocks transferFrom to winner in Status.NftWon, the sponsor can still settle and withdraw 95% of the USDC pot via releaseSponsorProceeds while redeemWinningTicket permanently reverts with no fallback to Status.Refunding.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: uncompensated-single-shot-vrf-request | group_key: Raffle | requestDraw | uncompensated-single-shot-vrf-request
smell: In Raffle.sol:253-286 and Raffle.sol:449-451, requestDraw() can only be called once (transitioning status from Active to Drawing), requires the caller to pay the native VRF fee without reimbursement, and checks getVrfRequestPrice() which calls calculateRequestPriceNative using tx.gasprice (returning a lower fee in eth_call simulations where tx.gasprice is 0).
unverified: Callers can query estimateVrfRequestPrice(requestGasPriceWei) and supply excess msg.value (refunded at Raffle.sol:275-283), and Chainlink VRF wrapper availability within the 2-day request/callback windows is part of the protocol's trusted dependency model.
description: Sizing msg.value from an unconfigured getVrfRequestPrice() eth_call causes requestDraw() to revert with InsufficientVrfFee on-chain, and because requestDraw() has no economic bounty or retry path from Status.Drawing, prolonged gas spikes or wrapper liveness failures push even reserve-met raffles into Status.Refunding.
```
