# CLAUDE-OPENKRITT — BLOCKED

- Cell: CLAUDE-OPENKRITT (OpenKritt × Anthropic `claude-opus-5-5`)
- Upstream: https://github.com/Kritt-ai/open-kritt @ `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` (VERSION 1.4.1), copied unmodified to the lane runtime `harness/openkritt`.
- Decision time: 2026-10-21T08:00Z. No review was run, so there are no findings and no first-pass output.
- No homemade substitute review was made. A generic prompt is not OpenKritt.

## Why the native route cannot run (evidence: `blocker-probes.txt`)

1. **Engine/runtime pin cannot serve the requested model.** OpenKritt's engine image and its per-job Claude runner both install `@anthropic-ai/claude-code@2.1.215` (`engine/Dockerfile:17`, `engine/Dockerfile.claude-runner:7`). For `claude-opus-5-5` the Anthropic API requires Claude Code `>= 2.1.280`. The API's own refusal is saved in `evidence-claude-code-version-gate-2.1.58.json` (`claude_code_version_too_old`, "version 2.1.280 or newer is required"). Changing the pin would make it a modified controller, which is a different method.
2. **The model catalog has no exact model.** `engine/open_kritt_engine/model_catalog.py` lists `claude-opus-5`, `claude-opus-4-8` and similar IDs, and has no `claude-opus-5-5`. The documented subscription route offers only the stable aliases `sonnet`/`opus`. The bundled 2.1.215 runtime would resolve those aliases, so an exact-ID selection with no fallback cannot be guaranteed.
3. **No container daemon is available to this lane.** The Docker CLI 29.8.2 is installed, but `/var/run/docker.sock` is missing. There is no Docker Desktop, OrbStack, Rancher, Podman or colima. The three pre-existing lima VMs belong to other workflows/projects and were deliberately left untouched.
4. **No non-interactive Anthropic credential route exists.** No `ANTHROPIC_API_KEY` is configured (`apiKeySource=none`). OpenKritt's Claude subscription login needs an interactive browser OAuth flow ("Accounts → Sign in to Claude", then paste a callback code). The assistant may not complete that on the owner's behalf (credential entry/OAuth grant). Copying keychain credentials into a container was judged out of bounds.

Setup attempts used: 3 of 3 (daemon probe, alternative container runtimes, model-route/catalog check). The cell stays **BLOCKED**.

## What would unblock it (owner decision required)
- A dedicated container host for this lane, **and**
- either an OpenKritt release whose bundled Claude Code is `>= 2.1.280` with a catalog entry for `claude-opus-5-5`, or an explicitly approved, disclosed modified-controller method (that would be a distinct method, not this cell), **and**
- an owner-completed Claude login or an owner-provided API key inside that isolated stack.
