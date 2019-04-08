--======================================================
-- Usage: GetHttpRequest
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
-- 2019-04-08	DN		Intial
--======================================================
IF OBJECT_ID('GetHttpRequest', 'FN') IS NOT NULL
	DROP FUNCTION GetHttpRequest
GO
CREATE FUNCTION GetHttpRequest(@Url varchar(8000))
RETURNS varchar(8000)
AS 
BEGIN
    DECLARE @vWin int --token of WinHttp object
    DECLARE @vReturnCode int 
    DECLARE @vResponse varchar(8000)

	--Creates an instance of WinHttp.WinHttpRequest
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/winhttp-versions
	--Version of 5.0 is no longer supported
    EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Opens an HTTP connection to an HTTP resource.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-open
    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, 'GET'/*Method*/, @Url /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Sends an HTTP request to an HTTP server.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
    EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Get Response text
	--Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
    EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText',@vResponse OUTPUT
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin

	--Dispose objects 
    EXEC @vReturnCode = sp_OADestroy @vWin 
    IF @vReturnCode <> 0 EXEC sp_OAGetErrorInfo @vWin 

	--RESULT
    RETURN @vResponse
END
/*
select dbo.GetHttpRequest('http://example.com/')
*/
