# Configuring OpenID Connect in Azure

This guide will help you set up OpenID Connect (OIDC) in Azure for GitHub Actions workflows authentication. With OIDC, your workflows can access Azure resources without storing your Azure credentials as long-lived GitHub secrets. This guide includes instructions on how to run a script to set up your environment.

Learn more about OIDC and Azure: [Use OpenID Connect within your workflows to authenticate with Azure.](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)

# Prerequisites

Before running the script, you need to complete the following prerequisites:

1. [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. [Install GitHub CLI](https://cli.github.com)

3. When using the GitHub CLI, make sure you have the correct permissions set up for your access token. Minimum requirements are:
    - admin:org 
    - repo 
    - workflow

    Navigate to [Personal access tokens (classic)](https://github.com/settings/tokens) to generate a new access token.

4. You'll need sufficient Azure role assignment set to be able to create roles in Azure. More specifically _Microsoft.Authorization/roleAssignments/write_. It is sufficient to activate the Owner role on subscription level since it includes the _Microsoft.Authorization/roleAssignments/write_ permission. Learn more on how to activate Azure resource roles in Privileged Identity Management here: [Activate my Azure resource roles in Privileged Identity Management](https://learn.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-resource-roles-activate-your-roles). Or navigate directly to [Privileged Identity Management](https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac)

    The script will stop running if you do not have the owner role assigned since it is required for you to be able to assign the owner role for the user-assigned Managed Identity on your resource group.
___

# What the script does

The script will:

## Check Azure CLI login status and assigned roles

1. The script will first check if you have logged in to your Azure account. If not, it will log you in automatically (your browser will open up the login page for Azure portal and prompt you to log in).

2. If login succeeded you will see which subscription you have choosen and prompt you if you would like to continue with that subscription. If not, the script will exit and tell you how you can switch your subscription by using the following az cli command: `az account set -s xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`. 
You can use `az account list` to list all of your subscriptions.

3. Next, the script will list all of your assigned roles and check if you have sufficient permissions to continue. It will prompt you to activate the owner role in Privileged Identity Management if you have not already. See [Prerequisites](#prerequisites) section on how to do so.

## Configure OpenID Connect trust in Azure

1. The script will create a resource group to hold related resources for an Azure solution. Read more about [resource groups](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-cli).

2. Set up a user-assigned Managed Identity with federated identity credentials to create a trust relationship between your GitHub Actions workflows and your user-assigned managed identity in Azure Active Directory. This eliminates the need to store Azure credentials as long-lived GitHub secrets. The user-assigned managed identity will be assigned the Owner role scoped for the resource group to manage any other resources created later. Learn more about managed identities [here](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) and federated identity credentials [here](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation). 

    _NOTE: federated identity credentials for a user-assigned managed identities are not yet supported for all regions. See [Unsupported regions (user-assigned managed identities)](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation-considerations#unsupported-regions-user-assigned-managed-identities)_

## Setting GitHub repository secrets

Lastly, the script will create repository secrets in your GitHub repository. These secrets can then be used in the azure/login GitHub action. The action receives a JWT from the GitHub OpenID Connect provider, and with that, requests an access token from Azure. This token can then be used to access Azure cloud resources.
___

# Setting up _local.settings.jsonc_

The script will read from a file called _local.settings.jsonc_ located in the same directory. These settings are used to set up the names for your Azure resources and set the name of your GitHub repository that you are using. Copy the _local.settings.default.jsonc_ file and name it _local.settings.jsonc._ Add the names in the file. The file should be ignored by git to avoid checking in any possible sensitive information about your application.
___

# Running the _OpenId-Connect-With-User-Assigned-MI.ps1_ script

To run the script, open PowerShell and navigate to the directory where the script is saved. Then, run the following command:

```powershell
./OpenId-Connect-With-User-Assigned-Managed-Identity.ps1
```

Follow the instructions provided by the script to configure OpenID Connect in Azure.


## Overview

![overview](OpenIdConnectWithUserAssignedManagedIdentity.drawio.png)