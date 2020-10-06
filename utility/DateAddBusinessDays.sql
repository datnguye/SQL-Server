--======================================================
-- Usage:	DateAddBusinessDays
-- History:
-- Date			Author		Description
-- 2020-06-10	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS DateAddBusinessDays
GO
CREATE FUNCTION DateAddBusinessDays
(
    @Days int,
    @Date datetime  
)
RETURNS datetime
AS 
BEGIN
	DECLARE @DayOfWeek int
    SET @DayOfWeek = CASE 
                        WHEN @Days < 0 THEN (@@DateFirst + DATEPART(weekday, @Date) - 20) % 7
                        ELSE (@@DateFirst + DATEPART(weekday, @Date) - 2) % 7
                     END;

    IF @DayOfWeek = 6
		SET @Days = @Days - 1
    ELSE IF @DayOfWeek = -6
		SET @Days = @Days + 1;

    RETURN @Date + @Days + (@Days + @DayOfWeek) / 5 * 2;
END
/*
SELECT dbo.DateAddBusinessDays(-2,GETDATE())
SELECT dbo.DateAddBusinessDays(5,GETDATE())
*/