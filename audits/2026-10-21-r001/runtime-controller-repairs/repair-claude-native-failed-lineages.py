#!/usr/bin/env python3
"""One-shot supported resume for unresolved Claude OpenKritt logical failures.

Run only after scan 1 naturally reaches failed/paused/stopped with zero active
jobs. This does not stop or restart the engine, mutate the database, create a
new scan, replace the model, or retry a provider safety rejection. Historical
failed rows alone are insufficient: their logical keys must still be unresolved.
"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.request

AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
ATTEMPT = AUDIT / "provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01"
OUT = ATTEMPT / "native-supported-resume-02"
HOST = "unix:///Users/hishamel-husseini/.lima/raffle-claude-openkritt/sock/docker.sock"
URL = "http://127.0.0.1:3002/api/scans/1"


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def sql(query: str) -> str:
    command = [
        "docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
        'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "$1"',
        "audit-readonly-sql", query,
    ]
    return subprocess.check_output(command, text=True)


assert not OUT.exists(), f"refusing to overwrite {OUT}"


def observe() -> tuple[bytes, dict]:
    with urllib.request.urlopen(URL, timeout=20) as response:
        raw = response.read()
    value = json.loads(raw)
    if "scan" in value:
        value = value["scan"]
    summary_value = value.get("statusSummary", {})
    assert str(value["id"]) == "1"
    assert value["repoFull"] == "raffle-fun-r001-clean"
    assert value["status"] in {"failed", "paused", "stopped"}, value["status"]
    assert summary_value.get("activeJobCount") == 0, summary_value
    assert summary_value.get("runningAttempts") == 0, summary_value
    assert summary_value.get("canResume") is True, summary_value
    assert value["model"] == "claude-opus-5-5"
    assert value["modelProvider"] == "claude"
    assert value["thinkingEffort"] == "max"
    assert value["harness"] == "claude-code"
    return raw, value


raw_api, scan = observe()
time.sleep(5)
raw_api_2, scan_2 = observe()
summary = scan.get("statusSummary", {})
summary_2 = scan_2.get("statusSummary", {})
assert scan["status"] == scan_2["status"]
assert summary.get("activeJobCount") == summary_2.get("activeJobCount") == 0
assert summary.get("completedStepLineages") == summary_2.get("completedStepLineages")
assert summary.get("expectedStepLineages") == summary_2.get("expectedStepLineages")

assert sql("SELECT count(*)::text FROM public.scans;").strip() == "1"
assert sql("SELECT to_regclass('workflows.scans')::text;").strip() == ""
failed = [
    json.loads(line)
    for line in sql(
        "SELECT row_to_json(q) FROM ("
        "SELECT id::text, step_id, prev_id, prev_table, repeat_run, status, phase, error, "
        "model, model_provider, harness, thinking_effort, checked_out_commit "
        "FROM workflows.step_metadata WHERE scan_id=1 AND status='failed' ORDER BY id) q;"
    ).splitlines()
]
assert {int(row["id"]) for row in failed} == {21, 22}, failed
expected_prefix = "attempt 1: The model process exited without returning a structured result. Review its saved output. Diagnostic: model_process_error.; model output: /data/model-error-outputs/"
assert all(str(row.get("error", "")).startswith(expected_prefix) for row in failed), failed
assert all(row["model"] == "claude-opus-5-5" for row in failed)
assert all(row["model_provider"] == "claude" for row in failed)
assert all(row["harness"] == "claude-code" for row in failed)
assert all(row["thinking_effort"] == "max" for row in failed)


def logical(row: dict) -> tuple:
    return (
        row.get("step_id"), row.get("prev_id") or 0,
        row.get("prev_table"), row.get("repeat_run") or 1,
    )


completed = [
    json.loads(line)
    for line in sql(
        "SELECT row_to_json(q) FROM ("
        "SELECT id::text, step_id, prev_id, prev_table, repeat_run, status "
        "FROM workflows.step_metadata WHERE scan_id=1 AND status='completed' ORDER BY id) q;"
    ).splitlines()
]
completed_keys = {logical(row) for row in completed}
unresolved = [row for row in failed if logical(row) not in completed_keys]
if not unresolved:
    print(json.dumps({
        "scanId": 1,
        "action": "NO_RESUME",
        "reason": "All historical failed metadata rows already have completed counterparts for the same logical keys.",
        "historicalFailedMetadataIds": [21, 22],
        "unresolvedFailedMetadataIds": [],
    }, indent=2))
    raise SystemExit(0)
assert {int(row["id"]) for row in unresolved} == {21, 22}, unresolved

resume_capture_started = False
patch_attempted = False


def preserve_resume_failure(exc_type, exc_value, exc_traceback) -> None:
    if resume_capture_started and OUT.exists():
        try:
            write(OUT / "RESUME-FAILURE.json", {
                "schema": "raffle-fun.claude-openkritt-supported-resume-failure.v1",
                "failedUtc": now(),
                "exceptionType": exc_type.__name__,
                "exception": str(exc_value),
                "patchRequestAttempted": patch_attempted,
                "automaticRetryPermitted": False,
                "requiresStateDiagnosisBeforeAnyFurtherAction": True,
            })
        except Exception as preservation_error:
            print(f"failed to record resume failure: {preservation_error}", file=sys.stderr)
    sys.__excepthook__(exc_type, exc_value, exc_traceback)


sys.excepthook = preserve_resume_failure
OUT.mkdir()
resume_capture_started = True
(OUT / "pre-resume-api.json").write_bytes(raw_api)
(OUT / "pre-resume-api-stability-observation.json").write_bytes(raw_api_2)
write(OUT / "diagnosed-failures.json", {
    "historicalFailedRows": failed,
    "unresolvedFailedRows": unresolved,
    "completedCounterpartCount": len(completed),
})
write(OUT / "table-location-evidence.json", {
    "recordedUtc": now(),
    "publicScansRows": 1,
    "workflowsScansRegclass": None,
    "supervisorBugDiagnosis": "../SUPERVISOR-BUG-DIAGNOSIS.json",
})

destination = OUT / "preserved-model-error-outputs"
destination.mkdir()
for row in unresolved:
    match = re.search(r"model output:\s*(/data/model-error-outputs/[^;\s]+)", row["error"])
    assert match, row
    source = match.group(1)
    subprocess.run([
        "docker", "--host", HOST, "cp",
        f"open-kritt-engine:{source}", str(destination / Path(source).name),
    ], check=True)

dump = OUT / "before-supported-resume.sql"
with dump.open("xb") as stream:
    subprocess.run([
        "docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
        'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
        '--table=public.scans --table="workflows.*" --no-owner --no-privileges',
    ], stdout=stream, check=True)

files = {}
for path in sorted(OUT.rglob("*")):
    if path.is_file():
        files[path.relative_to(OUT).as_posix()] = {
            "bytes": path.stat().st_size,
            "sha256": sha(path),
        }
pre_seal = {
    "schema": "raffle-fun.claude-openkritt-pre-supported-resume-seal.v1",
    "sealedUtc": now(),
    "scanId": 1,
    "originalFailedMetadataIds": [21, 22],
    "originalFailureType": "model_process_error",
    "providerSafetyRejection": False,
    "databaseDumpSha256": sha(dump),
    "artifacts": files,
    "existingResultsRewritten": False,
    "directDatabaseMutation": False,
    "newScanCreated": False,
}
write(OUT / "PRE-RESUME-SEAL.json", pre_seal)

request = urllib.request.Request(
    URL,
    data=b'{"status":"pending"}',
    headers={"Content-Type": "application/json"},
    method="PATCH",
)
patch_attempted = True
with urllib.request.urlopen(request, timeout=20) as response:
    raw_result = response.read()
(OUT / "supported-resume-response.json").write_bytes(raw_result)
result = json.loads(raw_result)
if "scan" in result:
    result = result["scan"]
assert str(result["id"]) == "1"
assert result["status"] in {"pending", "running"}, result["status"]
write(OUT / "SUPPORTED-RESUME-RECEIPT.json", {
    "schema": "raffle-fun.claude-openkritt-supported-resume.v1",
    "resumedUtc": now(),
    "scanId": 1,
    "method": "PATCH",
    "url": URL,
    "body": {"status": "pending"},
    "returnedStatus": result["status"],
    "originalFailedMetadataIds": [21, 22],
    "preResumeSealSha256": sha(OUT / "PRE-RESUME-SEAL.json"),
    "databaseDumpSha256": sha(dump),
    "directDatabaseMutation": False,
    "newScanCreated": False,
    "modelSubstitution": False,
    "providerSafetyRejectionRetried": False,
})
print(json.dumps({
    "scanId": 1,
    "returnedStatus": result["status"],
    "preResumeSealSha256": sha(OUT / "PRE-RESUME-SEAL.json"),
    "receiptSha256": sha(OUT / "SUPPORTED-RESUME-RECEIPT.json"),
}, indent=2))
