import type { Metadata } from "next";

import { PageHeader } from "@/components/page-header";
import { CreateRaffleForm } from "@/features/create/create-raffle-form";

export const metadata: Metadata = {
  title: "Create a raffle",
  description:
    "Escrow one ERC721 prize and publish fixed ticket economics in a non-upgradeable raffle.",
};

export default function CreatePage() {
  return (
    <>
      <PageHeader
        eyebrow="Sponsor a prize"
        lede="Your NFT is escrowed the moment the raffle is created. Ticket price, threshold, sale window, fee, and both settlement branches are fixed from then on. You can cancel and reclaim the NFT until the first ticket sells — after that it moves only through settlement."
        title="Make the rules visible."
      />
      <div className="page-shell py-12 md:py-16">
        <CreateRaffleForm />
      </div>
    </>
  );
}
