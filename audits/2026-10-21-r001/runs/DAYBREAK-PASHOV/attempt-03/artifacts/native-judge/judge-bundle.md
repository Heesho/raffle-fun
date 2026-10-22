# DAYBREAK-PASHOV native Turn 4 judge bundle

This bundle contains only the frozen source-first-pass context, the accepted corrected specialist final responses, and the pinned native method resources.
The initial specialist wave is deliberately excluded because the controller superseded it. Memory and known-finding context are off.

# PINNED SKILL.md

---
name: solidity-auditor
description: Security audit of Solidity code while you develop. Trigger on "audit", "check this contract", "review for security", "loop mode", "run the auditor in loop mode", "run 3 passes". Modes - default (full repo) or a specific filename. Loop mode runs several passes in one scan, each pass told what the earlier ones found, and ends in one combined report; it remembers findings between scans in a ledger.
---

# Smart Contract Security Audit

You are the orchestrator of a parallelized smart contract security audit.

## Mode Selection

**Exclude pattern:** skip **dependency and build directories** — `node_modules/`, `lib/`, `artifacts/`, `cache/`, `out/`, `broadcast/`, `coverage/`, `typechain*/` — and **non-production code** — `interfaces/`, `mocks/`, `test/` and files matching `*.t.sol`, `*Test*.sol` or `*Mock*.sol`.

**Deploy scripts stay in scope.** `script/`, `deploy/` and `*.s.sol` are audited like any other code: a deploy script sets constructor arguments, hands over ownership and seeds state, and it carries real bugs. Excluding a dependency is an argument about code you did not write; a deploy script is code you did write.

- **Default** (no arguments): scan all `.sol` files using the exclude pattern. Use Bash `find` (not Glob), exactly this command:

  ```bash
  find . -type f -name '*.sol' \
    -not -path '*/node_modules/*' -not -path '*/lib/*' -not -path '*/artifacts/*' \
    -not -path '*/cache/*' -not -path '*/out/*' -not -path '*/broadcast/*' \
    -not -path '*/coverage/*' -not -path '*/typechain*/*' \
    -not -path '*/interfaces/*' -not -path '*/mocks/*' -not -path '*/test/*' \
    -not -name '*.t.sol' -not -name '*Test*.sol' -not -name '*Mock*.sol'
  ```

  `-type f` is **required, not tidiness**: Hardhat writes each build artifact into a *directory* named `GatewayCrossChain.sol/`, so a `find` without it matches directories as if they were source files and hands them to `cat`. Do not drop it, and do not re-derive this command — paste it.

- **`$filename ...`**: scan the specified file(s) only. **The exclude pattern does not apply here.** A file named on the command line is always scanned, wherever it lives — naming `node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol` scans that file. The pattern chooses what a *default* scan discovers; it never overrides an explicit request.

**Flags:**

- `--file-output` (off by default): **copy** the assembled report into the working directory (name per `{resolved_path}/report-formatting.md`). The flag never causes a report to be produced — every scan assembles `.solidity-auditor/runs/{stamp}/full-report.md` whether it is passed or not. It only decides whether a copy lands where the runner can see it.

  > **Line 33 used to read "Never write a report file unless explicitly passed", and that is now false.** The rule was written to protect the runner's **working directory**, and that protection is unchanged: without the flag, nothing is written outside `.solidity-auditor/`. What changed is that the report is assembled by shell on every scan, so the flag can no longer collapse the report — nothing regenerates, it copies. A later editor must not read this as a mistake and revert it.

- `--memory` (off by default): remember findings between scans in a ledger at `.solidity-auditor/memory.tsv` in the audited repo. Any pass count above 1 turns memory on by itself, whether or not the flag was passed.
- `--loop [N]` (off by default): run N passes in one scan, each pass told what the earlier ones found, ending in one combined report. `--loop` with no number is **3** passes. `--loop 1` is a 1-pass scan. The flag exists for runners who prefer flags; when it is passed the picker in Turn 1b does not ask, it obeys.

**Vocabulary (used throughout this file):**

- **run** — one pass of the 12 agents.
- **scan** — one invocation of this skill. A scan holds 1 or more runs.

The ledger's `scans` column counts scans. The report's `seen in k/N runs` counts runs inside one scan and is never written to the ledger. Two numbers, two names — do not mix them.

The pass count the scan runs is `{passes}` — settled in Turn 1b, 1 or more. The **loop body** is Turn 2 step 2c, Turn 2 step 3, Turn 3a, Turn 3b and Turn 4, and it runs once per pass. Everything before it runs once per scan, and Turn 5 closes the scan once, whatever `{passes}` is.

> **HARD RULE — the plain path must stay plain.** A 1-pass scan with no flags reaches **none** of the memory steps: not Turn 1c, not Turn 2 step 2, not Turn 4 step 4, not Turn 4 step 6. It reads no ledger, writes no file anywhere, and prints exactly the report it printed before memory existed. Memory is on only when `--memory` was passed or the pass count is above 1. A later editor who is tempted to make any memory step unconditional is breaking this on purpose, not tidying up.

> **A 1-pass answer reaches none of the loop or memory machinery.** No ledger is read or written. No `Passes` or `Memory` row in the Scope table. No `seen in k/N runs`. No `KNOWN` / `NEW` tag. No per-pass summary lines. **The printed report is the report this skill printed before loop mode existed.** The only trace of the picker is the question itself.
>
> **What it does write.** Every scan writes `.solidity-auditor/runs/{stamp}/` — one `run-1.md`, one `scope.tsv`, one `full-report.md` — because the report is assembled from those files at every pass count, and `name`, `mode`, `files` and `threshold` are needed by every report. This paragraph used to say a 1-pass answer creates no `.solidity-auditor/` directory and no `runs/` files; that is now false, and it was never what the rule was protecting.
>
> **What the rule protects, stated exactly:** on the plain path the scan reads no ledger, writes no `mem_` key, and prints a Scope table of exactly **three** rows — `Mode`, `Files reviewed`, `Confidence threshold (1-100)` — and no `Passes` row, no `Memory` row. Disk is not printed output. A later editor who makes a **memory** step unconditional is breaking this on purpose; writing the runs directory is not one of those steps.
>
> `--memory` on a 1-pass run is the single exception: memory turns on, the loop machinery stays off.

## Orchestration

**Turn 1 — Discover.** Print the banner, then make these parallel tool calls in one message:

a. Bash `find` for in-scope `.sol` files per mode selection
b. Glob for `**/references/hacking-agents/shared-rules.md` — extract the `references/` directory (two levels up) as `{resolved_path}`
c. ToolSearch `select:Agent`
d. Read the local `VERSION` file from the same directory as this skill
e. Bash `curl -sf https://raw.githubusercontent.com/pashov/skills/main/solidity-auditor/VERSION`
f. Bash `mktemp -d ./.audit-XXXXXX` → store as `{bundle_dir}`
g. Bash `date +%Y%m%d-%H%M%S` → store as `{stamp}`, the scan-time stamp. **One stamp per scan, computed once, here.** The runs directory, the run files and any `--file-output` copy all carry it, so a report and the runs that produced it are tied together by eye.

**Turn 1a — Open the scan directory.** After the `find` returns, in one Bash command:

```bash
mkdir -p .solidity-auditor/runs/{stamp}
: > .solidity-auditor/runs/{stamp}/scope.tsv
```

Then write the three scope keys this turn knows. **A scope key is written with one `printf` and never any other way:**

```bash
printf '%s\t%s\n' name  "{project-name}" >> .solidity-auditor/runs/{stamp}/scope.tsv
printf '%s\t%s\n' mode  "{mode}"         >> .solidity-auditor/runs/{stamp}/scope.tsv
printf '%s\t%s\n' files "{file list}"    >> .solidity-auditor/runs/{stamp}/scope.tsv
```

- `{project-name}` — the repo root basename, the same one `report-formatting.md` names.
- `{mode}` — `default` or `filename`, as Mode Selection settled it.
- `{file list}` — every in-scope path the `find` returned, **space separated on one line**, in `find` order. The assembler wraps them 3 per row; the order it prints is the order written here.

> **`scope.tsv` is `key<TAB>value`, append-only, last line per key wins.** An absent key gives an absent table row — that is what keeps the plain scan's Scope table at three rows with no special case. A tab or a newline in a value breaks the row, so values are **stripped**, not escaped: no key here has any use for either character. Six writers across four turns append to this one file, and none of them ever rewrites or deletes a line.
>
> `name` and `mode` are the **only two keys a model types**. Everything else is either shell knowledge or read by the assembler for itself: the threshold from the constant, `N` in `seen in k/N runs` from counting run files, the stamp from the directory's own name.

If the remote VERSION fetch succeeds, compare the two as **numbers** and warn **only when the local one is lower**: print `⚠️ You are not using the latest version. Please upgrade for best security coverage. See https://github.com/pashov/skills`. If it fails, skip silently.

> **Lower, not different.** A plain "differs" test warns the wrong person: somebody working on an unreleased version has a local `VERSION` **above** the published one, and gets told to upgrade to the version they are writing. Local equal to remote, or local above it, prints nothing.

**Turn 1b — Model and pass count.** This turn asks **two questions in one `AskUserQuestion` call**: which model the 12 agents use, and how many passes the scan runs. The runner is interrupted once, before any work starts.

> **The two questions do not fail the same way.** On a runtime without `AskUserQuestion` and an `Agent` tool that takes a `model` parameter — Codex, Gemini, Cursor's native agent — the **model** question is skipped silently, `{agent_model}` is left unset, and no prose replaces it. The **pass** question is not skipped: it falls through to the printed block in Turn 1b-ii, which stops and waits. This turn as a whole is never skipped. A later editor must not restore a blanket "SKIP this turn entirely" rule: it was true when this turn asked one question, and it is false now.

**Turn 1b-i — the `AskUserQuestion` call (Claude Code).** Ask both questions in one call. Where the `Agent` tool takes no `model` parameter, ask the pass question alone.

Question 1 — model:

1. Read your system prompt to detect your own model **family** (Opus, Sonnet, or Haiku). Ignore the version digits — the Agent tool's `model` parameter takes the family name (`"opus"` / `"sonnet"` / `"haiku"`), and the runtime resolves to the latest version in that family.
2. Put this question in the call:
   - Question: `"Which Claude model should the 12 audit agents use?"`
   - Three single-select options. Mark the orchestrator's own family as `(Recommended)` and place it first.
   - On each option, set the `description` field to `latest`.
   - On each option, set the `preview` field verbatim (preserve all whitespace exactly — the box widths must stay equal across all three):

   Opus preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  opus  ·  highest reasoning  ·  most expensive           │
   └──────────────────────────────────────────────────────────┘
   ```

   Sonnet preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  sonnet  ·  balanced reasoning  ·  mid cost              │
   └──────────────────────────────────────────────────────────┘
   ```

   Haiku preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  haiku  ·  lowest reasoning  ·  cheapest                 │
   └──────────────────────────────────────────────────────────┘
   ```
3. Store the runner's choice as `{agent_model}`. If no answer, default to the orchestrator's own model.

Question 2 — pass count. It goes in the **same call**, second:

4. Question: `"How many passes should this audit run? Each pass is a full 12-agent audit, and every pass after the first is told what the earlier ones found, so it hunts new ground. You get one combined report at the end."`

   Three single-select options, `3 passes` first and marked `(Recommended)`. Each carries a `preview` box in this turn's style — the boxes are **60 characters wide, equal to the model picker's**, so two questions in one prompt look like one thing. Set `preview` verbatim, whitespace preserved:

   | Label | `description` |
   | --- | --- |
   | `3 passes (Recommended)` | `~45 min` |
   | `1 pass` | `~15 min` |
   | `5 passes` | `~75 min` |

   3 passes preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  3 passes  ·  each pass hunts new ground  ·  ~45 min     │
   └──────────────────────────────────────────────────────────┘
   ```

   1 pass preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  1 pass  ·  today's audit  ·  ~15 min, nothing written   │
   └──────────────────────────────────────────────────────────┘
   ```

   5 passes preview:

   ```
   ┌──────────────────────────────────────────────────────────┐
   │  5 passes  ·  deepest sweep  ·  ~75 min                  │
   └──────────────────────────────────────────────────────────┘
   ```

   > **These are measured, not guessed — and they are a floor.** A real 3-pass scan of 2,228
   > lines of Solidity across 10 files, 12 agents per pass on Opus, took **43 minutes** wall
   > clock: 11 minutes for pass 1 and about 16 for each of passes 2 and 3, which run slower
   > because the growing `known-findings.md` is appended to all twelve bundles. Individual
   > agents ran 3.5–11 minutes. A larger codebase takes longer; a smaller model is faster.
   > Quote minutes rather than multipliers — "~3x time" told the runner nothing about whether
   > to wait or come back after lunch. If these numbers are ever re-measured, correct them
   > here rather than adding a second estimate somewhere else.

5. **Any other number needs no option of its own.** `AskUserQuestion` always adds an **Other** choice with a free-text box, and the runner types their number there. Do NOT add a fourth option reading "your own number" — options are fixed choices, so it could not collect the number and would dead-end.

   Parse the Other answer for the first integer. Below 1 or above 10 → ask once more. A second unusable answer → **1 pass**.

6. Store the answer as `{passes}`. No answer at all → 1 pass.

**Turn 1b-ii — the printed fallback (every runtime without `AskUserQuestion`).** Print this exactly:

```
How many passes should this audit run?

Each pass is a full 12-agent audit. Every pass after the first is told what the
earlier passes found, so it hunts new ground. You get one combined report at the end.

  1) 1 pass    — today's audit, about 15 minutes. Nothing is written to disk.
  2) 3 passes  — recommended. About 45 minutes.
  3) 5 passes  — deepest sweep. About 75 minutes.

Answer with 1, 2, 3, or any pass count you want.
```

> **STOP here and wait for the runner's answer.** Do NOT choose for them. Do NOT continue to Turn 2 with an assumed pass count. Do NOT start the scan and ask later.
>
> This is the one place in this skill where a question is emitted as prose. Turn 1b forbids prose questions because the model picker has a safe default — the orchestrator's own model. A pass count has no safe default: 1 and 5 differ by 5x in time and in cost, and that is the runner's money. A later editor must not "fix" this by deleting the prose block or by picking a default. If you are reading this and it looks like an inconsistency, it is deliberate.

Answers `1`, `2` and `3` are the three listed choices; any other integer is that many passes. Apply the same bounds as Turn 1b-i step 5 — below 1 or above 10, ask once more, then 1 pass.

**Turn 1b-iii — when the runner already said.** Ask nothing that has already been answered:

| What arrived | What the picker does |
| --- | --- |
| `--loop 5` | Skip the pass question, silently. 5 passes. |
| `--loop` with no number | Skip the pass question, silently. 3 passes. |
| "run 4 passes", "audit this four times" | Skip the pass question, silently. 4 passes. |
| "loop mode", "run it a few times" — a request with no number | **Ask.** They asked for the feature, not for a count. |
| Nothing | Ask. |

Skipping is silent in the first three rows — printing `using 5 passes` back at somebody who just typed `--loop 5` is noise. Skipping the pass question never skips the model question, and the reverse holds too.

**Turn 1b-iv — record the pass count.** However `{passes}` was settled — asked, typed in the prose fallback, or read off a flag — write it once, here:

```bash
printf '%s\t%s\n' passes_planned "{passes}" >> .solidity-auditor/runs/{stamp}/scope.tsv
```

This is the `P` in the Scope table's `Passes` row. The `R` — how many passes actually produced a run file — is counted by the assembler from the run files themselves, so a pass that dies before it can record anything still lowers the count. The row is printed only when `P` is above 1, so writing the key on a 1-pass scan is harmless: `passes_planned` `1` prints no row.

**Turn 1c — Memory read.** **SKIP this turn entirely when memory is off.** It is a turn of its own, and not a step of Turn 2, because two of its outcomes stop or downgrade the whole scan — they have to be reached before any expensive work starts.

1. **Shell check.** Memory is merged by `awk`. Run `command -v awk >/dev/null` once. If it fails, print `memory needs a bash shell — on Windows install Git for Windows`, turn memory **off** for this scan, scan as a plain 1-run scan, and touch no file. There is no second implementation of the merge; the rule that must never break lives in one language only.

2. **Stale temporary file.** If `.solidity-auditor/memory.tsv.tmp` exists, a previous scan did not finish. Print `warning: .solidity-auditor/memory.tsv.tmp left by an unfinished scan — overwriting`, then carry on. It is overwritten by this scan's merge.

3. **Read the ledger.** If `.solidity-auditor/memory.tsv` does not exist, this is a first-ever scan: memory is empty, every finding is `NEW`, the file is written at the end. Otherwise read it and **validate it before using it**:
   - the first line's first tab-separated field is exactly `#solidity-auditor-memory v1`
   - every later line has exactly **6** tab-separated fields

   On any failure print the path and the problem and **STOP the scan**. No agents, no report, no write. The user fixes or deletes the file. Do NOT start fresh and do NOT continue with a warning — a single bad row must never destroy real memory.

4. **Photocopy it.** `mkdir -p {bundle_dir}` is already done; copy the ledger as it was **before this scan started**:

   ```bash
   cp .solidity-auditor/memory.tsv {bundle_dir}/memory-before.tsv 2>/dev/null || : > {bundle_dir}/memory-before.tsv
   ```

   Every merge this scan performs reads this photocopy, never the live file. Create it empty when no ledger exists, so the merge command below needs no special case.

5. **Create the scan's row file**, empty: `: > {bundle_dir}/scan-rows.tsv`. Each run appends its gated rows to it.

6. **Hold the key list** — column 1 of every row of the photocopy (after the prune in Turn 2, if one runs).

   The **per-function bug-class vocabulary** — for each `contract|function` prefix, the bug-class labels the ledger already holds — is not held in the orchestrator's head. Turn 2 step 2c writes it to `{bundle_dir}/known-findings.md`, where the agents read it inside their bundles and Turn 4 reads it back from disk. It is a file and not a memory because the two readers are a long scan apart, and because the same labels must reach both.

   The vocabulary is what keeps exact key matching honest: a bug class is a label written in words, so the same bug re-labelled is a second record and memory fails silently. Handing the existing labels back is how the same bug keeps the same key.

**Turn 2 — Prepare.** In one message, make parallel tool calls: (a) Read `{resolved_path}/report-formatting.md`, (b) Read `{resolved_path}/judging.md`, (c) Read `{resolved_path}/agent-prompts.md`, (d) Read `{resolved_path}/report-language.md`.

> **Why `report-formatting.md` is still read, now that nothing here composes a report.** It is the shape Turn 4 step 5a writes each finding in — title line, location line, Description, diff Fix block — and the assembler pastes those bytes straight through. Read it as the contract the finding blocks meet, not as a template to imitate at the end.

> **`report-language.md` is read for the same reason, one level down.** `report-formatting.md` settles the **shape** of a finding block; `report-language.md` settles the **words inside it**. Turn 4 step 5a writes the title and the Description, the assembler pastes them through unchanged, so those bytes are the last chance to write a sentence a developer can act on. It is Simplified Technical English (ASD-STE100), and it is not optional styling: a finding the developer cannot read is a finding they do not fix. The same file is in every agent bundle, so the sentence the pass writes and the sentence the agent handed it obey one rule.

Then build `source.md`, run the memory step, and only then cat the bundles — in that order, because the bundles carry a file the memory step writes:

> **Turn 2 is split across the loop.** Step 1 runs **once per scan**: `source.md` provably cannot change between passes — one git SHA for the whole loop, no pruning between them — and it is the expensive half of the build. Step 2c and step 3 run **once per pass**, because only they carry the knowns, and re-catting twelve bundles from files already on disk is one Bash command. Steps 2a and 2b run once per scan with step 1, since both read that frozen source.
>
> **One `{bundle_dir}`, reused, everything overwritten.** `source.md` is written once and never touched again; `known-findings.md` and the twelve `agent-N-bundle.md` files are overwritten each pass. Disk stays flat whether the runner picked 1 pass or 10 — a directory per pass would hold 12 × N copies of the whole repo. This is safe because Turn 3b is a hard barrier: no pass-K agent is still reading a bundle when pass K+1 overwrites it. The cost, accepted: after the loop you cannot see what pass 2 told its agents. The durable record is the run files and the ledger.

1. **Once per scan.** `{bundle_dir}/source.md` — ALL in-scope `.sol` files, each with a `### path` header and fenced code block.
2. **Turn 2 step 2 — Name map, prune and known findings** (below). SKIPPED whole when memory is off. Parts a and b run once per scan; part c runs **every pass**, because the ledger it reads grows as the loop learns.
3. **Every pass.** Agent bundles, in a single Bash command using `cat` (not shell variables or heredocs) = `source.md` + agent-specific files:

| Bundle                | Appended files (relative to `{resolved_path}`)                                                                                                |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `agent-1-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/math-precision-agent.md` + `hacking-agents/shared-rules.md`                            |
| `agent-2-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/access-control-agent.md` + `hacking-agents/shared-rules.md`                            |
| `agent-3-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/economic-security-agent.md` + `hacking-agents/shared-rules.md`                         |
| `agent-4-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/execution-trace-agent.md` + `hacking-agents/shared-rules.md`                           |
| `agent-5-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/invariant-agent.md` + `hacking-agents/shared-rules.md`                                 |
| `agent-6-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/periphery-agent.md` + `hacking-agents/shared-rules.md`                                 |
| `agent-7-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/first-principles-agent.md` + `hacking-agents/shared-rules.md`                          |
| `agent-8-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/asymmetry-agent.md` + `hacking-agents/shared-rules.md`                                 |
| `agent-9-bundle.md`   | `source.md` + `senior-auditor-sop.md` + `hacking-agents/boundary-agent.md` + `hacking-agents/shared-rules.md`                                  |
| `agent-10-bundle.md`  | `source.md` + `senior-auditor-sop.md` + `hacking-agents/numerical-gap-agent.md` + `hacking-agents/shared-rules.md`                             |
| `agent-11-bundle.md`  | `source.md` + `senior-auditor-sop.md` + `hacking-agents/trust-gap-agent.md` + `hacking-agents/shared-rules.md`                                 |
| `agent-12-bundle.md`  | `source.md` + `senior-auditor-sop.md` + `hacking-agents/flow-gap-agent.md` + `hacking-agents/shared-rules.md`                                  |
| **every one of the 12** | **+ `report-language.md`, appended after `shared-rules.md`** — unconditional, every mode, every pass. The agent's `description:` is the seed of the report's Description, so the language rule has to reach the writer and not only the editor. |
| **every one of the 12** | **+ `{bundle_dir}/known-findings.md`, appended last** — only when memory is on **and** step 2 wrote that file. Never appended on a plain scan, and never appended when the ledger holds no record. |

Each bundle = source.md + SOP + specialty + shared-rules + report-language (+ known findings, when there are any). Agents read the bundle; no Read/Grep needed for the initial scan. Targeted Read/Grep allowed for cross-file investigation.

**Turn 2 step 2 — Name map, prune and known findings.** **SKIP this step entirely when memory is off.** It lives in Turn 2 and not in a turn of its own because all three parts read `source.md`, which Turn 2 has just built — a separate turn would only carry that file across a boundary. It is numbered **2**, ahead of the bundle cat, because part c writes a file every bundle carries; a pruned record must never reach an agent.

a. **Build the name map, always** — once per scan, with step 1 (both the prune and the report need it, and the source it reads is frozen for the whole scan):

```bash
grep -ohE '(contract|library|interface)[[:space:]]+[A-Za-z0-9_]+|function[[:space:]]+[A-Za-z0-9_]+' {bundle_dir}/source.md \
  | awk '{ n=$2; k=tolower(n); gsub(/[^a-z0-9]+/, "-", k); print k "\t" n }' \
  | sort -u > {bundle_dir}/source-names.tsv
```

Column 1 is the identifier normalised the same way a key segment is (lower case, every run of non-alphanumeric characters to one hyphen); column 2 is how it is spelled in the source. Normalising **both sides the same way** is what makes the comparison exact — a key segment can never be matched against raw source text, because `withdrawAll` is stored as `withdrawall`.

b. **Prune — once per scan, and only after a whole-repo scan.** Run it **only** in default mode. Never on a named-file scan (a file that was not scanned proves nothing about the records it holds), and never a second time inside one scan — the loop's later passes read the same frozen source, so there is nothing new for a second prune to learn.

The prune edits the **photocopy**, not the live ledger. The live file inherits the prune when the first merge writes it. Pruning the live file instead would be undone by the next rebuild.

```bash
awk -F'\t' -v OFS='\t' '
FILENAME==ARGV[1] { names[$1]=1; next }
FNR==1 { print; next }
{
  split($1, p, "|")
  keep = (p[1] in names) && (p[2] in names)
  if (p[2]=="constructor" || p[2]=="receive" || p[2]=="fallback") keep = (p[1] in names)
  if (keep) print; else print "pruned: " $6 "\t" $1 "\t" $5 > "/dev/stderr"
}
' {bundle_dir}/source-names.tsv {bundle_dir}/memory-before.tsv > {bundle_dir}/memory-before.tsv.tmp \
  && mv {bundle_dir}/memory-before.tsv.tmp {bundle_dir}/memory-before.tsv
```

A record is dropped when its contract or its function can no longer be found in the assembled source. `constructor`, `receive` and `fallback` are never written as `function <name>`, so a record on one of them is kept whenever its contract survives.

**The prune deletes Leads as well as findings.** A Lead is a full ledger record, so the same rule reaches it — and a pruned Lead leaves no trace anywhere else in the output. That is why the command prints every dropped row to the runner: `kind`, key and title, one line each. Print them under `Pruned N records (contract or function no longer in scope):`. Never drop a record silently.

After the prune, re-read the photocopy for the key list of Turn 1c step 6. A pruned record must not reach the agents, the merge, or the "Known from earlier scans" section.


c. **Write `mem_before`, then build `{bundle_dir}/known-findings.md`.**

**`mem_before` first** — the row count of the photocopy **as the merge will read it**, which is the count *after* the prune. It is written here and nowhere else, and it is written in every mode memory is on, whether or not part b's prune ran (it does not run on a named-file scan):

```bash
printf '%s\t%s\n' mem_before "$(( $(wc -l < {bundle_dir}/memory-before.tsv) - 1 ))" \
  >> .solidity-auditor/runs/{stamp}/scope.tsv
```

The `- 1` drops the header line. An empty photocopy has no header and would give `-1`; write `0` instead. The **pre**-prune number would make the `Memory` row's own arithmetic wrong — `12 records before this scan · 14 after` has to describe the same set the merge worked on.

**This key is the memory flag the assembler reads.** Its presence is what makes the `Memory` row appear and the "Known from earlier scans" section exist — the presence of `memory-before.tsv` is not. Nothing writes a `mem_` key when memory is off, and this whole step is skipped when it is, so the flag cannot get out of step with the scan.

It is written before the early exit below, so an empty ledger still gets a `Memory` row reading `0 records before this scan`.

**Then `{bundle_dir}/known-findings.md`** — the ledger as the agents and Turn 4 read it. It is built from the **pruned** photocopy and from `source-names.tsv`, so it never names a record the prune has just dropped and never prints a normalised key at a human.

```bash
awk -F'\t' '
FILENAME==ARGV[1] { nm[$1]=$2; next }
FNR==1 { next }
{
  split($1, p, "|")
  c = (p[1] in nm) ? nm[p[1]] : p[1]
  f = (p[2] in nm) ? nm[p[2]] : p[2]
  h = c "." f
  if (!(h in seen)) { seen[h]=1; ord[++n]=h }
  body[h] = body[h] "- `" p[3] "` — " $6 ", seen in " $3 ($3==1 ? " scan" : " scans") " — " $5 "\n"
}
END { for (i=1; i<=n; i++) printf "## %s\n\n%s\n", ord[i], body[ord[i]] }
' {bundle_dir}/source-names.tsv {bundle_dir}/memory-before.tsv > {bundle_dir}/known-findings.body.md
```

**If that file is empty, stop here** — delete it, write no `known-findings.md`, and append nothing to the bundles. An empty ledger (a first-ever scan, or a scan whose every record the prune removed) must not hand twelve agents an empty heading.

Otherwise write `{bundle_dir}/known-findings.md` as this exact prose followed by the body, unchanged:

````markdown
# Known findings — ground already walked

Earlier scans of this repository recorded the findings below, grouped by the contract and
function they sit in. Each line is `bug class` — kind, scans, title.

