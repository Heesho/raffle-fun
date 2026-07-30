import { AlertTriangle } from "lucide-react";

import { webEnvErrors } from "@/lib/env";

/**
 * Only a genuine misconfiguration is worth interrupting the page for.
 *
 * "No deployment registered on this network" is an expected state while the
 * protocol is pre-launch, so it is reported in the footer and inline on the
 * surfaces that actually need a signer, not as a persistent site-wide banner.
 */
export function ProtocolNotice() {
  if (webEnvErrors.length === 0) return null;

  return (
    <div
      className="bg-[var(--danger-wash)] px-4 py-2 text-center text-xs font-bold text-[var(--danger)]"
      role="status"
    >
      <span className="inline-flex items-center gap-2">
        <AlertTriangle aria-hidden size={14} />
        Configuration error: {webEnvErrors.join("; ")}
      </span>
    </div>
  );
}
