param (
    [Parameter(Mandatory=$True)]
    [string]$Server,

    [Parameter(Mandatory=$True)]
    [string]$Username,

    [Parameter(Mandatory=$True)]
    [Security.SecureString]$Password,

    [Parameter(Mandatory=$False)]
    [string]$Port = "5432",

    [Parameter(Mandatory=$False)]
    [string]$DB = "postgres"
)

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
$webClient = New-Object System.Net.WebClient
$installScript = $webClient.DownloadString('https://chocolatey.org/install.ps1')
Invoke-Expression $installScript

# Use Chocolatey to install PostgreSQL ODBC driver
choco install psqlodbc -y

# Build the connection string
$builder = New-Object System.Data.Odbc.OdbcConnectionStringBuilder
$builder.Driver = "PostgreSQL Unicode(x64)"
$builder.Add("Server", $Server)
$builder.Add("Port", $Port)
$builder.Add("Database", $DB)
$builder.Add("Uid", $Username)
$builder.Add("Pwd", $(ConvertFrom-SecureString $Password))

# Pass connection string to new connection
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = $builder.ConnectionString
#$conn.ConnectionString = "Driver={PostgreSQL Unicode(x64)};Server=$Server;Port=$Port;Database=$DB;Uid=$Username;Pwd=$(ConvertFrom-SecureString $Password);"

# Read query to run from file
$Query = Get-Content 'createdb.sql' -Raw

# Execute Query
$cmd = New-object System.Data.Odbc.OdbcCommand($Query,$conn)
$cmd.CommandTimeout = 60
$conn.open()
$cmd.ExecuteNonQuery()
$conn.close()