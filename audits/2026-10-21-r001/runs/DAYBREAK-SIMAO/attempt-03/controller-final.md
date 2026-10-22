Audit completed and sealed using the pinned 0xSimao accounting-first method.

- Native result: 5 High findings, 2 retained leads, 2 rejected candidates.
- Completeness: all 8 unique raw `(contract, function)` pairs covered through 9 four-gate adjudications.
- Local proof: 4/4 tests passed, reproducing all five accepted findings.
- Both leads’ mechanisms reproduced, but their missing external preconditions remain unresolved; neither was promoted.
- Required route retained: `gpt-daybreak-blue-latest`, `daybreak_blue`, `ultra`, no fallback. Provider identity remains unknown because events omitted it.
- Freeze verification passed before, at seal, and after proof. No production, configuration, lock, or freeze files changed.

Artifacts:

- [FIRST-PASS.md](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/FIRST-PASS.md)
- [SEAL.json](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/SEAL.json)
- [Native report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/NATIVE-REPORT.md)
- [Post-seal proof report](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/POST-SEAL-PROOF.md)
- [Stage ledger](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/stage-ledger.json)
- [Artifact hash manifest](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-03/AUDIT-ARTIFACTS.sha256)

Key hashes:

- First pass: `e44b2b1995fdf0410fc4608fbce64ba0fa28ae76e185564651468cad066a6f7c`
- Seal: `e4f532492a514f2d289a4dec5f1036791d704de003880eaa3ccdc26eb4e24c8a`
- Stage ledger: `ae345848c0a32db1a44846fbe4fd718c67aab3c99bcfa6a07b6ab69b8df00c86`
- Artifact manifest: `e6a2f809bc95934b535738c06d1245cc42bb16879dc6dc7c8aa7f4f5a204af9f`