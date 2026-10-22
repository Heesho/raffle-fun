from pathlib import Path
import json,datetime,collections,subprocess
p=Path(__file__).resolve().parents[1];out=[]
for r in sorted((p/'runs').glob('GEMINI-*-REPAIRED/attempt-*/**/native-run')):
 if not (r/'stdout.ndjson').exists():continue
 ev=[]
 for l in (r/'stdout.ndjson').open():
  try:ev.append(json.loads(l))
  except:pass
 init=next((x.get('init',{}) for x in ev if x.get('event')=='init'),{});steps={x['step_update']['step_index']:x['step_update'] for x in ev if x.get('event')=='step_update'};completed=[x for x in steps.values() if x.get('state')=='DONE'];calls=collections.Counter(x.get('tool_name') for x in completed if x.get('step_type')=='tool');models=[]
 for x in completed:
  if x.get('tool_name')=='invoke_subagent':
   ps=x.get('tool_info',{}).get('parameters',{});models.append({k:v for k,v in ps.items() if any(t in k.lower() for t in ['model','agent','type']) and 'prompt' not in k.lower()})
 term=next((x.get('result') for x in reversed(ev) if x.get('event')=='result'),None);out.append({'path':str(r.relative_to(p)),'conversation_id':next((x.get('conversation_id') for x in ev if x.get('event')=='init'),None),'model':init.get('model'),'permissionMode':init.get('permission_mode'),'state':'FINISHED_TRANSPORT' if term else 'RUNNING','transportStatus':term.get('status') if term else None,'lastStep':steps[max(steps)] if steps else None,'completedToolCounts':dict(calls),'subagentRequestedSelectors':models,'lastLogMtimeUTC':datetime.datetime.fromtimestamp((r/'stdout.ndjson').stat().st_mtime,datetime.timezone.utc).isoformat(),'workflowCompletion':'NOT_YET_ADJUDICATED'})
 # Strip tool output/parameters to avoid mixing source findings into operational updates.
 if out[-1]['lastStep']:
  s=out[-1]['lastStep'];out[-1]['lastStep']={k:s[k] for k in ['step_index','state','step_type','tool_name'] if k in s}
for c in [p/'provider-lanes/claude/runs/CLAUDE-TOB/S6/attempt-02', *sorted((p/'provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE').glob('attempt-*'))]:
 ev=[]
 if (c/'events.jsonl').exists():
  for l in (c/'events.jsonl').open():
   try:ev.append(json.loads(l))
   except:pass
  models=collections.Counter(x.get('message',{}).get('model') for x in ev if x.get('type')=='assistant');toolcalls=collections.Counter(b.get('name') for x in ev if x.get('type')=='assistant' for b in x.get('message',{}).get('content',[]) if b.get('type')=='tool_use');res=next((x for x in reversed(ev) if x.get('type')=='result'),None);out.append({'path':str(c.relative_to(p)),'state':'FINISHED_TRANSPORT' if res else 'RUNNING','assistantModels':dict(models),'toolCounts':dict(toolcalls),'transportSubtype':res.get('subtype') if res else None,'isError':res.get('is_error') if res else None,'lastLogMtimeUTC':datetime.datetime.fromtimestamp((c/'events.jsonl').stat().st_mtime,datetime.timezone.utc).isoformat()})
for r in sorted((p/'runs/GEMINI-TOB-REPAIRED/attempt-03').glob('S*/workflow-adapter-execution')):
 es=[]
 if (r/'journal.jsonl').exists():
  for l in (r/'journal.jsonl').read_text().splitlines():
   try:es.append(json.loads(l))
   except:pass
  out.append({'path':str(r.relative_to(p)),'state':'WORKFLOW_TERMINAL' if (r/'result.json').exists() else 'RUNNING','journalEventCounts':dict(collections.Counter(x.get('event') for x in es)),'lastLogMtimeUTC':datetime.datetime.fromtimestamp((r/'journal.jsonl').stat().st_mtime,datetime.timezone.utc).isoformat(),'workflowCompletion':'NOT_YET_ADJUDICATED'})
for r in sorted((p/'runs').glob('GEMINI-*-REPAIRED/attempt-04/explicit-high-leaves')):
 children=[]
 for child in sorted(r.glob('leaf-*')):
  if not (child/'invocation.json').exists():continue
  ev=[]
  for l in (child/'stdout.ndjson').read_text().splitlines():
   try:ev.append(json.loads(l))
   except:pass
  init=next((x.get('init',{}) for x in ev if x.get('event')=='init'),{});term=next((x.get('result',{}) for x in ev if x.get('event')=='result'),{})
  receipt=json.loads((child/'transport-result.json').read_text()) if (child/'transport-result.json').exists() else {}
  children.append({'leaf':child.name,'model':init.get('model'),'status':receipt.get('status','RUNNING'),'terminal':term.get('status'),'conversationId':term.get('conversation_id'),'inputHashesUnchanged':receipt.get('inputHashesUnchanged'),'lastLogMtimeUTC':datetime.datetime.fromtimestamp((child/'stdout.ndjson').stat().st_mtime,datetime.timezone.utc).isoformat()})
 out.append({'path':str(r.relative_to(p)),'state':'RUNNING' if len(children)<12 or any(x['status']=='RUNNING' for x in children) else 'LEAF_TRANSPORTS_TERMINAL','launchedLeafCount':len(children),'children':children,'workflowCompletion':'NO_JUDGMENT_OR_ASSEMBLY_YET'})
text=subprocess.run(['ps','-axo','pid,ppid,etime,args'],capture_output=True,text=True).stdout;processes=[]
for line in text.splitlines():
 if ('run_native_gemini.py --workspace' in line or 'claude-native-continuation.py CLAUDE-' in line or 'tob-native-workflow-adapter.mjs' in line or 'native_high_leaf_adapter.py run' in line or 'run_high_native_stage.py' in line) and 'python3 -' not in line and '/bin/zsh -c' not in line:
  q=line.split(None,3);processes.append({'pid':int(q[0]),'ppid':int(q[1]),'elapsed':q[2],'controller':'Claude native continuation' if 'claude-native-continuation' in line else ('Gemini exact-body workflow adapter' if 'tob-native-workflow-adapter.mjs' in line else 'Gemini native')})
d={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runs':out,'activeControllerProcesses':processes};(p/'provider-route-repair/native-stage-ledger.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))
