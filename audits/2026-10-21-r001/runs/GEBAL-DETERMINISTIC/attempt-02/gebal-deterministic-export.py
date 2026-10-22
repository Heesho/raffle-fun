import pathlib,json,hashlib,shutil,subprocess,os,sys,datetime
base=pathlib.Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001');audit=pathlib.Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');node='/Users/hishamel-husseini/.npm/_npx/2643742ee1db1418/node_modules/node/bin/node'
v2=sys.argv[1]!='1';out=audit/('runs/GEBAL-DETERMINISTIC/attempt-0'+sys.argv[1]);controller=base/('gebal-deterministic-controller-v'+sys.argv[1] if v2 else 'gebal-deterministic-controller');state=base/('gebal-deterministic-home-v'+sys.argv[1]+'-compatible' if v2 else 'gebal-deterministic-home-compatible');raw=(out/'run-compatible.stdout').read_text();_,end=json.JSONDecoder().raw_decode(raw);result=json.loads(raw[end:]);(out/'result-compatible.json').write_text(json.dumps(result,indent=2)+'\n');rid=result['run']['id']
(out/'evidence').mkdir(exist_ok=True)
for execution in result['executions']:
 for h in execution['evidence']:
  src=state/'artifacts'/h;data=src.read_bytes();assert hashlib.sha256(data).hexdigest()==h;shutil.copyfile(src,out/'evidence'/h)
  process=json.loads(data);env=json.loads(process['stdout'])
  (out/'evidence'/(execution['tool']+'-envelope.json')).write_text(json.dumps(env,indent=2)+'\n')
  for key in ['stdout','stderr']:
   if key in env:(out/'evidence'/(execution['tool']+'.'+key)).write_text(env[key])
prefix=[node,str(controller/'node_modules/tsx/dist/cli.mjs'),str(controller/'packages/cli/src/main.ts'),'--home',str(state)]
for name,args in [('context',['context',rid,'--output',str(out/'test-inclusive-native-context.json')]),('report',['report',rid,'--format','json','--output',str(out/'native-report.json')])]:
 p=subprocess.run(prefix+args,capture_output=True);(out/(name+'.stdout')).write_bytes(p.stdout);(out/(name+'.stderr')).write_bytes(p.stderr);print(name,p.returncode)
manifest={str(p.relative_to(controller)):hashlib.sha256(p.read_bytes()).hexdigest() for p in controller.rglob('*') if p.is_file() and 'node_modules' not in p.parts};(out/'controller-final-manifest.json').write_text(json.dumps({'upstream':'9ad24645f92a3821ae4539db5f1be52b48ed379e','controller':str(controller),'files':manifest},indent=2)+'\n')
patch=''
for rel in ['packages/core/src/intake.ts','packages/adapters/src/sandbox.ts']:
 p=subprocess.run(['diff','-u',str(base/'upstreams/gebal'/rel),str(controller/rel)],capture_output=True,text=True);patch+=p.stdout
patch+='\nAdded tests/gas-reports-compatibility.test.ts:\n'+(controller/'tests/gas-reports-compatibility.test.ts').read_text();(out/'controller-compatibility.patch').write_text(patch)
freeze=json.loads((audit/'freeze.json').read_text());root=audit.parent.parent;errors=[]
for p,h in freeze['files'].items():
 if not (root/p).is_file() or hashlib.sha256((root/p).read_bytes()).hexdigest()!=h:errors.append(p)
for p,h in freeze['reachable_dependency_files'].items():
 if hashlib.sha256((base/'validation'/p).read_bytes()).hexdigest()!=h:errors.append('frozen-validation:'+p)
(out/'freeze-after.json').write_text(json.dumps({'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checked':len(freeze['files'])+len(freeze['reachable_dependency_files']),'mismatches':errors},indent=2)+'\n');assert not errors,errors
print(result['run']['state'],[(t['kind'],t['state'],t['detail']) for t in result['tasks']])
