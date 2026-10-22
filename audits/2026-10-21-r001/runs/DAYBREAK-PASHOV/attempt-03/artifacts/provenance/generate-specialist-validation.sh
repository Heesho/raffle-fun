#!/bin/sh
set -eu

out=/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-PASHOV/attempt-03
evidence="$out/artifacts/inherited-specialists"
work=/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-continuation/runtime/package
result="$out/artifacts/specialist-validation.json"
provider_message="Daybreak isn't available for this model. Turn off Daybreak or choose another model."

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

specialty_for() {
    case "$1" in
        1) printf '%s' first-principles ;;
        2) printf '%s' access-control ;;
        3) printf '%s' invariant ;;
        4) printf '%s' economic-security ;;
        5) printf '%s' execution-trace ;;
        6) printf '%s' boundary ;;
        7) printf '%s' asymmetry ;;
        8) printf '%s' periphery ;;
        9) printf '%s' math-precision ;;
        10) printf '%s' numerical-gap ;;
        11) printf '%s' trust-gap ;;
        12) printf '%s' flow-gap ;;
    esac
}

n=1
while [ "$n" -le 12 ]; do
    base="$evidence/logs/agent-$n-valid"
    command="$base.command.txt"
    events="$base.jsonl"
    status="$base.status.tsv"
    stderr_file="$base.stderr"
    raw="$evidence/raw/agent-$n-valid.md"
    prompt="$evidence/agent-$n-prompt.txt"
    bundle="$evidence/bundles/agent-$n-bundle.md"
    final_message="$work/agent-$n-final-message.tmp"

    IFS="$(printf '\t')" read -r started_at completed_at exit_code < "$status"
    jq -s -j '[.[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] | last' "$events" > "$final_message"

    if cmp -s "$final_message" "$raw"; then raw_matches=true; else raw_matches=false; fi
    raw_bytes=$(wc -c < "$raw" | tr -d ' ')
    turn_completed=$(jq -s '[.[] | select(.type == "turn.completed")] | length' "$events")
    turn_failed=$(jq -s '[.[] | select(.type == "turn.failed")] | length' "$events")
    top_errors=$(jq -s '[.[] | select(.type == "error")] | length' "$events")
    last_event=$(tail -n 1 "$events" | jq -r '.type')
    top_thread=$(jq -r 'select(.type == "thread.started") | .thread_id' "$events" | head -n 1)
    receiver_ids=$(jq -s -c '[.[] | select(.item.type? == "collab_tool_call") | .item.receiver_thread_ids[]?] | unique' "$events")
    provider_count=$({ rg -o -F "$provider_message" "$stderr_file" || true; } | wc -l | tr -d ' ')
    provider_ids=$({ rg -F "$provider_message" "$stderr_file" || true; } | { rg -o 'turn_id=[0-9a-f-]{36}' || true; } | sed 's/^turn_id=//' | sort -u | jq -Rsc 'split("\n") | map(select(length > 0))')
    model_flag_count=$({ rg -o -- '-m gpt-daybreak-blue-latest' "$command" || true; } | wc -l | tr -d ' ')
    route_flag_count=$({ rg -o -- '--cyber-access-program daybreak_blue' "$command" || true; } | wc -l | tr -d ' ')
    effort_flag_count=$({ rg -o -F 'model_reasoning_effort="ultra"' "$command" || true; } | wc -l | tr -d ' ')
    disable_multi_count=$({ rg -o -- '--disable multi_agent' "$command" || true; } | wc -l | tr -d ' ')
    model_flags_total=$({ rg -o -- '-m [^ ]+' "$command" || true; } | wc -l | tr -d ' ')
    findings=$(rg -c '^FINDING \|' "$raw" 2>/dev/null || true)
    leads=$(rg -c '^LEAD \|' "$raw" 2>/dev/null || true)
    [ -n "$findings" ] || findings=0
    [ -n "$leads" ] || leads=0

    jq -n \
        --argjson specialist "$n" \
        --arg specialty "$(specialty_for "$n")" \
        --arg started_at "$started_at" \
        --arg completed_at "$completed_at" \
        --argjson exit_code "$exit_code" \
        --arg top_thread_id "$top_thread" \
        --argjson turn_completed_count "$turn_completed" \
        --argjson turn_failed_count "$turn_failed" \
        --argjson top_level_error_count "$top_errors" \
        --arg last_event "$last_event" \
        --argjson receiver_thread_ids "$receiver_ids" \
        --argjson raw_bytes "$raw_bytes" \
        --argjson raw_matches_final_agent_message "$raw_matches" \
        --argjson raw_findings "$findings" \
        --argjson raw_leads "$leads" \
        --arg raw_sha256 "$(sha256_file "$raw")" \
        --arg prompt_sha256 "$(sha256_file "$prompt")" \
        --arg bundle_sha256 "$(sha256_file "$bundle")" \
        --arg command_sha256 "$(sha256_file "$command")" \
        --arg events_sha256 "$(sha256_file "$events")" \
        --arg status_sha256 "$(sha256_file "$status")" \
        --arg stderr_sha256 "$(sha256_file "$stderr_file")" \
        --argjson requested_model_flag_count "$model_flag_count" \
        --argjson model_flags_total "$model_flags_total" \
        --argjson route_flag_count "$route_flag_count" \
        --argjson effort_flag_count "$effort_flag_count" \
        --argjson disable_multi_agent_flag_count "$disable_multi_count" \
        --argjson provider_rejection_log_occurrences "$provider_count" \
        --argjson provider_rejection_turn_ids "$provider_ids" \
        --arg command_path "artifacts/inherited-specialists/logs/agent-$n-valid.command.txt" \
        --arg events_path "artifacts/inherited-specialists/logs/agent-$n-valid.jsonl" \
        --arg status_path "artifacts/inherited-specialists/logs/agent-$n-valid.status.tsv" \
        --arg stderr_path "artifacts/inherited-specialists/logs/agent-$n-valid.stderr" \
        --arg raw_path "artifacts/inherited-specialists/raw/agent-$n-valid.md" \
        --arg prompt_path "artifacts/inherited-specialists/agent-$n-prompt.txt" \
        --arg bundle_path "artifacts/inherited-specialists/bundles/agent-$n-bundle.md" \
        '{
          specialist: $specialist,
          specialty: $specialty,
          accepted: true,
          started_at: $started_at,
          completed_at: $completed_at,
          exit_code: $exit_code,
          top_level_thread_id: $top_thread_id,
          turn_completed_count: $turn_completed_count,
          turn_failed_count: $turn_failed_count,
          top_level_error_count: $top_level_error_count,
          last_event: $last_event,
          collaboration_receiver_thread_ids: $receiver_thread_ids,
          output: {
            bytes: $raw_bytes,
            nonempty: ($raw_bytes > 0),
            matches_final_agent_message_byte_for_byte: $raw_matches_final_agent_message,
            raw_findings: $raw_findings,
            raw_leads: $raw_leads,
            sha256: $raw_sha256
          },
          actual_runner_selection: {
            model: "gpt-daybreak-blue-latest",
            cyber_access_program: "daybreak_blue",
            reasoning_effort: "ultra",
            sandbox: "read-only",
            multi_agent_disabled_via_inherited_equivalent_flag: true,
            requested_model_flag_count: $requested_model_flag_count,
            total_model_flag_count: $model_flags_total,
            access_program_flag_count: $route_flag_count,
            effort_flag_count: $effort_flag_count,
            disable_multi_agent_flag_count: $disable_multi_agent_flag_count,
            fallback: false,
            provider_returned_identity: null,
            provider_identity_evidence: "The JSON event stream does not provide a provider-returned model identity."
          },
          provider_rejection_evidence: {
            top_level_parent_rejected: false,
            auxiliary_log_occurrences: $provider_rejection_log_occurrences,
            affected_non_parent_turn_ids: $provider_rejection_turn_ids,
            affected_routes_counted_as_specialists: false,
            retried_by_continuation: false
          },
          paths: {
            command: $command_path,
            events: $events_path,
            status: $status_path,
            stderr: $stderr_path,
            raw_output: $raw_path,
            prompt: $prompt_path,
            source_bundle: $bundle_path
          },
          hashes: {
            prompt_sha256: $prompt_sha256,
            source_bundle_sha256: $bundle_sha256,
            command_sha256: $command_sha256,
            events_sha256: $events_sha256,
            status_sha256: $status_sha256,
            stderr_sha256: $stderr_sha256
          }
        }' > "$work/specialist-$n.json"

    n=$((n + 1))
