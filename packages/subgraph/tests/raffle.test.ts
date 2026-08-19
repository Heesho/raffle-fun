import {
  afterEach,
  assert,
  clearStore,
  describe,
  newMockEvent,
  test,
} from "matchstick-as/assembly/index";
import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { RaffleCreated } from "../generated/RaffleFactory/RaffleFactory";
import {
  DrawRequested,
  RaffleResolved,
  TicketPurchased,
  TicketsRefunded,
  RefundsEnabled,
  Transfer,
  VrfCallbackIgnored,
  WinnerPrizeReleased,
  WinnerProceedsReleased,
  WinningTicketSettled,
} from "../generated/templates/Raffle/Raffle";
import { handleRaffleCreated } from "../src/factory";
import {
  handleDrawRequested,
  handleRaffleResolved,
  handleTicketPurchased,
  handleTicketsRefunded,
  handleRefundsEnabled,
  handleTransfer,
  handleVrfCallbackIgnored,
  handleWinnerPrizeReleased,
  handleWinnerProceedsReleased,
  handleWinningTicketSettled,
} from "../src/raffle";
import { ticketEntityId } from "../src/helpers";

const FACTORY = Address.fromString(
  "0x1000000000000000000000000000000000000001",
);
const RAFFLE = Address.fromString("0x2000000000000000000000000000000000000002");
const SPONSOR = Address.fromString(
  "0x3000000000000000000000000000000000000003",
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
const TICKET_ID = BigInt.fromI32(1);

describe("Raffle mappings", () => {
  afterEach(() => clearStore());

  test("factory creation is active because escrow was verified before the event", () => {
    handleRaffleCreated(createRaffleCreatedEvent());

    assert.entityCount("Raffle", 1);
    assert.dataSourceCount("Raffle", 1);
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "ACTIVE");
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "entryPrice", "1000000");
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "reserveEntries", "100");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "drawRequestDeadline",
      "174800",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "sponsorRecipient",
      SPONSOR.toHexString(),
    );
  });

  test("one purchase creates one range ticket without per-entry entities", () => {
    createPurchasedRaffle();
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, TICKET_ID, 4));

    const id = ticketEntityId(RAFFLE, TICKET_ID);
    assert.entityCount("Ticket", 1);
    assert.entityCount("Purchase", 1);
    assert.fieldEquals("Ticket", id, "firstEntry", "1");
    assert.fieldEquals("Ticket", id, "lastEntry", "20");
    assert.fieldEquals("Ticket", id, "entryCount", "20");
    assert.fieldEquals("Ticket", id, "currentOwner", RECIPIENT.toHexString());
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "totalEntries", "20");
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "ticketCount", "1");
    assert.fieldEquals("Account", BUYER.toHexString(), "entriesBought", "20");
    assert.fieldEquals(
      "Account",
      RECIPIENT.toHexString(),
      "ticketsCurrentlyOwned",
      "1",
    );
  });

  test("uint128-sized purchase values remain BigInt and still create one entity", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    const maxEntries = BigInt.fromString(
      "340282366920938463463374607431768211455",
    );
    const gross = BigInt.fromString(
      "340282366920938463463374607431768211455000000",
    );
    handleTransfer(createTransferEvent(Address.zero(), BUYER, TICKET_ID, 1));
    handleTicketPurchased(
      createPurchaseEvent(TICKET_ID, maxEntries, maxEntries, gross),
    );

    assert.entityCount("Ticket", 1);
    assert.entityCount("Purchase", 1);
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalEntries",
      maxEntries.toString(),
    );
    assert.fieldEquals(
      "Ticket",
      ticketEntityId(RAFFLE, TICKET_ID),
      "entryCount",
      maxEntries.toString(),
    );
  });

  test("cash resolution records 80/5/15 of gross", () => {
    createPurchasedRaffle();
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, TICKET_ID, 4));
    handleDrawRequested(createDrawRequestedEvent());
    const resolution = createResolutionEvent(4);
    const resolutionId = resolution.transaction.hash.toHexString() + "-6";
    handleRaffleResolved(resolution);
    handleTransfer(
      createTransferEvent(RECIPIENT, Address.zero(), TICKET_ID, 7),
    );
    handleWinningTicketSettled(createWinningSettlementEvent(4));

    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "CASH_WON");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "1000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winnerProceeds",
      "16000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winnerRecipient",
      RECIPIENT.toHexString(),
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "sponsorProceeds",
      "3000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "protocolFees",
      "1000000",
    );
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "winningEntry", "2");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winningTicketId",
      TICKET_ID.toString(),
    );
    assert.fieldEquals(
      "Ticket",
      ticketEntityId(RAFFLE, TICKET_ID),
      "winning",
      "true",
    );
    assert.entityCount("WinningSettlement", 1);

    const release = createWinnerProceedsReleasedEvent();
    handleWinnerProceedsReleased(release);
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "winnerProceeds", "0");
    assert.fieldEquals(
      "QuoteTokenStats",
      FACTORY.toHexString() + "-" + QUOTE.toHexString(),
      "winnerCashRedeemed",
      "16000000",
    );
    assert.fieldEquals(
      "ProceedsRelease",
      release.transaction.hash.toHexString() + "-9",
      "kind",
      "WINNER",
    );
  });

  test("ignored VRF callbacks are indexed for operational alerts", () => {
    createPurchasedRaffle();
    handleDrawRequested(createDrawRequestedEvent());
    const ignored = createIgnoredCallbackEvent(999, 1, 2, 6);
    handleVrfCallbackIgnored(ignored);
    handleVrfCallbackIgnored(ignored);

    const id = ignored.transaction.hash.toHexString() + "-6";
    assert.entityCount("IgnoredVrfCallback", 1);
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "ignoredVrfCallbackCount",
      "1",
    );
    assert.fieldEquals("IgnoredVrfCallback", id, "receivedRequestId", "999");
    assert.fieldEquals("IgnoredVrfCallback", id, "expectedRequestId", "1");
    assert.fieldEquals("IgnoredVrfCallback", id, "status", "DRAWING");
  });

  test("NFT settlement allocates fees before isolated prize delivery", () => {
    createPurchasedRaffle();
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, TICKET_ID, 4));
    handleDrawRequested(createDrawRequestedEvent());
    handleRaffleResolved(createResolutionEvent(3));

    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "unsettledPot",
      "20000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "0",
    );

    handleTransfer(
      createTransferEvent(RECIPIENT, Address.zero(), TICKET_ID, 7),
    );
    handleWinningTicketSettled(createWinningSettlementEvent(3));
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "unsettledPot", "0");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "sponsorProceeds",
      "19000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "1000000",
    );
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "prizeClaimed", "false");

    const release = createWinnerPrizeReleasedEvent();
    handleWinnerPrizeReleased(release);
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "prizeClaimed", "true");
    assert.entityCount("WinnerPrizeRelease", 1);
  });

  test("refund redemption records ticket and entry quantities separately", () => {
    createPurchasedRaffle();
    handleRefundsEnabled(createRefundsEnabledEvent());
    handleTransfer(createTransferEvent(BUYER, Address.zero(), TICKET_ID, 6));
    const redemption = createRefundRedemptionEvent();
    handleTicketsRefunded(redemption);

    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "REFUNDING");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "remainingRefundLiability",
      "0",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalRefundRedeemed",
      "20000000",
    );
    assert.entityCount("RefundEnable", 1);
    assert.entityCount("RefundRedemption", 1);
    const redemptionId = redemption.transaction.hash.toHexString() + "-8";
    assert.fieldEquals("RefundRedemption", redemptionId, "ticketQuantity", "1");
    assert.fieldEquals("RefundRedemption", redemptionId, "entryQuantity", "20");
  });
});

