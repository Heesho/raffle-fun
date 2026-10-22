#!/usr/bin/env python3
"""Exhaustive SMT partition of exact execution obligations, not concrete EVM testing.
Each a,b low-byte pair in [1,16]^2 is checked; all other symbolic terms remain.
"""
import argparse,concurrent.futures,datetime,hashlib,itertools,json,re,subprocess,time
from pathlib import Path
from halmos.solve import refine
from halmos.sevm import SMTQuery
ap=argparse.ArgumentParser()
ap.add_argument('--destination',type=Path,required=True)
ap.add_argument('--solver',type=Path,required=True)
ap.add_argument('--timeout',type=int,default=60)
ap.add_argument('--workers',type=int,default=4)
ap.add_argument('queries',type=Path,nargs='+')
a=ap.parse_args();a.destination.mkdir()
def sha(s): return hashlib.sha256(s.encode()).hexdigest()
def run(job):
 file=job['query'];cmd=[str(a.solver),'--smt2-model-format','--bvconst-in-decimal',str(file)]
 rec={**job,'query':str(file),'command':cmd,'timeout_seconds':a.timeout,'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 start=time.monotonic()
 with file.with_suffix('.stdout.txt').open('wb') as out,file.with_suffix('.stderr.txt').open('wb') as err:
  try:rec['exit_code']=subprocess.run(cmd,stdout=out,stderr=err,timeout=a.timeout).returncode
  except subprocess.TimeoutExpired:rec['exit_code']=124
 rec['duration_seconds']=time.monotonic()-start
 rec['finished_at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 lines=file.with_suffix('.stdout.txt').read_text().splitlines()
 rec['result']=lines[0] if lines else ('timeout' if rec['exit_code']==124 else 'no-output')
 file.with_suffix('.result.json').write_text(json.dumps(rec,indent=2)+'\n')
 return rec
# Independent coverage obligation: no legal 8-bit pair lies outside the enumerated partition.
pairs=list(itertools.product(range(1,17),repeat=2))
coverage='(set-logic QF_BV)\n(declare-fun a () (_ BitVec 8))\n(declare-fun b () (_ BitVec 8))\n(assert (and (bvuge a (_ bv1 8)) (bvule a (_ bv16 8)) (bvuge b (_ bv1 8)) (bvule b (_ bv16 8))))\n'
coverage+='(assert (not (or '+ ' '.join(f'(and (= a (_ bv{x} 8)) (= b (_ bv{y} 8)))' for x,y in pairs)+')))\n(check-sat)\n'
cf=a.destination/'partition-coverage.smt2';cf.write_text(coverage)
coverage_result=run({'query':cf,'kind':'coverage','sha256':sha(coverage)})
assert coverage_result['result']=='unsat' and coverage_result['exit_code']==0,coverage_result
records=[]
for q in a.queries:
 raw=q.read_text(); refined=refine(SMTQuery(raw,[])).smtlib
 anames=re.findall(r'\(declare-fun (p_a_uint8_[^ ]+) \(\) \(_ BitVec 256\)\)',refined)
 bnames=re.findall(r'\(declare-fun (p_b_uint8_[^ ]+) \(\) \(_ BitVec 256\)\)',refined)
 assert len(anames)==len(bnames)==1,(anames,bnames)
 assert refined.count('(check-sat)')==1
 d=a.destination/(q.parent.parent.name+'__'+q.parent.name+'__'+q.name);d.mkdir()
 (d/'original.smt2').write_text(raw);(d/'refined.smt2').write_text(refined)
 jobs=[]
 for av,bv in pairs:
  assumption=f'(assert (= ((_ extract 7 0) {anames[0]}) (_ bv{av} 8)))\n(assert (= ((_ extract 7 0) {bnames[0]}) (_ bv{bv} 8)))\n'
  partition=refined.replace('(check-sat)',assumption+'(check-sat)')
  f=d/f'a{av:02d}-b{bv:02d}.smt2';f.write_text(partition)
  jobs.append({'query':f,'source':str(q),'source_sha256':sha(raw),'refined_sha256':sha(refined),'a':av,'b':bv,'partition_sha256':sha(partition)})
 with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as executor:results=list(executor.map(run,jobs))
 record={'source':str(q),'source_sha256':sha(raw),'refined_sha256':sha(refined),'input_domain':'all a,b low-byte pairs in 1..16; all other symbolic terms untouched','partition_count':len(results),'unsat_count':sum(x['result']=='unsat' and x['exit_code']==0 for x in results),'failed':[x for x in results if x['result']!='unsat' or x['exit_code']!=0],'partition_coverage':str(cf),'results':results}
 (d/'SUMMARY.json').write_text(json.dumps(record,indent=2)+'\n');records.append(record)
 print(json.dumps({k:v for k,v in record.items() if k!='results'}),flush=True)
(a.destination/'SUMMARY.json').write_text(json.dumps({'coverage':coverage_result,'queries':records},indent=2)+'\n')
raise SystemExit(0 if all(r['unsat_count']==256 for r in records) else 1)
