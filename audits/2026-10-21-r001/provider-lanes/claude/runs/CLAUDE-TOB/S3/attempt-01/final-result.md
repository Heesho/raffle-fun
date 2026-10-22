I wrote the report to `TOB-S3-token-integration-analyzer.md` in the working directory. Overall risk is **Low–Medium**: no critical or high findings, 1 Medium, 1 Low and 5 Informational. Nothing under `packages/` was modified; the five in-scope file hashes and all 31 dependency hashes are unchanged.

**Main findings**
- **TIA-1 (Medium): when the reserve is met and the winner gets the NFT, buyers carry all the risk of the prize contract.**
  - The factory accepts any contract that claims to be an ERC-721.
  - It checks the prize is held in escrow only once, at creation, using the prize contract's own answers.
  - Settlement then releases 95% of the pot to the sponsor whether or not the NFT can ever be delivered.
  - Tests confirmed three ways the winner ends up with nothing: a fake escrow, a sponsor withdrawing the prize mid-sale through an approval the NFT contract never cleared, and an ENS-style name that expires while escrowed.
  - The fix I recommend fits the current design: re-check the escrow in `buyEntries` and `requestDraw`, plus frontend allowlisting. This catches honest-but-unusual prizes, but not a contract that lies about who owns the NFT.
- **TIA-2 (Low): the treasury and sponsor recipient addresses are fixed forever.** If USDC blocklists either one, those payouts are stuck permanently: fees from every raffle, or one raffle's sponsor proceeds. Winners and refund claimants are not affected, because they can transfer their ticket to another address and claim from there.
- **Informational:**
  - **TIA-3:** purchases are credited without checking what actually arrived, so a future USDC fee would make raffles insolvent.
  - **TIA-4:** the USDC address is only validated by deployment tooling.
  - **TIA-5:** returning the prize to a sponsor recipient set to a future raffle's address moves the NFT into that raffle.
  - **TIA-6:** tickets from every raffle look identical in wallets and marketplaces.
  - **TIA-7:** a sponsor can force the NFT outcome by buying the remaining reserve entries for about 5% of their cost.

The USDC handling itself is solid. Every transfer goes through SafeERC20, accounting uses an internal ledger, all payouts are reentrancy-protected, no zero-value transfers happen, and the splits leave no rounding dust. The ticket ERC-721 passes every `slither-check-erc` check.

**How it was checked**
- **Slither:** the full detector run returned 12 results, all low or informational, with one false positive. The analysis also used the summary and authorization printers.
- **Foundry tests:** 39 pass, against standard USDC, weird ERC-20s and malicious ERC-721 mocks. These include 6 stateful invariants at 131,072 calls each. Five deliberately-failing probes confirmed the fuzzer reached every end state.
- **Isolation:** all builds and tests ran in a scratch copy in `/tmp`, which may be cleaned up, so the full test code is reproduced in Appendix D.

**Not performed**
- **On-chain checks**, because RPC access wasn't authorized. The report lists what to run at deployment.
- **`slither-prop`**, which only applies to ERC-20 tokens and the protocol has none; the invariant suite covers that ground instead.
- **`slither-check-erc` on deployed USDC.**
- **The deployment script** the build config points to (`ignition/modules/RaffleFun.ts`) is not in the tree, so I couldn't check where the USDC address gets pinned.
- **USDC addresses:** the canonical mainnet and Sepolia addresses in TIA-4 still need confirming against Circle's published list.