"""SETUP ONLY: synthetic fake native CLI, never an audit or real model call."""
import importlib.util,json,tempfile,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('continuation',HERE/'native_leaf_transport_continuation.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class SetupTests(unittest.TestCase):
 def fixture(self,root,variant='success'):
  work=root/'work';work.mkdir();(work/'source.sol').write_text('synthetic setup input')
  evidence=root/'leaf-01';evidence.mkdir();cid='synthetic-original-conversation'
  init={'event':'init','conversation_id':cid,'init':{'model':m.MODEL,'permission_mode':'always-proceed'}}
  terminal={'conversation_id':cid,'status':'ERROR','error':'The stream was interrupted. Please continue the task you were working on.'}
  m.write(evidence/'native-terminal-result.json',terminal);m.write(evidence/'transport-result.json',{'status':'failed','conversationId':cid,'inputHashesUnchanged':True,'delegatedStepIndices':[]})
  (evidence/'stdout.ndjson').write_text(json.dumps(init)+'\n'+json.dumps({'event':'result','result':terminal})+'\n')
  prompt=b'exact synthetic leaf';(evidence/'prompt.txt').write_bytes(prompt)
  m.write(evidence/'invocation.json',{'argv':['fake','--model',m.MODEL,'--effort','high']})
  hashes={'source.sol':m.sha((work/'source.sol').read_bytes())}
  for n in ['input-hashes-before.json','input-hashes-after.json']:m.write(evidence/n,hashes)
  manifest=root/'input-manifest.json';m.write(manifest,{'cell':'SETUP-SYNTHETIC','leaves':[{'number':1,'perspective':'synthetic','outputDir':str(evidence),'workspace':str(work),'runtimePromptSha256':m.sha(prompt),'inputHashesBefore':hashes}]})
  prepared=m.prepare(manifest,1);config=Path(prepared['config']);c=m.read(config)
  cli=root/'fake-cli';final_id=cid if variant!='changed-identity' else 'wrong-new-conversation'
  events=[{**init,'conversation_id':final_id}]
  if variant=='delegation':events.append({'event':'step_update','step_update':{'tool_name':'invoke_subagent'}})
  events.append({'event':'result','result':{'conversation_id':final_id,'status':'SUCCESS','response':'SETUP ONLY synthetic native response','usage':{'total_tokens':0}}})
  cli.write_text('#!/usr/bin/env python3\nimport json\n'+('from pathlib import Path\nPath("source.sol").write_text("mutation")\n' if variant=='mutation' else '')+'\n'.join('print('+repr(json.dumps(e))+')' for e in events)+'\n');cli.chmod(0o755);c['cli']=str(cli);m.write(config,c)
  return config
 def test_same_identity_success(self):
  with tempfile.TemporaryDirectory() as d:
   c=self.fixture(Path(d));r=m.run(c);self.assertEqual(r['status'],'transport-completed');self.assertTrue(r['originalEvidenceUnchanged'])
 def test_changed_identity_rejected(self):
  with tempfile.TemporaryDirectory() as d:self.assertEqual(m.run(self.fixture(Path(d),'changed-identity'))['status'],'failed')
 def test_delegation_rejected(self):
  with tempfile.TemporaryDirectory() as d:self.assertEqual(m.run(self.fixture(Path(d),'delegation'))['status'],'failed')
 def test_mutation_rejected(self):
  with tempfile.TemporaryDirectory() as d:self.assertEqual(m.run(self.fixture(Path(d),'mutation'))['status'],'failed')
 def test_no_overwrite(self):
  with tempfile.TemporaryDirectory() as d:
   c=self.fixture(Path(d));m.run(c)
   with self.assertRaises(FileExistsError):m.run(c)
if __name__=='__main__':unittest.main()
