from pathlib import Path
import subprocess,re,json,datetime
root=Path(__file__).resolve().parents[1]
raw=subprocess.run(['ps','-axo','pid,ppid,etime,args'],capture_output=True,text=True,check=True).stdout;rows=[]
for line in raw.splitlines():
 fields=line.split(None,3)
 if len(fields)!=4:continue
 pid,ppid,elapsed,args=fields
 if args.startswith(('/bin/zsh -c','python3 -','python3 audits/','/usr/bin/python3 -')):continue
 if 'provider-route-repair/bin/agy' in args and '--print-timeout' in args:
  logs=re.findall(r'--log-file\s+([^\s]+)',args);models=re.findall(r'--model\s+([^\s]+)',args);efforts=re.findall(r'--effort\s+([^\s]+)',args)
  rows.append({'pid':int(pid),'ppid':int(ppid),'elapsed':elapsed,'runner':'owned official agy1.4.4','observedModelFlags':models,'observedEffortFlags':efforts,'logFile':logs[-1] if logs else None,'rawPromptOmitted':True})
 elif 'claude-code/node_modules/.bin/claude' in args and '--output-format stream-json' in args:
  models=re.findall(r'--model\s+([^\s]+)',args);efforts=re.findall(r'--effort\s+([^\s]+)',args)
  rows.append({'pid':int(pid),'ppid':int(ppid),'elapsed':elapsed,'runner':'isolated ClaudeCode2.1.299','observedModelFlags':models,'observedEffortFlags':efforts,'rawPromptOmitted':True})
out={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'activeNativeCliCount':len(rows),'processes':rows,'qualification':'Observed process argv flags only. Applied model requires separate actual native init/model events; no child model inference.'};(root/'provider-route-repair/native-cli-process-ledger.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'at':out['at'],'activeNativeCliCount':len(rows)}))
