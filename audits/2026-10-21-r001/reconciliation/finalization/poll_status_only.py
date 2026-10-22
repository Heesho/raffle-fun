"""One-shot scalar status capture; deliberately never emits explanations/findings."""
from pathlib import Path
import datetime,json,urllib.request
D=Path(__file__).resolve().parent
j=json.load(urllib.request.urlopen('http://127.0.0.1:3002/api/scans/1',timeout=15));j=j.get('scan',j)
z=j.get('statusSummary',{})
record={'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),**{k:j.get(k) for k in ('status','updatedAt','progress','progressLabel')},'counters':{k:z[k] for k in ('totalAttempts','completedAttempts','runningAttempts','failedAttempts','expectedStepLineages','completedStepLineages','postAttempts','activeJobCount') if isinstance(z.get(k),(int,float))}}
with (D/'claude-openkritt-status-only.jsonl').open('a') as f:f.write(json.dumps(record)+'\n')
record['coordinator_request_count']=len((D.parent.parent/'runs/COORDINATOR-DAYBREAK/attempt-01/requests-to-parent.jsonl').read_text().splitlines())
print(json.dumps(record))
