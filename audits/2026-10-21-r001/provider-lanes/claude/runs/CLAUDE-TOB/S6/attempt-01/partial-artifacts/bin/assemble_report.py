"""Assemble TOB-S6-secure-workflow-guide.md from the report parts and the raw tool outputs (stdlib only)."""

import hashlib
import os
import re
import subprocess

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.dirname(ART)
import sys
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(WORK, "TOB-S6-secure-workflow-guide.md")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def rd(rel):
    with open(os.path.join(ART, rel), encoding="utf-8", errors="replace") as f:
        return ANSI.sub("", f.read())


def fence(text, lang="text"):
    text = text.rstrip("\n")
    ticks = "````" if "```" in text else "```"
    return f"{ticks}{lang}\n{text}\n{ticks}\n"


def raw(title, rel, lang="text", note=""):
    s = f"\n#### {title}\n\nSource: `tob-s6-artifacts/{rel}`{(' (' + note + ')') if note else ''}\n\n"
    return s + fence(rd(rel), lang)


def elide_sequences(lines):
    """Drop counterexample call-sequence entries (Echidna 4-space-indented calls, Foundry tab-indented sequence
    entries), keeping verdicts, reasons and sequence headers; insert a marker with the number of elided lines."""
    out, n = [], 0
    for l in lines:
        is_seq = ((l.startswith("    ") and not l.strip().startswith(("Reason:", "Call sequence")))
                  or l.startswith("\t\t") or re.match(r"^(EchidnaRaffle\w*\.|\*wait\*)", l) is not None)
        if is_seq:
            n += 1
            continue
        if n:
            out.append(f"    … {n} counterexample call-sequence line(s) elided …")
            n = 0
        out.append(l)
    if n:
        out.append(f"    … {n} counterexample call-sequence line(s) elided …")
    return out


def echidna_summary(title, rel):
    keep = [l for l in rd(rel).splitlines()
            if re.match(r"^(echidna_\w+: |Total calls|Unique instructions|Unique codehashes|Corpus size|Seed)", l) or "falsified" in l]
    return (f"\n#### {title}\n\nSource: `tob-s6-artifacts/{rel}` (superseded diagnostic run: final property results and totals only)\n\n"
            + fence("\n".join(keep)))


def echidna_log(title, rel):
    lines = elide_sequences(rd(rel).splitlines())
    status = [l for l in lines if "[status]" in l]
    cov = [l for l in lines if "New coverage" in l or "Saved reproducer" in l]
    keep = [l for l in lines if l not in status and l not in cov]
    body = "\n".join(keep)
    tail = "\n".join(status[-5:])
    note = (f"verbatim except {len(status) - min(5, len(status))} intermediate `[status]` lines and {len(cov)} "
            f"`New coverage`/`Saved reproducer` lines, which are elided (full log at the source path); the last 5 status "
            f"lines are shown first")
    return (f"\n#### {title}\n\nSource: `tob-s6-artifacts/{rel}` ({note})\n\n"
            + fence("…last status lines…\n" + tail + "\n…event and summary lines…\n" + body))


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


parts = [rd(f"report/{p}") for p in ("01-front-step1-3.md", "02-step4.md", "03-step5-findings.md", "04-action-plan.md")]
doc = "".join(parts)
for key, rel in (("{{FUZZ_RESULTS}}", "report/fuzz-results.md"), ("{{COVERAGE_TABLE}}", "report/coverage-table.md"),
                 ("{{MUTATION_TABLE}}", "report/mutation-table.md")):
    doc = doc.replace(key, rd(rel).rstrip("\n"))
assert "{{" not in doc, "unfilled placeholder"

app = ["\n---\n\n## Appendices: raw tool results relied upon\n"]

# A. Integrity
before = rd("integrity/packages-sha256-before.txt")
after = rd("integrity/packages-sha256-after.txt")
app.append("\n### Appendix A: Integrity of `packages/` and dependencies\n")
app.append("\nSHA-256 of every file under `packages/` before any tool ran, and after all work completed:\n")
app.append(fence("$ diff packages-sha256-before.txt packages-sha256-after.txt\n" + (
    "(no differences: identical, 40 files)" if before == after else "DIFFERENCES FOUND")))
