#!/usr/bin/env python3
"""Capture and qualify terminal CLAUDE-OPENKRITT-MOD scan 1.

The raw API, canonical ZIP, selected-table database dump, source identity, and
available native logs are sealed before any finding content is parsed or
adopted. This helper does not mutate the scan, database, containers, or VM.
"""
from pathlib import Path
import collections
import datetime
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

AUDIT = Path("/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001")
ATTEMPT = AUDIT / "provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01"
OUT = ATTEMPT / "final-capture"
RAW = OUT / "raw"
HOST = "unix:///Users/hishamel-husseini/.lima/raffle-claude-openkritt/sock/docker.sock"
URL = "http://127.0.0.1:3002/api/scans/1"
ENGINE = Path("/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/openkritt-mod")
TARGET = ENGINE / "local_repos/raffle-fun-r001-clean"
SUPERVISOR = ATTEMPT / "native-resume-supervisor"
EXPECTED_SOURCE = AUDIT / "provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03/frozen-source-manifest.json"
EXPECTED_SOURCE_SHA256 = "b5de09082c6e954d0a9a3e70ca393f37e0cc28e861e62ce64ac67b6b0a3ebe8b"
TARGET_COMMIT = "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155"
SNAPSHOT_COMMIT = "9732b7d81ed464ced9948d2c590b1a258947d67d"
SNAPSHOT_TREE = "5571fa2e34b925efb18ddccfeddd9f441077afe5"
OPENKRITT_COMMIT = "43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3"
RECORDED_METHOD_PATCH_SHA256 = "489af1123620057d4839ca2cd8532d1a239b110f710e77d73e8f079eac099fc8"
FULL_ENGINE_DIFF_SHA256 = "6820938ad453b96b4496a4a29cb07cac8de1a6caef7759ebd3b1c195fa49b7e9"
LOCKFILE_DIFF_SHA256 = "145c6938326068a474ed30510f75aaf68fed461d2c1febf6926c61566df0b2bf"
LOCKFILE_SHA256 = "a6cd825004a02f4237d48d3f34744e7edca9e1ee7b739c62f6ebbf367b1bd9d7"
MODEL = "claude-opus-5-5"
PROVIDER = "claude"
HARNESS = "claude-code"
EFFORT = "max"


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def run(argv: list[str], *, cwd: Path | None = None, timeout: int = 120, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(argv, cwd=cwd, text=True, capture_output=True, timeout=timeout, check=check)


def docker(*argv: str, timeout: int = 120, check: bool = True) -> subprocess.CompletedProcess:
    return run(["docker", "--host", HOST, *argv], timeout=timeout, check=check)


def sql(query: str) -> str:
    command = [
        "docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
        'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "$1"',
        "audit-readonly-sql", query,
    ]
    return subprocess.check_output(command, text=True, timeout=180)


def fetch(url: str, timeout: int = 180) -> bytes:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def fetch_response(url: str, timeout: int = 180) -> tuple[int, dict, bytes]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            status = response.status
            headers = response.headers
            body = response.read()
    except urllib.error.HTTPError as error:
        status = error.code
        headers = error.headers
        body = error.read()
    selected_headers = {
        key.lower(): value
        for key, value in headers.items()
        if key.lower() in {"content-type", "content-length", "content-disposition"}
    }
    return status, selected_headers, body


def minimal_terminal(raw: bytes) -> dict:
    value = json.loads(raw)
    scan = value.get("scan", value)
    summary = scan.get("statusSummary", {})
    return {
        "id": str(scan.get("id")),
        "repoFull": scan.get("repoFull"),
        "status": scan.get("status"),
        "jobsStarted": scan.get("jobsStarted"),
        "activeJobCount": summary.get("activeJobCount"),
        "runningAttempts": summary.get("runningAttempts"),
        "completedAttempts": summary.get("completedAttempts"),
        "failedAttempts": summary.get("failedAttempts"),
        "completedStepLineages": summary.get("completedStepLineages"),
        "expectedStepLineages": summary.get("expectedStepLineages"),
        "model": scan.get("model"),
        "modelProvider": scan.get("modelProvider"),
        "harness": scan.get("harness"),
        "thinkingEffort": scan.get("thinkingEffort"),
    }


def secure_tree(root: Path) -> None:
    for path in sorted(root.rglob("*")):
        if path.is_dir():
            path.chmod(0o700)
        elif path.is_file():
            path.chmod(0o600)


def artifact(path: Path) -> dict:
    return {
        "path": str(path),
        "auditRelativePath": str(path.relative_to(AUDIT)) if path.is_relative_to(AUDIT) else None,
        "bytes": path.stat().st_size,
        "sha256": sha(path),
    }


capture_started = False
capture_complete = False


def preserve_failed_capture(exc_type, exc_value, exc_traceback) -> None:
    """Keep a failed capture, but move it aside so a corrected run is possible."""
    if capture_started and OUT.exists() and not capture_complete:
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        failed = ATTEMPT / f"failed-final-capture-{stamp}"
        try:
            OUT.rename(failed)
            write(failed / "CAPTURE-FAILURE.json", {
                "schema": "raffle-fun.claude-openkritt-capture-failure.v1",
                "failedUtc": now(),
                "exceptionType": exc_type.__name__,
                "exception": str(exc_value),
                "preservedFrom": str(OUT),
                "preservedAt": str(failed),
                "scanOrDatabaseMutatedByCaptureHelper": False,
            })
            secure_tree(failed)
        except Exception as preservation_error:
            print(f"failed to preserve partial capture: {preservation_error}", file=sys.stderr)
    sys.__excepthook__(exc_type, exc_value, exc_traceback)


sys.excepthook = preserve_failed_capture
assert not OUT.exists(), f"refusing to overwrite {OUT}"

# Two stable terminal observations. Only routing and lifecycle fields are used
# before the raw-first-pass seal; finding content is not inspected here.
raw_status_1 = fetch(URL, 30)
view_1 = minimal_terminal(raw_status_1)
time.sleep(5)
raw_status_2 = fetch(URL, 30)
view_2 = minimal_terminal(raw_status_2)
for view in (view_1, view_2):
    assert view["id"] == "1", view
    assert view["repoFull"] == "raffle-fun-r001-clean", view
    assert view["status"] == "completed", view
    assert view["activeJobCount"] == 0, view
    assert view["runningAttempts"] == 0, view
    assert view["model"] == MODEL, view
    assert view["modelProvider"] == PROVIDER, view
    assert view["harness"] == HARNESS, view
    assert view["thinkingEffort"] == EFFORT, view
assert view_1["completedStepLineages"] == view_2["completedStepLineages"]
assert view_1["expectedStepLineages"] == view_2["expectedStepLineages"]
assert view_1["jobsStarted"] == view_2["jobsStarted"]
assert view_1["completedAttempts"] == view_2["completedAttempts"]
assert view_1["failedAttempts"] == view_2["failedAttempts"]
assert sql("SELECT count(*)::text FROM public.scans;").strip() == "1"
supervisor_terminal = SUPERVISOR / "native-terminal.json"
assert supervisor_terminal.is_file(), "wait for the existing supervisor to record its terminal observation"
supervisor_view = json.loads(supervisor_terminal.read_text())
assert supervisor_view["status"] == "completed"
assert supervisor_view["counts"]["activeJobCount"] == 0

OUT.mkdir()
capture_started = True
RAW.mkdir()
(RAW / "terminal-api-observation-01.json").write_bytes(raw_status_1)
(RAW / "terminal-api-observation-02.json").write_bytes(raw_status_2)

# Native canonical export response: terminal scan only. OpenKritt returns a ZIP
# when canonical findings exist and a native 409 JSON response when none exist.
# Preserve either response byte-for-byte before parsing it or opening a ZIP.
export_status, export_headers, export_bytes = fetch_response(URL + "/export", 300)
write(RAW / "canonical-export-http.json", {
    "capturedUtc": now(),
    "status": export_status,
    "selectedHeaders": export_headers,
    "bodyBytes": len(export_bytes),
    "bodySha256": hashlib.sha256(export_bytes).hexdigest(),
})
if export_status == 200:
    assert export_bytes[:4] == b"PK\x03\x04", "native export response is not a ZIP"
    (RAW / "canonical-export.zip").write_bytes(export_bytes)
elif export_status == 409:
    (RAW / "canonical-export-unavailable.json").write_bytes(export_bytes)
else:
    raise AssertionError(f"unexpected native export HTTP status {export_status}")

# One consistent selected-table PostgreSQL dump. Credentials expand only
# inside the database container and never enter argv/output.
tables = [
    "public.scans", "public.llm_workflows", "public.steps", "public.post_scripts",
    "public.severity_rankers", "public.model_catalogs", "public.agent_skills", "public.generations",
    "workflows.step_metadata", "workflows.step_results", "workflows.step_results_default",
    "workflows.post_process_metadata", "workflows.supplemental_post_script_runs",
    "workflows.supplemental_post_script_targets", "workflows.triage",
    "workflows.vulnerabilities", "workflows.vulnerability_enrichments",
]
dump = RAW / "selected-native-database.sql"
dump_command = [
    "docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
    'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
    '--no-owner --no-privileges --serializable-deferrable "$@"',
    "audit-selected-pg-dump", *[f"--table={table}" for table in tables],
]
with dump.open("xb") as stream:
    subprocess.run(dump_command, stdout=stream, check=True, timeout=600)

# Capture saved model-process errors, if any, without exposing Docker env or
# provider homes.
error_dirs = docker(
    "exec", "open-kritt-engine", "sh", "-c",
    "find /data/model-error-outputs -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort",
    timeout=60,
    check=False,
).stdout.splitlines()
error_root = RAW / "model-error-outputs"
error_root.mkdir()
for source in error_dirs:
    docker("cp", f"open-kritt-engine:{source}", str(error_root / Path(source).name), timeout=180)

# Source identity and immutable byte comparison.
assert sha(EXPECTED_SOURCE) == EXPECTED_SOURCE_SHA256
expected = json.loads(EXPECTED_SOURCE.read_text())
assert len(expected) == 43
actual_files = sorted(
    path.relative_to(TARGET).as_posix()
    for path in TARGET.rglob("*")
    if path.is_file() and ".git" not in path.relative_to(TARGET).parts
)
assert actual_files == sorted(expected), (len(actual_files), len(expected))
actual_hashes = {rel: sha(TARGET / rel) for rel in actual_files}
assert actual_hashes == expected
source_identity = {
    "capturedUtc": now(),
    "frozenTargetCommit": TARGET_COMMIT,
    "scanCommitField": "LOCAL_SNAPSHOT",
    "snapshotRepositoryCommit": run(["git", "rev-parse", "HEAD"], cwd=TARGET).stdout.strip(),
    "snapshotRepositoryTree": run(["git", "rev-parse", "HEAD^{tree}"], cwd=TARGET).stdout.strip(),
    "snapshotRepositoryStatus": run(["git", "status", "--porcelain=v1"], cwd=TARGET).stdout,
    "expectedManifestSha256": sha(EXPECTED_SOURCE),
    "expectedFileCount": 43,
    "matchedFileCount": 43,
    "allFilesMatched": True,
    "files": actual_hashes,
}
assert source_identity["snapshotRepositoryCommit"] == SNAPSHOT_COMMIT
assert source_identity["snapshotRepositoryTree"] == SNAPSHOT_TREE
assert source_identity["snapshotRepositoryStatus"] == ""
write(RAW / "source-identity.json", source_identity)
shutil.copy2(EXPECTED_SOURCE, RAW / "frozen-source-manifest.json")

# Exact patched OpenKritt identity without copying secret-bearing env files.
engine_head = run(["git", "rev-parse", "HEAD"], cwd=ENGINE).stdout.strip()
assert engine_head == OPENKRITT_COMMIT
engine_status = run(["git", "status", "--porcelain=v1"], cwd=ENGINE).stdout
engine_patch = run(["git", "diff", "--binary", "HEAD"], cwd=ENGINE).stdout
method_patch = run([
    "git", "diff", "--binary", "HEAD", "--", ".", ":(exclude)backend/package-lock.json",
], cwd=ENGINE).stdout
lockfile_patch = run([
    "git", "diff", "--binary", "HEAD", "--", "backend/package-lock.json",
], cwd=ENGINE).stdout
recorded_method_patch = (ATTEMPT / "openkritt-mod.patch").read_bytes()
assert sha(ATTEMPT / "openkritt-mod.patch") == RECORDED_METHOD_PATCH_SHA256
assert method_patch.encode() == recorded_method_patch
assert hashlib.sha256(method_patch.encode()).hexdigest() == RECORDED_METHOD_PATCH_SHA256
assert hashlib.sha256(engine_patch.encode()).hexdigest() == FULL_ENGINE_DIFF_SHA256
assert hashlib.sha256(lockfile_patch.encode()).hexdigest() == LOCKFILE_DIFF_SHA256
assert sha(ENGINE / "backend/package-lock.json") == LOCKFILE_SHA256
(RAW / "openkritt-git-status.txt").write_text(engine_status)
(RAW / "openkritt-working-tree.patch").write_text(engine_patch)
(RAW / "openkritt-package-lock-drift.patch").write_text(lockfile_patch)
modified = [line[3:] for line in engine_status.splitlines() if len(line) > 3]
expected_modified = {
    "backend/package-lock.json",
    "backend/src/lib/modelCatalog.js",
    "engine/Dockerfile",
    "engine/Dockerfile.claude-runner",
    "engine/open_kritt_engine/model_catalog.py",
}
assert set(modified) == expected_modified, modified
engine_hashes = {
    rel: sha(ENGINE / rel)
    for rel in sorted(modified)
    if (ENGINE / rel).is_file() and rel not in {".env", ".data/engine/engine-runtime.env"}
}
engine_identity = {
    "capturedUtc": now(),
    "upstreamCommit": engine_head,
    "workingTreeModifiedPaths": modified,
    "modifiedFileHashes": engine_hashes,
    "recordedAuditPatchSha256": RECORDED_METHOD_PATCH_SHA256,
    "recordedAuditPatchEqualsNonLockfileWorkingTreeDiff": True,
    "capturedFullWorkingTreeDiffSha256": FULL_ENGINE_DIFF_SHA256,
    "additionalPackageLockDrift": {
        "path": "backend/package-lock.json",
        "sha256": LOCKFILE_SHA256,
        "diffSha256": LOCKFILE_DIFF_SHA256,
        "change": "npm lock metadata added dev=true to the optional fsevents 2.3.3 record",
        "runtimeMethodChange": False,
        "includedInRecordedAuditPatch": False,
        "includedInCapturedFullWorkingTreeDiff": True,
    },
    "credentialsOrRuntimeEnvCopied": False,
}
write(RAW / "openkritt-source-identity.json", engine_identity)

# Container/image identity and available service logs. Full docker inspect and
# environment output are deliberately excluded.
ps = docker("ps", "-a", "--no-trunc", "--format", "{{json .}}", timeout=60)
(RAW / "docker-ps.jsonl").write_text(ps.stdout)
container_rows = []
for line in ps.stdout.splitlines():
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    name = row.get("Names", "")
    if name.startswith("open-kritt-"):
        image_id = docker("inspect", "--format", "{{.Image}}", name, timeout=30).stdout.strip()
        container_rows.append({
            "name": name,
            "containerId": row.get("ID"),
            "image": row.get("Image"),
            "imageId": image_id,
            "state": row.get("State"),
            "status": row.get("Status"),
        })
write(RAW / "container-image-identities.json", {"capturedUtc": now(), "containers": container_rows})
log_receipts = []
for name in ["open-kritt-engine", "open-kritt-backend", "open-kritt-db", "open-kritt-executor-view"]:
    result = docker("logs", "--timestamps", name, timeout=180, check=False)
    path = RAW / f"{name}.log"
    path.write_text(result.stdout + result.stderr)
    log_receipts.append({"container": name, "exitCode": result.returncode, "path": path.name})
write(RAW / "container-log-capture.json", {
    "capturedUtc": now(),
    "logs": log_receipts,
    "historicalAutoRemovedRunnerStreamsAvailable": False,
    "limitation": "Prior per-job runner containers were auto-removed; their raw Docker stdout streams were not retained. Database output rows, generations, saved error outputs and available service logs are preserved instead.",
})

# Freeze verifier output is captured without modifying the closure.
freeze_run = run(["python3", "verify-freeze.py"], cwd=AUDIT, timeout=300, check=False)
(RAW / "verify-freeze.stdout.txt").write_text(freeze_run.stdout)
(RAW / "verify-freeze.stderr.txt").write_text(freeze_run.stderr)
write(RAW / "verify-freeze-exit.json", {"capturedUtc": now(), "exitCode": freeze_run.returncode})
assert freeze_run.returncode == 0

# Copy immutable setup/intervention evidence into the raw capture. Do not copy
# .env, provider homes, or engine-runtime.env.
evidence_paths = [
    "docker-compose.override.yml", "freeze-before.json", "intervention.log", "monitor.log",
    "openkritt-mod.patch", "scan-create-response.json", "scan-request.json", "settings-changes.log",
    "started_at.txt", "SUPERVISOR-BUG-DIAGNOSIS.json", "CAPTURE-HELPER-REPAIR.json",
    "LOGICAL-FAILURE-RESOLUTION-DIAGNOSIS.json", "PRE-SEAL-STATUS-EXPOSURE.json",
    "TERMINAL-PRE-SEAL-STATUS-EXPOSURE-ADDENDUM.json",
]
setup_dir = RAW / "setup-evidence"
setup_dir.mkdir()
for rel in evidence_paths:
    source = ATTEMPT / rel
    if source.is_file():
        shutil.copy2(source, setup_dir / source.name)
supervisor_dir = ATTEMPT / "native-resume-supervisor"
if supervisor_dir.is_dir():
    shutil.copytree(supervisor_dir, setup_dir / "native-resume-supervisor")
supported_resume = ATTEMPT / "native-supported-resume-02"
if supported_resume.is_dir():
    shutil.copytree(supported_resume, setup_dir / "native-supported-resume-02")

# Seal every raw artifact before opening the export or querying structured
# findings. The manifest excludes itself to avoid a hash cycle.
secure_tree(RAW)
assert stat.S_IMODE(dump.stat().st_mode) == 0o600
raw_artifacts = {
    path.relative_to(OUT).as_posix(): {
        "bytes": path.stat().st_size,
        "sha256": sha(path),
    }
    for path in sorted(RAW.rglob("*"))
    if path.is_file()
}
raw_manifest = {
    "schema": "raffle-fun.claude-openkritt-raw-first-pass-manifest.v1",
    "recordedUtc": now(),
    "scanId": 1,
    "terminalStatus": "completed",
    "artifactCount": len(raw_artifacts),
    "artifacts": raw_artifacts,
    "findingsParsedBeforeSeal": False,
    "nativeStatusNarrativeExposedBeforeSeal": True,
    "nativeStatusNarrativeAdoptedBeforeSeal": False,
    "nativeStatusNarrativeFedBackToReviewer": False,
    "canonicalExportArchiveOpenedBeforeSeal": False,
    "canonicalExportResponseParsedBeforeSeal": False,
    "databaseDumpMode": "0600",
    "credentialEnvironmentsOrProviderHomesIntentionallyCopied": False,
    "secretValueSanitizationClaimedForRawNativeLogs": False,
    "rawArtifactFileMode": "0600",
}
write(OUT / "RAW-FIRST-PASS-MANIFEST.json", raw_manifest)
raw_seal = {
    "schema": "raffle-fun.claude-openkritt-raw-first-pass-seal.v1",
    "sealedUtc": now(),
    "scanId": 1,
    "targetCommit": TARGET_COMMIT,
    "rawManifest": {
        "path": "RAW-FIRST-PASS-MANIFEST.json",
        "sha256": sha(OUT / "RAW-FIRST-PASS-MANIFEST.json"),
    },
    "rawArtifactCount": len(raw_artifacts),
    "sourceFilesMatched": 43,
    "findingsParsedBeforeSeal": False,
    "nativeStatusNarrativeExposedBeforeSeal": True,
    "nativeStatusNarrativeAdoptedBeforeSeal": False,
    "canonicalExportArchiveOpenedBeforeSeal": False,
    "canonicalExportResponseParsedBeforeSeal": False,
}
write(OUT / "RAW-FIRST-PASS-SEAL.json", raw_seal)
secure_tree(OUT)

# Post-seal structured export in one PostgreSQL statement/snapshot. The three
# account-attribution fields are omitted; no credential-bearing table is read.
def aggregate(table: str, where: str = "true", order: str = "id") -> str:
    return (
        "(SELECT coalesce(json_agg(to_jsonb(t) - 'codex_source_home' - 'codex_account_id' - "
        f"'codex_account_email' ORDER BY {order}),'[]'::json) FROM "
        f"(SELECT * FROM {table} WHERE {where}) t)"
    )


structured_query = "SELECT json_build_object(" + ",".join([
    "'captured_utc',clock_timestamp()",
    "'scan'," + aggregate("public.scans", "id=1"),
    "'workflow'," + aggregate("public.llm_workflows", "id=(SELECT workflow_id FROM public.scans WHERE id=1)"),
    "'step_definitions'," + aggregate("public.steps", "id IN (SELECT unnest(step_ids) FROM public.llm_workflows WHERE id=(SELECT workflow_id FROM public.scans WHERE id=1))"),
    "'post_scripts'," + aggregate("public.post_scripts", "id=4"),
    "'rankers'," + aggregate("public.severity_rankers", "name=(SELECT severity_ranker FROM public.scans WHERE id=1)"),
    "'model_catalogs'," + aggregate("public.model_catalogs", "provider='claude'", "provider"),
    "'agent_skills'," + aggregate("public.agent_skills"),
    "'generations'," + aggregate("public.generations"),
    "'step_metadata'," + aggregate("workflows.step_metadata", "scan_id=1"),
    "'step_results'," + aggregate("workflows.step_results", "scan_id=1"),
    "'step_results_default'," + aggregate("workflows.step_results_default", "scan_id=1"),
    "'post_processing'," + aggregate("workflows.post_process_metadata", "scan_id=1"),
    "'supplemental_runs'," + aggregate("workflows.supplemental_post_script_runs", "scan_id=1"),
    "'supplemental_targets'," + aggregate("workflows.supplemental_post_script_targets", "scan_id=1"),
    "'findings'," + aggregate("workflows.vulnerabilities", "scan_id=1"),
    "'enrichments'," + aggregate("workflows.vulnerability_enrichments", "scan_id=1"),
    "'triage'," + aggregate("workflows.triage", "vulnerability_id IN (SELECT id FROM workflows.vulnerabilities WHERE scan_id=1)"),
]) + ");"
structured_text = sql(structured_query).strip()
data = json.loads(structured_text)
write(OUT / "native-results.json", data)

# Parse or open the already sealed native export response.
zip_index = []
export_unavailable = None
if export_status == 200:
    export_dir = OUT / "canonical-export"
    export_dir.mkdir()
    with zipfile.ZipFile(RAW / "canonical-export.zip") as archive:
        assert archive.testzip() is None
        for info in archive.infolist():
            member = Path(info.filename)
            assert not member.is_absolute() and ".." not in member.parts, info.filename
            if info.is_dir():
                continue
            destination = export_dir / member
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(info))
            zip_index.append({
                "path": member.as_posix(),
                "bytes": destination.stat().st_size,
                "sha256": sha(destination),
            })
