import sys, json, subprocess, datetime, hashlib
from pathlib import Path

out = Path(sys.argv[1]).resolve()
prompt = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
cli = '/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex'
cwd = Path(__file__).resolve().parent.parent
cmd = [cli, 'exec', '--ignore-user-config', '--ephemeral', '--skip-git-repo-check', '-s', 'danger-full-access', '-m', 'gpt-6-astra', '-c', 'model_reasoning_effort="ultra"', '-c', 'features.multi_agent=false', '--json', '-C', str(cwd), '-o', str(out/'last-message.txt'), '-']
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = {'command':cmd, 'cwd':str(cwd), 'started_at':now(), 'requested_model':'gpt-6-astra', 'requested_effort':'ultra', 'provider_returned_model':'unknown', 'provider_returned_effort':'unknown', 'access_program_override':None, 'fallback':False, 'prompt_path':str(prompt),'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest()}
(out/'command.json').write_text(json.dumps(record,indent=2))
with prompt.open('rb') as stdin, (out/'events.jsonl').open('wb') as stdout, (out/'stderr.txt').open('wb') as stderr:
    proc = subprocess.Popen(cmd,stdin=stdin,stdout=stdout,stderr=stderr,cwd=cwd)
    record['pid']=proc.pid
    (out/'command.json').write_text(json.dumps(record,indent=2))
    status=proc.wait()
record.update(finished_at=now(),exit_code=status)
(out/'execution.json').write_text(json.dumps(record,indent=2))
print(json.dumps({'output':str(out),'exit_code':status}))
