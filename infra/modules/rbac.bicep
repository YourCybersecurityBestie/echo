// RBAC role assignments for the Function App and Foundry project managed identities.
param functionAppPrincipalId string
param foundryProjectPrincipalId string
param storageAccountName string
param speechAccountName string
param keyVaultName string

resource sa 'Microsoft.Storage/storageAccounts@2024-01-01' existing = { name: storageAccountName }
resource speech 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: speechAccountName }
resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = { name: keyVaultName }

// Built-in role IDs
var storageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataReader = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var cognitiveServicesUser = 'a97b65f3-24c7-4388-baec-2e87135dc908'
var cognitiveServicesSpeechUser = 'f2dc8367-1007-4938-bd23-fe263f013447'
var keyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'

// Function App → Storage (read/write blobs and the deployment container)
resource funcStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sa
  name: guid(sa.id, functionAppPrincipalId, storageBlobDataContributor)
  properties: {
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributor)
  }
}

// Function App → Speech (call synthesize endpoint with MI)
resource funcSpeech 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: speech
  name: guid(speech.id, functionAppPrincipalId, cognitiveServicesSpeechUser)
  properties: {
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesSpeechUser)
  }
}

// Function App → Key Vault (read DirectLine secret etc.)
resource funcKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, functionAppPrincipalId, keyVaultSecretsUser)
  properties: {
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUser)
  }
}

// Foundry project → Storage (read briefs, episode metadata)
resource foundryStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sa
  name: guid(sa.id, foundryProjectPrincipalId, storageBlobDataReader)
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReader)
  }
}

// Foundry project → Speech (in case agents call Speech directly later)
resource foundrySpeech 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: speech
  name: guid(speech.id, foundryProjectPrincipalId, cognitiveServicesUser)
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUser)
  }
}
