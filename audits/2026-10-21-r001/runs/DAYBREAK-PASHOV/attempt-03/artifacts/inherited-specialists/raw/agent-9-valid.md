FINDING | contract: RaffleFactory | function: createRaffle | bug_class: fake-erc721-escrow | group_key: RaffleFactory | createRaffle | fake-erc721-escrow
file: target/packages/contracts/src/RaffleFactory.sol:97
boundary: Caller-selected `supportsInterface`, `safeTransferFrom`, `onERC721Received`, and `ownerOf` calls
assumption: The factory assumes that the prize contract provides independent proof of a transferable NFT.
actual: The prize contract can fabricate the callback and ownership result, then reject every delivery attempt.
root_cause: `createRaffle` treats statements from one caller-selected contract as proof that the raffle owns a transferable NFT.
path: sponsor → fake prize callback and ownership response → `Active` raffle → buyer payment → `NftWon` → failed redemption
proof: A token returns true for ERC-721 support, calls `onERC721Received(factory,sponsor,tokenId,"")`, reports the clone from `ownerOf`, and makes `transferFrom` revert. With one entry and `reserveEntries=1`, the sponsor receives 950,000 of 1,000,000 USDC units while redemption always reverts.
description: A sponsor can fake prize escrow and get an active raffle whose winner cannot receive the advertised NFT.
fix: The factory must restrict prizes to an immutable allowlist of ERC-721 contracts with trusted ownership and transfer behavior.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:375
boundary: `releaseSponsorProceeds` pays before the later `prizeToken.transferFrom` call succeeds.
assumption: The raffle assumes that a prize which entered escrow remains transferable when the winner redeems it.
actual: A sponsor-controlled pausable or upgradeable ERC-721 can reject delivery after the sponsor receives the sale proceeds.
root_cause: `_settleWinningTicket` exposes payout claims before `redeemWinningTicket` proves delivery, while `enableRefunds` rejects the resulting `NftWon` state.
path: genuine escrow → buyer payments → token pause → `NftWon` settlement → sponsor payout → permanent redemption failure
proof: With 100 entries and `reserveEntries=1`, settlement allocates 95,000,000 units to the sponsor and 5,000,000 units to fees. After payout, a paused prize makes every redemption revert at `transferFrom`; `enableRefunds` then reverts because the status is `NftWon`.
description: A sponsor can pause an escrowed ERC-721, take 95% of sales, and block the winner from both the prize and a refund.
fix: `Raffle` must keep sponsor and protocol proceeds escrowed until NFT delivery succeeds, then open full refunds if delivery misses a fixed deadline.