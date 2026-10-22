"""Disclosed local transport adapter; native workflow, queue and schema validation unchanged."""
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
