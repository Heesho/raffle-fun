import type { Metadata } from "next";

import { PageHeader } from "@/components/page-header";
import { CreateRaffleForm } from "@/features/create/create-raffle-form";

export const metadata: Metadata = {
  title: "Create a raffle",
  description:
    "Escrow one ERC721 prize and open fixed $1 USDC entry sales in a non-upgradeable raffle.",
};

export default function CreatePage() {
  return (
    <>
      <PageHeader
        eyebrow="Sponsor a prize"
        lede="Your NFT is escrowed atomically when the raffle is created. $1 entry pricing, the reserve, sale deadline, 5% fee, and both settlement branches are fixed from then on. Sales begin immediately and the sponsor recovers the NFT only through an empty, cash, or refund settlement."
        title="Make the rules visible."
      />
      <div className="page-shell py-12 md:py-16">
        <CreateRaffleForm />
      </div>
    </>
  );
}
