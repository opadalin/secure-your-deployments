@description('Location for all resources.')
param location string = resourceGroup().location

param tags object = {
  'Competence-day': '2023-06-09'
}

module storgageAccountDeploy 'storageAccount.bicep' = {
  name: 'storage-account-deployment'
  params: {
    location: location
    tags: tags
  }
}

