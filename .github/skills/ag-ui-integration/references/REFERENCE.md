# AG-UI Integration Reference

## Packages

### Frontend (npm)

| Package | Version | Purpose |
|---------|---------|---------|
| `@copilotkit/react-core` | `^1.10.6` | Core React hooks and context |
| `@copilotkit/react-ui` | `^1.10.6` | Pre-built UI components |
| `@copilotkit/runtime` | `^1.10.6` | Server-side runtime |
| `@ag-ui/client` | `^0.0.41` | AG-UI protocol client |

### Backend (Python)

| Package | Version | Purpose |
|---------|---------|---------|
| `agent-framework-ag-ui` | `>=1.0.0b251120` | Agent framework with AG-UI |

## CopilotKit Components

### CopilotKit Provider

The root provider that enables CopilotKit functionality:

```tsx
<CopilotKit 
  runtimeUrl="/api/copilotkit"  // API route URL
  agent="my_agent"               // Agent name from runtime config
>
  {children}
</CopilotKit>
```

### CopilotSidebar

```tsx
<CopilotSidebar
  defaultOpen={boolean}          // Open by default?
  clickOutsideToClose={boolean}  // Close on outside click
  labels={{
    title: string,               // Sidebar title
    initial: string,             // Initial message
    placeholder: string,         // Input placeholder
  }}
  instructions={string}          // System instructions
  className={string}             // Custom CSS class
/>
```

### CopilotPopup

```tsx
<CopilotPopup
  defaultOpen={boolean}
  labels={{
    title: string,
    initial: string,
    placeholder: string,
  }}
  instructions={string}
/>
```

### CopilotChat

```tsx
<CopilotChat
  labels={{
    title: string,
    placeholder: string,
    stopGenerating: string,
  }}
  instructions={string}
  className={string}
/>
```

## React Hooks

### useCopilotChat

Access chat state and methods:

```tsx
const {
  visibleMessages,    // Message[] - visible messages
  appendMessage,      // (msg: Message) => void
  setMessages,        // (msgs: Message[]) => void
  deleteMessage,      // (id: string) => void
  reloadMessages,     // () => void
  stopGeneration,     // () => void
  isLoading,          // boolean
} = useCopilotChat();
```

### useCopilotAction

Define frontend actions the agent can call:

```tsx
useCopilotAction({
  name: "showNotification",
  description: "Display a notification to the user",
  parameters: [
    { name: "message", type: "string", required: true },
    { name: "type", type: "string", enum: ["info", "warning", "error"] },
  ],
  handler: async ({ message, type }) => {
    // Handle the action
    toast[type](message);
    return "Notification shown";
  },
});
```

### useCopilotReadable

Provide context to the agent:

```tsx
useCopilotReadable({
  description: "The current user's profile",
  value: JSON.stringify({
    name: user.name,
    role: user.role,
    preferences: user.preferences,
  }),
});
```

## CopilotRuntime Configuration

```typescript
const runtime = new CopilotRuntime({
  agents: {
    [agentName: string]: HttpAgent | LangGraphAgent,
  },
  // Optional: middleware
  middleware: {
    onRequest?: (req) => req,
    onResponse?: (res) => res,
  },
});
```

## HttpAgent Options

```typescript
new HttpAgent({
  url: string,              // Backend URL
  headers?: Record<string, string>,  // Custom headers
  timeout?: number,         // Request timeout (ms)
});
```

## AG-UI Protocol Events

| Event | Payload | Description |
|-------|---------|-------------|
| `RUN_STARTED` | `{ runId }` | Agent run initiated |
| `TEXT_MESSAGE_START` | `{ messageId }` | Text message starting |
| `TEXT_MESSAGE_CONTENT` | `{ delta }` | Streaming text chunk |
| `TEXT_MESSAGE_END` | `{}` | Text message complete |
| `TOOL_CALL_START` | `{ toolCallId, toolName }` | Tool invocation starting |
| `TOOL_CALL_ARGS` | `{ delta }` | Tool arguments streaming |
| `TOOL_CALL_END` | `{}` | Tool invocation complete |
| `RUN_FINISHED` | `{}` | Agent run complete |
| `RUN_ERROR` | `{ error }` | Error occurred |

## Environment Variables

### Frontend (.env.local)

```bash
AGENT_API_URL=http://localhost:8080
```

### Production

```bash
AGENT_API_URL=https://your-backend.azurecontainerapps.io
```

## CSS Customization

Import the default styles:

```tsx
import "@copilotkit/react-ui/styles.css";
```

Override with CSS variables:

```css
:root {
  --copilot-kit-primary-color: #0066cc;
  --copilot-kit-background-color: #ffffff;
  --copilot-kit-text-color: #333333;
  --copilot-kit-border-radius: 8px;
}
```

## Message Types

```typescript
interface Message {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  createdAt: Date;
  // For tool calls
  toolCalls?: ToolCall[];
  toolResults?: ToolResult[];
}

interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

interface ToolResult {
  toolCallId: string;
  result: unknown;
}
```
