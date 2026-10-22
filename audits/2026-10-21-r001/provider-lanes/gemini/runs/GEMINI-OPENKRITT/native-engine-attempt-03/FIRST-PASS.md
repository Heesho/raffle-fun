# Gemini native OpenKritt first pass

Target: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Upstream OpenKritt: `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`.

This is the actual native Python engine and PostgreSQL workflow, using a disclosed local file-spool adapter to the official macOS Antigravity CLI. Every direct call requests `gemini-4-argon-high`, effort `high`, and a fresh source workspace. Internal provider checkpoint identity is not independently returned. The adapter does not replace native queue, workflow, ranking or postprocessing decisions.

This export preserves native findings without operator synthesis or independent security validation. Claim counts are output records, not votes or established defects.

## Execution

```json
{
  "completed_utc": "2026-10-21T21:47:47.855840+00:00",
  "native_status": "completed",
  "target_commit": "9238b6ce8eb7f768c0dcd0cfcef26e1427a03155",
  "method": "actual pinned OpenKritt Python engine, native PostgreSQL queue/workflow/ranker/postprocessors; disclosed official agy file-spool adapter",
  "requested_model": "gemini-4-argon-high",
  "requested_effort": "high",
  "provider_internal_identity": "not independently returned",
  "calls": 115,
  "historical_network_failures": [
    {
      "call": "010df358179942d18c36c84213270f2c",
      "error": "The stream was interrupted. Please continue the task you were working on.",
      "preserved_failed_attempt": true
    },
    {
      "call": "222e3a34460a4f4884be6beee526b881",
      "error": "API error (attempt 1): request failed: Post \"https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse\": read tcp [2601:600:9000:45f2:38ae:83bd:fd08:e56a]:50902->[2001:4860:4846:400::]:443: read: operation timed out",
      "preserved_failed_attempt": true
    },
    {
      "call": "ccf9dc8882d347a0b7df0f991e880751",
      "error": "API error (attempt 1): request failed: Post \"https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse\": read tcp [2601:600:9000:45f2:38ae:83bd:fd08:e56a]:50885->[2001:4860:4841:400::]:443: read: operation timed out",
      "preserved_failed_attempt": true
    }
  ],
  "native_resume_disclosure": "One native pending transition after network interruptions; failed attempts preserved and successful logical jobs retained. No provider safety rejection retried.",
  "stage_counts": {
    "('step', 'completed')": 112,
    "('step', 'failed')": 6
  },
  "required_post_script_ids": [
    3,
    4,
    5,
    6
  ],
  "postprocessing_tuple_mismatches": [],
  "missing_dedupe_ids": [],
  "missing_rank_ids": [],
  "missing_post_enrichments": [],
  "open_metadata_ids": [],
  "finding_records": 0,
  "canonical_findings": 0,
  "qualification_issues": [],
  "qualifies_route_and_source": true,
  "no_claim_of_independent_finding_validation": true
}
```

