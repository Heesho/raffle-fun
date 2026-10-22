[Model: gpt-daybreak-blue-latest] `RaffleFactory.constructor` / `Raffle.constructor` — The deployer supplies the payment-token, randomness-service, and treasury addresses and receives an ownerless factory plus a locked raffle template. No participant value enters; configuration becomes fixed and the template is unusable as a live raffle.

[Defeat: RaffleFactory.constructor] (1) A payment-token or wrapper address with no code is rejected. (2) A token reporting 18 decimals is rejected. (3) A treasury equal to the factory, payment token, wrapper, or deployed template is rejected.

[Model: gpt-daybreak-blue-latest] `Raffle.initialize` — The canonical factory supplies the sponsor, recipients, prize identity, reserve, identifier, and deadline. No asset moves; the new raffle becomes configured and waits for its prize.

[Defeat: initialize] (1) Alice calling directly is rejected because she is not the factory. (2) The factory calling a second time is rejected because initialization is one-shot. (3) Supplying the payment token, prize contract, or a registered raffle as a recipient is rejected.

[Model: gpt-daybreak-blue-latest] `RaffleFactory.createRaffle` — The sponsor gives one purported NFT and receives a registered, active raffle plus the future sponsor claim. The raffle count and all three registry directions advance once.

[Why: RaffleFactory.sol:123] Why is the raffle registered before its prize transfer finishes? Registration makes the new clone recognizable as a forbidden protocol destination during the untrusted prize call; a later failure rolls every registry write back atomically.

[Why: RaffleFactory.sol:129] Why does the sponsor-selected prize contract’s own ownership report prove escrow? It only does if that contract honestly implements ERC-721; the implicit belief conflicts with the stated boundary that prize contracts are untrusted.

[Defeat: createRaffle] (1) Prize address `0x1234` with no code is rejected. (2) A contract returning `false` for ERC-721 support is rejected. (3) A sponsor-controlled contract returning `true`, fabricating the receiver call, and reporting the clone as owner passes every check despite creating no enforceable NFT claim.

[Model: gpt-daybreak-blue-latest] `Raffle.onERC721Received` — The sponsor is meant to give the configured NFT through the factory; the raffle records that the prize arrived and opens ticket sales. Quote-token totals remain unchanged.

[Defeat: onERC721Received] (1) A call from a different token is rejected. (2) The configured token supplying token ID `8` instead of `7`, or the wrong sponsor, is rejected. (3) The configured malicious token can directly supply all expected fields without actually transferring an enforceable NFT, so the guard is defeated.

[LastOut: create / escrow] No quote claimant exists yet. With an honest ERC-721, the sole prize remains available for its eventual recipient; with the counterfeit contract above, the last prize claimant has no backed asset.

[Model: gpt-daybreak-blue-latest] `Raffle.buyEntries` — A buyer gives `entryCount × 1 USDC`; the chosen recipient gets one ticket covering that many entries. Sold entries, ticket count, the ticket’s range, and the unallocated pot increase together.

[Why: Raffle.sol:224] Why is payment collected before entry totals advance? The design relies on canonical fee-free USDC and transaction rollback, so a failed payment or failed ticket receipt restores both asset and accounting state.

[Model: gpt-daybreak-blue-latest] `Raffle._update` — A ticket owner gives the bearer claim to another address, or the raffle destroys it during payout. Lifetime entry and ticket totals intentionally do not decrease.

[Defeat: buyEntries] (1) Buying zero entries is rejected. (2) Buying past the largest representable cumulative entry is rejected. (3) A recipient reverting during ticket acceptance reverts the payment and every total update.

[Defeat: _update] (1) Sending a ticket to its own raffle is rejected. (2) Sending it to the payment token, prize contract, wrapper, factory, or template is rejected. (3) Sending it to any already-registered sibling raffle is rejected.

