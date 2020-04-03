IF OBJECT_ID('tempdb.dbo.#tempIndexesUsages','U') IS NOT NULL
	DROP TABLE #tempIndexesUsages
GO
IF OBJECT_ID('tempdb.dbo.#tempIndexesColumns','U') IS NOT NULL
	DROP TABLE #tempIndexesColumns
GO

SET NOCOUNT ON;

DECLARE @NoOfDaySinceRestart BIGINT
SELECT @NoOfDaySinceRestart = DATEDIFF(DAY, sqlserver_start_time, GETDATE()) FROM sys.dm_os_sys_info

CREATE TABLE #tempIndexesUsages
(
	DBName sysname,
	TableName sysname,
	IndexName sysname,
	IndexType sysname,
	IndexSizeKB BIGINT,
	NumOfSeeks BIGINT,
	NumOfScans BIGINT,
	NumOfLookups BIGINT,
	NumOfUpdates BIGINT,
	NumOfSeeksAvgPerDay DECIMAL(38,4),
	NumOfScansAvgPerDay DECIMAL(38,4),
	NumOfLookupsAvgPerDay DECIMAL(38,4),
	NumOfUpdatesAvgPerDay DECIMAL(38,4),
)
CREATE TABLE #tempIndexesColumns
(
	DBName sysname,
	TableName sysname,
	IndexName sysname,
	IndexType sysname,
	ColumnName sysname,
	IsInInclude sysname
)

EXEC master..DbExec '
INSERT
INTO	#tempIndexesColumns
SELECT	DB_NAME(),
		TableName = t.name,
		IndexName = ind.name,
		IndexType = ind.type_desc,
		ColumnName = UPPER(col.name),
		IsInInclude = ic.is_included_column
FROM	sys.indexes ind 
JOIN	sys.index_columns ic
	ON  ind.object_id = ic.object_id
	AND	ind.index_id = ic.index_id 
JOIN	sys.columns col
	ON	ic.object_id = col.object_id
	AND ic.column_id = col.column_id 
JOIN	sys.tables t
	ON	ind.object_id = t.object_id 
WHERE	t.is_ms_shipped = 0
'
EXEC master..DbExec '
INSERT
INTO	#tempIndexesUsages (DBName,TableName,IndexName,IndexType,
			IndexSizeKB,NumOfSeeks,NumOfScans,NumOfLookups,NumOfUpdates)
SELECT	DB_NAME(IXUS.database_id) as DBName,
		OBJECT_NAME(IX.OBJECT_ID) Table_Name,
		IX.name AS Index_Name,
		IX.type_desc Index_Type,
		SUM(PS.[used_page_count]) * 8 IndexSizeKB,
		IXUS.user_seeks AS NumOfSeeks,
		IXUS.user_scans AS NumOfScans,
		IXUS.user_lookups AS NumOfLookups,
		IXUS.user_updates AS NumOfUpdates
FROM	sys.indexes IX
JOIN	sys.dm_db_index_usage_stats IXUS
	ON	IXUS.index_id = IX.index_id
	AND IXUS.OBJECT_ID = IX.OBJECT_ID
JOIN	sys.dm_db_partition_stats PS
	ON	PS.index_id = IX.index_id
	AND PS.object_id=IX.object_id
WHERE	DB_ID(DB_NAME()) = IXUS.database_id
	AND OBJECTPROPERTY(IX.OBJECT_ID,''IsUserTable'') = 1
	AND IX.type_desc <> ''HEAP''
GROUP BY DB_NAME(IXUS.database_id),
		OBJECT_NAME(IX.OBJECT_ID),
		IX.name ,IX.type_desc,
		IXUS.user_seeks ,IXUS.user_scans ,IXUS.user_lookups,IXUS.user_updates
'
UPDATE	#tempIndexesUsages 
SET		NumOfSeeksAvgPerDay = NumOfSeeks / @NoOfDaySinceRestart,
		NumOfScansAvgPerDay = NumOfScans / @NoOfDaySinceRestart,
		NumOfLookupsAvgPerDay = NumOfLookups / @NoOfDaySinceRestart,
		NumOfUpdatesAvgPerDay = NumOfUpdates / @NoOfDaySinceRestart

SELECT	'All Data', *
FROM	#tempIndexesUsages

--1
SELECT	'Review to remove/or not' as Item,* 
FROM	#tempIndexesUsages
WHERE	NumOfLookups = 0
	AND NumOfScans = 0
	AND NumOfSeeks = 0
	AND NumOfUpdates > 1000
	AND IndexType = 'NONCLUSTERED'

--2
IF OBJECT_ID('tempdb.dbo.#tempIndexesColumnsC','U') IS NOT NULL
	DROP TABLE #tempIndexesColumnsC
GO
SELECT	DISTINCT
		DBName,
		TableName,
		IndexName,
		IndexType,
		STUFF(
			(
				SELECT		',' + B.ColumnName
				FROM		#tempIndexesColumns B
				WHERE		B.DBName = A.DBName
					AND		B.TableName = A.TableName
					AND		B.IndexName = A.IndexName
					AND		B.IndexType = A.IndexType
					AND		B.IsInInclude = 0
				ORDER BY	B.ColumnName
				FOR XML PATH('')
            ), 1, 1, ''
		) as ColumnNames,
		STUFF(
			(
				SELECT		',' + B.ColumnName
				FROM		#tempIndexesColumns B
				WHERE		B.DBName = A.DBName
					AND		B.TableName = A.TableName
					AND		B.IndexName = A.IndexName
					AND		B.IndexType = A.IndexType
					AND		B.IsInInclude = 1
				ORDER BY	B.ColumnName
				FOR XML PATH('')
            ), 1, 1, ''
		) as IncludedColumnNames
INTO	#tempIndexesColumnsC
FROM	#tempIndexesColumns A

SElECT	'Review to de-dup indexes' as Item, A.*, C.*
FROM	#tempIndexesColumnsC A
JOIN	#tempIndexesColumnsC B
	ON	B.DBName = A.DBName
	AND B.TableName = A.TableName
	AND B.ColumnNames = A.ColumnNames
	AND B.IncludedColumnNames = A.IncludedColumnNames
	AND B.IndexName <> A.IndexName
JOIN	#tempIndexesUsages C
	ON	C.DBName = A.DBName
	AND C.TableName = A.TableName
	AND C.IndexName = A.IndexName
	AND C.IndexType = A.IndexType
ORDER BY A.DBName,A.TableName,A.IndexName