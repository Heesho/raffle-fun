#!/usr/bin/env python3
"""Append-only receipt bookkeeping. No final-finding adoption or workflow completion inference."""
from pathlib import Path
import json,hashlib,datetime,re,sys
A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001')
O=A/'reconciliation';D=O/'finalization';COMMIT='9238b6ce8eb7f768c0dcd0cfcef26e1427a03155'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def validate_previous():
 for name in ['ADDENDUM-SEAL.json','PASHOV-SUPPLEMENT-SEAL.json']:
  s=json.loads((O/name).read_text())
  for f,h in s['artifacts'].items():assert sha(O/f)==h,(name,f,'changed')
  for f,h in s.get('original_files_unchanged',{}).items():assert sha(O/f)==h,(name,f,'changed')
def init():
 validate_previous();base=O/'findings-register-final-draft.json';pash=O/'findings-register-PASHOV-SUPPLEMENT.json'
 d=json.loads(base.read_text());p=json.loads(pash.read_text());index={x['id']:x for x in d['findings']}
 for x in p['append_attributions']:
  q=dict(x);target=q.pop('target');q.update({'report_key':p['source_report']['report_key'],'report_path':p['source_report']['path']});index[target]['original_attributions'].append(q)
 d['source_reports'].append(p['source_report']);q=p['remediation_proposal_review'];q['title']='Proposed delivery fallback omits unsettled NftWon liability';d['assurance_issues'].append(q)
 d['kind']='working merge only; awaiting eligible sealed continuations';d['working_created_utc']=now();d['counts']['source_report_paths']=len(d['source_reports']);d['counts']['assurance_issues']=len(d['assurance_issues']);d['counts']['original_attributions_preserved_and_added']=sum(len(f['original_attributions']) for f in d['findings']);d['counts']['distinct_first_pass_hashes']=len(set(x['sha256'] for x in d['source_reports']))
 dest=D/'working-register.json'
 if not dest.exists():dump(dest,d)
 state={'created_utc':now(),'status':'awaiting seals; no finalization authorization inferred','baseline_inputs':{str(base):sha(base),str(pash):sha(pash)},'expected_lanes':['DAYBREAK-TOB/attempt-03','CLAUDE-TOB/S6/attempt-02','GEMINI-SIMAO/fresh fully preverified native attempt','GEMINI-PASHOV/fresh fully preverified native attempt','GEMINI-OPENKRITT/fresh fully preverified native attempt','GEMINI-TOB/fresh fully preverified native attempt','GEMINI-GEBAL/fresh fully preverified native attempt'],'qualification_notes':['Gemini SIMAO/PASHOV attempt-02 had dependency changes after launch; preserve as limited-context and do not qualify fresh independent closure.','OpenKritt supp_whole independent validator was provider-rejected; no retry and no complete validation claim.','Source receipt validity does not prove native workflow completion, source coverage or model identity.','Parent owns final matrix/report/integrity; reconciliation adopts only verified sealed source findings.']}
 if not (D/'state.json').exists():dump(D/'state.json',state)
 scan()
def scan():
 validate_previous();state=json.loads((D/'state.json').read_text());prior={}
 log=D/'receipt-history.jsonl'
 if log.exists():
  for line in log.read_text().splitlines():
   row=json.loads(line);prior[row['report_path']]=row
 roots=[A/'runs/DAYBREAK-TOB',A/'provider-lanes/claude',A/'provider-lanes/gemini', *sorted((A/'runs').glob('GEMINI-*-REPAIRED'))]
 found=[]
 for root in roots:
  if not root.exists():continue
  for name in ['FIRST-PASS.md','FIRSTPASS.md']:
   for report in sorted(root.rglob(name)):
    if not report.is_file():continue
    seals=[report.parent/'SEAL.json',report.parent/'artifact-integrity-seal.json',report.parent/'EVIDENCE-SEAL.json',report.parent.parent/'EVIDENCE-SEAL.json',report.with_name(report.name+'.sha256')]
    for seal in seals:
     if not seal.is_file():continue
     seal_bytes=seal.read_bytes();seal_text=seal_bytes.decode(errors='replace');h=sha(report)
     row={'observed_utc':now(),'report_path':str(report),'sha256':h,'seal_path':str(seal),'seal_sha256':sha(seal),'hash_bound':h in seal_text,'target_in_seal':COMMIT in seal_text,'status':'unverified','findings_read':False}
     if not row['hash_bound']:row['status']='HASH_MISMATCH_OR_UNRECOGNIZED_SCHEMA'
     else:row['status']='HASH_VERIFIED_TARGET_NAMED' if row['target_in_seal'] else 'HASH_VERIFIED_NEEDS_TARGET_BINDING'
     # Report contents are not read by this helper: only hashing. An auditor must adjudicate newly sealed findings.
     old=prior.get(str(report));keys=['sha256','seal_sha256','status']
     if old is None or any(old.get(k)!=row[k] for k in keys):
      with log.open('a') as f:f.write(json.dumps(row)+'\n')
      print(json.dumps(row))
     prior[str(report)]=row;found.append(row);break
 summary={'checked_utc':now(),'known_receipts':len(found),'eligible_new_seals_adopted':0,'receipts':found,'pending_lanes':state['expected_lanes'],'semantic_qualification_pending':state.get('semantic_qualification_pending',[]),'note':'Pending source receipts and semantic qualification are separate. Scoped artifact seals do not establish method completion. No unsealed findings were read.'}
 dump(D/'latest-receipts.json',summary)
 print(json.dumps({'checked_utc':summary['checked_utc'],'known_receipts':len(found),'new_report_adoption':False}))
if __name__=='__main__':
 if len(sys.argv)>1 and sys.argv[1]=='init':init()
 else:scan()
