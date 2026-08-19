import {
  ENTRY_PRICE,
  type Sandbox,
  type SandboxRaffle,
  type SandboxTicket,
} from "./engine";

/** The account the visitor plays as. Not a real wallet. */
export const PLAYER = "0x7a3f9c14b8e02d65a17c94f38b05e2d7c619a4f8";

const SPONSOR_A = "0x8f2c19a4b7d05e63f1a8c4d9e02b7f36a5c1d840";
const SPONSOR_B = "0x3c7e18d29f0a54b6c81d3f7a90e25b4c6d81f309";
const SPONSOR_C = "0x5a91c4e07b28d63f10a95c8d472e6b31f80c92a7";
const TREASURY = "0x4132a98c7051db4ef80637d29a1c65f9b30e82d7";

const OTHERS = [
  "0x6f13c98a025bd47e1a06c83f92b5d740e26a1c93",
  "0x2a74e08c15b93d6f0a8c25e71b4d930f6a1c85e2",
  "0x8d02a71c46e95b38f0c1a7d24e69b350f8a2c17d",
  "0x0e97b25a13c86d40f7a2c95e18b3d704f6c2a89b",
];

const MINUTE = 60_000;
const usdc = (dollars: bigint) => dollars * ENTRY_PRICE;
const eth = (value: string) =>
  BigInt(Math.round(Number(value) * 1e6)) * 10n ** 12n;

/** Builds one sequential ticket per purchase, never one object per entry. */
function ticketLedger(
  purchases: readonly { readonly owner: string; readonly entries: bigint }[],
): SandboxTicket[] {
  let lastEntry = 0n;
  return purchases.map(({ owner, entries }, index) => {
    const firstEntry = lastEntry + 1n;
    lastEntry += entries;
    return {
      id: BigInt(index + 1),
      owner,
      firstEntry,
      lastEntry,
    };
  });
}

function raffle(
  partial: Omit<
    SandboxRaffle,
    | "protocolTreasury"
    | "sponsorRecipient"
    | "status"
    | "totalEntries"
    | "grossSales"
    | "unsettledPot"
    | "remainingRefundLiability"
    | "winnerRecipient"
    | "winnerProceeds"
    | "sponsorProceeds"
    | "protocolFees"
    | "winningEntry"
    | "winningTicketId"
    | "settlementComplete"
    | "winnerRedeemed"
    | "prizeClaimed"
    | "drawRequestedAt"
    | "drawRequestedBy"
    | "callbackDeadline"
    | "resolvedAt"
  >,
): SandboxRaffle {
  const totalEntries = partial.tickets.reduce(
    (total, ticket) => total + ticket.lastEntry - ticket.firstEntry + 1n,
    0n,
  );
  const gross = totalEntries * ENTRY_PRICE;
  return {
    ...partial,
    protocolTreasury: TREASURY,
    sponsorRecipient: partial.sponsor,
    status: "ACTIVE",
    totalEntries,
    grossSales: gross,
    unsettledPot: gross,
    remainingRefundLiability: 0n,
    winnerRecipient: null,
    winnerProceeds: 0n,
    sponsorProceeds: 0n,
    protocolFees: 0n,
    winningEntry: null,
    winningTicketId: null,
    settlementComplete: false,
    winnerRedeemed: false,
    prizeClaimed: false,
    drawRequestedAt: null,
    drawRequestedBy: null,
    callbackDeadline: null,
    resolvedAt: null,
  };
}

/** A fresh compressed-time sandbox using six-decimal USDC and range tickets. */
export function createSandbox(now: number): Sandbox {
  return {
    player: PLAYER,
    wallet: {
      usdc: usdc(10_000n),
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
        prizeToken: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        prizeTokenId: "6873",
        prizeCollection: "Pudgy Penguins",
        prizeName: "Pudgy Penguin #6873",
        prizeImage: "/demo/pudgy-6873.png",
        reserveEntries: 120n,
        endTime: now - MINUTE,
        tickets: ticketLedger([
          { owner: PLAYER, entries: 20n },
          { owner: OTHERS[0]!, entries: 45n },
          { owner: OTHERS[1]!, entries: 65n },
        ]),
      }),
      raffle({
        id: "0xe38c05b1a7f2d964c0e83b17d5a29f460c81b7e3",
        factoryId: "37",
        sponsor: SPONSOR_B,
        prizeToken: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        prizeTokenId: "9605",
        prizeCollection: "Azuki",
        prizeName: "Azuki #9605",
        prizeImage: "/demo/azuki-9605.png",
        reserveEntries: 300n,
        endTime: now - 2 * MINUTE,
        tickets: ticketLedger([
          { owner: PLAYER, entries: 30n },
          { owner: OTHERS[2]!, entries: 25n },
          { owner: OTHERS[3]!, entries: 15n },
        ]),
      }),
      raffle({
        id: "0xb7d41e08c95a2367fd0b8e1a4c72d9350fa6b21c",
        factoryId: "40",
        sponsor: SPONSOR_B,
        prizeToken: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        prizeTokenId: "8817",
        prizeCollection: "Bored Ape Yacht Club",
        prizeName: "Bored Ape #8817",
        prizeImage: "/demo/bayc-8817.png",
        reserveEntries: 200n,
        endTime: now + 3 * MINUTE,
        tickets: ticketLedger([
          { owner: OTHERS[0]!, entries: 70n },
          { owner: OTHERS[1]!, entries: 55n },
        ]),
      }),
      raffle({
        id: "0xa1f0c2e5d4b39871c60a5f2e8d7b4c1902e6f3a8",
        factoryId: "41",
        sponsor: SPONSOR_A,
        prizeToken: "0xb47e3cd837ddf8e4c57f05d70ab865de6e193bbb",
        prizeTokenId: "3100",
        prizeCollection: "CryptoPunks",
        prizeName: "CryptoPunk #3100",
        prizeImage: "/demo/punk-3100.png",
        prizePixelated: true,
        reserveEntries: 500n,
        endTime: now + 9 * MINUTE,
        tickets: ticketLedger([
          { owner: OTHERS[2]!, entries: 125n },
          { owner: OTHERS[3]!, entries: 105n },
        ]),
      }),
      raffle({
        id: "0xc2e83b17f409a56d1c7b0e94a3d82f65017c9ba4",
        factoryId: "39",
        sponsor: SPONSOR_C,
        prizeToken: "0x5af0d9827e0c53e4799bb226655a1de152a425a5",
        prizeTokenId: "1618",
        prizeCollection: "Milady Maker",
        prizeName: "Milady #1618",
        prizeImage: "/demo/milady-1618.png",
        reserveEntries: 400n,
        endTime: now + 16 * MINUTE,
        tickets: ticketLedger([
          { owner: OTHERS[0]!, entries: 155n },
          { owner: OTHERS[1]!, entries: 145n },
        ]),
      }),
      // Sponsored by the player with zero sales, so early finalization can be tried.
      raffle({
        id: "0xf40b91c67d28a35e0b1c7f94a28d6350e91c4b7d",
        factoryId: "36",
        sponsor: PLAYER,
        prizeToken: "0x8a90cab2b38dba80c64b7734e58ee1db38b8992e",
        prizeTokenId: "6914",
        prizeCollection: "Doodles",
        prizeName: "Doodle #6914",
        prizeImage: "/demo/doodles-6914.png",
        reserveEntries: 250n,
        endTime: now + 12 * MINUTE,
        tickets: [],
      }),
    ],
  };
}
