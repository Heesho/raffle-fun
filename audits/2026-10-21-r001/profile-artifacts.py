from pathlib import Path
import json,subprocess,hashlib
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);cwd=r/'validation/packages/contracts';runner=out/'run-command.py';records=[]
for profile in ['default','ci','audit','audit_strict','audit_release','coverage','comparison']:
 target=r/'profile-artifacts'/profile;cache=r/'profile-caches'/profile
 subprocess.run(['python3',str(runner),'TOOL-ARTIFACTS-'+profile.upper(),'180',str(cwd),'env','FOUNDRY_PROFILE='+profile,'forge','build','--build-info','--out',str(target),'--cache-path',str(cache),'--skip','test','--skip','script'],check=True)
 for contract,file in [('Raffle','Raffle.sol'),('RaffleFactory','RaffleFactory.sol'),('IRaffle','IRaffle.sol'),('IRaffleFactory','IRaffleFactory.sol'),('RaffleConstants','RaffleConstants.sol')]:
  p=target/file/(contract+'.json')
  if not p.exists():records.append({'profile':profile,'contract':contract,'missing':True});continue
  x=json.loads(p.read_text());m=x.get('metadata',{});m=json.loads(m) if isinstance(m,str) else m
  h=lambda v:hashlib.sha256(v).hexdigest()
  rec={'profile':profile,'contract':contract,'artifact_path':str(p),'artifact_sha256':h(p.read_bytes()),'compiler':m.get('compiler'),'settings':m.get('settings'),'source_hashes':{k:v.get('keccak256') for k,v in m.get('sources',{}).items()},'abi_sha256':h(json.dumps(x.get('abi'),sort_keys=True,separators=(',',':')).encode()),'creation_bytecode_sha256':h(x.get('bytecode',{}).get('object','').encode()),'runtime_bytecode_sha256':h(x.get('deployedBytecode',{}).get('object','').encode()),'immutable_references':x.get('deployedBytecode',{}).get('immutableReferences',{})}
  records.append(rec);dest=out/'compiler-artifacts'/profile;dest.mkdir(parents=True,exist_ok=True);(dest/(contract+'.json')).write_bytes(p.read_bytes())
(out/'compiler-artifact-provenance.json').write_text(json.dumps(records,indent=2)+'\n');print('Preserved',len(records),'profile/contract artifact records')
