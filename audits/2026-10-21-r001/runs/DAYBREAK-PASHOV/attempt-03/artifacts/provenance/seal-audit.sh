#!/bin/sh
set -eu

out=/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-03
cell=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation
previous_cell=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-attempt-02
method=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/pashov/solidity-auditor
freeze=/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/freeze.json
verifier=/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/verify-freeze.py
judge="$out/artifacts/native-judge"
inherited="$out/artifacts/inherited-specialists"
run="$out/artifacts/native-run/20261021-005946"
package="$cell/runtime/package"
sealed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

mtime_utc() {
    epoch=$(stat -f '%m' "$1")
    date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ'
}

mkdir -p "$out/artifacts/provenance"
cp "$package/generate-specialist-validation.sh" "$out/artifacts/provenance/generate-specialist-validation.sh"
cp "$package/seal-audit.sh" "$out/artifacts/provenance/seal-audit.sh"

specialist_validation_sha=$(sha256_file "$out/artifacts/specialist-validation.json")
method_skill_sha=$(sha256_file "$out/artifacts/method/SKILL.md")
method_version_sha=$(sha256_file "$out/artifacts/method/VERSION")
assembler_sha=$(sha256_file "$out/artifacts/method/references/assemble.sh")
scope_sha=$(sha256_file "$run/scope.tsv")
source_sha=$(sha256_file "$inherited/source.md")
source_manifest_sha=$(sha256_file "$inherited/target-baseline.sha256")
dependency_verification_sha=$(sha256_file "$inherited/dependency-verification.tsv")
dependency_manifest_sha=$(sha256_file "$cell/target/dependency-hashes.json")
bundle_manifest_sha=$(sha256_file "$inherited/bundle-hashes.sha256")
judge_bundle_sha=$(sha256_file "$judge/judge-bundle.md")
judge_command_sha=$(sha256_file "$judge/logs/judge.command.txt")
judge_events_sha=$(sha256_file "$judge/logs/judge.jsonl")
judge_status_sha=$(sha256_file "$judge/logs/judge.status.tsv")
judge_stderr_sha=$(sha256_file "$judge/logs/judge.stderr")
judge_response_sha=$(sha256_file "$judge/raw/judge-response.md")
gate_sha=$(sha256_file "$out/artifacts/gate-decisions.md")
coverage_sha=$(sha256_file "$out/artifacts/per-file-property-coverage.md")
unresolved_sha=$(sha256_file "$out/artifacts/UNRESOLVED-LEADS.md")
run_sha=$(sha256_file "$run/run-1.md")
report_sha=$(sha256_file "$run/full-report.md")
first_pass_sha=$(sha256_file "$out/FIRST-PASS.md")
native_report_sha=$(sha256_file "$out/native-report.md")
shape_input_sha=$(sha256_file "$out/artifacts/shape-repair/run-1.judge-extracted-with-ordinals.md")
shape_report_sha=$(sha256_file "$out/artifacts/shape-repair/full-report.superseded-double-ordinals.md")
before_sha=$(sha256_file "$out/integrity-before.json")
after_sha=$(sha256_file "$out/integrity-after.json")
freeze_sha=$(sha256_file "$freeze")
verifier_sha=$(sha256_file "$verifier")
runner_selection_sha=$(sha256_file "$out/runner-selection.json")
judge_started=$(awk -F '\t' 'NR == 1 { print $1 }' "$judge/logs/judge.status.tsv")
judge_completed=$(awk -F '\t' 'NR == 1 { print $2 }' "$judge/logs/judge.status.tsv")
judge_exit=$(awk -F '\t' 'NR == 1 { print $3 }' "$judge/logs/judge.status.tsv")
freeze_before_at=$(mtime_utc "$out/integrity-before.json")
freeze_after_at=$(mtime_utc "$out/integrity-after.json")
assembler_completed_at=$(mtime_utc "$run/full-report.md")

