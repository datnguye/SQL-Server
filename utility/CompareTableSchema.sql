--======================================================
-- Usage: CompareTableSchema
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-12-24	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [CompareTableSchema]
GO
CREATE PROCEDURE [dbo].[CompareTableSchema]	@SourceDatabase sysname = NULL,
											@SourceSchema sysname = 'dbo',
											@SourceTable sysname = '#tSource', 
											@DestinationDatabase sysname = NULL,
											@DestinationSchema sysname = 'dbo',
											@DestinationTable sysname = 'Test'
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @vSQL nvarchar(4000)

	IF @SourceDatabase IS NULL SET @SourceDatabase = DB_NAME()
	IF @DestinationDatabase IS NULL SET @DestinationDatabase = DB_NAME()

	DECLARE @tSSchema TABLE (Name sysname, DataType sysname, MaxLength int, Precision int, Scale int, IsNullable bit)
	DECLARE @tDSchema TABLE (Name sysname, DataType sysname, MaxLength int, Precision int, Scale int, IsNullable bit)

	SET @vSQL = FORMATMESSAGE(N'SELECT name,TYPE_NAME(user_type_id) as data_type, max_length, precision, scale, is_nullable FROM %s.sys.columns WHERE Object_ID = OBJECT_ID(''%s.%s.%s'')', @SourceDatabase,@SourceDatabase, @SourceSchema, @SourceTable)
	INSERT INTO @tSSchema EXEC sp_executesql @vSQL

	SET @vSQL = FORMATMESSAGE(N'SELECT name,TYPE_NAME(user_type_id) as data_type, max_length, precision, scale, is_nullable FROM %s.sys.columns WHERE Object_ID = OBJECT_ID(''%s.%s.%s'')', @DestinationDatabase,@DestinationDatabase, @DestinationSchema, @DestinationTable)
	INSERT INTO @tDSchema EXEC sp_executesql @vSQL

	--RESULT
	SELECT	FORMATMESSAGE(N'%s column''s data type is differred in %s.%s.%s table comparing to the source one', D.Name, @DestinationDatabase, @DestinationSchema, @DestinationTable) as Messages, 
			D.Name as ColumnName
	FROM	@tSSchema S
	JOIN	@tDSchema D 
		ON	S.Name = D.Name
	WHERE	S.DataType <> D.DataType	
	UNION ALL
	SELECT	FORMATMESSAGE(N'String binary could be truncated in %s column (lenght = %d, expected = %d) of %s.%s.%s table comparing to the source one', D.Name, D.MaxLength, S.MaxLength, @DestinationDatabase, @DestinationSchema, @DestinationTable) as Messages, 
			D.Name as ColumnName
	FROM	@tSSchema S
	JOIN	@tDSchema D 
		ON	S.Name = D.Name
	WHERE	S.DataType = D.DataType
		AND D.MaxLength < S.MaxLength
	RETURN
END
/*
	Use M1Master
	DROP TABLE IF EXISTS #tSource
	CREATE TABLE #tSource (FirstName varchar(255), LastName nvarchar(255))

	DROP TABLE IF EXISTS Destination
	CREATE TABLE Destination (FirstName nvarchar(255), LastName nvarchar(250))

	EXEC [dbo].[CompareTableSchema]	@SourceDatabase = 'tempdb', @SourceTable = '#tSource',
									@DestinationDatabase = 'M1Master', @DestinationTable = 'Destination'
*/
