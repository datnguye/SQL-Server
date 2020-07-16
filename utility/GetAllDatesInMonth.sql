--======================================================
-- Usage: GetAllDatesInMonth - to get list date
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-07-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS GetAllDatesInMonth
GO
CREATE FUNCTION GetAllDatesInMonth
(
	@Date DATE
)
RETURNS TABLE
AS
	RETURN WITH
		T4		AS (SELECT 1 N UNION ALL SELECT 1 N UNION ALL SELECT 1 N UNION ALL SELECT 1 N),-- 4
		T16		AS (SELECT 1 N FROM T4 x, T4 y),-- 16
		Tally	AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) N FROM T16 x, T16 y)-- 256
		SELECT	DATEADD(DAY,N-1,DATEADD(DAY,1-DATEPART(DAY,@Date),@Date)) as [Date]
		FROM	Tally
		WHERE	N <= DATEDIFF(DAY, @Date, DATEADD(MONTH, 1, @Date))
GO
/*
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-01-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-02-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-03-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-04-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-05-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-06-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-07-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-08-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-09-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-10-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-11-01')
SELECT [Date] FROM dbo.GetAllDatesInMonth('2020-12-01')
*/