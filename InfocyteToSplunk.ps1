function Get-InfocyteToSplunk {
	Param(
		[Parameter()]
		[Int]$Days = 7, # Age of new data to pull from HUNT (in days)
		[String]$Path = "C:\Program Files\Infocyte\SplunkData\" # Output Path of SplunkData json files - this folder should be monitored by a Splunk Forwarder
	)

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

	$CompletionDate = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-dd HH:mm:ss')

	if (-NOT (Test-Path $Path)) {
		New-Item $Path -ItemType "directory"
	}

	$ObjectTypes = @(
		"splunkmodules",
		"splunkprocesses",
		"splunkautostarts",
		"splunkmem",
		"splunkconnection",
		"splunkscan",
		"splunkhost"
		)

	# Create commands
	$Commands = $ObjectTypes | % { "COPY (select row_to_json($_) from $_ where scancompletedon > '" + $CompletionDate + "') to '" + $Path + "$_.json'" }
		
	# Check if Splunkviews are loaded
	if (&$psql -U $username -d $database -c "select viewname from pg_catalog.pg_views where schemaname NOT IN ('pg_catalog', 'information_schema')" | Select-String splunk) {
		# Views Exist
	} else { 
		Write-Warning "ERROR: Splunk Views have not been loaded in the Infocyte Database.  Run SetupInfocyteViews.ps1 first!"
		Start-Wait 3
		return
	}

	# Run psql command to dump views
	$Commands | % { &$psql -U $username -d $database -c $_ }

}

function Add-InfocyteToSplunk {
	Param(
		[String]$Path = "C:\Program Files\Infocyte\SplunkData" # Output Path of SplunkData json files - this folder should be monitored by a Splunk Forwarder
		[PSCredential]$Credential
	)

	$SplunkForwarderPath = "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe"
	
	if ($Credential) {
		$username = $Credential.Username
		$password = $Credential.GetNetworkCredential().password
	} else {
		$username = "admin"
		$password = "changeme"
	}



	if (-NOT (Test-Path $Path)) {
		Write-Warning "$Path is not a valid path"
	}

	$ObjectTypes = @(
		"splunkmodules",
		"splunkprocesses",
		"splunkautostarts",
		"splunkmem",
		"splunkconnection",
		"splunkscan",
		"splunkhost"
		)

	# Create commands
	$Commands = $ObjectTypes | % { 
		Write-Host "Adding $Path\$_.json to index infocyte and sourcetype infocytescan"
		&$SplunkForwarderPath add oneshot "$Path\$_.json" -index infocyte -sourcetype infocytescan -auth $username:$password
	}
}


















<# 
$ScriptPath = "$PSScriptRoot\splunk.PS1"
 
# Trigger Every 5 Minutes
$Trigger = New-JobTrigger -Once -At $(get-date) -RepetitionInterval (New-TimeSpan -Minute 5) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledJob -Name InfocyteSplunk -FilePath $scriptPath -Trigger $Trigger

#>

