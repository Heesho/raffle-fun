import {
  afterEach,
  assert,
  clearStore,
  describe,
  newMockEvent,
  test,
} from "matchstick-as/assembly/index";
import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import {
  QuoteTokenVerificationUpdated,
  RaffleCreated,
} from "../generated/RaffleFactory/RaffleFactory";
import {
  DrawFailureFinalized,
  PrizeClaimed,
  PrizeDeposited,
  QuoteClaimed,
  RaffleResolved,
  TicketRefundCredited,
  TicketsPurchased,
  Transfer,
} from "../generated/templates/Raffle/Raffle";
import {
  handleQuoteTokenVerificationUpdated,
  handleRaffleCreated,
} from "../src/factory";
import {
  handleDrawFailureFinalized,
  handlePrizeClaimed,
  handlePrizeDeposited,
  handleQuoteClaimed,
  handleRaffleResolved,
  handleTicketRefundCredited,
  handleTicketsPurchased,
  handleTransfer,
} from "../src/raffle";
import { eventId, ticketId } from "../src/helpers";

const FACTORY = Address.fromString(
  "0x1000000000000000000000000000000000000001",
);
const RAFFLE = Address.fromString("0x2000000000000000000000000000000000000002");
const SPONSOR = Address.fromString(
  "0x3000000000000000000000000000000000000003",
);
const RECOVERY = Address.fromString(
  "0x7000000000000000000000000000000000000007",
);
const TREASURY = Address.fromString(
  "0x4000000000000000000000000000000000000004",
);
const BUYER = Address.fromString("0x5000000000000000000000000000000000000005");
const RECIPIENT = Address.fromString(
  "0x6000000000000000000000000000000000000006",
);
const PRIZE = Address.fromString("0x8000000000000000000000000000000000000008");
const QUOTE = Address.fromString("0x9000000000000000000000000000000000000009");

