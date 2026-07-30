"use client";

import { Menu, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { isDemoMode } from "@/lib/demo";

import { SandboxWalletButton } from "./sandbox/sandbox-wallet-button";
import { BrandMark, Wordmark } from "./brand-mark";
import { WalletButton } from "./wallet-button";

const links = [
  { href: "/", label: "Discover" },
  { href: "/create", label: "Create" },
  { href: "/activity", label: "Activity" },
  { href: "/docs", label: "How it works" },
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const demo = isDemoMode();

  function isCurrent(href: string): boolean {
    return href === "/" ? pathname === "/" : pathname.startsWith(href);
  }

  return (
    <header className="sticky top-0 z-40 border-b border-[var(--line)] bg-[color-mix(in_srgb,var(--paper)_82%,transparent)] backdrop-blur-xl">
      <div className="page-shell flex min-h-[4.5rem] items-center gap-4">
        <Link
          className="flex shrink-0 items-center gap-2.5"
          href="/"
          aria-label="raffle.fun home"
        >
          <BrandMark size={30} />
          <Wordmark className="text-xl" />
        </Link>

        <nav
          className="mx-auto hidden items-center gap-1 md:flex"
          aria-label="Primary"
        >
          {links.map((link) => {
            const current = isCurrent(link.href);
            return (
              <Link
                aria-current={current ? "page" : undefined}
                className={`rounded-full px-4 py-2 text-sm font-bold transition-colors ${
                  current
                    ? "bg-[var(--pink-wash)] text-[var(--pink-strong)]"
                    : "text-[var(--ink-soft)] hover:bg-[rgba(27,42,155,0.06)] hover:text-[var(--ink)]"
                }`}
                href={link.href}
                key={link.href}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto hidden md:block">
          {demo ? <SandboxWalletButton /> : <WalletButton />}
        </div>

        <button
          aria-controls="mobile-nav"
          aria-expanded={open}
          aria-label={open ? "Close menu" : "Open menu"}
          className="btn btn-outline ml-auto !size-11 !min-h-0 !p-0 md:hidden"
          onClick={() => setOpen((value) => !value)}
          type="button"
        >
          {open ? <X aria-hidden size={20} /> : <Menu aria-hidden size={20} />}
        </button>
      </div>

      {open ? (
        <div
          className="page-shell border-t border-[var(--line)] py-4 md:hidden"
          id="mobile-nav"
        >
          <nav className="grid gap-1" aria-label="Mobile primary">
            {links.map((link) => (
              <Link
                aria-current={isCurrent(link.href) ? "page" : undefined}
                className={`rounded-xl px-3 py-3 font-bold ${
                  isCurrent(link.href)
                    ? "bg-[var(--pink-wash)] text-[var(--pink-strong)]"
                    : "hover:bg-[rgba(27,42,155,0.06)]"
                }`}
                href={link.href}
                key={link.href}
                onClick={() => setOpen(false)}
              >
                {link.label}
              </Link>
            ))}
          </nav>
          <div className="mt-3">
            {demo ? <SandboxWalletButton full /> : <WalletButton full />}
          </div>
        </div>
      ) : null}
    </header>
  );
}
