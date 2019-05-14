--======================================================
-- Usage: Kill all processes connecting to current database
-- Notes:	NOT RECOMMENDED TO RUN this sproc onto Production database / USAGE of DEV, TESTING and SETUP NEW DATABASE only
--			Require sysadmin role
-- History:
-- Date			Author		Description
-- 2019-05-14	DN			Intial
--======================================================
--use master;
DROP PROCEDURE IF EXISTS KillAllDatabaseProcesses
GO

CREATE PROCEDURE KillAllDatabaseProcesses	@DatabaseName sysname = NULL,
											@LiveRun bit = 0
AS
BEGIN
	DECLARE @v_SQL nvarchar(4000)
	DECLARE @v_spid int
	DECLARE @v_sphost nvarchar(128)
	DECLARE @v_spuser nvarchar(128)
	DECLARE @v_spstatus nvarchar(128)

	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- Checking for processes connected to test database.'
	If Exists (
					SELECT	spid, ltrim(rtrim(hostname)), ltrim(rtrim(loginame)), ltrim(rtrim(status))
					FROM	sys.sysprocesses
					WHERE	dbid = db_id(Coalesce(@DatabaseName,db_name()))
						AND	ltrim(rtrim(status)) In ('background','rollback')
				)
	Begin
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Error: Processes exist attached to the database which cannot be killed, aborting this restore.'	
	End
	Else
	Begin
		Declare c_procCursor CURSOR FOR
			SELECT	spid, ltrim(rtrim(hostname)), ltrim(rtrim(loginame)), ltrim(rtrim(status))
			FROM	sys.sysprocesses
			WHERE	dbid = db_id(Coalesce(@DatabaseName,db_name()))
				AND	ltrim(rtrim(status)) Not In ('background','rollback')
		OPEN c_procCursor
		FETCH NEXT FROM c_procCursor INTO @v_spid, @v_sphost, @v_spuser, @v_spstatus
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @v_SQL = 'KILL ' + CAST(@v_spid AS nvarchar(5))
				Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Killing process '+CAST(@v_spid AS nvarchar(5))+' with status '+@v_spstatus+' for user '+@v_spuser+' from host '+@v_sphost
				If @LiveRun = '0' Print @v_SQL Else Exec sp_ExecuteSQL @v_SQL
				FETCH NEXT FROM c_procCursor INTO @v_spid, @v_sphost, @v_spuser, @v_spstatus
			END
		CLOSE c_procCursor
		DEALLOCATE c_procCursor
	End
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- Finished killing processes.'

	RETURN;
END

/*
-- Run for Current DB
Use master
GO
EXEC KillAllDatabaseProcesses @DatabaseName = NULL, @LiveRun = 1

-- Run for your_database_name DB
Use master
GO
EXEC KillAllDatabaseProcesses @DatabaseName = 'your_database_name', @LiveRun = 1

--Set @LiveRun = 0 to just see output, no real run
Use master
GO
EXEC KillAllDatabaseProcesses @DatabaseName = NULL, @LiveRun = 0
EXEC KillAllDatabaseProcesses @DatabaseName = 'template-database', @LiveRun = 1
*/