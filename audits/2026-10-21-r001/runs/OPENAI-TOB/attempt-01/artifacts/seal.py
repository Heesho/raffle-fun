from pathlib import Path
import sys,json,hashlib,datetime
folder=Path(sys.argv[1]); name=sys.argv[2] if len(sys.argv)>2 else 'SEAL.json';dest=folder/name
if dest.exists(): raise SystemExit('Refusing to replace existing seal '+str(dest))
items=[{'path':str(p.relative_to(folder)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(folder.rglob('*')) if p.is_file() and p!=dest and not p.name.endswith('.tmp')]
result={'sealed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'algorithm':'SHA256','target_sha':'9238b6ce8eb7f768c0dcd0cfcef26e1427a03155','scope':str(folder.resolve()),'model_selection':{'local_model':'gpt-6-astra','local_effort':'ultra','provider_returned_model':'unknown','provider_returned_effort':'unknown','fallback':False},'files':items}
dest.write_text(json.dumps(result,indent=2)+'\n');print(str(dest),len(items),'files',hashlib.sha256(dest.read_bytes()).hexdigest())
