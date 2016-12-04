-- View: public.splunkscan
CREATE OR REPLACE VIEW public.splunkscan AS 
 WITH threats AS (
 	SELECT objects.scanid, 
		count(*) FILTER (WHERE objects.threatname = 'Bad' OR objects.threatname = 'Blacklist') AS bad,
		count(*) FILTER (WHERE objects.threatname = 'Suspicious') AS suspicious,
		count(*) FILTER (WHERE objects.threatname = 'Unknown') AS unknown,
		count(*) FILTER (WHERE objects.threatname = 'Low Risk') AS lowrisk,
		count(*) FILTER (WHERE objects.threatname = 'Good' OR objects.threatname = 'Whitelist') AS good
	FROM ( SELECT scanprocess.scanid,
			scanprocess.threatname,
			scanprocess.flagweight
		   FROM scanprocess
		UNION ALL
		 SELECT scanmodule.scanid,
			scanmodule.threatname,
			scanmodule.flagweight
		   FROM scanmodule
		UNION ALL
		 SELECT scandriver.scanid,
			scandriver.threatname,
			scandriver.flagweight
		   FROM scandriver
		UNION ALL
		 SELECT scanautostart.scanid,
			scanautostart.threatname,
			scanautostart.flagweight
		   FROM scanautostart
		UNION ALL
		 SELECT scanmemscaninstance.scanid,
			scanmemscaninstance.threatname,
			scanmemscaninstance.flagweight
		   FROM scanmemscaninstance) as objects
		GROUP BY objects.scanid
	)
	SELECT scan.completedon AS scancompletedon,
 	target.name AS targetlist,
	scanreportsummary.scanid AS id,
	'ScanMetadata'::text AS type,
	scan.name as scanname,
	scan.hostcount,
	scanreportsummary.failedhosts,	
	scan.processcount,
	scan.modulecount,
	scan.drivercount,
	scan.memorycount,
	scan.autostartcount,
	scan.accountcount,
	scan.hookcount,
	(scan.processcount + scan.modulecount + scan.drivercount + scan.memorycount + scan.autostartcount + scan.accountcount + scan.hookcount) AS totalobjectcount,
	scanreportsummary.compromisedhosts,
	scanreportsummary.compromisedaccounts,
	scanreportsummary.compromisedobjects,
	threats.*
 FROM scanreportsummary
    LEFT JOIN scan ON scanreportsummary.scanid = scan.id
	LEFT JOIN target ON scan.targetid = target.id
	LEFT JOIN threats ON scanreportsummary.scanid = threats.scanid;
	
-- View: public.splunkhost
CREATE OR REPLACE VIEW public.splunkhost AS 
 SELECT scan.scancompletedon,
	scanhost.hostid AS id,
	'Host'::text AS type,
	scan.targetlist,
	scanhost.scanid,
	scanhost.hostname,
	scanhost.ip,
	scanhost.domain,
	scanhost.osversion,
	host.servicepack,
	host.servicepackversion,
	scanhost.architecture,
	scanhost.failed,
	scanhost.compromised	
 FROM scanhost
	LEFT JOIN host ON scanhost.hostid = host.id
	LEFT JOIN splunkscan scan ON scanhost.scanid = scan.id;
	
	
CREATE OR REPLACE VIEW public.splunkprocesses AS 
    SELECT DISTINCT scan.scancompletedon,
		scanhost.hostname,
		scanhost.ip,
		scan.targetlist,
		scanprocessinstance.processid AS id,
		'Process'::text AS type,
		scanprocessinstance.name,
		scanprocessinstance.path,
		scanprocessinstance.size,
		scanprocessinstance.filerepid,
		scanprocessinstance.scanid,
		scanprocessinstance.malicious,
		scanprocessinstance.suspicious,
		scanprocessinstance.unknown,
		scanprocessinstance.flagname,
		scanprocessinstance.flagweight,
		scanprocessinstance.localblacklist,
		scanprocessinstance.localwhitelist,
		scanprocessinstance.hostcount as occurrences,
		scanprocessinstance.threatscore,
		scanprocessinstance.compromised,
		scanprocessinstance.threatname,
		scanprocessinstance.hostid,
		scanprocessinstance.pid,
		scanprocessinstance.ppid,
		a.fullname as account,
		a.uid as accountuid,
		a.priv as accountpriv,
		f.synapse
	   FROM scanprocessinstance,
		filerep f,
		account a,  
		scanhost,
		splunkscan scan
		WHERE scanprocessinstance.scanid = scan.id 
		AND scanprocessinstance.hostid = scanhost.hostid 
		AND scanprocessinstance.scanid = scanhost.scanid
		AND scanprocessinstance.accountid = a.id
		AND scanprocessinstance.filerepid = f.id;
		
			 