function createPurchasedRaffle(): void {
  handleRaffleCreated(createRaffleCreatedEvent());
  handleTransfer(createTransferEvent(Address.zero(), BUYER, TICKET_ID, 1));
  handleTicketPurchased(
    createPurchaseEvent(
      TICKET_ID,
      BigInt.fromI32(20),
      BigInt.fromI32(20),
      BigInt.fromI32(20_000_000),
    ),
  );
}

function createRaffleCreatedEvent(): RaffleCreated {
  const event = changetype<RaffleCreated>(newMockEvent());
  event.address = FACTORY;
  event.logIndex = BigInt.zero();
  event.parameters = new Array();
  pushUnsigned(event, "raffleId", 1);
  pushAddress(event, "raffle", RAFFLE);
  pushAddress(event, "sponsor", SPONSOR);
  pushAddress(event, "sponsorRecipient", SPONSOR);
  pushAddress(event, "prizeToken", PRIZE);
  pushUnsigned(event, "prizeTokenId", 42);
  pushAddress(event, "quoteToken", QUOTE);
  pushAddress(event, "protocolTreasury", TREASURY);
  pushUnsigned(event, "reserveEntries", 100);
  pushUnsigned(event, "endTime", 2_000);
  return event;
}

function createTransferEvent(
  from: Address,
  to: Address,
  tokenId: BigInt,
  logIndex: i32,
): Transfer {
  const event = changetype<Transfer>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(logIndex);
  event.parameters = new Array();
  pushAddress(event, "from", from);
  pushAddress(event, "to", to);
  pushBigInt(event, "tokenId", tokenId);
  return event;
}