else:
    export_unavailable = json.loads(export_bytes)
    assert export_unavailable == {"error": "This scan has no canonical findings to export."}
write(OUT / "canonical-export-index.json", {
    "httpStatus": export_status,
    "archiveSha256": sha(RAW / "canonical-export.zip") if export_status == 200 else None,
    "unavailableResponseSha256": sha(RAW / "canonical-export-unavailable.json") if export_status == 409 else None,
    "unavailableReason": export_unavailable.get("error") if export_unavailable else None,
    "entryCount": len(zip_index),
    "entries": zip_index,
})

scans = data["scan"]
assert len(scans) == 1
scan = scans[0]
assert str(scan["id"]) == "1"
assert scan["status"] == "completed"
assert scan["model"] == MODEL and scan["model_provider"] == PROVIDER
assert scan["harness"] == HARNESS and scan["thinking_effort"] == EFFORT
assert scan["commit_sha"] == "LOCAL_SNAPSHOT"
assert (scan.get("agent_skill_ids") or []) == []

workflow = data["workflow"]
assert len(workflow) == 1 and workflow[0]["name"] == "external-flow-analysis"
steps = sorted(data["step_definitions"], key=lambda row: row["depth"])
assert [row["depth"] for row in steps] == [0, 1, 2]
assert len(data["post_scripts"]) == 1 and data["post_scripts"][0]["id"] == 4
assert len(data["rankers"]) == 1

