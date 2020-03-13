--======================================================
-- Usage: GetTableSize
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-23	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetTableSize
GO
CREATE PROCEDURE [dbo].[GetTableSize] @TableNamePattern varchar(256) = NULL
AS
BEGIN
	SET NOCOUNT ON

	SELECT		t.name AS TableName,
				p.rows AS [Rows],
				(SUM(a.total_pages) * 8) AS SizeInBytes,
				CAST(((SUM(a.total_pages) * 8) / CAST(1024 AS DECIMAL)) AS NUMERIC(36, 2)) AS SizeInMegaBytes,
				CAST(((SUM(a.total_pages) * 8) / CAST(1024 AS DECIMAL) / CAST(1024 AS DECIMAL)) AS NUMERIC(36, 5)) AS SizeInGigaBytes
	FROM		sys.tables t WITH (NOLOCK)
	JOIN		sys.indexes i WITH (NOLOCK)
		ON		t.OBJECT_ID = i.OBJECT_ID
	JOIN		sys.partitions p WITH (NOLOCK)
		ON		i.object_id = p.OBJECT_ID
		AND		i.index_id = p.index_id
	JOIN		sys.allocation_units a WITH (NOLOCK)
		ON		p.partition_id = a.container_id
	WHERE		t.name LIKE @TableNamePattern ESCAPE '\'
		AND		t.is_ms_shipped = 0
		AND		a.total_pages > 0
	GROUP BY	t.name,
				p.rows
	ORDER BY	3 DESC
	
	RETURN
END
GO
/*
	EXEC GetTableSize '%' --get size of all tables
	EXEC GetTableSize @TableNamePattern = 'User%' --get size of tables prefixed by 'User'
	EXEC GetTableSize @TableNamePattern = '\_%' --get size of tables prefixed by '_'
*/
