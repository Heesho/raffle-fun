import json, os, re
art = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
man = json.load(open(os.path.join(art, "mutants", "manifest.json")))
print("| Mutant | Injected specification violation | Verdict | Mutant source compiled | Tests that failed (killing tests) |")
print("|---|---|---|---|---|")
for mid, desc in man.items():
    log = os.path.join(art, "mutant-runs", mid, "forge-test.log")
    txt = open(log).read() if os.path.exists(log) else ""
    fails = []
    lines = txt.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("[FAIL") and not re.search(r"\]\s*(test|invariant)\w*\(", line):
            reason = re.match(r"\[FAIL(?::\s*)?(.*)\]\s*$", line)
            for nxt in lines[i + 1:i + 40]:
                m2 = re.match(r"^\s*(invariant_\w+)\(", nxt)
                if m2:
                    name = f"{m2.group(1)} [{reason.group(1) if reason else ''}]"
                    if name not in fails:
                        fails.append(name)
                    break
    for line in lines:
        if line.startswith("[FAIL"):
            m = re.search(r"\]\s*((?:test|invariant)\w*)\(", line)
            if m and m.group(1) not in fails:
                fails.append(m.group(1))
        if line.startswith("{") and '"event":"failure"' in line:
            try:
                ev = json.loads(line)
                name = f"{ev['invariant']} [{ev.get('reason', '')}]"
                if name not in fails:
                    fails.append(name)
            except Exception:
                pass
    cache = os.path.join(art, "mutant-runs", mid, "cache", "solidity-files-cache.json")
    compiled = os.path.exists(cache) and (f"mutants/{mid}/src/Raffle.sol" in open(cache).read())
    summ = re.search(r"(\d+) tests passed, (\d+) failed", txt)
    verdict = "KILLED" if fails else ("SURVIVED" if summ else "ERROR")
    counts = f" ({summ.group(2)} of {int(summ.group(1))+int(summ.group(2))} tests failed)" if summ else ""
    print(f"| {mid} | {desc} | **{verdict}**{counts} | {'yes' if compiled else 'NO'} | {', '.join(f'`{f}`' for f in fails) or '—'} |")
