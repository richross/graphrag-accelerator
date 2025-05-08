@minLength(1)
@maxLength(64)
@description('Name of the resource group that GraphRAG will be deployed in.')
param resourceGroupName string

@description('Unique name to append to each resource')
param resourceBaseName string = ''
var resourceBaseNameFinal = !empty(resourceBaseName) ? resourceBaseName : toLower(uniqueString(az.resourceGroup().id))

@description('Cloud region for all resources')
param location string

@minLength(1)
@description('Name of the publisher of the API Management service.')
param apiPublisherName string = 'Microsoft'

@minLength(1)
@description('Email address of the publisher of the API Management service.')
param apiPublisherEmail string = 'publisher@microsoft.com'

param apimTier string = 'Developer'
param apimName string = ''

@description('Whether to use private endpoint connections or not.')
param enablePrivateEndpoints bool = true

var abbrs = loadJsonContent('abbreviations.json')
var tags = { 'azd-env-name': resourceGroupName }
var utcString = utcNow()

var dnsDomain = 'graphrag.io'
var workloadIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceBaseNameFinal}'
var aksControlPlaneIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceBaseNameFinal}-akscp'
var aksKubeletIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceBaseNameFinal}-akskubelet'
var aksIngressIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceBaseNameFinal}-aksingress'
var cosmosDbIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}${resourceBaseNameFinal}-cosmosdb'
var workloadIdentitySubject = 'system:serviceaccount:graphrag:graphrag-workload-sa'

var roles = {
  acrPull: resourceId(
    'Microsoft.Authorization/roleDefinitions',
    '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  )
  networkContributor: resourceId(
    'Microsoft.Authorization/roleDefinitions',
    '4d97b98b-1d4f-4787-a291-c67834d212e7'
  )
  privateDnsZoneContributor: resourceId(
    'Microsoft.Authorization/roleDefinitions',
    'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
  )
}

module nsg 'core/vnet/nsg.bicep' = {
  name: 'nsg-deployment'
  params: {
    nsgName: '${abbrs.networkNetworkSecurityGroups}${resourceBaseNameFinal}'
    location: location
  }
}

module vnet 'core/vnet/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    vnetName: '${abbrs.networkVirtualNetworks}${resourceBaseNameFinal}'
    location: location
    subnetPrefix: abbrs.networkVirtualNetworksSubnets
    apimTier: apimTier
    nsgID: nsg.outputs.id
  }
}

module privateDnsZone 'core/vnet/private-dns-zone.bicep' = {
  name: 'private-dns-zone-deployment'
  params: {
    name: dnsDomain
    vnetName: vnet.outputs.name
  }
}

module privatelinkPrivateDns 'core/vnet/privatelink-private-dns-zones.bicep' = if (enablePrivateEndpoints) {
  name: 'privatelink-private-dns-zones-deployment'
  params: {
    linkedVnetId: vnet.outputs.id
  }
}

module workloadIdentity 'core/identity/identity.bicep' = {
  name: 'workload-identity-deployment'
  params: {
    name: workloadIdentityName
    location: location
    federatedCredentials: {
      'aks-workload-identity': {
        issuer: '<aks-issuer-placeholder>' // Replace with actual value or param
        audiences: ['api://AzureADTokenExchange']
        subject: workloadIdentitySubject
      }
    }
  }
}

module aksControlPlaneIdentity 'core/identity/identity.bicep' = {
  name: 'aks-control-plane-identity-deployment'
  params: {
    name: aksControlPlaneIdentityName
    location: location
  }
}

module aksKubeletIdentity 'core/identity/identity.bicep' = {
  name: 'aks-kubelet-identity-deployment'
  params: {
    name: aksKubeletIdentityName
    location: location
  }
}

module aksIngressIdentity 'core/identity/identity.bicep' = {
  name: 'aks-ingress-identity-deployment'
  params: {
    name: aksIngressIdentityName
    location: location
  }
}

module cosmosDbIdentity 'core/identity/identity.bicep' = {
  name: 'cosmosdb-identity-deployment'
  params: {
    name: cosmosDbIdentityName
    location: location
  }
}

module aksWorkloadIdentityRBAC 'core/rbac/workload-identity-rbac.bicep' = {
  name: 'aks-workload-identity-rbac-assignments'
  params: {
    principalId: workloadIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    aiSearchName: '<aiSearchName-placeholder>' // Replace with actual value or param
    appInsightsName: '<appInsightsName-placeholder>' // Replace with actual value or param
    cosmosDbName: '<cosmosDbName-placeholder>' // Replace with actual value or param
    storageName: '<storageName-placeholder>' // Replace with actual value or param
    aoaiId: '<aoaiId-placeholder>' // Replace with actual value or param
  }
}

module aksRBAC 'core/rbac/aks-rbac.bicep' = {
  name: 'aks-rbac-assignments'
  params: {
    roleAssignments: [
      {
        principalId: aksKubeletIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionId: roles.acrPull
      }
      {
        principalId: aksIngressIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionId: roles.privateDnsZoneContributor
      }
      {
        principalId: aksControlPlaneIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionId: roles.networkContributor
      }
    ]
  }
}

// Output all IDs needed by main-contrib.bicep
output vnetId string = vnet.outputs.id
output aksSubnetId string = vnet.outputs.aksSubnetId
output apimSubnetId string = vnet.outputs.apimSubnetId
output workloadIdentityId string = workloadIdentity.outputs.id
output aksControlPlaneIdentityId string = aksControlPlaneIdentity.outputs.id
output aksKubeletIdentityId string = aksKubeletIdentity.outputs.id
output aksIngressIdentityId string = aksIngressIdentity.outputs.id
output cosmosDbIdentityId string = cosmosDbIdentity.outputs.id
output privateDnsZoneName string = privateDnsZone.outputs.name
