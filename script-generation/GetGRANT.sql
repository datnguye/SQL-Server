DROP PROCEDURE IF EXISTS GetGRANT
GO
--======================================================================================================
-- Usage: GetGRANT
-- Dependencies:	
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-10-15	DN			Intial
--=======================================================================================================
CREATE PROCEDURE GetGRANT	@To sysname,
							@Schema sysname = 'dbo',
							@Grants varchar(255) = 'SELECT,INSERT,UPDATE,DELETE,EXECUTE',
							@ObjectPattern varchar(255) = '%'
AS
BEGIN
	SET NOCOUNT ON;

	--Stored Procedure
	SELECT	sp.object_id AS [ObjectId],
			sp.name AS [Name],
			SCHEMA_NAME(sp.schema_id) AS [Schema],
			db_name() as [DatabaseName],
			'Stored Procedure' as ObjType,
			FORMATMESSAGE('GRANT EXECUTE ON [%s].[%s] TO [%s]', SCHEMA_NAME(sp.schema_id), sp.name, @To) as GRANTScript
	FROM	sys.all_objects AS sp
	WHERE	(sp.type = 'P' OR sp.type = 'RF' OR sp.type='PC')
		AND	SCHEMA_NAME(sp.schema_id) = @Schema
		AND sp.name  NOT IN ('GetGRANT')
		AND PATINDEX('%EXECUTE%',@Grants) > 0
		AND PATINDEX(@ObjectPattern,sp.name) > 0
	UNION ALL

	--Function
	SELECT	udf.object_id AS [ID],
			udf.name AS [Name],
			SCHEMA_NAME(udf.schema_id) AS [Schema],
			db_name() as [DatabaseName],
			'Scalar Function' as ObjType,
			FORMATMESSAGE('GRANT EXECUTE ON [%s].[%s] TO [%s]', SCHEMA_NAME(udf.schema_id), udf.name, @To) as GRANTScript
	FROM	sys.all_objects AS udf
	WHERE	udf.type in ('FN', 'IF', 'FS')
		AND	SCHEMA_NAME(udf.schema_id) = @Schema
		AND PATINDEX('%EXECUTE%',@Grants) > 0
		AND PATINDEX(@ObjectPattern,udf.name) > 0
	UNION ALL
	--Function (Table)
	SELECT	udf.object_id AS [ID],
			udf.name AS [Name],
			SCHEMA_NAME(udf.schema_id) AS [Schema],
			db_name() as [DatabaseName],
			'Table Function' as ObjType,
			FORMATMESSAGE('GRANT SELECT ON [%s].[%s] TO [%s]', SCHEMA_NAME(udf.schema_id), udf.name, @To) as GRANTScript
	FROM	sys.all_objects AS udf
	WHERE	udf.type in ('TF', 'FT')
		AND	SCHEMA_NAME(udf.schema_id) = @Schema
		AND PATINDEX('%SELECT%',@Grants) > 0
		AND PATINDEX(@ObjectPattern,udf.name) > 0
	UNION ALL

	--Table
	SELECT	tbl.object_id AS [ID],
			tbl.name AS [Name],
			SCHEMA_NAME(tbl.schema_id) AS [Schema],
			db_name() as [DatabaseName],
			'Table' as ObjType,
			FORMATMESSAGE('GRANT %s ON [%s].[%s] TO [%s]', REPLACE(REPLACE(@Grants,'EXECUTE,',''),',EXECUTE',''), SCHEMA_NAME(tbl.schema_id), tbl.name, @To) as GRANTScript
	FROM	sys.tables AS tbl
	WHERE	SCHEMA_NAME(tbl.schema_id) = @Schema
		AND (
				PATINDEX('%SELECT%',@Grants) > 0
				OR PATINDEX('%INSERT%',@Grants) > 0
				OR PATINDEX('%UPDATE%',@Grants) > 0
				OR PATINDEX('%DELETE%',@Grants) > 0
			)
		AND PATINDEX(@ObjectPattern,tbl.name) > 0
	UNION ALL

	--View
	SELECT	v.object_id AS [ID],
			v.name AS [Name],
			SCHEMA_NAME(v.schema_id) AS [Schema],
			db_name() as [DatabaseName],
			'View' as ObjType,
			FORMATMESSAGE('GRANT SELECT ON [%s].[%s] TO [%s]', SCHEMA_NAME(v.schema_id), v.name, @To) as GRANTScript
	FROM	sys.all_views AS v
	WHERE	v.type = 'V'
		AND	SCHEMA_NAME(v.schema_id) = @Schema
		AND PATINDEX('%SELECT%',@Grants) > 0
		AND PATINDEX(@ObjectPattern,v.name) > 0

	RETURN
END

/*
	EXEC GetGRANT @To = 'user123', @Grants='SELECT,INSERT,UPDATE,DELETE,EXECUTE'
*/
