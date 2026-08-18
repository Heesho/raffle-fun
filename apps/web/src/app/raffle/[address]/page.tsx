import type { Metadata } from "next";

import { RaffleDetail } from "@/features/raffle/raffle-detail";

export const metadata: Metadata = {
  title: "Raffle detail",
  description:
    "Inspect live raffle economics, buy $1 entries, prove ticket ranges, and settle payouts.",
};

export default async function RafflePage({
  params,
}: {
  readonly params: Promise<{ address: string }>;
}) {
  const { address } = await params;
  return <RaffleDetail raffleAddress={address} />;
}