**They are not false positives, and they are not off limits.** Put your **effort** into new
ground: functions, flows and mechanisms this list does not name. That is a rule about where
your reading time goes. It is **not** a rule about what you report.

**Report every bug you find in full, listed or not.** A listed bug you reach again is a bug
that is still there, and the report has to say so. Write it up exactly as you would write up
anything new — the same path, proof and fix — whether you reached it by the mechanism it is
listed with or by a different one. Silence is read as "nobody found this": a finding no agent
raises drops out of the report into a table of records nobody re-checked, so a repository
scanned twice would show fewer bugs than the same repository scanned once.

**Reuse the bug-class label.** The backticked label on each line is the word this repository
already uses for that class of bug in that function. When you report a finding or a lead
whose bug class is one of the classes listed for that same contract and function, write
**that exact label**. Invent a new label only when none of them is the same class of bug.
Memory matches these labels as plain text, so the same bug under a new word is remembered
twice and recognised never.

<body — one `## Contract.function` section per function, as generated above>
````

The label-reuse rule is written here, once, for **both** readers of this file: the 12 agents,
who write the bug class in a finding, and Turn 4 step 4, which writes it into a key.

**The builder takes any 6-column ledger file.** On a single-run scan that file is the pruned
photocopy, as above. A multi-pass scan rebuilds `known-findings.md` from the freshly merged
`.solidity-auditor/memory.tsv` after every pass, before it re-cats the bundles, so the agents
of pass K+1 read what pass K found as ground already walked. That is the whole point of
passing memory down a loop; the command does not change, only the file it is pointed at.

Print line counts for every bundle and `source.md`. Do NOT inline source code into the Agent call prompt itself.

**Turn 3a — Spawn all 12 agents.** Runs **every pass**. In one message, spawn all 12 agents as **parallel BACKGROUND Agent calls** (`run_in_background=true`). If Turn 1b set `{agent_model}`, pass `model={agent_model}` on every Agent call. If `{agent_model}` is unset (Turn 1b skipped — Codex, Gemini, others), omit the `model` parameter entirely — do NOT substitute any default. The orchestrator will receive a notification when each agent completes — do NOT poll or sleep. Single phase, no later spawns. Proceed to Turn 3b only after all 12 have notified completion.

Agents 1–9 use the **single-specialty prompt** (Turn 3a-i). Agents 10–12 use the **gap-hunter prompt** (Turn 3a-ii).

**Turn 3a-i — Single-specialty prompt (agents 1–9).** Use the template under "Single-specialty prompt" in `{resolved_path}/agent-prompts.md`, substituting `{bundle_dir}`, the agent number and the bundle line count.

**Turn 3a-ii — Gap-hunter prompt (agents 10–12).** Use the template under "Gap-hunter prompt" in the same file.

Two rules that file carries, repeated here because they are conditions and not text:

- The **"Known findings"** paragraph is included **only when memory is on and `known-findings.md` was appended**. On a plain scan the prompt is byte-identical to the one it has always been — a paragraph about a section that is not there would send agents hunting for it.
- The **READ-ONLY** paragraph is **unconditional** — every agent, every mode, every pass. A real scan proved it necessary: an agent built Foundry proof-of-concept files inside the audited repository and deleted them afterwards. It left the tree clean and the stored SHA honest, and it was still wrong. A later editor must not make it conditional, and must not soften it into a preference.

**Turn 3b — Wait for all 12 agents to complete.** Runs **every pass**. Once every one of the 12 spawned agents has notified completion, proceed to Turn 4. Do NOT proceed to dedup until every agent has finished — let them run to natural completion. Do NOT poll or sleep; act only on completion notifications.

**While you wait, on the first pass only, Read `{resolved_path}/dedup-and-assembly.md`.** It holds the whole of Turn 4 and Turn 5. This turn is the one point in the scan where the orchestrator has nothing else to do, so the read costs no wall-clock; and having it in hand before Turn 4 starts is what keeps Turn 4 from improvising. Later passes already hold it.

**When an agent dies.** Continue the pass with the eleven that came back. **Never respawn it, in any mode.** A retry costs an unbounded wait for one twelfth of the coverage, and a loop covers it for free — the next pass runs the same twelve specialties again, knowing what this one found. Record the loss in all three places, or it is a silent coverage loss: the pass summary line (Turn 4 step 5), the `run-K.md` header, and the report's `Passes` row.

**When a whole pass produces nothing** — the bundle build failed, or all twelve died:

**Record the failure before doing either.** A pass that produces nothing writes no run file, so nothing else on disk knows it was ever planned:

```bash
printf '%s\t%s\n' pass_{K}_failed 1 >> .solidity-auditor/runs/{stamp}/scope.tsv
```

- **Pass 1 produces nothing:** this is not a loop failure, it is today's failure. No ledger write. Go to Turn 5, which assembles a report with no findings in it — `_None — this scan raised no findings._` — rather than printing nothing at all. The `Passes` row is suppressed on a 1-pass scan, so the assembler says it in a **Run files** row instead — `⚠️ No pass produced a run file. This scan reviewed nothing.` The runs directory stays; it holds the `scope.tsv` that says what was attempted.
- **A later pass produces nothing:** stop the loop and go straight to Turn 5. The report is assembled from the passes that finished and its `Passes` row says which one failed. Nothing is lost — the ledger was rebuilt after every pass. Grinding on to the next pass after the machinery has broken burns the runner's money.

**Turn 4 — Deduplicate, validate & record.** Runs **every pass**, and it is the end of the loop body: deduplicate this pass's agent results, gate-evaluate, tag, record the pass, write the ledger. **It prints no report** — there is exactly one report per scan and Turn 5 prints it. Do NOT print an intermediate dedup list.

**Steps 4 and 6 are SKIPPED entirely when memory is off.** Every other step runs at any pass count.

Follow `{resolved_path}/dedup-and-assembly.md`, section **"Turn 4"**, step by step.

Then, after the loop body has run `{passes}` times (or stopped early), go to Turn 5 once.

**Turn 5 — Assemble, print, clean.** Runs **once per scan**, at any pass count, including a 1-pass scan and including a loop that stopped early. There is no path where a scan ends without this turn.

**This turn holds no model judgment.** It copies two files, runs `assemble.sh`, counts with `awk`, and prints. `assemble.sh` is the only producer of a report in this skill: do not re-word its output, do not re-order it, do not add to it and do not summarise it in your own words. If this turn looks too thin to be a reporting step — that is the point, and `dedup-and-assembly.md` records why.

Follow `{resolved_path}/dedup-and-assembly.md`, section **"Turn 5"**, step by step. Its step 1 is SKIPPED when memory is off; its step 4 runs only when `--file-output` was passed.

## Banner

Before doing anything else, print this exactly:

```

██████╗  █████╗ ███████╗██╗  ██╗ ██████╗ ██╗   ██╗     ███████╗██╗  ██╗██╗██╗     ██╗     ███████╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██╔═══██╗██║   ██║     ██╔════╝██║ ██╔╝██║██║     ██║     ██╔════╝
██████╔╝███████║███████╗███████║██║   ██║██║   ██║     ███████╗█████╔╝ ██║██║     ██║     ███████╗
██╔═══╝ ██╔══██║╚════██║██╔══██║██║   ██║╚██╗ ██╔╝     ╚════██║██╔═██╗ ██║██║     ██║     ╚════██║
██║     ██║  ██║███████║██║  ██║╚██████╔╝ ╚████╔╝      ███████║██║  ██╗██║███████╗███████╗███████║
╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝       ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝

```

# PINNED dedup-and-assembly.md

# Dedup, record and assembly — Turn 4 and Turn 5

This file holds the two turns that run **after the 12 agents return**: Turn 4
deduplicates, gates, tags and records each pass, and Turn 5 assembles and prints
the one report. `SKILL.md` keeps the name of each turn and the condition that
decides whether it runs; the procedure is here.

The orchestrator reads this file **once, in Turn 3b**, while it waits for the
agents. It stays in context for the later passes of a loop.

Both turns use `{stamp}`, `{bundle_dir}`, `{passes}`, `{resolved_path}` and
`{project-name}` exactly as `SKILL.md` set them.

---

## Turn 4

**Turn 4 — Deduplicate, validate & record.** Runs **every pass**, and it is the end of the loop body: deduplicate this pass's agent results, gate-evaluate, tag, record the pass, write the ledger. **It prints no report** — there is exactly one report per scan and Turn 5 prints it. Do NOT print an intermediate dedup list.

> **This turn used to print the report and clean up, and both moved.** The report moved to Turn 5 so that a 1-pass scan and an N-pass scan take the **same** path through this turn — the "1 pass is byte-identical to today" constraint is easier to hold with one report writer than with a last pass that doubles as one. The auto-clean moved to Turn 5 because, left here, pass 1 deletes what pass 2 needs: `source.md`, the ledger photocopy and the accumulating rows file. A later editor must not move either back.

Then, after the loop body has run `{passes}` times (or stopped early), go to Turn 5 once.

1. **Dedup.** Parse every FINDING and LEAD from the 12 agents. Group by `group_key` (Contract | function | bug-class). Exact-match first; merge synonymous bug_class within same (Contract, function). Keep best per group, number sequentially, annotate `[agents: N]`.

   **MANDATORY — Canonicalise the bug-class label (HARD GATE).** Before grouping, for every (Contract, function) whose agents used **more than one** bug-class label, choose **one** label and rewrite every one of those findings to carry it. Then group.

   Choose in this order, and stop at the first that applies:
   1. A label already listed for that same contract and function in `{bundle_dir}/known-findings.md` — the repository's own word wins, always.
   2. Otherwise the label that most agents used.
   3. Otherwise the shortest label that names the **defect**, not its consequence. `zero-abort-address` over `abort-address-zero-burns-funds`.

   Merging under one label is only correct when the labels name the **same class of bug**. Two genuinely different bugs in one function keep two labels and stay two records — function isolation is about functions, and this rule is about words.

   **Why this is a gate and not a nicety.** The per-function vocabulary that keeps a key stable only constrains what an **earlier scan** wrote. A class discovered mid-scan is constrained by nothing, and a real scan proved what follows: three agents in one pass named one bug `zero-abort-address`, `unregistered-abort-address` and `abort-address-zero-burns-funds`, and the over-approval class drew three labels across three passes. Unfixed, that is three ledger records for one bug, three lines in every future `known-findings.md`, and one bug that is never recognised again. This step is the only thing standing between the fork and the ledger. Canonicalise here and the next pass inherits the canonical label, so the fork closes after one scan.

   **MANDATORY — Wide-description (group_key).** Merged group with distinct mechanisms (different `fix:`, code-level cause, or attack path) MUST list every mechanism. No dropping. Same function can have multiple coexisting bugs at the same group_key — all MUST appear.

   **MANDATORY — Function-level second pass (after group_key dedup).** Run at (Contract, function), ignoring bug_class. Agents often label coexisting bugs with different bug_class tags but reference multiple mechanisms in the body. For every (Contract, function) with multiple final findings: scan body (description, path, proof, fix) of every constituent for distinct mechanisms across bug_class boundaries. Every mechanism in any constituent body MUST appear in ≥1 final finding.

   **MANDATORY — Function isolation (HARD).** NEVER merge across different `function:` fields. Dedup only within (Contract, function). Different function = different bug. Second pass above stays WITHIN (Contract, function), never across.

   **MANDATORY — Fix preservation (HARD GATE).** Before writing merged `fix:` on a multi-finding (Contract, function):
   1. Collect every raw `fix:` from agents flagging the tuple.
   2. Group by ADD-lines (`+` lines, or equivalent require/assignment).
   3. Distinct if ADD-lines differ in: called function/expression (e.g., `require(msg.value == amount)` vs `require(zrc20 != _ETH_ADDRESS_)`), check direction (validate/restrict/ban), or checked parameter.
   4. ≥2 distinct → present as Option A, B, … — one block per distinct fix, verbatim from agent text (no paraphrase).
   5. Label intuitively: validate / restrict / allow-and-handle / ban-path.

   **Output format when 2+ distinct fixes exist:**

   ```
   **Fix (Option A — <label>)**:

   ```diff
   <verbatim diff from raw agent N1's fix>
   ```

   **Fix (Option B — <label>)**:

   ```diff
   <verbatim diff from raw agent N2's fix>
   ```
   ```

   **Inline check before printing**: count distinct fixes from raw for this (Contract, function). ≥2 distinct but merged shows 1 → violation, add alternatives.

   **MANDATORY — Completeness (HARD GATE).** Before print: list every unique (Contract, function, bug-class) in any raw FINDING/LEAD across the 12 agents. Every unique (Contract, function) MUST have ≥1 item in final. Zero = silent drop, fix it. Multiple bug-class within same (Contract, function) MAY collapse to one item (wide-description), but the (Contract, function) MUST survive. Print inline before report: `Completeness: N unique (Contract, function) in raw, N covered in final.`

   Composite chains: if A's output feeds B's precondition AND combined impact > either alone, add `Chain: [A] + [B]` at conf = min(A, B). Most audits: 0–2.

2. **Gate.** Run each deduped finding through the four gates in `judging.md` (no skip, no reorder, no revisit after verdict).

   **Single-pass:** every relevant code path ONCE in fixed order (constructor → setters → swap → mint → burn → liquidate). One-line verdict: `BLOCKS` / `ALLOWS` / `IRRELEVANT` / `UNCERTAIN`. `UNCERTAIN = ALLOWS`. Commit, no re-examination.

3. **Lead promotion / rejection.**
   - LEAD → FINDING (conf 75) if: full exploit chain in source, OR `[agents: 2+]` demoted (not rejected) same issue.
   - `[agents: 2+]` does NOT override a code path that interrupts attack before harm — demote to LEAD if execution uncertain.
   - No deployer-intent reasoning — what code allows, not how deployer might use it.

4. **Memory tag.** **SKIP this step entirely when memory is off.** It comes before the report, not after it, because the report prints what it decides. It is a **lookup, never a judgment** — no finding is re-argued here, and no verdict from the gate is revisited.

   a. **Build the key** for every gated FINDING and every gated LEAD — the three segments of Turn 4's `group_key`, each normalised **on its own** (lower case, every run of non-alphanumeric characters to one hyphen), then joined with `|`: `vault|withdraw|reentrancy`. Normalise the segments separately, never the joined string, or the separators become hyphens too.

   **The bug-class segment is where memory succeeds or fails.** Before writing a key, read the per-function vocabulary back from `{bundle_dir}/known-findings.md` — the same file the agents were given: *if this finding is one of the bug classes already listed for this same contract and function, write that exact label. Invent a new label only when none of them is the same class of bug.* This is the only judgment in the whole memory path, and it happens when the label is **written** — never at merge time. The keys built here are the keys step 6 writes; build them once.

   b. **Tag each finding and each lead.** Look its key up in the pre-scan key list:

   ```bash
   tail -n +2 {bundle_dir}/memory-before.tsv | cut -f1,3 | sort > {bundle_dir}/known-keys.tsv
   ```

   Key present → **KNOWN**, printed as `KNOWN (n scans)` where **n is column 2 plus one**. The scan that is printing has found it again, so the count the report shows is the count the ledger will hold when step 6 has written it — report and file say the same number. Key absent → **NEW**. Nothing else decides this tag.

   The lookup is against the **pre-scan photocopy**, in every pass of a loop. `KNOWN` means "an earlier **scan** recorded this"; a finding first raised by pass 1 of this scan is still `NEW` in pass 3, and how many passes saw it is what `seen in k/N runs` says. Tagging against the live ledger would make pass 2 call this scan's own work old news.

   c. **Write this run's keys** to `{bundle_dir}/run-keys.tsv`, one per line, from step 4a.

   The "Known from earlier scans" rows are **not** built here. They are report work, and a pass that built them could not know what a later pass is about to raise. They are built once, in Turn 5.

5. **Record the pass.** Do NOT print the report.

   a. **Write the run file** to `.solidity-auditor/runs/{stamp}/run-K.md`, where `K` is the pass number. **Every pass of every scan writes one**, at any pass count, `{passes}` of 1 included. This is the only place this pass's work is recorded, and Turn 5 assembles the report out of these files — a pass that writes no run file has produced nothing the report can print.

   One directory per scan, one file per run; `ls` is history in order. The git SHA goes **inside** the file, not in the directory name, so two scans of the same commit sit side by side instead of colliding. Nothing deletes these files, and `--file-output` does not govern them — they are memory, not reports.

   **The file, exactly:**

   ````markdown
   # Run K — solidity-auditor

   <!--RUN pass=K of=N stamp={stamp} sha=abc1234 agents=11/12-->

   Pass K of N · <date> · `abc1234` · 11/12 agents returned — the access-control agent died.

   ## Findings

   <finding blocks, kind=FINDING>

   ## Leads

   <finding blocks, kind=LEAD>
   ````

   The sentence is for the human; the `<!--RUN-->` marker is what shell reads. `agents=11/12` is where the `Passes` row gets its degradation text, so a lost agent is on disk and not only in a printed line that scrolls away — and the dead agent's **name** stays here, in the sentence, and never enters the Scope table.

   **These two headings and no others, in every run.** No `## New findings` in a later run — newness is already carried by the `NEW` / `KNOWN` tag and by `seen in k/N runs`, and a heading saying it again is a second source of truth that can disagree with the first. **No "verified clean", "checked" or "sound" section, under any name.** A path a pass did not raise is not a path a pass cleared, and a real scan invented such a section unasked. Nothing ever reads it back, and it is the same overstated-coverage defect this whole design exists to kill.

   **The finding block, exactly:**

   ````markdown
   <!--F key=contract|function|bug-class conf=95 kind=FINDING agents=8-->

   [95] **<Title>**

   `ContractName.functionName` · Confidence: 95

   **Description**
   <the vulnerable pattern and why it is exploitable, 1 short sentence>

   **Fix**

   ```diff
   - vulnerable line(s)
   + fixed line(s)
   ```

   <!--/F-->
   ````

   - **The markers bound the block.** `<!--F ` opens it, `<!--/F-->` closes it, each on its own line at the start of the line. **Never `---`**: today's separator also appears inside a unified diff (`--- a/Vault.sol`), so it cannot cut a block that now carries one. The HTML comment renders invisible, so the file still reads as human memory.
   - **`key`** — exactly the key step 4a built, unchanged. Never re-derived here. The same key the ledger stores, so the run file and `memory.tsv` agree by construction.
   - **`conf`** — an integer, on `kind=FINDING` blocks only. **A `kind=LEAD` block carries no `conf` attribute at all** — a lead is not scored, and writing `0` would sort it against real numbers.
   - **`kind`** — `FINDING` or `LEAD`.
   - **`agents`** — carried from `[agents: 8]`. Informational; nothing parses it.

   **Write the markers exactly as printed.** They are the only thing standing between a finding and a silent loss: the assembler counts open markers against close markers against readable blocks, and a disagreement becomes a visible `**Run files**` row in the report saying how many findings could not be read. The report may print **less** than the scan found; it may never claim to print **more**. A fudged marker costs a visible warning, not a hidden hole — but it still costs the finding.

   **Above and below the threshold, the block shape is identical.** A block whose `conf` is below 75 simply has no `**Fix**` section. The run file does **not** mark which side of the line a finding sits on; the assembler re-derives that from `conf`. One source of truth.

   **Write the Description and the diff Fix block here, in full.** This is the expensive per-finding writing, and it is paid **now**, in the pass that found the bug, while that pass still has context to spare. Turn 5 re-words nothing — it pastes these bytes into the report. An orchestrator drafting seventy findings at the end of a long scan is the failure this ordering exists to prevent.

   **The title and the Description are written in Simplified Technical English**, per `{resolved_path}/report-language.md`, which Turn 2 read. Because Turn 5 re-words nothing, this is the **only** step where the report's sentences can be made readable — there is no later cleanup pass and there must never be one. Four pieces of text obey that file: the title, the Description, the Lead description, and the Lead's code-smell list.

   Three things it does **not** reach, and a later editor must not extend it to them: the **diff** inside the Fix block, which is pasted verbatim from the agent, the **bug-class label** in the `key` attribute, which is a memory key and is chosen by step 1 and step 4a, and the **identifiers** on the location line, which are spelled as the source spells them. Softening a label to read better writes a second ledger record for one bug.

   Where the agent handed up a sentence that already meets the rules, keep the agent's words. Where it did not — a metaphor, an `-ing` clause, forty words, `catastrophic` — rewrite the sentence and keep the claim. Rewriting is about the wording only: the mechanism, the actor and the effect the agent proved are not up for revision here, and the gate has already run.

   **Then record the agent count**, once per pass, always, `12/12` included:

   ```bash
   printf '%s\t%s\n' pass_{K}_agents "11/12" >> .solidity-auditor/runs/{stamp}/scope.tsv
   ```

   Written only when a pass ran short, a missing key would mean two different things — a whole pass and a lost pass — and the assembler could not tell them apart.

   b. **Print one summary line**, only when `{passes}` is above 1, and nothing else — the last thing the pass does, after step 6 has written the ledger. It is the only thing the runner sees for minutes at a time, so it answers two questions: how far along, and is the loop still learning?

   ```
   Pass 2/3 — 17 findings (3 new) · 6 leads (2 new) · ledger 41 records
   ```

   - The counts are post-dedup and post-gate — the numbers `run-2.md` holds, not raw agent output.
   - **new** = the key was not in the ledger before this pass. A lookup, not a judgment.
   - `ledger N records` is the row count of `.solidity-auditor/memory.tsv` after step 6 has written it, so print this line after step 6.
   - The parentheses are printed **only when the ledger was non-empty when the scan started**. On a first-ever scan every key is new and they say nothing: `Pass 1/3 — 17 findings · 6 leads · ledger 17 records`.
   - When a pass lost an agent, the line gains a clause: `Pass 2/3 — 15 findings (2 new) · 6 leads (0 new) · ledger 39 records · 11/12 agents`.
   - When **both** new-counts are zero, the line ends with `· no new ground`. That is the loop's most informative outcome — the passes have converged — and it must not have to be inferred from two zeros:

   ```
   Pass 3/3 — 17 findings (0 new) · 6 leads (0 new) · ledger 41 records · no new ground
   ```

   Elapsed time is deliberately not printed: it needs a `date` call either side of every pass, and the runner's terminal already shows wall-clock.

   > **On a 1-pass scan this whole step prints nothing.** Step 5a still writes `run-1.md` — silently. `Pass 1/1 — …` is a progress line for a loop that is not running, and the plain path prints the bytes it printed before loop mode existed. Writing a file is not printing; the freeze covers printed output.

6. **Memory write.** **SKIP this step entirely when memory is off.** It is a step of Turn 4 and not a turn of its own because it can only be built from this turn's gated findings — the rows do not exist until the gate has run.

   a. **Build this run's rows** from the keys step 4 already built. One row per gated FINDING and per gated LEAD, four tab-separated columns:

   ```
   key	sha	title	kind
   ```

   - `key` — exactly the key step 4a built and step 4b tagged. Never rebuilt here: a key that differs between the tag and the row would report `NEW` and store a duplicate.
   - `sha` — `git rev-parse --short HEAD`. Not a git repo, or a repo with no commits: write `none` and carry on. The SHA is never part of the match, so a missing one costs nothing.
   - `title` — the finding title, tabs and newlines replaced by a single space, cut to 80 characters. Bars are safe: only the key is ever split on bars.
   - `kind` — `FINDING` or `LEAD`.

   Append the rows to the accumulating file, do not overwrite it:

   ```bash
   cat >> {bundle_dir}/scan-rows.tsv
   ```

   b. **Merge.** One `awk` pass over the photocopy and this scan's accumulated rows. `sort` + `join` is not used: `join` returns only matching rows, so keeping old-only and new-only rows would need three invocations and identical sort order across locales.

   ```bash
   awk -F'\t' -v OFS='\t' '
   FILENAME==ARGV[1] {
     if (FNR==1) next
     o_st[$1]=$2; o_sc[$1]=$3; o_sha[$1]=$4; o_ti[$1]=$5; o_ki[$1]=$6
     if (!($1 in o_seen)) { o_seen[$1]=1; oord[++on]=$1 }
     next
   }
   {
     if (!($1 in n_seen)) { n_seen[$1]=1; nord[++nn]=$1 }
     n_sha[$1]=$2; n_ti[$1]=$3; n_ki[$1]=$4
   }
   END {
     print "#solidity-auditor-memory v1", "key", "status", "scans", "sha", "title", "kind"
     for (i=1; i<=on; i++) {
       k = oord[i]
       if (k in n_seen) print k, "KNOWN", o_sc[k]+1, n_sha[k], n_ti[k], n_ki[k]
       else             print k, o_st[k], o_sc[k], o_sha[k], o_ti[k], o_ki[k]
     }
     for (i=1; i<=nn; i++) {
       k = nord[i]
       if (!(k in o_seen)) print k, "NEW", 1, n_sha[k], n_ti[k], n_ki[k]
     }
   }
   ' {bundle_dir}/memory-before.tsv {bundle_dir}/scan-rows.tsv > .solidity-auditor/memory.tsv.tmp
   ```

   The three cases, all visible in one command:

   | Case | Result |
   |---|---|
   | Old row re-found | `status` `KNOWN`, `scans` + 1, `sha` / `title` / `kind` taken from **this scan's** row |
   | Old row not re-found | carried over completely unchanged |
   | No old row | `status` `NEW`, `scans` 1 |

   Two rules the merge carries, and a later editor must not simplify away:

   - **`kind` is not part of the key.** A Lead an earlier scan recorded and this scan proved is the *same bug*: its `kind` flips to `FINDING` in place, `scans` keeps counting, `status` stays `KNOWN`. Demotion is the same rule running backwards and needs no special case. Putting `kind` in the key would remember one bug twice and list it twice.
   - **The merge is idempotent.** It always reads the pre-scan photocopy plus everything this scan has found so far, so `scans` rises by exactly 1 however many times it runs inside one scan. "Have I already counted this key?" is a question that cannot arise. Where one key appears more than once in `scan-rows.tsv`, the last row wins — which is what makes a Lead proven by a later pass land as `FINDING`.

   c. **Move it into place.**

   ```bash
   mv .solidity-auditor/memory.tsv.tmp .solidity-auditor/memory.tsv
   ```

   The temporary file sits beside the real one so the move stays on one disk. **The new file is always written before the old one is replaced** — an interrupted scan leaves one whole ledger, never half of one. Never write `memory.tsv` directly.

   `mkdir -p .solidity-auditor` before the first write. The user is expected to gitignore that directory; the ledger is not shared between machines or people.

   **Then write the other two `mem_` keys**, every pass, immediately after the move:

   ```bash
   printf '%s\t%s\n' mem_after "$(( $(wc -l < .solidity-auditor/memory.tsv) - 1 ))" \
     >> .solidity-auditor/runs/{stamp}/scope.tsv
   printf '%s\t%s\n' mem_sha "$(git rev-parse --short HEAD 2>/dev/null || echo none)" \
     >> .solidity-auditor/runs/{stamp}/scope.tsv
   ```

   Both are re-written on every pass and **last wins**, so the `Memory` row ends up describing the ledger as the scan left it, with no delete step and no "have I written this already?" flag. `mem_before` is not touched here — it was written once, in Turn 2 step 2c, and the row's arithmetic depends on it staying put.

   d. **In a loop, this step runs after every pass, and it rebuilds rather than appends.** Pass K+1 learns what pass K found by reading the merged ledger, so the write cannot wait for the end. But re-running the merge N times must not raise `scans` by N, because `scans` counts scans. The command above already holds this: it always reads the **pre-scan photocopy** plus **everything this scan has accumulated so far**, so `scans` rises by exactly 1 however many passes ran. Nothing new is invented per pass, and no "have I counted this key already?" flag exists to get wrong. It also keeps the interrupt rule for the whole loop: a loop killed at pass 3 keeps what passes 1 and 2 learned, written atomically.

   Then the next pass starts at **Turn 2 step 2c**, which rebuilds `known-findings.md` from the freshly merged `.solidity-auditor/memory.tsv` — not from the photocopy, or pass K+1 would never see pass K's findings — and re-cats the twelve bundles at Turn 2 step 3.

## Turn 5

**Turn 5 — Assemble, print, clean.** Runs **once per scan**, at any pass count, including a 1-pass scan and including a loop that stopped early. There is no path where a scan ends without this turn.

