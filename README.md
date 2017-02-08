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
 - Modify C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf with content in props.conf
   -- input.conf will monitor folder: C:\Program Files\Infocyte\SplunkData\
   -- input.conf will monitor folder: C:\Program Files\Infocyte\HUNT\Log\
   -- input.conf will monitor folder: C:\Program Files\Infocyte\HUNT-UI-Server\Log\
 - Modify C:\Program Files\SplunkUniversalForwarder\etc\system\local\props.conf with content in props.conf
   -- props.conf will format/parse logs and events prior to indexing
 - Restart Splunk Forwarder
   -- PS C:\> Restart-Service -Name "SplunkForwarder"

Load Database Views into Infocyte
 - Run Setup.ps1
   -- PS C:\> .\Setup.ps1
 - Views format Infocyte scan data into one line JSON events that can be dropped to disk (monitored by forwarder) or sent to a TCP listener
 - Add the -All selection if you want all objects dumped.  This is a LOT of data so make sure you have plenty of splunk licenses if you want this.  Normally it defaults to all processes and then a selection of modules and autostarts that are Bad, Suspicious, Unknown, and Synapse below -0.5.
  
Pull Scan Data from Infocyte (manual)
 - Run SplunkDataDump.ps1
   -- PS C:\> .\SplunkDataDump.ps1
 - This drops the data to C:\Program Files\Infocyte\SplunkData\ in one-line JSON Documents
