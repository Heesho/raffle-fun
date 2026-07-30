"use client";

import { ChevronDown, LogOut, User, Wallet } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";

import { configuredChain, configuredChainId } from "@/lib/protocol";
import { shortAddress } from "@/lib/format";

export function WalletButton({ full = false }: { readonly full?: boolean }) {
  const [expanded, setExpanded] = useState(false);
  const container = useRef<HTMLDivElement>(null);
  const { address, chainId, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  useEffect(() => {
    if (!expanded) return;
    function onPointerDown(event: MouseEvent) {
      if (!container.current?.contains(event.target as Node)) {
        setExpanded(false);
      }
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setExpanded(false);
    }
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [expanded]);

  const width = full ? "w-full" : "";

  if (!isConnected || address === undefined) {
    const connector = connectors[0];
    return (
      <button
        className={`btn btn-ink ${width}`}
        disabled={connector === undefined || isPending}
        onClick={() => connector && connect({ connector })}
        type="button"
      >
        <Wallet aria-hidden size={17} />
        {isPending ? "Opening wallet…" : "Connect wallet"}
      </button>
    );
  }

  if (chainId !== configuredChainId) {
    return (
      <button
        className={`btn btn-primary ${width}`}
        disabled={isSwitching}
        onClick={() => switchChain({ chainId: configuredChainId })}
        type="button"
      >
        {isSwitching ? "Switching…" : `Switch to ${configuredChain.name}`}
      </button>
    );
  }

  return (
    <div className={`relative ${width}`} ref={container}>
      <button
        aria-expanded={expanded}
        aria-haspopup="menu"
        className={`btn btn-outline ${width}`}
        onClick={() => setExpanded((value) => !value)}
        type="button"
      >
        <span className="size-2 rounded-full bg-[var(--grass)]" />
        <span className="numeric">{shortAddress(address)}</span>
        <ChevronDown
          aria-hidden
          className={`transition-transform ${expanded ? "rotate-180" : ""}`}
          size={15}
        />
      </button>
      {expanded ? (
        <div
          className="card absolute right-0 top-[calc(100%+0.5rem)] z-50 min-w-56 p-1.5 shadow-[var(--shadow-lift)]"
          role="menu"
        >
          <Link
            className="flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-bold hover:bg-[var(--paper-sunk)]"
            href={`/profile/${address}`}
            onClick={() => setExpanded(false)}
            role="menuitem"
          >
            <User aria-hidden size={16} /> View profile
          </Link>
          <button
            className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm font-bold text-[var(--danger)] hover:bg-[var(--danger-wash)]"
            onClick={() => {
              setExpanded(false);
              disconnect();
            }}
            role="menuitem"
            type="button"
          >
            <LogOut aria-hidden size={16} />
            Disconnect
          </button>
        </div>
      ) : null}
    </div>
  );
}
