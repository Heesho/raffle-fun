
---

## Action plan

Effort estimates assume the harness in `tob-s6-artifacts/harness/` is adopted, so every fix can be re-verified with the existing properties and PoCs.

### Critical (fix before deployment)

None. No issue allows theft of funds, breaks solvency, or bypasses access control under the documented trust model.

### High priority (decide and fix before deployment)

1. **TOB‑S6‑3: couple `NftWon` sponsor payouts to prize deliverability, or explicitly accept and disclose the risk.** About 1 day of design, then 2–3 days of implementation and tests.
   - Option A: release the `NftWon` sponsor share only after `winnerRedeemed`, with a long-timeout cash fallback to the winning ticket.
   - Option B: a prize list fixed at factory deployment.
   - Minimum: UI disclosure of prize-collection admin powers and an update to `DESIGN.md`.
   - Re-verify with PoCs G4 and H5 (they should fail after the fix) and property P31.
2. **TOB‑S6‑1: fail-closed destination screen on prize outflows.** About 0.5 day.
   - Call `_isProtocolDestination` in `releaseSponsorPrize` and in the NFT branch of `redeemWinningTicket`.
   - Decide whether an immutable recipient that later becomes invalid gets a recovery path.
   - Optionally use `CREATE2` with a creator-bound salt.
   - G1 should then show no cross-clone movement; extend property P27 to predicted addresses.
   - The deployment script must reject a `protocolTreasury` equal to a predicted factory `CREATE` address (probe P1).
3. **TOB‑S6‑2: decide on a ticket-transfer lock while `Drawing`.** About 0.5 day plus a specification update. If the lock is adopted, add the property "no ownership change between request and resolution" and adapt PoC G3.

### Medium priority (before or alongside external audit)

4. **TOB‑S6‑7: commit the security tooling.** 1–2 days.
   - The harness: properties, Echidna profiles A and B, Foundry invariants and canaries, PoCs.
   - A `slither.config.json` plus a triage database for S1‑01 … S1‑15.
   - CI jobs: Slither (fail on new results), Echidna (≥30 min per profile nightly), Foundry invariants, and a mutation smoke run. Fix the stale `package.json` scripts.
5. **TOB‑S6‑4: align `DESIGN.md` and the code on empty-raffle cancellation.** About 0.5 day.
6. **TOB‑S6‑5: document the immutable-recipient blocklist risk.** Optionally let recipients redirect their own pending claims. About 1 day.

### Low priority

7. **TOB‑S6‑8:** migrate to `ReentrancyGuardTransient`, then re-run the full suite and mutation analysis. About 0.5 day.
8. **TOB‑S6‑6:** document stranded value; optionally add a permissionless USDC surplus sweep to the treasury. About 0.5 day.
9. **Formal checks:** Halmos or Manticore proofs of P8, P13, P17, and P18. 2–3 days.
10. **Operations:** deployment scripts must assert the canonical USDC and VRF-wrapper addresses per chain. Monitor VRF fulfillment latency against the 2‑day deadlines. Publish marketplace guidance for tickets (cancel listings before `endTime`; verify `factory.isRaffle`).

---

## Workflow checklist

| Step | Status | Evidence |
|---|---|---|
| 1. Slither | ✅ Fully triaged. 110 results, 15 in scope, 0 true positives. | Step 1; Appendix B |
| 2. Special features | ✅ Clone and initializer checks (`slither-check-upgradeability`: 2 expected informational results); ERC‑721 and ERC‑165 conformant; `slither-prop` not applicable (no ERC‑20 implementation, verified); token integration reviewed | Step 2; Appendix C |
| 3. Visual inspection | ✅ Inheritance graph (SVG + Mermaid), function summary, vars-and-auth, state-machine and asset-flow diagrams, storage layout | Step 3; Appendix D |
| 4. Properties and testing | ✅ 32 properties documented. Echidna and Foundry harness built and validated (sanity tests, canaries, 12-mutant analysis). Custom Slither checks run. ⚠ Manticore unavailable; substituted by a hand proof plus boundary tests and mutants. | Step 4; Appendices E–G |
| 5. Manual review | ✅ Privacy, front-running, cryptography, and DeFi reviewed; 8 findings, each reproducible by PoC where applicable | Step 5 |

**Workflow status: complete for the tool-assisted stage.** The remaining work is the fixes and decisions in the action plan. After fixes, re-run the five steps, in particular Step 4's harness (the PoCs are expected to start failing) and the mutation analysis.
