#!/usr/bin/env python3
from pathlib import Path
import datetime
import hashlib
import json
import re

AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
ATTEMPT = AUDIT / "runs/DAYBREAK-TOB/attempt-03"
PKG = AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/daybreak-tob-adjudication"
OBS = AUDIT / "reconciliation/finalization/DAYBREAK-TOB-03-SEAL-VERSION-OBSERVATION.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


receipt_path = PKG / "completion-receipt.json"
manifest_path = PKG / "integrity-manifest.json"
seal_path = PKG / "SEAL.json"
for output in (receipt_path, manifest_path, seal_path):
    assert not output.exists(), f"refusing to overwrite {output}"

expected = {
    ATTEMPT / "REPORT.md": "32ad9d271ef4d3ecb7f4b093b22d0beed2162305e29a5d746e5f907038e90360",
    ATTEMPT / "REPORT.sha256": "fdf123720b82315477567e37a7315cd329e8ccc356ffd484fe56654984f019dc",
    ATTEMPT / "REPORT.timestamp": "826ddfcb15681902c7e670164d2cc9c3119b47e3548810480101aba7e0accbad",
    ATTEMPT / "FINAL-SEAL.json": "f0adec605906be11bab443e05711eae6278de90b076f100ade0ead817c2a1b4f",
    ATTEMPT / "FIRST-PASS.md": "981bea8dd6fe0e96328c38cf8375f93bc8bdf272476b4defcbeca71fdfdd9bc6",
    ATTEMPT / "SEAL.json": "c7d730eb6687f33fbc6e10bc43671ad1975813a03e05d37cbb2d85b6ca2ba82b",
    ATTEMPT / "stage-ledger.json": "e294618490edaef7e38e365629b0776754be689d44bbfdf50d6210ce179ec0cd",
    ATTEMPT / "artifacts/final-aggregate/FINAL-MANIFEST.sha256": "ee8cd2f29495ff3c46ea948c4772e08df1679ffa271d5e3fff68a4725953f8a8",
    ATTEMPT / "artifacts/final-aggregate/findings.json": "009499daca3c762d89fb28a136f7e363f72d9cdd5d5ea2d3ac02134294e8f984",
    ATTEMPT / "artifacts/final-aggregate/unresolved-leads.json": "503860ba73d871c821ba11e906745fc5cd1721ae0ffd585d2ca97d10ecb8b6bb",
    ATTEMPT / "artifacts/final-aggregate/manifest-scope.json": "13157d837ce52c6b93a059e80cee531b923956e07e5d16827031af0ef030f5cc",
    ATTEMPT / "artifacts/logs/freeze-final.json": "1ee0c2a842cd0af99058c43bebeb5a2022ff9335be294c731a6df15677a20a45",
    OBS: "b80fb0578dab2e3bf3666eb0a7760223deee0d897b9a33df374d34dbb4d4f903",
    AUDIT / "runs/COORDINATOR-DAYBREAK/attempt-01/ROUTE-EVIDENCE.json": "c32d301de24c2613d6adf549622043cb70df9df02b7845c5e34fb4039c5e8d89",
}
for path, digest in expected.items():
    assert path.is_file(), path
    assert sha(path) == digest, (path, sha(path), digest)

native_seal = json.loads((ATTEMPT / "FINAL-SEAL.json").read_text())
assert native_seal["status"] == "sealed-complete-six-stage-audit"
assert native_seal["target_sha"] == "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155"
assert native_seal["report_sha256"] == expected[ATTEMPT / "REPORT.md"]
assert native_seal["final_manifest_entries"] == 807
assert native_seal["final_manifest_sha256"] == expected[ATTEMPT / "artifacts/final-aggregate/FINAL-MANIFEST.sha256"]
assert native_seal["final_synthesis"]["exit_code"] == 0
assert native_seal["final_synthesis"]["provider_rejection"] is False
assert native_seal["route"] == {
    "model": "gpt-daybreak-blue-latest",
    "cyber_access_program": "daybreak_blue",
    "model_reasoning_effort": "ultra",
    "multi_agent": False,
    "fallback": False,
    "provider_returned_identity": "unknown",
}
assert native_seal["freeze_verification"]["ok"] is True
assert native_seal["freeze_verification"]["errors"] == []
assert native_seal["integrity"]["production_or_dependency_changes"] is False
assert native_seal["integrity"]["production_remediation"] is False
assert native_seal["integrity"]["live_transactions"] is False

ledger = json.loads((ATTEMPT / "stage-ledger.json").read_text())
assert len(ledger["stages"]) == 6
assert [stage["id"] for stage in ledger["stages"]] == ["S1", "S2", "S3", "S4", "S5", "S6"]
assert all(stage["status"] == "sealed" for stage in ledger["stages"])
assert ledger["stages"][4]["results"]["requirements"] == 56
assert ledger["stages"][4]["results"]["refutations"] == 22
assert ledger["stages"][4]["results"]["dropped_candidates"] == 4

