#!/usr/bin/env python3
"""Read-only evidence verification; writes no sealed campaign artifacts."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parent
issues = []
checked = {}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(path, expected, label):
    if not path.is_file():
        issues.append(f"Missing {label}: {path}")
    elif sha(path) != expected:
        issues.append(f"Hash mismatch {label}: {path}")

freeze = subprocess.run([sys.executable, str(root / "verify-freeze.py")], capture_output=True, text=True)
try:
    checked["freeze"] = json.loads(freeze.stdout)
except json.JSONDecodeError:
    issues.append("Freeze verifier did not return JSON")
if freeze.returncode:
    issues.append("Frozen inputs differ")

matrix = json.loads((root / "matrix.json").read_text())
ids = [row["id"] for row in matrix["runs"]]
if len(ids) != len(set(ids)):
    issues.append("Duplicate matrix IDs")
required = {f"{provider}-{method}" for provider in ["OPENAI", "CLAUDE", "GEMINI"] for method in ["SIMAO", "PASHOV", "OPENKRITT", "TOB", "GEBAL"]}
if not required.issubset(ids):
    issues.append("Required fifteen-cell matrix is missing entries")
expected = required | {f"DAYBREAK-{method}" for method in ["SIMAO", "PASHOV", "OPENKRITT", "TOB", "GEBAL"]} | {"SUP-A1", "SUP-A2", "SUP-S1"}
if not expected.issubset(ids):
    issues.append("Daybreak or supplementary matrix entries are missing")
unfinished = []
for row in matrix["runs"]:
    if row["id"] not in expected:
        continue
    # Only an actual OpenAI refusal satisfies the user's stop condition.
    # Other providers' failed original attempts require a completed, disclosed
    # continuation; setup failures and arbitrary time budgets are not terminal.
    allowed_refusal = row.get("provider") == "OPENAI" and row.get("execution_state") == "PROVIDER_REJECTED"
    continuation = row.get("continuation", {})
    completed_variant = continuation.get("state") == "COMPLETE" and bool(continuation.get("completion_receipt"))
    if row.get("workflow_status") != "COMPLETE" and not allowed_refusal and not completed_variant:
        unfinished.append(row["id"])
    if continuation.get("state") == "RUNNING":
        unfinished.append(row["id"] + " qualified continuation")
if "--require-terminal" in sys.argv and unfinished:
    issues.append("Eligible requested work is unfinished: " + ", ".join(unfinished))
checked["required_cells_present"] = len(required.intersection(ids))
checked["total_matrix_rows"] = len(ids)
checked["terminal_delivery_required"] = "--require-terminal" in sys.argv
checked["unfinished_eligible_cells"] = unfinished
checked["matrix_statuses"] = {row["id"]: {k: row.get(k) for k in ["workflow_status", "execution_state"]} for row in matrix["runs"]}

report_count = 0
for register in sorted((root / "reconciliation").rglob("findings-register*.json")):
    data = json.loads(register.read_text())
    for record in data.get("source_reports", []):
        if record.get("path") and record.get("sha256"):
            check(Path(record["path"]), record["sha256"], "registered source report")
            report_count += 1
        if record.get("seal") and record.get("seal_sha256"):
            check(Path(record["seal"]), record["seal_sha256"], "registered source seal")
checked["registered_report_hash_records"] = report_count

link_count = 0
for name in ["FINAL-AUDIT-REPORT.md", "INDEX.md", "PER-FILE-PROPERTY-COVERAGE.md"]:
    document = root / name
    for match in re.finditer(r"\]\((/[^)]+)\)", document.read_text()):
        target = re.sub(r":\d+$", "", match.group(1))
        link_count += 1
        if not Path(target).exists():
            issues.append(f"Missing local evidence link in {name}: {target}")
checked["local_evidence_links"] = link_count

halmos = root / "runs/TOOL-HALMOS-CONTINUATION"
seal = json.loads((halmos / "SEAL.json").read_text())
check(halmos / seal["report"], seal["report_sha256"], "Halmos summary")
check(halmos / seal["manifest"], seal["manifest_sha256"], "Halmos manifest")
manifest = json.loads((halmos / seal["manifest"]).read_text())
for name, digest in manifest.items():
    check(halmos / name, digest, "Halmos evidence")
checked["halmos_manifest_files"] = len(manifest)

artifacts = json.loads((root / "compiler-artifact-provenance.json").read_text())
for record in artifacts:
    retained = root / "compiler-artifacts" / record["profile"] / (record["contract"] + ".json")
    check(retained, record["artifact_sha256"], "retained compiler artifact")
checked["compiler_artifacts"] = len(artifacts)

preimages = root / "historical-preimages/tool-consolidation-2026-10-21T173849Z/PREIMAGE-MAPPING.json"
if preimages.exists():
    mapping = json.loads(preimages.read_text())
    check(root / mapping["originalSeal"], mapping["originalSealSha256"], "original tool seal")
    original_seal = json.loads((root / mapping["originalSeal"]).read_text())
    for row in mapping["rows"]:
        if row["sha256"] != original_seal["hashes"][row["originalPath"]]:
            issues.append("Preimage mapping differs from original seal: " + row["originalPath"])
        check(root / row["preimagePath"], row["sha256"], "historical tool preimage")
    checked["historical_tool_preimages"] = len(mapping["rows"])

fork = root / "runs/TOOL-PUBLIC-FORK/attempt-01"
if (fork / "ASSESSMENT.json").exists():
    assessment = json.loads((fork / "ASSESSMENT.json").read_text())
    check(fork / "stdout.txt", assessment["stdout_sha256"], "pinned fork output")
    if (assessment["passed"], assessment["failed"], assessment["skipped"]) != (2, 0, 0):
        issues.append("Pinned fork tests did not both pass")
    checked["pinned_dependency_fork_tests"] = 2

for campaign in ["TOOL-ECHIDNA-EXTENDED-1", "TOOL-ECHIDNA-EXTENDED-2"]:
    directory = root / "runs" / campaign / "attempt-01"
    assessment = json.loads((directory / "ASSESSMENT.json").read_text())
    check(directory / "stdout.txt", assessment["evidence_sha256"], campaign)
    if assessment["status"] != "COMPLETE" or assessment["actual_calls"] < 100000:
        issues.append(f"Extended campaign unfinished: {campaign}")

result = {
    "schema": "raffle-audit-delivery-verification/v1",
    "verified_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "ok": not issues,
    "issues": issues,
    "checks": checked,
    "interpretation": "Evidence byte integrity and bookkeeping only; does not certify workflow completeness or security. Running and rejected cells remain separate statuses.",
}
print(json.dumps(result, indent=2))
raise SystemExit(1 if issues else 0)
