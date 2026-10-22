#!/usr/bin/env python3
"""Run an explicitly prepared prompt in a fresh native Antigravity session.

No wall-clock timeout, automatic retries, continuation, fallback, or report import.
The controller must prepare and verify the workspace and pinned resources first.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--prompt-file', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--agent', help='Prepared workspace custom agent name')
    parser.add_argument('--mode', choices=['plan', 'auto', 'accept-edits'], default='plan')
    parser.add_argument('--dangerously-skip-permissions', action='store_true',
                        help='Authorized isolated local workflow: approve tool calls for this run')
    args = parser.parse_args()
    workspace = args.workspace.resolve(strict=True)
    prompt_path = args.prompt_file.resolve(strict=True)
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binary = Path(__file__).resolve().parent / 'bin/agy'
    prompt = prompt_path.read_text()
    argv = [str(binary), '-p', prompt, '--model', 'gemini-4-argon-high',
            '--effort', 'high', '--output-format', 'stream-json',
            '--mode', args.mode, '--print-timeout', '0',
            '--log-file', str(output / 'native.log')]
    if args.agent:
        argv += ['--agent', args.agent]
    if args.dangerously_skip_permissions:
        argv += ['--dangerously-skip-permissions']
    manifest = {
        'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'argv': argv, 'cwd': str(workspace),
        'prompt_path': str(prompt_path),
        'prompt_sha256': hashlib.sha256(prompt_path.read_bytes()).hexdigest(),
        'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
        'expected_model': 'gemini-4-argon-high', 'expected_effort': 'high',
        'outer_timeout': None, 'native_print_timeout': '0',
        'resume_requested': False, 'automatic_retries': False,
        'global_context_isolation': 'not guaranteed; inspect documented global paths',
    }
    (output / 'launch.json').write_text(json.dumps(manifest, indent=2) + '\n')
    with (output / 'stdout.ndjson').open('w') as stdout, (output / 'stderr.log').open('w') as stderr:
        result = subprocess.run(argv, cwd=workspace, stdin=subprocess.DEVNULL,
                                stdout=stdout, stderr=stderr)
    init = None
    terminal = None
    malformed = 0
    with (output / 'stdout.ndjson').open() as stdout:
        for line in stdout:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                malformed += 1
                continue
            if event.get('event') == 'init':
                init = event.get('init')
            if event.get('event') == 'result':
                terminal = event.get('result')
    checks = {
        'exit_code': result.returncode,
        'init_model': init.get('model') if init else None,
        'conversation_id': terminal.get('conversation_id') if terminal else None,
        'terminal_status': terminal.get('status') if terminal else None,
        'usage': terminal.get('usage') if terminal else None,
        'malformed_stdout_lines': malformed,
        'provider_internal_revision': None,
        'report_import_performed': False,
        'ended_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    checks['transport_verified'] = (
        result.returncode == 0 and checks['init_model'] == 'gemini-4-argon-high'
        and checks['terminal_status'] == 'SUCCESS' and malformed == 0
    )
    (output / 'transport-result.json').write_text(json.dumps(checks, indent=2) + '\n')
    print(json.dumps(checks, indent=2))
    return 0 if checks['transport_verified'] else 1


if __name__ == '__main__':
    sys.exit(main())
