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
  PrizeDeposited,
  RaffleResolved,
  RefundsEnabled,
  RefundTicketsRedeemed,
  TicketsPurchased,
  Transfer,
  WinningTicketRedeemed,
} from "../generated/templates/Raffle/Raffle";
import { handleRaffleCreated } from "../src/factory";
import {
  handleDrawRequested,
  handlePrizeDeposited,
  handleRaffleResolved,
  handleRefundsEnabled,
  handleRefundTicketsRedeemed,
  handleTicketsPurchased,
  handleTransfer,
  handleWinningTicketRedeemed,
} from "../src/raffle";
import { ticketId } from "../src/helpers";

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
const RECOVERY = Address.fromString(
  "0x7000000000000000000000000000000000000007",
);
const PRIZE = Address.fromString("0x8000000000000000000000000000000000000008");
const QUOTE = Address.fromString("0x9000000000000000000000000000000000000009");

describe("Raffle mappings", () => {
  afterEach(() => clearStore());

  test("constructor deployment indexes one immutable quote token and activates after escrow", () => {
    handleRaffleCreated(createRaffleCreatedEvent());
    assert.entityCount("Raffle", 1);
    assert.dataSourceCount("Raffle", 1);
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "status",
      "AWAITING_PRIZE",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "quoteToken",
      QUOTE.toHexString(),
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winnerCashLiability",
      "0",
    );

    handlePrizeDeposited(createPrizeDepositedEvent());
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "ACTIVE");
  });

  test("purchase and transfer keep the bearer owner current", () => {
    createActiveRaffle();
    handleTransfer(createTransferEvent(Address.zero(), BUYER, 1, 1));
    handleTransfer(createTransferEvent(Address.zero(), BUYER, 2, 2));
    handleTicketsPurchased(createPurchaseEvent());
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, 2, 4));

    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "grossSales", "2000000");
    assert.fieldEquals(
      "Ticket",
      ticketId(RAFFLE, BigInt.fromI32(2)),
      "currentOwner",
      RECIPIENT.toHexString(),
    );
    assert.fieldEquals(
      "Account",
      BUYER.toHexString(),
      "ticketsCurrentlyOwned",
      "1",
    );
    assert.fieldEquals(
      "Account",
      RECIPIENT.toHexString(),
      "ticketsCurrentlyOwned",
      "1",
    );
  });

  test("cash resolution records the 5 percent fee and burn redemption", () => {
    createPurchasedRaffle();
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, 2, 4));
    handleDrawRequested(createDrawRequestedEvent());
    handleRaffleResolved(createResolutionEvent(4));
    handleTransfer(createTransferEvent(RECIPIENT, Address.zero(), 2, 7));
    handleWinningTicketRedeemed(createWinningRedemptionEvent(4));

    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "CASH_WON");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "100000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winnerCashLiability",
      "0",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "winningTicketRedeemed",
      "true",
    );
    assert.fieldEquals(
      "Ticket",
      ticketId(RAFFLE, BigInt.fromI32(2)),
      "burned",
      "true",
    );
    assert.entityCount("WinningRedemption", 1);
  });

  test("NFT resolution defers proceeds until delivery", () => {
    createPurchasedRaffle();
    handleTransfer(createTransferEvent(BUYER, RECIPIENT, 2, 4));
    handleDrawRequested(createDrawRequestedEvent());
    handleRaffleResolved(createResolutionEvent(3));

    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "unsettledPot",
      "2000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalClaimableQuote",
      "0",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "0",
    );

    handleTransfer(createTransferEvent(RECIPIENT, Address.zero(), 2, 7));
    handleWinningTicketRedeemed(createWinningRedemptionEvent(3));
    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "unsettledPot", "0");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalClaimableQuote",
      "2000000",
    );
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "totalProtocolFees",
      "100000",
    );
  });

  test("NFT delivery timeout reclassifies the winner branch as refunds", () => {
    createPurchasedRaffle();
    handleDrawRequested(createDrawRequestedEvent());
    handleRaffleResolved(createResolutionEvent(3));
    handleRefundsEnabled(createRefundsEnabledEvent(true));

    assert.fieldEquals("Raffle", RAFFLE.toHexString(), "status", "REFUNDING");
    assert.fieldEquals(
      "Raffle",
      RAFFLE.toHexString(),
      "remainingRefundLiability",
      "2000000",
    );
    assert.fieldEquals("Protocol", FACTORY.toHexString(), "nftWonCount", "0");
    assert.fieldEquals(
      "Protocol",
      FACTORY.toHexString(),
      "refundingCount",
      "1",
    );
  });

  test("refund enable and batch redemption track only remaining liability", () => {
    createPurchasedRaffle();
    handleRefundsEnabled(createRefundsEnabledEvent(false));
    handleTransfer(createTransferEvent(BUYER, Address.zero(), 1, 6));
    handleTransfer(createTransferEvent(BUYER, Address.zero(), 2, 7));
    handleRefundTicketsRedeemed(createRefundRedemptionEvent());

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
      "2000000",
    );
    assert.entityCount("RefundEnable", 1);
    assert.entityCount("RefundRedemption", 1);
  });
});

function createActiveRaffle(): void {
  handleRaffleCreated(createRaffleCreatedEvent());
  handlePrizeDeposited(createPrizeDepositedEvent());
}

