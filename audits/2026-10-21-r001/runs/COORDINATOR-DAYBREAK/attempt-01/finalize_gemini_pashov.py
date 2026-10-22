#!/usr/bin/env python3
from pathlib import Path
import datetime
import hashlib
import json

AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
PKG = AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication"
ATTEMPT = AUDIT / "runs/GEMINI-PASHOV-REPAIRED/attempt-04"
ADJ = ATTEMPT / "adjudication"
NATIVE = ADJ / "native-run"
FIRST = ADJ / "native-first-pass"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


expected = {
    FIRST / "FIRST-PASS.md": "8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802",
    FIRST / "run-1.md": "47998330e2c58643f5d4f5fd8a99dbcc6d2410febd77f456d809a0b9915b97ee",
    FIRST / "gate-ledger.md": "48ed47417382433bb061456a09895c274cd418c288c498e27830b3d9d94b27e9",
    FIRST / "native-artifact-preservation-receipt.json": "545e810ec59a374761a7e1a44e7eeeaf6d1d9666a33de6be96bf3fe913058e41",
    FIRST / "artifact-integrity-seal.json": "60c47bc20bbe2f9ddaf81dc395bf2da498b951cc29329efa538a5a6f37653091",
    ADJ / "protected-inputs.json": "2901cd30e78d9782e52dd4d4f3432a12d5234da0dc7c179b78ce9e0f371450f9",
    ADJ / "preparation.json": "efdce5aeefe899b738e71a538e0cce932519586161d0e3bdffda5f2e79fd398d",
    ADJ / "leaf-semantic-binding.json": "e2e4ab87e48797399b8f2c31214e46a7c5aeff1e12e289d715701f700fcb0c64",
    ATTEMPT / "explicit-high-leaves/input-manifest.json": "4baf5e92a998edefdfc0e5df7db3d58b91b744ba4121169ea92a40e14f7ba9de",
    AUDIT / "provider-route-repair/native-high-pashov-semantic-validation.approved.json": "735f92bc7248295e803ddbba8e16c9f755df2bbcbd57e338f003b1607aa1b67e",
    NATIVE / "native-terminal-result.json": "41866c19e22a77728417afd7886c20e24cb1ad9ee564e5d6eea8c38a293b307a",
    NATIVE / "transport-result.json": "76524b3c7d393a71bfdf877b8df1464158d79fca5e0b9a0fd6f7325ddc10abc1",
    NATIVE / "stdout.ndjson": "a2485284793d6b91ff84e3bb77e35e5ad83f237095b0b7f68fef3eeb305f3b8c",
    NATIVE / "report.native-response.md": "8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802",
    NATIVE / "continuation-01/native-terminal-result.json": "6814b232d1c7985cb000283937cde00030f94b6939481baa62dd45d7d2aab41f",
    NATIVE / "continuation-01/transport-result.json": "f03dd2cefc5884811ec1887684c3ad478f65cfc74e199beee03cc08c1ee8e091",
    NATIVE / "continuation-01/stdout.ndjson": "f5cb175b06d7ec600cb4be693e915f1b4143865133efbd77f60690561fc59e8b",
    NATIVE / "continuation-01/report.native-response.md": "8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802",
    NATIVE / "continuation-02/native-terminal-result.json": "286f0ca0475bd6a0f47e4eed744bcc821603af6ea1bff4929a28c8ae2de320e8",
    NATIVE / "continuation-02/transport-result.json": "5cc8ca6e6865d304aca00631485be403c24ad8d9a2c7fc67cf2fcc164d701a5d",
    NATIVE / "continuation-02/stdout.ndjson": "5b54a35628ab0437ef4bf8f0a4a377a0afab2e71fdde3079de31f352cab4d7c6",
    NATIVE / "continuation-02/report.native-response.md": "8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802",
}
for path, digest in expected.items():
    assert path.is_file(), path
    assert sha(path) == digest, (path, sha(path), digest)