findings = json.loads((ATTEMPT / "artifacts/final-aggregate/findings.json").read_text())
assert findings["counts"] == {
    "critical": 1,
    "high": 0,
    "medium": 1,
    "low": 3,
    "informational_or_conditional": 2,
    "total": 7,
}
assert [item["id"] for item in findings["findings"]] == [
    "DAYBREAK-F-01", "DAYBREAK-F-02", "DAYBREAK-F-03", "DAYBREAK-F-04",
    "DAYBREAK-F-05", "DAYBREAK-DIV-01", "DAYBREAK-OOS-01",
]
leads = json.loads((ATTEMPT / "artifacts/final-aggregate/unresolved-leads.json").read_text())
assert leads["lead_count"] == 8

observation = json.loads(OBS.read_text())
assert observation["first_observed_seal_sha256"] == "5fa3ac85bf972415c2d711b35f72bda9d8e6193911abcd85e4179c16333eb07e"
assert observation["verified_adopted_seal_sha256"] == expected[ATTEMPT / "SEAL.json"]
assert observation["first_pass_sha256"] == expected[ATTEMPT / "FIRST-PASS.md"]
assert observation["first_pass_hash_unchanged_across_observed_receipts"] is True
assert observation["prior_seal_bytes_retained"] is False

manifest_lines = (ATTEMPT / "artifacts/final-aggregate/FINAL-MANIFEST.sha256").read_text().splitlines()
assert len(manifest_lines) == 807
seen = set()
for line in manifest_lines:
    match = re.fullmatch(r"([0-9a-f]{64})  (/.+)", line)
    assert match, line
    digest, raw_path = match.groups()
    path = Path(raw_path)
    assert path not in seen, path
    seen.add(path)
    assert path.is_file(), path
    assert sha(path) == digest, (path, sha(path), digest)

adjudication = PKG / "ADJUDICATION.md"
assert adjudication.is_file()

receipt = {
    "schema": "raffle-fun.daybreak-tob-semantic-adjudication-completion.v1",
    "recordedUtc": now(),
    "cell": "DAYBREAK-TOB",
    "selectedAttempt": "runs/DAYBREAK-TOB/attempt-03",
    "targetCommit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
    "method": "six-declared-trail-of-bits-skills-with-sealed-source-first-and-post-seal-secure-workflow",
    "qualification": "PASS_WITH_APPEND_ONLY_SEMANTIC_RECONCILIATION",
    "adjudication": {
        "path": "runs/COORDINATOR-DAYBREAK/attempt-01/daybreak-tob-adjudication/ADJUDICATION.md",
        "sha256": sha(adjudication),
    },
    "route": {
        "requestedModel": "gpt-daybreak-blue-latest",
        "acceptedLocalSelection": "gpt-daybreak-blue-latest",
        "cyberAccessProgram": "daybreak_blue",
        "requestedEffort": "ultra",
        "providerReturnedIdentity": None,
        "fallbackUsed": False,
        "multiAgent": False,
        "actualOpenAISafetyRejection": False,
    },
    "nativeRunSucceeded": True,
    "nativeTerminalStatus": "sealed-complete-six-stage-audit",
    "nativeProcessExitCode": 0,
    "providerRejection": False,
    "methodOutputsComplete": True,
    "declaredSkillsComplete": 6,
    "fullTrailOfBitsCatalogClaimed": False,
    "inputIntegrity": {
        "finalManifestEntries": 807,
        "finalManifestSha256": expected[ATTEMPT / "artifacts/final-aggregate/FINAL-MANIFEST.sha256"],
        "manifestEntriesVerified": 807,
        "productionFiles": 5,
        "reachableDependencies": 31,
        "freezeVerifiedInputs": 435,
        "freezeErrors": [],
        "productionOrDependencyChanges": False,
    },
    "sourceFirstBoundary": {
        "reportSha256": expected[ATTEMPT / "FIRST-PASS.md"],
        "currentSealSha256": expected[ATTEMPT / "SEAL.json"],
        "firstObservedSealSha256": observation["first_observed_seal_sha256"],
        "olderSealBytesRetained": False,
        "firstPassUnchanged": True,
        "scannerOrTestExposureBeforeSeal": False,
        "provenanceGapPreserved": True,
    },
    "stages": [
        {
            "id": stage["id"],
            "skill": stage["skill"],
            "status": stage["status"],
            "primaryOutputSha256": stage["primary_output_sha256"],
            "sealSha256": stage["seal_sha256"],
        }
        for stage in ledger["stages"]
    ],
    "sourceCompliance": {
        "requirements": 56,
        "analyses": 56,
        "refutations": 22,
        "droppedCandidates": 4,
    },
    "laneFindings": findings["counts"],
    "unresolvedLeads": 8,
    "mappings": {
        "RF-001": ["DAYBREAK-F-01", "UL-03"],
        "RF-002": ["DAYBREAK-F-03", "UL-04"],
        "CONFIG-001": ["DAYBREAK-F-03", "UL-04"],
        "OBS-003": ["DAYBREAK-F-05", "UL-02"],
        "OBS-004": ["DAYBREAK-F-02", "DAYBREAK-F-03", "UL-07"],
        "OBS-006": ["DAYBREAK-F-04"],
        "DOC-001": ["DAYBREAK-DIV-01"],
        "CLOSED-003": ["UL-06"],
        "EVIDENCE-001": ["UL-01", "UL-02", "UL-05", "UL-08", "DAYBREAK-OOS-01"],
    },
    "semanticDecision": {
        "independentSemanticReviewPerformed": True,
        "laneCriticalRatingPreservedAsDissent": True,
        "unconditionalCriticalAdopted": False,
        "controllingRootSeverity": "High under explicit untrusted-prize DESIGN scope; trust limitation under narrower honest-prize interface scope",
        "newProductionRoots": 0,
        "nativeFixesApprovedForProduction": False,
        "globalAuditCompletionIssued": False,
    },
    "limitations": [
        "Completion covers the six skills declared for this audit, not the full Trail of Bits catalog.",
        "The lane Critical rating is preserved as dissent; the controlling reconciliation does not adopt an unconditional Critical.",
        "The watcher-observed older source seal bytes were not retained; no cause is inferred for the seal-version change.",
        "Deployment identities for the live wrapper, quote token, prize, frontend and chain environment remain unresolved.",
        "No native mitigation is approved as production-ready and no owner risk acceptance is inferred.",
    ],
    "newProviderWorkRequired": False,
    "globalAuditCompletionIssued": False,
}
write(receipt_path, receipt)

