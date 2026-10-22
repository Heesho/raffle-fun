import json, sys, collections
data = json.load(open(sys.argv[1]))
dets = data.get("results", {}).get("detectors", [])
print("success:", data.get("success"), "error:", data.get("error"), "results:", len(dets))
def files(d):
    fs = set()
    for el in d.get("elements", []):
        sm = el.get("source_mapping", {})
        fs.add(sm.get("filename_relative", "?"))
    return fs
c = collections.Counter(); scope = collections.Counter()
for d in dets:
    fs = files(d)
    inscope = any("packages/contracts/src/" in f or f.startswith("src/") for f in fs)
    key = (d["check"], d["impact"], d["confidence"])
    c[key] += 1
    if inscope: scope[key] += 1
print(f"{'detector':32} {'impact':14} {'conf':8} total in-scope")
for k, v in sorted(c.items(), key=lambda kv: (["High","Medium","Low","Informational","Optimization"].index(kv[0][1]), kv[0][0])):
    print(f"{k[0]:32} {k[1]:14} {k[2]:8} {v:5} {scope[k]:5}")
