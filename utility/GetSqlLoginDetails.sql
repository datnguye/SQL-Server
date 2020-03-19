--======================================================
-- Usage: GetSqlLoginDetails
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-23	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetSqlLoginDetails
GO
CREATE PROCEDURE  [dbo].GetSqlLoginDetails	@LoginName sysname = NULL,
											@IncludeUserMapping BIT = 0
AS
BEGIN
	SET NOCOUNT ON
	IF OBJECT_ID(N'tempdb.dbo.#tLogin', 'U') IS NOT NULL 
		DROP TABLE #tLogin;

	SELECT		l.LoginName,
				l.dbname as DefaultDB,
				l.sysadmin,
				l.isntname,
				l.isntgroup,
				l.isntuser,
				l.securityadmin,
				l.serveradmin,
				l.setupadmin,
				l.processadmin,
				l.diskadmin,
				l.dbcreator,
				l.bulkadmin
	INTO		#tLogin
	FROM		sys.syslogins l
	JOIN		sys.server_principals sp
		ON		sp.name = l.loginname 
	WHERE		l.hasaccess=1 
		AND		l.denylogin=0 
		AND		l.loginname NOT LIKE 'NT %'
		AND		l.loginname NOT LIKE '##%'
		AND		sp.is_disabled <> 1
	
	SELECT		*
	FROM		#tLogin
	ORDER BY	1

	IF @IncludeUserMapping = 1
	BEGIN
		IF OBJECT_ID(N'tempdb.dbo.#tUserMapping', 'U') IS NOT NULL 
			DROP TABLE #tUserMapping;

		CREATE TABLE #tUserMapping (
			LoginName sysname,
			LoginType nvarchar(60),
			IsMustChange bit,
			DatabaseName sysname NULL,
			DatabaseUserName sysname NULL,
			DatabaseRoleName sysname NULL
		)

		EXEC sp_MSforeachdb '
			USE [?];
			INSERT INTO #tUserMapping
			SELECT		sp.name AS LoginName,
						sp.type_desc AS LoginType,
						CAST(LOGINPROPERTY(sp.name, ''IsMustChange'') AS bit) AS IsMustChange,
						DB_NAME() AS DatabaseName,
						dp.name AS DatabaseUserName,
						r.name AS DatabaseRoleName
			FROM		sys.server_principals sp
			JOIN		#tLogin L 
				ON		L.LoginName = sp.name
			JOIN		sys.database_principals dp
				ON		dp.sid = sp.sid
			JOIN		sys.database_role_members drm
				ON		drm.member_principal_id = dp.principal_id
			JOIN		sys.database_principals r
				ON		r.principal_id = drm.role_principal_id';
		
		SELECT		*
		FROM		#tUserMapping
		ORDER BY	1,2,4
	END

	
	RETURN
END
GO
/*
	EXEC GetSqlLoginDetails @LoginName = NULL,
							@IncludeUserMapping = 1
*/
