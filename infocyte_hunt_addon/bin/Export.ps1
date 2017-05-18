<#

#>
Param(
	[Parameter()]
	[Int]$Days = 0, # Age of new data to pull from HUNT (in days)
	
	[Parameter()]
	[String]$HuntServer = "https://localhost:4443",
	
	[Parameter()]
	[String]$OutPath = "C:\Program Files\SplunkUniversalForwarder\etc\app\infocyte_hunt_addon\bin\SplunkData", # Output Path of SplunkData json files
	
	[Parameter()]
	[Switch]$Replace,
	
	[Parameter()]
	[PSCredential]$HuntCredential
)

# $Script:HuntServer = 'https://demo.infocyte.com'
$SplunkHome = "C:\Program Files\SplunkUniversalForwarder\etc\app\infocyte_hunt_addon"

if (-NOT $HuntCredential.username) {
	# Grab from config file
	$username = (Get-Contect $SplunkHome\bin\export.config)[0]
	$password = (Get-Contect $SplunkHome\bin\export.config)[1] | ConvertTo-SecureString -asPlainText -Force
	
	#Use Default Infocyte Credentials
	#$username = 'infocyte'
	#$password = 'pulse' | ConvertTo-SecureString -asPlainText -Force
	$Script:HuntCredential = New-Object System.Management.Automation.PSCredential($username,$password)
}


if (-NOT (Test-Path $OutPath)) {
	New-Item $OutPath -ItemType "directory"
}


# Functions

## FUNCTIONS

#Get Login Token (required)
function New-ICToken ([PSCredential]$Credential, [String]$HuntServer = "https://localhost:4443" ) {
	Write-Verbose "Requesting new Token from $HuntServer using account $($Credential.username)"
	Write-Verbose "Credentials and Hunt Server Address are stored in global variables for use in all IC cmdlets"
	if (-NOT ([System.Net.ServicePointManager]::ServerCertificateValidationCallback)) { 
		#Accept Unsigned CERTS
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
	}
	if (-NOT $Credential) {
		# Default Credentials
		$username = 'infocyte'
		$password = 'pulse' | ConvertTo-SecureString -asPlainText -Force
		$Credential = New-Object System.Management.Automation.PSCredential($username,$password)
	}
	
	$Global:HuntServerAddress = $HuntServer
	
	$data = @{
		username = $Credential.GetNetworkCredential().username
		password = $Credential.GetNetworkCredential().password
	}
	$i = $data | ConvertTo-JSON
	try {
		$response = Invoke-RestMethod "$HuntServerAddress/api/users/login" -Method POST -Body $i -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	if ($response -match "Error") {
		Write-Warning "Error: Unauthorized"
		return "ERROR: $($_.Exception.Message)"
	} else {
		# Set Token to global variable
		$Global:ICToken = $response.id
		Write-Verbose 'New token saved to global variable: $Global:ICToken'
		$response
	}
}


# Get Scan Metadata
function Get-ICTargetList {
	Write-Verbose "Requesting TargetLists from $HuntServerAddress"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"order":["name","id"]}')
	try {
		$objects += Invoke-RestMethod ("$HuntServerAddress/api/targets") -Headers $headers -Method GET -ContentType 'application/json'		
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}	
	$objects
}

function Get-ICScans {
	$skip = 0
	Write-Verbose "Exporting Scans from $HuntServerAddress"
	Write-Progress -Activity "Exporting Scans from Hunt Server" -status "Requesting Scans from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod "$HuntServerAddress/api/SplunkScans" -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Scans from Hunt Server" -status "Requesting Scans from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkScans") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			Write-Output $moreobjects
			# $objects += $moreobjects
		} else {
			$more = $false
		}
	}
}


# Get Full FileReports on all Suspicious and Malicious objects by scanid
function Get-ICFileReports ($scanid) {
	$skip = 0
	Write-Verbose "Exporting FileReports from $HuntServerAddress"
	Write-Progress -Activity "Exporting FileReports from Hunt Server" -status "Requesting FileReports from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	try {
		$scan = Invoke-RestMethod ("$HuntServerAddress/api/scans/$scanid") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	
	$skip = 0
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/ScanReportFiles") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {}
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting FileReports from Hunt Server" -status "Requesting FileReports from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/ScanReportFiles") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			$objects += $moreobjects
		} else {
			$more = $false
		}
	}
	
	$objects | % {
		$_ | Add-Member -Type NoteProperty -Name 'scancompletedon' -Value $scan.scancompletedon
		$_ | Add-Member -Type NoteProperty -Name 'targetlist' -Value $scan.targetlist
			
		# Add Signature
		$signatureId = $_.signatureId
		try {
			$sig = Invoke-RestMethod ("$HuntServerAddress/api/Signatures/$signatureId") -Headers $headers -Method GET -ContentType 'application/json'
			$_ | Add-Member -Type NoteProperty -Name 'signature' -Value $sig
		} catch {}

		# Add FileRep
		$fileRepId = $_.fileRepId
		try {
			$filerep = Invoke-RestMethod ("$HuntServerAddress/api/FileReps/$fileRepId") -Headers $headers -Method GET -ContentType 'application/json'
			$_ | Add-Member -Type NoteProperty -Name 'fileReps' -Value $filerep
		} catch {}
	}
	$objects
}