[LastOut: buy / transfer] This is not terminal: no ticket holder can withdraw while sales remain active. Every live ticket remains backed by exactly its range length multiplied by 1 USDC, and transfers neither create nor destroy backing.

[Model: gpt-daybreak-blue-latest] `Raffle.requestDraw` — A permissionless caller gives the randomness-service fee, receives any excess native currency back, and advances the raffle from sales to drawing. The request time and identifier are recorded; USDC claims do not change.

[Why: Raffle.sol:254] Why ignore a response while the request call is still executing? The request identifier cannot be recorded until that call returns, so the code assumes the trusted service fulfills asynchronously and prevents an early response from resolving against identifier zero.

[Why: Raffle.sol:267] Why return excess with an unrestricted native-currency call? The caller funded that exact excess; the raffle’s entry lock prevents nested economic actions, and a failed return reverts the request and wrapper payment atomically.

[Defeat: requestDraw] (1) A request one second before sale end is rejected. (2) A request exactly at `endTime + 2 days` is rejected while refunds become available. (3) A synchronous service response is ignored while the request is in flight; under the trusted service’s asynchronous semantics, the later authenticated response remains available.

[Model: gpt-daybreak-blue-latest] `Raffle.fulfillRandomWords` — The trusted randomness service supplies one word. No asset moves; one entry is selected and the final NFT-or-cash outcome is fixed.

[Defeat: fulfillRandomWords] (1) Request ID `12` when `13` is recorded is ignored. (2) Two random words instead of one are ignored. (3) A response exactly at the callback deadline is ignored, after which full refunds are available.

[LastOut: successful draw] No claimant exits during resolution. For a 100 USDC pot, all 100 USDC remains recorded as unallocated until settlement; the selected entry is covered by exactly one existing ticket range.

[Model: gpt-daybreak-blue-latest] `settleWinningTicket` / `_settleWinningTicket` — A caller gives no asset and receives no protocol value. The 100 USDC example moves from one unallocated pot into either `95 sponsor + 5 treasury`, or `80 winner + 15 sponsor + 5 treasury`.

[Why: Raffle.sol:538] Why prove only the winning range and not ownership during settlement? Settlement allocates fixed liabilities without consuming the bearer claim; the current owner is checked later when that ticket is destroyed for payout.

[Why: Raffle.sol:539] Why allocate from the recorded pot instead of the live token balance? This excludes donations and preserves exact correspondence between sold entries and participant liabilities.

[Defeat: settleWinningTicket] (1) Unminted ticket `0` has range `[0,0]` and cannot contain a positive winning entry. (2) A real losing ticket is rejected. (3) Mallory may settle Alice’s correct winning ticket, but receives nothing and cannot redeem it.

[Model: gpt-daybreak-blue-latest] `Raffle.redeemWinningTicket` — The current winner gives up and destroys the winning ticket. They receive either the prize NFT or the entire recorded 80% cash claim; the winner and prize completion flags advance once.

[Why: Raffle.sol:315] Why may settlement occur before checking the caller owns the ticket? This permits settlement and redemption in one action; if ownership later fails, the entire action, including settlement, is rolled back.

[Why: Raffle.sol:334] Why is receiver acknowledgement omitted for an NFT sent to a contract winner? The code equates a reported ownership change with usable delivery, implicitly assuming every contract ticket owner can manage an NFT received without its receiver hook.

[Why: Raffle.sol:335] Why does the same untrusted prize contract’s post-transfer ownership report verify delivery? It is sound only for an honest ERC-721 and is defeated by the same self-attesting contract accepted during creation.

[Defeat: redeemWinningTicket] (1) Bob calling with Alice’s winning ticket is rejected. (2) Alice supplying a different ticket after settlement is rejected. (3) A malicious prize contract can make `transferFrom` a no-op, report Alice as owner, and cause the ticket to burn and all completion flags to finalize without a usable prize.

