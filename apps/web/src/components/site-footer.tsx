import { ExternalLink, ShieldCheck } from "lucide-react";
import Link from "next/link";

import { configuredChain, protocolIsConfigured } from "@/lib/protocol";

export function SiteFooter() {
  return (
    <footer className="mt-24 border-t border-white/10 bg-[#1726a3] py-14 text-white">
      <div className="page-shell grid gap-10 md:grid-cols-[1.4fr_1fr_1fr]">
        <div>
          <p className="display text-3xl font-bold">
            A fair draw, in plain sight.
          </p>
          <p className="mt-3 max-w-md text-sm leading-6 text-white/60">
            Permissionless NFT raffles with fixed economics, transferable
            tickets, verifiable randomness, and pull-based claims.
          </p>
        </div>
        <div>
          <p className="eyebrow !text-white/40">Explore</p>
          <div className="mt-4 grid gap-2 text-sm font-bold">
            <Link href="/docs">Mechanics & risks</Link>
            <Link href="/activity">Protocol activity</Link>
            <Link href="/create">Sponsor a raffle</Link>
          </div>
        </div>
        <div>
          <p className="eyebrow !text-white/40">Network</p>
          <p className="mt-4 flex items-center gap-2 text-sm font-bold">
            <ShieldCheck aria-hidden size={17} className="text-[#ffdc55]" />
            {configuredChain.name}
          </p>
          <p className="mt-2 text-xs leading-5 text-white/50">
            {protocolIsConfigured
              ? "Deployment registry verified."
              : "No protocol deployment is registered. Writes stay disabled."}
          </p>
        </div>
      </div>
      <div className="page-shell mt-12 flex flex-wrap items-center justify-between gap-4 border-t border-white/10 pt-6 text-xs text-white/45">
        <p>
          Unaudited software. Chance-based systems may require local legal
          review.
        </p>
        <a
          className="inline-flex items-center gap-1 hover:text-white"
          href="https://github.com/Heesho"
          rel="noreferrer"
          target="_blank"
        >
          Source <ExternalLink aria-hidden size={12} />
        </a>
      </div>
    </footer>
  );
}
