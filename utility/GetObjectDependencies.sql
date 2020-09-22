--======================================================
-- Usage: GetObjectDependencies 
-- Notes: 
-- Parameters:
-- @FindRef defines ordering
--    1 order for drop
--    0 order for script
-- History:
-- Date			Author		Description
-- 2020-09-21	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [GetObjectDependencies]
GO
CREATE PROCEDURE [dbo].[GetObjectDependencies]	@ObjectName varchar(255), 
												@ObjectSchema varchar(255) = 'dbo', 
												@RefType INT = 1,
												@FindRef BIT = 0, 
												@FilterCurrentDBOnly BIT = 1
AS
BEGIN
	SET NOCOUNT ON

	DROP TABLE IF EXISTS #tObjectInfo
	CREATE TABLE #tObjectInfo (objid int NOT NULL, objname sysname NOT NULL, objschema sysname NULL, objdb sysname NOT NULL, objtype smallint NOT NULL)
	
	INSERT
	INTO	#tObjectInfo 
	SELECT	sp.object_id AS [ID],
			sp.name AS [Name],
			SCHEMA_NAME(sp.schema_id) AS [Schema],
			db_name(),
			4 as objtype
	FROM	sys.all_objects AS sp
	WHERE	(sp.type = 'P' OR sp.type = 'RF' OR sp.type='PC')
		AND	sp.name = @ObjectName 
		AND SCHEMA_NAME(sp.schema_id) = @ObjectSchema
		AND @RefType = 4 --Stored Procedure

	UNION ALL
	SELECT	udf.object_id AS [ID],
			udf.name AS [Name],
			SCHEMA_NAME(udf.schema_id) AS [Schema],
			db_name(),
			0 as objtype
	FROM	sys.all_objects AS udf
	WHERE	udf.type in ('TF', 'FN', 'IF', 'FS', 'FT')
		AND udf.name=@ObjectName 
		AND SCHEMA_NAME(udf.schema_id) = @ObjectSchema
		AND @RefType = 0 --Function

	UNION ALL
	SELECT	tbl.object_id AS [ID],
			tbl.name AS [Name],
			SCHEMA_NAME(tbl.schema_id) AS [Schema],
			db_name(),
			3 as objtype
	FROM	sys.tables AS tbl
	WHERE	tbl.name = @ObjectName 
		AND SCHEMA_NAME(tbl.schema_id) = @ObjectSchema
		AND @RefType = 3 --Table

	UNION ALL
	SELECT	v.object_id AS [ID],
			v.name AS [Name],
			SCHEMA_NAME(v.schema_id) AS [Schema],
			db_name(),
			2
	FROM	sys.all_views AS v
	WHERE	v.type = 'V'
		AND v.name = @ObjectName 
		AND SCHEMA_NAME(v.schema_id) = @ObjectSchema
		AND @RefType = 2 --View

	DECLARE @u int
	DECLARE @udf int
	DECLARE @v int
	DECLARE @sp int
	DECLARE @def int
	DECLARE @rule int
	DECLARE @tr int
	DECLARE @uda int
	DECLARE @uddt int
	DECLARE @xml int
	DECLARE @udt int
	DECLARE @assm int
	DECLARE @part_sch int
	DECLARE @part_func int
	DECLARE @synonym int
	DECLARE @sequence int
	DECLARE @udtt int
	DECLARE @ddltr int
	DECLARE @unknown int
	DECLARE @pg int

	SET @u = 3
	SET @udf = 0
	SET @v = 2
	SET @sp = 4
	SET @def = 6
	SET @rule = 7
	SET @tr = 8
	SET @uda = 11
	SET @synonym = 12
	SET @sequence = 13
	--above 100 -> not in sys.objects
	SET @uddt = 101
	SET @xml = 102
	SET @udt = 103
	SET @assm = 1000
	SET @part_sch = 201
	SET @part_func = 202
	SET @udtt = 104
	SET @ddltr = 203
	SET @unknown = 1001
	SET @pg = 204

	-- variables for referenced type obtained FROM sys.sql_expression_dependencies
	DECLARE @obj int = 20
	DECLARE @type int = 21
	-- variables for xml AND part_func are already there
	
	DROP TABLE IF EXISTS #t1
	CREATE TABLE #t1
	(
		object_id int NULL,
		object_name sysname collate database_default NULL,
		object_schema sysname collate database_default NULL,
		object_db sysname NULL,
		object_svr sysname NULL,
		object_type smallint NOT NULL,
		relative_id int NOT NULL,
		relative_name sysname collate database_default NOT NULL,
		relative_schema sysname collate database_default NULL,
		relative_db sysname NULL,
		relative_svr sysname NULL,
		relative_type smallint NOT NULL,
		schema_bound bit NOT NULL,
		rank smallint NULL,
		degree int NULL
	)

	-- we need to create another temporary table to store the dependencies FROM sys.sql_expression_dependencies till the updated values are inserted finally into #t1
	DROP TABLE IF EXISTS #t2
	CREATE TABLE #t2
	(
		object_id int NULL,
		object_name sysname collate database_default NULL,
		object_schema sysname collate database_default NULL,
		object_db sysname NULL,
		object_svr sysname NULL,
		object_type smallint NOT NULL,
		relative_id int NOT NULL,
		relative_name sysname collate database_default NOT NULL,
		relative_schema sysname collate database_default NULL,
		relative_db sysname NULL,
		relative_svr sysname NULL,
		relative_type smallint NOT NULL,
		schema_bound bit NOT NULL,
		rank smallint NULL
	)

	-- This index will ensure that we have unique parent-child relationship
	CREATE UNIQUE CLUSTERED INDEX i1 ON #t1(object_name, object_schema, object_db, object_svr, object_type, relative_name, relative_schema, relative_type) WITH IGNORE_DUP_KEY

	DECLARE @iter_no int
	SET @iter_no = 1

	DECLARE @rows int
	SET @rows = 1

	INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank) 
	   SELECT l.objid, l.objname, l.objschema, l.objdb, l.objtype, l.objid, l.objname, l.objschema, l.objdb, l.objtype, 1, @iter_no FROM #tObjectInfo l

	-- change the object_id of table types to their user_defined_id
	UPDATE #t1 SET object_id = tt.user_type_id, relative_id = tt.user_type_id
	FROM sys.table_types as tt WHERE tt.type_table_object_id = #t1.object_id AND object_type = @udtt

	WHILE @rows > 0
	BEGIN
		SET @rows = 0
		IF (1 = @FindRef)
		BEGIN
			-- HARD DEPENDENCIES
			-- these dependencies have to be in the same database only

			-- tables that reference uddts or udts
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tbl.object_id, tbl.name, SCHEMA_NAME(tbl.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as c ON c.user_type_id = t.object_id
				JOIN sys.tables as tbl ON tbl.object_id = c.object_id
				WHERE @iter_no = t.rank AND (t.object_type = @uddt OR t.object_type = @udt) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- udtts that reference uddts or udts
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tt.user_type_id, tt.name, SCHEMA_NAME(tt.schema_id), t.object_db, @udtt, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as c ON c.user_type_id = t.object_id
				JOIN sys.table_types as tt ON tt.type_table_object_id = c.object_id
				WHERE @iter_no = t.rank AND (t.object_type = @uddt OR t.object_type = @udt) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- tables/views that reference triggers
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @tr, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.objects as o ON o.parent_object_id = t.object_id AND o.type = 'TR'
				WHERE @iter_no = t.rank AND (t.object_type = @u OR  t.object_type = @v) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- tables that reference defaults (only default objects)
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as clmns ON clmns.default_object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = clmns.object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE @iter_no = t.rank AND t.object_type = @def AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- types that reference defaults (only default objects)
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, @uddt, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.types as tp ON tp.default_object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = t.object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE @iter_no = t.rank AND t.object_type = @def AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- tables that reference rules
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tbl.object_id, tbl.name, SCHEMA_NAME(tbl.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as clmns ON clmns.rule_object_id = t.object_id
				JOIN sys.tables as tbl ON tbl.object_id = clmns.object_id
				WHERE @iter_no = t.rank AND t.relative_type = @rule AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- types that reference rules
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, @uddt, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.types as tp ON tp.rule_object_id = t.object_id
				WHERE @iter_no = t.rank AND t.object_type = @rule AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- tables that reference XmlSchemaCollections
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tbl.object_id, tbl.name, SCHEMA_NAME(tbl.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as c ON c.xml_collection_id = t.object_id
				JOIN sys.tables as tbl ON tbl.object_id = c.object_id -- eliminate views
				WHERE @iter_no = t.rank AND t.object_type = @xml AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- table types that reference XmlSchemaCollections
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tt.user_type_id, tt.name, SCHEMA_NAME(tt.schema_id), t.object_db, @udtt, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as c ON c.xml_collection_id = t.object_id
				JOIN sys.table_types as tt ON tt.type_table_object_id = c.object_id
				WHERE @iter_no = t.rank AND t.object_type = @xml AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- procedures that reference XmlSchemaCollections
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, (case when o.type in ( 'P', 'RF', 'PC') then @sp else @udf end), t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.parameters as c ON c.xml_collection_id = t.object_id
				JOIN sys.objects as o ON o.object_id = c.object_id
				WHERE @iter_no = t.rank AND t.object_type = @xml AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
			-- udf, sp, uda, trigger all that reference assembly
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, (case o.type when 'AF' then @uda when 'PC' then @sp when 'FS' then @udf when 'FT' then @udf when 'TA' then @tr else @udf end), t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_modules as am ON ((am.assembly_id = t.object_id) AND (am.assembly_id >= 65536))
				JOIN sys.objects as o ON am.object_id = o.object_id
				WHERE @iter_no = t.rank AND t.object_type = @assm AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
			-- udt that reference assembly
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT at.user_type_id, at.name, SCHEMA_NAME(at.schema_id), t.object_db, @udt, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_types as at ON ((at.assembly_id = t.object_id) AND (at.is_user_defined = 1))
				WHERE @iter_no = t.rank AND t.object_type = @assm AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- assembly that reference assembly
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT asm.assembly_id, asm.name, t.object_db, @assm, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_references as ar ON ((ar.referenced_assembly_id = t.object_id) AND (ar.referenced_assembly_id >= 65536))
				JOIN sys.assemblies as asm ON asm.assembly_id = ar.assembly_id
				WHERE @iter_no = t.rank AND t.object_type = @assm AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- table references table
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tbl.object_id, tbl.name, SCHEMA_NAME(tbl.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.foreign_keys as fk ON fk.referenced_object_id = t.object_id
				JOIN sys.tables as tbl ON tbl.object_id = fk.parent_object_id
				WHERE @iter_no = t.rank AND t.object_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- uda references types
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @uda, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.parameters as p ON p.user_type_id = t.object_id
				JOIN sys.objects as o ON o.object_id = p.object_id AND o.type = 'AF'
				WHERE @iter_no = t.rank AND t.object_type in (@udt, @uddt, @udtt) AND (t.object_svr IS null AND t.object_db = db_name())

			-- table,view references partition scheme
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, (case o.type when 'V' then @v else @u end), t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.indexes as idx ON idx.data_space_id = t.object_id
				JOIN sys.objects as o ON o.object_id = idx.object_id
				WHERE @iter_no = t.rank AND t.object_type = @part_sch AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- partition scheme references partition function
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT ps.data_space_id, ps.name, t.object_db, @part_sch, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.partition_schemes as ps ON ps.function_id = t.object_id
				WHERE @iter_no = t.rank AND t.object_type = @part_func AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
        
			-- plan guide references sp, udf, triggers
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT pg.plan_guide_id, pg.name, t.object_db, @pg, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.plan_guides as pg ON pg.scope_object_id = t.object_id
				WHERE @iter_no = t.rank AND t.object_type in (@sp, @udf, @tr) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- synonym refrences object
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT s.object_id, s.name, SCHEMA_NAME(s.schema_id), t.object_db, @synonym, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 0, @iter_no + 1
				FROM #t1 as t
				JOIN sys.synonyms as s ON object_id(s.base_object_name) = t.object_id
				WHERE @iter_no = t.rank AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount						
        
			--  sequences that reference uddts 
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT s.object_id, s.name, SCHEMA_NAME(s.schema_id), t.object_db, @sequence, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 0, @iter_no + 1
				FROM #t1 as t
				JOIN sys.sequences as s ON s.user_type_id = t.object_id
				WHERE @iter_no = t.rank AND (t.object_type = @uddt) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount	
        

			-- SOFT DEPENDENCIES
			DECLARE name_cursor CURSOR
			FOR
				SELECT DISTINCT t.object_id, t.object_name, t.object_schema, t.object_type
				FROM #t1 as t
				WHERE @iter_no = t.rank AND (t.object_svr IS null AND t.object_db = db_name()) AND t.object_type NOT IN (@part_sch, @assm, @tr, @ddltr)
			OPEN name_cursor
			DECLARE @objid int
			DECLARE @objname sysname
			DECLARE @objschema sysname
			DECLARE @objtype smallint
			DECLARE @fullname sysname
			DECLARE @objecttype sysname
			FETCH NEXT FROM name_cursor INTO @objid, @objname, @objschema, @objtype
			WHILE (@@FETCH_STATUS <> -1)
			BEGIN
				SET @fullname = case when @objschema IS NULL then quotename(@objname)
								else quotename(@objschema) + '.' + quotename(@objname) end
				SET @objecttype = case when @objtype in (@uddt, @udt, @udtt) then 'TYPE'
									when @objtype = @xml then 'XML_SCHEMA_COLLECTION'
									when @objtype = @part_func then 'PARTITION_FUNCTION'
									else 'OBJECT' end
				INSERT #t2 (object_type, object_id, object_name, object_schema, object_db, object_svr, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
					SELECT
						case dep.referencing_class when 1 then (SELECT
							case when obj.type = 'U' then @u
							when obj.type = 'V' then @v
							when obj.type = 'TR' then @tr
							when obj.type in ('P', 'RF', 'PC') then @sp
							when obj.type in ('AF') then @uda
							when obj.type in ('TF', 'FN', 'IF', 'FS', 'FT') then @udf
							when obj.type = 'D' then @def
							when obj.type = 'SN' then @synonym
							when obj.type = 'SO' then @sequence
							else @obj
							end
						FROM sys.objects as obj WHERE obj.object_id = dep.referencing_id)
					when 6 then (SELECT 
							case when (tp.is_assembly_type = 1) then @udt
							when (tp.is_table_type = 1) then @udtt
							else @uddt
							end
						FROM sys.types as tp WHERE tp.user_type_id = dep.referencing_id)
					when 7 then @u
					when 9 then @u	
					when 10 then @xml 
					when 12 then @ddltr 
					when 21 then @part_func 
					end,
				dep.referencing_id,
				dep.referencing_entity_name,
				dep.referencing_schema_name,
				db_name(), null,
				@objid, @objname,
				@objschema, db_name(), @objtype, 
				0, @iter_no + 1
				FROM sys.dm_sql_referencing_entities(@fullname, @objecttype) dep

				FETCH NEXT FROM name_cursor INTO @objid, @objname, @objschema, @objtype
			END
			CLOSE name_cursor
			DEALLOCATE name_cursor

			UPDATE #t2 SET object_id = obj.object_id, object_name = obj.name, object_schema = schema_name(obj.schema_id), object_type = case when obj.type = 'U' then @u when obj.type = 'V' then @v end		
			FROM sys.objects as o
			JOIN sys.objects as obj ON obj.object_id = o.parent_object_id
			WHERE o.object_id = #t2.object_id AND (#t2.object_type = @obj OR o.parent_object_id != 0) AND #t2.rank = @iter_no + 1

			INSERT #t1 (object_id, object_name, object_schema, object_db, object_svr, object_type, relative_id, relative_name, relative_schema, relative_db, relative_svr, relative_type, schema_bound, rank)
				SELECT object_id, object_name, object_schema, object_db, object_svr, object_type, relative_id, relative_name, relative_schema, relative_db, relative_svr, relative_type, schema_bound, rank 
				FROM #t2 WHERE @iter_no + 1 = rank AND #t2.object_id != #t2.relative_id
			SET @rows = @rows + @@rowcount

		end
		else
		BEGIN
			-- SOFT DEPENDENCIES
			-- INSERT all values FROM sys.sql_expression_dependencies for the corresponding object
			-- first INSERT them in #t2, UPDATE them AND then finally INSERT them in #t1
			INSERT #t2 (object_type, object_name, object_schema, object_db, object_svr, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT 
					case dep.referenced_class when 1 then @obj
					when 6 then @type
					when 7 then @u
					when 9 then @u	
					when 10 then @xml
					when 21 then @part_func
					end,
				dep.referenced_entity_name,
				dep.referenced_schema_name,
				dep.referenced_database_name,
				dep.referenced_server_name,
				t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type,
				dep.is_schema_bound_reference, @iter_no + 1
				FROM #t1 as t
				JOIN sys.sql_expression_dependencies as dep ON dep.referencing_id = t.object_id
				WHERE @iter_no = t.rank AND t.object_svr IS NULL AND t.object_db = db_name()

			-- INSERT all the dependency values in case of a table that references a check
			INSERT #t2 (object_type, object_name, object_schema, object_db, object_svr, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT 
					case dep.referenced_class when 1 then @obj
					when 6 then @type
					when 7 then @u
					when 9 then @u	
					when 10 then @xml
					when 21 then @part_func
					end,
				dep.referenced_entity_name,
				dep.referenced_schema_name,
				dep.referenced_database_name,
				dep.referenced_server_name,
				t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type,
				dep.is_schema_bound_reference, @iter_no + 1
				FROM #t1 as t
				JOIN sys.sql_expression_dependencies as d ON d.referenced_id = t.object_id
				JOIN sys.objects as o ON o.object_id = d.referencing_id AND o.type = 'C'
				JOIN sys.sql_expression_dependencies as dep ON dep.referencing_id = d.referencing_id AND dep.referenced_id != t.object_id
				WHERE @iter_no = t.rank AND t.object_svr IS NULL AND t.object_db = db_name() AND t.object_type = @u

			-- INSERT all the dependency values in case of an object that belongs to another object whose dependencies are being found
			INSERT #t2 (object_type, object_name, object_schema, object_db, object_svr, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT
					case dep.referenced_class when 1 then @obj
					when 6 then @type
					when 7 then @u
					when 9 then @u	
					when 10 then @xml
					when 21 then @part_func
					end,
				dep.referenced_entity_name,
				dep.referenced_schema_name,
				dep.referenced_database_name,
				dep.referenced_server_name,
				t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type,
				dep.is_schema_bound_reference, @iter_no + 1
				FROM #t1 as t
				JOIN sys.objects as o ON o.parent_object_id = t.object_id
				JOIN sys.sql_expression_dependencies as dep ON dep.referencing_id = o.object_id
				WHERE @iter_no = t.rank AND t.object_svr IS NULL AND t.object_db = db_name()

			-- queries for objects WITH object_id null AND object_svr null - resolve them
			-- we will build the query to resolve the objects 
			-- increase @rows as we bind the objects
        
			DECLARE db_cursor CURSOR
			FOR
				SELECT distinct ISNULL(object_db, db_name()) FROM #t2 as t
				WHERE t.rank = (@iter_no+1) AND t.object_id IS NULL AND t.object_svr IS NULL
			OPEN db_cursor
			DECLARE @dbname sysname
			DECLARE @quote_quoted_dbname sysname
			DECLARE @bracket_quoted_dbname sysname
			FETCH NEXT FROM db_cursor INTO @dbname
			WHILE (@@FETCH_STATUS <> -1)
			BEGIN
				IF (db_id(@dbname) IS NULL) 
				BEGIN
					FETCH NEXT FROM db_cursor INTO @dbname
					CONTINUE
				END
				SET @quote_quoted_dbname = quotename(@dbname, '''')
				SET @bracket_quoted_dbname = quotename(@dbname, ']')
				DECLARE @query nvarchar(MAX)
				-- when schema is not null 
				-- @obj
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = obj.object_id, object_type = 
								case when obj.type = ''U'' then ' + CAST(@u AS nvarchar(8)) +
								' when obj.type = ''V'' then ' + CAST(@v AS nvarchar(8)) +
								' when obj.type = ''TR'' then ' + CAST(@tr AS nvarchar(8)) +
								' when obj.type in ( ''P'', ''RF'', ''PC'' ) then ' + CAST(@sp AS nvarchar(8)) +
								' when obj.type in ( ''AF'' ) then ' + CAST(@uda AS nvarchar(8)) +
								' when obj.type in ( ''TF'', ''FN'', ''IF'', ''FS'', ''FT'' ) then ' + CAST(@udf AS nvarchar(8)) +
								' when obj.type = ''D'' then ' + CAST(@def AS nvarchar(8)) +
								' when obj.type = ''SN'' then ' + CAST(@synonym AS nvarchar(8)) +
								' when obj.type = ''SO'' then ' + CAST(@sequence AS nvarchar(8)) +
								' else ' + CAST(@unknown AS nvarchar(8)) +
								' end
					FROM ' + @bracket_quoted_dbname + '.sys.objects as obj 
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = obj.schema_id
					WHERE obj.name = #t2.object_name collate database_default
					AND sch.name = #t2.object_schema collate database_default
					AND #t2.object_type = ' + CAST(@obj AS nvarchar(8)) + ' AND #t2.object_schema IS NOT NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)
				-- @type
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = t.user_type_id, object_type = case when t.is_assembly_type = 1 then ' + CAST(@udt AS nvarchar(8)) + ' when t.is_table_type = 1 then ' + CAST(@udtt AS nvarchar(8)) + ' else ' + CAST(@uddt AS nvarchar(8)) + ' end
					FROM ' + @bracket_quoted_dbname + '.sys.types as t
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = t.schema_id
					WHERE t.name = #t2.object_name collate database_default
					AND sch.name = #t2.object_schema collate database_default
					AND #t2.object_type = ' + CAST(@type AS nvarchar(8)) + ' AND #t2.object_schema IS NOT NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- @xml
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = x.xml_collection_id 
					FROM ' + @bracket_quoted_dbname + '.sys.xml_schema_collections as x
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = x.schema_id
					WHERE x.name = #t2.object_name collate database_default
					AND sch.name = #t2.object_schema collate database_default
					AND #t2.object_type = ' + CAST(@xml AS nvarchar(8)) + ' AND #t2.object_schema IS NOT NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)
				-- @part_func - schema is always null
				-- @schema is null
				-- consider schema as 'dbo'
				-- @obj
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = obj.object_id, object_schema = SCHEMA_NAME(obj.schema_id), object_type = 
								case when obj.type = ''U'' then ' + CAST(@u AS nvarchar(8)) +
								' when obj.type = ''V'' then ' + CAST(@v AS nvarchar(8)) +
								' when obj.type = ''TR'' then ' + CAST(@tr AS nvarchar(8)) +
								' when obj.type in ( ''P'', ''RF'', ''PC'' ) then ' + CAST(@sp AS nvarchar(8)) +
								' when obj.type in ( ''AF'' ) then ' + CAST(@uda AS nvarchar(8)) +
								' when obj.type in ( ''TF'', ''FN'', ''IF'', ''FS'', ''FT'' ) then ' + CAST(@udf AS nvarchar(8)) +
								' when obj.type = ''D'' then ' + CAST(@def AS nvarchar(8)) +
								' when obj.type = ''SN'' then ' + CAST(@synonym AS nvarchar(8)) +
								' when obj.type = ''SO'' then ' + CAST(@sequence AS nvarchar(8)) +
								' else ' + CAST(@unknown AS nvarchar(8)) +
								' end
					FROM ' + @bracket_quoted_dbname + '.sys.objects as obj 
					WHERE obj.name = #t2.object_name collate database_default
					AND SCHEMA_NAME(obj.schema_id) = ''dbo''
					AND #t2.object_type = ' + CAST(@obj AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)
				-- @type
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = t.user_type_id, object_schema = SCHEMA_NAME(t.schema_id), object_type = case when t.is_assembly_type = 1 then ' + CAST(@udt AS nvarchar(8)) + ' when t.is_table_type = 1 then ' + CAST(@udtt AS nvarchar(8)) + ' else ' + CAST(@uddt AS nvarchar(8)) + ' end
					FROM ' + @bracket_quoted_dbname + '.sys.types as t
					WHERE t.name = #t2.object_name collate database_default
					AND SCHEMA_NAME(t.schema_id) = ''dbo''
					AND #t2.object_type = ' + CAST(@type AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)
				-- @xml
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = x.xml_collection_id, object_schema = SCHEMA_NAME(x.schema_id)
					FROM ' + @bracket_quoted_dbname + '.sys.xml_schema_collections as x
					WHERE x.name = #t2.object_name collate database_default
					AND SCHEMA_NAME(x.schema_id) = ''dbo''
					AND #t2.object_type = ' + CAST(@xml AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- consider schema as t.relative_schema
				-- the parent object will have the default schema of user in case of dynamic schema binding
				-- @obj
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = obj.object_id, object_schema = SCHEMA_NAME(obj.schema_id), object_type = 
								case when obj.type = ''U'' then ' + CAST(@u AS nvarchar(8)) +
								' when obj.type = ''V'' then ' + CAST(@v AS nvarchar(8)) +
								' when obj.type = ''TR'' then ' + CAST(@tr AS nvarchar(8)) +
								' when obj.type in ( ''P'', ''RF'', ''PC'' ) then ' + CAST(@sp AS nvarchar(8)) +
								' when obj.type in ( ''AF'' ) then ' + CAST(@uda AS nvarchar(8)) +
								' when obj.type in ( ''TF'', ''FN'', ''IF'', ''FS'', ''FT'' ) then ' + CAST(@udf AS nvarchar(8)) +
								' when obj.type = ''D'' then ' + CAST(@def AS nvarchar(8)) +
								' when obj.type = ''SN'' then ' + CAST(@synonym AS nvarchar(8)) +
								' when obj.type = ''SO'' then ' + CAST(@sequence AS nvarchar(8)) +
								' else ' + CAST(@unknown AS nvarchar(8)) +
								' end
					FROM ' + @bracket_quoted_dbname + '.sys.objects as obj 
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = obj.schema_id
					WHERE obj.name = #t2.object_name collate database_default
					AND sch.name = #t2.relative_schema collate database_default
					AND #t2.object_type = ' + CAST(@obj AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- @type
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = t.user_type_id, object_schema = SCHEMA_NAME(t.schema_id), object_type = case when t.is_assembly_type = 1 then ' + CAST(@udt AS nvarchar(8)) + ' when t.is_table_type = 1 then ' + CAST(@udtt AS nvarchar(8)) + ' else ' + CAST(@uddt AS nvarchar(8)) + ' end
					FROM ' + @bracket_quoted_dbname + '.sys.types as t
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = t.schema_id
					WHERE t.name = #t2.object_name collate database_default
					AND sch.name = #t2.relative_schema collate database_default
					AND #t2.object_type = ' + CAST(@type AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- @xml
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = x.xml_collection_id, object_schema = SCHEMA_NAME(x.schema_id)
					FROM ' + @bracket_quoted_dbname + '.sys.xml_schema_collections as x
					JOIN ' + @bracket_quoted_dbname + '.sys.schemas as sch ON sch.schema_id = x.schema_id
					WHERE x.name = #t2.object_name collate database_default
					AND sch.name = #t2.relative_schema collate database_default
					AND #t2.object_type = ' + CAST(@xml AS nvarchar(8)) + ' AND #t2.object_schema IS NULL 
					AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- @part_func always have schema as null
				SET @query = 'UPDATE #t2 SET object_db = N' + @quote_quoted_dbname + ', object_id = p.function_id
					FROM ' + @bracket_quoted_dbname + '.sys.partition_functions as p
					WHERE p.name = #t2.object_name collate database_default
					AND #t2.object_type = ' + CAST(@part_func AS nvarchar(8)) + 
					' AND (#t2.object_db IS NULL or #t2.object_db = N' + @quote_quoted_dbname + ')
					AND #t2.rank = (' + CAST(@iter_no AS nvarchar(8)) + '+1) AND #t2.object_id IS NULL AND #t2.object_svr IS NULL'
				EXEC (@query)

				-- UPDATE the shared object IF any (schema is not null)
				UPDATE #t2 SET object_db = 'master', object_id = o.object_id, object_type = @sp
				FROM master.sys.objects as o 
				JOIN master.sys.schemas as sch ON sch.schema_id = o.schema_id
				WHERE o.name = #t2.object_name collate database_default AND sch.name = #t2.object_schema collate database_default AND 
				o.type in ('P', 'RF', 'PC') AND #t2.object_id IS null AND
				#t2.object_name LIKE 'sp/_%' ESCAPE '/' AND #t2.object_db IS null AND #t2.object_svr IS null

				-- UPDATE the shared object IF any (schema is null)
				UPDATE #t2 SET object_db = 'master', object_id = o.object_id, object_schema = SCHEMA_NAME(o.schema_id), object_type = @sp
				FROM master.sys.objects as o 
				WHERE o.name = #t2.object_name collate database_default AND SCHEMA_NAME(o.schema_id) = 'dbo' collate database_default  AND 
				o.type in ('P', 'RF', 'PC') AND 
				#t2.object_schema IS null AND #t2.object_id IS null AND
				#t2.object_name LIKE 'sp/_%' ESCAPE '/' AND #t2.object_db IS null AND #t2.object_svr IS null

				FETCH NEXT FROM db_cursor INTO @dbname
			END
			CLOSE db_cursor
			DEALLOCATE db_cursor

		UPDATE #t2 SET object_type = @unknown WHERE object_id IS NULL

			INSERT #t1 (object_id, object_name, object_schema, object_db, object_svr, object_type, relative_id, relative_name, relative_schema, relative_db, relative_svr, relative_type, schema_bound, rank)
				SELECT object_id, object_name, object_schema, object_db, object_svr, object_type, relative_id, relative_name, relative_schema, relative_db, relative_svr, relative_type, schema_bound, rank 
				FROM #t2 WHERE @iter_no + 1 = rank
			SET @rows = @rows + @@rowcount


			-- HARD DEPENDENCIES
			-- uddt or udt referenced by table
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, case tp.is_assembly_type when 1 then @udt else @uddt end, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as col ON col.object_id = t.object_id
				JOIN sys.types as tp ON tp.user_type_id = col.user_type_id AND tp.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- uddt or udt referenced by table type
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, case tp.is_assembly_type when 1 then @udt else @uddt end, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.table_types as tt ON tt.user_type_id = t.object_id
				JOIN sys.columns as col ON col.object_id = tt.type_table_object_id
				JOIN sys.types as tp ON tp.user_type_id = col.user_type_id AND tp.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type = @udtt AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- table or view referenced by trigger
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, case o.type when 'V' then @v else @u end, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.triggers as tr ON tr.object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = tr.parent_id
				WHERE @iter_no = t.rank AND t.object_type = @tr AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- defaults (only default objects) referenced by tables
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @def, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as clmns ON clmns.object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = clmns.default_object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE  @iter_no = t.rank AND t.object_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- defaults (only default objects) referenced by types
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @def, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.types as tp ON tp.user_type_id = t.object_id
				JOIN sys.objects as o ON o.object_id = tp.default_object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE @iter_no = t.rank AND t.object_type = @uddt AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
      
			-- rules referenced by tables
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @rule, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as clmns ON clmns.object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = clmns.rule_object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE @iter_no = t.rank AND t.relative_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- rules referenced by types
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, @rule, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.types as tp ON tp.user_type_id = t.object_id
				JOIN sys.objects as o ON o.object_id = tp.rule_object_id AND 0 = isnull(o.parent_object_id, 0)
				WHERE @iter_no = t.rank AND t.relative_type = @uddt AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
        
			-- XmlSchemaCollections referenced by tables
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT x.xml_collection_id, x.name, SCHEMA_NAME(x.schema_id), t.object_db, @xml, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.columns as c ON c.object_id = t.object_id
				JOIN sys.xml_schema_collections as x ON x.xml_collection_id = c.xml_collection_id AND x.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- XmlSchemaCollections referenced by tabletypes
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT x.xml_collection_id, x.name, SCHEMA_NAME(x.schema_id), t.object_db, @xml, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.table_types as tt ON tt.user_type_id = t.object_id
				JOIN sys.columns as c ON c.object_id = tt.type_table_object_id
				JOIN sys.xml_schema_collections as x ON x.xml_collection_id = c.xml_collection_id AND x.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type = @udtt AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- XmlSchemaCollections referenced by procedures
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT x.xml_collection_id, x.name, SCHEMA_NAME(x.schema_id), t.object_db, @xml, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.parameters as c ON c.object_id = t.object_id
				JOIN sys.xml_schema_collections as x ON x.xml_collection_id = c.xml_collection_id AND x.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type in (@sp, @udf) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- table referenced by table
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tbl.object_id, tbl.name, SCHEMA_NAME(tbl.schema_id), t.object_db, @u, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.foreign_keys as fk ON fk.parent_object_id = t.object_id
				JOIN sys.tables as tbl ON tbl.object_id = fk.referenced_object_id
				WHERE @iter_no = t.rank AND t.object_type = @u AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- uddts referenced by uda
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, case when tp.is_table_type = 1 then @udtt when tp.is_assembly_type = 1 then @udt else @uddt end, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.parameters as p ON p.object_id = t.object_id
				JOIN sys.types as tp ON tp.user_type_id = p.user_type_id
				WHERE @iter_no = t.rank AND t.object_type = @uda AND t.object_type = @uda AND tp.user_type_id>256
			SET @rows = @rows + @@rowcount

			-- assembly referenced by assembly
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT asm.assembly_id, asm.name, t.object_db, @assm, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_references as ar ON ((ar.assembly_id = t.object_id) AND (ar.referenced_assembly_id >= 65536))
				JOIN sys.assemblies as asm ON asm.assembly_id = ar.referenced_assembly_id
				WHERE @iter_no = t.rank AND t.object_type = @assm AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- assembly referenced by udt
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT asm.assembly_id, asm.name, t.object_db, @assm, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_types as at ON ((at.user_type_id = t.object_id) AND (at.is_user_defined = 1))
				JOIN sys.assemblies as asm ON asm.assembly_id = at.assembly_id
				WHERE @iter_no = t.rank AND t.object_type = @udt AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- assembly referenced by udf, sp, uda, trigger
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT asm.assembly_id, asm.name, t.object_db, @assm, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.assembly_modules as am ON ((am.object_id = t.object_id) AND (am.assembly_id >= 65536))
				JOIN sys.assemblies as asm ON asm.assembly_id = am.assembly_id
				WHERE @iter_no = t.rank AND t.object_type in ( @udf, @sp, @uda, @tr) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- Partition Schemes referenced by tables/views
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT ps.data_space_id, ps.name, t.object_db, @part_sch, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.indexes as idx ON idx.object_id = t.object_id
				JOIN sys.partition_schemes as ps ON ps.data_space_id = idx.data_space_id
				WHERE @iter_no = t.rank AND t.object_type in (@u, @v) AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- Partition Function referenced by Partition Schemes
			INSERT #t1 (object_id, object_name, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT pf.function_id, pf.name, t.object_db, @part_func, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.partition_schemes as ps ON ps.data_space_id = t.object_id
				JOIN sys.partition_functions as pf ON pf.function_id = ps.function_id
				WHERE @iter_no = t.rank AND t.object_type = @part_sch AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
        
			-- sp, udf, triggers referenced by plan guide
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, (case o.type when 'P' then @sp when 'TR' then @tr else @udf end), t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.plan_guides as pg ON pg.plan_guide_id = t.object_id
				JOIN sys.objects as o ON o.object_id = pg.scope_object_id
				WHERE @iter_no = t.rank AND t.object_type = @pg AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount

			-- objects referenced by synonym
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT o.object_id, o.name, SCHEMA_NAME(o.schema_id), t.object_db, (case when o.type = 'U' then @u when o.type = 'V' then @v when o.type in ('P', 'RF', 'PC') then @sp when o.type = 'AF' then @uda else @udf end), t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 0, @iter_no + 1
				FROM #t1 as t
				JOIN sys.synonyms as s ON s.object_id = t.object_id
				JOIN sys.objects as o ON o.object_id = OBJECT_ID(s.base_object_name) AND o.type in ('U', 'V', 'P', 'RF', 'PC', 'AF', 'TF', 'FN', 'IF', 'FS', 'FT')
				WHERE @iter_no = t.rank AND t.object_type = @synonym AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount
        
			-- uddt referenced by sequence. Used to find UDDT that is in sequence dependencies.
			INSERT #t1 (object_id, object_name, object_schema, object_db, object_type, relative_id, relative_name, relative_schema, relative_db, relative_type, schema_bound, rank)
				SELECT tp.user_type_id, tp.name, SCHEMA_NAME(tp.schema_id), t.object_db, case tp.is_assembly_type when 1 then @udt else @uddt end, t.object_id, t.object_name, t.object_schema, t.object_db, t.object_type, 1, @iter_no + 1
				FROM #t1 as t
				JOIN sys.sequences as s ON s.object_id = t.object_id
				JOIN sys.types as tp ON tp.user_type_id = s.user_type_id AND tp.schema_id != 4
				WHERE @iter_no = t.rank AND t.object_type = @sequence AND (t.object_svr IS null AND t.object_db = db_name())
			SET @rows = @rows + @@rowcount						
        
		end
		SET @iter_no = @iter_no + 1
	end

	UPDATE #t1 SET rank = 0
	-- computing the degree of the nodes
	UPDATE #t1 SET degree = (
		SELECT count(*) FROM #t1 t
		WHERE t.relative_id = #t1.object_id AND t.object_id != t.relative_id)

	-- perform the topological sorting
	SET @iter_no = 1
	WHILE 1 = 1
	BEGIN
		UPDATE #t1 SET rank=@iter_no WHERE degree = 0
		-- end the loop IF no more rows left to process
		IF (@@rowcount = 0) break
		UPDATE #t1 SET degree = NULL WHERE rank = @iter_no

		UPDATE #t1 SET degree = (
			SELECT count(*) FROM #t1 t
			WHERE t.relative_id = #t1.object_id AND t.object_id != t.relative_id
			AND t.object_id in (SELECT tt.object_id FROM #t1 tt WHERE tt.rank = 0))
			WHERE degree is not null

		SET @iter_no = @iter_no + 1
	end

	--correcting naming mistakes of objects present in current database 
	--This part need to be removed once SMO's URN comparision gets fixed
			DECLARE @collation sysname;
			DECLARE db_cursor CURSOR
			FOR
				SELECT distinct ISNULL(object_db, db_name()) FROM #t1 as t
				WHERE t.object_id IS NOT NULL AND t.object_svr IS NULL
			OPEN db_cursor
			FETCH NEXT FROM db_cursor INTO @dbname
			WHILE (@@FETCH_STATUS <> -1)
			BEGIN
				IF (db_id(@dbname) IS NULL) 
				BEGIN
					FETCH NEXT FROM db_cursor INTO @dbname
					CONTINUE
				END
            
				SET @collation = (SELECT convert(sysname,DatabasePropertyEx(@dbname,'Collation')));
				SET @query = 'UPDATE #t1 SET #t1.object_name = o.name,#t1.object_schema = sch.name FROM #t1  inner JOIN '+ quotename(@dbname)+ '.sys.objects as o ON #t1.object_id = o.object_id inner JOIN '+ quotename(@dbname)+ '.sys.schemas as sch ON sch.schema_id = o.schema_id  WHERE o.name = #t1.object_name collate '+  @collation +' AND sch.name = #t1.object_schema collate '+ @collation
				EXEC (@query)	


				FETCH NEXT FROM db_cursor INTO @dbname
			END
			CLOSE db_cursor
			DEALLOCATE db_cursor
    

	--final SELECT
	SELECT		ISNULL(t.object_id, 0) as [object_id],
				t.object_name,
				ISNULL(t.object_schema, '') as [object_schema], 
				ISNULL(t.object_db, '') as [object_db], 
				ISNULL(t.object_svr, '') as [object_svr], 
				t.object_type, 
				ISNULL(t.relative_id, 0) as [relative_id], 
				t.relative_name, 
				ISNULL(t.relative_schema, '') as [relative_schema], 
				relative_db, 
				ISNULL(t.relative_svr, '') as [relative_svr], 
				t.relative_type, 
				t.schema_bound, 
				ISNULL(CASE WHEN p.type= 'U' then @u when p.type = 'V' then @v end, 0) as [ptype], 
				ISNULL(p.name, '') as [pname], 
				ISNULL(SCHEMA_NAME(p.schema_id), '') as [pschema]
	FROM		#t1 as t
	left JOIN	sys.objects as o ON (t.object_type = @tr AND o.object_id = t.object_id) or (t.relative_type = @tr AND o.object_id = t.relative_id)
	left JOIN	sys.objects as p ON p.object_id = o.parent_object_id

	 WHERE @FilterCurrentDBOnly = 0
		OR ISNULL(t.object_db, '') = DB_NAME()
	 order by rank desc


	RETURN
END
/*
	EXEC [dbo].[GetObjectDependencies]	@ObjectName='INV_ReloadILI_FromERPPRD', @RefType=4
	EXEC [dbo].[GetObjectDependencies]	@ObjectName='INV_GetExchangeRate', @RefType=0
	EXEC [dbo].[GetObjectDependencies]	@ObjectName='INV_ILI', @RefType=3
	EXEC [dbo].[GetObjectDependencies]	@ObjectName='INV_ILIV', @RefType=2
*/