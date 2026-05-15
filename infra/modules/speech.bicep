// Azure AI Speech — S0 tier with HD voices (Ava + Andrew Dragon).
// May be deployed in West Europe if Sweden Central doesn't yet host the HD voices.
param location string
param tags object

var speechAccountName = 'spch-echo-prod'

resource speech 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: speechAccountName
  location: location
  tags: tags
  sku: { name: 'S0' }
  kind: 'SpeechServices'
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: speechAccountName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false // keep key auth on for now; v1.1 switches to MI
  }
}

output speechAccountName string = speech.name
output speechAccountId string = speech.id
output speechEndpoint string = speech.properties.endpoint
