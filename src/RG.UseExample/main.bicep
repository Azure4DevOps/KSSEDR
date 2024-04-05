param appName string = 'rotateexam'
param stage string = 'dev'
param loc string = 'euw'
param location string = resourceGroup().location

var keyVaultName = '${appName}-${stage}-${loc}-kv'
var storageName = '${appName}${stage}${loc}'
var userAssignedIdentitieName='${appName}-${stage}-${loc}-uai'

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    createMode: 'default'
    enableSoftDelete: false
    softDeleteRetentionInDays: 90    
    sku: {
      name: 'standard'
      family: 'A'
    }        
    accessPolicies: kv_policies
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'      
    }
  }
}

var kv_policies = [
  {
    //fun app
    objectId: '11fd85ac-4aa5-422f-aaef-f5695f7dfb0e'
    tenantId: subscription().tenantId
    permissions: {
      keys: [
        'all'
      ]
      secrets: [
        'all'
      ]
      certificates: [
        'all'
      ]
      storage: [
        'all'
      ]
    }
  }
  {
    //me
    objectId: '23babb49-a328-427c-abbf-4b9a01ed3809'
    tenantId: subscription().tenantId
    permissions: {
      keys: [
        'all'
      ]
      secrets: [
        'all'
      ]
      certificates: [
        'all'
      ]
      storage: [
        'all'
      ]
    }
     {
    //me sp fo
    objectId: 'e82de239-2ad4-4e87-8100-d0bfd1f2134c'
    tenantId: subscription().tenantId
    permissions: {
      keys: [
        'all'
      ]
      secrets: [
        'all'
      ]
      certificates: [
        'all'
      ]
      storage: [
        'all'
      ]
    }
  }
]

param baseTime string = utcNow('u')
var nowEpoch = dateTimeToEpoch(baseTime)
var convertToEpoch = dateTimeToEpoch(dateTimeAdd(baseTime, 'PT5M'))

resource blob_connection_string 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'blob-connection-string'
  tags: {        
        orgin: storageAcct.id
        key: '0'    
    }
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAcct.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAcct.listKeys().keys[0].value}'        
    contentType: storageAcct.id
    attributes: {
        enabled: true
        exp: convertToEpoch
        nbf: nowEpoch        
    }
  }
}

resource storageAcct 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
}

var topicName = '${appName}-${stage}-${loc}-eventgridsystemTopics'

var appResourceGroup = 'Rotate-dev-euw-rg'

var SubsripitonName='${appName}-${stage}-${loc}-subsription'

resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2023-12-15-preview' existing = {
  name: 'rotate-dev-euw-eventgridnamespace'
  scope: resourceGroup(appResourceGroup)
}

resource destinationTopic 'Microsoft.EventGrid/namespaces/topics@2023-12-15-preview' existing = {
  name: 'rotate-dev-euw-eventgridnamespacetopic'
  parent: eventGridNamespace
}

resource topic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: topicName
  location: location
  properties: {
      source: kv.id
      topicType: 'microsoft.keyvault.vaults'
  }
  identity: { type: 'SystemAssigned' }

}

resource resourceProviderSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  dependsOn: [ eventSendRole ]
  name: SubsripitonName
  parent: topic

  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    deliveryWithResourceIdentity: {
      destination: {
        endpointType: 'NamespaceTopic'
        properties: {
          resourceId: destinationTopic.id
        }
      }
      identity: {
        type: 'SystemAssigned'
      }
    }
    filter: {
      enableAdvancedFilteringOnArrays: true
      includedEventTypes: [         'Microsoft.KeyVault.SecretNearExpiry'       ]
    }
    retryPolicy: {
      eventTimeToLiveInMinutes: 1440
      maxDeliveryAttempts: 30
    }
  }
}

param timestamp string = utcNow()
var name = 'rolesender'

module eventSendRole 'roleAssignments.bicep' = {
  name: 'stSendRole-${name}-${timestamp}'
  scope: resourceGroup(appResourceGroup)
  params: {
    principalId: topic.identity.principalId
    roleDefinitionIds: {
      'EventGrid Data Sender': 'd5a91429-5739-47e2-a06b-3470a27159e7'
    }
  }
}