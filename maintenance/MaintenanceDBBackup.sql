--======================================================
-- Usage: This is to perform a FULL backup of a database.
-- Notes: 
-- History:
-- Date			By			Description
-- 20-Jun-2019	DN			Created.
-- ===========================================================================
DROP PROCEDURE IF EXISTS [MaintenanceDBBackup] 
GO

CREATE PROCEDURE [MaintenanceDBBackup]	@DbName sysname,
										@BackupFolderPath nvarchar(256)
AS
BEGIN
	DECLARE @vBackupFileLocation nvarchar(256)
	DECLARE @vCurrent DATE = CURRENT_TIMESTAMP

	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Processing FULL BACKUP database: '+@DbName+' - to location: '+@BackupFolderPath+'.'
	IF RIGHT(@BackupFolderPath,1) <> '\' SET @BackupFolderPath = @BackupFolderPath + '\'

	Set @vBackupFileLocation = @BackupFolderPath + @DbName + '-FULL-'+FORMAT(@vCurrent,'yyyyMMdd')+'.bck'
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		FULL backup file path: '+@vBackupFileLocation+'.'
		
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		Performing the backup...'
	BEGIN TRY
		BACKUP DATABASE @DbName TO DISK = @vBackupFileLocation WITH NAME = @DbName, NOFORMAT, INIT, SKIP, NOUNLOAD, CHECKSUM
	END TRY
	BEGIN CATCH
		Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Full backup of database '+@DbName+' failed with error code '+Cast(Error_Number() as nvarchar)+' - ['+Error_Message()+']'
		RETURN -1			
	END CATCH
	Print CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Finished'

	RETURN
END
GO 
/*
	EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp'
*/


