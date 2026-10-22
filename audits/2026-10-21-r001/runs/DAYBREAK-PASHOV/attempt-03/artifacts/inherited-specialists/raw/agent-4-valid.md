FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-attestation
file: target/packages/contracts/src/RaffleFactory.sol
input: The sponsor supplies `Fake721`, token ID `1`, and reserve `1`.
assumption: The factory assumes an attacker-selected prize contract can prove its own custody and transferability.
root_cause: `createRaffle` accepts custody evidence only from the selected `prizeToken`, which controls the transfer callback and `ownerOf` response.
path: sponsor → `createRaffle` → forged receiver callback → forged `ownerOf` result → `Active` → ticket sale → sponsor payout
proof: `Fake721` returns true for ERC-721 support, calls `onERC721Received(factory, sponsor, 1, "")` without a transfer, and reports the raffle from `ownerOf(1)`. One entry supplies 1,000,000 units; settlement assigns 950,000 units to the sponsor, while `Fake721` can reject winner delivery.
description: A sponsor can activate a raffle with no transferable prize, so buyers pay USDC and the sponsor takes 95% of the sales.
fix: The factory must accept only prize contracts that a fixed trusted allowlist approves.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: pre-delivery-sponsor-payout | group_key: Raffle | releaseSponsorProceeds | pre-delivery-sponsor-payout
file: target/packages/contracts/src/Raffle.sol
input: The sponsor supplies a prize with an administrator-controlled transfer block, sets `reserveEntries` to `1`, and blocks transfers after genuine escrow.
assumption: A prize that passes the initial escrow checks will remain transferable to the winner.
root_cause: `releaseSponsorProceeds` pays an `NftWon` sponsor without checking `winnerRedeemed` or current prize ownership.
path: genuine escrow → one entry → transfer block → `NftWon` → settlement → sponsor payout → failed redemption
proof: One entry creates a 1,000,000-unit pot. Settlement assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. The sponsor receives 950,000 units before `prizeToken.transferFrom` reverts; `enableRefunds` rejects `NftWon`.
description: A sponsor can block prize delivery after genuine escrow and take 95% of sales before the winner receives the NFT.
fix: Both release functions must require `winnerRedeemed` for `NftWon` before they transfer sponsor proceeds or protocol fees.