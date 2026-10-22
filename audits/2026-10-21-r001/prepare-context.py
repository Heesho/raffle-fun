from pathlib import Path
import re,shutil,hashlib,json,tarfile
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);v=r/'validation';c=r/'clean-context'
queue=[(v/p,c/p) for p in f['production_scope']];seen=set();deps={}
while queue:
 source,target=queue.pop();key=str(target)
 if key in seen:continue
 seen.add(key)
 if not source.is_file():raise RuntimeError('Missing dependency '+str(source))
 target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists():shutil.copy2(source,target)
 rel=str(target.relative_to(c))
 if 'node_modules/' in rel:deps[rel]=hashlib.sha256(target.read_bytes()).hexdigest()
 for imp in re.findall(r'import\s+(?:[^;]*?\sfrom\s+)?["\']([^"\']+)["\']',source.read_text()):
  if imp.startswith('@'):queue.append((v/'packages/contracts/node_modules'/imp,c/'packages/contracts/node_modules'/imp))
  elif imp.startswith('.'):queue.append(((source.parent/imp).resolve(),(target.parent/imp).resolve()))
  else:raise RuntimeError('Unsupported import '+imp)
(c/'dependency-hashes.json').write_text(json.dumps(deps,indent=2)+'\n');(out/'dependency-hashes.json').write_text(json.dumps(deps,indent=2)+'\n')
with tarfile.open(out/'clean-context.tar.gz','w:gz') as t:t.add(c,arcname='clean-context')
f['dependencies_pending']=False;f['reachable_dependency_files']=deps;f['review_context_sha256']=hashlib.sha256((out/'clean-context.tar.gz').read_bytes()).hexdigest();f['dependency_versions']={'@openzeppelin/contracts':'5.6.1','@chainlink/contracts':'1.5.0','forge-std':'37a36ca389095b2f677abb07642634573ba7e265'}
(out/'freeze.json').write_text(json.dumps(f,indent=2)+'\n')
for p in c.rglob('*'):
 if p.is_file():p.chmod(0o444)
print('Frozen reachable dependencies',len(deps))
