:::part id="part-iii" no="Part III" title="Creating a Raffle" compact="true"
Creation fixes every raffle-specific asset, party, price, threshold, timestamp, and
dependency before the prize enters escrow.
- 10|Creation Inputs
- 11|Creation Bounds
- 12|Atomic Escrow
- 13|The Recovery Recipient
:::

# Part III | Creating a Raffle

## 10. Creation Inputs

Sofia calls `RaffleFactory.createRaffle` with eight sponsor-controlled fields:

| Input | Plain meaning | Pixel Passport example |
| --- | --- | --- |
| `prizeToken` | ERC-721 collection contract | fictional Pixel Passport collection |
| `prizeTokenId` | exact prize within that collection | 42 |
| `sponsorPrizeRecoveryRecipient` | fixed NFT recipient for cash, refund, or empty outcome | Sofia's secure recovery wallet |
| `ticketPrice` | complete raw USDC price for one ticket | 10,000,000 raw units = 10.00 USDC |
| `minimumTickets` | sold count selecting NFT rather than cash after a valid callback | 100 |
| `startTime` | inclusive sale start; zero means the creation timestamp | immediate |
| `endTime` | exclusive sale end | seven days after start |
| `metadataURI` | shared raffle and ticket metadata URI | fictional HTTPS or content-addressed URI |

The sponsor does not supply the quote token, Entropy address, callback gas limit,
protocol treasury, factory address, or raffle ID. The factory fixes or assigns those
values.

The displayed ticket price is the full gross price. It is not a deposit, pre-fee
amount, or partial contribution. Economic fees are allocated only after a successful
random callback.

## 11. Creation Bounds

The factory rejects a creation unless:

- the prize address has deployed code and reports ERC-721 support;
- `ticketPrice` is nonzero;
- `minimumTickets` is nonzero;
- a nonzero scheduled start is not in the past;
- start is no more than {{MAX_START_DELAY_DAYS}} days after creation;
- end is strictly after the normalized start;
- sale duration is no more than {{MAX_SALE_DURATION_DAYS}} days;
- the metadata URI is at most {{MAX_METADATA_URI_LENGTH}} bytes;
- future creation is not paused.

These are custody and execution bounds. They do not decide whether the chosen price,
threshold, duration, prize, or promotional structure is commercially sensible or
legally permitted.

The minimum threshold is not a supply cap. A threshold of 100 means that a valid draw
with 100 or more sold tickets awards the NFT. It does not stop ticket 101, 120, or
10,000 from being sold before the sale ends.

:::callout kind="sponsor" title="For sponsors"
Verify the recovery recipient character by character. It cannot be changed after
creation. A zero input intentionally defaults to the sponsor, but a separate secured
wallet may reduce operational risk if it can call `claimSponsorPrize`.
:::

## 12. Atomic Escrow

The factory uses ordinary constructor `CREATE`. It does not deploy an EIP-1167 clone,
an initializer proxy, a CREATE2 address, or an upgradeable raffle. Each new raffle has
its own runtime code, storage, tickets, liabilities, and assets.

Creation follows one transaction:

1. validate the sponsor-controlled fields;
2. normalize a zero start to the current block timestamp;
3. assign the next raffle ID;
4. constructor-deploy an independent `Raffle` with all fixed values;
5. register its address in both ID mappings and `isRaffle`;
6. emit the indexer-complete `RaffleCreated` event;
7. safe-transfer the configured NFT from the sponsor to the raffle;
8. have the raffle receiver validate token, ID, sponsor, operator, and status;
9. verify `ownerOf` and `Active` after transfer.

An Ethereum transaction is atomic: either the complete sequence succeeds or every
state and asset movement reverts. A rejecting prize, dishonest postcondition,
reentrant factory attempt, wrong approval, or receiver mismatch cannot leave a
successfully registered but unfunded raffle.

The event is emitted before the external NFT transfer in execution order, but a later
failure reverts the event with the transaction. Indexers should not treat a reverted
log as creation evidence.

:::callout kind="hood" title="Under the hood"
The raffle constructor begins at `AwaitingPrize` and accepts only its declared factory
as `msg.sender`. The safe receiver moves it to `Active`. No successfully completed
factory creation should leave a registered raffle at `AwaitingPrize`.
:::

## 13. The Recovery Recipient

The recovery recipient exists because sponsor identity and operational asset custody
need not be the same address. Sofia can sponsor the raffle from one account while her
security-controlled wallet is responsible for recovering Pixel Passport #42 if the
NFT is not awarded.

The recovery recipient receives the right to claim the NFT in three result groups:

- `CashWon`, after a valid draw below the threshold;
- `Refunding`, after the request or callback liveness deadline;
- `Closed`, after zero sales.

It does not receive sponsor USDC proceeds merely because it holds this NFT right.
Successful sponsor quote claims belong to the immutable sponsor address. It cannot
claim the NFT in `NftWon`, where the winning bearer holds the prize right.

The recipient chooses a safe nonzero destination at claim time. If the destination
rejects the NFT, the transaction reverts and `prizeClaimed` returns to its prior value,
so the authorized recipient can retry.

Known protocol addresses cannot be configured as unsafe fixed recipients. The
constructor rejects itself, the factory, quote token, Entropy contract, prize token,
and registered sibling raffles. A permissionless selective helper covers a narrower
case where a future same-factory raffle address was selected while still code-less.
Recovered assets route only to the holding raffle's immutable recovery recipient.
