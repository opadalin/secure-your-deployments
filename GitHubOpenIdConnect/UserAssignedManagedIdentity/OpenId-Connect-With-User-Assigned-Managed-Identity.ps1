$ErrorActionPreference = "Stop"
# https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure

Write-Host "-----------------------------------------------"
Write-Host "|  Configuring OpenID Connect trust in Azure  |"
Write-Host "-----------------------------------------------"

Write-Host "Making sure user is logged in to correct Azure tenant and subscription"

$signedInUserId = az ad signed-in-user show --query id -o tsv

if ($null -eq $signedInUserId) {
    az login -o none
}

$userPrincipalName = az account show --query user.name -o tsv
$userDisplayName = az ad user list --upn $userPrincipalName --query [].displayName -o tsv
$azureAccountName = az account show --query name -o tsv
Write-Host "Signed in as $userDisplayName to $azureAccountName"
$azureAccount = az account show --query "{subscriptionId:id,tenantId:tenantId,name:name}"
Write-Output $azureAccount

$promptResponse = Read-Host -Prompt "Do you want to use the above subscription? (y/N)"
if ([string]::IsNullOrWhiteSpace($promptResponse) -or $promptResponse.ToLower() -eq "y" -or $promptResponse.ToLower() -eq "yes") {
    # Do nothing
}
else {
    Write-Host "Use the \`az account set -s\` command to set the subscription you'd like to use and re-run this script."
    exit 0
}

$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
$userRoleDefinitionNames = az role assignment list --all --assignee $userPrincipalName --query [].roleDefinitionName -o tsv

if ($userRoleDefinitionNames.Contains("Owner") -eq $false) {
    Write-Host "The Owner role must be assigned to $userDisplayName in order to create role assignments in this script."
    Write-Host "Follow the link to see how to activate Azure resource roles in Privileged Identity Management: https://learn.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-resource-roles-activate-your-roles"
    exit 0
}

Write-Host "Assigned roles for $userDisplayName"
az role assignment list --all --assignee $userPrincipalName --output json --query '[].{principalName:principalName, principalId:principalId, roleDefinitionName:roleDefinitionName, scope:scope}'

Write-Host "--------------------------------------------------------------------------------------"
Write-Host "|  Configuring settings for the OpenID Connect integration between GitHub and Azure  |"
Write-Host "--------------------------------------------------------------------------------------"
$localSettingsJson = Get-Content ./../local.settings.jsonc -Raw | ConvertFrom-Json
$userAssignedManagedIdentityName = $localSettingsJson.name
$repositoryName = $localSettingsJson.repositoryName
$resourceGroupName = $localSettingsJson.resourceGroup.name
$location = $localSettingsJson.resourceGroup.location
$tags = $localSettingsJson.resourceGroup.tags | ForEach-Object {
    $props = $_.PSObject.Properties | ForEach-Object {
        $name = $_.Name
        $value = $_.Value
        "$name=$value"
    }
    $props -join ' '
}

Write-Host "User-assigned Managed Identity name: '$userAssignedManagedIdentityName'"
Write-Host "GitHub repository: '$repositoryName'"
Write-Host "Resource group: '$resourceGroupName' in '$location'"
Write-Host "Tags: $tags"

if (($null -eq $repositoryName) -or ($null -eq $resourceGroupName) -or ($null -eq $location) -or ($null -eq $userAssignedManagedIdentityName)) {
    Write-Host "Insufficient parameters provided. Please make sure..."
    Write-Host "    - name"
    Write-Host "    - repositoryName"
    Write-Host "    - resourceGroup.name"
    Write-Host "    - resourceGroup.location"
    Write-Host "are populated in your local.settings.jsonc file."
    exit 0
}

$promptResponse = Read-Host -Prompt "Do you want to proceed with the above configuration? (y/N)"
if ($promptResponse.ToLower() -eq "y" -or $promptResponse.ToLower() -eq "yes") {
    # Do nothing
}
else {
    Write-Host "Make your preferred changes in the local.settings.jsonc file, and run the script anew"
    exit 0
}

