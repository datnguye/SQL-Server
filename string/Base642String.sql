--======================================================
-- Usage: 	Convert Base64 to string
-- Notes: 
-- History:
-- Date			Author		Description
-- 2020-05-25	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS Base642String
GO
CREATE FUNCTION Base642String(@Base64 nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
	RETURN 
	(
		SELECT CONVERT(nvarchar(max), CONVERT(xml,N'').value('xs:base64Binary(sql:variable("@Base64"))', 'VARBINARY(MAX)')) as D
	)
END
GO

/*
	SELECT dbo.[Base642String]('dQBzAGUAcgBuAGEAbQBlADoAcABhAHMAcwB3AG8AcgBkAA==')
*/