#!/usr/bin/env python3
"""Validate transport/model/protected-file metadata only; never display or judge findings."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import time

HERE = Path(__file__).resolve().parent
def digest(value): return hashlib.sha256(value).hexdigest()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()

def validate(stage):
    cfg_file = HERE / ('native-high-tob-' + stage.lower() + '-stage-config.json')
    cfg = json.loads(cfg_file.read_text())
    output = Path(cfg['outputDir'])
    receipt_file = output / 'transport-result.json'
    if not receipt_file.exists(): return None
    receipt = json.loads(receipt_file.read_text())
    launch_file = output / 'launch.json'
    launch = json.loads(launch_file.read_text())
    flags = launch['argv']
    protected_file = Path(cfg['protectedInputManifest'])
    protected = json.loads(protected_file.read_text())
    after = json.loads((output / 'protected-inputs-after.json').read_text())
    work = Path(cfg['workspace'])
    actual = {name: digest((work / name).read_bytes()) if (work / name).is_file() else None for name in protected}
    inits, terminal_count, delegated = [], 0, []
    tool_counts = {}
    with (output / 'stdout.ndjson').open() as stream:
        for line in stream:
            if not line.strip(): continue
            event = json.loads(line)
            if event.get('event') == 'init': inits.append(event)
            if event.get('event') == 'result': terminal_count += 1
            step = event.get('step_update', {})
            name = step.get('tool_name')
            if name and step.get('state') == 'DONE': tool_counts[name] = tool_counts.get(name, 0) + 1
            if name in ['invoke_subagent', 'define_subagent', 'browser_subagent', 'run_workflow']:
                delegated.append({'step': step.get('step_index'), 'tool': name})
    def value(flag): return flags[flags.index(flag) + 1] if flag in flags else None
    frozen_names = list(json.loads((Path(cfg['promptFile']).parent / 'preparation.json').read_text())['frozen43'])
    checks = {
        'nativeExitZero': receipt.get('exitCode') == 0,
        'transportCompleted': receipt.get('status') == 'native-stage-transport-completed',
        'terminalSuccess': receipt.get('nativeStatus') == 'SUCCESS',
        'explicitCliModelHigh': value('--model') == 'gemini-4-argon-high',
        'explicitCliEffortHigh': value('--effort') == 'high',
        'nativeInitModelHigh': len(inits) == 1 and inits[0]['init'].get('model') == 'gemini-4-argon-high',
        'singleTerminalResult': terminal_count == 1,
        'noNativeDescendantsOrWorkflowDelegates': not delegated and not receipt.get('delegatedStepIndices'),
        'protectedManifestBoundAtLaunch': launch.get('protectedInputManifestSha256') == digest(protected_file.read_bytes()),
        'allProtectedHashesUnchanged': receipt.get('protectedInputsUnchanged') is True and protected == after == actual,
        'complete43FrozenInputsBound': len(frozen_names) == 43 and all(name in protected for name in frozen_names),
        'complete31DependenciesBound': sum('/node_modules/' in name and name.endswith('.sol') for name in frozen_names) == 31,
        'noContinuationRequested': '--continue' not in flags and '-c' not in flags and '--conversation' not in flags,
        'noOuterTimeout': launch.get('outerTimeout') is None and value('--print-timeout') == '0',
    }
    return {'stage': stage, 'validatedUtc': utc(), 'metadataValid': all(checks.values()), 'checks': checks,
            'conversationId': receipt.get('conversationId'), 'usage': receipt.get('usage'),
            'nativeToolsCompleted': tool_counts, 'delegatedEvents': delegated,
            'receipt': str(receipt_file), 'receiptSha256': digest(receipt_file.read_bytes()),
            'rawTrace': str(output / 'stdout.ndjson'), 'rawTraceSha256': digest((output / 'stdout.ndjson').read_bytes()),
            'protectedFileCount': len(protected), 'semanticCompletenessChecked': False,
            'sourceFindingsReadOrJudgedByValidator': False, 'providerInternalRevisionVerified': False}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--watch', action='store_true')
    args = parser.parse_args()
    results = {}
    destinations = HERE / 'tob-a04-receipt-metadata'
    destinations.mkdir(exist_ok=True)
    while True:
        for stage in ['S2', 'S3', 'S4', 'S6']:
            if stage in results: continue
            try: row = validate(stage)
            except (json.JSONDecodeError, FileNotFoundError): continue  # producer may still be writing its receipt
            if row is None: continue
            results[stage] = row
            (destinations / (stage + '.json')).write_text(json.dumps(row, indent=2) + '\n')
            print(json.dumps(row), flush=True)
        if len(results) == 4 or not args.watch: break
        time.sleep(5)
    identities = [row['conversationId'] for row in results.values()]
    summary = {'updatedUtc': utc(), 'completedStages': sorted(results),
               'pendingStages': [stage for stage in ['S2', 'S3', 'S4', 'S6'] if stage not in results],
               'metadataValidForCompleted': all(row['metadataValid'] for row in results.values()),
               'allFourCompletedWithUniqueConversations': len(results) == 4 and len(set(identities)) == 4,
               'semanticCompletenessChecked': False, 'sourceFindingsReadOrJudged': False}
    (destinations / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary), flush=True)

if __name__ == '__main__': main()
