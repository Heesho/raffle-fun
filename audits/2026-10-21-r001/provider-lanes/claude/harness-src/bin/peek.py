import json,sys
from pathlib import Path
L=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/claude/runs')
for c in sys.argv[1:]:
  for att in sorted((L/c).glob('attempt-*')):
    ev=att/'events.jsonl'
    if not ev.exists(): continue
    lines=open(ev,'rb').read().splitlines()
    out=[];models={};agents=0
    for l in lines:
      try:d=json.loads(l)
      except:continue
      if d.get('type')=='assistant':
        m=d['message'].get('model');models[m]=models.get(m,0)+1
        if d.get('parent_tool_use_id'): continue
        for x in d['message']['content']:
          if x.get('type')=='tool_use':
            if x['name'] in ('Agent','Task'): agents+=1
            out.append('TOOL %s %s'%(x['name'],json.dumps(x['input'])[:160]))
          elif x.get('type')=='text': out.append('TEXT '+x['text'][:160].replace('\n',' '))
      if d.get('type')=='result': out.append('RESULT %s err=%s'%(d.get('subtype'),d.get('is_error')))
      if d.get('type')=='rate_limit_event': out.append('RATE %s'%json.dumps(d.get('rate_limit_info'))[:200])
    print('==',c,att.name,'events',len(lines),'models',models,'agent_calls',agents)
    print('\n'.join(out[-int(sys.argv[0] and 8):]))
