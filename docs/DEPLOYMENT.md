# Deployment runbook

Hardhat Ignition is the production source of truth. The Foundry script is for local
debugging and independent constructor/state verification.

## Non-negotiable gates

- independent contract/security review completed for the exact source commit;
- legal review for every operating jurisdiction;
- every initially verified Base quote token and the Pyth Entropy v2 address rechecked;
- `eth_getCode` confirms every configured dependency contains expected bytecode;
- protocol treasury and final owner are nonzero Safe/multisig addresses;
- Safe threshold, signers, hardware wallets, and incident procedure reviewed;
- full frozen-lockfile CI passes;
- callback gas retested against production compiler settings;
- Base Sepolia full create/buy/draw/claim smoke test completed.

Never copy an address from an old deployment, this README, or an unverified third-party
post. The repository intentionally ships no production/testnet parameter file.

## Inputs

```text
DEPLOYER_PRIVATE_KEY       temporary funded deployer EOA
VERIFIED_QUOTE_TOKENS      reviewed discovery tokens (comma-separated in Foundry)
ENTROPY                    verified Pyth Entropy v2 contract
PROTOCOL_TREASURY          configured Safe/treasury
FACTORY_OWNER              final Safe
CALLBACK_GAS_LIMIT         default 300000 after regression test
BASE_SEPOLIA_RPC_URL
BASE_RPC_URL               mainnet only
BASESCAN_API_KEY
```

Use a secrets manager or encrypted CI environment. Never commit `.env` or parameter
files containing a key.

## Base Sepolia

1. Record the clean source commit.
2. Run all build, Foundry, Hardhat, ABI, subgraph, and web checks.
3. Prepare an Ignition parameter file outside version control.
4. Deploy:

   ```bash
   pnpm deploy:base-sepolia
   ```

5. Record implementation, factory, lens, blocks, transaction hashes, and constructor
   arguments.
6. Verify contracts:

   ```bash
   pnpm verify:base-sepolia
   ```

7. Ignition starts `transferOwnership(FACTORY_OWNER)`. Confirm `pendingOwner` exactly
   matches the Safe, then submit `acceptOwnership()` from the Safe.
8. Configure later quote-token verification changes through reviewed Safe transactions
   and record each hash. Verification changes official discovery only.
9. Build a candidate deployment record with `verifiedQuoteTokens` as an address array
   and the source commit encoded as exactly the 40 Git SHA hex characters. Validate
   runtime code and write:

   ```bash
   pnpm --filter @raffle-fun/contracts deployment:write ./candidate.json
   ```

10. Run `pnpm sdk:sync`, generate the network subgraph manifest, deploy the subgraph,
    and configure public web endpoints.
11. Complete a smoke raffle using disposable test assets and document create,
    purchase, request, callback, quote claim, and prize claim transactions.

## Mainnet

There is no root mainnet deployment command. Mainnet requires an explicit, reviewed
operator procedure and an environment guard added for that release. Repeat every
testnet step, confirm audit fixes/source commit, use a dedicated deployer, simulate all
Safe transactions, and apply monitoring before enabling public creation.

## Deployment record

`deployments/schema.json` and the TypeScript parser require:

- chain/network, UTC timestamp, positive deployment block;
- deployer and final owner;
- one to 32 initially verified quote tokens, Entropy, implementation, factory, lens,
  treasury;
- callback gas, 20-byte source commit, verification status.

Zero addresses, extra fields, mismatched chain labels, missing RPC, and addresses
without runtime bytecode are rejected. No record is better than a guessed record.

## Rollback and incident reality

Existing clones are immutable and cannot be paused or upgraded. An incident response
can pause creation, remove UI exposure, warn users, and deploy a new factory, but
cannot change an existing raffle's result or seize/redirect claims.
