# r001 Git publication

The [final audit report](2026-10-21-r001/FINAL-AUDIT-REPORT.md) and [evidence index](2026-10-21-r001/INDEX.md) describe the frozen source, findings, qualified methods and preserved provider refusals.

The original local delivery remains sealed and unchanged. Git contains the reports and evidence, including retained outputs that normal build rules ignore, with three explicit omissions: the downloaded 188 MB Antigravity executable, its 57 MB release archive, and one executor-viewer runtime log containing a local access token. No audit results are omitted from that log: a [redacted copy](2026-10-21-r001-publication/open-kritt-executor-view.redacted.txt) is supplied separately.

The [publication manifest](2026-10-21-r001-publication.json) records exact omissions, original hashes, the pinned tool download location and the redacted copy's hash. The original delivery seal describes the complete private local package. A public Git checkout intentionally lacks those three original objects and therefore cannot independently pass the whole-package verifier without the original private log and restored tool payloads. The redacted copy must not replace the original sealed log.

No sealed evidence was rewritten for publication, and no production contract source changed.
