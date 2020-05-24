--======================================================
-- Usage: API (supported methods: GET,POST,...)
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
DROP PROCEDURE IF EXISTS API
GO
CREATE PROCEDURE API	@Url varchar(8000), 
						@Method varchar(5) = 'GET',--POST
						@BodyData nvarchar(max) = NULL,--normally json object string : '{"key":"value"}',
						@Authorization varchar(8000) = NULL,--Basic auth token, Api key,...
						@ContentType varchar(255) = 'application/json'--'application/xml'
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @vWin int --token of WinHttp object
    DECLARE @vReturnCode int 
    DECLARE @tResponse TABLE (ResponseText nvarchar(max))

	--Creates an instance of WinHttp.WinHttpRequest
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/winhttp-versions
	--Version of 5.0 is no longer supported
    EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
    IF @vReturnCode <> 0 GOTO EXCEPTION

	--Opens an HTTP connection to an HTTP resource.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-open
    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @Url /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 GOTO EXCEPTION

	IF @Authorization IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Authorization', @Authorization
		IF @vReturnCode <> 0 GOTO EXCEPTION
	END

	IF @ContentType IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
		IF @vReturnCode <> 0 GOTO EXCEPTION
	END

	--Sends an HTTP request to an HTTP server.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
    IF @BodyData IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @vWin,'Send', NULL, @BodyData
		IF @vReturnCode <> 0 GOTO EXCEPTION
	END
	ELSE
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
		IF @vReturnCode <> 0 GOTO EXCEPTION
	END

    IF @vReturnCode <> 0 GOTO EXCEPTION

	--Get Response text
	--Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
	INSERT INTO @tResponse (ResponseText) 
	EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
    IF @vReturnCode <> 0 GOTO EXCEPTION

	--Dispose objects 
    EXEC @vReturnCode = sp_OADestroy @vWin 
    IF @vReturnCode <> 0 GOTO EXCEPTION

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

	--RESULT
	RESULT:
    SELECT	* 
	FROM	@tResponse

	RETURN
END
/*
EXEC API @Url = 'http://example.com/'
EXEC API @Method = 'GET', @Url = 'http://dummy.restapiexample.com/api/v1/employees'

Send Grid Email:
EXEC API @Method = 'POST', 
@Url = 'https://api.sendgrid.com/v3/mail/send',
@Authorization = 'Bearer your-api-key',
@ContentType = 'application/json',
@BodyData = '{
  "personalizations": [
    {
      "to": [
        {
          "email": "your-email@domain"
        }
      ],
    }
  ],
  "from": {
    "email": "noreply@domain",
    "name": "No Reply"
  },
  "template_id": "your-template_id"
}'
*/
