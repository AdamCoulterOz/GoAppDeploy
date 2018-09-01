<#
 .DESCRIPTION
    Deploys the Vibrato Test App to a given Azure Subscription.
    Requires that the Azure user running it has subscription provisioning rights.
#>

param(
 [Parameter(Mandatory=$True,HelpMessage="ID of SUBSCRIPTION to deploy to.")]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True,HelpMessage="Name of RESOURCE GROUP to deploy to; cannot be existing.")]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True,HelpMessage="Name of LOCATION to deploy to; specified if resource group is new.")]
 [string]
 $resourceGroupLocation,

 [Parameter(Mandatory=$True,HelpMessage="Name for instance of application deployment; must be unique across Azure websites and contain only letters or numbers.")]
 [string]
 $appInstanceName,

 [Parameter(Mandatory=$True,HelpMessage="Password to use as default database admin account.")]
 [securestring]
 $dbAdminPassword,

 [Parameter(Mandatory=$False,HelpMessage="Path to TEMPLATE file; specified if not template.json in local folder.")]
 [string]
 $templateFilePath = "./Templates/template.json",

 [Parameter(Mandatory=$False,HelpMessage="Path to PARAMETERS file; specified if not parameters.json in local folder.")]
 [string]
 $parametersFilePath = "./Templates/parameters.json"
)

#******************************************************************************
# Basic Input Validation
#******************************************************************************
$ErrorActionPreference = "Stop"

if((-Not (Test-Path $parametersFilePath)) -Or (-Not (Test-Path $templateFilePath)))
{
  # Halt script because parameters and/or templates files cannot be found.
  Write-Error "Template or Parameters files cannot be found. Halting deployment." -ErrorAction Stop
}

#******************************************************************************
# Execution
#******************************************************************************

# Login to Azure Account
Write-Host "Logging in..."
Login-AzureRmAccount

# Find and select Azure Subscription
Write-Host "Selecting subscription '$subscriptionId'"
Select-AzureRmSubscription -SubscriptionID $subscriptionId

# Register Relevent Resource Providers
$resourceProviders = @("microsoft.web","microsoft.dbforpostgresql")
Write-Host "Registering resource providers"
foreach($resourceProvider in $resourceProviders) {
    Write-Host "Registering resource provider '$resourceProvider'"
    Register-AzureRmResourceProvider -ProviderNamespace $resourceProvider
}

# Check and Halt if resource group already exists
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if($resourceGroup)
{
  # Halt script because resource group name is already in use.
  Write-Error "Resource group with name '$resourceGroupName' is already in use. Halting deployment." -ErrorAction Stop
}

# Create resource group in specified location
Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'"
New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation

# Start the deployment
Write-Host "Starting deployment..."
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -appInstName $appInstanceName -dbAdminPass $dbAdminPassword