# Get objects by scanid
function Get-ICProcesses ($scanid){
	$skip = 0
	Write-Verbose "Exporting Processes from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Process Instances from Hunt Server" -status "Requesting Processes from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkProcesses") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Process Instances from Hunt Server" -status "Requesting Processes from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkProcesses") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			# $objects += $moreobjects
			Write-Output $moreobjects
		} else {
			$more = $false
		}	
	}
}

function Get-ICModules ($scanid){
	$skip = 0
	Write-Verbose "Exporting Modules from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Module Instances from Hunt Server" -status "Requesting Modules from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkModules") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Module Instances from Hunt Server" -status "Requesting Modules from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkModules") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			Write-Output $moreobjects
			#$objects += $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICDrivers ($scanid){
	$skip = 0
	Write-Verbose "Exporting Drivers from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Driver Instances from Hunt Server" -status "Requesting Drivers from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkDrivers") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Driver Instances from Hunt Server" -status "Requesting Drivers from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkDrivers") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			#$objects += $moreobjects
			write-output $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICAutostarts ($scanid){
	$skip = 0
	Write-Verbose "Exporting Autostarts from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Autostart Instances from Hunt Server" -status "Requesting Autostarts from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkAutostarts") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Autostart Instances from Hunt Server" -status "Requesting Autostarts from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkAutostarts") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			# $objects += $moreobjects
			Write-Output $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICMemscans ($scanid){
	$skip = 0
	Write-Verbose "Exporting Memscans from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Memscan Instances from Hunt Server" -status "Requesting Memscans from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod "$HuntServerAddress/api/SplunkMemscans" -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Memscan Instances from Hunt Server" -status "Requesting Memscans from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkMemscans") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			#$objects += $moreobjects
			Write-Output $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICConnections ([String]$scanid, [Switch]$All) {
	$skip = 0
	Write-Verbose "Exporting Connections from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Connection Instances from Hunt Server" -status "Requesting Connections from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"and":[{"scanid":"'+$scanid+'"},{"or":[{"state":"SYN-SENT"},{"state":"ESTABLISHED"}]}]},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = (Invoke-RestMethod ("$HuntServerAddress/api/SplunkConnections") -Headers $headers -Method GET -ContentType 'application/json') | where { $_.localaddr -ne $_.remoteaddr }
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Connection Instances from Hunt Server" -status "Requesting Connections from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"and":[{"scanid":"'+$scanid+'"},{"or":[{"state":"SYN-SENT"},{"state":"ESTABLISHED"}]}]},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkConnections") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			# $objects += $moreobjects
			Write-Output $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICAccounts ($scanid) {
	$skip = 0
	Write-Verbose "Exporting Accounts from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Account Instances from Hunt Server" -status "Requesting Accounts from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod "$HuntServerAddress/api/SplunkAccounts" -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	write-output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Account Instances from Hunt Server" -status "Requesting Accounts from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkAccounts") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			Write-Output $moreobjects
			#$objects += $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICHosts ($scanid) {
	$skip = 0
	Write-Verbose "Exporting Hosts from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Host Instances from Hunt Server" -status "Requesting Hosts from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkHosts") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	Write-Output $objects
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Host Instances from Hunt Server" -status "Requesting Hosts from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/SplunkHosts") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			# $objects += $moreobjects
			Write-Output $moreobjects
		} else {
			$more = $false
		}
	}
}

function Get-ICAccounts ($scanid) {
	$skip = 0
	Write-Verbose "Exporting Accounts from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Account Instances from Hunt Server" -status "Requesting Accounts from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects = Invoke-RestMethod "$HuntServerAddress/api/ScanAccountInstances" -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"	
	}
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Account Instances from Hunt Server" -status "Requesting Accounts from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"scanid":"'+$scanid+'"},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/ScanAccountInstances") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			$objects += $moreobjects
		} else {
			$more = $false
		}
	}
	
	$skip = 0
	$headers.remove('filter') | Out-Null
	$headers.Add("filter", '{"limit":1000,"skip":'+$skip+'}')
	try {
		$Accounts = Invoke-RestMethod ("$HuntServerAddress/api/Accounts") -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"	
	}
	$more = $true
	While ($more) {
		$skip += 1000
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/Accounts") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			$Accounts += $moreobjects
		} else {
			$more = $false
		}
	}
	
	$Hosts = Get-ICHosts $scanid
	$objects | % {
		# Add Host Info
		$hostId = $_.hostId
		$hostinfo = $Hosts | where { $_.hostId -eq $hostId }
		$_ | Add-Member -Type NoteProperty -Name 'hostname' -Value $hostinfo.hostname
		$_ | Add-Member -Type NoteProperty -Name 'ip' -Value $hostinfo.ip
		
		# Add account Info
		$accountId = $_.accountId
		$acctinfo = $Accounts | where { $_.accountId -eq $accountId }
		$_ | Add-Member -Type NoteProperty -Name 'fullname' -Value $acctinfo.fullname		
	}
	
	$objects
}