jq -n \
    --arg generated_at "$sealed_at" \
    --arg out "$out" \
    --arg cell "$cell" \
    --arg previous_cell "$previous_cell" \
    --arg method "$method" \
    --arg method_skill_sha "$method_skill_sha" \
    --arg method_version_sha "$method_version_sha" \
    --arg assembler_sha "$assembler_sha" \
    --arg scope_sha "$scope_sha" \
    --arg source_sha "$source_sha" \
    --arg source_manifest_sha "$source_manifest_sha" \
    --arg dependency_verification_sha "$dependency_verification_sha" \
    --arg dependency_manifest_sha "$dependency_manifest_sha" \
    --arg bundle_manifest_sha "$bundle_manifest_sha" \
    --arg specialist_validation_sha "$specialist_validation_sha" \
    --arg judge_bundle_sha "$judge_bundle_sha" \
    --arg judge_command_sha "$judge_command_sha" \
    --arg judge_events_sha "$judge_events_sha" \
    --arg judge_status_sha "$judge_status_sha" \
    --arg judge_stderr_sha "$judge_stderr_sha" \
    --arg judge_response_sha "$judge_response_sha" \
    --arg gate_sha "$gate_sha" \
    --arg coverage_sha "$coverage_sha" \
    --arg unresolved_sha "$unresolved_sha" \
    --arg run_sha "$run_sha" \
    --arg report_sha "$report_sha" \
    --arg first_pass_sha "$first_pass_sha" \
    --arg native_report_sha "$native_report_sha" \
    --arg shape_input_sha "$shape_input_sha" \
    --arg shape_report_sha "$shape_report_sha" \
    --arg before_sha "$before_sha" \
    --arg after_sha "$after_sha" \
    --arg freeze_sha "$freeze_sha" \
    --arg verifier_sha "$verifier_sha" \
    --arg runner_selection_sha "$runner_selection_sha" \
    --arg judge_started "$judge_started" \
    --arg judge_completed "$judge_completed" \
    --argjson judge_exit "$judge_exit" \
    --arg freeze_before_at "$freeze_before_at" \
    --arg freeze_after_at "$freeze_after_at" \
    --arg assembler_completed_at "$assembler_completed_at" \
    --slurpfile specialist_validation "$out/artifacts/specialist-validation.json" \
    --slurpfile integrity_before "$out/integrity-before.json" \
    --slurpfile integrity_after "$out/integrity-after.json" \
    '{
      schema: "daybreak-pashov-stage-ledger-v1",
      generated_at: $generated_at,
      status: "complete",
      cell: "DAYBREAK-PASHOV",
      attempt: "attempt-03",
      continuation_of_same_cell: true,
      output_root: $out,
      runtime_root: $cell,
      inherited_same_cell_root: $previous_cell,
      authorization_boundary: {
        source_only_first_pass: true,
        tests_exposed_before_seal: false,
        historical_audits_exposed: false,
        scanner_campaigns_exposed: false,
        cross_cell_reconciliation_performed: false,
        accepted_risks_exposed: false,
        live_transactions_or_publication: false,
        production_or_configuration_edits: false
      },
      source: {
        frozen_commit: "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
        mode: "filename",
        production_files: [
          {path: "target/packages/contracts/src/Raffle.sol", sha256: "6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617"},
          {path: "target/packages/contracts/src/RaffleFactory.sol", sha256: "d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace"},
          {path: "target/packages/contracts/src/interfaces/IRaffle.sol", sha256: "a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd"},
          {path: "target/packages/contracts/src/interfaces/IRaffleFactory.sol", sha256: "747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf"},
          {path: "target/packages/contracts/src/libraries/RaffleConstants.sol", sha256: "0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6"}
        ],
        design: {path: "target/DESIGN.md", sha256: "25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1"},
        reachable_dependencies: 31,
        dependency_manifest: {path: "target/dependency-hashes.json", sha256: $dependency_manifest_sha},
        full_target_baseline: {path: "artifacts/inherited-specialists/target-baseline.sha256", sha256: $source_manifest_sha},
        dependency_verification: {path: "artifacts/inherited-specialists/dependency-verification.tsv", sha256: $dependency_verification_sha},
        concatenated_source: {path: "artifacts/inherited-specialists/source.md", lines: 7117, bytes: 288539, sha256: $source_sha},
        native_scope: {path: "artifacts/native-run/20261021-005946/scope.tsv", sha256: $scope_sha}
      },
      method: {
        name: "Pashov solidity-auditor",
        version: 4,
        pinned_path: $method,
        git_pin: "8ce544c9c9affab448d3dc4c79191d052e3a57ec",
        skill_copy: {path: "artifacts/method/SKILL.md", sha256: $method_skill_sha},
        version_copy: {path: "artifacts/method/VERSION", sha256: $method_version_sha},
        assembler_copy: {path: "artifacts/method/references/assemble.sh", sha256: $assembler_sha, modified: false},
        pass_mode: "SINGLE PASS",
        passes_completed: 1,
        memory: "OFF",
        specialists_required: 12,
        specialists_completed: 12,
        run_id: "20261021-005946"
      },
      actual_model_selection: {
        executable: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
        runner_version: "0.163.0-alpha.10.2",
        model: "gpt-daybreak-blue-latest",
        cyber_access_program: "daybreak_blue",
        reasoning_effort: "ultra",
        fallback: false,
        provider_returned_identity: null,
        provider_identity_note: "Provider event streams omit model identity; requested/locally accepted selection is evidenced by command records.",
        runner_selection: {path: "runner-selection.json", sha256: $runner_selection_sha},
        fresh_stage_option_spine: "--ignore-user-config --ephemeral --skip-git-repo-check -s danger-full-access -m gpt-daybreak-blue-latest --cyber-access-program daybreak_blue -c model_reasoning_effort=\"ultra\" -c features.multi_agent=false --json"
      },
      stages: [
        {
          id: "method-load-and-pin",
          native_turn: 0,
          status: "completed",
          provenance: "continuation",
          model_driven: false,
          evidence: ["artifacts/method/SKILL.md", "artifacts/method/VERSION", "artifacts/method/references/"],
          hashes: {skill_sha256: $method_skill_sha, git_pin: "8ce544c9c9affab448d3dc4c79191d052e3a57ec"}
        },
        {
          id: "freeze-verification-before",
          native_turn: 0,
          status: "completed",
          provenance: "continuation",
          completed_at: $freeze_before_at,
          model_driven: false,
          command: "python3 /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/verify-freeze.py",
          result: $integrity_before[0],
          evidence: {path: "integrity-before.json", sha256: $before_sha, freeze_json_sha256: $freeze_sha, verifier_sha256: $verifier_sha}
        },
        {
          id: "discover-and-scope",
          native_turn: 1,
          native_step: "Turn 1",
          status: "completed",
          provenance: "inherited same-cell stage",
          model_driven: false,
          evidence: {scope_path: "artifacts/native-run/20261021-005946/scope.tsv", scope_sha256: $scope_sha, target_manifest_sha256: $source_manifest_sha}
        },
        {
          id: "user-choice",
          native_turn: 1,
          native_step: "Turn 1b",
          status: "completed",
          provenance: "inherited same-cell stage plus explicit continuation authorization",
          model_driven: false,
          choices: {mode: "filename", passes: 1, memory: "OFF", specialists: 12, model: "gpt-daybreak-blue-latest", cyber_access_program: "daybreak_blue", reasoning_effort: "ultra"}
        },
        {
          id: "memory-load",
          native_turn: 1,
          native_step: "Turn 1c",
          status: "skipped-by-configuration",
          provenance: "native method",
          model_driven: false,
          reason: "Memory OFF"
        },
        {
          id: "build-source-and-specialist-bundles",
          native_turn: 2,
          status: "completed",
          provenance: "inherited same-cell stage",
          model_driven: false,
          evidence: {
            source: {path: "artifacts/inherited-specialists/source.md", sha256: $source_sha},
            bundle_hashes: {path: "artifacts/inherited-specialists/bundle-hashes.sha256", sha256: $bundle_manifest_sha},
            upstream_resource_hashes: "artifacts/inherited-specialists/upstream-reference-hashes.sha256"
          }
        },
        {
          id: "initial-specialist-wave",
          native_turn: 3,
          status: "superseded-and-preserved",
          provenance: "inherited same-cell stage",
          model_driven: true,
          accepted_downstream: false,
          reason: "Nine contexts lacked evidenced route inheritance for attempted nested collaboration; agents 4, 11, and 12 were superseded for uniform provenance.",
          stale_raw_output_used: false,
          evidence: ["artifacts/inherited-specialists/logs/rejected-termination.tsv", "artifacts/inherited-specialists/logs/superseded-termination.tsv", "artifacts/inherited-specialists/raw/agent-5.md"]
        },
        {
          id: "corrected-specialist-wave",
          native_turn: 3,
          status: "completed",
          provenance: "inherited same-cell stage",
          started_at: "2026-10-21T08:15:31Z",
          completed_at: "2026-10-21T08:38:00Z",
          model_driven: true,
          model: "gpt-daybreak-blue-latest",
          cyber_access_program: "daybreak_blue",
          reasoning_effort: "ultra",
          fallback: false,
          provider_returned_identity: null,
          runner_note: "Inherited corrected contexts used --disable multi_agent and read-only sandbox; these are the user-declared accepted corrected set.",
          validation: $specialist_validation[0].selection,
          provider_rejections: $specialist_validation[0].provider_rejections,
          evidence: {path: "artifacts/specialist-validation.json", sha256: $specialist_validation_sha}
        },
        {
          id: "judge-bundle-reconstruction",
          native_turn: 4,
          status: "completed",
          provenance: "continuation local repair",
          model_driven: false,
          source_inputs: ["pinned method resources", "accepted corrected raw specialist responses", "inherited source.md"],
          evidence: {path: "artifacts/native-judge/judge-bundle.md", lines: 8844, bytes: 422994, sha256: $judge_bundle_sha}
        },
        {
          id: "collect-and-deduplicate",
          native_turn: 4,
          native_step: 1,
          status: "completed",
          provenance: "continuation native judge",
          model_driven: true,
          model: "gpt-daybreak-blue-latest",
          cyber_access_program: "daybreak_blue",
          reasoning_effort: "ultra",
          fallback: false,
          provider_returned_identity: null,
          shared_judge_evidence: {response_sha256: $judge_response_sha, gate_decisions_sha256: $gate_sha}
        },
        {
          id: "apply-four-gates",
          native_turn: 4,
          native_step: 2,
          status: "completed",
          provenance: "continuation native judge",
          model_driven: true,
          model: "gpt-daybreak-blue-latest",
          cyber_access_program: "daybreak_blue",
          reasoning_effort: "ultra",
          fallback: false,
          provider_returned_identity: null,
          candidate_count: 20,
          canonical_group_count: 5,
          evidence: {path: "artifacts/gate-decisions.md", sha256: $gate_sha}
        },
        {
          id: "coverage",
          native_turn: 4,
          native_step: 3,
          status: "completed",
          provenance: "continuation native judge",
          model_driven: true,
          model: "gpt-daybreak-blue-latest",
          cyber_access_program: "daybreak_blue",
          reasoning_effort: "ultra",
          fallback: false,
          provider_returned_identity: null,
          completeness: "5 unique (Contract, function) pairs in raw; 5 covered in final",
          evidence: {path: "artifacts/per-file-property-coverage.md", sha256: $coverage_sha}
        },
        {
          id: "memory-check",
          native_turn: 4,
          native_step: 4,
          status: "skipped-by-configuration",
          provenance: "native method",
          model_driven: false,
          reason: "Memory OFF"
        },
        {
          id: "global-second-pass-and-run-draft",
          native_turn: 4,
          native_step: 5,
          status: "completed",
          provenance: "continuation native judge",
          started_at: $judge_started,
          completed_at: $judge_completed,
          model_driven: true,
          model: "gpt-daybreak-blue-latest",
          cyber_access_program: "daybreak_blue",
          reasoning_effort: "ultra",
          fallback: false,
          provider_returned_identity: null,
          runtime: {
            exit_code: $judge_exit,
            turn_completed_count: 1,
            turn_failed_count: 0,
            provider_rejection_count: 0,
            command_sha256: $judge_command_sha,
            events_sha256: $judge_events_sha,
            status_sha256: $judge_status_sha,
            stderr_sha256: $judge_stderr_sha,
            response_sha256: $judge_response_sha,
            usage: {input_tokens: 1894083, cached_input_tokens: 1758208, output_tokens: 33697, reasoning_output_tokens: 22589}
          }
        },
        {
          id: "known-findings-ledger",
          native_turn: 4,
          native_step: 6,
          status: "skipped-by-configuration",
          provenance: "native method",
          model_driven: false,
          reason: "Memory OFF"
        },
        {
          id: "run-file-shape-normalization",
          native_turn: 4,
          status: "completed",
          provenance: "continuation local format repair",
          model_driven: false,
          exact_change: "Removed only redundant numeric ordinals embedded in the two finding title lines because the pinned assembler supplies numbering; finding content, confidence, descriptions, and fixes were unchanged.",
          evidence: {
            pre_normalization_run_sha256: $shape_input_sha,
            superseded_double_ordinal_report_sha256: $shape_report_sha,
            normalized_run_sha256: $run_sha
          }
        },
        {
          id: "unmodified-native-assembly",
          native_turn: 5,
          status: "completed",
          provenance: "continuation native assembler",
          completed_at: $assembler_completed_at,
          model_driven: false,
          command: "bash artifacts/method/references/assemble.sh --dir .solidity-auditor/runs/20261021-005946",
          assembler_modified: false,
          assembler_sha256: $assembler_sha,
          counts: {findings: 2, leads: 0, listed_findings: 2, listed_leads: 0, unclassified: 0},
          evidence: {
            run_path: "artifacts/native-run/20261021-005946/run-1.md",
            run_sha256: $run_sha,
            report_path: "artifacts/native-run/20261021-005946/full-report.md",
            report_sha256: $report_sha,
            native_report_sha256: $native_report_sha,
            first_pass_sha256: $first_pass_sha
          }
        },
        {
          id: "freeze-verification-after",
          native_turn: 5,
          status: "completed",
          provenance: "continuation",
          completed_at: $freeze_after_at,
          model_driven: false,
          command: "python3 /Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/verify-freeze.py",
          result: $integrity_after[0],
          evidence: {path: "integrity-after.json", sha256: $after_sha, freeze_json_sha256: $freeze_sha, verifier_sha256: $verifier_sha}
        },
        {
          id: "source-first-pass-seal",
          native_turn: 5,
          status: "completed",
          provenance: "continuation",
          completed_at: $generated_at,
          model_driven: false,
          report_sha256: $first_pass_sha,
          seal_path: "SEAL.json",
          hash_manifest_path: "HASHES.sha256"
        }
      ],
      local_repairs: [
        "Reconstructed the absent judge bundle from pinned method resources, inherited source, and only the accepted corrected specialist outputs.",
        "Changed a local macOS awk validator variable name from close to closes; no audit content changed.",
        "Corrected a local metadata-comment regex to accept the native closing marker; no audit content changed.",
        "Normalized duplicate title ordinals before rerunning the unmodified assembler; superseded output was preserved.",
        "When destructive runtime cleanup was locally refused, preserved the complete original native-judge runtime by moving it into artifacts/native-judge-runtime-original."
      ],
      result: {
        findings: 2,
        leads: 0,
        unresolved_leads: 0,
        unresolved_leads_evidence: {path: "artifacts/UNRESOLVED-LEADS.md", sha256: $unresolved_sha},
        finding_keys: [
          "rafflefactory|createraffle|fake-prize-escrow",
          "raffle|releasesponsorproceeds|payout-before-prize-delivery"
        ],
        report: {path: "FIRST-PASS.md", sha256: $first_pass_sha},
        exact_native_report: {path: "native-report.md", sha256: $native_report_sha},
        byte_identical_report_copies: ($first_pass_sha == $native_report_sha and $native_report_sha == $report_sha)
      }
    }' > "$out/stage-ledger.json"

