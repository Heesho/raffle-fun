#!/usr/bin/env python3
"""SETUP/AVAILABILITY CANARY ONLY. Never audit evidence; no source/resources/findings."""
import datetime,json,subprocess
from pathlib import Path
import native_leaf_transport_continuation as helper
p=Path(__file__).resolve().parent;out=p/'transport-health-20261021-02';out.mkdir(exist_ok=False);work=out/'empty-work';work.mkdir()
results=[];cid=None
for name,prompt in [('fresh','Availability canary only. Do not use any tools. Remember the marker PAPER-KITE-739 and reply exactly TRANSPORT_CANARY_FRESH_OK.'),('resume','Availability canary continuation only. Do not use any tools. Return the marker from the preceding message and then TRANSPORT_CANARY_RESUME_OK.')]:
 d=out/name;d.mkdir();argv=[str(p/'bin/agy'),'-p',prompt,'--model',helper.MODEL,'--effort','high','--dangerously-skip-permissions','--output-format','stream-json','--print-timeout','120s','--log-file',str(d/'native.log')]
 if name=='resume':
  if not cid:break
  argv+=['--conversation',cid]
 helper.write(d/'invocation.json',{'argv':argv,'cwd':str(work),'startedUtc':helper.utc(),'setupOnly':True,'auditEvidence':False,'nativeCanaryTimeoutSeconds':120})
 with (d/'stdout.ndjson').open('x') as stdout,(d/'stderr.log').open('x') as stderr:r=subprocess.run(argv,cwd=work,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr)
 try:
  init,t,delegated,tools=helper.native_events(d/'stdout.ndjson');row={'stage':name,'exitCode':r.returncode,'status':t.get('status'),'conversationId':t.get('conversation_id'),'initModel':init['init'].get('model'),'sameConversation':name=='fresh' or cid==t.get('conversation_id')==init.get('conversation_id'),'response':t.get('response'),'errorClass': 'stream-interruption' if 'stream was interrupted' in t.get('error','') else 'other-native-error' if t.get('error') else None,'usage':t.get('usage'),'tools':tools};cid=t.get('conversation_id') if t.get('status')=='SUCCESS' else None
 except Exception as e:row={'stage':name,'exitCode':r.returncode,'parseError':str(e)}
 results.append(row);helper.write(d/'metadata.json',row);print(json.dumps(row),flush=True)
helper.write(out/'result.json',{'setupOnly':True,'auditEvidence':False,'results':results,'endedUtc':helper.utc()})
