import { GraphQLClient, gql } from "graphql-request";

import { webEnv } from "./env";

export interface IndexedRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
  readonly quoteToken: string;
  /** Retained for shared cards; the factory-wide token is always canonical. */
  readonly quoteTokenVerified: true;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
  readonly prizeCollection?: string;
  readonly prizeName?: string;
  readonly prizeImage?: string;
  readonly prizePixelated?: boolean;
  readonly metadataURI: string;
  readonly ticketPrice: string;
  readonly minimumTickets: string;
  readonly startTime: string;
  readonly endTime: string;
  readonly state: string;
  readonly outcome: string;
  readonly totalTickets: string;
  readonly grossSales: string;
  readonly unsettledPot: string;
  readonly winner: string | null;
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
    sponsor
    quoteToken
    prizeToken
    prizeTokenId
    metadataURI
    ticketPrice
    minimumTickets
    startTime
    endTime
    status
    totalTickets
    grossSales
    unsettledPot
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
    positions: raffleAccounts(
      first: $first
      where: { account: $address, ticketsCurrentlyOwned_gt: "0" }
    ) {
      raffle {
        ...RaffleFields
      }
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
    quoteClaims(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
      }
      account {
        id
      }
      amount
      timestamp
      transactionHash
    }
    sponsorPrizeClaims(
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

type IndexedRaffleRow = Omit<
  IndexedRaffle,
  "quoteTokenVerified" | "state" | "outcome" | "winner"
> & { readonly status: string };

function normalizeRaffle(row: IndexedRaffleRow): IndexedRaffle {
  const { status, ...raffle } = row;
  return {
    ...raffle,
    quoteTokenVerified: true,
    state: status,
    outcome:
      status === "NFT_WON" || status === "CASH_WON" || status === "CLOSED"
        ? status
        : "NONE",
    winner: null,
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
}> {
  const data = await client().request<{
    sponsored: IndexedRaffleRow[];
    positions: { raffle: IndexedRaffleRow }[];
  }>(profileQuery, { address: address.toLowerCase(), first: 100 });
  return {
    sponsored: data.sponsored.map(normalizeRaffle),
    positions: data.positions.map(({ raffle }) => normalizeRaffle(raffle)),
  };
}

export async function fetchActivity(): Promise<readonly IndexedActivity[]> {
  type EventRow = {
    id: string;
    raffle: { id: string; quoteToken: string };
    timestamp: string;
    transactionHash: string;
    buyer?: { id: string };
    account?: { id: string };
    recipient?: { id: string };
    grossAmount?: string;
    amount?: string;
  };
  const data = await client().request<{
    purchases: EventRow[];
    resolutions: EventRow[];
    quoteClaims: EventRow[];
    sponsorPrizeClaims: EventRow[];
  }>(activityQuery, { first: 50 });

  const normalize = (
    rows: EventRow[],
    kind: IndexedActivity["kind"],
  ): IndexedActivity[] =>
    rows.map((row) => ({
      id: row.id,
      kind,
      raffle: row.raffle.id,
      account: row.buyer?.id ?? row.account?.id ?? row.recipient?.id ?? null,
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
    ...normalize(data.quoteClaims, "QUOTE_CLAIM"),
    ...normalize(data.sponsorPrizeClaims, "PRIZE_CLAIM"),
  ]
    .sort((a, b) => Number(b.timestamp) - Number(a.timestamp))
    .slice(0, 100);
}
