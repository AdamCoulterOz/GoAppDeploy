# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
$webClient = New-Object System.Net.WebClient
$installScript = $webClient.DownloadString('https://chocolatey.org/install.ps1')
Invoke-Expression $installScript

# Use Chocolatey to install PostgreSQL ODBC driver
choco install psqlodbc -y -Force