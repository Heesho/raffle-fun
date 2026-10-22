from pathlib import Path
import json,subprocess
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);runner=out/'run-command.py';s=r/'static-slither';a=r/'static-aderyn'
# Explicit new configuration does not load historical suppression database or suppress severity classes.
config={'compile_force_framework':'foundry','filter_paths':'node_modules|lib|test|src/mocks','exclude_dependencies':True,'triage_database':str(s/'fresh-slither-triage.json'),'detectors_to_exclude':''}
(s/'fresh-slither-config.json').write_text(json.dumps(config,indent=2));(out/'slither-campaign-config.json').write_text(json.dumps(config,indent=2))
plan=[('TOOL-SLITHER',180,s,['slither','.','--config-file',str(s/'fresh-slither-config.json'),'--json',str(out/'slither-raw.json')]),('TOOL-SLITHER-PRINTERS',180,s,['slither','.','--config-file',str(s/'fresh-slither-config.json'),'--print','inheritance-graph,function-summary,vars-and-auth,entry-points,call-graph','--json',str(out/'slither-printers.json')]),('TOOL-ADERYN',180,a,[str(r/'tools/aderyn/aderyn-aarch64-apple-darwin/aderyn'),'.','--path-excludes','src/mocks,test,script','--output',str(out/'aderyn-raw.json')])]
for slot,t,c,cmd in plan:subprocess.run(['python3',str(runner),slot,str(t),str(c),*cmd],check=True)