for generation in [NATIVE, NATIVE / "continuation-01", NATIVE / "continuation-02"]:
    terminal = json.loads((generation / "native-terminal-result.json").read_text())
    transport = json.loads((generation / "transport-result.json").read_text())
    assert terminal["conversation_id"] == "a1bf9a6d-c915-4ccb-971d-a043d8ef5031"
    assert terminal["status"] == "ERROR"
    assert terminal["error"] == "The stream was interrupted. Please continue the task you were working on."
    assert transport["status"] == "failed"
    assert transport["exitCode"] == 0
    assert sha(generation / "report.native-response.md") == expected[NATIVE / "report.native-response.md"]

binding = json.loads((ADJ / "leaf-semantic-binding.json").read_text())
assert len(binding["receipts"]) == 12
assert binding["nativeTransportErrorsRenamedSuccess"] is False
assert binding["strictOriginalReceiptsOverwritten"] is False
assert sum(item["nativeTerminalStatus"] == "SUCCESS" for item in binding["receipts"]) == 10
assert [item["number"] for item in binding["receipts"] if item["nativeTerminalStatus"] == "ERROR"] == [3, 4]

paths = set(expected)
for item in binding["receipts"]:
    report = Path(item["sourceReport"])
    receipt = Path(item["receipt"])
    assert sha(report) == item["reportSha256"]
    assert sha(receipt) == item["receiptSha256"]
    paths.update([report, receipt])
    for prior in item.get("receiptChain", []):
        prior_path = Path(prior["receipt"])
        assert sha(prior_path) == prior["receiptSha256"]
        paths.add(prior_path)
    for reference in item["coordinatorSemanticValidation"]["coordinatorEvidenceReferences"]:
        if reference.startswith("/"):
            candidate = Path(reference)
            if candidate.is_file():
                paths.add(candidate)

adjudication = PKG / "ADJUDICATION.md"
receipt = PKG / "completion-receipt.json"
paths.update([adjudication, receipt])
assert json.loads(receipt.read_text())["nativeRunSucceeded"] is False
assert json.loads(receipt.read_text())["methodOutputsComplete"] is True

artifacts = []
for path in sorted(paths, key=lambda value: str(value)):
    artifacts.append({
        "path": str(path),
        "auditRelativePath": str(path.relative_to(AUDIT)) if path.is_relative_to(AUDIT) else None,
        "bytes": path.stat().st_size,
        "sha256": sha(path),
    })

manifest = {
    "schema": "raffle-fun.pashov-qualified-method-output-integrity-manifest.v1",
    "recordedUtc": now(),
    "targetCommit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
    "cell": "GEMINI-PASHOV",
    "qualification": "PASS_WITH_APPEND_ONLY_ADJUDICATION_AND_PRESERVED_NATIVE_ERRORS",
    "artifactCount": len(artifacts),
    "artifacts": artifacts,
    "checks": {
        "criticalExpectedHashesMatched": len(expected),
        "leafReportReceiptPairsMatched": 12,
        "nativeErrorGenerationsPreserved": 3,
        "nativeSuccessClaimed": False,
        "methodOutputsComplete": True,
        "newProductionRoots": 0,
    },
}
manifest_path = PKG / "integrity-manifest.json"
write(manifest_path, manifest)

seal = {
    "schema": "raffle-fun.pashov-qualified-method-output-seal.v1",
    "sealedUtc": now(),
    "cell": "GEMINI-PASHOV",
    "targetCommit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
    "status": "QUALIFIED_METHOD_OUTPUT_COMPLETE_WITH_NATIVE_ERROR_PRESERVED",
    "nativeTerminalStatus": "ERROR",
    "transportErrorsRenamedSuccess": False,
    "adjudication": {"path": str(adjudication), "sha256": sha(adjudication)},
    "completionReceipt": {"path": str(receipt), "sha256": sha(receipt)},
    "integrityManifest": {"path": str(manifest_path), "sha256": sha(manifest_path)},
    "reportSha256": "8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802",
    "globalAuditCompletionIssued": False,
}
write(PKG / "SEAL.json", seal)
print(json.dumps({
    "artifactCount": len(artifacts),
    "adjudicationSha256": sha(adjudication),
    "completionReceiptSha256": sha(receipt),
    "integrityManifestSha256": sha(manifest_path),
    "sealSha256": sha(PKG / "SEAL.json"),
}, indent=2))
