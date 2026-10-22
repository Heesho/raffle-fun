[Model: gpt-daybreak-blue-latest] `createRaffle`: the sponsor gives one NFT and receives a contingent sponsor claim; the factory increments its raffle count, binds the new clone in all three registry views, and activates the raffle after reported custody.

[Model: gpt-daybreak-blue-latest] `initialize`: no asset moves; the clone records the sponsor, beneficiaries, prize, reserve, and deadline, then becomes ready to receive the prize.

[Model: gpt-daybreak-blue-latest] `onERC721Received`: the sponsor gives the configured NFT, the raffle is meant to gain custody, and its state changes from waiting for the prize to selling entries.

[Model: gpt-daybreak-blue-latest] `buyEntries`: the buyer gives exactly one USDC per entry, the recipient gets a transferable ticket covering those entries, and sold entries, ticket count, and the unallocated pot increase by matching amounts.

[Model: gpt-daybreak-blue-latest] `_update`: the current owner gives a ticket claim to a recipient; ownership changes but sold entries and all USDC liabilities remain unchanged.

[Model: gpt-daybreak-blue-latest] `requestDraw`: the caller gives the Chainlink native fee, receives any excess back, and the raffle records that a draw is pending together with its request identifier and time.

[Model: gpt-daybreak-blue-latest] `fulfillRandomWords`: nobody gives or receives an asset; one sold entry becomes the winner and the raffle records either the NFT or cash result.

[Model: gpt-daybreak-blue-latest] `enableRefunds`: no new asset moves; the entire unallocated USDC pot becomes an equal aggregate refund obligation.

[Model: gpt-daybreak-blue-latest] `_settleWinningTicket`: no asset moves; the unallocated pot becomes winner, sponsor, and treasury claims whose sum equals the prior pot.

[Model: gpt-daybreak-blue-latest] `redeemWinningTicket`: the current winner gives up and burns the winning ticket, receiving either the configured NFT or the entire recorded cash-winner claim.

[Model: gpt-daybreak-blue-latest] `refundTickets`: the caller burns owned tickets, receives one USDC per represented entry, and the aggregate refund obligation decreases by exactly that payment.

[Model: gpt-daybreak-blue-latest] `releaseSponsorProceeds`: the sponsor beneficiary receives its entire recorded USDC claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest] `releaseProtocolFees`: the treasury receives its entire recorded fee claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest] `releaseSponsorPrize`: after a cash or refund result, the sponsor beneficiary receives the escrowed NFT and the prize is marked released.

[Why: RaffleFactory.sol:172] Why does the collection’s own claim that it implements ERC-721 establish safe ownership semantics? It does not; the check assumes an expressly untrusted collection reports its capabilities honestly and has no privileged seizure path.

[Why: RaffleFactory.sol:129] Why is `ownerOf` an independent escrow proof? It is not: the same prize contract controls the transfer behavior, receiver call, and ownership answer.

[Why: Raffle.sol:254] Why ignore a callback during the request call? The code assumes the official Chainlink wrapper is asynchronous; a synchronous wrapper would spend the fee but have its only callback discarded.

[Why: Raffle.sol:258] Why compare the actual fee only after requesting? The inherited call recomputes and sends the fee first; safety rests on reverting the entire wrapper interaction if it exceeded this caller’s payment.

[Why: Raffle.sol:334] Why deliver the prize without recipient acceptance? The code assumes a contract that can own and redeem the ticket can also control any arbitrary prize deposited into it.

[Why: Raffle.sol:566] Why does a correctly debited claim imply it remains payable? It assumes canonical USDC will not freeze the immutable clone or payout address.

[Why: Raffle.sol:602] Why skip the registry query for an address without code? It assumes every unsafe raffle destination already has code; this excludes current same-factory clones but not future or foreign-factory clone addresses.

[Defeat: createRaffle] 1) Mallory’s `AdminSeizablePrize721` genuinely transfers token 7 and passes both checks, then Mallory seizes it after buyers pay. 2) `SpoofPrize721` calls the receiver with Mallory, factory, and token 7 without transferring and reports the clone from `ownerOf`. 3) A malicious prize reenters during escrow and buys ten entries; it must pay ten USDC, so accounting remains exact. Moves 1 and 2 defeat durable-custody verification.

[Defeat: buyEntries] 1) Alice submits zero entries and is rejected. 2) At `totalEntries = 2^128-1`, Alice submits one more and is rejected before payment. 3) A ticket receiver transfers the freshly minted ten-entry ticket during its callback; only claim ownership changes and the ten-USDC pot remains exact.

[Defeat: _update] 1) Sending ticket 1 to the current factory is rejected. 2) Sending it to a registered same-factory clone is rejected. 3) Sending it to a foreign-factory clone or a code-less future clone address is accepted, but every demonstrated loss requires the ticket owner to choose that sink.

