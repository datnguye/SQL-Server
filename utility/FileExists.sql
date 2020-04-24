--======================================================
-- Usage:	Check file path existing
-- Notes:	
-- History:
-- Date			Author		Description
-- 2020-04-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS dbo.FileExists
GO
CREATE FUNCTION dbo.FileExists(@Path varchar(512))
RETURNS BIT
AS
BEGIN
     DECLARE @Result INT
     EXEC 	master.dbo.xp_fileexist @Path, @Result OUTPUT
     RETURN CAST(@Result as BIT)
END;
GO

/*
SELECT dbo.FileExists('C:\Temp\textFile.txt') as FileExists
*/