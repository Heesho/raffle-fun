# Audit Scope — Google Gemini Provider Lane (`2026-10-21-r001`)

## 1. Frozen Repository & Immutable Target
- **Project**: `raffle.fun`
- **Repository**: `/Users/hishamel-husseini/Documents/projects/raffle-fun`
- **Frozen Commit SHA**: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Common Freeze Manifest**: [`../../freeze.json`](../../freeze.json)
- **Common Freeze Verifier**: [`../../verify-freeze.py`](../../verify-freeze.py)
- **Portable Clean Context Archive**: [`../../clean-context.tar.gz`](../../clean-context.tar.gz) (SHA-256: `fc53106bb75495a4caa732f3be0a7e5bca3d619c5d01a77b0909227d30ede96d`)
- **Full Immutable Target Archive**: [`../../target.tar.gz`](../../target.tar.gz) (SHA-256: `67d554dfd521c83a3383fe1b58b934647ff86ead6c3f3b9290af45e44d6aae1d`)
- **Reachable Dependency Manifest**: [`../../dependency-hashes.json`](../../dependency-hashes.json) (31 reachable library files across `@openzeppelin/contracts` v5.6.1 and `@chainlink/contracts` v1.5.0)
- **Uncommitted Production Changes**: None (`git status --porcelain` clean on tracked files; all 435 tracked files verified byte-for-byte against `freeze.json`).

## 2. Mandatory Production Scope (5 Files)

| File Path | Lines | Bytes | SHA-256 | Role |
|---|---:|---:|---|---|
| `packages/contracts/src/Raffle.sol` | 614 | 26,421 | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` | Core EIP-1167 implementation contract (`ERC721`, `ReentrancyGuard`, `IERC721Receiver`, `VRFV2PlusWrapperConsumerBase`) escrowing one ERC-721 prize and selling fixed-price 1 USDC (`1_000_000`) entries via sequential `[firstEntry, lastEntry]` ERC-721 tickets across lifecycle states (`AwaitingPrize`, `Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`) |
| `packages/contracts/src/RaffleFactory.sol` | 186 | 8,286 | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` | Ownerless factory (`ReentrancyGuard`) deploying EIP-1167 clones of `Raffle`, validating six-decimal `quoteToken` and ERC-165 `prizeToken`, registering clones (`raffleById`, `idByRaffle`, `isRaffle`), and atomically escrowing the prize NFT via `safeTransferFrom` |
| `packages/contracts/src/interfaces/IRaffle.sol` | 521 | 29,703 | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` | Complete interface, `Status` enum, `RaffleInitParams` struct, events, and custom errors for `Raffle` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 150 | 7,875 | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` | Complete interface, `CreateRaffleParams` struct, `RaffleCreated` event, and custom errors for `RaffleFactory` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 43 | 2,172 | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` | Protocol-wide constants (`BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8000`, `ENTRY_PRICE = 1_000_000`, `QUOTE_TOKEN_DECIMALS = 6`, `MAX_REFUND_TICKET_BATCH_SIZE = 100`, `MAX_SALE_DURATION = 30 days`, `DRAW_REQUEST_TIMEOUT = 2 days`, `DRAW_CALLBACK_TIMEOUT = 2 days`, `VRF_CALLBACK_GAS_LIMIT = 300_000`, `VRF_REQUEST_CONFIRMATIONS = 30`) |

## 3. Clean Specification & Compiler / Build Profiles Included in Cold Review
- **Design Specification**: `DESIGN.md` (4 lines, 1,496 bytes, SHA-256: `25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1`)
- **Compiler & Build Configurations**:
  - `packages/contracts/foundry.toml` (SHA-256: `0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50`):
    - `[profile.default]`: `solc_version = "0.8.36"`, `evm_version = "cancun"`, `optimizer = true`, `optimizer_runs = 200`, `via_ir = false`, `fuzz = { runs = 1_000, seed = "0x524146464c45" }`, `invariant = { runs = 256, depth = 64, fail_on_revert = false }`
    - Additional profiles: `ci`, `audit`, `audit_strict`, `audit_release`, `coverage` (`optimizer = false`), `comparison` (`via_ir = true`, `optimizer_runs = 1_000`)
  - `packages/contracts/hardhat.config.ts` (SHA-256: `f49e407ce503095fda43bc32cca2a26fef8341094dc324131f7a427ae52ca28f`):
    - `default` & `production` profiles: `version = "0.8.36"`, `optimizer = { enabled: true, runs: 200 }`, `evmVersion = "cancun"`
  - `packages/contracts/remappings.txt`: `@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/`, `@chainlink/contracts/=node_modules/@chainlink/contracts/`, `forge-std/=lib/forge-std/src/`
- **Reachable Dependency Closure (31 files verified via `dependency-hashes.json`)**:
  - `@chainlink/contracts` v1.5.0 (`VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`, `ConfirmedOwnerWithProposal.sol`, `ConfirmedOwner.sol`, `IOwnable.sol`, `IERC677Receiver.sol`, `LinkTokenInterface.sol`)
  - `@openzeppelin/contracts` v5.6.1 (`proxy/Clones.sol`, `utils/ReentrancyGuard.sol`, `utils/StorageSlot.sol`, `utils/Create2.sol`, `utils/Errors.sol`, `utils/LowLevelCall.sol`, `utils/Panic.sol`, `utils/Context.sol`, `utils/Strings.sol`, `utils/math/Math.sol`, `utils/math/SafeCast.sol`, `utils/introspection/ERC165.sol`, `utils/introspection/IERC165.sol`, `token/ERC20/IERC20.sol`, `token/ERC20/extensions/IERC20Metadata.sol`, `token/ERC20/utils/SafeERC20.sol`, `token/ERC721/ERC721.sol`, `token/ERC721/IERC721.sol`, `token/ERC721/IERC721Receiver.sol`, `token/ERC721/extensions/IERC721Metadata.sol`, `token/ERC721/utils/ERC721Utils.sol`, `interfaces/IERC165.sol`, `interfaces/IERC20.sol`, `interfaces/IERC721.sol`, `interfaces/IERC1363.sol`, `interfaces/draft-IERC6093.sol`)

## 4. Cold-Review Exclusions (Strict Independence Before `FIRST-PASS.md` Seal)
Until `FIRST-PASS.md` is written, UTC-timestamped, and sealed in `FIRST-PASS.md.sha256`, the following are strictly excluded from all cold-review cells (`GEMINI-SIMAO`, `GEMINI-PASHOV`, `GEMINI-TOB`, `GEMINI-GEBAL` cold run, and `GEMINI-SUPPLEMENTARY`):
- All historical test suites (`packages/contracts/test/**`)
- All historical audit reports and corpora (`packages/contracts/audit/**`, `packages/contracts/audit-corpus/**`, `packages/contracts/slither.db.json`)
- All other audit rounds or peer provider lanes (`audits/2026-10-21-r001/runs/**`, `audits/2026-10-21-r001/reconciliation/**`, `audits/2026-10-21-r001/provider-lanes/{openai,anthropic,daybreak}/**`)
- All deterministic scanner/test outputs from the full `target.tar.gz` validation copy
