
choco install psqlodbc -y

$Server = ""
$Port = "5432"
$DB = "postgres"
$Username = ''
$Password = ''
$Query = Get-Content 'createdb.sql' -Raw

$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "Driver={PostgreSQL Unicode(x64)};Server=$Server;Port=5432;Database=postgres;Uid=$Username;Pwd=$Password;"
$cmd = New-object System.Data.Odbc.OdbcCommand($Query,$conn)
$cmd.CommandTimeout = 60
$conn.open()
$cmd.ExecuteNonQuery()
$conn.close()