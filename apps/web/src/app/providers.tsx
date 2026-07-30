"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { WagmiProvider } from "wagmi";

import { isDemoMode } from "@/lib/demo";
import { SandboxProvider } from "@/lib/sandbox/store";
import { wagmiConfig } from "@/lib/wagmi";

export function Providers({ children }: { readonly children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            refetchOnWindowFocus: false,
            staleTime: 12_000,
            retry: 1,
          },
        },
      }),
  );

  const body = isDemoMode() ? (
    <SandboxProvider>{children}</SandboxProvider>
  ) : (
    children
  );

  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>{body}</QueryClientProvider>
    </WagmiProvider>
  );
}