# Configuring resource group
##############################################################################################################################################################################################################################################
Write-Host "--------------------------------"
Write-Host "|  Configuring resource group  |"
Write-Host "--------------------------------"
$resourceGroupExists = az group exists -n $resourceGroupName
if ($resourceGroupExists -eq $true) {
    Write-Host "Resource group '$resourceGroupName' already created."
}
else {
    Write-Host "Creating new resource group '$resourceGroupName' in '$location'"
    az group create -l $location -n $resourceGroupName --tags $tags
    az group wait --created --resource-group $resourceGroupName # Waiting for the resource group to be created   
}

# Configuring user-assigned Managed Identity with federated credentials
##############################################################################################################################################################################################################################################
Write-Host "------------------------------------------------"
Write-Host "|  Configuring user-assigned Managed Identity  |"
Write-Host "------------------------------------------------"
Write-Host "Creating user-assigned Managed Identity '$userAssignedManagedIdentityName':"
$userAssignedManagedIdentityClientId = az identity create --name $userAssignedManagedIdentityName --resource-group $resourceGroupName --location $location --subscription $subscriptionId --tags $tags --query clientId -o tsv
$userAssignedManagedIdentityPrincipalId = az identity show --name $userAssignedManagedIdentityName --resource-group $resourceGroupName --query principalId -o tsv
az identity show --name $userAssignedManagedIdentityName --resource-group $resourceGroupName

Write-Host "------------------------------------------------------------------------------"
Write-Host "|  Configuring federated credentials for '$userAssignedManagedIdentityName'  |"
Write-Host "------------------------------------------------------------------------------"
$audience = "api://AzureADTokenExchange"
$issuer = "https://token.actions.githubusercontent.com"

Write-Host "Creating a federated identity credential for '$repositoryName' main branch"
az identity federated-credential create --name "mainfic" --identity-name $userAssignedManagedIdentityName --resource-group $resourceGroupName --issuer $issuer --subject "repo:$($repositoryName):ref:refs/heads/main" --audiences $audience

Write-Host "Creating a federated identity credential for '$repositoryName' pull request"
az identity federated-credential create --name "prfic" --identity-name $userAssignedManagedIdentityName --resource-group $resourceGroupName --issuer $issuer --subject "repo:$($repositoryName):pull_request" --audiences $audience

$userAssignedIdentityPrincipalId = az identity show --name $userAssignedManagedIdentityName --resource-group $resourceGroupName --query principalId -o tsv
Write-Host "Assigning Owner role for user-assigned Managed Identity on resource group level:"
az role assignment create --role Owner --subscription $subscriptionId --assignee-object-id $userAssignedIdentityPrincipalId --assignee-principal-type ServicePrincipal --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName

# Setting GitHub repository secrets
##############################################################################################################################################################################################################################################
Write-Host "---------------------------------------"
Write-Host "|  Setting GitHub repository secrets  |"
Write-Host "---------------------------------------"
Write-Host "Creating the following GitHub repository secrets..."
Write-Host "AZURE_CLIENT_ID: '$userAssignedManagedIdentityClientId'"
Write-Host "AZURE_SUBSCRIPTION_ID: '$subscriptionId'"
Write-Host "AZURE_TENANT_ID: '$tenantId'"
Write-Host "AZURE_PRINCIPAL_ID: '$userAssignedManagedIdentityPrincipalId'"
Write-Host "AZURE_SIGNED_IN_USER_ID: '$signedInUserId'"
Write-Host "AZURE_RESOURCE_GROUP_NAME: '$resourceGroupName'"

Write-Host "Logging into GitHub CLI..."
gh auth login

gh secret set AZURE_CLIENT_ID -b $userAssignedManagedIdentityClientId --repo $repositoryName
gh secret set AZURE_SUBSCRIPTION_ID -b $subscriptionId --repo $repositoryName
gh secret set AZURE_TENANT_ID -b $tenantId --repo $repositoryName
gh secret set AZURE_PRINCIPAL_ID -b $userAssignedManagedIdentityPrincipalId --repo $repositoryName
gh secret set AZURE_SIGNED_IN_USER_ID -b $signedInUserId --repo $repositoryName
gh secret set AZURE_RESOURCE_GROUP_NAME -b $resourceGroupName --repo $repositoryName
