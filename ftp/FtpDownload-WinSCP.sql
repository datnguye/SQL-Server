--======================================================
-- Usage: FtpDownload using WinSCP
-- Notes: xp_cmdshell needs enabling
--		EXEC sp_configure 'xp_cmdshell', 1
--		RECONFIGURE;
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-06-14	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS FtpDownload
GO
CREATE PROCEDURE [dbo].[FtpDownload]	@FtpFolder nvarchar(255) = '/',
										@FtpFileMask nvarchar(255) = '*',
										@FtpHost nvarchar(255),
										@FtpUser nvarchar(255),
										@FtpPassword nvarchar(255),
										@LocalFolder nvarchar(255) = 'C:\Temp\',
										@WinSCPFolder nvarchar(255) = 'C:\Program Files (x86)\WinSCP\',
										@LogFolder nvarchar(255) = NULL
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vMessage nvarchar(MAX)
	DECLARE @vCommand nvarchar(4000)
	DECLARE @LogFileName nvarchar(255) = 'FtpDownload_log_' + FORMAT(GETDATE(),'_yyyyMMdd_HHmmss') + '.log'
	DECLARE @vReturnCode INT = 0

	IF RIGHT(@FtpFolder,1) <> '/' SET @FtpFolder += '/'
	IF RIGHT(@LocalFolder,1) <> '\' AND RIGHT(@LocalFolder,1) <> '/' SET @LocalFolder += '\'
	IF @LogFolder IS NULL SET @LogFolder = @LocalFolder

	SET @LogFileName = @LocalFolder + @LogFileName

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Starting FTP download files from: ' + @FtpHost + ' - with user: ' + @FtpUser
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Remote folder: ' + @FtpFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Local folder: ' + @LocalFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		File(s): ' + @FtpFileMask
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Log: ' + @LogFileName
	RAISERROR(@vMessage,0,1)

	SET @vCommand = LEFT(@LocalFolder,2) + 
					' & cd "' + @LocalFolder + '"' + 
					' & "' + @WinSCPFolder + 'WinSCP.com" /log="' + @LogFileName + '" /command ' + 
					'"open ftp://' + @FtpUser + ':' + @FtpPassword + '@' + @FtpHost + '" ' + 
					'"get ""' + @FtpFolder + '*"" -filemask=' + @FtpFileMask + '" "exit"'

	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Command used: '
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'			' + @vCommand
	RAISERROR(@vMessage,0,1)
	IF @vReturnCode <> 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Something wrong happened. Please help to review log: ' + @LogFileName
		RAISERROR(@vMessage,16,1)

		RETURN -1
	END
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Finished'
	RAISERROR(@vMessage,0,1)

	RETURN
END
GO
/*
	EXEC dbo.FtpDownload	@FtpHost='localhost', @FtpUser='ftpuser', @FtpPassword='ftpuser',
							@FtpFolder = '/', @LocalFolder = 'C:\Temp'

	EXEC dbo.FtpDownload	@FtpHost='localhost', @FtpUser='ftpuser', @FtpPassword='ftpuser', @FtpFileMask = '*-20200614-090721.sql',
							@FtpFolder = '/', @LocalFolder = 'C:\Temp'

	EXEC dbo.FtpDownload	@FtpHost='localhost', @FtpUser='ftpuser', @FtpPassword='ftpuser', @FtpFileMask = 'Countries-20200614-090721.sql',
							@FtpFolder = '/', @LocalFolder = 'C:\Temp'
*/


