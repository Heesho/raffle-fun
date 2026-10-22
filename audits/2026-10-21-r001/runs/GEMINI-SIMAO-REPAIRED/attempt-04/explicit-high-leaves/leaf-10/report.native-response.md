### Phase 0 & Phase 1 — Vocabulary, Money Map, and Integration Surface

In `raffle.fun`, a sponsor creates an isolated raffle clone by depositing one NFT (`prizeToken`, `prizeTokenId`) via `RaffleFactory::createRaffle`. Buyers pay 1 USDC (`1,000,000` units of canonical 6-decimal `quoteToken`) per entry in `Raffle::buyEntries`, receiving one sequential bearer ERC-721 ticket representing an inclusive `[firstEntry, lastEntry]` range while increasing `totalEntries`, `ticketCount`, and `unsettledPot`. After `endTime`, anyone funds a Chainlink VRF v2.5 native draw request in `Raffle::requestDraw`; `Raffle::fulfillRandomWords` selects `winningEntry` in `[1, totalEntries]` and resolves `status` to `Status.NftWon` (when `totalEntries >= reserveEntries`) or `Status.CashWon` (when `totalEntries < reserveEntries`). If the draw request window (`endTime + 2 days`) or callback window (`drawRequestedAt + 2 days`) expires, `Raffle::enableRefunds` moves `unsettledPot` into `remainingRefundLiability` and sets `status = Status.Refunding`.

Under **Lens 10 (Integration & Environment Assumptions)**, we examine every assumption `Raffle` and `RaffleFactory` make about external contracts and chain behavior:
1. **`prizeToken` (untrusted / stateful ERC-721):** `DESIGN.md` explicitly states *"Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."* Even among canonical Ethereum Mainnet ERC-721s, tokens such as ENS `.eth` `BaseRegistrarImplementation` (`0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85`), LimitBreak `ERC721C` collections using `CreatorTokenTransferValidator` (`0x721C0078c2328597Ca70F5451ffF5A7B38D4E947`), and `ERC721Pausable` tokens can succeed at initial escrow during `createRaffle` and later revert on `transferFrom` or `ownerOf` at redemption time.
2. **`quoteToken` (canonical 6-decimal Circle USDC, `FiatTokenV2_2`):** Enforces `notBlacklisted` on `from`, `to`, and `msg.sender`.
3. **Chainlink VRF v2.5 (`VRFV2PlusWrapper` / `VRFV2PlusWrapperConsumerBase`):** Prices native requests using the request transaction's `tx.gasprice` (`calculateRequestPriceNative`) and delivers randomness asynchronously after `requestConfirmations = 30`.
4. **Clone deployment (`Clones.clone`) & `_isProtocolDestination`:** Uses deterministic `CREATE` addresses derived from `(address(factory), nonce)` and screens protocol destinations against `isRaffle` and `code.length != 0`.

---

### Phase 3 & Phase 4 — Lifecycle & Function Walkthrough with Reasoning Protocol

#### Lifecycle 1: Creation & Escrow (`RaffleFactory::createRaffle` → `Raffle::initialize` → `Raffle::onERC721Received`)

`[Model: createRaffle]`
A sponsor supplies a prize NFT, a sponsor payout recipient, an entry reserve threshold, and a sale end time. The factory increments its raffle counter, deploys a new raffle clone, configures the clone, registers it in the factory mappings, and moves the sponsor's NFT into the clone. The clone's receipt callback marks the raffle active, and the factory checks that the clone now owns the NFT and is in the active state.
Spot where plain English reaches for a Solidity/ERC-721 term: *"the factory checks that the clone now owns the NFT"* — `RaffleFactory.sol:129` calls `prize.ownerOf(params.prizeTokenId) == raffle` and `IERC165.supportsInterface(0x80ac58cd)` at creation time, assuming that passing `supportsInterface`, `safeTransferFrom`, and `ownerOf` at `block.timestamp` guarantees the NFT will remain owned by `raffle` and transferable out of `raffle` up to 34+ days later.

