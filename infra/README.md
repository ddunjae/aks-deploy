# AKS Infrastructure Deployment (Bicep)

This directory contains Bicep templates for deploying the AKS demo environment with a Hub-Spoke network topology.

## Architecture Overview

```
                    ┌─────────────────────────────────────────┐
                    │           Hub VNet (10.0.0.0/16)        │
                    │  ┌─────────────────────────────────┐    │
                    │  │ AzureFirewallSubnet (10.0.1.0/24)│   │
                    │  ├─────────────────────────────────┤    │
                    │  │ GatewaySubnet (10.0.2.0/24)     │    │
                    │  ├─────────────────────────────────┤    │
                    │  │ AzureBastionSubnet (10.0.3.0/26)│    │
                    │  ├─────────────────────────────────┤    │
                    │  │ snet-management (10.0.4.0/24)   │◄───┼──── Jumpbox VM
                    │  └─────────────────────────────────┘    │
                    └─────────────────┬───────────────────────┘
                                      │ VNet Peering
                    ┌─────────────────┴───────────────────────┐
                    │        Spoke VNet (10.1.0.0/16)         │
                    │  ┌─────────────────────────────────┐    │
                    │  │ snet-aks-system (10.1.1.0/24)  │◄───┼──── AKS System Pool
                    │  ├─────────────────────────────────┤    │
                    │  │ snet-aks-user (10.1.2.0/23)    │◄───┼──── AKS User Pools
                    │  ├─────────────────────────────────┤    │
                    │  │ snet-aks-ilb (10.1.4.0/24)     │◄───┼──── Internal LB
                    │  ├─────────────────────────────────┤    │
                    │  │ snet-appgw (10.1.5.0/24)       │◄───┼──── App Gateway
                    │  ├─────────────────────────────────┤    │
                    │  │ snet-privateendpoint (10.1.10.0/24)│ │
                    │  └─────────────────────────────────┘    │
                    └─────────────────────────────────────────┘
```

## Resources Deployed

| Resource | Description |
|----------|-------------|
| Resource Group | Container for all resources |
| Hub VNet | Central network for shared services |
| Spoke VNet | Network for AKS workloads |
| VNet Peering | Connectivity between Hub and Spoke |
| NSGs | Network security for AKS, AppGW, Jumpbox |
| Route Table | Custom routing for AKS subnets |
| AKS Cluster | Managed Kubernetes cluster |
| ACR | Container registry for images |
| Jumpbox VM | Management VM in Hub network |

## Prerequisites

- Azure CLI 2.50+ or Azure PowerShell
- Bicep CLI 0.20+
- Azure subscription with Contributor access
- SSH key pair for AKS nodes

## Deployment

### Using Azure CLI

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<subscription-id>"

# Deploy using parameter file
az deployment sub create \
  --location koreacentral \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters jumpboxAdminPassword='<your-password>' \
  --parameters sshPublicKey='<your-ssh-public-key>'
```

### Using Azure PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Set subscription
Set-AzContext -SubscriptionId "<subscription-id>"

# Deploy
New-AzSubscriptionDeployment `
  -Location koreacentral `
  -TemplateFile main.bicep `
  -TemplateParameterFile main.parameters.json `
  -jumpboxAdminPassword (ConvertTo-SecureString '<your-password>' -AsPlainText -Force) `
  -sshPublicKey '<your-ssh-public-key>'
```

## Module Structure

```
infra/
├── main.bicep                 # Main orchestration template
├── main.bicepparam            # Bicep parameters file
├── main.parameters.json       # JSON parameters file
├── README.md                  # This file
└── modules/
    ├── acr/
    │   └── acr.bicep          # Container Registry module
    ├── aks/
    │   └── aks-cluster.bicep  # AKS Cluster module
    ├── compute/
    │   └── jumpbox-vm.bicep   # Jumpbox VM module
    ├── identity/
    │   └── role-assignment.bicep  # Role assignment module
    └── network/
        ├── nsg.bicep          # Network Security Group module
        ├── route-table.bicep  # Route Table module
        ├── vnet.bicep         # Virtual Network module
        └── vnet-peering.bicep # VNet Peering module
```

## Configuration

### Network Configuration

| Network | CIDR | Purpose |
|---------|------|---------|
| Hub VNet | 10.0.0.0/16 | Shared services |
| Spoke VNet | 10.1.0.0/16 | AKS workloads |
| AKS Service CIDR | 10.2.0.0/16 | Kubernetes services |

### AKS Configuration

| Setting | Value |
|---------|-------|
| Kubernetes Version | 1.32 |
| Network Plugin | Azure CNI |
| SKU Tier | Free |
| System Node VM Size | Standard_DS2_v2 |
| Auto-scaling | Enabled (1-10 nodes) |

## Post-Deployment

### Connect to AKS Cluster

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-aks-network-demo --name aks-demo-cluster

# Verify connection
kubectl get nodes
```

### Connect to Jumpbox

```bash
# Get Jumpbox public IP
az vm show -g rg-aks-network-demo -n vm-jumpbox -d --query publicIps -o tsv

# SSH to Jumpbox
ssh conortest@<public-ip>
```

## Cleanup

```bash
# Delete the resource group and all resources
az group delete --name rg-aks-network-demo --yes --no-wait
```

## Related Documentation

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Hub-Spoke Network Topology](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
