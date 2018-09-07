<#
 .DESCRIPTION
    Deploys the Vibrato Test App to a given Azure Subscription.
    Requires that the Azure user running it has subscription provisioning rights.
#>

param(
 [Parameter(Mandatory=$True,`
   HelpMessage="ID of SUBSCRIPTION to deploy to.")]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$False,`
   HelpMessage="Name of RESOURCE GROUP to deploy to; cannot be existing.")]
 [string]
 $resourceGroupName="exam-app-adamc",

 [Parameter(Mandatory=$False,`
   HelpMessage="Name of LOCATION to deploy to; specified if resource group is new.")]
 [string]
 $resourceGroupLocation="australiaeast",

 [Parameter(Mandatory=$False,`
   HelpMessage="Name for instance of application deployment; must be unique across Azure websites and contain only letters or numbers.")]
 [string]
 $appInstanceName="vibratotestapp",

 [Parameter(Mandatory=$False,`
   HelpMessage="Path to TEMPLATE file; specified if not template.json in Template folder.")]
 [string]
 $templateFilePath = "./Template/template.json",

 [Parameter(Mandatory=$False,`
   HelpMessage="Path to PARAMETERS file; specified if not parameters.json in Template folder.")]
 [string]
 $parametersFilePath = "./Template/parameters.json"
)

# default variables
$dbUsername = "dbuser"
$dbName = "app"

. ./Helper/GitHubArtefacts.ps1
. ./Helper/GeneratePassword.ps1
. ./Helper/FtpUploadDirectory.ps1

[string]$dbAdminPasswordPlain = GeneratePassword
[securestring]$dbAdminPassword =  ConvertTo-SecureString $dbAdminPasswordPlain -AsPlainText -Force
function downloadArtefactForPlatform($platform,$folder)
{
  $saveFolder = "$folder/$platform"
  New-Item -Path $saveFolder -ItemType directory
  DownloadGitHubArtefact -Organisation "vibrato" `
                         -Repository "TechTestApp" `
                         -PackageName "TechTestApp_[ver]_$platform.zip" `
                         -SavePath $saveFolder `
                         -Unzip

  Get-ChildItem -Path "$saveFolder\dist" -Recurse |  `
      Move-Item -Destination $saveFolder
  Remove-Item "$saveFolder\dist"
}

#******************************************************************************
# Basic Input Validation
#******************************************************************************
$ErrorActionPreference = "Stop"

if((-Not (Test-Path $parametersFilePath)) `
    -Or (-Not (Test-Path $templateFilePath)))
{
  # Halt script because parameters and/or templates files cannot be found.
  Write-Error "Template or Parameters files cannot be found. Halting deployment." `
    -ErrorAction Stop
}

#******************************************************************************
# Host OS Validation
#******************************************************************************
# Determine OS Version
$os = [Environment]::OSVersion.Platform
$is64 = [System.Environment]::Is64BitProcess

switch($os)
{
  "Unix" { $plat = "darwin"}
  "Linux" { If($is64) { $plat = "linux64" } }
  "Win32NT" { If($is64) { $plat = "win64" } Else {$plat = "win32"} }
}

if(!$plat)
{
  Write-Error "Current Host OS is not supported. Supported OS includes Unix 64bit, Linux 64bit, Win 32/64bit." `
    -ErrorAction Stop
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

# Register Relevent Resource Providers for Azure services used
$resourceProviders = @("microsoft.web","microsoft.dbforpostgresql")
Write-Host "Registering resource providers"
foreach($resourceProvider in $resourceProviders) {
    Write-Host "Registering resource provider '$resourceProvider'"
    Register-AzureRmResourceProvider -ProviderNamespace $resourceProvider
}

# Check and Halt if resource group already exists
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName `
                                          -ErrorAction SilentlyContinue
if($resourceGroup)
{
  # Halt script because resource group name is already in use.
  Write-Error "Resource group with name '$resourceGroupName' is already in use. `
                Halting deployment." -ErrorAction Stop
}
else
{
  # Create resource group in specified location
  Write-Host "Creating resource group '$resourceGroupName' `
  in location '$resourceGroupLocation'"

  New-AzureRmResourceGroup -Name $resourceGroupName `
              -Location $resourceGroupLocation
}

# Start the deployment
Write-Host "Starting deployment..."
New-AzureRmResourceGroupDeployment  -ResourceGroupName $resourceGroupName `
                                    -TemplateFile $templateFilePath `
                                    -TemplateParameterFile $parametersFilePath `
                                    -appInstName $appInstanceName `
                                    -dbAdminUser $dbUsername `
                                    -dbAdminPass $dbAdminPassword `
                                    -dbName $dbName

#******************************************************************************
# Get & Stage Go App Deployment Files
#******************************************************************************

Write-Host "Getting latest artefacts from Vibrato github..."

#clear bin folder from previous attempts
Remove-Item ".\bin" -Recurse -ErrorAction Ignore
New-Item -Path ".\bin" -ItemType directory
$appdirectory=Resolve-Path ".\bin"

$deploymentPlatform = "win64"
downloadArtefactForPlatform -platform $deploymentPlatform -folder $appdirectory
Copy-Item ".\Config\web.config" -Destination "$appdirectory\$deploymentPlatform\"

#******************************************************************************
# Deploy Go App Deployment Files
#******************************************************************************

Write-Host "Download publishing profile..."
# Get publishing profile for the web app
$xml = [xml](Get-AzureRmWebAppPublishingProfile -Name $appInstanceName `
                                                -ResourceGroupName $resourceGroupName)

