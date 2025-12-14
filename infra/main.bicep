// Main Bicep Template for AKS Demo Environment
// This template deploys a Hub-Spoke network topology with AKS cluster
targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Location for all resources')
param location string = 'koreacentral'

@description('Resource group name')
param resourceGroupName string = 'rg-aks-network-demo'

@description('Environment tag')
param environment string = 'Demo'

@description('Hub VNet address prefix')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Spoke VNet address prefix')
param spokeVnetAddressPrefix string = '10.1.0.0/16'

@description('AKS Service CIDR')
param aksServiceCidr string = '10.2.0.0/16'

@description('AKS DNS Service IP')
param aksDnsServiceIp string = '10.2.0.10'

@description('AKS cluster name')
param aksClusterName string = 'aks-demo-cluster'

@description('Kubernetes version')
param kubernetesVersion string = '1.32'

@description('AKS system node pool VM size')
param aksSystemNodeVmSize string = 'Standard_DS2_v2'

@description('ACR name (must be globally unique)')
param acrName string

@description('Jumpbox admin username')
param jumpboxAdminUsername string = 'conortest'

@description('Jumpbox admin password')
@secure()
param jumpboxAdminPassword string

@description('SSH public key for AKS nodes')
param sshPublicKey string

// ============================================================================
// Variables
// ============================================================================

var tags = {
  Environment: environment
  Purpose: 'AKS Demo Cluster'
}

// Hub Subnets
var hubSubnets = [
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '10.0.1.0/24'
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '10.0.2.0/24'
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.0.3.0/26'
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.4.0/24'
    nsgId: ''
    routeTableId: ''
  }
]

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ============================================================================
// Network Security Groups
// ============================================================================

module nsgAksNodes 'modules/network/nsg.bicep' = {
  name: 'nsg-aks-nodes-deployment'
  scope: rg
  params: {
    nsgName: 'nsg-aks-nodes'
    location: location
    tags: union(tags, { Purpose: 'AKS Node NSG' })
    securityRules: [
      {
        name: 'Allow-HTTP-Inbound'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
        description: 'Allow HTTP traffic from Internet'
      }
    ]
  }
}

module nsgAppGw 'modules/network/nsg.bicep' = {
  name: 'nsg-appgw-deployment'
  scope: rg
  params: {
    nsgName: 'nsg-appgw'
    location: location
    tags: union(tags, { Purpose: 'App Gateway NSG' })
    securityRules: [
      {
        name: 'Allow-GatewayManager'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '65200-65535'
        sourceAddressPrefix: 'GatewayManager'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-HTTP'
        priority: 110
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-HTTPS'
        priority: 120
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
      }
    ]
  }
}

module nsgJumpbox 'modules/network/nsg.bicep' = {
  name: 'nsg-jumpbox-deployment'
  scope: rg
  params: {
    nsgName: 'nsg-jumpbox'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'default-allow-ssh'
        priority: 1000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
      }
    ]
  }
}

// ============================================================================
// Route Table
// ============================================================================

module routeTable 'modules/network/route-table.bicep' = {
  name: 'rt-aks-spoke-deployment'
  scope: rg
  params: {
    routeTableName: 'rt-aks-spoke'
    location: location
    tags: union(tags, { Purpose: 'AKS Route Table' })
    disableBgpRoutePropagation: false
    routes: []
  }
}

// ============================================================================
// Virtual Networks
// ============================================================================

module vnetHub 'modules/network/vnet.bicep' = {
  name: 'vnet-hub-deployment'
  scope: rg
  params: {
    vnetName: 'vnet-hub'
    location: location
    tags: union(tags, { Purpose: 'Hub VNet' })
    addressPrefixes: [hubVnetAddressPrefix]
    subnets: hubSubnets
  }
}