> **This turn no longer composes a report, and must never be re-taught to.** It used to combine the runs, dedup them, build the "Known from earlier scans" rows and format the whole thing — all of it model work, all of it at the moment of least remaining context. On a real 3-pass scan that produced 71 findings, it printed 14 of them in full, collapsed the rest into two lines, and **claimed a coverage it did not have**. Nothing was lost from disk; the report lied about what it was showing. A prose instruction cannot fix that, because the orchestrator under context pressure is the thing that failed.
>
> So the step that must not lose a finding holds **no model judgment**. The dedup, the `seen in k/N runs` counts, the strongest-kind rule, the "Known from earlier scans" rows and the whole report body are `assemble.sh`'s work now, and it is shell. This turn copies two files, runs it, counts, and prints. If you are reading this turn and it looks too thin to be a reporting step — that is the point.

1. **Copy the memory inputs in.** **SKIP when memory is off.** The assembler reads one directory, so anything it needs that lives in `{bundle_dir}` has to be in the runs directory before it runs:

   ```bash
   cp {bundle_dir}/memory-before.tsv {bundle_dir}/source-names.tsv .solidity-auditor/runs/{stamp}/
   ```

   `memory-before.tsv` is the **pruned** photocopy — the "Known from earlier scans" section is built from it, so a record the prune dropped must not reappear here. `source-names.tsv` turns a normalised key back into the spelling the source uses, so no reader is ever shown `gatewaytransfernative.withdrawtonativechain`.

   Only these two. `run-keys.tsv` and `scan-rows.tsv` are **not** copied: the keys this scan raised come from the assembler's own index of the run files, which is the same data with no copy step.

2. **Assemble the report.**

   ```bash
   bash {resolved_path}/assemble.sh --dir .solidity-auditor/runs/{stamp}
   ```

   It writes `.solidity-auditor/runs/{stamp}/full-report.md` — the whole report, banner line down to the disclaimer, ready to print word for word. It writes to a `.part` file and moves it into place, so a half-report never exists.

   **This is the only producer of a report in this skill.** Do not re-word its output, do not re-order it, do not add to it and do not summarise it in your own words. Do not re-read source to "verify the most critical claim" either — the agents did that and the gate filtered it; re-verification costs about five minutes and rarely changes a verdict.

   If it exits non-zero, print its stderr and stop. It has told you it could not read its own inputs, and there is nothing for a model to salvage by hand.

3. **Count the findings, then branch.** One `awk` over the assembled file, no model arithmetic anywhere:

   ```bash
   awk '
   /^## Leads$/  { sec="leads"; next }
   /^## /        { sec="";      next }
   /^\[[0-9]+\]/ { F++; next }
   sec=="leads" && /^- \*\*/ { L++ }
   /Confidence: [0-9]+/ && /^`/ {
     match($0, /Confidence: [0-9]+/)
     c = substr($0, RSTART+12, RLENGTH-12) + 0
     if (c >= 90) A++; else if (c >= 75) B++; else C++
   }
   END { printf "%d %d %d %d %d\n", F, L, A, B, C }
   ' .solidity-auditor/runs/{stamp}/full-report.md
   ```

   `F` is findings, `L` leads, and `A` / `B` / `C` the confidence buckets `100-90`, `89-75` and `below 75`.

   **Only `F` is printed** — it is the trigger and it is the total in `top 3 of {F}`. `L`, `A`, `B` and `C` are computed anyway and kept as a **self-check**, not as output.

   > **`A + B + C` must equal `F`.** The buckets are the whole set, in every mode. If they do not sum, the assembled file is malformed — a finding block the counter could not read is a finding block a reader may not get either. Say so and print the full report rather than a three-row slice of a file you cannot stand behind.

   **The trigger is more than 20 findings** — `F` alone. Leads are excluded, so a scan with 18 findings and 40 leads still prints in full.

   a. **`F` is 20 or fewer — print `full-report.md` word for word.** Every byte, nothing added, nothing cut, no preface. This is the path a plain scan of a small contract takes, and its printed bytes are exactly what this skill printed before any of this existed.

   b. **`F` is above 20 — print this instead**, and nothing else:

   ````markdown
   # 🔐 Security Review — {project-name}

   ---

   ## Scope

   {the Scope table from full-report.md, copied unchanged}

   ---

   Findings List — top 3 of {F}

   | # | Confidence | Title | Location | Seen |
   |---|---|---|---|---|
   {the three rows the extractor below printed}

   **→ Full findings list, every description and every fix:** {path}

   ---

   > ⚠️ {the disclaimer line from full-report.md, copied unchanged}
   ````

   - **`{path}`** — `.solidity-auditor/runs/{stamp}/full-report.md`, or, when `--file-output` was passed, the **copy** and only the copy: `{project-name}-pashov-ai-audit-report-{stamp}.md`. Never both. Two paths to identical bytes answers a question the runner did not ask at the moment they want one filename. This line is the only part of the block a flag changes.
   - **The Scope table's `Files reviewed` row is copied unchanged**, full paths and all. It is the one row that proves *which* `SafeMath.sol` was read, and a terminal that shortens it can no longer be diffed against the file it claims to summarise.
   - **No counts summary.** The `{F} findings, {L} leads` line and the `100-90 / 89-75 / below 75` split are **not** printed. `top 3 of {F}` already carries the only total a reader needs at this moment, and the bucket split answered a question nobody asked while standing between them and the path.

   > **The `{F}` in `top 3 of {F}` is what makes the slice safe, and it is not optional.** The rule this block obeys is that a report may print **less** than the scan found and may never look like it printed **more**. A bare list of three findings breaks that rule — a reader cannot tell a truncated list from a complete one. `top 3 of 52` cannot be misread, and it sits in the header rather than in a footnote for exactly that reason. An editor who drops the total, or moves it below the table, has re-created the failure this sentence exists to prevent.
   >
   > **This replaces the older "nothing is enumerated above the trigger" rule.** That rule was right about bare truncation and wrong to conclude that no slice can ever be honest; a counted slice is. Still enumerated **nowhere**: the Leads section, the "Known from earlier scans" section, and findings 4 and beyond. Three rows, and the header says three.

   **The three rows are extracted by shell, never typed from memory.** The orchestrator has by this point read dozens of findings and is the least reliable thing in the room; one `awk` over the assembled file cannot mis-rank, mis-quote a function name or invent a confidence. Pass `-v withseen=1` when the `Passes` row is printed — that is, when `{passes}` is above 1 — and `0` otherwise, because a plain scan's location line carries no `seen in k/N runs` and an empty column would print as a stub:

   ```bash
   awk -v withseen={1 or 0} '
   /^\[[0-9]+\] \*\*/ {
     if (n >= 3) exit
     line = $0
     match(line, /^\[[0-9]+\]/); conf = substr(line, RSTART+1, RLENGTH-2)
     sub(/^\[[0-9]+\] \*\*[0-9]+\. /, "", line); sub(/\*\*[ \t]*$/, "", line)
     title = line; want = 1; next
   }
   want && /^`/ {
     loc = $0
     match(loc, /^`[^`]*`/); fn = substr(loc, RSTART+1, RLENGTH-2)
     n++
     if (withseen) {
       seen = ""
       if (match(loc, /seen in [0-9]+\/[0-9]+ runs/)) seen = substr(loc, RSTART+8, RLENGTH-13)
       printf "| %d | [%s] | %s | `%s` | %s |\n", n, conf, title, fn, seen
     } else printf "| %d | [%s] | %s | `%s` |\n", n, conf, title, fn
     want = 0
   }
   ' .solidity-auditor/runs/{stamp}/full-report.md
   ```

   With `withseen=0` the awk prints four columns, so **drop `Seen` from the header row and from the separator row too** — a five-column header over four-column rows renders as a broken table in every terminal that draws one.

   The assembled file is already sorted highest-confidence first, so "top 3" is the first three finding blocks and no sort happens here. `exit` after the third block means the extractor does not read the rest of the file.

   **Fewer than 3 findings cannot reach this branch** — `F` is above 20 or this block is not printed — so the extractor needs no short-list case.

4. **`--file-output` — copy the assembled file.** Only when the flag was passed:

   ```bash
   cp .solidity-auditor/runs/{stamp}/full-report.md "{project-name}-pashov-ai-audit-report-{stamp}.md"
   ```

   A copy, not a second build. **Nothing regenerates**, so the flag cannot collapse the report the way the terminal once did — the file and the terminal are the same bytes by construction, whatever the finding count. The run files stay in `.solidity-auditor/runs/` and are never copied into the working directory.

5. **Auto-clean.** `rm -rf {bundle_dir}`. Bundle dir = transient build state, not an artifact. Don't skip. It runs once per scan, at any pass count, and it runs when the loop stopped early too. For debugging a loop: copy the bundle elsewhere before re-running.

   > **It runs last, and the order is load-bearing.** Step 1 copies two files **out of** `{bundle_dir}`, and step 2 reads them. Deleting the bundle before either has run destroys the "Known from earlier scans" section and the name map that keeps it readable — silently, because the assembler treats a missing input as an absent section and carries on. Steps 1 → 2 → 5 is not a style preference; moving this step earlier breaks a report that will still look finished.

   Do **not** add a per-pass partial clean — reclaiming disk between passes would mean rebuilding `source.md`, the one thing built once. Do **not** add a startup sweep of stale `.audit-*` directories: a crashed scan leaks one, as it does today, and a sweep would delete the working directory of a second scan running at the same time on the same repo.


# PINNED judging.md

# Finding Validation

Every finding passes four sequential gates. Fail any gate → **rejected** or **demoted** to lead. Later gates are not evaluated for failed findings.

You are not defending the code. The job of these gates is to verify the attacker's claimed exploit actually fires end-to-end — anything that interrupts the attack between the attacker's call and the harm means the agent's claim does not execute, and only then does it fail to qualify as a finding.

## Gate 1 — Attack execution

Trace the agent's claimed attack path from caller to harm. Read every guard, check, modifier, and constraint that sits on that path. Confirm that none of them interrupts the attack before the exploit step fires.
- A specific guard / check / modifier on the attack path interrupts the claimed exploit step before harm occurs (quote the exact line and trace it) → **REJECTED** (or **DEMOTE** if a related code smell remains)
- The supposed interruption is speculative ("probably wouldn't happen", "the caller would notice", "the deployer would set X") → **clears**, continue

## Gate 2 — Reachability

Prove the vulnerable state exists in a live deployment.

- Structurally impossible (enforced invariant prevents it) → **REJECTED**
- Requires privileged actions outside normal operation → **DEMOTE**
- Achievable through normal usage or common token behaviors → **clears**, continue

## Gate 3 — Trigger

Prove an unprivileged actor executes the attack.

- Only trusted roles can trigger → **DEMOTE**
- Unprivileged actor triggers profitably → **clears**, continue

**Admin-action findings — reject unless an unprivileged amplifier is named.** This applies ONLY to actions performed by admin/owner, NOT to unprivileged attacker actions. If the harm requires the admin acting maliciously or against documented intent, **REJECT** — do not even emit as a LEAD (stricter than the DEMOTE above). The finding clears only when the body names a concrete unprivileged amplifier:

- **race** — admin sets X mid-flow; an unprivileged user exploits the window before the update propagates.
- **retroactive sweep** — an admin update rewrites a pending value already credited.
- **asymmetric formula** — admin output chains into a formula an unprivileged actor profits from.
- **access gap** — missing guard, tautological auth, or missing init guard (the access mechanism itself is the bug).

No amplifier named → **REJECTED**. Amplifier named → judge it on that unprivileged path.

## Gate 4 — Impact

Prove material harm to an identifiable victim.

- Self-harm only → **REJECTED**
- Dust-level, no compounding → **DEMOTE**
- Material loss to identifiable victim → **CONFIRMED**

## Confidence

Start at **100**, deduct: partial attack path **-20**, bounded non-compounding impact **-15**, requires specific (but achievable) state **-10**. Confidence ≥ 75 gets description + fix. Below 75 gets description only.

**The threshold is 75, and it is set here.** `report-formatting.md` reads it from this line and states it nowhere else. It is 75 and not 80 because the three lead-promotion rules below all land a promoted lead at exactly 75: at a threshold of 80 every cross-contract echo, every multi-agent convergence and every completed partial path would be promoted to a finding and then printed with no **Fix** block. Moving this number means moving those three, or the promotions stop being worth making.

## Safe patterns (do not flag)

- `unchecked` in 0.8+ (but verify the reasoning is correct)
- Explicit narrowing casts in 0.8+ (reverts on overflow)
- MINIMUM_LIQUIDITY burn on first deposit
- SafeERC20 (`safeTransfer`/`safeTransferFrom`)
- `nonReentrant` (only flag cross-contract attacks)
- Two-step admin transfer
- Consistent protocol-favoring rounding unless compounding or zero-rounding

## Lead promotion

Before finalizing leads, promote where warranted:

- **Cross-contract echo.** Same root cause confirmed as FINDING in one contract → promote in every contract where the identical pattern appears.
- **Multi-agent convergence.** 2+ agents flagged same area, lead was demoted (not rejected) → promote to FINDING at confidence 75.
- **Partial-path completion.** Only weakness is incomplete trace but path is reachable and unguarded → promote to FINDING at confidence 75, **description only — a deliberate exception to the threshold**. 75 clears the line, so this finding would otherwise carry a **Fix** block; it does not, because the trace it would fix was never completed. The other two promotions above take their **Fix** block normally.

## Leads

High-signal trails for manual investigation. No confidence score, no fix — title, code smells, and what remains unverified.

## Do Not Report

Linter/compiler issues, gas micro-opts, naming, NatSpec. Admin privileges by design. Missing events. Centralization without exploit path. Implausible preconditions (but fee-on-transfer, rebasing, blacklisting ARE plausible for contracts accepting arbitrary tokens).

# PINNED report-formatting.md

# Report Formatting

## The one rule

**A report must not overstate its own coverage.** Every other rule in this file serves that
one. The report may print **less** than the scan found — a mistyped marker, a dead agent, a
pass that never ran — and when it does it says so in words. It may never claim to print
**more**. A report that shows 14 findings and reads as if it showed all of them is the defect
this whole design exists to kill.

## Who reads this file

Nothing composes a report from this template any more. There are two readers:

- **SKILL.md Turn 4 step 5a** — the pass writing its findings into `run-K.md`. It uses the
  **finding block** shape below: title line, location line, `**Description**`, diff `**Fix**`
  block. Those bytes are pasted straight through into the report, so they are written in the
  report's own shape while the pass still has context to spare.
- **`references/assemble.sh`** — the assembler. Everything below the finding block — the
  banner, the Scope table, the ordering, the Findings List, the Leads section, "Known from
  earlier scans", the disclaimer — is what the assembler emits.

**This file settles the shape. `report-language.md` settles the words.** Every sentence a
human reads in the report — the finding title, the Description, the Lead description, the
Lead's code smells — is written in Simplified Technical English, and that file holds the rules.
It is read by the same Turn 4 step 5a that writes the block, and it is in all twelve agent
bundles. It never reaches the diff in a **Fix** block, the bug-class label inside a key, or an
identifier on a location line: those three are data, and it says so.

**The template is the contract the assembler emits, not a shape a model imitates.** A later
editor must not re-teach the orchestrator to write it. The orchestrator under context pressure
is the thing that failed; the step that must not lose a finding holds no model judgment.

## Report Path

**Every scan assembles `.solidity-auditor/runs/{stamp}/full-report.md`** — the whole report,
banner line down to the disclaimer — at any pass count, with or without flags. That file is
the report. There is exactly one producer of it, and it is the assembler.

`--file-output` makes a **copy** of that file into the current working directory as
`{project-name}-pashov-ai-audit-report-{stamp}.md`, where `{project-name}` is the repo root
basename and `{stamp}` is `YYYYMMDD-HHMMSS` at scan time. A copy, not a second build —
nothing regenerates, so the flag cannot collapse the report the way the terminal once did. The
flag never causes a report to be produced; it only decides whether a copy lands where the
runner can see it.

The `run-K.md` files stay in `.solidity-auditor/runs/{stamp}/` under the same stamp, so a
report and the runs that produced it are tied together by eye. They are never copied into the
working directory — they are memory, not reports.

## Output Format

This is what the assembler emits.

````
# 🔐 Security Review — <ContractName or repo name>

---

## Scope

|  |  |
| --- | --- |
| **Mode** | ALL / default / filename                              |
| **Files reviewed** | `File1.sol` · `File2.sol`<br>`File3.sol` · `File4.sol` | <!-- every file, 3 per line -->
| **Confidence threshold (1-100)** | N                                    |
| **Passes** | 3                                                      | <!-- only when passes > 1 -->
| **Memory** | 12 records before this scan · 14 after · `a1b2c3d`     | <!-- only when memory is on -->
| **Run files** | ⚠️ 2 findings marked, 1 readable. 1 could not be read. | <!-- only when the structure check disagrees -->

---

## Findings

[95] **1. <Title>**

`ContractName.functionName` · Confidence: 95 · seen in 2/3 runs · KNOWN (4 scans) <!-- runs segment only when passes > 1; memory segment only when memory is on -->

**Description**
<The vulnerable code pattern and why it is exploitable, in 1 short sentence>

**Fix**

```diff
- vulnerable line(s)
+ fixed line(s)
```

---

[82] **2. <Title>**

`ContractName.functionName` · Confidence: 82

**Description**
<The vulnerable code pattern and why it is exploitable, in 1 short sentence>

**Fix**

```diff
- vulnerable line(s)
+ fixed line(s)
```

---

< ... all above-threshold findings >

---

[60] **3. <Title>**

`ContractName.functionName` · Confidence: 60

**Description**
<The vulnerable code pattern and why it is exploitable, in 1 short sentence>

---

< ... all below-threshold findings (description only, no Fix block) >

---

Findings List

| # | Confidence | Title |
|---|---|---|
| 1 | [95] | <title> |
| 2 | [82] | <title> |
| 3 | [75] | <title> |
| | | **Below Confidence Threshold** |
| 4 | [60] | <title> |

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **<Title>** — `Contract.function` · NEW — Code smells: <missing guard, unsafe arithmetic, etc.> — <1-2 sentence description of the trail and what remains unverified> <!-- memory segment only when memory is on -->
- **<Title>** — `Contract.function` · seen in 2/3 runs · KNOWN (2 scans) — Code smells: <...> — <1-2 sentence description> <!-- runs segment only when passes > 1 -->

---

## Known from earlier scans

<!-- only when memory is on AND the ledger held at least one record — see Memory in the report -->

_Recorded by earlier scans of this repo, not raised again by this one. Not re-checked — a record here may be fixed, or may still be live and missed. `.solidity-auditor/memory.tsv`._

| Scans | Kind | Location | Title |
|---|---|---|---|
| 4 | FINDING | `Router.swap` | Swap trusts a spot price as an oracle |
| 2 | LEAD | `Vault.sweep` | Sweep lets the owner take user deposits |

---

> ⚠️ This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)

````

**Rules describing the output**, all of them held by the assembler and none of them addressed
to a model:

- Findings are sorted by confidence, highest first.
- A finding at or above the threshold carries a **Description** and a diff **Fix** block. One
  below carries the **Description** only. Nothing in the run file marks which side of the line
  a finding sits on — it is re-derived from the confidence, so there is one source of truth.
- The **Below Confidence Threshold** separator row is printed whenever at least one finding
  falls below the threshold, and left out when none does. Without it the table runs 1, 2, 3
  with nothing to mark the boundary, so a reader of the table alone cannot tell which findings
  carry no **Fix** block.
- **Empty cases say so in words, never with an empty table**: `_None — this scan raised no
  findings._` in place of the Findings List, `_None._` under Leads, `**Body missing** — pass K
  raised this finding and wrote no description.` in place of a body.
- **A `Run files` row appears only when the structure check disagrees.** The model types the
  markers that bound each finding in a run file, so it can mistype one. The assembler counts
  open markers against close markers against readable blocks, and prints the disagreement as a
  Scope row naming how many findings could not be read. Everything readable is still printed
  and the assembler never stops. That row is the one rule at the top made mechanical.
- **The Scope table's column padding is not part of the shape.** Markdown renders
  `| **Mode** | default |` and a space-padded form identically, and the padding above is for
  reading this file. Content and order are the contract; character widths are not.

**The threshold is 75**, set in `judging.md` and printed in the Scope row above. It is named
in `judging.md` and nowhere else; this file reads it from there. A finding at 75 or above gets
a description and a **Fix** block, one below 75 gets the description only. A promoted lead
lands at exactly 75, so it clears — that is why the number is 75.

## The size trigger

**More than 20 findings.** At 20 the terminal prints the assembled file word for word; at 21
it stops printing findings. Findings only — above and below the threshold together. **Leads
are excluded from the trigger count**, so a scan with 18 findings and 40 leads prints in full.

The trigger is on **size, not on flags**. A plain scan of a small contract is unchanged; a
plain scan of a big one gets the new shape.

**Above the trigger the terminal prints four things:** the banner, the Scope table unchanged,
a **Findings List holding the top 3 findings**, and the path to the full report — then the
disclaimer. About fifteen lines.

The full report is unaffected. Above the trigger, as below it, `full-report.md` holds every
finding in the shape above — only the terminal changes.

**The slice is honest because it is counted.** The table's header reads
`Findings List — top 3 of {F}`, and that `{F}` is the whole rule:

- **A report may print less than the scan found. It may never look like it printed more.**
  A bare list of three findings breaks that — a reader cannot tell a truncated list from a
  complete one. `top 3 of 52` cannot be misread.
- **The total goes in the header, not a footnote.** A reader who sees the table sees the
  total in the same glance. This is not a style choice; a footnote can be scrolled past.
- **Three rows, and nothing else is enumerated.** No Leads, no "Known from earlier scans",
  no findings past the third.

> **This replaces the older "nothing is enumerated above the trigger" rule**, which forbade
> every top-N slice. That rule was right that bare truncation lies and wrong to conclude no
> slice can be honest; a counted one is. A later editor must not restore the blanket ban by
> citing the half of the argument that survived.

**The rows are extracted by shell, never typed.** One `awk` over the assembled file — which is
already sorted highest-confidence first, so no sort happens in the terminal step. The
orchestrator has read dozens of findings by then and is the least reliable thing in the room;
the extractor cannot mis-rank, mis-quote a function name or invent a confidence. The command
is in `dedup-and-assembly.md` Turn 5 step 3b.

**The `Seen` column appears only when the `Passes` row does** — that is, when the pass count is
above 1. A plain scan's location line carries no `seen in k/N runs`, so the column is dropped
from the header, the separator and the rows together. A five-column header over four-column
rows draws as a broken table.

**There is no counts summary.** The `{F} findings, {L} leads` line and the
`100-90 / 89-75 / below 75` split are not printed. `top 3 of {F}` carries the only total the
moment needs, and the bucket split stood between the reader and the path. The buckets are still
**computed** as a self-check — `A + B + C` must equal `F`, in every mode, or the assembled file
is malformed and the scan says so instead of printing a slice of it.

The path line names `.solidity-auditor/runs/{stamp}/full-report.md`, or — when `--file-output`
was passed — the **copy** and only the copy. Never both: two paths to identical bytes answer a
question the runner did not ask at the moment they want one filename. That line is the only
part of the block a flag changes.

The exact wording, spacing and order of the block are in `dedup-and-assembly.md` Turn 5 step
3b, which is where the terminal is printed.

## The freeze

**A small scan with no flags prints what it printed before any of this existed.** Below the
trigger the terminal prints `full-report.md` word for word — every byte, nothing added,
nothing cut, no preface — so the freeze is a property of the assembled file.

The freeze is a **diff against `golden/plain-full-report.md`**, the frozen plain-path report,
and it covers the report's **content and order, not its column padding** and not what lands on
disk. Byte-identity against "today" was tried and is unmeetable: no captured report exists
anywhere, and today's bytes were composed by a model from a template that contradicted itself.
The golden file is what replaced it.

What the freeze does **not** cover: writing files. Every scan now writes a runs directory and
assembles a report there, at any pass count. Writing a file is not printing, and the freeze is
on printed output.

## Memory in the report

Everything in this section is printed **only when memory is on** (`--memory`, or a pass count
above 1). With memory off the assembled file carries no extra rows, no extra segments, no
extra sections and no dangling `·`, and below the trigger it still diffs clean against the
golden file.

**Segment order on the meta line.** One dot-separated chain, in a fixed order:

```
`ContractName.functionName` · Confidence: 95 · seen in 2/3 runs · KNOWN (4 scans)
```

location · confidence · runs · memory. **A segment appears only when it carries information** —
`seen in k/N runs` needs more than one run, `KNOWN (n scans)` / `NEW` needs memory on. So:

| Scan | Meta line |
|---|---|
| 1 pass, no flags | `` `Vault.withdraw` · Confidence: 95 `` |
| 1 pass, `--memory` | `` … · Confidence: 95 · KNOWN (4 scans) `` |
| 3 passes | `` … · Confidence: 95 · seen in 2/3 runs · KNOWN (4 scans) `` |

`KNOWN (4 scans)` and `NEW` are the ledger's own two words, so the report and the file say the
same thing. **`n` counts this scan.** The tag is derived by the assembler from
`memory-before.tsv` — the pre-scan photocopy — and `n` is that row's `scans` **plus one**: the
scan that is printing has just found it again, and the ledger already holds that same number.
Printing the stored count instead would show a report one behind its own ledger. `NEW` carries
no count. The tag is **not** carried in the run-file marker: one source, so the report and the
ledger cannot disagree.

The `Scans` column of "Known from earlier scans" is the opposite case and is printed **as
stored**: this scan did not raise those records, so nothing about them counts up. The
**Findings List** table is unchanged — it stays `# | Confidence | Title`.

Leads carry the same segments as findings, on their own line, because a Lead is a full ledger
record.

**The `Memory` row in Scope.** `<records in the ledger before this scan> records before this
scan · <records after the merge> after · `<sha>``. The SHA is the one every row of this scan
wrote; `none` when the repo has no commits. The row states the whole ledger state in one line,
so the two counts show at a glance what the scan added.

**The "before" count is the count after the prune** — the row count of `memory-before.tsv` as
the merge reads it, not the row count of the file the scan opened. On a scan where the prune
drops records the two differ, and using the pre-prune number makes the row's own arithmetic
wrong: a scan that opened 4 records, pruned 1 and added 12 would read `4 records before this
scan · 15 after`, and a reader counting 4 + 12 gets 16. The prune is already reported on its
own line (`Pruned N records …`), so the Scope row does not restate it and must not contradict
it.

**Building "Known from earlier scans".** These are the records the ledger already held that
this scan did **not** raise again. It is **not** a filter on the `status` column — `status`
stays `KNOWN` once set and never marks the not-found-again case.

**The `comm` block that used to sit here is now in `assemble.sh`**, under
`# Known from earlier scans`. It reads two inputs Turn 5 copies into the runs directory:
`memory-before.tsv`, the pruned photocopy, and `source-names.tsv`. The keys this scan raised
come from the assembler's own index of the run files, so no `run-keys.tsv` or `scan-rows.tsv`
is carried in — the run files are the record. It is computed once per scan, scoped to the
whole scan and not to the last run, so a bug found in run 1 but not in run 3 does not appear
here.

Each key `comm` returns is one row: `Scans`, `Kind` and `Title` come straight from its row in
`memory-before.tsv`. `Location` is rebuilt from the key's first two segments, which are stored
normalised (lower case, hyphenated) and cannot be printed as they are — each segment is looked
up in `source-names.tsv` and printed as the source spells it, or printed as stored when it is
not in the map, which happens on a named-file scan where the contract was never assembled into
`source.md`.

Three states, and no fourth:

- The ledger held records this scan did not raise → the table above.
- The ledger held records and this scan raised **every one** → `_None — every record in the
  ledger was raised again by this scan._`
- Memory is off, or the ledger is empty (first-ever scan) → **no section at all.** A plain
  scan grows no empty headings.

The italic line under the heading is load-bearing and is printed verbatim: these records are
**not re-checked**. A reader must not take the section as "still open", and must not take it
as "fixed".

## Loop mode in the report

Everything in this section is printed **only when the pass count is above 1**. One pass prints
none of it.

**One report per scan.** However many passes ran, the runner sees one combined list. The
per-pass output is one summary line each (SKILL.md Turn 4 step 5b) and one `run-K.md` in
`.solidity-auditor/runs/{stamp}/` — neither is a report.

