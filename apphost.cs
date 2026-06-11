

#:sdk Aspire.AppHost.Sdk@13.0.0
#:package Aspire.Hosting.Python@13.0.0
#:package Aspire.Hosting.JavaScript@13.0.0
#:package Aspire.Hosting.Azure.CognitiveServices@13.0.0
#:package Aspire.Hosting.Azure.AIFoundry@13.0.0-preview.1.25560.3

var builder = DistributedApplication.CreateBuilder(args);

var openAiEndpoint = builder.AddParameter("openAiEndpoint");
var openAiDeployment = builder.AddParameter("openAiDeployment");

// LangGraph orchestrator (Python, uvicorn). Holds the stateful agent graph; the BFF
// proxies to it. Reads the model endpoint/deployment so its example node can call the
// model. Replace the example graph with your domain agent (see src/orchestrator/graph.py).
var orchestrator = builder.AddUvicornApp("orchestrator", "./src/orchestrator", "main:app")
    .WithUv()
    .WithEnvironment("AZURE_OPENAI_ENDPOINT", openAiEndpoint)
    .WithEnvironment("AZURE_OPENAI_DEPLOYMENT_NAME", openAiDeployment)
    .WithExternalHttpEndpoints();

// FastAPI BFF. The browser only ever talks to this; it validates identity and proxies
// to the orchestrator. Replace the example routes with your domain API (src/agentic-api).
var api = builder.AddUvicornApp("agentic-api", "./src/agentic-api", "main:app")
    .WithUv()
    .WithEnvironment("AZURE_OPENAI_ENDPOINT", openAiEndpoint)
    .WithEnvironment("AZURE_OPENAI_DEPLOYMENT_NAME", openAiDeployment)
    .WithEnvironment("ORCHESTRATOR_URL", orchestrator.GetEndpoint("http"))
    .WithReference(orchestrator)
    .WaitFor(orchestrator)
    .WithExternalHttpEndpoints();

// Next.js SPA / BFF-fronted UI.
builder.AddJavaScriptApp("agentic-ui", "./src/agentic-ui")
    .WithRunScript("dev")
    .WithNpm(installCommand: "ci")
    .WithEnvironment("AGENT_API_URL", api.GetEndpoint("http"))
    .WithReference(api)
    .WaitFor(api)
    .WithHttpEndpoint(env: "PORT")
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
