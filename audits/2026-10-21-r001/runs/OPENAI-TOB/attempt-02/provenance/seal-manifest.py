"""Create an append-only timestamped SHA-256 seal of an explicit artifact set."""
import argparse, datetime, hashlib, json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--seal', required=True)
parser.add_argument('--kind', required=True)
parser.add_argument('paths', nargs='+')
args = parser.parse_args()
root = Path(args.root).resolve()
seal = (root / args.seal).resolve()
if seal.exists() or Path(str(seal)+'.sha256').exists():
    raise SystemExit('Refusing to rewrite an earlier seal')
files = {}
for relative in args.paths:
    path = root / relative
    if not path.exists():
        raise SystemExit(f'Missing artifact: {relative}')
    candidates = [path] if path.is_file() else sorted(path.rglob('*'))
    for item in candidates:
        if item.is_file() and not item.is_symlink():
            rel = str(item.relative_to(root))
            files[rel] = {'path':rel, 'bytes':item.stat().st_size,
                          'sha256':hashlib.sha256(item.read_bytes()).hexdigest()}
record = {'schema_version':1, 'cell':'OPENAI-TOB', 'attempt':'02',
          'kind':args.kind, 'sealed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'algorithm':'SHA-256', 'artifact_root':str(root),
          'target_commit':'9238b6ce8eb7f768c0dcd0cfcef26e1427a03155',
          'method_pin':'82fe8226252622fa807643bdca1710901198553a',
          'file_count':len(files), 'files':[files[k] for k in sorted(files)]}
seal.parent.mkdir(parents=True, exist_ok=True)
with seal.open('x') as stream:
    json.dump(record,stream,indent=2)
    stream.write('\n')
digest = hashlib.sha256(seal.read_bytes()).hexdigest()
with Path(str(seal)+'.sha256').open('x') as stream:
    stream.write(digest+'  '+seal.name+'\n')
print(json.dumps({'seal':str(seal),'sha256':digest,'files':len(files),'timestamp':record['sealed_at']}))
