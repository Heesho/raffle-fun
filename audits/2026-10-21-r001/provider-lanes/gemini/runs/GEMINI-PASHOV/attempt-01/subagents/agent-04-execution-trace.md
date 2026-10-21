FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: uncreated-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | uncreated-clone-destination-bypass
file: packages/contracts/src/Raffle.sol
input: `params.sponsorRecipient` in `RaffleFactory.createRaffle` or `recipient` in `Raffle.buyEntries` / `ERC721.transferFrom` set to the deterministic `CREATE` address of a future `Raffle` clone (`address(uint160(uint256(keccak256(rlp.encode(address(factory), factoryNonce)))))`).
assumption: `_isProtocolDestination` and `_validateCreateParams` assume every same-factory `Raffle` clone already has deployed code (`destination.code.length != 0`) and `isRaffle[destination] == true` when an address is validated, and `releaseSponsorPrize` assumes `sponsorRecipient` cannot become a `Raffle` clone after initialization.
root_cause: `_isProtocolDestination` only queries `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0` and `RaffleFactory.createRaffle` deploys clones at predictable `CREATE` addresses without checking `releaseSponsorPrize` against `_isProtocolDestination`.
path: caller -> RaffleFactory.createRaffle(sponsorRecipient = nextClone) or Raffle.buyEntries(nextClone, 1) -> RaffleFactory.createRaffle() deploys Raffle #2 at nextClone -> Raffle #1.releaseSponsorProceeds() reverts with InvalidQuoteDestination(nextClone) while Raffle #1.releaseSponsorPrize() transfers prizeToken into Raffle #2, and tickets owned by Raffle #2 in Raffle #1 cannot be redeemed or refunded.
proof:
1. `RaffleFactory` deploys its implementation at `nonce = 1`. When `raffleCount == 0`, the first clone `raffle1` is deployed at `nonce = 2` and the second clone `raffle2` will be deployed at `nextClone = computeCreateAddress(address(factory), 3)`.
2. Before `raffle2` is created, `nextClone.code.length == 0` and `factory.isRaffle(nextClone) == false`.
3. Path A (Sponsor recipient bypass and cross-clone asset transfer):
   - Sponsor creates `raffle1` with `params.sponsorRecipient = nextClone`. `RaffleFactory._validateCreateParams` (line 799: `isRaffle[params.sponsorRecipient]`) and `Raffle.initialize` (lines 206, 615: `destination.code.length != 0`) both evaluate to `false` and succeed.
   - Any sponsor calls `factory.createRaffle(...)`, deploying `raffle2` at `nextClone` (`nextClone.code.length == 45`, `factory.isRaffle(nextClone) == true`).
   - If `raffle1` settles in `Status.NftWon` or `Status.CashWon` (e.g., `totalEntries = 10`, `grossPot = 10,000,000`), calling `raffle1.releaseSponsorProceeds()` calls `_transferQuote(nextClone, sponsorAmount)`, which checks `_isProtocolDestination(nextClone, address(prizeToken))` (line 578) and reverts with `InvalidQuoteDestination(nextClone)`, permanently locking `sponsorProceeds` (`9,500,000` or `1,500,000` USDC units) in `raffle1`.
   - If `raffle1` enters `Status.CashWon` or `Status.Refunding`, calling `raffle1.releaseSponsorPrize()` (lines 408-420) skips `_isProtocolDestination` and calls `prizeToken.transferFrom(raffle1, nextClone, prizeTokenId)`, moving `raffle1`'s prize NFT directly into `raffle2` (violating the `DESIGN.md` rule "Never move assets between raffle clones") where `raffle2` cannot release it.
4. Path B (Ticket ownership by a clone and permanent prize/pot lock):
   - Before `raffle2` is created, a caller invokes `raffle1.buyEntries(nextClone, 10)` (or `raffle1.transferFrom(caller, nextClone, ticketId)`). `_update` (line 511) and `ERC721Utils.checkOnERC721Received` both see `nextClone.code.length == 0` and succeed.
   - `factory.createRaffle(...)` deploys `raffle2` at `nextClone`. Now `raffle1.ownerOf(ticketId) == raffle2`.
   - `raffle2` has no function to call `redeemWinningTicket` or `refundTickets`. If `ticketId` wins in `Status.NftWon`, `raffle1`'s prize NFT is permanently locked in `raffle1`; if `Status.CashWon`, `winnerProceeds` (`80%` of pot) is permanently locked; if `Status.Refunding`, `remainingRefundLiability` for `ticketId` is permanently locked.
