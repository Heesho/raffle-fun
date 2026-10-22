#!/usr/bin/env python3
"""Assemble and seal FIRST-PASS.md for the Anthropic lane (source-only cold outputs only).

Writes FIRST-PASS.md (index + verbatim original reports) and FIRST-PASS.md.sha256 into the lane dir.
Refuses to overwrite an existing sealed FIRST-PASS.md.
"""
import datetime, hashlib, json, sys
from pathlib import Path

LANE = Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/provider-lanes/claude')
RUNS = LANE / 'runs'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def sel(path):
    d = json.loads((path / 'runner-selection.json').read_text()) if (path / 'runner-selection.json').exists() else {}
    return d


def main():
    out = LANE / 'FIRST-PASS.md'
    if out.exists():
        sys.exit('FIRST-PASS.md already exists (sealed); refusing to overwrite')
    cells = json.loads(Path(sys.argv[1]).read_text())  # [{cell, status, attempt_dir, reports:[relpaths], note}]
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    idx, bodies = [], []
    for c in cells:
        ad = RUNS / c['attempt_dir'] if c.get('attempt_dir') else None
        s = sel(ad) if ad else {}
        ident = (f"init.model={s.get('init_model')}; assistant models={s.get('assistant_models')}; subagent models={s.get('subagent_assistant_models')}; "
                 f"modelUsage={s.get('modelUsage_keys')}; runner={s.get('claude_code_version')}; effort requested=max (provider echo: unknown); "
                 f"exit={s.get('exit_code')}; duration_s={s.get('duration_s')}") if s else 'n/a'
        idx.append(f"### {c['cell']} — {c['status']}\n- attempt: `runs/{c.get('attempt_dir') or '-'}`\n- identity: {ident}\n- note: {c.get('note','')}")
        for r in c.get('reports', []):
            p = RUNS / r
            h = sha(p)
            idx.append(f"  - report `runs/{r}` sha256 `{h}` ({p.stat().st_size} bytes) [embedded below]")
            bodies.append(f"\n\n---\n\n## ORIGINAL: {c['cell']} — `runs/{r}`\n\nsha256 `{h}`\n\n````text\n{p.read_text(errors='replace')}\n````\n")
        for r in c.get('hash_only', []):
            for p in sorted((RUNS / r).rglob('*')) if (RUNS / r).is_dir() else [RUNS / r]:
                if p.is_file():
                    idx.append(f"  - artifact `{p.relative_to(LANE)}` sha256 `{sha(p)}` ({p.stat().st_size} bytes) [hash-bound, not embedded]")
    head = f"""# FIRST-PASS — Anthropic provider lane (raffle.fun audit r001)

Assembled: {now}
Scope: cold first-pass outputs of the lane's harness cells and the supplementary review, exactly as produced. Harness-native
tools ran inside some cells (e.g. Slither/Echidna/Foundry inside ToB secure-workflow-guide; Slither in other ToB stages). Each
such cell is labelled TOOL-ASSISTED in the index; the others are source-only.
Every included report was produced from a fresh copy of the frozen clean context (no tests, audit history,
scanner results or peer output). This file adds no reconciliation, deduplication, triage or tool results. Lane tool
campaigns (Slither, Aderyn, Echidna, Medusa, Halmos, Foundry, SMTChecker, mutation) were run in the separate
validation copy and are deliberately excluded here. Severity labels are each harness's own and are unadjudicated.
After sealing, this file is never edited. Corrections go in reconciliation/ as appended documents.

## Cell index
"""
    text = head + '\n'.join(idx) + '\n\n# Verbatim original reports\n' + ''.join(bodies)
    out.write_text(text)
    digest = sha(out)
    (LANE / 'FIRST-PASS.md.sha256').write_text(f"{digest}  FIRST-PASS.md\nsealed_at {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n")
    for p in (out, LANE / 'FIRST-PASS.md.sha256'):
        p.chmod(0o444)
    print(json.dumps({'sha256': digest, 'bytes': out.stat().st_size, 'sealed_at': now}))


if __name__ == '__main__':
    main()
