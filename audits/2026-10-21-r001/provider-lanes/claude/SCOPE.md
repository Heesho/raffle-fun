# Anthropic lane — SCOPE

Target commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` (worktree clean at capture; `working-tree.patch` is empty). Frozen captured_at 2026-10-21T07:38:19.129448+00:00.
The common freeze is `../../freeze.json` (435 files), verified before and after every attempt by `python3 ../../verify-freeze.py`.
`target.tar.gz` sha256 is `67d554df…6aae1d`, checked per attempt.

## Production scope (all five mandatory, interfaces explicitly included)
| File | sha256 |
|---|---|
| `packages/contracts/src/Raffle.sol` | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| `packages/contracts/src/RaffleFactory.sol` | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| `packages/contracts/src/interfaces/IRaffle.sol` | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |

## Single compiler profile
`packages/contracts/foundry.toml` [profile.default]: solc 0.8.36, evm cancun, optimizer on, 200 runs, via_ir false, remappings
`@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/`, `forge-std/=lib/forge-std/src/`. Other profiles (ci, audit*, coverage,
comparison via_ir/1000) change only fuzz parameters or are compatibility/comparison builds. The Hardhat config compiles the same sources.
Dependencies: @openzeppelin/contracts 5.6.1, @chainlink/contracts 1.5.0, forge-std 37a36ca (tests only).

## Reachable dependency source (31 files; hashes independently re-verified 31/31 in the clean context and in the lane validation copy)
| File | sha256 (prefix) |
|---|---|
| `@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` | `f81ec96e909daa2c…` |
| `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` | `8cf045f295b8c603…` |
| `@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` | `a48aaaeaed60e65f…` |
| `@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` | `f3b89bb466c2a79b…` |
| `@openzeppelin/contracts/interfaces/IERC1363.sol` | `9c3a75a925a6dac9…` |
| `@openzeppelin/contracts/interfaces/IERC165.sol` | `dfb3f56fa928a7c6…` |
| `@openzeppelin/contracts/interfaces/IERC20.sol` | `0158e2d3e0e28bed…` |
| `@openzeppelin/contracts/interfaces/draft-IERC6093.sol` | `fa7068f56bc18057…` |
| `@openzeppelin/contracts/proxy/Clones.sol` | `06c768a2b794ea59…` |
| `@openzeppelin/contracts/token/ERC20/IERC20.sol` | `01b6f5c4fa45fd38…` |
| `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` | `0b7132f17d14d1d8…` |
| `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | `c2394cb2a327f234…` |
| `@openzeppelin/contracts/token/ERC721/ERC721.sol` | `ef8e2398c78851bd…` |
| `@openzeppelin/contracts/token/ERC721/IERC721.sol` | `ff0eb9902bf0ac09…` |
| `@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` | `eafee3ffdc7cb2fb…` |
| `@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` | `33223782ea652dca…` |
| `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` | `b48e95db8c85866c…` |
| `@openzeppelin/contracts/utils/Bytes.sol` | `3ce9120a27934c75…` |
| `@openzeppelin/contracts/utils/Context.sol` | `847fda5460fee70f…` |
| `@openzeppelin/contracts/utils/Create2.sol` | `9623aa59745a23a7…` |
| `@openzeppelin/contracts/utils/Errors.sol` | `0704b9d6c032cca8…` |
| `@openzeppelin/contracts/utils/LowLevelCall.sol` | `e128cbe9c6c406d5…` |
| `@openzeppelin/contracts/utils/Panic.sol` | `270fc8401c1a13fa…` |
| `@openzeppelin/contracts/utils/ReentrancyGuard.sol` | `94e409e8f6e31842…` |
| `@openzeppelin/contracts/utils/StorageSlot.sol` | `75704538dcb22323…` |
| `@openzeppelin/contracts/utils/Strings.sol` | `e318709bbe73a783…` |
| `@openzeppelin/contracts/utils/introspection/ERC165.sol` | `61a2b12c96857aaa…` |
| `@openzeppelin/contracts/utils/introspection/IERC165.sol` | `9055c2994b37dea1…` |
| `@openzeppelin/contracts/utils/math/Math.sol` | `bdfdbe133991c0c7…` |
| `@openzeppelin/contracts/utils/math/SafeCast.sol` | `5779bc848bde39f1…` |
| `@openzeppelin/contracts/utils/math/SignedMath.sol` | `1ed50b1056af8867…` |

## Explicit exclusions
Tests, mocks, scripts, deployment/ignition, frontend/SDK/subgraph, docs/whitepaper (beyond DESIGN.md), audit history and corpora,
and scanner configs/suppressions (`slither.config.json`, `slither.db.json`) are not part of the cold review. Tool campaigns run them
only after the seal or explicitly neutralise them (Slither run with an empty config and a fresh triage DB).
No deployed bytecode is in scope, so no on-chain comparison is made.
