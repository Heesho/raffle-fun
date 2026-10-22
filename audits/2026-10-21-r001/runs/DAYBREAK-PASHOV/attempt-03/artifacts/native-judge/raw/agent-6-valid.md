FINDING | contract: RaffleFactory | function: createRaffle | bug_class: spoofed-erc721-escrow | group_key: RaffleFactory | createRaffle | spoofed-erc721-escrow
file: target/packages/contracts/src/RaffleFactory.sol
root_cause: createRaffle accepts sponsor-controlled ERC-165, callback, and ownerOf results as proof that the clone holds a transferable prize.
path: sponsor-controlled prize → fake ERC-165 response → fake safeTransferFrom invokes onERC721Received without escrow → fake ownerOf reports the clone → victim buys entries → sponsor withdraws proceeds → prize transfer reverts
proof: A fake prize returns true for the IERC721 interface ID. Its safeTransferFrom(attacker, raffle, 1) calls raffle.onERC721Received(factory, attacker, 1, "") without transferring a token. ownerOf(1) then returns raffle, so every creation check passes. With reserveEntries=1, a victim buys ticket 1 for 1,000,000 units. After winningEntry=1 and NftWon, settleWinningTicket(1) assigns 950,000 units to sponsorProceeds and 50,000 units to protocolFees. releaseSponsorProceeds pays the attacker. The fake prize makes transferFrom revert, so redeemWinningTicket(1) always rolls back, while refunds remain unavailable in NftWon.
description: A sponsor can fake ERC-721 escrow, collect 95% of ticket sales, and block the winner from both the prize and a refund.
fix: The factory must use an immutable allowlist of vetted ERC-721 contracts because an untrusted contract can pass every escrow check without a transfer.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
root_cause: releaseSponsorProceeds and releaseProtocolFees pay NFT-result revenue before redeemWinningTicket proves that the prize transfer succeeds.
path: sponsor escrows an unpaused pausable ERC-721 → victim buys entries → NftWon settlement allocates the pot → sponsor pauses transfers → proceeds leave → redemption always reverts → refunds remain unavailable
proof: With reserveEntries=1 and totalEntries=100, settlement splits the 100,000,000-unit pot into 95,000,000 sponsorProceeds and 5,000,000 protocolFees. The sponsor pauses the validly escrowed prize and claims 95,000,000 units. releaseProtocolFees can transfer the remaining 5,000,000 units. The prize transfer then reverts on every redemption, while enableRefunds rejects Status.NftWon.
description: A sponsor can block the prize transfer after escrow and still collect the sale proceeds, so the winner receives no prize or refund.
fix: The contract must require successful prize delivery before payouts and must enable full refunds if delivery fails.