**`seen in k/N runs`.** `k` is how many of this scan's runs raised that group key; `N` is how
many passes produced a run file. A pass that collapsed produced none, so it is not in `N` — a
report must not claim a run that never happened. The segment sits between confidence and the
memory tag, and it is printed on Leads exactly as it is on findings, because a Lead is a full
ledger record.

**`seen in k/N runs` and `KNOWN (n scans)` count different things and must never be mixed.**
`k/N` counts runs inside **this** scan and is never written to the ledger. `n` counts scans and
comes from the ledger. A finding first raised by pass 1 of this scan is `NEW` in pass 3 — it is
this scan's work, however many of its runs saw it.

**Which write-up survives the merge.** One winner per key: strongest kind, then highest
confidence, then the later pass — a later pass read the ledger every earlier pass wrote, so it
is the better-informed write-up. **Confidence is untouched by the merge.** A finding three runs
saw keeps the number the runs gave it; repetition is reported on the line, never scored, and
`seen in 3/3 runs` is there for the reader to weigh.

**The `Passes` row in Scope** is composed by the assembler from recorded facts, never written
as prose. It carries degradation text whenever the scan did not run whole — a report claiming
3 passes when one of them ran three-quarters of its agents overstates its own coverage:

```
| **Passes** | 3                                                    |
| **Passes** | 3 (pass 2 ran 11/12 agents)                          |
| **Passes** | 2 of 3 (pass 3 failed)                               |
| **Passes** | 2 of 3 (pass 1 ran 11/12 agents, pass 3 failed)      |
```

The `R of P` prefix comes from counting run files. The dead agent's **name** never appears
here — it stays in the run file, in the sentence under the `<!--RUN-->` marker.

On a 1-pass scan this row is suppressed, so a pass 1 that produced nothing is reported by the
`Run files` row instead: `⚠️ No pass produced a run file. This scan reviewed nothing.`

# PINNED report-language.md

# Report language — Simplified Technical English

Every sentence a human reads in the report obeys this file. The rules are ASD-STE100
(Simplified Technical English), reduced to the part an audit finding needs.

## Why

A report is read by the developer who must fix the code, often at speed, often not in their
first language. A sentence they must decode twice costs the fix, and the bug stays in the
code. The scan is only as good as the sentence that delivers it.

Short words do not make a finding less rigorous. The proof is the diff in the **Fix** block
and the location on the meta line. The sentence exists to say what breaks and who breaks it.

## What this covers

Four pieces of text, and no others:

- the finding **title**
- the **Description** sentence
- the **Lead** description
- the **code smells** list on a Lead

## What it must never touch

These are data, not prose. Rewriting one of them for readability breaks the scan:

- **Solidity identifiers** — contract, function, variable and event names. They are printed as
  the source spells them. `withdrawToNativeChain` is never softened to `withdraw to chain`.
- **The diff inside a Fix block.** It is code. It is pasted verbatim from the agent that wrote
  it, and `judging.md` and `dedup-and-assembly.md` both forbid paraphrase there.
- **The bug-class label** (`zero-abort-address`). It is the third segment of a memory key.
  The same bug under a plainer word is a second ledger record, so memory remembers it twice
  and recognises it never. Labels are chosen by the rules in `dedup-and-assembly.md` step 1,
  never by this file.
- **Fixed strings the assembler prints** — the banner, the Scope table headers, the italic
  lines under Leads and "Known from earlier scans", the disclaimer. They are in
  `assemble.sh` and they are already written.

## The rules

1. **One sentence, one idea.** A Description is one sentence. A Lead description is one or
   two. Never three.
2. **Twenty-five words is the ceiling.** Count them. Over the ceiling means two ideas in one
   sentence — cut it or split it.
3. **Active voice, and name the actor.** Who does this? Write that word first.
   - No: `Funds can be drained due to a missing check.`
   - Yes: `Any caller can take all the tokens, because the function checks no caller.`
4. **Simple present tense.** The code does this today. Not `would be able to`, not
   `could potentially`. If the path is uncertain it is a Lead, and the Lead says which step
   is unproven.
5. **No `-ing` clauses.** They hide the actor and the order of events. Use `that`, `so`, or a
   second sentence.
   - No: `Missing access control allowing anyone to drain the vault.`
   - Yes: `The function has no access control, so any caller can take all the tokens.`
6. **Keep the articles.** `the`, `a`, `an`. Telegraphic style — `Function reverts on zero
   amount` — is not shorter to read, only shorter to type.
7. **Three nouns in a row is the limit.** Break a longer stack with `of`, `for` or `in`.
   - No: `cross-chain message replay protection gap`
   - Yes: `the contract does not stop a replay of a cross-chain message`
8. **One word for one thing, every time.** Pick `token`, or pick `asset`, and use that word
   in the title, the Description and the fix. A synonym reads as a second thing.
9. **No metaphor, no idiom, no slang.** See the table below. A metaphor is a word the reader
   must translate before they can act.
10. **Say what happens, not how bad it is.** `catastrophic`, `critical`, `severe` and
    `trivially` carry no information — the confidence number and the Fix block carry it. Write
    the effect: `the caller keeps the tokens and the pool keeps the debt`.
11. **Positive statements. No double negatives.** `The check is absent` beats `the check is
    not present`.
12. **Event order is sentence order.** Cause, then effect. `The price comes from the pool
    balance, so an attacker who moves the balance moves the price.`
13. **A title is one clause, twelve words or fewer,** present tense, active, and it names the
    defect or its effect. `Swap trusts a spot price as an oracle.`
    Not `Oracle manipulation vulnerability in swap functionality`.

## Words to replace

Left column: the wording to keep out of the report. Right column: what the report prints.

| Do not write | Write |
| --- | --- |
| burns the funds | sends the tokens to an address that cannot spend them |
| bricks the contract | makes the function fail for every caller, forever |
| rug / rugpull | the owner takes the user deposits |
| griefing | an attacker makes the function fail for other users |
| footgun | (delete the word and name the defect) |
| silently swallows the error | ignores the error |
| DoS / denial of service | blocks every caller |
| attack surface / attack vector | path |
| malicious actor / bad actor | an attacker |
| leverages / utilizes | uses |
| is able to | can |
| in order to | to |
| arbitrary value | any value the caller chooses |
| stale price | old price |
| sanity check | check |
| happy path | the normal path |
| atomically | in one transaction |
| trustlessly / permissionlessly | (delete, or name who may call) |
| non-zero | more than zero |
| cascading failures | (name each failure) |
| exponentially / trivially / catastrophically | (delete) |
| edge case | (name the input or the state) |

## Technical names stay

STE-100 keeps technical names, and a security report cannot work without them:
`reentrancy`, `slippage`, `oracle`, `revert`, `overflow`, `rounding`, `allowance`, `nonce`,
`slot`, `delegatecall`. Use them. They are precise and the reader who fixes Solidity knows
them.

The rule is what goes **around** them: name the mechanism once with its technical name, then
say in plain words what the attacker gets.

- No: `Classic CEI violation enabling reentrant drainage of the vault.`
- Yes: `The function sends ETH before it lowers the balance, so a reentrant call withdraws
  the same deposit twice.`

## Worked examples

Before, and after. The code the sentence describes did not change.

**One**

- Before: `Improper validation of the abort address results in a catastrophic loss of user
  funds via burning to the zero address.`
- After: `The function accepts a zero abort address, so a failed transfer sends the tokens to
  an address that nobody controls.`

**Two**

- Before: `Lack of slippage protection in the swap path exposes users to sandwich attacks,
  potentially leading to significant value extraction by MEV searchers.`
- After: `The swap sets the minimum output to zero, so an attacker who trades before and
  after the victim keeps most of the output.`

**Three — a Lead**

- Before: `Potential accounting inconsistency stemming from asymmetric fee handling on
  deposit/withdraw flows warranting further investigation.`
- After: `The deposit takes the fee from the amount, and the withdrawal takes it from the
  balance. We did not find the input that makes the two disagree.`

## Self-check before you write the block

Four questions. Any `no` means rewrite the sentence, not the code:

- Does the sentence name **who** acts and **what** they get?
- Is it one sentence, twenty-five words or fewer, with no `-ing` clause?
- Is every word in it a word the reader does not have to translate?
- Are the identifiers, the label and the diff exactly as the source and the agent wrote them?

# FROZEN SOURCE, CLEAN DESIGN, INTERFACES, AND REACHABLE DEPENDENCIES

### target/DESIGN.md

```
# Clean design specification
Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation. One entry costs 1,000,000 units of canonical six-decimal USDC. One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range. Exactly one ERC721 prize is escrowed atomically at creation. Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. Refund outcome pays 100% per entry and returns prize. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss. No administrator, mutable configuration or upgrade. Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days. Refunds open at deadline. Callback records result only. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure. Sponsor and treasury can claim independently after settlement. Never move assets between raffle clones. Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted. Frontend discovery is advisory; transaction decisions must reread current chain state.

This specification was composed before scanner results and historical findings. Source, not design prose, determines actual behavior. No tests, audit history, accepted-risk lists or scanner results are provided.

```

### target/packages/contracts/src/Raffle.sol

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/// @title raffle.fun Raffle Escrow and Entry Ticket
/// @author heesho
/// @notice Escrows one NFT and sells fixed-price USDC entries through one transferable ERC-721 ticket per purchase.
/// @dev Ticket IDs are sequential and map to one inclusive `[firstEntry,lastEntry]` uint128 range. Purchases, Chainlink
///      callbacks, and winner proofs are O(1) in entry count. Tickets remain transferable bearer claims until their
///      owners burn them for redemption or refund. Each raffle is a fixed, non-upgradeable ERC-1167 clone with no
///      administrator or rescue path. Permissionless settlement only allocates liabilities; the winning-ticket owner
///      atomically burns the ticket while receiving the NFT or cash prize.
/// @custom:version 1.0.0
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {
    using SafeERC20 for IERC20;

    // Types

    /// @notice Inclusive global entry-number range represented by one sequential ERC-721 ticket.
    /// @param firstEntry First represented one-based global entry.
    /// @param lastEntry Last represented one-based global entry.
    struct TicketRange {
        uint128 firstEntry;
        uint128 lastEntry;
    }

    // Constants

    /// @inheritdoc IRaffle
    uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;

    /// @inheritdoc IRaffle
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;

    /// @inheritdoc IRaffle
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;

    // Immutables and state

    /// @inheritdoc IRaffle
    address public immutable override factory;

    /// @inheritdoc IRaffle
    IERC20 public immutable override quoteToken;

    /// @inheritdoc IRaffle
    address public override sponsor;

    /// @inheritdoc IRaffle
    address public override sponsorRecipient;

    /// @inheritdoc IRaffle
    address public override protocolTreasury;

    /// @inheritdoc IRaffle
    IERC721 public override prizeToken;

    /// @inheritdoc IRaffle
    uint256 public override prizeTokenId;

    /// @inheritdoc IRaffle
    uint256 public override raffleId;

    /// @inheritdoc IRaffle
    uint128 public override reserveEntries;

    /// @inheritdoc IRaffle
    uint64 public override endTime;

    /// @inheritdoc IRaffle
    uint128 public override totalEntries;

    /// @inheritdoc IRaffle
    uint128 public override ticketCount;

    /// @inheritdoc IRaffle
    uint256 public override unsettledPot;

    /// @inheritdoc IRaffle
    uint256 public override remainingRefundLiability;

    /// @inheritdoc IRaffle
    address public override winnerRecipient;

    /// @inheritdoc IRaffle
    uint256 public override winnerProceeds;

    /// @inheritdoc IRaffle
    uint256 public override sponsorProceeds;

    /// @inheritdoc IRaffle
    uint256 public override protocolFees;

    /// @inheritdoc IRaffle
    uint256 public override vrfRequestId;

    /// @inheritdoc IRaffle
    uint64 public override drawRequestedAt;

    /// @inheritdoc IRaffle
    uint64 public override resolvedAt;

    /// @inheritdoc IRaffle
    uint128 public override winningEntry;

    /// @inheritdoc IRaffle
    uint256 public override winningTicketId;

    /// @inheritdoc IRaffle
    Status public override status;

    /// @inheritdoc IRaffle
    bool public override settlementComplete;

    /// @inheritdoc IRaffle
    bool public override winnerRedeemed;

    /// @inheritdoc IRaffle
    bool public override prizeClaimed;

    /// @inheritdoc IRaffle
    bool public override initialized;

    /// @dev Historical ticket ranges remain stored after burns so indexers and callers can reconstruct entry coverage.
    mapping(uint256 ticketId => TicketRange range) private _ticketRanges;

    /// @dev True only while the wrapper request call is executing, so a synchronous callback cannot resolve early.
    bool private _requestInFlight;

    // Errors

    /// @notice Raised when native currency is sent outside the payable draw-request path.
    error DirectNativeTransfer();

    // Constructor

    /// @notice Deploys and locks the implementation shared by one factory's minimal-proxy raffles.
    /// @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
    /// @param quoteToken_ Canonical six-decimal USDC contract fixed for the implementation and every clone.
    /// @param vrfWrapper_ Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.
    constructor(address quoteToken_, address vrfWrapper_)
        ERC721("", "")
        VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
    {
        if (msg.sender == address(0) || quoteToken_ == address(0)) revert ZeroAddress();

        factory = msg.sender;
        quoteToken = IERC20(quoteToken_);

        initialized = true;
        status = Status.Refunding;
    }

    // External state-changing functions

    /// @notice Rejects direct native-token transfers that are not attached to `requestDraw`.
    receive() external payable {
        revert DirectNativeTransfer();
    }

    /// @inheritdoc IRaffle
    function initialize(RaffleInitParams calldata params) external override {
        if (initialized) revert AlreadyInitialized();
        if (msg.sender != factory) revert OnlyFactory();
        initialized = true;

        if (
            params.sponsor == address(0) || params.sponsorRecipient == address(0)
                || params.protocolTreasury == address(0) || params.prizeToken == address(0)
        ) {
            revert ZeroAddress();
        }
        if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.sponsor);
        }
        if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.protocolTreasury);
        }
        if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.sponsorRecipient);
        }

        sponsor = params.sponsor;
        sponsorRecipient = params.sponsorRecipient;
        protocolTreasury = params.protocolTreasury;
        prizeToken = IERC721(params.prizeToken);
        prizeTokenId = params.prizeTokenId;
        raffleId = params.raffleId;
        reserveEntries = params.reserveEntries;
        endTime = params.endTime;
        status = Status.AwaitingPrize;
    }

    /// @inheritdoc IRaffle
    function buyEntries(address recipient, uint128 entryCount)
        external
        override
        nonReentrant
        returns (uint256 ticketId)
    {
        _requireStatus(Status.Active);
        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
        if (recipient == address(0)) revert InvalidRecipient();
        if (entryCount == 0) revert ZeroEntryCount();
        if (entryCount > type(uint128).max - totalEntries) {
            revert TotalEntriesOverflow(totalEntries, entryCount);
        }

        uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

        uint128 firstEntry = totalEntries + 1;
        uint128 lastEntry = totalEntries + entryCount;
        ticketId = uint256(ticketCount) + 1;

        totalEntries = lastEntry;
        ++ticketCount;
        _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
        unsettledPot += grossAmount;

        _safeMint(recipient, ticketId);
        emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
    }

    /// @inheritdoc IRaffle
    function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
        _requireStatus(Status.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalEntries == 0) revert NoEntriesSold();
        uint256 requestDeadline = drawRequestDeadline();
        if (block.timestamp >= requestDeadline) {
            revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
        }

        uint256 quotedFee = getVrfRequestPrice();
        if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

        status = Status.Drawing;
        drawRequestedAt = uint64(block.timestamp);
        _requestInFlight = true;
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
        uint256 paidPrice;
        (requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
        if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
        vrfRequestId = requestId;
        _requestInFlight = false;

        uint256 excess = msg.value - paidPrice;
        if (excess != 0) {
            bool success;
            address refundRecipient = msg.sender;
            assembly ("memory-safe") {
                success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
            }
            if (!success) revert NativeRefundFailed(msg.sender, excess);
        }

        emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
    }

    /// @inheritdoc IRaffle
    function enableRefunds() external override nonReentrant {
        uint256 deadline;

        if (status == Status.Active) {
            if (totalEntries == 0) {
                deadline = endTime;
                if (msg.sender != sponsor && block.timestamp < deadline) {
                    revert RefundsNotAvailable(deadline, block.timestamp);
                }
            } else {
                deadline = drawRequestDeadline();
                if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
            }
        } else if (status == Status.Drawing) {
            deadline = callbackDeadline();
            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
        } else {
            revert InvalidStatus(status);
        }

        uint256 liability = unsettledPot;
        unsettledPot = 0;
        remainingRefundLiability = liability;
        status = Status.Refunding;
        emit RefundsEnabled(msg.sender, liability);
    }

    /// @inheritdoc IRaffle
    function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
        cashAmount = _settleWinningTicket(ticketId);
    }

    /// @inheritdoc IRaffle
    function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
        if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        if (!settlementComplete) {
            _settleWinningTicket(ticketId);
        } else if (ticketId != winningTicketId) {
            revert WinningTicketMismatch(ticketId, winningTicketId);
        }

        address winner = ownerOf(ticketId);
        if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

        winnerRecipient = winner;
        winnerRedeemed = true;
        _burn(ticketId);

        address deliveredPrizeToken = address(0);
        uint256 deliveredPrizeTokenId = 0;
        if (result == Status.NftWon) {
            if (prizeClaimed) revert PrizeAlreadyClaimed();
            prizeClaimed = true;
            deliveredPrizeToken = address(prizeToken);
            deliveredPrizeTokenId = prizeTokenId;
            prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
            if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
                revert PrizeDeliveryVerificationFailed(winner);
            }
        } else {
            cashAmount = winnerProceeds;
            if (cashAmount == 0) revert NoWinnerProceeds();
            winnerProceeds = 0;
            _transferQuote(winner, cashAmount);
        }

        emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
    }

    /// @inheritdoc IRaffle
    function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
        _requireStatus(Status.Refunding);
        uint256 ticketQuantity = ticketIds.length;
        if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
            revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
        }

        uint256 aggregateEntries = 0;
        for (uint256 index; index < ticketQuantity; ++index) {
            uint256 ticketId = ticketIds[index];
            address owner = ownerOf(ticketId);
            if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

            (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
            aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
            _burn(ticketId);
        }

        amount = aggregateEntries * ENTRY_PRICE;
        remainingRefundLiability -= amount;
        _transferQuote(msg.sender, amount);
        uint256 liabilityAfter = remainingRefundLiability;
        emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
    }

    /// @inheritdoc IRaffle
    function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
        amount = sponsorProceeds;
        if (amount == 0) revert NoSponsorProceeds();
        sponsorProceeds = 0;
        address recipient = sponsorRecipient;
        _transferQuote(recipient, amount);
        emit SponsorProceedsReleased(msg.sender, recipient, amount);
    }

    /// @inheritdoc IRaffle
    function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
        amount = protocolFees;
        if (amount == 0) revert NoProtocolFees();
        protocolFees = 0;
        address treasury = protocolTreasury;
        _transferQuote(treasury, amount);
        emit ProtocolFeesReleased(msg.sender, treasury, amount);
    }

    /// @inheritdoc IRaffle
    function releaseSponsorPrize() external override nonReentrant {
        Status currentStatus = status;
        if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
            revert SponsorPrizeUnavailable(currentStatus);
        }
        if (prizeClaimed) revert PrizeAlreadyClaimed();

        address recipient = sponsorRecipient;
        prizeClaimed = true;
        prizeToken.transferFrom(address(this), recipient, prizeTokenId);
        if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
        emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
    }

    /// @notice Accepts only the exact configured prize deposited by the factory for the sponsor.
    /// @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be
    ///      rescued.
    /// @param operator ERC-721 transfer operator, which must be the canonical factory.
    /// @param from Previous owner, which must be the configured sponsor.
    /// @param tokenId Transferred token ID, which must match the configured prize.
    /// @return selector ERC-721 receiver acceptance selector.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4 selector)
    {
        if (
            status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
                || from != sponsor || operator != factory
        ) {
            revert UnexpectedPrize(msg.sender, tokenId, from, operator);
        }

        status = Status.Active;
        emit PrizeDeposited(msg.sender, tokenId, from);
        selector = IERC721Receiver.onERC721Received.selector;
    }

    // Public view and pure functions

    /// @inheritdoc IRaffle
    function getVrfRequestPrice() public view override returns (uint256 fee) {
        fee = i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1);
    }

    /// @inheritdoc IRaffle
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) public view override returns (uint256 fee) {
        fee = i_vrfV2PlusWrapper.estimateRequestPriceNative(callbackGasLimit, 1, requestGasPriceWei);
    }

    /// @inheritdoc IRaffle
    function vrfWrapper() public view override returns (IVRFV2PlusWrapper wrapper) {
        wrapper = i_vrfV2PlusWrapper;
    }

    /// @inheritdoc IRaffle
    function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
        TicketRange storage range = _ticketRanges[ticketId];
        firstEntry = range.firstEntry;
        lastEntry = range.lastEntry;
    }

    /// @inheritdoc IRaffle
    function drawRequestDeadline() public view override returns (uint256 deadline) {
        deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function callbackDeadline() public view override returns (uint256 deadline) {
        if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
    }

    /// @inheritdoc IRaffle
    function grossSales() public view override returns (uint256 amount) {
        amount = uint256(totalEntries) * ENTRY_PRICE;
    }

    /// @notice Returns the fixed display name shared by every raffle ticket collection.
    /// @return Exact ERC-721 collection name, `raffle.fun Ticket`.
    function name() public pure override returns (string memory) {
        return "raffle.fun Ticket";
    }

    /// @notice Returns the fixed display symbol shared by every raffle ticket collection.
    /// @return Exact ERC-721 collection symbol, `RAFFLE`.
    function symbol() public pure override returns (string memory) {
        return "RAFFLE";
    }

    // Internal state-changing functions

    /// @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected
    ///      before their ownership could make a claim unreachable. Burns pass the zero address and remain permitted.
    /// @param to Prospective ticket recipient, or the zero address for a burn.
    /// @param ticketId Ticket being minted, transferred, or burned.
    /// @param auth Caller whose owner or operator authority is checked by ERC-721.
    /// @return previousOwner Ticket owner before the update, or the zero address for a mint.
    function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
        if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
            revert UnsafeProtocolDestination(to);
        }
        previousOwner = super._update(to, ticketId, auth);
    }

    /// @dev Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer
    ///      occurs. In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for
    ///      liveness; malformed ABI calldata reverts during Solidity decoding before this handler runs.
    /// @param requestId Wrapper-authenticated request identifier supplied by the callback.
    /// @param randomWords Callback words; exactly one word is required for resolution.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        if (
            _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
                || block.timestamp >= callbackDeadline()
        ) {
            emit VrfCallbackIgnored(requestId, vrfRequestId, status);
            return;
        }

        uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
        winningEntry = resolvedEntry;
        resolvedAt = uint64(block.timestamp);
        status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

        emit RaffleResolved(requestId, resolvedEntry, status);
    }

    // Private state-changing helpers

    /// @dev Validates the winning range once and allocates all terminal quote-token liabilities without transferring
    ///      an asset or reading ticket ownership. Both percentage allocations round down; sponsor proceeds are the
    ///      remainder.
    /// @param ticketId Ticket whose inclusive range must contain the selected winning entry.
    /// @return cashAmount Raw six-decimal quote-token units allocated to the cash winner, or zero for `NftWon`.
    function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
        if (settlementComplete) revert SettlementAlreadyComplete();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        _requireWinningTicket(ticketId);
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 sponsorAmount;

        if (result == Status.NftWon) {
            sponsorAmount = grossPot - protocolFee;
        } else {
            cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            sponsorAmount = grossPot - protocolFee - cashAmount;
            winnerProceeds = cashAmount;
        }

        settlementComplete = true;
        winningTicketId = ticketId;
        unsettledPot = 0;
        sponsorProceeds = sponsorAmount;
        protocolFees = protocolFee;

        emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
    }

    /// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
    ///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
    /// @param to Immutable or owner-derived recipient of the claim.
    /// @param amount Raw six-decimal USDC units transferred.
    function _transferQuote(address to, uint256 amount) private {
        if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
        quoteToken.safeTransfer(to, amount);
    }

    // Private view and pure helpers

    /// @dev Reverts unless the raffle is in the expected lifecycle state.
    /// @param expected Status required by the calling operation.
    function _requireStatus(Status expected) private view {
        if (status != expected) revert InvalidStatus(status);
    }

    /// @dev Reverts unless the supplied ticket's stored inclusive range contains the selected winning entry.
    /// @param ticketId Candidate winning ticket ID.
    function _requireWinningTicket(uint256 ticketId) private view {
        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        uint128 selectedEntry = winningEntry;
        if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
            revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
        }
    }

    /// @dev Identifies same-factory protocol plumbing that cannot safely own a ticket or receive a payout.
    ///      Initialization supplies the prospective prize token because clone storage is not populated yet; runtime
    ///      checks pass the stored prize token. Code-less addresses are not queried in the registry.
    /// @param destination Address being screened.
    /// @param prizeToken_ Configured or prospective prize-token address to reject.
    /// @return unsafeDestination True when the address is known same-factory protocol plumbing.
    function _isProtocolDestination(address destination, address prizeToken_)
        private
        view
        returns (bool unsafeDestination)
    {
        IRaffleFactory canonicalFactory = IRaffleFactory(factory);
        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
            || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
            || destination == canonicalFactory.raffleImplementation();
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = canonicalFactory.isRaffle(destination);
        }
    }

    /// @dev Validates the wrapper before passing it to the inherited constructor initializer.
    /// @param wrapper Prospective Chainlink wrapper address.
    /// @return validatedWrapper The same nonzero wrapper address.
    function _validatedVrfWrapper(address wrapper) private pure returns (address validatedWrapper) {
        if (wrapper == address(0)) revert ZeroAddress();
        validatedWrapper = wrapper;
    }
}

