from pathlib import Path
import json,re,hashlib,datetime
A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');D=A/'reconciliation/finalization';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ledger=json.loads((D/'METADATA-PATH-BINDINGS-01.json').read_text());ledger['extends']={'path':str(D/'METADATA-PATH-BINDINGS-01.json'),'sha256':sha(D/'METADATA-PATH-BINDINGS-01.json')};ledger['created_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();files=ledger['metadata_files'];added=[]
def add(p,name,h,loc,why,typ='explicit audit-root-relative'):
 assert sha(loc)==h,(str(p),name,str(loc));spec=files.setdefault(str(p),{'sha256':sha(p),'reason':why,'bindings':{}});assert spec['sha256']==sha(p);spec['bindings'][name]={'sha256':h,'resolved_path':str(loc.resolve()),'resolution_type':typ,'reason':why,'original_runtime_identity_claimed':typ=='declared native command cwd'};added.append((str(p),name))
def walk(x):
 if isinstance(x,dict):
  if isinstance(x.get('path'),str) and re.fullmatch('[a-f0-9]{64}',str(x.get('sha256',''))):yield x['path'],x['sha256']
  for v in x.values():yield from walk(v)
 elif isinstance(x,list):
  for v in x:yield from walk(v)
for root in [A/'provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-02',A/'provider-lanes/claude/runs/CLAUDE-TOB']:
 for p in root.rglob('*.json'):
  if p.name not in ['SEAL.json','CONTINUATION-SEAL.json','artifact-manifest.json']:continue
  for name,h in walk(json.loads(p.read_text())):
   if name.startswith('provider-lanes/'):add(p,name,h,A/name,'Sealed capture paths explicitly use the audit-root provider-lanes prefix.')
s=A/'provider-lanes/claude/runs/CLAUDE-SIMAO-PUBLIC-EVIDENCE/attempt-02';cwd=Path(json.loads((s/'command.json').read_text())['cwd'])
for p in (s/'native-capture').rglob('*.sha256'):
 for line in p.read_text().splitlines():
  m=re.match(r'([a-f0-9]{64})\s+[ *]?(.+)$',line)
  if not m:continue
  h,name=m.groups();loc=cwd/name;typ='declared native command cwd';why='Native cwd-relative input/bundle ledger. Exact original command cwd remains available; every hash checked.'
  if p.name=='FIRST-PASS.md.sha256':loc=s/'preserved/FIRST-PASS.md';typ='exact preserved report copy';why='Captured report explicitly identified by native receipt.'
  elif name.startswith('./raw-lens-outputs/'):
   loc=s/'native-capture/evidence'/name;typ='exact captured raw lens output';why='Native preserved ledger raw-lens-outputs subtree is captured under native-capture/evidence, as bound by artifact-manifest. Earlier generic cwd-only attempt failed; no missing-runtime-file identity is asserted.'
  add(p,name,h,loc,why,typ)
g=A/'runs/COORDINATOR-DAYBREAK/attempt-01/gemini-simao-adjudication/integrity-manifest.json';old='0a912087781680f337f64d1772883140c3838065ec53d0493f8f8552488a07d5';copy=D/'PRESERVED-COORDINATOR-INPUTS'/f'{old}.working-register.json';add(g,str(D/'working-register.json'),old,copy,'Original mutable input advanced; INPUT-RECOVERY-QUALIFICATION.json binds this exact prior SHA256 preimage. Literal-path mismatch retained.','qualified historical preimage copy')
ledger['added_record_count']=len(added);out=D/'METADATA-PATH-BINDINGS-02.json';assert not out.exists();out.write_text(json.dumps(ledger,indent=2)+'\n');print(json.dumps({'file':str(out),'sha256':sha(out),'added':len(added),'total_metadata':len(files)},indent=2))
