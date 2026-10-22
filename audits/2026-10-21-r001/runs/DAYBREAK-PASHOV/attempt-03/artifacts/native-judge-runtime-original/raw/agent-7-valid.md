FINDING | contract: RaffleFactory | function: createRaffle | bug_class: false-prize-ownership | group_key: RaffleFactory | createRaffle | false-prize-ownership
file: target/packages/contracts/src/RaffleFactory.sol:97
path: sponsor → createRaffle → false ownership reports → buyers fund raffle → false delivery report → winner ticket burns → sponsor takes proceeds
root_cause: `createRaffle` trusts sponsor-controlled `supportsInterface`, `safeTransferFrom`, and `ownerOf` behavior as proof that the raffle received a usable prize.
assumption: An untrusted prize contract reports ownership and transfer rights truthfully.
violation: The sponsor separates reported ownership from transfer authority, so each ownership check passes while the sponsor retains control.
proof: `FakePrize` reports ERC-721 support, calls `onERC721Received`, and makes `ownerOf(7)` return the raffle while the sponsor remains controller. With `reserveEntries=1`, ticket 1 buys 100 entries for 100,000,000 USDC units. During redemption, `transferFrom` changes only the reported owner to the winner. The next `ownerOf` check passes, so the raffle burns ticket 1 and sets `winnerRedeemed`. The winner’s later transfer reverts because only the sponsor remains authorized. The sponsor receives 95,000,000 units.
description: A sponsor can make an ERC-721 lie about ownership, take 95% of sales, and give the winner no usable token.
fix: The factory must enforce an immutable allowlist of ERC-721 contracts whose ownership and transfer rules the protocol trusts.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: sponsor-payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | sponsor-payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:375
path: sponsor escrows prize → prize blocks outbound transfers → settleWinningTicket allocates proceeds → releaseSponsorProceeds pays sponsor → redeemWinningTicket always reverts
root_cause: `releaseSponsorProceeds` sends an `NftWon` allocation without checking that `redeemWinningTicket` completed prize delivery and set `winnerRedeemed`.
assumption: An escrowed prize remains transferable, so settlement can expose sponsor proceeds before delivery.
violation: The sponsor controls a prize that accepts the factory deposit but rejects every transfer from the raffle.
proof: A prize with truthful ownership transfers token 7 from the sponsor to the raffle during creation. A victim buys ticket 1 with 100 entries for 100,000,000 USDC units, and `reserveEntries` is 1. After `NftWon`, `settleWinningTicket(1)` sets `sponsorProceeds` to 95,000,000. `releaseSponsorProceeds` pays that amount while `winnerRedeemed` is false. The prize then rejects the winner’s transfer, redemption reverts, and `NftWon` prevents refunds.
description: A sponsor can block the escrowed prize transfer and collect 95% of sales before the winner receives the prize.
fix: For `NftWon`, `releaseSponsorProceeds` must require `winnerRedeemed` before it sends the sponsor balance.