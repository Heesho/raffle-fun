#!/usr/bin/env python3
"""Read-only verification of receipt bindings, without interpreting findings.

API: verify_register(path, extra_seals={absolute_path: expected_sha256}) returns
a JSON-serializable result, including ``verified_inventory`` (path -> hash).
The register and the local reconciliation seals are explicitly reported trust
roots, not independently authenticated signatures. Unknown schemas and absent
bindings remain gaps; no path is searched for by matching its current hash.
The CLI writes JSON to stdout only and exits 1 for any error or unresolved gap.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
from pathlib import Path
from typing import Any

HEX = re.compile(r"^[0-9a-fA-F]{64}$")
CHECKSUM = re.compile(r"^([0-9a-fA-F]{64})[ \t]+[ *]?(.+)$")
CONTAINERS = {
    "artifacts", "files", "sealedFiles", "sealedArtifacts", "nativeOriginals",
    "sha256", "hashes", "original_files_unchanged", "prior_artifacts_unchanged",
    "original_seals_unchanged", "input_hashes", "verified_new_source_reports",
    "native_record_verifications",
}
RECEIPTS = (
    "completion_receipt", "native_completion_receipt",
    "native_artifact_preservation_receipt", "additional_qualification_receipts",
)
PRIOR_SEALS = (
    "RECONCILIATION-SEAL.json", "ADDENDUM-SEAL.json",
    "PASHOV-SUPPLEMENT-SEAL.json", "HISTORICAL-COMPARISON-SEAL.json",
)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical(path: str | Path, base: Path) -> Path:
    p = Path(path)
    return (p if p.is_absolute() else base / p).resolve()


def fingerprint(path: Path) -> tuple[int, ...]:
    s = path.stat()
    return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)


class ReceiptVerifier:
    def __init__(self, audit_root: Path) -> None:
        self.audit_root = audit_root
        self.metadata_bases: dict[str, Path] = {}
        self.explicit_bindings: dict[str, dict[str, Any]] = {}
        self.binding_resolutions: dict[str, dict[str, Any]] = {}
        self.active_metadata: Path | None = None
        self.inventory: dict[str, str] = {}
        self.bindings: dict[str, list[str]] = {}
        self.errors: list[dict[str, Any]] = []
        self.gaps: list[dict[str, Any]] = []
        self.diagnostics: list[dict[str, Any]] = []
        self.roots: dict[str, dict[str, str]] = {}
        self.historical_stream_qualifications: list[dict[str, Any]] = []
        self.pending_pathless: list[tuple[Path, dict[str, str]]] = []
        self.verified_line_attributions = 0
        self.verified_pointer_attributions = 0
        self.parsed: set[str] = set()
        self.stats: dict[str, tuple[int, ...]] = {}
        self.queue: list[tuple[Path, str]] = []
        self._issues: set[tuple[str, str, str]] = set()

    def issue(self, kind: str, code: str, path: Path | str, detail: str) -> None:
        marker = (kind, code, str(path) + detail)
        if marker not in self._issues:
            self._issues.add(marker)
            getattr(self, kind).append({"code": code, "path": str(path), "detail": detail})

    def bind(self, path: Path, expected: Any, origin: str, *, parse: bool = False,
             unresolved_relative: bool = False) -> bool:
        path = path.resolve()
        key = str(path)
        if not isinstance(expected, str) or not HEX.fullmatch(expected):
            self.issue("gaps", "invalid_hash_binding", path, origin)
            return False
        expected = expected.lower()
        if key in self.inventory and self.inventory[key] != expected:
            self.issue("errors", "conflicting_hash_bindings", path, origin)
            return False
        try:
            before = fingerprint(path)
            actual = self.inventory.get(key) if self.stats.get(key) == before else digest(path)
            after = fingerprint(path)
        except (OSError, ValueError) as e:
            if isinstance(e, FileNotFoundError) and unresolved_relative:
                self.issue("gaps", "relative_binding_unresolved", path,
                           f"{origin}; declared relative path does not resolve at the metadata base; an explicit original/copy base binding is required")
            else:
                self.issue("errors", "unreadable_bound_artifact", path, f"{origin}: {type(e).__name__}: {e}")
            return False
        if before != after:
            self.issue("errors", "artifact_changed_during_read", path, origin)
            return False
        if actual != expected:
            self.issue("errors", "hash_mismatch", path, f"{origin}; expected={expected}; actual={actual}")
            return False
        self.inventory[key] = expected
        self.stats[key] = after
        self.bindings.setdefault(key, [])
        if origin not in self.bindings[key]:
            self.bindings[key].append(origin)
        if parse or self.is_metadata(path):
            self.queue.append((path, origin))
        return True

    @staticmethod
    def is_metadata(path: Path) -> bool:
        name = path.name.lower()
        return (path.suffix.lower() == ".sha256" or
                path.suffix.lower() == ".json" and
                (name.endswith("seal.json") or "manifest" in name or
                 name in {"capture.json", "source-hashes.json", "stage-seals.json"} or
                 name == "openai-tob-01-raw-log-binding-diagnostic.json" or
                 name.endswith("receipt-verification.json")))

    def root(self, path: Path, expected: str | None, basis: str) -> None:
        path = path.resolve()
        try:
            h = expected if expected is not None else digest(path)
        except OSError as e:
            self.issue("errors", "unreadable_trust_root", path, str(e))
            return
        self.roots[str(path)] = {"sha256": h, "basis": basis}
        self.bind(path, h, "trust-root:" + basis, parse=True)

    def bind_reference(self, name: str, expected: Any, base: Path, label: str) -> bool:
        """Apply only caller-supplied, hash-bound per-manifest resolutions."""
        manifest = str(self.active_metadata) if self.active_metadata else ""
        spec = self.explicit_bindings.get(manifest)
        resolution = spec.get("bindings", {}).get(name) if spec else None
        if resolution:
            if (self.inventory.get(manifest) != spec.get("sha256") or
                    resolution.get("sha256") != expected or
                    not Path(resolution.get("resolved_path", "")).is_absolute()):
                self.issue("errors", "explicit_binding_ledger_mismatch", manifest, label + "/" + name)
                return False
            resolved = Path(resolution["resolved_path"])
            ok = self.bind(resolved, expected, label + "; explicit-ledger:" + resolution["resolution_type"])
            key = manifest + "#" + name
            self.binding_resolutions[key] = {"manifest": manifest, "declared_path": name,
                **resolution, "verified": ok,
                "default_metadata_relative_path": str(canonical(name, base)),
                "original_and_alternative_paths_not_conflated": True}
            return ok
        return self.bind(canonical(name, base), expected, label,
                         unresolved_relative=not Path(name).is_absolute())

    def record(self, record: dict[str, Any], base: Path, label: str) -> int:
        count = 0
        if isinstance(record.get("path"), str) and "sha256" in record:
            self.bind_reference(record["path"], record["sha256"], base, label)
            count += 1
        # These paired path/hash fields are actual seal schemas, not inferred filenames.
        for path_key, hash_key in (
            ("artifact", "sha256"), ("report", "sha256"),
            ("report_path", "report_sha256"), ("firstPass", "firstPassSha256"),
            ("seal", "seal_sha256"), ("seal_path", "seal_sha256"),
            ("results", "results_sha256"), ("hash_manifest", "hash_manifest_sha256"),
            ("report", "report_sha256"), ("manifest", "manifest_sha256"),
            ("original", "sha256"), ("copy", "copy_sha256"),
            ("templateSource", "templateSourceSha256"),
            ("absolutePath", "sha256"),
            ("bundle", "bundleSha256"),
        ):
            if isinstance(record.get(path_key), str) and hash_key in record:
                self.bind_reference(record[path_key], record[hash_key], base, label + "/" + path_key)
                count += 1
        return count

    def container(self, value: Any, base: Path, label: str) -> int:
        count = 0
        if isinstance(value, list):
            for i, entry in enumerate(value):
                if isinstance(entry, dict):
                    n = self.record(entry, base, f"{label}/{i}")
                    if not n:
                        self.issue("gaps", "unrecognized_artifact_record", base, f"{label}/{i}; keys={list(entry)}")
                    count += n
                else:
                    self.issue("gaps", "unrecognized_artifact_record", base, f"{label}/{i}")
        elif isinstance(value, dict):
            for name, entry in value.items():
                h = entry.get("sha256") if isinstance(entry, dict) else entry
                if isinstance(h, str) and HEX.fullmatch(h):
                    entry_base = self.audit_root if isinstance(entry, dict) and entry.get("binding") == "audit-root-relative" else base
                    self.bind_reference(name, h, entry_base, label + "/" + name)
                    count += 1
                else:
                    self.issue("gaps", "unrecognized_artifact_mapping", base, label + "/" + name)
        else:
            self.issue("gaps", "unrecognized_artifact_container", base, label)
        return count

    def parse_json(self, path: Path, obj: Any) -> None:
        base = self.metadata_bases.get(str(path), path.parent)
        count = 0
        if isinstance(obj, list):
            count += self.container(obj, base, str(path))
        elif isinstance(obj, dict):
            if path.name == "manifest-scope.json" and obj.get("purpose") == "Stable final audit artifact manifest" and isinstance(obj.get("included"), list) and isinstance(obj.get("excluded"), list):
                self.diagnostics.append({"path": str(path), "kind": "manifest_scope_description_only", "sha256": self.inventory[str(path)], "contains_no_artifact_hash_bindings": True})
                return
            if "integrity-manifest" in str(obj.get("schema", "")) and obj.get("auditRoot") == str(self.audit_root):
                # Coordinator manifests explicitly declare their audit root and
                # nest records in target/leaf/receipt groups. Preserve each
                # literal record, including any explicit qualified copy mapping.
                def visit(value: Any, label: str) -> int:
                    n = 0
                    if isinstance(value, dict):
                        n += self.record(value, self.audit_root, label)
                        for key, child in value.items():
                            if isinstance(child, (dict, list)):
                                n += visit(child, label + "/" + key)
                    elif isinstance(value, list):
                        for i, child in enumerate(value):
                            n += visit(child, label + "/" + str(i))
                    return n
                count += visit(obj, str(path))
                if not count:
                    self.issue("gaps", "unresolved_metadata_schema", path, "Coordinator manifest has no supported bindings")
                return
            if path.name == "OPENAI-TOB-01-RAW-LOG-BINDING-DIAGNOSTIC.json":
                self.verify_recovered_streams(path, obj)
                return
            # Verified inventories are deliberately narrower than generic recursion.
            # Wrong-cwd runtime_source_checks are diagnostics, not file requirements.
            if path.name.endswith("RECEIPT-VERIFICATION.json"):
                for field in ("hash_records", "records"):
                    for i, r in enumerate(obj.get(field, [])):
                        record_path = r.get("effective_path", r.get("path")) if isinstance(r, dict) else None
                        if not isinstance(r, dict) or not isinstance(record_path, str):
                            self.issue("gaps", "invalid_verification_record", path, f"{field}/{i}")
                            continue
                        expected = r.get("expected_sha256", r.get("sha256"))
                        recorded = r.get("actual_sha256", r.get("actual"))
                        if ("actual_sha256" in r or "actual" in r) and recorded != expected:
                            self.issue("errors", "inventory_record_did_not_verify", path, f"{field}/{i}")
                        self.bind(canonical(record_path, base), expected, f"{path}#{field}/{i}")
                        if r.get("effective_path") and r.get("path") != record_path:
                            self.diagnostics.append({"path": str(path), "kind": "explicit_effective_copy_in_verification_inventory", "record": r, "literal_manifest_bindings_still_checked_independently": True})
                        count += 1
                if obj.get("runtime_source_mismatches"):
                    self.diagnostics.append({"path": str(path), "kind": "retained_runtime_diagnostic",
                                             "records": obj["runtime_source_mismatches"],
                                             "required_artifacts": False})
                if obj.get("errors"):
                    self.issue("errors", "verification_inventory_contains_errors", path, "Inventory errors are nonempty")
                count += self.record(obj, base, str(path))
            else:
                count += self.record(obj, base, str(path))
                if path.name == "stage-seals.json":
                    for stage, embedded in obj.items():
                        if isinstance(embedded, dict) and isinstance(embedded.get("scope"), str) and "files" in embedded:
                            count += self.container(embedded["files"], canonical(embedded["scope"], base), str(path) + "#" + stage)
                for key, value in obj.items():
                    if key in CONTAINERS and isinstance(value, (dict, list)):
                        count += self.container(value, base, str(path) + "#" + key)
                    elif isinstance(value, dict):
                        count += self.record(value, base, str(path) + "#" + key)
                        # Some schemas nest the manifest path/hash one level down.
                        for subkey, subvalue in value.items():
                            if isinstance(subvalue, dict):
                                count += self.record(subvalue, base, str(path) + "#" + key + "/" + subkey)
                    elif isinstance(value, list) and key in {"source_files", "inputs"}:
                        count += self.container(value, base, str(path) + "#" + key)
                if "source_sha256" in obj:
                    source_root = obj.get("clean_context_root", obj.get("source_root"))
                    if isinstance(source_root, str):
                        count += self.container(obj["source_sha256"], canonical(source_root, base), str(path) + "#source_sha256")
                    else:
                        self.issue("gaps", "source_hashes_without_root", path, "source_sha256 has no declared root")
                if isinstance(obj.get("sourceManifest"), dict) and isinstance(obj.get("stageWorkspace"), str):
                    count += self.container(obj["sourceManifest"], canonical(obj["stageWorkspace"], base), str(path) + "#sourceManifest")
                if obj.get("method") == "disclosed-direct-native-High-leaf-runtime-for-pinned-model-agnostic-method" and isinstance(obj.get("leaves"), list):
                    for i, leaf in enumerate(obj["leaves"]):
                        count += self.record(leaf, base, f"{path}#leaves/{i}")
                        count += self.container(leaf.get("parts", []), base, f"{path}#leaves/{i}/parts")
                        if isinstance(leaf.get("workspace"), str) and isinstance(leaf.get("inputHashesBefore"), dict):
                            count += self.container(leaf["inputHashesBefore"], canonical(leaf["workspace"], base), f"{path}#leaves/{i}/inputHashesBefore")
                # A plain JSON path->hash inventory is supported only as a manifest.
                if not count and obj and all(isinstance(v, str) and HEX.fullmatch(v) for v in obj.values()):
                    count += self.container(obj, base, str(path))
        else:
            self.issue("gaps", "invalid_metadata_document", path, type(obj).__name__)
        if not count:
            if isinstance(obj, dict) and all(HEX.fullmatch(str(obj.get(k, ""))) for k in ("report_sha256", "manifest_sha256")):
                self.pending_pathless.append((path, {k: obj[k] for k in ("report_sha256", "manifest_sha256")}))
            else:
                self.issue("gaps", "unresolved_metadata_schema", path,
                           "No supported path/hash bindings; keys=" + str(list(obj) if isinstance(obj, dict) else []))

    def resolve_pathless_from_bound_inventories(self) -> None:
        for path, fields in self.pending_pathless:
            resolved: dict[str, dict[str, str]] = {}
            for field, expected in fields.items():
                candidates = [name for name, h in self.inventory.items()
                              if h == expected and Path(name).is_relative_to(path.parent)
                              and any("RECEIPT-VERIFICATION.json#" in origin or "FINAL-MANIFEST.sha256:" in origin or "STAGE-MANIFEST.sha256:" in origin for origin in self.bindings[name])]
                if len(candidates) != 1:
                    self.issue("gaps", "pathless_binding_unresolved", path,
                               f"{field}; {len(candidates)} matching paths in already verified, sealed receipt inventories")
                else:
                    resolved[field] = {"path": candidates[0], "sha256": expected}
            self.diagnostics.append({"path": str(path), "kind": "native_pathless_schema",
                                     "limitation": "Native seal supplies digests without paths; identities come from an already hash-bound explicit receipt inventory or native final/stage checksum manifest",
                                     "inventory_resolutions": resolved})

    def verify_recovered_streams(self, path: Path, obj: dict[str, Any]) -> None:
        """Report the two exact historical prefix recoveries; never waive errors."""
        for r in obj.get("records", []):
            original = canonical(r["original_path"], path.parent)
            native_seal = canonical(r["native_seal_path"], path.parent)
            prefix = canonical(r["recovered_prefix_path"], path.parent)
            if original.parent != self.audit_root / "runs/OPENAI-TOB/attempt-01" or original.name not in {"events.jsonl", "stderr.txt"}:
                self.issue("errors", "unrecognized_stream_exception", original, str(path))
                continue
            if not self.bind(native_seal, obj.get("native_seal_sha256"), str(path) + "#native_seal"):
                continue
            native = json.loads(native_seal.read_bytes())
            binding = [x for x in native.get("files", []) if x.get("path") == original.name]
            if len(binding) != 1 or binding[0].get("bytes") != r.get("sealed_bytes") or binding[0].get("sha256") != r.get("sealed_sha256"):
                self.issue("errors", "recovered_prefix_native_binding_mismatch", original, str(path))
                continue
            if self.inventory.get(str(prefix)) != r.get("sealed_sha256") or r.get("prefix_sha256") != r.get("sealed_sha256"):
                self.issue("errors", "recovered_prefix_not_bound", prefix, str(path))
                continue
            raw = original.read_bytes()
            n = r["sealed_bytes"]
            if len(raw) != r.get("current_bytes") or hashlib.sha256(raw).hexdigest() != r.get("current_sha256") or hashlib.sha256(raw[:n]).hexdigest() != r["sealed_sha256"]:
                self.issue("errors", "recovered_prefix_current_stream_mismatch", original, str(path))
                continue
            self.historical_stream_qualifications.append({
                "original_path": str(original), "original_whole_file_error_retained": True,
                "native_seal_path": str(native_seal), "native_sealed_at": native.get("sealed_at"),
                "sealed_bytes": n, "sealed_sha256": r["sealed_sha256"],
                "current_bytes": len(raw), "current_sha256": r["current_sha256"],
                "recovered_prefix_path": str(prefix), "prefix_independently_verified": True,
                "diagnostic_path": str(path), "diagnostic_sha256": self.inventory[str(path)],
                "causality": "No inference about why or when the bytes were appended",
            })

    def drain(self) -> None:
        while self.queue:
            path, origin = self.queue.pop(0)
            if str(path) in self.parsed:
                continue
            self.parsed.add(str(path))
            self.active_metadata = path
            try:
                raw = path.read_bytes()
            except OSError as e:
                self.issue("errors", "metadata_read_failed", path, str(e))
                continue
            if hashlib.sha256(raw).hexdigest() != self.inventory[str(path)]:
                self.issue("errors", "metadata_changed_before_parse", path, origin)
                continue
            if path.suffix.lower() == ".sha256":
                for i, line in enumerate(raw.decode("utf-8").splitlines(), 1):
                    if not line.strip():
                        continue
                    # Both aggregate first-pass checksums carry a timestamp.
                    if re.fullmatch(r"sealed_at [0-9T:.+Z-]+", line):
                        continue
                    line = re.sub(r"  sealed_at=[0-9T:.+Z-]+$", "", line)
                    m = CHECKSUM.fullmatch(line)
                    if not m:
                        self.issue("gaps", "unrecognized_checksum_line", path, f"line {i}")
                    else:
                        base = self.metadata_bases.get(str(path), path.parent)
                        self.bind_reference(m[2], m[1], base, f"{path}:{i}")
                continue
            try:
                self.parse_json(path, json.loads(raw))
            except (OSError, KeyError, ValueError, TypeError) as e:
                self.issue("gaps", "unparseable_metadata", path, f"{type(e).__name__}: {e}")

    def require_receipts(self, reports: list[dict[str, Any]], base: Path) -> int:
        checked = 0
        for report in reports:
            for field in RECEIPTS:
                value = report.get(field)
                values = value if isinstance(value, list) else ([value] if value is not None else [])
                for value in values:
                    if not isinstance(value, str):
                        self.issue("gaps", "invalid_receipt_reference", base, str(report.get("report_key")) + "/" + field)
                        continue
                    p = canonical(value, base)
                    if str(p) not in self.inventory:
                        self.issue("gaps", "receipt_not_hash_bound", p, str(report.get("report_key")) + "/" + field)
                    else:
                        checked += 1
        return checked

    def verify_attributions(self, register: dict[str, Any], base: Path) -> int:
        checked = 0
        lines: dict[str, int] = {}
        for f in register.get("findings", []):
            for i, a in enumerate(f.get("original_attributions", [])):
                label = f"{f.get('id', '?')}/original_attributions/{i}"
                if not isinstance(a.get("report_path"), str):
                    self.issue("gaps", "attribution_without_report_path", base, label)
                    continue
                p = canonical(a["report_path"], base)
                key = str(p)
                if key not in self.inventory:
                    self.issue("gaps", "attribution_not_hash_bound", p, label)
                    continue
                line = a.get("report_line")
                if "report_line" not in a:
                    pointer = a.get("json_pointer")
                    if isinstance(pointer, str) and pointer.startswith("/"):
                        raw = p.read_bytes()
                        if hashlib.sha256(raw).hexdigest() != self.inventory[key]:
                            self.issue("errors", "attribution_changed_before_pointer_check", p, label)
                            continue
                        try:
                            node = json.loads(raw)
                            for part in pointer[1:].split("/"):
                                if re.search(r"~(?![01])", part):
                                    raise ValueError("Invalid JSON-pointer escape")
                                part = part.replace("~1", "/").replace("~0", "~")
                                if isinstance(node, list):
                                    if not re.fullmatch(r"0|[1-9][0-9]*", part):
                                        raise ValueError("Invalid JSON-pointer array index")
                                    node = node[int(part)]
                                elif isinstance(node, dict):
                                    node = node[part]
                                else:
                                    raise ValueError("Pointer descends into a scalar")
                            checked += 1
                            self.verified_pointer_attributions += 1
                        except (ValueError, KeyError, IndexError, TypeError):
                            self.issue("errors", "invalid_attribution_json_pointer", p, label + "; " + pointer)
                    else:
                        self.issue("gaps", "non_line_attribution_locator", p, label + "; available locator keys=" + str([k for k in ("json_pointer", "report_lines", "original_id") if k in a]))
                    continue
                if type(line) is not int or line < 1:
                    self.issue("errors", "invalid_attribution_line", p, f"{label}: {line!r}")
                    continue
                if key not in lines:
                    raw = p.read_bytes()
                    if hashlib.sha256(raw).hexdigest() != self.inventory[key]:
                        self.issue("errors", "attribution_changed_before_line_check", p, label)
                        continue
                    # Count bytes only. Finding prose is neither parsed nor returned.
                    lines[key] = len(raw.splitlines())
                if line > lines[key]:
                    self.issue("errors", "attribution_line_out_of_bounds", p, f"{label}: {line} > {lines[key]}")
                else:
                    checked += 1
                    self.verified_line_attributions += 1
        return checked


def verify_register(register_path: str | Path, *, extra_seals: dict[str, str] | None = None,
                    binding_ledger: str | Path | None = None,
                    binding_ledger_sha256: str | None = None) -> dict[str, Any]:
    p = Path(register_path).resolve()
    d = p.parent
    v = ReceiptVerifier(d.parent.parent)
    register_bytes = p.read_bytes()
    register_hash = hashlib.sha256(register_bytes).hexdigest()
    register = json.loads(register_bytes)
    reports = register["source_reports"]
    ledger_binding = None
    if binding_ledger is not None:
        ledger_path = Path(binding_ledger).resolve()
        ledger_bytes = ledger_path.read_bytes()
        ledger_hash = hashlib.sha256(ledger_bytes).hexdigest()
        if binding_ledger_sha256 is not None and ledger_hash != binding_ledger_sha256:
            v.issue("errors", "binding_ledger_hash_mismatch", ledger_path,
                    f"expected={binding_ledger_sha256}; actual={ledger_hash}")
        else:
            ledger = json.loads(ledger_bytes)
            if ledger.get("schema") != "explicit-metadata-bindings/v1" or not isinstance(ledger.get("metadata_files"), dict):
                v.issue("gaps", "unsupported_binding_ledger_schema", ledger_path, "Expected explicit-metadata-bindings/v1")
            else:
                v.explicit_bindings = ledger["metadata_files"]
                v.bind(ledger_path, ledger_hash, "caller-supplied metadata resolution ledger")
                ledger_binding = {"path": str(ledger_path), "sha256": ledger_hash,
                                  "caller_supplied_expected_hash": binding_ledger_sha256 is not None}
    for r in reports:
        if r.get("adopted_native_seal_copy") and r.get("seal"):
            # Exact copies retain the native seal's relative-path base.
            copy = canonical(r["adopted_native_seal_copy"], d)
            v.metadata_bases[str(copy)] = canonical(r["seal"], d).parent
            v.bind(copy, r.get("seal_sha256"), str(p) + "#adopted_native_seal_copy", parse=True)
    for i, r in enumerate(reports):
        label = f"{p}#source_reports/{i}"
        for field, hash_field in (("path", "sha256"), ("seal", "seal_sha256")):
            if not isinstance(r.get(field), str):
                v.issue("gaps", "source_report_missing_binding", p, label + "/" + field)
                continue
            v.bind(canonical(r[field], d), r.get(hash_field), label + "/" + field, parse=field == "seal")
    # Existing reconciliation seals are explicit local trust roots. Hashes are
    # returned so callers can anchor them to an earlier external checkpoint.
    for name in PRIOR_SEALS:
        v.root(d.parent / name, None, "local reconciliation seal snapshot")
    for seal in sorted(d.glob("*RECONCILIATION-SEAL.json")):
        v.root(seal, None, "local late reconciliation seal snapshot")
    diagnostic = d / "OPENAI-TOB-01-RAW-LOG-BINDING-DIAGNOSTIC-SEAL.json"
    if diagnostic.is_file():
        v.root(diagnostic, None, "explicit historical raw-log diagnostic seal snapshot")
    # Explicit additional standalone receipt roots authorized by the owning
    # reconciliation agent. Their current hashes are captured, not represented
    # as hashes anchored by the older first-pass seal (which predates them).
    for r in reports:
        if r.get("report_key") == "GEMINI-OPENKRITT/native-engine-attempt-03":
            native_dir = canonical(r["seal"], d).parent
            for name in ("TOOL-SCOPE-SEAL.json", "SOURCE-AND-LIFECYCLE-SEAL.json"):
                v.root(native_dir / name, None, "explicit additional standalone receipt seal snapshot; not anchored by earlier first-pass seal")
    for name, h in (extra_seals or {}).items():
        v.root(canonical(name, d), h, "caller supplied seal hash")
    v.drain()
    v.resolve_pathless_from_bound_inventories()
    receipts = v.require_receipts(reports, d)
    attributions = v.verify_attributions(register, d)
    if digest(p) != register_hash:
        v.issue("errors", "register_changed_during_verification", p, "Retry against a quiescent snapshot")
    for name, before in v.stats.items():
        try:
            if fingerprint(Path(name)) != before:
                v.issue("errors", "artifact_changed_after_verification", name, "Retry against quiescent artifacts")
        except OSError as e:
            v.issue("errors", "artifact_disappeared_after_verification", name, str(e))
    for error in v.errors:
        if error["code"] == "hash_mismatch":
            expected = re.search(r"expected=([0-9a-f]{64});", error["detail"])
            if expected:
                error["verified_exact_byte_copies"] = [name for name, h in v.inventory.items()
                                                       if h == expected[1] and name != error["path"]]
                error["original_path_error_retained"] = True
    return {
        "ok": not v.errors and not v.gaps,
        "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "helper_path": str(Path(__file__).resolve()), "helper_sha256": digest(Path(__file__)),
        "register_path": str(p), "register_sha256": register_hash,
        "scope": "Byte integrity and attribution bounds only; no workflow, identity, finding, or target-semantic qualification",
        "trust_roots": v.roots,
        "explicit_binding_ledger": ledger_binding,
        "explicit_binding_resolutions": list(v.binding_resolutions.values()),
        "counts": {"source_reports": len(reports), "verified_paths": len(v.inventory),
                   "verified_source_report_hashes": sum(v.inventory.get(str(canonical(r['path'], d))) == r.get('sha256') for r in reports),
                   "verified_source_seal_hashes": sum(v.inventory.get(str(canonical(r['seal'], d))) == r.get('seal_sha256') for r in reports),
                   "parsed_metadata_files": len(v.parsed), "verified_receipt_references": receipts,
                   "verified_attributions": attributions, "verified_line_attributions": v.verified_line_attributions,
                   "verified_json_pointer_attributions": v.verified_pointer_attributions,
                   "errors": len(v.errors), "gaps": len(v.gaps)},
        "errors": v.errors, "gaps": v.gaps, "retained_diagnostics": v.diagnostics,
        "historical_stream_qualifications": v.historical_stream_qualifications,
        "verified_inventory": dict(sorted(v.inventory.items())),
        "binding_provenance": dict(sorted(v.bindings.items())),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--register", type=Path, default=Path(__file__).with_name("working-register.json"))
    parser.add_argument("--extra-seals", type=Path, help="JSON object of absolute seal paths to previously bound SHA256 values")
    parser.add_argument("--binding-ledger", type=Path, help="Explicit per-manifest path/copy resolution ledger")
    parser.add_argument("--binding-ledger-sha256", help="Expected SHA256 for the explicit binding ledger")
    parser.add_argument("--summary", action="store_true", help="Omit the large verified inventory and binding provenance")
    args = parser.parse_args()
    extra = json.loads(args.extra_seals.read_text()) if args.extra_seals else None
    result = verify_register(args.register, extra_seals=extra, binding_ledger=args.binding_ledger,
                             binding_ledger_sha256=args.binding_ledger_sha256)
    if args.summary:
        result.pop("verified_inventory")
        result.pop("binding_provenance")
    print(json.dumps(result, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