# Extract connection information from publishing profile
$baseXPath = "//publishProfile[@publishMethod=`"MSDeploy`"]"

$username = $xml.SelectNodes("$baseXPath/@userName").value
$password = $xml.SelectNodes("$baseXPath/@userPWD").value

# Upload bin folder contents to wwwroot, maintaining folder structure

$sourceFolder = "$appdirectory/$deploymentPlatform"

# zip the publish folder
$destination = "$appdirectory/publish.zip"
if(Test-path $destination) {Remove-item $destination}
Add-Type -assembly "System.IO.Compression.FileSystem"
[IO.Compression.ZipFile]::CreateFromDirectory($sourceFolder, $destination)

WebDeploy -username $username -password $password -zipPath $destination -appName $appInstanceName

#******************************************************************************
# Initialise Database
#******************************************************************************

$env:VTT_DBUSER = "$dbUsername@$appInstanceName"
$env:VTT_DBPASSWORD = $dbAdminPasswordPlain
$env:VTT_DBNAME = $dbName
$env:VTT_DBHOST = "$appInstanceName.postgres.database.azure.com"

$execPath = "./TechTestApp.exe"
if(-Not ($plat -Eq "win64"))
{
  downloadArtefactForPlatform -platform $plat -folder $appdirectory
  $execPath = "./TechTestApp"
  if($plat.StartsWith("win")) { $execPath += ".exe" }
}
Set-Location "$appdirectory/$plat/"
#ensure executeable has exec permission
#this is needed because the .net core implemention of unzip doesnt retain exec permissions
if(($plat -eq "darwin") -or ($plat -eq "linux64"))
{
  chmod +x TechTestApp
}

& $execPath "updatedb" "-s"
#******************************************************************************
# Restart Web App and Test Deployment
#******************************************************************************
Restart-AzureRmWebApp -ResourceGroupName $resourceGroupName `
                   -Name $appInstanceName

$passedTest = $False
For ($i=0; $i -le 3; $i++)
{
  $response = Invoke-WebRequest -Uri "https://$appInstanceName.azurewebsites.net/healthcheck/" -TimeoutSec 10  -ErrorAction Ignore
  if($response.StatusCode -eq 200)
  {
    $passedTest = $True
    Break
  }
  Start-Sleep -Seconds 2
}

if($passedTest) {
  Write-Output "App deployed successfully. Browse to deployed website here: https://$appInstanceName.azurewebsites.net/"
}
else {
  Write-Error "There was a problem with the deployment."
}