[Defeat: requestDraw] 1) A caller supplies one wei less than the quote and is rejected. 2) A contract overpays by one wei and rejects its refund; the entire request reverts. 3) Forced ETH in the clone cannot subsidize a caller whose payment is below the actual fee because the post-request comparison reverts the whole transaction.

[Defeat: fulfillRandomWords] 1) The wrapper supplies request ID 8 when 7 is recorded. 2) It supplies two words instead of one. 3) It supplies the correct word exactly at the callback deadline. All three callbacks are ignored and refunds become available without corrupting the pot.

[Defeat: enableRefunds] 1) Mallory calls one second before the sold-raffle request deadline and is rejected. 2) Alice calls exactly at that deadline and migrates the full pot. 3) Bob calls exactly at a pending draw’s callback deadline and migrates the same full pot; no callback/refund overlap exists.

[Defeat: _settleWinningTicket] 1) Mallory supplies nonexistent ticket 0 and its zero range fails. 2) Mallory supplies the adjacent losing range and fails. 3) Mallory supplies the correct 100-entry range without owning it; settlement succeeds as intended but leaves redemption to the current owner.

[Defeat: redeemWinningTicket] 1) Alice sells the settled winning ticket to Bob, and only Bob can redeem. 2) An honest prize transfer reverts, rolling back the burn and all redemption flags. 3) An admin-seizable or lying prize makes delivery permanently unavailable even though sponsor proceeds can already leave; this defeats the external-asset guarantee.

[Defeat: refundTickets] 1) Alice supplies ticket 1 twice and the second ownership lookup reverts the whole batch. 2) Alice mixes Bob’s ticket into her batch and the entire batch reverts. 3) Alice submits the final one-entry ticket after every other refund; the remaining 1,000,000-unit liability pays in full.

[Defeat: _transferQuote] 1) Circle blacklists only a winning owner, who can transfer the still-live ticket to an unblocked address. 2) Circle blacklists the immutable sponsor beneficiary, permanently blocking that fixed claim absent unblacklisting. 3) Circle blacklists the raffle clone itself, blocking every winner, refund, sponsor, and treasury transfer. Moves 2 and 3 defeat payout liveness.

[Defeat: releaseSponsorPrize] 1) A caller tries during `NftWon` and is rejected. 2) A second release after successful delivery is rejected. 3) The prize administrator seizes or freezes the token after escrow; release reverts atomically, but no recovery branch restores durable custody.

[LastOut: Create / escrow] With an immutable honest ERC-721, the clone holds exactly one prize for one terminal recipient. With `AdminSeizablePrize721`, the last rightful claimant is short one NFT because the collection administrator can remove it after the point-in-time factory check.

[LastOut: Buy / transfer] After tickets of 40, 30, and 30 entries are sold, the raffle holds 100,000,000 raw USDC against exactly 100 entries. Transfers only move bearer ownership; there is no shortfall before the terminal branch.

[LastOut: Successful draw] Selecting one entry moves no USDC and creates no additional claim. The 100,000,000-unit pot remains intact for settlement, so last-out payment is deferred without drift.

[LastOut: Settle / redeem NFT] From 100,000,000 units, the sponsor can take 95,000,000 and the treasury 5,000,000 in either order; the last USDC claimant is paid in full. The NFT winner is nevertheless short one prize if the untrusted collection seized or disabled it.

[LastOut: Settle / redeem cash] From 100,000,000 units, the winner receives 80,000,000, the sponsor 15,000,000, and the treasury 5,000,000. In every withdrawal order, the last claimant receives its full amount and the balance reaches zero.

[LastOut: Timeout / refund] Refund 40-entry and 30-entry tickets first, leaving 30,000,000 units; the final 30-entry owner receives all 30,000,000. If Circle blacklists the clone, every attempted refund instead reverts and all 100,000,000 units remain unavailable despite remaining on balance.

[LastOut: Empty raffle] No USDC claim exists. With an honest collection the sponsor beneficiary receives the sole prize in full; with a collection-controlled seizure, it may already be absent.

[LastOut: Independent releases] Winner, sponsor, and treasury claims clear independently and sum exactly to the pot. Under transferable, fee-free USDC the last claim is fully paid; a sender blacklist turns this from a solvency invariant into an unreachable balance.

