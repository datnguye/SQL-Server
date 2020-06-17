--======================================================
-- Usage: GetResponseAsync
-- Notes: 
-- Dependencies: Required to enable 'show advanced options' and 'Ole Automation Procedures'
/*
	sp_configure 'show advanced options', 1;
	go
	RECONFIGURE;
	GO
	sp_configure 'Ole Automation Procedures', 1;
	GO
	RECONFIGURE;
	GO
*/
-- History:
-- Date			Author		Description
-- 2020-05-21	DN		Intial
--======================================================
DROP FUNCTION IF EXISTS GetResponseAsync
GO
CREATE FUNCTION GetResponseAsync (@Win INT)
RETURNS @Result TABLE (Win INT, ResponseText nvarchar(4000))
AS
BEGIN
	DECLARE @vResponse nvarchar(4000)
	DECLARE @vTimeoutSec INT = 60
	DECLARE @vSuccess BIT  = 0
	
	--Wait
	EXEC sp_OAMethod @Win, 'WaitForResponse', NULL, @vTimeoutSec, @vSuccess OUT

	--Response
	IF @vSuccess IS NOT NULL
	BEGIN
		EXEC sp_OAGetProperty @Win,'ResponseText', @vResponse OUT
		INSERT INTO @Result SELECT @Win, @vResponse
	END

	IF @Win IS NOT NULL EXEC sp_OADestroy @Win

	RETURN
END
/*
-- See APIAsync
*/
