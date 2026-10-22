from pathlib import Path
import json,hashlib,shutil,subprocess,difflib,datetime
R=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001');A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');T=Path('/Users/hishamel-husseini/.local/share/glaze-audit-harnesses/openkritt/raffle-fun-r001');W=R/'runtime/openkritt-gemini-native';O=A/'provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert not W.exists();assert not O.exists();W.mkdir(parents=True);O.mkdir(parents=True)
for d in ['data/bridge/requests','data/bridge/responses','host-calls','repos','scripts']: (W/d).mkdir(parents=True,exist_ok=True)
shutil.copytree(T/'compat-engine',W/'engine',ignore=shutil.ignore_patterns('__pycache__','.pytest_cache'))
shutil.copytree(R/'clean-context',W/'repos/clean-context')
manifest={str(p.relative_to(R/'clean-context')):sha(p) for p in sorted((R/'clean-context').rglob('*')) if p.is_file()};assert len(manifest)==43,(len(manifest))
assert sum(x.endswith('.sol') for x in manifest)==36
for f,h in manifest.items():assert sha(W/'repos/clean-context'/f)==h
(W/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(O/'frozen-source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Independent provider/harness, transport only. Workflow/DB/queue/post-processing implementations stay exact.
p=W/'engine/open_kritt_engine/harnesses.py';s=p.read_text();old='    normalized = normalize_harness_name(name)\n    provider = model_provider if model_provider is not None else codex_model_provider\n';new=old+'    if normalized == "gemini-cli":\n        from .gemini_bridge import GeminiBridgeHarness\n        return GeminiBridgeHarness()\n';assert s.count(old)==1;s=s.replace(old,new);s=s.replace('raffle-r001-scan-','raffle-r001-gemini-native-scan-').replace('raffle-r001.scan-','raffle-r001-gemini-native.scan-');p.write_text(s)
bridge='''"""Disclosed local transport adapter; native workflow, queue and schema validation unchanged."""
from pathlib import Path
import os,json,time,uuid,hashlib,base64
from jsonschema import validate
from .harnesses import HarnessResult,HarnessOutput,HarnessError
class GeminiBridgeHarness:
 def run(self,prompt,schema,repo_dir,model,thinking_effort=None,env=None,allow_tools=True,runner_image=None):
  if model!='gemini-4-argon-high' or thinking_effort!='high':raise HarnessError('Gemini bridge requires exact Argon High/high',code='configuration_error',retryable=False)
  root=Path(os.environ['GEMINI_BRIDGE_ROOT']);manifest=json.loads(Path(os.environ['GEMINI_SOURCE_MANIFEST']).read_text());repo=Path(repo_dir).resolve();data={}
  for rel,want in manifest.items():
   p=repo/rel
   if not p.is_file():raise HarnessError('Missing frozen source input: '+rel,code='configuration_error',retryable=False)
   raw=p.read_bytes()
   if hashlib.sha256(raw).hexdigest()!=want:raise HarnessError('Changed frozen source: '+rel,code='configuration_error',retryable=False)
   data[rel]=base64.b64encode(raw).decode()
  key=uuid.uuid4().hex;request={'request_id':key,'prompt':prompt,'schema':schema,'repo_dir':str(repo),'model':model,'effort':thinking_effort,'allow_tools':allow_tools,'source_manifest':manifest,'files_base64':data,'runner_image_hint':runner_image}
  request_path=root/'requests'/f'{key}.json';tmp=request_path.with_suffix('.tmp');tmp.write_text(json.dumps(request));tmp.replace(request_path)
  response_path=root/'responses'/f'{key}.json'
  while not response_path.is_file():time.sleep(1)
  result=json.loads(response_path.read_text());output=HarnessOutput(stdout=result.get('stdout',''),stderr=result.get('stderr',''),returncode=result.get('exit_code'),files={'bridge-result.json':json.dumps({k:v for k,v in result.items() if k not in ['stdout','stderr','payload']})})
  if not result.get('ok'):raise HarnessError(result.get('error','Official Gemini CLI failed'),code=result.get('error_code','invalid_output'),harness='gemini-cli',retryable=False,output=output)
  validate(result['payload'],schema)
  return HarnessResult(payload=result['payload'],usage=result.get('usage'),codex_session_id=result.get('conversation_id'),output=output)
'''
(W/'engine/open_kritt_engine/gemini_bridge.py').write_text(bridge)
seed=(T/'evidence/fresh-native-seed.sql').read_text();second=seed.index('INSERT INTO public.scans',seed.index('INSERT INTO public.scans')+1);seed=seed[:second]+'COMMIT;\n';seed=seed.replace('gpt-6-astra','gemini-4-argon-high').replace('OPENAI-OPENKRITT','GEMINI-OPENKRITT-NATIVE').replace('"standard"','"official-native-agy-host-bridge"').replace('"codex"','"gemini"').replace("'codex','codex'","'gemini','gemini-cli'").replace('"post_processing_harness": "gemini"','"post_processing_harness": "gemini-cli"').replace('ultra','high');seed=seed.replace('COMMIT;',"UPDATE public.scans SET configuration=configuration || '{\"frozen_source_commit\":\"9238b6ce8eb7f768c0dcd0cfcef26e1427a03155\",\"transport_method\":\"official agy 1.4.4 host spool bridge; no private provider API\"}'::jsonb WHERE id=1;\nCOMMIT;")
(W/'seed.sql').write_text(seed);shutil.copy2(W/'seed.sql',O/'seed.sql')
# Preserve both upstream and inherited compatibility deltas, not just this last adapter.
for base,name in [(T/'native-source/engine','upstream-to-gemini.patch'),(T/'compat-engine','healthy-compat-to-gemini.patch')]:
 pieces=[]
 for p in sorted((W/'engine/open_kritt_engine').glob('*.py')):
  old=base/'open_kritt_engine'/p.name
  a=old.read_text().splitlines(True) if old.exists() else []
  b=p.read_text().splitlines(True)
  if a!=b:pieces.extend(difflib.unified_diff(a,b,fromfile=str(old),tofile=str(p)))
 (O/name).write_text(''.join(pieces))
for f in ['worker.py','queue.py','db.py','prompting.py','schema.py','models.py','post_processing.py']:
 assert sha(W/'engine/open_kritt_engine'/f)==sha(T/'native-source/engine/open_kritt_engine'/f),f
proof={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'upstream_pin':subprocess.check_output(['git','-C',str(T/'native-source'),'rev-parse','HEAD'],text=True).strip(),'runtime_root':str(W),'output_root':str(O),'frozen_commit':'9238b6ce8eb7f768c0dcd0cfcef26e1427a03155','source_files':len(manifest),'production_files':5,'reachable_dependencies':31,'all_source_hashes_match':True,'method':'actual native Python worker + PostgreSQL engine, not module/DB stubs; official macOS agy filesystem transport bridge','model':'gemini-4-argon-high','effort':'high','outer_timeout':None,'native_print_timeout':0,'automatic_retry':False,'provider_credentials_extracted':False,'source_peer_reports_or_history_loaded':False,'native_core_hashes':{f:sha(W/'engine/open_kritt_engine'/f) for f in ['worker.py','queue.py','db.py','prompting.py','schema.py','models.py','post_processing.py']},'binary':str(A/'provider-route-repair/bin/agy'),'binary_sha256':sha(A/'provider-route-repair/bin/agy')}
(O/'SETUP.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(proof,indent=2))