`[Why: RaffleFactory.sol:129]`
Why does `createRaffle` verify `prize.ownerOf(params.prizeTokenId) != raffle` and `IRaffle(raffle).status() != IRaffle.Status.Active` after `safeTransferFrom`?
Because `params.prizeToken` is an arbitrary, untrusted contract supplied by the sponsor (`DESIGN.md`: *"arbitrary prize contracts and ticket recipients are untrusted"*). The code rests on the implicit belief that verifying `ownerOf == raffle` at `createRaffle` time is sufficient to guarantee that `raffle` holds an unencumbered, deliverable prize for the duration of the raffle.

`[Defeat: createRaffle]`
1. Sponsor `0xAAA1` deploys an ERC-721 contract `MaliciousPrize` at `0xBEEF` that returns `true` for `supportsInterface(0x80ac58cd)` and allows `safeTransferFrom` when `to == raffle`, setting `_owner = raffle` so `createRaffle` succeeds, but reverts inside `transferFrom` whenever `from == raffle` and `to != sponsorRecipient`.
2. Sponsor `0xAAA2` calls `createRaffle` with Ethereum Mainnet ENS `BaseRegistrarImplementation` (`0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85`) for `prizeTokenId = uint256(keccak256("rare"))` whose `expiries[prizeTokenId] == block.timestamp + 2 days`, while setting `endTime = uint64(block.timestamp + 7 days)`. At `createRaffle`, `expiries[prizeTokenId] > block.timestamp`, so `safeTransferFrom` and `ownerOf` succeed; 2 days later the ENS registration expires and both `ownerOf` and `transferFrom` revert.
3. Sponsor `0xAAA3` calls `createRaffle` for `raffle_1` with `sponsorRecipient = computeCreateAddress(factory, 3)` (the deterministic `CREATE` address of the next clone `raffle_2`). At `raffle_1` creation time, `computeCreateAddress(factory, 3)` has `code.length == 0` and `isRaffle[...] == false`, bypassing both `_validateCreateParams` (`RaffleFactory.sol:163`) and `_isProtocolDestination` (`Raffle.sol:602`).

`[LastOut: Creation & Escrow]`
If `createRaffle` completes and no entries are bought (`totalEntries == 0`), the sponsor calls `enableRefunds()` and `releaseSponsorPrize()`. `unsettledPot` is `0`, `remainingRefundLiability` is `0`, and `prizeTokenId` is returned to `sponsorRecipient` (provided `prizeToken` still permits transfer and `sponsorRecipient` was not set to a future raffle clone). The protocol holds `0` USDC and owes `0` USDC.

---

#### Lifecycle 2: Entry Purchase (`Raffle::buyEntries`)

`[Model: buyEntries]`
A buyer gives 1 USDC per requested entry to the raffle contract and specifies a recipient address. In return, the raffle increases the global sold-entry counter by the entry count, increments the ticket counter by one, records the inclusive start and end entry numbers for the new ticket, adds the USDC amount to the unsettled pot, and mints one ticket NFT to the recipient.

`[Why: Raffle.sol:235]`
Why is `_safeMint(recipient, ticketId)` called only after `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot` are written?
Because `_safeMint` invokes `onERC721Received` on contract recipients; updating all accounting variables first and guarding external entry points with `nonReentrant` ensures a recipient callback cannot observe partially updated state or reenter state-changing raffle functions, even if it calls `ERC721::transferFrom` during the callback.

