--======================================================
-- Usage: 	Remove leading & trailling spaces of a string
-- 			< SQL 2016
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-09-19	Dave		Intial
--======================================================
DROP FUNCTION IF EXISTS [Trim]
GO
CREATE FUNCTION [Trim](@String nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
	RETURN LTRIM(RTRIM(@String))
END
GO

/*
	SELECT dbo.[Trim]('                This is to be trimmed                    ')
*/