[LastOut: NFT settlement / redemption] With 100 USDC and an honest prize, sponsor-first then treasury-last pays exactly 95 and 5 USDC, leaving zero quote liability, while the winner receives the escrowed NFT. Against the accepted counterfeit prize, the quote claimants are paid but the final winner receives no enforceable NFT.

[LastOut: cash settlement / redemption] For 100 entries, pay sponsor 15 USDC and treasury 5 USDC first; the last winner still receives the full 80 USDC and the balance reaches zero. Reversing the order produces the same result.

[Model: gpt-daybreak-blue-latest] `Raffle.enableRefunds` — No caller contributes value. The complete unallocated pot becomes the refund balance owed to all still-live tickets, and the raffle enters its refund outcome.

[Defeat: enableRefunds] (1) A sold active raffle cannot enter refunds before `endTime + 2 days`. (2) A drawing raffle cannot enter refunds before its callback deadline. (3) At the exact applicable deadline, refunds open while draw initiation or fulfillment is no longer accepted, leaving no time gap.

[Model: gpt-daybreak-blue-latest] `Raffle.refundTickets` — An owner gives up and destroys one to 100 tickets and receives 1 USDC per represented entry. The refund balance falls by exactly the paid amount.

[Defeat: refundTickets] (1) `[ticket 1, ticket 1]` fails on the second ownership lookup and rolls the whole batch back. (2) Including Bob’s ticket in Alice’s batch rolls every burn back. (3) A 101-ticket batch is rejected before any ticket changes.

[LastOut: timeout / refund] With tickets covering 40, 35, and 25 entries and a 100 USDC refund balance, refunding 40 then 35 leaves 25; the last owner burns the final ticket, receives the full 25 USDC, and leaves zero liability and zero shortfall.

[Model: gpt-daybreak-blue-latest] `Raffle.releaseSponsorPrize` — A permissionless caller contributes nothing; after a cash or refund result, the configured prize is sent to the fixed sponsor recipient and marked released once.

[Why: Raffle.sol:404] Why is the prize recipient not asked to acknowledge receipt? The code assumes reported ownership is sufficient even when the fixed recipient is a contract.

[Defeat: releaseSponsorPrize] (1) Release while sales are active is rejected. (2) A second release is rejected. (3) A malicious prize contract can no-op the transfer and return the expected recipient from `ownerOf`, falsely finalizing release.

[LastOut: empty raffle] There is no quote claimant and therefore no quote shortfall. With an honest prize, the sponsor recipient receives the sole NFT; the same counterfeit-prize defect can falsely mark that return complete.

[Model: gpt-daybreak-blue-latest] `releaseSponsorProceeds`, `releaseProtocolFees`, and `_transferQuote` — A permissionless caller contributes nothing. Each fixed beneficiary receives its complete recorded USDC claim, and that one claim falls to zero; a failed payment restores it.

[Defeat: independent releases] (1) Releasing the sponsor claim twice fails on the second zero balance. (2) Releasing treasury before sponsor changes neither amount. (3) A failed token payment rolls the cleared claim back, so it cannot disappear without payment.

[LastOut: independent releases] In the NFT result, either `95 then 5` or `5 then 95` pays the last quote claimant in full. In the cash result, every ordering of `80`, `15`, and `5` totals exactly 100 USDC; no rounding dust or order-dependent shortfall remains.

[Saturation: counterfeit-prize-self-attestation] The full bundled source was mined for `supportsInterface`, prize receiver calls, `safeTransferFrom`, `transferFrom`, `ownerOf`, and `prizeClaimed`. The same trust defect appears at initial escrow (`RaffleFactory.sol:128-132`), winner delivery (`Raffle.sol:334-335`), and sponsor return (`Raffle.sol:404-405`); these are one root cause because one trusted-prize restriction removes every instance.

