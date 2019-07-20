--================================================================================
-- Usage: 	Replace any cases of multiple inputs by single input in a string
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-07-20	DN			Intial
--================================================================================
DROP FUNCTION IF EXISTS ReplaceManyToSingle
GO
CREATE FUNCTION ReplaceManyToSingle(@String nvarchar(max), @SingleInput char(1))
RETURNS nvarchar(max)
AS
BEGIN
	RETURN REPLACE(REPLACE(REPLACE(REPLACE(@String,@SingleInput,'{0}{1}'),'{1}{0}',''),'{1}',''),'{0}',@SingleInput)
END
GO

/*
	SELECT dbo.ReplaceManyToSingle('Thisssssss is one of the bad sentencessssssssssssssssssssssssssss','s')--any multi to single 's'
	SELECT dbo.ReplaceManyToSingle('This           is one of     the            bad sentences',' ')--any multi to single space
	SELECT dbo.ReplaceManyToSingle('This''''''''''''s one of the sentences which''''''s bad','''')--any multi to single quote
*/
