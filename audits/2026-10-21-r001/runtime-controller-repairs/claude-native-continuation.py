#!/usr/bin/env python3
"""Claude provider-lane cell runner (raffle.fun audit r001).

Runs one headless Claude Code session for a harness cell/stage inside a fresh copy of the
frozen clean context, with an isolated configuration, and preserves all evidence.

Usage: run_cell.py CELL_ID ATTEMPT --prompt-file F [--plugin-dir D ...] [--workdir-src DIR]
                   [--timeout-min 75] [--extra-allow-read]
"""
import argparse, datetime, hashlib, json, os, shutil, signal, subprocess, sys, threading, time
from pathlib import Path

RT = Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude')
CODEX_RT = Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001')
CLEAN = CODEX_RT / 'clean-context'
CTRL = Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001')
LANE = CTRL / 'provider-lanes/claude'
CLAUDE_BIN = RT / 'claude-code/node_modules/.bin/claude'
MODEL = 'claude-opus-5-5'
EFFORT = 'max'
NODE_BIN = '/Users/hishamel-husseini/.nvm/versions/node/v22.23.2/bin'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def tree_hash(root: Path, skip=()):
    h = hashlib.sha256(); files = {}
    for p in sorted(root.rglob('*')):
        if p.is_file() and not any(s in p.parts for s in skip):
            rel = str(p.relative_to(root)); d = hashlib.sha256(p.read_bytes()).hexdigest()
            files[rel] = d; h.update(rel.encode() + b'\0' + d.encode() + b'\n')
    return h.hexdigest(), files


