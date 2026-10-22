#!/usr/bin/env python3
"""Finish monitoring the existing isolated scan; resume its diagnosed failed jobs.

No new scan, replacement reviewer, model substitution or native result rewriting.
Only the two previously diagnosed model_process_error rows are eligible here.
"""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "provider-lanes/claude/runs/CLAUDE-OPENKRITT-MOD/attempt-01/native-resume-supervisor"
HOST = "unix:///Users/hishamel-husseini/.lima/raffle-claude-openkritt/sock/docker.sock"
URL = "http://127.0.0.1:3002/api/scans/1"


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sql(query):
    # Normal use of the container's own database credentials. No credential
    # values leave the container or appear in this process's argv/output.
    command = ["docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
               'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "$1"',
               "audit-readonly-sql", query]
    return subprocess.check_output(command, text=True)


def record(name, data):
    (OUT / name).write_text(json.dumps(data, indent=2) + "\n")


OUT.mkdir(exist_ok=False)
record("launch.json", {"started_at": now(), "scan_url": URL, "docker_host": HOST,
                       "existing_scan_only": True, "eligible_failed_ids": [21, 22],
                       "outer_deadline": None, "automatic_safety_refusal_retry": False})
resumed = False
while True:
    try:
        with urllib.request.urlopen(URL, timeout=20) as response:
            scan = json.load(response)
        assert str(scan["id"]) == "1" and scan["repoFull"] == "raffle-fun-r001-clean"
        assert scan["model"] == "claude-opus-5-5" and scan["thinkingEffort"] == "max"
        assert scan["harness"] == "claude-code"
        summary = scan.get("statusSummary", {})
        safe = {"observed_at": now(), "status": scan["status"],
                "progress": scan.get("progress"), "progressLabel": scan.get("progressLabel"),
                "counts": {key: summary.get(key) for key in ["completedAttempts", "runningAttempts", "failedAttempts", "currentFailedAttempts", "activeJobCount", "canResume", "postCompletedAttempts", "postRunningAttempts"]}}
        with (OUT / "observations.jsonl").open("a") as stream:
            stream.write(json.dumps(safe) + "\n")
        if scan["status"] == "completed" and summary.get("activeJobCount") == 0:
            record("native-terminal.json", safe)
            break
        if scan["status"] in ["failed", "paused", "stopped"] and summary.get("activeJobCount") == 0 and not resumed:
            # Refuse to operate on an unexpectedly reused database.
            assert sql("SELECT count(*)::text FROM workflows.scans;").strip() == "1"
            failed = [json.loads(line) for line in sql("SELECT row_to_json(q) FROM (SELECT id::text, status, error FROM workflows.step_metadata WHERE scan_id=1 AND status='failed' ORDER BY id) q;").splitlines()]
            assert failed and {int(row["id"]) for row in failed}.issubset({21, 22})
            assert all(row.get("error") == "model_process_error" for row in failed), "Undiagnosed failure; no automatic transition"
            record("diagnosed-failures-before-resume.json", failed)
            dump = OUT / "before-native-resume.sql"
            with dump.open("xb") as destination:
                subprocess.run(["docker", "--host", HOST, "exec", "open-kritt-db", "sh", "-c",
                                'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --schema=workflows --no-owner --no-privileges'],
                               stdout=destination, check=True)
            record("pre-resume-seal.json", {"captured_at": now(), "path": dump.name,
                                           "sha256": hashlib.sha256(dump.read_bytes()).hexdigest(),
                                           "existing_results_rewritten": False})
            request = urllib.request.Request(URL, data=b'{"status":"pending"}',
                                             headers={"Content-Type": "application/json"}, method="PATCH")
            with urllib.request.urlopen(request, timeout=20) as response:
                result = json.load(response)
            resumed = True
            record("native-resume-receipt.json", {"resumed_at": now(), "method": "PATCH", "url": URL,
                                                  "body": {"status": "pending"}, "returned_scan_id": result.get("id"),
                                                  "returned_status": result.get("status"),
                                                  "preserved_pre_resume_dump": dump.name,
                                                  "direct_database_mutation": False, "new_scan_created": False})
        elif scan["status"] in ["failed", "paused", "stopped"] and summary.get("activeJobCount") == 0:
            record("needs-operational-diagnosis.json", safe)
    except Exception as error:
        # Preserve diagnostics; an operational error does not terminate the lane.
        with (OUT / "operational-errors.jsonl").open("a") as stream:
            stream.write(json.dumps({"observed_at": now(), "error": str(error)}) + "\n")
    time.sleep(20)
