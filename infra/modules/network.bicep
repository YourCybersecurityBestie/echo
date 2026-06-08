// VNet for Echo: Function App outbound VNet integration + private endpoints to storage.
// Lets the Publisher reach Blob/Queue/Table over the VNet so the storage account
// can keep publicNetworkAccess=Disabled without breaking the Functions host.
param location string
param tags object

@description('Address space for the Echo VNet.')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet for Function App VNet integration (delegated to Microsoft.App/environments). Flex Consumption requires a dedicated, empty, delegated subnet.')
param functionsSubnetPrefix string = '10.20.1.0/24'

@description('Subnet that hosts the storage private endpoints.')
param privateEndpointSubnetPrefix string = '10.20.2.0/28'

var vnetName = 'vnet-echo-prod'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ vnetAddressPrefix ]
    }
    subnets: [
      {
        name: 'snet-functions'
        properties: {
          addressPrefix: functionsSubnetPrefix
          // Flex Consumption outbound VNet integration delegation.
          delegations: [
            {
              name: 'flex-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-privateendpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output functionsSubnetId string = vnet.properties.subnets[0].id
output privateEndpointSubnetId string = vnet.properties.subnets[1].id