metadata = data["step_metadata"]
post = data["post_processing"]
open_rows = [
    {"table": table, "id": row["id"], "status": row["status"]}
    for table, rows in (("step_metadata", metadata), ("post_process_metadata", post))
    for row in rows
    if row.get("status") in {"pending", "running"}
]

tuple_mismatches = []
for table, rows in (("step_metadata", metadata), ("post_process_metadata", post)):
    for row in rows:
        if row.get("model") and (
            row.get("model") != MODEL or row.get("model_provider") != PROVIDER
            or row.get("harness") != HARNESS or row.get("thinking_effort") != EFFORT
        ):
            tuple_mismatches.append({"table": table, "id": row["id"]})

def logical(row: dict) -> tuple:
    return (
        row.get("kind", "step"), row.get("step_id"), row.get("prev_id") or 0,
        row.get("prev_table"), row.get("repeat_run") or 1,
    )


completed_keys = {logical(row) for row in metadata if row.get("status") == "completed"}
failed_rows = [row for row in metadata if row.get("status") == "failed"]
unresolved_failed = [row["id"] for row in failed_rows if logical(row) not in completed_keys]
historical_failed_ids = [row["id"] for row in failed_rows]
assert {int(value) for value in historical_failed_ids} == {21, 22}, historical_failed_ids

