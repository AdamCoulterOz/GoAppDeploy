# PowerShell defaults to TLS 1.0, github needs TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get the latest release details in JSON format
$latestRelease = Invoke-WebRequest https://github.com/vibrato/TechTestApp/releases/latest -Headers @{"Accept"="application/json"}

# Extract the tag_name attribute for use in getting the specific binary needed
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name

# Build the URL to get the specific win64 version of the app binaries
$url = "https://github.com/vibrato/TechTestApp/releases/download/$($latestVersion)/TechTestApp_$($latestVersion)_win64.zip"

# Download the file to some local directory
$output = "C:\Users\adamc\TechTestApp_$($latestVersion)_win64.zip"
Invoke-WebRequest -Uri $url -OutFile $output