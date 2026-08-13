# Base fork validation

The fork harness is opt-in through `RUN_FORK_TESTS=true`; the ordinary suite skips it
without silently treating it as passed.

```text
RUN_FORK_TESTS=true forge test --match-contract BaseForkTest -vv
```

An independently gated current-head campaign detects live dependency or interface
drift without making ordinary CI nondeterministic:

```text
RUN_LATEST_FORK_TESTS=true forge test --match-contract BaseForkTest -vv
```

Both flags can be enabled together to compare the pinned and current-head behavior in
one run. The 2026-08-13 current-head rerun passed at Base block `49,923,565` and Base
Sepolia block `45,434,095`.

Two tests passed against pinned Base mainnet block `49,752,968` (chain 8453) and Base
Sepolia block `45,263,498` (chain 84532). The test uses the official chain-specific
addresses:

| Chain        | USDC                                         | Pyth Entropy v2                              |
| ------------ | -------------------------------------------- | -------------------------------------------- |
| Base         | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0x6E7D74FA7d5c90FEF9F0512987605a6d546181Bb` |
| Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7c` | `0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c` |

Validated on local forks:

- runtime code, chain IDs, USDC name/decimals, and exact transfer deltas;
- real `getFeeV2(300_000)` and payable `requestV2(300_000)` encoding;
- callback-wrapper authentication rejection;
- local production factory/raffle construction using fork dependencies;
- standard ERC-721 prize deposit and claim;
- Cancun bytecode execution on Base.

The observed Base mainnet fee quote was `10,000,000,000,000` wei. Pyth may apply a
provider minimum above the requested callback limit; the fork request event exposed a
500,000 effective limit while the local callback consumed 95,078 gas. Fork tests do
not impersonate Pyth to deliver a real production callback and do not replace a
monitored Base Sepolia lifecycle deployment.

Primary address sources: Pyth Entropy chain list and Circle's USDC contract-address
directory. No transaction was broadcast and no public state or funds were changed.
