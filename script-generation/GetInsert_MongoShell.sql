--======================================================
-- Usage: GetInsert_MongoShell
-- NOTES: This routine is using SQL Windows Authentication to export js file
-- History:
-- Date			Author		Description
-- 2020-06-11	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [dbo].GetInsert_MongoShell
GO
CREATE PROCEDURE [dbo].GetInsert_MongoShell	@TableName sysname,
											@TableSchema sysname = 'dbo',
											@Top INT = NULL,
											@Where nvarchar(4000) = '',
											@ExportPath nvarchar(255) = NULL,
											@ExportOverrideServerInstance nvarchar(255) = NULL,
											@OverrideDestinationCollection nvarchar(255) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @vCommand nvarchar(4000)
	DECLARE @vCollectionName nvarchar(255) = COALESCE(@OverrideDestinationCollection, @TableName)
	DECLARE @vReturnCode INT

	SET @ExportPath += '<table-name>-<yyyyMMdd-HHmmss>.js' 
	DECLARE @vExportPath nvarchar(255) = REPLACE(REPLACE(@ExportPath, '<table-name>', @TableName), '<yyyyMMdd-HHmmss>', FORMAT(GETDATE(), 'yyyyMMdd-HHmmss'))

	--Checking for the existence of @TableName
	IF NOT EXISTS (SELECT	TOP 1 1
					FROM	INFORMATION_SCHEMA.TABLES
					WHERE	TABLE_NAME = @TableName
						AND (@TableSchema IS NULL OR TABLE_SCHEMA = @TableSchema)
						AND	(TABLE_TYPE = 'BASE TABLE' OR TABLE_TYPE = 'VIEW'))
	BEGIN
		RAISERROR('User table or view not found.',16,1)
		RAISERROR('You may see this error, if you are not the owner of this table or view. In that case use @SchemaName parameter to specify the owner name.',0,1) WITH NOWAIT
		RAISERROR('Make sure you have SELECT permission on that table or view.',0,1) WITH NOWAIT
		RETURN -1
	END
	
	RAISERROR(@vExportPath,0,1) WITH NOWAIT

	--Store json data into a temp table
	DROP TABLE IF EXISTS ##tJsonData
	CREATE TABLE ##tJsonData (InsertScript nvarchar(max))

	SET @vCommand = '
	DECLARE @vJsonData nvarchar(max)
	SELECT @vJsonData = (
		SELECT		TOP (@Top) *
		FROM		<schema>.<table>
		<where>
		FOR JSON AUTO
	)
	INSERT INTO ##tJsonData SELECT ''db.createCollection("<collection>");db.<collection>.remove({});db.<collection>.insert('' + @vJsonData + '')'''

	SET @vCommand = REPLACE(@vCommand, '<schema>', @TableSchema)
	SET @vCommand = REPLACE(@vCommand, '<table>', @TableName)
	SET @vCommand = REPLACE(@vCommand, '<collection>', @vCollectionName)
	IF COALESCE(LTRIM(RTRIM(@Where)),'') <> ''
		SET @Where = 'WHERE	' + @Where
	ELSE 
		SET @Where = ''
	SET @vCommand = REPLACE(@vCommand, '<where>', @Where)

	EXEC sp_executesql @vCommand, N'@Top INT', @Top

	--Export to js file using sqlcmd
	IF @ExportPath IS NOT NULL
	BEGIN
		SET @vCommand = 'bcp "SELECT InsertScript FROM ##tJsonData" QUERYOUT "' + @vExportPath + '" -T -w -S "' + COALESCE(@ExportOverrideServerInstance, @@SERVERNAME) + '"'
		RAISERROR(@vCommand,0,1) WITH NOWAIT
		EXEC @vReturnCode = xp_cmdshell @vCommand, no_output
		IF @vReturnCode <> 0
		BEGIN
			RAISERROR('Exporting has been failed',16,1) WITH NOWAIT
			RETURN -1
		END
	END
	ELSE 
	BEGIN
		SELECT InsertScript FROM ##tJsonData
	END

	RETURN
END
GO
/*
--This sample will get results of https://github.com/datnguye/SQL-Server/blob/master/web-call/ApiCovid19.sql to generate mongo shell script

EXEC GetInsert_MongoShell	@TableName='ApiCovid19Route'
EXEC GetInsert_MongoShell	@TableName='ApiCovid19CountryDayOne', @Top = 10, @Where = 'CountryCode = ''vn'''
EXEC GetInsert_MongoShell	@TableName='ApiCovid19Route'

EXEC GetInsert_MongoShell	@TableName='ApiCovid19Route', @ExportPath = 'C:\Temp\'
EXEC GetInsert_MongoShell	@TableName='ApiCovid19Countries', @ExportPath = 'C:\Temp\'
EXEC GetInsert_MongoShell	@TableName='ApiCovid19CountryDayOne', @ExportPath = 'C:\Temp\'
EXEC GetInsert_MongoShell	@TableName='ApiCovid19Summary', @ExportPath = 'C:\Temp\'

*/