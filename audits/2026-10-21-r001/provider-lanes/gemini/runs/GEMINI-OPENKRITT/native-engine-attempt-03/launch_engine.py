from pathlib import Path
import json,os,subprocess,time,datetime,secrets,shutil
W=Path(__file__).resolve().parents[1];A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');O=A/'provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03';T=Path('/Users/hishamel-husseini/.local/share/glaze-audit-harnesses/openkritt/raffle-fun-r001');prefix='raffle-r001-gemini-native';env=os.environ.copy();env['DOCKER_HOST']='unix:///Users/hishamel-husseini/.lima/glaze-openkritt-daybreak/sock/docker.sock';counter=0
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def run(args,input=None,check=True):
 global counter
 counter+=1;name=f'launch-{counter:02}';p=subprocess.run(args,input=input,text=True,capture_output=True,env=env);(O/(name+'.stdout.txt')).write_text(p.stdout);(O/(name+'.stderr.txt')).write_text(p.stderr);(O/(name+'.command.json')).write_text(json.dumps({'at_utc':now(),'argv':args,'exit_code':p.returncode,'DOCKER_HOST':env['DOCKER_HOST']},indent=2)+'\n')
 if check and p.returncode:raise RuntimeError(f'{name} failed exit {p.returncode}: {p.stderr[-700:]}')
 return p
run(['docker','ps','--format','{{.Names}}\t{{.Status}}'])
for kind,name in [('network',prefix+'-net'),('volume',prefix+'-postgres')]:run(['docker',kind,'create',name])
password=secrets.token_hex(24);(W/'db.env').write_text('POSTGRES_USER=raffle_gemini\nPOSTGRES_DB=raffle_gemini\nPOSTGRES_PASSWORD='+password+'\n');(W/'db.env').chmod(0o600)
dbimage=run(['docker','image','inspect','5660c2cbfea5','--format','{{.Id}}']).stdout.strip();engineimage=run(['docker','image','inspect','2724f091e794','--format','{{.Id}}']).stdout.strip()
run(['docker','run','--detach','--name',prefix+'-db','--network',prefix+'-net','--network-alias','db','--env-file',str(W/'db.env'),'--mount','type=volume,src='+prefix+'-postgres,dst=/var/lib/postgresql/data','--mount','type=bind,src='+str(T/'native-source/database/init')+',dst=/docker-entrypoint-initdb.d,readonly',dbimage])
while True:
 p=subprocess.run(['docker','logs',prefix+'-db'],env=env,text=True,capture_output=True)
 if 'PostgreSQL init process complete; ready for start up.' in p.stdout+p.stderr:break
 state=subprocess.check_output(['docker','inspect',prefix+'-db','--format','{{.State.Status}}'],env=env,text=True).strip()
 if state=='exited':(O/'db-init-failure.txt').write_text(p.stdout+p.stderr);raise RuntimeError('Owned fresh database exited; inspect retained init log')
 time.sleep(2)
