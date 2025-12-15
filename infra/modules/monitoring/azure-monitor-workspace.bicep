// Azure Monitor Workspace Module
// Provides Prometheus metrics storage and querying for AKS

@description('Name of the Azure Monitor Workspace')
param workspaceName string

@description('Azure region for deployment')
param location string

@description('Tags for the resource')
param tags object = {}

resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {}
}

@description('Resource ID of the Azure Monitor Workspace')
output workspaceId string = azureMonitorWorkspace.id

@description('Name of the Azure Monitor Workspace')
output workspaceName string = azureMonitorWorkspace.name

@description('Prometheus query endpoint')
output queryEndpoint string = azureMonitorWorkspace.properties.metrics.prometheusQueryEndpoint

@description('Internal ID of the Azure Monitor Workspace')
output internalId string = azureMonitorWorkspace.properties.metrics.internalId