describe("Raffle mappings", () => {
  afterEach(() => {
    clearStore();
  });

  test("factory creation starts the dynamic template before same-block prize deposit", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    assert.entityCount("Protocol", 1);
    assert.entityCount("Raffle", 1);
    assert.dataSourceCount("Raffle", 1);
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "state",
      "AWAITING_PRIZE",
    );
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "minimumTickets", "100");
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "verified",
      "false",
    );

    handlePrizeDeposited(createPrizeDepositedEvent());
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "state", "ACTIVE");
  });

  test("quote-token verification controls discovery metadata without changing raffles", () => {
    handleQuoteTokenVerificationUpdated(
      createQuoteTokenVerificationUpdatedEvent(false, true),
    );
    handleRaffleCreated(createRaffleCreatedEvent());
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "verified",
      "true",
    );

    handleQuoteTokenVerificationUpdated(
      createQuoteTokenVerificationUpdatedEvent(true, false),
    );
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "verified",
      "false",
    );
    assert.entityCount("Raffle", 1);
  });

  test("multi-ticket purchase links prior mint transfers and updates aggregates", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    handlePrizeDeposited(createPrizeDepositedEvent());
    handleTransfer(createTransferEvent(Address.zero(), RECIPIENT, 1, 1));
    handleTransfer(createTransferEvent(Address.zero(), RECIPIENT, 2, 2));
    const purchaseEvent = createPurchaseEvent();
    handleTicketsPurchased(purchaseEvent);

    assert.entityCount("Purchase", 1);
    assert.entityCount("Ticket", 2);
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "totalTickets", "2");
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "grossSales", "2000000");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "unsettledPot",
      "2000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "0",
    );
    assert.fieldEquals("Protocol", FACTORY.toHexString(), "totalTickets", "2");
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "grossVolume",
      "2000000",
    );
    assert.fieldEquals(
      "Ticket",
      ticketId(RAFFLE, BigInt.fromI32(2)),
      "purchase",
      eventId(purchaseEvent),
    );
    assert.fieldEquals(
      "Account",
      RECIPIENT.toHexString(),
      "ticketsCurrentlyOwned",
      "2",
    );
  });

  test("pre-draw transfer and cash resolution preserve ownership history and mark the winner", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    handleTransfer(createTransferEvent(Address.zero(), BUYER, 1, 1));
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, 1, 2));
    handleRaffleResolved(createResolutionEvent(2));

    const id = ticketId(RAFFLE, BigInt.fromI32(1));
    assert.fieldEquals("Ticket", id, "currentOwner", RECIPIENT.toHexString());
    assert.fieldEquals("Ticket", id, "winning", "true");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "outcome",
      "CASH_FALLBACK",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winner",
      RECIPIENT.toHexString(),
    );
    assert.entityCount("RaffleTransfer", 2);
    assert.entityCount("Resolution", 1);
    assert.fieldEquals(
      "Resolution",
      eventId(createResolutionEvent(2)),
      "protocolFee",
      "100000",
    );
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "protocolFees",
      "100000",
    );
  });

  test("threshold-met resolution records the NFT outcome and winner claimant", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    handleTransfer(createTransferEvent(Address.zero(), RECIPIENT, 1, 1));
    handleRaffleResolved(createResolutionEvent(1));

    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "outcome",
      "NFT_AWARDED",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "prizeClaimant",
      RECIPIENT.toHexString(),
    );
    assert.fieldEquals(
      "Protocol",
      FACTORY.toHexString(),
      "nftAwardedCount",
      "1",
    );
  });

  test("failed draws and bounded refund credits reconstruct liabilities", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    handleTransfer(createTransferEvent(Address.zero(), RECIPIENT, 1, 1));
    handleTransfer(createTransferEvent(Address.zero(), BUYER, 2, 2));
    handleTicketsPurchased(createPurchaseEvent());

    handleDrawFailureFinalized(createDrawFailureEvent());
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "state", "REFUNDING");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "outcome",
      "DRAW_NOT_REQUESTED",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "prizeClaimant",
      RECOVERY.toHexString(),
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "uncreditedRefundLiability",
      "2000000",
    );
    assert.fieldEquals(
      "Protocol",
      FACTORY.toHexString(),
      "refundingCount",
      "1",
    );
    assert.entityCount("DrawFailure", 1);

    handleTicketRefundCredited(
      createTicketRefundCreditedEvent(1, RECIPIENT, 1_000_000, 1_000_000, 6),
    );
    handleTicketRefundCredited(
      createTicketRefundCreditedEvent(2, BUYER, 1_000_000, 0, 7),
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "uncreditedRefundLiability",
      "0",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalRefundCredited",
      "2000000",
    );
    assert.fieldEquals(
      "Ticket",
      ticketId(RAFFLE, BigInt.fromI32(1)),
      "refundOwner",
      RECIPIENT.toHexString(),
    );
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "refundedVolume",
      "2000000",
    );
    assert.entityCount("TicketRefund", 2);
  });

  test("duplicate delivery is idempotent for counters and immutable histories", () => {
    const created = createRaffleCreatedEvent();
    handleRaffleCreated(created);
    handleRaffleCreated(created);
    const transfer = createTransferEvent(Address.zero(), RECIPIENT, 1, 1);
    handleTransfer(transfer);
    handleTransfer(transfer);
    const purchase = createPurchaseEvent();
    handleTicketsPurchased(purchase);
    handleTicketsPurchased(purchase);
    const resolution = createResolutionEvent(2);
    handleRaffleResolved(resolution);
    handleRaffleResolved(resolution);

    assert.fieldEquals("Protocol", FACTORY.toHexString(), "raffleCount", "1");
    assert.fieldEquals("Protocol", FACTORY.toHexString(), "totalTickets", "2");
    assert.fieldEquals("Protocol", FACTORY.toHexString(), "resolvedCount", "1");
    assert.fieldEquals(
      "Account",
      RECIPIENT.toHexString(),
      "ticketsCurrentlyOwned",
      "1",
    );
    assert.entityCount("Purchase", 1);
    assert.entityCount("Resolution", 1);
    assert.entityCount("RaffleTransfer", 1);
  });

  test("quote and prize claims create immutable history and update totals", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    handleQuoteClaimed(createQuoteClaimedEvent());
    handlePrizeClaimed(createPrizeClaimedEvent());

    assert.entityCount("QuoteClaim", 1);
    assert.entityCount("PrizeClaim", 1);
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "quoteClaimed",
      "1520000",
    );
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "prizeClaimed", "true");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "prizeDestination",
      SPONSOR.toHexString(),
    );
  });
});

function createRaffleCreatedEvent(): RaffleCreated {
  const event = changetype<RaffleCreated>(newMockEvent());
  event.address = FACTORY;
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam(
      "raffleId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(1)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam("raffle", ethereum.Value.fromAddress(RAFFLE)),
  );
  event.parameters.push(
    new ethereum.EventParam("sponsor", ethereum.Value.fromAddress(SPONSOR)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "sponsorPrizeRecoveryRecipient",
      ethereum.Value.fromAddress(RECOVERY),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam("prizeToken", ethereum.Value.fromAddress(PRIZE)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "prizeTokenId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(42)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam("quoteToken", ethereum.Value.fromAddress(QUOTE)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "protocolTreasury",
      ethereum.Value.fromAddress(TREASURY),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "ticketPrice",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(1_000_000)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "minimumTickets",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(100)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "startTime",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(1_000)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "endTime",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(2_000)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "requestGraceDeadline",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(3_000)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "metadataURI",
      ethereum.Value.fromString("ipfs://raffle"),
    ),
  );
  return event;
}

function createQuoteTokenVerificationUpdatedEvent(
  previousVerified: boolean,
  newVerified: boolean,
): QuoteTokenVerificationUpdated {
  const event = changetype<QuoteTokenVerificationUpdated>(newMockEvent());
  event.address = FACTORY;
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("quoteToken", ethereum.Value.fromAddress(QUOTE)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "previousVerified",
      ethereum.Value.fromBoolean(previousVerified),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "newVerified",
      ethereum.Value.fromBoolean(newVerified),
    ),
  );
  return event;
}

