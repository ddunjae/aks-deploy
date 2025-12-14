// AKS Cluster Module
@description('Name of the AKS cluster')
param aksClusterName string

@description('Location for the AKS cluster')
param location string = resourceGroup().location

@description('Kubernetes version')
param kubernetesVersion string = '1.32'

@description('DNS prefix for the cluster')
param dnsPrefix string

@description('System node pool configuration')
param systemNodePool object

@description('User node pools configuration')
param userNodePools array = []

@description('Network profile configuration')
param networkProfile object

@description('Linux profile configuration')
param linuxProfile object = {}

@description('Enable RBAC')
param enableRbac bool = true

@description('AKS SKU tier')
@allowed(['Free', 'Standard', 'Premium'])
param skuTier string = 'Free'

@description('Tags for the resource')
param tags object = {}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: skuTier
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: enableRbac
    agentPoolProfiles: concat([
      {
        name: systemNodePool.name
        count: systemNodePool.count
        vmSize: systemNodePool.vmSize
        osDiskSizeGB: systemNodePool.osDiskSizeGB
        osDiskType: contains(systemNodePool, 'osDiskType') ? systemNodePool.osDiskType : 'Managed'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        vnetSubnetID: systemNodePool.subnetId
        enableAutoScaling: contains(systemNodePool, 'enableAutoScaling') ? systemNodePool.enableAutoScaling : false
        minCount: contains(systemNodePool, 'minCount') ? systemNodePool.minCount : null
        maxCount: contains(systemNodePool, 'maxCount') ? systemNodePool.maxCount : null
        maxPods: contains(systemNodePool, 'maxPods') ? systemNodePool.maxPods : 30
        type: 'VirtualMachineScaleSets'
        tags: contains(systemNodePool, 'tags') ? systemNodePool.tags : {}
        upgradeSettings: {
          maxSurge: contains(systemNodePool, 'maxSurge') ? systemNodePool.maxSurge : '10%'
        }
      }
    ], [for pool in userNodePools: {
      name: pool.name
      count: pool.count
      vmSize: pool.vmSize
      osDiskSizeGB: pool.osDiskSizeGB
      osDiskType: contains(pool, 'osDiskType') ? pool.osDiskType : 'Managed'
      osType: 'Linux'
      osSKU: 'Ubuntu'
      mode: 'User'
      vnetSubnetID: pool.subnetId
      enableAutoScaling: contains(pool, 'enableAutoScaling') ? pool.enableAutoScaling : false
      minCount: contains(pool, 'minCount') ? pool.minCount : null
      maxCount: contains(pool, 'maxCount') ? pool.maxCount : null
      maxPods: contains(pool, 'maxPods') ? pool.maxPods : 30
      type: 'VirtualMachineScaleSets'
      tags: contains(pool, 'tags') ? pool.tags : {}
      upgradeSettings: {
        maxSurge: contains(pool, 'maxSurge') ? pool.maxSurge : '10%'
      }
    }])
    networkProfile: {
      networkPlugin: networkProfile.networkPlugin
      networkDataplane: contains(networkProfile, 'networkDataplane') ? networkProfile.networkDataplane : 'azure'
      serviceCidr: networkProfile.serviceCidr
      dnsServiceIP: networkProfile.dnsServiceIP
      loadBalancerSku: contains(networkProfile, 'loadBalancerSku') ? networkProfile.loadBalancerSku : 'standard'
      outboundType: contains(networkProfile, 'outboundType') ? networkProfile.outboundType : 'loadBalancer'
    }
    linuxProfile: !empty(linuxProfile) ? {
      adminUsername: linuxProfile.adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: linuxProfile.sshPublicKey
          }
        ]
      }
    } : null
    autoUpgradeProfile: {
      upgradeChannel: null
      nodeOSUpgradeChannel: 'NodeImage'
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    windowsProfile: {
      adminUsername: 'azureuser'
    }
  }
}

output aksClusterId string = aksCluster.id
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output aksIdentityPrincipalId string = aksCluster.identity.principalId
