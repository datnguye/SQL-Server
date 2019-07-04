--============================================================================
-- Usage: This is to perform a FULL/DIFFERENTIAL/LOG backup of a database.
-- Notes: 
-- History:
-- Date			By			Description
-- 20-Jun-2019	DN			Created.
-- 04-Jul-2019	DN			Add @BackupMode
-- ===========================================================================
DROP PROCEDURE IF EXISTS [MaintenanceDBBackup] 
GO

CREATE PROCEDURE [MaintenanceDBBackup]	@DbName sysname,
										@BackupFolderPath nvarchar(256),
										@BackupMode varchar(20) = 'FULL'--DIFFERENTIAL, LOG
AS
BEGIN
	DECLARE @vBackupFileLocation nvarchar(256)
	DECLARE @vMessage nvarchar(MAX)

	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Processing FULL BACKUP database: '+@DbName+' - to location: '+@BackupFolderPath+'.'
	--Check DB exists
	IF NOT EXISTS ( SELECT TOP 1 1 FROM sys.databases WHERE name = @DbName)
	BEGIN
		SET @vMessage = 'ERROR: Database does not exist! Aborted!'
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+ '-	'+@vMessage
		RAISERROR(@vMessage,16,1) WITH NOWAIT
		RETURN -1
	END
	--Valid backup mode
	IF @BackupMode NOT IN ('FULL','DIFFERENTIAL','LOG')
	BEGIN
		SET @vMessage = 'ERROR: Backup MODE invalid, it must be FULL or DIFFERENTIAL or LOG! Aborted!'
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+ '-	'+@vMessage
		RAISERROR(@vMessage,16,1) WITH NOWAIT
		RETURN -1
	END

	--Get backup file path
	IF RIGHT(@BackupFolderPath,1) <> '\' SET @BackupFolderPath = @BackupFolderPath + '\'
	Set @vBackupFileLocation = 
		@BackupFolderPath 
		+ @DbName 
		+ CASE 
			WHEN @BackupMode = 'FULL' 
				THEN	'-FULL-'+FORMAT(CURRENT_TIMESTAMP,'yyyyMMdd')+'.bck'
			WHEN @BackupMode = 'DIFFERENTIAL' 
				THEN	'-DIFFERENTIAL-'+FORMAT(CURRENT_TIMESTAMP,'yyyyMMdd')+'.bck'
			ELSE		'-LOG-'+FORMAT(CURRENT_TIMESTAMP,'yyyyMMdd-HHmmss')+'.bck'
		END
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		'+@BackupMode+' backup file path: '+@vBackupFileLocation+'.'
	
	--Perform BACKUP
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Performing the backup...'
	BEGIN TRY
		IF @BackupMode = 'FULL'
			BACKUP DATABASE @DbName TO DISK = @vBackupFileLocation WITH NAME = @DbName, NOFORMAT, INIT, SKIP, NOUNLOAD, CHECKSUM
		ELSE IF @BackupMode = 'DIFFERENTIAL'
			BACKUP DATABASE @DbName TO DISK = @vBackupFileLocation WITH NAME = @DbName, NOFORMAT, INIT, SKIP, NOUNLOAD, CHECKSUM, DIFFERENTIAL, NOREWIND
		ELSE
			BACKUP LOG		@DbName TO DISK = @vBackupFileLocation WITH NAME = @DbName, NOFORMAT, INIT, SKIP, NOUNLOAD, CHECKSUM, NOREWIND
	END TRY
	BEGIN CATCH
		SET @vMessage = 'ERROR: '+@BackupMode+' Backup of database '+@DbName+' failed with error code '+Cast(Error_Number() as nvarchar)+' - ['+Error_Message()+']'
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+ '-	'+@vMessage		
		RAISERROR(@vMessage,16,1) WITH NOWAIT
		RETURN -1			
	END CATCH
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Finished'

	RETURN
END
GO 
/*
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'FULL'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'DIFFERENTIAL'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'LOG'

	--Invalid cases
	--DB does not exist
	EXEC [MaintenanceDBBackup] @DbName = 'DB NOT EXISTS', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'FULL'
	--Backup mode invalid
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'FULL INVALID'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'DIFFERENTIAL INVALID'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp', @BackupMode = 'LOG INVALID'
	--Backup location invalid
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Path Invalid', @BackupMode = 'FULL'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Path Invalid', @BackupMode = 'DIFFERENTIAL'
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Path Invalid', @BackupMode = 'LOG'
*/