function createPurchasedRaffle(): void {
  createActiveRaffle();
  handleTransfer(createTransferEvent(Address.zero(), BUYER, 1, 1));
  handleTransfer(createTransferEvent(Address.zero(), BUYER, 2, 2));
  handleTicketsPurchased(createPurchaseEvent());
}

function createRaffleCreatedEvent(): RaffleCreated {
  const event = changetype<RaffleCreated>(newMockEvent());
  event.address = FACTORY;
  event.parameters = new Array();
  pushUnsigned(event, "raffleId", 1);
  pushAddress(event, "raffle", RAFFLE);
  pushAddress(event, "sponsor", SPONSOR);
  pushAddress(event, "sponsorPrizeRecoveryRecipient", RECOVERY);
  pushAddress(event, "prizeToken", PRIZE);
  pushUnsigned(event, "prizeTokenId", 42);
  pushAddress(event, "quoteToken", QUOTE);
  pushAddress(event, "protocolTreasury", TREASURY);
  pushUnsigned(event, "ticketPrice", 1_000_000);
  pushUnsigned(event, "minimumTickets", 100);
  pushUnsigned(event, "startTime", 1_000);
  pushUnsigned(event, "endTime", 2_000);
  pushUnsigned(event, "requestGraceDeadline", 3_000);
  event.parameters.push(
    new ethereum.EventParam(
      "metadataURI",
      ethereum.Value.fromString("ipfs://raffle"),
    ),
  );
  return event;
}

function createPrizeDepositedEvent(): PrizeDeposited {
  const event = changetype<PrizeDeposited>(newMockEvent());
  event.address = RAFFLE;
  event.parameters = new Array();
  pushAddress(event, "prizeToken", PRIZE);
  pushUnsigned(event, "prizeTokenId", 42);
  pushAddress(event, "sponsor", SPONSOR);
  return event;
}

function createTransferEvent(
  from: Address,
  to: Address,
  token: i32,
  log: i32,
): Transfer {
  const event = changetype<Transfer>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(log);
  event.parameters = new Array();
  pushAddress(event, "from", from);
  pushAddress(event, "to", to);
  pushUnsigned(event, "tokenId", token);
  return event;
}

function createPurchaseEvent(): TicketsPurchased {
  const event = changetype<TicketsPurchased>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(3);
  event.parameters = new Array();
  pushAddress(event, "buyer", BUYER);
  pushAddress(event, "recipient", BUYER);
  pushUnsigned(event, "quantity", 2);
  pushUnsigned(event, "firstTicketId", 1);
  pushUnsigned(event, "lastTicketId", 2);
  pushUnsigned(event, "grossAmount", 2_000_000);
  return event;
}

function createDrawRequestedEvent(): DrawRequested {
  const event = changetype<DrawRequested>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  pushUnsigned(event, "sequenceNumber", 1);
  pushAddress(event, "requester", BUYER);
  pushUnsigned(event, "fee", 1_000);
  pushUnsigned(event, "excessReturned", 0);
  pushUnsigned(event, "drawRequestedAt", 2_000);
  pushUnsigned(event, "callbackDeadline", 4_000);
  return event;
}

function createResolutionEvent(result: i32): RaffleResolved {
  const event = changetype<RaffleResolved>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(6);
  event.parameters = new Array();
  pushUnsigned(event, "sequenceNumber", 1);
  pushUnsigned(event, "winningTicketId", 2);
  pushUnsigned(event, "result", result);
  pushUnsigned(event, "protocolFee", 100_000);
  pushUnsigned(event, "winnerCashAmount", result == 4 ? 1_520_000 : 0);
  pushUnsigned(event, "sponsorCashAmount", result == 4 ? 380_000 : 1_900_000);
  return event;
}

function createWinningRedemptionEvent(result: i32): WinningTicketRedeemed {
  const event = changetype<WinningTicketRedeemed>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(8);
  event.parameters = new Array();
  pushUnsigned(event, "ticketId", 2);
  pushAddress(event, "owner", RECIPIENT);
  pushAddress(event, "to", RECIPIENT);
  pushUnsigned(event, "result", result);
  pushUnsigned(event, "cashAmount", result == 4 ? 1_520_000 : 0);
  return event;
}

function createRefundsEnabledEvent(
  requestWasAccepted: boolean,
): RefundsEnabled {
  const event = changetype<RefundsEnabled>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(5);
  event.parameters = new Array();
  pushAddress(event, "finalizer", RECIPIENT);
  event.parameters.push(
    new ethereum.EventParam(
      "requestWasAccepted",
      ethereum.Value.fromBoolean(requestWasAccepted),
    ),
  );
  pushUnsigned(event, "remainingRefundLiability", 2_000_000);
  return event;
}

function createRefundRedemptionEvent(): RefundTicketsRedeemed {
  const event = changetype<RefundTicketsRedeemed>(newMockEvent());
  event.address = RAFFLE;
  event.logIndex = BigInt.fromI32(8);
  event.parameters = new Array();
  pushAddress(event, "owner", BUYER);
  pushAddress(event, "to", BUYER);
  pushUnsigned(event, "quantity", 2);
  pushUnsigned(event, "amount", 2_000_000);
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
  event.parameters.push(
    new ethereum.EventParam(
      name,
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(value)),
    ),
  );
}
