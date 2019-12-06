--=========================================================================================================
-- Usage:	This is to generate database snapshot
-- Note:    Run in source database.
--          For more information how db snapshop working: https://docs.microsoft.com/en-us/sql/relational-databases/databases/database-snapshots-sql-server
-- History:
-- Date			Author		Description
-- 2019-12-06	DN			Intial
--==========================================================================================================
DROP PROCEDURE IF EXISTS MaintenanceDBSnapshot
GO

CREATE PROCEDURE MaintenanceDBSnapshot  @LiveRun BIT = 0,
                                        --@Drop BIT = 1, --consider to use this param to drop all snapshots of current source database before creating new
                                        @SnapshotLocation varchar(256) = NULL
AS
BEGIN
	SET NOCOUNT ON;
		
	DECLARE @vSQL nvarchar(MAX)
	DECLARE @vMessage nvarchar(4000)
    DECLARE @vDbSnapshotName varchar(256)
    DECLARE @vDbSnapshotPhysicalName varchar(256)
    
	DECLARE @CurrentDate DATETIME = GETDATE()
	DECLARE @SnapshotSuffix varchar(40) = '-SNAPSHOT' + FORMAT(@CurrentDate, '-yyyyMMdd-HHmmss')

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + ' Starting creating database snapshot from ' + DB_NAME()
	RAISERROR(@vMessage,0,1) WITH NOWAIT

    SELECT  @vDbSnapshotName = [name] + @SnapshotSuffix,
            @vDbSnapshotPhysicalName = COALESCE(@SnapshotLocation + [name] + @SnapshotSuffix + '.ss', REPLACE([physical_name], '.mdf', + @SnapshotSuffix + '.ss'))
    FROM    [sys].[database_files]
    WHERE   [type] = 0

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  Snapshot name: ' + @vDbSnapshotName
	RAISERROR(@vMessage,0,1) WITH NOWAIT
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  Snapshot location: ' + @vDbSnapshotPhysicalName
	RAISERROR(@vMessage,0,1) WITH NOWAIT

    SET @vSQL = 'CREATE DATABASE [' + @vDbSnapshotName + '] ON (NAME = [' + DB_NAME() + '], FILENAME = ''' + @vDbSnapshotPhysicalName + ''') AS SNAPSHOT OF [' + DB_NAME() + ']'
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  Creating snap: ' + @vSQL
	RAISERROR(@vMessage,0,1) WITH NOWAIT
    IF @LiveRun = 1
    BEGIN
        IF NOT EXISTS (SELECT TOP 1 1 FROM sys.databases WHERE name = @vDbSnapshotName)
        BEGIN
            EXECUTE sp_executesql @statement=@vSQL
        END
        ELSE
        BEGIN
            SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + '  ERROR: Snapshot has been already existed. Aborted!'
            RAISERROR(@vMessage,16,1) WITH NOWAIT
            RETURN -1
        END
    END
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21) + ' Finished.'
	RAISERROR(@vMessage,0,1) WITH NOWAIT
END
GO
/*
    EXEC MaintenanceDBSnapshot @LiveRun = 0, @SnapshotLocation = NULL
    EXEC MaintenanceDBSnapshot @LiveRun = 0, @SnapshotLocation = 'C:\'
    EXEC MaintenanceDBSnapshot @LiveRun = 1, @SnapshotLocation = NULL
*/