#!/usr/bin/env python3
"""Run deterministic single-source mutants against an active candidate snapshot.

The runner snapshots the active checkout's uncommitted production source and test oracle,
overlays both into a detached disposable worktree, and mutates only that worktree. The
active source tree is never written by the campaign.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def run(command: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, check=check, text=True, capture_output=True)


def fingerprint_tree(root: Path, *, pattern: str = "*") -> dict[str, object]:
    files = sorted(path for path in root.rglob(pattern) if path.is_file())
    digest = hashlib.sha256()
    for path in files:
        relative = path.relative_to(root).as_posix().encode()
        contents = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(contents).to_bytes(8, "big"))
        digest.update(contents)
    return {
        "algorithm": "sha256",
        "digest": digest.hexdigest(),
        "file_count": len(files),
    }


def classify(completed: subprocess.CompletedProcess[str]) -> str:
    combined_output = completed.stdout + completed.stderr
    if "Compiler run failed" in combined_output or "Error: Compilation failed" in combined_output:
        return "compile-error"
    return "killed" if completed.returncode else "survived"


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
    test_command = config.get(
        "test_command",
        ["forge", "test", "-q", "--no-match-contract", "EthereumForkTest"],
    )
    if not isinstance(test_command, list) or not all(isinstance(part, str) for part in test_command):
        parser.error("test_command must be an array of strings")
    mutant_ids = [mutant["id"] for mutant in mutants]
    if len(mutant_ids) != len(set(mutant_ids)):
        parser.error("mutant IDs must be unique")
    if args.ids:
        requested = set(args.ids)
        mutants = [mutant for mutant in mutants if mutant["id"] in requested]
        missing = requested - {mutant["id"] for mutant in mutants}
        if missing:
            parser.error(f"unknown mutant IDs: {', '.join(sorted(missing))}")
    mutants = mutants[: args.limit or None]
    temporary = Path(tempfile.mkdtemp(prefix="raffle-current-mutation-"))
    worktree = temporary / "worktree"
    candidate_snapshot = temporary / "candidate"
    results: list[dict[str, object]] = []
    baseline: dict[str, object] = {}

    try:
        # Freeze the active, potentially uncommitted candidate before creating the worktree.
        # This avoids mixing HEAD production code with current tests and makes the recorded
        # fingerprint the exact source actually mutated.
        shutil.copytree(contracts_dir / "src", candidate_snapshot / "src")
        shutil.copytree(contracts_dir / "test", candidate_snapshot / "test")
        shutil.copytree(contracts_dir / "script", candidate_snapshot / "script")
        for filename in ("foundry.toml", "remappings.txt"):
            shutil.copy2(contracts_dir / filename, candidate_snapshot / filename)

        candidate_fingerprint = fingerprint_tree(candidate_snapshot / "src", pattern="*.sol")
        # Forge ignores the adjacent TypeScript/Python suites; fingerprint only the
        # Solidity oracle that this campaign actually executes.
        oracle_fingerprint = fingerprint_tree(candidate_snapshot / "test", pattern="*.sol")

        run(["git", "worktree", "add", "--detach", str(worktree), "HEAD"], cwd=repo)

        mutation_contracts = worktree / "packages/contracts"
        for directory in ("src", "test", "script"):
            target = mutation_contracts / directory
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(candidate_snapshot / directory, target)
        for filename in ("foundry.toml", "remappings.txt"):
            shutil.copy2(candidate_snapshot / filename, mutation_contracts / filename)

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

        baseline_started = time.monotonic()
        baseline_run = run(test_command, cwd=mutation_contracts, check=False)
        baseline_classification = classify(baseline_run)
        baseline = {
            "classification": "passed" if baseline_run.returncode == 0 else baseline_classification,
            "exit_code": baseline_run.returncode,
            "seconds": round(time.monotonic() - baseline_started, 3),
            "stderr_tail": baseline_run.stderr[-2000:],
            "stdout_tail": baseline_run.stdout[-2000:],
        }
        if baseline_run.returncode != 0:
            raise RuntimeError(
                "candidate baseline failed: "
                f"{baseline_classification}\nstdout:\n{baseline_run.stdout[-4000:]}"
                f"\nstderr:\n{baseline_run.stderr[-4000:]}"
            )

        source_root = (mutation_contracts / "src").resolve()
        for mutant in mutants:
            source = (mutation_contracts / mutant["path"]).resolve()
            try:
                source.relative_to(source_root)
            except ValueError:
                results.append(
                    {
                        "id": mutant["id"],
                        "description": mutant["description"],
                        "classification": "invalid-definition",
                        "reason": "mutation path must resolve inside packages/contracts/src",
                    }
                )
                continue
            if not source.is_file():
                results.append(
                    {
                        "id": mutant["id"],
                        "description": mutant["description"],
                        "classification": "invalid-definition",
                        "reason": "mutation source file does not exist",
                    }
                )
                continue
            original = source.read_text()
            count = original.count(mutant["before"])
            started = time.monotonic()
            if count != 1:
                results.append(
                    {
                        "id": mutant["id"],
                        "description": mutant["description"],
                        "classification": "invalid-definition",
                        "match_count": count,
                    }
                )
                continue

            source.write_text(original.replace(mutant["before"], mutant["after"], 1))
            try:
                completed = run(test_command, cwd=mutation_contracts, check=False)
            finally:
                source.write_text(original)
            classification = classify(completed)
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
        "schema": 2,
        "source_commit": run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip(),
        "candidate_source": candidate_fingerprint,
        "test_oracle": oracle_fingerprint,
        "config": str(args.config.resolve().relative_to(repo)),
        "test_command": test_command,
        "baseline": baseline,
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
