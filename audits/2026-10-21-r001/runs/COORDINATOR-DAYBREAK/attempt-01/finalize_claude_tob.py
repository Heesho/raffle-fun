#!/usr/bin/env python3
"""Verify, manifest, and append-only qualify the six-stage Claude ToB lane."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path


AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
LANE = AUDIT / "provider-lanes/claude/runs/CLAUDE-TOB"
S6 = LANE / "S6/attempt-02"
RUNTIME_GENERATED = Path("/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/cells/CLAUDE-TOB/S6/attempt-02/work/_generated")
TARGET = "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155"
TREE = "d148a1ef56a42193fac99c9a121e830f77d31aa53487d3465b1c21dceb9fb535"
TARGET_TAR = "67d554dfd521c83a3383fe1b58b934647ff86ead6c3f3b9290af45e44d6aae1d"
CONTEXT_TAR = "fc53106bb75495a4caa732f3be0a7e5bca3d619c5d01a77b0909227d30ede96d"

STAGES = [
    ("S1", LANE / "S1/attempt-02", "preserved/TOB-S1-audit-context-building.md", "f7f720894eae441fe1c5bcc330cfd6088f2d978ea7063a17e60a480881c56354"),
    ("S2", LANE / "S2/attempt-01", "preserved/TOB-S2-entry-point-analyzer.md", "b175795b0ab76d8171db2caa015174e0c6608e38babd64281050e054dd84062e"),
    ("S3", LANE / "S3/attempt-01", "preserved/TOB-S3-token-integration-analyzer.md", "f3fdf283c4007c97fb08f57b660449951c465cbfda4690afef37973900bdc0ca"),
    ("S4", LANE / "S4/attempt-01", "preserved/TOB-S4-guidelines-advisor.md", "a22164ad27f77c8e3bdea84d38e5d751a5ecc844d6dc245376dce927818f2557"),
    ("S5", LANE / "S5/attempt-03", "preserved/TOB-S5-spec-to-code-compliance.md", "a84bd609d50ccae5d05fe96e37e79c3ce7794eb857ea28b527c5f0b90f6dcca9"),
    ("S6", S6, "preserved/TOB-S6-secure-workflow-guide.md", "cf0113222c7a972e44cae4ec85d13b66124b7a597148110c7c40950cff8f5291"),
]
OUTPUT_NAMES = {"artifact-manifest.json", "completion-receipt.json", "SEAL.json", "CONTINUATION-SEAL.json"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text())


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def rel(path: Path) -> str:
    return str(path.relative_to(AUDIT))


def check(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)


for path in [S6 / "artifact-manifest.json", S6 / "completion-receipt.json", S6 / "SEAL.json", LANE / "completion-receipt.json", LANE / "CONTINUATION-SEAL.json"]:
    check(not path.exists(), f"refusing to overwrite {path}")

capture_list = [line.strip() for line in (S6 / "generated-capture-files.txt").read_text().splitlines() if line.strip()]
check(len(capture_list) == 37 and len(set(capture_list)) == 37, "generated capture list is not 37 unique files")
capture = S6 / "generated-capture"
capture_lines = []
for name in capture_list:
    source, saved = RUNTIME_GENERATED / name, capture / name
    check(source.is_file() and saved.is_file(), f"generated capture file missing: {name}")
    digest = sha(source)
    check(sha(saved) == digest, f"generated capture mismatch: {name}")
    capture_lines.append(f"{digest}  {name}")
capture_tree = hashlib.sha256(("\n".join(sorted(capture_lines)) + "\n").encode()).hexdigest()
check(capture_tree == "a36d949a9dfb61b22283df43e4897b20dfb574471491e7fc31fbed2b33858a5b", "generated capture tree digest mismatch")
check(sum((capture / name).stat().st_size for name in capture_list) == 335952, "generated capture byte count mismatch")

stage_receipts = []
for stage, root, report_name, expected_report in STAGES:
    runner = read_json(root / "runner-selection.json")
    check(runner.get("requested_model") == runner.get("init_model") == "claude-opus-5-5", f"{stage} model mismatch")
    check(runner.get("requested_effort") == "max", f"{stage} effort mismatch")
    check(runner.get("result_subtype") == "success" and runner.get("exit_code") == 0 and not runner.get("timed_out"), f"{stage} was not terminal success")
    freeze = read_json(root / "freeze-after.json")
    check(freeze.get("ok") is True and freeze.get("verify_freeze_exit") == 0, f"{stage} terminal freeze failed")
    check(freeze.get("target_tar_sha256") == freeze.get("target_tar_expected") == TARGET_TAR, f"{stage} target tar mismatch")
    check(freeze.get("clean_context_tar_sha256") == CONTEXT_TAR and freeze.get("clean_context_tree_sha256") == TREE, f"{stage} clean context mismatch")
    report = root / report_name
    check(sha(report) == expected_report, f"{stage} report hash mismatch")
    stage_receipts.append({
        "stage": stage,
        "attempt": rel(root),
        "report": rel(report),
        "report_sha256": expected_report,
        "runner_selection": rel(root / "runner-selection.json"),
        "runner_selection_sha256": sha(root / "runner-selection.json"),
        "freeze_after": rel(root / "freeze-after.json"),
        "freeze_after_sha256": sha(root / "freeze-after.json"),
        "session_id": runner.get("session_id"),
        "duration_s": runner.get("duration_s"),
    })

s6_report = S6 / "preserved/TOB-S6-secure-workflow-guide.md"
s6_text = s6_report.read_text()
for marker in ["400,073 calls", "400,047 calls", "3,116,102 calls", "7/9 PASS", "2/9 TIMEOUT", "Manticore was not run", "S6-F1", "S6-F2", "S6-F3", "S6-F4", "S6-F5", "S6-F6", "S6-F7", "S6-F8"]:
    check(marker in s6_text, f"S6 report missing marker: {marker}")
halmos = read_json(S6 / "preserved/evidence/04-properties/60-halmos-symbolic.json")
halmos_results = [
    item
    for contract_results in halmos.get("test_results", {}).values()
    for item in contract_results
]
check(halmos.get("exitcode") == 1, "original Halmos process exit was not preserved as 1")
check(len(halmos_results) == 9, "expected nine original Halmos checks")
check(sum(item.get("exitcode") == 0 for item in halmos_results) == 7, "expected seven passing Halmos checks")
check(sum(item.get("exitcode") == 2 for item in halmos_results) == 2, "expected two timeout/unknown Halmos checks")
check(all(item.get("num_models") == 0 for item in halmos_results), "unexpected Halmos counterexample model")

semantic = LANE / "SEMANTIC-ADJUDICATION.md"
check(semantic.exists() and "No new production root" in semantic.read_text(), "semantic adjudication missing")
old_first_pass = AUDIT / "provider-lanes/claude/FIRST-PASS.md"
old_sidecar = AUDIT / "provider-lanes/claude/FIRST-PASS.md.sha256"
check(sha(old_first_pass) == "16cb0e68e79fba00c1ba91878e682184db08a175fbcf9164dd7b51cc469aefb2", "immutable Claude lane first pass changed")
check("16cb0e68e79fba00c1ba91878e682184db08a175fbcf9164dd7b51cc469aefb2" in old_sidecar.read_text(), "old first-pass sidecar mismatch")

evidence_files = []
for _, root, _, _ in STAGES:
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.name in OUTPUT_NAMES:
            continue
        evidence_files.append({"path": rel(path), "sha256": sha(path), "bytes": path.stat().st_size})
check(len({item["path"] for item in evidence_files}) == len(evidence_files), "duplicate aggregate evidence paths")

now = dt.datetime.now(dt.timezone.utc).isoformat()
s6_files = [item for item in evidence_files if item["path"].startswith(rel(S6) + "/")]
s6_manifest = {
    "schema": "audit-artifact-manifest/v1",
    "created_at": now,
    "cell": "CLAUDE-TOB/S6",
    "attempt": "attempt-02",
    "target": TARGET,
    "files": s6_files,
    "file_count": len(s6_files),
    "generated_capture": {"files": 37, "bytes": 335952, "tree_digest": capture_tree, "runtime_byte_exact": True},
}
s6_manifest_path = S6 / "artifact-manifest.json"
write_json(s6_manifest_path, s6_manifest)

s6_receipt = {
    "schema": "audit-qualified-stage-completion/v1",
    "completed_at": now,
    "cell": "CLAUDE-TOB",
    "stage": "S6 secure-workflow-guide",
    "attempt": "attempt-02",
    "target": TARGET,
    "workflow_status": "COMPLETE_WITH_EXPLICIT_UNRESOLVED_PROOF_LIMITS",
    "requested_model": "claude-opus-5-5",
    "requested_effort": "max",
    "provider_returned_model": "claude-opus-5-5",
    "provider_internal_revision": None,
    "report": {"path": rel(s6_report), "sha256": sha(s6_report)},
    "artifact_manifest": {"path": rel(s6_manifest_path), "sha256": sha(s6_manifest_path), "bound_files": len(s6_files)},
    "generated_capture": {"path": rel(capture), "files": 37, "bytes": 335952, "tree_digest": capture_tree},
    "campaigns": {
        "foundry": {"tests": 20, "passed": 20},
        "echidna_property": {"calls": 400073, "checks": 9, "passed": 9},
        "echidna_assertion": {"calls": 400047, "checks": 38, "passed": 38},
        "medusa": {"calls": 3116102, "checks": 46, "passed": 46},
        "custom_slither": {"checks": 12, "passed": 12},
        "halmos_original": {"process_exit": 1, "checks": 9, "passed": 7, "timeout_unknown": 2, "status": "PARTIAL_UNRESOLVED"},
        "halmos_followups": {"z3_and_uint32_variants": "TIMEOUT", "count_as_original_passes": False},
        "manticore": {"executed": False, "reason": "unavailable offline", "substitute": "Halmos"},
    },
    "no_new_production_root": True,
    "semantic_adjudication": {"path": rel(semantic), "sha256": sha(semantic)},
    "source_integrity": True,
}
s6_receipt_path = S6 / "completion-receipt.json"
write_json(s6_receipt_path, s6_receipt)
s6_seal = {
    "schema": "audit-artifact-seal/v1",
    "sealed_at": now,
    "cell": "CLAUDE-TOB/S6",
    "attempt": "attempt-02",
    "target": TARGET,
    "artifacts": [
        {"path": rel(s6_manifest_path), "sha256": sha(s6_manifest_path)},
        {"path": rel(s6_receipt_path), "sha256": sha(s6_receipt_path)},
        {"path": rel(s6_report), "sha256": sha(s6_report)},
        {"path": rel(semantic), "sha256": sha(semantic)},
    ],
    "original_halmos_exit_1_preserved": True,
    "halmos_unknowns_not_relabelled_pass": True,
    "workflow_complete": True,
}
s6_seal_path = S6 / "SEAL.json"
write_json(s6_seal_path, s6_seal)

aggregate_manifest = {
    "schema": "audit-artifact-manifest/v1",
    "created_at": now,
    "cell": "CLAUDE-TOB",
    "target": TARGET,
    "selected_stage_attempts": stage_receipts,
    "files": evidence_files,
    "file_count": len(evidence_files),
    "immutable_original_lane_first_pass": {"path": rel(old_first_pass), "sha256": sha(old_first_pass)},
    "s6_seal": {"path": rel(s6_seal_path), "sha256": sha(s6_seal_path)},
}
aggregate_manifest_path = LANE / "artifact-manifest.json"
check(not aggregate_manifest_path.exists(), "refusing to overwrite aggregate manifest")
write_json(aggregate_manifest_path, aggregate_manifest)

aggregate_receipt = {
    "schema": "audit-qualified-method-completion/v1",
    "completed_at": now,
    "cell": "CLAUDE-TOB",
    "target": TARGET,
    "workflow_status": "COMPLETE",
    "qualification": "six declared Trail of Bits skills; append-only S6 attempt-02 continuation over immutable lane first pass",
    "requested_model": "claude-opus-5-5",
    "requested_effort": "max",
    "provider_returned_model": "claude-opus-5-5",
    "provider_internal_revision": None,
    "stages": stage_receipts,
    "coverage_limits": {"declared_skills": 6, "full_catalog": False, "s1_selected_functions": 12, "s1_not_analyzed_functions": 9, "s5_checked_requirements": 10, "s5_extracted_requirements": 248, "s5_deferred_requirements": 238},
    "s6_completion_receipt": {"path": rel(s6_receipt_path), "sha256": sha(s6_receipt_path)},
    "s6_seal": {"path": rel(s6_seal_path), "sha256": sha(s6_seal_path)},
    "artifact_manifest": {"path": rel(aggregate_manifest_path), "sha256": sha(aggregate_manifest_path), "bound_files": len(evidence_files)},
    "immutable_original_lane_first_pass": {"path": rel(old_first_pass), "sha256": sha(old_first_pass), "s6_attempt_01_status_preserved": "INCOMPLETE/TIMEOUT"},
    "semantic_adjudication": {"path": rel(semantic), "sha256": sha(semantic), "new_production_roots": 0},
    "source_integrity": True,
    "limitations": [
        "Six declared skills only; not the full Trail of Bits catalog.",
        "S1 analyzed 12 selected functions and left nine without equal-depth analysis.",
        "S5 checked the exact native default 10/248 requirements; 238 remain deferred/unknown.",
        "Original Halmos exit 1 and two TIMEOUT/unknown checks remain unresolved; follow-ups are separately labeled.",
        "Manticore was unavailable and not run; Halmos substitution is disclosed.",
        "Mocks and isolated copies do not establish live deployment, USDC, prize-token, or VRF behavior.",
    ],
    "no_new_production_root": True,
}
aggregate_receipt_path = LANE / "completion-receipt.json"
write_json(aggregate_receipt_path, aggregate_receipt)
continuation_seal = {
    "schema": "audit-method-continuation-seal/v1",
    "sealed_at": now,
    "cell": "CLAUDE-TOB",
    "target": TARGET,
    "immutable_prior_artifact": {"path": rel(old_first_pass), "sha256": sha(old_first_pass), "detached_sidecar": rel(old_sidecar), "detached_sidecar_sha256": sha(old_sidecar)},
    "artifacts": [
        {"path": rel(aggregate_manifest_path), "sha256": sha(aggregate_manifest_path)},
        {"path": rel(aggregate_receipt_path), "sha256": sha(aggregate_receipt_path)},
        {"path": rel(s6_seal_path), "sha256": sha(s6_seal_path)},
        {"path": rel(semantic), "sha256": sha(semantic)},
    ] + [{"path": stage["report"], "sha256": stage["report_sha256"]} for stage in stage_receipts],
    "workflow_complete": True,
    "prior_s6_timeout_preserved": True,
    "proof_unknowns_preserved": True,
    "source_integrity": True,
}
continuation_seal_path = LANE / "CONTINUATION-SEAL.json"
write_json(continuation_seal_path, continuation_seal)

print(json.dumps({
    "status": "COMPLETE_SIX_DECLARED_STAGES",
    "receipt": rel(aggregate_receipt_path),
    "receipt_sha256": sha(aggregate_receipt_path),
    "continuation_seal": rel(continuation_seal_path),
    "continuation_seal_sha256": sha(continuation_seal_path),
    "s6_seal_sha256": sha(s6_seal_path),
    "bound_files": len(evidence_files),
    "generated_capture_files": 37,
}, indent=2))
