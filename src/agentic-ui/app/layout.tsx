import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Agentic Azure Blueprint",
  description: "Spec-driven agentic Azure blueprint — Next.js + FastAPI BFF + LangGraph orchestrator.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
