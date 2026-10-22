#!/usr/bin/env python3
"""Operational only; all24 direct leaves and response receipt paths, no findings interpretation."""
import json,hashlib,datetime
from pathlib import Path
P=Path(__file__).resolve().parent;RUNS=P.parent/'runs';rows=[]
for cell in ['SIMAO','PASHOV']:
 base=RUNS/f'GEMINI-{cell}-REPAIRED/attempt-04/explicit-high-leaves';mf=base/'input-manifest.json';manifest=json.loads(mf.read_text());leaves=[]
 for leaf in manifest['leaves']:
  d=Path(leaf['outputDir']);f=d/'transport-result.json';r=json.loads(f.read_text()) if f.exists() else {};row={'number':leaf['number'],'perspective':leaf['perspective'],'state':r.get('status','active' if (d/'invocation.json').exists() else 'queued'),'conversationId':r.get('conversationId'),'nativeStatus':r.get('nativeStatus'),'inputHashesUnchanged':r.get('inputHashesUnchanged'),'nativeReport':str(d/'report.native-response.md'),'strictReceipt':str(f),'workspace':leaf['workspace'],'exactUpstreamPrompt':str(d/'upstream-prompt.txt'),'publicStreamTrace':str(d/'stdout.ndjson'),'continuations':[],'semanticCompletenessValidated':False}
  for c in sorted(d.glob('continuation-*')):
   cf=c/'transport-result.json'
   if not cf.exists():continue
   cr=json.loads(cf.read_text());rf=c/'report.native-response.md';row['continuations'].append({'generation':c.name,'strictStatus':cr.get('status'),'sameIdentity':cr.get('conversationId')==r.get('conversationId'),'report':str(rf),'reportBytes':rf.stat().st_size,'reportSha256':hashlib.sha256(rf.read_bytes()).hexdigest(),'receipt':str(cf),'publicStreamTrace':str(c/'stdout.ndjson')})
  leaves.append(row)
 rows.append({'cell':cell,'inputManifest':str(mf),'inputManifestSha256':hashlib.sha256(mf.read_bytes()).hexdigest(),'strictSuccessCount':sum(x['state']=='transport-completed' for x in leaves),'terminalCount':sum(x['state'] in ['transport-completed','failed'] for x in leaves),'all12Terminal':all(x['state'] in ['transport-completed','failed'] for x in leaves),'leaves':leaves})
record={'observedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'metadataOnly':True,'sourceFindingsReadOrJudged':False,'judgeLaunched':False,'cells':rows};(P/'simao-pashov-current-leaf-receipt-inventory.json').write_text(json.dumps(record,indent=2)+'\n')
for row in rows:print(row['cell']+' '+', '.join(str(x['number'])+':'+x['state']+(' +same-ID-'+x['continuations'][-1]['generation']+'-candidate' if x['continuations'] else '') for x in row['leaves']))
