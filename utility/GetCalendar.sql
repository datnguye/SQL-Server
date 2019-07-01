--======================================================
-- Usage: GetCalendar - to get list date
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-06-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS GetCalendar
GO
CREATE FUNCTION GetCalendar
(
	@Date DATE = NULL, 
	@BackDay INT = 30
)
RETURNS 
	@Result TABLE (Id INT, DateValue DATE)
AS
BEGIN
	;WITH cte AS
	(
		SELECT		TOP (@BackDay) ROW_NUMBER() OVER (ORDER BY s1.[object_id]) AS Id
		FROM		sys.all_objects AS s1
		CROSS JOIN	sys.all_objects AS s2
		ORDER BY	s1.[object_id]
	)
	INSERT INTO @Result (Id, DateValue)
	SELECT	Id,
			DATEADD(DAY,-Id,DATEADD(Day,1,COALESCE(@Date,GETDATE())))
	FROM	cte
	RETURN
END
GO
/*
	SELECT * FROM dbo.GetCalendar(default,default)--return date from today back to 30 days
	SELECT * FROM dbo.GetCalendar('2019-06-25', 20)--return date from '2019-06-25' back to 20 days
*/