findings = data["findings"]
missing_dedupe = [row["id"] for row in findings if row.get("dedupe_is_canonical") is None]
canonical = [row for row in findings if row.get("dedupe_is_canonical") is True]
assert (export_status == 200) == bool(canonical), (export_status, len(canonical))
missing_rank = [row["id"] for row in canonical if row.get("bounty_rank") is None]
config = scan.get("configuration") or scan.get("config") or {}
configured_posts = set(config.get("post_script_ids") or [])
if scan.get("post_script_id") is not None:
    configured_posts.add(scan["post_script_id"])
configured_posts = {int(value) for value in configured_posts}
assert configured_posts == {4}, configured_posts
enrichment_pairs = {
    (int(row["vulnerability_id"]), int(row["post_script_id"]))
    for row in data["enrichments"]
    if row.get("supplemental_run_id") is None
}
missing_posts = [
    {"findingId": row["id"], "postScriptId": post_id}
    for row in canonical
    for post_id in sorted(configured_posts)
    if (int(row["id"]), post_id) not in enrichment_pairs
]

status_counts = collections.Counter(row["status"] for row in metadata)
metadata_attempts = len(metadata)
logical_all = len({logical(row) for row in metadata})
logical_completed = len({logical(row) for row in metadata if row.get("status") == "completed"})
post_executed = len(post) > 0 or len(data["enrichments"]) > 0
if not findings:
    assert not post_executed