[Saturation: flow-completeness] Every write to sold entries, ticket count, unallocated pot, refund balance, winner proceeds, sponsor proceeds, protocol fees, prize completion, settlement completion, winner completion, status, and the three factory registries was matched against all inverse and sibling paths. No unmatched USDC increment, decrement, branch allocation, or terminal release survived the sweep.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: counterfeit-prize-escrow | group_key: RaffleFactory | createRaffle | counterfeit-prize-escrow
root_cause: RaffleFactory.sol:129 wrongly treats `prize.ownerOf(prizeTokenId)`—a return value supplied by the sponsor-selected prize contract—as independent escrow proof; the missing operation is restricting `params.prizeToken` to trusted prize code before accepting its receiver call and self-reported ownership
internal_pre: None
external_pre: None
path:
  1. Mallory deploys `Counterfeit721` for token ID 7; it reports ERC-721 support, makes `safeTransferFrom` call the raffle receiver with the expected factory, sponsor, and ID without creating an enforceable token, and reports whichever destination the protocol expects from `ownerOf`.
  2. Mallory creates a raffle with reserve 1 and herself as sponsor recipient. The clone becomes `Active` because the counterfeit contract fabricates the receiver call and reports the clone as owner.
  3. Alice buys 60 entries for 60,000,000 raw USDC and Bob buys 40 for 40,000,000 raw USDC. The authenticated draw selects entry 10 on Alice’s ticket and resolves `NftWon`.
  4. A keeper settles Alice’s ticket, allocating 95,000,000 raw USDC to Mallory and 5,000,000 to the treasury; Mallory releases her 95 USDC.
  5. Alice redeems. `Counterfeit721.transferFrom` does not give her transferable control but reports Alice from `ownerOf`, so the raffle burns her ticket and permanently records the prize as delivered.
impact: Alice and Bob fund a 100 USDC raffle with no enforceable prize; Mallory extracts 95 USDC while retaining control of the purported NFT, and the selected winner is left holding the entire missing-prize loss after her ticket is burned
mitigation: Restrict `params.prizeToken` during creation to an immutable allowlist or trusted registry of reviewed, non-upgradeable ERC-721 implementations; ERC-165, receiver callbacks, and `ownerOf` reported by arbitrary prize code cannot authenticate that code

LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: unsafe-contract-nft-delivery | group_key: Raffle | redeemWinningTicket | unsafe-contract-nft-delivery
smell: Raffle.sol:334 and sibling Raffle.sol:404 use `transferFrom` rather than `safeTransferFrom`, so a contract winner or sponsor recipient never acknowledges or accounts for the incoming prize before the raffle finalizes delivery
unverified: No in-scope recipient implementation establishes that such a recipient cannot recover an unsafely received NFT; without that external behavior, the path may reduce to recipient-specific misconfiguration or self-harm
description: A contract that accepts raffle tickets but relies on its ERC-721 receiver hook to record the eventual prize can become the reported NFT owner without recording or exposing that NFT to its beneficiary.

[Coverage: files] `Raffle.sol` — all value entries/exits, tracked writes, status branches, ticket movement, deadlines, callbacks, settlement, redemption, refunds, releases, and destination checks; `RaffleFactory.sol` — deployment validation, clone creation, registry atomicity, escrow, and untrusted-token calls; `IRaffle.sol` and `IRaffleFactory.sol` — signatures, lifecycle promises, events, errors, getters, and documented trust assumptions; `RaffleConstants.sol` — price, percentages, bounds, timing, gas, and confirmations; `DESIGN.md` — every economic split, deadline, one-shot promise, custody promise, and trust boundary.

[Coverage: properties] Quote solvency and exact allocation; contiguous entry coverage; mint/burn and forward/inverse symmetry; last-ticket and last-liability payout; prize custody and both prize exits; one-shot initialization/request/resolution/settlement/redemption; factory registry consistency; deadline boundary equality; reentrancy and external-call rollback; interface/implementation agreement; complete sibling-site saturation.