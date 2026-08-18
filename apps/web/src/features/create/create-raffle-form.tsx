"use client";

import {
  ArrowRight,
  Check,
  CircleDollarSign,
  ExternalLink,
  ImageOff,
  Info,
  LoaderCircle,
  ShieldCheck,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useMemo, useState } from "react";
import {
  decodeEventLog,
  erc721Abi,
  isAddress,
  type Address,
  type Hash,
} from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWalletClient,
} from "wagmi";
import { z } from "zod";

import {
  calculateResolutionAmounts,
  createRaffle,
  ENTRY_PRICE,
  MAX_SALE_DURATION_SECONDS,
  MAX_UINT128,
  raffleFactoryAbi,
  type ActionContext,
} from "@raffle-fun/sdk";

import { WalletButton } from "@/components/wallet-button";
import { formatTokenAmount } from "@/lib/format";
import { fetchSafeNftMetadata, type SafeNftMetadata } from "@/lib/nft-metadata";
import {
  configuredChain,
  explorerTransactionUrl,
  protocolDeployment,
} from "@/lib/protocol";

const formSchema = z.object({
  sponsorRecipient: z
    .string()
    .refine(
      (value) => value === "" || isAddress(value),
      "Enter a valid sponsor payment address.",
    ),
  prizeToken: z.string().refine(isAddress, "Enter a valid ERC721 address."),
  prizeTokenId: z
    .string()
    .regex(/^(0|[1-9]\d*)$/, "Use a nonnegative token ID."),
  reserveEntries: z
    .string()
    .regex(/^[1-9]\d*$/, "Reserve entries must be at least one."),
  endTime: z.string().min(1, "Choose an end time."),
});

type FormField = keyof z.infer<typeof formSchema>;

type ProgressState =
  | { readonly kind: "idle" }
  | { readonly kind: "pending"; readonly message: string }
  | { readonly kind: "success"; readonly hash: Hash; readonly raffle?: Address }
  | { readonly kind: "error"; readonly message: string };

function initialDate(hoursFromNow: number): string {
  const date = new Date(Date.now() + hoursFromNow * 3_600_000);
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 16);
}

