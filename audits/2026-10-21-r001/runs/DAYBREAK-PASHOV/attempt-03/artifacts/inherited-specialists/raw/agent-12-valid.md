FINDING | contract: RaffleFactory | function: createRaffle | bug_class: prize-self-attestation | group_key: RaffleFactory | createRaffle | prize-self-attestation
file: target/packages/contracts/src/RaffleFactory.sol; target/packages/contracts/src/Raffle.sol
seam: three-way
root_cause: `createRaffle` and `redeemWinningTicket` let one untrusted prize contract attest to both transfers through caller-dependent `ownerOf` results.
path: sponsor → `createRaffle` → fake prize calls `onERC721Received` without a transfer → `ownerOf` makes factory accept escrow → buyer pays → `NftWon` → fake redemption transfer → ticket burns → sponsor collects proceeds
trace: `createRaffle` → `safeTransferFrom` → forged callback → `ownerOf` reports the clone → `redeemWinningTicket` → no-op `transferFrom` → `ownerOf` reports the winner → false delivery state
violated_principle: A reserve-met winner must receive the escrowed ERC-721, and the raffle must escrow exactly one prize at creation.
proof: With `reserveEntries=1` and one 1,000,000-unit purchase, entry 1 wins; a fake token forges the callback, reports the clone only to the factory, no-ops redemption, and reports the winner only to the raffle, so `winnerRedeemed=true`, the ticket is burned, `balanceOf(winner)=0`, sponsor proceeds equal 950,000, and protocol fees equal 50,000.
description: A sponsor uses a false prize contract to collect 95% of sales, and the winner gets no transferable NFT.
fix: The factory must accept only prize contracts from an immutable allowlist because an untrusted token cannot prove its own custody.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
seam: three-way
root_cause: `_settleWinningTicket` creates sponsor and protocol claims before `redeemWinningTicket` proves that the prize contract permits delivery.
path: sponsor → escrow pausable ERC-721 → buyer pays → sponsor pauses prize → `NftWon` → settlement → sponsor withdraws proceeds → prize transfer reverts → refunds remain unavailable
trace: `settleWinningTicket` allocates quote tokens → `releaseSponsorProceeds` finalizes payment → `redeemWinningTicket` calls paused `transferFrom` → redemption reverts while the prior sponsor payment remains final
violated_principle: A reserve-met raffle must award the NFT to the winner.
proof: With `reserveEntries=1` and one 1,000,000-unit purchase, settlement allocates 950,000 to the sponsor and 50,000 to the treasury; the sponsor withdraws 950,000 before a paused ERC-721 rejects redemption, while `NftWon` prevents `enableRefunds`.
description: A sponsor pauses the prize after escrow and takes 95% of sales, so the winner cannot redeem the NFT or recover payment.
fix: The raffle must require `winnerRedeemed` before either `releaseSponsorProceeds` or `releaseProtocolFees` can pay an `NftWon` raffle.