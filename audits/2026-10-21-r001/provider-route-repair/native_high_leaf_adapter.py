#!/usr/bin/env python3
"""Disclosed explicit-High leaf runtime for pinned Simao/Pashov methods.

prepare copies only qualifying same-cell attempt-03 inputs; run requires a
coordinator qualification bound to the prepared manifest. No automatic retry,
model fallback, built-in research agents, judgment, assembly, or review import.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


HERE = Path(__file__).resolve().parent
SIMAO_LENSES = [
    'accounting-desync', 'share-exchange-rate', 'temporal-cohort',
    'liquidation-solvency', 'cross-chain-state', 'rounding-precision',
    'ordering-mev', 'dos-griefing', 'access-trust',
    'integration-assumptions', 'edge-states', 'flow-completeness',
]
PASHOV_SPECIALTIES = [
    'math-precision-agent', 'access-control-agent', 'economic-security-agent',
    'execution-trace-agent', 'invariant-agent', 'periphery-agent',
    'first-principles-agent', 'asymmetry-agent', 'boundary-agent',
    'numerical-gap-agent', 'trust-gap-agent', 'flow-gap-agent',
]
PROMPT_PINS = {
    'SIMAO': ('SKILL.md', '815e1bb9b494d2f4e1bec23b13862207dd4d59069cc56c04c5f80e7c2bf5b800'),
    'PASHOV': ('references/agent-prompts.md', '5285c7bac64ac11e56b6ee36b2a0e9d62b22510ad53be577c00beba573e837e5'),
}
UPSTREAM_REVISIONS = {'SIMAO': '3f81e5803174182a7db07eca87849d2b3d571113',
                      'PASHOV': '8ce544c9c9affab448d3dc4c79191d052e3a57ec'}
KNOWN_PARAGRAPH = '''\nYour bundle ends with "Known findings — ground already walked". Obey it:
spend your effort on new ground, report every bug you find in full —
the listed ones included — and reuse its bug-class labels for the same
class of bug in the same function.\n'''
BOUNDARY_POLICY = '''Runtime isolation policy for this independent leaf call:
Use only the current child workspace's input files and your own native scratchpad.
Do not read parent directories, sibling leaf workspaces, other audits, provider lanes,
personal memory, or external findings. Do not invoke subagents or change models.
The following audit task is the exact pinned upstream leaf prompt with only its
documented bundle path, leaf number, line count, and plain-scan memory condition
resolved. Preserve its output syntax. No judgment or report assembly is requested.'''


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def write_json(file, data):
    file.write_text(json.dumps(data, indent=2) + '\n')


def file_map(root):
    return {str(f.relative_to(root)): digest(f.read_bytes())
            for f in sorted(root.rglob('*')) if f.is_file()}


def extract_template(cell, source, number):
    if cell == 'SIMAO':
        anchor = 'Prompt template (substitute real values):'
    else:
        anchor = '## Single-specialty prompt' if number <= 9 else '## Gap-hunter prompt'
    section = source.split(anchor, 1)[1]
    match = re.search(r'```\n(.*?)\n```', section, re.S)
    if not match:
        raise ValueError('Exact upstream prompt block not found')
    template = match.group(1)
    if cell == 'PASHOV':
        if template.count(KNOWN_PARAGRAPH) != 1:
            raise ValueError('Expected exact conditional upstream known-findings paragraph')
        template = template.replace(KNOWN_PARAGRAPH, '')
    return template


def render_prompt(cell, source, number, bundle_relative, bundle_bytes):
    template = extract_template(cell, source, number)
    prefix = 'lens' if cell == 'SIMAO' else 'agent'
    expected = '{bundle_dir}/' + prefix + '-N-bundle.md'
    if template.count(expected) != 1:
        raise ValueError('Expected exact bundle-path placeholder')
    return template.replace(expected, bundle_relative).replace('XXXX', str(bundle_bytes.count(b'\n')))


def ensure_stage(cell, workspace):
    if cell not in ['SIMAO', 'PASHOV']:
        raise ValueError('Only SIMAO and PASHOV cells are supported')
    suffix = (cell, 'attempt-03', 'work')
    if tuple(workspace.parts[-3:]) != suffix:
        raise ValueError('Only this cell\'s qualifying attempt-03/work is accepted')


def bundle_parts(cell, number, bundle_dir, upstream):
    ref = upstream / 'references'
    if cell == 'SIMAO':
        return [bundle_dir / 'source.md', bundle_dir / 'money-map.md',
                ref / 'simao-method.md', ref / 'attack-lenses' / (SIMAO_LENSES[number - 1] + '.md'),
                ref / 'attack-lenses/shared-rules.md']
    return [bundle_dir / 'source.md', ref / 'senior-auditor-sop.md',
            ref / 'hacking-agents' / (PASHOV_SPECIALTIES[number - 1] + '.md'),
            ref / 'hacking-agents/shared-rules.md', ref / 'report-language.md']


def inspect_inputs(config):
    cell = config['cell']
    stage = Path(config['stageWorkspace']).resolve(strict=True)
    ensure_stage(cell, stage)
    bundle_dir = Path(config['bundleDir']).resolve(strict=True)
    if bundle_dir.parent != stage or not bundle_dir.name.startswith('.audit'):
        raise ValueError('Bundle directory must be this cell\'s own pre-lens stage directory')
    frozen = Path(config['frozenContext']).resolve(strict=True)
    source = file_map(frozen)
    if len(source) != 43 or sum(name.endswith('.sol') for name in source) != 36:
        raise ValueError('Frozen context must contain exactly43 files /36 Solidity files')
    if sum('/node_modules/' in name and name.endswith('.sol') for name in source) != 31:
        raise ValueError('Frozen context must contain all31 pinned dependency Solidity files')
    for name, expected in source.items():
        if digest((stage / name).read_bytes()) != expected:
            raise ValueError('Attempt03 frozen input mismatch: ' + name)
    upstream = Path(config['upstream']).resolve(strict=True)
    revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != UPSTREAM_REVISIONS[cell]:
        raise ValueError('Upstream revision differs from exact pinned method')
    upstream_root = Path(subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', '--show-toplevel'], text=True).strip())
    pin_file, pin_hash = PROMPT_PINS[cell]
    prompt_bytes = (upstream / pin_file).read_bytes()
    if digest(prompt_bytes) != pin_hash:
        raise ValueError('Pinned prompt-template source hash mismatch')
    rows = []
    resource_files = {upstream / pin_file}
    for number in range(1, 13):
        prefix = 'lens' if cell == 'SIMAO' else 'agent'
        name = f'{prefix}-{number}-bundle.md'
        blob = (bundle_dir / name).read_bytes()
        parts = bundle_parts(cell, number, bundle_dir, upstream)
        resource_files.update(part for part in parts if upstream in part.parents)
        if blob != b''.join(part.read_bytes() for part in parts):
            raise ValueError('Bundle differs from exact native plain-scan concatenation: ' + name)
        rows.append({'number': number, 'bundle': str(bundle_dir / name),
                     'bundleSha256': digest(blob), 'bundleBytes': len(blob),
                     'perspective': (SIMAO_LENSES if cell == 'SIMAO' else PASHOV_SPECIALTIES)[number - 1],
                     'parts': [{'path': str(part), 'sha256': digest(part.read_bytes())} for part in parts]})
    for resource in sorted(resource_files):
        relative = str(resource.relative_to(upstream_root))
        pinned_bytes = subprocess.check_output(['git', '-C', str(upstream_root), 'show', revision + ':' + relative])
        if resource.read_bytes() != pinned_bytes:
            raise ValueError('Method resource differs from pinned Git blob: ' + relative)
    return cell, stage, bundle_dir, frozen, source, upstream, prompt_bytes, rows


def prepare(config):
    cell, stage, bundle_dir, frozen, source, upstream, prompt_bytes, rows = inspect_inputs(config)
    output = Path(config['outputDir']).resolve()
    workspaces = Path(config['childWorkspaceRoot']).resolve()
    if stage == workspaces or stage in workspaces.parents:
        raise ValueError('Child workspaces must be outside the active input-stage workspace')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir(exist_ok=False)
    workspaces.parent.mkdir(parents=True, exist_ok=True)
    workspaces.mkdir(exist_ok=False)
    manifest = {'method': 'disclosed-direct-native-High-leaf-runtime-for-pinned-model-agnostic-method',
                'createdUtc': utc(), 'cell': cell, 'stageWorkspace': str(stage),
                'sourceStageAttempt': '03', 'builtInResearchChildrenAccepted': False,
                'upstreamRevision': UPSTREAM_REVISIONS[cell],
                'sourceManifest': source, 'frozenFileCount': len(source),
                'frozenSolidityCount': 36, 'dependencyCount': 31,
                'templateSource': str(upstream / PROMPT_PINS[cell][0]),
                'templateSourceSha256': digest(prompt_bytes),
                'sourceBundleSha256': digest((bundle_dir / 'source.md').read_bytes()),
                'moneyMapSha256': digest((bundle_dir / 'money-map.md').read_bytes()) if cell == 'SIMAO' else None,
                'runtimePolicy': BOUNDARY_POLICY, 'upstreamPromptChanges': 'documented placeholders only; Pashov known-findings paragraph omitted for this memory-off scan',
                'coordinatorQualificationRequiredBeforeModelLaunch': True,
                'sourceStageQualification': config.get('sourceStageQualification'),
                'concurrency': config.get('concurrency', 2), 'nativePrintTimeout': 0,
                'outerWallClockCap': None, 'automaticRetries': False, 'fallbackModels': False,
                'model': 'gemini-4-argon-high', 'effort': 'high',
                'adapterSha256': digest(Path(__file__).read_bytes()), 'leaves': []}
    for row in rows:
        number = row['number']
        work = workspaces / f'leaf-{number:02d}'
        work.mkdir()
        # Copy the enumerated43 actual files individually; never reuse an ignore rule for node_modules.
        for name, expected in source.items():
            dest = work / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(frozen / name, dest)
            if digest(dest.read_bytes()) != expected:
                raise ValueError('Frozen child copy mismatch: ' + name)
        if file_map(work) != source:
            raise ValueError('Actual destination does not match all43 frozen inputs')
        inputs = work / '.native-leaf-inputs'
        inputs.mkdir()
        for common in ['source.md'] + (['money-map.md'] if cell == 'SIMAO' else []):
            shutil.copyfile(bundle_dir / common, inputs / common)
        bundle_name = Path(row['bundle']).name
        shutil.copyfile(row['bundle'], inputs / bundle_name)
        exact = render_prompt(cell, prompt_bytes.decode(), number,
                              '.native-leaf-inputs/' + bundle_name, (inputs / bundle_name).read_bytes())
        evidence = output / f'leaf-{number:02d}'
        evidence.mkdir()
        (evidence / 'upstream-prompt.txt').write_text(exact)
        (evidence / 'prompt.txt').write_text(BOUNDARY_POLICY + '\n\n' + exact)
        original_template = extract_template(cell, prompt_bytes.decode(), number)
        (evidence / 'upstream-template.txt').write_text(original_template)
        inputs_pre = file_map(work)
        write_json(evidence / 'input-hashes-before.json', inputs_pre)
        manifest['leaves'].append({**row, 'workspace': str(work), 'outputDir': str(evidence),
                                   'upstreamPromptSha256': digest(exact.encode()),
                                   'runtimePromptSha256': digest((BOUNDARY_POLICY + '\n\n' + exact).encode()),
                                   'inputHashesBefore': inputs_pre})
    # Recheck the live stage inputs after the complete copy, without changing them.
    for name, expected in source.items():
        if digest((stage / name).read_bytes()) != expected:
            raise ValueError('Active stage inputs changed during preparation: ' + name)
    for row in rows:
        if digest(Path(row['bundle']).read_bytes()) != row['bundleSha256']:
            raise ValueError('Active stage bundle changed during preparation')
    destination = output / 'input-manifest.json'
    write_json(destination, manifest)
    qualification_template = {'qualified': False, 'cell': cell, 'sourceStageAttempt': '03',
                              'inputManifestSha256': digest(destination.read_bytes()),
                              'preLensStageVerifiedBy': None, 'evidence': [],
                              'note': 'Coordinator must establish same-cell attempt03 pre-lens source/money-map/bundle provenance before launching leaves. No findings or other-cell outputs may be inputs.'}
    write_json(output / 'qualification.template.json', qualification_template)
    return {'status': 'prepared-no-model-launched', 'cell': cell,
            'manifest': str(destination), 'inputManifestSha256': digest(destination.read_bytes()),
            'leafCount': 12, 'sourceFilesPerLeaf': 43, 'assessedModelStarted': False,
            'qualificationTemplate': str(output / 'qualification.template.json')}


def execute_leaf(leaf, cli):
    evidence = Path(leaf['outputDir'])
    work = Path(leaf['workspace'])
    before = leaf['inputHashesBefore']
    for name, expected in before.items():
        if digest((work / name).read_bytes()) != expected:
            raise ValueError('Prepared input changed before launch: ' + name)
    prompt = (evidence / 'prompt.txt').read_text()
    if digest(prompt.encode()) != leaf['runtimePromptSha256']:
        raise ValueError('Prepared prompt changed before launch')
    argv = [str(cli), '-p', prompt, '--model', 'gemini-4-argon-high', '--effort', 'high',
            '--dangerously-skip-permissions', '--output-format', 'stream-json',
            '--print-timeout', '0', '--log-file', str(evidence / 'native.log')]
    invocation = {'startedUtc': utc(), 'argv': argv, 'cwd': str(work),
                  'nativeModel': 'gemini-4-argon-high', 'nativeEffort': 'high',
                  'schema': None, 'reasonNoSchema': 'Preserve exact upstream native FINDING/LEAD syntax.',
                  'automaticRetry': False, 'outerTimeout': None}
    write_json(evidence / 'invocation.json', invocation)
    result = {'number': leaf['number'], 'perspective': leaf['perspective'], 'status': 'failed'}
    try:
        with (evidence / 'stdout.ndjson').open('x') as stdout, (evidence / 'stderr.log').open('x') as stderr:
            completed = subprocess.run(argv, cwd=work, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr)
        result['exitCode'] = completed.returncode
        inits, terminals, delegated, tools = [], [], [], []
        with (evidence / 'stdout.ndjson').open() as stdout:
            for line in stdout:
                if not line.strip():
                    continue
                event = json.loads(line)
                if event.get('event') == 'init':
                    inits.append(event)
                if event.get('event') == 'result':
                    terminals.append(event['result'])
                step = event.get('step_update', {})
                tool = step.get('tool_name')
                if tool and tool not in tools:
                    tools.append(tool)
                if tool in ['invoke_subagent', 'define_subagent']:
                    delegated.append(step.get('step_index'))
        if len(inits) != 1 or len(terminals) != 1:
            raise ValueError('Expected exactly one native init/result')
        initial, terminal = inits[0], terminals[0]
        write_json(evidence / 'native-terminal-result.json', terminal)
        (evidence / 'report.native-response.md').write_text(terminal.get('response', ''))
        result.update({'conversationId': terminal.get('conversation_id'), 'nativeInit': initial['init'],
                       'usage': terminal.get('usage'), 'nativeStatus': terminal.get('status'),
                       'tools': tools, 'delegatedStepIndices': delegated})
        if completed.returncode != 0 or terminal.get('status') != 'SUCCESS':
            raise ValueError('Native run did not succeed')
        if initial['init'].get('model') != 'gemini-4-argon-high':
            raise ValueError('Native selected model mismatch')
        if initial['init'].get('permission_mode') != 'always-proceed':
            raise ValueError('Native permission mode mismatch')
        if not terminal.get('conversation_id') or terminal['conversation_id'] != initial.get('conversation_id'):
            raise ValueError('Inconsistent native conversation identity')
        if delegated:
            raise ValueError('Native leaf delegated; downstream model identity is unverified')
        if not terminal.get('response', '').strip():
            raise ValueError('Native raw report was empty')
        result['status'] = 'transport-completed'
    except Exception as error:
        result['error'] = str(error)
    finally:
        after = {name: digest((work / name).read_bytes()) if (work / name).is_file() else None for name in before}
        write_json(evidence / 'input-hashes-after.json', after)
        result['inputHashesUnchanged'] = after == before
        if after != before:
            result['status'] = 'failed'
            result['inputMutations'] = [name for name in before if after[name] != before[name]]
        result['endedUtc'] = utc()
        write_json(evidence / 'transport-result.json', result)
    return result


def run(manifest_file, qualification_file, concurrency=2, cli=HERE / 'bin/agy'):
    if concurrency not in [2, 3]:
        raise ValueError('Disclosed leaf scheduler supports concurrency2 or3 only')
    manifest = json.loads(manifest_file.read_text())
    qualification = json.loads(qualification_file.read_text())
    if qualification.get('qualified') is not True or qualification.get('inputManifestSha256') != digest(manifest_file.read_bytes()):
        raise ValueError('Coordinator qualification must be true and bound to this exact prepared input manifest')
    if qualification.get('cell') != manifest['cell'] or qualification.get('sourceStageAttempt') != '03' or not qualification.get('preLensStageVerifiedBy') or not qualification.get('evidence'):
        raise ValueError('Missing same-cell attempt03 pre-lens provenance qualification')
    leaves = manifest['leaves']
    if [leaf['number'] for leaf in leaves] != list(range(1, 13)):
        raise ValueError('Exactly12 independent ordered upstream perspectives are required')
    output = manifest_file.parent
    launch_file = output / 'leaf-launch.json'
    if launch_file.exists():
        raise ValueError('This prepared leaf run has already been launched; no implicit retry or overwrite')
    write_json(launch_file, {'startedUtc': utc(), 'inputManifestSha256': digest(manifest_file.read_bytes()),
                            'qualification': qualification, 'concurrency': concurrency,
                            'cli': str(cli), 'cliSha256': digest(cli.read_bytes()),
                            'adapterSha256': digest(Path(__file__).read_bytes()),
                            'automaticRetries': False, 'fallbackModels': False, 'outerTimeout': None})
    results = {}
    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        pending = {pool.submit(execute_leaf, leaf, cli): leaf['number'] for leaf in leaves}
        for future in as_completed(pending):
            number = pending[future]
            try:
                results[number] = future.result()
            except Exception as error:
                results[number] = {'number': number, 'status': 'failed', 'error': str(error)}
            write_json(output / 'leaf-progress.json', {'updatedUtc': utc(), 'completed': sorted(results),
                                                       'statuses': {n: row['status'] for n, row in results.items()}})
    ordered = [results[number] for number in range(1, 13)]
    identities = [row.get('conversationId') for row in ordered if row.get('conversationId')]
    all_complete = (all(row['status'] == 'transport-completed' for row in ordered)
                    and len(identities) == 12 and len(set(identities)) == 12)
    result = {'endedUtc': utc(), 'status': 'all12-transports-completed' if all_complete else 'incomplete-leaf-coverage',
              'leafCount': 12, 'uniqueConversations': len(set(identities)), 'leaves': ordered,
              'securityAssessmentClaim': False, 'judgeOrAssemblyPerformed': False, 'reviewImported': False}
    write_json(output / 'leaf-result.json', result)
    # Print transport metadata only; raw findings stay in per-leaf evidence for the coordinating judge.
    return {'status': result['status'], 'output': str(output), 'uniqueConversations': result['uniqueConversations'],
            'failedLeaves': [row['number'] for row in ordered if row['status'] != 'transport-completed']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prep = commands.add_parser('prepare')
    prep.add_argument('config', type=Path)
    execute = commands.add_parser('run')
    execute.add_argument('manifest', type=Path)
    execute.add_argument('--qualification', required=True, type=Path)
    execute.add_argument('--concurrency', type=int, default=2)
    execute.add_argument('--cli', type=Path, default=HERE / 'bin/agy')
    args = parser.parse_args()
    result = prepare(json.loads(args.config.read_text())) if args.command == 'prepare' else run(
        args.manifest.resolve(), args.qualification.resolve(), args.concurrency, args.cli.resolve())
    print(json.dumps(result, indent=2))
    return 1 if result['status'] == 'incomplete-leaf-coverage' else 0


if __name__ == '__main__':
    sys.exit(main())
