--======================================================
-- Usage: GetInsert - to get (additional) INSERT scipt from a table
-- Notes: From SQL 2016
-- Parameters:
--		@TableName:					The table/view for which the INSERT statements will be generated using the existing data
--		@TableSchema:				Use this if your table schema is not a default one
--		@Where:						Use this parameter to filter the rows based on a filter condition (using WHERE)
--		@PrimaryColumns:			A comma delimited list of the fields to use for primary key checking
--		@IncludeColumnList:			Use this parameter to include/ommit column list in the generated INSERT statement
--		@Top:						Use this parameter to generate INSERT statements only for the TOP n rows
--		@ExcludeIdentityColumn:		Use this parameter to ommit the identity column
--		@ExcludeComputedColumns:	When 1, computed columns will NOT be included in the INSERT statement
--		@ColumnsIncluded:			List of columns to be included in the INSERT statement
--		@ColumnsExcluded:			List of columns to be excluded from the INSERT statement
-- History:
-- Date			Author		Description
-- 2019-05-17	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetInsert
GO
CREATE PROCEDURE [dbo].[GetInsert]	@TableName				NVARCHAR(256),
                                    @TableSchema			VARCHAR(20) = NULL,
                                    @Where					NVARCHAR(MAX) = NULL,
									@PrimaryColumns			NVARCHAR(MAX) = NULL,
                                    @Top					INT = NULL,
                                    @IncludeColumnList		BIT = 1,
                                    @ExcludeIdentityColumn	BIT = 0,
                                    @ExcludeComputedColumns BIT = 1,
                                    @ColumnsIncluded		NVARCHAR(MAX) = NULL,
                                    @ColumnsExcluded		NVARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON

	--Making sure user only uses either @ColumnsIncluded or @ColumnsExcluded
	IF @ColumnsIncluded IS NOT NULL AND @ColumnsExcluded IS NOT NULL
	BEGIN
		RAISERROR('Use either @ColumnsIncluded or @ColumnsExcluded. Do not use both the parameters at once',16,1)
		RETURN -1
	END

	--Making sure the @ColumnsIncluded and @ColumnsExcluded parameters are receiving values in proper format
	IF (@ColumnsIncluded IS NOT NULL AND PATINDEX('[%]', @ColumnsIncluded) = 0)
		OR (@ColumnsExcluded IS NOT NULL AND PATINDEX('[%]', @ColumnsExcluded) = 0)
		OR (@PrimaryColumns IS NOT NULL AND PATINDEX('[%]', @PrimaryColumns) = 0)
	BEGIN
		RAISERROR('Invalid use of @ColumnsIncluded property',16,1)
		PRINT 'Specify column names surrounded by single quotes and separated by commas'
		PRINT 'Eg: EXEC GetInsert @TableName = ''titles'', @ColumnsIncluded = ''[title_id],[title]'''
		PRINT 'Eg: EXEC GetInsert @TableName = ''titles'', @ColumnsExcluded = ''[title_id],[title]'''
		PRINT 'Eg: EXEC GetInsert @TableName = ''titles'', @PrimaryColumns = ''[title_id],[title]'''
		RETURN -1
	END

	--Checking to see if the database name is specified along wih the table name
	IF PARSENAME(@TableName, 3) IS NOT NULL
	BEGIN
		RAISERROR('Do not specify the database name. Be in the required database and just specify the table name.',16,1)
		RETURN -1
	END

	--Checking for the existence of @TableName
	IF NOT EXISTS (SELECT	TOP 1 1
					FROM	INFORMATION_SCHEMA.TABLES
					WHERE	TABLE_NAME = @TableName
						AND (@TableSchema IS NULL OR TABLE_SCHEMA = @TableSchema)
						AND	(TABLE_TYPE = 'BASE TABLE' OR TABLE_TYPE = 'VIEW'))
	BEGIN
		RAISERROR('User table or view not found.',16,1)
		PRINT 'You may see this error, if you are not the owner of this table or view. In that case use @SchemaName parameter to specify the owner name.'
		PRINT 'Make sure you have SELECT permission on that table or view.'
		RETURN -1
	END

	--Variable declarations
	DECLARE @vColumnId			INT = 0
	DECLARE @vColumnList		NVARCHAR(MAX) = ''
	DECLARE @vColumnName		NVARCHAR(MAX) = ''
	DECLARE @vStartInsert		NVARCHAR(MAX)
	DECLARE @vDataType			NVARCHAR(MAX)
	DECLARE @vCharacterSetName	NVARCHAR(MAX) --to define if it contains unicode text
	DECLARE @vPrimaryKeys		NVARCHAR(MAX)
	DECLARE @vValueList			NVARCHAR(MAX) = '' --This is the string that will be finally executed to generate INSERT statements
	DECLARE @vValueListBlank	NVARCHAR(MAX) = ''
	DECLARE @vValueListTemp		NVARCHAR(MAX) = ''
	DECLARE @vIdentityNames		NVARCHAR(MAX) = '' --Will contain the IDENTITY column's name in the table
	DECLARE @vPrimaryKeyList	TABLE (Name NVARCHAR(MAX))

	IF @TableSchema IS NULL
	BEGIN
		SET @vStartInsert = 'INSERT INTO ' + '[' + TRIM(@TableName) + ']'
	END
	ELSE
	BEGIN
		SET @vStartInsert = 'INSERT INTO ' + '[' + TRIM(TRIM(@TableSchema)) + '].' + '[' + TRIM(@TableName) + ']'
	END

	--To get the first column's ID
	SELECT	@vColumnId = MIN(ORDINAL_POSITION)
	FROM	INFORMATION_SCHEMA.COLUMNS (NOLOCK)
	WHERE	TABLE_NAME = @TableName
		AND (@TableSchema IS NULL OR TABLE_SCHEMA = @TableSchema)

	--Loop through all the columns of the table, to get the column names and their data types
	WHILE @vColumnId IS NOT NULL
	BEGIN
		SELECT	@vColumnName = QUOTENAME(COLUMN_NAME),
				@vDataType = DATA_TYPE,
				@vCharacterSetName = CHARACTER_SET_NAME
		FROM	INFORMATION_SCHEMA.COLUMNS (NOLOCK)
		WHERE	ORDINAL_POSITION = @vColumnId
			AND TABLE_NAME = @TableName
			AND	(@TableSchema IS NULL OR TABLE_SCHEMA = @TableSchema)

		--Selecting only user specified columns
		IF @ColumnsIncluded IS NOT NULL 
		AND CHARINDEX('[' + SUBSTRING(@vColumnName, 2, LEN(@vColumnName) - 2) + ']', @ColumnsIncluded) = 0
		BEGIN
			GOTO SKIP_LOOP
		END
		IF @ColumnsExcluded IS NOT NULL
		AND CHARINDEX('[' + SUBSTRING(@vColumnName, 2, LEN(@vColumnName) - 2) + ']', @ColumnsExcluded) <> 0
		BEGIN
			GOTO SKIP_LOOP
		END

		--Making sure to output SET IDENTITY_INSERT ON/OFF in case the table has an IDENTITY column
		IF (SELECT COLUMNPROPERTY(OBJECT_ID(QUOTENAME(COALESCE(@TableSchema, User_Name())) + '.' + @TableName), SUBSTRING(@vColumnName, 2, LEN(@vColumnName) - 2), 'IsIdentity')) = 1
		BEGIN
		IF @ExcludeIdentityColumn = 0 --Determing whether to include or exclude the IDENTITY column
			SET @vIdentityNames = @vColumnName
		ELSE
			GOTO SKIP_LOOP
		END

		--Making sure whether to output computed columns or not
		IF @ExcludeComputedColumns = 1
		AND (SELECT COLUMNPROPERTY(OBJECT_ID(QUOTENAME(COALESCE(@TableSchema, User_Name())) + '.' + @TableName), SUBSTRING(@vColumnName, 2, LEN(@vColumnName) - 2), 'IsComputed')) = 1
		BEGIN
			GOTO SKIP_LOOP
		END

		--PK column lists              
		IF EXISTS (	SELECT	TOP 1 1
					FROM	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CCU
					JOIN	INFORMATION_SCHEMA.TABLE_CONSTRAINTS C
						ON	C.CONSTRAINT_NAME = CCU.CONSTRAINT_NAME
					WHERE	C.CONSTRAINT_TYPE = 'PRIMARY KEY'
						AND C.CONSTRAINT_SCHEMA = COALESCE(@TableSchema, User_Name())
						AND CCU.TABLE_NAME = @TableName
						AND '[' + COLUMN_NAME + ']' = @vColumnName)
		OR EXISTS (SELECT TOP 1 1 FROM STRING_SPLIT(@PrimaryColumns, ',') WHERE value = @vColumnName)
		BEGIN
			INSERT @vPrimaryKeyList (Name) VALUES ( @vColumnName )
		END
		
		--Generating the column value for the INSERT statement
		SET @vValueList += 
			CASE
				WHEN @vCharacterSetName = 'UNICODE' 
					THEN 'COALESCE(''N'''''' + REPLACE(RTRIM(' + @vColumnName + '),'''''''','''''''''''')+'''''''',''NULL'')'
				WHEN @vDataType LIKE '%char' 
					THEN 'COALESCE('''''''' + REPLACE(RTRIM(' + @vColumnName + '),'''''''','''''''''''')+'''''''',''NULL'')'
				WHEN @vDataType LIKE '%date%' 
					THEN 'COALESCE('''''''' + RTRIM(CONVERT(varchar,' + @vColumnName + ',109))+'''''''',''NULL'')'
				WHEN @vDataType IN ( 'uniqueidentifier' ) 
					THEN 'COALESCE('''''''' + REPLACE(CONVERT(nvarchar(max),RTRIM(' + @vColumnName + ')),'''''''','''''''''''')+'''''''',''NULL'')'
				WHEN @vDataType LIKE '%text'
					THEN 'COALESCE('''''''' + REPLACE(CONVERT(nvarchar(max),' + @vColumnName + '),'''''''','''''''''''')+'''''''',''NULL'')'
				WHEN @vDataType LIKE'%binary'
					THEN 'CONVERT(nvarchar(max),0x0,1)'
				WHEN @vDataType IN ( 'image' ) 
					THEN 'CASE WHEN ' + @vColumnName + ' IS NULL THEN ''NULL'' ELSE ''0x0'' END'
				WHEN @vDataType IN ( 'float', 'real', 'money', 'smallmoney' ) 
					THEN 'COALESCE(TRIM(RTRIM(' + 'CONVERT(char, ' + @vColumnName + ',2)' + ')),''NULL'')'
				ELSE 'COALESCE(TRIM(RTRIM(' + 'CONVERT(nvarchar(max), ' + @vColumnName + ')' + ')),''NULL'')'
			END + '+'',''+'

		--Generating the column name list for the INSERT statement
		SET @vColumnList += @vColumnName + ','

		SKIP_LOOP: --The label used in GOTO

		SELECT	@vColumnId = MIN(ORDINAL_POSITION)
		FROM	INFORMATION_SCHEMA.COLUMNS (NOLOCK)
		WHERE	TABLE_NAME = @TableName
			AND ORDINAL_POSITION > @vColumnId
			AND (@TableSchema IS NULL OR TABLE_SCHEMA = @TableSchema)
	END

	--To get rid of the extra characters that got concatenated during the last run through the loop
	SET @vColumnList = LEFT(@vColumnList, LEN(@vColumnList) - 1)
	SET @vValueList = LEFT(@vValueList, LEN(@vValueList) - 5)

	IF TRIM(@vColumnList) = ''
	BEGIN
		RAISERROR('No columns to select. There should at least be one column to generate the output',16,1)
		RETURN -1
	END

	--Forming the final string that will be executed, to output the INSERT statements
	IF @IncludeColumnList <> 0
	BEGIN
		--Format:
		--IF NOT EXISTS (SELECT TOP 1 1 FROM Table WHERE ?) INSERT INTO Table (column1,column2,column3) VALUES (value1,value2,value3)
		IF (SELECT Count(*) FROM @vPrimaryKeyList) > 0
		BEGIN
			SET @vValueListTemp = 'IF NOT EXISTS (SELECT TOP 1 1 FROM ' + COALESCE('[' + TRIM(TRIM(@TableSchema)) + '].','') + '[' + TRIM(@TableName) + '] WHERE ';
			
			SET @vPrimaryKeys = ''
			;WITH CTE AS 
			(
				SELECT	Row_Number() OVER (ORDER BY Name) AS Counter,
						Name
				FROM	@vPrimaryKeyList
			)
			SELECT		@vPrimaryKeys += (CASE WHEN CTE.Counter <> 1 THEN ' AND ' ELSE '' END) + CTE.Name  + ' = '''''' + CAST(' + CTE.Name + ' AS NVARCHAR(MAX)) + '''''''
			FROM		CTE
			ORDER BY	Counter

			SELECT @vValueListTemp += @vPrimaryKeys + ') '
		END

		SET @vValueList	= 'SELECT ' + (CASE WHEN @Top IS NULL OR @Top < 0 THEN '' ELSE ' TOP ' + TRIM(STR(@Top)) + ' ' END) + '''' 
									+ COALESCE(@vValueListTemp,'')
									+ TRIM(@vStartInsert) + ' ''+' + '''(' + TRIM(@vColumnList) + '''+' + ''')''' + ' +''VALUES(''+ ' + @vValueList + '+'')''' + ' ' 
						+ ' FROM ' + COALESCE('[' + TRIM(TRIM(@TableSchema)) + '].','') + '[' + TRIM(@TableName) + ']' + '(NOLOCK)' 
						+ COALESCE(' WHERE ' + @Where, '')

		--SET @vValueListBlank = COALESCE(@vValueListTemp,'') + TRIM(@vStartInsert) + ' ''+' + '''(' + TRIM(@vColumnList) + '''+' + ''')''' + ' +''VALUES(''+ ' + @vValueList + '+'')''' + ' ' 
	END
	ELSE IF @IncludeColumnList = 0
	BEGIN
		--Format:
		--INSERT INTO Table VALUES(value1,value2,value3)
		SET @vValueList = 'SELECT ' + (CASE WHEN @Top IS NULL OR @Top < 0 THEN '' ELSE ' TOP ' + TRIM(STR(@Top)) + ' ' END) + ''''	
									+ TRIM(@vStartInsert) + ' '' +''VALUES(''+ ' + @vValueList + '+'')''' + ' ' 
						+ ' FROM ' + COALESCE('[' + TRIM(TRIM(@TableSchema)) + '].','') + '[' + TRIM(@TableName) + ']' + '(NOLOCK)' 
						+ COALESCE(' WHERE ' + @Where, '')

		--SET @vValueListBlank = TRIM(@vStartInsert) + ' ''+' + ' +''VALUES(''+ ' + @vValueList + '+'')''' + ' ' 
	END


	--RESULT HERE
	EXEC (@vValueList)
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT '-- Nothing for ' + @TableName, @vValueListBlank
	END

	RETURN
END
GO

/*
	EXEC dbo.GetInsert @TableName = 'Your_Table_Name'
*/