def verify_freeze():
    r = subprocess.run([sys.executable, str(CTRL / 'verify-freeze.py')], capture_output=True, text=True)
    out = {'verify_freeze_exit': r.returncode, 'verify_freeze': r.stdout.strip()[:2000]}
    tgt = (CTRL / 'target.tar.gz')
    out['target_tar_sha256'] = hashlib.sha256(tgt.read_bytes()).hexdigest()
    out['target_tar_expected'] = (CTRL / 'target.tar.gz.sha256').read_text().split()[0]
    out['clean_context_tar_sha256'] = hashlib.sha256((CTRL / 'clean-context.tar.gz').read_bytes()).hexdigest()
    out['clean_context_tree_sha256'] = tree_hash(CLEAN)[0]
    out['ok'] = r.returncode == 0 and out['target_tar_sha256'] == out['target_tar_expected']
    out['at'] = now()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cell'); ap.add_argument('attempt')
    ap.add_argument('--prompt-file', required=True)
    ap.add_argument('--plugin-dir', action='append', default=[])
    ap.add_argument('--workdir-src', default=str(CLEAN))
    ap.add_argument('--timeout-min', type=float, default=75)
    ap.add_argument('--disallow', action='append', default=['AskUserQuestion'])
    ap.add_argument('--tools', default=None)
    ap.add_argument('--preserve-glob', action='append', default=['.audit-*', '.solidity-auditor', '*.md'])
    a = ap.parse_args()

    out = LANE / 'runs' / a.cell / a.attempt
    if out.exists():
        sys.exit(f'refusing to overwrite {out}')
    out.mkdir(parents=True)
    work_root = RT / 'cells' / a.cell / a.attempt
    work = work_root / 'work'
    if work_root.exists():
        sys.exit(f'refusing to reuse {work_root}')
    shutil.copytree(a.workdir_src, work, symlinks=False)
    src_hash_before, _ = tree_hash(work)
    prompt = Path(a.prompt_file).read_text()
    (out / 'prompt.txt').write_text(prompt)
    (out / 'freeze-before.json').write_text(json.dumps(verify_freeze(), indent=1))

    settings = {
        'autoMemoryEnabled': False,
        'permissions': {
            'deny': [
                'Bash(rm:*)',
                'Read(//Users/hishamel-husseini/Documents/projects/raffle-fun/**)',
                f'Read(/{CODEX_RT}/**)',
                'Read(//Users/hishamel-husseini/.claude/projects/**)',
            ]
        },
    }
    (out / 'settings.json').write_text(json.dumps(settings, indent=1))
    session_id = None
    import uuid
    session_id = str(uuid.uuid4())
    cmd = [str(CLAUDE_BIN), '-p', '--model', MODEL, '--effort', EFFORT,
           '--setting-sources', 'project', '--settings', str(out / 'settings.json'),
           '--permission-mode', 'bypassPermissions', '--strict-mcp-config',
           '--output-format', 'stream-json', '--verbose', '--forward-subagent-text',
           '--session-id', session_id,
           '--disallowed-tools', *a.disallow]
    for d in a.plugin_dir:
        cmd += ['--plugin-dir', d]
    if a.tools is not None:
        cmd += ['--tools', a.tools]
    env = {
        'HOME': os.environ['HOME'], 'USER': os.environ.get('USER', ''), 'LOGNAME': os.environ.get('USER', ''),
        'SHELL': '/bin/zsh', 'TMPDIR': os.environ.get('TMPDIR', '/tmp'), 'TERM': 'dumb', 'LANG': 'en_US.UTF-8',
        'PATH': ':'.join(['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/opt/homebrew/bin',
                          os.path.expanduser('~/.foundry/bin'), NODE_BIN,
                          str(RT / 'tools/bin')]),
        'CLAUDE_CODE_DISABLE_AUTO_MEMORY': '1',
        'CLAUDE_CODE_SUBAGENT_MODEL': MODEL,
    }
    (out / 'command.json').write_text(json.dumps({
        'cell': a.cell, 'attempt': a.attempt, 'argv': cmd, 'stdin': 'prompt.txt', 'cwd': str(work),
        'env_keys': sorted(env), 'env_nonsecret': {k: env[k] for k in ('CLAUDE_CODE_DISABLE_AUTO_MEMORY', 'CLAUDE_CODE_SUBAGENT_MODEL', 'PATH')},
        'requested_model': MODEL, 'requested_effort': EFFORT, 'fallback_model': None,
        'timeout_min': a.timeout_min, 'plugin_dirs': a.plugin_dir, 'workdir_src': a.workdir_src,
        'workdir_src_tree_sha256': src_hash_before, 'session_id': session_id,
        'runner_version': subprocess.run([str(CLAUDE_BIN), '--version'], capture_output=True, text=True).stdout.strip(),
        'started_at': now()}, indent=1))

    preserve = out / 'preserved'
    stop = threading.Event()

    def preserver():
        while not stop.is_set():
            for g in a.preserve_glob:
                for p in work.glob(g):
                    dst = preserve / p.name
                    try:
                        if p.is_dir():
                            shutil.copytree(p, dst, dirs_exist_ok=True)
                        elif p.is_file() and p.name not in ('DESIGN.md',):
                            dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(p, dst)
                    except Exception:
                        pass
            stop.wait(15)

    preserve.mkdir()
    th = threading.Thread(target=preserver, daemon=True); th.start()
    t0 = time.time(); timed_out = False
    with open(out / 'events.jsonl', 'wb') as ev, open(out / 'stderr.txt', 'wb') as er:
        proc = subprocess.Popen(cmd, cwd=work, env=env, stdin=subprocess.PIPE, stdout=ev, stderr=er, start_new_session=True)
        proc.stdin.write(prompt.encode()); proc.stdin.close()
        try:
            rc = proc.wait(timeout=None if a.timeout_min == 0 else a.timeout_min * 60)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGTERM); time.sleep(10)
            try: os.killpg(proc.pid, signal.SIGKILL)
            except Exception: pass
            rc = proc.wait()
    dur = time.time() - t0
    stop.set(); th.join(timeout=60)
    # final preserve pass
    for g in a.preserve_glob:
        for p in work.glob(g):
            dst = preserve / p.name
            try:
                if p.is_dir(): shutil.copytree(p, dst, dirs_exist_ok=True)
                elif p.is_file() and p.name != 'DESIGN.md': shutil.copy2(p, dst)
            except Exception: pass
    # copy session transcripts (main + subagents)
    proj_dirs = list((Path.home() / '.claude/projects').glob('*'))
    tx = out / 'transcripts'; tx.mkdir()
    for pd in proj_dirs:
        for p in pd.glob(f'{session_id}*'):
            if p.is_dir(): shutil.copytree(p, tx / p.name, dirs_exist_ok=True)
            else: shutil.copy2(p, tx / p.name)
    # work tree diff (what the run created/changed)
    after_hash, after_files = tree_hash(work, skip=('node_modules',))
    _, before_files = tree_hash(Path(a.workdir_src), skip=('node_modules',))
    changed = sorted(k for k in before_files if after_files.get(k) != before_files[k])
    created = sorted(k for k in after_files if k not in before_files)
    (out / 'workdir-delta.json').write_text(json.dumps({'source_files_changed_or_deleted': changed, 'created': created}, indent=1))
    (out / 'freeze-after.json').write_text(json.dumps(verify_freeze(), indent=1))
    # model identity summary
    ident = {'requested_model': MODEL, 'requested_effort': EFFORT, 'init_model': None, 'assistant_models': {},
             'subagent_assistant_models': {}, 'modelUsage_keys': [], 'result_subtype': None, 'is_error': None,
             'num_turns': None, 'total_cost_usd': None, 'subagent_stats': None, 'rate_limit_events': [],
             'claude_code_version': None, 'thinking_blocks': 0}
    for line in open(out / 'events.jsonl', 'rb'):
        try: d = json.loads(line)
        except Exception: continue
        t = d.get('type')
        if t == 'system' and d.get('subtype') == 'init' and ident['init_model'] is None:
            ident['init_model'] = d.get('model'); ident['claude_code_version'] = d.get('claude_code_version')
            ident['init_skills_loaded'] = [s for s in d.get('skills', []) if ':' in s]
        elif t == 'assistant':
            m = d.get('message', {}).get('model'); k = 'subagent_assistant_models' if d.get('parent_tool_use_id') else 'assistant_models'
            ident[k][m] = ident[k].get(m, 0) + 1
            ident['thinking_blocks'] += sum(1 for c in d.get('message', {}).get('content', []) if c.get('type') == 'thinking')
        elif t == 'rate_limit_event':
            ident['rate_limit_events'].append(d.get('rate_limit_info'))
        elif t == 'result':
            ident.update(result_subtype=d.get('subtype'), is_error=d.get('is_error'), num_turns=d.get('num_turns'),
                         total_cost_usd=d.get('total_cost_usd'), subagent_stats=d.get('subagent_stats'),
                         modelUsage_keys=list((d.get('modelUsage') or {}).keys()), modelUsage=d.get('modelUsage'))
            (out / 'final-result.md').write_text(d.get('result') or '')
    # subagent transcript models
    sub_models = {}
    for p in tx.rglob('*.jsonl'):
        for line in open(p, 'rb'):
            try: d = json.loads(line)
            except Exception: continue
            m = (d.get('message') or {}).get('model') if isinstance(d.get('message'), dict) else None
            if m: sub_models.setdefault(p.name, {}); sub_models[p.name][m] = sub_models[p.name].get(m, 0) + 1
    ident['transcript_models'] = sub_models
    ident['rate_limit_events'] = ident['rate_limit_events'][-5:]
    ident.update(exit_code=rc, timed_out=timed_out, duration_s=round(dur, 1), finished_at=now())
    (out / 'runner-selection.json').write_text(json.dumps(ident, indent=1))
    print(json.dumps({'cell': a.cell, 'attempt': a.attempt, 'exit': rc, 'timed_out': timed_out, 'duration_s': round(dur),
                      'models': ident['assistant_models'], 'transcript_models': {k: v for k, v in list(sub_models.items())[:20]}}))


if __name__ == '__main__':
    main()
