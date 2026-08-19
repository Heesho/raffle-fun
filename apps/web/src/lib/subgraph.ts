import { GraphQLClient, gql } from "graphql-request";

import { webEnv } from "./env";

export interface IndexedRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
  readonly quoteToken: string;
  /** The factory fixes one verified six-decimal quote token for every raffle. */
  readonly quoteTokenVerified: true;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
  readonly prizeCollection?: string;
  readonly prizeName?: string;
  readonly prizeImage?: string;
  readonly prizePixelated?: boolean;
  readonly entryPrice: string;
  readonly reserveEntries: string;
  readonly endTime: string;
  readonly drawRequestDeadline: string;
  readonly callbackDeadline: string | null;
  readonly state: string;
  readonly outcome: string;
  readonly totalEntries: string;
  readonly ticketCount: string;
  readonly grossSales: string;
  readonly unsettledPot: string;
  readonly remainingRefundLiability: string;
  readonly winningEntry: string | null;
  readonly winningTicketId: string | null;
}

export interface IndexedTicketRange {
  readonly id: string;
  readonly ticketId: string;
  readonly firstEntry: string | null;
  readonly lastEntry: string | null;
  readonly entryCount: string | null;
}

export interface IndexedTicket extends IndexedTicketRange {
  readonly raffle: IndexedRaffle;
}

export interface IndexedActivity {
  readonly id: string;
  readonly kind: "PURCHASE" | "RESOLUTION" | "QUOTE_CLAIM" | "PRIZE_CLAIM";
  readonly raffle: string;
  readonly account: string | null;
  readonly amount: string | null;
  readonly quoteToken: string | null;
  readonly timestamp: string;
  readonly transactionHash: string;
}

const raffleFields = gql`
  fragment RaffleFields on Raffle {
    id
    factoryId
    sponsor {
      id
    }
    quoteToken
    prizeToken
    prizeTokenId
    entryPrice
    reserveEntries
    endTime
    drawRequestDeadline
    callbackDeadline
    status
    totalEntries
    ticketCount
    grossSales
    unsettledPot
    remainingRefundLiability
    winningEntry
    winningTicketId
  }
`;

const rafflesQuery = gql`
  ${raffleFields}
  query DiscoverRaffles($first: Int!, $skip: Int!) {
    raffles(
      first: $first
      skip: $skip
      orderBy: createdTimestamp
      orderDirection: desc
    ) {
      ...RaffleFields
    }
  }
`;

const profileQuery = gql`
  ${raffleFields}
  query ProfileRaffles($address: Bytes!, $first: Int!, $skip: Int!) {
    sponsored: raffles(
      first: $first
      skip: $skip
      orderBy: createdTimestamp
      orderDirection: desc
      where: { sponsor: $address }
    ) {
      ...RaffleFields
    }
    winnerClaims: raffles(
      first: $first
      skip: $skip
      orderBy: createdTimestamp
      orderDirection: desc
      where: { winnerRecipient: $address }
    ) {
      ...RaffleFields
    }
    positions: tickets(
      first: $first
      skip: $skip
      orderBy: id
      orderDirection: asc
      where: { currentOwner: $address, burned: false }
    ) {
      id
      ticketId
      firstEntry
      lastEntry
      entryCount
      raffle {
        ...RaffleFields
      }
    }
  }
`;

const ownedTicketRangesQuery = gql`
  query OwnedTicketRanges(
    $raffle: Bytes!
    $owner: Bytes!
    $first: Int!
    $skip: Int!
  ) {
    tickets(
      first: $first
      skip: $skip
      where: { raffle: $raffle, currentOwner: $owner, burned: false }
    ) {
      id
      ticketId
      firstEntry
      lastEntry
      entryCount
    }
  }
`;

const activityQuery = gql`
  query ProtocolActivity($first: Int!) {
    purchases(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
      }
      buyer {
        id
      }
      grossAmount
      timestamp
      transactionHash
    }
    resolutions(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
      }
      timestamp
      transactionHash
    }
    proceedsReleases(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
      }
      recipient {
        id
      }
      amount
      timestamp
      transactionHash
    }
    sponsorPrizeReleases(
      first: $first
      orderBy: timestamp
      orderDirection: desc
    ) {
      id
      raffle {
        id
        quoteToken
      }
      recipient {
        id
      }
      timestamp
      transactionHash
    }
    winningRedemptions(
      first: $first
      orderBy: timestamp
      orderDirection: desc
    ) {
      id
      raffle {
        id
        quoteToken
      }
      winner {
        id
      }
      cashAmount
      timestamp
      transactionHash
    }
  }
`;

function client(): GraphQLClient {
  if (webEnv.NEXT_PUBLIC_SUBGRAPH_URL === undefined) {
    throw new Error("No subgraph endpoint is configured for this network.");
  }
  return new GraphQLClient(webEnv.NEXT_PUBLIC_SUBGRAPH_URL);
}

export function isSubgraphConfigured(): boolean {
  return webEnv.NEXT_PUBLIC_SUBGRAPH_URL !== undefined;
}

interface IndexedRaffleRow {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: { readonly id: string };
  readonly quoteToken: string;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
  readonly entryPrice: string;
  readonly reserveEntries: string;
  readonly endTime: string;
  readonly drawRequestDeadline: string;
  readonly callbackDeadline: string | null;
  readonly status: string;
  readonly totalEntries: string;
  readonly ticketCount: string;
  readonly grossSales: string;
  readonly unsettledPot: string;
  readonly remainingRefundLiability: string;
  readonly winningEntry: string | null;
  readonly winningTicketId: string | null;
}

