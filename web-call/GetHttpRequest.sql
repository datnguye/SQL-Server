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
-- 2019-04-08	Dave		Intial
--======================================================
IF OBJECT_ID('GetHttpRequest', 'FN') IS NOT NULL
	DROP FUNCTION GetHttpRequest
GO
CREATE FUNCTION GetHttpRequest(@Url varchar(8000))
RETURNS varchar(8000)
AS 
BEGIN
    DECLARE @vWin int 
    DECLARE @vHttpRequest int 
    DECLARE @vResponse varchar(8000)

    EXEC @vHttpRequest=sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT 
    IF @vHttpRequest <> 0 EXEC sp_OAGetErrorInfo @vWin

    EXEC @vHttpRequest=sp_OAMethod @vWin, 'Open',NULL,'GET',@Url,'false'
    IF @vHttpRequest <> 0 EXEC sp_OAGetErrorInfo @vWin

    EXEC @vHttpRequest=sp_OAMethod @vWin,'Send'
    IF @vHttpRequest <> 0 EXEC sp_OAGetErrorInfo @vWin

    EXEC @vHttpRequest=sp_OAGetProperty @vWin,'ResponseText',@vResponse OUTPUT
    IF @vHttpRequest <> 0 EXEC sp_OAGetErrorInfo @vWin

    EXEC @vHttpRequest=sp_OADestroy @vWin 
    IF @vHttpRequest <> 0 EXEC sp_OAGetErrorInfo @vWin 

    RETURN @vResponse
END
/*
select dbo.GetHttpRequest('http://example.com/')
*/