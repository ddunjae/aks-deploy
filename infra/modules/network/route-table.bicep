// Route Table Module
@description('Name of the Route Table')
param routeTableName string

@description('Location for the Route Table')
param location string = resourceGroup().location

@description('Routes for the Route Table')
param routes array = []

@description('Disable BGP route propagation')
param disableBgpRoutePropagation bool = false

@description('Tags for the resource')
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [for route in routes: {
      name: route.name
      properties: {
        addressPrefix: route.addressPrefix
        nextHopType: route.nextHopType
        nextHopIpAddress: contains(route, 'nextHopIpAddress') ? route.nextHopIpAddress : null
      }
    }]
  }
}

output routeTableId string = routeTable.id
output routeTableName string = routeTable.name
