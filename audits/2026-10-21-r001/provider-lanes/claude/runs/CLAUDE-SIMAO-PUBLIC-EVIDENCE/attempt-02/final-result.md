I ran Turn 4 through Turn 6 of the public-evidence Simao method in attempt-02. All 12 lenses returned output and the full report is written. This is the disclosed public-evidence variant, not an original unmodified Simao run. The attempt-01 failure (parent ended at Turn 5, all 12 background children killed, no report) is recorded as a failure, not a completed review.

**Integrity checks before and after the lens runs:**
- The 43 input files matched their baseline hashes before the lenses, after them, and at the end. No source, build or lock bytes changed.
- The 31 dependency hashes and 14 bundle hashes also match.
- All 12 bundles are byte-exact concatenations of source + money map + method + lens + shared rules.

**Turn 4/5:**
- I launched the 12 lenses in one parallel foreground batch on Opus 5.5 at max effort, each with only its own bundle.
- All 12 returned output, so none needed a re-run.
- Each raw output is in `evidence/raw-lens-outputs/`.

**Turn 6 result:**
- The 43 raw items (3 findings, 40 leads) deduplicated into 15 groups. Scripted checks passed for function isolation and for the 37 mitigation and caution quotes being verbatim from the raw outputs.
- `Completeness: 11 unique (Contract, function) in raw, 11 covered in final.`
- **0 High · 5 Medium · 3 Low · 0 Info, plus 7 unverified leads.** The findings:
  - **M-1** `releaseSponsorProceeds()`, and the same gap in `releaseProtocolFees()`: when the reserve is met and the NFT is the prize, the sponsor's 95% and the treasury's 5% are paid without checking the prize was delivered. A prize contract that blocks transfers leaves the winner with nothing. Raised by 9 lenses.
  - **M-2** `buyEntries()`: the sponsor can buy last-minute entries, 95% of which come back to it, diluting other buyers' odds on the NFT.
  - **M-3** `_settleWinningTicket()`: the sponsor's 95% share is computed on a pot that includes its own entries.
  - **M-4** `_settleWinningTicket()`: the NFT-prize split is booked with no dependency on the NFT being delivered.
  - **M-5** `redeemWinningTicket()`: there is no fallback if prize delivery fails.
  - **L-1** `_update()`: tickets can be traded while the random draw result is pending, so stale listings can be sniped.
  - **L-2 and L-3** `fulfillRandomWords()` and `buyEntries()`: the sponsor can buy the missing entries to reach the reserve, switching buyers' 80% cash prize to the NFT outcome at about 5% of that cost.

The count overstates the number of distinct issues. M-1, M-4 and M-5 are one root cause, which all 12 lenses raised. M-2, M-3, L-2 and L-3 are another: the sponsor's own entries come back at 95%. The native rules forbid merging findings across functions, so the report cross-references them under "Systemic observations". All 12 lenses found the USDC accounting conserved in every lifecycle.

**What didn't go as specified:**
- **Cleanup denied:** the final cleanup (`rm -rf ./.audit-simao-s29F2o`) was denied by the permission system, after I had made and verified an exact copy in `evidence/native-preserved/`. I didn't retry it or work around it. The bundle directory is still there, unchanged (all 14 hashes match).
- **Early denial:** my first verification command, which used `/tmp` scratch files and `rm`, was also denied. I re-ran the checks as read-only commands.
- **Independence not audited:** each lens stayed independent only through its prompt instructions and by writing its output as its last step. I couldn't inspect the lenses' actual tool calls from inside the workspace.
- **Report condensed here:** the full report is in the file; this message is the short version.

Files are in the work directory:
- `FIRST-PASS.md`
- `FIRST-PASS.md.sha256` (`21a16f6a3dd82428a3ee25864428cc166e351953d9aa96c543f1cf0b97a805de`)
- `METHOD-STAGES.json`
- `evidence/native-report.md`
- `evidence/turn6/gate-ledger.md`
- `evidence/turn6/dedup-ledger.md`
- `evidence/ledger/attempt-02-stage-ledger.md`