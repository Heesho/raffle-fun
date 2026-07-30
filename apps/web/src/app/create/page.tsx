import type { Metadata } from "next";

import { CreateRaffleForm } from "@/features/create/create-raffle-form";

export const metadata: Metadata = {
  title: "Create a raffle",
  description:
    "Escrow one ERC721 prize and publish fixed ticket economics in a non-upgradeable raffle.",
};

export default function CreatePage() {
  return (
    <div className="page-shell py-14 md:py-20">
      <div className="mb-10 max-w-3xl">
        <p className="eyebrow">Sponsor a prize</p>
        <h1 className="mt-3 text-[clamp(2.5rem,6vw,4rem)]">
          Make the rules visible.
        </h1>
        <p className="mt-5 text-base leading-7 text-[var(--ink-soft)]">
          Your NFT is escrowed the moment the raffle is created. Ticket price,
          threshold, sale window, fees, and both settlement branches are fixed
          from then on. You can cancel and reclaim the NFT until the first
          ticket sells — after that it moves only through settlement.
        </p>
      </div>
      <CreateRaffleForm />
    </div>
  );
}
