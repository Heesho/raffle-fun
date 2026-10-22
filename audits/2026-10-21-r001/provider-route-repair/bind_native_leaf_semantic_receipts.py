#!/usr/bin/env python3
"""Separate coordinator-approved semantic binding; never changes native ERROR/strict transport receipts."""
import argparse,datetime,hashlib,json,re,shutil
from pathlib import Path
P=Path(__file__).resolve().parent
MODEL='gemini-4-argon-high'
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(p,v):Path(p).write_text(json.dumps(v,indent=2)+'\n')
def events(p):return [json.loads(l) for l in Path(p).read_text().splitlines() if l.strip()]
def trace_check(trace,original_error,cutoff=-1):
 ev=events(trace);inits=[x for x in ev if x.get('event')=='init'];terminals=[x['result'] for x in ev if x.get('event')=='result']
 if len(inits)!=1 or len(terminals)!=1:raise ValueError('Need exactly one native init/result')
 init,terminal=inits[0],terminals[0];cid=terminal.get('conversation_id')
 if not cid or cid!=init.get('conversation_id') or init['init'].get('model')!=MODEL or init['init'].get('permission_mode')!='always-proceed':raise ValueError('Native identity/route mismatch')
 steps=[e['step_update'] for e in ev if e.get('step_update')]
 if any(s.get('tool_name') in ['invoke_subagent','define_subagent','browser_subagent','run_workflow'] for s in steps):raise ValueError('Native delegation disqualifies explicit-High leaf')
 if terminal.get('status') not in ['SUCCESS','ERROR']:raise ValueError('Unknown native terminal status')
 if terminal['status']=='ERROR' and (not original_error or terminal.get('error')!=original_error):raise ValueError('Current ERROR is not identical historical error')
 responses=[s for s in steps if s.get('step_type')=='agent_response' and s.get('step_index',-1)>cutoff]
 if not responses:raise ValueError('No new current-turn response step')
 idx=max(s['step_index'] for s in responses);chunks=[s for s in responses if s['step_index']==idx]
 if not any(s.get('state')=='DONE' for s in chunks):raise ValueError('Current final response has no DONE event')
 text=''.join(s.get('text_delta','') for s in chunks)
 if not text.strip() or text!=terminal.get('response'):raise ValueError('Current final-step deltas do not equal complete native response')
 return {'conversationId':cid,'nativeTerminalStatus':terminal['status'],'historicalErrorPreserved':terminal['status']=='ERROR','historicalErrorSha256':sha(terminal.get('error','').encode()) if terminal.get('error') else None,'newFinalResponseStep':idx,'finalStepHasDoneEvent':True,'newFinalStepDeltasEqualNativeResponse':True,'reportSha256':sha(text.encode()),'reportBytes':len(text.encode()),'nativeUsageSnapshot':terminal.get('usage'),'streamSha256':sha(Path(trace).read_bytes())}

def context(config_file):
 c=read(config_file);out=Path(c['promptFile']).parent;prep=read(out/'preparation.json');mf=Path(prep['leafInputManifest'])
 if sha(mf.read_bytes())!=prep['leafInputManifestSha256']:raise ValueError('Prepared leaf input manifest changed')
 return c,out,mf,read(mf)

def template(config_file,output):
 c,out,mf,m=context(config_file);rows=[]
 for leaf in m['leaves']:
  base=Path(leaf['outputDir']);choices=[base]+[d for d in sorted(base.glob('continuation-*')) if (d/'transport-result.json').exists()];d=choices[-1];report=d/'report.native-response.md'
  rows.append({'number':leaf['number'],'perspective':leaf['perspective'],'evidenceDir':str(d),'nativeReportSha256':sha(report.read_bytes()) if report.exists() else None,'fullNativeReportVerified':False,'closingMethodRequirementsVerified':False,'coordinatorEvidenceReferences':[]})
 result={'kind':'coordinator-semantic-completion-validation-template','cell':m['cell'],'inputManifestSha256':sha(mf.read_bytes()),'validated':False,'validatedBy':None,'transportStatusesMustRemainOriginal':True,'leaves':rows}
 with output.open('x') as f:json.dump(result,f,indent=2)
 return {'status':'template-only-no-acceptance','output':str(output),'modelLaunched':False}

