#!/usr/bin/env python3
"""Run deterministic single-source mutants in a disposable git worktree.

This deliberately uses exact source fragments rather than production helpers. It overlays
the active checkout's tests onto a detached worktree of HEAD, never edits the active
production source, and removes the temporary worktree on exit.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def run(command: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, check=check, text=True, capture_output=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "audit" / "current-mutations.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "audit" / "current-mutation-results.json",
    )
    parser.add_argument("--limit", type=int, default=0, help="Run only the first N mutants")
    parser.add_argument("--ids", nargs="*", default=[], help="Run only these mutant IDs")
    args = parser.parse_args()

    contracts_dir = Path(__file__).resolve().parents[1]
    repo = Path(run(["git", "rev-parse", "--show-toplevel"], cwd=contracts_dir).stdout.strip())
    config = json.loads(args.config.read_text())
    mutants = config["mutants"]
    if args.ids:
        requested = set(args.ids)
        mutants = [mutant for mutant in mutants if mutant["id"] in requested]
        missing = requested - {mutant["id"] for mutant in mutants}
        if missing:
            parser.error(f"unknown mutant IDs: {', '.join(sorted(missing))}")
    mutants = mutants[: args.limit or None]
    temporary = Path(tempfile.mkdtemp(prefix="raffle-current-mutation-"))
    worktree = temporary / "worktree"
    results: list[dict[str, object]] = []

    try:
        run(["git", "worktree", "add", "--detach", str(worktree), "HEAD"], cwd=repo)

        # Use the campaign's active tests, including uncommitted regressions, against
        # the exact committed production source in the detached worktree.
        target_tests = worktree / "packages/contracts/test"
        shutil.rmtree(target_tests)
        shutil.copytree(contracts_dir / "test", target_tests)

        root_modules = repo / "node_modules"
        if root_modules.exists():
            os.symlink(root_modules, worktree / "node_modules", target_is_directory=True)

        target_contract_modules = worktree / "packages/contracts/node_modules"
        if target_contract_modules.exists() or target_contract_modules.is_symlink():
            if target_contract_modules.is_dir() and not target_contract_modules.is_symlink():
                shutil.rmtree(target_contract_modules)
            else:
                target_contract_modules.unlink()
        os.symlink(contracts_dir / "node_modules", target_contract_modules, target_is_directory=True)

        target_forge_std = worktree / "packages/contracts/lib/forge-std"
        if target_forge_std.exists() or target_forge_std.is_symlink():
            if target_forge_std.is_dir() and not target_forge_std.is_symlink():
                shutil.rmtree(target_forge_std)
            else:
                target_forge_std.unlink()
        target_forge_std.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(contracts_dir / "lib/forge-std", target_forge_std, target_is_directory=True)

        mutation_contracts = worktree / "packages/contracts"
        for mutant in mutants:
            source = mutation_contracts / mutant["path"]
            original = source.read_text()
            count = original.count(mutant["before"])
            started = time.monotonic()
            if count != 1:
                results.append(
                    {
                        "id": mutant["id"],
                        "classification": "invalid-definition",
                        "match_count": count,
                    }
                )
                continue

            source.write_text(original.replace(mutant["before"], mutant["after"], 1))
            completed = run(
                ["forge", "test", "-q", "--no-match-contract", "BaseForkTest"],
                cwd=mutation_contracts,
                check=False,
            )
            source.write_text(original)
            combined_output = completed.stdout + completed.stderr
            if "Compiler run failed" in combined_output or "Error: Compilation failed" in combined_output:
                classification = "compile-error"
            else:
                classification = "killed" if completed.returncode else "survived"
            results.append(
                {
                    "id": mutant["id"],
                    "description": mutant["description"],
                    "classification": classification,
                    "exit_code": completed.returncode,
                    "seconds": round(time.monotonic() - started, 3),
                    "stderr_tail": completed.stderr[-2000:],
                    "stdout_tail": completed.stdout[-2000:],
                }
            )
            print(f"{mutant['id']}: {results[-1]['classification']}", flush=True)
    finally:
        if worktree.exists():
            run(["git", "worktree", "remove", "--force", str(worktree)], cwd=repo, check=False)
        shutil.rmtree(temporary, ignore_errors=True)

    output = {
        "schema": 1,
        "source_commit": run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip(),
        "config": str(args.config),
        "generated": len(results),
        "compiled_and_killed": sum(item["classification"] == "killed" for item in results),
        "survived": sum(item["classification"] == "survived" for item in results),
        "compile_errors": sum(item["classification"] == "compile-error" for item in results),
        "invalid": sum(item["classification"] == "invalid-definition" for item in results),
        "results": results,
    }
    args.output.write_text(json.dumps(output, indent=2) + "\n")
    return 1 if output["survived"] or output["compile_errors"] or output["invalid"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