issues = []
if logical_completed != view_2["completedStepLineages"]:
    issues.append({
        "issue": "completed logical lineage count does not match terminal completed counter",
        "completedLogicalLineages": logical_completed,
        "terminalCompletedStepLineages": view_2["completedStepLineages"],
    })
if logical_completed != view_2["completedAttempts"] or logical_completed != view_2["jobsStarted"]:
    issues.append({
        "issue": "completed logical lineage count does not match terminal completed/job-started counters",
        "completedLogicalLineages": logical_completed,
        "terminalCompletedAttempts": view_2["completedAttempts"],
        "terminalJobsStarted": view_2["jobsStarted"],
    })
if metadata_attempts != view_2["expectedStepLineages"]:
    issues.append({
        "issue": "metadata attempt count does not match terminal expected counter",
        "metadataAttempts": metadata_attempts,
        "expectedStepLineages": view_2["expectedStepLineages"],
    })
if len(failed_rows) != view_2["failedAttempts"]:
    issues.append({
        "issue": "preserved failed metadata count does not match terminal failed counter",
        "failedMetadataRows": len(failed_rows),
        "terminalFailedAttempts": view_2["failedAttempts"],
    })
if logical_all != logical_completed or metadata_attempts != logical_completed + len(failed_rows):
    issues.append({
        "issue": "terminal attempt/logical-key accounting is inconsistent",
        "metadataAttempts": metadata_attempts,
        "distinctAllLogicalLineages": logical_all,
        "completedLogicalLineages": logical_completed,
        "preservedFailedMetadataRows": len(failed_rows),
    })
