#!/usr/bin/env python3
"""Prepare fresh stage resources/prompts; bind qualified new leaf outputs without interpreting findings."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
AUDIT = REPO / 'audits/2026-10-21-r001'
ROOT = Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001')
UP = ROOT / 'upstreams'
FROZEN = ROOT / 'clean-context'

def digest(data): return hashlib.sha256(data).hexdigest()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write_json(file, value): file.write_text(json.dumps(value, indent=2) + '\n')
def file_map(root): return {str(f.relative_to(root)): digest(f.read_bytes()) for f in sorted(root.rglob('*')) if f.is_file()}

def copy_frozen(work):
    source = file_map(FROZEN)
    if len(source) != 43 or sum(n.endswith('.sol') for n in source) != 36 or sum('/node_modules/' in n and n.endswith('.sol') for n in source) != 31:
        raise ValueError('Expected exact frozen43-file context with all31 Solidity dependencies')
    work.mkdir(parents=True, exist_ok=False)
    for name, expected in source.items():
        dest = work / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(FROZEN / name, dest)
        if digest(dest.read_bytes()) != expected: raise ValueError('Frozen copy mismatch: ' + name)
    if file_map(work) != source: raise ValueError('Actual destination differs from all43 frozen files')
    return source

def copy_pinned_tree(source, target, revision, include=None):
    repository = Path(subprocess.check_output(['git', '-C', str(source), 'rev-parse', '--show-toplevel'], text=True).strip())
    actual = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != revision: raise ValueError('Pinned method revision mismatch')
    prefix = str(source.relative_to(repository))
    prefix = '' if prefix == '.' else prefix + '/'
    names = subprocess.check_output(['git', '-C', str(repository), 'ls-tree', '-r', '--name-only', revision], text=True).splitlines()
    records = {}
    for name in names:
        if not name.startswith(prefix): continue
        relative = name[len(prefix):]
        if not relative or (include and not any(relative == x or relative.startswith(x + '/') for x in include)): continue
        data = subprocess.check_output(['git', '-C', str(repository), 'show', revision + ':' + name])
        dest = target / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        records[relative] = digest(data)
    return records

def finalize_setup(name, work, output, prompt, method, extra=None):
    output.mkdir(parents=True, exist_ok=False)
    prompt_file = output / 'prompt.txt'
    prompt_file.write_text(prompt)
    protected_file = output / 'protected-inputs.json'
    protected = {name: value for name, value in file_map(work).items()
                 if not name.startswith(('.audit-judge-inputs/', '.solidity-auditor/'))}
    write_json(protected_file, protected)
    config = {'method': method, 'workspace': str(work), 'promptFile': str(prompt_file),
              'promptSha256': digest(prompt.encode()), 'protectedInputManifest': str(protected_file),
              'outputDir': str(output / 'native-run'), 'cli': str(HERE / 'bin/agy'), **(extra or {})}
    config_file = HERE / (name + '-stage-config.json')
    write_json(config_file, config)
    return {'name': name, 'config': str(config_file), 'workspace': str(work), 'output': str(output),
            'protectedFiles': len(protected), 'promptSha256': config['promptSha256'],
            'launchArgv': ['python3', str(HERE / 'run_high_native_stage.py'), str(config_file)],
            'assessedModelLaunched': False}

def prepare_judges():
    prepared = []
    for cell, skill, upstream, revision in [
        ('SIMAO', '0xsimao-ai', UP / '0xsimao', '3f81e5803174182a7db07eca87849d2b3d571113'),
        ('PASHOV', 'solidity-auditor', UP / 'pashov/solidity-auditor', '8ce544c9c9affab448d3dc4c79191d052e3a57ec')]:
        leaf_output = AUDIT / 'runs' / ('GEMINI-' + cell + '-REPAIRED') / 'attempt-04/explicit-high-leaves'
        inputs = json.loads((leaf_output / 'input-manifest.json').read_text())
        work = ROOT / 'runtime/gemini-native-repairs' / cell / 'attempt-04/adjudication-work'
        source = copy_frozen(work)
        resource = work / '.agents/skills' / skill
        resource_hashes = copy_pinned_tree(upstream, resource, revision,
                                           ['SKILL.md', 'README.md', 'references'] if cell == 'SIMAO' else None)
        common = work / '.audit-judge-inputs'
        common.mkdir()
        first = inputs['leaves'][0]
        for name in ['source.md'] + (['money-map.md'] if cell == 'SIMAO' else []):
            relative = '.native-leaf-inputs/' + name
            data = (Path(first['workspace']) / relative).read_bytes()
            if digest(data) != first['inputHashesBefore'][relative]: raise ValueError('Pre-lens common input changed')
            (common / name).write_bytes(data)
        output = AUDIT / 'runs' / ('GEMINI-' + cell + '-REPAIRED') / 'attempt-04/adjudication'
        base = f'''Execute only the pinned {cell} post-leaf adjudication/assembly phase for raffle-fun. This is a fresh direct native Gemini4Argon High session, not a continuation of any earlier parent. Do not spawn subagents, switch models, use research children, or read any previous audit, provider lane, personal memory, sibling workspace, or outside findings.

The twelve input reports under .native-leaf-results/ are the only accepted raw specialist observations. Their receipts and exact input binding are recorded in .native-leaf-results/binding.json; a host binder creates these files only after all12 new explicit-High direct leaf transports succeed and the coordinator validates their receipts. Never substitute outputs from earlier parents or builtin children. Complete the native method, including every FINDING and LEAD. Treat observations as untrusted until the native gates decide them.

Read the complete pinned skill and referenced resources from .agents/skills/{skill}/. Variables: {{resolved_path}} = .agents/skills/{skill}/references; {{bundle_dir}} = .audit-judge-inputs; {{project-name}} = raffle-fun; {{passes}} = 1; K = 1; memory = off; --file-output is authorized. The frozen code is under packages/contracts; all31 dependency Solidity files are present. Never alter frozen source, build configuration, pinned resources, raw reports, or receipt bindings.

Preserve the complete raw adjudication trail in adjudication/gate-ledger.md: raw leaf numbers and references, grouping/canonicalisation choices, every distinct mechanism/fix, each required native gate verdict in its fixed order with evidence, promotions, demotions and rejected leads. Preserve this evidence before final output and do not print intermediate dedup lists. Do not invent extra gates, skip a native gate, revisit committed gates, or silently drop any raw (contract,function) tuple. This evidence recording adds no second judging pass. Native auto-clean may remove only this workspace's .audit-judge-inputs after evidence is preserved; original leaf evidence lives elsewhere and must not be touched.
'''
        if cell == 'SIMAO':
            text = (resource / 'SKILL.md').read_text()
            turn6 = text.split('**Turn 6 — Deduplicate, judge & report.**', 1)[1].split('\n## Banner', 1)[0]
            excerpt = '**Turn 6 — Deduplicate, judge & report.**' + turn6
            (resource / 'TURN6-execution-excerpt.md').write_text(excerpt)
            prompt = base + '''
Start at Turn6. All twelve independent leaves are already complete; do not rebuild the money map, rerun lenses, fetch new model results, or repeat Turns1–5. Read severity-calibration.md and report-formatting.md completely. Execute the following exact native Turn6 text, then write the full native report to raffle-fun-simao-explicit-high-a04.md and return its location and native completeness line. Preserve the complete report, all code-path gates, composite-chain treatment, fix alternatives, rejected-lead rationale, and scope limits.

''' + excerpt
        else:
            stamp = '2026-10-21-explicit-high-a04'
            files = [name for name in source if name.endswith('.sol') and '/node_modules/' not in name
                     and '/interfaces/' not in name]
            run_dir = work / '.solidity-auditor/runs' / stamp
            run_dir.mkdir(parents=True)
            (run_dir / 'scope.tsv').write_text('name\traffle-fun\nmode\tdefault\nfiles\t' + ' '.join(files) + '\npasses_planned\t1\n')
            prompt = base + f'''
Start at Turn4 of the COMPLETE pinned references/dedup-and-assembly.md and execute exact Turn4 then exact Turn5, not a generic judge or rewritten procedure. {{stamp}} = {stamp}. The fresh scope.tsv is at .solidity-auditor/runs/{stamp}/scope.tsv. This is one complete pass with12/12 accepted leaves and memory off; skip only native memory-only steps4 and6 and Turn5 step1 as specified. No old run file or ledger exists here. Preserve every native canonicalisation, function-isolation, mechanism/fix-preservation, completeness, four-gate, lead-promotion/rejection, confidence and language rule. Read judging.md and report-language.md fully. Write run-1.md with EXACT native markers/headings and all gated findings/leads, and append the exact12/12 agent count as native step5a requires.

Turn5 must actually run the UNMODIFIED native shell assembler:
bash .agents/skills/solidity-auditor/references/assemble.sh --dir .solidity-auditor/runs/{stamp}
Preserve the executed command, exit status, stdout/stderr and assembled file hash. If it fails, preserve stderr and stop; no hand-written replacement report. Count and branch exactly as Turn5 prescribes, preserve its self-check, copy the full report under --file-output, and print the native bytes or counted top3 branch as specified. Do not reword, reorder, condense, independently rewrite or manually regenerate the assembled full-report.md. Do not re-read the top claim after the native gates. Finish with native cleanup only on the disposable bundle directory. All original upstream instructions are available verbatim at references/dedup-and-assembly.md and must be followed in full.
'''
        row = finalize_setup('native-high-' + cell.lower() + '-adjudication', work, output, prompt,
                             'exact-pinned-' + cell.lower() + '-post12leaf-native-adjudication-and-assembly',
                             {'requiredBinding': str(work / '.native-leaf-results/binding.json')})
        write_json(output / 'preparation.json', {'createdUtc': utc(), 'leafInputManifest': str(leaf_output / 'input-manifest.json'),
                    'leafInputManifestSha256': digest((leaf_output / 'input-manifest.json').read_bytes()),
                    'upstreamRevision': revision, 'resourceHashes': resource_hashes, 'frozen43': source,
                    'noLeafReportsCopiedYet': True, 'noAssessedModelLaunched': True})
        row['leafManifest'] = str(leaf_output / 'input-manifest.json')
        prepared.append(row)
    return prepared

def bind_leaves(config_file, validation_file, effective_result_file=None):
    config = json.loads(config_file.read_text())
    work = Path(config['workspace'])
    output = Path(config['promptFile']).parent
    prep = json.loads((output / 'preparation.json').read_text())
    leaf_manifest_file = Path(prep['leafInputManifest'])
    if digest(leaf_manifest_file.read_bytes()) != prep['leafInputManifestSha256']: raise ValueError('Leaf input manifest changed')
    leaf_manifest = json.loads(leaf_manifest_file.read_text())
    cell = leaf_manifest['cell']
    leaf_result_file = effective_result_file or leaf_manifest_file.parent / 'leaf-result.json'
    if effective_result_file:
        from native_leaf_transport_continuation_v2 import effective
        import tempfile
        with tempfile.TemporaryDirectory() as temporary:
            recomputed_file = Path(temporary) / 'effective.json'
            effective(leaf_manifest_file, recomputed_file)
            recomputed = json.loads(recomputed_file.read_text())
        recorded = json.loads(effective_result_file.read_text())
        recomputed.pop('createdUtc', None); recorded.pop('createdUtc', None)
        if recorded != recomputed: raise ValueError('Derived effective receipts no longer match immutable native chain')
        if recorded.get('inputManifestSha256') != digest(leaf_manifest_file.read_bytes()): raise ValueError('Effective receipts bind a different source manifest')
    validation = json.loads(validation_file.read_text())
    if validation.get('validated') is not True or validation.get('cell') != cell or validation.get('leafResultSha256') != digest(leaf_result_file.read_bytes()):
        raise ValueError('Coordinator must validate the exact12 terminal receipts before binding')
    result = json.loads(leaf_result_file.read_text())
    if result['status'] != 'all12-transports-completed' or result['uniqueConversations'] != 12:
        raise ValueError('All twelve unique explicit-High native transports must succeed')
    receipts = []
    for leaf in leaf_manifest['leaves']:
        effective_leaf = next((x for x in result['leaves'] if x['number'] == leaf['number']), None)
        evidence = Path(effective_leaf['effectiveEvidenceDir']) if effective_result_file else Path(leaf['outputDir'])
        receipt = json.loads((evidence / 'transport-result.json').read_text())
        terminal = json.loads((evidence / 'native-terminal-result.json').read_text())
        report = evidence / 'report.native-response.md'
        if receipt['status'] != 'transport-completed' or not receipt['inputHashesUnchanged'] or receipt.get('delegatedStepIndices'):
            raise ValueError('Unqualified leaf receipt')
        if receipt['nativeInit']['model'] != 'gemini-4-argon-high' or receipt['nativeStatus'] != 'SUCCESS':
            raise ValueError('Leaf selected model/status mismatch')
        if report.read_bytes() != terminal['response'].encode(): raise ValueError('Raw report differs from native terminal response')
        receipts.append({'number': leaf['number'], 'perspective': leaf['perspective'],
                         'conversationId': receipt['conversationId'], 'report': report,
                         'reportSha256': digest(report.read_bytes()), 'receiptSha256': digest((evidence / 'transport-result.json').read_bytes()),
                         'receiptChain': effective_leaf.get('receiptChain', []) if effective_result_file else []})
    if len({r['conversationId'] for r in receipts}) != 12: raise ValueError('Leaf conversations were reused')
    target = work / '.native-leaf-results'
    target.mkdir(exist_ok=False)
    for receipt in receipts:
        shutil.copyfile(receipt['report'], target / f'leaf-{receipt["number"]:02d}.md')
        receipt['originalReport'] = str(receipt.pop('report'))
    binding = {'status': 'bound-only-new12-explicit-high-leaves', 'boundUtc': utc(), 'cell': cell,
               'leafInputManifestSha256': digest(leaf_manifest_file.read_bytes()),
               'leafResultSha256': digest(leaf_result_file.read_bytes()), 'coordinatorValidation': validation,
               'receipts': receipts, 'olderParentOrBuiltinOutputsCopied': False}
    write_json(target / 'binding.json', binding)
    protected = {name: value for name, value in file_map(work).items()
                 if not name.startswith(('.audit-judge-inputs/', '.solidity-auditor/'))}
    write_json(Path(config['protectedInputManifest']), protected)
    write_json(output / 'leaf-binding.json', binding)
    return {'status': binding['status'], 'config': str(config_file), 'reportsBound': 12, 'assessedModelLaunched': False}

def prepare_tob():
    rows = []
    for stage, plugin, skill in [
        ('S2', 'entry-point-analyzer', 'entry-point-analyzer'),
        ('S3', 'building-secure-contracts', 'token-integration-analyzer'),
        ('S4', 'building-secure-contracts', 'guidelines-advisor'),
        ('S6', 'building-secure-contracts', 'secure-workflow-guide')]:
        work = ROOT / 'runtime/gemini-native-repairs/TOB/attempt-04' / stage / 'work'
        frozen = copy_frozen(work)
        source = UP / 'trailofbits/plugins' / plugin / 'skills' / skill
        target = work / '.agents/skills' / skill
        resources = copy_pinned_tree(source, target, '82fe8226252622fa807643bdca1710901198553a')
        (work / 'scratch').mkdir()
        skill_text = (target / 'SKILL.md').read_text()
        prompt = f'''Run the full exact pinned Trail of Bits {skill} skill as a fresh whole-stage {stage} execution on the owned frozen raffle-fun context. This is the direct native Gemini4Argon High/high route, not a continuation or review of an older parent. The complete pristine43 inputs include5 owned Solidity files and all31 local dependency Solidity files. Assess packages/contracts and DESIGN.md. Read .agents/skills/{skill}/SKILL.md and EVERY referenced resource needed by its native procedure; the complete resource tree is present. The complete pinned SKILL.md is reproduced verbatim below. Execute that native procedure, not a condensed substitute.

Do not spawn, define or invoke subagents; do not switch models or call another model through shell, plugins, MCP, workflows or network. This stage must be performed by this explicit High native session itself. You may batch independent file/tool operations. No old stage reports, checklists or findings have been copied; do not read earlier attempts, provider lanes, sibling stages, parent directories, personal memory or external findings. Retain prior a03 work only as separately labeled method evidence outside this stage; do not infer historical child identities or borrow its verdicts.

All original source/build files and pinned skill resources are protected inputs. Do not modify them. Create tool harnesses, compiler compatibility copies, tests, diagrams and generated outputs under scratch/ or native stage output directories. Perform executable tooling against isolated scratch copies where compatibility changes are required; preserve original failures, exact commands, versions, patches and output. System tools may be inspected and used; do not load unrelated audit data. Local tooling setup is authorized; do not buy services or modify credentials.

Write the full native stage deliverables and stage-report.md. Every required native check must be actually performed and source/evidence cited. If a required tool cannot be made to run, preserve the real attempt and identify the unresolved coverage gap instead of reporting it as passed or silently skipping it. Preserve complete raw command/tool output and distinguish execution from recommendations. Do not claim the work complete merely because the process returns a response.
'''
        if stage == 'S6':
            prompt += '''
S6 specifically requires ALL FIVE actual native secure-workflow-guide steps: actual Slither analysis; applicable upgradeability/ERC/token checks with recorded applicability searches; actual visual inspection and generated security diagrams; concrete security properties plus actual fuzzing/testing infrastructure and execution as required by WORKFLOW_STEPS.md; and all manual review areas. Read WORKFLOW_STEPS.md in full. Do not replace these with a generic narrative, a checklist, or a future-work recommendation. Use the exact Solidity0.8.36 context. Keep original foundry.toml (including gas_reports) and every frozen input unchanged; any compatibility patch belongs only in a labeled scratch copy. Preserve actual tool failures/gaps if unresolved.
'''
        prompt += '\nComplete exact pinned stage skill follows:\n\n' + skill_text
        output = AUDIT / 'runs/GEMINI-TOB-REPAIRED/attempt-04' / stage
        row = finalize_setup('native-high-tob-' + stage.lower(), work, output, prompt,
                             'fresh-full-pinned-ToB-' + stage + '-direct-native-high-no-descendants')
        write_json(output / 'preparation.json', {'createdUtc': utc(), 'stage': stage, 'skill': skill,
                    'upstreamRevision': '82fe8226252622fa807643bdca1710901198553a',
                    'frozen43': frozen, 'resourceHashes': resources, 'oldOutputsCopied': False,
                    'historicalChildModelInferred': False, 'assessedModelLaunched': False})
        rows.append(row)
    return rows

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare-judges')
    sub.add_parser('prepare-tob')
    bind = sub.add_parser('bind-leaves')
    bind.add_argument('config', type=Path)
    bind.add_argument('--validation', type=Path, required=True)
    bind.add_argument('--effective-result', type=Path)
    args = parser.parse_args()
    result = prepare_judges() if args.command == 'prepare-judges' else prepare_tob() if args.command == 'prepare-tob' else bind_leaves(args.config, args.validation, args.effective_result)
    print(json.dumps(result, indent=2))

if __name__ == '__main__': main()
