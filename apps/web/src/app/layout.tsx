import type { Metadata, Viewport } from "next";
import { Nunito } from "next/font/google";
import type { ReactNode } from "react";

import { ProtocolNotice } from "@/components/protocol-notice";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

import "./globals.css";
import { Providers } from "./providers";

const nunito = Nunito({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-nunito",
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
    <html lang="en" className={nunito.variable}>
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
