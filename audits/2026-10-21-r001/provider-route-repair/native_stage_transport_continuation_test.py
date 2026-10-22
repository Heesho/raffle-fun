"""SETUP ONLY synthetic stage transport tests; no actual model invocation."""
import json,tempfile,unittest
from pathlib import Path
import native_stage_transport_continuation as s
b=s.base
class SyntheticStage(unittest.TestCase):
 def fixture(self,root,wrong=False):
  work=root/'work';work.mkdir();(work/'source').write_text('SETUP');out=root/'native-run';out.mkdir()
  protected=root/'protected.json';b.write(protected,{'source':b.sha(b'SETUP')});b.write(out/'protected-inputs-after.json',b.read(protected))
  prompt=root/'prompt';prompt.write_text('SETUP full native task')
  cid='setup-stage-original';init={'event':'init','conversation_id':cid,'init':{'model':b.MODEL,'permission_mode':'always-proceed'}};terminal={'conversation_id':cid,'status':'ERROR','error':'API error synthetic operation timed out'}
  b.write(out/'transport-result.json',{'status':'failed','conversationId':cid,'protectedInputsUnchanged':True,'delegatedStepIndices':[]});b.write(out/'native-terminal-result.json',terminal)
  (out/'stdout.ndjson').write_text(json.dumps(init)+'\n'+json.dumps({'event':'result','result':terminal})+'\n')
  b.write(out/'launch.json',{'argv':['fake','--model',b.MODEL,'--effort','high'],'protectedInputManifestSha256':b.sha(protected.read_bytes()),'promptSha256':b.sha(prompt.read_bytes())})
  cli=root/'fake-cli';events=[{**init,'conversation_id':'WRONG' if wrong else cid},{'event':'result','result':{'conversation_id':'WRONG' if wrong else cid,'status':'SUCCESS','response':'SETUP final'}}]
  cli.write_text('#!/usr/bin/env python3\n'+'\n'.join('print('+repr(json.dumps(e))+')' for e in events));cli.chmod(0o755)
  original=root/'config.json';b.write(original,{'workspace':str(work),'outputDir':str(out),'protectedInputManifest':str(protected),'promptFile':str(prompt),'cli':str(cli)})
  return Path(s.prepare(original)['config'])
 def test_same_identity(self):
  with tempfile.TemporaryDirectory() as d:self.assertEqual(s.run(self.fixture(Path(d)))['status'],'native-stage-transport-completed')
 def test_changed_identity_rejected(self):
  with tempfile.TemporaryDirectory() as d:self.assertEqual(s.run(self.fixture(Path(d),True))['status'],'failed')
if __name__=='__main__':unittest.main()
