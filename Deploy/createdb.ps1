﻿param (
    [Parameter(Mandatory=$True)]
    [string]$Server,

    [Parameter(Mandatory=$True)]
    [string]$Username,

    [Parameter(Mandatory=$True)]
    [Security.SecureString]$Password,

    [Parameter(Mandatory=$False)]
    [string]$Port = "5432",

    [Parameter(Mandatory=$False)]
    [string]$Database = "postgres"
)

# Build the connection string
$builder = New-Object System.Data.Odbc.OdbcConnectionStringBuilder
$builder.Driver = "PostgreSQL Unicode(x64)"
$builder.Add("Server", $Server)
$builder.Add("Port", $Port)
$builder.Add("Database", $Database)
$builder.Add("Uid", $Username)
$builder.Add("Pwd", $(ConvertFrom-SecureString $Password))

# Pass connection string to new connection
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = $builder.ConnectionString
#$conn.ConnectionString = "Driver={PostgreSQL Unicode(x64)};Server=$Server;Port=$Port;Database=$DB;Uid=$Username;Pwd=$(ConvertFrom-SecureString $Password);"

# Read query to run from file
$Query = Get-Content '../config/createdb.sql' -Raw

# Execute Query
$cmd = New-object System.Data.Odbc.OdbcCommand($Query,$conn)
$cmd.CommandTimeout = 60
$conn.Open()
$cmd.ExecuteNonQuery()
$conn.Close()