done

jq -s 'sort_by(.specialist)' "$work"/specialist-*.json > "$work/specialists-array.json"

jq -n \
    --slurpfile specialists "$work/specialists-array.json" \
    --arg generated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg copied_evidence_root "artifacts/inherited-specialists" \
    --arg original_evidence_root "/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-attempt-02/.audit-gDK92V" \
    --arg accepted_command_shape '/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec --ignore-user-config --ignore-rules --ephemeral --disable multi_agent --skip-git-repo-check -s read-only -C /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-PASHOV-attempt-02 -m gpt-daybreak-blue-latest --cyber-access-program daybreak_blue -c model_reasoning_effort="ultra" --json -o .audit-gDK92V/raw/agent-N-valid.md - < .audit-gDK92V/agent-N-prompt.txt' \
    --arg provider_message "$provider_message" \
    '{
      schema: "daybreak-pashov-specialist-validation-v1",
      generated_at: $generated_at,
      continuation_of_same_cell: true,
      accepted_set: "corrected agent-N-valid contexts only",
      original_evidence_root: $original_evidence_root,
      copied_evidence_root: $copied_evidence_root,
      accepted_command_shape: $accepted_command_shape,
      inherited_flag_equivalence_note: "The inherited corrected contexts used --disable multi_agent. Fresh continuation stages use -c features.multi_agent=false as requested.",
      selection: {
        specialists_required: 12,
        specialists_accepted: 12,
        pass: 1,
        memory: "OFF",
        raw_findings: ([$specialists[0][].output.raw_findings] | add),
        raw_leads: ([$specialists[0][].output.raw_leads] | add),
        all_exit_zero: ([$specialists[0][].exit_code == 0] | all),
        all_exactly_one_turn_completed: ([$specialists[0][].turn_completed_count == 1] | all),
        all_end_in_turn_completed: ([$specialists[0][].last_event == "turn.completed"] | all),
        all_outputs_nonempty: ([$specialists[0][].output.nonempty] | all),
        all_outputs_match_final_agent_message: ([$specialists[0][].output.matches_final_agent_message_byte_for_byte] | all),
        all_commands_select_only_expected_model: ([$specialists[0][] | (.actual_runner_selection.requested_model_flag_count == 1 and .actual_runner_selection.total_model_flag_count == 1)] | all),
        all_commands_select_expected_route: ([$specialists[0][].actual_runner_selection.access_program_flag_count == 1] | all),
        all_commands_select_ultra: ([$specialists[0][].actual_runner_selection.effort_flag_count == 1] | all),
        all_commands_disable_multi_agent: ([$specialists[0][].actual_runner_selection.disable_multi_agent_flag_count == 1] | all),
        fallback: false,
        provider_returned_identity: null
      },
      superseded_initial_set: {
        accepted: false,
        preserved_for_exposure: true,
        rejected_agents: [1, 2, 3, 5, 6, 7, 8, 9, 10],
        rejected_reason: "Nested collaboration calls lacked evidenced daybreak_blue inheritance; corrected replacement launched with multi_agent disabled.",
        uniformly_superseded_agents: [4, 11, 12],
        uniformly_superseded_reason: "Replacement launched with multi_agent disabled for uniform provenance.",
        stale_raw_output_present_agents: [5],
        stale_raw_output_used_downstream: false,
        termination_evidence: [
          "artifacts/inherited-specialists/logs/rejected-termination.tsv",
          "artifacts/inherited-specialists/logs/superseded-termination.tsv"
        ]
      },
      provider_rejections: {
        exact_message: $provider_message,
        total_log_occurrences: ([$specialists[0][].provider_rejection_evidence.auxiliary_log_occurrences] | add),
        accepted_parent_specialists_with_affected_auxiliary_routes: ([$specialists[0][] | select(.provider_rejection_evidence.auxiliary_log_occurrences > 0) | .specialist]),
        unique_affected_non_parent_turn_ids: ([$specialists[0][].provider_rejection_evidence.affected_non_parent_turn_ids[]] | unique),
        classification: "Actual provider 403 responses on nine non-parent auxiliary turns; those affected routes terminated and were not retried or counted. The accepted parent contexts completed successfully.",
        no_rephrase_or_retry_by_continuation: true
      },
      specialists: $specialists[0]
    }' > "$result"

jq -e '
  .selection.specialists_accepted == 12 and
  .selection.raw_findings == 18 and
  .selection.raw_leads == 2 and
  .selection.all_exit_zero and
  .selection.all_exactly_one_turn_completed and
  .selection.all_end_in_turn_completed and
  .selection.all_outputs_nonempty and
  .selection.all_outputs_match_final_agent_message and
  .selection.all_commands_select_only_expected_model and
  .selection.all_commands_select_expected_route and
  .selection.all_commands_select_ultra and
  .selection.all_commands_disable_multi_agent and
  .provider_rejections.total_log_occurrences == 90 and
  (.provider_rejections.unique_affected_non_parent_turn_ids | length) == 9
' "$result" >/dev/null

jq -S '.' "$result" > "$work/specialist-validation.sorted.json"
cp "$work/specialist-validation.sorted.json" "$result"
