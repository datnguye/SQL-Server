--======================================================
-- Usage: GetPKColumns - to get list of Primary Key columns
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-06-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS GetPKColumns
GO
CREATE FUNCTION GetPKColumns 
(
	@Schema sysname = 'dbo',
	@Table sysname
)
RETURNS  @Result TABLE 
(
	TableSchema sysname, 
	TableName sysname, 
	ColumnName sysname, 
	ColumnOrder Int
)
AS
BEGIN
	INSERT 
	INTO		@Result
	SELECT		T.TABLE_SCHEMA,
				T.TABLE_NAME,
				C.COLUMN_NAME,
				ROW_NUMBER() OVER(ORDER BY C.ORDINAL_POSITION) AS COLUMN_ORDER
	FROM		INFORMATION_SCHEMA.TABLE_CONSTRAINTS T
	JOIN		INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CU
		ON		CU.Constraint_Name = T.Constraint_Name
		AND		CU.Table_Name = T.Table_Name
	JOIN		INFORMATION_SCHEMA.COLUMNS C
		ON		C.TABLE_SCHEMA = T.TABLE_SCHEMA
		AND		C.TABLE_NAME = T.TABLE_NAME
		AND		C.COLUMN_NAME = CU.COLUMN_NAME
	WHERE		T.CONSTRAINT_TYPE = 'PRIMARY KEY'
		AND		T.TABLE_SCHEMA = @Schema
		AND		T.TABLE_NAME = @Table
	ORDER BY	4

	RETURN
END

/*
SELECT * FROM dbo.GetPKColumns(default, 'CommandLog')
SELECT * FROM dbo.GetPKColumns(default, 'CommandLog-NOT_EXISTS')
*/