```

### target/packages/contracts/src/RaffleFactory.sol

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Raffle } from "./Raffle.sol";
import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/// @title raffle.fun Canonical USDC Raffle Factory
/// @author heesho
/// @notice Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.
/// @dev The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable. The
///      factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.
/// @custom:version 1.0.0
contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
    // Constants

    /// @inheritdoc IRaffleFactory
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;

    /// @inheritdoc IRaffleFactory
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;

    // Immutables and state

    /// @inheritdoc IRaffleFactory
    address public immutable override quoteToken;

    /// @inheritdoc IRaffleFactory
    address public immutable override vrfWrapper;

    /// @inheritdoc IRaffleFactory
    address public immutable override protocolTreasury;

    /// @inheritdoc IRaffleFactory
    address public immutable override raffleImplementation;

    /// @inheritdoc IRaffleFactory
    uint256 public override raffleCount;

    /// @inheritdoc IRaffleFactory
    mapping(uint256 raffleId => address raffle) public override raffleById;

    /// @inheritdoc IRaffleFactory
    mapping(address raffle => uint256 raffleId) public override idByRaffle;

    /// @inheritdoc IRaffleFactory
    mapping(address raffle => bool registered) public override isRaffle;

    // Constructor

    /// @notice Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.
    /// @dev The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code.
    ///      Deployment tooling must supply and verify the target chain's official USDC address because the constructor
    ///      cannot prove token identity from metadata.
    /// @param quoteToken_ Target chain's official six-decimal USDC contract trusted by every raffle.
    /// @param vrfWrapper_ Official Chainlink VRF v2.5 native direct-funding wrapper for the target chain.
    /// @param protocolTreasury_ Immutable protocol-fee recipient used by every raffle.
    constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
        _requireContract(quoteToken_);
        _requireContract(vrfWrapper_);
        if (protocolTreasury_ == address(0)) revert ZeroAddress();

        uint8 quoteDecimals = 0;
        try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
            quoteDecimals = decimals_;
        } catch {
            revert UnsupportedQuoteToken(quoteToken_);
        }
        if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
            revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
        }

        if (protocolTreasury_ == address(this) || protocolTreasury_ == quoteToken_ || protocolTreasury_ == vrfWrapper_)
        {
            revert UnsafeProtocolDestination(protocolTreasury_);
        }

        quoteToken = quoteToken_;
        vrfWrapper = vrfWrapper_;
        protocolTreasury = protocolTreasury_;

        address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
        if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
        raffleImplementation = implementation;
    }

    // External state-changing functions

    /// @inheritdoc IRaffleFactory
    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
        _validateCreateParams(params);
        uint256 currentTime = block.timestamp;
        if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
        uint256 saleDuration = uint256(params.endTime) - currentTime;
        if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
            revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
        }
        uint256 raffleId = ++raffleCount;
        raffle = Clones.clone(raffleImplementation);
        // The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
        // slither-disable-next-line reentrancy-no-eth
        IRaffle(raffle)
            .initialize(
                IRaffle.RaffleInitParams({
                sponsor: msg.sender,
                sponsorRecipient: params.sponsorRecipient,
                protocolTreasury: protocolTreasury,
                prizeToken: params.prizeToken,
                prizeTokenId: params.prizeTokenId,
                raffleId: raffleId,
                reserveEntries: params.reserveEntries,
                endTime: params.endTime
            })
            );

        raffleById[raffleId] = raffle;
        idByRaffle[raffle] = raffleId;
        isRaffle[raffle] = true;

        IERC721 prize = IERC721(params.prizeToken);
        prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
        if (prize.ownerOf(params.prizeTokenId) != raffle) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }
        if (IRaffle(raffle).status() != IRaffle.Status.Active) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }

        emit RaffleCreated(
            raffleId,
            raffle,
            msg.sender,
            params.sponsorRecipient,
            params.prizeToken,
            params.prizeTokenId,
            quoteToken,
            protocolTreasury,
            params.reserveEntries,
            params.endTime
        );
    }

    // Private view helpers

    /// @dev Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.
    /// @param params Prospective raffle configuration supplied by the sponsor.
    function _validateCreateParams(CreateRaffleParams calldata params) private view {
        _requireContract(params.prizeToken);
        if (params.sponsorRecipient == address(0)) revert ZeroAddress();
        if (
            params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
                || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
        ) {
            revert UnsafeProtocolDestination(params.prizeToken);
        }
        if (
            params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
                || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
                || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
        ) {
            revert UnsafeProtocolDestination(params.sponsorRecipient);
        }

        bool supports721 = false;
        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            supports721 = supported;
        } catch {
            revert UnsupportedPrizeToken(params.prizeToken);
        }
        if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
        if (params.reserveEntries == 0) revert ZeroReserveEntries();
    }

    /// @dev Reverts unless an address contains deployed code.
    /// @param account Address required to be a contract.
    function _requireContract(address account) private view {
        if (account.code.length == 0) revert NotContract(account);
    }
}

```

### target/packages/contracts/src/interfaces/IRaffle.sol

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title raffle.fun Raffle Interface
/// @author heesho
/// @notice Defines one autonomous NFT raffle using fixed-price USDC entries and one transferable ERC-721 ticket per
///         purchase.
/// @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable
///      bearer claim until its owner atomically burns it for redemption or refund. The immutable quote token is trusted
///      canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest,
///      standards-compliant ERC-721s.
/// @custom:version 1.0.0
interface IRaffle {
    // Types

    /// @notice The single authoritative raffle lifecycle and economic result.
    enum Status {
        /// @notice The clone is initialized and waiting for the factory to escrow the configured prize.
        AwaitingPrize,
        /// @notice The prize is escrowed and entry sales or post-sale draw initiation are available.
        Active,
        /// @notice A Chainlink VRF request was accepted and its callback window is open.
        Drawing,
        /// @notice The reserve was met and the winning ticket may redeem the prize NFT.
        NftWon,
        /// @notice The reserve was missed and the winning ticket may redeem its cash allocation.
        CashWon,
        /// @notice Full ticket refunds are enabled and the sponsor may recover the prize NFT.
        Refunding
    }

    /// @notice Complete clone-specific configuration supplied once by the canonical factory.
    /// @param sponsor Prize depositor and empty-raffle cancellation authority.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param protocolTreasury Immutable recipient of protocol fees.
    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    /// @param prizeTokenId Token ID of the prize escrowed by this raffle.
    /// @param raffleId One-based canonical factory identifier for this raffle.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Unix timestamp, in seconds, at which entry sales end exclusively.
    struct RaffleInitParams {
        address sponsor;
        address sponsorRecipient;
        address protocolTreasury;
        address prizeToken;
        uint256 prizeTokenId;
        uint256 raffleId;
        uint128 reserveEntries;
        uint64 endTime;
    }

    // Events

    /// @notice Emitted when the factory deposits the configured prize and activates the raffle.
    /// @param prizeToken ERC-721 contract of the deposited prize.
    /// @param prizeTokenId Token ID of the deposited prize.
    /// @param sponsor Address that deposited the prize through the factory.
    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);

    /// @notice Emitted when a buyer pays for entries and one range ticket is minted.
    /// @param buyer Address that paid the six-decimal quote-token amount.
    /// @param recipient Address that received the newly minted ticket.
    /// @param ticketId Sequential ticket ID assigned to the purchase.
    /// @param firstEntry First global raffle entry represented by the ticket, inclusive.
    /// @param lastEntry Last global raffle entry represented by the ticket, inclusive.
    /// @param entryCount Number of entries represented by the ticket.
    /// @param grossAmount Raw six-decimal quote-token units paid, equal to `entryCount * ENTRY_PRICE`.
    event TicketPurchased(
        address indexed buyer,
        address indexed recipient,
        uint256 indexed ticketId,
        uint128 firstEntry,
        uint128 lastEntry,
        uint128 entryCount,
        uint256 grossAmount
    );

    /// @notice Emitted when the raffle pays for and records its one Chainlink VRF request.
    /// @param requestId Wrapper-assigned request identifier.
    /// @param requester Address that initiated and funded the request.
    /// @param fee Native-token wei actually paid to the wrapper for the request.
    /// @param excessReturned Native-token wei returned to the requester after paying the actual fee.
    /// @param drawRequestedAt Unix timestamp, in seconds, when the request was accepted.
    /// @param callbackDeadline Exclusive Unix-timestamp deadline for accepting the authenticated callback.
    event DrawRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 fee,
        uint256 excessReturned,
        uint256 drawRequestedAt,
        uint256 callbackDeadline
    );

    /// @notice Emitted when an authenticated, ABI-decodable callback cannot resolve the raffle.
    /// @param receivedRequestId Request ID supplied by the wrapper callback.
    /// @param expectedRequestId Request ID currently recorded by the raffle, or zero before request persistence.
    /// @param status Current raffle status when the callback is ignored.
    event VrfCallbackIgnored(uint256 indexed receivedRequestId, uint256 indexed expectedRequestId, Status status);

    /// @notice Emitted when an authenticated callback selects the winning entry and final result.
    /// @param requestId Request ID that produced the accepted randomness.
    /// @param winningEntry Selected one-based global entry number in `[1,totalEntries]`.
    /// @param result Final `NftWon` or `CashWon` result.
    event RaffleResolved(uint256 indexed requestId, uint128 indexed winningEntry, Status indexed result);

    /// @notice Emitted when the raffle enters the full-refund branch.
    /// @param finalizer Address that enabled refunds.
    /// @param remainingRefundLiability Raw six-decimal quote-token units initially available for ticket refunds.
    event RefundsEnabled(address indexed finalizer, uint256 remainingRefundLiability);

    /// @notice Emitted when the winning ticket is proven and all terminal quote-token liabilities are allocated.
    /// @param ticketId Ticket proven to contain the selected winning entry.
    /// @param settler Address that performed permissionless settlement.
    /// @param result Final `NftWon` or `CashWon` result.
    /// @param cashAmount Raw six-decimal quote-token units allocated to the cash winner; zero for `NftWon`.
    /// @param protocolFee Raw six-decimal quote-token units allocated to the treasury, rounded down from gross sales.
    /// @param sponsorAmount Raw six-decimal quote-token units allocated to the sponsor recipient as the remainder.
    event WinningTicketSettled(
        uint256 indexed ticketId,
        address indexed settler,
        Status indexed result,
        uint256 cashAmount,
        uint256 protocolFee,
        uint256 sponsorAmount
    );

    /// @notice Emitted when the winning ticket owner burns the ticket and receives the corresponding prize.
    /// @param ticketId Burned winning ticket ID.
    /// @param winner Ticket owner that received the prize at redemption time.
    /// @param result Final `NftWon` or `CashWon` result.
    /// @param cashAmount Raw six-decimal quote-token units paid for `CashWon`; zero for `NftWon`.
    /// @param prizeToken ERC-721 prize contract for `NftWon`; the zero address for `CashWon`.
    /// @param prizeTokenId ERC-721 prize token ID for `NftWon`; zero for `CashWon`.
    event WinningTicketRedeemed(
        uint256 indexed ticketId,
        address indexed winner,
        Status indexed result,
        uint256 cashAmount,
        address prizeToken,
        uint256 prizeTokenId
    );

    /// @notice Emitted when an owner burns one or more tickets for a full quote-token refund.
    /// @param owner Ticket owner that burned the tickets and received the refund.
    /// @param ticketQuantity Number of tickets burned in this transaction.
    /// @param entryQuantity Aggregate number of entries represented by the burned tickets.
    /// @param amount Raw six-decimal quote-token units refunded, equal to `entryQuantity * ENTRY_PRICE`.
    /// @param remainingRefundLiability Raw six-decimal quote-token units still claimable after this refund.
    event TicketsRefunded(
        address indexed owner,
        uint256 ticketQuantity,
        uint256 entryQuantity,
        uint256 amount,
        uint256 remainingRefundLiability
    );

    /// @notice Emitted when the complete current sponsor balance is released to its immutable recipient.
    /// @param caller Address that triggered the permissionless release.
    /// @param recipient Immutable sponsor recipient that received the payment.
    /// @param amount Raw six-decimal quote-token units paid.
    event SponsorProceedsReleased(address indexed caller, address indexed recipient, uint256 amount);

    /// @notice Emitted when the complete current protocol-fee balance is released to the immutable treasury.
    /// @param caller Address that triggered the permissionless release.
    /// @param treasury Immutable protocol treasury that received the payment.
    /// @param amount Raw six-decimal quote-token units paid.
    event ProtocolFeesReleased(address indexed caller, address indexed treasury, uint256 amount);

    /// @notice Emitted when the escrowed prize is returned after a cash result or refund transition.
    /// @param caller Address that triggered the permissionless release.
    /// @param recipient Immutable sponsor recipient that received the prize.
    /// @param prizeToken ERC-721 contract of the returned prize.
    /// @param prizeTokenId Token ID of the returned prize.
    event SponsorPrizeReleased(
        address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId
    );

    // Errors

    /// @notice Raised when a caller other than the immutable factory attempts clone initialization.
    error OnlyFactory();

    /// @notice Raised when initialization is attempted more than once or on the locked implementation.
    error AlreadyInitialized();

    /// @notice Raised when a required address is the zero address.
    error ZeroAddress();

    /// @notice Raised when an operation is unavailable in the current lifecycle state.
    /// @param actual Current raffle status.
    error InvalidStatus(Status actual);

    /// @notice Raised when an ERC-721 receiver callback does not exactly match the configured factory prize deposit.
    /// @param token ERC-721 contract that invoked the receiver callback.
    /// @param tokenId Token ID supplied by the callback.
    /// @param from Address identified as the previous token owner.
    /// @param operator Address identified as the transfer operator.
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);

    /// @notice Raised when an entry purchase is submitted at or after the exclusive sale end.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error SaleEnded(uint256 endTime, uint256 currentTime);

    /// @notice Raised when an entry ticket would be minted to the zero address.
    error InvalidRecipient();

    /// @notice Raised when a purchase requests no entries.
    error ZeroEntryCount();

    /// @notice Raised when a purchase would exceed the `uint128` global entry-number representation.
    /// @param totalEntries Current global sold-entry count.
    /// @param requestedEntries Prospective entry count requested by the purchase.
    error TotalEntriesOverflow(uint128 totalEntries, uint128 requestedEntries);

    /// @notice Raised when a refund batch is empty or exceeds the bounded ticket limit.
    /// @param quantity Number of supplied ticket IDs.
    /// @param maximum Maximum ticket IDs accepted per refund transaction.
    error InvalidTicketBatchSize(uint256 quantity, uint256 maximum);

    /// @notice Raised when a quote-token claim targets a known protocol destination that could strand the claim.
    /// @param destination Rejected payout recipient.
    error InvalidQuoteDestination(address destination);

    /// @notice Raised when a draw request is submitted before the sale end.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);

    /// @notice Raised when a draw request is submitted at or after the exclusive request deadline.
    /// @param deadline Exclusive draw-request Unix-timestamp deadline, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);

    /// @notice Raised when draw initiation is attempted for a raffle with zero sold entries.
    error NoEntriesSold();

    /// @notice Raised when refunds are requested before the applicable liveness deadline.
    /// @param deadline Unix timestamp, in seconds, at which refunds become available.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error RefundsNotAvailable(uint256 deadline, uint256 currentTime);

    /// @notice Raised when supplied native value cannot cover the quoted or actual Chainlink request fee.
    /// @param requiredFee Native-token wei required for the request.
    /// @param suppliedValue Native-token wei supplied by the caller.
    error InsufficientVrfFee(uint256 requiredFee, uint256 suppliedValue);

    /// @notice Raised when excess native value cannot be returned to the draw requester.
    /// @param recipient Draw requester that was due the refund.
    /// @param amount Native-token wei that could not be returned.
    error NativeRefundFailed(address recipient, uint256 amount);

    /// @notice Raised when no current cash-winner proceeds remain claimable.
    error NoWinnerProceeds();

    /// @notice Raised when no current sponsor proceeds remain claimable.
    error NoSponsorProceeds();

    /// @notice Raised when no current protocol fees remain claimable.
    error NoProtocolFees();

    /// @notice Raised when initialization or a ticket transfer targets known protocol plumbing.
    /// @param destination Rejected address.
    error UnsafeProtocolDestination(address destination);

    /// @notice Raised when the caller is not the current owner of the supplied ticket.
    /// @param ticketId Ticket whose ownership was checked.
    /// @param caller Address attempting the owner-only operation.
    /// @param owner Current ticket owner.
    error NotTicketOwner(uint256 ticketId, address caller, address owner);

    /// @notice Raised when the supplied ticket range does not contain the selected winning entry.
    /// @param ticketId Supplied ticket ID.
    /// @param winningEntry Selected one-based global winning entry.
    error TicketDoesNotContainWinningEntry(uint256 ticketId, uint128 winningEntry);

    /// @notice Raised when terminal liabilities have already been allocated.
    error SettlementAlreadyComplete();

    /// @notice Raised when redemption supplies a ticket other than the recorded winning ticket.
    /// @param suppliedTicketId Ticket ID supplied for redemption.
    /// @param winningTicketId Previously settled winning ticket ID.
    error WinningTicketMismatch(uint256 suppliedTicketId, uint256 winningTicketId);

    /// @notice Raised when the winning ticket has already been burned and redeemed.
    error WinningTicketAlreadyRedeemed();

    /// @notice Raised when the sponsor prize cannot be returned in the current result state.
    /// @param status Current raffle status.
    error SponsorPrizeUnavailable(Status status);

    /// @notice Raised when the escrowed prize has already been released.
    error PrizeAlreadyClaimed();

    /// @notice Raised when the prize token does not report the expected owner after transfer.
    /// @param recipient Address that should own the prize after delivery.
    error PrizeDeliveryVerificationFailed(address recipient);

    // External state-changing functions

    /// @notice Initializes a fresh fixed-target clone with its immutable-per-raffle configuration.
    /// @dev Callable exactly once and only by the immutable canonical factory. Prize escrow activates the raffle later.
    /// @param params Clone-specific sponsor, prize, accounting, identifier, reserve, and timing configuration.
    function initialize(RaffleInitParams calldata params) external;

    /// @notice Buys any positive number of entries and mints one sequential ticket containing their inclusive range.
    /// @param recipient Address that receives the newly minted ERC-721 range ticket.
    /// @param entryCount Prospective number of entries to buy for this ticket.
    /// @return ticketId Sequential ID of the newly minted ticket.
    function buyEntries(address recipient, uint128 entryCount) external returns (uint256 ticketId);

    /// @notice Pays the current native Chainlink fee and requests the raffle's one random word.
    /// @dev Callable by anyone only in `[endTime,drawRequestDeadline())` after at least one entry is sold. Any native
    ///      value above the wrapper's actual fee is returned to the caller atomically.
    /// @return requestId Wrapper-assigned request identifier recorded by the raffle.
    function requestDraw() external payable returns (uint256 requestId);

    /// @notice Enables full refunds after the sold-raffle request deadline or an accepted request's callback deadline.
    ///         Also closes an empty raffle immediately for the sponsor and after sale end for anyone.
    function enableRefunds() external;

    /// @notice Proves which ticket contains the winning entry and allocates winner, sponsor, and protocol liabilities.
    /// @dev Anyone may execute; ownership is not read, the ticket remains transferable, and no external asset transfer
    ///      occurs. The cash-winner allocation is rounded down; the sponsor receives the remaining raw units.
    /// @param ticketId Ticket whose stored inclusive range must contain `winningEntry`.
    /// @return cashAmount Raw six-decimal quote-token units allocated to the winner, or zero for an NFT result.
    function settleWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);

    /// @notice Lets the current winning-ticket owner atomically burn the ticket and receive the NFT or cash prize.
    /// @dev If necessary, this first settles the supplied winning ticket so the owner can complete both steps in one
    ///      transaction. Any failed delivery reverts the burn and every redemption state change.
    /// @param ticketId Winning ticket to settle if needed, burn, and redeem.
    /// @return cashAmount Raw six-decimal quote-token units paid for `CashWon`, or zero for `NftWon`.
    function redeemWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);

    /// @notice Burns an owner-selected batch of tickets and returns their full entry purchase value.
    /// @dev Accepts one to 100 tickets. Duplicate, nonexistent, or foreign-owned IDs revert the entire batch.
    /// @param ticketIds Ticket IDs owned by the caller and submitted for refund.
    /// @return amount Raw six-decimal quote-token units paid, equal to represented entries times `ENTRY_PRICE`.
    function refundTickets(uint256[] calldata ticketIds) external returns (uint256 amount);

    /// @notice Releases the complete current sponsor-proceeds balance to the immutable sponsor recipient.
    /// @return amount Raw six-decimal quote-token units paid in this release.
    function releaseSponsorProceeds() external returns (uint256 amount);

    /// @notice Releases the complete current protocol-fee balance to the immutable treasury.
    /// @return amount Raw six-decimal quote-token units paid in this release.
    function releaseProtocolFees() external returns (uint256 amount);

    /// @notice Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`.
    function releaseSponsorPrize() external;

    // External view functions

    /// @notice Returns the wrapper's current native direct-funding price for the configured callback.
    /// @return fee Native-token wei currently quoted by the wrapper; the value may change before request inclusion.
    function getVrfRequestPrice() external view returns (uint256 fee);

    /// @notice Estimates the native direct-funding price at a caller-selected gas price.
    /// @param requestGasPriceWei Prospective transaction gas price in wei per gas.
    /// @return fee Estimated native-token wei for the configured callback and one random word.
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) external view returns (uint256 fee);

    /// @notice Returns the inclusive global entry range represented by a ticket ID.
    /// @dev Returns zeros for an ID that has never been minted; ranges remain historical after ticket burns.
    /// @param ticketId Sequential ticket ID to inspect.
    /// @return firstEntry First represented one-based global entry, inclusive.
    /// @return lastEntry Last represented one-based global entry, inclusive.
    function ticketRange(uint256 ticketId) external view returns (uint128 firstEntry, uint128 lastEntry);

    /// @notice Returns the exclusive deadline for initiating the draw.
    /// @return deadline Unix timestamp, in seconds, equal to `endTime + 2 days`.
    function drawRequestDeadline() external view returns (uint256 deadline);

    /// @notice Returns the exclusive deadline for accepting the authenticated callback.
    /// @return deadline Unix timestamp, in seconds, equal to `drawRequestedAt + 2 days`, or zero before a request.
    function callbackDeadline() external view returns (uint256 deadline);

    /// @notice Returns all currently outstanding quote-token liabilities tracked by the raffle.
    /// @return amount Raw six-decimal quote-token units across the unsettled pot, refunds, and allocated claims.
    function accountedQuoteBalance() external view returns (uint256 amount);

    /// @notice Returns lifetime gross sales derived from the global sold-entry count.
    /// @dev No redundant gross-sales value is stored.
    /// @return amount Raw six-decimal quote-token units equal to `totalEntries * ENTRY_PRICE`.
    function grossSales() external view returns (uint256 amount);

    // Public generated getters

    /// @notice Returns the fixed raw six-decimal quote-token price of one entry.
    /// @return price One entry price, exactly 1,000,000 raw units.
    function ENTRY_PRICE() external view returns (uint256 price);

    /// @notice Returns the fixed Chainlink callback execution limit.
    /// @return gasLimit Callback gas units requested from the wrapper.
    function callbackGasLimit() external view returns (uint32 gasLimit);

    /// @notice Returns the fixed Chainlink confirmation count.
    /// @return confirmations Blocks requested before callback fulfillment.
    function requestConfirmations() external view returns (uint16 confirmations);

    /// @notice Returns the immutable factory authorized to initialize this implementation's clones.
    /// @return factoryAddress Canonical factory address.
    function factory() external view returns (address factoryAddress);

    /// @notice Returns the prize depositor and pre-end empty-raffle refund authority.
    /// @return sponsorAddress Immutable-per-raffle sponsor address.
    function sponsor() external view returns (address sponsorAddress);

    /// @notice Returns the immutable recipient of sponsor quote proceeds and returned prizes.
    /// @return recipient Sponsor recipient address.
    function sponsorRecipient() external view returns (address recipient);

    /// @notice Returns the immutable recipient of this raffle's protocol fees.
    /// @return treasury Protocol treasury address.
    function protocolTreasury() external view returns (address treasury);

    /// @notice Returns the immutable canonical six-decimal USDC contract.
    /// @return token Canonical USDC contract trusted by this factory deployment.
    function quoteToken() external view returns (IERC20 token);

    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper.
    /// @return wrapper Wrapper contract.
    function vrfWrapper() external view returns (IVRFV2PlusWrapper wrapper);

    /// @notice Returns the configured ERC-721 prize contract.
    /// @return token Prize-token contract.
    function prizeToken() external view returns (IERC721 token);

    /// @notice Returns the configured ERC-721 prize token ID.
    /// @return tokenId Escrowed prize token ID.
    function prizeTokenId() external view returns (uint256 tokenId);

    /// @notice Returns this raffle's one-based canonical factory identifier.
    /// @return id Raffle identifier.
    function raffleId() external view returns (uint256 id);

    /// @notice Returns the global entry threshold that selects the NFT outcome when met or exceeded.
    /// @return entries Reserve entry count.
    function reserveEntries() external view returns (uint128 entries);

    /// @notice Returns the exclusive sale-end timestamp.
    /// @return timestamp Unix timestamp, in seconds.
    function endTime() external view returns (uint64 timestamp);

    /// @notice Returns the lifetime global number of entries sold.
    /// @return entries Sold-entry count; also the last assigned global entry number.
    function totalEntries() external view returns (uint128 entries);

    /// @notice Returns the lifetime number of range tickets minted.
    /// @return tickets Ticket count; also the latest assigned ticket ID.
    function ticketCount() external view returns (uint128 tickets);

    /// @notice Returns the current unallocated sale pot.
    /// @return amount Raw six-decimal quote-token units collected before settlement or refund activation.
    function unsettledPot() external view returns (uint256 amount);

    /// @notice Returns the current aggregate full-refund liability.
    /// @return amount Raw six-decimal quote-token units still claimable by unrefunded tickets.
    function remainingRefundLiability() external view returns (uint256 amount);

    /// @notice Returns the address that burned and redeemed the winning ticket.
    /// @return recipient Winner at redemption time, or the zero address before redemption.
    function winnerRecipient() external view returns (address recipient);

    /// @notice Returns the current cash-winner liability.
    /// @return amount Raw six-decimal quote-token units claimable by the winning ticket, or zero otherwise.
    function winnerProceeds() external view returns (uint256 amount);

    /// @notice Returns the current sponsor liability.
    /// @return amount Raw six-decimal quote-token units claimable by the immutable sponsor recipient.
    function sponsorProceeds() external view returns (uint256 amount);

    /// @notice Returns the current protocol-fee liability.
    /// @return amount Raw six-decimal quote-token units claimable by the immutable treasury.
    function protocolFees() external view returns (uint256 amount);

    /// @notice Returns the accepted Chainlink request ID.
    /// @return requestId Wrapper-assigned ID, or zero before request persistence.
    function vrfRequestId() external view returns (uint256 requestId);

    /// @notice Returns when the accepted draw request was recorded.
    /// @return timestamp Unix timestamp, in seconds, or zero before request persistence.
    function drawRequestedAt() external view returns (uint64 timestamp);

    /// @notice Returns when an authenticated callback resolved the raffle.
    /// @return timestamp Unix timestamp, in seconds, or zero before resolution.
    function resolvedAt() external view returns (uint64 timestamp);

    /// @notice Returns the selected one-based global winning entry.
    /// @return entry Entry in `[1,totalEntries]`, or zero before resolution.
    function winningEntry() external view returns (uint128 entry);

    /// @notice Returns the ticket proven to contain the winning entry.
    /// @return ticketId Sequential ticket ID, or zero before settlement.
    function winningTicketId() external view returns (uint256 ticketId);

    /// @notice Returns the current lifecycle and economic result.
    /// @return currentStatus Current `Status` value.
    function status() external view returns (Status currentStatus);

    /// @notice Returns whether terminal winner, sponsor, and protocol liabilities have been allocated.
    /// @return complete True after winning-ticket settlement.
    function settlementComplete() external view returns (bool complete);

    /// @notice Returns whether the winning ticket has been burned and its NFT or cash prize delivered.
    /// @return redeemed True after successful winner redemption.
    function winnerRedeemed() external view returns (bool redeemed);

    /// @notice Returns whether the prize has been delivered to the winner or returned to the sponsor recipient.
    /// @return claimed True after successful prize release.
    function prizeClaimed() external view returns (bool claimed);

    /// @notice Returns whether this implementation or clone has completed its one-time initialization step.
    /// @return complete True for the locked implementation and every initialized clone.
    function initialized() external view returns (bool complete);
}