jq -S '.' "$out/stage-ledger.json" > "$package/stage-ledger.sorted.json"
cp "$package/stage-ledger.sorted.json" "$out/stage-ledger.json"

printf 'artifact=FIRST-PASS.md\nsealed_at_utc=%s\nsha256=%s\n' "$sealed_at" "$first_pass_sha" > "$out/FIRST-PASS.timestamp.txt"
printf '%s  %s\n' "$first_pass_sha" 'FIRST-PASS.md' > "$out/FIRST-PASS.sha256"

(
    cd "$out"
    {
        find artifacts -type f -print
        printf '%s\n' FIRST-PASS.md FIRST-PASS.sha256 FIRST-PASS.timestamp.txt integrity-after.json integrity-before.json native-report.md runner-selection.json stage-ledger.json
    } | LC_ALL=C sort -u | while IFS= read -r path; do
        shasum -a 256 "$path"
    done > HASHES.sha256
)

manifest_sha=$(sha256_file "$out/HASHES.sha256")
sealed_file_count=$(wc -l < "$out/HASHES.sha256" | tr -d ' ')
stage_ledger_sha=$(sha256_file "$out/stage-ledger.json")
timestamp_sha=$(sha256_file "$out/FIRST-PASS.timestamp.txt")
first_pass_checksum_sha=$(sha256_file "$out/FIRST-PASS.sha256")

