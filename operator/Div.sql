--======================================================
-- Usage: Divison in safe
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-05-17	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS dbo.Div
GO
CREATE FUNCTION dbo.Div
(
    @Dividend sql_variant,
    @Divisor   sql_variant
)
RETURNS sql_variant
AS
BEGIN
     RETURN CASE
               WHEN @Divisor   = 0
                   THEN 0.00
               ELSE Convert(float, @Dividend) / Convert(float, @Divisor  ) 
           END;
END
GO
/*
	SELECT dbo.Div(4,4.4622434)
*/