// Storage account for Echo audio + RSS feeds + catalog snapshots.
@minLength(4)
@maxLength(8)
param nameSuffix string
param location string
param tags object

var storageAccountName = toLower('stechoprod${nameSuffix}')

resource sa 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // managed-identity only
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: sa
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 7 }
    containerDeleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

// Single shared container for the demo. Per-user isolation handled via blob prefixes
// (echo-audio-{userSlug}/...) — created on demand by the Function.
resource defaultContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blobService
  name: 'echo-audio'
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = sa.name
output storageAccountId string = sa.id
output blobEndpoint string = sa.properties.primaryEndpoints.blob
