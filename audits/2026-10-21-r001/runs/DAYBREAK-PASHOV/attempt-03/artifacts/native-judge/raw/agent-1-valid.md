FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-proceeds-release
file: target/packages/contracts/src/Raffle.sol
severity: high
root_cause: `releaseSponsorProceeds` and `releaseProtocolFees` pay `NftWon` claims without checking `winnerRedeemed`.
path: sponsor escrows pausable ERC721 → victim buys → `NftWon` → settlement → sponsor pauses prize → sponsor withdraws proceeds → winner redemption reverts
proof: With `reserveEntries=1`, one victim pays 1,000,000 units. Settlement assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. The sponsor pauses the prize and withdraws 950,000 units. `redeemWinningTicket` then reverts at `prizeToken.transferFrom`; `enableRefunds` rejects `NftWon`, so the victim cannot recover 1,000,000 units.
description: A sponsor can block the prize transfer and take 95% of ticket payments before the winner receives the NFT.
fix: The contract must require `winnerRedeemed` before either `releaseSponsorProceeds` or `releaseProtocolFees` pays an `NftWon` claim.