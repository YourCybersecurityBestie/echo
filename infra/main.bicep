// Echo — root infra (subscription scope)
// Creates rg-echo-prod in Sweden Central and deploys all per-resource modules.
// Reuses (does NOT recreate): law-uksouth in sentinel-goodies RG.
// Deploy:
//   az deployment sub create --location swedencentral \
//     --template-file infra/main.bicep \
//     --parameters infra/main.parameters.json

targetScope = 'subscription'

@description('Short suffix appended to globally-unique resource names. Lowercase letters/digits, 4-8 chars.')
@minLength(4)
@maxLength(8)
param nameSuffix string

@description('Primary region for compute, storage, Speech, Foundry.')
param location string = 'swedencentral'

@description('Region used for the Speech account if HD voices are not in the primary region. Set equal to location to deploy in-region.')
param speechLocation string = 'westeurope'

@description('Resource group of the SHARED Log Analytics workspace to attach App Insights to.')
param sharedLawResourceGroup string = 'sentinel-goodies'

@description('Name of the SHARED Log Analytics workspace.')
param sharedLawName string = 'law-uksouth'

@description('Object ID of the human/service principal that owns this deployment (gets Key Vault Administrator).')
param ownerObjectId string

@description('Public network access for the storage account. The Function App reaches storage over private endpoints; the Listener reads blobs through the Publisher proxy (/api/feed, /api/audio, /api/cover). Kept Disabled as the durable state. Only set Enabled temporarily if you need to roll back the proxy.')
@allowed([
  'Enabled'
  'Disabled'
])
param storagePublicNetworkAccess string = 'Disabled'

@description('Tags applied to every resource.')
param tags object = {
  project: 'echo'
  environment: 'prod'
  owner: 'vesolomons'
  costCenter: 'demo'
}

var rgName = 'rg-echo-prod'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

// Look up the shared LAW (cross-RG reference, no creation)
resource sharedLaw 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(sharedLawResourceGroup)
  name: sharedLawName
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    nameSuffix: nameSuffix
    location: location
    tags: tags
    publicNetworkAccess: storagePublicNetworkAccess
  }
}

module network 'modules/network.bicep' = {
  scope: rg
  name: 'network'
  params: {
    location: location
    tags: tags
  }
}

// Private endpoints + private DNS for blob/queue/table so the VNet-integrated
// Function App reaches storage while publicNetworkAccess stays Disabled.
module privateEndpoints 'modules/private-endpoints.bicep' = {
  scope: rg
  name: 'privateEndpoints'
  params: {
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
  }
}

module keyvault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    nameSuffix: nameSuffix
    location: location
    tags: tags
    ownerObjectId: ownerObjectId
  }
}

module speech 'modules/speech.bicep' = {
  scope: rg
  name: 'speech'
  params: {
    location: speechLocation
    tags: tags
  }
}

module appInsights 'modules/appinsights.bicep' = {
  scope: rg
  name: 'appInsights'
  params: {
    location: location
    tags: tags
    sharedLawId: sharedLaw.id
  }
}

module functionApp 'modules/function-app.bicep' = {
  scope: rg
  name: 'functionApp'
  // Ensure private endpoints + DNS exist before the host starts pulling its package.
  dependsOn: [
    privateEndpoints
  ]
  params: {
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    appInsightsConnectionString: appInsights.outputs.connectionString
    keyVaultName: keyvault.outputs.keyVaultName
    speechAccountName: speech.outputs.speechAccountName
    speechRegion: speechLocation
    functionsSubnetId: network.outputs.functionsSubnetId
    staticWebAppUrl: 'https://${staticWebApp.outputs.defaultHostName}'
  }
}

module staticWebApp 'modules/static-web-app.bicep' = {
  scope: rg
  name: 'staticWebApp'
  params: {
    location: 'westeurope' // SWA is not GA in Sweden Central yet; West Europe is closest
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = {
  scope: rg
  name: 'foundry'
  params: {
    location: location
    tags: tags
  }
}

// RBAC — grant the Function App MI access to Storage, Speech, Key Vault
module rbac 'modules/rbac.bicep' = {
  scope: rg
  name: 'rbac'
  params: {
    functionAppPrincipalId: functionApp.outputs.principalId
    foundryProjectPrincipalId: foundry.outputs.projectPrincipalId
    storageAccountName: storage.outputs.storageAccountName
    speechAccountName: speech.outputs.speechAccountName
    keyVaultName: keyvault.outputs.keyVaultName
  }
}

output resourceGroupName string = rg.name
output functionAppHost string = functionApp.outputs.defaultHostName
output staticWebAppHost string = staticWebApp.outputs.defaultHostName
output foundryProjectEndpoint string = foundry.outputs.projectEndpoint
output speechRegion string = speechLocation
output keyVaultName string = keyvault.outputs.keyVaultName
output appInsightsConnectionString string = appInsights.outputs.connectionString
output vnetId string = network.outputs.vnetId
output storagePublicNetworkAccess string = storagePublicNetworkAccess
