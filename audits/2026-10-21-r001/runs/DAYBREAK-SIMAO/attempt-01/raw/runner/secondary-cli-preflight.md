# Secondary CLI preflight record

The actual audit runner selection is preserved in `command.json` and `runner-selection.json`: local model `gpt-daybreak-blue-latest`, reasoning effort `ultra`, access program `daybreak_blue`, fallback disabled.

Three attempts were made to launch an additional fresh Codex CLI process using the same explicit flags, including an attempt with a writable `sqlite_home`. The bundled `/opt/homebrew/bin/codex` shim first failed with `ENOENT`; the actual binary at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex` reported version `0.163.0-alpha.10.2` but the nested process stopped before model dispatch with `failed to initialize in-process app-server client: Operation not permitted`. The first nested attempt also encountered a read-only default database.

The three JSONL event destinations are preserved as zero-byte files because dispatch never began. No provider model/program identity was returned. Native model stages therefore used independent `fork_turns=none` internal contexts inheriting the already selected root runner; every prompt repeated the exact model, effort, and access-program constraint. The provider-returned identity fields remain `unknown`.
