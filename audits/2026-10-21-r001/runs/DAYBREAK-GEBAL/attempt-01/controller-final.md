Native Gebal source-only workflow completed and imported successfully. Overall audit status is `PARTIAL` because execution stages were unavailable.

Findings requiring human review:

- High: an untrusted prize contract can fabricate both escrow and successful delivery by lying through `supportsInterface`, `ownerOf`, and transfer callbacks.
- Low: clone-destination filtering is factory-local, allowing cross-factory clone asset transfers under the stated isolation requirement.

Run details:

- Run: `a9a573ab-b66c-4d87-8ca0-1e7a5d5bcf78`
- Snapshot: `50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e`
- Context: `2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142`
- Gebal revision: `9ad24645f92a3821ae4539db5f1be52b48ed379e`
- Accepted local model: `gpt-daybreak-blue-latest`, `daybreak_blue`, `ultra`
- Provider-returned model: `unknown`
- All 40 scoped files still match the snapshot; target files were not modified.

Deliverables:

- [Sealed first pass](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-GEBAL/attempt-01/deliverables/FIRST-PASS.md>)
- [Native Gebal report](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-GEBAL/attempt-01/deliverables/native/report.source-only.md>)
- [Stage ledger](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-GEBAL/attempt-01/deliverables/stage-ledger.json>)
- [SEAL.json](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-GEBAL/attempt-01/deliverables/SEAL.json>)
- [Output manifest](</Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-GEBAL/attempt-01/deliverables/output-manifest.sha256>)

The test-inclusive plan was correctly left `BLOCKED`: Docker was unavailable and no pinned tool image was configured. No host-tool fallback was used. The separate exact-selection CLI specialist also produced no response because network access was denied; its raw failure logs are preserved.