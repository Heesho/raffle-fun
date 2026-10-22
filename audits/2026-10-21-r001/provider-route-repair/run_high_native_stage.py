#!/usr/bin/env python3
"""Explicit High native stage transport; launch only when the coordinator invokes it."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
def digest(data): return hashlib.sha256(data).hexdigest()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write_json(file, value): file.write_text(json.dumps(value, indent=2) + '\n')

def run(config):
    workspace = Path(config['workspace']).resolve(strict=True)
    protected_file = Path(config['protectedInputManifest']).resolve(strict=True)
    protected = json.loads(protected_file.read_text())
    if config.get('requiredBinding'):
        binding = json.loads(Path(config['requiredBinding']).read_text())
        if binding.get('status') != 'bound-only-new12-explicit-high-leaves':
            raise ValueError('Validated12-leaf binding is required before native adjudication')
    for name, expected in protected.items():
        if digest((workspace / name).read_bytes()) != expected:
            raise ValueError('Protected stage input mismatch before launch: ' + name)
    prompt_file = Path(config['promptFile']).resolve(strict=True)
    prompt = prompt_file.read_text()
    if config.get('promptSha256') and digest(prompt.encode()) != config['promptSha256']:
        raise ValueError('Prepared prompt hash mismatch')
    output = Path(config['outputDir']).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir(exist_ok=False)
    cli = Path(config.get('cli', HERE / 'bin/agy')).resolve(strict=True)
    argv = [str(cli), '-p', prompt, '--model', 'gemini-4-argon-high', '--effort', 'high',
            '--dangerously-skip-permissions', '--output-format', 'stream-json',
            '--print-timeout', '0', '--log-file', str(output / 'native.log')]
    launch = {'startedUtc': utc(), 'method': config['method'], 'argv': argv, 'cwd': str(workspace),
              'promptFile': str(prompt_file), 'promptSha256': digest(prompt.encode()),
              'protectedInputManifest': str(protected_file),
              'protectedInputManifestSha256': digest(protected_file.read_bytes()),
              'adapterSha256': digest(Path(__file__).read_bytes()), 'cliSha256': digest(cli.read_bytes()),
              'outerTimeout': None, 'automaticRetries': False, 'fallbackModels': False,
              'expectedModel': 'gemini-4-argon-high', 'expectedEffort': 'high',
              'subagentsPermitted': False, 'historicalBuiltinChildIdentityInferred': False}
    write_json(output / 'launch.json', launch)
    with (output / 'stdout.ndjson').open('x') as stdout, (output / 'stderr.log').open('x') as stderr:
        completed = subprocess.run(argv, cwd=workspace, stdin=subprocess.DEVNULL,
                                   stdout=stdout, stderr=stderr)
    result = {'exitCode': completed.returncode, 'status': 'failed'}
    try:
        inits, terminals, delegated = [], [], []
        for line in (output / 'stdout.ndjson').read_text().splitlines():
            if not line.strip(): continue
            event = json.loads(line)
            if event.get('event') == 'init': inits.append(event)
            if event.get('event') == 'result': terminals.append(event['result'])
            step = event.get('step_update', {})
            if step.get('tool_name') in ['invoke_subagent', 'define_subagent', 'browser_subagent', 'run_workflow']:
                delegated.append(step.get('step_index'))
        if len(inits) != 1 or len(terminals) != 1:
            raise ValueError('Expected exactly one native init/result')
        initial, terminal = inits[0], terminals[0]
        write_json(output / 'native-terminal-result.json', terminal)
        (output / 'report.native-response.md').write_text(terminal.get('response', ''))
        result.update({'conversationId': terminal.get('conversation_id'), 'nativeInit': initial['init'],
                       'usage': terminal.get('usage'), 'nativeStatus': terminal.get('status'),
                       'delegatedStepIndices': delegated})
        if completed.returncode != 0 or terminal.get('status') != 'SUCCESS':
            raise ValueError('Native stage did not succeed')
        if initial['init'].get('model') != 'gemini-4-argon-high':
            raise ValueError('Native model mismatch')
        if initial['init'].get('permission_mode') != 'always-proceed':
            raise ValueError('Native permission mode mismatch')
        if not terminal.get('conversation_id') or terminal['conversation_id'] != initial.get('conversation_id'):
            raise ValueError('Native conversation identity mismatch')
        if delegated: raise ValueError('Stage spawned descendants with unverified identities')
        if not terminal.get('response', '').strip(): raise ValueError('Native stage response was empty')
        result['status'] = 'native-stage-transport-completed'
    except Exception as error:
        result['error'] = str(error)
    after = {name: digest((workspace / name).read_bytes()) if (workspace / name).is_file() else None
             for name in protected}
    write_json(output / 'protected-inputs-after.json', after)
    result['protectedInputsUnchanged'] = after == protected
    if after != protected:
        result.update({'status': 'failed', 'protectedInputMutations': [name for name in protected if after[name] != protected[name]]})
    result.update({'endedUtc': utc(), 'methodCompletenessIndependentlyVerified': False,
                   'historicalChildModelsVerified': False, 'reviewImported': False})
    write_json(output / 'transport-result.json', result)
    return {'status': result['status'], 'conversationId': result.get('conversationId'),
            'outputDir': str(output), 'error': result.get('error')}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    args = parser.parse_args()
    result = run(json.loads(args.config.read_text()))
    print(json.dumps(result, indent=2))
    return 0 if result['status'] == 'native-stage-transport-completed' else 1

if __name__ == '__main__': sys.exit(main())
