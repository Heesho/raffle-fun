#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const constantsPath = resolve(
  root,
  "packages/contracts/src/libraries/RaffleConstants.sol",
);
const interfacePath = resolve(
  root,
  "packages/contracts/src/interfaces/IRaffle.sol",
);
const raffleArtifactPath = resolve(
  root,
  "packages/contracts/artifacts/src/Raffle.sol/Raffle.json",
);
const factoryArtifactPath = resolve(
  root,
  "packages/contracts/artifacts/src/RaffleFactory.sol/RaffleFactory.json",
);
const lensArtifactPath = resolve(
  root,
  "packages/contracts/artifacts/src/RaffleLens.sol/RaffleLens.json",
);
const outputPath = resolve(
  root,
  "docs/whitepaper/build/protocol-facts.generated.json",
);

function fail(message) {
  throw new Error(`whitepaper fact validation failed: ${message}`);
}

function parseLiteral(raw) {
  const value = raw.trim().replaceAll("_", "");
  const duration = value.match(/^(\d+)\s+(seconds|minutes|hours|days|weeks)$/);
  if (duration) {
    const multipliers = {
      seconds: 1,
      minutes: 60,
      hours: 3_600,
      days: 86_400,
      weeks: 604_800,
    };
    return Number(duration[1]) * multipliers[duration[2]];
  }
  if (!/^\d+$/.test(value)) fail(`unsupported Solidity literal ${raw}`);
  return Number(value);
}

function parseConstants(source) {
  const values = {};
  const pattern =
    /uint256\s+internal\s+constant\s+([A-Z0-9_]+)\s*=\s*([^;]+);/g;
  for (const match of source.matchAll(pattern)) {
    values[match[1]] = parseLiteral(match[2]);
  }
  return values;
}

function parseEnum(source, name) {
  const match = source.match(new RegExp(`enum\\s+${name}\\s*\\{([^}]+)\\}`));
  if (!match) fail(`enum ${name} not found`);
  return match[1]
    .split(",")
    .map((item) => item.replace(/\/\/.*$/gm, "").trim())
    .filter(Boolean);
}

