"use client";

import { useQuery } from "@tanstack/react-query";
import {
  Gift,
  Layers3,
  SearchX,
  Ticket,
  Trophy,
  WalletCards,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { encodeFunctionData, isAddress, type Address } from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWalletClient,
} from "wagmi";

import { raffleAbi, raffleLensAbi } from "@raffle-fun/sdk";

import { PrizeArt } from "@/components/prize-art";
import { RaffleCard, RaffleCardSkeleton } from "@/components/raffle-card";
import { WalletButton } from "@/components/wallet-button";
import { isDemoMode } from "@/lib/demo";
import { toIndexedRaffle } from "@/lib/sandbox/adapter";
import { ticketsOwnedBy } from "@/lib/sandbox/engine";
import { useSandbox } from "@/lib/sandbox/store";
import { shortAddress } from "@/lib/format";
import { protocolDeployment } from "@/lib/protocol";
import { fetchProfileRaffles, isSubgraphConfigured } from "@/lib/subgraph";
import type { IndexedRaffle } from "@/lib/subgraph";

type LiveClaim = {
  readonly raffle: Address;
  readonly quoteToken: Address;
  readonly accountQuoteClaim: bigint;
  readonly canClaimQuote: boolean;
  readonly canClaimPrize: boolean;
};

type ProfileData = {
  readonly sponsored: readonly IndexedRaffle[];
  readonly positions: readonly IndexedRaffle[];
};