function createPrizeDepositedEvent(): PrizeDeposited {
  const event = changetype<PrizeDeposited>(newMockEvent());
  event.address = RAFFLE;
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("prizeToken", ethereum.Value.fromAddress(PRIZE)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "prizeTokenId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(42)),
    ),
  );
  event.parameters.push(
    new ethereum.EventParam("sponsor", ethereum.Value.fromAddress(SPONSOR)),
  );
  return event;
}

function createTransferEvent(
  from: Address,
  to: Address,
  tokenIdValue: i32,
  logIndex: i32,
): Transfer {
  const event = changetype<Transfer>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(logIndex);
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from)),
  );
  event.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(tokenIdValue)),
    ),
  );
  return event;
}

function createPurchaseEvent(): TicketsPurchased {
  const event = changetype<TicketsPurchased>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(3);
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(BUYER)),
  );
  event.parameters.push(
    new ethereum.EventParam("recipient", ethereum.Value.fromAddress(RECIPIENT)),
  );
  pushUnsigned(event, "quantity", 2);
  pushUnsigned(event, "firstTicketId", 1);
  pushUnsigned(event, "lastTicketId", 2);
  pushUnsigned(event, "grossAmount", 2_000_000);
  return event;
}

function createResolutionEvent(outcome: i32): RaffleResolved {
  const event = changetype<RaffleResolved>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(4);
  event.parameters = new Array();
  pushUnsigned(event, "sequenceNumber", 1);
  pushUnsigned(event, "winningTicketId", 1);
  event.parameters.push(
    new ethereum.EventParam("winner", ethereum.Value.fromAddress(RECIPIENT)),
  );
  pushUnsigned(event, "outcome", outcome);
  event.parameters.push(
    new ethereum.EventParam(
      "prizeClaimant",
      ethereum.Value.fromAddress(outcome == 1 ? RECIPIENT : SPONSOR),
    ),
  );
  pushUnsigned(event, "protocolFee", 100_000);
  pushUnsigned(event, "winnerCashAmount", outcome == 1 ? 0 : 1_520_000);
  pushUnsigned(event, "sponsorCashAmount", outcome == 1 ? 1_900_000 : 380_000);
  return event;
}

function createQuoteClaimedEvent(): QuoteClaimed {
  const event = changetype<QuoteClaimed>(newMockEvent());
  event.address = RAFFLE;
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(RECIPIENT)),
  );
  event.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(RECIPIENT)),
  );
  pushUnsigned(event, "amount", 1_520_000);
  return event;
}

function createPrizeClaimedEvent(): PrizeClaimed {
  const event = changetype<PrizeClaimed>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  event.parameters.push(
    new ethereum.EventParam("claimant", ethereum.Value.fromAddress(SPONSOR)),
  );
  event.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(SPONSOR)),
  );
  event.parameters.push(
    new ethereum.EventParam("prizeToken", ethereum.Value.fromAddress(PRIZE)),
  );
  pushUnsigned(event, "prizeTokenId", 42);
  return event;
}

function createDrawFailureEvent(): DrawFailureFinalized {
  const event = changetype<DrawFailureFinalized>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  pushUnsigned(event, "outcome", 5);
  event.parameters.push(
    new ethereum.EventParam("finalizer", ethereum.Value.fromAddress(BUYER)),
  );
  event.parameters.push(
    new ethereum.EventParam(
      "prizeClaimant",
      ethereum.Value.fromAddress(RECOVERY),
    ),
  );
  pushUnsigned(event, "grossRefundLiability", 2_000_000);
  return event;
}

function createTicketRefundCreditedEvent(
  tokenIdValue: i32,
  owner: Address,
  amount: i32,
  remaining: i32,
  logIndex: i32,
): TicketRefundCredited {
  const event = changetype<TicketRefundCredited>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(logIndex);
  event.parameters = new Array();
  pushUnsigned(event, "ticketId", tokenIdValue);
  event.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner)),
  );
  pushUnsigned(event, "amount", amount);
  pushUnsigned(event, "remainingRefundLiability", remaining);
  return event;
}

function pushUnsigned(event: ethereum.Event, name: string, value: i32): void {
  event.parameters.push(
    new ethereum.EventParam(
      name,
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(value)),
    ),
  );
}
