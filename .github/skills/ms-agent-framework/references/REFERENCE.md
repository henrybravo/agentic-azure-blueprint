# Microsoft Agent Framework Reference

## Package Information

- **Package**: `agent-framework-ag-ui`
- **Min Version**: `1.0.0b251120`
- **PyPI**: Private Microsoft package (requires authentication)

## Core Classes

### ChatAgent

The main class for creating conversational agents.

```python
from agent_framework import ChatAgent

agent = ChatAgent(
    name: str,                    # Agent identifier
    instructions: str,            # System prompt / behavior instructions
    chat_client: BaseChatClient,  # The LLM client to use
    tools: list[Callable] = [],   # Optional tools the agent can use
)
```

### AzureOpenAIChatClient

Client for connecting to Azure OpenAI.

```python
from agent_framework.azure import AzureOpenAIChatClient
from azure.identity import AzureCliCredential, DefaultAzureCredential

client = AzureOpenAIChatClient(
    credential: TokenCredential,  # Azure credential
    endpoint: str,                # Azure OpenAI endpoint URL
    deployment_name: str,         # Model deployment name
)
```

## Tool Decorator

```python
from agent_framework import tool

@tool
def my_function(param1: str, param2: int = 10) -> str:
    """Description shown to the agent.
    
    Args:
        param1: Description of param1
        param2: Description of param2
    
    Returns:
        Description of return value
    """
    return "result"
```

## FastAPI Integration

```python
from agent_framework_ag_ui import add_agent_framework_fastapi_endpoint

add_agent_framework_fastapi_endpoint(
    app: FastAPI,     # Your FastAPI application
    agent: ChatAgent, # The agent to expose
    path: str = "/",  # URL path for the endpoint
)
```

## AG-UI Protocol

The agent framework implements the AG-UI (Agent-UI) protocol for frontend integration:

- **Endpoint**: `POST /` (or configured path)
- **Protocol**: Server-Sent Events (SSE) for streaming
- **Content-Type**: `text/event-stream`

### Event Types

| Event | Description |
|-------|-------------|
| `RUN_STARTED` | Agent run has begun |
| `TEXT_MESSAGE_START` | Beginning of a text message |
| `TEXT_MESSAGE_CONTENT` | Streaming text content |
| `TEXT_MESSAGE_END` | End of a text message |
| `TOOL_CALL_START` | Tool invocation started |
| `TOOL_CALL_ARGS` | Tool arguments being sent |
| `TOOL_CALL_END` | Tool invocation completed |
| `RUN_FINISHED` | Agent run completed |
| `RUN_ERROR` | Error occurred |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_OPENAI_ENDPOINT` | Yes | Azure OpenAI resource URL |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Yes | Model deployment name |
| `AZURE_CLIENT_ID` | No | For user-assigned managed identity |

## Authentication Options

### Local Development

```python
from azure.identity import AzureCliCredential
credential = AzureCliCredential()
```

### Production (Managed Identity)

```python
from azure.identity import DefaultAzureCredential
credential = DefaultAzureCredential()
```

### Service Principal

```python
from azure.identity import ClientSecretCredential
credential = ClientSecretCredential(
    tenant_id="...",
    client_id="...",
    client_secret="..."
)
```