def bind(config_file,validation_file):
 c,out,mf,m=context(config_file);v=read(validation_file)
 if v.get('validated') is not True or not v.get('validatedBy') or v.get('cell')!=m['cell'] or v.get('inputManifestSha256')!=sha(mf.read_bytes()):raise ValueError('Coordinator must explicitly validate exact same-cell manifest')
 if len(v.get('leaves',[]))!=12 or {x['number'] for x in v['leaves']}!=set(range(1,13)):raise ValueError('Coordinator must validate all12 independent leaves')
 rows=[]
 for leaf in m['leaves']:
  approved=next(x for x in v['leaves'] if x['number']==leaf['number']);base=Path(leaf['outputDir']).resolve();d=Path(approved['evidenceDir']).resolve()
  if d!=base and (d.parent!=base or not re.fullmatch(r'continuation-\d+',d.name)):raise ValueError('Approved output is outside own original leaf/continuation')
  if approved.get('fullNativeReportVerified') is not True or approved.get('closingMethodRequirementsVerified') is not True or not approved.get('coordinatorEvidenceReferences'):raise ValueError('Full native report and all native closing requirements need coordinator evidence')
  original=read(base/'native-terminal-result.json');receipt=read(d/'transport-result.json');invocation=read(d/'invocation.json');argv=invocation['argv']
  original_inits=[e for e in events(base/'stdout.ndjson') if e.get('event')=='init']
  if len(original_inits)!=1 or original_inits[0].get('init',{}).get('model')!=MODEL or original_inits[0].get('conversation_id')!=original.get('conversation_id'):raise ValueError('Original leaf did not establish explicit High identity')
  if d!=base:
   continuation_config=read(d/'config.json')
   for evidence_path,expected in continuation_config['originalEvidenceHashes'].items():
    if sha(Path(evidence_path).read_bytes())!=expected:raise ValueError('Immutable original/continuation evidence changed')
   if invocation.get('cliSha256') and sha(Path(argv[0]).read_bytes())!=invocation['cliSha256']:raise ValueError('Official CLI bytes changed since continuation')
  if argv[argv.index('--model')+1]!=MODEL or argv[argv.index('--effort')+1]!='high':raise ValueError('Actual leaf argv route mismatch')
  cutoff=-1;chain=[]
  for prior in [base,*sorted(base.glob('continuation-*'))]:
   if prior==d:break
   prior_receipt=read(prior/'transport-result.json');prior_terminal=read(prior/'native-terminal-result.json')
   if prior_terminal.get('conversation_id')!=original.get('conversation_id') or prior_receipt.get('delegatedStepIndices') or not prior_receipt.get('inputHashesUnchanged'):raise ValueError('Earlier identity/input/delegation chain disqualified')
   indices=[e['step_update']['step_index'] for e in events(prior/'stdout.ndjson') if e.get('step_update',{}).get('step_index') is not None];cutoff=max(indices) if indices else cutoff
   chain.append({'receipt':str(prior/'transport-result.json'),'receiptSha256':sha((prior/'transport-result.json').read_bytes()),'originalNativeStatus':prior_terminal.get('status')})
  meta=trace_check(d/'stdout.ndjson',original.get('error'),cutoff)
  if meta['conversationId']!=original.get('conversation_id'):raise ValueError('Leaf conversation identity changed')
  if d!=base and (argv[argv.index('--conversation')+1]!=original['conversation_id'] or not receipt.get('originalEvidenceUnchanged')):raise ValueError('Continuation chain is not same original identity/evidence')
  if not receipt.get('inputHashesUnchanged') or receipt.get('delegatedStepIndices'):raise ValueError('Protected-input/descendant disqualification')
  for name,expected in leaf['inputHashesBefore'].items():
   f=Path(leaf['workspace'])/name
   if not f.is_file() or sha(f.read_bytes())!=expected:raise ValueError('Original protected source/bundle/resource changed')
  report=d/'report.native-response.md'
  if sha(report.read_bytes())!=meta['reportSha256'] or approved.get('nativeReportSha256')!=meta['reportSha256']:raise ValueError('Coordinator validated different raw response')
  rows.append({'number':leaf['number'],'perspective':leaf['perspective'],'sourceReport':str(report),'receipt':str(d/'transport-result.json'),'strictReceiptStatusPreserved':receipt['status'],'receiptSha256':sha((d/'transport-result.json').read_bytes()),'receiptChain':chain,'coordinatorSemanticValidation':approved,**meta})
 if len({r['conversationId'] for r in rows})!=12:raise ValueError('Leaf independence requires12 unique original identities')
 work=Path(c['workspace']);prompt=Path(c['promptFile']);old=prompt.read_text()
 if sha(prompt.read_bytes())!=c['promptSha256']:raise ValueError('Prepared native judge prompt changed')
 original_judge_inputs=read(c['protectedInputManifest'])
 for relative,expected in original_judge_inputs.items():
  protected_file=work/relative
  if not protected_file.is_file() or sha(protected_file.read_bytes())!=expected:raise ValueError('Pristine judge input/resource changed before binding')
 needle='all12 new explicit-High direct leaf transports succeed and the coordinator validates their receipts'
 if needle not in old:raise ValueError('Expected unchanged prepared host framing not found')
 common_hashes={}
 for name in ['source.md']+(['money-map.md'] if m['cell']=='SIMAO' else []):
  expected=m['leaves'][0]['inputHashesBefore']['.native-leaf-inputs/'+name]
  common_file=work/'.audit-judge-inputs'/name
  if not common_file.is_file() or sha(common_file.read_bytes())!=expected:raise ValueError('Same-cell native pre-lens common input changed')
  common_hashes['.audit-judge-inputs/'+name]=expected
 target=work/'.native-leaf-results';target.mkdir(exist_ok=False)
 for r in rows:shutil.copyfile(r['sourceReport'],target/f'leaf-{r["number"]:02d}.md')
 binding={'status':'bound-only-new12-explicit-high-leaves','kind':'distinct-coordinator-verified-native-method-completion-binding','createdUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'cell':m['cell'],'inputManifestSha256':sha(mf.read_bytes()),'coordinatorValidationFile':str(validation_file),'coordinatorValidationSha256':sha(validation_file.read_bytes()),'validatedBy':v['validatedBy'],'nativeTransportErrorsRenamedSuccess':False,'strictOriginalReceiptsOverwritten':False,'allNativeMethodCompletionsVerifiedByCoordinator':True,'commonInputHashesAtBinding':common_hashes,'receipts':rows}
 write(target/'binding.json',binding);write(out/'leaf-semantic-binding.json',binding)
 # Amend only the unused host framing, preserving the exact pinned native judge procedure.
 replacement='all12 new explicit-High native leaf responses have their full native reports and closing method requirements verified by the coordinator; original transport statuses, including historical errors, remain preserved in binding.json'
 (out/'prompt.original-transport-framing.txt').write_text(old)
 receipt_scope='\n\nHost receipt scope: accepted leaf qualification establishes native method completion only. It does not approve any finding, proof, severity or source anchor. Some raw reports use concatenated-bundle line numbers; during the normal native gates/formatting resolve actual source-file anchors while preserving original reports. Pashov description/fix wording may exceed native25-word limits; apply its exact native report-language cleanup without altering identifiers, code or tags, adding gates or performing another judgment pass. Historical native ERROR statuses remain visible in the binding and are not renamed SUCCESS.\n'
 prompt.write_text(old.replace(needle,replacement)+receipt_scope);c['promptSha256']=sha(prompt.read_bytes());c['semanticCompletionBinding']=str(target/'binding.json');write(config_file,c)
 protected={str(f.relative_to(work)):sha(f.read_bytes()) for f in sorted(work.rglob('*')) if f.is_file() and not str(f.relative_to(work)).startswith(('.audit-judge-inputs/','.solidity-auditor/'))};write(Path(c['protectedInputManifest']),protected)
 return {'status':binding['status'],'kind':binding['kind'],'reportsBound':12,'strictNativeStatusesPreserved':True,'modelLaunched':False,'config':str(config_file)}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True);t=sub.add_parser('template');t.add_argument('config',type=Path);t.add_argument('--output',type=Path,required=True);b=sub.add_parser('bind');b.add_argument('config',type=Path);b.add_argument('--validation',type=Path,required=True);a=p.parse_args();print(json.dumps(template(a.config.resolve(),a.output.resolve()) if a.command=='template' else bind(a.config.resolve(),a.validation.resolve()),indent=2))
