import {
  ArrowRight,
  BadgeDollarSign,
  Dices,
  ShieldCheck,
  TicketCheck,
} from "lucide-react";
import Link from "next/link";

import { RaffleDirectory } from "@/features/discover/raffle-directory";

export default function HomePage() {
  return (
    <>
      <section className="relative overflow-hidden bg-[#1726a3] py-16 text-white md:py-24">
        <div className="page-shell grid items-center gap-14 lg:grid-cols-[1.05fr_.95fr]">
          <div>
            <p className="eyebrow !text-[#7fc8ff]">
              Permissionless raffles on Base
            </p>
            <h1 className="mt-4 max-w-3xl text-6xl font-bold leading-[0.93] md:text-8xl">
              A fair draw,
              <br />
              <span className="text-[#ffdc55]">in plain sight.</span>
            </h1>
            <p className="mt-7 max-w-2xl text-base leading-7 text-white/65 md:text-lg">
              One NFT prize. Equal-chance ERC721 tickets. A minimum threshold
              that determines whether the winner gets the NFT or 80% of the net
              pot. Every payout is fixed in code before the first sale.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <a className="btn btn-primary" href="#raffles-heading">
                Explore raffles <ArrowRight aria-hidden size={17} />
              </a>
              <Link
                className="btn border-white/40 bg-white/5 text-white"
                href="/create"
              >
                Sponsor a prize
              </Link>
            </div>
            <div className="mt-10 flex flex-wrap gap-x-7 gap-y-3 text-xs font-bold text-white/50">
              <span className="flex items-center gap-2">
                <ShieldCheck aria-hidden size={16} className="text-[#ffdc55]" />
                Non-upgradeable raffles
              </span>
              <span className="flex items-center gap-2">
                <Dices aria-hidden size={16} className="text-[#ef2ab2]" />
                Pyth Entropy v2
              </span>
              <span className="flex items-center gap-2">
                <TicketCheck aria-hidden size={16} className="text-[#7fc8ff]" />
                Transferable tickets
              </span>
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-lg">
            <div className="absolute -inset-16 rounded-full bg-[#ef2ab2]/20 blur-3xl" />
            <div className="ticket-card relative rotate-[2deg] !border-white/20 !bg-[#fff9e8] p-5 text-[#171717] shadow-[0_35px_100px_rgba(0,0,0,.4)] sm:p-7">
              <div className="flex items-start justify-between border-b border-dashed border-black/25 pb-6">
                <div>
                  <p className="eyebrow">How settlement works</p>
                  <p className="display mt-2 text-3xl font-bold">
                    One draw. Two outcomes.
                  </p>
                </div>
                <span className="grid size-12 place-items-center rounded-full border border-black bg-[#ef2ab2] font-black text-white">
                  01
                </span>
              </div>
              <div className="grid gap-4 py-6 sm:grid-cols-2">
                <div className="rounded-2xl border border-black/15 bg-[#ffdc55] p-5">
                  <p className="eyebrow">Threshold met</p>
                  <p className="mt-3 text-lg font-black">Winner gets the NFT</p>
                  <p className="mt-2 text-sm leading-5 text-black/65">
                    Sponsor claims the entire net ticket pot.
                  </p>
                </div>
                <div className="rounded-2xl border border-black/15 bg-[#7fc8ff] p-5">
                  <p className="eyebrow">Threshold missed</p>
                  <p className="mt-3 text-lg font-black">
                    Winner gets 80% cash
                  </p>
                  <p className="mt-2 text-sm leading-5 text-black/65">
                    Sponsor reclaims the NFT and 20% of the net pot.
                  </p>
                </div>
              </div>
              <div className="flex items-center justify-between border-t border-dashed border-black/25 pt-5">
                <p className="flex items-center gap-2 text-sm font-black">
                  <BadgeDollarSign aria-hidden size={18} />
                  Ticket price is the total paid
                </p>
                <p className="text-xs font-bold text-black/50">
                  5% protocol · +5% provider
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <RaffleDirectory />
    </>
  );
}
