import type { Metadata } from "next";

import { RaffleDetail } from "@/features/raffle/raffle-detail";

export const metadata: Metadata = {
  title: "Raffle detail",
  description:
    "Inspect live raffle economics, buy tickets, request settlement, and claim payouts.",
};

export default async function RafflePage({
  params,
  searchParams,
}: {
  readonly params: Promise<{ address: string }>;
  readonly searchParams: Promise<{ ref?: string }>;
}) {
  const [{ address }, { ref }] = await Promise.all([params, searchParams]);
  return <RaffleDetail raffleAddress={address} referrer={ref} />;
}
