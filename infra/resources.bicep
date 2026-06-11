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

// --- User-assigned managed identity shared by the apps (no secrets in code) ---
module uami 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'uami'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

// --- Container Registry ---
module containerRegistry 'br/public:avm/res/container-registry/registry:0.5.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: false
    acrSku: 'Basic'
    roleAssignments: [
      {
        principalId: uami.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPull'
      }
    ]
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
var commonEnv = [
  {
    name: 'AZURE_CLIENT_ID'
    value: uami.outputs.clientId
  }
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
    managedIdentities: { userAssignedResourceIds: [uami.outputs.resourceId] }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: uami.outputs.resourceId
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
    managedIdentities: { userAssignedResourceIds: [uami.outputs.resourceId] }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: uami.outputs.resourceId
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
    managedIdentities: { userAssignedResourceIds: [uami.outputs.resourceId] }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: uami.outputs.resourceId
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

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_AGENTIC_API_ID string = agenticApi.outputs.resourceId
output AZURE_RESOURCE_AGENTIC_UI_ID string = agenticUi.outputs.resourceId
output AZURE_RESOURCE_ORCHESTRATOR_ID string = orchestrator.outputs.resourceId
