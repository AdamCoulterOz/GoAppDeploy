# Get the latest release details in JSON format
$latestRelease = Invoke-WebRequest https://github.com/vibrato/TechTestApp/releases/latest -Headers @{"Accept"="application/json"}

# Extract the tag_name attribute for use in getting the specific binary needed
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name
$url = "https://github.com/vibrato/TechTestApp/releases/download/$(latestVersion)/echTestApp_$(latestVersion)_win64.zip"