app.append(raw("A.1 Pre-run snapshot (also equals the post-run snapshot)", "integrity/packages-sha256-before.txt"))
app.append(raw("A.2 Dependency hash verification against `dependency-hashes.json`", "integrity/dependency-hash-check.txt"))
app.append(raw("A.3 Accidental Foundry build artifacts (moved out of `packages/`)", "integrity/accidental-artifacts.txt"))

# B. Slither
app.append("\n### Appendix B: Step 1, Slither detectors\n")
app.append(raw("B.1 In-scope results (verbatim descriptions from the JSON, canonical run)", "slither/inscope-results.txt"))
app.append(raw("B.2 Result counts by detector (from JSON)", "slither/summary-counts.txt"))
app.append(raw("B.3 Full console output of the canonical run (`--show-ignored-findings`, all 110 results incl. dependencies)",
               "slither/detectors-all-show-ignored.txt"))

# C. Step 2
app.append("\n### Appendix C: Step 2, special-feature checks\n")
app.append(raw("C.1 Applicability searches", "step2/applicability-greps.txt"))
app.append(raw("C.2 `slither-check-upgradeability … Raffle`", "step2/check-upgradeability-Raffle.txt"))
app.append(raw("C.3 `slither-check-upgradeability --list-detectors`", "step2/check-upgradeability-detectors.txt"))
app.append(raw("C.4 `slither-check-erc … Raffle --erc erc721`", "step2/check-erc-Raffle-erc721.txt"))
app.append(raw("C.5 `slither-check-erc … Raffle --erc erc165`", "step2/check-erc-Raffle-erc165.txt"))

# D. Step 3
app.append("\n### Appendix D: Step 3, printers and custom Slither API output\n")
app.append(raw("D.1 `--print inheritance`", "step3/print-inheritance.txt"))
app.append(raw("D.2 `--print inheritance-graph --include-interfaces` (DOT)", "step3/with-interfaces/Scope.sol.inheritance-graph.dot", "dot"))
app.append(raw("D.3 `--print entry-points`", "step3/print-entry-points.txt"))
app.append(raw("D.4 `--print human-summary`", "step3/print-human-summary.txt"))
app.append("\n#### D.5 `--print function-summary` (rows for in-scope state-changing and security-relevant functions; padding compressed)\n\n"
           "Source: `tob-s6-artifacts/step3/print-function-summary.txt` (full 386 KB output; extracted by `bin/fsummary_extract.py`)\n\n"
           + rd("step3/function-summary-inscope-extract.md") + "\n")
app.append("\n#### D.6 `--print vars-and-auth` (Raffle and RaffleFactory; padding compressed)\n\n"
           "Source: `tob-s6-artifacts/step3/print-vars-and-auth.txt`\n\n" + rd("step3/vars-and-auth-inscope-compact.md") + "\n")
app.append(raw("D.7 Custom Slither API analysis (`bin/raffle_slither_checks.py`): function summary, authorization map, checks C1-C8",
               "step3/raffle-slither-api.txt", "markdown"))
app.append(raw("D.8 C3 linearization, explicit overrides and storage layout (Slither API)", "step3/c3-linearization.txt"))
app.append(raw("D.9 Targeted detector run (29 detectors: shadowing, inheritance, initialization, reentrancy, token, ETH)",
               "step3/targeted-detectors.txt"))

# E. Echidna
app.append("\n### Appendix E: Step 4, Echidna\n")
app.append(raw("E.0 Final configuration, profile A", "harness/echidna/echidna-final.yaml", "yaml"))
app.append(raw("E.0b Final configuration, profile B", "harness/echidna/echidna-final-B.yaml", "yaml"))
for title, rel in (
    ("E.1 Main property campaign, profile A (12 h max random delay)", "step4/echidna-final-main.txt"),
    ("E.2 Main property campaign, profile B (1 h max random delay)", "step4/echidna-final-main-B.txt"),
    ("E.3 Reachability canaries, profile A (all 11 expected to fail)", "step4/echidna-final-canaries.txt"),
    ("E.4 Reachability canaries, profile B", "step4/echidna-final-canaries-B.txt"),
    ("E.7 Smoke run", "step4/echidna-smoke.txt"),
):
    if os.path.exists(os.path.join(ART, rel)):
        app.append(echidna_log(title, rel))
