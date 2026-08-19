import { beforeEach, describe, expect, it, vi } from "vitest";

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));

vi.mock("graphql-request", () => ({
  GraphQLClient: class {
    request = requestMock;
  },
  gql: (strings: TemplateStringsArray, ...values: string[]) =>
    strings.reduce(
      (result, segment, index) => result + segment + (values[index] ?? ""),
      "",
    ),
}));

vi.mock("./env", () => ({
  webEnv: { NEXT_PUBLIC_SUBGRAPH_URL: "https://example.test/subgraph" },
}));

import { fetchProfileRaffles } from "./subgraph";

const raffle = {
  id: "0x0000000000000000000000000000000000000001",
  factoryId: "1",
  sponsor: { id: "0x0000000000000000000000000000000000000002" },
  quoteToken: "0x0000000000000000000000000000000000000003",
  prizeToken: "0x0000000000000000000000000000000000000004",
  prizeTokenId: "42",
  entryPrice: "1000000",
  reserveEntries: "100",
  endTime: "1",
  drawRequestDeadline: "2",
  callbackDeadline: null,
  status: "NFT_WON",
  totalEntries: "501",
  ticketCount: "501",
  grossSales: "501000000",
  unsettledPot: "0",
  remainingRefundLiability: "0",
  winningEntry: "501",
  winningTicketId: null,
} as const;

function ticket(ticketId: number) {
  return {
    id: `${raffle.id}-${ticketId}`,
    ticketId: ticketId.toString(),
    firstEntry: ticketId.toString(),
    lastEntry: ticketId.toString(),
    entryCount: "1",
    raffle,
  };
}

describe("profile ticket discovery", () => {
  beforeEach(() => requestMock.mockReset());

  it("paginates past 500 live tickets so a later winning bearer is discoverable", async () => {
    requestMock
      .mockResolvedValueOnce({
        sponsored: [],
        winnerClaims: [],
        positions: Array.from({ length: 500 }, (_, index) => ticket(index + 1)),
      })
      .mockResolvedValueOnce({
        sponsored: [],
        winnerClaims: [],
        positions: [ticket(501)],
      });

    const profile = await fetchProfileRaffles(
      "0x0000000000000000000000000000000000000005",
    );

    expect(requestMock).toHaveBeenCalledTimes(2);
    expect(requestMock.mock.calls.map((call) => call[1].skip)).toEqual([
      0, 500,
    ]);
    expect(profile.tickets).toHaveLength(501);
    expect(profile.tickets.at(-1)?.ticketId).toBe("501");
    expect(profile.positions).toHaveLength(1);
  });
});