[LastOut: Native fee pass-through] If the wrapper price is 0.015 ETH and the requester supplies 0.020 ETH, 0.015 ETH reaches the wrapper and 0.005 ETH returns atomically. A failed refund reverts the request, leaving no retained requester liability.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: untrusted-prize-seizure | group_key: RaffleFactory | _validateCreateParams | untrusted-prize-seizure
root_cause: RaffleFactory.sol:172 substitutes a prize contract’s self-reported ERC-721 support for the missing restriction to collections with trusted, durable custody semantics; the point-in-time `ownerOf` check at line 129 cannot prevent a collection administrator from later seizing or disabling the escrowed prize.
internal_pre: None
external_pre: Third parties buy 100 entries in the attacker’s raffle and the normal VRF callback resolves before its deadline.
path:
  1. Mallory deploys `AdminSeizablePrize721`, mints token 7, and creates a raffle with reserve 100 and Mallory as sponsor beneficiary; the token genuinely transfers token 7 to the clone and reports the clone as owner.
  2. Alice and 99 other entrants each buy one entry, transferring 100,000,000 raw USDC into the raffle while token 7 is visibly escrowed.
  3. After sales close, Mallory invokes the token’s privileged seizure operation and moves token 7 out of the raffle.
  4. Chainlink resolves `NftWon`; Mallory supplies the correct ticket to settlement, allocating 95,000,000 units to Mallory and 5,000,000 units to the treasury without checking or delivering the prize.
  5. Mallory releases the 95,000,000-unit sponsor claim. When winning-ticket owner Alice calls `redeemWinningTicket`, the prize transfer reverts because the raffle no longer owns token 7.
impact: Mallory retains the purported prize and receives 95 USDC. Alice is left holding a winning ticket that cannot deliver its NFT, while the entrants collectively funded Mallory’s 95-USDC proceeds and the treasury’s 5-USDC fee.
mitigation: Restrict `prizeToken` to an immutable, vetted collection allowlist whose transfer, upgrade, pause, burn, and seizure controls satisfy the protocol’s custody requirements.

FINDING | contract: Raffle | function: _transferQuote | bug_class: freezable-usdc-payout-lock | group_key: Raffle | _transferQuote | freezable-usdc-payout-lock
root_cause: Raffle.sol:566 makes every quote claim collectible only through an outgoing transfer from the immutable raffle address and is missing any supported recovery mechanism for canonical USDC’s sender-blacklist behavior.
internal_pre: The raffle holds 100,000,000 raw USDC and has two live 50-entry refund tickets.
external_pre: Circle’s blacklister blacklists the raffle clone in Ethereum mainnet USDC at `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`.
path:
  1. Alice and Bob each buy 50 entries, putting 100 USDC into the clone.
  2. No draw is requested before the deadline, so Alice enables refunds and the 100-USDC pot becomes the refund liability.
  3. Circle blacklists the clone address, causing every USDC transfer whose sender is the clone to revert.
  4. Alice submits her 50-entry ticket for a 50-USDC refund; the final transfer reverts, rolling back the burn and liability debit.
  5. Bob’s refund and every cash-winner, sponsor, or treasury release fail identically until Circle removes the blacklist.
impact: Alice and Bob lose access to 50 USDC each, and the corresponding claimant cohort is left holding the liquidity loss while the entire backed balance remains frozen in the raffle.
mitigation: If unconditional onchain collectability is required, use a non-freezable quote asset; no raffle-side fallback can move USDC after Circle has blacklisted the sender.

COVERAGE | Raffle.sol: Checked every USDC, NFT, native-token, and ticket movement; every tracked-total write; all status transitions; callback authentication and deadlines; destination screening; settlement, redemption, refund, and release ordering.

COVERAGE | RaffleFactory.sol: Checked dependency construction, clone initialization, registry ordering, prize receiver authentication, ERC-165 validation, point-in-time custody verification, and external-call reentrancy.

COVERAGE | IRaffle.sol: Matched lifecycle, claim, event, error, getter, deadline, and bearer-ticket semantics against implementation behavior.

COVERAGE | IRaffleFactory.sol: Matched creation parameters, registry getters, immutable configuration, errors, and event promises against the factory.

COVERAGE | RaffleConstants.sol: Checked six-decimal units, entry price, 5%/80% splits, refund batch bound, sale and callback windows, gas limit, and confirmation count.

COVERAGE | DESIGN.md: Tested quote solvency, exact terminal allocation, durable prize custody, one-shot transitions, no cross-clone movement, permissionless progress, and last-user collectability.

COVERAGE | properties: Quote accounting remains exact under fee-free transferable USDC; ticket ranges are contiguous and exhaustive; deadline boundaries do not overlap; winner ownership follows the ticket; the two surviving failures are external-asset custody and freeze-dependent payout reachability.

COVERAGE | saturation: Mined the prize defect across interface admission, receiver activation, factory ownership verification, both NFT exits, and sponsor-release ordering; mined USDC freezing across purchases, refunds, cash redemption, sponsor proceeds, and protocol fees. Reachable Chainlink and OpenZeppelin inheritance semantics were confirmed; no tests, history, reports, scanner output, or peer conclusions were read.