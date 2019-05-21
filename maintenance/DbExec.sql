--======================================================
-- Usage: Execute SQL script (in file) accross databases
-- Notes:	Recommend to release to master database
--			Recommend to have dbowner database role for all databases to be accessing to
--			xp_cmdshell option enabled for usage of SQL File Path 
-- Parameters:
--	@SQL:			SQL Text or file path containing SQL text to get run (Mandatory)
--					IF it is file path, log file to be ouput
--	@DBNamePattern:	To filter list of database by database name. Set % to run all
--	@Where:			To filter list of databases to be running.
--					Applicable for database scope ONLY.
--					Must be valid as Boolean_Expression of IF statement.
--	@FailedAtOne:	If Failed at one database then stop whole process
--	@LiveRun:		Turn to 1 to have REAL execution, otherwise log output only
--
-- History:
-- Date			Author		Description
-- 2019-05-21	DN			Intial
--======================================================
--use master;
DROP PROCEDURE IF EXISTS DbExec
GO

CREATE PROCEDURE DbExec	@SQL nvarchar(max),
						@DbNamePattern sysname = '%',
						@Where nvarchar(4000) = NULL,
						@FailedAtOne Bit = 1,
						@SQLInstanceName sysname = NULL,
						@SQLLoginName sysname = NULL,
						@SQLPassword sysname = NULL,
						@LiveRun bit = 1
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @vCommand nvarchar(4000)
	DECLARE @vExecFromFile Bit = 0
	Declare @vDBName nvarchar(256)
	
	DECLARE @vCmdOutput TABLE (content char(256))

	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- Starting executing...'
	--1. Validation
	IF PATINDEX('[A-Za-z]:\%', @SQL) = 1 OR PATINDEX('\\%', @SQL) = 1
	BEGIN 
		SET @vExecFromFile = 1
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		SQL taken from file path: '+@SQL
	END

	IF @vExecFromFile = 1
	BEGIN
		DECLARE @vCmdShellInfo TABLE (name sysname, minimum int, maximum int, config_value int, run_value int)
		INSERT INTO @vCmdShellInfo EXEC sp_configure 'xp_cmdshell'
		IF (SELECT run_value FROM @vCmdShellInfo) = 0 
		BEGIN
			Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: xp_cmdshell is being disabled. Please help to run EXEC sp_configure ''xp_cmdshell'', 1'' to fix it.'
			RETURN -1;
		END
		
		SET @vCommand = 'IF EXIST "'+@SQL+'" (echo 1) ELSE (echo 0)'
		INSERT INTO @vCmdOutput EXEC xp_cmdshell @vCommand
		IF (SELECT content FROM @vCmdOutput WHERE content IS NOT NULL) = '0'
		BEGIN
			Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: File does not exists - '+@SQL
			RETURN -1;
		END
	END

	--2. Get list of databases
	--   For each db, call execution. If failed at one database, process will stop at that point at all.
	DECLARE db_cursor CURSOR FOR
		SELECT	name
		FROM	sys.databases 
		WHERE	database_id > 4
			AND name LIKE @DbNamePattern

	OPEN db_cursor
	FETCH NEXT FROM db_cursor INTO @vDBName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Processing '+QUOTENAME(@vDBName)+'...'
		BEGIN TRY
			IF @Where IS NOT NULL
			BEGIN
				DELETE FROM @vCmdOutput
				SET @vCommand = 'Use '+QUOTENAME(@vDBName)+';IF '+@Where+' SELECT 1 ELSE SELECT 0'
				INSERT INTO @vCmdOutput EXEC(@vCommand)
				IF (SELECT content FROM @vCmdOutput) = 0 
				BEGIN
					PRINT CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-			'+QUOTENAME(@vDBName)+' does not sastify WHERE parameter. SKIPPED!'
					GOTO DBSKIP
				END
			END

			IF @vExecFromFile = 1 
			BEGIN
				Set @vCommand =	'sqlcmd'
								+' -S "'+Coalesce(@SQLInstanceName,@@ServerName)+'" '--Server Name
								+ (CASE WHEN @SQLLoginName IS NULL THEN ' -E ' ELSE '' END) --Trusted Connection
								+' -d "'+@vDBName+'"' --Database Name
								+(CASE WHEN @SQLLoginName IS NOT NULL THEN ' -U '+@SQLLoginName ELSE '' END) --Login Name
								+(CASE WHEN @SQLLoginName IS NOT NULL THEN ' -P '+@SQLPassword ELSE '' END) --Password
								+' -i "'+@SQL+'"' --input file
								+' -o "'+Replace(@SQL,'.sql','-'+@vDBName+FORMAT(GETDATE(),'yyyyMMdd')+'.log"') --output file
				IF @LiveRun = 0 PRINT @vCommand ELSE Exec xp_cmdshell @vCommand, no_output
				Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-			Output under: '+Replace(@SQL,'.sql','-'+@vDBName+FORMAT(GETDATE(),'-yyyyMMdd')+'.log"')
			END
			ELSE
			BEGIN
				SET @vCommand = 'EXEC '+QUOTENAME(@vDBName)+'.dbo.sp_executesql @SQL';
				IF @LiveRun = 0 PRINT @vCommand ELSE EXEC sp_executesql @vCommand, N'@SQL nvarchar(max)', @SQL
			END
		END TRY
		BEGIN CATCH
			Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: Something potential happened. Please help to review the log and re-run where required.'
			SELECT	ERROR_NUMBER() AS ErrorNumber,
					ERROR_SEVERITY() AS ErrorSeverity,
					ERROR_STATE() AS ErrorState,
					ERROR_PROCEDURE() AS ErrorProcedure,
					ERROR_LINE() AS ErrorLine,
					ERROR_MESSAGE() AS ErrorMessage
			IF @FailedAtOne = 1
				RETURN -1
		END CATCH
		
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Finished '+QUOTENAME(@vDBName)+'...'

		DBSKIP:
		FETCH NEXT FROM db_cursor INTO @vDBName
	END

	CLOSE db_cursor
	DEALLOCATE db_cursor
		
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- Finished killing processes.'
	RETURN;
END

/*
Test cases:
	Exec DbExec @SQL = 'SELECT DB_NAME(), 1', @LiveRun = 0
	Exec DbExec @SQL = 'SELECT DB_NAME(), 1', @LiveRun = 1
	Exec DbExec @SQL = 'SELECT DB_NAME(), 1', @LiveRun = 1, @DbNamePattern = '%[A-Za-z]-[A-Za-z]%' --database name contains hyphen
	Exec DbExec @SQL = 'SELECT DB_NAME(), 1', @LiveRun = 1, @Where = 'DB_NAME() LIKE ''%TEST%'''
	Exec DbExec @SQL = 'SELECT DB_NAME(), 1', @LiveRun = 1, @Where = 'EXISTS (SELECT TOP 1 1 FROM opp)', @FailedAtOne = 0
	
	Exec DbExec @SQL = 'C:\Temp\release-something-someday.sql', @LiveRun = 0
	Exec DbExec @SQL = 'C:\Temp\release-something-someday.sql', 
				@SQLInstanceName = 'DAVE\DAVE140', 
				@SQLLoginName='sa',
				@SQLPassword = '123',
				@LiveRun = 1

*/ 