// Private endpoints + private DNS for the Echo storage account (blob, queue, table).
// Required so the VNet-integrated Function App resolves and reaches storage privately
// while the account keeps publicNetworkAccess=Disabled.
param location string
param tags object
param storageAccountName string
param privateEndpointSubnetId string
param vnetId string

// Sub-resource types the Publisher uses: blob (deployment package + audio + SSML),
// queue (synth-jobs trigger), table (job state).
var services = [
  'blob'
  'queue'
  'table'
]

resource sa 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for svc in services: {
  name: 'privatelink.${svc}.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}]

resource dnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (svc, i) in services: {
  parent: dnsZones[i]
  name: 'link-to-vnet-echo'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [for svc in services: {
  name: 'pe-${storageAccountName}-${svc}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${svc}'
        properties: {
          privateLinkServiceId: sa.id
          groupIds: [ svc ]
        }
      }
    ]
  }
}]

resource dnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [for (svc, i) in services: {
  parent: privateEndpoints[i]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${svc}-config'
        properties: {
          privateDnsZoneId: dnsZones[i].id
        }
      }
    ]
  }
}]
