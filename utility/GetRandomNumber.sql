--======================================================
-- Usage:	GetRandomNumber
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
DROP FUNCTION IF EXISTS GetRandomNumber
GO
CREATE FUNCTION GetRandomNumber(@BaseNumber INT)
RETURNS INT
AS 
BEGIN
	--RESULT
    RETURN ABS(CHECKSUM((SELECT RandValue FROM VWRAND)))%@BaseNumber
END
/*
SELECT dbo.GetRandomNumber(255)
SELECT dbo.GetRandomNumber(2)
*/
