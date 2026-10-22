# Finalization helper hardening

A separate read-only reviewer identified publication and watcher shutdown issues. The current helpers enforce exact five-output/four-payload publication, typed receipt path/hash bindings, an anchored required-lane baseline, duplicate disposition rejection, same-byte state parsing/hashing, explicit failure under optimized finalizer execution, and input-set equality on resume. Unpublished staging is prepared before atomic installation; watcher receipt files install complete bytes exclusively.

Watcher shutdown verifies its exact PID and cwd, treats query failures separately from absent processes, and rechecks all final outputs and the bound state after termination. It publishes a resumable exact-byte receipt/seal. This does not grant permission to stop other processes or complete the global audit.

Twenty-five temporary-fixture checks pass. No actual finalization or watcher stop occurred. Earlier check01 and check02 records are retained, along with exact helper/script snapshots. Three check01 helper versions were reconstructed by reversing the subsequent edits and then matched against all previously recorded SHA256 values; the other snapshots were exact copies. Current working helper paths can advance before finalization, so this seal binds their preserved snapshots, not a claim that the live helpers will never change.
