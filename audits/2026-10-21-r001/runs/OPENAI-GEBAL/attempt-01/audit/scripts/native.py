import os, sys, json, pathlib, subprocess, datetime, hashlib

BASE = pathlib.Path(__file__).resolve().parents[2]
UP = BASE.parents[1] / 'upstreams/gebal'
label, *args = sys.argv[1:]
env = os.environ.copy()
env.update(GEBAL_HOME=str(BASE/'gebal-state'), TMPDIR=str(BASE/'audit/tmp'), npm_config_logs_dir=str(BASE/'audit/logs/npm'), npm_config_update_notifier='false', npm_config_cache=str(BASE/'audit/npm-cache'), npm_config_prefix='/Users/hishamel-husseini/.npm/_npx/2643742ee1db1418')
cmd = ['npx','--offline','--yes','--package=node@22.23.3','--package=pnpm@10.34.6','pnpm','--dir',str(UP),'exec','node','--import','tsx','packages/cli/src/main.ts',*args]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
env['npm_config_prefix'] = str(BASE/'audit/toolchain')
r = subprocess.run(cmd, cwd=BASE/'audit/toolchain', env=env, text=True, capture_output=True)
record = {'stageId':label,'command':cmd,'cwd':str(BASE/'audit/toolchain'),'environmentOverrides':{k:env[k] for k in ['GEBAL_HOME','TMPDIR','npm_config_logs_dir','npm_config_update_notifier','npm_config_cache','npm_config_prefix']},'startedAt':started,'finishedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exitCode':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
dest = BASE/'audit/logs'/f'{label}.json'
if dest.exists(): raise RuntimeError('Refusing to overwrite command log')
dest.write_text(json.dumps(record,indent=2)+'\n')
print(r.stdout,end=''); print(r.stderr,end='',file=sys.stderr)
print(f'LOG: {dest}; EXIT: {r.returncode}')
sys.exit(r.returncode)
