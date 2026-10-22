from pathlib import Path
import subprocess,hashlib,json,datetime,shutil,tarfile,os
repo=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
runtime=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001')
runtime.mkdir(parents=True,exist_ok=True)
snapshot=runtime/'snapshot'
if snapshot.exists(): raise SystemExit('Snapshot exists; refusing overwrite')
snapshot.mkdir()
files=subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0')
hashes={}; missing=[]; symlinks={}
for name in filter(None,files):
 p=repo/name
 if not p.is_file():
  if not p.is_dir(): missing.append(name)
  continue
 dest=snapshot/name;dest.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(p,dest)
 hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest()
for p in (repo/'packages/contracts/lib/forge-std').rglob('*'):
 if p.is_file() and '.git' not in p.parts:
  name=str(p.relative_to(repo));dest=snapshot/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest);hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest()
for p in sorted((repo/'packages/contracts/src').rglob('*.sol')):
 name=str(p.relative_to(repo))
 if name not in hashes:
  dest=snapshot/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest);hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest()
scope=[p for p in hashes if p.startswith('packages/contracts/src/') and '/mocks/' not in p]
(out/'scope-files.txt').write_text('\n'.join(sorted(scope))+'\n')
for cmd,name in [(['git','diff','--binary','HEAD'],'working-tree.patch'),(['git','status','--porcelain=v1','--untracked-files=all'],'initial-status.txt'),(['git','submodule','status','--recursive'],'submodules.txt')]:
 (out/name).write_bytes(subprocess.check_output(cmd,cwd=repo))
# Status includes this newly created control package, not pre-existing production edits.
freeze={'schema':1,'project':'raffle.fun','repository':str(repo),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'captured_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runtime':str(runtime),'snapshot':str(snapshot),'files':hashes,'missing_tracked_files':missing,'production_scope':sorted(scope),'dependencies_pending':True,'original_worktree_clean':True,'source_only_review_exclusions':['audits/**','packages/contracts/audit/**','packages/contracts/audit-corpus/**','packages/contracts/test/**','packages/contracts/slither.db.json','docs/*AUDIT*','docs/whitepaper/archive/**']}
(out/'freeze.json').write_text(json.dumps(freeze,indent=2)+'\n')
with tarfile.open(out/'target.tar.gz','w:gz') as t:t.add(snapshot,arcname='snapshot')
(out/'target.tar.gz.sha256').write_text(hashlib.sha256((out/'target.tar.gz').read_bytes()).hexdigest()+'  target.tar.gz\n')
for p in snapshot.rglob('*'):
 if p.is_file():p.chmod(0o444)
print(json.dumps({'runtime':str(runtime),'files':len(hashes),'production_files':scope,'archive_bytes':(out/'target.tar.gz').stat().st_size}))
