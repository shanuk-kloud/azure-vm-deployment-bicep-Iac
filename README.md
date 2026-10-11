# GitHub Copilot Instructions for this Repository

## Project overview
This repository contains an Azure Bicep deployment for a small environment with:
- one virtual network
- one subnet
- one network security group
- two NICs
- two Windows Server 2025 virtual machines

The main deployment logic lives in `main.bicep`, while parameter values are kept in `main.bicepparam`.

## Azure portal resource view
The deployment is expected to appear in a single resource group named `article-vm-rg` and should contain the following Azure resources:
- Virtual network: `article-vm-vnet`
- Subnet: `article-vm-subnet`
- Network security group: `article-vm-nsg`
- NICs: `article-vm-01-nic`, `article-vm-02-nic`
- Virtual machines: `article-vm-01`, `article-vm-02`
- Associated OS disks for each VM

<img width="1698" height="875" alt="image" src="https://github.com/user-attachments/assets/2fcbe5dc-4425-48e0-a7f8-a0c7b11f46da" />


This reflects the current Bicep structure and helps confirm the portal view matches the template.

## Core conventions
- Keep all infrastructure changes in Bicep (`.bicep`) rather than JSON unless a conversion is explicitly required.
- Prefer matching the established naming pattern using the `article-vm` prefix.
- Keep resource definitions consistent across the two VM resources and their associated NICs.
- Use secure parameters for credentials and never hardcode secrets in source files.
- Preserve Azure resource naming, network topology, and VM sizing conventions unless the user explicitly requests a change.

## Deployment workflow
Use the Azure CLI from the repository root. These PowerShell commands cover the normal deployment workflow for this project.

### Sign in and select a subscription

```powershell
az login
az account list --output table
az account set --subscription "<subscription-id-or-name>"
az account show --output table
```

### Set deployment values and prepare the resource group

```powershell
$resourceGroup = "article-vm-rg"
$location = "francecentral"
$deploymentName = "article-vm-deployment"
$adminUsername = "azureuser"
$vmSize = "Standard_D2alds_v6"
$adminPasswordPlain = Read-Host "Enter the VM administrator password"

az group create --name $resourceGroup --location $location --output table

```

Use a strong password that meets Azure's Windows VM requirements. Do not put the password in source files, commit it, or share it in logs. For automation, use a protected CI/CD secret or an approved secret store.

### Validate and preview

```powershell
az bicep version
az bicep build --file .\main.bicep
az deployment group validate --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword="$adminPasswordPlain"
az deployment group what-if --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword="$adminPasswordPlain"
```

Review the what-if output before applying changes.

### Deploy and inspect

```powershell
az deployment group create --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword="$adminPasswordPlain" --output table
az deployment group show --name $deploymentName --resource-group $resourceGroup --output table
az resource list --resource-group $resourceGroup --output table
az vm list --resource-group $resourceGroup --show-details --output table
az network vnet list --resource-group $resourceGroup --output table
az network nsg list --resource-group $resourceGroup --output table
az network nic list --resource-group $resourceGroup --output table
```

### Manage the virtual machines

Replace `<vm-name>` with `article-vm-01` or `article-vm-02`:

```powershell
az vm show --resource-group $resourceGroup --name "<vm-name>" --show-details --output table
az vm list-ip-addresses --resource-group $resourceGroup --name "<vm-name>" --output table
az vm start --resource-group $resourceGroup --name "<vm-name>"
az vm stop --resource-group $resourceGroup --name "<vm-name>"
az vm deallocate --resource-group $resourceGroup --name "<vm-name>"
az vm restart --resource-group $resourceGroup --name "<vm-name>"
```

`stop` shuts down the guest OS but can leave compute allocated. `deallocate` releases compute capacity. Use `start` to bring a stopped or deallocated VM back online.

To remove the entire environment, only when you intend to delete every resource in the resource group:

```powershell
az group delete --name $resourceGroup --yes --no-wait
```

If the deployment parameters change, update `main.bicepparam` to reflect the current configuration and keep its values aligned with the template. The current parameter file does not contain the required secure `adminPassword`, so supply that value securely when validating or deploying.

## Editing guidance
- Update `main.bicep` for resource and networking changes.
- Update `main.bicepparam` for environment-specific parameter values.
- Keep comments short and useful; avoid noisy or redundant comments.
- Prefer Azure-native resource types and current API versions already used in the template.
- When changing VM settings, make sure NIC and VM properties remain aligned.

## Validation expectations
Before finalizing a change:
1. Confirm the Bicep syntax is valid.
2. Check that all parameter names still match the template declaration.
3. Verify that any new or modified resource names do not conflict with existing ones.
4. Validate the deployment with Azure CLI if infrastructure changes are substantial.

## Contribution notes
- Keep PRs focused on a single infrastructure change when possible.
- Mention any deployment or resource naming changes clearly in the PR description.
- Do not commit real credentials or environment-specific secrets.
- If a change affects the deployment flow, update examples or parameter guidance in the repository.
