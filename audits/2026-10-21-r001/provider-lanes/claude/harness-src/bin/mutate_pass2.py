#!/usr/bin/env python3
"""Mutation pass 2: re-run pass-1 survivors with the gap tests added to the kill suite."""
import json, shutil, subprocess, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import mutate as m
OUT = m.OUT / 'pass2'; OUT.mkdir(parents=True, exist_ok=True)
MUT2 = m.RT / 'validation/claude-harness-mutation2'
if MUT2.exists(): shutil.rmtree(MUT2)
shutil.copytree(m.SRC_H, MUT2, ignore=shutil.ignore_patterns('out', 'cache'))
surv = [r['id'] for r in json.loads((m.OUT / 'results.json').read_text()) if r.get('status') == 'SURVIVED']
suite = ['forge', 'test', '--match-contract', 'LanePropsFuzz|LaneInvariantTest|LaneGapTests', '--fuzz-runs', '128', '--fuzz-seed', '0x4d555441']
res = []
for mid, f, old, new, desc in m.MUTANTS:
    if mid not in surv: continue
    p = MUT2 / 'src' / f; orig = p.read_text(); p.write_text(orig.replace(old, new))
    code, out, dur = m.run(suite, MUT2, 900); p.write_text(orig)
    (OUT / f'{mid}.txt').write_text(out)
    failed = [l.strip() for l in out.splitlines() if l.startswith('[FAIL')]
    st = 'KILLED' if (code != 0 and failed) else ('SURVIVED' if code == 0 else f'ERROR({code})')
    res.append({'id': mid, 'desc': desc, 'status': st, 'killed_by': failed[:6], 'duration_s': round(dur, 1)}); print(mid, st, desc, flush=True)
(OUT / 'results.json').write_text(json.dumps(res, indent=1))
