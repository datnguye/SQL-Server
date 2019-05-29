--======================================================
-- Usage:	Trigger database schema changes
-- Notes:	Recommend to create agent job to regurlarly clean up Audit table
-- History:
-- Date			Author		Description
-- 2019-05-29	DN			Intial
--======================================================
/*
	--Pre-condition
	DROP TABLE IF EXISTS dbo.SystemDDLAudit
	GO
	CREATE TABLE dbo.SystemDDLAudit
	(
		EventType nvarchar(256),
		SchemaName nvarchar(256),
		ObjectName nvarchar(256),
		SqlCommand nvarchar(MAX),
		EventXml XML,
		IpAddress nvarchar(256),
		HostName nvarchar(256),
		AppName nvarchar(256),
		NetTransport nvarchar(256),
		ProtocolType nvarchar(256),
		AuthScheme nvarchar(256),
		LocalNetAddress nvarchar(256),
		LocalTcpPort nvarchar(256),
		PhysicalNetTransport nvarchar(256),
		Principal nvarchar(256),
		LoginToken XML,
		[User] nvarchar(256),
		CurrentUser nvarchar(256),
		SessionUser nvarchar(256),
		SystemUser nvarchar(256),
		UserName nvarchar(256),
		SuserName nvarchar(256),
		SuserSname nvarchar(256),
		OriginalLogin nvarchar(256),
		IsSysadmin bit,
		IsDbOwner bit,
		IsDdlAdmin bit,
		IsDbDatareader bit,
		MachineName nvarchar(256),
		InstanceName nvarchar(256),
		ServerName nvarchar(256),
		NetbiosName nvarchar(256),
		DatabaseName nvarchar(256),
		EventTimestamp DateTime CONSTRAINT DFSystemDDLAuditEventTimestamp DEFAULT(GETDATE())
	)
	GO
*/
DROP TRIGGER IF EXISTS DatabaseSchemaAudit ON DATABASE 
GO
CREATE TRIGGER DatabaseSchemaAudit ON DATABASE 
FOR
	CREATE_USER, ALTER_USER, DROP_USER,
    CREATE_SCHEMA, ALTER_SCHEMA, DROP_SCHEMA, 
    CREATE_TABLE, ALTER_TABLE, DROP_TABLE,
    CREATE_VIEW, ALTER_VIEW, DROP_VIEW, 
    CREATE_PROCEDURE, ALTER_PROCEDURE, DROP_PROCEDURE,
    CREATE_FUNCTION, ALTER_FUNCTION, DROP_FUNCTION,
    CREATE_TRIGGER, ALTER_TRIGGER, DROP_TRIGGER,
    CREATE_TYPE, DROP_TYPE,
    CREATE_INDEX, ALTER_INDEX, DROP_INDEX,
    CREATE_QUEUE, ALTER_QUEUE, DROP_QUEUE,
    RENAME
AS 
BEGIN 
    SET NOCOUNT ON; 

    IF NOT EXISTS(SELECT TOP 1 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SystemDDLAudit') 
        RETURN; 

    DECLARE @EventData XML = EVENTDATA();
    DECLARE @LoginToken XML; 
    DECLARE @OperationPrincipal nvarchar(256); 

    SET @LoginToken = 
		( 
			SELECT	lt.*
			FROM	sys.login_token AS lt 
			JOIN	sys.server_principals AS sp 
				ON	lt.principal_id = sp.principal_id 
			WHERE	lt.name NOT IN (SELECT name FROM sys.database_principals WHERE type = 'R' AND name IS NOT NULL) 
				AND lt.name IS NOT NULL 
				AND sp.type <> 'R'
			ORDER BY lt.name 
			FOR XML PATH(''), ROOT ('token') 
		)
    SET @OperationPrincipal =
		( 
			SELECT		TOP 1 p.NameNode.value('.', 'nvarchar(256)')
			FROM		@LoginToken.nodes('//name') AS p(NameNode) 
			ORDER BY	1
		); 

    INSERT 
	INTO	dbo.SystemDDLAudit
    SELECT	-- Did what ? 
			@EventData.value('(/EVENT_INSTANCE/EventType)[1]',   'nvarchar(256)') AS EventType, 
			@EventData.value('(/EVENT_INSTANCE/SchemaName)[1]',  'nvarchar(256)') AS SchemaName,
			@EventData.value('(/EVENT_INSTANCE/ObjectName)[1]',  'nvarchar(256)') AS ObjectName, 
			@EventData.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'nvarchar(MAX)') AS SqlCommand, 
			@EventData AS EventXml,

			-- Where from ? 
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('client_net_address')) AS IpAddress,
			HOST_NAME() AS HostName, 
			APP_NAME() AS AppName,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('net_transport')) AS NetTransport,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('protocol_type')) AS ProtocolType,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('auth_scheme')) AS AuthScheme,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('local_net_address')) AS LocalNetAddress,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('local_tcp_port')) AS LocalTcpPort,
			CONVERT(nvarchar(256),CONNECTIONPROPERTY('physical_net_transport')) AS PhysicalNetTransport,

			-- Who did it ? 
			@OperationPrincipal AS Principal,
			@LoginToken AS LoginToken,
			USER,
			CURRENT_USER AS CurrentUser, 
			SESSION_USER AS SessionUser, 
			SYSTEM_USER AS SystemUser, 
			USER_NAME() AS UserName,
			SUSER_NAME() AS SuserName, 
			SUSER_SNAME() AS SuserSname, 
			ORIGINAL_LOGIN() AS OriginalLogin,

			-- What rights did said person have ? 
			CONVERT(nvarchar(256),IS_SRVROLEMEMBER('sysadmin')) AS IsSysadmin,
			CONVERT(nvarchar(256),IS_MEMBER('db_owner')) AS IsDbOwner, 
			CONVERT(nvarchar(256),IS_MEMBER('db_ddladmin')) AS IsDdlAdmin, 
			CONVERT(nvarchar(256),IS_MEMBER('db_datareader')) AS IsDbDatareader,
			 
			-- On which server was this done ? 
			CONVERT(nvarchar(256),SERVERPROPERTY(N'MachineName')) AS MachineName, 
			CONVERT(nvarchar(256),SERVERPROPERTY(N'InstanceName')) AS InstanceName, 
			CONVERT(nvarchar(256),SERVERPROPERTY(N'ServerName')) AS ServerName, 
			CONVERT(nvarchar(256),SERVERPROPERTY(N'ComputerNamePhysicalNetBIOS')) AS NetbiosName, 
			DB_NAME() AS DatabaseName,

			--When
			GETDATE()

    WHERE	@EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(256)')  IS NOT NULL 
        AND	@EventData.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'nvarchar(MAX)') IS NOT NULL 
        AND	 
        ( 
            1 = 1 --// PUT YOUR EXTRA EXLUSION HERE //
        )
END 
GO 

/*
TRUNCATE TABLE SystemDDLAudit
GO
DROP TABLE IF EXISTS test1
GO
CREATE TABLE test1 (id int)
GO
SELECT * 
FROM SystemDDLAudit
GO
*/