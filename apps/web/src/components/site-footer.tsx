import { ExternalLink } from "lucide-react";
import Link from "next/link";

import { configuredChain, protocolIsConfigured } from "@/lib/protocol";
import { isDemoMode } from "@/lib/demo";

import { BrandMark, Wordmark } from "./brand-mark";

const columns = [
  {
    title: "Explore",
    links: [
      { href: "/", label: "Discover raffles" },
      { href: "/activity", label: "Protocol activity" },
      { href: "/create", label: "Sponsor a raffle" },
    ],
  },
  {
    title: "Learn",
    links: [
      { href: "/docs", label: "How it works" },
      { href: "/docs#economics", label: "Fees & economics" },
      { href: "/docs#trust", label: "Trust & risks" },
    ],
  },
] as const;

export function SiteFooter() {
  return (
    <footer className="panel-ink mt-20">
      <div className="page-shell grid gap-10 py-14 md:grid-cols-[1.6fr_1fr_1fr_1.2fr]">
        <div>
          <div className="flex items-center gap-2.5">
            <BrandMark size={26} />
            <Wordmark className="text-[length:var(--text-lg)] text-white" />
          </div>
          <p className="mt-4 max-w-xs text-[length:var(--text-sm)] leading-relaxed text-white/55">
            A fair draw, in plain sight. Fixed economics, transferable tickets,
            verifiable randomness, pull-based claims.
          </p>
        </div>

        {columns.map((column) => (
          <div key={column.title}>
            <p className="eyebrow">{column.title}</p>
            <ul className="mt-4 grid gap-2.5 text-[length:var(--text-sm)]">
              {column.links.map((link) => (
                <li key={link.href + link.label}>
                  <Link
                    className="text-white/75 transition-colors hover:text-white"
                    href={link.href}
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}

        <div>
          <p className="eyebrow">Network</p>
          <p className="mt-4 text-[length:var(--text-sm)] font-semibold">
            {configuredChain.name}
          </p>
          <p className="mt-2 text-[length:var(--text-xs)] leading-relaxed text-white/50">
            {isDemoMode()
              ? "Interactive preview: balances, draws and prizes on this build are simulated, not onchain."
              : protocolIsConfigured
                ? "Deployment registry verified."
                : "No deployment registered on this network. Transactions stay disabled."}
          </p>
        </div>
      </div>

      <div className="page-shell flex flex-wrap items-center justify-between gap-4 border-t border-white/10 py-6 text-[length:var(--text-xs)] text-white/45">
        <p>
          Unaudited software. Chance-based systems may require local legal
          review.
        </p>
        <a
          className="inline-flex items-center gap-1.5 font-medium transition-colors hover:text-white"
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
