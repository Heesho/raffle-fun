"""SETUP ONLY diagnostic binding tests: synthetic marker responses, no findings/model calls."""
import tempfile,json,unittest
from pathlib import Path
import bind_native_leaf_semantic_receipts as b
class TraceTests(unittest.TestCase):
 def fixture(self,root,error='historical synthetic stream interruption',done=True):
  response='SETUP leaf final report';events=[{'event':'init','conversation_id':'setup-uuid','init':{'model':b.MODEL,'permission_mode':'always-proceed'}},{'event':'step_update','step_update':{'step_index':3,'step_type':'agent_response','state':'ACTIVE','text_delta':'SETUP leaf '}},{'event':'step_update','step_update':{'step_index':3,'step_type':'agent_response','state':'DONE' if done else 'ACTIVE','text_delta':'final report'}},{'event':'result','result':{'conversation_id':'setup-uuid','status':'ERROR','error':error,'response':response}}];f=root/'stdout.ndjson';f.write_text('\n'.join(json.dumps(e) for e in events));return f
 def test_preserves_error_and_recovers_new_final_delta(self):
  with tempfile.TemporaryDirectory() as d:
   r=b.trace_check(self.fixture(Path(d)),'historical synthetic stream interruption',2);self.assertEqual(r['nativeTerminalStatus'],'ERROR');self.assertTrue(r['historicalErrorPreserved']);self.assertTrue(r['newFinalStepDeltasEqualNativeResponse'])
 def test_new_error_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(ValueError):b.trace_check(self.fixture(Path(d),'a new failure'),'historical synthetic stream interruption',2)
 def test_no_done_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(ValueError):b.trace_check(self.fixture(Path(d),done=False),'historical synthetic stream interruption',2)
 def test_old_step_cannot_qualify_new_turn(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(ValueError):b.trace_check(self.fixture(Path(d)),'historical synthetic stream interruption',3)

class FullBindingSetupTests(unittest.TestCase):
 def fixture(self,root):
  sources=root/'sources';sources.mkdir();(sources/'input.sol').write_text('SETUP source')
  judge=root/'judge';judge.mkdir();(judge/'input.sol').write_text('SETUP source');out=root/'evidence';out.mkdir();(judge/'.audit-judge-inputs').mkdir();(judge/'.audit-judge-inputs/source.md').write_text('SETUP source')
  prompt=out/'prompt.txt';prompt.write_text('SETUP host: all12 new explicit-High direct leaf transports succeed and the coordinator validates their receipts. Exact native procedure SETUP unchanged.')
  protected=out/'protected.json';b.write(protected,{'input.sol':b.sha(b'SETUP source')});manifest=root/'manifest.json';leaves=[];approved=[]
  for number in range(1,13):
   work=root/f'leafwork{number}';work.mkdir();(work/'input.sol').write_text('SETUP source');(work/'.native-leaf-inputs').mkdir();(work/'.native-leaf-inputs/source.md').write_text('SETUP source');d=root/f'leaf{number}';d.mkdir();cid=f'SETUP-independent-{number}';text=f'SETUP native final {number}'
   init={'event':'init','conversation_id':cid,'init':{'model':b.MODEL,'permission_mode':'always-proceed'}};terminal={'conversation_id':cid,'status':'SUCCESS','response':text}
   events=[init,{'event':'step_update','step_update':{'step_index':1,'step_type':'agent_response','state':'DONE','text_delta':text}},{'event':'result','result':terminal}];(d/'stdout.ndjson').write_text('\n'.join(json.dumps(e) for e in events));b.write(d/'native-terminal-result.json',terminal);b.write(d/'transport-result.json',{'status':'transport-completed','inputHashesUnchanged':True,'delegatedStepIndices':[]});b.write(d/'invocation.json',{'argv':['SETUP-fake-cli','--model',b.MODEL,'--effort','high']});(d/'report.native-response.md').write_text(text)
   leaves.append({'number':number,'perspective':f'SETUP-{number}','outputDir':str(d),'workspace':str(work),'inputHashesBefore':{'input.sol':b.sha(b'SETUP source'),'.native-leaf-inputs/source.md':b.sha(b'SETUP source')}});approved.append({'number':number,'evidenceDir':str(d),'nativeReportSha256':b.sha(text.encode()),'fullNativeReportVerified':True,'closingMethodRequirementsVerified':True,'coordinatorEvidenceReferences':['SYNTHETIC SETUP ONLY']})
  b.write(manifest,{'cell':'PASHOV','leaves':leaves});b.write(out/'preparation.json',{'leafInputManifest':str(manifest),'leafInputManifestSha256':b.sha(manifest.read_bytes())});config=root/'config.json';b.write(config,{'workspace':str(judge),'promptFile':str(prompt),'promptSha256':b.sha(prompt.read_bytes()),'protectedInputManifest':str(protected)});validation=root/'validation.json';b.write(validation,{'validated':True,'validatedBy':'SETUP-ONLY mock coordinator','cell':'PASHOV','inputManifestSha256':b.sha(manifest.read_bytes()),'leaves':approved});return config,validation,judge
 def test_full_twelve_binding_setup(self):
  with tempfile.TemporaryDirectory() as temporary:
   config,validation,judge=self.fixture(Path(temporary));result=b.bind(config,validation);self.assertEqual(result['reportsBound'],12);self.assertFalse(result['modelLaunched']);self.assertEqual(len(list((judge/'.native-leaf-results').glob('leaf-*.md'))),12);self.assertFalse(b.read(judge/'.native-leaf-results/binding.json')['nativeTransportErrorsRenamedSuccess'])
 def test_one_unapproved_closure_blocks_all_writes(self):
  with tempfile.TemporaryDirectory() as temporary:
   config,validation,judge=self.fixture(Path(temporary));v=b.read(validation);v['leaves'][4]['closingMethodRequirementsVerified']=False;b.write(validation,v)
   with self.assertRaises(ValueError):b.bind(config,validation)
   self.assertFalse((judge/'.native-leaf-results').exists())
 def test_pristine_judge_mutation_rejected(self):
  with tempfile.TemporaryDirectory() as temporary:
   config,validation,judge=self.fixture(Path(temporary));(judge/'input.sol').write_text('MUTATED')
   with self.assertRaises(ValueError):b.bind(config,validation)
   self.assertFalse((judge/'.native-leaf-results').exists())

if __name__=='__main__':unittest.main()
