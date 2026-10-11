targetScope = 'resourceGroup'

@description('Deployment location')
param location string = resourceGroup().location

@description('Windows administrator username')
param adminUsername string

@description('Windows administrator password')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_D2alds_v6'

// ---------------------------------------------------------
// Naming
// ---------------------------------------------------------

var prefix = 'article-vm'

var vnetName = '${prefix}-vnet'
var subnetName = '${prefix}-subnet'
var nsgName = '${prefix}-nsg'

var vmNames = [
  '${prefix}-01'
  '${prefix}-02'
]

// ---------------------------------------------------------
// Network Security Group
// ---------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

// ---------------------------------------------------------
// Virtual Network
// ---------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
  }
}

// ---------------------------------------------------------
// Subnet
// ---------------------------------------------------------

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: subnetName

  properties: {
    addressPrefix: '10.10.1.0/24'

    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// ---------------------------------------------------------
// Network Interfaces - Two NICs
// ---------------------------------------------------------

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = [
  for (vmName, i) in vmNames: {

    name: '${vmName}-nic'
    location: location

    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'

          properties: {
            privateIPAllocationMethod: 'Dynamic'

            subnet: {
              id: subnet.id
            }
          }
        }
      ]
    }
  }
]

// ---------------------------------------------------------
// Virtual Machines - Two Windows Server 2025 VMs
// ---------------------------------------------------------

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = [
  for (vmName, i) in vmNames: {

    name: vmName
    location: location

    properties: {

      hardwareProfile: {
        vmSize: vmSize
      }

      osProfile: {

        computerName: vmName
        adminUsername: adminUsername
        adminPassword: adminPassword

        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
      }

      storageProfile: {

        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2025-datacenter-azure-edition'
          version: 'latest'
        }

        osDisk: {
          name: '${vmName}-osdisk'

          caching: 'ReadWrite'
          createOption: 'FromImage'

          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }

      networkProfile: {

        networkInterfaces: [
          {
            id: nic[i].id

            properties: {
              primary: true
            }
          }
        ]
      }
    }
  }
]

// ---------------------------------------------------------
// Outputs
// ---------------------------------------------------------

output vmNames array = [
  for (vmName, i) in vmNames: {
    name: vm[i].name
    resourceId: vm[i].id
  }
]

output vnetName string = vnet.name
output subnetName string = subnet.name

