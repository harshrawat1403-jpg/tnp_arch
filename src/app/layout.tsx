import type { Metadata } from "next";

import { SiteFooter } from "@/components/layout/site-footer";
import { SiteHeader } from "@/components/layout/site-header";
import { getPublicEnvironment } from "@/lib/environment";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Training & Placement Office",
    template: "%s | Training & Placement Office",
  },
  description: "Training and Placement Office portal.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const environment = getPublicEnvironment();

  return (
    <html lang="en">
      <body data-environment={environment.nodeEnv}>
        <a className="skip-link" href="#main-content">
          Skip to main content
        </a>
        <div className="site-shell">
          <SiteHeader />
          <main id="main-content" className="site-main">
            {children}
          </main>
          <SiteFooter />
        </div>
      </body>
    </html>
  );
}
