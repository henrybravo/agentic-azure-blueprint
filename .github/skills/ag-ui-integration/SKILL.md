---
name: ag-ui-integration
description: Integrate AG-UI protocol with backend and frontend. Use this skill to connect a Next.js/React frontend to a Python agent backend using CopilotKit and the AG-UI protocol.
license: MIT
metadata:
  author: agentic-shell
  version: "1.0"
compatibility: Requires Next.js 16+, React 19+, and a backend implementing AG-UI protocol
---

# AG-UI Integration

This skill helps you integrate the AG-UI (Agent-UI) protocol to connect a frontend application with an AI agent backend using CopilotKit.

## When to Use

- Connecting a React/Next.js frontend to an AI agent backend
- Adding a chat sidebar or conversational UI to your application
- Implementing the AG-UI protocol for agent-frontend communication
- Building a BFF (Backend-for-Frontend) pattern with AI agents

## Architecture

```
Browser → Next.js (/api/copilotkit) → Python Backend (/) → Azure OpenAI
          └─ CopilotKit Runtime         └─ Agent Framework
```

The AG-UI protocol enables:
- Streaming responses from the agent
- Tool call visualization
- Message history management
- State synchronization

## Step-by-Step Instructions

### Backend Setup

First, ensure your backend implements the AG-UI protocol. See the `ms-agent-framework` skill for Python/FastAPI setup.

The backend should expose an endpoint (e.g., `POST /`) that:
- Accepts AG-UI protocol requests
- Returns Server-Sent Events (SSE) for streaming

### Frontend Setup

#### 1. Install Dependencies

```bash
cd src/agentic-ui
npm install @copilotkit/react-core @copilotkit/react-ui @copilotkit/runtime @ag-ui/client
```

Or add to `package.json`:

```json
{
  "dependencies": {
    "@ag-ui/client": "^0.0.41",
    "@copilotkit/react-core": "^1.10.6",
    "@copilotkit/react-ui": "^1.10.6",
    "@copilotkit/runtime": "^1.10.6",
    "next": "16.0.3",
    "react": "19.2.0",
    "react-dom": "19.2.0"
  }
}
```

#### 2. Create the API Route (BFF)

Create `app/api/copilotkit/route.ts`:

```typescript
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { HttpAgent } from "@ag-ui/client";
import { NextRequest } from "next/server";

// Use the empty adapter since we're routing to a single agent
const serviceAdapter = new ExperimentalEmptyAdapter();

// Create the CopilotRuntime with AG-UI HttpAgent
const runtime = new CopilotRuntime({
  agents: {
    my_agent: new HttpAgent({ 
      url: process.env.AGENT_API_URL || "http://localhost:8080" 
    }),
  },
});

// Handle POST requests
export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
```

#### 3. Configure Environment

Create `.env.local`:

```bash
AGENT_API_URL=http://localhost:8080
```

#### 4. Set Up the Layout Provider

Update `app/layout.tsx`:

```tsx
import { CopilotKit } from "@copilotkit/react-core"; 
import "@copilotkit/react-ui/styles.css";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Your App</title>
      </head>
      <body>
        <CopilotKit runtimeUrl="/api/copilotkit" agent="my_agent">
          {children}
        </CopilotKit>
      </body>
    </html>
  );
}
```

#### 5. Add the Chat UI

Update `app/page.tsx`:

```tsx
"use client";
import { CopilotSidebar } from "@copilotkit/react-ui";

export default function Page() {
  return (
    <CopilotSidebar
      defaultOpen={true}
      labels={{
        title: "AI Assistant",
        initial: "Hi! 👋 How can I help you today?",
        placeholder: "Ask me anything...",
      }}
      instructions="You are a helpful AI assistant."
    >
      <main>
        {/* Your app content here */}
      </main>
    </CopilotSidebar>
  );
}
```

## Alternative UI Components

### CopilotPopup

A floating chat popup:

```tsx
import { CopilotPopup } from "@copilotkit/react-ui";

<CopilotPopup
  labels={{
    title: "AI Assistant",
    initial: "How can I help?",
  }}
/>
```

### CopilotChat

An inline chat component:

```tsx
import { CopilotChat } from "@copilotkit/react-ui";

<div className="h-[600px]">
  <CopilotChat
    labels={{
      title: "Chat",
      placeholder: "Type a message...",
    }}
  />
</div>
```

### Custom UI with Hooks

Build your own UI:

```tsx
"use client";
import { useCopilotChat } from "@copilotkit/react-core";

export function CustomChat() {
  const { 
    visibleMessages, 
    appendMessage, 
    isLoading 
  } = useCopilotChat();

  return (
    <div>
      {visibleMessages.map((msg) => (
        <div key={msg.id}>{msg.content}</div>
      ))}
      <input 
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            appendMessage({ content: e.currentTarget.value, role: "user" });
          }
        }}
      />
    </div>
  );
}
```

## Multiple Agents

Configure multiple agents in the runtime:

```typescript
const runtime = new CopilotRuntime({
  agents: {
    support_agent: new HttpAgent({ url: "http://localhost:8080/support" }),
    sales_agent: new HttpAgent({ url: "http://localhost:8080/sales" }),
    technical_agent: new HttpAgent({ url: "http://localhost:8080/technical" }),
  },
});
```

Switch agents in the frontend:

```tsx
<CopilotKit runtimeUrl="/api/copilotkit" agent="support_agent">
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `AGENT_API_URL undefined` | Create `.env.local` with the URL |
| CORS errors | Add CORS headers to backend or use BFF pattern |
| Connection refused | Ensure backend is running on the specified port |
| Streaming not working | Check that backend sends proper SSE headers |
| Agent not responding | Verify agent name matches in runtime and CopilotKit |

## Running the Full Stack

1. Start the backend:
```bash
cd src/agentic-api
uv run fastapi dev main.py
```

2. Start the frontend:
```bash
cd src/agentic-ui
npm run dev
```

3. Open `http://localhost:3000` and start chatting!

## Related Skills

- Use the `ms-agent-framework` skill to set up the Python backend
