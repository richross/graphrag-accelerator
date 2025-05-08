@minLength(1)
@maxLength(64)
@description('Name of the resource group that GraphRAG will be deployed in.')
param resourceGroupName string

@description('Unique name to append to each resource')
param resourceBaseName string = ''
var resourceBaseNameFinal = !empty(resourceBaseName) ? resourceBaseName : toLower(uniqueString(az.resourceGroup().id))

@description('Cloud region for all resources')
param location string

@description('Whether or not to deploy a new AOAI resource instead of connecting to an existing service.')
param deployAoai bool = true

@description('Resource id of an existing AOAI resource.')
param existingAoaiId string = ''

@description('Whether or not to deploy a new ACR resource instead of connecting to an existing service.')
param deployAcr bool = false
param existingAcrLoginServer string = ''
param acrTokenName string = ''
@secure()
param acrTokenPassword string = ''
param graphragImageName string = 'graphrag'
param graphragImageVersion string = 'latest'

@description('Name of the AOAI LLM model to use. Must match official model id.')
@allowed(['gpt-4', 'gpt-4o', 'gpt-4o-mini'])
param llmModelName string = 'gpt-4o'
param llmModelDeploymentName string = 'gpt-4o'
@allowed(['2024-08-06', 'turbo-2024-04-09'])
param llmModelVersion string = '2024-08-06'
@minValue(1)
param llmModelQuota int = 1
@allowed(['text-embedding-ada-002', 'text-embedding-3-large'])
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingModelDeploymentName string = 'text-embedding-ada-002'
@allowed(['2', '1'])
param embeddingModelVersion string = '2'
@minValue(1)
param embeddingModelQuota int = 1

@description('The AKS namespace to install GraphRAG in.')
param aksNamespace string = 'graphrag'

@description('Whether to use private endpoint connections or not.')
param enablePrivateEndpoints bool = true

@description('ID of the AKS subnet')
param aksSubnetId string
@description('ID of the APIM subnet')
param apimSubnetId string
@description('User-Assigned Managed Identity IDs')
param workloadIdentityId string
param aksControlPlaneIdentityId string
param aksKubeletIdentityId string
param aksIngressIdentityId string
param cosmosDbIdentityId string
@description('Private DNS Zone Name')
param privateDnsZoneName string

var abbrs = loadJsonContent('abbreviations.json')
var tags = { 'azd-env-name': resourceGroupName }
var utcString = utcNow()
var aksServiceAccountName = '${aksNamespace}-workload-sa'
var dnsDomain = 'graphrag.io'
var appHostname = 'graphrag.${dnsDomain}'
var appUrl = 'http://${appHostname}'

module log 'core/log-analytics/log.bicep' = {
  name: 'log-analytics-deployment'
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceBaseNameFinal}'
    location: location
    publicNetworkAccessForIngestion: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module aoai 'core/aoai/aoai.bicep' = if (deployAoai) {
  name: 'aoai-deployment'
  params: {
    openAiName: '${abbrs.cognitiveServicesAccounts}${resourceBaseNameFinal}'
    location: location
    llmModelName: llmModelName
    llmModelDeploymentName: llmModelDeploymentName
    llmModelVersion: llmModelVersion
    llmTpmQuota: llmModelQuota
    embeddingModelName: embeddingModelName
    embeddingModelDeploymentName: embeddingModelDeploymentName
    embeddingModelVersion: embeddingModelVersion
    embeddingTpmQuota: embeddingModelQuota
  }
}

module acr 'core/acr/acr.bicep' = if (deployAcr) {
  name: 'acr-deployment'
  params: {
    registryName: '${abbrs.containerRegistryRegistries}${resourceBaseNameFinal}'
    location: location
  }
}

module aks 'core/aks/aks.bicep' = {
  name: 'aks-deployment'
  params: {
    clusterName: '${abbrs.containerServiceManagedClusters}${resourceBaseNameFinal}'
    location: location
    graphragVMSize: 'standard_d8s_v5'
    graphragIndexingVMSize: 'standard_e8s_v5'
    clusterAdmins: [deployer().objectId]
    logAnalyticsWorkspaceId: log.outputs.id
    subnetId: aksSubnetId
    privateDnsZoneName: privateDnsZoneName
    controlPlaneUserAssignedIdentityId: aksControlPlaneIdentityId
    kubeletUserAssignedIdentityId: aksKubeletIdentityId
    ingressUserAssignedIdentityId: aksIngressIdentityId
  }
}

module cosmosdb 'core/cosmosdb/cosmosdb.bicep' = {
  name: 'cosmosdb-deployment'
  params: {
    cosmosDbName: '${abbrs.documentDBDatabaseAccounts}${resourceBaseNameFinal}'
    location: location
    publicNetworkAccess: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
    userAssignedIdentityId: cosmosDbIdentityId
  }
}

module aiSearch 'core/ai-search/ai-search.bicep' = {
  name: 'aisearch-deployment'
  params: {
    name: '${abbrs.searchSearchServices}${resourceBaseNameFinal}'
    location: location
    publicNetworkAccess: enablePrivateEndpoints ? 'disabled' : 'enabled'
  }
}

module storage 'core/storage/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    name: '${abbrs.storageStorageAccounts}${replace(resourceBaseNameFinal, '-', '')}'
    location: location
    publicNetworkAccess: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
    tags: tags
    deleteRetentionPolicy: {
      enabled: true
      days: 5
    }
    defaultToOAuthAuthentication: true
  }
}

module appInsights 'core/monitor/app-insights.bicep' = {
  name: 'app-insights-deployment'
  params: {
    appInsightsName: '${abbrs.insightsComponents}${resourceBaseNameFinal}'
    location: location
    appInsightsPublicNetworkAccessForIngestion: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
    logAnalyticsWorkspaceId: log.outputs.id
  }
}

module apim 'core/apim/apim.bicep' = {
  name: 'apim-deployment'
  params: {
    apiManagementName: !empty(apimName) ? apimName : '${abbrs.apiManagementService}${resourceBaseNameFinal}'
    restoreAPIM: false
    appInsightsId: appInsights.outputs.id
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    publicIpName: '${abbrs.networkPublicIPAddresses}${resourceBaseNameFinal}'
    location: location
    sku: apimTier
    skuCount: 1
    availabilityZones: []
    publisherEmail: apiPublisherEmail
    publisherName: apiPublisherName
    subnetId: apimSubnetId
  }
}
