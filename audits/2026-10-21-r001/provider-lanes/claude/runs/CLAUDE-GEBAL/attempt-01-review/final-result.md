I wrote `review.json` in this directory. It found no high or medium issues: one low-severity design risk and three informational notes. The file passes the schema; `jsonschema` isn't installed, so I checked it with a hand-written validator covering every keyword the schema uses. `schemaVersion`, `snapshotHash` and `contextHash` match `context.json` exactly. All 21 cited line spans are in range, and I printed each one to confirm it points at the code described.

| # | Title | Severity | Confidence |
|---|---|---|---|
| 1 | Prize escrow and delivery are verified only through the untrusted prize contract, and sponsor proceeds in the NFT outcome don't depend on delivery | low | high |
| 2 | The winning ticket can be identified from the pending VRF fulfillment while tickets remain transferable during the draw | informational | medium |
| 3 | The sponsor prize return isn't re-checked at release time, and not-yet-deployed clone addresses pass creation-time checks | informational | high |
| 4 | Empty raffles can close before the stated refund deadline: the sponsor at any time, anyone else at sale end | informational | high |

- **Finding 1** is the only one with real buyer impact. A malicious or admin-controlled prize contract can fake the escrow, or block delivery after the draw, while the sponsor still collects 95% of the pot. The requirements say sponsor and treasury claims are independent, so this is a risk the design accepts rather than a coding mistake.
- **Findings 2–4** are a trade-off of freely transferable tickets, a self-inflicted edge case, and a gap between the requirements and the code. None of them puts raffle funds at risk.

**Assumptions:**
- USDC behaves as a standard token with no fees or hooks.
- The Chainlink VRF v2.5 wrapper is canonical: it calls back asynchronously, at most once per request, and doesn't retry.
- Ethereum mainnet timestamps.
- Prize contracts and ticket recipients may be hostile.

**Checked by reading, no defect found:**
- Liabilities always add up to total sales, with no rounding dust.
- Refunds are exact, and each ticket is burned before it is paid.
- The time windows match the spec and can't overlap at the same timestamp.
- The VRF callback only records the result.
- Settlement only records allocations, and only the ticket owner can redeem, atomically.
- Only the factory can initialize a raffle, once.
- Every state-changing function is protected against reentrancy, apart from the standard ticket transfer functions, the prize-deposit hook and the VRF callback, which have their own guards.
- Every raffle can reach an exit within 34 days.

**Main gaps** (11 are listed in the file):
- Nothing was compiled, tested, fuzzed or formally proven.
- The Chainlink wrapper and coordinator code isn't in the snapshot, so findings 2's mechanism and the timing conclusions depend on assumed behavior.
- USDC's blacklist and pause powers weren't assessed.
- The dependencies weren't compared against the published releases.
- How `@chainlink/contracts` imports resolve at build time wasn't verified.
- Tests, deployment scripts and the frontend weren't in scope.

I only reviewed source text; I ran no assessed code, builds or tests. I didn't see any other reviewers' findings, analyzer output or labels, so this is an independent cold pass. One printout was too long, and the harness saved it to a file outside this directory; I didn't open it and re-printed the source in chunks instead.