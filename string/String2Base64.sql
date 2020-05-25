--======================================================
-- Usage: 	Convert to Base64
-- Notes: 
-- History:
-- Date			Author		Description
-- 2020-05-25	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS String2Base64
GO
CREATE FUNCTION String2Base64(@String nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
	RETURN 
	(
		SELECT	CONVERT(XML, N'').value('xs:base64Binary(xs:hexBinary(sql:column("bin")))', 'NVARCHAR(MAX)') AS Base64Encoding
        FROM	(
					SELECT CONVERT(VARBINARY(MAX),@String) AS bin
				) AS D
	)
END
GO

/*
	SELECT dbo.[String2Base64]('username:password')
*/