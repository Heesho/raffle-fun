# Final extended campaign addendum

This append-only addendum supersedes the *current outstanding* status of the original Echidna 100,000-call targets in `TOOL-CAMPAIGN-SUMMARY.md`; the original interrupted attempts remain incomplete historical records.

Both extended attempts reached the actual native test limit, exited zero and reported all six properties passing. Cash/range: **100,040 calls**, seed **2026102101**, 14,661 instructions, eight codehashes, corpus 14, duration 176.995 seconds. NFT: **100,077 calls**, seed **2026102102**, 15,414 instructions, eight codehashes, corpus 14, duration 176.325 seconds. Both used one worker and sequence length 100. Their original native 180-second cutoff was raised to 1800 seconds with an outer 2000-second diagnostic bound; neither extended run timed out.

Exact commands, raw output, integrity checks and semantic assessments are in `runs/TOOL-ECHIDNA-EXTENDED-{1,2}/attempt-01/`. `ECHIDNA-EXTENDED-RESULTS.json` records the native counters. Counterexample absence is bounded by the handler, actor set, inputs and modeled dependencies. Native output does not report rejected-input/revert counts; those remain unknown.

The original separately bounded 3,000-call experiments remain distinct. No existing sealed tool summary or failed attempt was overwritten.

## Public fork setup repaired

Both maintained fork tests now pass at explicit mainnet/Sepolia block and hash pins, with actual quote transfers and local real-wrapper requests. See [PUBLIC-FORK-VALIDATION.md](PUBLIC-FORK-VALIDATION.md), the unmodified test source, command and raw output. Earlier unconfigured skips remain unchanged; no live candidate deployment or genuine offchain fulfillment is claimed.
