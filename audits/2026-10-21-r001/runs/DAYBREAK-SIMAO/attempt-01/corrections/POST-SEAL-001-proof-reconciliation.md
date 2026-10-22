# Post-seal follow-up 001 — proof reconciliation

**FIRST-PASS seal:** `e3f441a444e260b5ea28a9dc26d5e6a25696aaa6dd1e9ca84ab22c185567f64f`  
**Disposition:** No correction to the sealed conclusions. The follow-up corroborates H-1 through H-4.

## Executed proof

An isolated Foundry copy used byte-identical production `Raffle.sol` and `RaffleFactory.sol` and passed 2/2 tests:

1. A genuine OpenZeppelin ERC-721 safe escrow succeeds; the sponsor permanently freezes outbound transfers; one 1-USDC entry resolves `NftWon`; settlement creates 950,000 sponsor and 50,000 protocol units; both release; winner redemption reverts immediately and after a 3,650-day warp; `enableRefunds()` reverts in `NftWon`; the raffle holds zero quote balance and records no refundable liability.
2. A malicious token fabricates the expected receiver callback and reports the raffle as `ownerOf` while its independently tracked actual owner remains the sponsor; `createRaffle()` accepts and activates the clone.

This directly reproduces the component paths reported as H-1 (`createRaffle`), H-2 (`settleWinningTicket`), H-3 (`_settleWinningTicket`), and H-4 (`releaseSponsorProceeds`). The proof and traces are preserved in `output/raw/proofs/untrusted-prize/`; the primary test source hash is `a66e46245a2da2637da953e1e10b884e9bcf04cf7f35606dcb12b9b294db1d24`.

## Precise unmet proof obligations for remaining candidates

- **M-1 — `_transferQuote` sender freeze:** reproducing the named canonical-USDC condition requires an authorized Circle denylist state or an exact local/forked implementation and privileged freeze actor. Live actions were prohibited and no fork/network dependency was introduced. A mock freeze would demonstrate the already stated revert but would not prove Circle will target a raffle clone.
- **M-2 — fixed recipient freeze:** the same named issuer-controlled condition is required. A complete follow-up must freeze the immutable sponsor recipient or treasury after settlement and show that every retry retains the claim while targeting the same address.
- **`buyEntries` lead:** the arithmetic timeline is source-complete, but no test can establish the missing normative premise that sponsor-funded entries are forbidden or that an entrant owns a cash-branch entitlement before an open sale closes. A protocol-intent rule and sybil-resistant invariant are required.
- **`requestDraw` lead:** an EVM harness can warp beyond `uint64.max` and confirm the narrowing behavior, but a reportable proof also needs a supported chain capable of reaching that timestamp and real present-day value at risk; that obligation is unmet.
- **`_isProtocolDestination` lead:** a harness can reproduce self-stranding at a predicted/foreign clone. Promotion requires a path by which an attacker forces a distinct victim's claim into that address or extracts value; no such path was found.

## Proof artifact hashes

- `UntrustedPrizeProof.t.sol`: `a66e46245a2da2637da953e1e10b884e9bcf04cf7f35606dcb12b9b294db1d24`
- `forge-test.log`: `f402b753228f60675a536a488dafcf06f5c96fc03131e7c3ba2edff9cd691e00`
- `primary-trace.log`: `64ac467af6742c3f7fd15c1e2d65686a73dc5e884ace6c6a6941b92fdf669ac9`
- `self-attestation-trace.log`: `9271fc535f259f52eb29dc1a6b1ead272f43646863431daeffa6c33d691be2d1`
