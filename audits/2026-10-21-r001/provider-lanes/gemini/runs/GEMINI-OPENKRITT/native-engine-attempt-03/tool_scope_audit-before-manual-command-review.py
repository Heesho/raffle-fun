from pathlib import Path
import collections,datetime,hashlib,json
M=Path(__file__).resolve().parents[1];O=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03');expected=json.loads((M/'source-manifest.json').read_text());rows=[];issues=[];failed_lookups={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for call in sorted((M/'host-calls').iterdir()):
 if not call.is_dir():continue
 log=call/'stdout.ndjson';launch=json.loads((call/'launch.json').read_text());counts=collections.Counter();paths=set();commands=set();model=None;terminal=False
 for line in log.read_text().splitlines():
  try:e=json.loads(line)
  except:continue
  if e.get('event')=='init':model=e.get('init',{}).get('model')
  if e.get('event')=='result':terminal=True
  s=e.get('step_update',{});name=s.get('tool_name');info=s.get('tool_info') or {};params=info.get('parameters') or {}
  if not name:continue
  counts[name]+=1
  if name=='read_file':
   path=params.get('Path')
   if isinstance(path,str):
    p=Path(path);p=(p if p.is_absolute() else call/'workspace'/p).resolve();paths.add(str(p))
    try:relative=str(p.relative_to(call/'workspace'))
    except ValueError:relative=None
    if relative not in expected and p!=(call/'full-prompt.txt').resolve():
     if relative is not None and not p.exists():
      key=(call.name,str(p));failed_lookups.setdefault(key,set()).add(s.get('state'))
     else:issues.append({'call':call.name,'issue':'read outside frozen manifest/supplied native prompt','path':str(p)})
  elif name=='run_command':
   command=params.get('CommandLine') or params.get('command') or str(params);commands.add(command)
   # Explicit observed listing commands; no general shell safety inference.
   if not command.startswith('find ') or any(t in command for t in [';','&&','|','`','$(',' -exec',' -delete','>','../']):issues.append({'call':call.name,'issue':'command requires manual scope review','command':command})
  elif name!='finish':issues.append({'call':call.name,'issue':'additional tool requires review','tool_name':name})
  if not launch['allow_tools_requested_by_engine'] and name!='finish':issues.append({'call':call.name,'issue':'native no-tool request used tool','tool_name':name})
 rows.append({'call':call.name,'terminal_event':terminal,'init_model':model,'tool_event_counts_started_and_completed':dict(counts),'read_paths':sorted(paths),'commands':sorted(commands),'log_sha256':sha(log),'launch_sha256':sha(call/'launch.json'),'native_allow_tools':launch['allow_tools_requested_by_engine']})
lookup_rows=[{'call':k[0],'path':k[1],'states':sorted(v),'explicit_error_event':'ERROR' in v} for k,v in failed_lookups.items()]
for x in lookup_rows:
 if not x['explicit_error_event']:issues.append({'call':x['call'],'path':x['path'],'issue':'unmanifested lookup outcome not yet established'})
result={'failed_in_workspace_lookups':lookup_rows,'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'complete_transport_set':all(r['terminal_event'] for r in rows),'calls':len(rows),'issues':issues,'call_metadata':rows,'limitations':['Metadata audit, not OS sandbox or proof of provider-side memory isolation.','Tool event counts include start/completion events and are not unique read operations.','Unfinished model reasoning/finding text is never read by this audit.']}
name='TOOL-SCOPE-AUDIT.json' if (O/'SEAL.json').exists() else 'tool-scope-provisional.json';p=O/name
if p.exists() and (O/'TOOL-SCOPE-SEAL.json').exists():raise RuntimeError('Already sealed tool-scope audit')
p.write_text(json.dumps(result,indent=2)+'\n')
if (O/'SEAL.json').exists() and result['complete_transport_set']:
 (O/'TOOL-SCOPE-SEAL.json').write_text(json.dumps({'sealed_utc':result['checked_utc'],'artifacts':{name:sha(p),'tool_scope_audit.py':sha(O/'tool_scope_audit.py')},'native_first_pass_seal_sha256':sha(O/'SEAL.json'),'issues':len(issues)},indent=2)+'\n')
print(json.dumps({'calls':len(rows),'complete_transport_set':result['complete_transport_set'],'issue_count':len(issues),'failed_in_workspace_lookups':len(lookup_rows),'output':str(p)}))
