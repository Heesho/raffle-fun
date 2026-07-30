"use client";

import { Menu, X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useState } from "react";

import { WalletButton } from "./wallet-button";

const links = [
  { href: "/", label: "Discover" },
  { href: "/create", label: "Create" },
  { href: "/activity", label: "Activity" },
  { href: "/docs", label: "How it works" },
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);

  return (
    <header className="relative z-40 border-b border-black/10 bg-[#fff9e8]/90 backdrop-blur-xl">
      <div className="page-shell flex min-h-20 items-center justify-between gap-4">
        <Link
          className="flex items-center gap-2 font-black tracking-[-0.04em]"
          href="/"
          aria-label="raffles home"
        >
          <span className="grid size-11 place-items-center">
            <Image
              alt=""
              aria-hidden
              height={44}
              priority
              src="/brand/logo-raffle-pink.png"
              width={39}
            />
          </span>
          <span className="text-xl lowercase">raffles</span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex" aria-label="Primary">
          {links.map((link) => (
            <Link
              className="rounded-full px-4 py-2 text-sm font-bold text-[#56506a] hover:bg-[#ef2ab2]/10 hover:text-[#1726a3]"
              href={link.href}
              key={link.href}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        <div className="hidden md:block">
          <WalletButton />
        </div>

        <button
          aria-expanded={open}
          aria-label={open ? "Close menu" : "Open menu"}
          className="grid size-11 place-items-center rounded-full border border-black md:hidden"
          onClick={() => setOpen((value) => !value)}
          type="button"
        >
          {open ? <X aria-hidden /> : <Menu aria-hidden />}
        </button>
      </div>

      {open ? (
        <div className="page-shell border-t border-black/10 py-4 md:hidden">
          <nav className="grid gap-1" aria-label="Mobile primary">
            {links.map((link) => (
              <Link
                className="rounded-xl px-3 py-3 font-bold hover:bg-black/5"
                href={link.href}
                key={link.href}
                onClick={() => setOpen(false)}
              >
                {link.label}
              </Link>
            ))}
          </nav>
          <div className="mt-3">
            <WalletButton />
          </div>
        </div>
      ) : null}
    </header>
  );
}
