--=============================================================================================================================================
-- Usage: This is to perform INDEXES REBUILD/REORGANIZE for current database
-- Notes: 
-- History:
-- Date			By			Description
-- 2020-11-05	DN			Created.
--=============================================================================================================================================
DROP PROCEDURE IF EXISTS dbo.MaintenanceRebuildIndexes  
GO
CREATE PROCEDURE [dbo].[MaintenanceRebuildIndexes] @Debug BIT = 1
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vMessage nvarchar(4000)
	DECLARE @vSQL nvarchar(MAX) = ''

	SET @vMessage = CONVERT(nvarchar,GETDATE(),21) + ' - ' + 'Starting REBUILD\REORGANIZE indexes - @Database = ' + DB_NAME()
	IF @Debug = 1 RAISERROR(@vMessage,0,1)

	SET @vMessage = CONVERT(nvarchar,GETDATE(),21) + ' - ' + '	Processing '+QUOTENAME(DB_NAME())+' - Rowstore indexes'
	IF @Debug = 1 RAISERROR(@vMessage,0,1)

	;WITH CTE AS
	(
		SELECT	object_name(a.object_id) AS TableName, 
				schema_name(o.schema_id) AS SchemaName, 
				b.name AS IndexName, 
				a.avg_fragmentation_in_percent as FragPercent,
				CASE
					WHEN a.avg_fragmentation_in_percent > 5 AND a.avg_fragmentation_in_percent <= 30 
						THEN FORMATMESSAGE('ALTER INDEX %s ON [%s].[%s] REORGANIZE;', b.name, SCHEMA_NAME(o.schema_id), OBJECT_NAME(a.object_id))
					WHEN a.avg_fragmentation_in_percent > 30 
						THEN FORMATMESSAGE('ALTER INDEX %s ON [%s].[%s] REBUILD;', b.name, SCHEMA_NAME(o.schema_id), OBJECT_NAME(a.object_id))
					ELSE ''
				END as Script
		FROM	sys.dm_db_index_physical_stats (DB_ID (DB_NAME()), NULL, NULL, NULL, NULL) AS a
		JOIN	sys.objects o 
			ON	o.object_id = a.object_id
		JOIN	sys.indexes AS b
			ON	a.object_id = b.object_id
			AND a.index_id = b.index_id
		WHERE	b.index_id > 0
	)
	SELECT	@vSQL += CHAR(13)+CHAR(10) + Script 
	FROM	CTE 
	WHERE	Script <> ''
	

	SET @vMessage = CONVERT(nvarchar,GETDATE(),21) + ' - ' + '	Processing '+QUOTENAME(DB_NAME())+' - Columnstore indexes'
	IF @Debug = 1 RAISERROR(@vMessage,0,1)
	;WITH CTE AS 
	(
		SELECT  object_name(i.object_id) AS TableName,
				schema_name(o.schema_id) AS SchemaName,
				i.name AS IndexName,
				100*(ISNULL(SUM(CSRowGroups.deleted_rows),0))/NULLIF(SUM(CSRowGroups.total_rows),0) AS FragPercent
		FROM	sys.indexes AS i  
		JOIN	sys.objects o 
			ON	o.object_id = i.object_id
		JOIN	sys.dm_db_column_store_row_group_physical_stats AS CSRowGroups
			ON	i.object_id = CSRowGroups.object_id
			AND i.index_id = CSRowGroups.index_id
		GROUP BY o.schema_id, i.object_id, i.index_id, i.name
	)
	SELECT	@vSQL += CHAR(13)+CHAR(10) + FORMATMESSAGE('ALTER INDEX %s ON [%s].[%s] REORGANIZE;', CTE.IndexName, CTE.SchemaName, CTE.TableName) 
	FROM	CTE 
	WHERE	FragPercent >= 20

	IF @Debug = 1 PRINT @vSQL
	EXEC sp_executesql @vSQL
	
	SET @vMessage = CONVERT(nvarchar,GETDATE(),21) + ' - ' + 'Finished'
	IF @Debug = 1 RAISERROR(@vMessage,0,1)

	RETURN
END
GO
/*
	EXEC MaintenanceRebuildIndexes @Debug=1
*/

