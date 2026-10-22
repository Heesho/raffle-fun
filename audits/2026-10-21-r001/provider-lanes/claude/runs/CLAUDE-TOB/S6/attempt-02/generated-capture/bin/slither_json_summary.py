# Generated scratch helper: summarize Slither JSON by detector/impact/confidence and source location class.
import json, sys, collections
def loc_class(res):
    files = set()
    for el in res.get("elements", []):
        sm = el.get("source_mapping", {})
        f = sm.get("filename_relative") or sm.get("filename_short") or ""
        files.add(f)
    if any(f.startswith("src/") for f in files): return "src", files
    return "deps", files
for path in sys.argv[1:]:
    d = json.load(open(path))
    dets = d.get("results", {}).get("detectors", [])
    print(f"== {path.split('/')[-1]} success={d.get('success')} error={d.get('error')} results={len(dets)}")
    c = collections.Counter()
    for r in dets:
        lc, _ = loc_class(r)
        c[(r["impact"], r["confidence"], r["check"], lc)] += 1
    order = {"High":0,"Medium":1,"Low":2,"Informational":3,"Optimization":4}
    for (imp, conf, chk, lc), n in sorted(c.items(), key=lambda x: (order.get(x[0][0],9), x[0][2], x[0][3])):
        print(f"   {imp:13s} {conf:7s} {chk:28s} {lc:5s} x{n}")
