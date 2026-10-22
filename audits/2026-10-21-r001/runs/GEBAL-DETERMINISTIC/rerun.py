#!/usr/bin/env python3
"""Rerun the disclosed compatibility-v3 deterministic method into a NEW directory."""
import pathlib,sys,json,os,hashlib,subprocess,time,datetime
lane=pathlib.Path(__file__).resolve().parent;prior=lane/'attempt-03';base=pathlib.Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001');target=base/'gebal-deterministic-target';controller=base/'gebal-deterministic-controller-v3';node='/Users/hishamel-husseini/.npm/_npx/2643742ee1db1418/node_modules/node/bin/node'
if len(sys.argv)!=2:raise SystemExit('usage: rerun.py /absolute/new/output-directory')
out=pathlib.Path(sys.argv[1]);assert out.is_absolute() and not out.exists(),'Select a NEW absolute output directory';out.mkdir(parents=True);state=out/'native-state'
for rel,h in json.loads((lane/'attempt-01/target-manifest.json').read_text())['files'].items():assert hashlib.sha256((target/rel).read_bytes()).hexdigest()==h,rel
for rel,h in json.loads((prior/'controller-final-manifest.json').read_text())['files'].items():assert hashlib.sha256((controller/rel).read_bytes()).hexdigest()==h,rel
config=json.loads((prior/'scope-compatible.json').read_text());(out/'scope.json').write_text(json.dumps(config,indent=2)+'\n')
env=os.environ.copy();env.update({'PATH':str(pathlib.Path(node).parent)+':'+env['PATH'],'GEBAL_DOCKER_HOST':'unix:///Users/hishamel-husseini/.lima/gebal/sock/docker.sock','GEBAL_SANDBOX_ROOT':'/Users/hishamel-husseini/.local/share/gebal-runtime/work/raffle-r001-deterministic','GEBAL_ISOLATION_CANARY':'synthetic-not-a-secret'})
prefix=[node,str(controller/'node_modules/tsx/dist/cli.mjs'),str(controller/'packages/cli/src/main.ts'),'--home',str(state)]
def call(name,args):
 start=time.time();p=subprocess.run(prefix+args,cwd=controller,env=env,capture_output=True);(out/(name+'.stdout')).write_bytes(p.stdout);(out/(name+'.stderr')).write_bytes(p.stderr)
 with (out/'commands.jsonl').open('a') as f:f.write(json.dumps({'argv':prefix+args,'exitCode':p.returncode,'durationSeconds':time.time()-start,'startedAt':datetime.datetime.fromtimestamp(start,datetime.timezone.utc).isoformat(),'environmentOverrides':{k:env[k] for k in ['PATH','GEBAL_DOCKER_HOST','GEBAL_SANDBOX_ROOT','GEBAL_ISOLATION_CANARY']}})+'\n')
 return p
p=call('plan',['plan',str(target),'--config',str(out/'scope.json'),'--authorized']);assert p.returncode==0,p.stderr
plan,_=json.JSONDecoder().raw_decode(p.stdout.decode());assert plan['diagnosis']['supported'] and plan['egress']==[] and plan['provider'] is None
assert plan['snapshotHash']=='4ccea2a55fbb3cf6320126f9ffb175c3029d2b94e09b3d1ff4592e1cbc8bd4de'
p=call('approval',['approve',plan['id'],'--hash',plan['hash'],'--actor','delegated-audit-assistant','--reason','User-authorized local bounded deterministic sandbox checks; assistant inspected exact scope and limits. Delegated execution authorization, not a claim the owner reviewed this hash. No remote egress.']);assert p.returncode==0,p.stderr
p=call('run',['run',plan['id']]);_,end=json.JSONDecoder().raw_decode(p.stdout.decode());r=json.loads(p.stdout.decode()[end:]);(out/'result.json').write_text(json.dumps(r,indent=2)+'\n');rid=r['run']['id']
for name,args in [('context',['context',rid,'--output',str(out/'test-inclusive-context.json')]),('report',['report',rid,'--format','json','--output',str(out/'native-report.json')])]:call(name,args)
print(r['run']['state'],rid);sys.exit(p.returncode)
