from pathlib import Path
import shutil,json,hashlib,datetime
ctrl=Path(__file__).resolve().parents[1];freeze=json.loads((ctrl/'freeze.json').read_text());base=Path(freeze['runtime']);clean=base/'clean-context';up=base/'upstreams';root=base/'runtime/gemini-native-repairs';rows=[]
stages={'S1':('audit-context-building','audit-context-building'),'S2':('entry-point-analyzer','entry-point-analyzer'),'S3':('building-secure-contracts','token-integration-analyzer'),'S4':('building-secure-contracts','guidelines-advisor'),'S5':('spec-to-code-compliance','spec-to-code-compliance'),'S6':('building-secure-contracts','secure-workflow-guide')}
for cell,stage in [('SIMAO',None),('PASHOV',None),('GEBAL',None),*[( 'TOB',s) for s in stages]]:
 work=root/cell/'attempt-03';work=work/stage/'work' if stage else work/'work';assert not work.exists(),work;shutil.copytree(clean,work,symlinks=False)
 if cell=='SIMAO':shutil.copytree(up/'0xsimao',work/'.agents/skills/0xsimao-ai',ignore=shutil.ignore_patterns('.git','img'))
 if cell=='PASHOV':shutil.copytree(up/'pashov/solidity-auditor',work/'.agents/skills/solidity-auditor')
 if cell=='GEBAL':shutil.copytree(up/'gebal/agents',work/'gebal-resources/agents');shutil.copy2(up/'gebal/START_HERE.md',work/'gebal-resources/START_HERE.md');shutil.copy2(up/'gebal/docs/assurance.md',work/'gebal-resources/assurance.md') if (up/'gebal/docs/assurance.md').exists() else None
 if cell=='TOB':
  plugin,skill=stages[stage];shutil.copytree(up/'trailofbits/plugins'/plugin/'skills'/skill,work/'.agents/skills'/skill)
  for sub in ['agents','workflows']:
   src=up/'trailofbits/plugins'/plugin/sub
   if src.exists():shutil.copytree(src,work/'upstream-plugins'/plugin/sub)
 files={str(x.relative_to(work)):hashlib.sha256(x.read_bytes()).hexdigest() for x in work.rglob('*') if x.is_file()};required={**{x:freeze['files'][x] for x in freeze['production_scope']},**freeze['reachable_dependency_files']};assert all(files.get(x)==h for x,h in required.items()),(cell,stage)
 rows.append({'cell':cell,'stage':stage,'work':str(work),'preverifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'frozenSourceFiles':43,'productionFilesVerified':5,'dependencyFilesVerified':31,'files':files})
(ctrl/'provider-route-repair/prepared-attempt03.json').write_text(json.dumps({'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':str(clean),'contexts':rows},indent=2)+'\n');print([(x['cell'],x['stage'],x['work']) for x in rows])