CREATE OR REPLACE VIEW public.splunkmodules AS 
 WITH module AS (
         SELECT DISTINCT scanmoduleinstance.moduleid AS id,
            'Module'::text AS type,
            scanmoduleinstance.name,
            scanmoduleinstance.path,
			scanmoduleinstance.size,
            scanmoduleinstance.filerepid,
            scanmoduleinstance.scanid,
            scanmoduleinstance.malicious,
            scanmoduleinstance.suspicious,
			scanmoduleinstance.unknown,
            scanmoduleinstance.flagname,
			scanmoduleinstance.flagweight,
            scanmoduleinstance.localblacklist,
            scanmoduleinstance.localwhitelist,
            scanmoduleinstance.hostcount as occurrences,
            scanmoduleinstance.threatscore,
            scanmoduleinstance.compromised,
            scanmoduleinstance.threatname,
            scanmoduleinstance.hostid,
            f.synapse
           FROM scanmoduleinstance join filerep f on scanmoduleinstance.filerepid = f.id
        UNION
         SELECT DISTINCT scandriverinstance.driverid AS id,
            'Driver'::text AS type,
            scandriverinstance.name,
            scandriverinstance.path,
			scandriverinstance.size,
            scandriverinstance.filerepid,
            scandriverinstance.scanid,
            scandriverinstance.malicious,
            scandriverinstance.suspicious,
			scandriverinstance.unknown,
            scandriverinstance.flagname,
			scandriverinstance.flagweight,
            scandriverinstance.localblacklist,
            scandriverinstance.localwhitelist,
            scandriverinstance.hostcount as occurrences,
            scandriverinstance.threatscore,
            scandriverinstance.compromised,
            scandriverinstance.threatname,
            scandriverinstance.hostid,
            f.synapse
           FROM scandriverinstance join filerep f on scandriverinstance.filerepid = f.id
		)
  SELECT scan.scancompletedon,
    scanhost.hostname,
    scanhost.ip,
	scan.targetlist,
    module.scanid,
    module.type,
    module.id,
    module.filerepid AS sha1,
    module.name,
    module.path,
	module.size,
    module.threatscore,
    module.threatname,
    module.compromised,
    module.malicious,
    module.suspicious,
	module.unknown,
    module.flagname,
	module.flagweight,
    module.localblacklist,
	module.localwhitelist,
	module.occurrences,
    module.synapse
   FROM module,
    scanhost,
	splunkscan scan 
  WHERE module.scanid = scan.id
	AND module.hostid = scanhost.hostid
	AND module.scanid = scanhost.scanid;
	
	
CREATE OR REPLACE VIEW public.splunkautostarts AS 
	 SELECT DISTINCT scan.scancompletedon,
		scanhost.hostname,
		scanhost.ip,
		scan.targetlist,
		scanautostartinstance.autostartid AS id,
		'Autostart'::text AS type,
		scanautostartinstance.name,
		scanautostartinstance.path,
		scanautostartinstance.size,
		scanautostartinstance.filerepid as sha1,
		scanautostartinstance.scanid,
		scanautostartinstance.malicious,
		scanautostartinstance.suspicious,
		scanautostartinstance.unknown,
		scanautostartinstance.flagname,
		scanautostartinstance.flagweight,
		scanautostartinstance.localblacklist,
		scanautostartinstance.localwhitelist,
		scanautostartinstance.hostcount as occurrences,
		scanautostartinstance.threatscore,
		scanautostartinstance.compromised,
		scanautostartinstance.threatname,
		scanautostartinstance.hostid,
		scanautostartinstance.autostarttype,
		scanautostartinstance.regpath,
		scanautostartinstance.value as regvalue,
		f.synapse
	FROM scanautostartinstance,
	    scanhost,
		splunkscan scan,
	    filerep f 
	WHERE scanautostartinstance.scanid = scan.id 
		AND scanautostartinstance.hostid = scanhost.hostid 
		AND scanautostartinstance.scanid = scanhost.scanid
		AND scanautostartinstance.filerepid = f.id;

-- View: public.splunkmem
CREATE OR REPLACE VIEW public.splunkmem AS 
 SELECT scan.scancompletedon,
    scanhost.hostname,
    scanhost.ip,
	scan.targetlist,
	scanmemscaninstance.scanid,
	'MemoryObject'::text AS type,
    scanmemscaninstance.memscanid AS id,
	scanmemscaninstance.filerepid AS sha1,
	scanmemscaninstance.pid,
	scanmemscaninstance.name as processname,
    scanmemscaninstance.path as processpath,
	process.filerepid as processsha1,
	scanmemscaninstance.address,
	scanmemscaninstance.size,
	scanmemscaninstance.protection,
    scanmemscaninstance.compromised,
    scanmemscaninstance.threatscore,
    scanmemscaninstance.threatname,
    scanmemscaninstance.malicious,
    scanmemscaninstance.suspicious,
	scanmemscaninstance.unknown,
    scanmemscaninstance.flagname,
    scanmemscaninstance.localblacklist,
	scanmemscaninstance.localwhitelist,
    filerep.synapse 
 FROM scanmemscaninstance,
    splunkscan scan,
    scanhost,
	filerep,
	process
  WHERE scanmemscaninstance.scanid = scan.id
    AND scanmemscaninstance.scanid = scanhost.scanid  
	AND scanmemscaninstance.hostid = scanhost.hostid
    AND scanmemscaninstance.filerepid = filerep.id
	AND scanmemscaninstance.processid = process.id;
	

-- View: public.splunkconnection
CREATE OR REPLACE VIEW public.splunkconnection AS 
 SELECT scan.scancompletedon,
    scanhost.hostname,
    scanhost.ip,
	scan.targetlist,
	scanconnectioninstance.scanid,
	'Connection'::text AS type,
    scanconnectioninstance.connectionid AS id,
	scanconnectioninstance.pid,
	scanconnectioninstance.processname,
    scanconnectioninstance.processpath,
	scanconnectioninstance.localaddr,
	scanconnectioninstance.localport,
	scanconnectioninstance.remoteaddr,
    scanconnectioninstance.remoteport,
    scanconnectioninstance.proto,
    scanconnectioninstance.state,
    scanconnectioninstance.threatscore
 FROM scanconnectioninstance,
    splunkscan scan,
    scanhost
 WHERE scanconnectioninstance.scanid = scan.id
    AND scanconnectioninstance.scanid = scanhost.scanid
	AND scanconnectioninstance.hostid = scanhost.hostid
	AND scanconnectioninstance.state = 'ESTABLISHED'
	AND scanconnectioninstance.localaddr != scanconnectioninstance.remoteaddr;
