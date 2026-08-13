import {
  DRAW_REQUEST_GRACE_MS,
  type Sandbox,
  type SandboxRaffle,
  type SandboxTicket,
} from "./engine";

/** The account the visitor plays as. Not a real wallet. */
export const PLAYER = "0x7a3f9c14b8e02d65a17c94f38b05e2d7c619a4f8";

const SPONSOR_A = "0x8f2c19a4b7d05e63f1a8c4d9e02b7f36a5c1d840";
const SPONSOR_B = "0x3c7e18d29f0a54b6c81d3f7a90e25b4c6d81f309";
const SPONSOR_C = "0x5a91c4e07b28d63f10a95c8d472e6b31f80c92a7";

const OTHERS = [
  "0x6f13c98a025bd47e1a06c83f92b5d740e26a1c93",
  "0x2a74e08c15b93d6f0a8c25e71b4d930f6a1c85e2",
  "0x8d02a71c46e95b38f0c1a7d24e69b350f8a2c17d",
  "0x0e97b25a13c86d40f7a2c95e18b3d704f6c2a89b",
];

const MINUTE = 60_000;
const eth = (value: string) =>
  BigInt(Math.round(Number(value) * 1e6)) * 10n ** 12n;

/**
 * Ticket ledger for a pre-seeded raffle: `mine` tickets belong to the player,
 * the rest are spread across other accounts so a draw is genuinely uncertain.
 */
function ledger(total: number, mine: number): SandboxTicket[] {
  return Array.from({ length: total }, (_, index) => ({
    id: index + 1,
    owner: index < mine ? PLAYER : OTHERS[index % OTHERS.length]!,
  }));
}

function raffle(
  partial: Omit<
    SandboxRaffle,
    | "status"
    | "grossSales"
    | "unsettledPot"
    | "requestGraceDeadline"
    | "remainingRefundLiability"
    | "winnerCashLiability"
    | "winningTicketId"
    | "prizeClaimed"
    | "claimableQuote"
    | "drawRequestedAt"
    | "drawRequestedBy"
    | "callbackDeadline"
    | "resolvedAt"
    | "nftRedemptionDeadline"
  >,
): SandboxRaffle {
  const gross = partial.ticketPrice * BigInt(partial.tickets.length);
  return {
    ...partial,
    status: "ACTIVE",
    grossSales: gross,
    unsettledPot: gross,
    requestGraceDeadline: partial.endTime + DRAW_REQUEST_GRACE_MS,
    remainingRefundLiability: 0n,
    winnerCashLiability: 0n,
    winningTicketId: null,
    prizeClaimed: false,
    claimableQuote: {},
    drawRequestedAt: null,
    drawRequestedBy: null,
    callbackDeadline: null,
    resolvedAt: null,
    nftRedemptionDeadline: null,
  };
}

/**
 * A fresh sandbox.
 *
 * Sale windows are compressed to minutes so a visitor can watch one close,
 * request the draw and claim inside a single sitting. Two raffles are seeded
 * already past their deadline so settlement can be tried immediately.
 */
export function createSandbox(now: number): Sandbox {
  return {
    player: PLAYER,
    wallet: {
      weth: eth("5"),
      eth: eth("0.05"),
      nfts: [],
    },
    seed: (now ^ 0x5f37_2a1b) >>> 0,
    log: [],
    raffles: [
      raffle({
        id: "0xd91a7f26b0c84e35a1f7d0b92c46e8137fa05d2b",
        factoryId: "38",
        sponsor: SPONSOR_A,
        sponsorPrizeRecoveryRecipient: SPONSOR_A,
        prizeToken: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        prizeTokenId: "6873",
        prizeCollection: "Pudgy Penguins",
        prizeName: "Pudgy Penguin #6873",
        prizeImage: "/demo/pudgy-6873.png",
        ticketPrice: eth("0.02"),
        minimumTickets: 12,
        startTime: now - 40 * MINUTE,
        endTime: now - MINUTE,
        tickets: ledger(18, 5),
      }),
      raffle({
        id: "0xe38c05b1a7f2d964c0e83b17d5a29f460c81b7e3",
        factoryId: "37",
        sponsor: SPONSOR_B,
        sponsorPrizeRecoveryRecipient: SPONSOR_B,
        prizeToken: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        prizeTokenId: "9605",
        prizeCollection: "Azuki",
        prizeName: "Azuki #9605",
        prizeImage: "/demo/azuki-9605.png",
        ticketPrice: eth("0.03"),
        minimumTickets: 30,
        startTime: now - 60 * MINUTE,
        endTime: now - 2 * MINUTE,
        tickets: ledger(7, 3),
      }),
      raffle({
        id: "0xb7d41e08c95a2367fd0b8e1a4c72d9350fa6b21c",
        factoryId: "40",
        sponsor: SPONSOR_B,
        sponsorPrizeRecoveryRecipient: SPONSOR_B,
        prizeToken: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        prizeTokenId: "8817",
        prizeCollection: "Bored Ape Yacht Club",
        prizeName: "Bored Ape #8817",
        prizeImage: "/demo/bayc-8817.png",
        ticketPrice: eth("0.05"),
        minimumTickets: 20,
        startTime: now - 20 * MINUTE,
        endTime: now + 3 * MINUTE,
        tickets: ledger(14, 0),
      }),
      raffle({
        id: "0xa1f0c2e5d4b39871c60a5f2e8d7b4c1902e6f3a8",
        factoryId: "41",
        sponsor: SPONSOR_A,
        sponsorPrizeRecoveryRecipient: SPONSOR_A,
        prizeToken: "0xb47e3cd837ddf8e4c57f05d70ab865de6e193bbb",
        prizeTokenId: "3100",
        prizeCollection: "CryptoPunks",
        prizeName: "CryptoPunk #3100",
        prizeImage: "/demo/punk-3100.png",
        prizePixelated: true,
        ticketPrice: eth("0.04"),
        minimumTickets: 50,
        startTime: now - 5 * MINUTE,
        endTime: now + 9 * MINUTE,
        tickets: ledger(23, 0),
      }),
      raffle({
        id: "0xc2e83b17f409a56d1c7b0e94a3d82f65017c9ba4",
        factoryId: "39",
        sponsor: SPONSOR_C,
        sponsorPrizeRecoveryRecipient: SPONSOR_C,
        prizeToken: "0x5af0d9827e0c53e4799bb226655a1de152a425a5",
        prizeTokenId: "1618",
        prizeCollection: "Milady Maker",
        prizeName: "Milady #1618",
        prizeImage: "/demo/milady-1618.png",
        ticketPrice: eth("0.01"),
        minimumTickets: 40,
        startTime: now - 12 * MINUTE,
        endTime: now + 16 * MINUTE,
        tickets: ledger(31, 0),
      }),
      // Sponsored by the player with zero sales, so cancelling can be tried.
      raffle({
        id: "0xf40b91c67d28a35e0b1c7f94a28d6350e91c4b7d",
        factoryId: "36",
        sponsor: PLAYER,
        sponsorPrizeRecoveryRecipient: PLAYER,
        prizeToken: "0x8a90cab2b38dba80c64b7734e58ee1db38b8992e",
        prizeTokenId: "6914",
        prizeCollection: "Doodles",
        prizeName: "Doodle #6914",
        prizeImage: "/demo/doodles-6914.png",
        ticketPrice: eth("0.02"),
        minimumTickets: 25,
        startTime: now - 2 * MINUTE,
        endTime: now + 12 * MINUTE,
        tickets: [],
      }),
    ],
  };
}
