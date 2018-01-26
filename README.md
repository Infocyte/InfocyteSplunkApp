# InfocyteSplunkApp
Setup HUNT Server
 - Install Infocyte HUNT

Install Infocyte HUNT App in Splunk
 - Copy app the infocyte_hunt_app folder to *Splunk installation directory* \etc\apps\
 - Restart Splunk

Pull up the HTTP Event Collector
 - Open the Settings dropdown menu in Splunk
 - Click Data Inputs > HTTP Event Collector
 - Note the Token Value for the collector called "infocyte" with the description "Infocyte HUNT HTTP Input"

Setup Splunk Integration in HUNT
 - Sign in to HUNT as an administrator
 - Click Admin > Integrations > Splunk
 - Click Add Splunk Integration
 - Enter the FQDN or IP address for the Splunk server in the "Server" textbox
 - Enter the port number for the Splunk server in the "Port" textbox (Port 8088 is the default)
 - Enter the "Infocyte HUNT HTTP Input" token value from the Splunk server, into the "HTTP Event Collector Token" textbox 
 - Make sure the "Enabled?" checkbox is filled, select which data you would like to have appear in Splunk, and click create

Run a scan! Happy Hunting!
