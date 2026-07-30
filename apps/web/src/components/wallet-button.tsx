"use client";

import { ChevronDown, LogOut, Wallet } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";

import { configuredChain, configuredChainId } from "@/lib/protocol";
import { shortAddress } from "@/lib/format";

export function WalletButton() {
  const [expanded, setExpanded] = useState(false);
  const { address, chainId, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  if (!isConnected || address === undefined) {
    const connector = connectors[0];
    return (
      <button
        className="btn btn-dark w-full"
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
        className="btn btn-primary w-full"
        disabled={isSwitching}
        onClick={() => switchChain({ chainId: configuredChainId })}
        type="button"
      >
        {isSwitching ? "Switching…" : `Switch to ${configuredChain.name}`}
      </button>
    );
  }

  return (
    <div className="relative">
      <button
        aria-expanded={expanded}
        className="btn btn-ghost w-full bg-white/70"
        onClick={() => setExpanded((value) => !value)}
        type="button"
      >
        <span className="status-dot text-emerald-500" />
        {shortAddress(address)}
        <ChevronDown aria-hidden size={15} />
      </button>
      {expanded ? (
        <div className="absolute right-0 top-[calc(100%+0.5rem)] z-50 min-w-52 rounded-2xl border border-black/15 bg-[#fffdf7] p-2 shadow-xl">
          <Link
            className="block rounded-xl px-3 py-2 text-sm font-bold hover:bg-black/5"
            href={`/profile/${address}`}
            onClick={() => setExpanded(false)}
          >
            View profile
          </Link>
          <button
            className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm font-bold text-red-700 hover:bg-red-50"
            onClick={() => disconnect()}
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
