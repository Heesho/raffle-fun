I found no Critical, High or Medium defects. There is one confirmed Low (SUP-01), one confirmed Informational (SUP-02), and five integration risks. The full report is in `SUP-REPORT.md`; scratch tests are under `./sup-notes/poc/`, and `packages/` is unchanged (scope files re-hashed, all 31 dependency hashes still match).

**Main conclusion:** the core properties hold, both by reasoning and in executable tests:
- the contract always holds enough USDC to cover everything it owes;
- the 95/5 and 80/15/5 splits are exact, because gross is always a multiple of 1e6;
- nothing can be claimed twice;
- ticket ranges are contiguous and cover every entry, and the winner draw is uniform;
- initialization and status changes are one-shot;
- reentrancy through ERC-721 hooks is blocked;
- every raffle reaches an end state within about 34 days of creation.

Every timing comparison matches DESIGN.md exactly, with no gap or overlap at any window edge. 27 tests pass, including a multi-actor random-walk fuzz (512 runs, plus 3,000 more on a second seed) that checks the invariants after every step and then forces each raffle to drain completely.

**Findings:**
- **SUP-01 (Low, confirmed by test).** Clone addresses are predictable. A sponsor can set `sponsorRecipient` to the address a future clone will take, and creation-time checks can't catch it because nothing is deployed there yet.
  - Returning the prize (`Raffle.sol:404`) isn't re-checked at payout, unlike USDC payouts (`:565`). So the NFT ends up inside another clone, which breaks DESIGN's "never move assets between raffle clones".
  - The sponsor's USDC share also becomes unclaimable for good.
  - Only the sponsor's own assets are affected. Fix: apply the same payout-time check when returning the prize.
- **SUP-02 (Informational, confirmed).** If the deployer sets the treasury to a future clone address, `createRaffle` stops working permanently. No user funds are at risk.

**Integration risks:**
- **SUP-03.** Prize escrow is verified only through `ownerOf`, and a won NFT has no fallback if delivery fails (DESIGN deliberately requires a revert instead). The test uses a prize contract that doesn't clear approvals on transfer:
  - an accomplice pulls the prize out of an active raffle;
  - the sponsor still collects 95%;
  - the winner can never redeem.

  The USDC side is unaffected.
- **SUP-04.** The pending VRF fulfilment transaction reveals the winner about one block early, while tickets stay transferable, so marketplace listings and bids can be sniped.
- **SUP-05 to SUP-07** are lower-impact: who pays the VRF fee and why, failure modes of USDC and the VRF wrapper, and `_safeMint` reverting for EIP-7702 accounts.

I also checked one thing directly rather than just reasoning about it: during raffle creation a malicious prize contract can force the new clone into refunding, but the factory's final status check (`RaffleFactory.sol:132`) catches it and reverts the whole creation.

**Not covered:**
- the real Chainlink wrapper and USDC sources aren't in the working directory, so I modelled them with mocks;
- I didn't check solc 0.8.36's known-bug list, since external reads were excluded;
- there was no mainnet fork run and no formal verification, and the fuzzing has fixed limits.

The report lists these and every other gap.