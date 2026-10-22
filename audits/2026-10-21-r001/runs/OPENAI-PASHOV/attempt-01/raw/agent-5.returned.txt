LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: untrusted-prize-payout | group_key: Raffle | releaseSponsorProceeds | untrusted-prize-payout
file: target/packages/contracts/src/Raffle.sol:375
code_smells: The sponsor receives USDC before the winner receives the NFT.
path: sponsor creates raffle → buyers purchase entries → authenticated callback selects NftWon → anyone settles the winning ticket → anyone releases sponsor proceeds → winner attempts NFT redemption.
source_evidence: With 100 entries and reserveEntries = 100, _settleWinningTicket allocates 95,000,000 USDC units to sponsorProceeds and 5,000,000 to protocolFees; releaseSponsorProceeds transfers 95,000,000 without checking prizeClaimed or winnerRedeemed.
invariant: Under the untrusted-prize boundary, the winner must retain an executable NFT claim after the sponsor receives the sale proceeds.
unverified: The bundle contains no prize implementation that passes creation and then refuses all valid redemption transfers; this source-only path therefore does not establish an exploit.
trust_boundary: DESIGN.md treats arbitrary prize contracts as untrusted, while IRaffle.sol states that supported prizes are honest, standards-compliant ERC-721s.
description: A sponsor receives USDC before prize delivery; the supplied contracts do not prove that an accepted prize can refuse delivery after escrow.