paths = set(expected)
paths.update([adjudication, receipt_path, Path(__file__)])
artifacts = []
for path in sorted(paths, key=lambda value: str(value)):
    artifacts.append({
        "path": str(path),
        "auditRelativePath": str(path.relative_to(AUDIT)) if path.is_relative_to(AUDIT) else None,
        "bytes": path.stat().st_size,
        "sha256": sha(path),
    })

manifest = {
    "schema": "raffle-fun.daybreak-tob-semantic-adjudication-integrity-manifest.v1",
    "recordedUtc": now(),
    "targetCommit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
    "cell": "DAYBREAK-TOB",
    "qualification": "PASS_WITH_APPEND_ONLY_SEMANTIC_RECONCILIATION",
    "artifactCount": len(artifacts),
    "artifacts": artifacts,
    "checks": {
        "criticalExpectedHashesMatched": len(expected),
        "nativeFinalManifestEntries": 807,
        "nativeFinalManifestEntriesVerified": 807,
        "sixDeclaredStagesSealed": True,
        "nativeExitZero": True,
        "providerRejection": False,
        "olderSealBytesRetained": False,
        "oldSealProvenanceGapPreserved": True,
        "newProductionRoots": 0,
        "globalAuditCompletionIssued": False,
    },
}
write(manifest_path, manifest)

seal = {
    "schema": "raffle-fun.daybreak-tob-semantic-adjudication-seal.v1",
    "sealedUtc": now(),
    "cell": "DAYBREAK-TOB",
    "targetCommit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
    "status": "QUALIFIED_COMPLETE_SIX_DECLARED_STAGES",
    "nativeTerminalStatus": "sealed-complete-six-stage-audit",
    "nativeFinalSeal": {
        "path": str(ATTEMPT / "FINAL-SEAL.json"),
        "sha256": expected[ATTEMPT / "FINAL-SEAL.json"],
    },
    "adjudication": {"path": str(adjudication), "sha256": sha(adjudication)},
    "completionReceipt": {"path": str(receipt_path), "sha256": sha(receipt_path)},
    "integrityManifest": {"path": str(manifest_path), "sha256": sha(manifest_path)},
    "laneCriticalRatingPreservedAsDissent": True,
    "unconditionalCriticalAdopted": False,
    "oldSealProvenanceGapPreserved": True,
    "globalAuditCompletionIssued": False,
}
write(seal_path, seal)

print(json.dumps({
    "artifactCount": len(artifacts),
    "nativeManifestEntriesVerified": 807,
    "adjudicationSha256": sha(adjudication),
    "completionReceiptSha256": sha(receipt_path),
    "integrityManifestSha256": sha(manifest_path),
    "sealSha256": sha(seal_path),
}, indent=2))