`[Defeat: buyEntries]`
1. Buyer `0xBBB1` deploys a receiver contract `0xCAFE` whose `onERC721Received` calls `Raffle::transferFrom(0xCAFE, 0xBBB2, ticketId)` during `buyEntries(0xCAFE, 10)`. Because `_mint` already completed and `totalEntries`/`unsettledPot` were already updated (`10e6` USDC), the secondary transfer only moves ownership of `ticketId = 1` from `0xCAFE` to `0xBBB2` without altering `unsettledPot` or `_ticketRanges[1]`.
2. Buyer `0xBBB1` attempts to pass `recipient = address(quoteToken)` or `recipient = address(raffle)` in `buyEntries(recipient, 5)`. `_update` (`Raffle.sol:498`) calls `_isProtocolDestination` and reverts with `UnsafeProtocolDestination`.
3. Buyer `0xBBB1` attempts `buyEntries(0xBBB1, type(uint128).max)` when `totalEntries == 1`. Line 219 (`entryCount > type(uint128).max - totalEntries`) reverts with `TotalEntriesOverflow(1, type(uint128).max)`.

`[LastOut: Entry Purchase]`
After $N$ buyers purchase entries totaling `totalEntries` entries, the contract holds `totalEntries * 1,000,000` USDC, and `unsettledPot == totalEntries * 1,000,000`. No withdrawals occur during `Status.Active`; every entry is backed 1:1 by 1 USDC in `unsettledPot`.

---

#### Lifecycle 3: Draw & Resolution (`Raffle::requestDraw` → `Raffle::fulfillRandomWords`)

`[Model: requestDraw]`
After the sale end time and before the 2-day request deadline, any caller sends native currency to cover the Chainlink VRF wrapper fee. The raffle marks its status as drawing, records the request timestamp, pays the wrapper's calculated native price to request one random word, stores the returned request identifier, and sends any leftover native currency back to the caller.

`[Model: fulfillRandomWords]`
When the Chainlink VRF wrapper delivers one random word before the 2-day callback deadline for the active request identifier, the raffle maps that random number into a winning entry between 1 and total entries sold, records the resolution timestamp, and sets the raffle status to NFT-won if total entries meet or exceed the reserve threshold, or cash-won otherwise.

`[Why: Raffle.sol:511]`
Why does `fulfillRandomWords` emit `VrfCallbackIgnored` and `return` instead of reverting when `status != Status.Drawing` or `block.timestamp >= callbackDeadline()`?
Because Chainlink VRF v2.5 wrapper callbacks shouldn't revert on late delivery after `callbackDeadline()` has passed or after `enableRefunds()` has transitioned the raffle to `Status.Refunding`.

`[Defeat: requestDraw]`
1. Attacker `0xCCC1` force-sends `1 ether` to `Raffle` via `selfdestruct` prior to `requestDraw()`, then calls `requestDraw()` with `msg.value = 0` hoping `Raffle` will spend its forced balance and refund `excess`. Line 250 (`if (msg.value < quotedFee) revert InsufficientVrfFee`) and Line 258 (`if (paidPrice > msg.value) revert InsufficientVrfFee`) check `msg.value` directly, defeating the attempt.
2. Attacker `0xCCC1` deploys a contract that calls `requestDraw()` with `msg.value = quotedFee + 1 wei` and attempts to reenter `requestDraw()` or `enableRefunds()` inside its `receive()` hook when `excess = 1 wei` is refunded at `Raffle.sol:267`. `nonReentrant` reverts the reentrant call, causing `success == false` and reverting with `NativeRefundFailed`.
3. Attacker `0xCCC1` calls `rawFulfillRandomWords(vrfRequestId, [0])` directly from `0xCCC1`. `VRFV2PlusWrapperConsumerBase::rawFulfillRandomWords` checks `msg.sender != address(i_vrfV2PlusWrapper)` and reverts with `OnlyVRFWrapperCanFulfill`.

`[LastOut: Draw & Resolution]`
During `requestDraw` and `fulfillRandomWords`, no USDC leaves the contract (`unsettledPot` remains `totalEntries * 1,000,000`). For native ETH, `requestDraw` forwards `paidPrice` to `i_vrfV2PlusWrapper` and refunds `msg.value - paidPrice` to `msg.sender`, leaving `0` net native ETH liability on `Raffle`. Note, however, that if `i_vrfV2PlusWrapper` fails to fulfill before `callbackDeadline()` and `enableRefunds()` is called, the caller who paid `paidPrice` in `requestDraw()` is never reimbursed for the wasted VRF fee.

