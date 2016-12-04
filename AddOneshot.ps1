Param(
	[String]$Path = "C:\Program Files\Infocyte\SplunkData" # Output Path of SplunkData json files - this folder should be monitored by a Splunk Forwarder
	[PSCredential]$Credential
)

$splunk = "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe"
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
	&$splunk add oneshot "$Path\$_.json" -index infocyte -sourcetype infocytescan -auth $username:$password
}
