import type { ReactNode } from "react";

export type StatusTone = "neutral" | "active" | "warning" | "resolved" | "good";

/**
 * Status tones sit on a translucent white ground so they stay legible over
 * prize artwork without each one becoming its own saturated block.
 */
const tones: Record<StatusTone, string> = {
  neutral: "text-[var(--ink-2)]",
  active: "text-[var(--grass-deep)]",
  warning: "text-[var(--amber-ink)]",
  resolved: "text-[var(--sky-ink)]",
  good: "text-[var(--pink-ink)]",
};

export function StatusPill({
  children,
  tone = "neutral",
  pulse = false,
}: {
  readonly children: ReactNode;
  readonly tone?: StatusTone;
  readonly pulse?: boolean;
}) {
  return (
    <span className={`chip chip-overlay capitalize ${tones[tone]}`}>
      <span className="relative flex size-1.5">
        {pulse ? (
          <span className="absolute inline-flex size-full animate-ping rounded-full bg-current opacity-60" />
        ) : null}
        <span className="relative inline-flex size-1.5 rounded-full bg-current" />
      </span>
      {children}
    </span>
  );
}
