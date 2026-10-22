#!/usr/bin/env python3
"""Generate lane matrix.json from per-attempt evidence + a small manual status table (argv[1] json)."""
import json, sys, datetime
from pathlib import Path

LANE = Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/claude')


def attempt_info(rel):
    d = LANE / 'runs' / rel
    info = {'path': f'runs/{rel}'}
    rs = d / 'runner-selection.json'
    if rs.exists():
        s = json.loads(rs.read_text())
        info.update({k: s.get(k) for k in ('init_model', 'assistant_models', 'subagent_assistant_models', 'modelUsage_keys',
                                           'claude_code_version', 'exit_code', 'timed_out', 'duration_s', 'result_subtype',
                                           'is_error', 'total_cost_usd', 'subagent_stats', 'thinking_blocks')})
        info['requested_model'] = 'claude-opus-5-5'
        info['requested_effort'] = 'max'
        info['accepted_local_selection'] = {'model': s.get('init_model'), 'effort': 'max (accepted, no warning)'}
        info['provider_returned_identity'] = sorted(set(list((s.get('assistant_models') or {}).keys()) + list((s.get('subagent_assistant_models') or {}).keys()) + (s.get('modelUsage_keys') or [])))
        info['provider_returned_effort'] = 'unknown (not echoed by provider)'
        info['fallbacks'] = 'none configured; none observed'
    for fn in ('freeze-before.json', 'freeze-after.json'):
        f = d / fn
        if f.exists():
            info[fn.replace('.json', '')] = json.loads(f.read_text()).get('ok')
    return info


def main():
    manual = json.loads(Path(sys.argv[1]).read_text())
    out = {'schema': 1, 'lane': 'anthropic', 'generated_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'frozen_target': '9238b6ce8eb7f768c0dcd0cfcef26e1427a03155', 'cells': [], 'supplementary': [], 'tool_campaigns': manual.get('tools', [])}
    for c in manual['cells']:
        c = dict(c)
        c['attempts'] = [dict(attempt_info(a['dir']), outcome=a['outcome']) for a in c.get('attempts', [])]
        out['cells'].append(c)
    for c in manual.get('supplementary', []):
        c = dict(c)
        c['attempts'] = [dict(attempt_info(a['dir']), outcome=a['outcome']) for a in c.get('attempts', [])]
        out['supplementary'].append(c)
    (LANE / 'matrix.json').write_text(json.dumps(out, indent=1))
    print('matrix.json written', len(out['cells']), 'cells')


if __name__ == '__main__':
    main()
