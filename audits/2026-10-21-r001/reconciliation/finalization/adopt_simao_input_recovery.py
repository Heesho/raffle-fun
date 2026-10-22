from pathlib import Path
import datetime, hashlib, json, os

A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001')
D=A/'reconciliation/finalization'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt=D/'GEMINI-SIMAO-LEAF-INPUT-COPY-RECOVERY.json'
seal=D/'GEMINI-SIMAO-LEAF-INPUT-COPY-RECOVERY-SEAL.json'
assert sha(receipt)=='9b92135c1e7ce33d8a265c84e820eabba93e157d659857733a747c6adeb4bb14'
assert sha(seal)=='0630c4d1239e2742933755cd16564c8484ff39919fff5915d144758166b9dd45'
r=json.loads(receipt.read_text());s=json.loads(seal.read_text())
for name,h in s['artifacts'].items(): assert sha(D/name)==h, name
assert len(r['records'])==14
for x in r['records']:
 assert sha(Path(x['preserved_copy']))==x['expected_sha256']==sha(Path(x['explicit_retained_input_path']))
 assert not Path(x['original_path']).exists() and not x['reconstructed']
 for c in x['all_explicit_retained_copy_checks']:
  assert sha(Path(c['explicit_retained_input_path']))==c['expected_sha256']

lane='GEMINI-SIMAO-REPAIRED/attempt-04'
recovery={'path':str(receipt),'sha256':sha(receipt),'seal':str(seal),'seal_sha256':sha(seal),'all14_effective_input_byte_bindings_verified':True,'literal_original_paths_still_absent':True,'copies_reconstructed':False}
state=json.loads((D/'state.json').read_text());w=json.loads((D/'working-register.json').read_text())
disposition='PASS_WITH_APPEND_ONLY_ADJUDICATION: native SUCCESS and historical leaf03/04 ERROR retained. Fourteen absent historical bundle/source/money-map paths have exact preserved per-leaf byte equivalents, independently hash-verified; literal-path absence remains disclosed. This adds byte-integrity evidence, not a new semantic approval.'
for arr in (state['method_semantic_qualifications'],w['method_semantic_qualifications']):
 q=next(x for x in arr if x['lane']==lane)
 assert 'historical_input_copy_recovery' not in q
 q['disposition_before_input_copy_recovery']=q['disposition'];q['disposition']=disposition;q['historical_input_copy_recovery']=recovery
sr=next(x for x in w['source_reports'] if x['report_key']==lane)
sr['qualification_before_input_copy_recovery']=sr.get('qualification');sr['qualification']=disposition
sr['append_only_semantic_qualification']=next(x for x in state['method_semantic_qualifications'] if x['lane']==lane)
next(x for x in w['assurance_issues'] if x['id']=='AQ-007').setdefault('late_provenance_qualifications',[]).append({'lane':lane,'effective_input_copy_recovery':recovery,'prior_literal_absence_diagnostics_preserved':True})

prior=D/'METADATA-PATH-BINDINGS-03.json';ledger=json.loads(prior.read_text())
ledger['created_utc']=now;ledger['scope']='Explicit hash-bound metadata path and retained-copy resolutions only; earlier ledgers and all original artifacts remain unchanged.'
ledger['extends']={'path':str(prior),'sha256':sha(prior)}
mp=r['manifest'];assert sha(Path(mp))==r['manifest_sha256']
spec=ledger['metadata_files'].setdefault(mp,{'sha256':r['manifest_sha256'],'reason':'Manifest-declared retained per-leaf copies preserve exact bytes for removed transient inputs.','evidence':recovery,'bindings':{}})
for x in r['records']:
 spec['bindings'][x['original_path']]={'sha256':x['expected_sha256'],'resolved_path':x['preserved_copy'],'resolution_type':'explicit_retained_leaf_input_exact_copy','original_runtime_identity_claimed':False,'original_runtime_path_unresolved':True,'original_path_still_absent':True,'evidence':str(receipt)}
ps=A/'runs/COORDINATOR-DAYBREAK/attempt-01/gemini-pashov-adjudication/GEMINI-PASHOV-REQUEST-05-PREIMAGE-RECOVERY-SEAL.json'
pj=json.loads(ps.read_text());sp=ledger['metadata_files'].setdefault(str(ps),{'sha256':sha(ps),'reason':'Coordinator recovery seal uses declared audit-root-relative paths.','evidence':{'audit_root':str(A)},'bindings':{}})
for key in ('recoveryReceipt','recoveryHelper'):
 x=pj[key];p=A/x['path'];assert sha(p)==x['sha256']
 sp['bindings'][x['path']]={'sha256':x['sha256'],'resolved_path':str(p),'resolution_type':'explicit_audit_root_base','original_runtime_identity_claimed':False,'original_runtime_path_unresolved':False}
out=D/'METADATA-PATH-BINDINGS-04.json';assert not out.exists();out.write_text(json.dumps(ledger,indent=2)+'\n')
adopt=D/'GEMINI-SIMAO-INPUT-COPY-ADOPTION.json';adoptseal=D/'GEMINI-SIMAO-INPUT-COPY-ADOPTION-SEAL.json';assert not adopt.exists() and not adoptseal.exists()
adopt.write_text(json.dumps({'adopted_utc':now,'lane':lane,'recovery':recovery,'verification':'14 distinct preserved copies and36 explicit retained-copy bindings independently rehashed; original paths remain absent.','binding_ledger':str(out),'binding_ledger_sha256':sha(out),'native_statuses_and_original_seals_unchanged':True,'new_semantic_qualification_issued':False,'source_findings_read':False},indent=2)+'\n')
adoptseal.write_text(json.dumps({'sealed_utc':now,'artifacts':{str(p.relative_to(D)):sha(p) for p in (adopt,receipt,seal,out,Path(__file__))}},indent=2)+'\n')
w['working_updated_utc']=now;state['updated_utc']=now
(D/'working-register.json').write_text(json.dumps(w,indent=2)+'\n');(D/'state.json').write_text(json.dumps(state,indent=2)+'\n')
message={'utc':now,'from':'supp_accounting','type':'exact_input_copy_adoption','lane':lane,'receipt':str(adopt),'receipt_sha256':sha(adopt),'seal':str(adoptseal),'seal_sha256':sha(adoptseal),'message':'All14 historical bundle/source/money-map inputs now independently hash-verified through explicitly retained per-leaf copies. No source paths restored, no statuses rewritten, no semantic approval added. Ledger04 also resolves request9 seal audit-root-relative paths.'}
fd=os.open(A/'runs/COORDINATOR-DAYBREAK/attempt-01/PARENT-INBOX.jsonl',os.O_WRONLY|os.O_APPEND|os.O_CREAT,0o644);os.write(fd,(json.dumps(message)+'\n').encode());os.close(fd)
print(json.dumps(message,indent=2))