```

### target/packages/contracts/src/interfaces/IRaffleFactory.sol

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title raffle.fun Raffle Factory Interface
/// @author heesho
/// @notice Defines atomic ERC-1167 raffle creation for one immutable USDC, treasury, and Chainlink configuration.
/// @dev The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration. Deployment tooling must
///      verify that the immutable quote-token address is the target chain's official USDC; onchain construction checks
///      only code presence and six-decimal metadata.
/// @custom:version 1.0.0
interface IRaffleFactory {
    // Types

    /// @notice Sponsor-selected configuration for one new raffle.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    /// @param prizeTokenId Token ID to escrow atomically during creation.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    struct CreateRaffleParams {
        address sponsorRecipient;
        address prizeToken;
        uint256 prizeTokenId;
        uint128 reserveEntries;
        uint64 endTime;
    }

    // Events

    /// @notice Emitted after a raffle clone is initialized, registered, funded, and active.
    /// @param raffleId One-based canonical raffle identifier.
    /// @param raffle Newly created fixed-target ERC-1167 clone.
    /// @param sponsor Prize depositor and pre-end empty-raffle refund authority.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param prizeToken ERC-721 contract of the escrowed prize.
    /// @param prizeTokenId Token ID of the escrowed prize.
    /// @param quoteToken Immutable canonical six-decimal USDC contract used by the raffle.
    /// @param protocolTreasury Immutable recipient of protocol fees.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed raffle,
        address indexed sponsor,
        address sponsorRecipient,
        address prizeToken,
        uint256 prizeTokenId,
        address quoteToken,
        address protocolTreasury,
        uint128 reserveEntries,
        uint64 endTime
    );

    // Errors

    /// @notice Raised when a required address is the zero address.
    error ZeroAddress();

    /// @notice Raised when an address required to contain deployed code is not a contract.
    /// @param account Address whose code length was zero.
    error NotContract(address account);

    /// @notice Raised when the quote token cannot report its decimal precision.
    /// @param quoteToken Rejected quote-token contract.
    error UnsupportedQuoteToken(address quoteToken);

    /// @notice Raised when the quote token does not use the required six-decimal precision.
    /// @param actualDecimals Decimal precision reported by the quote token.
    /// @param requiredDecimals Required decimal precision, exactly six.
    error InvalidQuoteTokenDecimals(uint8 actualDecimals, uint8 requiredDecimals);

    /// @notice Raised when the prize contract does not report ERC-721 interface support.
    /// @param prizeToken Rejected prize-token contract.
    error UnsupportedPrizeToken(address prizeToken);

    /// @notice Raised when a raffle is configured with a zero reserve entry threshold.
    error ZeroReserveEntries();

    /// @notice Raised when the sale end is not strictly after the creation block timestamp.
    /// @param currentTime Current block Unix timestamp, in seconds.
    /// @param endTime Supplied exclusive sale-end Unix timestamp, in seconds.
    error InvalidEndTime(uint256 currentTime, uint256 endTime);

    /// @notice Raised when the prospective sale duration exceeds the fixed 30-day limit.
    /// @param duration Prospective sale duration in seconds.
    /// @param maximumDuration Maximum permitted sale duration in seconds.
    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);

    /// @notice Raised when a configured token or recipient is known protocol plumbing.
    /// @param destination Rejected address.
    error UnsafeProtocolDestination(address destination);

    /// @notice Raised when the exact configured prize is not owned by an active clone after escrow.
    /// @param raffle Newly created clone expected to hold the prize and report `Active`.
    /// @param prizeToken ERC-721 prize contract.
    /// @param prizeTokenId Configured prize token ID.
    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);

    // External state-changing functions

    /// @notice Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.
    /// @param params Sponsor-selected recipient, prize, reserve, and timing configuration.
    /// @return raffle Address of the newly created and activated clone.
    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);

    // Public generated getters

    /// @notice Returns the immutable canonical six-decimal USDC contract used by every raffle.
    /// @return quoteTokenAddress Canonical USDC contract address trusted by this deployment.
    function quoteToken() external view returns (address quoteTokenAddress);

    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.
    /// @return wrapperAddress Wrapper contract address.
    function vrfWrapper() external view returns (address wrapperAddress);

    /// @notice Returns the immutable recipient of protocol fees from every raffle.
    /// @return treasuryAddress Protocol treasury address.
    function protocolTreasury() external view returns (address treasuryAddress);

    /// @notice Returns the fixed Chainlink callback execution limit used by every raffle.
    /// @return gasLimit Callback gas units requested from the wrapper.
    function callbackGasLimit() external view returns (uint32 gasLimit);

    /// @notice Returns the fixed Chainlink confirmation count used by every raffle.
    /// @return confirmations Blocks requested before callback fulfillment.
    function requestConfirmations() external view returns (uint16 confirmations);

    /// @notice Returns the immutable implementation targeted by every registered ERC-1167 clone.
    /// @return implementation Locked raffle implementation address.
    function raffleImplementation() external view returns (address implementation);

    /// @notice Returns the lifetime number of successfully created raffles.
    /// @return count Latest one-based raffle identifier and total registered raffle count.
    function raffleCount() external view returns (uint256 count);

    /// @notice Returns whether an address is a raffle registered by this factory.
    /// @param raffle Address to check.
    /// @return registered True only for a successfully created canonical clone.
    function isRaffle(address raffle) external view returns (bool registered);

    /// @notice Returns the canonical raffle address for an identifier.
    /// @param raffleId One-based raffle identifier.
    /// @return raffle Registered clone address, or the zero address for an unknown identifier.
    function raffleById(uint256 raffleId) external view returns (address raffle);

    /// @notice Returns the canonical identifier assigned to a raffle address.
    /// @param raffle Address to query.
    /// @return raffleId One-based identifier, or zero for an unregistered address.
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}

```

### target/packages/contracts/src/libraries/RaffleConstants.sol

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title raffle.fun Protocol Constants
/// @author heesho
/// @notice Defines the fixed v1 economics, timing, and bounded-execution limits shared by the factory and raffles.
/// @dev Quote-token amounts use raw six-decimal units. Basis-point calculations round down through `Math.mulDiv`, and
///      the sponsor receives the remaining raw units after winner and protocol allocations.
/// @custom:version 1.0.0
library RaffleConstants {
    /// @notice Denominator used for every global protocol basis-point rate.
    uint256 internal constant BPS = 10_000;

    /// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
    uint256 internal constant PROTOCOL_FEE_BPS = 500;

    /// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
    uint256 internal constant CASH_WINNER_BPS = 8000;

    /// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
    uint256 internal constant ENTRY_PRICE = 1_000_000;

    /// @notice Decimal precision required from the immutable quote token.
    uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;

    /// @notice Refund execution is bounded by tickets, while each ticket may represent any uint128 entry count.
    uint256 internal constant MAX_REFUND_TICKET_BATCH_SIZE = 100;

    /// @notice Maximum prospective raffle sale duration, measured from creation to the exclusive sale end.
    uint256 internal constant MAX_SALE_DURATION = 30 days;

    /// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
    uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;

    /// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
    uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;

    /// @notice Gas-unit limit requested for the single-word Chainlink callback.
    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 300_000;

    /// @notice Block confirmations requested from Chainlink before callback fulfillment.
    uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 30;
}

```

### target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(
    address owner
  ) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

```

### target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LinkTokenInterface} from "../../shared/interfaces/LinkTokenInterface.sol";
import {IVRFV2PlusWrapper} from "./interfaces/IVRFV2PlusWrapper.sol";

/**
 *
 * @notice Interface for contracts using VRF randomness through the VRF V2 wrapper
 * ********************************************************************************
 * @dev PURPOSE
 *
 * @dev Create VRF V2+ requests without the need for subscription management. Rather than creating
 * @dev and funding a VRF V2+ subscription, a user can use this wrapper to create one off requests,
 * @dev paying up front rather than at fulfillment.
 *
 * @dev Since the price is determined using the gas price of the request transaction rather than
 * @dev the fulfillment transaction, the wrapper charges an additional premium on callback gas
 * @dev usage, in addition to some extra overhead costs associated with the VRFV2Wrapper contract.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFV2PlusWrapperConsumerBase. The consumer must be funded
 * @dev with enough LINK or ether to make the request, otherwise requests will revert. To request randomness,
 * @dev call the 'requestRandomWords' function with the desired VRF parameters. This function handles
 * @dev paying for the request based on the current pricing.
 *
 * @dev Consumers must implement the fullfillRandomWords function, which will be called during
 * @dev fulfillment with the randomness result.
 */
abstract contract VRFV2PlusWrapperConsumerBase {
  error OnlyVRFWrapperCanFulfill(address have, address want);

  LinkTokenInterface internal immutable i_linkToken;
  IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

  /**
   * @param _vrfV2PlusWrapper is the address of the VRFV2Wrapper contract
   */
  constructor(
    address _vrfV2PlusWrapper
  ) {
    IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);

    i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
    i_vrfV2PlusWrapper = vrfV2PlusWrapper;
  }

  /**
   * @dev Requests randomness from the VRF V2+ wrapper.
   *
   * @param _callbackGasLimit is the gas limit that should be used when calling the consumer's
   *        fulfillRandomWords function.
   * @param _requestConfirmations is the number of confirmations to wait before fulfilling the
   *        request. A higher number of confirmations increases security by reducing the likelihood
   *        that a chain re-org changes a published randomness outcome.
   * @param _numWords is the number of random words to request.
   *
   * @return requestId is the VRF V2+ request ID of the newly created randomness request.
   */
  // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
  function requestRandomness(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords,
    bytes memory extraArgs
  ) internal returns (uint256 requestId, uint256 reqPrice) {
    reqPrice = i_vrfV2PlusWrapper.calculateRequestPrice(_callbackGasLimit, _numWords);
    i_linkToken.transferAndCall(
      address(i_vrfV2PlusWrapper), reqPrice, abi.encode(_callbackGasLimit, _requestConfirmations, _numWords, extraArgs)
    );
    return (i_vrfV2PlusWrapper.lastRequestId(), reqPrice);
  }

  // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
  function requestRandomnessPayInNative(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords,
    bytes memory extraArgs
  ) internal returns (uint256 requestId, uint256 requestPrice) {
    requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords);
    return (
      i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(
        _callbackGasLimit, _requestConfirmations, _numWords, extraArgs
      ),
      requestPrice
    );
  }

  /**
   * @notice fulfillRandomWords handles the VRF V2 wrapper response. The consuming contract must
   * @notice implement it.
   *
   * @param _requestId is the VRF V2 request ID.
   * @param _randomWords is the randomness result.
   */
  // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal virtual;

  function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
    address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
    if (msg.sender != vrfWrapperAddr) {
      revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
    }
    fulfillRandomWords(_requestId, _randomWords);
  }

  /// @notice getBalance returns the native balance of the consumer contract
  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }

  /// @notice getLinkToken returns the link token contract
  function getLinkToken() public view returns (LinkTokenInterface) {
    return i_linkToken;
  }
}

```

### target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVRFV2PlusWrapper {
  /**
   * @return the request ID of the most recent VRF V2 request made by this wrapper. This should only
   * be relied option within the same transaction that the request was made.
   */
  function lastRequestId() external view returns (uint256);

  /**
   * @notice Calculates the price of a VRF request with the given callbackGasLimit at the current
   * @notice block.
   *
   * @dev This function relies on the transaction gas price which is not automatically set during
   * @dev simulation. To estimate the price at a specific gas price, use the estimatePrice function.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   * @param _numWords is the number of words to request.
   */
  function calculateRequestPrice(uint32 _callbackGasLimit, uint32 _numWords) external view returns (uint256);

  /**
   * @notice Calculates the price of a VRF request in native with the given callbackGasLimit at the current
   * @notice block.
   *
   * @dev This function relies on the transaction gas price which is not automatically set during
   * @dev simulation. To estimate the price at a specific gas price, use the estimatePrice function.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   * @param _numWords is the number of words to request.
   */
  function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords) external view returns (uint256);

  /**
   * @notice Estimates the price of a VRF request with a specific gas limit and gas price.
   *
   * @dev This is a convenience function that can be called in simulation to better understand
   * @dev pricing.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   * @param _numWords is the number of words to request.
   * @param _requestGasPriceWei is the gas price in wei used for the estimation.
   */
  function estimateRequestPrice(
    uint32 _callbackGasLimit,
    uint32 _numWords,
    uint256 _requestGasPriceWei
  ) external view returns (uint256);

  /**
   * @notice Estimates the price of a VRF request in native with a specific gas limit and gas price.
   *
   * @dev This is a convenience function that can be called in simulation to better understand
   * @dev pricing.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   * @param _numWords is the number of words to request.
   * @param _requestGasPriceWei is the gas price in wei used for the estimation.
   */
  function estimateRequestPriceNative(
    uint32 _callbackGasLimit,
    uint32 _numWords,
    uint256 _requestGasPriceWei
  ) external view returns (uint256);

  /**
   * @notice Requests randomness from the VRF V2 wrapper, paying in native token.
   *
   * @param _callbackGasLimit is the gas limit for the request.
   * @param _requestConfirmations number of request confirmations to wait before serving a request.
   * @param _numWords is the number of words to request.
   */
  function requestRandomWordsInNative(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords,
    bytes calldata extraArgs
  ) external payable returns (uint256 requestId);

  function link() external view returns (address);
  function linkNativeFeed() external view returns (address);
}

```

