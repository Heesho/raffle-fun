import type { Metadata } from "next";

import { PageHeader } from "@/components/page-header";
import { ActivityFeed } from "@/features/activity/activity-feed";

export const metadata: Metadata = {
  title: "Protocol activity",
  description: "Indexed raffle.fun purchases, resolutions, and claims.",
};

export default function ActivityPage() {
  return (
    <>
      <PageHeader
        eyebrow="Onchain tape"
        lede="Purchases, resolutions, and pull-based claims indexed from the selected network. The index may lag; linked receipts and direct contract state are the source of truth."
        title="Every draw leaves a trail."
      />
      <div className="page-shell py-12 md:py-16">
        <ActivityFeed />
      </div>
    </>
  );
}
