"use client";

import { ChevronDown, RotateCcw, Trophy, User } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { formatTokenAmount, shortAddress } from "@/lib/format";
import { SANDBOX_WETH } from "@/lib/sandbox/adapter";
import { useSandbox } from "@/lib/sandbox/store";

/**
 * The connected-account control. Presents the visitor's sandbox account the
 * way a real connected wallet would, with balances and prizes in the menu.
 */
export function SandboxWalletButton({
  full = false,
}: {
  readonly full?: boolean;
}) {
  const { sandbox, reset } = useSandbox();
  const [open, setOpen] = useState(false);
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: MouseEvent) {
      if (!container.current?.contains(event.target as Node)) setOpen(false);
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  if (sandbox === undefined) {
    return <div className={`h-11 ${full ? "w-full" : "w-40"}`} aria-hidden />;
  }

  const address = sandbox.player as `0x${string}`;
  const width = full ? "w-full" : "";

  return (
    <div className={`relative ${width}`} ref={container}>
      <button
        aria-expanded={open}
        aria-haspopup="menu"
        className={`btn btn-outline ${width}`}
        onClick={() => setOpen((value) => !value)}
        type="button"
      >
        <span className="size-2 rounded-full bg-[var(--grass)]" />
        <span className="numeric hidden sm:inline">
          {formatTokenAmount(
            sandbox.wallet.weth,
            SANDBOX_WETH.decimals,
            SANDBOX_WETH.symbol,
          )}
        </span>
        <span className="numeric text-[var(--ink-2)]">
          {shortAddress(address)}
        </span>
        <ChevronDown
          aria-hidden
          className={`transition-transform ${open ? "rotate-180" : ""}`}
          size={15}
        />
      </button>

      {open ? (
        <div
          className="card absolute right-0 top-[calc(100%+0.5rem)] z-50 min-w-64 p-1.5 shadow-[var(--shadow-lg)]"
          role="menu"
        >
          <div className="px-3 py-2.5">
            <p className="eyebrow">Balance</p>
            <p className="numeric mt-1 text-lg font-extrabold">
              {formatTokenAmount(
                sandbox.wallet.weth,
                SANDBOX_WETH.decimals,
                SANDBOX_WETH.symbol,
              )}
            </p>
            <p className="numeric mt-0.5 text-xs font-bold text-[var(--ink-2)]">
              {formatTokenAmount(sandbox.wallet.eth, 18, "ETH")} for gas
            </p>
          </div>

          {sandbox.wallet.nfts.length > 0 ? (
            <p className="mx-1.5 mb-1 flex items-center gap-2 rounded-xl bg-[var(--yellow-wash)] px-3 py-2 text-sm font-extrabold text-[var(--amber-ink)]">
              <Trophy aria-hidden size={15} />
              {sandbox.wallet.nfts.length} NFT
              {sandbox.wallet.nfts.length === 1 ? "" : "s"} won
            </p>
          ) : null}

          <div className="perforation mx-1.5 my-1" />

          <Link
            className="flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-bold hover:bg-[var(--paper-sunk)]"
            href={`/profile/${address}`}
            onClick={() => setOpen(false)}
            role="menuitem"
          >
            <User aria-hidden size={16} /> View profile
          </Link>
          <button
            className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm font-bold text-[var(--ink-2)] hover:bg-[var(--paper-sunk)] hover:text-[var(--ink)]"
            onClick={() => {
              setOpen(false);
              reset();
            }}
            role="menuitem"
            type="button"
          >
            <RotateCcw aria-hidden size={16} /> Start over
          </button>
        </div>
      ) : null}
    </div>
  );
}
