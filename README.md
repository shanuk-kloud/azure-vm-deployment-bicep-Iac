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

<img width="1698" height="875" alt="image" src="https://github.com/user-attachments/assets/62a361f4-e743-4f5c-b880-f5c334e51879" />


This reflects the current Bicep structure and helps confirm the portal view matches the template.

## Core conventions
- Keep all infrastructure changes in Bicep (`.bicep`) rather than JSON unless a conversion is explicitly required.
- Prefer matching the established naming pattern using the `article-vm` prefix.
- Keep resource definitions consistent across the two VM resources and their associated NICs.
- Use secure parameters for credentials and never hardcode secrets in source files.
- Preserve Azure resource naming, network topology, and VM sizing conventions unless the user explicitly requests a change.

## Deployment workflow
## Complete Azure CLI deployment
The commands below are written for Windows PowerShell and should be run from the repository root, where `main.bicep` is located. They create two Windows Server 2025 VMs and supporting network resources in one resource group.

Before starting, you need an Azure subscription, permission to create a resource group and resources in it, and Azure CLI installed. Sign in with an account that has those permissions. VM availability and quota depend on your subscription and selected region; creating and running VMs incurs Azure charges.
Before starting, you need an Azure subscription and permission to create a resource group and resources in it. VM availability and quota depend on your subscription and selected region; creating and running VMs incurs Azure charges.

If Azure CLI is not installed on Windows and WinGet is available, install it from PowerShell, then close and reopen PowerShell:

```powershell
winget install --exact --id Microsoft.AzureCLI
```

Alternatively, install Azure CLI using Microsoft's official instructions: https://learn.microsoft.com/cli/azure/install-azure-cli-windows

### 1. Check Azure CLI and sign in

```powershell
az version
az login
az account list --output table
```

If you have more than one subscription, select the one to use. Replace the placeholder with the subscription name or ID shown by `az account list`:

```powershell
az account set --subscription "<subscription-id-or-name>"
az account show --output table
```

Check the `name` and `id` in the output to confirm the intended subscription is selected. Install or update Bicep CLI if needed:
Check the `name` and `id` in the output to confirm the intended subscription is selected. Check that Bicep CLI is available:

```powershell
az bicep version
```

If Bicep is not installed, install it. To update an existing installation, use the upgrade command:

```powershell
az bicep install
az bicep upgrade
```

### 2. Set deployment values

These values match the current `main.bicep` and `main.bicepparam`. Change the location or VM size only after confirming the size is available and supported in your subscription.

```powershell
$resourceGroup = "article-vm-rg"
$location = "francecentral"
$deploymentName = "article-vm-deployment"
$adminUsername = "azureuser"
$vmSize = "Standard_D2alds_v6"
$adminPasswordSecure = Read-Host "Enter a strong Windows VM administrator password" -AsSecureString
$adminPassword = (New-Object System.Net.NetworkCredential("", $adminPasswordSecure)).Password
```

The password is required by the template and is deliberately not stored in `main.bicepparam`. Although the prompt hides it, Azure CLI must receive the password to deploy the VMs. Keep it private, do not paste it into source files or commit it, and avoid recording the terminal session. For automated deployments, use a protected CI/CD secret or an approved secret store.

### 3. Create the resource group

```powershell
az group create --name $resourceGroup --location $location --output table
```

The resource group is the container for the virtual network, subnet, network security group, NICs, VMs, and OS disks.

### 4. Build and validate the template

Build checks the Bicep syntax and generates `main.json` from `main.bicep`:

```powershell
az bicep build --file .\main.bicep
```

Validate the deployment request against Azure without creating the resources:

```powershell
az deployment group validate --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword=$adminPassword
```

Preview the changes Azure would make. Read the output before continuing:

```powershell
az deployment group what-if --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword=$adminPassword
```

### 5. Deploy the resources

Run this only after reviewing the validation and what-if results:

```powershell
az deployment group create --name $deploymentName --resource-group $resourceGroup --template-file .\main.bicep --parameters location=$location adminUsername=$adminUsername vmSize=$vmSize adminPassword=$adminPassword --output table
```

Deployment can take several minutes. A successful deployment returns provisioning information. If it fails, inspect the error before retrying; common causes include an unavailable VM size, insufficient quota, or missing permissions.

### 6. Verify the deployment

Show the deployment result and list all resources in the resource group:

```powershell
az deployment group show --name $deploymentName --resource-group $resourceGroup --output table
az deployment group show --name $deploymentName --resource-group $resourceGroup --query properties.outputs --output jsonc
az resource list --resource-group $resourceGroup --query "[].{Name:name, Type:type, Location:location}" --output table
```

Check the VMs, virtual network, NSG, and NICs:

```powershell
az vm list --resource-group $resourceGroup --show-details --output table
az network vnet list --resource-group $resourceGroup --output table
az network nsg list --resource-group $resourceGroup --output table
az network nic list --resource-group $resourceGroup --output table
```

To see a VM's network addresses, use one of the VM names:

```powershell
az vm list-ip-addresses --resource-group $resourceGroup --name article-vm-01 --output table
az vm list-ip-addresses --resource-group $resourceGroup --name article-vm-02 --output table
```

This template creates NICs with private IP addresses only. It does not create public IP addresses or inbound NSG rules, so the VMs are not directly reachable from the public internet.

### 7. Manage the VMs

Run the command for the VM you want to manage, substituting `article-vm-01` or `article-vm-02` for `<vm-name>`:
The following commands show examples for `article-vm-01`. Replace that name with `article-vm-02` to manage the second VM:

```powershell
az vm show --resource-group $resourceGroup --name article-vm-01 --show-details --output table
az vm start --resource-group $resourceGroup --name article-vm-01
az vm restart --resource-group $resourceGroup --name article-vm-01
az vm stop --resource-group $resourceGroup --name article-vm-01
az vm deallocate --resource-group $resourceGroup --name article-vm-01
```

`stop` shuts down the guest OS but may leave compute allocated and billable. `deallocate` releases compute capacity. A deallocated VM must be started again before use.

### 8. Delete the deployment when finished (optional)

The following command permanently deletes the resource group and every resource inside it, including both VMs and their disks. Run it only when you are sure you no longer need anything in `article-vm-rg`:

```powershell
az group delete --name $resourceGroup --yes --no-wait
```

If deployment values change, update `main.bicepparam` to keep its non-secret values aligned with the template. Never add the administrator password to that file; provide it securely as shown above.

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
