import argparse,subprocess,os,json,datetime,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--name',required=True);p.add_argument('--cwd',default='.');p.add_argument('--timeout',type=int,default=120);p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args();cmd=a.command[1:] if a.command[:1]==['--'] else a.command
root=Path(__file__).resolve().parent.parent;dest=root/'audit/S6/logs'/a.name;dest.mkdir(parents=True,exist_ok=False)
env=os.environ.copy();env.update({'PIP_CACHE_DIR':str(root/'audit/cache/pip'),'XDG_CACHE_HOME':str(root/'audit/cache/xdg'),'npm_config_cache':str(root/'audit/cache/npm'),'PYTHONDONTWRITEBYTECODE':'1','SVM_HOME':str(root/'audit/cache/svm'),'SOLC_SELECT_DIR':str(root/'audit/cache/solc-select'),'FOUNDRY_CACHE_PATH':str(root/'audit/cache/foundry'),'HARDHAT_TELEMETRY_DISABLED':'true'})
record={'command':cmd,'cwd':str(Path(a.cwd).resolve()),'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'timeout_seconds':a.timeout,'cache_overrides':{k:env[k] for k in ['PIP_CACHE_DIR','XDG_CACHE_HOME','npm_config_cache','PYTHONDONTWRITEBYTECODE']}}
try:
 r=subprocess.run(cmd,cwd=a.cwd,env=env,capture_output=True,timeout=a.timeout);(dest/'stdout.txt').write_bytes(r.stdout);(dest/'stderr.txt').write_bytes(r.stderr);record['exit_code']=r.returncode
except subprocess.TimeoutExpired as e:
 (dest/'stdout.txt').write_bytes(e.stdout or b'');(dest/'stderr.txt').write_bytes(e.stderr or b'');record['status']='TIMEOUT'
except Exception as e:
 (dest/'stderr.txt').write_text(repr(e));record['status']='LAUNCH_ERROR';record['error']=repr(e)
record['finished_at']=datetime.datetime.now(datetime.timezone.utc).isoformat();(dest/'execution.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record));print((dest/'stderr.txt').read_text(errors='replace')[-4000:])
