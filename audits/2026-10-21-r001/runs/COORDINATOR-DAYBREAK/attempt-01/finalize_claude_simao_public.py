#!/usr/bin/env python3
"""Verify and seal the completed, disclosed Claude Simao public-evidence variant."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path


AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
ATTEMPT = AUDIT / "provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-02"
RUNTIME = Path("/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/cells/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-02/work")
ORIGINAL_REFUSAL = AUDIT / "provider-lanes/claude/runs/CLAUDE-SIMAO/attempt-01"
PUBLIC_A01 = AUDIT / "provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-01/WORKFLOW-ASSESSMENT.json"
TARGET = "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155"
OUTPUTS = {"artifact-manifest.json", "completion-receipt.json", "SEAL.json"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text())


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def rel(path: Path) -> str:
    return str(path.relative_to(AUDIT))


def check(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


for name in OUTPUTS:
    check(not (ATTEMPT / name).exists(), f"refusing to overwrite {name}")

capture = ATTEMPT / "native-capture"
runtime_files = {}
for item in ("evidence", "METHOD-STAGES.json", "FIRST-PASS.md.sha256"):
    root = RUNTIME / item
    files = [root] if root.is_file() else sorted(p for p in root.rglob("*") if p.is_file())
    for path in files:
        runtime_files[str(path.relative_to(RUNTIME))] = sha(path)
capture_files = {
    str(path.relative_to(capture)): sha(path)
    for path in sorted(capture.rglob("*"))
    if path.is_file()
}
check(len(runtime_files) == 67, f"expected 67 runtime capture files, got {len(runtime_files)}")
check(capture_files == runtime_files, "native capture differs from terminal runtime snapshot")

first_pass = ATTEMPT / "preserved/FIRST-PASS.md"
sidecar = capture / "FIRST-PASS.md.sha256"
expected_first_pass = sidecar.read_text().strip().split()[0]
check(sha(first_pass) == expected_first_pass, "FIRST-PASS sidecar mismatch")
check(expected_first_pass == "21a16f6a3dd82428a3ee25864428cc166e351953d9aa96c543f1cf0b97a805de", "unexpected FIRST-PASS hash")

bindings = read_json(ATTEMPT / "source-input-bindings.json")
check(bindings.get("protectedSourceCount") == 43, "protected source count is not 43")
check(bindings.get("dependencyCount") == 31, "dependency count is not 31")
check(bindings.get("allMatchCleanFreeze") is True, "source binding did not pass")
check(len(bindings.get("files", {})) == 43, "source binding file set is not 43")
for name, values in bindings["files"].items():
    check(values.get("expected") == values.get("initialSameCellCopy") == values.get("current"), f"source mismatch: {name}")

freeze = read_json(ATTEMPT / "freeze-after.json")
check(freeze.get("ok") is True and freeze.get("verify_freeze_exit") == 0, "terminal freeze failed")
runner = read_json(ATTEMPT / "runner-selection.json")
check(runner.get("requested_model") == runner.get("init_model") == "claude-opus-5-5", "Claude model mismatch")
check(runner.get("requested_effort") == "max", "Claude effort mismatch")
check(runner.get("result_subtype") == "success" and runner.get("exit_code") == 0 and not runner.get("timed_out"), "runner was not terminal success")
stats = runner.get("subagent_stats", {})
check(stats.get("spawned") == stats.get("completed") == 12 and stats.get("failed") == 0, "12/12 foreground lenses did not complete")

stages = read_json(capture / "METHOD-STAGES.json")
check(stages.get("cell") == "CLAUDE-SIMAO-PUBLIC-EVIDENCE", "wrong method cell")
check("NOT an original, unmodified" in stages.get("claim", ""), "variant disclosure missing")
report = capture / "evidence/native-report.md"
report_text = report.read_text()
check("Method variant disclosure" in report_text and "not an original, unmodified" in report_text, "native report variant disclosure missing")
check(all(token in report_text for token in ("M-1", "M-2", "M-3", "M-4", "M-5", "L-1", "L-2", "L-3")), "native report finding set incomplete")

refusal_text = (ORIGINAL_REFUSAL / "final-result.md").read_text() + (ORIGINAL_REFUSAL / "BLOCKED.md").read_text()
check("reasoning_extraction" in refusal_text and "req_011CgF39yAWEzzYTZnJK2jVW" in refusal_text, "original provider refusal evidence missing")
public_a01 = read_json(PUBLIC_A01)
check(public_a01.get("status") == "INCOMPLETE_PARENT_EXIT_DURING_WAIT" and public_a01.get("systemKilled") == 12, "public attempt-01 failure changed")

semantic = ATTEMPT / "SEMANTIC-ADJUDICATION.md"
check(semantic.exists() and "No new production root" in semantic.read_text(), "semantic adjudication missing")

evidence_files = []
for path in sorted(ATTEMPT.rglob("*")):
    if not path.is_file() or path.name in OUTPUTS:
        continue
    evidence_files.append({"path": rel(path), "sha256": sha(path), "bytes": path.stat().st_size})
check(len(evidence_files) >= 100, "attempt evidence inventory unexpectedly small")

now = dt.datetime.now(dt.timezone.utc).isoformat()
manifest = {
    "schema": "audit-artifact-manifest/v1",
    "created_at": now,
    "cell": "CLAUDE-SIMAO-PUBLIC-EVIDENCE",
    "attempt": "attempt-02",
    "target": TARGET,
    "files": evidence_files,
    "file_count": len(evidence_files),
    "native_capture_file_count": len(capture_files),
    "runtime_capture_byte_exact": True,
}
manifest_path = ATTEMPT / "artifact-manifest.json"
write_json(manifest_path, manifest)

receipt = {
    "schema": "audit-qualified-method-completion/v1",
    "completed_at": now,
    "cell": "CLAUDE-SIMAO-PUBLIC-EVIDENCE",
    "target": TARGET,
    "workflow_status": "COMPLETE",
    "qualification": "separately disclosed public-evidence variant; not the original unmodified 0xSimao method",
    "requested_model": "claude-opus-5-5",
    "requested_effort": "max",
    "provider_returned_model": "claude-opus-5-5",
    "provider_internal_revision": None,
    "native_runner_status": "success",
    "native_lenses": {"requested": 12, "completed": 12, "failed": 0, "mode": "foreground"},
    "native_turn6": "completed with dedup, function-isolation, mechanism/mitigation preservation, completeness and severity gates",
    "source_binding": {"protected_inputs": 43, "production_files": 5, "reachable_solidity_dependencies": 31, "all_match_frozen_target": True},
    "first_pass": {"path": rel(first_pass), "sha256": sha(first_pass)},
    "native_report": {"path": rel(report), "sha256": sha(report)},
    "gate_ledger": {"path": rel(capture / "evidence/turn6/gate-ledger.md"), "sha256": sha(capture / "evidence/turn6/gate-ledger.md")},
    "dedup_ledger": {"path": rel(capture / "evidence/turn6/dedup-ledger.md"), "sha256": sha(capture / "evidence/turn6/dedup-ledger.md")},
    "method_stages": {"path": rel(capture / "METHOD-STAGES.json"), "sha256": sha(capture / "METHOD-STAGES.json")},
    "semantic_adjudication": {"path": rel(semantic), "sha256": sha(semantic), "new_production_roots": 0},
    "artifact_manifest": {"path": rel(manifest_path), "sha256": sha(manifest_path), "bound_files": len(evidence_files)},
    "immutable_failures_preserved": [
        {"cell": "CLAUDE-SIMAO", "status": "PROVIDER_REJECTED", "reason": "Anthropic reasoning_extraction safeguard", "request_id": "req_011CgF39yAWEzzYTZnJK2jVW", "evidence": rel(ORIGINAL_REFUSAL / "events.jsonl"), "evidence_sha256": sha(ORIGINAL_REFUSAL / "events.jsonl")},
        {"cell": "CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-01", "status": "INCOMPLETE_PARENT_EXIT_DURING_WAIT", "system_killed_children": 12, "evidence": rel(PUBLIC_A01), "evidence_sha256": sha(PUBLIC_A01)},
    ],
    "limitations": [
        "Modified method variant; must never be relabeled as the original unmodified Simao method.",
        "No hidden/private reasoning was requested or inferred.",
        "Lens independence was enforced by isolated inputs/instructions and foreground completion; private reasoning was not inspected.",
        "The native report's severities are retained as attributions; final reconciled dispositions are not model votes.",
        "Source analysis does not replace deterministic proofs, deployment binding, or genuine VRF execution.",
    ],
    "qualifies_modified_method_variant": True,
    "qualifies_original_unmodified_method": False,
    "no_new_production_root": True,
}
receipt_path = ATTEMPT / "completion-receipt.json"
write_json(receipt_path, receipt)

seal = {
    "schema": "audit-artifact-seal/v1",
    "sealed_at": now,
    "cell": "CLAUDE-SIMAO-PUBLIC-EVIDENCE",
    "attempt": "attempt-02",
    "target": TARGET,
    "artifacts": [
        {"path": rel(manifest_path), "sha256": sha(manifest_path)},
        {"path": rel(receipt_path), "sha256": sha(receipt_path)},
        {"path": rel(first_pass), "sha256": sha(first_pass)},
        {"path": rel(report), "sha256": sha(report)},
        {"path": rel(semantic), "sha256": sha(semantic)},
    ],
    "bound_evidence_files": len(evidence_files),
    "native_capture_files": 67,
    "source_integrity": True,
    "workflow_complete": True,
    "modified_method_disclosed": True,
    "original_provider_refusal_preserved": True,
}
seal_path = ATTEMPT / "SEAL.json"
write_json(seal_path, seal)

print(json.dumps({
    "status": "COMPLETE_DISCLOSED_MODIFIED_METHOD_VARIANT",
    "receipt": rel(receipt_path),
    "receipt_sha256": sha(receipt_path),
    "seal": rel(seal_path),
    "seal_sha256": sha(seal_path),
    "bound_evidence_files": len(evidence_files),
    "native_capture_files": len(capture_files),
}, indent=2))
