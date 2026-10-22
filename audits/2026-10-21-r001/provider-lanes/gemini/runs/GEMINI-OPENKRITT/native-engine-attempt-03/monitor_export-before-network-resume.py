#!/usr/bin/env python3
"""Monitor our isolated native scan. Read only status before completion; atomically export/seal afterwards."""
from pathlib import Path
from datetime import datetime,timezone
import collections,hashlib,json,os,shutil,subprocess,time
M=Path(__file__).resolve().parents[1]
O=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03')
ENV=os.environ.copy();ENV['DOCKER_HOST']='unix:///Users/hishamel-husseini/.lima/glaze-openkritt-daybreak/sock/docker.sock'
MODEL='gemini-4-argon-high';COMMIT='9238b6ce8eb7f768c0dcd0cfcef26e1427a03155'
def now():return datetime.now(timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
 t=p.with_suffix(p.suffix+'.tmp');t.write_text(json.dumps(v,indent=2)+'\n');t.replace(p)
def query(sql):
 argv=['docker','exec','raffle-r001-gemini-native-db','psql','-U','raffle_gemini','-d','raffle_gemini','-Atc',sql]
 p=subprocess.run(argv,env=ENV,text=True,capture_output=True,timeout=30)
 with (O/'monitor-command-log.jsonl').open('a') as f:f.write(json.dumps({'utc':now(),'argv':argv,'exit_code':p.returncode,'stderr':p.stderr})+'\n')
 if p.returncode:raise RuntimeError(p.stderr)
 return json.loads(p.stdout.strip()) if p.stdout.strip() else None
def rows(table,where):return query("select coalesce(json_agg(to_jsonb(t)-'codex_account_email'-'codex_account_id'-'codex_source_home'),'[]'::json) from (select * from "+table+" where "+where+" order by id)t")
def status():
 return query("select json_build_object('scan',(select to_jsonb(t) from (select id,status,model,model_provider,harness,thinking_effort from public.scans where id=1)t),'jobs',(select json_agg(t) from (select id,step_id,kind,status,phase,model,harness,thinking_effort,error from workflows.step_metadata where scan_id=1 order by id)t))")
def export():
 if (O/'SEAL.json').exists():return
 scan=rows('public.scans','id=1')[0];assert scan['status']=='completed'
 data={'scan':scan,'steps':rows('workflows.step_metadata','scan_id=1'),'post_processing':rows('workflows.post_process_metadata','scan_id=1'),'step_results':rows('workflows.step_results','scan_id=1'),'findings':rows('workflows.vulnerabilities','scan_id=1'),'enrichments':rows('workflows.vulnerability_enrichments','scan_id=1'),'workflow':rows('public.llm_workflows','id='+str(scan['workflow_id'])),'step_definitions':rows('public.steps','id in (1,2,3)'),'post_scripts':rows('public.post_scripts','id in (3,4,5,6)'),'rankers':rows('public.severity_rankers','id=1')}
 write(O/'native-results.json',data)
 expected=json.loads((M/'source-manifest.json').read_text());calls=[];issues=[]
 for call in sorted((M/'host-calls').iterdir()):
  if not call.is_dir():continue
  dest=O/'host-call-evidence'/call.name;dest.mkdir(parents=True,exist_ok=True)
  for p in call.iterdir():
   if p.is_file():shutil.copy2(p,dest/p.name)
  result=json.loads((call/'result.json').read_text());launch=json.loads((call/'launch.json').read_text());tools=[]
  for line in (call/'stdout.ndjson').read_text().splitlines():
   try:e=json.loads(line)
   except:continue
   s=e.get('step_update',{});name=s.get('tool_name')
   if name:tools.append({'step_index':s.get('step_index'),'state':s.get('state'),'tool_name':name})
  after={rel:sha(call/'workspace'/rel) for rel in expected}
  delegated=sorted({x['tool_name'] for x in tools if any(w in x['tool_name'].lower() for w in ['research','agent','delegate','model'])})
  receipt={k:v for k,v in result.items() if k not in ['payload','source_after','tool_event_summary']};receipt.update(source_after_matches=after==expected,launch_sha256=sha(call/'launch.json'),tools=tools,delegated_tool_names=delegated,native_allows_tools=launch['allow_tools_requested_by_engine'])
  calls.append(receipt)
  if not result.get('ok') or not receipt['source_after_matches'] or result.get('init_model')!=MODEL:issues.append({'call':call.name,'issue':'route/source/transport integrity'})
  if delegated:issues.append({'call':call.name,'issue':'unverified delegated model invocation','tools':delegated})
  if not launch['allow_tools_requested_by_engine'] and any(t['tool_name']!='finish' for t in tools):issues.append({'call':call.name,'issue':'native no-tool request violated','tools':sorted({t['tool_name'] for t in tools})})
 write(O/'CLI-CALL-RECEIPTS.json',calls)
 mismatch=[s['id'] for s in data['steps'] if s.get('model') and (s['model']!=MODEL or s.get('thinking_effort')!='high' or s.get('harness')!='gemini-cli')]
 if mismatch:issues.append({'issue':'native tuple mismatch','metadata':mismatch})
 findings=data['findings'];counts=collections.Counter((s['kind'],s['status']) for s in data['steps'])
 completion={'completed_utc':now(),'native_status':'completed','target_commit':COMMIT,'method':'actual pinned OpenKritt Python engine, native PostgreSQL queue/workflow/ranker/postprocessors; disclosed official agy file-spool adapter','requested_model':MODEL,'requested_effort':'high','provider_internal_identity':'not independently returned','calls':len(calls),'stage_counts':{str(k):v for k,v in counts.items()},'finding_records':len(findings),'canonical_findings':sum(bool(x.get('dedupe_is_canonical')) for x in findings),'qualification_issues':issues,'qualifies_route_and_source':not issues,'no_claim_of_independent_finding_validation':True}
 write(O/'COMPLETION-RECEIPT.json',completion)
 lines=['# Gemini native OpenKritt first pass','',f'Target: `{COMMIT}`. Upstream OpenKritt: `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`.','', 'This is the actual native Python engine and PostgreSQL workflow, using a disclosed local file-spool adapter to the official macOS Antigravity CLI. Every direct call requests `gemini-4-argon-high`, effort `high`, and a fresh source workspace. Internal provider checkpoint identity is not independently returned. The adapter does not replace native queue, workflow, ranking or postprocessing decisions.','', 'This export preserves native findings without operator synthesis or independent security validation. Claim counts are output records, not votes or established defects.','', '## Execution','', '```json',json.dumps(completion,indent=2),'```','','| Native job | Kind | Step | Status | Model | Effort |','|---|---|---|---|---|---|']
 for s in data['steps']:lines.append('| '+' | '.join(str(s.get(k) or '').replace('|','/') for k in ['id','kind','step_id','status','model','thinking_effort'])+' |')
 lines+=['','## Native finding records','','Original database IDs, source spans, ranker state and deduplication fields are preserved verbatim below and in native-results.json. Native enrichment records remain in that JSON.']
 for v in findings:lines+=['', '### Native finding #'+str(v['id']),'','```json',json.dumps(v,indent=2),'```']
 if not findings:lines+=['','The native workflow produced zero finding records. This is not a proof of absence. Ranking/postprocessing calls are reported only where the native engine actually scheduled them.']
 lines+=['','## Limits','','Scope was the frozen 43-file source context. The host provided fresh cwd and unchanged-source checks; absence of all service-side memory is not provable. The CLI tool surface was not independently sandboxed: actual tool metadata and any native no-tool or delegation issues are recorded in CLI-CALL-RECEIPTS.json. Source/workflow integrity does not establish severity or exploitability. No deployment, RPC, production changes or finding-validation campaign was performed by the operator.']
 (O/'FIRST-PASS.md').write_text('\n'.join(lines)+'\n')
 coverage=['# Native source mapping coverage','','Native stage-1 outputs enumerate mapping claims only. They are not instrumented line coverage.','','```json',json.dumps([r for r in data['step_results'] if r.get('step_id')==1],indent=2),'```']
 (O/'COVERAGE.md').write_text('\n'.join(coverage)+'\n')
 # Exclude ongoing heartbeat/receipt files. All copied per-call evidence is terminal and immutable here.
 excluded={'SEAL.json','host-bridge-heartbeat.json','host-bridge-receipts.jsonl','monitor-status.json','monitor-status-history.jsonl','monitor-command-log.jsonl'}
 files={str(p.relative_to(O)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(O.rglob('*')) if p.is_file() and p.name not in excluded}
 write(O/'SEAL.json',{'sealed_utc':now(),'target_commit':COMMIT,'native_status':'completed','first_pass_sha256':sha(O/'FIRST-PASS.md'),'artifacts':files,'qualification_issues':issues,'note':'Integrity seal; not independent endorsement of native findings. Live heartbeat and monitor logs deliberately excluded.'})
 print(json.dumps({'sealed':str(O/'SEAL.json'),'first_pass_sha256':sha(O/'FIRST-PASS.md'),'finding_records':len(findings),'qualification_issues':issues}),flush=True)
if __name__=='__main__':
 previous=None
 while True:
  try:
   s=status();s['checked_utc']=now();write(O/'monitor-status.json',s);finger=json.dumps({k:v for k,v in s.items() if k!='checked_utc'},sort_keys=True)
   if finger!=previous:
    with (O/'monitor-status-history.jsonl').open('a') as f:f.write(json.dumps(s)+'\n')
    print(json.dumps(s),flush=True);previous=finger
   state=s['scan']['status']
   if state=='completed':export();break
   if state in ['failed','cancelled','canceled']:
    print(json.dumps({'requires_diagnostics':True,'status':state,'no_fake_first_pass':True}),flush=True);break
  except Exception as e:
   print(json.dumps({'monitor_error':repr(e),'utc':now()}),flush=True)
  time.sleep(30)