function createPurchaseEvent(
  ticketId: BigInt,
  lastEntry: BigInt,
  entryCount: BigInt,
  grossAmount: BigInt,
): TicketPurchased {
  const event = changetype<TicketPurchased>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(2);
  event.parameters = new Array();
  pushAddress(event, "buyer", BUYER);
  pushAddress(event, "recipient", BUYER);
  pushBigInt(event, "ticketId", ticketId);
  pushUnsigned(event, "firstEntry", 1);
  pushBigInt(event, "lastEntry", lastEntry);
  pushBigInt(event, "entryCount", entryCount);
  pushBigInt(event, "grossAmount", grossAmount);
  return event;
}

function createDrawRequestedEvent(): DrawRequested {
  const event = changetype<DrawRequested>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  pushUnsigned(event, "requestId", 1);
  pushAddress(event, "requester", BUYER);
  pushUnsigned(event, "fee", 1_000);
  pushUnsigned(event, "excessReturned", 0);
  pushUnsigned(event, "drawRequestedAt", 2_000);
  pushUnsigned(event, "callbackDeadline", 174_800);
  return event;
}

function createResolutionEvent(result: i32): RaffleResolved {
  const event = changetype<RaffleResolved>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(6);
  event.parameters = new Array();
  pushUnsigned(event, "requestId", 1);
  pushUnsigned(event, "winningEntry", 2);
  pushUnsigned(event, "result", result);
  return event;
}

function createIgnoredCallbackEvent(
  receivedRequestId: i32,
  expectedRequestId: i32,
  status: i32,
  logIndex: i32,
): VrfCallbackIgnored {
  const event = changetype<VrfCallbackIgnored>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(logIndex);
  event.parameters = new Array();
  pushUnsigned(event, "receivedRequestId", receivedRequestId);
  pushUnsigned(event, "expectedRequestId", expectedRequestId);
  pushUnsigned(event, "status", status);
  return event;
}

function createWinningSettlementEvent(result: i32): WinningTicketSettled {
  const event = changetype<WinningTicketSettled>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(8);
  event.parameters = new Array();
  pushBigInt(event, "ticketId", TICKET_ID);
  pushAddress(event, "winner", RECIPIENT);
  pushUnsigned(event, "result", result);
  pushUnsigned(event, "cashAmount", result == 4 ? 16_000_000 : 0);
  pushUnsigned(event, "protocolFee", 1_000_000);
  pushUnsigned(event, "sponsorAmount", result == 3 ? 19_000_000 : 3_000_000);
  return event;
}

function createWinnerProceedsReleasedEvent(): WinnerProceedsReleased {
  const event = changetype<WinnerProceedsReleased>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(9);
  event.parameters = new Array();
  pushAddress(event, "caller", BUYER);
  pushAddress(event, "recipient", RECIPIENT);
  pushUnsigned(event, "amount", 16_000_000);
  return event;
}

function createWinnerPrizeReleasedEvent(): WinnerPrizeReleased {
  const event = changetype<WinnerPrizeReleased>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(9);
  event.parameters = new Array();
  pushAddress(event, "caller", BUYER);
  pushAddress(event, "recipient", RECIPIENT);
  pushAddress(event, "prizeToken", PRIZE);
  pushUnsigned(event, "prizeTokenId", 42);
  return event;
}

function createRefundsEnabledEvent(): RefundsEnabled {
  const event = changetype<RefundsEnabled>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  pushAddress(event, "finalizer", RECIPIENT);
  pushUnsigned(event, "remainingRefundLiability", 20_000_000);
  return event;
}

function createRefundRedemptionEvent(): TicketsRefunded {
  const event = changetype<TicketsRefunded>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(8);
  event.parameters = new Array();
  pushAddress(event, "owner", BUYER);
  pushUnsigned(event, "ticketQuantity", 1);
  pushUnsigned(event, "entryQuantity", 20);
  pushUnsigned(event, "amount", 20_000_000);
  pushUnsigned(event, "remainingRefundLiability", 0);
  return event;
}

function pushAddress(
  event: ethereum.Event,
  name: string,
  value: Address,
): void {
  event.parameters.push(
    new ethereum.EventParam(name, ethereum.Value.fromAddress(value)),
  );
}

function pushUnsigned(event: ethereum.Event, name: string, value: i32): void {
  pushBigInt(event, name, BigInt.fromI32(value));
}

function pushBigInt(event: ethereum.Event, name: string, value: BigInt): void {
  event.parameters.push(
    new ethereum.EventParam(name, ethereum.Value.fromUnsignedBigInt(value)),
  );
}
