#!/usr/bin/env python3
"""Seal or read-only verify the completed, quiescent audit delivery package."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
EXCLUDED = {"DELIVERY-MANIFEST.json", "DELIVERY-SEAL.json"}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def inventory():
    result = {}
    for directory, subdirs, files in os.walk(ROOT, followlinks=False):
        base = Path(directory)
        names = files + [name for name in subdirs if (base / name).is_symlink()]
        for name in sorted(names):
            path = base / name
            relative = path.relative_to(ROOT).as_posix()
            if relative in EXCLUDED:
                continue
            before = path.lstat()
            if path.is_symlink():
                row = {"kind": "symlink", "target": os.readlink(path)}
            elif path.is_file():
                row = {"kind": "file", "bytes": before.st_size, "sha256": digest(path)}
            else:
                raise RuntimeError(f"Unsupported package object: {relative}")
            after = path.lstat()
            if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                raise RuntimeError(f"Package changed during hashing: {relative}")
            result[relative] = row
    return dict(sorted(result.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seal", action="store_true", help="Create a final seal once; refuses existing seals and unfinished lanes")
    args = parser.parse_args()
    manifest_path = ROOT / "DELIVERY-MANIFEST.json"
    seal_path = ROOT / "DELIVERY-SEAL.json"
    if args.seal:
        if manifest_path.exists() or seal_path.exists():
            raise RuntimeError("Delivery already sealed; preserve the original and use a new named addendum")
        run = subprocess.run([sys.executable, str(ROOT / "verify-delivery.py"), "--require-terminal"], capture_output=True, text=True)
        if run.returncode:
            sys.stdout.write(run.stdout)
            sys.stderr.write(run.stderr)
            raise RuntimeError("Delivery integrity or required terminal-state check failed")
        (ROOT / "FINAL-VERIFICATION.json").write_text(run.stdout)
        rows = inventory()
        # A second walk catches additions, removals and concurrent log changes.
        if rows != inventory():
            raise RuntimeError("Package is still changing; quiesce owned writers before sealing")
        manifest = {
            "schema": "raffle-audit-delivery-manifest/v1",
            "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "excluded_self_references": sorted(EXCLUDED),
            "symlink_policy": "Link text is bound; external target bytes are not embedded by this manifest. Frozen inputs and separately retained artifacts have their own manifests.",
            "files": rows,
        }
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        seal = {
            "schema": "raffle-audit-delivery-seal/v1",
            "sealed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "target": json.loads((ROOT / "freeze.json").read_text())["head"],
            "manifest": manifest_path.name,
            "manifest_sha256": digest(manifest_path),
            "report": "FINAL-AUDIT-REPORT.md",
            "report_sha256": digest(ROOT / "FINAL-AUDIT-REPORT.md"),
            "verification": "FINAL-VERIFICATION.json",
            "verification_sha256": digest(ROOT / "FINAL-VERIFICATION.json"),
            "regular_files": sum(row["kind"] == "file" for row in rows.values()),
            "symlinks": sum(row["kind"] == "symlink" for row in rows.values()),
            "interpretation": "Tamper-evident byte binding, not WORM storage, external auditor certification or release approval.",
        }
        seal_path.write_text(json.dumps(seal, indent=2) + "\n")
        print(json.dumps(seal, indent=2))
    else:
        seal = json.loads(seal_path.read_text())
        if digest(manifest_path) != seal["manifest_sha256"]:
            raise RuntimeError("Delivery manifest hash mismatch")
        expected = json.loads(manifest_path.read_text())["files"]
        actual = inventory()
        missing = sorted(set(expected) - set(actual))
        added = sorted(set(actual) - set(expected))
        changed = sorted(name for name in expected.keys() & actual.keys() if expected[name] != actual[name])
        result = {"ok": not (missing or added or changed), "checked_objects": len(expected), "missing": missing, "added": added, "changed": changed}
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
