# Post-seal proof and reproduction — DAYBREAK-SIMAO

This follow-up was performed only after the source-only first pass was sealed at `2026-10-21T17:43:18Z`. It does not modify or replace `FIRST-PASS.md` or `SEAL.json`.

## Isolation and toolchain

- Frozen source commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- Isolated runtime copy: `DAYBREAK-SIMAO-continuation/proof-worktree/target`
- Production source edits: none
- Proof-only file: `proof/DaybreakSimaoProof.t.sol`
- Proof-file SHA-256: `c059b1e87c4e37ad9ab767d613eb852f32afba324a18d29dcf4fec178baac5ae`
- Foundry: `forge 1.7.1` (`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`)
- Network, live transactions, and publishing: none

The untouched isolated copy compiled before the proof harness was added. The final proof run compiled successfully and passed 4/4 tests with no failures or skips.

## Results

| First-pass item | Follow-up result | Evidence |
| --- | --- | --- |
| H-1 — hostile or revocable prize code passes `_validateCreateParams()` | Reproduced | A sponsor-controlled ERC-721 reports interface support, escrows normally, and later blocks transfers from the raffle. The factory admitted it and the raffle reached `NftWon`. The counterfeit variant was also admitted without any enforceable token balance. |
| H-2 — `createRaffle()` accepts token-supplied custody assertions | Reproduced | `CounterfeitPrize` fabricated the receiver callback and `ownerOf()` answer, activated the clone, later fabricated delivery, and left the winner with zero enforceable token balance while buyer USDC was paid out. |
| H-3 — settlement creates payable claims before NFT delivery | Reproduced | For a 100-USDC pot, `settleWinningTicket(1)` created a 95-USDC sponsor claim and a 5-USDC treasury claim after delivery had been disabled. |
| H-4 — failed NFT delivery has no refund escape | Reproduced | Winner redemption reverted with `BLOCKED_FROM`; the ticket and `winnerRedeemed == false` rolled back, status remained `NftWon`, and `enableRefunds()` reverted with `InvalidStatus(3)`. |
| H-5 — proceeds can leave before delivery | Reproduced | Sponsor and treasury released the entire 100-USDC pot. The raffle's actual and accounted quote balances both became zero while the winning ticket remained unredeemable. |
| Lead J-3 — transfer around the VRF reveal | Mechanism reproduced; remains a lead | Ticket 1 transferred Alice→Bob in `Drawing` and Bob→Carol in `NftWon`. The local source does not establish an external stale order or real-world visibility/ordering of a pending fulfillment, so no source-only promotion is warranted. |
| Lead J-7 — contract winner receives NFT without acknowledgement | Mechanism reproduced; remains a lead | A contract received the ticket through one ERC-721 receiver callback and redeemed it. The prize became nominally owned by the contract through `transferFrom()` without a second callback. Permanent third-party loss still depends on an out-of-scope recipient design, so no promotion is warranted. |

## Critical-chain state

The verbose trace records the complete retained chain:

1. The switchable prize passes `supportsInterface`, transfers into the clone, and activates it.
2. Alice purchases 100 entries for `100,000,000` raw six-decimal quote units.
3. The authenticated mock wrapper resolves entry 1 as `NftWon`.
4. The sponsor disables transfers from the clone.
5. Settlement allocates `95,000,000` to the sponsor and `5,000,000` to the treasury.
6. Both claims are released, reducing the clone's actual and accounted quote balances to zero.
7. Alice's redemption reverts, refunds remain unavailable, her ticket remains live, and `winnerRedeemed` remains false.

## Evidence files

- `proof/proof-test-final.log` — final 4/4 test summary; SHA-256 `7bdc5fc44d3476b6bc0ac25e77a51e69fc7e6a48bf3d9ccdf46794f1404e0129`
- `proof/critical-chain-trace.log` — verbose transaction-level trace; SHA-256 `6611992edb7d2bb4007c0ef791844108d73ff3b61d10be4916523113d6bdfa64`
- `proof/baseline-forge-build.log` — pre-harness isolated baseline build; SHA-256 `a7af529aae50f36b0d1211432693748cc591d8556f5b2475037ec28dcfbee325`
- `proof/proof-test-01.log` — preserved first successful test run before formatting normalization
- `proof/proof-fmt-check-01.log` — preserved initial style-only failure

## Commands

```text
forge build
forge fmt --check test/foundry/DaybreakSimaoProof.t.sol
forge test --match-path test/foundry/DaybreakSimaoProof.t.sol -vvv
forge test --match-test test_revocablePrizeDrainsClaimsWhileWinnerCannotRedeemOrRefund -vvvv
```

No rejected source-first candidate was resurrected, no cross-cell material was consulted, and model agreement was not used as proof.
