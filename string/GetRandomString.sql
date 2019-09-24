--======================================================
-- Usage:	GetRandomString (support to generate 512 characters in maximum)
-- Notes:	Run script to create VWRAND to have workaround usage of RAND function
--			OR: convert this to be a stored procedure if you'd like not to create the SQL View
-- History:
-- Date			Author		Description
-- 2019-06-19	DN			Intial
--======================================================
/*
DROP VIEW IF EXISTS VWRAND
GO
CREATE VIEW VWRAND
AS
	SELECT RAND() AS RandValue
GO
*/
DROP FUNCTION IF EXISTS GetRandomString
GO
CREATE FUNCTION GetRandomString	(@Length SmallInt = 40, @IncludeNumber Bit = 0, @IncludeSpecialCharacters Bit = 0)
RETURNS varchar(512)
AS 
BEGIN
	DECLARE @UpperCaseLetters	varchar(26) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	DECLARE @LowerCaseLetters	varchar(26) = 'abcdefghijklmnopqrstuvwxyz'
	DECLARE @NumberLetters		varchar(10) = '1234567890'
	DECLARE @SpecialLetters		varchar(33) = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'

	DECLARE @vSourceLetters varchar(95) = ''
	DECLARE @vSourceLettersLen Int = 95
    DECLARE @vResult varchar(512) = ''

	SET @vSourceLetters += @UpperCaseLetters
	SET @vSourceLetters += @LowerCaseLetters
	IF @IncludeNumber = 1 SET @vSourceLetters += @NumberLetters
	IF @IncludeSpecialCharacters = 1 SET @vSourceLetters += @SpecialLetters

	SET @vSourceLettersLen = LEN(@vSourceLetters)

	WHILE LEN(@vResult) < @Length
	BEGIN
		SET @vResult = @vResult + SUBSTRING(@vSourceLetters, (ABS(CHECKSUM((SELECT RandValue FROM VWRAND)))%@vSourceLettersLen)+1, 1)
	END

	--RESULT
    RETURN @vResult
END
/*
SELECT dbo.GetRandomString(-1 ,0, 0)
SELECT dbo.GetRandomString(0  ,0, 0)
SELECT dbo.GetRandomString(10 ,0, 0)
SELECT dbo.GetRandomString(10 ,1, 0)
SELECT dbo.GetRandomString(512,0, 0)
SELECT dbo.GetRandomString(512,0, 1) 
SELECT dbo.GetRandomString(40 ,0, 1) 
*/
