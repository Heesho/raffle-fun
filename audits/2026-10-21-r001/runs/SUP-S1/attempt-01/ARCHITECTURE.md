# Architecture, authority and assets

## Contract and call map

```
Untrusted sponsor --createRaffle(params)--> immutable RaffleFactory
  Factory --CREATE fixed EIP1167 proxy--> one Raffle clone
  Factory --initialize(factory-only)--> clone AwaitingPrize
  Factory --safeTransferFrom(sponsor,clone,id)--> arbitrary prize contract
  Prize --exact onERC721Received(factory,sponsor,id)--> clone Active
  Factory --ownerOf(id),status()--> verifies present escrow and Active

Buyer --canonical USDC payment + buyEntries(recipient,count)--> clone
  clone --safeMint range ticket--> recipient callback (untrusted)
  ticket owner/operator --ERC721 transfer--> next bearer

Anyone --native fee + requestDraw--> clone Drawing
  clone --native funding request--> trusted immutable Chainlink wrapper
  wrapper --authenticated timely random callback--> NftWon or CashWon
Anyone --winning range ID + settle--> ledger allocation only
Current ticket owner --redeem+burn--> NFT or cash
Anyone --releaseSponsorProceeds/releaseProtocolFees--> immutable payees
Anyone --releaseSponsorPrize on CashWon/Refunding--> immutable sponsor payee
Anyone --enableRefunds at deadline--> Refunding; owners --refund+burn--> USDC
```

## Lifecycle

| From | Trigger | To | Time/authority |
|---|---|---|---|
| clone-zero AwaitingPrize | initialize fills config | AwaitingPrize | factory once, during atomic create |
| AwaitingPrize | exact configured NFT deposit callback | Active | exact prizeToken, id, sponsor and factory operator |
| Active | buyEntries | Active | any buyer, t<end, positive entries |
| Active | requestDraw | Drawing | anyone funds fee, E>0, end<=t<end+2days |
| Active | enableRefunds, E=0 | Refunding | sponsor anytime or anyone t>=end |
| Active | enableRefunds, E>0 | Refunding | anyone t>=end+2days |
| Drawing | accepted wrapper callback | NftWon/CashWon | before requestedAt+2days; E>=reserve selects NFT |
| Drawing | enableRefunds | Refunding | anyone at/after requestedAt+2days |
| terminal result | settle/redemption/releases | same terminal | one-time flags and current bearer authority |

## Trust map

- **Deployment:** chooses immutable canonical USDC, canonical wrapper and treasury. Constructor can check code/decimals, not official identity, administration, network support or operational availability. No later correction mechanism.
- **Factory/implementation:** protocol-owned fixed code, no administrator or upgrade path. Only factory initializes. Registry is authoritative for same-factory clone discovery and sink checks.
- **Quote token:** trusted six-decimal, standard, fee-free, nonrebasing USDC. SafeERC20 handles revert/false/no-return; it does not prove economic delivery for a malicious replacement token. USDC administration/blacklisting remains an external availability dependency.
- **VRF wrapper:** trusted official identity and async request/callback semantics. Only it can call the externally exposed raw callback successfully. Random value and fulfillment availability are outside sponsor/buyer control under that trust.
- **Sponsor:** untrusted parameter chooser and prize depositor. Cannot cancel a sold raffle, edit deadlines/reserve/recipients, select randomness or withdraw unallocated quote funds.
- **Prize token:** untrusted external calls in the clean design; source interface limits support to honest standards-compliant ERC721s. This is a material boundary conflict. Callback/ownerOf checks authenticate only what the external contract reports at the time.
- **Ticket recipient/owner:** untrusted code may reenter or reject safeMint. Current bearer chooses transfer/redemption/refund. Loss of key, sending to sink or wallet inability to call is not repaired by protocol.
- **Treasury/sponsor recipient:** immutable payout targets; transfers are permissionless to those targets. Their failure does not block settlement or unrelated claim release.
- **Permissionless callers:** may fund draw, activate due refunds, prove winning range and trigger payouts; cannot choose recipient or redirect liabilities.

## Asset/liability map

| Asset | Ingress | Custody/accounting | Egress |
|---|---|---|---|
| canonical USDC | buyer safeTransferFrom | one clone; U before terminal migration, then refund R or W/S/F | owner refund, cash winner, immutable sponsor, immutable treasury |
| prize ERC721 | atomic factory safeTransferFrom | exact token/id; prizeClaimed prevents repeat; no USDC-equivalent valuation | NFT winner if reserve met; sponsor recipient otherwise |
| range-ticket ERC721 | one mint per purchase | contiguous inclusive range; lifetime range survives burns; transferable in every state | burned only by redeem/refund; represents bearer claim |
| native currency | requestDraw msg.value | temporary fee + excess; forced currency unaccounted | actual wrapper fee and atomic caller refund; no rescue |
| unsolicited USDC/NFT/LINK | direct/forced transfer possible | not added to protocol liability | no rescue or sweep path |

## External call / rollback boundaries

1. Factory interface probe uses staticcall. Clone creation/init/registration and prize safe transfer are atomic. Malicious prize callbacks may access the active clone before create returns, but factory status/ownership postchecks still constrain the successful final state; no victim balance exists before this creation unless callers fund it within that same transaction.
2. buyEntries performs canonical payment before range bookkeeping, then safeMint after bookkeeping. Guard prevents economic callbacks; receiver can transfer its newly owned ticket. Receiver revert rolls back payment and bookkeeping.
3. requestDraw enters Drawing and in-flight state before wrapper call. All request/native-refund failures revert the entire request. Authenticated callback outside the in-flight period records only an entry/result.
4. Settlement performs no token/owner calls, only range checks and liability writes. Its liveness is independent of prize/recipient behavior.
5. Redemptions clear/burn before external delivery and verify NFT owner afterwards. Transfer failure reverts that call. Separate earlier settlement/release transactions remain final.
6. Sponsor prize/proceeds/fee functions clear their one claim before transfer and are independent. No externally supplied destination can redirect them.
