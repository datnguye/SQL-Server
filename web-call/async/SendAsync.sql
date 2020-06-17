--======================================================
-- Usage: SendAsync
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
-- 2020-06-17	DN		Intial
--======================================================
DROP FUNCTION IF EXISTS SendAsync
GO
CREATE FUNCTION SendAsync (
	@Win INT, 
	@Url varchar(8000), 
	@Method varchar(5) = 'GET',--POST
	@BodyData nvarchar(max) = NULL,--normally json object string : '{"key":"value"}',
	@Authorization varchar(8000) = NULL,--Basic auth token, SendAsync key,...
	@ContentType varchar(255) = 'application/json'--'application/xml'
)
RETURNS INT
AS 
BEGIN
    DECLARE @vReturnCode int 
    DECLARE @tResponse TABLE (ResponseText nvarchar(max))

    EXEC @vReturnCode = sp_OAMethod @Win, 'Open', NULL, @Method/*Method*/, @Url /*Url*/, 'true' /*IsAsync*/
    IF @vReturnCode <> 0 GOTO RESULT

	IF @Authorization IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @Win, 'SetRequestHeader', NULL, 'Authorization', @Authorization
		IF @vReturnCode <> 0 GOTO RESULT
	END

	IF @ContentType IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @Win, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
		IF @vReturnCode <> 0 GOTO RESULT
	END

    IF @BodyData IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @Win,'Send', NULL, @BodyData
		IF @vReturnCode <> 0 GOTO RESULT
	END
	ELSE
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @Win,'Send'
		IF @vReturnCode <> 0 GOTO RESULT
	END

	RESULT:
	RETURN @vReturnCode
END
/*
-- See APIAsync
*/
