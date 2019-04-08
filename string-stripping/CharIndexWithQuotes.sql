--======================================================
-- Usage: CharIndexWithQuotes
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-03-29	Dave		Intial
--======================================================
IF OBJECT_ID('CharIndexWithQuotes', 'FN') IS NOT NULL
	DROP FUNCTION CharIndexWithQuotes
GO
CREATE FUNCTION CharIndexWithQuotes(@ExpressionToSearch VARCHAR(8000), 
									@ExpressionToFind VARCHAR(255) = ',', 
									@QuotesOn Bit = 0)
RETURNS int
AS
BEGIN
	IF @QuotesOn = 0 OR LEFT(@ExpressionToSearch, 1) <> '"' 
		RETURN CHARINDEX(@ExpressionToFind, @ExpressionToSearch)
	
	DECLARE @vEndQuotePosition Int 
	SET @vEndQuotePosition = NULLIF(CHARINDEX('"', @ExpressionToSearch, 2),0)

	RETURN CHARINDEX(@ExpressionToFind, @ExpressionToSearch, Coalesce(@vEndQuotePosition, LEN(@ExpressionToSearch)))
END
GO

/*
	DECLARE @test varchar(30);
	SET @test = '"This,is,a",sentence'
	SELECT dbo.CharIndexWithQuotes(@test, ',', 1)
*/
