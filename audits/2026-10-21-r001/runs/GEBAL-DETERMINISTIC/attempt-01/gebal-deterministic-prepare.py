import pathlib,json,hashlib,re,shutil,datetime
root=pathlib.Path('/Users/hishamel-husseini/Documents/projects/raffle-fun'); audit=root/'audits/2026-10-21-r001'; runtime=pathlib.Path(json.loads((audit/'freeze.json').read_text())['runtime']); freeze=json.loads((audit/'freeze.json').read_text()); snap=runtime/'snapshot'; validation=runtime/'validation'; dest=runtime/'gebal-deterministic-target'; out=audit/'runs/GEBAL-DETERMINISTIC/attempt-01'; dest.mkdir(exist_ok=True)
# Freeze verification includes original tracked and reachable source dependencies.
errors=[]
for p,h in freeze['files'].items():
 if not (root/p).is_file() or hashlib.sha256((root/p).read_bytes()).hexdigest()!=h:errors.append(p)
for p,h in freeze['reachable_dependency_files'].items():
 if not (validation/p).is_file() or hashlib.sha256((validation/p).read_bytes()).hexdigest()!=h:errors.append('frozen-validation:'+p)
(out/'freeze-before.json').write_text(json.dumps({'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checked':len(freeze['files'])+len(freeze['reachable_dependency_files']),'mismatches':errors},indent=2)+'\n');assert not errors,errors
files={}; queue=[]
def add(rel):
 if rel in files:return
 p=snap/rel
 if not p.is_file():p=validation/rel
 if not p.is_file():raise Exception('Missing '+rel)
 data=p.read_bytes(); target=dest/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);files[rel]=hashlib.sha256(data).hexdigest()
 if rel.endswith('.sol'):queue.append(rel)
for p in (snap/'packages/contracts/src').rglob('*.sol'):add(p.relative_to(snap).as_posix())
for sub in ['unit','fuzz','invariant','security']:
 for p in (snap/('packages/contracts/test/foundry/'+sub)).rglob('*.sol'):add(p.relative_to(snap).as_posix())
for rel in ['packages/contracts/foundry.toml','packages/contracts/remappings.txt','packages/contracts/package.json','package.json','pnpm-lock.yaml']:add(rel)
while queue:
 rel=queue.pop();data=(dest/rel).read_text()
 for imp in re.findall(r'import\s+(?:[^;]*?from\s+)?[\"\']([^\"\']+)[\"\']',data):
  if imp.startswith('.'):q=(pathlib.PurePosixPath(rel).parent/imp).as_posix();import posixpath;q=posixpath.normpath(q)
  elif imp.startswith('forge-std/'):q='packages/contracts/lib/forge-std/src/'+imp[len('forge-std/'):]
  else:q='packages/contracts/node_modules/'+imp
  add(q)
for dep in ['@openzeppelin/contracts','@chainlink/contracts']:
 add('packages/contracts/node_modules/'+dep+'/package.json')
add('packages/contracts/lib/forge-std/package.json')
(out/'target-manifest.json').write_text(json.dumps({'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'target':str(dest),'files':dict(sorted(files.items())),'fileCount':len(files),'testSelection':'Existing local unit, fuzz, invariant, security; fork/EthereumFork.t.sol excluded because RPC/live-chain unavailable and forbidden inside native sandbox','source':'frozen snapshot plus frozen validation dependencies; import closure materialized with exact bytes'},indent=2)+'\n')
print(dest,len(files))
