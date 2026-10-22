from pathlib import Path
import json,hashlib,datetime,shutil,collections,re
p=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');runs=p/'runs';stamp=datetime.datetime.now(datetime.timezone.utc).isoformat();old=json.loads((p/'tool-campaign-results.json').read_text());backup=p/'tool-campaign-results.pre-final-consolidation.json'
if not backup.exists():shutil.copyfile(p/'tool-campaign-results.json',backup)
prior={(x['id'],x['attempt']):x for x in old};rows=[]
for slot in sorted(runs.glob('TOOL-*')):
 for f in sorted(slot.glob('**/attempt-*/result.json')):
  x=json.loads(f.read_text())
  if 'slot' not in x or 'command' not in x:continue
  key=(x['slot'],f.parent.name);a=json.loads((f.parent/'ASSESSMENT.json').read_text()) if (f.parent/'ASSESSMENT.json').exists() else {};row=dict(prior.get(key,{}));row.update({'id':x['slot'],'attempt':f.parent.name,'command':x['command'],'cwd':x['cwd'],'timeout_seconds':x.get('timeout_seconds'),'duration_seconds':x.get('duration_seconds'),'process_status':x['status'],'workflow_status':a.get('workflow_status',row.get('workflow_status',x['status'])),'exit_code':x['exit_code'],'evidence':str(f.parent.relative_to(p)),'started_at':x.get('started_at'),'finished_at':x.get('finished_at')})
  for k in ['reason','limitations','findings_status']:
   if k in a:row[k]=a[k]
  for label in ['stdout','stderr']:
   log=f.parent/(label+'.txt')
   if log.exists():row[label+'_sha256']=hashlib.sha256(log.read_bytes()).hexdigest()
  row['current_for_slot']=f.parent.name==max(y.parent.name for y in slot.glob('**/attempt-*/result.json') if json.loads(y.read_text()).get('slot')==x['slot'])
  if row['id']=='TOOL-RELEASE':row['superseded_for_current_coverage_by']='TOOL-RELEASE-EXTENDED/attempt-01'
  if row['id']=='TOOL-RELEASE-EXTENDED':row.update(workflow_status='COMPLETE',reason='Native full audit_release suite completed:79passed,0failed,1forkskipped;3853.995s under4200s outer budget. Original600s interrupted attempt remains incomplete.')
  if row['id'] in ['TOOL-ECHIDNA-1','TOOL-ECHIDNA-2']:row.update(workflow_status='INCOMPLETE',reason='Native180s timeout;requested100000callsnotattained;allpropertiesstatus=fuzzing despiteexit0/success=true. Separate3000targetcampaign isnotcompletionofthis100000target.')
  if row['id'].startswith('TOOL-ECHIDNA-EXTENDED-'):
   log=(f.parent/'stdout.txt').read_text();calls=int(re.search(r'Total calls: (\d+)',log).group(1));passing=len(re.findall(r'^echidna_[^\n]+: passing$',log,re.M));assert calls>=100000 and passing==6 and 'Test limit reached. Stopping.' in log
   row.update(workflow_status='COMPLETE',actual_calls=calls,passing_properties=passing,reason='Separate extended native100000target completed at declared test limit; six properties passing; original180s attempts remain incomplete.')
  if row['id']=='TOOL-CONFIG-TEST':row.update(workflow_status='NOT_APPLICABLE',reason='Native script selected0tests; no test coverage counted.')
  if row['id']=='TOOL-BUILD-COVERAGE':row.update(workflow_status='COMPLETE_WITH_LIMITATION',reason='Compilation/size check completed and correctly rejected unoptimized Raffle runtime28172bytes>EIP170; separate artifact compilation and instrumented coverage completed. Not deployable coverage bytecode.')
  rows.append(row)