jq -n \
    --arg sealed_at "$sealed_at" \
    --arg manifest_sha "$manifest_sha" \
    --argjson sealed_file_count "$sealed_file_count" \
    --arg first_pass_sha "$first_pass_sha" \
    --arg native_report_sha "$native_report_sha" \
    --arg report_sha "$report_sha" \
    --arg run_sha "$run_sha" \
    --arg scope_sha "$scope_sha" \
    --arg stage_ledger_sha "$stage_ledger_sha" \
    --arg timestamp_sha "$timestamp_sha" \
    --arg first_pass_checksum_sha "$first_pass_checksum_sha" \
    --arg specialist_validation_sha "$specialist_validation_sha" \
    --arg judge_bundle_sha "$judge_bundle_sha" \
    --arg judge_response_sha "$judge_response_sha" \
    --arg gate_sha "$gate_sha" \
    --arg coverage_sha "$coverage_sha" \
    --arg unresolved_sha "$unresolved_sha" \
    --arg before_sha "$before_sha" \
    --arg after_sha "$after_sha" \
    --arg source_manifest_sha "$source_manifest_sha" \
    --arg dependency_manifest_sha "$dependency_manifest_sha" \
    --arg source_sha "$source_sha" \
    --arg freeze_sha "$freeze_sha" \
    --arg verifier_sha "$verifier_sha" \
    --arg method_skill_sha "$method_skill_sha" \
    --arg assembler_sha "$assembler_sha" \
    --slurpfile specialist_validation "$out/artifacts/specialist-validation.json" \
    --slurpfile integrity_before "$out/integrity-before.json" \
    --slurpfile integrity_after "$out/integrity-after.json" \
    '{
      schema: "daybreak-pashov-source-first-pass-seal-v1",
      sealed_at: $sealed_at,
      status: "SEALED",
      cell: "DAYBREAK-PASHOV",
      attempt: "attempt-03",
      continuation_of_same_cell: true,
      source_only_first_pass: true,
      source: {
        frozen_commit: "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
        production_files: 5,
        reachable_dependency_files: 31,
        design_included: true,
        target_baseline_manifest_sha256: $source_manifest_sha,
        dependency_manifest_sha256: $dependency_manifest_sha,
        concatenated_source_sha256: $source_sha,
        freeze_json_sha256: $freeze_sha,
        verifier_sha256: $verifier_sha
      },
      method: {
        name: "Pashov solidity-auditor",
        version: 4,
        git_pin: "8ce544c9c9affab448d3dc4c79191d052e3a57ec",
        skill_sha256: $method_skill_sha,
        assembler_sha256: $assembler_sha,
        assembler_modified: false,
        pass: 1,
        memory: "OFF",
        specialists: "12/12"
      },
      actual_model_selection: {
        executable: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
        runner_version: "0.163.0-alpha.10.2",
        model: "gpt-daybreak-blue-latest",
        cyber_access_program: "daybreak_blue",
        reasoning_effort: "ultra",
        fallback: false,
        provider_returned_identity: null
      },
      specialist_validation: {
        sha256: $specialist_validation_sha,
        accepted_corrected_contexts: 12,
        raw_findings: 18,
        raw_leads: 2,
        actual_provider_rejection_log_occurrences: $specialist_validation[0].provider_rejections.total_log_occurrences,
        affected_auxiliary_turns: $specialist_validation[0].provider_rejections.unique_affected_non_parent_turn_ids,
        affected_routes_retried_or_counted: false
      },
      native_judge: {
        bundle_sha256: $judge_bundle_sha,
        response_sha256: $judge_response_sha,
        gate_decisions_sha256: $gate_sha,
        coverage_sha256: $coverage_sha,
        provider_rejection_count: 0,
        exit_code: 0,
        turn_completed_count: 1
      },
      result: {
        findings: 2,
        leads: 0,
        unresolved_leads: 0,
        finding_keys: [
          "rafflefactory|createraffle|fake-prize-escrow",
          "raffle|releasesponsorproceeds|payout-before-prize-delivery"
        ],
        unresolved_leads_sha256: $unresolved_sha,
        scope_sha256: $scope_sha,
        run_sha256: $run_sha,
        native_assembler_report_sha256: $report_sha,
        native_report_sha256: $native_report_sha,
        first_pass_sha256: $first_pass_sha,
        report_copies_byte_identical: ($first_pass_sha == $native_report_sha and $native_report_sha == $report_sha)
      },
      freeze_verification: {
        before: {result: $integrity_before[0], sha256: $before_sha},
        after: {result: $integrity_after[0], sha256: $after_sha}
      },
      exposure_boundary: {
        tests_exposed_before_seal: false,
        tests_or_reproductions_run_after_seal: false,
        historical_audits_exposed: false,
        scanner_campaigns_exposed: false,
        cross_cell_reconciliation_performed: false,
        accepted_risks_exposed: false,
        live_transactions_or_publication: false,
        production_or_configuration_edits: false
      },
      sealed_artifacts: {
        hash_manifest: "HASHES.sha256",
        hash_manifest_sha256: $manifest_sha,
        sealed_file_count: $sealed_file_count,
        stage_ledger_sha256: $stage_ledger_sha,
        first_pass_timestamp_sha256: $timestamp_sha,
        first_pass_checksum_file_sha256: $first_pass_checksum_sha
      },
      unsealed_controller_files: {
        paths: ["command.json", "prompt.txt", "events.jsonl", "stderr.txt", "pid.txt", "controller-final.md", "SEAL.json", "SEAL.sha256"],
        reason: "Outer controller streams may remain live through handoff; SEAL.json cannot self-hash and SEAL.sha256 is its detached checksum. None is an audit input or native report artifact."
      }
    }' > "$out/SEAL.json"