---

#### Lifecycle 4: Settlement & Claims (`_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`)

`[Model: _settleWinningTicket]`
Anyone supplies a ticket identifier after the draw has resolved. The raffle checks that the ticket's entry range covers the winning entry, marks settlement complete, zeroes the unsettled pot, allocates 5% of the pot (rounded down) to protocol fees, and either allocates the remaining 95% to sponsor proceeds (when the NFT was won) or allocates 80% of the pot (rounded down) to the cash winner and the remaining ~15% to sponsor proceeds (when cash was won).
Spot where plain English exposes the bug: *"when the NFT was won, allocates 95% of the pot to sponsor proceeds"* — `_settleWinningTicket` (`Raffle.sol:543-555`) and `releaseSponsorProceeds` (`Raffle.sol:375`) allocate and pay out 95% of all buyers' USDC to `sponsorRecipient` **without verifying that the NFT prize is still owned by `Raffle` or has been delivered (`prizeClaimed == true`) to the winner**!

`[Why: Raffle.sol:335]`
Why does `redeemWinningTicket` check `if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner)` after `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`?
Because `prizeToken` is untrusted (`DESIGN.md`: *"arbitrary prize contracts and ticket recipients are untrusted; ... redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure"*). Yet the code rests on the faulty belief that reverting `redeemWinningTicket` on delivery failure protects the winner — ignoring that `status == Status.NftWon` is terminal (cannot transition to `Refunding` or `CashWon`) and that `_settleWinningTicket` + `releaseSponsorProceeds` already let the sponsor withdraw 95% of the USDC pot without `prizeClaimed` being true!

`[Model: redeemWinningTicket]`
The current owner of the winning ticket calls the function (which runs settlement first if not yet settled), records themselves as the winner recipient, marks the winning ticket redeemed, burns the winning ticket, and either transfers the prize NFT from the raffle to themselves (in the NFT-won state) or zeroes and transfers the cash winner proceeds in USDC to themselves (in the cash-won state).

`[Model: releaseSponsorProceeds]`
Anyone calls the function to zero the current sponsor proceeds liability and transfer that USDC amount to the immutable sponsor recipient.

`[Model: releaseProtocolFees]`
Anyone calls the function to zero the current protocol fee liability and transfer that USDC amount to the immutable protocol treasury.

`[Model: releaseSponsorPrize]`
When the raffle is in the cash-won or refunding state, anyone calls the function to mark the prize claimed and transfer the prize NFT from the raffle back to the immutable sponsor recipient.

`[Why: Raffle.sol:375]`
Why does `releaseSponsorProceeds()` not check `if (status == Status.NftWon && !prizeClaimed) revert ...` before sending 95% of the USDC pot to `sponsorRecipient`?
Because `DESIGN.md` specified *"Settlement is permissionless, storage-only ... Sponsor and treasury can claim independently after settlement"* so that a passive or reverting winner could not delay the sponsor's payout. In doing so, it assumed `prizeToken` delivery in `Status.NftWon` is guaranteed to succeed once `createRaffle` escrowed the token — directly contradicting both `DESIGN.md` (*"arbitrary prize contracts and ticket recipients are untrusted"*) and real-world ERC-721 behavior on Ethereum Mainnet (expiring ENS `.eth` domains, `ERC721C` transfer validators, pausable/revocable NFTs).

