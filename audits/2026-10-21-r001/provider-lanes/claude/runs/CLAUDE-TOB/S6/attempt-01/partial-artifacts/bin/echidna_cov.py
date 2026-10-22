"""Summarize Echidna txt coverage for the in-scope files: executed vs. executable-looking lines, list uncovered ones."""
import re, sys
path = sys.argv[1]
targets = ("packages/contracts/src/Raffle.sol", "packages/contracts/src/RaffleFactory.sol")
cur = None; data = {}
for line in open(path):
    line = line.rstrip("\n")
    if line.startswith("/"):
        cur = next((t for t in targets if line.endswith(t)), None)
        if cur: data[cur] = []
        continue
    if cur is None: continue
    m = re.match(r"\s*(\d+) \|\s*([^|]*)\|\s?(.*)$", line)
    if m: data[cur].append((int(m.group(1)), m.group(2).strip(), m.group(3)))
def executable(src):
    s = src.strip()
    if not s or s.startswith("//") or s.startswith("*") or s.startswith("/*"): return False
    if s in ("{", "}", ")", "});", ");", "})", "} else {", "else {", ") {", "{}") : return False
    if re.match(r"^(import|pragma|contract|library|interface|struct|enum|event|error|using|mapping|uint|int|address|bool|bytes|string|IERC|IRaffle|Status|TicketRange)\b", s) and not "=" in s and not s.startswith(("uint256 ", "uint128 ", "address ", "bool ")):
        return False
    if re.match(r"^(external|public|internal|private|view|pure|override|returns|nonReentrant|payable)\b", s): return False
    if re.match(r"^(function|constructor|receive|modifier)\b", s): return False
    if s.startswith("emit ") or s.startswith("revert ") or "revert " in s: return True
    return True
for f, rows in data.items():
    in_fn = False; exe = cov = 0; unc = []
    for n, mark, src in rows:
        s = src.strip()
        if re.match(r"^(function|constructor|receive)\b", s): in_fn = True
        if not in_fn: continue
        if not executable(src): continue
        exe += 1
        if mark: cov += 1
        else: unc.append((n, s))
    print(f"{f}: {cov}/{exe} executable-looking lines executed ({100*cov/max(1,exe):.1f}%)")
    for n, s in unc: print(f"   L{n}: {s[:110]}")
