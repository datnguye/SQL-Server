--======================================================
-- Usage: FindStringData
-- Notes: Depends on DbExec
-- History:
-- Date			Author		Description
-- 2020-09-04	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS dbo.FindStringData
GO
CREATE PROCEDURE dbo.FindStringData @SearchPattern sysname
AS
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS ##temp
	CREATE TABLE ##temp (ColumnName sysname)
	DECLARE @vSQL nvarchar(MAX) = '';
	
	SELECT	@vSQL += FORMATMESSAGE('IF EXISTS(SELECT TOP 1 1 FROM [%s].[%s] WHERE [%s] LIKE ''%s'') INSERT INTO ##temp (ColumnName) SELECT ''%s'';', 
						TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, @SearchPattern, FORMATMESSAGE('[%s].[%s].[%s]', TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME))
	FROM	INFORMATION_SCHEMA.COLUMNS
	WHERE	DATA_TYPE LIKE '%char%';
		
	--Searching...
	EXEC (@vSQL)

	--RESULT
	SELECT * FROM ##temp

	RETURN;
END
GO

/*
	EXEC FindStringData @SearchPattern='%promo%'
*/