`[Defeat: releaseSponsorProceeds]`
1. Sponsor `0xAAA1` deploys an untrusted ERC-721 `prizeToken` (permitted by permissionless `RaffleFactory::createRaffle`) that allows `safeTransferFrom(sponsor, raffle, 1)` during creation, then disables transfers out of `raffle` (or returns `ownerOf(1) != winner`). Honest buyers purchase 100 entries (`100,000,000` USDC) meeting `reserveEntries = 100`. VRF resolves to `Status.NftWon`. Sponsor calls `settleWinningTicket(winningTicketId)` and `releaseSponsorProceeds()`, extracting `95,000,000` USDC while `redeemWinningTicket` permanently reverts for the winner.
2. Sponsor `0xAAA2` escrows an Ethereum Mainnet ENS `.eth` domain (`BaseRegistrarImplementation` at `0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85`, `tokenId = uint256(keccak256("example"))`) whose `expiries[tokenId]` is `block.timestamp + 3 days` in a raffle with `endTime = block.timestamp + 10 days` and `reserveEntries = 50`. Buyers purchase 50 entries (`50,000,000` USDC). After day 3, the ENS name expires (`expiries[tokenId] <= block.timestamp`). At day 10, the raffle resolves to `Status.NftWon`. Sponsor calls `settleWinningTicket` and `releaseSponsorProceeds()`, taking `47,500,000` USDC, while the winner's `redeemWinningTicket` permanently reverts inside `BaseRegistrarImplementation.ownerOf(tokenId)` (`require(expiries[tokenId] > block.timestamp)`).
3. Sponsor `0xAAA3` escrows an `ERC721C` NFT (coupled to LimitBreak's `CreatorTokenTransferValidator` at `0x721C0078c2328597Ca70F5451ffF5A7B38D4E947`) or `ERC721Pausable` NFT. While the raffle is active, the collection owner updates the validator security level to whitelist-only operators or pauses transfers. After resolution to `Status.NftWon`, `sponsor` withdraws 95% of the USDC pot via `releaseSponsorProceeds()`, while `redeemWinningTicket` reverts on `prizeToken.transferFrom`.

`[LastOut: Settlement & Claims]`
- **In `Status.CashWon`:** `protocolFee = floor(grossPot * 500 / 10_000)`, `cashAmount = floor(grossPot * 8000 / 10_000)`, and `sponsorAmount = grossPot - protocolFee - cashAmount`. Because `protocolFee + cashAmount + sponsorAmount == grossPot == quoteToken.balanceOf(address(this))`, when the winner (`redeemWinningTicket`), sponsor (`releaseSponsorProceeds`), and treasury (`releaseProtocolFees`) withdraw in any order, the last one out receives their exact USDC allocation with `0` shortfall (unless `sponsorRecipient` or `protocolTreasury` has been blacklisted by Circle USDC).
- **In `Status.NftWon`:** `protocolFee + sponsorAmount == grossPot`, so `protocolTreasury` (5%) and `sponsorRecipient` (95%) withdraw 100% of the USDC balance. However, the last user out — the winning ticket holder calling `redeemWinningTicket` for the NFT prize — is **short by the entire NFT prize (and 100% of the pot)** whenever `prizeToken.transferFrom(address(this), winner, prizeTokenId)` or `prizeToken.ownerOf(prizeTokenId) == winner` fails!

---

#### Lifecycle 5: Refund Lifecycle (`Raffle::enableRefunds` → `Raffle::refundTickets` + `Raffle::releaseSponsorPrize`)

`[Model: enableRefunds]`
Once the draw request window or VRF callback window expires (or immediately if no entries were sold and the sponsor cancels), the caller moves the entire unsettled pot into the remaining refund liability, zeroes the unsettled pot, and sets the raffle status to refunding.

`[Model: refundTickets]`
In the refunding state, a ticket owner submits a batch of 1 to 100 ticket identifiers they own. For each ticket, the raffle checks ownership, adds the number of entries in that ticket's stored range to a running total, and burns the ticket. It then multiplies the total entries by 1 USDC, subtracts that amount from the remaining refund liability, and transfers that USDC amount to the caller.

`[Why: Raffle.sol:350]`
Why is `ticketIds.length` capped at `RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE` (`100`) in `refundTickets`?
To bound per-transaction gas consumption while still allowing a user who owns more than 100 tickets to refund all of them across multiple `refundTickets` calls.

`[Defeat: refundTickets]`
1. Attacker `0xDDD1` passes duplicate ticket IDs `[1, 1]` to `refundTickets` to claim twice for `ticketId = 1`. On `index = 0`, `_burn(1)` sets `_owners[1] = address(0)`; on `index = 1`, `ownerOf(1)` reverts with `ERC721NonexistentToken(1)`.
2. Blacklisted USDC user `0xDDD2` (blacklisted on Circle `FiatTokenV2_2` `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`) cannot call `refundTickets` directly because `quoteToken.safeTransfer(0xDDD2, amount)` reverts. However, `0xDDD2` can call `Raffle::transferFrom(0xDDD2, 0xDDD3, ticketId)` to move the ERC-721 ticket to an unblacklisted address `0xDDD3`, which then calls `refundTickets` and recovers the USDC.
3. Attacker `0xDDD1` attempts to call `refundTickets` after a late VRF callback arrives at `block.timestamp >= callbackDeadline()`. Because `fulfillRandomWords` ignored the late callback, `enableRefunds()` still transitions `status` to `Status.Refunding` and `refundTickets` succeeds.

`[LastOut: Refund Lifecycle]`
When `enableRefunds()` runs, `remainingRefundLiability = unsettledPot = totalEntries * 1,000,000`. Because minted tickets `1 .. ticketCount` form an exact contiguous partition of `[1, totalEntries]`, $\sum_{i=1}^{\text{ticketCount}} (\text{lastEntry}_i - \text{firstEntry}_i + 1) \times 1{,}000{,}000 = \text{totalEntries} \times 1{,}000{,}000 = \text{remainingRefundLiability}$. As every ticket owner calls `refundTickets` in any order, the last ticket owner out receives their exact `entryCount * 1,000,000` USDC refund and `remainingRefundLiability` reaches `0` with `0` shortfall.

---

### Phase 5 — Saturation Sweep

Having identified the core integration defects, we sweep every sibling site across `Raffle.sol` and `RaffleFactory.sol`:

1. **Pattern 1 — External `prizeToken` assumptions across lifecycle states:**
   - `RaffleFactory::createRaffle` (`RaffleFactory.sol:128-131`): Calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` and checks `prize.ownerOf(params.prizeTokenId) != raffle`. Only validates at `block.timestamp` of creation.
   - `Raffle::_settleWinningTicket` (`Raffle.sol:533-558`): Allocates `sponsorProceeds = grossPot - protocolFee` in `Status.NftWon` without checking `prizeToken.ownerOf(prizeTokenId) == address(this)` or `prizeClaimed`.
   - `Raffle::releaseSponsorProceeds` (`Raffle.sol:375-382`): Releases `sponsorProceeds` to `sponsorRecipient` in `Status.NftWon` without checking `prizeClaimed == true`.
   - `Raffle::redeemWinningTicket` (`Raffle.sol:329-337`): Calls `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` and checks `prizeToken.ownerOf(deliveredPrizeTokenId) != winner`. Reverts on failure, leaving `winner` with no fallback to recover USDC in `Status.NftWon`.
   - `Raffle::releaseSponsorPrize` (`Raffle.sol:395-407`): Calls `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` and checks `prizeToken.ownerOf(prizeTokenId) != recipient` in `Status.CashWon` / `Status.Refunding`. Also note that `releaseSponsorPrize` does NOT call `_isProtocolDestination(recipient, address(prizeToken))`, unlike `_transferQuote` and `_update`.

2. **Pattern 2 — Destination screening (`_isProtocolDestination` and `_validateCreateParams`) vs future deterministic `CREATE` clones:**
   - `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:154-179`): Checks `isRaffle[params.prizeToken]` and `isRaffle[params.sponsorRecipient]`.
   - `Raffle::initialize` (`Raffle.sol:187-195`): Checks `_isProtocolDestination` for `sponsor`, `protocolTreasury`, and `sponsorRecipient`.
   - `Raffle::_update` (`Raffle.sol:497-502`): Checks `_isProtocolDestination(to, address(prizeToken))`.
   - `Raffle::_transferQuote` (`Raffle.sol:564-567`): Checks `_isProtocolDestination(to, address(prizeToken))`.
   - `Raffle::_isProtocolDestination` (`Raffle.sol:593-605`): Checks `if (!unsafeDestination && destination.code.length != 0) { unsafeDestination = canonicalFactory.isRaffle(destination); }`. None of these screen predicted `CREATE` addresses of not-yet-deployed clones from `RaffleFactory`, and `releaseSponsorPrize` omits `_isProtocolDestination` altogether.

3. **Pattern 3 — Immutable payout recipients vs Circle USDC (`FiatTokenV2_2`) blacklist:**
   - `redeemWinningTicket` (`Raffle.sol:342`) and `refundTickets` (`Raffle.sol:369`): Pay `ownerOf(ticketId)`, which is transferable via `ERC721::transferFrom` even if the current owner is blacklisted on USDC.
   - `releaseSponsorProceeds` (`Raffle.sol:380`) and `releaseProtocolFees` (`Raffle.sol:390`): Pay immutable `sponsorRecipient` and `protocolTreasury`, which have no transfer or update mechanism if blacklisted on USDC.

---

### Findings and Leads

```
FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: external-integration-untrusted-prize-token | group_key: Raffle | releaseSponsorProceeds | external-integration-untrusted-prize-token
root_cause: In Raffle.sol:375 (and Raffle.sol:543-554 in _settleWinningTicket), releaseSponsorProceeds() allows the sponsor to withdraw 95% of unsettledPot in Status.NftWon without requiring prizeClaimed == true, and Raffle provides no fallback to Refunding when prizeToken delivery fails in redeemWinningTicket (Raffle.sol:334-336).
internal_pre: A raffle reaches totalEntries >= reserveEntries and resolves to Status.NftWon.
external_pre: Either (a) the sponsor created the raffle with an untrusted ERC-721 prizeToken (permitted by permissionless RaffleFactory::createRaffle and explicitly in-scope per DESIGN.md: "arbitrary prize contracts and ticket recipients are untrusted") that blocks transfers from the raffle clone after initial escrow, or (b) the prizeToken is a real-world stateful Ethereum Mainnet ERC-721 whose transferability lapses during the up-to-34-day raffle window — such as an ENS .eth domain on BaseRegistrarImplementation (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) whose expiries[tokenId] timestamp passes after createRaffle, or an ERC721C token using CreatorTokenTransferValidator (0x721C0078c2328597Ca70F5451ffF5A7B38D4E947) / ERC721Pausable token whose transfer policy is restricted or paused while escrowed.
path:
  1. Sponsor 0xAAA1 calls RaffleFactory::createRaffle with reserveEntries = 100, endTime = uint64(block.timestamp + 7 days), and either a sponsor-deployed ERC-721 prizeToken that disables transfers when msg.sender == raffle after escrow, or an ENS .eth domain on BaseRegistrarImplementation (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85) whose expiries[prizeTokenId] is block.timestamp + 2 days. At creation time, safeTransferFrom and prize.ownerOf(prizeTokenId) == raffle both succeed.
  2. Honest buyers purchase 100 entries via buyEntries for 100,000,000 USDC (100 USDC), setting totalEntries = 100 and unsettledPot = 100,000,000.
  3. After day 2, the ENS registration expires (expiries[prizeTokenId] <= block.timestamp) or the untrusted prizeToken blocks transfers out of raffle.
  4. At day 7, requestDraw() and fulfillRandomWords() execute; because totalEntries (100) >= reserveEntries (100), status becomes Status.NftWon.
  5. Sponsor 0xAAA1 calls settleWinningTicket(winningTicketId) and releaseSponsorProceeds(), receiving 95,000,000 USDC (95% of the pot) while protocolTreasury claims 5,000,000 USDC via releaseProtocolFees().
  6. The winning ticket owner calls redeemWinningTicket(winningTicketId); prizeToken.transferFrom(address(this), winner, prizeTokenId) (or the ownerOf check at Raffle.sol:335) reverts permanently, and because Status.NftWon is terminal and unsettledPot is 0, neither the NFT nor any USDC can ever be recovered.
impact: Entry buyers / the winning ticket owner lose 100% of the raffle pot (e.g. 100,000,000 USDC) and receive no NFT prize; the winning ticket owner is left holding an unredeemable ticket while the sponsor walks away with 95% of the USDC proceeds.
mitigation: In Raffle::releaseSponsorProceeds (Raffle.sol:375), require `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();` so sponsor proceeds in Status.NftWon cannot be withdrawn until the prize NFT has been verified as delivered to the winner (and allow transitioning from unredeemed Status.NftWon to Status.Refunding after a redemption liveness window if prizeToken delivery fails).
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: token-blacklist-immutable-recipient | group_key: Raffle | releaseSponsorProceeds | token-blacklist-immutable-recipient
smell: In Raffle.sol:375 and Raffle.sol:385, sponsorRecipient and protocolTreasury are immutable addresses with no fallback recipient or claim-transfer mechanism, unlike ticket owners whose ERC-721 tickets remain transferable via Raffle::_update even if blacklisted by Circle USDC (FiatTokenV2_2 at 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).
unverified: Whether Circle blacklisting sponsorRecipient or protocolTreasury during a raffle's lifecycle is considered an actionable protocol defect given that independent pull functions prevent any cross-cohort contagion to ticket buyers or winners.
description: If sponsorRecipient or protocolTreasury is blacklisted on canonical USDC (FiatTokenV2_2), releaseSponsorProceeds() or releaseProtocolFees() permanently reverts on quoteToken.safeTransfer, stranding that cohort's own USDC allocation inside the clone.
```

```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: precomputed-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | precomputed-clone-destination-bypass
smell: In Raffle.sol:602 (and RaffleFactory.sol:163), _isProtocolDestination only checks `destination.code.length != 0` and `canonicalFactory.isRaffle(destination)` against already-created clones, while Raffle::releaseSponsorPrize (Raffle.sol:395) omits `_isProtocolDestination` entirely; because RaffleFactory.sol:106 uses `Clones.clone` (deterministic CREATE based on factory nonce), a future raffle clone's address passes `_isProtocolDestination` before that clone is created and becomes a registered raffle afterward.
unverified: A concrete path where an attacker uses a precomputed future clone address to strand another user's funds rather than only stranding the caller's own sponsorRecipient payout/prize or the caller's own transferred ticket.
description: Setting sponsorRecipient or transferring a ticket in Raffle 1 to the deterministic CREATE address of a not-yet-deployed Raffle 2 bypasses _isProtocolDestination at setup/transfer time and later causes releaseSponsorProceeds/redeemWinningTicket to revert (or releaseSponsorPrize to push Raffle 1's prize NFT into Raffle 2) once Raffle 2 is created.
```

```
LEAD | contract: Raffle | function: requestDraw | bug_class: vrf-requester-unreimbursed-fee-loss | group_key: Raffle | requestDraw | vrf-requester-unreimbursed-fee-loss
smell: In Raffle.sol:240-273, requestDraw() requires a permissionless caller to pay `paidPrice` in native ETH to Chainlink's VRFV2PlusWrapper with no reimbursement from the raffle pot and no refund if the VRF callback misses `callbackDeadline()` (`drawRequestedAt + 2 days`) and `enableRefunds()` is triggered.
unverified: Whether an external actor can profitably force a callback timeout on canonical Chainlink VRF v2.5 after an honest user pays `paidPrice` in `requestDraw()`, beyond natural Chainlink wrapper/network outage.
description: If the Chainlink VRF v2.5 wrapper fails to fulfill before `callbackDeadline()`, `enableRefunds()` makes ticket buyers and the sponsor whole, leaving the caller who funded `requestDraw()` holding the entire loss of the `paidPrice` native VRF fee.
```
