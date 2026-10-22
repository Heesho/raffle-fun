#!/usr/bin/env python3
"""Replay exact timed-out path obligations after Halmos' own arithmetic refinement.
No constraints or assertions are removed or added. All raw and refined SMT is retained.
"""
import argparse, concurrent.futures, datetime, hashlib, json, subprocess, time
from pathlib import Path
from halmos.solve import refine
from halmos.sevm import SMTQuery
ap=argparse.ArgumentParser()
ap.add_argument('--destination',type=Path,required=True)
ap.add_argument('--solver',type=Path,required=True)
ap.add_argument('--timeout',type=int,default=180)
ap.add_argument('--workers',type=int,default=2)
ap.add_argument('queries',type=Path,nargs='+')
a=ap.parse_args(); a.destination.mkdir()
def run(q):
 label=q.parent.parent.name+'__'+q.parent.name+'__'+q.name
 d=a.destination/label; d.mkdir()
 raw=q.read_text(); (d/'original.smt2').write_text(raw)
 refined=refine(SMTQuery(raw,[])).smtlib; (d/'refined.smt2').write_text(refined)
 cmd=[str(a.solver),'--smt2-model-format','--bvconst-in-decimal',str(d/'refined.smt2')]
 record={'source':str(q),'source_sha256':hashlib.sha256(raw.encode()).hexdigest(),'refined_sha256':hashlib.sha256(refined.encode()).hexdigest(),'refinement_changed':raw!=refined,'command':cmd,'timeout_seconds':a.timeout,'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 start=time.monotonic()
 with (d/'stdout.txt').open('wb') as out,(d/'stderr.txt').open('wb') as err:
  try:
   r=subprocess.run(cmd,stdout=out,stderr=err,timeout=a.timeout)
   record['exit_code']=r.returncode
  except subprocess.TimeoutExpired:
   record['exit_code']=124
 record['duration_seconds']=time.monotonic()-start
 record['finished_at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 lines=(d/'stdout.txt').read_text().splitlines()
 record['result']=lines[0] if lines else ('timeout' if record['exit_code']==124 else 'no-output')
 (d/'result.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps(record),flush=True)
 return record
with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as executor:
 results=list(executor.map(run,a.queries))
(a.destination/'SUMMARY.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['result']=='unsat' and r['exit_code']==0 for r in results) else 1)
