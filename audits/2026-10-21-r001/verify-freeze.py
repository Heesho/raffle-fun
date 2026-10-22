from pathlib import Path
import hashlib,json,sys
out=Path(__file__).resolve().parent;fp=out/'freeze.json';f=json.loads(fp.read_text());runtime=Path(f['runtime'])
roots={'working_tree':Path(f['repository']),'snapshot':Path(f['snapshot'])};errors=[]
for kind,root in roots.items():
 for name,want in f['files'].items():
  p=root/name;got=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
  if got!=want:errors.append({'root':kind,'path':name,'expected':want,'actual':got})
for name,want in f.get('reachable_dependency_files',{}).items():
 p=runtime/'clean-context'/name;got=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
 if got!=want:errors.append({'root':'clean_dependencies','path':name,'expected':want,'actual':got})
for name in f['production_scope']:
 p=runtime/'clean-context'/name;got=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
 if got!=f['files'][name]:errors.append({'root':'clean_source','path':name,'actual':got})
for archive,hashfile in [('target.tar.gz','target.tar.gz.sha256'),('freeze.json','freeze.json.sha256')]:
 p=out/archive;h=out/hashfile
 if h.exists():
  got=hashlib.sha256(p.read_bytes()).hexdigest();want=h.read_text().split()[0]
  if got!=want:errors.append({'root':'control','path':archive,'expected':want,'actual':got})
p=out/'clean-context.tar.gz'
if hashlib.sha256(p.read_bytes()).hexdigest()!=f['review_context_sha256']:errors.append({'root':'control','path':p.name})
print(json.dumps({'verified_files_per_root':len(f['files']),'dependency_files':len(f.get('reachable_dependency_files',{})),'production_files':len(f['production_scope']),'errors':errors,'ok':not errors}))
sys.exit(bool(errors))