if open_rows:
    issues.append({"issue": "open native metadata", "rows": open_rows})
if tuple_mismatches:
    issues.append({"issue": "model/provider/harness/effort mismatch", "rows": tuple_mismatches})
if unresolved_failed:
    issues.append({"issue": "unresolved historical logical failures", "metadataIds": unresolved_failed})
if missing_dedupe or missing_rank or missing_posts:
    issues.append({
        "issue": "native finding obligations incomplete",
        "missingDedupe": missing_dedupe,
        "missingRank": missing_rank,
        "missingPostScript4": missing_posts,
    })

completion = {
    "schema": "raffle-fun.claude-openkritt-mod-completion.v1",
    "completedUtc": now(),
    "cell": "CLAUDE-OPENKRITT-MOD",
    "originalCellDisposition": "CLAUDE-OPENKRITT attempt-01 remains blocked and is not relabeled complete",
    "selectedAttempt": "provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01",
    "targetCommit": TARGET_COMMIT,
    "scanId": 1,
    "method": "actual isolated OpenKritt Python/PostgreSQL native external-flow-analysis with disclosed engine/catalog patch",
    "modifiedMethod": True,
    "nativeStatus": "completed",
    "route": {
        "requestedModel": MODEL,
        "acceptedRecordedSelection": MODEL,
        "modelProvider": PROVIDER,
        "harness": HARNESS,
        "thinkingEffort": EFFORT,
        "providerReturnedIdentity": None,
        "fallbackUsed": False,
    },
    "workflow": {
        "id": scan["workflow_id"],
        "name": workflow[0]["name"],
        "depths": [0, 1, 2],
        "agentSkillIds": [],
        "configuredPostScriptIds": [4],
        "configuredPostScriptName": data["post_scripts"][0]["name"],
        "severityRanker": scan["severity_ranker"],
    },
    "sourceIntegrity": source_identity,
    "engineIdentity": engine_identity,
    "execution": {
        "metadataAttempts": metadata_attempts,
        "metadataStatusCounts": dict(sorted(status_counts.items())),
        "distinctAllLogicalLineages": logical_all,
        "completedLogicalLineages": logical_completed,
        "terminalApiCounters": {
            "jobsStarted": view_2["jobsStarted"],
            "completedAttempts": view_2["completedAttempts"],
            "failedAttempts": view_2["failedAttempts"],
            "completedStepLineages": view_2["completedStepLineages"],
            "expectedStepLineages": view_2["expectedStepLineages"],
            "interpretation": "For a completed scan, expectedStepLineages is the raw metadata-attempt count and includes the two preserved failed rows; the completed and jobs-started counters equal the 193 distinct completed logical keys."
        },
        "historicalFailedMetadataIds": historical_failed_ids,
        "historicalFailuresPreserved": True,
        "unresolvedFailedLogicalJobs": unresolved_failed,
        "openMetadata": open_rows,
        "tupleMismatches": tuple_mismatches,
    },
    "nativeOutputs": {
        "findingRecords": len(findings),
        "canonicalFindings": len(canonical),
        "missingDedupeIds": missing_dedupe,
        "missingRankIds": missing_rank,
        "missingPostScript4": missing_posts,
        "postprocessorExecuted": post_executed,
        "zeroFindingMeaning": "No native candidate required rank or postprocessing; zero findings is not proof of absence." if not findings else None,
    },
    "rawFirstPass": {
        "manifestSha256": sha(OUT / "RAW-FIRST-PASS-MANIFEST.json"),
        "sealSha256": sha(OUT / "RAW-FIRST-PASS-SEAL.json"),
        "canonicalExportHttpStatus": export_status,
        "canonicalExportSha256": sha(RAW / "canonical-export.zip") if export_status == 200 else None,
        "canonicalExportUnavailableResponseSha256": sha(RAW / "canonical-export-unavailable.json") if export_status == 409 else None,
        "databaseDumpSha256": sha(dump),
        "findingsParsedBeforeSeal": False,
        "preSealStatusNarrativeExposure": True,
        "preSealStatusNarrativeAdopted": False,
        "terminalExposureAddendumSha256": sha(ATTEMPT / "TERMINAL-PRE-SEAL-STATUS-EXPOSURE-ADDENDUM.json"),
    },
    "qualificationIssues": issues,
    "qualifiesRouteSourceAndNativeWorkflow": not issues,
    "semanticAdjudicationRequired": bool(findings),
    "newProductionRoots": 0 if not findings else None,
    "noClaimOfIndependentFindingValidation": True,
    "productionRemediation": False,
    "deploymentOrLiveTransactions": False,
    "globalAuditCompletionIssued": False,
}
write(OUT / "COMPLETION-RECEIPT.json", completion)