export function CreateRaffleForm() {
  const { address, chainId, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const wallet = useWalletClient();
  const [form, setForm] = useState({
    sponsorRecipient: "",
    prizeToken: "",
    prizeTokenId: "",
    reserveEntries: "100000",
    endTime: initialDate(24 * 7),
  });
  const [touched, setTouched] = useState<ReadonlySet<FormField>>(new Set());
  const [attempted, setAttempted] = useState(false);
  const [metadata, setMetadata] = useState<SafeNftMetadata>();
  const [metadataState, setMetadataState] = useState<
    "idle" | "loading" | "error"
  >("idle");
  const [metadataError, setMetadataError] = useState("");
  const [progress, setProgress] = useState<ProgressState>({ kind: "idle" });
  const [approved, setApproved] = useState(false);

  const deployed = protocolDeployment !== undefined;
  const quoteTokenQuery = useReadContract({
    address: protocolDeployment?.raffleFactory,
    abi: raffleFactoryAbi,
    functionName: "quoteToken",
    query: { enabled: deployed, staleTime: 300_000 },
  });
  const quoteToken =
    typeof quoteTokenQuery.data === "string" && isAddress(quoteTokenQuery.data)
      ? quoteTokenQuery.data
      : undefined;

  const parsed = useMemo(
    () =>
      formSchema
        .superRefine((value, context) => {
          if (/^[1-9]\d*$/.test(value.reserveEntries)) {
            const reserve = BigInt(value.reserveEntries);
            if (reserve > MAX_UINT128) {
              context.addIssue({
                code: "custom",
                path: ["reserveEntries"],
                message: "Reserve entries must fit uint128.",
              });
            }
          }
        })
        .safeParse(form),
    [form],
  );

  const issues = useMemo(() => {
    const map = new Map<string, string>();
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const key = String(issue.path[0] ?? "");
        if (!map.has(key)) map.set(key, issue.message);
      }
    }
    return map;
  }, [parsed]);

  function errorFor(field: FormField): string | undefined {
    if (!attempted && !touched.has(field)) return undefined;
    return issues.get(field);
  }

  const target = useMemo(() => {
    if (!parsed.success) return undefined;
    return {
      prizeToken: parsed.data.prizeToken as Address,
      prizeTokenId: BigInt(parsed.data.prizeTokenId),
    };
  }, [parsed]);
  const reserveEconomics = useMemo(() => {
    if (!parsed.success) return undefined;
    return calculateResolutionAmounts(
      BigInt(parsed.data.reserveEntries) * ENTRY_PRICE,
      true,
    );
  }, [parsed]);

  function update(key: FormField, value: string) {
    setForm((current) => ({ ...current, [key]: value }));
    if (key === "prizeToken" || key === "prizeTokenId") {
      setApproved(false);
      setMetadata(undefined);
    }
  }

  function markTouched(key: FormField) {
    setTouched((current) => new Set(current).add(key));
  }

  async function loadMetadata() {
    if (
      publicClient === undefined ||
      target === undefined ||
      address === undefined
    ) {
      setMetadataError("Connect a wallet and enter a valid NFT first.");
      setMetadataState("error");
      return;
    }
    setMetadataState("loading");
    setMetadataError("");
    try {
      const [owner, tokenUri] = await Promise.all([
        publicClient.readContract({
          address: target.prizeToken,
          abi: erc721Abi,
          functionName: "ownerOf",
          args: [target.prizeTokenId],
        }),
        publicClient.readContract({
          address: target.prizeToken,
          abi: erc721Abi,
          functionName: "tokenURI",
          args: [target.prizeTokenId],
        }),
      ]);
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet does not own this token.");
      }
      setMetadata(await fetchSafeNftMetadata(tokenUri));
      setMetadataState("idle");
    } catch (error) {
      setMetadataState("error");
      setMetadataError(
        error instanceof Error ? error.message : "Could not load NFT.",
      );
    }
  }

  async function approvePrize() {
    setAttempted(true);
    if (
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined ||
      target === undefined ||
      protocolDeployment === undefined
    ) {
      setProgress({
        kind: "error",
        message: "Wallet or protocol is not ready.",
      });
      return;
    }
    setProgress({
      kind: "pending",
      message: "Confirm NFT approval in your wallet…",
    });
    try {
      const owner = await publicClient.readContract({
        address: target.prizeToken,
        abi: erc721Abi,
        functionName: "ownerOf",
        args: [target.prizeTokenId],
      });
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet no longer owns this NFT.");
      }
      const { request } = await publicClient.simulateContract({
        account: address,
        address: target.prizeToken,
        abi: erc721Abi,
        functionName: "approve",
        args: [protocolDeployment.raffleFactory, target.prizeTokenId],
      });
      const hash = await wallet.data.writeContract(request);
      setProgress({ kind: "pending", message: "Waiting for NFT approval…" });
      await publicClient.waitForTransactionReceipt({ hash });
      setApproved(true);
      setProgress({ kind: "success", hash });
    } catch (error) {
      setProgress({
        kind: "error",
        message: error instanceof Error ? error.message : "Approval failed.",
      });
    }
  }

  async function submitRaffle() {
    setAttempted(true);
    if (
      !parsed.success ||
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined ||
      protocolDeployment === undefined ||
      target === undefined
    ) {
      setProgress({
        kind: "error",
        message: "Complete every required field first.",
      });
      return;
    }

    setProgress({
      kind: "pending",
      message: "Checking live ownership and approval…",
    });
    try {
      const [owner, tokenApproval, operatorApproval, latestBlock] =
        await Promise.all([
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "ownerOf",
            args: [target.prizeTokenId],
          }),
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "getApproved",
            args: [target.prizeTokenId],
          }),
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "isApprovedForAll",
            args: [address, protocolDeployment.raffleFactory],
          }),
          publicClient.getBlock(),
        ]);
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet no longer owns this NFT.");
      }
      if (
        tokenApproval.toLowerCase() !==
          protocolDeployment.raffleFactory.toLowerCase() &&
        !operatorApproval
      ) {
        throw new Error("Approve the factory to escrow this NFT first.");
      }

      const endTime = BigInt(
        Math.floor(new Date(parsed.data.endTime).getTime() / 1_000),
      );
      if (endTime <= latestBlock.timestamp) {
        throw new Error("End time must be in the future.");
      }
      if (endTime - latestBlock.timestamp > MAX_SALE_DURATION_SECONDS) {
        throw new Error("Entry sales cannot run longer than 30 days.");
      }

      setProgress({ kind: "pending", message: "Simulating raffle creation…" });
      const hash = await createRaffle(
        {
          publicClient,
          walletClient: wallet.data,
          account: address,
        } as unknown as ActionContext,
        protocolDeployment.raffleFactory,
        {
          sponsorRecipient:
            parsed.data.sponsorRecipient === ""
              ? address
              : (parsed.data.sponsorRecipient as Address),
          prizeToken: target.prizeToken,
          prizeTokenId: target.prizeTokenId,
          reserveEntries: BigInt(parsed.data.reserveEntries),
          endTime,
        },
      );
      setProgress({
        kind: "pending",
        message: "Escrowing prize and opening entry sales…",
      });
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      let raffle: Address | undefined;
      for (const log of receipt.logs) {
        try {
          const decoded = decodeEventLog({
            abi: raffleFactoryAbi,
            data: log.data,
            topics: log.topics,
          });
          if (decoded.eventName === "RaffleCreated") {
            raffle = (decoded.args as { raffle: Address }).raffle;
            break;
          }
        } catch {
          // Logs from the prize NFT and new raffle are intentionally skipped.
        }
      }
      setProgress({ kind: "success", hash, raffle });
    } catch (error) {
      setProgress({
        kind: "error",
        message:
          error instanceof Error ? error.message : "Raffle creation failed.",
      });
    }
  }

  const canWrite =
    isConnected &&
    address !== undefined &&
    chainId === protocolDeployment?.chainId &&
    parsed.success;

  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_22rem]">
      <div className="space-y-5">
        {!deployed ? (
          <div className="card flex gap-3 border-[var(--line-strong)] bg-[var(--yellow-wash)] p-5 text-sm leading-6 text-[var(--amber-ink)]">
            <Info aria-hidden className="mt-0.5 shrink-0" size={18} />
            <p>
              <strong>No deployment on {configuredChain.name} yet.</strong> You
              can review the flow, but creation stays disabled until its
              canonical factory is registered.
            </p>
          </div>
        ) : null}

        <FormSection
          done={target !== undefined}
          number="1"
          title="Connect and choose a prize"
        >
          <div className="mb-5 max-w-xs">
            <WalletButton full />
          </div>
          <div className="grid gap-4 sm:grid-cols-[1fr_10rem]">
            <Field
              error={errorFor("prizeToken")}
              label="ERC721 contract"
              onBlur={() => markTouched("prizeToken")}
              onChange={(value) => update("prizeToken", value)}
              placeholder="0x…"
              value={form.prizeToken}
            />
            <Field
              error={errorFor("prizeTokenId")}
              label="Token ID"
              onBlur={() => markTouched("prizeTokenId")}
              onChange={(value) => update("prizeTokenId", value)}
              placeholder="42"
              value={form.prizeTokenId}
            />
          </div>
          <button
            className="btn btn-outline mt-4"
            disabled={metadataState === "loading" || target === undefined}
            onClick={loadMetadata}
            type="button"
          >
            {metadataState === "loading" ? (
              <LoaderCircle aria-hidden className="animate-spin" size={17} />
            ) : (
              <ShieldCheck aria-hidden size={17} />
            )}
            Verify ownership &amp; metadata
          </button>
          {metadataError ? (
            <p className="field-error" role="alert">
              {metadataError}
            </p>
          ) : null}
          {metadata ? (
            <div className="mt-5 flex gap-4 rounded-2xl bg-[var(--paper-sunk)] p-4">
              <div className="relative grid size-24 shrink-0 place-items-center overflow-hidden rounded-2xl bg-[var(--ink)] text-white">
                {metadata.imageUrl ? (
                  <Image
                    alt=""
                    className="object-cover"
                    fill
                    sizes="96px"
                    src={metadata.imageUrl}
                    unoptimized
                  />
                ) : (
                  <ImageOff aria-hidden />
                )}
              </div>
              <div>
                <p className="font-extrabold">{metadata.name}</p>
                <p className="mt-1 line-clamp-3 text-sm leading-5 text-[var(--ink-2)]">
                  {metadata.description}
                </p>
              </div>
            </div>
          ) : null}
        </FormSection>

        <FormSection
          done={
            issues.get("reserveEntries") === undefined &&
            issues.get("sponsorRecipient") === undefined
          }
          number="2"
          title="Set the NFT reserve"
        >
          <div className="mb-4 rounded-2xl bg-[var(--paper-sunk)] p-4">
            <span className="field-label">Entry price</span>
            <p className="numeric mt-1 text-lg font-extrabold">$1 USDC</p>
            <span className="field-hint">
              Fixed in the protocol. One purchase may bundle any number of
              entries into one ticket.
            </span>
          </div>
          <Field
            error={errorFor("reserveEntries")}
            label="Reserve entries (equal to USDC gross target)"
            onBlur={() => markTouched("reserveEntries")}
            onChange={(value) => update("reserveEntries", value)}
            placeholder="100000"
            value={form.reserveEntries}
          />
          <p className="field-hint">
            Equality meets the reserve. Sales remain uncapped and continue until
            the deadline.
          </p>
          <div className="mt-5">
            <Field
              error={errorFor("sponsorRecipient")}
              label="Sponsor payout address (optional)"
              onBlur={() => markTouched("sponsorRecipient")}
              onChange={(value) => update("sponsorRecipient", value)}
              placeholder={address ?? "Defaults to the connected sponsor"}
              value={form.sponsorRecipient}
            />
            <p className="field-hint">
              Sponsor USDC proceeds and any returned NFT always go to this fixed
              address. Leave blank to use the connected wallet.
            </p>
          </div>
        </FormSection>

        <FormSection done number="3" title="Choose the sale deadline">
          <Field
            error={errorFor("endTime")}
            label="Ends"
            onBlur={() => markTouched("endTime")}
            onChange={(value) => update("endTime", value)}
            type="datetime-local"
            value={form.endTime}
          />
          <p className="field-hint">
            Sales begin immediately after atomic NFT escrow and may run for at
            most 30 days.
          </p>
        </FormSection>

        <FormSection number="4" title="Approve and create">
          {attempted && !parsed.success ? (
            <ul
              className="mb-5 space-y-1.5 rounded-2xl bg-[var(--danger-wash)] p-4 text-sm font-bold text-[var(--danger)]"
              role="alert"
            >
              {[...issues.values()].map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          ) : null}
          <div className="flex flex-wrap gap-3">
            <button
              className="btn btn-outline"
              disabled={!canWrite || progress.kind === "pending"}
              onClick={approvePrize}
              type="button"
            >
              {approved ? <Check aria-hidden size={17} /> : null}
              {approved ? "Factory approved" : "1. Approve NFT"}
            </button>
            <button
              className="btn btn-primary"
              disabled={!canWrite || !approved || progress.kind === "pending"}
              onClick={submitRaffle}
              type="button"
            >
              2. Create raffle <ArrowRight aria-hidden size={17} />
            </button>
          </div>
          {progress.kind !== "idle" ? (
            <div
              className={`mt-5 rounded-2xl p-4 text-sm ${progress.kind === "error" ? "bg-[var(--danger-wash)] text-[var(--danger)]" : "bg-[var(--paper-sunk)]"}`}
              role={progress.kind === "error" ? "alert" : "status"}
            >
              {progress.kind === "pending" ? (
                <p className="flex items-center gap-2 font-bold">
                  <LoaderCircle
                    aria-hidden
                    className="animate-spin"
                    size={17}
                  />
                  {progress.message}
                </p>
              ) : null}
              {progress.kind === "error" ? (
                <p className="font-bold">{progress.message}</p>
              ) : null}
              {progress.kind === "success" ? (
                <div>
                  <p className="flex items-center gap-2 font-extrabold text-[#0d6b45]">
                    <Check aria-hidden size={17} /> Transaction confirmed
                  </p>
                  <div className="mt-3 flex flex-wrap gap-4">
                    <a
                      className="font-bold underline"
                      href={explorerTransactionUrl(progress.hash)}
                      rel="noreferrer"
                      target="_blank"
                    >
                      View transaction{" "}
                      <ExternalLink className="inline" size={13} />
                    </a>
                    {progress.raffle ? (
                      <Link
                        className="font-bold underline"
                        href={`/raffle/${progress.raffle}`}
                      >
                        Open raffle
                      </Link>
                    ) : null}
                  </div>
                </div>
              ) : null}
            </div>
          ) : null}
        </FormSection>
      </div>

      <aside className="lg:sticky lg:top-24 lg:self-start">
        <div className="card overflow-hidden">
          <div className="panel-ink p-6">
            <p className="eyebrow !text-[var(--sky)]">Review economics</p>
            <h2 className="mt-2 text-2xl">One reserve, no ambiguity.</h2>
          </div>
          <div className="space-y-4 p-6">
            <OutcomeCard
              tint="var(--yellow-wash)"
              label="Reserve met"
              text="The winning entry receives the NFT. After successful delivery, you claim 95% of gross and the treasury claims 5%."
            />
            <OutcomeCard
              tint="var(--sky-wash)"
              label="Reserve missed"
              text="The winning entry receives 80% of gross sales. You recover the NFT plus 15% of gross, and the protocol receives 5%."
            />
            <div className="perforation !my-5" />
            <dl className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <dt className="text-[var(--ink-2)]">Protocol fee</dt>
                <dd className="font-extrabold">5% of gross</dd>
              </div>
              <div className="flex items-center justify-between">
                <dt className="text-[var(--ink-2)]">Sale starts</dt>
                <dd className="font-extrabold">Immediately</dd>
              </div>
            </dl>
            <p className="flex items-start gap-2 rounded-2xl bg-[var(--paper-sunk)] p-3 text-xs leading-5 text-[var(--ink-2)]">
              <CircleDollarSign
                aria-hidden
                className="mt-0.5 shrink-0"
                size={16}
              />
              <span>
                <strong className="numeric">
                  {form.reserveEntries || "—"} entries
                </strong>{" "}
                is the same as a{" "}
                <strong className="numeric">
                  ${form.reserveEntries || "—"} USDC
                </strong>{" "}
                gross reserve.
              </span>
            </p>
            {reserveEconomics ? (
              <p className="rounded-2xl bg-[var(--yellow-wash)] p-3 text-xs leading-5 text-[var(--ink-2)]">
                If the raffle ends at exactly that reserve, you receive{" "}
                <strong>
                  {formatTokenAmount(reserveEconomics.sponsorAmount, 6, "USDC")}
                </strong>{" "}
                after the 5% protocol fee. The reserve is a gross sales
                threshold, not your net payout.
              </p>
            ) : null}
            <p className="numeric break-all text-xs leading-5 text-[var(--ink-faint)]">
              Factory USDC: {quoteToken ?? "unavailable"}
            </p>
          </div>
        </div>
      </aside>
    </div>
  );
}

