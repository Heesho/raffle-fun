"""Attempt-02 Turn 6 validator + ledger renderer (native Simao dedup/judge gates, public-evidence variant).

Inputs : raw-items.json (mechanical extraction of the 12 raw lens outputs)
         turn6-judgement-spec.json (orchestrator dedup groups, gate verdicts, promotion decisions)
Checks : (1) every raw item belongs to exactly one group; (2) function isolation: every member of a group has the
         group's (contract, function); (3) mechanism members are group members; (4) every quoted mitigation/caution
         is a verbatim substring of the cited raw block and the cited item is a group member; (5) every gate verdict is
         one of BLOCKS/ALLOWS/IRRELEVANT/UNCERTAIN; (6) completeness: every unique raw (contract, function) has >=1
         item in the final report.
Outputs: dedup-ledger.md, gate-ledger.md, turn6-groups.json (all in <out_dir>). Exit code 1 on any failed check.

Usage: python3 -I turn6_render.py <raw-items.json> <spec.json> <out_dir>
"""
import json
import sys
from pathlib import Path

VERDICTS = {"BLOCKS", "ALLOWS", "IRRELEVANT", "UNCERTAIN"}


def main():
    raw = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    spec = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    out = Path(sys.argv[3])
    items = {i["raw_id"]: i for i in raw["items"]}
    groups = spec["groups"]
    errors = []

    # (1) partition
    seen = {}
    for g in groups:
        for r in g["members"]:
            if r not in items:
                errors.append(f"{g['id']}: unknown raw id {r}")
            if r in seen:
                errors.append(f"{r} in both {seen[r]} and {g['id']}")
            seen[r] = g["id"]
    missing = sorted(set(items) - set(seen))
    if missing:
        errors.append(f"raw items not grouped: {missing}")

    # (2) function isolation, (3) mechanisms, (4) verbatim quotes, (5) verdicts
    quote_checks = []
    for g in groups:
        for r in g["members"]:
            it = items.get(r)
            if it and (it["contract"], it["function"]) != (g["contract"], g["function"]):
                errors.append(f"FUNCTION ISOLATION: {g['id']} ({g['contract']}|{g['function']}) contains {r} "
                              f"({it['contract']}|{it['function']})")
        for m in g["mechanisms"]:
            for r in m["members"]:
                if r not in g["members"]:
                    errors.append(f"{g['id']} mechanism {m['id']} cites non-member {r}")
        for kind in ("mitigations", "cautions"):
            for q in g[kind]:
                r = q["raw_id"]
                ok_member = r in g["members"]
                ok_verbatim = r in items and q["quote"] in items[r]["block"]
                quote_checks.append({"group": g["id"], "kind": kind, "raw_id": r, "member": ok_member,
                                     "verbatim": ok_verbatim})
                if not ok_member:
                    errors.append(f"{g['id']} {kind} cites non-member {r}")
                if not ok_verbatim:
                    errors.append(f"{g['id']} {kind} quote not verbatim in {r}: {q['quote'][:80]}")
        for gate in ("G1", "G2", "G3", "G4"):
            v = g["gates"][gate][0]
            if v not in VERDICTS:
                errors.append(f"{g['id']} {gate} invalid verdict {v}")
        g["lenses"] = sorted({items[r]["lens"] for r in g["members"] if r in items})
        g["raw_kinds"] = {r: items[r]["kind"] for r in g["members"] if r in items}
        g["effective"] = {k: ("ALLOWS" if v[0] == "UNCERTAIN" else v[0]) for k, v in g["gates"].items()}

    # (6) completeness gate
    raw_pairs = sorted({(i["contract"], i["function"]) for i in raw["items"]})
    final_groups = [g for g in groups if g["decision"] in ("FINDING", "LEAD") and g.get("report_id")]
    covered = sorted({(g["contract"], g["function"]) for g in final_groups})
    uncovered = [p for p in raw_pairs if p not in covered]
    if uncovered:
        errors.append(f"COMPLETENESS: uncovered {uncovered}")
    completeness_line = (f"Completeness: {len(raw_pairs)} unique (Contract, function) in raw, "
                         f"{len([p for p in raw_pairs if p in covered])} covered in final.")

    # consistency of decisions with effective gates
    for g in groups:
        blocks = [k for k, v in g["effective"].items() if v == "BLOCKS"]
        if g["decision"] == "FINDING" and blocks:
            errors.append(f"{g['id']} is FINDING but gates {blocks} BLOCK")
        if g["decision"] == "FINDING" and not g.get("severity"):
            errors.append(f"{g['id']} FINDING without severity")

    sev_order = {"High": 0, "Medium": 1, "Low": 2, "Info": 3}
    findings = sorted([g for g in groups if g["decision"] == "FINDING"],
                      key=lambda g: (sev_order[g["severity"]], g["report_id"]))
    leads = [g for g in groups if g["decision"] == "LEAD"]
    counts = {s: sum(1 for g in findings if g["severity"] == s) for s in sev_order}

    # ---------------- render dedup ledger ----------------
    L = []
    L.append("# Turn 6 dedup ledger — CLAUDE-SIMAO-PUBLIC-EVIDENCE attempt-02 (public-evidence method variant)")
    L.append("")
    L.append("Generated by `evidence/tools/turn6_render.py` from `evidence/turn6/raw-items.json` (mechanical extraction "
             "of the 12 raw lens outputs) and `evidence/turn6/turn6-judgement-spec.json` (orchestrator judgement).")
    L.append("")
    L.append(f"Raw items: {len(items)} ({raw['counts']['FINDING']} FINDING, {raw['counts']['LEAD']} LEAD) from "
             f"{len(raw['files'])} raw outputs → {len(groups)} deduplicated groups.")
    L.append("")
    L.append("Rules applied (SKILL.md Turn 6 step 1): group_key exact match first; synonymous bug_class merged only "
             "within the same (Contract, function); **function isolation** — no group spans two `function:` fields "
             "(machine-checked); **mechanism preservation** — every distinct mechanism listed; **mitigation "
             "preservation** — raw mitigations grouped by actual change, ≥2 distinct → Options, quotes machine-checked "
             "as verbatim substrings of the raw block.")
    L.append("")
    L.append("## Raw item → group map")
    L.append("")
    L.append("| Raw | Lens | Kind | Contract | function | bug_class | Group |")
    L.append("| --- | --- | --- | --- | --- | --- | --- |")
    for r, it in items.items():
        L.append(f"| {r} | {it['lens']} | {it['kind']} | {it['contract']} | {it['function']} | {it['bug_class']} | "
                 f"{seen.get(r, '—')} |")
    L.append("")
    for g in groups:
        L.append(f"## {g['id']} — `{g['contract']} | {g['function']} | {g['group_bug_class']}` [lenses: {len(g['lenses'])}]")
        L.append("")
        member_desc = ", ".join("%s (L%s %s)" % (r, items[r]["lens"], items[r]["kind"]) for r in g["members"])
        L.append(f"- Members: {member_desc}")
        L.append(f"- Lenses: {g['lenses']}")
        L.append(f"- Synonym merge: {g['synonym_merge'] or 'none (single member or exact group_key)'}")
        L.append("- Mechanisms:")
        for m in g["mechanisms"]:
            L.append(f"  - **{m['id']}** ({', '.join(m['members'])}): {m['summary']}")
        if g["mitigations"]:
            L.append("- Raw mitigations (verbatim, grouped by actual change):")
            for q in g["mitigations"]:
                L.append(f"  - Option {q['option']} — {q['kind']} — {q['raw_id']}: “{q['quote']}”")
            distinct = sorted({q["option"] for q in g["mitigations"] if q["option"] != "-"})
            L.append(f"  - Distinct changes: {len(distinct)} ({', '.join(distinct) if distinct else 'no on-chain change proposed'})")
        else:
            L.append("- Raw mitigations: none proposed by any member.")
        if g["cautions"]:
            L.append("- Preserved trade-offs / cautions (verbatim):")
            for q in g["cautions"]:
                L.append(f"  - {q['raw_id']}: “{q['quote']}”")
        L.append(f"- Decision: **{g['decision']}**" + (f" — {g['severity']} ({g['report_id']})" if g['decision'] == 'FINDING'
                                                   else f" — surviving lead ({g['report_id']})"))
        L.append("")
    L.append("## Composite chains")
    L.append("")
    for c in spec.get("chains", []):
        L.append(f"- Chain: [{c['chain'][0]}] + [{c['chain'][1]}] (also {', '.join(c['also'])}): {c['summary']}")
    L.append("")
    L.append("## Mechanical checks")
    L.append("")
    L.append(f"- Partition: {len(seen)}/{len(items)} raw items assigned to exactly one group; ungrouped: {missing or 'none'}")
    L.append(f"- Function isolation: {'PASS' if not any('FUNCTION ISOLATION' in e for e in errors) else 'FAIL'}")
    L.append(f"- Verbatim quotes: {sum(1 for q in quote_checks if q['verbatim'])}/{len(quote_checks)} verbatim; "
             f"{sum(1 for q in quote_checks if q['member'])}/{len(quote_checks)} cite a group member")
    L.append(f"- {completeness_line}")
    (out / "dedup-ledger.md").write_text("\n".join(L) + "\n", encoding="utf-8")

    # ---------------- render gate ledger ----------------
    G = []
    G.append("# Turn 6 gate ledger — CLAUDE-SIMAO-PUBLIC-EVIDENCE attempt-02 (public-evidence method variant)")
    G.append("")
    G.append("Native `severity-calibration.md` gates, one line each, single pass in fixed order (constructor/initialize → "
             "setters → deposit → accrue → borrow → liquidate → withdraw → cross-chain receive; mapped to this protocol "
             "as createRaffle → (none) → buyEntries → requestDraw/_settleWinningTicket → (none) → enableRefunds → "
             "redeem/release/_update → fulfillRandomWords async callback). `UNCERTAIN` = `ALLOWS`. Committed; not revisited.")
    G.append("")
    G.append("Lead promotion/demotion (SKILL.md Turn 6 step 3): LEAD → FINDING if the full path exists in source or "
             "[lenses: 2+]; [lenses: 2+] does not override a code path that interrupts the attack (demote). A promoted "
             "group that fails a gate is not reported as a finding and is kept as a surviving LEAD (never silently "
             "dropped; it remains in the report's Unverified leads, which the completeness gate requires).")
    G.append("")
    G.append("| Group | (Contract, function) | Stage | Lenses | Raw kinds | G1 | G2 | G3 | G4 | Decision | Severity | Report id |")
    G.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for g in groups:
        kinds = "/".join(sorted(set(g["raw_kinds"].values())))
        G.append(f"| {g['id']} | {g['contract']}::{g['function']} | {g['judge_stage']} | {len(g['lenses'])} | {kinds} | "
                 + " | ".join(g["gates"][k][0] for k in ("G1", "G2", "G3", "G4"))
                 + f" | {g['decision']} | {g['severity'] or '—'} | {g['report_id']} |")
    G.append("")
    for g in groups:
        G.append(f"## {g['id']} — `{g['contract']} | {g['function']} | {g['group_bug_class']}` [lenses: {len(g['lenses'])}]")
        G.append("")
        for k in ("G1", "G2", "G3", "G4"):
            G.append(f"- {k}: `{g['gates'][k][0]}` — {g['gates'][k][1]}")
        G.append(f"- Promotion/demotion: {g['promotion']}")
        if g["decision"] == "FINDING":
            G.append(f"- Severity: **{g['severity']}** — {g['severity_reason']}")
        G.append(f"- Final: {g['decision']} → {g['report_id']}")
        G.append("")
    G.append("## Totals")
    G.append("")
    G.append(f"- Findings: {counts['High']} High · {counts['Medium']} Medium · {counts['Low']} Low · {counts['Info']} Info")
    G.append(f"- Surviving leads: {len(leads)} ({', '.join(g['report_id'] + '=' + g['id'] for g in leads)})")
    G.append(f"- Rejected (excluded from report): {len(groups) - len(final_groups)}")
    G.append(f"- {completeness_line}")
    (out / "gate-ledger.md").write_text("\n".join(G) + "\n", encoding="utf-8")

    merged = {"completeness": completeness_line, "raw_unique_contract_function": raw_pairs,
              "covered_contract_function": covered, "counts": counts, "surviving_leads": len(leads),
              "quote_checks": quote_checks, "errors": errors, "groups": groups, "chains": spec.get("chains", [])}
    (out / "turn6-groups.json").write_text(json.dumps(merged, indent=2, ensure_ascii=False), encoding="utf-8")

    print(completeness_line)
    print(f"groups={len(groups)} findings={len(findings)} {counts} leads={len(leads)} "
          f"quotes verbatim={sum(1 for q in quote_checks if q['verbatim'])}/{len(quote_checks)}")
    for g in groups:
        print(f"{g['id']} {g['contract']}|{g['function']}|{g['group_bug_class']} lenses={g['lenses']} "
              f"gates={[g['gates'][k][0] for k in ('G1','G2','G3','G4')]} -> {g['decision']} {g['severity'] or ''} {g['report_id']}")
    if errors:
        print("ERRORS:")
        for e in errors:
            print("  " + e)
        sys.exit(1)
    print("ALL CHECKS PASS")


if __name__ == "__main__":
    main()
