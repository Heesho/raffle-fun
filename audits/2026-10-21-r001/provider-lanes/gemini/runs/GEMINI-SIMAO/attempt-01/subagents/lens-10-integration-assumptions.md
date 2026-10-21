# 0xSimao Audit Report — Lens 10 (Integration & Environment Assumptions)

## Working Protocol Trace & Reasoning Markers

`[Model: createRaffle]`
A sponsor supplies a prize NFT contract, token ID, sponsor payout recipient, minimum reserve entry count, and sale end timestamp. The factory validates the parameters, increments the raffle counter, deploys a new raffle clone, initializes the clone in the AwaitingPrize state, registers the clone in the factory mappings, transfers the prize NFT from the sponsor into the clone (which triggers the clone's receiver hook to move its status to Active), verifies the clone now owns the prize NFT and is in the Active state, and emits the creation event.

`[Why: RaffleFactory.sol:106]`
Why does `RaffleFactory::createRaffle` deploy clones with `Clones.clone(raffleImplementation)` (`CREATE`) while relying on `isRaffle[destination]` and `destination.code.length != 0` in `Raffle::_isProtocolDestination` (`Raffle.sol:602`) to block raffle clones from ever owning tickets or receiving payouts?
The code rests on the implicit belief that a `Raffle` clone address cannot be known or used as a ticket recipient or payout destination before `createRaffle` deploys it. In reality, `CREATE` addresses deployed by `RaffleFactory` are 100% deterministic from `address(factory)` and the factory's contract nonce (`raffleCount + 1`), and before deployment they have `code.length == 0` and `isRaffle[futureRaffle] == false`.

`[Defeat: _isProtocolDestination]`
1. Compute `futureRaffle2 = address(uint160(uint256(keccak256(rlp.encode([address(factory), uint256(3)])))))` before Raffle #2 is created. At this moment `futureRaffle2.code.length == 0` and `isRaffle[futureRaffle2] == false`. Call `Raffle(raffle1).buyEntries(futureRaffle2, 1)` paying `1_000_000` USDC. Both `_isProtocolDestination(futureRaffle2, address(prizeToken))` in `_update` and `ERC721Utils.checkOnERC721Received` in `_safeMint` treat `futureRaffle2` as a benign EOA. Then call `RaffleFactory::createRaffle` to deploy Raffle #2 at `futureRaffle2`, making `futureRaffle2` a registered `Raffle` clone that now owns `ticketId` in Raffle #1 with no function to redeem, refund, or transfer it.
2. Create Raffle #1 with `params.sponsorRecipient = futureRaffle2` before Raffle #2 is deployed. Both `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:168`) and `Raffle::initialize` (`Raffle.sol:193`) pass because `isRaffle[futureRaffle2] == false` and `futureRaffle2.code.length == 0`. Once Raffle #2 is deployed at `futureRaffle2`, `isRaffle[futureRaffle2]` becomes `true`. When Raffle #1 settles, `releaseSponsorProceeds()` calls `_transferQuote(futureRaffle2, amount)` (`Raffle.sol:565`), which re-checks `_isProtocolDestination` and permanently reverts with `InvalidQuoteDestination(futureRaffle2)`.
3. In the same state (`sponsorRecipient == futureRaffle2` after Raffle #2 is deployed), if Raffle #1 resolves to `CashWon` or `Refunding`, calling `releaseSponsorPrize()` (`Raffle.sol:404`) executes `prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId)` without checking `_isProtocolDestination` and without `safeTransferFrom`, transferring Raffle #1's prize NFT directly into Raffle #2 (`futureRaffle2`) where it is permanently locked outside protocol accounting.

`[Model: buyEntries]`
While the raffle is active and before the sale end time, a buyer specifies a recipient address and a positive number of entries to buy. The buyer pays one unit of quote token (1,000,000 raw units) per entry into the raffle. The contract assigns the next contiguous range of entry numbers from the old total entries plus one up to the new total entries, increments the ticket counter by one, records that entry range for the new ticket ID, adds the paid quote tokens to the unsettled pot, and mints the new ticket NFT to the recipient.

`[Why: Raffle.sol:235]`
Why does `buyEntries` invoke `_safeMint(recipient, ticketId)` only after updating `totalEntries`, `ticketCount`, `_ticketRanges[ticketId]`, and `unsettledPot`?
Because `recipient` is an untrusted address that receives an `onERC721Received` callback if `recipient.code.length > 0`, and any state read or ERC-721 ticket transfer triggered inside that callback must observe fully updated accounting and range storage.

`[Defeat: buyEntries]`
1. Deploy a contract `MaliciousRecipient` whose `onERC721Received` calls `Raffle::buyEntries`, `Raffle::enableRefunds`, or `Raffle::refundTickets`: blocked by `nonReentrant` (`ReentrancyGuardReentrantCall()`).
2. Have `MaliciousRecipient::onERC721Received` call `Raffle::transferFrom(address(MaliciousRecipient), EOA, ticketId)` (which does not have `nonReentrant`): `_mint` already set `_owners[ticketId] = MaliciousRecipient` and `_ticketRanges[ticketId]` is already populated, so the transfer succeeds cleanly without corrupting entry ranges or `unsettledPot`.
3. Call `buyEntries(futureRaffle, 1)` where `futureRaffle` is the next deterministic `CREATE` address of `RaffleFactory`: because `futureRaffle.code.length == 0` at mint time, `ERC721Utils.checkOnERC721Received` skips the callback and `_isProtocolDestination` returns `false`, allowing a future `Raffle` clone to own a ticket.

`[Model: requestDraw]`
When the ticket sale time has ended and at least one entry was bought, any caller can initiate the random draw within two days of the sale end by sending native currency (ETH) to cover the random number provider's fee. The raffle transitions its status from Active to Drawing, records the current timestamp as the request time, pays the random number wrapper the price it calculates in native currency, stores the returned request identifier, and sends any leftover native currency back to the caller. No quote token totals change.

`[Why: Raffle.sol:254-260]`
Why does `requestDraw` set `_requestInFlight = true` before calling `requestRandomnessPayInNative` and clear it only after storing `vrfRequestId = requestId`?
Because if a wrapper implementation synchronously invoked `rawFulfillRandomWords` inside `requestRandomWordsInNative` before `vrfRequestId` was written to storage, `fulfillRandomWords` would compare `requestId` against `vrfRequestId == 0` unless explicitly guarded by `_requestInFlight`.

`[Defeat: requestDraw]`
1. Call `requestDraw()` from a contract whose `receive()` reverts when `excess > 0` (`msg.value > paidPrice`): the entire `requestDraw()` call reverts via `NativeRefundFailed`, leaving the raffle in `Status.Active` for any honest caller to call `requestDraw()` with exact `quotedFee`.
2. Force native ETH into the `Raffle` clone via `selfdestruct` before `requestDraw()` and call `requestDraw()` with `msg.value < getVrfRequestPrice()`: blocked by `if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value)` at `Raffle.sol:250` and `if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value)` at `Raffle.sol:258`.
3. Call `requestDraw()` at `block.timestamp == drawRequestDeadline()`: reverts with `DrawRequestWindowExpired`, cleanly handing over to `enableRefunds()`.

`[Model: enableRefunds]`
When a raffle has no entries sold (either canceled early by the sponsor before the sale end, or by anyone at or after the sale end), or when entries were sold but nobody requested a draw within two days after the sale end, or when a draw was requested but the random number callback did not arrive within two days of the request, this function transitions the raffle to the Refunding state. It moves the entire unsettled pot into the remaining refund liability and zeroes the unsettled pot.

`[Model: settleWinningTicket]`
When the raffle has resolved to either an NFT win or a cash win, anyone can pass the ticket ID that covers the winning entry number. The contract checks that the ticket's entry range contains the winning entry, calculates the 5% protocol fee (rounded down) and, for a cash win, the 80% cash winner share (rounded down), assigns the remaining quote tokens from the unsettled pot to the sponsor proceeds, sets the unsettled pot to zero, records the winning ticket ID, and marks settlement as complete. No tokens or NFTs are transferred.

`[Model: redeemWinningTicket]`
When the raffle has resolved to either an NFT win or a cash win, the current owner of the winning ticket calls this function to claim their prize. If the winning ticket has not been settled yet, the contract first settles the pot by splitting the unsettled pot into protocol fees (5% rounded down), cash winner proceeds (80% rounded down, only if cash win), and sponsor proceeds (the remainder), and zeroes the unsettled pot. Then the contract verifies the caller owns the winning ticket, records the caller as the winner recipient, marks the winning ticket as redeemed, and destroys the winning ticket. If the outcome is an NFT win, it marks the prize as claimed, transfers the escrowed prize NFT to the winner, and verifies the winner now owns the NFT. If the outcome is a cash win, it zeroes the winner proceeds and transfers that amount of quote token to the winner.

`[Model: releaseSponsorProceeds]`
Anyone can trigger the payout of the sponsor's allocated quote token proceeds. The contract reads the current sponsor proceeds, zeroes that storage variable, and transfers that amount of quote tokens to the configured sponsor recipient address.

`[Why: Raffle.sol:533-558]`
Why does `_settleWinningTicket` allocate `sponsorProceeds` and `protocolFees` in `Status.NftWon` without transferring the prize NFT or requiring `prizeClaimed == true` before `releaseSponsorProceeds()` can be called?
The code assumes that because `RaffleFactory::createRaffle` verified `prize.ownerOf(prizeTokenId) == raffle` at creation time (`RaffleFactory.sol:129`), `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` in `redeemWinningTicket` (`Raffle.sol:334`) will always succeed weeks later after the raffle resolves to `Status.NftWon`. This assumption fails both for untrusted/sponsor-controlled ERC-721 contracts (`DESIGN.md`: *"arbitrary prize contracts and ticket recipients are untrusted"*) and for real-world expiring/pausable ERC-721 contracts on Ethereum Mainnet (such as ENS `BaseRegistrarImplementation` at `0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA8`, where `ownerOf` and `transferFrom` revert as soon as `block.timestamp >= expiries[tokenId]`).

`[Model: refundTickets]`
When the raffle is in the Refunding state, a ticket holder passes a list of between 1 and 100 ticket IDs they own. For each ticket ID, the contract verifies the caller is the current owner, reads the ticket's stored first and last entry numbers to add its entry count to the batch total, and destroys the ticket. It then multiplies the total entries in the batch by the entry price, subtracts that amount from the remaining refund liability, and transfers that amount of quote tokens to the caller.

`[LastOut: NftWon]`
Buyers purchase `totalEntries >= reserveEntries` entries, depositing `grossPot = totalEntries * 1,000,000` USDC into `unsettledPot`. After `requestDraw()` and `fulfillRandomWords`, `status == Status.NftWon`.
1. `settleWinningTicket(winningTicketId)` splits `unsettledPot` into `protocolFees = totalEntries * 50,000` and `sponsorProceeds = totalEntries * 950,000`, setting `unsettledPot = 0`.
2. Protocol Treasury calls `releaseProtocolFees()` and receives `totalEntries * 50,000` USDC.
3. Sponsor calls `releaseSponsorProceeds()` and receives `totalEntries * 950,000` USDC (`0` USDC remaining, no shortfall).
4. Winning ticket owner calls `redeemWinningTicket(winningTicketId)`: if `prizeToken.transferFrom(address(this), winner, prizeTokenId)` succeeds, the winner receives the NFT; however, if `prizeToken.transferFrom` reverts (e.g., expired ENS `.eth` NFT or untrusted `prizeToken` blocking transfer) or if `ownerOf(winningTicketId)` is a `Raffle` clone deployed at a precomputed `CREATE` address, the last user out (the winner) gets nothing while the Sponsor and Treasury have already withdrawn 100% of the USDC pot.

`[LastOut: CashWon]`
Buyers purchase `0 < totalEntries < reserveEntries` entries, depositing `grossPot = totalEntries * 1,000,000` USDC into `unsettledPot`. After `requestDraw()` and `fulfillRandomWords`, `status == Status.CashWon`.
1. Sponsor calls `releaseSponsorPrize()` and recovers `(prizeToken, prizeTokenId)`.
2. `settleWinningTicket(winningTicketId)` sets `protocolFees = totalEntries * 50,000`, `winnerProceeds = totalEntries * 800,000`, and `sponsorProceeds = grossPot - protocolFees - winnerProceeds = totalEntries * 150,000`.
3. Protocol Treasury calls `releaseProtocolFees()` and receives `totalEntries * 50,000` USDC.
4. Winning ticket owner calls `redeemWinningTicket(winningTicketId)` and receives `totalEntries * 800,000` USDC.
5. Sponsor calls `releaseSponsorProceeds()` last and receives `totalEntries * 150,000` USDC in full (`0` USDC shortfall).

`[LastOut: Refunding]`
Buyers `1..k` purchase `e_1..e_k` entries (`totalEntries = Σ e_i`), depositing `unsettledPot = (Σ e_i) * 1,000,000` USDC. After `enableRefunds()`, `remainingRefundLiability = (Σ e_i) * 1,000,000` and `unsettledPot = 0`.
1. Sponsor calls `releaseSponsorPrize()` and recovers `(prizeToken, prizeTokenId)`.
2. Ticket owners `1..k-1` call `refundTickets` and withdraw `(Σ_{i=1}^{k-1} e_i) * 1,000,000` USDC.
3. Ticket owner `k` calls `refundTickets([k])` last and withdraws `e_k * 1,000,000` USDC in full, reducing `remainingRefundLiability` and contract USDC balance to `0`.

---

## Findings & Leads

```
FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: external-integration-dos | group_key: Raffle | releaseSponsorProceeds | external-integration-dos
root_cause: In Raffle.sol:554 (_settleWinningTicket) and Raffle.sol:376-380 (releaseSponsorProceeds), sponsorProceeds (95% of grossPot) and protocolFees (5% of grossPot) in Status.NftWon are credited and released without requiring prizeClaimed == true or verifying that prizeToken.transferFrom(address(this), winner, prizeTokenId) in redeemWinningTicket (Raffle.sol:334) succeeded.
internal_pre: None
external_pre: Either (a) prizeToken is an expiring ERC-721 on Ethereum Mainnet such as ENS BaseRegistrarImplementation (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA8) whose nameExpires(prizeTokenId) timestamp passes after createRaffle, or a pausable/freezeable ERC-721 that pauses/freezes before redemption, or (b) prizeToken is an untrusted ERC-721 contract (explicitly in-scope per DESIGN.md: "arbitrary prize contracts and ticket recipients are untrusted") that reverts on transferFrom after status reaches Status.NftWon.
path:
  1. Sponsor calls RaffleFactory::createRaffle with an ENS .eth NFT on Mainnet (0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA8) that expires at t0 + 1 day (or an untrusted ERC-721 contract), setting reserveEntries = 10_000 (10,000 USDC) and endTime = t0 + 7 days. At t0, prize.safeTransferFrom(sponsor, raffle, prizeTokenId) and prize.ownerOf(prizeTokenId) == raffle both succeed.
  2. Buyers call Raffle::buyEntries to purchase 10,000 entries for 10,000,000,000 raw USDC (10,000 USDC).
  3. At t0 + 1 day, the ENS .eth NFT expires (so ENS BaseRegistrarImplementation.ownerOf(prizeTokenId) and transferFrom now revert with require(expiries[tokenId] > block.timestamp)), or the untrusted prizeToken blocks transferFrom from the raffle address.
  4. At t0 + 7 days, requestDraw() is called and Chainlink VRF fulfills randomness, setting status = Status.NftWon (since totalEntries == 10_000 >= reserveEntries).
  5. Sponsor calls settleWinningTicket(winningTicketId) and releaseSponsorProceeds(), withdrawing 9,500,000,000 raw USDC (9,500 USDC) to sponsorRecipient, and protocolTreasury withdraws 500,000,000 raw USDC (500 USDC) via releaseProtocolFees().
  6. Winning ticket owner calls redeemWinningTicket(winningTicketId), which reverts at Raffle.sol:334 when calling prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId). Because status is terminally Status.NftWon, enableRefunds() reverts with InvalidStatus(Status.NftWon).
impact: The winning ticket owner (and ticket buyers collectively) lose 10,000 USDC (9,500 USDC paid to sponsorRecipient and 500 USDC paid to protocolTreasury) while the winning ticket owner is left holding an unredeemable winning ticket with neither the prize NFT nor a USDC refund path.
mitigation: In Raffle.sol:375 (releaseSponsorProceeds) and Raffle.sol:385 (releaseProtocolFees), require `if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);` so sponsor proceeds and protocol fees in Status.NftWon can only be released after the prize NFT has been successfully delivered to the winner in redeemWinningTicket (or allow transitioning to Status.Refunding if prize delivery fails before proceeds are released).
```

```
FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: deterministic-clone-address-bypass | group_key: Raffle | _isProtocolDestination | deterministic-clone-address-bypass
root_cause: In Raffle.sol:602 (_isProtocolDestination) and RaffleFactory.sol:159,166 (_validateCreateParams), protocol-sink screening only checks canonicalFactory.isRaffle(destination) on already-deployed clones (destination.code.length != 0) while RaffleFactory::createRaffle (RaffleFactory.sol:106) deploys clones via Clones.clone (CREATE) at deterministic future addresses, and Raffle::releaseSponsorPrize (Raffle.sol:404) / Raffle::redeemWinningTicket (Raffle.sol:334) do not re-check _isProtocolDestination before calling prizeToken.transferFrom.
internal_pre: None
external_pre: None
path:
  1. Honest Sponsor creates Raffle #1 (raffleId = 1, deployed at factory CREATE nonce 2) with a prize NFT worth 10,000 USDC and reserveEntries = 100. Honest buyers purchase 99 entries (99 USDC).
  2. Attacker computes the deterministic CREATE address of Raffle #2 (factory CREATE nonce 3): futureRaffle2 = address(uint160(uint256(keccak256(rlp.encode([address(factory), uint256(3)]))))). Because Raffle #2 is not deployed yet, futureRaffle2.code.length == 0 and factory.isRaffle(futureRaffle2) == false.
  3. Attacker calls Raffle(raffle1).buyEntries(futureRaffle2, 1) paying 1,000,000 raw USDC (1 USDC). Inside _safeMint(futureRaffle2, ticketId), _update calls _isProtocolDestination(futureRaffle2, address(prizeToken)) which returns false, and ERC721Utils.checkOnERC721Received skips onERC721Received because futureRaffle2.code.length == 0.
  4. Any user (or the attacker) calls RaffleFactory::createRaffle to create Raffle #2, which deploys a Raffle clone at futureRaffle2 and sets isRaffle[futureRaffle2] = true.
  5. After endTime on Raffle #1, requestDraw() and fulfillRandomWords select entry #100 (ticketId owned by futureRaffle2) in Status.NftWon (or Status.CashWon). Because futureRaffle2 is a Raffle clone with no function to call redeemWinningTicket, refundTickets, or transferFrom on external ERC-721 tickets, redeemWinningTicket can never be called and the prize NFT (in NftWon) or 80% winnerProceeds (in CashWon) is permanently frozen inside Raffle #1. (Additionally, if sponsorRecipient in Raffle #1 was set to futureRaffle2, releaseSponsorProceeds() permanently reverts with InvalidQuoteDestination(futureRaffle2) at Raffle.sol:565, while releaseSponsorPrize() at Raffle.sol:404 transfers Raffle #1's prize NFT directly into Raffle #2, violating "Never move assets between raffle clones".)
impact: In Raffle #1, the escrowed prize NFT (in Status.NftWon), the 80% winnerProceeds (in Status.CashWon), or the refund liability for the ticket (in Status.Refunding) is permanently frozen in Raffle #1 with no recovery path for either the winner or the sponsor; if futureRaffle2 is used as sponsorRecipient, sponsorProceeds are permanently frozen in Raffle #1 and releaseSponsorPrize() permanently locks the prize NFT inside Raffle #2.
mitigation: In Raffle::buyEntries (Raffle.sol:235) or Raffle::_update (Raffle.sol:497), or by deploying clones in RaffleFactory::createRaffle with Clones.cloneDeterministic using a salt bound to `keccak256(abi.encode(msg.sender, params, block.Hash/prevrandao))` or checking `_isProtocolDestination` in `releaseSponsorPrize` (Raffle.sol:404) and `redeemWinningTicket` (Raffle.sol:334), prevent precomputed future clone addresses from passing `_isProtocolDestination` and prevent `releaseSponsorPrize` from transferring NFTs to registered raffle clones.
```

```
LEAD | contract: RaffleFactory | function: createRaffle | bug_class: mutable-erc721-prize-stripping | group_key: RaffleFactory | createRaffle | mutable-erc721-prize-stripping
smell: In RaffleFactory.sol:128-131 and Raffle.sol:334-336, prize integrity is verified solely via IERC721.ownerOf(prizeTokenId), which does not detect when an honest, standards-compliant ERC-721 position NFT (such as a cancelable Sablier V2 LockupLinear/LockupDynamic stream NFT on Ethereum Mainnet) has its underlying tokens canceled or withdrawn by the original sender (sponsor) while the ERC-721 token itself remains owned by the Raffle clone.
unverified: Whether non-collectible DeFi position ERC-721s like Sablier V2 streams are intended to be supported by the frontend discovery layer without collection whitelisting.
description: A sponsor can escrow a cancelable Sablier V2 stream ERC-721 in createRaffle, let buyers fund the raffle pot past reserveEntries, and call cancel() on Sablier to claw back the underlying streamed tokens while leaving the empty ERC-721 shell in the Raffle clone for the winner.
```

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: blacklisted-recipient-locked-funds | group_key: Raffle | releaseSponsorProceeds | blacklisted-recipient-locked-funds
smell: In Raffle.sol:375-382 (releaseSponsorProceeds) and Raffle.sol:385-392 (releaseProtocolFees), quote-token payouts are sent exclusively to the immutable per-raffle sponsorRecipient and protocolTreasury addresses with no fallback recipient mechanism if either address is blacklisted by canonical USDC (FiatTokenV2_2 at 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4 on Mainnet), whereas ticket holders can bypass a personal USDC blacklist by transferring their Raffle ERC-721 ticket to an unblacklisted address before calling redeemWinningTicket or refundTickets.
unverified: Concrete trigger causing Circle/Centre to blacklist sponsorRecipient or protocolTreasury during an active raffle window.
description: If sponsorRecipient or protocolTreasury is blacklisted by USDC after raffle creation, releaseSponsorProceeds() or releaseProtocolFees() permanently reverts in quoteToken.safeTransfer, stranding those allocated USDC proceeds in the Raffle clone forever.
```

```
LEAD | contract: RaffleFactory | function: constructor | bug_class: parameter-validation | group_key: RaffleFactory | constructor | parameter-validation
smell: In RaffleFactory.sol:80-90, the constructor validates protocolTreasury_ against address(this), quoteToken_, vrfWrapper_, and implementation, but does not prevent protocolTreasury_ from matching a deterministic future Raffle clone CREATE address (keccak256(rlp.encode([address(this), nonce])) for nonce >= 2).
unverified: Why the factory deployer would supply a future CREATE address of the factory as protocolTreasury_.
description: If protocolTreasury_ is set to the k-th clone's deterministic CREATE address, Raffles 1..k-1 have their releaseProtocolFees() permanently bricked once clone k is deployed, and deploying clone k reverts in Raffle::initialize at Raffle.sol:190 (destination == address(this)), permanently bricking RaffleFactory::createRaffle for all subsequent raffles.
```