description: A caller can pass a future clone address to initialize or buyEntries, which locks the claim or sends the prize to the second clone.
fix: The factory must deploy each clone with Clones.cloneDeterministic and a salt derived from msg.sender, and releaseSponsorPrize must check _isProtocolDestination.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-sponsor-payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | premature-sponsor-payout-before-prize-delivery
file: packages/contracts/src/Raffle.sol
input: `params.prizeToken` set to an untrusted or transfer-restricted ERC-721 contract and `params.reserveEntries = 1` in `createRaffle`.
assumption: `settleWinningTicket` and `releaseSponsorProceeds` assume that in `Status.NftWon` the escrowed `prizeToken` will always succeed when `redeemWinningTicket` later calls `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`.
root_cause: `releaseSponsorProceeds` transfers `sponsorProceeds` (95% of `unsettledPot`) in `Status.NftWon` without requiring `prizeClaimed == true`, even though `DESIGN.md` specifies that arbitrary prize contracts are untrusted.
path: sponsor -> RaffleFactory.createRaffle(prizeToken, reserveEntries = 1) -> buyers call Raffle.buyEntries -> Raffle.requestDraw & fulfillRandomWords -> Status.NftWon -> Raffle.settleWinningTicket -> Raffle.releaseSponsorProceeds pays 95% USDC to sponsorRecipient -> winner calls Raffle.redeemWinningTicket -> prizeToken.transferFrom reverts -> winner loses USDC and never receives the NFT.
proof:
1. Sponsor deploys or uses an untrusted `prizeToken` contract (which returns `true` for `supportsInterface(0x80ac58cd)` and allows `safeTransferFrom(sponsor, raffle, tokenId)` during `createRaffle`, but reverts on `transferFrom` when `from == raffle`) and creates a raffle with `reserveEntries = 1`.
2. Buyers purchase `100` entries for `100,000,000` raw USDC units (`100 USDC`).
3. After `endTime`, `requestDraw()` and `fulfillRandomWords()` resolve the raffle to `Status.NftWon` because `totalEntries (100) >= reserveEntries (1)` (line 534).
4. Sponsor calls `settleWinningTicket(winningTicketId)` (lines 546-571), which sets `protocolFees = 5,000,000` and `sponsorProceeds = 95,000,000`.
5. Sponsor calls `releaseSponsorProceeds()` (lines 388-395), which checks only `if (amount == 0) revert NoSponsorProceeds();` and transfers `95,000,000` USDC units (`95 USDC`) to `sponsorRecipient`.
6. Winner calls `redeemWinningTicket(winningTicketId)` (lines 322-359), which calls `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` (line 347) and reverts. Because `Status.NftWon` cannot transition to `Status.Refunding` in `enableRefunds()` (line 306), the winner never receives the NFT and buyers cannot recover their USDC, while the sponsor keeps `95 USDC`.
description: A sponsor with a custom prizeToken can take the sponsorProceeds in releaseSponsorProceeds and make redeemWinningTicket revert for the winner.
fix: The releaseSponsorProceeds function must require that prizeClaimed is true when status equals Status.NftWon.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: pre-creation-active-raffle-reentrancy | group_key: RaffleFactory | createRaffle | pre-creation-active-raffle-reentrancy
file: packages/contracts/src/RaffleFactory.sol
input: `params.prizeToken` in `RaffleFactory.createRaffle` set to an ERC-721 contract that calls `IRaffle(raffle).buyEntries(recipient, entryCount)` inside `safeTransferFrom` after invoking `IERC721Receiver(raffle).onERC721Received`.
assumption: `RaffleFactory.createRaffle` assumes the clone cannot accept entry purchases or emit ticket lifecycle events until after `createRaffle` verifies `prize.ownerOf(params.prizeTokenId) == raffle` and emits `RaffleCreated`.
root_cause: `Raffle.onERC721Received` sets `status = Status.Active` inside `prize.safeTransferFrom` while `Raffle`'s reentrancy guard is unentered and before `RaffleFactory.createRaffle` verifies prize ownership or emits `RaffleCreated`.
path: caller -> RaffleFactory.createRaffle -> prize.safeTransferFrom -> Raffle.onERC721Received sets status = Status.Active -> prizeToken calls Raffle.buyEntries -> TicketPurchased and Transfer emitted before RaffleCreated and before prize.ownerOf check.
proof:
1. In `RaffleFactory.createRaffle` (lines 756-761), `isRaffle[raffle] = true` is set and `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` is called before `RaffleCreated` is emitted (line 769).
2. Inside `safeTransferFrom`, `prize` calls `raffle.onERC721Received(address(factory), msg.sender, params.prizeTokenId, "")` (lines 429-444 of `Raffle.sol`), which sets `status = Status.Active` and emits `PrizeDeposited`.
3. Control returns to `prize.safeTransferFrom`. At this point `raffle.status()` is `Status.Active`, `block.timestamp < endTime` (enforced at line 733), and `raffle`'s `ReentrancyGuard` is `NOT_ENTERED` (only `RaffleFactory` has `ENTERED` its own guard).
4. `prize` (or a sender hook invoked by `prize`) calls `raffle.buyEntries(recipient, 1)` (lines 222-250 of `Raffle.sol`), which succeeds and emits `Transfer(address(0), recipient, 1)` and `TicketPurchased(...)` before `RaffleFactory.createRaffle` executes `if (prize.ownerOf(params.prizeTokenId) != raffle)` (line 762) and before `emit RaffleCreated(...)` (line 769).
description: A prizeToken contract can call buyEntries on the clone inside safeTransferFrom in createRaffle, so the clone emits TicketPurchased before RaffleCreated.
fix: The Raffle contract must activate the clone in a separate factory call after createRaffle verifies prize ownership and emits RaffleCreated.

LEAD | contract: Raffle | function: requestDraw | bug_class: early-inflight-flag-reset-before-refund | group_key: Raffle | requestDraw | early-inflight-flag-reset-before-refund
code_smells: The requestDraw function sets _requestInFlight to false before the native refund call to msg.sender, and rawFulfillRandomWords has no nonReentrant modifier.
description: A contract caller in requestDraw can receive the native refund while _requestInFlight is false and revert if the draw result is bad. We did not verify a wrapper that fulfills in the same transaction.

LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: unsafe-erc721-transfer-to-contract-recipient | group_key: Raffle | releaseSponsorPrize | unsafe-erc721-transfer-to-contract-recipient
code_smells: The releaseSponsorPrize and redeemWinningTicket functions call prizeToken.transferFrom instead of safeTransferFrom, so contract recipients do not receive an onERC721Received call.
description: Any caller can trigger releaseSponsorPrize to send the prize to a sponsorRecipient contract that requires onERC721Received to track deposits. We did not verify whether sponsorRecipient contracts in scope rely on that callback.