export function ProfileView({
  profileAddress,
}: {
  readonly profileAddress: string;
}) {
  const valid = isAddress(profileAddress);
  const profile = valid ? (profileAddress as Address) : undefined;
  const demo = isDemoMode();
  const configured = isSubgraphConfigured();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const wallet = useWalletClient();
  const [claimStatus, setClaimStatus] = useState("");

  const { sandbox } = useSandbox();
  const remoteQuery = useQuery<ProfileData>({
    queryKey: ["profile", profile?.toLowerCase()],
    queryFn: async () => fetchProfileRaffles(profile!),
    enabled: !demo && configured && profile !== undefined,
  });

  const sandboxProfile = useMemo<ProfileData | undefined>(() => {
    if (!demo || sandbox === undefined || profile === undefined)
      return undefined;
    const key = profile.toLowerCase();
    return {
      sponsored: sandbox.raffles
        .filter((raffle) => raffle.sponsor.toLowerCase() === key)
        .map(toIndexedRaffle),
      positions: sandbox.raffles
        .filter((raffle) => ticketsOwnedBy(raffle, profile) > 0)
        .map(toIndexedRaffle),
    };
  }, [demo, profile, sandbox]);

  const profileQuery = demo
    ? {
        data: sandboxProfile,
        isPending: sandboxProfile === undefined,
        isError: false,
      }
    : remoteQuery;

  const raffles = useMemo(() => {
    const all = [
      ...(profileQuery.data?.sponsored ?? []),
      ...(profileQuery.data?.positions ?? []),
    ];
    return [...new Map(all.map((raffle) => [raffle.id, raffle])).values()];
  }, [profileQuery.data]);
  const raffleAddresses = raffles.map((raffle) => raffle.id as Address);

  const liveQuery = useReadContract({
    address: protocolDeployment?.raffleLens,
    abi: raffleLensAbi,
    functionName: "getRaffleStates",
    args:
      profile === undefined || raffleAddresses.length === 0
        ? undefined
        : [raffleAddresses, profile],
    query: {
      enabled:
        protocolDeployment !== undefined &&
        profile !== undefined &&
        raffleAddresses.length > 0,
    },
  });

  const liveClaims = (liveQuery.data ?? []) as readonly LiveClaim[];
  const claimableQuoteCount = liveClaims.filter(
    (item) => item.canClaimQuote,
  ).length;
  const claimableTokenCount = new Set(
    liveClaims
      .filter((item) => item.canClaimQuote)
      .map((item) => item.quoteToken.toLowerCase()),
  ).size;
  const claimablePrizes = liveClaims.filter(
    (item) => item.canClaimPrize,
  ).length;
  const connectedProfile =
    address !== undefined &&
    profile !== undefined &&
    address.toLowerCase() === profile.toLowerCase();
  const batchCalls = liveClaims.flatMap((item) => [
    ...(item.canClaimQuote
      ? [
          {
            to: item.raffle,
            data: encodeFunctionData({
              abi: raffleAbi,
              functionName: "claimQuoteFor",
              args: [profile!],
            }),
          },
        ]
      : []),
    ...(item.canClaimPrize && connectedProfile
      ? [
          {
            to: item.raffle,
            data: encodeFunctionData({
              abi: raffleAbi,
              functionName: "claimPrize",
              args: [profile!],
            }),
          },
        ]
      : []),
  ]);

  async function batchClaims() {
    if (
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined ||
      profile === undefined ||
      !connectedProfile ||
      batchCalls.length === 0
    ) {
      return;
    }
    setClaimStatus("Simulating all claim calls…");
    try {
      await publicClient.simulateCalls({ account: address, calls: batchCalls });
      const { id } = await wallet.data.sendCalls({
        account: address,
        calls: batchCalls,
        experimental_fallback: true,
      });
      setClaimStatus(`Wallet batch submitted: ${id}`);
    } catch (batchError) {
      setClaimStatus(
        "Batch unavailable; submitting confirmed claims in order…",
      );
      try {
        for (const call of batchCalls) {
          const isQuoteClaim =
            call.data.slice(0, 10) ===
            encodeFunctionData({
              abi: raffleAbi,
              functionName: "claimQuoteFor",
              args: [profile],
            }).slice(0, 10);
          const { request } = await publicClient.simulateContract({
            account: address,
            address: call.to,
            abi: raffleAbi,
            functionName: isQuoteClaim ? "claimQuoteFor" : "claimPrize",
            args: [profile],
          } as Parameters<typeof publicClient.simulateContract>[0]);
          const hash = await wallet.data.writeContract(request);
          await publicClient.waitForTransactionReceipt({ hash });
        }
        await liveQuery.refetch();
        setClaimStatus("All claims confirmed.");
      } catch (error) {
        setClaimStatus(
          error instanceof Error ? error.message : String(batchError),
        );
      }
    }
  }

  if (!valid || profile === undefined) {
    return (
      <ProfileEmpty
        title="Invalid profile address"
        text="Profiles are keyed by a complete EVM account address."
      />
    );
  }

  const loading = (demo || configured) && profileQuery.isPending;
  const connectedSandbox =
    demo && profile?.toLowerCase() === sandbox?.player.toLowerCase();

  return (
    <div className="page-shell py-14 md:py-20">
      <div className="flex flex-col justify-between gap-6 md:flex-row md:items-center">
        <div className="flex items-center gap-5">
          <PrizeArt
            className="size-20 shrink-0 rounded-3xl md:size-24"
            seed={profile}
          />
          <div>
            <p className="eyebrow">
              {connectedProfile || connectedSandbox
                ? "Your account"
                : "Onchain identity"}
            </p>
            <h1 className="numeric mt-2 text-4xl md:text-5xl">
              {shortAddress(profile)}
            </h1>
          </div>
        </div>
        {!connectedProfile && !connectedSandbox ? (
          <div className="w-full max-w-xs">
            <WalletButton full />
          </div>
        ) : null}
      </div>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Summary
          icon={<Layers3 aria-hidden size={19} />}
          label="Sponsored"
          value={(profileQuery.data?.sponsored.length ?? 0).toString()}
        />
        <Summary
          icon={<Ticket aria-hidden size={19} />}
          label="Open positions"
          value={(profileQuery.data?.positions.length ?? 0).toString()}
        />
        <Summary
          icon={<WalletCards aria-hidden size={19} />}
          label="Payouts to claim"
          value={
            claimableQuoteCount === 0
              ? "0"
              : `${claimableQuoteCount} · ${claimableTokenCount} token${claimableTokenCount === 1 ? "" : "s"}`
          }
        />
        <Summary
          icon={<Trophy aria-hidden size={19} />}
          label="Prizes to claim"
          value={claimablePrizes.toString()}
        />
      </div>

      {connectedProfile && batchCalls.length > 0 ? (
        <div className="card mt-6 flex flex-col items-start justify-between gap-4 border-[var(--pink)] p-5 sm:flex-row sm:items-center">
          <div>
            <p className="font-extrabold">Claims are ready</p>
            <p className="mt-1 text-xs leading-5 text-[var(--ink-2)]">
              A compatible wallet submits them as one batch; the fallback
              confirms each claim in order.
            </p>
          </div>
          <button
            className="btn btn-primary shrink-0"
            onClick={batchClaims}
            type="button"
          >
            <Gift aria-hidden size={17} /> Claim all
          </button>
          {claimStatus ? (
            <p className="w-full text-xs font-bold">{claimStatus}</p>
          ) : null}
        </div>
      ) : null}

      {loading ? (
        <div
          className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
          role="status"
        >
          <span className="sr-only">Loading positions</span>
          {[0, 1, 2].map((value) => (
            <RaffleCardSkeleton key={value} />
          ))}
        </div>
      ) : null}

      {profileQuery.isError ? (
        <ProfileEmpty
          title="The index could not be reached"
          text="Direct chain reads remain authoritative. Retry when the index endpoint is healthy."
        />
      ) : null}

      {!loading && !profileQuery.isError && raffles.length === 0 ? (
        <ProfileEmpty
          title={
            demo || configured
              ? "Nothing here yet"
              : "Profile index not connected"
          }
          text={
            demo || configured
              ? "This account has not sponsored a raffle or bought a ticket yet."
              : "Configure a subgraph endpoint to discover positions. No sample history is shown."
          }
        />
      ) : null}

      {profileQuery.data?.sponsored.length ? (
        <section className="mt-14">
          <p className="eyebrow">Created by this account</p>
          <h2 className="mt-2 text-3xl md:text-4xl">Sponsored raffles</h2>
          <div className="mt-7 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {profileQuery.data.sponsored.map((raffle) => (
              <RaffleCard key={raffle.id} raffle={raffle} />
            ))}
          </div>
        </section>
      ) : null}

      {profileQuery.data?.positions.length ? (
        <section className="mt-14">
          <p className="eyebrow">Tickets currently held</p>
          <h2 className="mt-2 text-3xl md:text-4xl">Positions & wins</h2>
          <div className="mt-7 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {profileQuery.data.positions.map((raffle) => (
              <RaffleCard key={raffle.id} raffle={raffle} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function Summary({
  icon,
  label,
  value,
}: {
  readonly icon: React.ReactNode;
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="card p-5">
      <span className="grid size-10 place-items-center rounded-xl bg-[var(--yellow-wash)] text-[var(--amber-ink)]">
        {icon}
      </span>
      <p className="eyebrow mt-4">{label}</p>
      <p className="numeric mt-1.5 text-2xl font-extrabold">{value}</p>
    </div>
  );
}

function ProfileEmpty({
  title,
  text,
}: {
  readonly title: string;
  readonly text: string;
}) {
  return (
    <div className="card mt-10 grid place-items-center px-6 py-16 text-center">
      <div className="max-w-md">
        <span className="mx-auto grid size-12 place-items-center rounded-2xl bg-[var(--paper-sunk)] text-[var(--ink-2)]">
          <SearchX aria-hidden size={22} />
        </span>
        <h2 className="mt-5 text-2xl">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
        <Link className="btn btn-outline mt-6" href="/">
          Discover raffles
        </Link>
      </div>
    </div>
  );
}
