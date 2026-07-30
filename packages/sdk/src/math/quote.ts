import { formatUnits } from "viem";

export function parseQuoteAmount(value: string, decimals: number): bigint {
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 255) {
    throw new RangeError("decimals must be an integer between 0 and 255");
  }
  const match = /^(0|[1-9]\d*)(?:\.(\d+))?$/.exec(value);
  if (match === null) {
    throw new TypeError("Use a plain nonnegative decimal amount");
  }
  const whole = match[1];
  const fraction = match[2] ?? "";
  if (whole === undefined) throw new TypeError("Invalid amount");
  if (fraction.length > decimals) {
    throw new RangeError(`Amount has more than ${decimals} decimal places`);
  }

  const scale = 10n ** BigInt(decimals);
  const fractionalRaw =
    fraction.length === 0 ? 0n : BigInt(fraction.padEnd(decimals, "0"));
  return BigInt(whole) * scale + fractionalRaw;
}

export function formatQuoteAmount(value: bigint, decimals: number): string {
  if (value < 0n) throw new RangeError("value must not be negative");
  return formatUnits(value, decimals);
}
