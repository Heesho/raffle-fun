import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import { ProtocolNotice } from "@/components/protocol-notice";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

import "./globals.css";
import { Providers } from "./providers";

export const metadata: Metadata = {
  metadataBase: new URL("https://raffle.fun"),
  title: {
    default: "raffles — Transparent NFT raffles on Base",
    template: "%s · raffles",
  },
  description:
    "Permissionless NFT raffles with transferable tickets, fixed economics, Pyth Entropy randomness, and chain-authoritative settlement.",
  openGraph: {
    title: "raffles",
    description: "A fair draw, in plain sight.",
    images: ["/og.png"],
  },
  twitter: {
    card: "summary_large_image",
    images: ["/og.png"],
  },
};

export const viewport: Viewport = {
  colorScheme: "light",
  themeColor: "#fff9e8",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <ProtocolNotice />
          <SiteHeader />
          <main>{children}</main>
          <SiteFooter />
        </Providers>
      </body>
    </html>
  );
}
