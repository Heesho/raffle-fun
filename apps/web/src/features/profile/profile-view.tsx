"use client";

import { useQuery } from "@tanstack/react-query";
import {
  Check,
  Gift,
  Layers3,
  LoaderCircle,
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

import { RaffleCard } from "@/components/raffle-card";
import { WalletButton } from "@/components/wallet-button";
import { shortAddress } from "@/lib/format";
import { protocolDeployment } from "@/lib/protocol";
import { fetchProfileRaffles, isSubgraphConfigured } from "@/lib/subgraph";

type LiveClaim = {
  readonly raffle: Address;
  readonly quoteToken: Address;
  readonly accountQuoteClaim: bigint;
  readonly canClaimQuote: boolean;
  readonly canClaimPrize: boolean;
};

export function ProfileView({
  profileAddress,
}: {
  readonly profileAddress: string;
}) {
  const valid = isAddress(profileAddress);
  const profile = valid ? (profileAddress as Address) : undefined;
  const configured = isSubgraphConfigured();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const wallet = useWalletClient();
  const [claimStatus, setClaimStatus] = useState("");

  const profileQuery = useQuery({
    queryKey: ["profile", profile?.toLowerCase()],
    queryFn: () => fetchProfileRaffles(profile!),
    enabled: configured && profile !== undefined,
  });

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
          const { request } = await publicClient.simulateContract({
            account: address,
            address: call.to,
            abi: raffleAbi,
            dataSuffix: undefined,
            functionName:
              call.data.slice(0, 10) ===
              encodeFunctionData({
                abi: raffleAbi,
                functionName: "claimQuoteFor",
                args: [profile],
              }).slice(0, 10)
                ? "claimQuoteFor"
                : "claimPrize",
            args:
              call.data.slice(0, 10) ===
              encodeFunctionData({
                abi: raffleAbi,
                functionName: "claimQuoteFor",
                args: [profile],
              }).slice(0, 10)
                ? [profile]
                : [profile],
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

  return (
    <div className="page-shell py-14 md:py-20">
      <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end">
        <div>
          <p className="eyebrow">Onchain identity</p>
          <h1 className="mt-3 text-5xl font-bold md:text-7xl">
            {shortAddress(profile)}
          </h1>
          <p className="mt-4 max-w-xl text-sm leading-6 text-[#56506a]">
            Sponsored raffles and ticket positions come from the index.
            Claimability is independently refreshed from the protocol lens.
          </p>
        </div>
        {!connectedProfile ? (
          <div className="w-full max-w-xs">
            <WalletButton />
          </div>
        ) : null}
      </div>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Summary
          icon={<Layers3 aria-hidden />}
          label="Sponsored"
          value={(profileQuery.data?.sponsored.length ?? 0).toString()}
        />
        <Summary
          icon={<Ticket aria-hidden />}
          label="Open positions"
          value={(profileQuery.data?.positions.length ?? 0).toString()}
        />
        <Summary
          icon={<WalletCards aria-hidden />}
          label="Live quote claims"
          value={
            claimableQuoteCount === 0
              ? "0"
              : `${claimableQuoteCount} · ${claimableTokenCount} token${claimableTokenCount === 1 ? "" : "s"}`
          }
        />
        <Summary
          icon={<Trophy aria-hidden />}
          label="Live prize claims"
          value={claimablePrizes.toString()}
        />
      </div>

      {connectedProfile && batchCalls.length > 0 ? (
        <div className="ticket-card mt-6 flex flex-col items-start justify-between gap-4 p-5 sm:flex-row sm:items-center">
          <div>
            <p className="font-black">Claims are ready</p>
            <p className="mt-1 text-xs text-[#56506a]">
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

      {profileQuery.isPending && configured ? (
        <div
          className="mt-10 flex items-center gap-2 text-sm font-bold"
          role="status"
        >
          <LoaderCircle aria-hidden className="animate-spin" size={18} />{" "}
          Loading indexed positions…
        </div>
      ) : null}

      {profileQuery.isError ? (
        <ProfileEmpty
          title="The index could not be reached"
          text="Direct chain reads remain authoritative. Retry when the index endpoint is healthy."
        />
      ) : null}

      {!profileQuery.isPending &&
      !profileQuery.isError &&
      raffles.length === 0 ? (
        <ProfileEmpty
          title={
            configured ? "No indexed activity" : "Profile index not connected"
          }
          text={
            configured
              ? "This account has no sponsored raffles or current ticket positions in the selected index."
              : "Configure a real subgraph endpoint to discover positions. No sample history is shown."
          }
        />
      ) : null}

      {profileQuery.data?.sponsored.length ? (
        <section className="mt-14">
          <p className="eyebrow">Created by this account</p>
          <h2 className="mt-2 text-4xl font-bold">Sponsored raffles</h2>
          <div className="mt-7 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {profileQuery.data.sponsored.map((raffle) => (
              <RaffleCard key={raffle.id} raffle={raffle} />
            ))}
          </div>
        </section>
      ) : null}

      {profileQuery.data?.positions.length ? (
        <section className="mt-14">
          <p className="eyebrow">Tickets currently held</p>
          <h2 className="mt-2 text-4xl font-bold">Positions & wins</h2>
          <div className="mt-7 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
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
    <div className="ticket-card p-5">
      <span className="grid size-10 place-items-center rounded-xl bg-[#ffdc55]">
        {icon}
      </span>
      <p className="eyebrow mt-5">{label}</p>
      <p className="numeric mt-2 text-2xl font-black">{value}</p>
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
    <div className="ticket-card mt-10 p-10 text-center">
      <Check aria-hidden className="mx-auto text-[#56506a]" />
      <h2 className="mt-4 text-2xl font-bold">{title}</h2>
      <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-[#56506a]">
        {text}
      </p>
      <Link className="btn btn-ghost mt-5" href="/">
        Discover raffles
      </Link>
    </div>
  );
}
