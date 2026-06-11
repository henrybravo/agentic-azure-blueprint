targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@metadata({ azd: {
  type: 'location'
  usageName: [
    'OpenAI.GlobalStandard.gpt-4o-mini,10'
  ] }
})
@description('Location for the Azure AI Foundry model deployment.')
param aiDeploymentsLocation string

@description('Whether the agentic-api container app already exists (azd-managed).')
param agenticApiExists bool

@description('Whether the agentic-ui container app already exists (azd-managed).')
param agenticUiExists bool

@description('Whether the orchestrator container app already exists (azd-managed).')
param orchestratorExists bool

@description('Id of the user or app to assign application roles.')
param principalId string

@description('Principal type of user or app (User or ServicePrincipal).')
param principalType string

@description('Name of the model deployment exposed to the apps.')
param deploymentName string = 'gpt4oMiniDeployment'

var tags = {
  'azd-env-name': environmentName
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module aiModelsDeploy 'ai-project.bicep' = {
  scope: rg
  name: 'ai-project'
  params: {
    tags: tags
    location: aiDeploymentsLocation
    envName: environmentName
    principalId: principalId
    principalType: principalType
    deployments: [
      {
        name: deploymentName
        model: {
          name: 'gpt-4o-mini'
          format: 'OpenAI'
          version: '2024-07-18'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 10
        }
      }
    ]
  }
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    principalType: principalType
    agenticApiExists: agenticApiExists
    agenticUiExists: agenticUiExists
    orchestratorExists: orchestratorExists
    openAiEndpoint: aiModelsDeploy.outputs.OPENAI_ENDPOINT
    deploymentName: deploymentName
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_RESOURCE_AGENTIC_API_ID string = resources.outputs.AZURE_RESOURCE_AGENTIC_API_ID
output AZURE_RESOURCE_AGENTIC_UI_ID string = resources.outputs.AZURE_RESOURCE_AGENTIC_UI_ID
output AZURE_RESOURCE_ORCHESTRATOR_ID string = resources.outputs.AZURE_RESOURCE_ORCHESTRATOR_ID
output AZURE_AI_PROJECT_ENDPOINT string = aiModelsDeploy.outputs.ENDPOINT
output AZURE_OPENAI_ENDPOINT string = aiModelsDeploy.outputs.OPENAI_ENDPOINT
output AZURE_OPENAI_DEPLOYMENT_NAME string = deploymentName
