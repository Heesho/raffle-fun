import type { Metadata } from "next";

import { ProfileView } from "@/features/profile/profile-view";

export const metadata: Metadata = {
  title: "Profile",
  description:
    "Sponsored raffles, ticket positions, wins, and live claimability.",
};

export default async function ProfilePage({
  params,
}: {
  readonly params: Promise<{ address: string }>;
}) {
  const { address } = await params;
  return <ProfileView profileAddress={address} />;
}
