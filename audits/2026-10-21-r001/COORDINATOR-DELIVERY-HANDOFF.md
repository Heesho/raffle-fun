# Final delivery sequencing for the Daybreak coordinator

The parent has launched the explicit Daybreak coordinator at the user's request. All audit semantics, remaining native workflows, receipt qualification, final reconciliation, matrix/report updates and final source verification belong to that actual Daybreak coordinator.

Your own events.jsonl/stderr/coordinator-final.md are inside the audit package. The launch wrapper writes exit-code.txt after your CLI exits. Therefore do not create the whole-package DELIVERY-MANIFEST/DELIVERY-SEAL while your own CLI is still writing: subsequent normal final events would invalidate that seal.

Complete all eligible workflows and report/reconciliation work, stop the other task-owned writers after their final receipts, run the final read-only verification, then write runs/COORDINATOR-DAYBREAK/attempt-01/READY-FOR-PARENT-DELIVERY-SEAL.json with final report/register paths, verification result and remaining writer information. End your coordinator turn with a concise completed-work summary. The parent will perform the mechanical whole-package sealing after your CLI and wrapper have exited, then verify the resulting manifest before delivery. This is sequencing for byte integrity, not authorization to skip audit gates. If a native lane actually receives OpenAI rejection, retain its honest terminal status.

Do not alter any original prompt, old seal or earlier rejection record. A parent administrative seal is not a replacement security judgment and does not qualify any unresolved workflow.