run(['docker','logs',prefix+'-db']);run(['docker','exec','-i',prefix+'-db','psql','-v','ON_ERROR_STOP=1','-U','raffle_gemini','-d','raffle_gemini'],input=(W/'seed.sql').read_text())
run(['docker','exec',prefix+'-db','psql','-U','raffle_gemini','-d','raffle_gemini','-Atc',"SELECT row_to_json(x) FROM (SELECT id,status,model,model_provider,harness,thinking_effort,workflow_id,post_script_id,configuration->'post_script_ids' AS post_script_ids FROM public.scans) x;"])
config={'DATABASE_URL':'postgresql://raffle_gemini:'+password+'@db:5432/raffle_gemini','ENGINE_DATA_DIR':'/data','ENGINE_REPO_DIR':'/data/jobs','ENGINE_DOCKER_DATA_DIR_HOST':str(W/'data'),'ENGINE_CHECKOUT_CACHE_DIR':'/data/checkout-cache','ENGINE_CHECKOUT_CACHE_PERSIST_DIR':'/data/checkout-cache-persist','ENGINE_POST_PROCESS_WORKSPACE_MODE':'copy','ENGINE_SCAN_RUNNER_IMAGE':engineimage,'ENGINE_SCAN_RUNNER_MEMORY_MB':'512','ENGINE_SCAN_RUNNER_MEMORY_RESERVATION_MB':'256','ENGINE_SCAN_RUNNER_CPUS':'0.5','ENGINE_MEMORY_RESERVE_GB':'0.25','ENGINE_WORKER_COUNT':'3','ENGINE_MAX_CONCURRENT_SCANS':'1','ENGINE_MAX_WORKERS_PER_SCAN':'3','ENGINE_WORKERS_PER_ACCOUNT':'3','ENGINE_WORKSPACE_SETUP_CONCURRENCY':'2','ENGINE_AUTOSCALE_SCAN_WORKERS_ON_PROVIDER_CAPACITY':'false','ENGINE_RETRY_COUNT':'0','ENGINE_CYBER_SAFETY_RETRY_COUNT':'0','ENGINE_CODEX_AUTO_UPDATE':'false','ENGINE_AUTO_PRUNE_DOCKER_BUILD_CACHE':'false','ENGINE_AUTO_PRUNE_UNUSED_DOCKER_IMAGES':'false','ENGINE_SCAN_CACHE_RETENTION_DAYS':'0','ENGINE_IGNORE_LOW_STORAGE':'true','ENGINE_MIN_FREE_STORAGE_GB':'0','ENGINE_HARNESS_TIMEOUT_SECONDS':'86400','ENGINE_POLL_SECONDS':'2','LOCAL_REPOS_PATH':'/local-repos','RAFFLE_R001_ISOLATED':'1','PYTHONUNBUFFERED':'1','GEMINI_BRIDGE_ROOT':'/data/bridge','GEMINI_SOURCE_MANIFEST':'/source-manifest.json'}
(W/'engine.env').write_text('\n'.join(k+'='+v for k,v in config.items())+'\n');(W/'engine.env').chmod(0o600)
public=dict(config);public['DATABASE_URL']='postgresql://raffle_gemini:[local-password-redacted]@db:5432/raffle_gemini';public['HARNESS_TIMEOUT_NOTE']='Native config ceiling retained for compatibility; Gemini spool harness has no outer deadline and agy --print-timeout 0';(O/'runtime-config-public.json').write_text(json.dumps(public,indent=2)+'\n')
run(['docker','run','--detach','--name',prefix+'-engine','--network',prefix+'-net','--env-file',str(W/'engine.env'),'--mount','type=bind,src='+str(W/'engine')+',dst=/app,readonly','--mount','type=bind,src='+str(W/'data')+',dst=/data','--mount','type=bind,src='+str(W/'repos')+',dst=/local-repos,readonly','--mount','type=bind,src='+str(W/'source-manifest.json')+',dst=/source-manifest.json,readonly','--mount','type=bind,src=/run/user/501/docker.sock,dst=/var/run/docker.sock',engineimage])
for name in ['host_bridge.py','launch_engine.py']:shutil.copy2(W/'scripts'/name,O/name)
shutil.copy2(W/'engine/open_kritt_engine/gemini_bridge.py',O/'gemini_bridge.py');shutil.copy2('/tmp/prepare_gemini_openkritt.py',O/'prepare_gemini_openkritt.py')
(O/'LAUNCHED.json').write_text(json.dumps({'started_utc':now(),'prefix':prefix,'scan_id':1,'engine':prefix+'-engine','database':prefix+'-db','database_user':'raffle_gemini','database_name':'raffle_gemini','DOCKER_HOST':env['DOCKER_HOST'],'engine_image':engineimage,'database_image':dbimage,'bridge':'official native agy host spool','model':'gemini-4-argon-high','effort':'high','review_output_unsealed_do_not_read':True},indent=2)+'\n')
print(json.dumps({'status':'launched','prefix':prefix,'scan_id':1,'output':str(O),'runtime':str(W)}))
