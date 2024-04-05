param appName string = 'rotate'
param stage string = 'dev'
param loc string = 'euw'
param location string = resourceGroup().location

var EventGridNamespaceName = '${appName}-${stage}-${loc}-eventgridnamespace'
var EventGridNamespaceTopicName = '${appName}-${stage}-${loc}-eventgridnamespacetopic'
var EventGridTopicName = '${appName}-${stage}-${loc}-eventgridtopic'
var appServicePlanName = '${appName}-${stage}-${loc}-applan'
var webSiteName = '${appName}-${stage}-${loc}-applan-funapp'
var webSiteName2 = '${appName}-${stage}-${loc}-applan-funapp2'
var storageName = '${appName}${stage}${loc}'
var appinsName = '${appName}-${stage}-${loc}-appins'
var userAssignedIdentitieName='${appName}-${stage}-${loc}-uai'


resource symbolicname 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentitieName
  location: location
  tags: {
    tagName1: 'tagValue1'
    tagName2: 'tagValue2'
  }
}

output objectId string = symbolicname.id

resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2023-12-15-preview' = {
  name: EventGridNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
  identity: { type: 'SystemAssigned' }
}

resource eventGridNamespaceTopic 'Microsoft.EventGrid/namespaces/topics@2023-12-15-preview' = {
  parent:  eventGridNamespace
  name: EventGridNamespaceTopicName  
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: webSiteName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(webSiteName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appinsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    DisableIpMasking: true
  }
}

var eventHubNamespaceName = '${appName}-${stage}-${loc}-eventHubNamespace'
var eventHubName = '${appName}-${stage}-${loc}-eventHubName'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}