function Get-ICAddresses ($TargetId) {
	$skip = 0
	Write-Verbose "Exporting Addresses from $scanid [$skip]" 
	Write-Progress -Activity "Exporting Address Instances from Hunt Server" -status "Requesting Addresses from $scanid [$skip]" 
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	$skip = 0
	$headers.Add("filter", '{"where":{"and":[{"targetid":"'+$targetid+'"}]},"limit":1000,"skip":'+$skip+'}')
	try {
		$objects += Invoke-RestMethod ("$HuntServerAddress/api/Addresses") -Headers $headers -Method GET -ContentType 'application/json'		
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	$more = $true
	While ($more) {
		$skip += 1000
		Write-Progress -Activity "Exporting Address Instances from Hunt Server" -status "Requesting Addresses from $scanid [$skip]" 
		$headers.remove('filter') | Out-Null
		$headers.Add("filter", '{"where":{"and":[{"targetid":"'+$targetid+'"}]},"limit":1000,"skip":'+$skip+'}')
		try {
			$moreobjects = Invoke-RestMethod ("$HuntServerAddress/api/Addresses") -Headers $headers -Method GET -ContentType 'application/json'
		} catch {
			Write-Warning "Error: $_"	
		}
		if ($moreobjects.count -gt 0) {
			$objects += $moreobjects
		} else {
			$more = $false
		}
	}	
	$objects
}


# Get Full FileReport on an object by sha1
function Get-ICFileReport ($sha1){
	Write-Verbose "Requesting FileReport on file with SHA1: $sha1"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $Global:ICToken)
	try {
		$objects = Invoke-RestMethod "$HuntServerAddress/api/FileReps/$sha1" -Headers $headers -Method GET -ContentType 'application/json'
	} catch {
		Write-Warning "Error: $_"
		return "ERROR: $($_.Exception.Message)"
	}
	
	$objects | % {
		$_ | Add-Member -Type NoteProperty -Name 'avpositives' -Value $_.avResults.positives
		$_ | Add-Member -Type NoteProperty -Name 'avtotal' -Value $_.avResults.total	
	}
	$objects
}



# MAIN
New-ICToken $Credential $HuntServer

# splunkscan
$AllScans = Get-ICScans

# Create Time Box
if ($Days -ne 0 -AND $AllScans) {
	$CurrentDT = Get-Date
	$FirstDT = $CurrentDT.AddDays(-$Days)
	$Scans = $AllScans | where { $_.scancompletedon } | where { [datetime]$_.scancompletedon -gt $FirstDT -AND $_.hostCount -gt 0 }
} else {
	$Scans = $AllScans
}

if (-NOT $Scans) {
	Write-Warning "No Scans were found for the given date range"
	exit
}

# splunkscans
$itemtype = "Scans"
if (Test-Path $OutPath\$itemtype.json) {
	if ($Replace) {
		Remove-Item $OutPath\$itemtype.json
		Write-Verbose "Requesting data from $($Scans.count) Scans."
	} else {
		#Check latest, only append new scanids
		$old = gc $OutPath\$itemtype.json | convertfrom-JSON
		$scanIds = $old.scanid
		Write-Verbose "$($Scans.count) Scans found. $($scanIds.count) scans have already been exported"
		$Scans = $Scans | where { $scanIds -notcontains $_.scanid }
		Write-Verbose "Requesting $($Scans.count) new Scans."
		
	}
}
$Scans | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$itemtype.json -Append }


if ((Test-Path $OutPath\$scanname.json) -AND $Replace) {
	Remove-Item $OutPath\$scanname.json
}
$Scans | % {
	$scanname = "$($_.targetlist)-$($_.scanname)"
	
	# splunkprocesses
	$itemtype = "Processes"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICProcesses $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	#$obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	# splunkmodules
	$itemtype = "Modules"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICModules $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"	
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	#$obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	
	# splunkdrivers
	$itemtype = "Drivers"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICDrivers $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	#$obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	# splunkautostarts
	$itemtype = "Autostarts"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICAutostarts $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	#$obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	# splunkmemscans
	$itemtype = "Memscans"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICMemscans $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	# $obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	# splunkconnections
	$itemtype = "Connections"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICConnections $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	# $obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }

	# splunkhosts
	$itemtype = "Hosts"
	Write-Verbose "[] Exporting $itemtype from $scanname"
	$time = Measure-Command { $obj = Get-ICHosts $_.id }
	Write-Verbose "Received $($obj.count) $itemtype from Hunt server in $($time.TotalSeconds) seconds"
	$obj | % { $_ | ConvertTo-Json -compress | Write-Output }
	# $obj | % { $_ | ConvertTo-Json -compress | Out-File $OutPath\$scanname.json -Append }
}


