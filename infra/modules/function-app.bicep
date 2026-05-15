// Function App on Flex Consumption (Linux, Node 20).
// Storage uses managed identity (allowSharedKeyAccess=false on the SA).
param location string
param tags object
param storageAccountName string
param appInsightsConnectionString string
param keyVaultName string
param speechAccountName string
param speechRegion string

var functionAppName = 'func-echo-publisher'
var planName = 'plan-echo-flex'

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp,linux'
  properties: {
    reserved: true
  }
}

resource func 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployment'
          authentication: { type: 'SystemAssignedIdentity' }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'node'
        version: '20'
      }
    }
    siteConfig: {
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: storageAccount.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'STORAGE_ACCOUNT_NAME', value: storageAccount.name }
        { name: 'STORAGE_BLOB_ENDPOINT', value: storageAccount.properties.primaryEndpoints.blob }
        { name: 'SPEECH_REGION', value: speechRegion }
        { name: 'SPEECH_ACCOUNT_NAME', value: speechAccountName }
        { name: 'KEY_VAULT_NAME', value: keyVaultName }
        { name: 'DEFAULT_COVER_URL', value: '${storageAccount.properties.primaryEndpoints.blob}echo-audio/cover-default.jpg' }
      ]
    }
  }
}

output principalId string = func.identity.principalId
output defaultHostName string = func.properties.defaultHostName
output functionAppName string = func.name
