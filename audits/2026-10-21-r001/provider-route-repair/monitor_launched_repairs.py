#!/usr/bin/env python3
"""Read-only receipt monitor. Never prints/assesses native source findings."""
import datetime,hashlib,json,time
from pathlib import Path
P=Path(__file__).resolve().parent;RUNS=P.parent/'runs';OUT=P/'launched-repair-metadata';OUT.mkdir(exist_ok=True)
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def read(f):return json.loads(f.read_text())
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write(f,v):f.write_text(json.dumps(v,indent=2)+'\n')
def native_metadata(f):
 events=[]
 for line in f.read_text().splitlines():
  if not line.strip():continue
  e=json.loads(line)
  if e.get('event') in ['init','result']:events.append(e)
  elif e.get('step_update',{}).get('tool_name') in ['invoke_subagent','define_subagent','browser_subagent','run_workflow']:events.append({'delegated':True})
 inits=[e for e in events if e.get('event')=='init'];ts=[e['result'] for e in events if e.get('event')=='result'];i=inits[0] if len(inits)==1 else {};t=ts[0] if len(ts)==1 else {};error=t.get('error','')
 error_class='stream-interrupted' if 'stream was interrupted' in error else 'API-stream-read-timeout' if error.startswith('API error') and 'operation timed out' in error else 'API-stream-read-reset' if error.startswith('API error') and 'read: connection reset by peer' in error else 'other-native-error' if error else None
 return {'singleInitAndTerminal':len(inits)==len(ts)==1,'initConversationId':i.get('conversation_id'),'terminalConversationId':t.get('conversation_id'),'initModel':i.get('init',{}).get('model'),'permissionMode':i.get('init',{}).get('permission_mode'),'nativeStatus':t.get('status'),'usage':t.get('usage'),'errorClass':error_class,'delegationObserved':any(e.get('delegated') for e in events),'rawTraceSha256':sha(f)}
targets=[]
for cell in ['SIMAO','PASHOV']:
 for n in [3,4]:targets.append((f'{cell}-leaf{n:02d}-continuation02','continuation',RUNS/f'GEMINI-{cell}-REPAIRED/attempt-04/explicit-high-leaves/leaf-{n:02d}/continuation-02'))
for n,gen in [(2,2),(3,2),(4,2),(6,1)]:targets.append((f'TOB-S{n}-continuation{gen:02d}','continuation',RUNS/f'GEMINI-TOB-REPAIRED/attempt-04/S{n}/native-run/continuation-{gen:02d}'))
for n in [1,5]:targets.append((f'TOB-S{n}-exact-body-replay','replay',RUNS/f'GEMINI-TOB-REPAIRED/attempt-04/S{n}/workflow-replay-execution'))
seen={}
while True:
 for name,kind,d in targets:
  if name in seen:continue
  terminal=d/('workflow-result.json' if kind=='replay' else 'transport-result.json')
  if not terminal.exists():continue
  try:
   r=read(terminal);meta={'target':name,'kind':kind,'observedUtc':utc(),'receipt':str(terminal),'receiptSha256':sha(terminal),'transportStatus':r.get('status'),'semanticCompletenessValidated':False,'sourceFindingsReadOrJudged':False}
   if kind=='continuation':
    c=read(d/'config.json');meta.update(native_metadata(d/'stdout.ndjson'));meta.update({'expectedOriginalConversationId':c['originalConversationId'],'sameOriginalConversationId':meta['initConversationId']==meta['terminalConversationId']==c['originalConversationId'],'protectedInputsUnchanged':r.get('inputHashesUnchanged',r.get('protectedInputsUnchanged')),'originalEvidenceUnchanged':r.get('originalEvidenceUnchanged'),'nativeExitCode':r.get('exitCode')})
   else:
    calls=[]
    for call in r.get('calls',[]):
     invocation=read(d/'agents'/call['id']/'invocation.json');raw=d/'agents'/call['id']/'stdout.ndjson'
     row={k:invocation.get(k) for k in ['id','status','runtimeOrigin','conversationId','schemaValidated','argvExecuted']}
     if raw.exists():row.update(native_metadata(raw))
     calls.append(row)
    meta.update({'calls':calls,'reusedCalls':sum(x.get('runtimeOrigin')=='reused-original-validated-native-call' for x in calls),'newNativeCalls':sum(x.get('runtimeOrigin')=='fresh-native-High-after-transport-repair' for x in calls),'failedCallIds':[x['id'] for x in calls if x['status']!='succeeded'],'workflowErrorPresent':bool(r.get('error')),'rawTimestampsNormalized':False})
   write(OUT/(name+'.json'),meta);seen[name]=meta;print(json.dumps(meta),flush=True)
  except Exception as error:print(json.dumps({'target':name,'metadataParsePending':type(error).__name__}),flush=True)
 summary={'updatedUtc':utc(),'terminalTargets':sorted(seen),'pendingTargets':[name for name,_,_ in targets if name not in seen],'allTerminal':len(seen)==len(targets),'semanticCompletenessValidated':False,'sourceFindingsReadOrJudged':False};write(OUT/'summary.json',summary)
 if len(seen)==len(targets):break
 time.sleep(5)
print(json.dumps(summary),flush=True)
