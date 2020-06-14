--======================================================
-- Usage: FtpDownload using native cmd shell
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
										@FtpFileName nvarchar(255),
										@FtpHost nvarchar(255),
										@FtpUser nvarchar(255),
										@FtpPassword nvarchar(255),
										@LocalFolder nvarchar(255) = 'C:\Temp\'
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vMessage nvarchar(MAX)
	DECLARE @vCommand nvarchar(4000)
	DECLARE @RunFileName nvarchar(255) = 'FtpDownload_RUN.txt'
	DECLARE @vReturnCode INT = 0

	IF RIGHT(@FtpFolder,1) <> '/' SET @FtpFolder += '/'
	IF RIGHT(@LocalFolder,1) <> '\' AND RIGHT(@LocalFolder,1) <> '/' SET @LocalFolder += '\'
	SET @RunFileName = @LocalFolder + @RunFileName

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Starting FTP download files from: ' + @FtpHost + ' - with user: ' + @FtpUser
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Remote folder: ' + @FtpFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Local folder: ' + @LocalFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		File: ' + @FtpFileName
	RAISERROR(@vMessage,0,1)
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Creating run file under: ' + @RunFileName
	RAISERROR(@vMessage,0,1)
	SET @vCommand = 'echo open ' + @FtpHost + ' > ' + @RunFileName
	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	IF @vReturnCode <> 0 GOTO EXCEPTION

	SET @vCommand = 'echo ' + @FtpUser + '>> "' + @RunFileName + '"'
	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	IF @vReturnCode <> 0 GOTO EXCEPTION

	SET @vCommand = 'echo ' + @FtpPassword + '>> "' + @RunFileName + '"'
	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	IF @vReturnCode <> 0 GOTO EXCEPTION

	SET @vCommand = 'echo get "' + @FtpFolder + @FtpFileName + '" "' + @LocalFolder + @FtpFileName + '" >> "' + @RunFileName + '"'
	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	IF @vReturnCode <> 0 GOTO EXCEPTION
	
	SET @vCommand = 'echo quit >> "' + @RunFileName + '"'
	EXEC @vReturnCode = master..xp_cmdshell @vCommand, no_output
	IF @vReturnCode <> 0 GOTO EXCEPTION
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Start running'
	RAISERROR(@vMessage,0,1)
	SET @vCommand = 'ftp -s:"' + @RunFileName + '"'
	RAISERROR(@vCommand,0,1)
	EXEC @vReturnCode = master..xp_cmdshell @vCommand
	IF @vReturnCode <> 0 GOTO EXCEPTION
	
	IF @vReturnCode = 0 GOTO DONE
	EXCEPTION:
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Something wrong happened'
		RAISERROR(@vMessage,16,1)

		RETURN -1
	END
	
	DONE:
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Finished'
	RAISERROR(@vMessage,0,1)

	RETURN
END
GO
/*
	EXEC dbo.FtpDownload	@FtpHost='localhost', @FtpUser='ftpuser', @FtpPassword='ftpuser',
							@FtpFolder = '/', @LocalFolder = 'C:\Temp',
							@FtpFileName = 'Countries-20200614-090721.sql'
*/


