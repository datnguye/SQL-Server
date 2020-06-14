--======================================================
-- Usage: FtpDownload using Python code
-- Notes: 
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
										@LocalFolder nvarchar(255) = 'C:\Temp\'
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vMessage nvarchar(MAX)
	DECLARE @vCommand nvarchar(4000)
	DECLARE @vReturnCode INT = 0

	IF RIGHT(@FtpFolder,1) <> '/' SET @FtpFolder += '/'
	IF RIGHT(@LocalFolder,1) <> '\' AND RIGHT(@LocalFolder,1) <> '/' SET @LocalFolder += '\'

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Starting FTP download files from: ' + @FtpHost + ' - with user: ' + @FtpUser
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Remote folder: ' + @FtpFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Local folder: ' + @LocalFolder
	RAISERROR(@vMessage,0,1)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		File(s): ' + @FtpFileMask
	RAISERROR(@vMessage,0,1)

	SET @vCommand = N'
from ftplib import FTP
import fnmatch as fm

ftp = FTP()

ftp.connect(host="' + @FtpHost + N'")
ftp.login(user="' + @FtpUser + N'", passwd="' + @FtpPassword + N'")

ftp.cwd("' + @FtpFolder + N'")

files = ftp.nlst()
files = (file for file in files if fm.fnmatch(file, "' + @FtpFileMask + N'"))

for file in files:
    print(f"Downloading {file}")
    with open("' + REPLACE(@LocalFolder,'\','\\') + N'" + file, "wb") as fp:
        ftp.retrbinary("RETR " + file, fp.write)

ftp.quit()
print("Done")'

	--PRINT @vCommand
	EXEC @vReturnCode = sp_execute_external_script 
		@language =N'Python', 
		@script= @vCommand

	IF @vReturnCode <> 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'		Something wrong happened. Please help to review message log'
		RAISERROR(@vMessage,16,1)

		RETURN -1
	END
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'	Finished'
	RAISERROR(@vMessage,0,1)

	RETURN
END
GO
/*
	EXEC dbo.FtpDownload	@FtpHost='localhost', @FtpUser='ftpuser', @FtpPassword='ftpuser', @FtpFolder = '/', 
							@LocalFolder = 'C:\Temp'
*/


