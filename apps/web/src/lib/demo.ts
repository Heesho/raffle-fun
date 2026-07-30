/**
 * Preview-mode gate.
 *
 * The protocol never substitutes sample activity for real indexed state. This
 * flag is the single, explicit exception: when it is on, the app runs against
 * the offline model in `src/lib/sandbox/` instead of a chain and a subgraph,
 * so the product can be demonstrated before either exists.
 */
import { webEnv } from "./env";

export function isDemoMode(): boolean {
  if (webEnv.NEXT_PUBLIC_DEMO_MODE === "off") return false;
  if (webEnv.NEXT_PUBLIC_DEMO_MODE === "on") return true;
  // Auto: only when there is nothing real to show.
  return webEnv.NEXT_PUBLIC_SUBGRAPH_URL === undefined;
}