jq -S '.' "$out/SEAL.json" > "$package/SEAL.sorted.json"
cp "$package/SEAL.sorted.json" "$out/SEAL.json"
seal_sha=$(sha256_file "$out/SEAL.json")
printf '%s  %s\n' "$seal_sha" 'SEAL.json' > "$out/SEAL.sha256"

(
    cd "$out"
    shasum -a 256 -c HASHES.sha256
    shasum -a 256 -c FIRST-PASS.sha256
    shasum -a 256 -c SEAL.sha256
)

jq -e '
  .status == "SEALED" and
  .source_only_first_pass == true and
  .method.specialists == "12/12" and
  .result.findings == 2 and
  .result.leads == 0 and
  .result.unresolved_leads == 0 and
  .result.report_copies_byte_identical == true and
  .freeze_verification.before.result.ok == true and
  .freeze_verification.after.result.ok == true and
  .exposure_boundary.tests_exposed_before_seal == false and
  .exposure_boundary.cross_cell_reconciliation_performed == false
' "$out/SEAL.json" >/dev/null

jq -e '
  .status == "complete" and
  .method.specialists_completed == 12 and
  .result.findings == 2 and
  .result.leads == 0 and
  .result.unresolved_leads == 0 and
  .result.byte_identical_report_copies == true and
  ([.stages[] | select(.status == "completed") | .id] | index("source-first-pass-seal") != null)
' "$out/stage-ledger.json" >/dev/null

printf 'sealed_at=%s\n' "$sealed_at"
printf 'first_pass_sha256=%s\n' "$first_pass_sha"
printf 'hash_manifest_sha256=%s\n' "$manifest_sha"
printf 'seal_sha256=%s\n' "$seal_sha"
printf 'sealed_file_count=%s\n' "$sealed_file_count"
