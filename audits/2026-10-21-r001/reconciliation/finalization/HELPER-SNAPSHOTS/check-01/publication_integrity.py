"""Integrity-checked, non-overwriting publication for reconciliation artifacts."""
from pathlib import Path
import hashlib, json, os

PAYLOADS={'findings-register-final.json','FINAL-RECONCILIATION.md','FINAL-RECEIPT-REGISTRY.json','FINAL-RECEIPT-INTEGRITY.json'}
SEAL='FINAL-RECONCILIATION-SEAL.json'
OUTPUTS=PAYLOADS|{SEAL}

def require(condition, detail):
    if not condition: raise ValueError(detail)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def verify_seal(path):
    path=Path(path)
    data=json.loads(path.read_text())
    require(isinstance(data.get('artifacts'),dict) and set(data['artifacts'])==PAYLOADS, ('Incomplete/unknown final artifact seal',str(path)))
    verified={}
    for rel,record in data['artifacts'].items():
        p=path.parent/rel
        require(Path(rel).name==rel, ('Final seal must bind direct sibling',rel))
        expected=record['sha256'] if isinstance(record,dict) else record
        require(sha(p)==expected, ('Final artifact mismatch',str(p)))
        verified[str(p)]=expected
    return data,verified

def publish_stage(stage,destination):
    stage=Path(stage);destination=Path(destination)
    manifest=json.loads((stage/'PUBLICATION.json').read_text())
    require(str(destination.resolve())==manifest['destination'], 'Wrong publication destination')
    require(set(manifest['outputs'])==OUTPUTS, 'Publication requires exactly five final outputs')
    require(isinstance(manifest.get('input_hashes'),dict) and manifest['input_hashes'], 'Missing input bindings')
    for path,expected in manifest['input_hashes'].items():
        require(sha(path)==expected, ('Input changed before publication',path))
    for name,expected in manifest['outputs'].items():
        require(Path(name).name==name and sha(stage/name)==expected, ('Invalid staged artifact',name))
        if (destination/name).exists():
            require(sha(destination/name)==expected, ('Existing output differs; preserve and diagnose',name))
    staged_seal,_=verify_seal(stage/SEAL)
    for name,record in staged_seal['artifacts'].items():
        require((record['sha256'] if isinstance(record,dict) else record)==manifest['outputs'][name], ('Seal/publication binding mismatch',name))
    # Publish the seal last. Existing equal bytes allow recovery from a partial prior publish.
    names=sorted(manifest['outputs'],key=lambda n:n=='FINAL-RECONCILIATION-SEAL.json')
    for name in names:
        try: os.link(stage/name,destination/name)
        except FileExistsError:
            require(sha(destination/name)==manifest['outputs'][name], ('Concurrent differing output',name))
    verify_seal(destination/SEAL)
    return {str(destination/n):v for n,v in manifest['outputs'].items()}

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description='Resume exact staged publication; refuses changed inputs or mismatched existing bytes.')
    p.add_argument('stage');p.add_argument('destination');a=p.parse_args()
    print(json.dumps(publish_stage(a.stage,a.destination),indent=2))
