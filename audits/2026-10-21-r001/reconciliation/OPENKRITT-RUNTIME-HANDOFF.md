# OpenKritt r001 runtime handoff

Runtime root: /Users/hishamel-husseini/.local/share/glaze-audit-harnesses/openkritt/raffle-fun-r001
Docker host: unix:///Users/hishamel-husseini/.lima/glaze-openkritt-daybreak/sock/docker.sock
Native upstream:43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3.

Both requested native workflows are running under a disclosed isolated compatibility method. Native completion is not yet claimed. The60-minute agent orchestration window does not stop any model job or scan. Only an actual OpenAI provider rejection may terminate an affected lane; local setup failures must be repaired rather than treated as final blockers.

## Owned resources

- raffle-r001-engine: native worker/queue/post-process engine against fresh PostgreSQL; no published ports/backend service.
- raffle-r001-db and raffle-r001-postgres volume: fresh dedicated database; networkraffle-r001-net, aliasdb. Database connection is recorded in runtime-config-public.json.
- raffle-r001-base-reference: retains original imagec247b67cb3b2…; Python files exactly match pinned upstream.
- raffle-r001-cli-reference: retains image2724f091e794662e7656f81c75aba84eebae7ee97efe57951c8b255bd685450f, with official Codex0.163.0.
- raffle-r001-engine-socket-baseline: stopped diagnostic of the repaired rootless socket mount.
- Per-job names/labels:raffle-r001-scan-* and raffle-r001.scan-runner/sandbox. Shared-host global stale-container cleanup is guarded off. New engine Docker prune flags are false. Do not touch unrelated open-kritt-* resources.

The rootless socket source inside the VM is /run/user/501/docker.sock, mounted as /var/run/docker.sock. The initially assumed /var/run/docker.sock source was not the daemon socket; its error remains preserved.

## Requested lanes and routing

- DB scan1 → OPENAI-OPENKRITT: exactgpt-6-astra, ultra, ordinary authenticated OpenAI route, no cyber program flag.
- DB scan2 → DAYBREAK-OPENKRITT: exactgpt-daybreak-blue-latest, ultra, explicit --cyber-access-program daybreak_blue.

Pinned source does not natively add the program flag. Base CLI0.145.0 and separately checked0.159.2 reject it locally; official pinned0.163.0 accepts exec and resume. Compatibility patch covers both exec/resume, rejects all unrequested model strings and disables multi_agent. Native workflow, schema, queue, dedupe/ranking and post-script logic remain unmodified. Workflow/default ranker/post-script definitions are seeded from this pinned upstream into fresh DB. Full source/flow fan-out remains intact; no results or tasks are capped to fit the orchestration window.

Provider-returned model identity is not independently attested. Actual command tuples and native metadata identify requested model/program/effort. Native subagent counts remain zero; observed collaboration events are empty-recipient waits, not spawns. No old source, findings, DB, corpora, provider config or account memory was reused. Target source has one fresh snapshot commit and all43 frozen source/dependency/config files are tracked and hashed.

## Observe/export

Read evidence/latest-status.json or run docker logs for raffle-r001-engine. The output path mapping is evidence/lane-output-paths.json.

`python3 <runtime-root>/evidence/export_lanes.py` exports current native records to both attempt-02 directories without exposing auth files. Running exports are progress snapshots. A completed lane is sealed and then skipped on later exports, preserving its seal. Source integrity is rechecked before completed seals. A failure is not automatically sealed or reclassified as a provider rejection; inspect exact retained errors first.

Existing observers:

- evidence/monitor.py: statuses/commands,3000-second observer budget from approximately08:34UTC.
- evidence/capture_runner_logs.py: exact Docker CLI event streams,2400-second budget from approximately08:46UTC. Early successful calls may have only native DB outputs/command evidence rather than a full CLI stream.
- evidence/export_on_completion.py: checks completion and invokes exporter automatically;2400-second observer budget. These observer deadlines do not stop the persistent native engine. Restart observers if needed; no need to recreate model jobs merely to observe them.

The live runtime config is data/engine-runtime.env:15workers/account slots, max2scans,512MiB hard/256MiB soft per new runner,0.25CPU. Resource adjustments are recorded. All current native calls are source-review/flow tasks on isolated clean copies; no production changes or live target requests were authorized.

## Completion handling

Keep actual complete vs running/failed state explicit. Export canonical findings/enrichments only from their native records; do not fabricate post-processing calls when there are no eligible findings. Selected native post-scripts are PoC Creator, Report Creator, Is Malicious Actor in scope and Ease of exploitability, with Blockchain security triage ranking. Parent reconciliation should assess native findings after sealing; the runtime operator has not independently reviewed or endorsed their security substance.

Once both scans are terminal and artifacts are captured, stopping our own engine is optional reversible runtime housekeeping. Do not prune Docker resources or remove unrelated data. Preserve prior BLOCKED attempt-01 diagnostics as superseded local setup evidence.
