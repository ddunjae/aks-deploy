using './main.bicep'

// ============================================================================
// AKS Demo Environment Parameters
// ============================================================================

param location = 'koreacentral'
param resourceGroupName = 'rg-aks-network-demo'
param environment = 'Demo'

// Network Configuration
param hubVnetAddressPrefix = '10.0.0.0/16'
param spokeVnetAddressPrefix = '10.1.0.0/16'
param aksServiceCidr = '10.2.0.0/16'
param aksDnsServiceIp = '10.2.0.10'

// AKS Configuration
param aksClusterName = 'aks-demo-cluster'
param kubernetesVersion = '1.32'
param aksSystemNodeVmSize = 'Standard_DS2_v2'

// ACR Configuration - IMPORTANT: Change this to a globally unique name
param acrName = 'acraksdemo${uniqueString(subscription().subscriptionId)}'

// Jumpbox Configuration
param jumpboxAdminUsername = 'conortest'
param jumpboxAdminPassword = readEnvironmentVariable('JUMPBOX_PASSWORD', '')

// SSH Public Key for AKS nodes - Replace with your SSH public key
param sshPublicKey = readEnvironmentVariable('SSH_PUBLIC_KEY', 'ssh-rsa AAAA...')
