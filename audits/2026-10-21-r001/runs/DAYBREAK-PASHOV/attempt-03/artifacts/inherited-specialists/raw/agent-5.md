FINDING | contract: RaffleFactory | function: createRaffle | bug_class: fake-prize-escrow | group_key: RaffleFactory | createRaffle | fake-prize-escrow
location: target/packages/contracts/src/RaffleFactory.sol:128-134; target/packages/contracts/src/Raffle.sol:334-337,416-429
root_cause: `createRaffle` treats the prize contract’s callback and `ownerOf` response as independent proof of custody.
path: sponsor → malicious ERC-721 → `createRaffle` → false callback and `ownerOf` response → buyer funds raffle → `NftWon` → false delivery → sponsor receives proceeds
invariant: Each active raffle must hold exactly one deliverable configured NFT.
violation_path: The token calls `onERC721Received` without a transfer, reports the clone to the factory, and reports the winner during delivery verification.
proof: With `reserveEntries = 1`, one buyer pays 1,000,000 units. A false token keeps `realOwner[7] = sponsor` but reports the clone at line 129. Settlement allocates 950,000 units to the sponsor and 50,000 units to the treasury. During redemption, the token ignores `transferFrom` and reports the winner, so the raffle burns the ticket and records delivery without transferring NFT rights.
description: A sponsor can make its prize contract report ERC-721 ownership without a transfer, then take 95% of buyer payments.
fix: The factory must enforce an immutable allowlist of vetted ERC-721 implementations that have no privileged or dishonest custody logic.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: proceeds-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | proceeds-before-prize-delivery
location: target/packages/contracts/src/Raffle.sol:334,375-382,533-555
root_cause: `_settleWinningTicket` makes sponsor proceeds payable before `redeemWinningTicket` proves that the prize contract transfers the NFT.
path: sponsor escrows pausable NFT → buyer purchases one entry → sponsor pauses NFT → `NftWon` → settlement → sponsor withdrawal → winner redemption reverts
invariant: An NFT result must not finalize sale proceeds unless the winner receives the NFT or buyers receive full refunds.
violation_path: `settleWinningTicket` allocates proceeds → `releaseSponsorProceeds` pays the sponsor → the paused NFT rejects `redeemWinningTicket` → `NftWon` prevents refunds
proof: One 1,000,000-unit entry produces 950,000 units of `sponsorProceeds` and 50,000 units of `protocolFees`. The sponsor withdraws 950,000 units before delivery. The paused NFT then makes every redemption revert, while `enableRefunds` rejects the terminal `NftWon` status.
description: A sponsor can pause its prize contract after escrow and take 95% of buyer payments while the winner gets no NFT or refund.
fix: The raffle must delay sponsor and protocol proceeds until NFT delivery and must enable full refunds if the NFT transfer fails.