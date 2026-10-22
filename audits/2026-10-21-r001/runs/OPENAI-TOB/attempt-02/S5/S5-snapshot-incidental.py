import pathlib,json,time,hashlib,datetime,shlex,re
OUT=pathlib.Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/OPENAI-TOB/attempt-02/S5')
def save(data,name,source_request,method):
    h=hashlib.sha256(data).hexdigest();d=OUT/'incidental-extraction-output'/h;d.mkdir(parents=True,exist_ok=True)
    (d/name).write_bytes(data)
    (d/'provenance.json').write_text(json.dumps({'non_authoritative':True,'native_phase':'Extract','source_request':source_request,'method':method,'sha256':h,'bytes':len(data),'snapshot_at':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
def scan():
    for req in (OUT/'requests').iterdir():
        for line in (req/'events.jsonl').read_text().splitlines():
            try:ev=json.loads(line)
            except:continue
            item=ev.get('item',{})
            if ev.get('type')!='item.completed' or item.get('type')!='command_execution':continue
            cmd=item.get('command','')
            if 'cat > audit/S5/spec-compliance/REPORT.md' not in cmd:continue
            try:script=shlex.split(cmd)[-1]
            except:continue
            m=re.search(r"cat > audit/S5/spec-compliance/REPORT.md <<'([^']+)'\n([\s\S]*?)\n\1(?:\n|$)",script)
            if m:save((m[2]+'\n').encode(),'REPORT.md',req.name,'Exact bytes recovered from completed quoted heredoc command in raw events; command not executed again')
    for n in ['REPORT.md','requirements.json']:
        f=OUT/'native-output/spec-compliance'/n
        if f.exists():
            b=f.read_bytes();heading=b.decode(errors='replace').splitlines()[0] if b else ''
            rid=next((v for k,v in [('IRaffle.sol','003'),('IRaffleFactory.sol','004'),('RaffleConstants.sol','005'),('Raffle.sol','006'),('RaffleFactory.sol','007')] if k in heading),'unknown')
            save(b,n,rid,'Live extraction-phase file snapshot')
while True:
    journal=OUT/'native/continuation-journal.jsonl'
    if journal.exists() and any(json.loads(x).get('name')=='Report' for x in journal.read_text().splitlines()):break
    scan()
    if (OUT/'host-completion.json').exists():break
    time.sleep(1)
