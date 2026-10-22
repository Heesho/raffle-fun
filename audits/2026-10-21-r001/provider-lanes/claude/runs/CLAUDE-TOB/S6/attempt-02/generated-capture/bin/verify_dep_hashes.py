# Generated scratch helper: verifies dependency-hashes.json against files on disk.
import hashlib, json, os, sys
root = sys.argv[1]
m = json.load(open(os.path.join(root, "dependency-hashes.json")))
ok = bad = 0
for rel, want in sorted(m.items()):
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        print("MISSING", rel); bad += 1; continue
    got = hashlib.sha256(open(p, "rb").read()).hexdigest()
    if got == want: ok += 1; print("OK     ", rel)
    else: bad += 1; print("MISMATCH", rel, got, want)
nm = []
for d, _, fs in os.walk(os.path.join(root, "packages/contracts/node_modules")):
    for f in fs:
        nm.append(os.path.relpath(os.path.join(d, f), root))
extra = sorted(set(nm) - set(m))
print(f"manifest_entries={len(m)} ok={ok} bad={bad} node_modules_files={len(nm)} files_not_in_manifest={len(extra)}")
for e in extra: print("EXTRA", e)
sys.exit(1 if bad else 0)
