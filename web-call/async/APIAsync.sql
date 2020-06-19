--======================================================
-- Usage: APIAsync
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
DROP PROCEDURE IF EXISTS APIAsync
GO
CREATE PROCEDURE APIAsync	@Url varchar(8000), 
							@Method varchar(5) = 'GET',--POST
							@BodyData nvarchar(max) = NULL,--normally json object string : '{"key":"value"}',
							@Authorization varchar(8000) = NULL,--Basic auth token, APIAsync key,...
							@ContentType varchar(255) = 'application/json'--'application/xml'
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @vWin int --token of WinHttp object
    DECLARE @vReturnCode int 
    DECLARE @tResponse TABLE (ResponseText nvarchar(4000)) 

	-- NOTE: Maximum 256 instances. NO MORE!. Ref: https://docs.microsoft.com/en-us/windows/win32/wmisdk/creating-an-instance
    EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
    IF @vReturnCode <> 0 GOTO EXCEPTION

	-- This section can be put in a loop
	-- Store Win object into a temp table
	PRINT 'Win = ' + CONVERT(varchar(255), @vWin)
	SELECT @vReturnCode = dbo.SendAsync(@vWin, @Url, @Method, @BodyData, @Authorization, @ContentType)
	IF @vReturnCode <> 0 GOTO EXCEPTION
	

	-- This section can be put in a loop
	-- Process for each Win object from the temp table
	PRINT 'Get response by Win = ' + CONVERT(varchar(255), @vWin)
	INSERT 
	INTO	@tResponse
	SELECT	ResponseText
	FROM	dbo.GetResponseAsync(@vWin)
	WHERE	ResponseText IS NOT NULL

	IF @vReturnCode = 0 
		GOTO RESULT

	EXCEPTION:
		BEGIN
			DECLARE @tException TABLE
			(
				Error binary(4),
				Source varchar(8000),
				Description varchar(8000),
				HelpFile varchar(8000),
				HelpID varchar(8000)
			)

			INSERT INTO @tException EXEC sp_OAGetErrorInfo @vWin
			INSERT
			INTO	@tResponse
			(
					ResponseText
			)
			SELECT	( 
						SELECT	*
						FROM	@tException
						FOR		JSON AUTO
					) AS ResponseText
		END

	--FINALLY
	RESULT:
	--Dispose objects 
	IF @vWin IS NOT NULL
		EXEC sp_OADestroy @vWin

	--Result
    SELECT	* 
	FROM	@tResponse

	RETURN
END
/*
EXEC APIAsync @Method = 'GET', @Url = 'http://dummy.restapiexample.com/api/v1/employees'
EXEC API @Method = 'GET', @Url = 'http://dummy.restapiexample.com/api/v1/employees'

*/
