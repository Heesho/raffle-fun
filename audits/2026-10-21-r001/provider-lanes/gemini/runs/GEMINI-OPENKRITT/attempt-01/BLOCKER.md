# `GEMINI-OPENKRITT` — Attempt 01 (`BLOCKED`)

## 1. Provenance & Pin Metadata
- **Cell ID**: `GEMINI-OPENKRITT`
- **Upstream Repository**: `https://github.com/Kritt-ai/open-kritt`
- **Requested Historical Pin**: `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`
- **Resolved Upstream Pin**: `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3` (`fix: accept valid duplicate scan payloads (#119)`)
- **Inspected Reference Checkout**: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/openkritt`
- **Staged Provenance Copy**: `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini/harnesses/openkritt`
- **Final Cell Status**: `BLOCKED`

## 2. Exact Blocker Evidence in Upstream OpenKritt Engine
Per Execution Rule 7 (`prompts/gemini-overnight.md` line 27):
> *"OpenKritt: native engine and pinned exact workflow/skills/ranker/post-processing/stage counts; if no working supported engine/provider route, mark BLOCKED rather than replace it with a homemade review."*

And Execution Rule 36 (`prompts/gemini-overnight.md` line 36):
> *"Use one selected exact model for all five cells and their specialists/judges with highest supported thinking; if a harness does not support its route, leave that cell BLOCKED. No private model-ID guesses, browser-session token extraction, fallback or role-play of a different provider."*

Inspection of the pinned upstream OpenKritt codebase (`43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`) confirms that the OpenKritt engine does **not** support Google Gemini as a direct model provider or the Antigravity runner as a harness CLI:

1. **Engine Provider Allowlist (`engine/open_kritt_engine/harnesses.py`, lines 199–215)** (`SHA256: b308b824802a38a33a554db443a6fb5d6e8f1bf41cb4de21b60678e5913bfcd7`):
   ```python
   HARNESSES: tuple[HarnessOption, ...] = (
       HarnessOption(id="codex", name="Codex", cli_command="codex"),
       HarnessOption(id="claude-code", name="Claude Code", cli_command="claude"),
       HarnessOption(id="grok-build", name="Grok Build", cli_command="grok"),
   )

   HARNESS_BY_ID: dict[str, HarnessOption] = {item.id: item for item in HARNESSES}
   MODEL_PROVIDERS = {"codex", "claude", "openrouter", "xai", "deepseek"}
   DIRECT_API_PROVIDERS = {"openrouter", "xai", "deepseek"}
   PROVIDER_API_ENV_VARS = {
       "openrouter": "OPENROUTER_API_KEY",
       "xai": "XAI_API_KEY",
       "deepseek": "DEEPSEEK_API_KEY",
   }
   ```
   Attempting to configure `provider = "gemini"` or `provider = "google"` raises `ValueError(f"Unsupported model provider '{provider}'.")` in `normalize_model_provider()` (`engine/open_kritt_engine/harnesses.py`, lines 237–242).

2. **Engine Execution Dispatcher (`engine/open_kritt_engine/harnesses.py`, lines 437–452)**:
   ```python
   def run_model_prompt(...) -> str:
       normalized_provider = normalize_model_provider(provider, harness)
       if normalized_provider in DIRECT_API_PROVIDERS:
           return _run_direct_api_prompt(...)
       harness_option = get_harness_option(harness)
       if harness_option.id == "codex":
           return _run_codex_prompt(...)
       if harness_option.id == "claude-code":
           return _run_claude_prompt(...)
       if harness_option.id == "grok-build":
           return _run_grok_prompt(...)
       raise RuntimeError(f"Unsupported harness '{harness}'.")
   ```
   Even for `openrouter`, `OPENROUTER_API_KEY` is not configured in the environment, and our assigned provider lane is native Google Gemini (`gemini-4-argon`) without third-party proxy fallback or modifying the upstream controller into a distinct homemade method.

3. **Backend Provider Catalog (`backend/src/lib/modelProviders.js`, lines 5–18)** (`SHA256: e3ee760f22a035fa356b16ef9502d2093338e3d9ed3d75beae5fa5a807ef29cb`):
   ```javascript
   export const MODEL_PROVIDER_DEFINITIONS = [
     { id: 'codex', name: 'OpenAI Codex', mode: 'harness', harnessId: 'codex' },
     { id: 'claude', name: 'Anthropic Claude', mode: 'harness', harnessId: 'claude-code' },
     { id: 'openrouter', name: 'OpenRouter', mode: 'api', apiKeyEnvVar: 'OPENROUTER_API_KEY' },
     { id: 'xai', name: 'xAI', mode: 'api', apiKeyEnvVar: 'XAI_API_KEY' },
     { id: 'deepseek', name: 'DeepSeek', mode: 'api', apiKeyEnvVar: 'DEEPSEEK_API_KEY' },
   ];
   ```

## 3. Freeze Verification
- Pre-attempt and post-attempt repository freeze verification: `PASS` (`435` tracked files verified against `freeze.json`).
