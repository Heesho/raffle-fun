FINDING | contract: RaffleFactory | function: createRaffle | bug_class: fake-prize-escrow | group_key: RaffleFactory | createRaffle | fake-prize-escrow
file: target/packages/contracts/src/RaffleFactory.sol:97; target/packages/contracts/src/Raffle.sol:416
root_cause: The factory treats sponsor-controlled callbacks and ownerOf results as proof that the raffle holds a deliverable prize.
invariant: Each Status.Active raffle must hold one deliverable prizeTokenId.
violation_path: sponsor → createRaffle → malicious safeTransferFrom → forged onERC721Received → false ownerOf result → Status.Active without a prize
path: sponsor → fake prize escrow → ticket sales → NftWon settlement → releaseSponsorProceeds → winner redemption reverts
proof: A malicious token reports IERC721 support, calls onERC721Received(factory,sponsor,7,"") without a transfer, and returns the clone from ownerOf(7). With reserveEntries=1 and 100 entries, buyers deposit 100,000,000 raw USDC units; settlement allocates 95,000,000 units to the sponsor despite the absent prize.
description: A sponsor can make a prize token report false custody, receive 95% of sales, and deny the winner a prize.
fix: The factory must accept only immutable trusted prize contracts, because an untrusted token controls the callback and every ownership check.

LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-nft-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-nft-proceeds-release
file: target/packages/contracts/src/Raffle.sol:309; target/packages/contracts/src/Raffle.sol:375; target/packages/contracts/src/Raffle.sol:533
root_cause: The NftWon settlement makes sponsor proceeds claimable before successful prize delivery and provides no later refund transition.
code_smells: The NftWon settlement creates sponsorProceeds before redemption, and releaseSponsorProceeds checks neither winnerRedeemed nor prizeClaimed.
proof: A genuine prize can enter escrow and later reject transferFrom. From a 100,000,000-unit pot, the sponsor withdraws 95,000,000 units; redemption always reverts, while enableRefunds rejects NftWon.
design_conflict: DESIGN.md permits independent sponsor claims after settlement, but it also defines prize contracts as untrusted.
description: A sponsor can take 95% of sales before the winner receives the NFT. The design permits this order, so the required failure response is unclear.
fix: The contract can delay NFT-outcome payouts until redemption succeeds and can enable refunds after a delivery deadline.