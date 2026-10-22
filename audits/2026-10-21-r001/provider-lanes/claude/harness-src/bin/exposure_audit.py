#!/usr/bin/env python3
"""Scan every attempt's main and subagent transcripts for tool calls that reference paths outside the cell work dir."""
import json, re
from pathlib import Path

LANE = Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/claude')
RISKY = [
    ('main-repo', re.compile(r'/Documents/projects/raffle-fun')),
    ('codex-runtime', re.compile(r'raffle-audit-r001/(?!.*-claude)|raffle-audit-r001(?!-claude)')),
    ('claude-projects', re.compile(r'\.claude/projects')),
    ('home-wide-search', re.compile(r'(find|mdfind|locate)\s+(/\s|~|\$HOME|/Users)')),
    ('parent-escape', re.compile(r'\.\./\.\./\.\.')),
    ('history-words', re.compile(r'audit-corpus|slither\.db\.json|packages/contracts/test|packages/contracts/audit')),
]


def scan(f, workdir):
    hits = []
    for line in open(f, 'rb'):
        try:
            d = json.loads(line)
        except Exception:
            continue
        m = d.get('message')
        if not isinstance(m, dict) or d.get('type') != 'assistant':
            continue
        for c in m.get('content', []) or []:
            if c.get('type') != 'tool_use':
                continue
            s = json.dumps(c.get('input'))
            s2 = s.replace(workdir, '<WORK>') if workdir else s
            for name, rx in RISKY:
                if rx.search(s2):
                    hits.append({'kind': name, 'tool': c.get('name'), 'input': s2[:300]})
    return hits


def main():
    report = {}
    for cmd in sorted(LANE.glob('runs/**/command.json')):
        att = cmd.parent
        c = json.loads(cmd.read_text())
        wd = c.get('cwd')
        files = [att / 'events.jsonl'] + sorted((att / 'transcripts').rglob('*.jsonl'))
        hits = []
        for f in files:
            if f.exists():
                for h in scan(f, wd):
                    h['file'] = str(f.relative_to(att)); hits.append(h)
        # dedupe
        seen = set(); uniq = []
        for h in hits:
            k = (h['kind'], h['input'])
            if k not in seen:
                seen.add(k); uniq.append(h)
        report[str(att.relative_to(LANE))] = {'count': len(uniq), 'hits': uniq[:40]}
    (LANE / 'EXPOSURE-AUDIT.json').write_text(json.dumps(report, indent=1))
    for k, v in report.items():
        print(k, v['count'], sorted(set(h['kind'] for h in v['hits'])))


if __name__ == '__main__':
    main()
