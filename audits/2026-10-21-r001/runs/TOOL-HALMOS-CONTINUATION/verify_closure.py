#!/usr/bin/env python3
"""Check proof-record consistency, remaining obligations and frozen-copy integrity."""
from pathlib import Path
import datetime,hashlib,itertools,json
from halmos.solve import refine
from halmos.sevm import SMTQuery
p=Path(__file__).resolve().parent
r=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001')
def sha(b):return hashlib.sha256(b).hexdigest()
issues=[];closed={};evidence=[]
for dirname in ['refined-replay-01-queries','refined-nft-yices-queries','refined-cash-yices-queries']:
 for rec in json.loads((p/dirname/'SUMMARY.json').read_text()):
  q=Path(rec['source']);raw=q.read_bytes();smt=refine(SMTQuery(raw.decode(),[])).smtlib.encode()
  d=p/dirname/(q.parent.parent.name+'__'+q.parent.name+'__'+q.name)
  assert sha(raw)==rec['source_sha256']==sha((d/'original.smt2').read_bytes())
  assert sha(smt)==rec['refined_sha256']==sha((d/'refined.smt2').read_bytes())
  if rec['result']=='unsat' and rec['exit_code']==0:
   assert (d/'stdout.txt').read_text().splitlines()[0]=='unsat'
   closed.setdefault(str(q),[]).append(str(d/'result.json'))
for dirname in ['smt-complete-refund-cash','smt-complete-nft-bitwuzla']:
 for q in sorted((p/dirname).glob('*-timeout/*.smt2')):
  record={'query':str(q),'sha256':sha(q.read_bytes()),'closing_evidence':closed.get(str(q),[])}
  evidence.append(record)
  if not record['closing_evidence']:issues.append('Unresolved: '+str(q))
assert len(evidence)==11,len(evidence)
for filename in ['complete-yices-refund-cash.json','complete-bitwuzla-nft.json']:
 j=json.loads((p/filename).read_text())
 for tests in j['test_results'].values():
  for t in tests:
   assert t['num_models']==0 and not t['models'] and t['num_paths'][2]==0 and t['num_bounded_loops']==0
   assert t['exitcode']==(0 if 'refund' in t['name'] else 2)
partition=json.loads((p/'partition-nft-queries/SUMMARY.json').read_text())
assert partition['coverage']['result']=='unsat' and partition['coverage']['exit_code']==0
assert len(partition['queries'])==2
for q in partition['queries']:
 assert q['partition_count']==q['unsat_count']==256 and not q['failed']
 assert {(x['a'],x['b']) for x in q['results']}==set(itertools.product(range(1,17),repeat=2))
 for x in q['results']:
  assert x['result']=='unsat' and x['exit_code']==0
  f=Path(x['query']);assert sha(f.read_bytes())==x['partition_sha256']
  assert f.with_suffix('.stdout.txt').read_text().splitlines()[0]=='unsat'
before=json.loads((p/'integrity-isolated-before.json').read_text())
roots=[r/'halmos',r/'runtime/halmos-continuation',*sorted((r/'runtime/halmos-continuation/branches').iterdir())]
integrity={}
for root in roots:
 vals={name:sha((root/name).read_bytes()) for name in before}
 integrity[str(root)]=vals
 if vals!=before:issues.append('Source/config hash mismatch: '+str(root))
(p/'integrity-isolated-after.json').write_text(json.dumps(integrity,indent=2)+'\n')
assert (p/'HARNESS-original-preserved.sol').read_bytes()==(r/'halmos/test/foundry/symbolic/SupplementarySymbolic.t.sol').read_bytes()
helper_checks=[]
for q in p.glob('*/attempt-*/integrity-*.json'):
 vals=json.loads(q.read_text());helper_checks.append(str(q))
 if vals:issues.append('Parent integrity mismatch: '+str(q))
sup=p.parent/'SUP-A1/attempt-01/FIRST-PASS.md'
suphash=sha(sup.read_bytes())
assert suphash=='c0c7d5de057e4cba87141ce5e4a296ce560e194ed2469bb9d3c674794cc20a28'
report={'verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'CLOSED' if not issues else 'UNRESOLVED','issues':issues,'completion_timeout_obligations':len(evidence),'closed_obligations':sum(bool(x['closing_evidence']) for x in evidence),'evidence':evidence,'partition_queries':2,'partition_subqueries_unsat':512,'partition_coverage_unsat':True,'source_config_roots_verified':len(roots),'source_config_files_per_root':len(before),'parent_integrity_checks_verified':len(helper_checks),'sup_a1_report_sha256_unchanged':suphash}
(p/'CLOSURE.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='evidence'},indent=2))
raise SystemExit(0 if not issues else 1)
