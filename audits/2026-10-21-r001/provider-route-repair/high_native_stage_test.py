"""SETUP ONLY: synthetic files and a fake native CLI; no assessed model calls."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('stage_runner', HERE / 'run_high_native_stage.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class StageSetupTests(unittest.TestCase):
    def fixture(self, root, mode='good'):
        work = root / 'work'
        work.mkdir()
        (work / 'protected.txt').write_text('SETUP ONLY synthetic protected input\n')
        manifest = root / 'protected.json'
        runner.write_json(manifest, {'protected.txt': runner.digest((work / 'protected.txt').read_bytes())})
        prompt = root / 'prompt.txt'
        prompt.write_text('SETUP ONLY synthetic prompt')
        cli = root / 'fake-native-cli-SETUP-ONLY'
        cli.write_text('''#!/usr/bin/env python3
import json, pathlib, sys
args=sys.argv
assert args[args.index('--model')+1]=='gemini-4-argon-high'
assert args[args.index('--effort')+1]=='high'
assert args[args.index('--print-timeout')+1]=='0'
mode=MODE
print(json.dumps({'event':'init','conversation_id':'SETUP-only','init':{'model':'wrong' if mode=='wrong' else 'gemini-4-argon-high','permission_mode':'always-proceed'}}))
if mode=='delegate':print(json.dumps({'event':'step_update','step_update':{'tool_name':'run_workflow','step_index':2}}))
if mode=='mutate':pathlib.Path('protected.txt').write_text('synthetic mutation')
print(json.dumps({'event':'result','result':{'conversation_id':'SETUP-only','status':'SUCCESS','response':'SETUP ONLY response','usage':{'input_tokens':1}}}))
'''.replace('MODE', repr(mode)))
        cli.chmod(0o755)
        return {'workspace': str(work), 'protectedInputManifest': str(manifest), 'promptFile': str(prompt),
                'outputDir': str(root / 'output'), 'cli': str(cli), 'method': 'SETUP ONLY fake transport'}

    def test_direct_stage_accepts_only_expected_native_receipt(self):
        with tempfile.TemporaryDirectory(prefix='high-stage-SETUP-ONLY-') as value:
            config = self.fixture(Path(value))
            self.assertEqual(runner.run(config)['status'], 'native-stage-transport-completed')
        with tempfile.TemporaryDirectory(prefix='high-stage-SETUP-ONLY-') as value:
            config = self.fixture(Path(value), 'wrong')
            self.assertEqual(runner.run(config)['status'], 'failed')

    def test_hidden_workflow_delegation_cannot_certify_direct_high_stage(self):
        with tempfile.TemporaryDirectory(prefix='high-stage-SETUP-ONLY-') as value:
            config = self.fixture(Path(value), 'delegate')
            result = runner.run(config)
            self.assertEqual(result['status'], 'failed')
            self.assertIn('descendants', result['error'])

    def test_source_mutation_is_reported_after_native_success(self):
        with tempfile.TemporaryDirectory(prefix='high-stage-SETUP-ONLY-') as value:
            config = self.fixture(Path(value), 'mutate')
            self.assertEqual(runner.run(config)['status'], 'failed')
            receipt = json.loads((Path(config['outputDir']) / 'transport-result.json').read_text())
            self.assertFalse(receipt['protectedInputsUnchanged'])

    def test_adjudication_binding_is_required_before_any_fake_model_call(self):
        with tempfile.TemporaryDirectory(prefix='high-stage-SETUP-ONLY-') as value:
            root = Path(value)
            config = self.fixture(root)
            binding = root / 'binding.json'
            runner.write_json(binding, {'status': 'not-yet-validated'})
            config['requiredBinding'] = str(binding)
            with self.assertRaisesRegex(ValueError, 'binding is required'):
                runner.run(config)
            self.assertFalse(Path(config['outputDir']).exists())

if __name__ == '__main__': unittest.main()
