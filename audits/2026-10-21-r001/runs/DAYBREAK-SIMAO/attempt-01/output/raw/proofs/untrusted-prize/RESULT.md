# Untrusted prize proof result

Status: **PASS — 2 tests passed, 0 failed, 0 skipped.**

The primary Foundry test uses the copied production `Raffle` and `RaffleFactory` unchanged. A sponsor-controlled ERC-721 first performs a genuine OpenZeppelin ERC-721 safe transfer into the raffle clone. The factory observes `ownerOf(tokenId) == raffle` and the raffle becomes `Active`. The sponsor then irreversibly freezes outbound transfers.

One buyer pays 1,000,000 raw six-decimal quote-token units for one entry. Authenticated mock-wrapper fulfillment resolves entry 1 and terminal status `NftWon`. Permissionless settlement allocates 950,000 to `sponsorProceeds` and 50,000 to `protocolFees`; both releases succeed, leaving the raffle with zero quote-token balance and the buyer with zero refund liability.

The buyer's redemption reverts with `OutboundTransfersFrozen()`. The entire redemption transaction rolls back, so the ticket remains owned by the buyer and `winnerRedeemed`/`prizeClaimed` remain false. The same call still reverts after a 3,650-day warp. `enableRefunds()` then reverts with `InvalidStatus(NftWon)`, while `accountedQuoteBalance()` is zero. Thus an adversarial prize issuer can keep the NFT while sponsor/protocol proceeds are irreversibly paid and the winner has neither prize nor refund path.

The second passing test demonstrates the separate creation-time self-attestation weakness. A malicious ERC-721 invokes the expected receiver hook and reports the raffle as `ownerOf(tokenId)` without changing its underlying ERC-721 owner. `createRaffle` accepts it and leaves the raffle `Active`; the mock's `actualOwnerOf` remains the sponsor.

The logs contain a Foundry warning that its global signature cache could not be written outside the sandbox. Compilation and all tests completed with exit status 0; the warning does not affect the EVM execution or assertions.

Isolation: the proof copy is under `proof-work/untrusted-prize`. SHA-256 confirms its copied `src/Raffle.sol` and `src/RaffleFactory.sol` are byte-identical to `target/packages/contracts`; `target/` was not edited.