function FormSection({
  number,
  title,
  done = false,
  children,
}: {
  readonly number: string;
  readonly title: string;
  readonly done?: boolean;
  readonly children: React.ReactNode;
}) {
  return (
    <section className="card p-6 md:p-7">
      <div className="mb-6 flex items-center gap-3">
        <span
          className={`grid size-8 shrink-0 place-items-center rounded-full text-sm font-extrabold ${done ? "bg-[var(--grass)] text-white" : "bg-[var(--yellow)] text-[var(--ink)]"}`}
        >
          {done ? <Check aria-hidden size={16} /> : number}
        </span>
        <h2 className="text-xl md:text-2xl">{title}</h2>
      </div>
      {children}
    </section>
  );
}

function Field({
  label,
  value,
  onChange,
  onBlur,
  placeholder,
  error,
  type = "text",
}: {
  readonly label: string;
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly onBlur?: () => void;
  readonly placeholder?: string;
  readonly error?: string;
  readonly type?: string;
}) {
  return (
    <label className="block">
      <span className="field-label">{label}</span>
      <input
        aria-invalid={error !== undefined}
        className="input numeric"
        onBlur={onBlur}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        type={type}
        value={value}
      />
      {error ? <span className="field-error">{error}</span> : null}
    </label>
  );
}

function OutcomeCard({
  tint,
  label,
  text,
}: {
  readonly tint: string;
  readonly label: string;
  readonly text: string;
}) {
  return (
    <div className="rounded-2xl p-4" style={{ background: tint }}>
      <p className="font-extrabold">{label}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--ink-2)]">{text}</p>
    </div>
  );
}
