BEGIN;
INSERT INTO public.steps(id,content,output_format,name,depth,multi_output,is_last_step,output_table,consume_all_previous) VALUES(1,'You are mapping the externally reachable attack surface of {{repo_full}} at commit {{commit_sha}}.

Repository scope: {{repo_scope}}
Dependencies: {{dependencies}}
Runtime configuration: {{configuration}}

Find each distinct production entrypoint through which an actor outside the deployed process or trusted local environment can cause the application to receive or process input. Consider public HTTP, GraphQL, gRPC, RPC, WebSocket, webhook, network/peer protocol, externally supplied queue or event handlers, public package/API boundaries, and externally exposed command interfaces when untrusted input reaches them.

For every entrypoint:
- Identify the concrete ingress and first application handler.
- State the external actor that can reach it and the input they control.
- Give the exact source path and line for the handler or its registration.
- Explain why it is externally reachable under the supplied configuration or inherited runtime defaults.

Include only production-relevant paths. Exclude tests, mocks, examples, benchmarks, dead code, developer-only tools, and interfaces limited to the same trusted host or process. Do not merge distinct handlers or routes into one result. Do not speculate about reachability: return a stub when no externally reachable entrypoints can be established.','{"entrypoint_kind": "string", "entrypoint_label": "string", "entrypoint_handler": "string", "entrypoint_file_path": "string", "entrypoint_line": "number", "entrypoint_actor": "string", "entrypoint_input": "string", "entrypoint_reachability": "string"}','Map external entrypoints',0,true,false,'workflows.step_results',false);
INSERT INTO public.steps(id,content,output_format,name,depth,multi_output,is_last_step,output_table,consume_all_previous) VALUES(2,'You are tracing production execution flows from one externally reachable entrypoint in {{repo_full}}.

Entrypoint:
- kind: {{entrypoint_kind}}
- label: {{entrypoint_label}}
- handler: {{entrypoint_handler}}
- location: {{entrypoint_file_path}}:{{entrypoint_line}}
- external actor: {{entrypoint_actor}}
- controlled input: {{entrypoint_input}}
- reachability evidence: {{entrypoint_reachability}}

Map every materially distinct flow that this external actor can reach from the entrypoint through production code. A flow should capture a meaningful route, dispatch target, validation outcome, authorization boundary, asynchronous continuation, state mutation, external call, sensitive sink, or terminal response. Do not create separate results for cosmetic helper calls, but do separate paths whose conditions, privileged actions, data handling, or security consequences differ.

For each flow:
- Summarize what the flow does and where it ends.
- Provide an ordered `flow_trace` with the important hops as `path:line symbol - behavior`, including parsing, validation, dispatch, and security-sensitive operations.
- Identify the terminal action and the externally controlled input as it reaches that action.
- Give the most security-relevant source location in the flow and why the flow deserves security review.

Keep the analysis grounded in the supplied configuration and production code. Exclude impossible, test-only, local-only, and dead paths. Do not report vulnerabilities yet; this stage is an accurate flow map.','{"flow_summary": "string", "flow_trace": "array", "flow_terminal_action": "string", "flow_file_path": "string", "flow_line": "number", "flow_input_to_sink": "string", "flow_security_relevance": "string"}','Trace reachable flows',1,true,false,'workflows.step_results',false);
INSERT INTO public.steps(id,content,output_format,name,depth,multi_output,is_last_step,output_table,consume_all_previous) VALUES(3,'You are investigating one externally reachable production flow in {{repo_full}} for concrete security vulnerabilities.

Entrypoint:
- kind: {{entrypoint_kind}}
- label: {{entrypoint_label}}
- handler: {{entrypoint_handler}}
- location: {{entrypoint_file_path}}:{{entrypoint_line}}
- external actor: {{entrypoint_actor}}
- controlled input: {{entrypoint_input}}

Flow under review:
- summary: {{flow_summary}}
- trace: {{flow_trace}}
- terminal action: {{flow_terminal_action}}
- focal location: {{flow_file_path}}:{{flow_line}}
- input to sink: {{flow_input_to_sink}}
- security relevance: {{flow_security_relevance}}

Review the source code for this exact flow, including the surrounding implementation and any necessary callers or callees. Report only vulnerabilities that are concrete, reachable from the stated external actor, and supported by code evidence. A valid finding must identify the vulnerable operation, the missing or flawed protection, a realistic malicious input or sequence, and the full trigger path.

Do not report style issues, hypothetical concerns, test-only behavior, or vulnerabilities that require unsupported configuration or unproven assumptions. Set `exploitable` to true only when the stated external actor can realistically trigger the issue in the configured production path. When the flow contains no supported vulnerability, return a stub instead of inventing a finding.

For each finding, point `file_path` and `line` to the actual vulnerable code, make `trigger_flow` an ordered list from attacker ingress to the vulnerable operation, and use `malicious_input_example` for a minimal realistic payload or sequence.','{"explanation": "string", "file_path": "string", "line": "number", "malicious_input_example": "string", "summary": "string", "trigger_flow": "array", "vulnerability_type": "string", "malicious_actor": "string", "exploitable": "boolean"}','Investigate flow vulnerabilities',2,true,true,'workflows.vulnerabilities',false);
INSERT INTO public.llm_workflows(id,step_ids,name,description,extra) VALUES(1,ARRAY[1,2,3],'external-flow-analysis','Maps externally reachable entrypoints, traces each production flow, and investigates every flow for concrete security vulnerabilities.',ARRAY[]::text[]);
INSERT INTO public.severity_rankers(id,name,description,content) VALUES(1,'Blockchain security triage','A conservative production-impact ranker suitable for a first scan.','Rank only findings with a concrete, externally reachable production trigger.

- Critical: consensus or integrity corruption, network-wide persistent outage, or unauthorized asset creation, destruction, or theft.
- High: realistic remote input causing a prolonged service outage, consensus safety/liveness failure, authentication bypass, or substantial asset impact.
- Medium: bounded availability, authorization, or integrity impact with meaningful prerequisites or limited blast radius.
- Low: defense-in-depth issues with a concrete but minor production impact.
- Informational: hardening opportunities without demonstrated security impact.

Prefer end-to-end evidence, reachable default or supplied configuration, and reproducible triggers. Demote theoretical, test-only, privileged-local, brute-force, race-dependent, non-default, and unverified findings. Rank likely false positives last.');
INSERT INTO public.scans(id,workflow_id,post_script_id,repo_full,commit_sha,repo_scope,dependencies,configuration,model,model_provider,harness,status,config,scopes,repo_kind,dependencies_detail,thinking_effort,severity_ranker) VALUES(1,1,4,'clean-context','LOCAL_SNAPSHOT','Whole-system security review of packages/contracts/src/Raffle.sol, RaffleFactory.sol, interfaces/IRaffle.sol, interfaces/IRaffleFactory.sol, libraries/RaffleConstants.sol, reachable imported Solidity dependencies, and DESIGN.md only. Every public/external/inherited state-changing boundary is in scope. No tests, mocks, audit history, scanner findings, peer reports, memory, external websites or live systems. Read and inspect only; no production modifications.',ARRAY[]::text[],'{"repeat_runs": 1, "post_script_ids": [4, 5, 6, 3], "include_tests": false, "independence": "Only frozen clean-context; no audit history, scanners, peer reports or account memory. Only these production files and their imported dependencies, plus DESIGN.md. Do not access external web/chain/live systems. Do not modify production sources. No agent delegation or other models.", "lane": "GEMINI-OPENKRITT-NATIVE", "requested_model": "gemini-4-argon-high", "requested_reasoning": "high", "requested_program": "official-native-agy-host-bridge", "post_processing_model": "gemini-4-argon-high", "post_processing_model_provider": "gemini", "post_processing_harness": "gemini-cli", "post_processing_thinking_effort": "high"}'::jsonb,'gemini-4-argon-high','gemini','gemini-cli','pending','{}'::jsonb,'{"files":[],"lines":[]}'::jsonb,'local','[]'::jsonb,'high','Rank only findings with a concrete, externally reachable production trigger.

- Critical: consensus or integrity corruption, network-wide persistent outage, or unauthorized asset creation, destruction, or theft.
- High: realistic remote input causing a prolonged service outage, consensus safety/liveness failure, authentication bypass, or substantial asset impact.
- Medium: bounded availability, authorization, or integrity impact with meaningful prerequisites or limited blast radius.
- Low: defense-in-depth issues with a concrete but minor production impact.
- Informational: hardening opportunities without demonstrated security impact.

Prefer end-to-end evidence, reachable default or supplied configuration, and reproducible triggers. Demote theoretical, test-only, privileged-local, brute-force, race-dependent, non-default, and unverified findings. Rank likely false positives last.');
UPDATE public.scans SET configuration=configuration || '{"frozen_source_commit":"9238b6ce8eb7f768c0dcd0cfcef26e1427a03155","transport_method":"official agy 1.4.4 host spool bridge; no private provider API"}'::jsonb WHERE id=1;
COMMIT;
