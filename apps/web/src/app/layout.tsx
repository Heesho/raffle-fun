import type { Metadata, Viewport } from "next";
import { Inter, Nunito } from "next/font/google";
import type { ReactNode } from "react";

import { ProtocolNotice } from "@/components/protocol-notice";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

import "./globals.css";
import { Providers } from "./providers";

/** The brand voice: headings, the wordmark, display type. */
const nunito = Nunito({
  subsets: ["latin"],
  display: "swap",
  weight: ["700", "800"],
  variable: "--font-nunito",
});

/** Everything else. Body copy, UI, and every number in the product — a
 *  rounded display face makes prices and odds look like a game, not a ledger. */
const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://raffle.fun"),
  title: {
    default: "raffle.fun — a fair draw, in plain sight",
    template: "%s · raffle.fun",
  },
  description:
    "Permissionless NFT raffles on Ethereum with transferable tickets, fixed economics, Pyth Entropy randomness, and chain-authoritative settlement.",
  openGraph: {
    title: "raffle.fun",
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
  themeColor: "#fbfaff",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en" className={`${nunito.variable} ${inter.variable}`}>
      <body>
        <Providers>
          <a className="skip-link" href="#main">
            Skip to content
          </a>
          <ProtocolNotice />
          <SiteHeader />
          <main id="main">{children}</main>
          <SiteFooter />
        </Providers>
      </body>
    </html>
  );
}
