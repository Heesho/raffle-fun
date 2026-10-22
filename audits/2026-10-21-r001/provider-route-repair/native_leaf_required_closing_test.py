"""SETUP ONLY synthetic successful-original closing turns; no native model/audit work."""
import json,tempfile,unittest
from pathlib import Path
import native_leaf_required_closing as m
class ClosingTests(unittest.TestCase):
 def fixture(self,root,wrong=False,approved=True):
  work=root/'work';work.mkdir();(work/'input').write_text('SETUP');d=root/'leaf-02';d.mkdir();cid='setup-original-id';init={'event':'init','conversation_id':cid,'init':{'model':m.MODEL,'permission_mode':'always-proceed'}};t={'conversation_id':cid,'status':'SUCCESS','response':'SETUP ORIGINAL'}
  m.write(d/'transport-result.json',{'status':'transport-completed','conversationId':cid,'inputHashesUnchanged':True,'delegatedStepIndices':[]});m.write(d/'native-terminal-result.json',t);(d/'stdout.ndjson').write_text(json.dumps(init)+'\n'+json.dumps({'event':'result','result':t}));(d/'prompt.txt').write_text('SETUP original task');m.write(d/'invocation.json',{'argv':['fake','--model',m.MODEL,'--effort','high']});hashes={'input':m.sha(b'SETUP')}
  for name in ['input-hashes-before.json','input-hashes-after.json']:m.write(d/name,hashes)
  manifest=root/'manifest.json';m.write(manifest,{'cell':'SIMAO','leaves':[{'number':2,'perspective':'SETUP','outputDir':str(d),'workspace':str(work),'runtimePromptSha256':m.sha(b'SETUP original task'),'inputHashesBefore':hashes}]});gap=root/'gap.json';m.write(gap,{'coordinatorVerifiedClosingGap':approved,'verifiedBy':'/root','cell':'SIMAO','leaf':2})
  if not approved:return manifest,gap
  cfile=Path(m.prepare(manifest,2,gap)['config']);c=m.read(cfile);cli=root/'fake-cli';newcid='wrong-new-id' if wrong else cid;events=[{**init,'conversation_id':newcid},{'event':'result','result':{'conversation_id':newcid,'status':'SUCCESS','response':'SETUP final closing response'}}];cli.write_text('#!/usr/bin/env python3\n'+'\n'.join('print('+repr(json.dumps(e))+')' for e in events));cli.chmod(0o755);c['cli']=str(cli);m.write(cfile,c);return cfile,d
 def test_preserves_original_success(self):
  with tempfile.TemporaryDirectory() as temporary:
   c,d=self.fixture(Path(temporary));before=m.sha((d/'transport-result.json').read_bytes());r=m.run(c);self.assertEqual(r['status'],'transport-completed');self.assertEqual(m.sha((d/'transport-result.json').read_bytes()),before);self.assertEqual(m.read(d/'native-terminal-result.json')['status'],'SUCCESS')
 def test_identity_change_rejected(self):
  with tempfile.TemporaryDirectory() as temporary:self.assertEqual(m.run(self.fixture(Path(temporary),True)[0])['status'],'failed')
 def test_requires_verified_closing_gap(self):
  with tempfile.TemporaryDirectory() as temporary:
   manifest,gap=self.fixture(Path(temporary),approved=False)
   with self.assertRaises(ValueError):m.prepare(manifest,2,gap)
if __name__=='__main__':unittest.main()
