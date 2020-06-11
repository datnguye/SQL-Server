--======================================================
-- Usage: GetInsert_MongoShell
-- History:
-- Date			Author		Description
-- 2020-06-11	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [dbo].GetInsert_MongoShell
GO
CREATE PROCEDURE [dbo].GetInsert_MongoShell	@TableSchema sysname = 'dbo',
											@TableName sysname,
											@Where nvarchar(4000) = '',
											@ExportPath nvarchar(255) = 'C:\Temp\<table-name>-<yyyyMMdd-HHmmss>.js'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @vExportPath nvarchar(255) = @ExportPath

	RETURN
END
GO
/*
EXEC GetInsert_MongoShell
	@TableName='ApiCovid19Route',
	@Where=''
*/