lines = [
    "# Claude OpenKritt modified native first pass",
    "",
    f"Frozen target: `{TARGET_COMMIT}`. Native scan ID: `1`. Upstream OpenKritt: `{OPENKRITT_COMMIT}`.",
    "",
    "This is the separately disclosed `CLAUDE-OPENKRITT-MOD` method. The original `CLAUDE-OPENKRITT` cell remains blocked and is not relabeled complete. The scan ran in the isolated `raffle-claude-openkritt` Lima VM through the actual OpenKritt Python engine, PostgreSQL queue and native workflow. The recorded route is `claude-opus-5-5` / `claude` / `claude-code` / `max`; provider-returned underlying identity was not independently returned and no fallback is claimed.",
    "",
    "The raw terminal API, native canonical-export response, selected-table database dump, source identity, saved process-error outputs and available service logs were sealed before this lane's final semantic adoption. Before that seal, whole status diagnostics exposed some `recentEmptyResults` explanation text to the coordinator, parent and accounting owner, including one later terminal diagnostic recorded by an append-only addendum. Nobody assessed or adopted it as a finding or fed it back to the native reviewer; therefore native input independence remains intact, but no complete pre-seal narrative non-exposure claim is made. OpenKritt returns a ZIP only when canonical findings exist; its native 409 no-findings response is preserved instead of synthesizing an empty archive. Prior auto-removed runner stdout streams were unavailable and are not reconstructed.",
    "",
    "## Source and method identity",
    "",
    f"The local scan snapshot is clean commit `{SNAPSHOT_COMMIT}` / tree `{SNAPSHOT_TREE}` and uses the engine's `LOCAL_SNAPSHOT` scan marker. All 43 snapshot files match the frozen audit source manifest byte-for-byte: five production files, 31 reachable Solidity dependencies and seven design/config/lock inputs. The frozen repository identity remains `{TARGET_COMMIT}`; the local snapshot commit is not substituted for it.",
    "",
    f"The recorded four-file model/catalog runner patch remains `{sha(ATTEMPT / 'openkritt-mod.patch')}`. The captured complete five-file engine worktree diff is `{engine_identity['capturedFullWorkingTreeDiffSha256']}`; its only additional path is `backend/package-lock.json`, where npm added `dev=true` to the optional `fsevents` lock record. That lock metadata drift is disclosed separately and is not represented as part of the recorded method patch.",
    "",
    "Workflow `external-flow-analysis` ran depths 0, 1 and 2. Configured skills were `[]`; post-script 4 (`PoC Creator`) was the only configured post-script. This differs from cells configured with post-scripts 3/4/5/6 and is not represented as those methods.",
    "",
    "## Native execution",
    "",
    f"OpenKritt recorded {len(metadata)} step attempts and {logical_completed} completed logical lineages. Historical metadata 21 and 22 remain failed with their original `model_process_error` text; their logical work is complete only because later native attempts with the same logical keys completed. No failed row was rewritten or renamed success.",
    "",
    f"The database contains {len(findings)} native finding records and {len(canonical)} canonical findings. " + ("No ranker or postprocessor job was scheduled because no candidate existed. This is not a proof of absence." if not findings else "All canonical findings have native deduplication, severity rank and configured post-script 4 evidence."),
    "",
    "## Limits",
    "",
    "The configured skill list was empty, and the workflow configuration is accepted only as this modified OpenKritt method. Source mapping outputs are model-generated coverage claims, not instrumented line coverage. No deployed integration, live RPC behavior, production remediation, deployment, signing, broadcast, publication or owner acceptance occurred. Native output is retained as source evidence, not independent proof of finding truth or absence.",
]
(OUT / "FIRST-PASS.md").write_text("\n".join(lines) + "\n")

mapping_results = [row for row in data["step_results"] if int(row.get("step_id") or 0) == 1]
coverage_lines = [
    "# Claude OpenKritt native mapping coverage",
    "",
    f"All 43 frozen snapshot files matched the audit source manifest. The {len(mapping_results)} native depth-0 mapping records below are semantic model outputs, not instrumented line or branch coverage.",
    "",
    "```json",
    json.dumps(mapping_results, indent=2),
    "```",
]
(OUT / "COVERAGE.md").write_text("\n".join(coverage_lines) + "\n")

