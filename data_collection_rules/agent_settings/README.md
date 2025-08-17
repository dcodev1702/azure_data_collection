# 🚀 Azure Monitor Agent Disk Cache Settings

Configure Azure Monitor Agent (AMA) disk cache settings using Data Collection Rules (DCR) with AgentSettings kind.

## 📋 Overview

This ARM template provisions a Data Collection Rule of kind `AgentSettings` to control the disk cache size for Azure Monitor Agent. By default, AMA uses 10GB for disk cache - this DCR allows you to customize that value from 4GB to 1TB.

## 📍 Disk Cache Locations

### Linux 🐧
- **Location:** `/etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/`
- **Default Size:** 10GB (10240 MB)

### Windows 🪟
- **Location:** `C:\WindowsAzure\Resources\AMADataStore\Configuration\`
- **Default Size:** 10GB (10240 MB)


## 📝 ARM Template

Save this as `dcr-ama-agent-settings.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "dcrName": { 
      "type": "string", 
      "defaultValue": "ama-agent-settings-dcr",
      "metadata": {
        "description": "Name of the Data Collection Rule for Agent Settings"
      }
    },
    "location": { 
      "type": "string", 
      "defaultValue": "eastus2",
      "metadata": {
        "description": "Azure region for the DCR"
      }
    },
    "diskCacheSizeMB": {
      "type": "string",
      "defaultValue": "15360",
      "metadata": {
        "description": "Disk cache size in MB (4000-1000000)"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Insights/dataCollectionRules",
      "apiVersion": "2023-03-11",
      "name": "[parameters('dcrName')]",
      "location": "[parameters('location')]",
      "kind": "AgentSettings",
      "properties": {
        "description": "Configure AMA disk cache settings",
        "agentSettings": {
          "logs": [
            { 
              "name": "MaxDiskQuotaInMB", 
              "value": "[parameters('diskCacheSizeMB')]"
            }
          ]
        }
      }
    }
  ]
}
```

## 🎯 Configuration Options

| Setting | Min Value | Max Value | Default | Description |
|---------|-----------|-----------|---------|-------------|
| MaxDiskQuotaInMB | 4000 (4GB) | 1000000 (1TB) | 10240 (10GB) | Maximum disk space for offline log cache |

## 🚀 Deployment Steps

### 1️⃣ Deploy the DCR
```bash
# Basic deployment with defaults (15GB cache)
az deployment group create \
  --resource-group YOUR_RG \
  --template-file dcr-ama-agent-settings.json

# Custom deployment with specific cache size
az deployment group create \
  --resource-group YOUR_RG \
  --template-file dcr-ama-agent-settings.json \
  --parameters dcrName="dcr-agent-settings-prod" \
               location="eastus2" \
               diskCacheSizeMB="15000"
```

### 2️⃣ Associate DCR with Virtual Machine

⚠️ **IMPORTANT:**  DCR <-> VM associations have to be completed via the CLI (e.g. az cli or PowerShell Az Module) <br/>
⚠️ **IMPORTANT:**  The association name MUST be `agentSettings` - this is hardcoded and the command will fail with any other value!

```bash
# Linux VM example
az monitor data-collection rule association create \
  --name agentSettings \
  --rule-id /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/dataCollectionRules/{dcr-name} \
  --resource /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{vm-name}

# Windows VM example (same command structure)
az monitor data-collection rule association create \
  --name agentSettings \
  --rule-id /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/dataCollectionRules/{dcr-name} \
  --resource /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{windows-vm-name}
```

### 3️⃣ Verify Association
```bash
# List all DCR associations for a VM
az monitor data-collection rule association list \
  --resource /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{vm-name}

# Get specific agentSettings association
az monitor data-collection rule association show \
  --name agentSettings \
  --resource /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{vm-name}
