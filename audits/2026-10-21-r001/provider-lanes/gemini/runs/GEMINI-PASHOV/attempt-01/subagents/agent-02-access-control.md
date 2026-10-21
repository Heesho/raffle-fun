FINDING | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-protocol-destination-check | group_key: Raffle | releaseSponsorPrize | missing-protocol-destination-check
guard_gap: `Raffle.releaseSponsorPrize` (lines 408-420) and the `Status.NftWon` branch of `Raffle.redeemWinningTicket` (lines 342-350) transfer `prizeToken` without calling `_isProtocolDestination(recipient, address(prizeToken))`, whereas `Raffle._transferQuote` (line 578) and `Raffle._update` (line 511) enforce `_isProtocolDestination`. Furthermore, `RaffleFactory.createRaffle` (line 739) deploys clones via `Clones.clone(raffleImplementation)` using predictable `CREATE` nonces, so a precomputed future clone address has `code.length == 0` and `isRaffle == false` during `RaffleFactory._validateCreateParams` and `Raffle.initialize`.
path: sponsor -> RaffleFactory.createRaffle (with sponsorRecipient = precomputed next clone address) -> RaffleFactory.createRaffle (deploys second clone at sponsorRecipient, setting isRaffle[sponsorRecipient] = true) -> Raffle.releaseSponsorProceeds reverts with InvalidQuoteDestination while Raffle.releaseSponsorPrize transfers prizeToken into the second Raffle clone
proof:
1. `RaffleFactory` is deployed at `factory`. In its constructor, `new Raffle(...)` consumes factory nonce 1.
2. Raffle #1 (`raffleId = 1`) will be deployed at `clone1 = address(keccak256(rlp([factory, 2])))`, and Raffle #2 (`raffleId = 2`) will be deployed at `clone2 = address(keccak256(rlp([factory, 3])))`.
3. Before Raffle #2 exists, `clone2.code.length == 0` and `factory.isRaffle(clone2) == false`.
4. Sponsor calls `factory.createRaffle` for Raffle #1 with `params.sponsorRecipient = clone2`.
   - `RaffleFactory._validateCreateParams` (lines 796-802) checks `isRaffle[clone2]`, which is `false`.
   - `Raffle.initialize` (lines 206-208) calls `_isProtocolDestination(clone2, params.prizeToken)`, which checks `clone2.code.length != 0 && canonicalFactory.isRaffle(clone2)` (lines 615-617) and returns `false`.
5. Anyone calls `factory.createRaffle` for Raffle #2. `Clones.clone(raffleImplementation)` deploys Raffle #2 at `clone2` (`clone2.code.length == 45`) and line 758 sets `isRaffle[clone2] = true`.
6. If Raffle #1 resolves to `Status.NftWon` or `Status.CashWon` and settles, calling `clone1.releaseSponsorProceeds()` executes `_transferQuote(clone2, amount)` (line 393 -> line 578). `_isProtocolDestination(clone2, address(prizeToken))` now returns `true` because `clone2.code.length == 45` and `factory.isRaffle(clone2) == true`, reverting with `InvalidQuoteDestination(clone2)` and permanently locking `sponsorProceeds` inside `clone1`.
7. If Raffle #1 ends in `Status.CashWon` or `Status.Refunding`, calling `clone1.releaseSponsorPrize()` (lines 408-420) skips `_isProtocolDestination` and executes `prizeToken.transferFrom(clone1, clone2, prizeTokenId)` (line 417), moving Raffle #1's prize NFT into Raffle #2 (`clone2`) in violation of DESIGN.md ("Never move assets between raffle clones") and permanently stranding the NFT inside `clone2`.
description: A sponsor sets `sponsorRecipient` to a next clone address, so after clone deployment `releaseSponsorProceeds` reverts and `releaseSponsorPrize` sends the prize to that clone.
fix: Check `_isProtocolDestination(recipient, address(prizeToken))` in `releaseSponsorPrize` and deploy clones with `Clones.cloneDeterministic` and a sender salt.

