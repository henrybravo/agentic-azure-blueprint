@description('Primary location for all resources.')
param location string

@description('Tags applied to every resource.')
param tags object

@description('Id of the user or app to assign application roles.')
param principalId string

@description('Principal type of user or app (User or ServicePrincipal).')
param principalType string

param agenticApiExists bool
param agenticUiExists bool
param orchestratorExists bool

@description('Azure OpenAI endpoint injected into the apps.')
param openAiEndpoint string

@description('Model deployment name injected into the apps.')
param deploymentName string

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, resourceGroup().id, location))

// --- Observability: Log Analytics + Application Insights ---
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.1' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
  }
}

// --- Identity model: SYSTEM-ASSIGNED managed identity ---
// This variant uses a system-assigned managed identity per Container App instead of a shared
// user-assigned identity (UAMI). Use it where Azure Policy blocks
// `Microsoft.ManagedIdentity/userAssignedIdentities` (common in regulated/FSI tenants).
// Trade-offs vs. UAMI: one identity per app (no shared identity), RBAC can only be assigned
// after the app exists, and the identity is deleted with the app. See the ACR-pull role
// assignments at the bottom of this file.

// --- Container Registry ---
// AcrPull is granted to each app's system-assigned identity AFTER the apps exist (see below),
// because a system-assigned principalId does not exist until its resource is created.
module containerRegistry 'br/public:avm/res/container-registry/registry:0.5.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: false
    acrSku: 'Basic'
  }
}

// --- Container Apps managed environment ---
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.8.0' = {
  name: 'container-apps-environment'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    zoneRedundant: false
  }
}

var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
// No AZURE_CLIENT_ID: a system-assigned identity is auto-detected by DefaultAzureCredential.
var commonEnv = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: monitoring.outputs.applicationInsightsConnectionString
  }
  {
    name: 'AZURE_OPENAI_ENDPOINT'
    value: openAiEndpoint
  }
  {
    name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
    value: deploymentName
  }
]

// --- orchestrator (internal) ---
module orchestrator 'br/public:avm/res/app/container-app:0.11.0' = {
  name: 'orchestrator'
  params: {
    name: 'orchestrator'
    location: location
    tags: union(tags, { 'azd-service-name': 'orchestrator' })
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: 'system'
      }
    ]
    ingressExternal: false
    ingressTargetPort: 8000
    containers: [
      {
        name: 'orchestrator'
        image: orchestratorExists ? '${containerRegistry.outputs.loginServer}/orchestrator:latest' : placeholderImage
        env: commonEnv
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
      }
    ]
  }
}

// --- agentic-api (BFF, internal — reachable only via the UI server-side proxy) ---
module agenticApi 'br/public:avm/res/app/container-app:0.11.0' = {
  name: 'agentic-api'
  params: {
    name: 'agentic-api'
    location: location
    tags: union(tags, { 'azd-service-name': 'agentic-api' })
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: 'system'
      }
    ]
    ingressExternal: false
    ingressTargetPort: 8080
    containers: [
      {
        name: 'agentic-api'
        image: agenticApiExists ? '${containerRegistry.outputs.loginServer}/agentic-api:latest' : placeholderImage
        env: union(commonEnv, [
          {
            name: 'ORCHESTRATOR_URL'
            value: 'https://${orchestrator.outputs.fqdn}'
          }
        ])
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
      }
    ]
  }
}

// --- agentic-ui (external) ---
module agenticUi 'br/public:avm/res/app/container-app:0.11.0' = {
  name: 'agentic-ui'
  params: {
    name: 'agentic-ui'
    location: location
    tags: union(tags, { 'azd-service-name': 'agentic-ui' })
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: 'system'
      }
    ]
    ingressExternal: true
    ingressTargetPort: 3000
    containers: [
      {
        name: 'agentic-ui'
        image: agenticUiExists ? '${containerRegistry.outputs.loginServer}/agentic-ui:latest' : placeholderImage
        env: [
          {
            name: 'AGENT_API_URL'
            value: 'https://${agenticApi.outputs.fqdn}'
          }
        ]
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
      }
    ]
  }
}

// --- AcrPull for each app's system-assigned identity ---
// Assigned after the apps exist, since a system-assigned principalId is created with its app.
// First deploy runs the public placeholder image (no ACR pull needed); `azd deploy` then pushes
// the real images, which the now-authorized system identities can pull.
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: '${abbrs.containerRegistryRegistries}${resourceToken}'
}

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource orchestratorAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResource
  name: guid(acrResource.id, 'orchestrator', acrPullRoleDefinitionId)
  properties: {
    principalId: orchestrator.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

resource agenticApiAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResource
  name: guid(acrResource.id, 'agentic-api', acrPullRoleDefinitionId)
  properties: {
    principalId: agenticApi.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

resource agenticUiAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResource
  name: guid(acrResource.id, 'agentic-ui', acrPullRoleDefinitionId)
  properties: {
    principalId: agenticUi.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

// NOTE: Model access is intentionally NOT granted to the apps here. Model egress is mandatory
// through the APIM AI Gateway (guarded behind `deployApim`, see azure-deployment-requirements.md
// B.2 and lld §5/§6), where APIM's own system-assigned identity holds the Cognitive Services role
// on the AI account. Granting the orchestrator direct data-plane access would bypass the gateway's
// guardrails. Local dev calls the model as the developer's own identity (granted in ai-project.bicep).

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_AGENTIC_API_ID string = agenticApi.outputs.resourceId
output AZURE_RESOURCE_AGENTIC_UI_ID string = agenticUi.outputs.resourceId
output AZURE_RESOURCE_ORCHESTRATOR_ID string = orchestrator.outputs.resourceId
