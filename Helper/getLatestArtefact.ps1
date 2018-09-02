# PowerShell defaults to TLS 1.0, github needs TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get the latest release details in JSON format
$latestRelease = Invoke-WebRequest `
  https://github.com/vibrato/TechTestApp/releases/latest `
  -Headers @{"Accept"="application/json"}

# Extract the tag_name attribute for use in getting the specific binary needed
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name

# Build the URL to get the specific win64 version of the app binaries
$baseUrl = "https://github.com/vibrato/TechTestApp/releases/download"
$url = "$baseUrl/$($latestVersion)/TechTestApp_$($latestVersion)_win64.zip"

# Download the file to some local directory
$folder = "./bin"

$output = "$folder/TechTestApp_$($latestVersion)_win64.zip"

Remove-Item $folder -Recurse -ErrorAction Ignore
New-Item -Path $folder -ItemType directory
Invoke-WebRequest -Uri $url -OutFile $output

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipFile = Resolve-Path $output
$unzipFolder = Resolve-Path $folder
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $unzipFolder)

Remove-Item $output

Get-ChildItem -Path "$unzipFolder\dist" -Recurse |  Move-Item -Destination $unzipFolder
Remove-Item "$unzipFolder\dist"
