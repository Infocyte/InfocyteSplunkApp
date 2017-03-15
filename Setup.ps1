function Setup-InfocyteToSplunk {
	Param(
		[Parameter()]
		[Bool]$All # Dump all objects (defaults to Bad, Suspicious, Unknown, and Synapse below -0.5)
	)

	$psql = "C:\Program Files\Infocyte\Dependencies\Postgresql\bin\psql.exe"
	<# 
	$creds = Get-Credential "postgres"
	$username = $creds.Username
	$env:PGPASSWORD = $creds.GetNetworkCredential().Password
	#>

	Write-Host "Setting up database views for Splunk export"
	# Grab postgres password from config file
	$PGConfig = (gc "C:\Program Files\Infocyte\Hunt-UI-Server\server\datasources.json" | ConvertFrom-Json).db
	$username = "postgres"
	$env:PGPASSWORD = $PGConfig.password
	$database = $PGConfig.database

	# Load Database Views
	if ($All) {
		&$psql -U $username -d $database -f "$PSScriptRoot\splunk2.sql"
	} else {
		&$psql -U $username -d $database -f "$PSScriptRoot\splunk.sql"
	}
}

Setup-InfocyteToSplunk