import { formatQuoteAmount } from "@raffle-fun/sdk";

export function shortAddress(address: `0x${string}`): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function formatTokenAmount(
  value: bigint,
  decimals: number | undefined,
  symbol: string,
): string {
  if (decimals === undefined)
    return `${value.toString()} raw units · ${symbol}`;
  const formatted = formatQuoteAmount(value, decimals);
  const [whole = "0", fraction = ""] = formatted.split(".");
  const groupedWhole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  const visibleFraction = fraction.slice(0, 6).replace(/0+$/, "");
  return `${groupedWhole}${visibleFraction ? `.${visibleFraction}` : ""} ${symbol}`;
}

export function formatDateTime(timestamp: bigint): string {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(Number(timestamp) * 1000));
}

export function formatCountdown(timestamp: bigint, now = Date.now()): string {
  const seconds = Math.max(0, Number(timestamp) - Math.floor(now / 1000));
  if (seconds === 0) return "Closed";
  const days = Math.floor(seconds / 86_400);
  const hours = Math.floor((seconds % 86_400) / 3_600);
  if (days > 0) return `${days}d ${hours}h`;
  const minutes = Math.floor((seconds % 3_600) / 60);
  return `${hours}h ${minutes}m`;
}

export function percentOf(value: bigint, total: bigint): number {
  if (total <= 0n) return 0;
  return Number((value * 10_000n) / total) / 100;
}
