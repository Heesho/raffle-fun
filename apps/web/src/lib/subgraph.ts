import { GraphQLClient, gql } from "graphql-request";

import { webEnv } from "./env";

export interface IndexedRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
  readonly quoteToken: string;
  readonly quoteTokenVerified: boolean;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
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

const rafflesQuery = gql`
  query DiscoverRaffles($first: Int!, $skip: Int!) {
    raffles(
      first: $first
      skip: $skip
      orderBy: createdTimestamp
      orderDirection: desc
    ) {
      id
      factoryId
      sponsor
      quoteToken
      quoteTokenStats {
        verified
      }
      prizeToken
      prizeTokenId
      metadataURI
      ticketPrice
      minimumTickets
      startTime
      endTime
      state
      outcome
      totalTickets
      grossSales
      unsettledPot
      winner
    }
  }
`;

const profileQuery = gql`
  query ProfileRaffles($address: Bytes!, $first: Int!) {
    sponsored: raffles(
      first: $first
      orderBy: createdTimestamp
      orderDirection: desc
      where: { sponsor: $address }
    ) {
      id
      factoryId
      sponsor
      quoteToken
      quoteTokenStats {
        verified
      }
      prizeToken
      prizeTokenId
      metadataURI
      ticketPrice
      minimumTickets
      startTime
      endTime
      state
      outcome
      totalTickets
      grossSales
      unsettledPot
      winner
    }
    positions: raffleAccounts(
      first: $first
      where: { account: $address, ticketsCurrentlyOwned_gt: "0" }
    ) {
      raffle {
        id
        factoryId
        sponsor
        quoteToken
        quoteTokenStats {
          verified
        }
        prizeToken
        prizeTokenId
        metadataURI
        ticketPrice
        minimumTickets
        startTime
        endTime
        state
        outcome
        totalTickets
        grossSales
        unsettledPot
        winner
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
        quoteTokenStats {
          verified
        }
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
        quoteTokenStats {
          verified
        }
      }
      winner {
        id
      }
      timestamp
      transactionHash
    }
    quoteClaims(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
        quoteTokenStats {
          verified
        }
      }
      account {
        id
      }
      amount
      timestamp
      transactionHash
    }
    prizeClaims(first: $first, orderBy: timestamp, orderDirection: desc) {
      id
      raffle {
        id
        quoteToken
        quoteTokenStats {
          verified
        }
      }
      claimant {
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

type IndexedRaffleRow = Omit<IndexedRaffle, "quoteTokenVerified"> & {
  readonly quoteTokenStats: { readonly verified: boolean };
};

function normalizeRaffle(row: IndexedRaffleRow): IndexedRaffle {
  const { quoteTokenStats, ...raffle } = row;
  return { ...raffle, quoteTokenVerified: quoteTokenStats.verified };
}

export async function fetchRaffles(): Promise<readonly IndexedRaffle[]> {
  const data = await client().request<{ raffles: IndexedRaffleRow[] }>(
    rafflesQuery,
    {
      first: 100,
      skip: 0,
    },
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
    raffle: {
      id: string;
      quoteToken: string;
      quoteTokenStats: { verified: boolean };
    };
    timestamp: string;
    transactionHash: string;
  };
  type AccountEventRow = EventRow & {
    buyer?: { id: string };
    winner?: { id: string };
    account?: { id: string };
    claimant?: { id: string };
    grossAmount?: string;
    amount?: string;
  };
  const data = await client().request<{
    purchases: AccountEventRow[];
    resolutions: AccountEventRow[];
    quoteClaims: AccountEventRow[];
    prizeClaims: AccountEventRow[];
  }>(activityQuery, { first: 50 });

  const normalize = (
    rows: AccountEventRow[],
    kind: IndexedActivity["kind"],
  ): IndexedActivity[] =>
    rows
      .filter((row) => row.raffle.quoteTokenStats.verified)
      .map((row) => ({
        id: row.id,
        kind,
        raffle: row.raffle.id,
        account:
          row.buyer?.id ??
          row.winner?.id ??
          row.account?.id ??
          row.claimant?.id ??
          null,
        amount: row.grossAmount ?? row.amount ?? null,
        quoteToken:
          (row.grossAmount ?? row.amount) !== undefined
            ? row.raffle.quoteToken
            : null,
        timestamp: row.timestamp,
        transactionHash: row.transactionHash,
      }));

  return [
    ...normalize(data.purchases, "PURCHASE"),
    ...normalize(data.resolutions, "RESOLUTION"),
    ...normalize(data.quoteClaims, "QUOTE_CLAIM"),
    ...normalize(data.prizeClaims, "PRIZE_CLAIM"),
  ]
    .sort((a, b) => Number(b.timestamp) - Number(a.timestamp))
    .slice(0, 100);
}