module vnetSpoke 'modules/network/vnet.bicep' = {
  name: 'vnet-spoke-aks-deployment'
  scope: rg
  dependsOn: [nsgAksNodes, nsgAppGw, routeTable]
  params: {
    vnetName: 'vnet-spoke-aks'
    location: location
    tags: union(tags, { Purpose: 'AKS Spoke VNet' })
    addressPrefixes: [spokeVnetAddressPrefix]
    subnets: [
      {
        name: 'snet-aks-system'
        addressPrefix: '10.1.1.0/24'
        nsgId: nsgAksNodes.outputs.nsgId
        routeTableId: routeTable.outputs.routeTableId
      }
      {
        name: 'snet-aks-user'
        addressPrefix: '10.1.2.0/23'
        nsgId: nsgAksNodes.outputs.nsgId
        routeTableId: routeTable.outputs.routeTableId
      }
      {
        name: 'snet-aks-ilb'
        addressPrefix: '10.1.4.0/24'
        nsgId: ''
        routeTableId: ''
      }
      {
        name: 'snet-appgw'
        addressPrefix: '10.1.5.0/24'
        nsgId: nsgAppGw.outputs.nsgId
        routeTableId: ''
      }
      {
        name: 'snet-privateendpoint'
        addressPrefix: '10.1.10.0/24'
        nsgId: ''
        routeTableId: ''
      }
    ]
  }
}

// ============================================================================
// VNet Peering
// ============================================================================

module peeringHubToSpoke 'modules/network/vnet-peering.bicep' = {
  name: 'peer-hub-to-spoke-aks-deployment'
  scope: rg
  dependsOn: [vnetHub, vnetSpoke]
  params: {
    peeringName: 'peer-hub-to-spoke-aks'
    localVnetName: 'vnet-hub'
    remoteVnetId: vnetSpoke.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
  }
}

module peeringSpokeToHub 'modules/network/vnet-peering.bicep' = {
  name: 'peer-spoke-aks-to-hub-deployment'
  scope: rg
  dependsOn: [vnetHub, vnetSpoke]
  params: {
    peeringName: 'peer-spoke-aks-to-hub'
    localVnetName: 'vnet-spoke-aks'
    remoteVnetId: vnetHub.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
  }
}

// ============================================================================
// Azure Container Registry
// ============================================================================

module acr 'modules/acr/acr.bicep' = {
  name: 'acr-deployment'
  scope: rg
  params: {
    acrName: acrName
    location: location
    tags: union(tags, { Purpose: 'AKS Demo ACR' })
    skuName: 'Basic'
    adminUserEnabled: true
    publicNetworkAccess: true
  }
}

// ============================================================================
// AKS Cluster
// ============================================================================

module aksCluster 'modules/aks/aks-cluster.bicep' = {
  name: 'aks-cluster-deployment'
  scope: rg
  dependsOn: [vnetSpoke]
  params: {
    aksClusterName: aksClusterName
    location: location
    tags: tags
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${aksClusterName}-${uniqueString(rg.id)}'
    skuTier: 'Free'
    enableRbac: true
    systemNodePool: {
      name: 'systempool'
      count: 1
      vmSize: aksSystemNodeVmSize
      osDiskSizeGB: 128
      osDiskType: 'Managed'
      subnetId: vnetSpoke.outputs.subnetIds[0] // snet-aks-system
      enableAutoScaling: true
      minCount: 1
      maxCount: 10
      maxPods: 30
      maxSurge: '10%'
      tags: { Environment: environment }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkDataplane: 'azure'
      serviceCidr: aksServiceCidr
      dnsServiceIP: aksDnsServiceIp
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    linuxProfile: {
      adminUsername: 'azureuser'
      sshPublicKey: sshPublicKey
    }
  }
}

// ============================================================================
// Jumpbox VM
// ============================================================================

module jumpboxVm 'modules/compute/jumpbox-vm.bicep' = {
  name: 'jumpbox-vm-deployment'
  scope: rg
  dependsOn: [vnetHub, nsgJumpbox]
  params: {
    vmName: 'vm-jumpbox'
    location: location
    tags: tags
    vmSize: 'Standard_B2s'
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    subnetId: vnetHub.outputs.subnetIds[3] // snet-management
    createPublicIp: true
    nsgId: nsgJumpbox.outputs.nsgId
  }
}

// ============================================================================
// Role Assignments - AKS to ACR
// ============================================================================

module acrPullRoleAssignment 'modules/identity/role-assignment.bicep' = {
  name: 'acr-pull-role-assignment'
  scope: rg
  dependsOn: [aksCluster, acr]
  params: {
    principalId: aksCluster.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
  }
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output aksClusterName string = aksCluster.outputs.aksClusterName
output aksClusterFqdn string = aksCluster.outputs.aksClusterFqdn
output acrLoginServer string = acr.outputs.acrLoginServer
output jumpboxPublicIp string = jumpboxVm.outputs.vmPublicIp
output hubVnetId string = vnetHub.outputs.vnetId
output spokeVnetId string = vnetSpoke.outputs.vnetId
