targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.eventhub.namespaces-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'ehncom'

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module resourceGroupResources 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    virtualNetworkName: 'dep-<<namePrefix>>-vnet-${serviceShort}'
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}'
    storageAccountName: 'dep<<namePrefix>>sa${serviceShort}'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep<<namePrefix>>diasa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-<<namePrefix>>-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-<<namePrefix>>-evh-${serviceShort}'
    eventHubNamespaceName: 'dep-<<namePrefix>>-evhns-${serviceShort}'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-${serviceShort}'
  params: {
    name: '<<namePrefix>>${serviceShort}001'

    authorizationRules: [
      {
        name: 'RootManageSharedAccessKey'
        rights: [
          'Listen'
          'Manage'
          'Send'
        ]
      }
      {
        name: 'SendListenAccess'
        rights: [
          'Listen'
          'Send'
        ]
      }
    ]
    diagnosticLogsRetentionInDays: 7
    diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
    diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
    diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
    eventHubs: [
      {
        name: '<<namePrefix>>-az-evh-x-001'
      }
      {
        authorizationRules: [
          {
            name: 'RootManageSharedAccessKey'
            rights: [
              'Listen'
              'Manage'
              'Send'
            ]
          }
          {
            name: 'SendListenAccess'
            rights: [
              'Listen'
              'Send'
            ]
          }
        ]
        captureDescriptionDestinationArchiveNameFormat: '{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
        captureDescriptionDestinationBlobContainer: 'eventhub'
        captureDescriptionDestinationName: 'EventHubArchive.AzureBlockBlob'
        captureDescriptionDestinationStorageAccountResourceId: resourceGroupResources.outputs.storageAccountResourceId
        captureDescriptionEnabled: true
        captureDescriptionEncoding: 'Avro'
        captureDescriptionIntervalInSeconds: 300
        captureDescriptionSizeLimitInBytes: 314572800
        captureDescriptionSkipEmptyArchives: true
        consumerGroups: [
          {
            name: 'custom'
            userMetadata: 'customMetadata'
          }
        ]
        messageRetentionInDays: 1
        name: '<<namePrefix>>-az-evh-x-002'
        partitionCount: 2
        roleAssignments: [
          {
            principalIds: [
              resourceGroupResources.outputs.managedIdentityPrincipalId
            ]
            roleDefinitionIdOrName: 'Reader'
          }
        ]
        status: 'Active'
      }
    ]
    lock: 'CanNotDelete'
    networkRuleSets: {
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          ipMask: '10.10.10.10'
        }
      ]
      trustedServiceAccessEnabled: false
      virtualNetworkRules: [
        {
          ignoreMissingVnetServiceEndpoint: true
          subnetResourceId: resourceGroupResources.outputs.subnetResourceId
        }
      ]
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            resourceGroupResources.outputs.privateDNSZoneResourceId
          ]
        }
        service: 'namespace'
        subnetResourceId: resourceGroupResources.outputs.subnetResourceId
      }
    ]
    roleAssignments: [
      {
        principalIds: [
          resourceGroupResources.outputs.managedIdentityPrincipalId
        ]
        roleDefinitionIdOrName: 'Reader'
      }
    ]
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
    }
  }
}
