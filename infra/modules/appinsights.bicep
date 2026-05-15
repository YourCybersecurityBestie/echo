// App Insights — workspace-based, attached to the SHARED law-uksouth.
param location string
param tags object
@description('Full resource ID of the shared Log Analytics workspace.')
param sharedLawId string

resource ai 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-echo-prod'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: sharedLawId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output connectionString string = ai.properties.ConnectionString
output instrumentationKey string = ai.properties.InstrumentationKey
output appInsightsId string = ai.id
