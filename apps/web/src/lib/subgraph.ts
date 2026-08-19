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
  query ProfileRaffles($address: Bytes!, $first: Int!) {
    sponsored: raffles(
      first: $first
      orderBy: createdTimestamp
      orderDirection: desc
      where: { sponsor: $address }
    ) {
      ...RaffleFields
    }
    winnerClaims: raffles(
      first: $first
      orderBy: createdTimestamp
      orderDirection: desc
      where: { winnerRecipient: $address }
    ) {
      ...RaffleFields
    }
    positions: tickets(
      first: $first
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
    winnerPrizeReleases(
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
  const data = await client().request<{
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
  }>(profileQuery, { address: address.toLowerCase(), first: 100 });
  const tickets = data.positions.map(({ raffle, ...ticket }) => ({
    ...ticket,
    raffle: normalizeRaffle(raffle),
  }));
  return {
    sponsored: data.sponsored.map(normalizeRaffle),
    positions: [
      ...new Map(
        [
          ...tickets.map((ticket) => ticket.raffle),
          ...data.winnerClaims.map(normalizeRaffle),
        ].map((raffle) => [raffle.id, raffle]),
      ).values(),
    ],
    tickets,
  };
}

/**
 * Index-assisted ownership discovery for one raffle. Settlement still checks
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
    grossAmount?: string;
    amount?: string;
  };
  const data = await client().request<{
    purchases: EventRow[];
    resolutions: EventRow[];
    proceedsReleases: EventRow[];
    sponsorPrizeReleases: EventRow[];
    winnerPrizeReleases: EventRow[];
  }>(activityQuery, { first: 50 });

  const normalize = (
    rows: EventRow[],
    kind: IndexedActivity["kind"],
  ): IndexedActivity[] =>
    rows.map((row) => ({
      id: row.id,
      kind,
      raffle: row.raffle.id,
      account: row.buyer?.id ?? row.recipient?.id ?? null,
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
    ...normalize(data.winnerPrizeReleases, "PRIZE_CLAIM"),
  ]
    .sort((a, b) => Number(b.timestamp) - Number(a.timestamp))
    .slice(0, 100);
}
