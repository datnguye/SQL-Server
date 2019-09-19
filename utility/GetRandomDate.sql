--======================================================
-- Usage:	GetRandomDate
-- Notes:	Run script to create VWRAND to have workaround usage of RAND function
--			OR: convert this to be a stored procedure if you'd like not to create the SQL View
-- History:
-- Date			Author		Description
-- 2019-09-20	DN			Intial
--======================================================
/*
DROP VIEW IF EXISTS VWRAND
GO
CREATE VIEW VWRAND
AS
	SELECT RAND() AS RandValue
GO
*/
DROP FUNCTION IF EXISTS GetRandomDate
GO
CREATE FUNCTION GetRandomDate()
RETURNS Date
AS 
BEGIN
	DECLARE @vStart DATE = '1980-01-01'
	DECLARE @vEnd DATE = GETDATE()
 
	--RESULT
    RETURN DATEADD(DAY, ABS(CHECKSUM((SELECT RandValue FROM VWRAND))) % ( 1 + DATEDIFF(DAY, @vStart ,@vEnd)), @vStart)
END
/*
SELECT dbo.GetRandomDate()
*/