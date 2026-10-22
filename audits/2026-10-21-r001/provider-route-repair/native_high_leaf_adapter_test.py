"""SETUP ONLY: synthetic input fixtures and fake CLI, never an assessed model call."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('leaf_adapter', HERE / 'native_high_leaf_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
UPSTREAM = Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams')


class LeafSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='native-high-leaf-SETUP-ONLY-')
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def fixture(self, cell='SIMAO'):
        frozen = self.root / 'frozen'
        frozen.mkdir()
        for i in range(5):
            f = frozen / f'packages/contracts/src/Synthetic{i}.sol'
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text('// SETUP ONLY synthetic source\n')
        for i in range(31):
            f = frozen / f'packages/contracts/node_modules/synthetic/Dependency{i}.sol'
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text('// SETUP ONLY synthetic dependency\n')
        for i in range(7):
            (frozen / f'synthetic-config-{i}.txt').write_text('SETUP ONLY\n')
        stage = self.root / cell / 'attempt-03/work'
        stage.mkdir(parents=True)
        for name in adapter.file_map(frozen):
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((frozen / name).read_bytes())
        bundle = stage / '.audit-synthetic'
        bundle.mkdir()
        (bundle / 'source.md').write_text('SETUP ONLY synthetic source bundle\n')
        if cell == 'SIMAO':
            (bundle / 'money-map.md').write_text('SETUP ONLY synthetic money map\n')
        upstream = UPSTREAM / ('0xsimao' if cell == 'SIMAO' else 'pashov/solidity-auditor')
        prefix = 'lens' if cell == 'SIMAO' else 'agent'
        for n in range(1, 13):
            data = b''.join(part.read_bytes() for part in adapter.bundle_parts(cell, n, bundle, upstream))
            (bundle / f'{prefix}-{n}-bundle.md').write_bytes(data)
        config = {'cell': cell, 'stageWorkspace': str(stage), 'bundleDir': str(bundle),
                  'frozenContext': str(frozen), 'upstream': str(upstream),
                  'outputDir': str(self.root / 'evidence'), 'childWorkspaceRoot': str(self.root / 'children')}
        return config

    def fake_cli(self, mode='good'):
        file = self.root / ('fake-CLI-SETUP-ONLY-' + mode)
        code = '''#!/usr/bin/env python3
import json, pathlib, sys
args=sys.argv[1:]
assert args[args.index('--model')+1]=='gemini-4-argon-high'
assert args[args.index('--effort')+1]=='high'
assert args[args.index('--print-timeout')+1]=='0'
identity='SETUP-ONLY-'+pathlib.Path.cwd().name
mode=MODE
print(json.dumps({'event':'init','conversation_id':identity,'init':{'model':'wrong-model' if mode=='wrong' else 'gemini-4-argon-high','permission_mode':'always-proceed'}}))
if mode=='delegate': print(json.dumps({'event':'step_update','step_update':{'step_index':2,'tool_name':'invoke_subagent'}}))
if mode=='mutate': (pathlib.Path.cwd()/'synthetic-config-0.txt').write_text('mutated synthetic fixture')
print(json.dumps({'event':'result','result':{'conversation_id':identity,'status':'SUCCESS','response':'SETUP ONLY synthetic result\\n','usage':{'input_tokens':1,'output_tokens':1,'thinking_tokens':1}}}))
'''.replace('MODE', repr(mode))
        file.write_text(code)
        file.chmod(0o755)
        return file

    def test_exact_templates_keep_all_twelve_native_perspectives_and_no_memory(self):
        simao = (UPSTREAM / '0xsimao/SKILL.md').read_text()
        pashov = (UPSTREAM / 'pashov/solidity-auditor/references/agent-prompts.md').read_text()
        for n in range(1, 13):
            prompt = adapter.render_prompt('SIMAO', simao, n, f'inputs/lens-{n}-bundle.md', b'x\ny\n')
            self.assertIn(f'inputs/lens-{n}-bundle.md (2 lines)', prompt)
            self.assertIn('Last User Out', prompt)
            prompt = adapter.render_prompt('PASHOV', pashov, n, f'inputs/agent-{n}-bundle.md', b'x\n')
            self.assertIn('You are READ-ONLY', prompt)
            self.assertNotIn('Your bundle ends with "Known findings', prompt)
            self.assertEqual('Your gap-hunter specialty' in prompt, n >= 10)

    def test_preparation_copies_all43_actual_files_and_only_own_bundle(self):
        config = self.fixture()
        prepared = adapter.prepare(config)
        self.assertEqual(prepared['status'], 'prepared-no-model-launched')
        manifest = json.loads(Path(prepared['manifest']).read_text())
        self.assertEqual(len(manifest['leaves']), 12)
        for leaf in manifest['leaves']:
            work = Path(leaf['workspace'])
            self.assertEqual(len(list((work / 'packages/contracts/node_modules').rglob('*.sol'))), 31)
            self.assertEqual(len(list((work / '.native-leaf-inputs').glob('*bundle.md'))), 1)
            self.assertEqual(adapter.file_map(work), leaf['inputHashesBefore'])

    def test_bad_stage_or_bundle_is_rejected_without_model_work(self):
        config = self.fixture('PASHOV')
        bundle = Path(config['bundleDir']) / 'agent-1-bundle.md'
        bundle.write_bytes(bundle.read_bytes() + b'foreign or memory append')
        with self.assertRaisesRegex(ValueError, 'exact native plain-scan concatenation'):
            adapter.inspect_inputs(config)
        with self.assertRaisesRegex(ValueError, 'attempt-03'):
            adapter.ensure_stage('PASHOV', self.root / 'PASHOV/attempt-02/work')

    def test_fake_native_transport_detects_model_delegation_and_source_mutation(self):
        config = self.fixture()
        manifest = json.loads(Path(adapter.prepare(config)['manifest']).read_text())
        for number, mode, expected in [(0, 'good', 'transport-completed'), (1, 'wrong', 'failed'),
                                        (2, 'delegate', 'failed'), (3, 'mutate', 'failed')]:
            result = adapter.execute_leaf(manifest['leaves'][number], self.fake_cli(mode))
            self.assertEqual(result['status'], expected)
            if mode == 'mutate':
                self.assertFalse(result['inputHashesUnchanged'])

    def test_qualification_binds_exact_manifest_and_twelve_fake_native_sessions(self):
        config = self.fixture('PASHOV')
        prepared = adapter.prepare(config)
        manifest = Path(prepared['manifest'])
        qualification = self.root / 'qualification.json'
        adapter.write_json(qualification, {'qualified': False})
        with self.assertRaisesRegex(ValueError, 'qualification'):
            adapter.run(manifest, qualification, cli=self.fake_cli())
        adapter.write_json(qualification, {'qualified': True, 'cell': 'PASHOV', 'sourceStageAttempt': '03',
                                          'inputManifestSha256': adapter.digest(manifest.read_bytes()),
                                          'preLensStageVerifiedBy': 'SETUP ONLY mock coordinator',
                                          'evidence': ['SETUP ONLY synthetic provenance']})
        result = adapter.run(manifest, qualification, concurrency=3, cli=self.fake_cli())
        self.assertEqual(result['status'], 'all12-transports-completed')
        self.assertEqual(result['uniqueConversations'], 12)
        with self.assertRaisesRegex(ValueError, 'already been launched'):
            adapter.run(manifest, qualification, cli=self.fake_cli())


if __name__ == '__main__':
    unittest.main()