| Native job | Kind | Step | Status | Model | Effort |
|---|---|---|---|---|---|
| 1 | step | 1 | completed | gemini-4-argon-high | high |
| 2 | step | 2 | completed | gemini-4-argon-high | high |
| 3 | step | 2 | completed | gemini-4-argon-high | high |
| 4 | step | 2 | completed | gemini-4-argon-high | high |
| 5 | step | 3 | completed | gemini-4-argon-high | high |
| 6 | step | 3 | completed | gemini-4-argon-high | high |
| 7 | step | 3 | completed | gemini-4-argon-high | high |
| 8 | step | 3 | completed | gemini-4-argon-high | high |
| 9 | step | 3 | completed | gemini-4-argon-high | high |
| 10 | step | 3 | completed | gemini-4-argon-high | high |
| 11 | step | 3 | completed | gemini-4-argon-high | high |
| 12 | step | 3 | completed | gemini-4-argon-high | high |
| 13 | step | 3 | completed | gemini-4-argon-high | high |
| 14 | step | 3 | completed | gemini-4-argon-high | high |
| 15 | step | 3 | completed | gemini-4-argon-high | high |
| 16 | step | 3 | completed | gemini-4-argon-high | high |
| 17 | step | 3 | completed | gemini-4-argon-high | high |
| 18 | step | 2 | completed | gemini-4-argon-high | high |
| 19 | step | 2 | failed | gemini-4-argon-high | high |
| 20 | step | 2 | failed | gemini-4-argon-high | high |
| 21 | step | 3 | failed | gemini-4-argon-high | high |
| 22 | step | 3 | failed | gemini-4-argon-high | high |
| 23 | step | 2 | failed | gemini-4-argon-high | high |
| 24 | step | 2 | failed | gemini-4-argon-high | high |
| 25 | step | 3 | completed | gemini-4-argon-high | high |
| 26 | step | 2 | completed | gemini-4-argon-high | high |
| 27 | step | 2 | completed | gemini-4-argon-high | high |
| 28 | step | 2 | completed | gemini-4-argon-high | high |
| 29 | step | 3 | completed | gemini-4-argon-high | high |
| 30 | step | 3 | completed | gemini-4-argon-high | high |
| 31 | step | 3 | completed | gemini-4-argon-high | high |
| 32 | step | 3 | completed | gemini-4-argon-high | high |
| 33 | step | 3 | completed | gemini-4-argon-high | high |
| 34 | step | 3 | completed | gemini-4-argon-high | high |
| 35 | step | 3 | completed | gemini-4-argon-high | high |
| 36 | step | 3 | completed | gemini-4-argon-high | high |
| 37 | step | 3 | completed | gemini-4-argon-high | high |
| 38 | step | 3 | completed | gemini-4-argon-high | high |
| 39 | step | 3 | completed | gemini-4-argon-high | high |
| 40 | step | 3 | completed | gemini-4-argon-high | high |
| 41 | step | 3 | completed | gemini-4-argon-high | high |
| 42 | step | 3 | completed | gemini-4-argon-high | high |
| 43 | step | 2 | completed | gemini-4-argon-high | high |
| 44 | step | 2 | completed | gemini-4-argon-high | high |
| 45 | step | 3 | completed | gemini-4-argon-high | high |
| 46 | step | 3 | completed | gemini-4-argon-high | high |
| 47 | step | 3 | completed | gemini-4-argon-high | high |
| 48 | step | 3 | completed | gemini-4-argon-high | high |
| 49 | step | 3 | completed | gemini-4-argon-high | high |
| 50 | step | 3 | completed | gemini-4-argon-high | high |
| 51 | step | 3 | completed | gemini-4-argon-high | high |
| 52 | step | 3 | completed | gemini-4-argon-high | high |
| 53 | step | 3 | completed | gemini-4-argon-high | high |
| 54 | step | 3 | completed | gemini-4-argon-high | high |
| 55 | step | 2 | completed | gemini-4-argon-high | high |
| 56 | step | 2 | completed | gemini-4-argon-high | high |
| 57 | step | 2 | completed | gemini-4-argon-high | high |
| 58 | step | 3 | completed | gemini-4-argon-high | high |
| 59 | step | 3 | completed | gemini-4-argon-high | high |
| 60 | step | 3 | completed | gemini-4-argon-high | high |
| 61 | step | 3 | completed | gemini-4-argon-high | high |
| 62 | step | 3 | completed | gemini-4-argon-high | high |
| 63 | step | 3 | completed | gemini-4-argon-high | high |
| 64 | step | 3 | completed | gemini-4-argon-high | high |
| 65 | step | 3 | completed | gemini-4-argon-high | high |
| 66 | step | 3 | completed | gemini-4-argon-high | high |
| 67 | step | 3 | completed | gemini-4-argon-high | high |
| 68 | step | 3 | completed | gemini-4-argon-high | high |
| 69 | step | 2 | completed | gemini-4-argon-high | high |
| 70 | step | 2 | completed | gemini-4-argon-high | high |
| 71 | step | 2 | completed | gemini-4-argon-high | high |
| 72 | step | 3 | completed | gemini-4-argon-high | high |
| 73 | step | 3 | completed | gemini-4-argon-high | high |
| 74 | step | 3 | completed | gemini-4-argon-high | high |
| 75 | step | 3 | completed | gemini-4-argon-high | high |
| 76 | step | 3 | completed | gemini-4-argon-high | high |
| 77 | step | 3 | completed | gemini-4-argon-high | high |
| 78 | step | 3 | completed | gemini-4-argon-high | high |
| 79 | step | 2 | completed | gemini-4-argon-high | high |
| 80 | step | 2 | completed | gemini-4-argon-high | high |
| 81 | step | 2 | completed | gemini-4-argon-high | high |
| 82 | step | 3 | completed | gemini-4-argon-high | high |
| 83 | step | 3 | completed | gemini-4-argon-high | high |
| 84 | step | 3 | completed | gemini-4-argon-high | high |
| 85 | step | 3 | completed | gemini-4-argon-high | high |
| 86 | step | 3 | completed | gemini-4-argon-high | high |
| 87 | step | 3 | completed | gemini-4-argon-high | high |
| 88 | step | 3 | completed | gemini-4-argon-high | high |
| 89 | step | 3 | completed | gemini-4-argon-high | high |
| 90 | step | 3 | completed | gemini-4-argon-high | high |
| 91 | step | 3 | completed | gemini-4-argon-high | high |
| 92 | step | 2 | completed | gemini-4-argon-high | high |
| 93 | step | 2 | completed | gemini-4-argon-high | high |
| 94 | step | 2 | completed | gemini-4-argon-high | high |
| 95 | step | 3 | completed | gemini-4-argon-high | high |
| 96 | step | 3 | completed | gemini-4-argon-high | high |
| 97 | step | 3 | completed | gemini-4-argon-high | high |
| 98 | step | 3 | completed | gemini-4-argon-high | high |
| 99 | step | 3 | completed | gemini-4-argon-high | high |
| 100 | step | 2 | completed | gemini-4-argon-high | high |
| 101 | step | 2 | completed | gemini-4-argon-high | high |
| 102 | step | 3 | completed | gemini-4-argon-high | high |
| 103 | step | 3 | completed | gemini-4-argon-high | high |
| 104 | step | 3 | completed | gemini-4-argon-high | high |
| 105 | step | 3 | completed | gemini-4-argon-high | high |
| 106 | step | 3 | completed | gemini-4-argon-high | high |
| 107 | step | 3 | completed | gemini-4-argon-high | high |
| 108 | step | 3 | completed | gemini-4-argon-high | high |
| 109 | step | 3 | completed | gemini-4-argon-high | high |
| 110 | step | 3 | completed | gemini-4-argon-high | high |
| 111 | step | 3 | completed | gemini-4-argon-high | high |
| 112 | step | 3 | completed | gemini-4-argon-high | high |
| 113 | step | 3 | completed | gemini-4-argon-high | high |
| 114 | step | 3 | completed | gemini-4-argon-high | high |
| 115 | step | 3 | completed | gemini-4-argon-high | high |
| 116 | step | 3 | completed | gemini-4-argon-high | high |
| 117 | step | 3 | completed | gemini-4-argon-high | high |
| 118 | step | 3 | completed | gemini-4-argon-high | high |

## Native finding records

Original database IDs, source spans, ranker state and deduplication fields are preserved verbatim below and in native-results.json. Native enrichment records remain in that JSON.

The native workflow produced zero finding records. This is not a proof of absence. Ranking/postprocessing calls are reported only where the native engine actually scheduled them.

## Limits

Scope was the frozen 43-file source context. The host provided fresh cwd and unchanged-source checks; absence of all service-side memory is not provable. The CLI tool surface was not independently sandboxed: actual tool metadata and any native no-tool or delegation issues are recorded in CLI-CALL-RECEIPTS.json. Source/workflow integrity does not establish severity or exploitability. No deployment, RPC, production changes or finding-validation campaign was performed by the operator.
