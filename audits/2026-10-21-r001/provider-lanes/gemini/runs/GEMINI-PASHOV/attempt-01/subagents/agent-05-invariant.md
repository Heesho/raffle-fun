FINDING | contract: Raffle | function: _isProtocolDestination | bug_class: unregistered-future-clone-sink | group_key: Raffle | _isProtocolDestination | unregistered-future-clone-sink
invariant: A Raffle clone must never own a ticket or be configured as sponsorRecipient, and accountedQuoteBalance() must remain claimable down to 0 in all terminal states
violation_path: compute next CREATE clone address of RaffleFactory → RaffleFactory.createRaffle(sponsorRecipient = nextClone) or Raffle.buyEntries(nextClone, entryCount) → RaffleFactory.createRaffle(...) deploys nextClone → Raffle.releaseSponsorProceeds() / Raffle.redeemWinningTicket() / Raffle.refundTickets()
path: caller → Raffle.buyEntries(nextClone, entryCount) or RaffleFactory.createRaffle(sponsorRecipient = nextClone) → RaffleFactory.createRaffle() registers isRaffle[nextClone] = true → Raffle._transferQuote(nextClone, amount) reverts with InvalidQuoteDestination(nextClone) and nextClone cannot call redeemWinningTicket or refundTickets → funds and NFT prize are permanently locked in Raffle
proof:
1. `RaffleFactory.createRaffle` (RaffleFactory.sol:739) deploys clones with `Clones.clone(raffleImplementation)`, which uses the `CREATE` opcode (`create(value, 0x09, 0x37)`). The address of clone `N` (`raffleId = N`) is deterministically `addressFrom(address(factory), nonce = N + 1)`.
2. Suppose `raffleCount == 1` (`raffle_1` is deployed at nonce 2). The next clone `raffle_2` will be deployed at `predictedRaffle2 = computeCreateAddress(address(factory), 3)`. Before `raffle_2` is created, `predictedRaffle2.code.length == 0` and `factory.isRaffle(predictedRaffle2) == false`.
3. Path A (Ticket ownership): A caller calls `raffle_1.buyEntries(predictedRaffle2, 10)` (paying `10_000_000` USDC, minting `ticketId = 1` with range `[1, 10]`). Inside `Raffle._update` (Raffle.sol:511), `_isProtocolDestination(predictedRaffle2, address(prizeToken))` returns `false` because `predictedRaffle2.code.length == 0` and `isRaffle(predictedRaffle2) == false`. Inside `_safeMint`, `ERC721Utils.checkOnERC721Received` is a no-op because `predictedRaffle2.code.length == 0`.
4. Path B (Sponsor recipient): A sponsor calls `factory.createRaffle` for `raffle_1` with `params.sponsorRecipient = predictedRaffle2`. Both `RaffleFactory._validateCreateParams` (RaffleFactory.sol:799) and `Raffle.initialize` (Raffle.sol:206) pass because `isRaffle[predictedRaffle2] == false`.
5. Next, anyone calls `factory.createRaffle(...)` to create `raffle_2` at `predictedRaffle2`. Now `predictedRaffle2.code.length == 45` and `factory.isRaffle(predictedRaffle2) == true`.
6. In `raffle_1`:
   - Under Path A, `ownerOf(1) == raffle_2`. `raffle_2` has no function to transfer, redeem, or refund `ticketId = 1`. When `raffle_1` resolves (`NftWon` or `CashWon`) or enters `Refunding`, `redeemWinningTicket(1)` and `refundTickets([1])` require `msg.sender == raffle_2` and `_transferQuote(raffle_2, amount)` reverts with `InvalidQuoteDestination(raffle_2)`. The `prizeTokenId` NFT (`NftWon`), `8_000_000` USDC `winnerProceeds` (`CashWon`), or `10_000_000` USDC `remainingRefundLiability` (`Refunding`) is permanently locked in `raffle_1`.
   - Under Path B, when `raffle_1` settles (`sponsorProceeds = 9_500_000` or `1_500_000`), calling `raffle_1.releaseSponsorProceeds()` calls `_transferQuote(predictedRaffle2, amount)` (Raffle.sol:578), where `_isProtocolDestination(predictedRaffle2, address(prizeToken))` now returns `true` and reverts with `InvalidQuoteDestination(predictedRaffle2)`, permanently locking `sponsorProceeds` in `raffle_1`.
