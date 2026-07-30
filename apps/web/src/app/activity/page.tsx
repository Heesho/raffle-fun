import type { Metadata } from "next";

import { ActivityFeed } from "@/features/activity/activity-feed";

export const metadata: Metadata = {
  title: "Protocol activity",
  description: "Indexed raffles purchases, resolutions, and claims.",
};

export default function ActivityPage() {
  return (
    <div className="page-shell py-14 md:py-20">
      <p className="eyebrow">Onchain tape</p>
      <h1 className="mt-3 text-5xl font-bold md:text-7xl">
        Every draw leaves a trail.
      </h1>
      <p className="mt-5 max-w-2xl text-base leading-7 text-[#56506a]">
        Purchases, resolutions, and pull-based claims indexed from the selected
        network. The index may lag; linked receipts and direct contract state
        are the source of truth.
      </p>
      <ActivityFeed />
    </div>
  );
}
