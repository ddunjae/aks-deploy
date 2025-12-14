// Network Security Group Module
@description('Name of the Network Security Group')
param nsgName string

@description('Location for the NSG')
param location string = resourceGroup().location

@description('Security rules for the NSG')
param securityRules array = []

@description('Tags for the resource')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [for rule in securityRules: {
      name: rule.name
      properties: {
        priority: rule.priority
        direction: rule.direction
        access: rule.access
        protocol: rule.protocol
        sourcePortRange: rule.sourcePortRange
        destinationPortRange: rule.destinationPortRange
        sourceAddressPrefix: rule.sourceAddressPrefix
        destinationAddressPrefix: rule.destinationAddressPrefix
        description: contains(rule, 'description') ? rule.description : null
      }
    }]
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name
