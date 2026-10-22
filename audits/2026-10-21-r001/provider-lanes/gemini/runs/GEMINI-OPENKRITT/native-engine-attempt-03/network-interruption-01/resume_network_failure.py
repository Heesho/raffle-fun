from pathlib import Path
import json,hashlib,datetime,subprocess,os,shutil
M=Path(__file__).resolve().parents[1];O=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03');F=O/'network-interruption-01';F.mkdir(exist_ok=False);env=os.environ.copy();env['DOCKER_HOST']='unix:///Users/hishamel-husseini/.lima/glaze-openkritt-daybreak/sock/docker.sock'
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
errors=[]
for p in (M/'host-calls').glob('*/result.json'):
 r=json.loads(p.read_text())
 if r.get('ok'):continue
 terminal=None
 for line in (p.parent/'stdout.ndjson').read_text().splitlines():
  try:e=json.loads(line)
  except:continue
  if e.get('event')=='result':terminal=e.get('result',{})
 message=(terminal or {}).get('error','');assert 'operation timed out' in message or 'stream was interrupted' in message,message
 assert r.get('source_unchanged') and r.get('init_model')=='gemini-4-argon-high'
 errors.append({'request':p.parent.name,'error':message,'status':terminal.get('status'),'duration_seconds':terminal.get('duration_seconds'),'source_unchanged':True,'model':r['init_model']})
 shutil.copytree(p.parent,F/'host-calls'/p.parent.name,ignore=shutil.ignore_patterns('workspace'))
assert len(errors)==3,errors
dump(F/'DIAGNOSIS.json',{'utc':now(),'cause':'Official CLI network stream interruptions/timeouts; not provider safety rejection','errors':errors,'action':'Native failed-to-pending resumption; preserve completed logical jobs, original tasks/schema, failed metadata/raw events. Fresh conversations on each newly scheduled call.'})
args=['docker','exec','raffle-r001-gemini-native-db','pg_dump','-U','raffle_gemini','-d','raffle_gemini','--no-owner','--no-privileges'];p=subprocess.run(args,env=env,capture_output=True);assert p.returncode==0,p.stderr;(F/'database-before-resume.sql').write_bytes(p.stdout)
sql="BEGIN; SELECT id,status FROM public.scans WHERE id=1 FOR UPDATE; UPDATE public.scans SET status='pending', reasoning=NULL, last_resumed_at=now(), updated_at=now() WHERE id=1 AND status='failed'; COMMIT;"
dump(F/'resume-command.json',{'utc':now(),'sql':sql,'database_container':'raffle-r001-gemini-native-db','scan_id':1,'method':'Direct SQL equivalent of upstream backend/src/routes/scans.js patchScanIfPresent pending transition, lines 608-635. No workflow/job/output row mutation. Native engine requeues only unfinished logical jobs.','upstream_pin':'43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3','reason':'This isolated engine has no backend HTTP service. Local administrative pending transition matches native endpoint semantics.'})
cmd=['docker','exec','raffle-r001-gemini-native-db','psql','-v','ON_ERROR_STOP=1','-U','raffle_gemini','-d','raffle_gemini','-c',sql];p=subprocess.run(cmd,env=env,capture_output=True,text=True);(F/'resume.stdout').write_text(p.stdout);(F/'resume.stderr').write_text(p.stderr);assert p.returncode==0,p.stderr
shutil.copy2(__file__,F/'resume_network_failure.py')
dump(F/'FAILURE-SNAPSHOT-SEAL.json',{'sealed_utc':now(),'classification':'non-rejection network failure; recovered by separately recorded resume','artifacts':{str(p.relative_to(F)):sha(p) for p in F.rglob('*') if p.is_file()}})
print(json.dumps({'resumed_scan':1,'failure_snapshot':str(F),'errors':len(errors),'stdout':p.stdout}))
