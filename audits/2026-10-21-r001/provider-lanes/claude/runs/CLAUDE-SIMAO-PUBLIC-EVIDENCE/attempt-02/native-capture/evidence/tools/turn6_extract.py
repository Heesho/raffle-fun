"""Attempt-02 mechanical extractor for native Simao Turn 6 (dedup input + completeness gate).

Parses raw lens outputs (lens-N-output.md) as text. For every FINDING / LEAD header line in the
shared-rules.md format it captures the verbatim block (header line through the end of the block), the
header fields, and the first line of each named field. It makes no security judgement.

Block end: the next FINDING/LEAD header, a closing ``` fence, a '---' rule, or a markdown heading.

Usage: python3 -I turn6_extract.py <raw_dir> <out_json>
"""
import hashlib
import json
import re
import sys
from pathlib import Path

HEADER = re.compile(
    r"^\s*[`*>\-]*\s*(?P<kind>FINDING|LEAD)\s*\|\s*contract:\s*(?P<contract>[^|]+?)\s*\|\s*"
    r"function:\s*(?P<function>[^|]+?)\s*\|\s*bug_class:\s*(?P<bug_class>[^|]+?)\s*\|\s*"
    r"group_key:\s*(?P<group_key>.+?)\s*[`*]*\s*$"
)
FIELD = re.compile(
    r"^\s*(root_cause|internal_pre|external_pre|path|impact|mitigation|smell|unverified|description):\s*(.*)$"
)
END = re.compile(r"^\s*(```|---\s*$|#{1,6}\s)")


def parse(path: Path):
    lens = int(re.search(r"lens-(\d+)-output", path.name).group(1))
    lines = path.read_text(encoding="utf-8").splitlines()
    items = []
    i = 0
    while i < len(lines):
        m = HEADER.match(lines[i])
        if not m:
            i += 1
            continue
        start = i
        j = i + 1
        while j < len(lines) and not HEADER.match(lines[j]) and not END.match(lines[j]):
            j += 1
        block = lines[start:j]
        fields = {}
        for line in block[1:]:
            f = FIELD.match(line)
            if f and f.group(1) not in fields:
                fields[f.group(1)] = f.group(2).strip()
        item = {k: v.strip() for k, v in m.groupdict().items()}
        item.update({
            "lens": lens,
            "file": path.name,
            "line_start": start + 1,
            "line_end": j,
            "fields": fields,
            "block": "\n".join(block),
        })
        items.append(item)
        i = j
    return items


def main():
    raw_dir, out_json = Path(sys.argv[1]), Path(sys.argv[2])
    files = sorted(raw_dir.glob("lens-*-output.md"), key=lambda p: int(re.search(r"lens-(\d+)", p.name).group(1)))
    inventory = []
    file_meta = []
    for p in files:
        file_meta.append({"file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
        inventory.extend(parse(p))
    for n, item in enumerate(inventory, 1):
        item["raw_id"] = f"R{n:02d}"
    pairs = sorted({(i["contract"], i["function"]) for i in inventory})
    summary = {
        "files": file_meta,
        "counts": {
            "FINDING": sum(1 for i in inventory if i["kind"] == "FINDING"),
            "LEAD": sum(1 for i in inventory if i["kind"] == "LEAD"),
            "per_lens": {str(n): {"FINDING": sum(1 for i in inventory if i["lens"] == n and i["kind"] == "FINDING"),
                                  "LEAD": sum(1 for i in inventory if i["lens"] == n and i["kind"] == "LEAD")}
                         for n in sorted({i["lens"] for i in inventory})},
        },
        "unique_contract_function": [list(p) for p in pairs],
        "items": inventory,
    }
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"files={len(files)} FINDING={summary['counts']['FINDING']} LEAD={summary['counts']['LEAD']} unique(C,f)={len(pairs)}")
    for i in inventory:
        print(f"{i['raw_id']} L{i['lens']:>2} {i['kind']:<7} {i['contract']} | {i['function']} | {i['bug_class']}  "
              f"[{i['file']}:{i['line_start']}-{i['line_end']}]")
    print("unique (Contract, function):")
    for c, f in pairs:
        print(f"  {c} | {f}")


if __name__ == "__main__":
    main()
