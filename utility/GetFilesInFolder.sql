--======================================================
-- Usage: GetFilesInFolder
-- Notes: xp_cmdshell needs enabling
--		EXEC sp_configure 'xp_cmdshell', 1
--		RECONFIGURE;
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-23	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetFilesInFolder
GO
CREATE PROCEDURE [dbo].[GetFilesInFolder]	@Folder varchar(256) = NULL,
											@MarginIndex INT = 39,
											@Debug BIT = 0
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vCommand nvarchar(4000) = 'DIR "' + @Folder + '" /A-D /T:W'
		
	IF OBJECT_ID('tempdb.dbo.#tOutput','U') IS NOT NULL DROP TABLE #tOutput
	CREATE TABLE #tOutput (ID INT IDENTITY(1,1), OUTPUT VARCHAR(255) NULL)

	INSERT 
	INTO	#tOutput (OUTPUT)
	EXEC	master.dbo.xp_cmdshell @vCommand

	IF @Debug = 1
		SELECT * FROM #tOutput
			
	SELECT 	LTRIM(RTRIM(Q1.FileName)) as FileName,
			CONVERT(DATETIME,SUBSTRING(Q1.ModifiedDate,7,4)+'-'+SUBSTRING(Q1.ModifiedDate,4,2)+'-'+SUBSTRING(Q1.ModifiedDate,1,2)+' '+SUBSTRING(Q1.ModifiedDate,12,6)+':00') ModifiedDate
	FROM
	(
		SELECT 	SUBSTRING(OUTPUT,1,17) ModifiedDate,
				SUBSTRING(OUTPUT,CHARINDEX(' ',OUTPUT,@MarginIndex)+1,LEN(OUTPUT)-CHARINDEX(' ',OUTPUT,@MarginIndex)) FileName
		FROM 	#tOutput
		WHERE 	OUTPUT IS NOT NULL
			AND ID > 4 
			AND ID < (SELECT MAX(id) FROM #tOutput)-2
	) Q1
	ORDER BY 2 DESC
	
	RETURN
END
GO
/*
	EXEC dbo.GetFilesInFolder @Folder = 'C:\Temp'
	EXEC dbo.GetFilesInFolder @Folder = 'C:\Temp', @MarginIndex = 31
	EXEC dbo.GetFilesInFolder @Folder = 'D:\FTP\Temp', @Debug = 1
*/


