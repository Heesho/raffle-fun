"""Extract (and whitespace-compress) the raw Slither function-summary rows for selected in-scope functions."""
import re, sys
txt = open(sys.argv[1]).read().splitlines()
want = sys.argv[2].split(",")
rows, cur, section = [], None, None
for line in txt:
    m = re.match(r"^Contract (\w+)$", line)
    if m: section = m.group(1); continue
    if line.startswith("+"):
        if cur: rows.append(cur); cur = None
        continue
    if not line.startswith("|"): continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if cells and cells[0] and not cells[0].startswith("Function") and not cells[0].startswith("Modifiers"):
        if cur: rows.append(cur)
        cur = [section] + cells
    elif cur and cells and not cells[0]:
        for i, c in enumerate(cells[1:], start=2):
            if i < len(cur) and c: cur[i] = (cur[i] + " " + c).strip()
if cur: rows.append(cur)
best = {}
for r in rows:
    name = r[1].split("(")[0]
    key = (r[0], name)
    if name in want and len(" ".join(r)) > len(" ".join(best.get(key, []))):
        best[key] = r
print("| Contract | Function | Visibility | Modifiers | Read | Write | Internal Calls | External Calls | Cyclomatic Complexity |")
print("|---|---|---|---|---|---|---|---|---|")
for key in sorted(best, key=lambda k: (k[0], want.index(k[1]))):
    r = best[key]
    print("| " + " | ".join(c.replace("|", "\\|") for c in r) + " |")
