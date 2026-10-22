#!/usr/bin/env python3
"""Local-owned spool bridge to official agy. No provider API or credential extraction."""
from pathlib import Path
import base64,concurrent.futures,datetime,hashlib,json,os,subprocess,time,traceback
W=Path(__file__).resolve().parents[1];A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');O=A/'provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03';B=A/'provider-route-repair/bin/agy';Q=W/'data/bridge';EXPECTED=json.loads((W/'source-manifest.json').read_text());MODEL='gemini-4-argon-high'
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,obj):
 temp=p.with_suffix(p.suffix+'.tmp');temp.write_text(json.dumps(obj,indent=2)+'\n');temp.replace(p)
def run(request_path):
 req=json.loads(request_path.read_text());key=req['request_id'];call=W/'host-calls'/key;call.mkdir(exist_ok=False);workspace=call/'workspace';workspace.mkdir();result={'request_id':key,'started_utc':now(),'ok':False,'provider_internal_revision':None}
 try:
  assert req['model']==MODEL and req['effort']=='high','Wrong requested model/effort'
  assert req['source_manifest']==EXPECTED,'Unexpected source manifest'
  assert set(req['files_base64'])==set(EXPECTED),'Unexpected source file set'
  for rel,want in EXPECTED.items():
   target=workspace/rel;assert not Path(rel).is_absolute() and '..' not in Path(rel).parts
   raw=base64.b64decode(req['files_base64'][rel]);assert hashlib.sha256(raw).hexdigest()==want,rel
   target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  source_before={rel:sha(workspace/rel) for rel in EXPECTED};assert source_before==EXPECTED
  native_prompt=req['prompt'];(call/'native-prompt.txt').write_text(native_prompt);write(call/'schema.json',req['schema'])
  guard=('Execution boundary: This is one independently scheduled native OpenKritt call. Use only the supplied native task and the frozen source in this fresh workspace. Do not inspect audit history, sibling job outputs, peer reports, personal memory, external websites or live systems. Do not invoke subagents, other models, continue/resume or research helpers. Do not modify production source or dependencies. Return the native requested schema. ' + ('Read-only source inspection tools are allowed.' if req['allow_tools'] else 'This native stage disallows tools: answer from supplied prompt only.'))
  prompt=guard+'\n\n'+native_prompt
  prompt_transport='literal argv'
  if len(prompt.encode())>100000:
   (call/'full-prompt.txt').write_text(prompt);prompt='Read the complete native task at '+str(call/'full-prompt.txt')+' and execute it exactly. Return the requested schema.';prompt_transport='large native prompt file; full bytes preserved'
  argv=[str(B),'-p',prompt,'--model',MODEL,'--effort','high','--output-format','stream-json','--json-schema',str(call/'schema.json'),'--print-timeout','0','--dangerously-skip-permissions','--disable-slash-commands','--log-file',str(call/'native.log')]
  manifest={'started_utc':now(),'argv':argv,'cwd':str(workspace),'binary_sha256':sha(B),'prompt_sha256':sha(call/'native-prompt.txt'),'source_before':source_before,'schema_sha256':sha(call/'schema.json'),'native_model':MODEL,'native_effort':'high','native_print_timeout':0,'outer_timeout':None,'resume':False,'automatic_retry':False,'prompt_transport':prompt_transport,'allow_tools_requested_by_engine':req['allow_tools'],'tool_isolation':'scope instructions, fresh cwd and post-call hash checks; CLI tool-surface enforcement not guaranteed','native_engine_repo_dir':req['repo_dir']};write(call/'launch.json',manifest)
  with (call/'stdout.ndjson').open('w') as out,(call/'stderr.log').open('w') as err:
   process=subprocess.Popen(argv,cwd=workspace,stdin=subprocess.DEVNULL,stdout=out,stderr=err);write(call/'pid.json',{'pid':process.pid,'started_utc':now()});code=process.wait()
  init=None;terminal=None;malformed=0;tool_events=[]
  for line in (call/'stdout.ndjson').read_text().splitlines():
   try:event=json.loads(line)
   except json.JSONDecodeError:malformed+=1;continue
   if event.get('event')=='init':init=event.get('init')
   if event.get('event')=='result':terminal=event.get('result')
   if 'tool' in str(event.get('event','')).lower():tool_events.append({'event':event.get('event'),'name':event.get('name') or event.get('tool_name')})
  result.update(exit_code=code,init_model=(init or {}).get('model'),terminal_status=(terminal or {}).get('status'),conversation_id=(terminal or {}).get('conversation_id'),usage=(terminal or {}).get('usage'),malformed_stdout_lines=malformed,tool_event_summary=tool_events,source_after={rel:sha(workspace/rel) for rel in EXPECTED})
  result['source_unchanged']=result['source_after']==EXPECTED
  if code!=0 or result['init_model']!=MODEL or result['terminal_status']!='SUCCESS' or malformed or not result['source_unchanged']:raise RuntimeError('Official CLI transport/model/source integrity failed; inspect retained native events and stderr')
  payload=terminal.get('structured_output')
  if isinstance(payload,str):payload=json.loads(payload)
  if not isinstance(payload,dict):raise RuntimeError('No terminal result.structured_output object; response field not used')
  result.update(ok=True,payload=payload)
 except BaseException as exc:
  result.update(error=str(exc),error_code='invalid_output',exception_type=type(exc).__name__);(call/'bridge-exception.txt').write_text(traceback.format_exc())
 result['ended_utc']=now();write(call/'result.json',result)
 response=dict(result);response['stdout']=(call/'stdout.ndjson').read_text() if (call/'stdout.ndjson').exists() else '';response['stderr']=(call/'stderr.log').read_text() if (call/'stderr.log').exists() else '';write(Q/'responses'/f'{key}.json',response)
 with (O/'host-bridge-receipts.jsonl').open('a') as f:f.write(json.dumps({k:v for k,v in result.items() if k not in ['payload','source_after','tool_event_summary']})+'\n')
 print(json.dumps({'request_id':key,'ok':result['ok'],'exit_code':result.get('exit_code'),'model':result.get('init_model'),'ended_utc':result['ended_utc']}),flush=True)
if __name__=='__main__':
 write(O/'host-bridge-start.json',{'pid':os.getpid(),'started_utc':now(),'root':str(W),'workers':3,'transport':'owned filesystem spool; no network listener','no_provider_credentials_extracted':True})
 print(json.dumps({'host_bridge':'ready','pid':os.getpid(),'workers':3}),flush=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  pending={}
  while True:
   for p in sorted((Q/'requests').glob('*.json')):
    key=p.stem
    if (Q/'responses'/p.name).exists() or key in pending:continue
    lock=Q/'requests'/f'{key}.claimed'
    try:lock.mkdir()
    except FileExistsError:continue
    pending[key]=pool.submit(run,p)
   write(O/'host-bridge-heartbeat.json',{'checked_utc':now(),'requests':len(list((Q/'requests').glob('*.json'))),'responses':len(list((Q/'responses').glob('*.json'))),'active':sum(not f.done() for f in pending.values())})
   time.sleep(1)
