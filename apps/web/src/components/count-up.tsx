"use client";

import { useEffect, useRef, useState } from "react";

const DURATION = 620;

/**
 * A number that tweens to its new value and flashes when it lands, so a live
 * ticket count reads as movement rather than a silent swap.
 */
export function CountUp({
  value,
  className = "",
}: {
  readonly value: number;
  readonly className?: string;
}) {
  const [display, setDisplay] = useState(value);
  const [bumping, setBumping] = useState(false);
  const previous = useRef(value);
  const frame = useRef(0);

  useEffect(() => {
    const from = previous.current;
    previous.current = value;
    if (from === value) return;

    // Large jumps (a fresh page of data) should not crawl through every step.
    if (Math.abs(value - from) > 500) {
      setDisplay(value);
      return;
    }

    setBumping(true);
    const started = performance.now();
    const step = (now: number) => {
      // Clamped at both ends: an unclamped negative progress feeds a cubic
      // ease and sends the displayed value wildly below the real one.
      const progress = Math.min(1, Math.max(0, (now - started) / DURATION));
      const eased = 1 - (1 - progress) ** 3;
      setDisplay(Math.round(from + (value - from) * eased));
      if (progress < 1) frame.current = requestAnimationFrame(step);
    };
    frame.current = requestAnimationFrame(step);
    const settle = setTimeout(() => setBumping(false), DURATION);

    return () => {
      cancelAnimationFrame(frame.current);
      clearTimeout(settle);
    };
  }, [value]);

  return (
    <span className={`numeric ${bumping ? "bump" : ""} ${className}`}>
      {display.toLocaleString()}
    </span>
  );
}
