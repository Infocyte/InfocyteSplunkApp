
$psql = "C:\Program Files\Infocyte\Dependencies\Postgresql\bin\psql.exe"
<# 
$creds = Get-Credential "postgres"
$username = $creds.Username
$env:PGPASSWORD = $creds.GetNetworkCredential().Password
#>
# Grab postgres password from config file
$PGConfig = (gc "C:\Program Files\Infocyte\Hunt-UI-Server\server\datasources.json" | ConvertFrom-Json).db
$username = "postgres"
$env:PGPASSWORD = $PGConfig.password
$database = $PGConfig.database

# Load Database Views
&$psql -U $username -d $database -f "$PSScriptRoot\splunk.sql"