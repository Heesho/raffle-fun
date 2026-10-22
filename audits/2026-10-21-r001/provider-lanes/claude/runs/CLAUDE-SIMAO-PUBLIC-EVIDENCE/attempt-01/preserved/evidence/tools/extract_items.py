"""Mechanical extractor for Turn 6 (dedup + completeness gate).

Reads raw lens outputs (lens-N-output.md), finds every FINDING / LEAD header line in the
shared-rules format, and emits a JSON inventory plus the unique (Contract, function) set.
It parses text only; it makes no security judgement.

Usage: python3 -I extract_items.py <raw_dir> <out_json>
"""
import json
import re
import sys
from pathlib import Path

HEADER = re.compile(
    r"^\s*[`*>\-]*\s*(?P<kind>FINDING|LEAD)\s*\|\s*contract:\s*(?P<contract>[^|]+?)\s*\|\s*"
    r"function:\s*(?P<function>[^|]+?)\s*\|\s*bug_class:\s*(?P<bug_class>[^|]+?)\s*\|\s*"
    r"group_key:\s*(?P<group_key>.+?)\s*[`*]*\s*$"
)
FIELD = re.compile(r"^\s*(root_cause|internal_pre|external_pre|impact|mitigation|smell|unverified|description):\s*(.*)$")


def parse(path: Path):
    lens = re.search(r"lens-(\d+)-output", path.name)
    lens_no = int(lens.group(1)) if lens else None
    items = []
    current = None
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        m = HEADER.match(line)
        if m:
            current = {k: v.strip() for k, v in m.groupdict().items()}
            current.update({"lens": lens_no, "line": lineno, "fields": {}})
            items.append(current)
            continue
        if current is not None:
            f = FIELD.match(line)
            if f and f.group(1) not in current["fields"]:
                current["fields"][f.group(1)] = f.group(2).strip()
    return items


def main():
    raw_dir, out_json = Path(sys.argv[1]), Path(sys.argv[2])
    files = sorted(raw_dir.glob("lens-*-output.md"), key=lambda p: int(re.search(r"lens-(\d+)", p.name).group(1)))
    inventory = []
    for p in files:
        inventory.extend(parse(p))
    pairs = sorted({(i["contract"], i["function"]) for i in inventory})
    summary = {
        "files": [p.name for p in files],
        "counts": {
            "FINDING": sum(1 for i in inventory if i["kind"] == "FINDING"),
            "LEAD": sum(1 for i in inventory if i["kind"] == "LEAD"),
            "per_lens": {str(n): sum(1 for i in inventory if i["lens"] == n) for n in sorted({i["lens"] for i in inventory})},
        },
        "unique_contract_function": [list(p) for p in pairs],
        "items": inventory,
    }
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"files={len(files)} FINDING={summary['counts']['FINDING']} LEAD={summary['counts']['LEAD']} unique(C,f)={len(pairs)}")
    for i in inventory:
        print(f"L{i['lens']:>2} {i['kind']:<7} {i['contract']} | {i['function']} | {i['bug_class']}")


if __name__ == "__main__":
    main()