method = {
    "schema": "raffle-fun.claude-openkritt-mod-method.v1",
    "recordedUtc": now(),
    "originalCell": "CLAUDE-OPENKRITT",
    "originalCellDisposition": "BLOCKED",
    "modifiedCell": "CLAUDE-OPENKRITT-MOD",
    "differences": [
        "isolated Lima VM and Docker host dedicated to this audit lane",
        "OpenKritt four-file catalog/runner method patch bound by openkritt-mod.patch",
        "separately disclosed backend/package-lock.json npm metadata drift outside the recorded method patch, included in the sealed complete worktree diff",
        "workflow external-flow-analysis at depths 0/1/2",
        "configured agent skills empty",
        "only post-script 4 PoC Creator configured",
    ],
    "upstreamOpenKrittCommit": OPENKRITT_COMMIT,
    "patchSha256": sha(ATTEMPT / "openkritt-mod.patch"),
    "capturedFullWorkingTreeDiffSha256": engine_identity["capturedFullWorkingTreeDiffSha256"],
    "additionalPackageLockDrift": engine_identity["additionalPackageLockDrift"],
    "rawRunnerStreamLimitation": "Prior auto-removed runner container stdout was unavailable at final capture.",
    "preSealStatusNarrativeExposure": {
        "path": str(ATTEMPT / "PRE-SEAL-STATUS-EXPOSURE.json"),
        "sha256": sha(ATTEMPT / "PRE-SEAL-STATUS-EXPOSURE.json"),
        "adoptedBeforeSeal": False,
        "fedBackToNativeReviewer": False,
    },
    "providerIdentity": "not independently returned",
}
write(OUT / "METHOD.json", method)

assert not issues, issues

# Final integrity manifest and seal. The seal is written last.
key_external = [
    Path(__file__).resolve(),
    ATTEMPT / "openkritt-mod.patch",
    ATTEMPT / "SUPERVISOR-BUG-DIAGNOSIS.json",
    AUDIT / "runtime-controller-repairs/monitor-claude-native-scan.py",
    AUDIT / "runtime-controller-repairs/repair-claude-native-failed-lineages.py",
    AUDIT / "provider-lanes/claude/runs/CLAUDE-OPENKRITT/attempt-01/BLOCKED.md",
    AUDIT / "reconciliation/finalization/PARENT-STATUS-EXPOSURE-ADDENDUM.json",
    ATTEMPT / "TERMINAL-PRE-SEAL-STATUS-EXPOSURE-ADDENDUM.json",
]
capture_files = [
    path for path in sorted(OUT.rglob("*"))
    if path.is_file() and path.name not in {"INTEGRITY-MANIFEST.json", "SEAL.json"}
]
manifest_artifacts = [artifact(path) for path in capture_files + key_external]
integrity = {
    "schema": "raffle-fun.claude-openkritt-mod-integrity-manifest.v1",
    "recordedUtc": now(),
    "targetCommit": TARGET_COMMIT,
    "scanId": 1,
    "artifactCount": len(manifest_artifacts),
    "artifacts": manifest_artifacts,
    "checks": {
        "rawFirstPassSealedBeforeFindingsParsed": True,
        "preSealStatusNarrativeExposureDisclosed": True,
        "preSealStatusNarrativeAdopted": False,
        "canonicalExportResponseCaptured": True,
        "canonicalExportArchiveCaptured": export_status == 200,
        "canonicalExportNativeNoFindingsResponseCaptured": export_status == 409,
        "selectedDatabaseDumpCaptured": True,
        "engineWorkingTreeFullyCapturedAndDisclosed": True,
        "sourceFilesMatched": 43,
        "routeTupleMatched": True,
        "openMetadataRows": 0,
        "unresolvedFailedLogicalJobs": 0,
        "findingObligationsComplete": True,
        "historicalFailuresPreserved": historical_failed_ids,
        "semanticAdjudicationRequired": bool(findings),
        "newProductionRoots": 0 if not findings else None,
    },
}
write(OUT / "INTEGRITY-MANIFEST.json", integrity)
for record in manifest_artifacts:
    path = Path(record["path"])
    assert path.stat().st_size == record["bytes"], path
    assert sha(path) == record["sha256"], path
seal = {
    "schema": "raffle-fun.claude-openkritt-mod-seal.v1",
    "sealedUtc": now(),
    "cell": "CLAUDE-OPENKRITT-MOD",
    "targetCommit": TARGET_COMMIT,
    "scanId": 1,
    "status": "QUALIFIED_MODIFIED_METHOD_COMPLETE" if not findings else "NATIVE_METHOD_OUTPUT_COMPLETE_SEMANTIC_GATE_PENDING",
    "route": completion["route"],
    "firstPass": {"path": "FIRST-PASS.md", "sha256": sha(OUT / "FIRST-PASS.md")},
    "completionReceipt": {"path": "COMPLETION-RECEIPT.json", "sha256": sha(OUT / "COMPLETION-RECEIPT.json")},
    "rawFirstPassSeal": {"path": "RAW-FIRST-PASS-SEAL.json", "sha256": sha(OUT / "RAW-FIRST-PASS-SEAL.json")},
    "integrityManifest": {"path": "INTEGRITY-MANIFEST.json", "sha256": sha(OUT / "INTEGRITY-MANIFEST.json")},
    "originalCellRelabeledComplete": False,
    "historicalFailuresRelabeledSuccess": False,
    "providerReturnedIdentity": None,
    "semanticAdjudicationRequired": bool(findings),
    "newProductionRoots": 0 if not findings else None,
    "globalAuditCompletionIssued": False,
}
write(OUT / "SEAL.json", seal)
secure_tree(OUT)
capture_complete = True
print(json.dumps({
    "status": seal["status"],
    "findingRecords": len(findings),
    "canonicalFindings": len(canonical),
    "completedLogicalLineages": logical_completed,
    "historicalFailedMetadataIds": historical_failed_ids,
    "rawFirstPassSealSha256": sha(OUT / "RAW-FIRST-PASS-SEAL.json"),
    "completionReceiptSha256": sha(OUT / "COMPLETION-RECEIPT.json"),
    "integrityManifestSha256": sha(OUT / "INTEGRITY-MANIFEST.json"),
    "sealSha256": sha(OUT / "SEAL.json"),
}, indent=2))
