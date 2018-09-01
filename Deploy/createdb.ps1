param (
    [Parameter(Mandatory=$True)]
    [string]$Server,

    [Parameter(Mandatory=$True)]
    [string]$Username,

    [Parameter(Mandatory=$True)]
    [string]$Password,

    [Parameter(Mandatory=$False)]
    [string]$Port = "5432",

    [Parameter(Mandatory=$False)]
    [string]$Database = "app"
)

# Build the connection string
$builder = New-Object System.Data.Odbc.OdbcConnectionStringBuilder
$builder.Driver = "PostgreSQL Unicode(x64)"
$builder.Add("Server", $Server)
$builder.Add("Port", $Port)
$builder.Add("Database", "postgres")
$builder.Add("Uid", $Username)
$builder.Add("Pwd", $Password)

# Pass connection string to new connection
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = $builder.ConnectionString

# Read query to run from file
$dropDbQuery = "DROP DATABASE IF EXISTS $Database;"
$createDbQuery = "CREATE DATABASE $Database
                    WITH
                    ENCODING = 'UTF8'
                    LC_COLLATE = 'en-US'
                    LC_CTYPE = 'en-US'
                    CONNECTION LIMIT = -1
                    TEMPLATE = template0;"

# Define commands
$dropCmd = New-object System.Data.Odbc.OdbcCommand($dropDbQuery,$conn)
$createCmd = New-object System.Data.Odbc.OdbcCommand($createDbQuery,$conn)
$createCmd.CommandTimeout = 60

# Connect
$conn.Open()

# Drop database if exists
echo "Attempting DROP IF EXISTS"
$dropResult = $dropCmd.ExecuteNonQuery();
echo "DROP Result: $($dropResult.ToString().Trim())"

# Create database
echo "Attempting CREATE"
$createResult = $createCmd.ExecuteNonQuery()
echo "CREATE Result: $($createResult.ToString().Trim())"

# Close connection
$conn.Close()