description: A caller can use the address of a future clone before deployment, so the contract locks the payout after the factory deploys that clone.
fix: The factory should deploy each clone with Clones.cloneDeterministic and a salt that includes blockhash(block.number - 1) so callers cannot precompute future clone addresses.

FINDING | contract: Raffle | function: releaseSponsorPrize | bug_class: missing-protocol-destination-check | group_key: Raffle | releaseSponsorPrize | missing-protocol-destination-check
invariant: Assets must never move between raffle clones (DESIGN.md: "Never move assets between raffle clones")
violation_path: RaffleFactory.createRaffle(sponsorRecipient = predictedRaffle2) creates raffle_1 → RaffleFactory.createRaffle(...) deploys raffle_2 at predictedRaffle2 → raffle_1.enableRefunds() → raffle_1.releaseSponsorPrize()
path: caller → Raffle.releaseSponsorPrize() → prizeToken.transferFrom(address(raffle_1), address(raffle_2), prizeTokenId) → prize NFT is transferred into raffle_2 and permanently locked
proof:
1. Sponsor creates `raffle_1` (`raffleId = 1`, `totalEntries = 0`) with `params.sponsorRecipient = predictedRaffle2` (where `predictedRaffle2 = computeCreateAddress(address(factory), 3)`). At creation time, `factory.isRaffle(predictedRaffle2) == false`, so `RaffleFactory._validateCreateParams` and `Raffle.initialize` succeed.
2. A second raffle `raffle_2` (`raffleId = 2`) is created via `factory.createRaffle(...)`, deploying the clone at `predictedRaffle2` and setting `factory.isRaffle(predictedRaffle2) = true`.
3. In `raffle_1`, the sponsor calls `raffle_1.enableRefunds()` (Raffle.sol:289), setting `status = Status.Refunding`.
4. Any caller invokes `raffle_1.releaseSponsorPrize()` (Raffle.sol:408-420):
   ```solidity
   address recipient = sponsorRecipient;
   prizeClaimed = true;
   prizeToken.transferFrom(address(this), recipient, prizeTokenId);
   if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
   ```
5. Unlike `_transferQuote` (Raffle.sol:578), `releaseSponsorPrize` does not check `_isProtocolDestination(recipient, address(prizeToken))` and calls `prizeToken.transferFrom` instead of `safeTransferFrom` (bypassing `raffle_2.onERC721Received`). The call transfers `prizeTokenId` from `raffle_1` directly into `raffle_2`, violating the cross-clone asset isolation invariant and permanently stranding the NFT inside `raffle_2`.
description: Any caller can invoke releaseSponsorPrize when sponsorRecipient is a second clone deployed later, so the contract sends the prize NFT into that clone.
fix: Add a call to _isProtocolDestination(recipient, address(prizeToken)) in releaseSponsorPrize and revert with UnsafeProtocolDestination(recipient) before prizeToken.transferFrom executes.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: reentrant-activation-during-escrow | group_key: RaffleFactory | createRaffle | reentrant-activation-during-escrow
code_smells: Raffle.onERC721Received sets status to Status.Active before prize.safeTransferFrom returns to RaffleFactory.createRaffle, so the prize contract can call Raffle.buyEntries before RaffleFactory verifies ownership or emits RaffleCreated.
description: The prize contract can call buyEntries on the new clone before createRaffle verifies prize ownership. We did not find a way to extract user tokens.
