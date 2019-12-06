--=========================================================================================================
-- Usage:	This is to restore database from a snapshot
-- Note:    Run in master database
--          For more information how db snapshop working: https://docs.microsoft.com/en-us/sql/relational-databases/databases/database-snapshots-sql-server
-- History:
-- Date			Author		Description
-- 2019-12-06	DN			Intial
--==========================================================================================================
use master
GO
DROP PROCEDURE IF EXISTS MaintenanceDBRestoreFromSnapshot
GO

CREATE PROCEDURE MaintenanceDBRestoreFromSnapshot   @DbName varchar(256),
                                                    @FromSnapshot varchar(256),
                                                    @LiveRun BIT = 0
AS
BEGIN
	SET NOCOUNT ON;
		
	DECLARE @vSQL nvarchar(MAX)
	DECLARE @vMessage nvarchar(4000)

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + ' Starting restore database [' + @DbName + '] from snapshot [' + @FromSnapshot + ']'
	RAISERROR(@vMessage,0,1) WITH NOWAIT
    
    IF NOT EXISTS (SELECT TOP 1 1 FROM sys.databases WHERE name = @DbName)
    BEGIN
        SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  ERROR: Target database does not exist. Aborted!'
        RAISERROR(@vMessage,16,1) WITH NOWAIT
        RETURN -1
    END
    
    IF (SELECT COUNT(*) FROM sys.databases S JOIN sys.databases SS ON SS.source_database_id = S.database_id WHERE S.name = @DbName) > 1
    BEGIN
        SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  ERROR: Please make sure ONLY ONE snapshot exists. Aborted!'
        RAISERROR(@vMessage,16,1) WITH NOWAIT
        RETURN -1
    END
    
    IF NOT EXISTS (SELECT TOP 1 1 FROM sys.databases WHERE name = @FromSnapshot)
    BEGIN
        SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  ERROR: Database snapshot does not exist. Aborted!'
        RAISERROR(@vMessage,16,1) WITH NOWAIT
        RETURN -1
    END

    -- consider to use KillAllDatabaseProcesses to kill all active processes before restoring
    -- EXEC KillAllDatabaseProcesses @DatabaseName = @DbName, @LiveRun = 1
    
    SET @vSQL = 'RESTORE DATABASE [' + @DbName + '] FROM DATABASE_SNAPSHOT = ''' + @FromSnapshot + ''''
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  Restoring... - ' + @vSQL
	RAISERROR(@vMessage,0,1) WITH NOWAIT
    IF @LiveRun = 1
    BEGIN
        EXECUTE sp_executesql @statement=@vSQL
    END
    
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + ' Finished.'
	RAISERROR(@vMessage,0,1) WITH NOWAIT
END
GO
/*
    use master
    GO
    EXEC MaintenanceDBRestoreFromSnapshot @DbName = 'TEST', @FromSnapshot = '', @LiveRun = 0
    EXEC MaintenanceDBRestoreFromSnapshot @DbName = 'TEST', @FromSnapshot = 'Test-SNAPSHOT-20191206-103640', @LiveRun = 0
    EXEC MaintenanceDBRestoreFromSnapshot @DbName = 'TEST', @FromSnapshot = 'Test-SNAPSHOT-20191206-103640', @LiveRun = 1
*/