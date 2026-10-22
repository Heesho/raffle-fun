# Gebal deterministic lane — completed compatibility method

The successful attempt is `attempt-03/`. It completed native Gebal intake, Docker-only Foundry build, selected existing Foundry tests, and native Slither processing. It is a deterministic lane, **not a model review**, and does not complete or replace a provider/model harness cell. No cold review was imported or rebound.

The upstream checkout remains pinned and unchanged at `9ad24645f92a3821ae4539db5f1be52b48ed379e`. The successful copied compatibility controller is a distinct method. Its exact patch SHA-256 is `ded46f036c2f95618bfe49faf74f0af575add3b7bbaa021d7d8ca86d80cc6bb7`; see `attempt-03/controller-compatibility.patch` and `controller-final-manifest.json`.

## Results

- Exact Solidity `0.8.36+commit.8a079791`, Cancun, optimizer enabled/200 runs, via-IR disabled; effective compiler settings verified by the native sandbox.
- Forge 1.3.1: 79 passed, 0 failed, 0 skipped in 5 suites. Nine fuzz tests ran 256 cases each (2,304 cases). Nine invariant assertions each reported 64 runs and 2,048 calls (18,432 reported calls total), with 0 outer reverts/discards. Repeated assertions may exercise common seeded sequences; these are not independent-sequence counts. Handler-internal no-ops and swallowed reverts are not established by these metrics.
- Slither 0.11.3: 100 detectors, 84 compiled contracts, 34 observations (9 Medium, 18 Low, 7 Informational). Primary locations are 12 in production scope and 22 in test mocks. These are untriaged scanner observations, not confirmed vulnerabilities; see `slither-observation-index.json`.
- Sandbox evidence confirms UID 65534, loopback interface only, zero capabilities, no-new-privileges, seccomp mode 2, read-only mounts, and absent host environment canary. No provider egress, deployment, RPC/live-chain calls, purchases, or production modifications.
- Final freeze verification has no mismatches. Original tracked frozen files are verified in the original repository; captured reachable dependencies are verified in the frozen validation copy because original repository dependencies were absent.

The test-inclusive target contains 78 hash-recorded files: all original contract sources including mocks; existing unit/fuzz/invariant/security Foundry tests; the exact import closure including forge-std; unchanged foundry.toml/remappings; package metadata and the root lockfile. The RPC-dependent Ethereum fork test is explicitly excluded. Native Gebal uses only `profile.default` and overrides campaigns to seed 1, 256 fuzz runs, 64 invariant runs and depth 32. This does not establish repository-default, CI, audit, strict, release, coverage, comparison, fork, gas-report, bytecode-identity, or symbolic proof coverage.

## Preserved attempts and changes

1. `attempt-01/result-original.json`: unmodified upstream diagnosis rejects the original `gas_reports` key. Build/Slither are unsupported and tests are not run. The original configuration was not edited or silently stripped.
2. `attempt-01/result-compatible.json`: a copied controller adds typed intake support for `gas_reports`, preserves it in the sandbox policy, and checks Forge's effective value. Build and 79 tests pass; Slither fails with `Output limit exceeded` under the configured maximum 8 MB output limit.
3. `attempt-02/`: a separate copied controller adds Slither reporting filters for `node_modules|lib/forge-std|test/foundry` and excludes dependency findings. All detectors remain active and test mocks remain visible. Build and 79 tests pass, but the same output limit still prevents scanner coverage.
4. `attempt-03/`: a separate copied controller retains all prior disclosed changes and removes `--json` **only from Slither's prerequisite `forge build --ast --build-info --extra-output storageLayout` command**. That step still generates the same AST/build-info/storage-layout artifacts, but uses normal text output instead of capturing enormous AST JSON; the controller consumes its exit code. Foundry build/test JSON parsing is unchanged. Stage-identifying output-limit diagnostics were added. All four stages succeed. No source, pragma, compiler version, optimizer setting or EVM target was changed.

Each copied controller passed its full controller test suite (37 passed, 2 opt-in integration cases skipped), typecheck/build and formatting checks. The exact compiler image separately passed upstream native real integration in root and monorepo layouts: 2 passed, 0 skipped; each fixture verified 7 test passes plus Foundry/Slither/isolation checks. Evidence is in `attempt-01/integration-original-0836.*`.

Compiler acquisition initially hit an official distribution HTTP 403 reported by the parent coordinator. The successful download used the official `ethereum/solc-bin` Linux-amd64 manifest and binary, with SHA-256 verified against that manifest: `c8d35afdddc3cd2743ee88b8f25e0fecd16e2bdd5f2120f37e52cd9cc45ae0e6`. URLs, manifest hash, compiler entry and prior failure provenance are retained in `attempt-01/compiler-provenance.json`. The image starts from full cached immutable base `sha256:8650f0012153891af2dc212f3fbc3407f3f3bbc0a1ee35f9e9d5511179190a4b` and replaces only solc. An initial Docker build rejected `COPY --chmod` because BuildKit was absent; that failed log is preserved, and the successful ordinary COPY retained the verified executable's mode.

## Native binding and evidence

- Final run: `7534f596-70e1-4ce7-ba04-d00d57e72291`
- Final plan: `20cd66d3-140e-4650-972e-e0cfa68cc525`
- Plan hash: `17ba9ff6087c56fda80175f8f5df89ec19c5a8a8a2b45fc2cd51ce2ad67985fd`
- Test-inclusive snapshot hash: `4ccea2a55fbb3cf6320126f9ffb175c3029d2b94e09b3d1ff4592e1cbc8bd4de`
- Native context hash: `077c525b4ffd82da17f1b970cdb074b5395b9fb96b2130c08ae6c5ab4959889a`
- Immutable image: `sha256:470f595a2226b79d436bd27ab38e789667f847234c8034beee470b086839bfd1`

`RESULT.json` is the concise machine-readable result. Native plans, approvals, results, context exports, reports, command logs, execution envelopes, raw tool outputs and content-addressed evidence are retained by attempt. The native approval actor is explicitly `delegated-audit-assistant`, grounded in the user's local execution authorization; it does not claim the owner personally reviewed a hash. Stores and controllers remain outside the assessed target. No peer source-review findings were read.

To rerun this exact compatibility method, execute `python3 /absolute/path/to/runs/GEBAL-DETERMINISTIC/rerun.py /absolute/new/output-directory`. The script requires a new directory, verifies target/controller hashes, uses a fresh native state store and plan, records delegated authorization and captures results. The current local Docker socket, exact Node runtime, immutable image and preserved controller/target must remain available. Treat failures as failures; never overwrite these historical attempts.
