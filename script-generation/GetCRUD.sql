--==================================================================
-- Usage: GetCRUD - to get script for SELECT/INSERT/UPDATE/DELETE
-- Dependencies:	Table function dbo.GetPKColumns
--					Scarlar function dbo.IsIdentityColumn
-- Notes:			Since SQL Server 2016+
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-06-24	DN			Intial
--==================================================================
/* 
--------------------------------------------------------------------------------
						Supported table designs
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS Base01 
GO
DROP TABLE IF EXISTS Base02
GO
DROP TABLE IF EXISTS Base03
GO
CREATE TABLE Base01
(
	Id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_Base01 PRIMARY KEY,
	IsActive BIT NOT NULL CONSTRAINT DF_Base01_IsActive DEFAULT(1),
	--Some columns here--
	CreateBy NVARCHAR(256) NOT NULL,
	CreateAt DATETIME NOT NULL CONSTRAINT DF_Base01_CreateAt DEFAULT(GETDATE()),
	UpdateBy NVARCHAR(256) NOT NULL,
	UpdateAt DATETIME NOT NULL CONSTRAINT DF_Base01_UpdateAt DEFAULT(GETDATE())
)
GO
CREATE TABLE Base02
(
	Code INT NOT NULL CONSTRAINT PK_Base02 PRIMARY KEY,
	IsActive BIT NOT NULL CONSTRAINT DF_Base02_IsActive DEFAULT(1),
	--Some columns here--
	CreateBy NVARCHAR(256) NOT NULL,
	CreateAt DATETIME NOT NULL CONSTRAINT DF_Base02_CreateAt DEFAULT(GETDATE()),
	UpdateBy NVARCHAR(256) NOT NULL,
	UpdateAt DATETIME NOT NULL CONSTRAINT DF_Base02_UpdateAt DEFAULT(GETDATE())
)
GO
CREATE TABLE Base03
(
	Code1 INT NOT NULL,
	Code2 INT NOT NULL,
	IsActive BIT NOT NULL CONSTRAINT DF_Base03_IsActive DEFAULT(1),
	--Some columns here--
	CreateBy NVARCHAR(256) NOT NULL,
	CreateAt DATETIME NOT NULL CONSTRAINT DF_Base03_CreateAt DEFAULT(GETDATE()),
	UpdateBy NVARCHAR(256) NOT NULL,
	UpdateAt DATETIME NOT NULL CONSTRAINT DF_Base03_UpdateAt DEFAULT(GETDATE()),
	CONSTRAINT PK_Base03 PRIMARY KEY (Code1, Code2)
)
GO
*/
DROP PROCEDURE IF EXISTS GetCRUD
GO
CREATE PROCEDURE GetCRUD	@Schema sysname = 'dbo',
							@Table sysname,
							@ExportTo nvarchar(256) = NULL--'C:\Temp\'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @vExportFullPath nvarchar(256)
	--
	DECLARE @tResult TABLE
	(
		TABLE_SELECT varchar(max), 
		TABLE_INSERT varchar(max), 
		TABLE_UPDATE varchar(max), 
		TABLE_DELETE varchar(max)
	)
	--	
	DECLARE @SelectTemplate varchar(4000) = 'DROP PROCEDURE IF EXISTS {table}_SELECT{endline}GO{endline}CREATE PROCEDURE {table}_SELECT {param_pk_columns_with_data_type}{endline}AS{endline}BEGIN{endline}{tab}SELECT{tab}{columns}{endline}{tab}FROM{tab}{table}{endline}{tab}WHERE{tab}{pk_columns_equal_param_pk_columns}{endline}END{endline}GO{endline}'
	DECLARE @InsertTemplate varchar(4000) = 'DROP PROCEDURE IF EXISTS {table}_INSERT{endline}GO{endline}CREATE PROCEDURE {table}_INSERT {param_non_identity_columns_with_data_type}, @CreateBy NVARCHAR(256){endline}AS{endline}BEGIN{endline}{tab}INSERT{endline}{tab}INTO{tab}{table}{endline}{tab}({endline}{tab}{tab}{non_identity_columns},{endline}{tab}{tab}CREATE_BY,{endline}{tab}{tab}UPDATE_BY{endline}{tab}){endline}{tab}VALUES{endline}{tab}({endline}{tab}{tab}{param_non_identity_columns},{endline}{tab}{tab}@CreateBy,{endline}{tab}{tab}@CreateBy{endline}{tab}){endline}{tab}{endline}{tab}{scope_identity}{endline}END{endline}GO{endline}'
	DECLARE @UpdateTemplate varchar(4000) = 'DROP PROCEDURE IF EXISTS {table}_UPDATE{endline}GO{endline}CREATE PROCEDURE {table}_UPDATE{tab}{param_columns_with_data_type}, @UpdateBy NVARCHAR(256){endline}AS{endline}BEGIN{endline}{tab}UPDATE{tab}{table}{endline}{tab}SET {tab}{columns_equal_param_columns},{endline}{tab}{tab}{tab}UPDATE_BY = @UpdateBy,{endline}{tab}{tab}{tab}UPDATE_DATE = GETDATE(){endline}{tab}WHERE{tab}{pk_columns_equal_param_pk_columns}{endline}END{endline}GO{endline}'
	DECLARE @DeleteTemplate varchar(4000) = 'DROP PROCEDURE IF EXISTS {table}_DELETE{endline}GO{endline}CREATE PROCEDURE {table}_DELETE{tab}{param_pk_columns_with_data_type}, @DeleteBy NVARCHAR(256){endline}AS{endline}BEGIN{endline}{tab}UPDATE{tab}{table}{endline}{tab}SET {tab}IS_ACTIVE = 0,{endline}{tab}{tab}{tab}UPDATE_BY = @DeleteBy{endline}{tab}{tab}{tab}UPDATE_DATE = GETDATE(){endline}{tab}WHERE{tab}{pk_columns_equal_param_pk_columns}{endline}END{endline}GO{endline}'

	SET @SelectTemplate = REPLACE(REPLACE(REPLACE(@SelectTemplate,'{table}',@Table),'{endline}',char(10)),'{tab}',char(9))
	/*
		DROP PROCEDURE IF EXISTS YOUR_TABLE_SELECT
		GO
		CREATE PROCEDURE YOUR_TABLE_SELECT {param_pk_columns_with_data_type}
		AS
		BEGIN
			SELECT	{columns}
			FROM	YOUR_TABLE
			WHERE	{pk_columns_equal_param_pk_columns}
		END
		GO
	*/
	SET @InsertTemplate = REPLACE(REPLACE(REPLACE(@InsertTemplate,'{table}',@Table),'{endline}',char(10)),'{tab}',char(9))
	/*
		DROP PROCEDURE IF EXISTS YOUR_TABLE_INSERT
		GO
		CREATE PROCEDURE YOUR_TABLE_INSERT {param_non_identity_columns_with_data_type}, @CreateBy NVARCHAR(256)
		AS
		BEGIN
			INSERT
			INTO	YOUR_TABLE
			(
				{non_identity_columns},
				CREATE_BY,
				UPDATE_BY
			)
			VALUES
			(
				{param_non_identity_columns},
				CREATE_BY = @CreateBy,
				UPDATE_BY = @CreateBy
			)
		END
		GO
	*/
	SET @UpdateTemplate = REPLACE(REPLACE(REPLACE(@UpdateTemplate,'{table}',@Table),'{endline}',char(10)),'{tab}',char(9))
	/*
		DROP PROCEDURE IF EXISTS YOUR_TABLE_UPDATE
		GO
		CREATE PROCEDURE YOUR_TABLE_UPDATE	{param_columns_with_data_type}, @UpdateBy NVARCHAR(256)
		AS
		BEGIN
			UPDATE	YOUR_TABLE
			SET 	{columns_equal_param_columns},
					UPDATE_BY = @UpdateBy,
					UPDATE_DATE = GETDATE()
			WHERE	{pk_columns_equal_param_pk_columns}
		END
		GO
	*/
	SET @DeleteTemplate = REPLACE(REPLACE(REPLACE(@DeleteTemplate,'{table}',@Table),'{endline}',char(10)),'{tab}',char(9))
	/*
		DROP PROCEDURE IF EXISTS YOUR_TABLE_DELETE
		GO
		CREATE PROCEDURE YOUR_TABLE_DELETE	{param_pk_columns_with_data_type}, @DeleteBy NVARCHAR(256)
		AS
		BEGIN
			UPDATE	YOUR_TABLE
			SET 	IS_ACTIVE = 0,
					UPDATE_BY = @DeleteBy
					UPDATE_DATE = GETDATE()
			WHERE	{pk_columns_equal_param_pk_columns}
		END
		GO

	*/


	/*
		Select column informations
	*/
	DROP TABLE IF EXISTS #tColumns;
	SELECT		C.TABLE_SCHEMA,
				C.TABLE_NAME,
				C.COLUMN_NAME,
				CASE
					WHEN C.DATA_TYPE LIKE '%char' THEN C.DATA_TYPE+'('+COALESCE(CONVERT(varchar,NULLIF(CHARACTER_MAXIMUM_LENGTH,-1)),'MAX')+')'
					WHEN C.DATA_TYPE LIKE '%decimal%' OR C.DATA_TYPE LIKE '%numeric%' THEN C.DATA_TYPE+'('+CONVERT(varchar,NUMERIC_PRECISION)+','+CONVERT(varchar,NUMERIC_SCALE)+')'
					ELSE C.DATA_TYPE
				END as DATA_TYPE,
				C.ORDINAL_POSITION,
				dbo.IsIdentityColumn(@Schema,@Table,C.COLUMN_NAME) AS IS_IDENTITY,
				CASE WHEN PC.ColumnName IS NULL THEN 0 ELSE 1 END IS_IN_PK,
				PC.ColumnOrder AS PK_ORDINAL_POSITION
	INTO		#tColumns
	FROM		INFORMATION_SCHEMA.COLUMNS C
	LEFT JOIN	dbo.GetPKColumns(@Schema,@Table) PC 
		ON		PC.TableSchema = C.TABLE_SCHEMA
		AND		PC.TableName = C.TABLE_NAME
		AND		PC.ColumnName = C.COLUMN_NAME
	WHERE		C.TABLE_SCHEMA = @Schema
		AND		C.TABLE_NAME = @Table
	PRINT 'Insert into #tColumns with @@ROWCOUNT = '+CONVERT(varchar,@@ROWCOUNT)

	/*
		Prepare statements
	*/
	DROP TABLE IF EXISTS #tStatements;
	SELECT		--Common usage
				'*' AS [columns],
				--SELECT,DELETE usage
				STRING_AGG(CASE WHEN IS_IN_PK = 1 THEN '@' + REPLACE(COLUMN_NAME,'_','') + ' ' + DATA_TYPE END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [param_pk_columns_with_data_type],
				--UPDATE,DELETE usage
				STRING_AGG(CASE WHEN IS_IN_PK = 1 THEN COLUMN_NAME + ' = @' + REPLACE(COLUMN_NAME,'_','') END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [pk_columns_equal_param_pk_columns],
				--SELECT usage
				STRING_AGG(CASE WHEN IS_IN_PK = 1 THEN COLUMN_NAME + ' = COALESCE(@' + REPLACE(COLUMN_NAME,'_','')+','+COLUMN_NAME+')' END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [pk_columns_equal_param_pk_columns_select],
				--INSERT usage
				STRING_AGG(CASE WHEN IS_IDENTITY = 0 THEN '@' + REPLACE(COLUMN_NAME,'_','') + ' ' + DATA_TYPE END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [param_non_identity_columns_with_data_type],
				STRING_AGG(CASE WHEN IS_IDENTITY = 0 THEN COLUMN_NAME END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [non_identity_columns],
				STRING_AGG(CASE WHEN IS_IDENTITY = 0 THEN '@' + REPLACE(COLUMN_NAME,'_','') END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [param_non_identity_columns],
				STRING_AGG(CASE WHEN IS_IDENTITY = 1 THEN 'SELECT SCOPE_IDENTITY()' END,';') WITHIN GROUP (ORDER BY ORDINAL_POSITION) as [scope_identity],
				--UPDATE usage
				STRING_AGG('@' + REPLACE(COLUMN_NAME,'_','') + ' ' + DATA_TYPE,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [param_columns_with_data_type],
				STRING_AGG(CASE WHEN IS_IN_PK = 0 THEN COLUMN_NAME + ' = @' + REPLACE(COLUMN_NAME,'_','') END,',') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS [columns_equal_param_columns]
	INTO		#tStatements
	FROM		#tColumns
	WHERE		COLUMN_NAME NOT IN ('CreateBy','CreateAt','UpdateBy','UpdateAt')
	GROUP BY	TABLE_SCHEMA, TABLE_NAME
	PRINT 'Insert into #tStatements with @@ROWCOUNT = '+CONVERT(varchar,@@ROWCOUNT)


	INSERT INTO @tResult VALUES (NULL,NULL,NULL,NULL)	
	/*
		SELECT
	*/
	UPDATE	@tResult
	SET		TABLE_SELECT = REPLACE(REPLACE(REPLACE(@SelectTemplate,
										'{param_pk_columns_with_data_type}',t.param_pk_columns_with_data_type),
										'{columns}',t.[columns]),
										'{pk_columns_equal_param_pk_columns}',t.pk_columns_equal_param_pk_columns_select)
	FROM	#tStatements t
	
	/*
		INSERT
	*/
	UPDATE	@tResult
	SET		TABLE_INSERT = REPLACE(REPLACE(REPLACE(REPLACE(@InsertTemplate,
										'{param_non_identity_columns_with_data_type}',t.param_non_identity_columns_with_data_type),
										'{non_identity_columns}',t.non_identity_columns),
										'{param_non_identity_columns}',t.param_non_identity_columns),
										'{scope_identity}',Coalesce([scope_identity],''))
	FROM	#tStatements t
	
	/*
		UPDATE
	*/
	UPDATE	@tResult
	SET		TABLE_UPDATE = REPLACE(REPLACE(REPLACE(@UpdateTemplate,
										'{param_columns_with_data_type}',t.param_columns_with_data_type),
										'{columns_equal_param_columns}',t.columns_equal_param_columns),
										'{pk_columns_equal_param_pk_columns}',t.pk_columns_equal_param_pk_columns)
	FROM	#tStatements t
	
	/*
		DELETE
	*/
	UPDATE	@tResult
	SET		TABLE_DELETE = REPLACE(REPLACE(@DeleteTemplate,
										'{param_pk_columns_with_data_type}',t.param_pk_columns_with_data_type),
										'{pk_columns_equal_param_pk_columns}',t.pk_columns_equal_param_pk_columns)
	FROM	#tStatements t
	
	/*
		EXPORT TO FILE
	*/
	IF @ExportTo IS NULL 
	BEGIN
		SELECT 'RESULT', * FROM @tResult
		SELECT '#DEBUG #tColumns', * FROM #tColumns
		SELECT '#DEBUG #tStatements', * FROM #tStatements
	END
	ELSE
	BEGIN
		SET @vExportFullPath = TRIM(@ExportTo) + CASE WHEN RIGHT(TRIM(@ExportTo),1) <> '\' THEN '\' ELSE '' END + @Table + '.sql'
		--TO BE CONTINUED...

		PRINT '(TO BE CONTINUED...)Exported to: '+@vExportFullPath
	END


	RETURN
END

/*
	EXEC GetCRUD @Table = 'Base01'
	EXEC GetCRUD @Table = 'Base02'
	EXEC GetCRUD @Table = 'Base03'
*/