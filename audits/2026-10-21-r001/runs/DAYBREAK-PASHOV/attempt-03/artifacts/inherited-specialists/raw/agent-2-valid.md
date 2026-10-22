FINDING | contract: RaffleFactory | function: createRaffle | bug_class: forged-prize-escrow | group_key: RaffleFactory | createRaffle | forged-prize-escrow
file: target/packages/contracts/src/RaffleFactory.sol
related: target/packages/contracts/src/Raffle.sol:onERC721Received
root_cause: `createRaffle` treats token-controlled ERC-165, callback, and `ownerOf` outputs as proof that the raffle holds a transferable prize.
guard_gap: The constructor pins the trusted quote token and wrapper, but `_validateCreateParams` accepts any sponsor-selected `prizeToken` that returns true.
path: sponsor → `createRaffle` → false `safeTransferFrom` → spoofed `onERC721Received` → false `ownerOf` → ticket sales → `NftWon` → sponsor withdrawal
proof: The sponsor sets `reserveEntries = 1` and supplies a false ERC-721. Its `safeTransferFrom` moves nothing, calls `onERC721Received(factory, sponsor, id, "")`, and makes `ownerOf(id)` return the clone. A victim buys ten entries, so `unsettledPot = 10_000_000`. The sponsor requests the draw, settles ticket 1, and receives `sponsorProceeds = 9_500_000`. The token then reverts every redemption transfer, and `NftWon` provides no refund path.
description: A sponsor can report a prize deposit without a transfer, take 95% of sales, and leave the winner unable to redeem the prize.
fix: The factory must accept only immutable, reviewed ERC-721 contracts from a deployment-time allowlist.