# InfocyteSplunkApp
Setup HUNT Server
 - Install Infocyte HUNT
 
Setup Splunk Server
 - Setup Receiver on port 9997
 - Create Index called "Infocyte"
 
Install Infocyte HUNT App in Splunk 
 - Copy app folder to C:\Program Files\Splunk\etc\app\
 - Restart Splunk
 
Setup Splunk Forwarder
- Install Splunk Universal Forwarder on HUNT Server
- Forward to Splunk Server on port 9997
- Install Infocyte HUNT Add-On in SplunkForwarder
  - Copy add-on folder to C:\Program Files\SplunkForwarder\etc\app\
	- input.conf will monitor folder: C:\Program Files\Infocyte\SplunkData\
	- input.conf will monitor folder: C:\Program Files\Infocyte\HUNT\Log\
- Restart Splunk Forwarder
  - PS C:\> Restart-Service -Name "SplunkForwarder"

Pull Scan Data from Infocyte (manual) via the REST api (drops files to disk)
- Import ...\infocyte_hunt_addon\bin\InfocyteAPIFunctions.ps1
- Run ...\infocyte_hunt_addon\bin\AnalysisExport.ps1
  - This drops the data to C:\Program Files\Infocyte\SplunkData\ in one-line JSON Documents
