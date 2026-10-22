#!/usr/bin/env python3
"""Coordinator-required original closing work in the SAME successful leaf conversation; not a transport retry or new lens."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import datetime

HERE = Path(__file__).resolve().parent
MODEL = 'gemini-4-argon-high'
FORBIDDEN = {'invoke_subagent', 'define_subagent', 'browser_subagent', 'run_workflow'}
PROMPT = '''Continue the exact independent native audit task already assigned in this conversation, from its preserved progress, to its COMPLETE native final response. The preceding turn ended due to a transport interruption or timeout. This is the same leaf and the same conversation, not another reviewer or a new lens. Keep the original assigned perspective, complete all original required checks, and preserve the exact original native FINDING/LEAD output syntax. Do not stop at a progress update. Use only your existing isolated workspace inputs and your own progress; do not read parent directories, sibling reports, other audit attempts, provider lanes, personal memory or outside findings. Do not spawn, define or invoke subagents, change models, or run another model through shell, network, plugins or workflows. Do not modify original source, resource, bundle or prompt inputs. Return the complete native final report for your original assigned leaf.'''

def sha(b): return hashlib.sha256(b).hexdigest()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(p): return json.loads(Path(p).read_text())
def write(p, value): Path(p).write_text(json.dumps(value, indent=2) + '\n')
def fingerprint(paths): return {str(p): sha(Path(p).read_bytes()) for p in paths}
def check_files(work, files):
    actual = {n: sha((work/n).read_bytes()) if (work/n).is_file() else None for n in files}
    if actual != files: raise ValueError('Protected original leaf input changed')
    return actual

def native_events(path):
    inits, terminals, delegated, tools = [], [], [], []
    for line in Path(path).read_text().splitlines():
        if not line.strip(): continue
        event = json.loads(line)
        if event.get('event') == 'init': inits.append(event)
        if event.get('event') == 'result': terminals.append(event['result'])
        tool = event.get('step_update', {}).get('tool_name')
        if tool and tool not in tools: tools.append(tool)
        if tool in FORBIDDEN: delegated.append(tool)
    if len(inits) != 1 or len(terminals) != 1: raise ValueError('Expected exactly one native init and terminal result')
    return inits[0], terminals[0], delegated, tools

def original_qualified(manifest_file, number):
    manifest = read(manifest_file)
    leaf = next(x for x in manifest['leaves'] if x['number'] == number)
    evidence, work = Path(leaf['outputDir']), Path(leaf['workspace'])
    receipt = read(evidence/'transport-result.json')
    init, terminal, delegated, _ = native_events(evidence/'stdout.ndjson')
    cid = receipt.get('conversationId')
    if not cid or cid != init.get('conversation_id') or cid != terminal.get('conversation_id'): raise ValueError('Original identity inconsistent')
    if init['init'].get('model') != MODEL or init['init'].get('permission_mode') != 'always-proceed': raise ValueError('Original selected route mismatch')
    if receipt.get('status') != 'transport-completed' or terminal.get('status') != 'SUCCESS': raise ValueError('This closing-work route requires a preserved successful original leaf')
    failure_class = 'coordinator-required-original-native-closing-work'
    if delegated or receipt.get('delegatedStepIndices') or not receipt.get('inputHashesUnchanged'): raise ValueError('Original delegate/mutation disqualifies continuation')
    check_files(work, leaf['inputHashesBefore'])
    if read(evidence/'input-hashes-after.json') != leaf['inputHashesBefore']: raise ValueError('Original after hashes mismatch')
    invocation = read(evidence/'invocation.json')
    argv = invocation['argv']
    if argv[argv.index('--model')+1] != MODEL or argv[argv.index('--effort')+1] != 'high' or '--conversation' in argv: raise ValueError('Original argv route mismatch')
    if sha((evidence/'prompt.txt').read_bytes()) != leaf['runtimePromptSha256']: raise ValueError('Original task prompt changed')
    artifacts = [Path(manifest_file), evidence/'transport-result.json', evidence/'native-terminal-result.json', evidence/'stdout.ndjson', evidence/'invocation.json', evidence/'prompt.txt', evidence/'input-hashes-before.json', evidence/'input-hashes-after.json']
    return manifest, leaf, cid, failure_class, fingerprint(artifacts)

def prepare(manifest_file, number, gap_file):
    manifest, leaf, cid, failure_class, bindings = original_qualified(manifest_file, number)
    gap=read(gap_file)
    if gap.get('coordinatorVerifiedClosingGap') is not True or gap.get('verifiedBy')!='/root' or gap.get('cell')!=manifest['cell'] or gap.get('leaf')!=number: raise ValueError('Exact original closing gap must be explicitly coordinator-verified')
    bindings[str(gap_file)]=sha(Path(gap_file).read_bytes())
    previous=[]
    for prior in sorted(Path(leaf['outputDir']).glob('continuation-*')):
        prior_result=read(prior/'transport-result.json')
        prior_init,prior_terminal,delegated,_=native_events(prior/'stdout.ndjson')
        error=prior_terminal.get('error','')
        eligible=error=='The stream was interrupted. Please continue the task you were working on.' or (error.startswith('API error') and any(t in error for t in ['operation timed out','context deadline exceeded','read: connection reset by peer']))
        if prior_result.get('status')!='failed' or prior_terminal.get('status')!='ERROR' or not eligible: raise ValueError('Previous continuation is active, successful, or not eligible for transport repair')
        if prior_init.get('conversation_id')!=cid or prior_terminal.get('conversation_id')!=cid or prior_init['init'].get('model')!=MODEL or delegated or not prior_result.get('inputHashesUnchanged') or not prior_result.get('originalEvidenceUnchanged'): raise ValueError('Previous continuation chain disqualified')
        prior_config=read(prior/'config.json')
        if fingerprint(prior_config['originalEvidenceHashes'])!=prior_config['originalEvidenceHashes']: raise ValueError('Previous continuation evidence changed')
        for name in ['config.json','invocation.json','transport-result.json','native-terminal-result.json','stdout.ndjson','input-hashes-after.json']:
            file=prior/name;bindings[str(file)]=sha(file.read_bytes())
        previous.append({'receipt':str(prior/'transport-result.json'),'receiptSha256':sha((prior/'transport-result.json').read_bytes()),'sameConversationId':cid})
    output = Path(leaf['outputDir'])/f'continuation-{len(previous)+1:02d}'
    output.mkdir(exist_ok=False)
    (output/'prompt.txt').write_text(PROMPT)
    config = {'kind':'same-identity-leaf-transport-continuation', 'createdUtc':utc(), 'cell':manifest['cell'], 'number':number,
              'perspective':leaf['perspective'], 'originalManifest':str(manifest_file), 'originalConversationId':cid,
              'continuationReason':failure_class, 'originalReceiptStatus':'transport-completed', 'coordinatorClosingGap':str(gap_file), 'originalEvidenceHashes':bindings, 'previousContinuationReceipts':previous,
              'minimumBackoffSeconds':0, 'notBeforeUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'workspace':leaf['workspace'],
              'protectedInputs':leaf['inputHashesBefore'], 'promptFile':str(output/'prompt.txt'), 'promptSha256':sha(PROMPT.encode()),
              'cli':str(HERE/'bin/agy'), 'outputDir':str(output), 'automaticRetry':False, 'newLensOrRespawn':False,
              'outerTimeout':None, 'model':MODEL, 'effort':'high', 'adapterSha256':sha(Path(__file__).read_bytes())}
    write(output/'config.json', config)
    return {'status':'prepared-no-model-launched','config':str(output/'config.json'),'conversationId':cid,
            'launchArgv':['python3',str(Path(__file__).resolve()),'run',str(output/'config.json')]}

def run(config_file):
    c=read(config_file); output=Path(c['outputDir']); work=Path(c['workspace'])
    if datetime.datetime.now(datetime.timezone.utc)<datetime.datetime.fromisoformat(c['notBeforeUtc']): raise ValueError('Explicit transport backoff not elapsed; no call launched')
    original_qualified(Path(c['originalManifest']), c['number'])
    if fingerprint(c['originalEvidenceHashes']) != c['originalEvidenceHashes']: raise ValueError('Original immutable evidence changed')
    check_files(work,c['protectedInputs'])
    prompt=Path(c['promptFile']).read_text()
    if sha(prompt.encode())!=c['promptSha256']: raise ValueError('Continuation prompt changed')
    if sha(Path(__file__).read_bytes())!=c['adapterSha256']: raise ValueError('Prepared continuation adapter changed')
    argv=[c['cli'],'--conversation',c['originalConversationId'],'-p',prompt,'--model',MODEL,'--effort','high','--dangerously-skip-permissions','--output-format','stream-json','--print-timeout','0','--log-file',str(output/'native.log')]
    invocation={'startedUtc':utc(),'argv':argv,'cwd':str(work),'configSha256':sha(config_file.read_bytes()),'cliSha256':sha(Path(c['cli']).read_bytes()),'sameIdentityRequired':True,'automaticRetry':False,'outerTimeout':None}
    with (output/'invocation.json').open('x') as f: json.dump(invocation,f,indent=2)
    result={'number':c['number'],'perspective':c['perspective'],'status':'failed','originalConversationId':c['originalConversationId'],'continuation':True,'newLensOrRespawn':False}
    try:
        with (output/'stdout.ndjson').open('x') as out,(output/'stderr.log').open('x') as err:
            process=subprocess.run(argv,cwd=work,stdin=subprocess.DEVNULL,stdout=out,stderr=err)
        result['exitCode']=process.returncode
        init,terminal,delegated,tools=native_events(output/'stdout.ndjson')
        write(output/'native-terminal-result.json',terminal)
        (output/'report.native-response.md').write_text(terminal.get('response',''))
        result.update(conversationId=terminal.get('conversation_id'),nativeInit=init['init'],nativeStatus=terminal.get('status'),usage=terminal.get('usage'),tools=tools,delegatedStepIndices=delegated)
        if init.get('conversation_id')!=c['originalConversationId'] or terminal.get('conversation_id')!=c['originalConversationId']: raise ValueError('CLI changed conversation identity: continuation does NOT qualify')
        if init['init'].get('model')!=MODEL or init['init'].get('permission_mode')!='always-proceed': raise ValueError('Continuation accepted route mismatch')
        if delegated: raise ValueError('Continuation delegated')
        if process.returncode!=0 or terminal.get('status')!='SUCCESS' or not terminal.get('response','').strip(): raise ValueError('Continuation did not produce successful nonempty final response')
        result['status']='transport-completed'
    except Exception as e: result['error']=str(e)
    finally:
        after={n:sha((work/n).read_bytes()) if (work/n).is_file() else None for n in c['protectedInputs']}
        write(output/'input-hashes-after.json',after)
        result['inputHashesUnchanged']=after==c['protectedInputs']
        result['originalEvidenceUnchanged']=fingerprint(c['originalEvidenceHashes'])==c['originalEvidenceHashes']
        if not result['inputHashesUnchanged'] or not result['originalEvidenceUnchanged']: result['status']='failed'
        result['endedUtc']=utc(); result['semanticCompletionValidated']=False
        write(output/'transport-result.json',result)
    return {k:result.get(k) for k in ['number','status','conversationId','inputHashesUnchanged','originalEvidenceUnchanged','error']}

def effective(manifest_file, output):
    manifest=read(manifest_file); leaves=[]
    for leaf in manifest['leaves']:
        evidence=Path(leaf['outputDir']); receipt=read(evidence/'transport-result.json'); chain=[]
        if receipt['status']!='transport-completed':
            original_qualified(manifest_file,leaf['number'])
            continuation=sorted(evidence.glob('continuation-*'))[-1]; config=read(continuation/'config.json'); receipt=read(continuation/'transport-result.json')
            if receipt['status']!='transport-completed' or not receipt.get('originalEvidenceUnchanged') or receipt.get('conversationId')!=config['originalConversationId']: raise ValueError('Unqualified continuation')
            if fingerprint(config['originalEvidenceHashes'])!=config['originalEvidenceHashes']: raise ValueError('Original chain changed')
            chain=[{'originalReceipt':str(evidence/'transport-result.json'),'originalReceiptSha256':sha((evidence/'transport-result.json').read_bytes()),'continuationReceipt':str(continuation/'transport-result.json'),'continuationReceiptSha256':sha((continuation/'transport-result.json').read_bytes()),'sameConversationId':config['originalConversationId'],'priorContinuationReceipts':config.get('previousContinuationReceipts',[])}]
            evidence=continuation
        init,terminal,delegated,_=native_events(evidence/'stdout.ndjson')
        cid=receipt.get('conversationId')
        if receipt['status']!='transport-completed' or terminal.get('status')!='SUCCESS' or init['init'].get('model')!=MODEL or delegated or receipt.get('delegatedStepIndices') or not receipt.get('inputHashesUnchanged'): raise ValueError('Unqualified effective transport')
        if not cid or cid!=init.get('conversation_id') or cid!=terminal.get('conversation_id'): raise ValueError('Effective identity mismatch')
        check_files(Path(leaf['workspace']),leaf['inputHashesBefore'])
        if (evidence/'report.native-response.md').read_bytes()!=terminal['response'].encode(): raise ValueError('Effective report is not exact native response')
        leaves.append({**receipt,'effectiveEvidenceDir':str(evidence),'receiptChain':chain,'effectiveReceiptSha256':sha((evidence/'transport-result.json').read_bytes())})
    if len(leaves)!=12 or len({x['conversationId'] for x in leaves})!=12: raise ValueError('Exactly12 independent original identities required')
    result={'kind':'derived-effective-leaf-receipts','createdUtc':utc(),'cell':manifest['cell'],'status':'all12-transports-completed','leafCount':12,'uniqueConversations':12,'inputManifestSha256':sha(manifest_file.read_bytes()),'leaves':leaves,'originalReceiptsOverwritten':False,'semanticCompletionValidated':False}
    with output.open('x') as f: json.dump(result,f,indent=2)
    return {'status':result['status'],'effectiveResult':str(output),'sha256':sha(output.read_bytes()),'continuedLeaves':[x['number'] for x in leaves if x['receiptChain']]}

def main():
    p=argparse.ArgumentParser(description=__doc__); sub=p.add_subparsers(dest='command',required=True)
    prep=sub.add_parser('prepare');prep.add_argument('manifest',type=Path);prep.add_argument('--leaf',type=int,required=True);prep.add_argument('--gap',type=Path,required=True)
    execute=sub.add_parser('run');execute.add_argument('config',type=Path)
    eff=sub.add_parser('effective');eff.add_argument('manifest',type=Path);eff.add_argument('--output',type=Path,required=True)
    a=p.parse_args(); result=prepare(a.manifest.resolve(),a.leaf,a.gap.resolve()) if a.command=='prepare' else run(a.config.resolve()) if a.command=='run' else effective(a.manifest.resolve(),a.output.resolve())
    print(json.dumps(result,indent=2));return int(result.get('status')=='failed')
if __name__=='__main__':sys.exit(main())