rows.append({'id':'TOOL-HALMOS-CONTINUATION/CLOSURE','attempt':'sealed-final','workflow_status':'COMPLETE_BOUNDED_PROOFS','process_status':'MIXED_ORIGINAL_ATTEMPTS_PRESERVED','evidence':'runs/TOOL-HALMOS-CONTINUATION/CLOSURE.json','reason':'Originalrefund/cash/NFT propertiespassed withoutnarroweddomains; strongercompletionpropertiesclosed;11residualnegatedassertionqueriesdischarged;zero unresolved declared obligations withinboundedmodel. OriginalCLI timeoutstatusesremain unchanged.','limitations':['twoowners,twoentryranges;a,b1..16;loopbound3;fixedexacttransfermocks/recipients/timestamps;no fullprotocol proof']})
rows.append({'id':'GEBAL-DETERMINISTIC','attempt':'attempt-03','workflow_status':'COMPLETE_DISTINCT_COMPATIBILITY_METHOD','evidence':'runs/GEBAL-DETERMINISTIC/RESULT.json','reason':'Docker nativebuild79tests/Slither100detectors;34observationsmapped separately. Unmodifiedupstream gas_reports unsupported;separatecontrollerpatchesdisclosed;no modelreviewcellcompletion.'})
rows.append({'id':'TOOL-MUTATION-QUALITY','attempt':'sealed-final','workflow_status':'COMPLETE_BOUNDED_TEST_EFFICACY_EXPERIMENT','evidence':'runs/TOOL-MUTATION-QUALITY/SUMMARY.md','reason':'Allfourmutantscompiled andkilled byexistingunit/fuzz/securitytests;shortinvariantssurvivedallfour,demonstratingreachability/vacuitylimits;notcomprehensivemutationscore.'})
(p/'tool-campaign-results.json').write_text(json.dumps(rows,indent=2)+'\n')
triage=json.loads((p/'reconciliation/scanner-triage.json').read_text());g=json.loads((runs/'GEBAL-DETERMINISTIC/attempt-03/slither-observation-index.json').read_text());lookup={x['scanner_id']:x for x in triage['observations'] if x['scanner']=='Slither'};mapped=[]
reason={'locked-ether':'Payable VRF wrapper fixture retains test payments; this observation concerns fixture behavior, not audited production custody.','reentrancy-no-eth':'Deliberately reentrant ERC20 fixture used to exercise defenses.','unused-return':'Adversarial fixture intentionally initiates/ignores nested calls to test rollback or rejection.','missing-zero-check':'Fixture arming setter; production authorization/configuration verdict not inferred.','calls-loop':'Adversarial callback fixture; excluded from production-source finding count.','reentrancy-benign':'Deliberately reentrant/callback fixture; behavior feeds tests rather than production implementation.','reentrancy-events':'Mock callback lifecycle; not a production finding.','assembly':'Adversarial fixture assembly; excluded from production scope.','low-level-calls':'Mock/adversarial low-level calls exercise malformed/reentrant dependency behavior.'}
for x in g['observations']:
 r={'gebal_scanner_id':x['id'],'detector':x['detector'],'source_class':x['sourceClass'],'primary_path':x['primaryPath'],'primary_lines':x['primaryLines']}
 if x['sourceClass']=='production-scope':
  y=lookup[x['id']];r.update({'relation':'EXACT_SCANNER_ID_DUPLICATE','triage_reference':'scanner-triage.json#/observations/'+str(triage['observations'].index(y)),'root_slither_ordinal':y['ordinal'],'existing_disposition':y['disposition'],'existing_triaged_severity':y['triaged_severity'],'rationale':'Identical detector ID on frozen production bytes; inherits the referenced existing evidence and limitations. No new security verdict.'})
 else:r.update({'relation':'EXCLUDED_TEST_MOCK_CONTEXT','rationale':reason[x['detector']],'security_verdict':'NONE_INFERRED'})
 mapped.append(r)
(p/'reconciliation/gebal-scanner-triage.json').write_text(json.dumps({'timestamp_utc':stamp,'base_triage_sha256':hashlib.sha256((p/'reconciliation/scanner-triage.json').read_bytes()).hexdigest(),'base_triage_preserved':True,'base_unique_items':23,'gebal_observations':34,'exact_production_duplicates':12,'test_mock_context_exclusions':22,'new_unique_production_scanner_items':0,'new_security_verdicts':0,'mapping':mapped},indent=2)+'\n')
print('campaign records',len(rows),'nativecommandrecords',len(rows)-3,'mapped',len(mapped))
