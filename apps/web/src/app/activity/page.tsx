import type { Metadata } from "next";

import { ActivityFeed } from "@/features/activity/activity-feed";

export const metadata: Metadata = {
  title: "Protocol activity",
  description: "Indexed raffle.fun purchases, resolutions, and claims.",
};

export default function ActivityPage() {
  return (
    <div className="page-shell py-14 md:py-20">
      <p className="eyebrow">Onchain tape</p>
      <h1 className="mt-3 text-[clamp(2.5rem,6vw,4rem)]">
        Every draw leaves a trail.
      </h1>
      <p className="mt-5 max-w-2xl text-base leading-7 text-[var(--ink-soft)]">
        Purchases, resolutions, and pull-based claims indexed from the selected
        network. The index may lag; linked receipts and direct contract state
        are the source of truth.
      </p>
      <ActivityFeed />
    </div>
  );
}
