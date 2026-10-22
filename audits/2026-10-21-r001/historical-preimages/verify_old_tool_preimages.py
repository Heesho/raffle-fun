from pathlib import Path
import json,hashlib,datetime
root=Path(__file__).resolve().parents[1]
mapping=root/'historical-preimages/tool-consolidation-2026-10-21T173849Z/PREIMAGE-MAPPING.json';m=json.loads(mapping.read_text());seal=json.loads((root/m['originalSeal']).read_text());results=[]
assert hashlib.sha256((root/m['originalSeal']).read_bytes()).hexdigest()==m['originalSealSha256']
for row in m['rows']:
 data=(root/row['preimagePath']).read_bytes();actual=hashlib.sha256(data).hexdigest();assert actual==row['sha256']==seal['hashes'][row['originalPath']];results.append({'originalPath':row['originalPath'],'preimagePath':row['preimagePath'],'sha256':actual,'matchesOldSeal':True})
assert len(results)==len(seal['hashes'])
out={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'originalSealPreserved':True,'allOldPreimagesExistAndMatch':True,'count':len(results),'rows':results};(mapping.parent/'PREIMAGE-VERIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'count':len(results),'allOldPreimagesExistAndMatch':True}))
