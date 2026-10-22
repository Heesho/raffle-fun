FINDING | contract: Raffle | function: buyEntries | bug_class: prize-custody-not-revalidated | group_key: Raffle | buyEntries | prize-custody-not-revalidated
file: target/packages/contracts/src/Raffle.sol
seam: three-way
actor: A sponsor that controls an admin transfer in the selected ERC-721 contract.
path: sponsor → valid initial escrow → admin removes prize → victim buys entries → NftWon → sponsor withdraws proceeds → winner redemption fails
root_cause: `createRaffle` verifies custody once, while `buyEntries` accepts later payments without a current ownership check.
proof: Set `reserveEntries=1`. The ERC-721 initially transfers token 7 to the raffle, then its admin returns token 7 to the sponsor. The victim calls `buyEntries(victim,1)` and pays 1,000,000 raw USDC. Ticket 1 always wins. Settlement assigns 950,000 to `sponsorProceeds` and 50,000 to `protocolFees`. The sponsor receives 950,000, but `redeemWinningTicket(1)` reverts because the raffle no longer owns token 7. `NftWon` rejects `enableRefunds`.
description: A sponsor can reclaim the prize before a purchase, keep the NFT, and take 95% of the buyer's payment.
fix: `buyEntries` must verify that the raffle owns `prizeTokenId` before it transfers the buyer's USDC.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: proceeds-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | proceeds-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
seam: three-way
actor: A sponsor that controls the selected prize contract and receives `sponsorProceeds`.
path: sponsor escrows prize → buyers fund raffle → sponsor pauses prize → NftWon → settlement allocates proceeds → sponsor withdraws → redemption fails
root_cause: `_settleWinningTicket` allocates USDC before NFT delivery, and `releaseSponsorProceeds` checks no delivery state.
proof: With `reserveEntries=100` and one 100-entry ticket, gross sales equal 100,000,000 raw USDC and ticket 1 always wins. The sponsor pauses outbound prize transfers. `_settleWinningTicket(1)` assigns 95,000,000 to `sponsorProceeds` and 5,000,000 to `protocolFees`. `releaseSponsorProceeds` pays the sponsor. `redeemWinningTicket(1)` then reverts in `prizeToken.transferFrom`, and `enableRefunds` rejects `NftWon`.
description: A sponsor can pause the prize transfer and take 95% of sales before the winner receives the NFT.
fix: `Raffle` must deliver the NFT before it releases sponsor or protocol proceeds and must enable refunds after delivery failure.