function readArtifact(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function abiNames(artifact, type) {
  return artifact.abi
    .filter((item) => item.type === type)
    .map((item) => item.name)
    .filter(Boolean);
}

function requireNames(actual, expected, label) {
  const set = new Set(actual);
  const missing = expected.filter((name) => !set.has(name));
  if (missing.length) fail(`${label} is missing ${missing.join(", ")}`);
}

function formatUnits(raw, decimals = 6) {
  const value = BigInt(raw);
  const base = 10n ** BigInt(decimals);
  const whole = value / base;
  const fraction = (value % base).toString().padStart(decimals, "0");
  return `${whole}.${fraction}`;
}

function formatDisplayUnits(raw, decimals = 6, displayDecimals = 2) {
  const exact = formatUnits(raw, decimals);
  const [whole, fraction] = exact.split(".");
  return `${Number(whole).toLocaleString("en-US")}.${fraction.slice(0, displayDecimals)}`;
}

function percent(bps) {
  return `${bps / 100}%`;
}

function example({ tickets, priceRaw, feeBps, cashWinnerBps }) {
  const gross = BigInt(tickets) * BigInt(priceRaw);
  const fee = (gross * BigInt(feeBps)) / 10_000n;
  const distributable = gross - fee;
  const winnerCash = (distributable * BigInt(cashWinnerBps)) / 10_000n;
  const sponsorCash = distributable - winnerCash;
  return {
    tickets,
    ticketPriceRaw: String(priceRaw),
    grossRaw: gross.toString(),
    feeRaw: fee.toString(),
    distributableRaw: distributable.toString(),
    winnerCashRaw: winnerCash.toString(),
    sponsorCashRaw: sponsorCash.toString(),
    ticketPrice: formatDisplayUnits(priceRaw),
    gross: formatDisplayUnits(gross),
    fee: formatDisplayUnits(fee),
    distributable: formatDisplayUnits(distributable),
    winnerCash: formatDisplayUnits(winnerCash),
    sponsorCash: formatDisplayUnits(sponsorCash),
  };
}

export function buildFacts() {
  const constantsSource = readFileSync(constantsPath, "utf8");
  const interfaceSource = readFileSync(interfacePath, "utf8");
  const constants = parseConstants(constantsSource);
  const states = parseEnum(interfaceSource, "Status");
  const protocolOwnedClaims = parseEnum(interfaceSource, "ProtocolOwnedClaim");
  const raffleArtifact = readArtifact(raffleArtifactPath);
  const factoryArtifact = readArtifact(factoryArtifactPath);
  const lensArtifact = readArtifact(lensArtifactPath);

  const requiredConstants = [
    "BPS",
    "PROTOCOL_FEE_BPS",
    "CASH_WINNER_BPS",
    "MAX_TICKETS_PER_PURCHASE",
    "MAX_REFUND_REDEMPTION_BATCH_SIZE",
    "MAX_START_DELAY",
    "MAX_SALE_DURATION",
    "DRAW_REQUEST_GRACE_PERIOD",
    "DRAW_CALLBACK_TIMEOUT",
    "MAX_METADATA_URI_LENGTH",
  ];
  requireNames(Object.keys(constants), requiredConstants, "RaffleConstants");

  const raffleFunctions = abiNames(raffleArtifact, "function");
  requireNames(
    raffleFunctions,
    [
      "buyTickets",
      "closeEmptyRaffle",
      "requestDraw",
      "enableRefunds",
      "redeemWinningTicket",
      "redeemRefundTickets",
      "recoverProtocolOwnedClaim",
      "claimQuote",
      "claimQuoteFor",
      "claimSponsorPrize",
      "accountedQuoteBalance",
    ],
    "compiled Raffle ABI",
  );
  requireNames(
    abiNames(factoryArtifact, "function"),
    [
      "createRaffle",
      "setProtocolTreasury",
      "setCreationPaused",
      "transferOwnership",
      "acceptOwnership",
      "quoteToken",
      "entropy",
      "callbackGasLimit",
    ],
    "compiled RaffleFactory ABI",
  );
  requireNames(
    abiNames(lensArtifact, "function"),
    ["getRaffleState", "getRaffleStates", "MAX_BATCH_SIZE", "factory"],
    "compiled RaffleLens ABI",
  );

  const expectedStates = [
    "AwaitingPrize",
    "Active",
    "Drawing",
    "NftWon",
    "CashWon",
    "Refunding",
    "Closed",
  ];
  if (JSON.stringify(states) !== JSON.stringify(expectedStates)) {
    fail(`unexpected status enum ${states.join(", ")}`);
  }

  const head = execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: root,
    encoding: "utf8",
  }).trim();

  const ticketPriceRaw = 10_000_000;
  const thresholdMet = example({
    tickets: 120,
    priceRaw: ticketPriceRaw,
    feeBps: constants.PROTOCOL_FEE_BPS,
    cashWinnerBps: constants.CASH_WINNER_BPS,
  });
  const cashFallback = example({
    tickets: 80,
    priceRaw: ticketPriceRaw,
    feeBps: constants.PROTOCOL_FEE_BPS,
    cashWinnerBps: constants.CASH_WINNER_BPS,
  });

  return {
    generatedAt: new Date().toISOString(),
    document: {
      version: "2.0",
      publicationDate: "August 10, 2026",
      reviewedRepositoryCommit: head,
      reviewedContractCommit: head,
      auditBaselineCommit: "a2120f5e163dc3641d9864773febbfedca047edb",
      auditBaselinePatchFingerprint: "55589ce1fce0bd5579e60df747796575df9b0d96",
      finalReviewedImplementationCommit: head,
      targetNetwork: "Base (chain ID 8453)",
      deploymentStatus: "Not deployed and not authorized for user funds",
      testnetDeploymentStatus: "No verified Base Sepolia deployment record",
      securityReviewStatus: "Internal adversarial review only",
      independentAuditStatus: "Not completed",
      legalReviewStatus: "Not completed",
    },
    architecture: {
      deployment: "ordinary constructor CREATE",
      upgradeable: false,
      clone: false,
      quoteTokenModel:
        "one immutable factory-wide exact-transfer, non-rebasing USDC deployment",
      ticketsTransferableInAllStates: true,
      ticketTransferFreeze: false,
      refundModel:
        "current owners burn refundable bearer tickets for exact payment",
      nativeOverpaymentModel: "immediate return or complete request rollback",
      lensBatchSize: 64,
    },
    constants,
    display: {
      protocolFeePercent: percent(constants.PROTOCOL_FEE_BPS),
      cashWinnerPercent: percent(constants.CASH_WINNER_BPS),
      maxStartDelayDays: constants.MAX_START_DELAY / 86_400,
      maxSaleDurationDays: constants.MAX_SALE_DURATION / 86_400,
      requestGraceDays: constants.DRAW_REQUEST_GRACE_PERIOD / 86_400,
      callbackTimeoutDays: constants.DRAW_CALLBACK_TIMEOUT / 86_400,
    },
    states,
    protocolOwnedClaims,
    compiled: {
      raffleFunctions,
      raffleEvents: abiNames(raffleArtifact, "event"),
      factoryFunctions: abiNames(factoryArtifact, "function"),
      lensFunctions: abiNames(lensArtifact, "function"),
    },
    examples: {
      decimals: 6,
      thresholdMet,
      cashFallback,
      failedDraw: {
        tickets: 80,
        refundPerTicketRaw: String(ticketPriceRaw),
        totalRefundsRaw: String(BigInt(80) * BigInt(ticketPriceRaw)),
        refundPerTicket: formatDisplayUnits(ticketPriceRaw),
        totalRefunds: formatDisplayUnits(BigInt(80) * BigInt(ticketPriceRaw)),
      },
    },
  };
}

export function writeFacts() {
  const facts = buildFacts();
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(facts, null, 2)}\n`);
  return { facts, outputPath };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { facts, outputPath: written } = writeFacts();
  console.log(
    `Validated ${Object.keys(facts.constants).length} Solidity constants, ${facts.states.length} states, and compiled ABIs.`,
  );
  console.log(`Wrote ${written}`);
}
