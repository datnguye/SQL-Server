--======================================================
-- Usage: GetDFColumns - to get list of Primary Key columns
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-06-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS GetDFColumns
GO
CREATE FUNCTION GetDFColumns 
(
	@Schema sysname = 'dbo',
	@Table sysname
)
RETURNS  @Result TABLE 
(
	TableSchema sysname, 
	TableName sysname, 
	ColumnName sysname, 
	ConstraintName sysname
)
AS
BEGIN
	INSERT 
	INTO		@Result
	SELECT		schemas.name as TABLE_SCHEMA,
				tables.name as TABLE_NAME,
				all_columns.name as COLUMN_NAME,
				default_constraints.name as CONSTRAINT_NAME
	FROM		sys.all_columns
	JOIN		sys.tables
        ON		all_columns.object_id = tables.object_id
	JOIN		sys.schemas
        ON		tables.schema_id = schemas.schema_id
	JOIN		sys.default_constraints
        ON		all_columns.default_object_id = default_constraints.object_id
	WHERE		schemas.name = @Schema
		AND		tables.name = @Table

	RETURN
END

/*
SELECT * FROM dbo.GetDFColumns(default, 'Tenant')
SELECT * FROM dbo.GetDFColumns(default, 'Tenant-NOT_EXISTS')
*/