from pathlib import Path
import json,hashlib,shutil,datetime,subprocess
p=Path(__file__).resolve().parents[1];out=p/'runs/GEMINI-GEBAL-REPAIRED/attempt-03';binding=json.loads((out/'native-intake/binding.json').read_text());f=json.loads((p/'freeze.json').read_text());work=Path(f['runtime'])/'runtime/gemini-native-repairs/GEBAL/attempt-03/work';preserved=out/'sealed-model-output';preserved.mkdir(exist_ok=True)
h=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
for name in ['FIRST-PASS.md','FIRST-PASS.md.sha256','review.json','REVIEW-PROVENANCE.json']:
 if (preserved/name).exists():assert h(preserved/name)==h(work/name)
 else:shutil.copyfile(work/name,preserved/name)
assert (preserved/'FIRST-PASS.md.sha256').read_text().split()[0]==h(preserved/'FIRST-PASS.md')
r=json.loads((preserved/'review.json').read_text());assert r['snapshotHash']==binding['snapshotHash'] and r['contextHash']==binding['contextHash'];prov=json.loads((preserved/'REVIEW-PROVENANCE.json').read_text());assert prov['sourceCoverage']['totalExportedFiles']==39 and prov['sourceCoverage']['reachableDependencyFilesCount']==31
assert all(h(work/n)==v for n,v in {**{n:f['files'][n] for n in f['production_scope']},**f['reachable_dependency_files']}.items())
# Local schema validation/format checking and origin binding are enforced by unmodified native import.
node='/Users/hishamel-husseini/.npm/_npx/2643742ee1db1418/node_modules/node/bin/node';controller=Path(binding['controller']);pre=[node,str(controller/'node_modules/tsx/dist/cli.mjs'),str(controller/'packages/cli/src/main.ts'),'--home',binding['home']]
def call(label,args):
 q=subprocess.run(pre+args,cwd=controller,capture_output=True);(out/(label+'.stdout')).write_bytes(q.stdout);(out/(label+'.stderr')).write_bytes(q.stderr)
 with (out/'native-finalization-commands.jsonl').open('a') as a:a.write(json.dumps({'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'argv':pre+args,'cwd':str(controller),'exit':q.returncode})+'\n')
 assert q.returncode==0,(label,q.stderr.decode());return q.stdout
if not (out/'import-review.stdout').exists():call('import-review',['import-review',binding['runId'],'--input',str(preserved/'review.json'),'--reviewer','Antigravity CLI 1.4.4 / gemini-4-argon-high / explicit high effort; provider-internal identity not returned'])
for fmt in ['json','md','html','sarif']:
 if not (out/('gebal-report.'+fmt)).exists():call('report-'+fmt,['report',binding['runId'],'--format',fmt,'--output',str(out/('gebal-report.'+fmt))])
imported=json.loads((out/'import-review.stdout').read_text());call('evidence-verified',['evidence',imported['evidence'],'--output',str(out/'gebal-import-evidence.json')])
receipt={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'COMPLETE_NATIVE_GEBAL_COLD_REVIEW','method':'unmodified pinned native Gebal intake/context/schema-import/report, source-only external model review','binding':binding,'actualRoute':{'runner':'Antigravity CLI 1.4.4','model':'gemini-4-argon-high','effort':'high','providerInternalIdentity':'not returned'},'contextFiles':39,'dependencyFiles':31,'firstPassSha256':h(preserved/'FIRST-PASS.md'),'reviewSha256':h(preserved/'review.json'),'provenanceReviewHashMatches':prov['reviewArtifact']['sha256']==h(preserved/'review.json'),'reviewImportedIntoOriginalRun':True,'reportGenerated':True,'sourceIntegrityVerified':True,'securityVerdict':'UNREVIEWED_OBSERVATIONS_ONLY','limitations':['source-only; no deterministic tool execution in this cell','exact server-internal model identifier and effort not returned','personal global memory absence checked by metadata inventory; perfect service-side memory isolation not proven']};(out/'COMPLETION-RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:receipt[k] for k in ['status','contextFiles','dependencyFiles','firstPassSha256','reviewImportedIntoOriginalRun','provenanceReviewHashMatches']}))
