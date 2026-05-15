// Azure AI Foundry — hub + project for Echo specialist agents.
param location string
param tags object

var hubName = 'aih-echo-prod'
var projectName = 'aif-echo-prod'

// Foundry hub (CognitiveServices kind=AIServices is the new "Foundry account")
resource hub 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: hubName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: hubName
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
    disableLocalAuth: false
  }
}

#disable-next-line BCP081
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: hub
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    description: 'Echo: orchestrated agents that turn URLs into two-host podcasts.'
    displayName: 'Echo (prod)'
  }
}

// Default GPT-4o deployment for the agents
resource gpt4o 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: hub
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 50
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

output hubName string = hub.name
output projectName string = project.name
output projectEndpoint string = hub.properties.endpoint
#disable-next-line BCP053
output projectPrincipalId string = project.identity.principalId
