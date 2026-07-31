import { thresholdScale } from "@/lib/economics";

/**
 * Progress toward the NFT threshold.
 *
 * The track keeps headroom past the threshold so the flip point reads as a
 * line the fill is travelling towards, and any overshoot stays visible as a
 * distinct segment instead of a bar that is simply "full".
 */
export function ThresholdBar({
  total,
  minimum,
  size = "sm",
}: {
  readonly total: bigint;
  readonly minimum: bigint;
  readonly size?: "sm" | "lg";
}) {
  const { fillPercent, markerPercent, overshootPercent, met } = thresholdScale(
    total,
    minimum,
  );

  return (
    <div
      aria-label={`${total} of ${minimum} tickets toward the NFT threshold`}
      aria-valuemax={Number(minimum)}
      aria-valuemin={0}
      aria-valuenow={Number(total)}
      className={`progress-track ${size === "lg" ? "!h-2.5" : ""}`}
      role="progressbar"
    >
      {/* Sales up to the threshold. */}
      <div
        className="progress-fill"
        data-met={met}
        style={{ width: `${fillPercent}%` }}
      />
      {/* Sales past it, so overshoot is legible rather than invisible. */}
      {overshootPercent > 0 ? (
        <div
          className="absolute inset-y-0 rounded-r-full bg-[var(--grass)]"
          style={{
            left: `${markerPercent}%`,
            width: `${overshootPercent}%`,
          }}
        />
      ) : null}
      {/* The flip point. A hairline gap keeps it readable against the fill. */}
      {markerPercent > 0 && markerPercent < 100 ? (
        <span
          aria-hidden
          className="absolute inset-y-0 w-[3px] -translate-x-1/2 border-x border-[var(--paper-raised)] bg-[var(--ink)]"
          style={{ left: `${markerPercent}%` }}
        />
      ) : null}
    </div>
  );
}
