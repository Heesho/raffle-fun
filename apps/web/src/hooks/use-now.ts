"use client";

import { useEffect, useState } from "react";

/**
 * The current unix time in seconds, as state rather than a render-time
 * `Date.now()` read. Undefined on the server and during the first client pass,
 * so time-dependent UI cannot cause a hydration mismatch.
 */
export function useNow(intervalMs = 30_000): number | undefined {
  const [now, setNow] = useState<number>();

  useEffect(() => {
    const tick = () => setNow(Math.floor(Date.now() / 1000));
    tick();
    const timer = setInterval(tick, intervalMs);
    return () => clearInterval(timer);
  }, [intervalMs]);

  return now;
}

/**
 * The current unix time in milliseconds. The sandbox engine works in
 * `Date.now()` units, so comparing it against the seconds-based `useNow`
 * would leave every deadline permanently in the future.
 */
export function useNowMs(intervalMs = 1_000): number | undefined {
  const [now, setNow] = useState<number>();

  useEffect(() => {
    const tick = () => setNow(Date.now());
    tick();
    const timer = setInterval(tick, intervalMs);
    return () => clearInterval(timer);
  }, [intervalMs]);

  return now;
}
