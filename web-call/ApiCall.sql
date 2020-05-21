--======================================================
-- Usage: ApiCall (supported methods: GET,...)
-- Notes: 
-- Dependencies: Required to enable 'show advanced options' and 'Ole Automation Procedures'
--	sp_configure 'show advanced options', 1;
--	go
--	RECONFIGURE;
--	GO
--	sp_configure 'Ole Automation Procedures', 1;
--	GO
--	RECONFIGURE;
--	GO
--
-- History:
-- Date			Author		Description
-- 2020-05-21	DN		Intial
--======================================================
DROP PROCEDURE IF EXISTS ApiCall
GO
CREATE PROCEDURE ApiCall	@Url varchar(8000), 
							@Method varchar(10) = 'GET'
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @vWin int --token of WinHttp object
    DECLARE @vReturnCode int 
    DECLARE @tResponse TABLE (ResponseText nvarchar(max))
    DECLARE @vPropertyName varchar(128)

	--Creates an instance of WinHttp.WinHttpRequest
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/winhttp-versions
	--Version of 5.0 is no longer supported
    EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Opens an HTTP connection to an HTTP resource.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-open
    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @Url /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Sends an HTTP request to an HTTP server.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
    EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Get Response text
	--Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
	INSERT INTO @tResponse (ResponseText) 
	EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Dispose objects 
    EXEC @vReturnCode = sp_OADestroy @vWin 
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin 

	--RESULT
    SELECT * FROM @tResponse

	RETURN
END
/*
EXEC dbo.ApiCall 'http://example.com/'
EXEC dbo.ApiCall 'http://dummy.restapiexample.com/api/v1/employees'
*/
