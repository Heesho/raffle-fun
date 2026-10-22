# Controller-only lead (not a native Pashov finding)

The 12-specialist pass returned no responses, so the native judge never evaluated this item. The controller found and locally reproduced it while preserving the failed native output.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-report | group_key: RaffleFactory | createRaffle | untrusted-prize-self-report

- Source: `RaffleFactory._validateCreateParams` accepts the prize contract's own ERC-165 answer at lines 171-177.
- Source: `RaffleFactory.createRaffle` trusts that same contract's `safeTransferFrom` callback and `ownerOf` answer at lines 127-133.
- Source: `Raffle.onERC721Received` activates the raffle from the prize contract's callback at lines 416-430.
- Source: `Raffle.redeemWinningTicket` trusts the prize contract's `transferFrom` and `ownerOf` answers at lines 334-336.
- Path: any sponsor deploys a fake ERC-721, creates a reserve-one raffle, sells one entry, receives 95% of sales, and fabricates prize delivery to the winner.
- Proof: `proofs/UntrustedPrize.t.sol::testFakePrizeTakesBuyerPaymentThroughFullRafflePath` passes with a buyer balance of zero, sponsor proceeds of 950,000, and unchanged internal prize ownership.
- Code smells: one untrusted contract controls every compliance, escrow, and delivery observation.
- Description: An attacker's prize contract fabricates ownership, so the raffle pays the sponsor 95% of sales while the winner receives no NFT.
- Minimal remediation: Treat prize contracts as trusted through an immutable registry, or change the stated trust model because arbitrary ERC-721 escrow cannot be verified onchain.

Controller gate trace (informational, not the absent native judge decision):

- Gate 1 — ALLOWS: all checks read answers or callbacks controlled by the fake prize contract.
- Gate 2 — ALLOWS: any external caller can deploy the prize and use the ordinary creation path.
- Gate 3 — ALLOWS: the sponsor needs no role and sets `reserveEntries` to one.
- Gate 4 — ALLOWS: one 1,000,000-unit purchase pays 950,000 units to the sponsor while the fake prize stays in the sponsor's ledger.