app.append(echidna_summary("E.5 Earlier canary run with 3-day random delays (diagnostic; 6/11 reached)", "step4/echidna-canaries-v2.txt"))
app.append(echidna_summary("E.6 Earlier canary run, pre-final harness (diagnostic; 8/9 reached)", "step4/echidna-canaries.txt"))
app.append(raw("E.8 In-scope line coverage summary from Echidna `covered.*.txt` (profiles A and B)", "step4/echidna-coverage-summary.txt"))

# F. Foundry
app.append("\n### Appendix F: Step 4, Foundry\n")
app.append(raw("F.1 Deterministic, fuzz, PoC and sanity tests (40 tests)", "step4/foundry-unit-poc-final.txt"))
app.append(raw("F.2 Final invariant campaign (final harness)", "step4/foundry-invariant-final.txt"))
app.append(raw("F.2b Final invariant campaign before the refund-action harness fix (1 handler revert, explained in Section 4.2)", "step4/foundry-invariant-final-prefix.txt"))
app.append(raw("F.3 Invariant campaign 2,000 runs x 150 depth (pre-final harness wiring; same handler logic)", "step4/foundry-invariant-2000x150.txt"))
app.append("\n#### F.4 Reachability canaries (all 14 expected to fail)\n\nSource: `tob-s6-artifacts/step4/foundry-canaries.txt` "
           "(verbatim except counterexample call-sequence entries, elided with counts, and the per-selector call tables)\n\n"
           + fence("\n".join(l for l in elide_sequences(rd("step4/foundry-canaries.txt").splitlines())
                              if not re.match(r"^\s*[|+╭╰├═─]", l))))
app.append(raw("F.5 Coverage summary (`forge coverage --ir-minimum`)", "step4/forge-coverage-final.txt"))
app.append(raw("F.5b Uncovered in-scope lines and untaken branch arms (from `lcov.info`)", "step4/forge-coverage-uncovered.txt"))
app.append(raw("F.6 Probe project (`gas-probe/`): cold-storage callback gas and probes P1-P4", "step4/gas-probe.txt"))
app.append(raw("F.7 Reproduction of the handler revert against the pre-fix harness (expects Panic 0x11)", "step4/handler-revert-repro-prefix.txt"))

# G. Mutation
app.append("\n### Appendix G: Step 4, mutation analysis\n")
app.append(raw("G.1 Runner output", "step4/mutation-results.txt"))
app.append(raw("G.2 Mutant M10 against the TOB-S6-1 PoCs", "step4/mutant-M10-vs-G1.txt"))
diffs = []
for mid in sorted(d for d in os.listdir(os.path.join(ART, "mutants")) if d.startswith("M")):
    p = subprocess.run(["diff", "-u", os.path.join(WORK, "packages/contracts/src/Raffle.sol"),
                        os.path.join(ART, "mutants", mid, "src", "Raffle.sol")], capture_output=True, text=True)
    out = p.stdout.replace(WORK + "/", "")
    diffs.append(f"### {mid}\n{out}")
app.append("\n#### G.3 Mutant diffs (against the original `Raffle.sol`)\n\n" + fence("\n".join(diffs), "diff"))

# H. Artifacts inventory
inv = []
for root, dirs, files in os.walk(os.path.join(ART, "harness")):
    dirs[:] = [d for d in dirs if d not in ("out", "cache") and not d.startswith("corpus")]
    for f in sorted(files):
        p = os.path.join(root, f)
        if p.endswith((".sol", ".yaml", ".toml")):
            inv.append(f"{sha(p)}  {os.path.relpath(p, WORK)}")
for f in sorted(os.listdir(os.path.join(ART, "bin"))):
    p = os.path.join(ART, "bin", f)
    inv.append(f"{sha(p)}  {os.path.relpath(p, WORK)}")
for f in sorted(os.listdir(os.path.join(ART, "gas-probe", "test"))):
    p = os.path.join(ART, "gas-probe", "test", f)
    inv.append(f"{sha(p)}  {os.path.relpath(p, WORK)}")
for f in sorted(os.listdir(os.path.join(ART, "diagrams"))):
    p = os.path.join(ART, "diagrams", f)
    inv.append(f"{sha(p)}  {os.path.relpath(p, WORK)}")
app.append("\n### Appendix H: Harness, script and diagram inventory (SHA-256)\n\n" + fence("\n".join(sorted(inv, key=lambda l: l.split('  ')[1]))))

doc += "".join(app)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(doc)
print(f"wrote {OUT}: {len(doc):,} chars, {doc.count(chr(10)):,} lines")
