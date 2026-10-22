#!/usr/bin/env python3
"""Metadata/structural diagnostic ONLY; never declares native audit semantic completion."""
import datetime,hashlib,json
from pathlib import Path
P=Path(__file__).resolve().parent;RUNS=P.parent/'runs';sha=lambda b:hashlib.sha256(b).hexdigest();read=lambda f:json.loads(f.read_text())
rows=[]
for cell,n,base in [(c,n,RUNS/f'GEMINI-{c}-REPAIRED/attempt-04/explicit-high-leaves/leaf-{n:02d}') for c in ['SIMAO','PASHOV'] for n in [3,4]]+[(f'TOB-S{n}',None,RUNS/f'GEMINI-TOB-REPAIRED/attempt-04/S{n}/native-run') for n in [2,3,4,6]]:
 if not (base/'native-terminal-result.json').exists():continue
 original=read(base/'native-terminal-result.json');original_error=original.get('error','');prior_max=-1;turns=[];lastconfig=None
 for d in [base,*sorted(base.glob('continuation-*'))]:
  if not (d/'transport-result.json').exists():continue
  terminal=read(d/'native-terminal-result.json');events=[json.loads(x) for x in (d/'stdout.ndjson').read_text().splitlines() if x.strip()];steps=[x['step_update'] for x in events if 'step_update' in x];ids=[s['step_index'] for s in steps if s.get('step_index') is not None];new=[s for s in steps if s.get('step_index',-1)>prior_max];groups={}
  for step in new:
   if step.get('step_type')=='agent_response':groups.setdefault(step['step_index'],[]).append(step)
  candidates=[]
  for idx,items in groups.items():
   done=[x for x in items if x.get('state')=='DONE'];text=''.join(x.get('text_delta','') for x in items);done_text=''.join(x.get('text_delta','') for x in done);response=terminal.get('response','')
   candidates.append({'stepIndex':idx,'hasDoneEvent':bool(done),'stepStates':sorted({x.get('state') for x in items}),'streamedTextBytes':len(text.encode()),'streamedTextSha256':sha(text.encode()),'doneTextBytes':len(done_text.encode()),'doneTextSha256':sha(done_text.encode()),'streamedTextEqualsNativeResponse':text==response,'doneTextEqualsNativeResponse':done_text==response,'doneEventUsage':done[-1].get('usage') if done else None})
  prior_max=max(ids) if ids else prior_max
  response=terminal.get('response','');turn={'generation':d.name,'nativeStatus':terminal.get('status'),'originalErrorStillByteIdentical':terminal.get('error','')==original_error,'errorSha256':sha(terminal.get('error','').encode()),'responseBytes':len(response.encode()),'responseSha256':sha(response.encode()),'responseFileMatchesTerminal':(d/'report.native-response.md').read_bytes()==response.encode(),'newAgentResponses':candidates,'newFinishedToolEvents':[{'index':s.get('step_index'),'tool':s.get('tool_name')} for s in new if s.get('state')=='DONE' and s.get('step_type')=='tool'],'finishToolObserved':any(s.get('tool_name')=='finish' and s.get('state')=='DONE' for s in new),'strictReceiptStatus':read(d/'transport-result.json').get('status'),'semanticCompletionQualified':False}
  turns.append(turn)
  if (d/'config.json').exists():lastconfig=read(d/'config.json')
 files=[]
 if lastconfig:
  work=Path(lastconfig['workspace']);protected=set(lastconfig['protectedInputs'])
  for f in sorted(work.rglob('*')):
   if not f.is_file() or str(f.relative_to(work)) in protected:continue
   stat=f.stat();files.append({'relativePath':str(f.relative_to(work)),'bytes':stat.st_size,'sha256':sha(f.read_bytes()),'modifiedUtc':datetime.datetime.fromtimestamp(stat.st_mtime,datetime.timezone.utc).isoformat()})
 rows.append({'cell':cell,'leaf':n,'turns':turns,'generatedUnprotectedFileMetadata':files,'fullReportOrClosingGatesVerified':False,'semanticReviewByCoordinatorRequired':True})
record={'observedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'metadataOnly':True,'sourceFindingsReadOrJudged':False,'strictReceiptsRewritten':False,'hypothesis':'Historical conversation error may persist despite new DONE agent responses; diagnostic evidence only, not proof of semantic audit completion.','targets':rows};(P/'continuation-completion-diagnostic-semantics.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps([{'cell':r['cell'],'leaf':r['leaf'],'generatedFiles':len(r['generatedUnprotectedFileMetadata']),'turns':[{'generation':t['generation'],'stickyError':t['originalErrorStillByteIdentical'],'responseBytes':t['responseBytes'],'freshDoneResponseSteps':[x['stepIndex'] for x in t['newAgentResponses'] if x['hasDoneEvent']],'latestDoneTextEqualsTerminal':t['newAgentResponses'][-1]['doneTextEqualsNativeResponse'] if t['newAgentResponses'] else False,'finishTool':t['finishToolObserved']} for t in r['turns']]} for r in rows],indent=2))
