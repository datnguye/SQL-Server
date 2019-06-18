--======================================================
-- Usage: GetRandomString (support to generate 512 characters in maximum)
-- Notes: 
--
-- History:
-- Date			Author		Description
-- 2019-06-18	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetRandomString
GO
CREATE PROCEDURE GetRandomString	@Length SmallInt = 40,
									@IncludeUpperCase Bit = 1,
									@IncludeLowerCase Bit = 1,
									@IncludeNumber Bit = 1,
									@IncludeSpecialCharacters Bit = 0
AS 
BEGIN
	DECLARE @UpperCaseLetters	varchar(26) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	DECLARE @LowerCaseLetters	varchar(26) = 'abcdefghijklmnopqrstuvwxyz'
	DECLARE @NumberLetters		varchar(10) = '1234567890'
	DECLARE @SpecialLetters		varchar(33) = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'

	DECLARE @vSourceLetters varchar(95) = ''
	DECLARE @vSourceLettersLen Int = 95
    DECLARE @vResult varchar(512) = ''

	IF @IncludeUpperCase = 1			SET @vSourceLetters += @UpperCaseLetters
	IF @IncludeLowerCase = 1			SET @vSourceLetters += @LowerCaseLetters
	IF @IncludeNumber = 1				SET @vSourceLetters += @NumberLetters
	IF @IncludeSpecialCharacters = 1	SET @vSourceLetters += @SpecialLetters

	SET @vSourceLettersLen = LEN(@vSourceLetters)
	PRINT @vSourceLetters

	WHILE LEN(@vResult) < @Length
	BEGIN
		SET @vResult = @vResult + SUBSTRING(@vSourceLetters, (ABS(CHECKSUM(NEWID()))%@vSourceLettersLen)+1, 1)
	END

	--RESULT
    SELECT @vResult
END
/*
EXEC dbo.GetRandomString @Length = -1
EXEC dbo.GetRandomString @Length = 0
EXEC dbo.GetRandomString @Length = 10
EXEC dbo.GetRandomString @Length = 512
EXEC dbo.GetRandomString @Length = 512, @IncludeSpecialCharacters = 1
EXEC dbo.GetRandomString @Length = 40, @IncludeSpecialCharacters = 1
*/
