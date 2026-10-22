FINDING | contract: Raffle | function: settleWinningTicket | bug_class: payout-before-prize-delivery | group_key: Raffle | settleWinningTicket | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:304
pair_or_branch: standalone `settleWinningTicket` plus `releaseSponsorProceeds` / inline settlement in `redeemWinningTicket`
asymmetry: Standalone settlement persists sponsor proceeds without prize delivery, while inline settlement reverts those proceeds when the same delivery fails.
root_cause: `_settleWinningTicket` makes NftWon proceeds releasable before `redeemWinningTicket` proves prize delivery.
path: sponsor escrows an unpaused pausable ERC-721 → buyer purchases → sponsor pauses transfers → `NftWon` → standalone settlement → sponsor withdrawal → winner redemption reverts
proof: With `reserveEntries = 1` and one 1,000,000-unit entry, `_settleWinningTicket` assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. `releaseSponsorProceeds` pays the sponsor without checking `prizeClaimed`. The paused prize then reverts at `prizeToken.transferFrom`, while `enableRefunds` rejects the terminal `NftWon` status.
description: A sponsor can pause its escrowed prize and claim 95% of buyers' USDC before the winner can receive the NFT.
fix: The contract must require `prizeClaimed` before it releases NftWon sponsor or protocol proceeds.