### target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// End consumer library.
library VRFV2PlusClient {
  // extraArgs will evolve to support new features
  bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

  struct ExtraArgsV1 {
    bool nativePayment;
  }

  struct RandomWordsRequest {
    bytes32 keyHash;
    uint256 subId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    bytes extraArgs;
  }

  function _argsToBytes(
    ExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;

import {IERC165} from "../utils/introspection/IERC165.sol";

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;

import {IERC20} from "../token/ERC20/IERC20.sol";

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (interfaces/draft-IERC6093.sol)

pragma solidity >=0.8.4;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-721.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (proxy/Clones.sol)

pragma solidity ^0.8.20;

import {Create2} from "../utils/Create2.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[ERC-1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 */
library Clones {
    error CloneArgumentsTooLong();

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     */
    function clone(address implementation) internal returns (address instance) {
        return clone(implementation, 0);
    }

    /**
     * @dev Same as {xref-Clones-clone-address-}[clone], but with a `value` parameter to send native currency
     * to the new contract.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(232, shl(96, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(120, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(value, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple times will revert, since
     * the clones cannot be deployed twice at the same address.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministic-address-bytes32-}[cloneDeterministic], but with
     * a `value` parameter to send native currency to the new contract.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(232, shl(96, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(120, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create opcode, which should never revert.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args) internal returns (address instance) {
        return cloneWithImmutableArgs(implementation, args, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneWithImmutableArgs-address-bytes-}[cloneWithImmutableArgs], but with a `value`
     * parameter to send native currency to the new contract.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneWithImmutableArgs(
        address implementation,
        bytes memory args,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        assembly ("memory-safe") {
            instance := create(value, add(bytecode, 0x20), mload(bytecode))
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy the clone. Using the same
     * `implementation`, `args` and `salt` multiple times will revert, since the clones cannot be deployed twice
     * at the same address.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        return cloneDeterministicWithImmutableArgs(implementation, args, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministicWithImmutableArgs-address-bytes-bytes32-}[cloneDeterministicWithImmutableArgs],
     * but with a `value` parameter to send native currency to the new contract.
     *
     * WARNING: This function does not check if `implementation` has code. A clone that points to an address
     * without code cannot be initialized. Initialization calls may appear to be successful when, in reality, they
     * have no effect and leave the clone uninitialized, allowing a third party to initialize it later.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.deploy(value, salt, bytecode);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    /**
     * @dev Get the immutable args attached to a clone.
     *
     * - If `instance` is a clone that was deployed using `clone` or `cloneDeterministic`, this
     *   function will return an empty array.
     * - If `instance` is a clone that was deployed using `cloneWithImmutableArgs` or
     *   `cloneDeterministicWithImmutableArgs`, this function will return the args array used at
     *   creation.
     * - If `instance` is NOT a clone deployed using this library, the behavior is undefined. This
     *   function should only be used to check addresses that are known to be clones.
     */
    function fetchCloneArgs(address instance) internal view returns (bytes memory) {
        bytes memory result = new bytes(instance.code.length - 0x2d); // revert if length is too short
        assembly ("memory-safe") {
            extcodecopy(instance, add(result, 0x20), 0x2d, mload(result))
        }
        return result;
    }

    /**
     * @dev Helper that prepares the initcode of the proxy with immutable args.
     *
     * An assembly variant of this function requires copying the `args` array, which can be efficiently done using
     * `mcopy`. Unfortunately, that opcode is not available before cancun. A pure solidity implementation using
     * abi.encodePacked is more expensive but also more portable and easier to review.
     *
     * NOTE: https://eips.ethereum.org/EIPS/eip-170[EIP-170] limits the length of the contract code to 24576 bytes.
     * With the proxy code taking 45 bytes, that limits the length of the immutable args to 24531 bytes.
     */
    function _cloneCodeWithImmutableArgs(
        address implementation,
        bytes memory args
    ) private pure returns (bytes memory) {
        if (args.length > 0x5fd3) revert CloneArgumentsTooLong();
        return
            abi.encodePacked(
                hex"61",
                uint16(args.length + 0x2d),
                hex"3d81600a3d39f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3",
                args
            );
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity >=0.6.2;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Oppositely, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity `token.transfer(to, value)` call, relaxing the requirement on the return value: the
     * return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev Imitates a Solidity `token.transferFrom(from, to, value)` call, relaxing the requirement on the return
     * value: the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param from The sender of the tokens
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    /**
     * @dev Imitates a Solidity `token.approve(spender, value)` call, relaxing the requirement on the return value:
     * the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param spender The spender of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.24;

import {IERC721} from "./IERC721.sol";
import {IERC721Metadata} from "./extensions/IERC721Metadata.sol";
import {ERC721Utils} from "./utils/ERC721Utils.sol";
import {Context} from "../../utils/Context.sol";
import {Strings} from "../../utils/Strings.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {IERC721Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC-721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC-721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if:
     * - `spender` does not have approval from `owner` for `tokenId`.
     * - `spender` does not have approval to manage all of `owner`'s assets.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC-721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (owner == address(0)) {
            revert ERC721InvalidApprover(address(0));
        }
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC-721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity >=0.5.0;

/**
 * @title ERC-721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC-721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity >=0.6.2;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC721/utils/ERC721Utils.sol)

pragma solidity ^0.8.20;

import {IERC721Receiver} from "../IERC721Receiver.sol";
import {IERC721Errors} from "../../../interfaces/draft-IERC6093.sol";

/**
 * @dev Library that provides common ERC-721 utility functions.
 *
 * See https://eips.ethereum.org/EIPS/eip-721[ERC-721].
 *
 * _Available since v5.1._
 */
library ERC721Utils {
    /**
     * @dev Performs an acceptance check for the provided `operator` by calling {IERC721Receiver-onERC721Received}
     * on the `to` address. The `operator` is generally the address that initiated the token transfer (i.e. `msg.sender`).
     *
     * The acceptance call is not executed and treated as a no-op if the target address doesn't contain code (i.e. an EOA).
     * Otherwise, the recipient must implement {IERC721Receiver-onERC721Received} and return the acceptance magic value to accept
     * the transfer.
     */
    function checkOnERC721Received(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    // Token rejected
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-IERC721Receiver implementer
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/Bytes.sol)

pragma solidity ^0.8.24;

import {Math} from "./math/Math.sol";

/**
 * @dev Bytes operations.
 */
library Bytes {
    /**
     * @dev Forward search for `s` in `buffer`
     * * If `s` is present in the buffer, returns the index of the first instance
     * * If `s` is not present in the buffer, returns type(uint256).max
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/indexOf[Javascript's `Array.indexOf`]
     */
    function indexOf(bytes memory buffer, bytes1 s) internal pure returns (uint256) {
        return indexOf(buffer, s, 0);
    }

    /**
     * @dev Forward search for `s` in `buffer` starting at position `pos`
     * * If `s` is present in the buffer (at or after `pos`), returns the index of the next instance
     * * If `s` is not present in the buffer (at or after `pos`), returns type(uint256).max
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/indexOf[Javascript's `Array.indexOf`]
     */
    function indexOf(bytes memory buffer, bytes1 s, uint256 pos) internal pure returns (uint256) {
        uint256 length = buffer.length;
        for (uint256 i = pos; i < length; ++i) {
            if (bytes1(_unsafeReadBytesOffset(buffer, i)) == s) {
                return i;
            }
        }
        return type(uint256).max;
    }

    /**
     * @dev Backward search for `s` in `buffer`
     * * If `s` is present in the buffer, returns the index of the last instance
     * * If `s` is not present in the buffer, returns type(uint256).max
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/lastIndexOf[Javascript's `Array.lastIndexOf`]
     */
    function lastIndexOf(bytes memory buffer, bytes1 s) internal pure returns (uint256) {
        return lastIndexOf(buffer, s, type(uint256).max);
    }

    /**
     * @dev Backward search for `s` in `buffer` starting at position `pos`
     * * If `s` is present in the buffer (at or before `pos`), returns the index of the previous instance
     * * If `s` is not present in the buffer (at or before `pos`), returns type(uint256).max
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/lastIndexOf[Javascript's `Array.lastIndexOf`]
     */
    function lastIndexOf(bytes memory buffer, bytes1 s, uint256 pos) internal pure returns (uint256) {
        unchecked {
            uint256 length = buffer.length;
            for (uint256 i = Math.min(Math.saturatingAdd(pos, 1), length); i > 0; --i) {
                if (bytes1(_unsafeReadBytesOffset(buffer, i - 1)) == s) {
                    return i - 1;
                }
            }
            return type(uint256).max;
        }
    }

    /**
     * @dev Copies the content of `buffer`, from `start` (included) to the end of `buffer` into a new bytes object in
     * memory.
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/slice[Javascript's `Array.slice`]
     */
    function slice(bytes memory buffer, uint256 start) internal pure returns (bytes memory) {
        return slice(buffer, start, buffer.length);
    }

    /**
     * @dev Copies the content of `buffer`, from `start` (included) to `end` (excluded) into a new bytes object in
     * memory. The `end` argument is truncated to the length of the `buffer`.
     *
     * NOTE: replicates the behavior of https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/slice[Javascript's `Array.slice`]
     */
    function slice(bytes memory buffer, uint256 start, uint256 end) internal pure returns (bytes memory) {
        // sanitize
        end = Math.min(end, buffer.length);
        start = Math.min(start, end);

        // allocate and copy
        bytes memory result = new bytes(end - start);
        assembly ("memory-safe") {
            mcopy(add(result, 0x20), add(add(buffer, 0x20), start), sub(end, start))
        }

        return result;
    }

    /**
     * @dev Moves the content of `buffer`, from `start` (included) to the end of `buffer` to the start of that buffer,
     * and shrinks the buffer length accordingly, effectively overriding the content of buffer with buffer[start:].
     *
     * NOTE: This function modifies the provided buffer in place. If you need to preserve the original buffer, use {slice} instead
     */
    function splice(bytes memory buffer, uint256 start) internal pure returns (bytes memory) {
        return splice(buffer, start, buffer.length);
    }

    /**
     * @dev Moves the content of `buffer`, from `start` (included) to `end` (excluded) to the start of that buffer,
     * and shrinks the buffer length accordingly, effectively overriding the content of buffer with buffer[start:end].
     * The `end` argument is truncated to the length of the `buffer`.
     *
     * NOTE: This function modifies the provided buffer in place. If you need to preserve the original buffer, use {slice} instead
     */
    function splice(bytes memory buffer, uint256 start, uint256 end) internal pure returns (bytes memory) {
        // sanitize
        end = Math.min(end, buffer.length);
        start = Math.min(start, end);

        // move and resize
        assembly ("memory-safe") {
            mcopy(add(buffer, 0x20), add(add(buffer, 0x20), start), sub(end, start))
            mstore(buffer, sub(end, start))
        }

        return buffer;
    }

    /**
     * @dev Replaces bytes in `buffer` starting at `pos` with all bytes from `replacement`.
     *
     * Parameters are clamped to valid ranges (i.e. `pos` is clamped to `[0, buffer.length]`).
     * If `pos >= buffer.length`, no replacement occurs and the buffer is returned unchanged.
     *
     * NOTE: This function modifies the provided buffer in place.
     */
    function replace(bytes memory buffer, uint256 pos, bytes memory replacement) internal pure returns (bytes memory) {
        return replace(buffer, pos, replacement, 0, replacement.length);
    }

    /**
     * @dev Replaces bytes in `buffer` starting at `pos` with bytes from `replacement` starting at `offset`.
     * Copies at most `length` bytes from `replacement` to `buffer`.
     *
     * Parameters are clamped to valid ranges (i.e. `pos` is clamped to `[0, buffer.length]`, `offset` is
     * clamped to `[0, replacement.length]`, and `length` is clamped to `min(length, replacement.length - offset,
     * buffer.length - pos))`. If `pos >= buffer.length` or `offset >= replacement.length`, no replacement occurs
     * and the buffer is returned unchanged.
     *
     * NOTE: This function modifies the provided buffer in place.
     */
    function replace(
        bytes memory buffer,
        uint256 pos,
        bytes memory replacement,
        uint256 offset,
        uint256 length
    ) internal pure returns (bytes memory) {
        // sanitize
        pos = Math.min(pos, buffer.length);
        offset = Math.min(offset, replacement.length);
        length = Math.min(length, Math.min(replacement.length - offset, buffer.length - pos));

        // replace
        assembly ("memory-safe") {
            mcopy(add(add(buffer, 0x20), pos), add(add(replacement, 0x20), offset), length)
        }

        return buffer;
    }

    /**
     * @dev Concatenate an array of bytes into a single bytes object.
     *
     * For fixed bytes types, we recommend using the solidity built-in `bytes.concat` or (equivalent)
     * `abi.encodePacked`.
     *
     * NOTE: this could be done in assembly with a single loop that expands starting at the FMP, but that would be
     * significantly less readable. It might be worth benchmarking the savings of the full-assembly approach.
     */
    function concat(bytes[] memory buffers) internal pure returns (bytes memory) {
        uint256 length = 0;
        for (uint256 i = 0; i < buffers.length; ++i) {
            length += buffers[i].length;
        }

        bytes memory result = new bytes(length);

        uint256 offset = 0x20;
        for (uint256 i = 0; i < buffers.length; ++i) {
            bytes memory input = buffers[i];
            assembly ("memory-safe") {
                mcopy(add(result, offset), add(input, 0x20), mload(input))
            }
            unchecked {
                offset += input.length;
            }
        }

        return result;
    }

    /**
     * @dev Split each byte in `input` into two nibbles (4 bits each)
     *
     * Example: hex"01234567" → hex"0001020304050607"
     */
    function toNibbles(bytes memory input) internal pure returns (bytes memory output) {
        assembly ("memory-safe") {
            let length := mload(input)
            output := mload(0x40)
            mstore(0x40, add(add(output, 0x20), mul(length, 2)))
            mstore(output, mul(length, 2))
            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 0x10)
            } {
                let chunk := shr(128, mload(add(add(input, 0x20), i)))
                chunk := and(
                    0x0000000000000000ffffffffffffffff0000000000000000ffffffffffffffff,
                    or(shl(64, chunk), chunk)
                )
                chunk := and(
                    0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff,
                    or(shl(32, chunk), chunk)
                )
                chunk := and(
                    0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff,
                    or(shl(16, chunk), chunk)
                )
                chunk := and(
                    0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff,
                    or(shl(8, chunk), chunk)
                )
                chunk := and(
                    0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f,
                    or(shl(4, chunk), chunk)
                )
                mstore(add(add(output, 0x20), mul(i, 2)), chunk)
            }
        }
    }

    /**
     * @dev Returns true if the two byte buffers are equal.
     */
    function equal(bytes memory a, bytes memory b) internal pure returns (bool) {
        return a.length == b.length && keccak256(a) == keccak256(b);
    }

    /**
     * @dev Reverses the byte order of a bytes32 value, converting between little-endian and big-endian.
     * Inspired by https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel[Reverse Parallel]
     */
    function reverseBytes32(bytes32 value) internal pure returns (bytes32) {
        value = // swap bytes
            ((value >> 8) & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) |
            ((value & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        value = // swap 2-byte long pairs
            ((value >> 16) & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) |
            ((value & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        value = // swap 4-byte long pairs
            ((value >> 32) & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) |
            ((value & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        value = // swap 8-byte long pairs
            ((value >> 64) & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) |
            ((value & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        return (value >> 128) | (value << 128); // swap 16-byte long pairs
    }

    /// @dev Same as {reverseBytes32} but optimized for 128-bit values.
    function reverseBytes16(bytes16 value) internal pure returns (bytes16) {
        value = // swap bytes
            ((value & 0xFF00FF00FF00FF00FF00FF00FF00FF00) >> 8) |
            ((value & 0x00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        value = // swap 2-byte long pairs
            ((value & 0xFFFF0000FFFF0000FFFF0000FFFF0000) >> 16) |
            ((value & 0x0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        value = // swap 4-byte long pairs
            ((value & 0xFFFFFFFF00000000FFFFFFFF00000000) >> 32) |
            ((value & 0x00000000FFFFFFFF00000000FFFFFFFF) << 32);
        return (value >> 64) | (value << 64); // swap 8-byte long pairs
    }

    /// @dev Same as {reverseBytes32} but optimized for 64-bit values.
    function reverseBytes8(bytes8 value) internal pure returns (bytes8) {
        value = ((value & 0xFF00FF00FF00FF00) >> 8) | ((value & 0x00FF00FF00FF00FF) << 8); // swap bytes
        value = ((value & 0xFFFF0000FFFF0000) >> 16) | ((value & 0x0000FFFF0000FFFF) << 16); // swap 2-byte long pairs
        return (value >> 32) | (value << 32); // swap 4-byte long pairs
    }

    /// @dev Same as {reverseBytes32} but optimized for 32-bit values.
    function reverseBytes4(bytes4 value) internal pure returns (bytes4) {
        value = ((value & 0xFF00FF00) >> 8) | ((value & 0x00FF00FF) << 8); // swap bytes
        return (value >> 16) | (value << 16); // swap 2-byte long pairs
    }

    /// @dev Same as {reverseBytes32} but optimized for 16-bit values.
    function reverseBytes2(bytes2 value) internal pure returns (bytes2) {
        return (value >> 8) | (value << 8);
    }

    /**
     * @dev Counts the number of leading zero bits a bytes array. Returns `8 * buffer.length`
     * if the buffer is all zeros.
     */
    function clz(bytes memory buffer) internal pure returns (uint256) {
        for (uint256 i = 0; i < buffer.length; i += 0x20) {
            bytes32 chunk = _unsafeReadBytesOffset(buffer, i);
            if (chunk != bytes32(0)) {
                return Math.min(8 * i + Math.clz(uint256(chunk)), 8 * buffer.length);
            }
        }
        return 8 * buffer.length;
    }

    /**
     * @dev Reads a bytes32 from a bytes array without bounds checking.
     *
     * NOTE: making this function internal would mean it could be used with memory unsafe offset, and marking the
     * assembly block as such would prevent some optimizations.
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        // This is not memory safe in the general case, but all calls to this private function are within bounds.
        assembly ("memory-safe") {
            value := mload(add(add(buffer, 0x20), offset))
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/Create2.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";
import {LowLevelCall} from "./LowLevelCall.sol";

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev There's no code to deploy.
     */
    error Create2EmptyBytecode();

    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        assembly ("memory-safe") {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (addr == address(0)) {
            if (LowLevelCall.returnDataSize() == 0) {
                revert Errors.FailedDeployment();
            } else {
                LowLevelCall.bubbleRevert();
            }
        }
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Get free memory pointer

            // |                     | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |---------------------|---------------------------------------------------------------------------|
            // | bytecodeHash        |                                                        CCCCCCCCCCCCC...CC |
            // | salt                |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer            | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF                |            FF                                                             |
            // |---------------------|---------------------------------------------------------------------------|
            // | memory              | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 0x55) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := and(keccak256(start, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/LowLevelCall.sol)

pragma solidity ^0.8.20;

/**
 * @dev Library of low level call functions that implement different calling strategies to deal with the return data.
 *
 * WARNING: Using this library requires an advanced understanding of Solidity and how the EVM works. It is recommended
 * to use the {Address} library instead.
 */
library LowLevelCall {
    /// @dev Performs a Solidity function call using a low level `call` and ignoring the return data.
    function callNoReturn(address target, bytes memory data) internal returns (bool success) {
        return callNoReturn(target, 0, data);
    }

    /// @dev Same as {callNoReturn-address-bytes}, but allows specifying the value to be sent in the call.
    function callNoReturn(address target, uint256 value, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `call` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function callReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        return callReturn64Bytes(target, 0, data);
    }

    /// @dev Same as {callReturn64Bytes-address-bytes}, but allows specifying the value to be sent in the call.
    function callReturn64Bytes(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and ignoring the return data.
    function staticcallNoReturn(address target, bytes memory data) internal view returns (bool success) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function staticcallReturn64Bytes(
        address target,
        bytes memory data
    ) internal view returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and ignoring the return data.
    function delegatecallNoReturn(address target, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function delegatecallReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Returns the size of the return data buffer.
    function returnDataSize() internal pure returns (uint256 size) {
        assembly ("memory-safe") {
            size := returndatasize()
        }
    }

    /// @dev Returns a buffer containing the return data from the last call.
    function returnData() internal pure returns (bytes memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, returndatasize())
            returndatacopy(add(result, 0x20), 0x00, returndatasize())
            mstore(0x40, add(result, add(0x20, returndatasize())))
        }
    }

    /// @dev Revert with the return data from the last call.
    function bubbleRevert() internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            returndatacopy(fmp, 0x00, returndatasize())
            revert(fmp, returndatasize())
        }
    }

    function bubbleRevert(bytes memory returndata) internal pure {
        assembly ("memory-safe") {
            revert(add(returndata, 0x20), mload(returndata))
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

pragma solidity ^0.8.20;

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state
library Panic {
    /// @dev generic / unspecified error
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/Strings.sol)

pragma solidity ^0.8.24;

import {Math} from "./math/Math.sol";
import {SafeCast} from "./math/SafeCast.sol";
import {SignedMath} from "./math/SignedMath.sol";
import {Bytes} from "./Bytes.sol";

/**
 * @dev String operations.
 */
library Strings {
    using SafeCast for *;

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;
    uint256 private constant SPECIAL_CHARS_LOOKUP =
        0xffffffff | // first 32 bits corresponding to the control characters (U+0000 to U+001F)
            (1 << 0x22) | // double quote
            (1 << 0x5c); // backslash

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev The string being parsed contains characters that are not in scope of the given base.
     */
    error StringsInvalidChar();

    /**
     * @dev The string being parsed is not a properly formatted address.
     */
    error StringsInvalidAddressFormat();

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly ("memory-safe") {
                ptr := add(add(buffer, 0x20), length)
            }
            while (true) {
                ptr--;
                assembly ("memory-safe") {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its checksummed ASCII `string` hexadecimal
     * representation, according to EIP-55.
     */
    function toChecksumHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = bytes(toHexString(addr));

        // hash the hex part of buffer (skip length + 2 bytes, length 40)
        uint256 hashValue;
        assembly ("memory-safe") {
            hashValue := shr(96, keccak256(add(buffer, 0x22), 40))
        }

        for (uint256 i = 41; i > 1; --i) {
            // possible values for buffer[i] are 48 (0) to 57 (9) and 97 (a) to 102 (f)
            if (hashValue & 0xf > 7 && uint8(buffer[i]) > 96) {
                // case shift by xoring with 0x20
                buffer[i] ^= 0x20;
            }
            hashValue >>= 4;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `bytes` buffer to its ASCII `string` hexadecimal representation.
     */
    function toHexString(bytes memory input) internal pure returns (string memory) {
        unchecked {
            bytes memory buffer = new bytes(2 * input.length + 2);
            buffer[0] = "0";
            buffer[1] = "x";
            for (uint256 i = 0; i < input.length; ++i) {
                uint8 v = uint8(input[i]);
                buffer[2 * i + 2] = HEX_DIGITS[v >> 4];
                buffer[2 * i + 3] = HEX_DIGITS[v & 0xf];
            }
            return string(buffer);
        }
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return Bytes.equal(bytes(a), bytes(b));
    }

    /**
     * @dev Parse a decimal string and returns the value as a `uint256`.
     *
     * Requirements:
     * - The string must be formatted as `[0-9]*`
     * - The result must fit into an `uint256` type
     */
    function parseUint(string memory input) internal pure returns (uint256) {
        return parseUint(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseUint-string} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `[0-9]*`
     * - The result must fit into an `uint256` type
     */
    function parseUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseUint-string} that returns false if the parsing fails because of an invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseUint(string memory input) internal pure returns (bool success, uint256 value) {
        return _tryParseUintUncheckedBounds(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseUint-string-uint256-uint256} that returns false if the parsing fails because of an invalid
     * character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseUint(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseUintUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Implementation of {tryParseUint-string-uint256-uint256} that does not check bounds. Caller should make sure that
     * `begin <= end <= input.length`. Other inputs would result in undefined behavior.
     */
    function _tryParseUintUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);

        uint256 result = 0;
        for (uint256 i = begin; i < end; ++i) {
            uint8 chr = _tryParseChr(bytes1(_unsafeReadBytesOffset(buffer, i)));
            if (chr > 9) return (false, 0);
            result *= 10;
            result += chr;
        }
        return (true, result);
    }

    /**
     * @dev Parse a decimal string and returns the value as a `int256`.
     *
     * Requirements:
     * - The string must be formatted as `[-+]?[0-9]*`
     * - The result must fit in an `int256` type.
     */
    function parseInt(string memory input) internal pure returns (int256) {
        return parseInt(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseInt-string} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `[-+]?[0-9]*`
     * - The result must fit in an `int256` type.
     */
    function parseInt(string memory input, uint256 begin, uint256 end) internal pure returns (int256) {
        (bool success, int256 value) = tryParseInt(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseInt-string} that returns false if the parsing fails because of an invalid character or if
     * the result does not fit in a `int256`.
     *
     * NOTE: This function will revert if the absolute value of the result does not fit in a `uint256`.
     */
    function tryParseInt(string memory input) internal pure returns (bool success, int256 value) {
        return _tryParseIntUncheckedBounds(input, 0, bytes(input).length);
    }

    uint256 private constant ABS_MIN_INT256 = 2 ** 255;

    /**
     * @dev Variant of {parseInt-string-uint256-uint256} that returns false if the parsing fails because of an invalid
     * character or if the result does not fit in a `int256`.
     *
     * NOTE: This function will revert if the absolute value of the result does not fit in a `uint256`.
     */
    function tryParseInt(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, int256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseIntUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Implementation of {tryParseInt-string-uint256-uint256} that does not check bounds. Caller should make sure that
     * `begin <= end <= input.length`. Other inputs would result in undefined behavior.
     */
    function _tryParseIntUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, int256 value) {
        bytes memory buffer = bytes(input);

        // Check presence of a negative sign.
        bytes1 sign = begin == end ? bytes1(0) : bytes1(_unsafeReadBytesOffset(buffer, begin)); // don't do out-of-bound (possibly unsafe) read if sub-string is empty
        bool positiveSign = sign == bytes1("+");
        bool negativeSign = sign == bytes1("-");
        uint256 offset = (positiveSign || negativeSign).toUint();

        (bool absSuccess, uint256 absValue) = tryParseUint(input, begin + offset, end);

        if (absSuccess && absValue < ABS_MIN_INT256) {
            return (true, negativeSign ? -int256(absValue) : int256(absValue));
        } else if (absSuccess && negativeSign && absValue == ABS_MIN_INT256) {
            return (true, type(int256).min);
        } else return (false, 0);
    }

    /**
     * @dev Parse a hexadecimal string (with or without "0x" prefix), and returns the value as a `uint256`.
     *
     * Requirements:
     * - The string must be formatted as `(0x)?[0-9a-fA-F]*`
     * - The result must fit in an `uint256` type.
     */
    function parseHexUint(string memory input) internal pure returns (uint256) {
        return parseHexUint(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseHexUint-string} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `(0x)?[0-9a-fA-F]*`
     * - The result must fit in an `uint256` type.
     */
    function parseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseHexUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseHexUint-string} that returns false if the parsing fails because of an invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseHexUint(string memory input) internal pure returns (bool success, uint256 value) {
        return _tryParseHexUintUncheckedBounds(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseHexUint-string-uint256-uint256} that returns false if the parsing fails because of an
     * invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseHexUint(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseHexUintUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Implementation of {tryParseHexUint-string-uint256-uint256} that does not check bounds. Caller should make sure that
     * `begin <= end <= input.length`. Other inputs would result in undefined behavior.
     */
    function _tryParseHexUintUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);

        // skip 0x prefix if present
        bool hasPrefix = (end > begin + 1) && bytes2(_unsafeReadBytesOffset(buffer, begin)) == bytes2("0x"); // don't do out-of-bound (possibly unsafe) read if sub-string is empty
        uint256 offset = hasPrefix.toUint() * 2;

        uint256 result = 0;
        for (uint256 i = begin + offset; i < end; ++i) {
            uint8 chr = _tryParseChr(bytes1(_unsafeReadBytesOffset(buffer, i)));
            if (chr > 15) return (false, 0);
            result *= 16;
            unchecked {
                // Multiplying by 16 is equivalent to a shift of 4 bits (with additional overflow check).
                // This guarantees that adding a value < 16 will not cause an overflow, hence the unchecked.
                result += chr;
            }
        }
        return (true, result);
    }

    /**
     * @dev Parse a hexadecimal string (with or without "0x" prefix), and returns the value as an `address`.
     *
     * Requirements:
     * - The string must be formatted as `(0x)?[0-9a-fA-F]{40}`
     */
    function parseAddress(string memory input) internal pure returns (address) {
        return parseAddress(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseAddress-string} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `(0x)?[0-9a-fA-F]{40}`
     */
    function parseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (address) {
        (bool success, address value) = tryParseAddress(input, begin, end);
        if (!success) revert StringsInvalidAddressFormat();
        return value;
    }

    /**
     * @dev Variant of {parseAddress-string} that returns false if the parsing fails because the input is not a properly
     * formatted address. See {parseAddress-string} requirements.
     */
    function tryParseAddress(string memory input) internal pure returns (bool success, address value) {
        return tryParseAddress(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseAddress-string-uint256-uint256} that returns false if the parsing fails because input is not a properly
     * formatted address. See {parseAddress-string-uint256-uint256} requirements.
     */
    function tryParseAddress(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, address value) {
        if (end > bytes(input).length || begin > end) return (false, address(0));

        bool hasPrefix = (end > begin + 1) && bytes2(_unsafeReadBytesOffset(bytes(input), begin)) == bytes2("0x"); // don't do out-of-bound (possibly unsafe) read if sub-string is empty
        uint256 expectedLength = 40 + hasPrefix.toUint() * 2;

        // check that input is the correct length
        if (end - begin == expectedLength) {
            // length guarantees that this does not overflow, and value is at most type(uint160).max
            (bool s, uint256 v) = _tryParseHexUintUncheckedBounds(input, begin, end);
            return (s, address(uint160(v)));
        } else {
            return (false, address(0));
        }
    }

    function _tryParseChr(bytes1 chr) private pure returns (uint8) {
        uint8 value = uint8(chr);

        // Try to parse `chr`:
        // - Case 1: [0-9]
        // - Case 2: [a-f]
        // - Case 3: [A-F]
        // - otherwise not supported
        unchecked {
            if (value > 47 && value < 58) value -= 48;
            else if (value > 96 && value < 103) value -= 87;
            else if (value > 64 && value < 71) value -= 55;
            else return type(uint8).max;
        }

        return value;
    }

    /**
     * @dev Escape special characters in JSON strings. This can be useful to prevent JSON injection in NFT metadata.
     *
     * WARNING: This function should only be used in double quoted JSON strings. Single quotes are not escaped.
     *
     * NOTE: This function escapes backslashes (including those in \uXXXX sequences) and the characters in ranges
     * defined in section 2.5 of RFC-4627 (U+0000 to U+001F, U+0022 and U+005C). All control characters in U+0000
     * to U+001F are escaped (\b, \t, \n, \f, \r use short form; others use \u00XX). ECMAScript's `JSON.parse` does
     * recover escaped unicode characters that are not in this range, but other tooling may provide different results.
     */
    function escapeJSON(string memory input) internal pure returns (string memory) {
        bytes memory buffer = bytes(input);

        // Put output at the FMP. Memory will be reserved later when we figure out the actual length of the escaped
        // string. All write are done using _unsafeWriteBytesOffset, which avoid the (expensive) length checks for
        // each character written.
        bytes memory output;
        assembly ("memory-safe") {
            output := mload(0x40)
        }
        uint256 outputLength = 0;

        for (uint256 i = 0; i < buffer.length; ++i) {
            uint8 char = uint8(bytes1(_unsafeReadBytesOffset(buffer, i)));
            if (((SPECIAL_CHARS_LOOKUP & (1 << char)) != 0)) {
                _unsafeWriteBytesOffset(output, outputLength++, "\\");
                if (char == 0x08) _unsafeWriteBytesOffset(output, outputLength++, "b");
                else if (char == 0x09) _unsafeWriteBytesOffset(output, outputLength++, "t");
                else if (char == 0x0a) _unsafeWriteBytesOffset(output, outputLength++, "n");
                else if (char == 0x0c) _unsafeWriteBytesOffset(output, outputLength++, "f");
                else if (char == 0x0d) _unsafeWriteBytesOffset(output, outputLength++, "r");
                else if (char == 0x5c) _unsafeWriteBytesOffset(output, outputLength++, "\\");
                else if (char == 0x22) {
                    // solhint-disable-next-line quotes
                    _unsafeWriteBytesOffset(output, outputLength++, '"');
                } else {
                    // U+0000 to U+001F without short form: output \u00XX
                    _unsafeWriteBytesOffset(output, outputLength++, "u");
                    _unsafeWriteBytesOffset(output, outputLength++, "0");
                    _unsafeWriteBytesOffset(output, outputLength++, "0");
                    _unsafeWriteBytesOffset(output, outputLength++, HEX_DIGITS[char >> 4]);
                    _unsafeWriteBytesOffset(output, outputLength++, HEX_DIGITS[char & 0x0f]);
                }
            } else {
                _unsafeWriteBytesOffset(output, outputLength++, bytes1(char));
            }
        }
        // write the actual length and reserve memory
        assembly ("memory-safe") {
            mstore(output, outputLength)
            mstore(0x40, add(output, add(outputLength, 0x20)))
        }

        return string(output);
    }

    /**
     * @dev Reads a bytes32 from a bytes array without bounds checking.
     *
     * NOTE: making this function internal would mean it could be used with memory unsafe offset, and marking the
     * assembly block as such would prevent some optimizations.
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        // This is not memory safe in the general case, but all calls to this private function are within bounds.
        assembly ("memory-safe") {
            value := mload(add(add(buffer, 0x20), offset))
        }
    }

    /**
     * @dev Write a bytes1 to a bytes array without bounds checking.
     *
     * NOTE: making this function internal would mean it could be used with memory unsafe offset, and marking the
     * assembly block as such would prevent some optimizations.
     */
    function _unsafeWriteBytesOffset(bytes memory buffer, uint256 offset, bytes1 value) private pure {
        // This is not memory safe in the general case, but all calls to this private function are within bounds.
        assembly ("memory-safe") {
            mstore8(add(add(buffer, 0x20), offset), shr(248, value))
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

import {Panic} from "../Panic.sol";
import {SafeCast} from "./SafeCast.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Return the 512-bit addition of two uint256.
     *
     * The result is stored in two 256 variables such that sum = high * 2²⁵⁶ + low.
     */
    function add512(uint256 a, uint256 b) internal pure returns (uint256 high, uint256 low) {
        assembly ("memory-safe") {
            low := add(a, b)
            high := lt(low, a)
        }
    }

    /**
     * @dev Return the 512-bit multiplication of two uint256.
     *
     * The result is stored in two 256 variables such that product = high * 2²⁵⁶ + low.
     */
    function mul512(uint256 a, uint256 b) internal pure returns (uint256 high, uint256 low) {
        // 512-bit multiply [high low] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
        // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = high * 2²⁵⁶ + low.
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            low := mul(a, b)
            high := sub(sub(mm, low), lt(mm, low))
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, with a success flag (no overflow).
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            success = c >= a;
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with a success flag (no overflow).
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a - b;
            success = c <= a;
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with a success flag (no overflow).
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a * b;
            assembly ("memory-safe") {
                // Only true when the multiplication doesn't overflow
                // (c / a == b) || (a == 0)
                success := or(eq(div(c, a), b), iszero(a))
            }
            // equivalent to: success ? c : 0
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            success = b > 0;
            assembly ("memory-safe") {
                // The `DIV` opcode returns zero when the denominator is 0.
                result := div(a, b)
            }
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a success flag (no division by zero).
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            success = b > 0;
            assembly ("memory-safe") {
                // The `MOD` opcode returns zero when the denominator is 0.
                result := mod(a, b)
            }
        }
    }

    /**
     * @dev Unsigned saturating addition, bounds to `2²⁵⁶ - 1` instead of overflowing.
     */
    function saturatingAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 result) = tryAdd(a, b);
        return ternary(success, result, type(uint256).max);
    }

    /**
     * @dev Unsigned saturating subtraction, bounds to zero instead of overflowing.
     */
    function saturatingSub(uint256 a, uint256 b) internal pure returns (uint256) {
        (, uint256 result) = trySub(a, b);
        return result;
    }

    /**
     * @dev Unsigned saturating multiplication, bounds to `2²⁵⁶ - 1` instead of overflowing.
     */
    function saturatingMul(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 result) = tryMul(a, b);
        return ternary(success, result, type(uint256).max);
    }

    /**
     * @dev Branchless ternary evaluation for `condition ? a : b`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `condition ? a : b`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * SafeCast.toUint(condition));
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a < b, a, b);
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // (a + b) / 2 can overflow.
            return (a & b) + (a ^ b) / 2;
        }
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }

        // The following calculation ensures accurate ceiling division without overflow.
        // Since a is non-zero, (a - 1) / b will not overflow.
        // The largest possible result occurs when (a - 1) / b is type(uint256).max,
        // but the largest value we can obtain is type(uint256).max - 1, which happens
        // when a = type(uint256).max and b = 1.
        unchecked {
            return SafeCast.toUint(a > 0) * ((a - 1) / b + 1);
        }
    }

    /**
     * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     *
     * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);

            // Handle non-overflow cases, 256 by 256 division.
            if (high == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return low / denominator;
            }

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= high) {
                Panic.panic(ternary(denominator == 0, Panic.DIVISION_BY_ZERO, Panic.UNDER_OVERFLOW));
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [high low].
            uint256 remainder;
            assembly ("memory-safe") {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                high := sub(high, gt(remainder, low))
                low := sub(low, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly ("memory-safe") {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [high low] by twos.
                low := div(low, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from high into low.
            low |= high * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and high
            // is no longer required.
            result = low * inverse;
            return result;
        }
    }

    /**
     * @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        return mulDiv(x, y, denominator) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
    }

    /**
     * @dev Calculates floor(x * y >> n) with full precision. Throws if result overflows a uint256.
     */
    function mulShr(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 result) {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);
            if (high >= 1 << n) {
                Panic.panic(Panic.UNDER_OVERFLOW);
            }
            return (high << (256 - n)) | (low >> n);
        }
    }

    /**
     * @dev Calculates x * y >> n with full precision, following the selected rounding direction.
     */
    function mulShr(uint256 x, uint256 y, uint8 n, Rounding rounding) internal pure returns (uint256) {
        return mulShr(x, y, n) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, 1 << n) > 0);
    }

    /**
     * @dev Calculate the modular multiplicative inverse of a number in Z/nZ.
     *
     * If n is a prime, then Z/nZ is a field. In that case all elements are inversible, except 0.
     * If n is not a prime, then Z/nZ is not a field, and some elements might not be inversible.
     *
     * If the input value is not inversible, 0 is returned.
     *
     * NOTE: If you know for sure that n is (big) a prime, it may be cheaper to use Fermat's little theorem and get the
     * inverse using `Math.modExp(a, n - 2, n)`. See {invModPrime}.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            // The inverse modulo is calculated using the Extended Euclidean Algorithm (iterative version)
            // Used to compute integers x and y such that: ax + ny = gcd(a, n).
            // When the gcd is 1, then the inverse of a modulo n exists and it's x.
            // ax + ny = 1
            // ax = 1 + (-y)n
            // ax ≡ 1 (mod n) # x is the inverse of a modulo n

            // If the remainder is 0 the gcd is n right away.
            uint256 remainder = a % n;
            uint256 gcd = n;

            // Therefore the initial coefficients are:
            // ax + ny = gcd(a, n) = n
            // 0a + 1n = n
            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (
                    // The old remainder is the next gcd to try.
                    remainder,
                    // Compute the next remainder.
                    // Can't overflow given that (a % gcd) * (gcd // (a % gcd)) <= gcd
                    // where gcd is at most n (capped to type(uint256).max)
                    gcd - remainder * quotient
                );

                (x, y) = (
                    // Increment the coefficient of a.
                    y,
                    // Decrement the coefficient of n.
                    // Can overflow, but the result is casted to uint256 so that the
                    // next value of y is "wrapped around" to a value between 0 and n - 1.
                    x - y * int256(quotient)
                );
            }

            if (gcd != 1) return 0; // No inverse exists.
            return ternary(x < 0, n - uint256(-x), uint256(x)); // Wrap the result if it's negative.
        }
    }

    /**
     * @dev Variant of {invMod}. More efficient, but only works if `p` is known to be a prime greater than `2`.
     *
     * From https://en.wikipedia.org/wiki/Fermat%27s_little_theorem[Fermat's little theorem], we know that if p is
     * prime, then `a**(p-1) ≡ 1 mod p`. As a consequence, we have `a * a**(p-2) ≡ 1 mod p`, which means that
     * `a**(p-2)` is the modular multiplicative inverse of a in Fp.
     *
     * NOTE: this function does NOT check that `p` is a prime greater than `2`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return Math.modExp(a, p - 2, p);
        }
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m)
     *
     * Requirements:
     * - modulus can't be zero
     * - underlying staticcall to precompile must succeed
     *
     * IMPORTANT: The result is only valid if the underlying call succeeds. When using this function, make
     * sure the chain you're using it on supports the precompiled contract for modular exponentiation
     * at address 0x05 as specified in https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise,
     * the underlying function will succeed given the lack of a revert, but the result may be incorrectly
     * interpreted as 0.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m).
     * It includes a success flag indicating if the operation succeeded. Operation will be marked as failed if trying
     * to operate modulo 0 or if the underlying precompile reverted.
     *
     * IMPORTANT: The result is only valid if the success flag is true. When using this function, make sure the chain
     * you're using it on supports the precompiled contract for modular exponentiation at address 0x05 as specified in
     * https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise, the underlying function will succeed given the lack
     * of a revert, but the result may be incorrectly interpreted as 0.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // | Offset    | Content    | Content (Hex)                                                      |
            // |-----------|------------|--------------------------------------------------------------------|
            // | 0x00:0x1f | size of b  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x20:0x3f | size of e  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x40:0x5f | size of m  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x60:0x7f | value of b | 0x<.............................................................b> |
            // | 0x80:0x9f | value of e | 0x<.............................................................e> |
            // | 0xa0:0xbf | value of m | 0x<.............................................................m> |
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)

            // Given the result < m, it's guaranteed to fit in 32 bytes,
            // so we can use the memory scratch space located at offset 0.
            success := staticcall(gas(), 0x05, ptr, 0xc0, 0x00, 0x20)
            result := mload(0x00)
        }
    }

    /**
     * @dev Variant of {modExp} that supports inputs of arbitrary length.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Variant of {tryModExp} that supports inputs of arbitrary length.
     */
    function tryModExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));

        uint256 mLen = m.length;

        // Encode call args in result and move the free memory pointer
        result = abi.encodePacked(b.length, e.length, mLen, b, e, m);

        assembly ("memory-safe") {
            let dataPtr := add(result, 0x20)
            // Write result on top of args to avoid allocating extra memory.
            success := staticcall(gas(), 0x05, dataPtr, mload(result), dataPtr, mLen)
            // Overwrite the length.
            // result.length > returndatasize() is guaranteed because returndatasize() == m.length
            mstore(result, mLen)
            // Set the memory pointer after the returned data.
            mstore(0x40, add(dataPtr, mLen))
        }
    }

    /**
     * @dev Returns whether the provided byte array is zero.
     */
    function _zeroBytes(bytes memory buffer) private pure returns (bool) {
        uint256 chunk;
        for (uint256 i = 0; i < buffer.length; i += 0x20) {
            // See _unsafeReadBytesOffset from utils/Bytes.sol
            assembly ("memory-safe") {
                chunk := mload(add(add(buffer, 0x20), i))
            }
            if (chunk >> (8 * saturatingSub(i + 0x20, buffer.length)) != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * This method is based on Newton's method for computing square roots; the algorithm is restricted to only
     * using integer operations.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }

            // In this function, we use Newton's method to get a root of `f(x) := x² - a`. It involves building a
            // sequence x_n that converges toward sqrt(a). For each iteration x_n, we also define the error between
            // the current value as `ε_n = | x_n - sqrt(a) |`.
            //
            // For our first estimation, we consider `e` the smallest power of 2 which is bigger than the square root
            // of the target. (i.e. `2**(e-1) ≤ sqrt(a) < 2**e`). We know that `e ≤ 128` because `(2¹²⁸)² = 2²⁵⁶` is
            // bigger than any uint256.
            //
            // By noticing that
            // `2**(e-1) ≤ sqrt(a) < 2**e → (2**(e-1))² ≤ a < (2**e)² → 2**(2*e-2) ≤ a < 2**(2*e)`
            // we can deduce that `e - 1` is `log2(a) / 2`. We can thus compute `x_n = 2**(e-1)` using a method similar
            // to the msb function.
            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }

            // We now have x_n such that `x_n = 2**(e-1) ≤ sqrt(a) < 2**e = 2 * x_n`. This implies ε_n ≤ 2**(e-1).
            //
            // We can refine our estimation by noticing that the middle of that interval minimizes the error.
            // If we move x_n to equal 2**(e-1) + 2**(e-2), then we reduce the error to ε_n ≤ 2**(e-2).
            // This is going to be our x_0 (and ε_0)
            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)

            // From here, Newton's method give us:
            // x_{n+1} = (x_n + a / x_n) / 2
            //
            // One should note that:
            // x_{n+1}² - a = ((x_n + a / x_n) / 2)² - a
            //              = ((x_n² + a) / (2 * x_n))² - a
            //              = (x_n⁴ + 2 * a * x_n² + a²) / (4 * x_n²) - a
            //              = (x_n⁴ + 2 * a * x_n² + a² - 4 * a * x_n²) / (4 * x_n²)
            //              = (x_n⁴ - 2 * a * x_n² + a²) / (4 * x_n²)
            //              = (x_n² - a)² / (2 * x_n)²
            //              = ((x_n² - a) / (2 * x_n))²
            //              ≥ 0
            // Which proves that for all n ≥ 1, sqrt(a) ≤ x_n
            //
            // This gives us the proof of quadratic convergence of the sequence:
            // ε_{n+1} = | x_{n+1} - sqrt(a) |
            //         = | (x_n + a / x_n) / 2 - sqrt(a) |
            //         = | (x_n² + a - 2*x_n*sqrt(a)) / (2 * x_n) |
            //         = | (x_n - sqrt(a))² / (2 * x_n) |
            //         = | ε_n² / (2 * x_n) |
            //         = ε_n² / | (2 * x_n) |
            //
            // For the first iteration, we have a special case where x_0 is known:
            // ε_1 = ε_0² / | (2 * x_0) |
            //     ≤ (2**(e-2))² / (2 * (2**(e-1) + 2**(e-2)))
            //     ≤ 2**(2*e-4) / (3 * 2**(e-1))
            //     ≤ 2**(e-3) / 3
            //     ≤ 2**(e-3-log2(3))
            //     ≤ 2**(e-4.5)
            //
            // For the following iterations, we use the fact that, 2**(e-1) ≤ sqrt(a) ≤ x_n:
            // ε_{n+1} = ε_n² / | (2 * x_n) |
            //         ≤ (2**(e-k))² / (2 * 2**(e-1))
            //         ≤ 2**(2*e-2*k) / 2**e
            //         ≤ 2**(e-2*k)
            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

            // Because e ≤ 128 (as discussed during the first estimation phase), we know have reached a precision
            // ε_6 ≤ 2**(e-144) < 1. Given we're operating on integers, then we can ensure that xn is now either
            // sqrt(a) or sqrt(a) + 1.
            return xn - SafeCast.toUint(xn > a / xn);
        }
    }

    /**
     * @dev Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && result * result < a);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // If upper 8 bits of 16-bit half set, add 8 to result
        r |= SafeCast.toUint((x >> r) > 0xff) << 3;
        // If upper 4 bits of 8-bit half set, add 4 to result
        r |= SafeCast.toUint((x >> r) > 0xf) << 2;

        // Shifts value right by the current result and use it as an index into this lookup table:
        //
        // | x (4 bits) |  index  | table[index] = MSB position |
        // |------------|---------|-----------------------------|
        // |    0000    |    0    |        table[0] = 0         |
        // |    0001    |    1    |        table[1] = 0         |
        // |    0010    |    2    |        table[2] = 1         |
        // |    0011    |    3    |        table[3] = 1         |
        // |    0100    |    4    |        table[4] = 2         |
        // |    0101    |    5    |        table[5] = 2         |
        // |    0110    |    6    |        table[6] = 2         |
        // |    0111    |    7    |        table[7] = 2         |
        // |    1000    |    8    |        table[8] = 3         |
        // |    1001    |    9    |        table[9] = 3         |
        // |    1010    |   10    |        table[10] = 3        |
        // |    1011    |   11    |        table[11] = 3        |
        // |    1100    |   12    |        table[12] = 3        |
        // |    1101    |   13    |        table[13] = 3        |
        // |    1110    |   14    |        table[14] = 3        |
        // |    1111    |   15    |        table[15] = 3        |
        //
        // The lookup table is represented as a 32-byte value with the MSB positions for 0-15 in the first 16 bytes (most significant half).
        assembly ("memory-safe") {
            r := or(r, byte(shr(r, x), 0x0000010102020202030303030303030300000000000000000000000000000000))
        }
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << result < value);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 10 ** result < value);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // Add 1 if upper 8 bits of 16-bit half set, and divide accumulated result by 8
        return (r >> 3) | SafeCast.toUint((x >> r) > 0xff);
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << (result << 3) < value);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }

    /**
     * @dev Counts the number of leading zero bits in a uint256.
     */
    function clz(uint256 x) internal pure returns (uint256) {
        return ternary(x == 0, 256, 255 - log2(x));
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.20;

/**
 * @dev Wrappers over Solidity's uintXX/intXX/bool casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in a uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in a uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev A uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }

    /**
     * @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }
}

```

### target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

import {SafeCast} from "./SafeCast.sol";

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * int256(SafeCast.toUint(condition)));
        }
    }

    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a < b, a, b);
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // Formula from the "Bit Twiddling Hacks" by Sean Eron Anderson.
            // Since `n` is a signed integer, the generated bytecode will use the SAR opcode to perform the right shift,
            // taking advantage of the most significant (or "sign" bit) in two's complement representation.
            // This opcode adds new most significant bits set to the value of the previous most significant bit. As a result,
            // the mask will either be `bytes32(0)` (if n is positive) or `~bytes32(0)` (if n is negative).
            int256 mask = n >> 255;

            // A `bytes32(0)` mask leaves the input unchanged, while a `~bytes32(0)` mask complements it.
            return uint256((n + mask) ^ mask);
        }
    }
}

```


# ACCEPTED CORRECTED SPECIALIST 1 FINAL RESPONSE

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-proceeds-release
file: target/packages/contracts/src/Raffle.sol
severity: high
root_cause: `releaseSponsorProceeds` and `releaseProtocolFees` pay `NftWon` claims without checking `winnerRedeemed`.
path: sponsor escrows pausable ERC721 → victim buys → `NftWon` → settlement → sponsor pauses prize → sponsor withdraws proceeds → winner redemption reverts
proof: With `reserveEntries=1`, one victim pays 1,000,000 units. Settlement assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. The sponsor pauses the prize and withdraws 950,000 units. `redeemWinningTicket` then reverts at `prizeToken.transferFrom`; `enableRefunds` rejects `NftWon`, so the victim cannot recover 1,000,000 units.
description: A sponsor can block the prize transfer and take 95% of ticket payments before the winner receives the NFT.
fix: The contract must require `winnerRedeemed` before either `releaseSponsorProceeds` or `releaseProtocolFees` pays an `NftWon` claim.

# ACCEPTED CORRECTED SPECIALIST 2 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: forged-prize-escrow | group_key: RaffleFactory | createRaffle | forged-prize-escrow
file: target/packages/contracts/src/RaffleFactory.sol
related: target/packages/contracts/src/Raffle.sol:onERC721Received
root_cause: `createRaffle` treats token-controlled ERC-165, callback, and `ownerOf` outputs as proof that the raffle holds a transferable prize.
guard_gap: The constructor pins the trusted quote token and wrapper, but `_validateCreateParams` accepts any sponsor-selected `prizeToken` that returns true.
path: sponsor → `createRaffle` → false `safeTransferFrom` → spoofed `onERC721Received` → false `ownerOf` → ticket sales → `NftWon` → sponsor withdrawal
proof: The sponsor sets `reserveEntries = 1` and supplies a false ERC-721. Its `safeTransferFrom` moves nothing, calls `onERC721Received(factory, sponsor, id, "")`, and makes `ownerOf(id)` return the clone. A victim buys ten entries, so `unsettledPot = 10_000_000`. The sponsor requests the draw, settles ticket 1, and receives `sponsorProceeds = 9_500_000`. The token then reverts every redemption transfer, and `NftWon` provides no refund path.
description: A sponsor can report a prize deposit without a transfer, take 95% of sales, and leave the winner unable to redeem the prize.
fix: The factory must accept only immutable, reviewed ERC-721 contracts from a deployment-time allowlist.

# ACCEPTED CORRECTED SPECIALIST 3 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-token | group_key: RaffleFactory | createRaffle | untrusted-prize-token
file: target/packages/contracts/src/RaffleFactory.sol
path: attacker sponsor → fake `safeTransferFrom` invokes `onERC721Received` without custody → fake `ownerOf` reports clone → buyers fund raffle → sponsor withdraws proceeds
proof: `FakeERC721` can report ERC-721 support, invoke the expected callback, and return each clone from `ownerOf`. The same token ID can activate two raffles. Two 100-entry raffles allocate 95,000,000 units each to the sponsor, so the attacker receives 190 USDC without exclusive prizes.
description: The factory trusts a sponsor’s ERC-721 reports, so the sponsor can collect 95% of buyer funds without an enforceable prize.
fix: The factory must allow only audited ERC-721 contracts with immutable ownership logic and no privileged transfer controls.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
path: sponsor escrows mutable prize → buyer purchases 100 entries → callback sets `NftWon` → settlement allocates proceeds → sponsor receives proceeds → prize transfer reverts
proof: A 100-entry ticket creates a 100,000,000-unit pot. Settlement assigns 95,000,000 units to `sponsorProceeds` and 5,000,000 units to `protocolFees`. The sponsor receives 95 USDC before redemption. A blocked prize transfer reverts every redemption, while `enableRefunds` rejects the permanent `NftWon` status.
description: `releaseSponsorProceeds` pays before `winnerRedeemed`, so a sponsor can block prize delivery and take 95% of buyer funds.
fix: The raffle must require `winnerRedeemed` before it releases sponsor proceeds after an `NftWon` result.

# ACCEPTED CORRECTED SPECIALIST 4 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-attestation
file: target/packages/contracts/src/RaffleFactory.sol
input: The sponsor supplies `Fake721`, token ID `1`, and reserve `1`.
assumption: The factory assumes an attacker-selected prize contract can prove its own custody and transferability.
root_cause: `createRaffle` accepts custody evidence only from the selected `prizeToken`, which controls the transfer callback and `ownerOf` response.
path: sponsor → `createRaffle` → forged receiver callback → forged `ownerOf` result → `Active` → ticket sale → sponsor payout
proof: `Fake721` returns true for ERC-721 support, calls `onERC721Received(factory, sponsor, 1, "")` without a transfer, and reports the raffle from `ownerOf(1)`. One entry supplies 1,000,000 units; settlement assigns 950,000 units to the sponsor, while `Fake721` can reject winner delivery.
description: A sponsor can activate a raffle with no transferable prize, so buyers pay USDC and the sponsor takes 95% of the sales.
fix: The factory must accept only prize contracts that a fixed trusted allowlist approves.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: pre-delivery-sponsor-payout | group_key: Raffle | releaseSponsorProceeds | pre-delivery-sponsor-payout
file: target/packages/contracts/src/Raffle.sol
input: The sponsor supplies a prize with an administrator-controlled transfer block, sets `reserveEntries` to `1`, and blocks transfers after genuine escrow.
assumption: A prize that passes the initial escrow checks will remain transferable to the winner.
root_cause: `releaseSponsorProceeds` pays an `NftWon` sponsor without checking `winnerRedeemed` or current prize ownership.
path: genuine escrow → one entry → transfer block → `NftWon` → settlement → sponsor payout → failed redemption
proof: One entry creates a 1,000,000-unit pot. Settlement assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. The sponsor receives 950,000 units before `prizeToken.transferFrom` reverts; `enableRefunds` rejects `NftWon`.
description: A sponsor can block prize delivery after genuine escrow and take 95% of sales before the winner receives the NFT.
fix: Both release functions must require `winnerRedeemed` for `NftWon` before they transfer sponsor proceeds or protocol fees.

# ACCEPTED CORRECTED SPECIALIST 5 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: fake-prize-escrow | group_key: RaffleFactory | createRaffle | fake-prize-escrow
file: target/packages/contracts/src/RaffleFactory.sol:97; target/packages/contracts/src/Raffle.sol:416
root_cause: The factory treats sponsor-controlled callbacks and ownerOf results as proof that the raffle holds a deliverable prize.
invariant: Each Status.Active raffle must hold one deliverable prizeTokenId.
violation_path: sponsor → createRaffle → malicious safeTransferFrom → forged onERC721Received → false ownerOf result → Status.Active without a prize
path: sponsor → fake prize escrow → ticket sales → NftWon settlement → releaseSponsorProceeds → winner redemption reverts
proof: A malicious token reports IERC721 support, calls onERC721Received(factory,sponsor,7,"") without a transfer, and returns the clone from ownerOf(7). With reserveEntries=1 and 100 entries, buyers deposit 100,000,000 raw USDC units; settlement allocates 95,000,000 units to the sponsor despite the absent prize.
description: A sponsor can make a prize token report false custody, receive 95% of sales, and deny the winner a prize.
fix: The factory must accept only immutable trusted prize contracts, because an untrusted token controls the callback and every ownership check.

LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-nft-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-nft-proceeds-release
file: target/packages/contracts/src/Raffle.sol:309; target/packages/contracts/src/Raffle.sol:375; target/packages/contracts/src/Raffle.sol:533
root_cause: The NftWon settlement makes sponsor proceeds claimable before successful prize delivery and provides no later refund transition.
code_smells: The NftWon settlement creates sponsorProceeds before redemption, and releaseSponsorProceeds checks neither winnerRedeemed nor prizeClaimed.
proof: A genuine prize can enter escrow and later reject transferFrom. From a 100,000,000-unit pot, the sponsor withdraws 95,000,000 units; redemption always reverts, while enableRefunds rejects NftWon.
design_conflict: DESIGN.md permits independent sponsor claims after settlement, but it also defines prize contracts as untrusted.
description: A sponsor can take 95% of sales before the winner receives the NFT. The design permits this order, so the required failure response is unclear.
fix: The contract can delay NFT-outcome payouts until redemption succeeds and can enable refunds after a delivery deadline.

# ACCEPTED CORRECTED SPECIALIST 6 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: spoofed-erc721-escrow | group_key: RaffleFactory | createRaffle | spoofed-erc721-escrow
file: target/packages/contracts/src/RaffleFactory.sol
root_cause: createRaffle accepts sponsor-controlled ERC-165, callback, and ownerOf results as proof that the clone holds a transferable prize.
path: sponsor-controlled prize → fake ERC-165 response → fake safeTransferFrom invokes onERC721Received without escrow → fake ownerOf reports the clone → victim buys entries → sponsor withdraws proceeds → prize transfer reverts
proof: A fake prize returns true for the IERC721 interface ID. Its safeTransferFrom(attacker, raffle, 1) calls raffle.onERC721Received(factory, attacker, 1, "") without transferring a token. ownerOf(1) then returns raffle, so every creation check passes. With reserveEntries=1, a victim buys ticket 1 for 1,000,000 units. After winningEntry=1 and NftWon, settleWinningTicket(1) assigns 950,000 units to sponsorProceeds and 50,000 units to protocolFees. releaseSponsorProceeds pays the attacker. The fake prize makes transferFrom revert, so redeemWinningTicket(1) always rolls back, while refunds remain unavailable in NftWon.
description: A sponsor can fake ERC-721 escrow, collect 95% of ticket sales, and block the winner from both the prize and a refund.
fix: The factory must use an immutable allowlist of vetted ERC-721 contracts because an untrusted contract can pass every escrow check without a transfer.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
root_cause: releaseSponsorProceeds and releaseProtocolFees pay NFT-result revenue before redeemWinningTicket proves that the prize transfer succeeds.
path: sponsor escrows an unpaused pausable ERC-721 → victim buys entries → NftWon settlement allocates the pot → sponsor pauses transfers → proceeds leave → redemption always reverts → refunds remain unavailable
proof: With reserveEntries=1 and totalEntries=100, settlement splits the 100,000,000-unit pot into 95,000,000 sponsorProceeds and 5,000,000 protocolFees. The sponsor pauses the validly escrowed prize and claims 95,000,000 units. releaseProtocolFees can transfer the remaining 5,000,000 units. The prize transfer then reverts on every redemption, while enableRefunds rejects Status.NftWon.
description: A sponsor can block the prize transfer after escrow and still collect the sale proceeds, so the winner receives no prize or refund.
fix: The contract must require successful prize delivery before payouts and must enable full refunds if delivery fails.

# ACCEPTED CORRECTED SPECIALIST 7 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: false-prize-ownership | group_key: RaffleFactory | createRaffle | false-prize-ownership
file: target/packages/contracts/src/RaffleFactory.sol:97
path: sponsor → createRaffle → false ownership reports → buyers fund raffle → false delivery report → winner ticket burns → sponsor takes proceeds
root_cause: `createRaffle` trusts sponsor-controlled `supportsInterface`, `safeTransferFrom`, and `ownerOf` behavior as proof that the raffle received a usable prize.
assumption: An untrusted prize contract reports ownership and transfer rights truthfully.
violation: The sponsor separates reported ownership from transfer authority, so each ownership check passes while the sponsor retains control.
proof: `FakePrize` reports ERC-721 support, calls `onERC721Received`, and makes `ownerOf(7)` return the raffle while the sponsor remains controller. With `reserveEntries=1`, ticket 1 buys 100 entries for 100,000,000 USDC units. During redemption, `transferFrom` changes only the reported owner to the winner. The next `ownerOf` check passes, so the raffle burns ticket 1 and sets `winnerRedeemed`. The winner’s later transfer reverts because only the sponsor remains authorized. The sponsor receives 95,000,000 units.
description: A sponsor can make an ERC-721 lie about ownership, take 95% of sales, and give the winner no usable token.
fix: The factory must enforce an immutable allowlist of ERC-721 contracts whose ownership and transfer rules the protocol trusts.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: sponsor-payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | sponsor-payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:375
path: sponsor escrows prize → prize blocks outbound transfers → settleWinningTicket allocates proceeds → releaseSponsorProceeds pays sponsor → redeemWinningTicket always reverts
root_cause: `releaseSponsorProceeds` sends an `NftWon` allocation without checking that `redeemWinningTicket` completed prize delivery and set `winnerRedeemed`.
assumption: An escrowed prize remains transferable, so settlement can expose sponsor proceeds before delivery.
violation: The sponsor controls a prize that accepts the factory deposit but rejects every transfer from the raffle.
proof: A prize with truthful ownership transfers token 7 from the sponsor to the raffle during creation. A victim buys ticket 1 with 100 entries for 100,000,000 USDC units, and `reserveEntries` is 1. After `NftWon`, `settleWinningTicket(1)` sets `sponsorProceeds` to 95,000,000. `releaseSponsorProceeds` pays that amount while `winnerRedeemed` is false. The prize then rejects the winner’s transfer, redemption reverts, and `NftWon` prevents refunds.
description: A sponsor can block the escrowed prize transfer and collect 95% of sales before the winner receives the prize.
fix: For `NftWon`, `releaseSponsorProceeds` must require `winnerRedeemed` before it sends the sponsor balance.

# ACCEPTED CORRECTED SPECIALIST 8 FINAL RESPONSE

FINDING | contract: Raffle | function: settleWinningTicket | bug_class: payout-before-prize-delivery | group_key: Raffle | settleWinningTicket | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:304
pair_or_branch: standalone `settleWinningTicket` plus `releaseSponsorProceeds` / inline settlement in `redeemWinningTicket`
asymmetry: Standalone settlement persists sponsor proceeds without prize delivery, while inline settlement reverts those proceeds when the same delivery fails.
root_cause: `_settleWinningTicket` makes NftWon proceeds releasable before `redeemWinningTicket` proves prize delivery.
path: sponsor escrows an unpaused pausable ERC-721 → buyer purchases → sponsor pauses transfers → `NftWon` → standalone settlement → sponsor withdrawal → winner redemption reverts
proof: With `reserveEntries = 1` and one 1,000,000-unit entry, `_settleWinningTicket` assigns 950,000 units to `sponsorProceeds` and 50,000 units to `protocolFees`. `releaseSponsorProceeds` pays the sponsor without checking `prizeClaimed`. The paused prize then reverts at `prizeToken.transferFrom`, while `enableRefunds` rejects the terminal `NftWon` status.
description: A sponsor can pause its escrowed prize and claim 95% of buyers' USDC before the winner can receive the NFT.
fix: The contract must require `prizeClaimed` before it releases NftWon sponsor or protocol proceeds.

# ACCEPTED CORRECTED SPECIALIST 9 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: fake-erc721-escrow | group_key: RaffleFactory | createRaffle | fake-erc721-escrow
file: target/packages/contracts/src/RaffleFactory.sol:97
boundary: Caller-selected `supportsInterface`, `safeTransferFrom`, `onERC721Received`, and `ownerOf` calls
assumption: The factory assumes that the prize contract provides independent proof of a transferable NFT.
actual: The prize contract can fabricate the callback and ownership result, then reject every delivery attempt.
root_cause: `createRaffle` treats statements from one caller-selected contract as proof that the raffle owns a transferable NFT.
path: sponsor → fake prize callback and ownership response → `Active` raffle → buyer payment → `NftWon` → failed redemption
proof: A token returns true for ERC-721 support, calls `onERC721Received(factory,sponsor,tokenId,"")`, reports the clone from `ownerOf`, and makes `transferFrom` revert. With one entry and `reserveEntries=1`, the sponsor receives 950,000 of 1,000,000 USDC units while redemption always reverts.
description: A sponsor can fake prize escrow and get an active raffle whose winner cannot receive the advertised NFT.
fix: The factory must restrict prizes to an immutable allowlist of ERC-721 contracts with trusted ownership and transfer behavior.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol:375
boundary: `releaseSponsorProceeds` pays before the later `prizeToken.transferFrom` call succeeds.
assumption: The raffle assumes that a prize which entered escrow remains transferable when the winner redeems it.
actual: A sponsor-controlled pausable or upgradeable ERC-721 can reject delivery after the sponsor receives the sale proceeds.
root_cause: `_settleWinningTicket` exposes payout claims before `redeemWinningTicket` proves delivery, while `enableRefunds` rejects the resulting `NftWon` state.
path: genuine escrow → buyer payments → token pause → `NftWon` settlement → sponsor payout → permanent redemption failure
proof: With 100 entries and `reserveEntries=1`, settlement allocates 95,000,000 units to the sponsor and 5,000,000 units to fees. After payout, a paused prize makes every redemption revert at `transferFrom`; `enableRefunds` then reverts because the status is `NftWon`.
description: A sponsor can pause an escrowed ERC-721, take 95% of sales, and block the winner from both the prize and a refund.
fix: `Raffle` must keep sponsor and protocol proceeds escrowed until NFT delivery succeeds, then open full refunds if delivery misses a fixed deadline.

# ACCEPTED CORRECTED SPECIALIST 10 FINAL RESPONSE

LEAD | contract: Raffle | function: requestDraw | bug_class: timestamp-downcast-deadline-rollover | group_key: Raffle | requestDraw | timestamp-downcast-deadline-rollover
file: target/packages/contracts/src/Raffle.sol
seam: three-way
code_smells: `requestDraw` casts `block.timestamp` to `uint64`, so `callbackDeadline` trusts a wrapped timestamp after the `uint64` limit.
proof: With `endTime = 2^64-1`, a valid request at `2^64` stores zero; `callbackDeadline()` returns zero, so `enableRefunds()` succeeds immediately.
description: An attacker can cancel a funded raffle at `2^64` seconds, but current deployments are about 584 billion years from that timestamp.

# ACCEPTED CORRECTED SPECIALIST 11 FINAL RESPONSE

FINDING | contract: Raffle | function: buyEntries | bug_class: prize-custody-not-revalidated | group_key: Raffle | buyEntries | prize-custody-not-revalidated
file: target/packages/contracts/src/Raffle.sol
seam: three-way
actor: A sponsor that controls an admin transfer in the selected ERC-721 contract.
path: sponsor → valid initial escrow → admin removes prize → victim buys entries → NftWon → sponsor withdraws proceeds → winner redemption fails
root_cause: `createRaffle` verifies custody once, while `buyEntries` accepts later payments without a current ownership check.
proof: Set `reserveEntries=1`. The ERC-721 initially transfers token 7 to the raffle, then its admin returns token 7 to the sponsor. The victim calls `buyEntries(victim,1)` and pays 1,000,000 raw USDC. Ticket 1 always wins. Settlement assigns 950,000 to `sponsorProceeds` and 50,000 to `protocolFees`. The sponsor receives 950,000, but `redeemWinningTicket(1)` reverts because the raffle no longer owns token 7. `NftWon` rejects `enableRefunds`.
description: A sponsor can reclaim the prize before a purchase, keep the NFT, and take 95% of the buyer's payment.
fix: `buyEntries` must verify that the raffle owns `prizeTokenId` before it transfers the buyer's USDC.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: proceeds-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | proceeds-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
seam: three-way
actor: A sponsor that controls the selected prize contract and receives `sponsorProceeds`.
path: sponsor escrows prize → buyers fund raffle → sponsor pauses prize → NftWon → settlement allocates proceeds → sponsor withdraws → redemption fails
root_cause: `_settleWinningTicket` allocates USDC before NFT delivery, and `releaseSponsorProceeds` checks no delivery state.
proof: With `reserveEntries=100` and one 100-entry ticket, gross sales equal 100,000,000 raw USDC and ticket 1 always wins. The sponsor pauses outbound prize transfers. `_settleWinningTicket(1)` assigns 95,000,000 to `sponsorProceeds` and 5,000,000 to `protocolFees`. `releaseSponsorProceeds` pays the sponsor. `redeemWinningTicket(1)` then reverts in `prizeToken.transferFrom`, and `enableRefunds` rejects `NftWon`.
description: A sponsor can pause the prize transfer and take 95% of sales before the winner receives the NFT.
fix: `Raffle` must deliver the NFT before it releases sponsor or protocol proceeds and must enable refunds after delivery failure.

# ACCEPTED CORRECTED SPECIALIST 12 FINAL RESPONSE

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: prize-self-attestation | group_key: RaffleFactory | createRaffle | prize-self-attestation
file: target/packages/contracts/src/RaffleFactory.sol; target/packages/contracts/src/Raffle.sol
seam: three-way
root_cause: `createRaffle` and `redeemWinningTicket` let one untrusted prize contract attest to both transfers through caller-dependent `ownerOf` results.
path: sponsor → `createRaffle` → fake prize calls `onERC721Received` without a transfer → `ownerOf` makes factory accept escrow → buyer pays → `NftWon` → fake redemption transfer → ticket burns → sponsor collects proceeds
trace: `createRaffle` → `safeTransferFrom` → forged callback → `ownerOf` reports the clone → `redeemWinningTicket` → no-op `transferFrom` → `ownerOf` reports the winner → false delivery state
violated_principle: A reserve-met winner must receive the escrowed ERC-721, and the raffle must escrow exactly one prize at creation.
proof: With `reserveEntries=1` and one 1,000,000-unit purchase, entry 1 wins; a fake token forges the callback, reports the clone only to the factory, no-ops redemption, and reports the winner only to the raffle, so `winnerRedeemed=true`, the ticket is burned, `balanceOf(winner)=0`, sponsor proceeds equal 950,000, and protocol fees equal 50,000.
description: A sponsor uses a false prize contract to collect 95% of sales, and the winner gets no transferable NFT.
fix: The factory must accept only prize contracts from an immutable allowlist because an untrusted token cannot prove its own custody.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
file: target/packages/contracts/src/Raffle.sol
seam: three-way
root_cause: `_settleWinningTicket` creates sponsor and protocol claims before `redeemWinningTicket` proves that the prize contract permits delivery.
path: sponsor → escrow pausable ERC-721 → buyer pays → sponsor pauses prize → `NftWon` → settlement → sponsor withdraws proceeds → prize transfer reverts → refunds remain unavailable
trace: `settleWinningTicket` allocates quote tokens → `releaseSponsorProceeds` finalizes payment → `redeemWinningTicket` calls paused `transferFrom` → redemption reverts while the prior sponsor payment remains final
violated_principle: A reserve-met raffle must award the NFT to the winner.
proof: With `reserveEntries=1` and one 1,000,000-unit purchase, settlement allocates 950,000 to the sponsor and 50,000 to the treasury; the sponsor withdraws 950,000 before a paused ERC-721 rejects redemption, while `NftWon` prevents `enableRefunds`.
description: A sponsor pauses the prize after escrow and takes 95% of sales, so the winner cannot redeem the NFT or recover payment.
fix: The raffle must require `winnerRedeemed` before either `releaseSponsorProceeds` or `releaseProtocolFees` can pay an `NftWon` raffle.
