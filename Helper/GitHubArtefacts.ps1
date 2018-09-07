function GetGitHubArtefactLatestVersion ([string]$Organisation, [string]$Repository)
{
  # PowerShell defaults to TLS 1.0, github needs TLS 1.2
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $baseURL = "https://github.com/$Organisation/$Repository"

  # Get the latest release details in JSON format
  $latestRelease = Invoke-WebRequest `
    "$baseURL/releases/latest" `
    -Headers @{"Accept"="application/json"}

  # Extract the tag_name attribute for use in getting the specific binary needed
  $json = $latestRelease.Content | ConvertFrom-Json
  return $json.tag_name
}

function DownloadGitHubArtefact([string]$Organisation,[string]$Repository,[string]$PackageName,[string]$SavePath,[switch]$Unzip)
{
  $latestVersion = GetGitHubArtefactLatestVersion -Organisation $Organisation -Repository $Repository

  #Substitute version flag if set
  $packageName = $PackageName.Replace("[ver]",$latestVersion)

  # PowerShell defaults to TLS 1.0, github needs TLS 1.2
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $baseURL = "https://github.com/$Organisation/$Repository"
  
  # Build the URL to get the specific win64 version of the app binaries
  $url = "$baseUrl/releases/download/$latestVersion/$packageName"

  # Download the file to specified location
  $output = "$SavePath/$packageName"

  Write-Host "Downloading '$url' to '$output'."
  Invoke-WebRequest -Uri $url -OutFile $output

  if($Unzip)
  {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFile = Resolve-Path $output
    $unzipFolder = Resolve-Path $SavePath
    Write-Host "Unzipping '$zipFile' to '$unZipfolder'."
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $unzipFolder)

    Remove-Item $output
  }
}