```

## 🔍 Verifying AMA Disk Cache Settings

### On Linux VM:
```bash
# SSH into your Linux VM and check the current configuration
# Search through all JSON files in configchunks directory for the disk quota setting
grep -h "MaxDiskQuotaInMB" /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/*.json | jq .

# Or to see the full AgentSettings configuration:
grep -l "MaxDiskQuotaInMB" /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/*.json | xargs cat | jq '.settings'

# Expected output:
# [
#   {
#     "name": "MaxDiskQuotaInMB",
#     "value": "15360"
#   }
# ]
```

### On Windows VM:
```powershell
# Check the AMA configuration
Get-Content "C:\WindowsAzure\Resources\AMADataStore\Configuration\configchunks.json" | ConvertFrom-Json
```

## 📊 Example Scenarios

### Small Environment (4GB Cache)
```json
{ "name": "MaxDiskQuotaInMB", "value": "4000" }
```
Use case: Development environments with minimal logging requirements

### Medium Environment (100GB Cache)
```json
{ "name": "MaxDiskQuotaInMB", "value": "100000" }
```
Use case: Standard production workloads with moderate logging

### Large Environment (400GB Cache)
```json
{ "name": "MaxDiskQuotaInMB", "value": "400000" }
```
Use case: High-volume production systems with extensive logging

### Maximum Cache (1TB)
```json
{ "name": "MaxDiskQuotaInMB", "value": "1000000" }
```
Use case: Critical systems requiring maximum offline log retention

## 🔄 Bulk Deployment Script

### PowerShell Script for Multiple VMs
```powershell
# deploy-ama-settings.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$DcrName,
    
    [Parameter(Mandatory=$true)]
    [string[]]$VmNames,
    
    [string]$CacheSizeMB = "15360"
)

# Deploy the DCR
Write-Host "Deploying DCR: $DcrName" -ForegroundColor Green
az deployment group create `
  --resource-group $ResourceGroup `
  --template-file dcr-ama-agent-settings.json `
  --parameters dcrName=$DcrName diskCacheSizeMB=$CacheSizeMB

# Get subscription ID
$subscriptionId = az account show --query id -o tsv

# Get DCR resource ID
$dcrId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DcrName"

# Associate with each VM
foreach ($vm in $VmNames) {
    Write-Host "Associating DCR with VM: $vm" -ForegroundColor Yellow
    $vmId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$vm"
    
    az monitor data-collection rule association create `
      --name agentSettings `
      --rule-id $dcrId `
      --resource $vmId
}

Write-Host "Deployment complete!" -ForegroundColor Green
```

### Bash Script for Multiple VMs
```bash
#!/bin/bash
# deploy-ama-settings.sh

RESOURCE_GROUP="$1"
DCR_NAME="$2"
CACHE_SIZE_MB="${3:-15360}"
shift 3
VM_NAMES=("$@")

# Deploy the DCR
echo "Deploying DCR: $DCR_NAME"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file dcr-ama-agent-settings.json \
  --parameters dcrName="$DCR_NAME" diskCacheSizeMB="$CACHE_SIZE_MB"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get DCR resource ID
DCR_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/dataCollectionRules/$DCR_NAME"

# Associate with each VM
for VM in "${VM_NAMES[@]}"; do
    echo "Associating DCR with VM: $VM"
    VM_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM"
    
    az monitor data-collection rule association create \
      --name agentSettings \
      --rule-id "$DCR_ID" \
      --resource "$VM_ID"
done

echo "Deployment complete!"
```

## ⚡ Quick Tips

- 💡 One AgentSettings DCR can be associated with multiple VMs
- 🔄 Changes take effect within 5 minutes after association
- 📈 Monitor disk usage to determine optimal cache size
- 🎯 AgentSettings DCR is separate from your data collection DCRs (syslog, events, etc.)
- ⚠️ The association name **MUST** be `agentSettings` - no exceptions!
- 🔍 You can have both AgentSettings DCR and regular data collection DCRs associated to the same VM
- 💾 Larger cache sizes help during network outages but consume more disk space

## 🔧 Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Association fails with "Invalid name" | Ensure the association name is exactly `agentSettings` |
| "Resource not found" error | Verify the AMA extension is installed on the target VM |
| Settings not applying | Check that the DCR kind is set to `AgentSettings` |
| Invalid value error | Confirm the value is between 4000 and 1000000 |
| Changes not taking effect | Wait 5-10 minutes for propagation, then restart AMA service |

### Verify AMA Extension Installation
```bash
# For Linux VM
az vm extension show \
  --resource-group YOUR_RG \
  --vm-name YOUR_VM \
  --name AzureMonitorLinuxAgent

# For Windows VM
az vm extension show \
  --resource-group YOUR_RG \
  --vm-name YOUR_VM \
  --name AzureMonitorWindowsAgent
```

### Restart AMA Service (if needed)
```bash
# Linux
sudo systemctl restart azuremonitoragent

# Windows (PowerShell as Administrator)
Restart-Service AzureMonitorAgent
```

## 📚 References

### Official Documentation
- [Azure Monitor Agent Overview](https://docs.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-overview)
- [Data Collection Rules in Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-overview)
- [AMA Configuration Settings](https://docs.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-data-collection)
- [DCR Associations](https://docs.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-associations)
- [AMA Troubleshooting Guide](https://docs.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-troubleshoot)

### Additional Resources
- [Azure Monitor Agent Migration Guide](https://docs.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-migration)
- [DCR ARM Template Reference](https://docs.microsoft.com/azure/templates/microsoft.insights/datacollectionrules)
- [Azure Monitor Pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [Azure Monitor Agent Performance Considerations](https://docs.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-performance)

### Community Resources
- [Azure Monitor GitHub Samples](https://github.com/Azure/azure-monitor-samples)
- [Azure Monitor Tech Community](https://techcommunity.microsoft.com/t5/azure-monitor/bd-p/AzureMonitor)

## 📝 Notes

- This configuration applies to both Linux and Windows VMs with Azure Monitor Agent installed
- The disk cache is used for offline storage when the agent cannot send data to Azure Monitor
- Cache location varies by OS but the configuration method remains the same
- Consider your VM's available disk space when setting cache sizes
- Regular monitoring of cache usage helps optimize the configuration

## 🏷️ Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | August 2025 | Initial release with AgentSettings DCR support |

---

**Author:** Azure Cloud Solutions Architecture Team  
**Last Updated:** Sunday, August 17, 2025  
**License:** MIT

## 📄 License

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
