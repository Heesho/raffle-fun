import { AlertTriangle } from "lucide-react";

import { configuredChain, protocolIsConfigured } from "@/lib/protocol";
import { webEnvErrors } from "@/lib/env";

export function ProtocolNotice() {
  if (protocolIsConfigured && webEnvErrors.length === 0) return null;

  return (
    <div
      className="border-b border-amber-900/20 bg-amber-100 px-4 py-2 text-center text-xs font-semibold text-amber-950"
      role="status"
    >
      <span className="inline-flex items-center gap-2">
        <AlertTriangle aria-hidden size={14} />
        {webEnvErrors.length > 0
          ? `Configuration error: ${webEnvErrors.join("; ")}`
          : `No verified raffles deployment is registered for ${configuredChain.name}. Browsing remains available; transactions are disabled.`}
      </span>
    </div>
  );
}