function normalizeRaffle(row: IndexedRaffleRow): IndexedRaffle {
  const { sponsor, status, ...raffle } = row;
  return {
    ...raffle,
    sponsor: sponsor.id,
    quoteTokenVerified: true,
    state: status,
    outcome: status === "NFT_WON" || status === "CASH_WON" ? status : "NONE",
  };
}

export async function fetchRaffles(): Promise<readonly IndexedRaffle[]> {
  const data = await client().request<{ raffles: IndexedRaffleRow[] }>(
    rafflesQuery,
    { first: 100, skip: 0 },
  );
  return data.raffles.map(normalizeRaffle);
}

export async function fetchProfileRaffles(address: `0x${string}`): Promise<{
  readonly sponsored: readonly IndexedRaffle[];
  readonly positions: readonly IndexedRaffle[];
  readonly tickets: readonly IndexedTicket[];
}> {
  type ProfilePage = {
    sponsored: IndexedRaffleRow[];
    winnerClaims: IndexedRaffleRow[];
    positions: Array<{
      id: string;
      raffle: IndexedRaffleRow;
      ticketId: string;
      firstEntry: string | null;
      lastEntry: string | null;
      entryCount: string | null;
    }>;
  };

  const pageSize = 500;
  const sponsored: IndexedRaffleRow[] = [];
  const winnerClaims: IndexedRaffleRow[] = [];
  const positions: ProfilePage["positions"] = [];
  let skip = 0;
  for (;;) {
    const page = await client().request<ProfilePage>(profileQuery, {
      address: address.toLowerCase(),
      first: pageSize,
      skip,
    });
    sponsored.push(...page.sponsored);
    winnerClaims.push(...page.winnerClaims);
    positions.push(...page.positions);
    if (
      page.sponsored.length < pageSize &&
      page.winnerClaims.length < pageSize &&
      page.positions.length < pageSize
    ) {
      break;
    }
    skip += pageSize;
  }

  const tickets = positions.map(({ raffle, ...ticket }) => ({
    ...ticket,
    raffle: normalizeRaffle(raffle),
  }));
  return {
    sponsored: sponsored.map(normalizeRaffle),
    positions: [
      ...new Map(
        [
          ...tickets.map((ticket) => ticket.raffle),
          ...winnerClaims.map(normalizeRaffle),
        ].map((raffle) => [raffle.id, raffle]),
      ).values(),
    ],
    tickets,
  };
}

/**
 * Index-assisted ownership discovery for one raffle. Redemption still checks
 * `ownerOf` directly; this function only discovers ticket IDs and stored ranges.
 * Pagination is by ticket, never by entry.
 */
export async function fetchOwnedTicketRanges(
  raffle: `0x${string}`,
  owner: `0x${string}`,
): Promise<readonly IndexedTicketRange[]> {
  const pageSize = 500;
  const tickets: IndexedTicketRange[] = [];
  let skip = 0;
  for (;;) {
    const page = await client().request<{
      tickets: IndexedTicketRange[];
    }>(ownedTicketRangesQuery, {
      raffle: raffle.toLowerCase(),
      owner: owner.toLowerCase(),
      first: pageSize,
      skip,
    });
    tickets.push(...page.tickets);
    if (page.tickets.length < pageSize) return tickets;
    skip += page.tickets.length;
  }
}

export async function fetchActivity(): Promise<readonly IndexedActivity[]> {
  type EventRow = {
    id: string;
    raffle: { id: string; quoteToken: string };
    timestamp: string;
    transactionHash: string;
    buyer?: { id: string };
    recipient?: { id: string };
    winner?: { id: string };
    grossAmount?: string;
    amount?: string;
    cashAmount?: string;
  };
  const data = await client().request<{
    purchases: EventRow[];
    resolutions: EventRow[];
    proceedsReleases: EventRow[];
    sponsorPrizeReleases: EventRow[];
    winningRedemptions: EventRow[];
  }>(activityQuery, { first: 50 });

  const normalize = (
    rows: EventRow[],
    kind: IndexedActivity["kind"],
  ): IndexedActivity[] =>
    rows.map((row) => ({
      id: row.id,
      kind,
      raffle: row.raffle.id,
      account: row.buyer?.id ?? row.recipient?.id ?? row.winner?.id ?? null,
      amount: row.grossAmount ?? row.amount ?? null,
      quoteToken:
        (row.grossAmount ?? row.amount) === undefined
          ? null
          : row.raffle.quoteToken,
      timestamp: row.timestamp,
      transactionHash: row.transactionHash,
    }));

  return [
    ...normalize(data.purchases, "PURCHASE"),
    ...normalize(data.resolutions, "RESOLUTION"),
    ...normalize(data.proceedsReleases, "QUOTE_CLAIM"),
    ...normalize(data.sponsorPrizeReleases, "PRIZE_CLAIM"),
    ...data.winningRedemptions.map((row): IndexedActivity => {
      const cashAmount = row.cashAmount ?? "0";
      const isCash = cashAmount !== "0";
      return {
        id: row.id,
        kind: isCash ? "QUOTE_CLAIM" : "PRIZE_CLAIM",
        raffle: row.raffle.id,
        account: row.winner?.id ?? null,
        amount: isCash ? cashAmount : null,
        quoteToken: isCash ? row.raffle.quoteToken : null,
        timestamp: row.timestamp,
        transactionHash: row.transactionHash,
      };
    }),
  ]
    .sort((a, b) => Number(b.timestamp) - Number(a.timestamp))
    .slice(0, 100);
}
