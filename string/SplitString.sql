--======================================================
-- Usage: 	SplitString with supporting value's order returned
-- 			From SQL 2016 and later
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-03-29	Dave		Intial
--======================================================
DROP FUNCTION IF EXISTS SplitString
GO
CREATE FUNCTION SplitString(@String nvarchar(max), @Delimiter char(1), @WithOrder bit)
RETURNS @Result TABLE (Piece nvarchar(max), OrderNo int)
AS
BEGIN
	INSERT 
	INTO @Result
	(
	    Piece,
	    OrderNo
	)
	SELECT	value,
			CASE 
				WHEN @WithOrder = 0 THEN NULL
				ELSE ROW_NUMBER() OVER (ORDER BY CURRENT_TIMESTAMP)
			END AS OrderNo
	FROM	STRING_SPLIT(@String, @Delimiter)

	RETURN
END
GO

/*
	SELECT * FROM dbo.SplitString('This,is,a,sentence,splitted by,comma',',',0)
	SELECT * FROM dbo.SplitString('This,is,a,sentence,splitted by,comma',',',1)
*/
