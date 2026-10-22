# Generated scratch helper (S6 attempt-02): parse raw Slither printer outputs (function-summary text table,
# vars-and-auth JSON) into compact per-contract tables (JSON + Markdown) for the production contracts.
# Inputs are the preserved raw printer files; nothing here re-runs Slither.
import json
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
PROD = ("Raffle", "RaffleFactory", "IRaffle", "IRaffleFactory", "RaffleConstants")


def parse_function_summary(path):
    text = ANSI.sub("", open(path, encoding="utf-8").read())
    contracts = {}
    current = None
    header = None
    for line in text.splitlines():
        m = re.match(r"^Contract (\w+)$", line)
        if m:
            current = m.group(1)
            contracts[current] = {"functions": [], "modifiers": []}
            header = None
            continue
        if current is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and cells[0] in ("Function", "Modifiers"):
            header = cells
            continue
        if header is None or len(cells) != len(header):
            continue
        row = dict(zip(header, cells))
        key = "functions" if header[0] == "Function" else "modifiers"
        contracts[current][key].append(row)
    return contracts


def parse_vars_and_auth(path):
    d = json.load(open(path, encoding="utf-8"))
    out = {}
    for el in d["results"]["printers"][0]["elements"]:
        name = el["name"]["name"]
        content = el["name"]["content"]
        rows = [dict(zip(content["fields_names"], r)) for r in content["rows"]]
        out[name] = rows
    return out


def main(fs_path, va_path, out_json, out_md):
    fs = parse_function_summary(fs_path)
    va = parse_vars_and_auth(va_path)
    result = {"function_summary": {c: fs.get(c) for c in PROD}, "vars_and_auth": {c: va.get(c) for c in PROD}}
    json.dump(result, open(out_json, "w"), indent=1)
    md = ["# Parsed Slither printer tables for the five production files (derived from raw printer outputs)", ""]
    for c in PROD:
        f = fs.get(c, {"functions": [], "modifiers": []})
        md.append(f"## {c} — function-summary ({len(f['functions'])} rows incl. inherited)")
        md.append("")
        md.append("| Function | Visibility | Modifiers | Writes | External calls | CC |")
        md.append("|---|---|---|---|---|---|")
        for r in f["functions"]:
            ext = r.get("External Calls", "")
            ext_short = ";".join(sorted(set(re.findall(r"HIGH_LEVEL_CALL, dest:([^,]+), function:([^,'\]]+)", ext) and
                                         [f"{a.strip()}.{b.strip()}" for a, b in
                                          re.findall(r"HIGH_LEVEL_CALL, dest:([^,]+), function:([^,'\]]+)", ext)] or [])))
            if "LOW_LEVEL_CALL" in ext:
                ext_short = (ext_short + ";" if ext_short else "") + "LOW_LEVEL_CALL"
            md.append("| {} | {} | {} | {} | {} | {} |".format(
                r.get("Function"), r.get("Visibility"), r.get("Modifiers"), r.get("Write"), ext_short or "[]",
                r.get("Cyclomatic Complexity")))
        md.append("")
        rows = va.get(c) or []
        md.append(f"## {c} — vars-and-auth ({len(rows)} rows incl. inherited)")
        md.append("")
        md.append("| Function | State variables written | Conditions on msg.sender |")
        md.append("|---|---|---|")
        for r in rows:
            md.append("| {} | {} | {} |".format(r.get("Function"), r.get("State variables written"),
                                               r.get("Conditions on msg.sender")))
        md.append("")
    open(out_md, "w").write("\n".join(md) + "\n")
    for c in PROD:
        f = fs.get(c, {"functions": []})
        print(c, "function rows:", len(f["functions"]), "vars-and-auth rows:", len(va.get(c) or []))


if __name__ == "__main__":
    main(*sys.argv[1:5])