FINDING | contract: Raffle | function: _update | bug_class: unregistered-clone-ticket-recipient | group_key: Raffle | _update | unregistered-clone-ticket-recipient
guard_gap: `Raffle._update` (lines 510-515) calls `_isProtocolDestination(to, address(prizeToken))` (lines 606-618), which only rejects addresses where `destination.code.length != 0 && canonicalFactory.isRaffle(destination)`. Because `RaffleFactory.createRaffle` (line 739) uses `Clones.clone(raffleImplementation)` (`CREATE`), any future clone address has `code.length == 0` and `isRaffle == false` until `createRaffle` is called, bypassing both `_isProtocolDestination` in `_update` and `checkOnERC721Received` in `_safeMint`.
path: buyer -> Raffle.buyEntries(futureCloneAddress, entryCount) or ERC721.transferFrom(owner, futureCloneAddress, ticketId) -> RaffleFactory.createRaffle (deploys clone at futureCloneAddress) -> ticket and its underlying quoteToken or prizeToken claim are permanently locked in Raffle
proof:
1. While `clone1` (`raffleId = 1`) is in `Status.Active`, the next clone address to be deployed by `factory` is `clone2 = address(keccak256(rlp([factory, 3])))`.
2. Before Raffle #2 is created, `clone2.code.length == 0` and `factory.isRaffle(clone2) == false`.
3. A caller calls `clone1.buyEntries(clone2, 10)` (or `clone1.transferFrom(caller, clone2, ticketId)`).
   - Inside `_update(clone2, ticketId, auth)` (line 511), `_isProtocolDestination(clone2, address(prizeToken))` evaluates `clone2.code.length != 0` as `false` and returns `false`.
   - Inside `_safeMint(clone2, ticketId)` -> `ERC721Utils.checkOnERC721Received` (line 3112), `if (to.code.length > 0)` is `false`, so the mint succeeds without calling `clone2.onERC721Received`.
4. Next, `factory.createRaffle` is called, deploying Raffle #2 at `clone2` and setting `isRaffle[clone2] = true`.
5. `clone2` is now a registered `Raffle` clone that owns `ticketId` in `clone1`. `Raffle` has no function to transfer, refund, or redeem tickets it owns in another raffle, and `_transferQuote` on `clone1` now rejects `clone2` with `InvalidQuoteDestination(clone2)`.
6. If `clone1` enters `Status.Refunding`, `10 * ENTRY_PRICE` (10,000,000 USDC units) of `remainingRefundLiability` can never be refunded. If `clone1` resolves to `Status.NftWon` or `Status.CashWon` with `winningEntry` inside `ticketId`, `redeemWinningTicket(ticketId)` requires `msg.sender == ownerOf(ticketId) == clone2` (line 334), permanently locking the prize NFT or `winnerProceeds` in `clone1`.
description: A buyer mints or transfers a ticket to a next clone address before deployment, so the new clone owns an unclaimable ticket.
fix: Deploy each clone in `RaffleFactory.createRaffle` with `Clones.cloneDeterministic` and a salt that includes `msg.sender` and `block.timestamp`.

LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: unverified-prize-delivery-before-sponsor-payout | group_key: Raffle | releaseSponsorProceeds | unverified-prize-delivery-before-sponsor-payout
code_smells: `settleWinningTicket` allocates `sponsorProceeds` before `redeemWinningTicket` transfers `prizeToken`, and `releaseSponsorProceeds` does not check `prizeClaimed` when `status` is `Status.NftWon`.
description: A sponsor supplies a `prizeToken` that reverts in `redeemWinningTicket` and still takes `sponsorProceeds`, though `IRaffle` assumes honest `prizeToken` contracts.

LEAD | contract: Raffle | function: requestDraw | bug_class: low-gas-price-vrf-request | group_key: Raffle | requestDraw | low-gas-price-vrf-request
code_smells: Any caller can call `requestDraw`, and `i_vrfV2PlusWrapper.calculateRequestPriceNative` computes the fee from the transaction gas price of that caller.
description: An attacker calls `requestDraw` with a low gas price to delay callback fulfillment past `callbackDeadline`, though rules for wrapper gas are outside scope.
