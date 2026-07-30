"use client";

import { useEffect, useState } from "react";

import { formatCountdown } from "@/lib/format";

/**
 * A ticking countdown. Renders an empty string on the server and during the
 * first client pass so the markup cannot mismatch, then fills in and updates
 * every second.
 */
export function useCountdown(endTime: bigint): string {
  const [label, setLabel] = useState("");

  useEffect(() => {
    function tick() {
      setLabel(formatCountdown(endTime));
    }
    tick();
    const timer = setInterval(tick, 1_000);
    return () => clearInterval(timer);
  }, [endTime]);

  return label;
}
