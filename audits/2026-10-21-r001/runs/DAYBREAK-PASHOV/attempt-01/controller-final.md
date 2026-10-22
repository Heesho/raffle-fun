Cell execution is sealed, but the native Pashov audit is incomplete—not a clean result.

- All 12 fresh specialist threads used the required local model, `ultra`, and `daybreak_blue`, with no fallback. Each failed during workspace routing before returning a response.
- Native dedup and judging are `INCOMPLETE/BLOCKED`.
- The exact native assembler report states: “No pass produced a run file. This scan reviewed nothing.”
- Provider-returned model and identity are recorded as `unknown`.
- The isolated target copy compiled successfully: 36 files with Solidity 0.8.36.
- A controller-only lead was reproduced through the full economic path: a fake ERC-721 can fabricate escrow and delivery while the sponsor receives 95% of buyer funds. Both Forge proof tests pass. It remains unscored because the native judge did not run.
- Final target integrity verification passed with no source modifications.
- The supplied target SHA and Pashov pin could not be independently verified because both snapshots lack Git metadata.

Artifacts:

- [FIRST-PASS.md](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/FIRST-PASS.md>)
- [SEAL.json](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/SEAL.json>)
- [stage-ledger.json](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/stage-ledger.json>)
- [Exact native report](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/native/full-report.md>)
- [Controller lead](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/CONTROLLER-LEAD.md>)
- [Proof harness](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-01/proofs/UntrustedPrize.t.sol>)

First-pass SHA256: `0e27dee8bc1bf21f7997d261f5cbb9c70279f092eed0de1660cf280359f61e9d`  
SEAL.json SHA256: `ba10bb74ab485877cabbbf77c25a44cd0a35eee81c37fef6ad2aa39a46b54713`