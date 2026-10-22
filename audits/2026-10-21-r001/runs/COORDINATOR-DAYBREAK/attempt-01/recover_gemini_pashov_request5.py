#!/usr/bin/env python3
"""Recover the exact superseded request-5 receipt without changing current evidence."""

from hashlib import sha256
from pathlib import Path
import json


AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
CURRENT = AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication/completion-receipt.json"
EXPECTED_CURRENT = "71f7217e769720ad230d8eac6c3f8fedc906abc7c56029729f250a8942d95bf7"
EXPECTED_OLD = "7da051d58f1b0b46925cfefc0a9fd42d606f3962c323ddba89c3c8c5fd8c1c5e"
DESTINATION = AUDIT / f"historical-preimages/coordinator-drafts/{EXPECTED_OLD}.completion-receipt.json"
CURRENT_MANIFEST = AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication/integrity-manifest.json"
EXPECTED_CURRENT_MANIFEST = "10d690d922be488e5d64bb1f64b462254e519cd50af30cedd060f1991c44ade8"
EXPECTED_OLD_MANIFEST = "b890eaed2c3a541c811adcf3cfbf7e96be274244fd1b588d290f9d311a01339d"
MANIFEST_DESTINATION = AUDIT / f"historical-preimages/coordinator-drafts/{EXPECTED_OLD_MANIFEST}.integrity-manifest.json"
CURRENT_SEAL = AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication/SEAL.json"
EXPECTED_CURRENT_SEAL = "0462347eae39b0cba0ffc41545fe85938e71bee4223a54df50e872bdfb6cbb48"
EXPECTED_OLD_SEAL = "b20488808bff940b7253d4c969c9c5d09322add6ad9c8737538128f65393d7b6"
SEAL_DESTINATION = AUDIT / f"historical-preimages/coordinator-drafts/{EXPECTED_OLD_SEAL}.SEAL.json"

BLOCK = (
    b'  "adjudication": {\n'
    b'    "path": "runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication/ADJUDICATION.md",\n'
    b'    "sha256": "5f181aa5fb97a3622055ea378a3613994e27fe31d5215fd750f5ae7dfc670dc3"\n'
    b'  },\n'
)


def digest(data: bytes) -> str:
    return sha256(data).hexdigest()


def preserve(path: Path, data: bytes) -> None:
    if path.exists():
        assert path.read_bytes() == data
    else:
        with path.open("xb") as handle:
            handle.write(data)


current = CURRENT.read_bytes()
assert digest(current) == EXPECTED_CURRENT
assert current.count(BLOCK) == 1
recovered = current.replace(BLOCK, b"", 1)
assert len(recovered) == 6551
assert digest(recovered) == EXPECTED_OLD

DESTINATION.parent.mkdir(parents=True, exist_ok=True)
preserve(DESTINATION, recovered)

current_manifest_bytes = CURRENT_MANIFEST.read_bytes()
assert digest(current_manifest_bytes) == EXPECTED_CURRENT_MANIFEST
old_manifest = json.loads(current_manifest_bytes)
old_manifest["recordedUtc"] = "2026-10-21T23:53:13.779112+00:00"
receipt_entries = [
    item for item in old_manifest["artifacts"]
    if item["path"].endswith("/gemini-pashov-adjudication/completion-receipt.json")
]
assert len(receipt_entries) == 1
receipt_entries[0]["bytes"] = 6551
receipt_entries[0]["sha256"] = EXPECTED_OLD
old_manifest_bytes = (json.dumps(old_manifest, indent=2) + "\n").encode()
assert len(old_manifest_bytes) == 28030
assert digest(old_manifest_bytes) == EXPECTED_OLD_MANIFEST
preserve(MANIFEST_DESTINATION, old_manifest_bytes)

current_seal_bytes = CURRENT_SEAL.read_bytes()
assert digest(current_seal_bytes) == EXPECTED_CURRENT_SEAL
old_seal = json.loads(current_seal_bytes)
old_seal["sealedUtc"] = "2026-10-21T23:53:13.779731+00:00"
old_seal["completionReceipt"]["sha256"] = EXPECTED_OLD
old_seal["integrityManifest"]["sha256"] = EXPECTED_OLD_MANIFEST
old_seal_bytes = (json.dumps(old_seal, indent=2) + "\n").encode()
assert len(old_seal_bytes) == 1350
assert digest(old_seal_bytes) == EXPECTED_OLD_SEAL
preserve(SEAL_DESTINATION, old_seal_bytes)

assert digest(CURRENT.read_bytes()) == EXPECTED_CURRENT
assert digest(DESTINATION.read_bytes()) == EXPECTED_OLD
assert digest(CURRENT_MANIFEST.read_bytes()) == EXPECTED_CURRENT_MANIFEST
assert digest(MANIFEST_DESTINATION.read_bytes()) == EXPECTED_OLD_MANIFEST
assert digest(CURRENT_SEAL.read_bytes()) == EXPECTED_CURRENT_SEAL
assert digest(SEAL_DESTINATION.read_bytes()) == EXPECTED_OLD_SEAL
for digest_value, path in (
    (EXPECTED_OLD, DESTINATION),
    (EXPECTED_OLD_MANIFEST, MANIFEST_DESTINATION),
    (EXPECTED_OLD_SEAL, SEAL_DESTINATION),
):
    print(f"{digest_value}  {path}")
