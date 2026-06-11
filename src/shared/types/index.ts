// Shared types used across services (mirror your API contracts here).
// Replace these examples with your domain contracts (keep BFF <-> UI shapes in sync).

export interface ChatRequest {
  threadId: string;
  message: string;
}

export type TurnEvent =
  | { type: "delta"; text: string }
  | { type: "done"; answer: string; citations: unknown[] }
  | { type: "error"; code: string; partial?: string };
