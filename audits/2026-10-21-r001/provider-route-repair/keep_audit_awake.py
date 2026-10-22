from pathlib import Path
import subprocess,time,json,datetime,os,signal
P=Path(__file__).resolve().parent;root=P.parent;stop=P/'idle-awake-stop';log=P/'idle-awake-supervisor.jsonl'
def emit(event,**fields):
 with log.open('a') as f:f.write(json.dumps({'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'event':event,**fields})+'\n')
def running(value):
 if isinstance(value,dict):
  for k,v in value.items():
   if k.lower() in ['status','validated_status','current_status','currentstatus','state'] and isinstance(v,str) and v.upper() in ['RUNNING','PENDING','QUEUED','ACTIVE','IN_PROGRESS']:return True
   if isinstance(v,(dict,list)) and running(v):return True
 elif isinstance(value,list):return any(running(x) for x in value)
 return False
lease=subprocess.Popen(['/usr/bin/caffeinate','-i'],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
emit('started',supervisorPid=os.getpid(),leasePid=lease.pid,automaticRelease='stop flag or all current required provider statuses and parent matrix no longer active',persistentSettingsChanged=False)
try:
 while not stop.exists():
  validation=json.loads((root/'provider-handoff-validation.json').read_text());provider_active=any(x.get('validated_status')=='RUNNING' for x in validation['cells']) or any(x.get('status')=='RUNNING' for x in validation.get('separate_methods',[]))
  matrix_active=running(json.loads((root/'matrix.json').read_text())) if (root/'matrix.json').exists() else False
  if not provider_active and not matrix_active:emit('authorized-runs-no-longer-active');break
  time.sleep(15)
finally:
 lease.terminate();lease.wait();emit('released',leasePid=lease.pid)
