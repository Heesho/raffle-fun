FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-token | group_key: RaffleFactory | createRaffle | untrusted-prize-token
file: target/packages/contracts/src/RaffleFactory.sol
path: attacker sponsor → fake `safeTransferFrom` invokes `onERC721Received` without custody → fake `ownerOf` reports clone → buyers fund raffle → sponsor withdraws proceeds
proof: `FakeERC721` can report ERC-721 support, invoke the expected callback, and return each clone from `ownerOf`. The same token ID can activate two raffles. Two 100-entry raffles allocate 95,000,000 units each to the sponsor, so the attacker receives 190 USDC without exclusive prizes.
description: The factory trusts a sponsor’s ERC-721 reports, so the sponsor can collect 95% of buyer funds without an enforceable prize.
fix: The factory must allow only audited ERC-721 contracts with immutable ownership logic and no privileged transfer controls.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
path: sponsor escrows mutable prize → buyer purchases 100 entries → callback sets `NftWon` → settlement allocates proceeds → sponsor receives proceeds → prize transfer reverts
proof: A 100-entry ticket creates a 100,000,000-unit pot. Settlement assigns 95,000,000 units to `sponsorProceeds` and 5,000,000 units to `protocolFees`. The sponsor receives 95 USDC before redemption. A blocked prize transfer reverts every redemption, while `enableRefunds` rejects the permanent `NftWon` status.
description: `releaseSponsorProceeds` pays before `winnerRedeemed`, so a sponsor can block prize delivery and take 95% of buyer funds.
fix: The raffle must require `winnerRedeemed` before it releases sponsor proceeds after an `NftWon` result.