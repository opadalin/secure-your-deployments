param location string
param tags object

@description('A unique string')
param uniqueNameId string = substring(uniqueString(resourceGroup().id), 0, 5)

@description('The storage account for the function app')
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'sa${uniqueNameId}dev'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
    }
  }
  resource blobServices 'blobServices' = {
    name: 'default'
  }
}
