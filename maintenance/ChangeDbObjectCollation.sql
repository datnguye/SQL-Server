--======================================================
-- Usage: ChangeDbObjectCollation 
-- Notes: Dependencies ON /script-generation/GetCreate[Drop]Index functions
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-17	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [ChangeDbObjectCollation]
GO
CREATE PROCEDURE [dbo].[ChangeDbObjectCollation]	@CurrentCollation nvarchar(255),
													@NewCollation nvarchar(255),
													@SupressInfoMessages bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @vMessage nvarchar(max)
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'	Starting collation re-definition procedure.'
	RAISERROR(@vMessage, 0, 1) WITH NOWAIT
    
    IF @CurrentCollation IS NULL 
	OR NOT EXISTS (SELECT 1 FROM fn_helpcollations() WHERE name = @CurrentCollation)
    BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Collation '+Coalesce(@CurrentCollation,'(NULL)')+' does NOT exist.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'	Collation re-definition procedure completed WITH error.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT

		RETURN
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND collation_name = @NewCollation)
    BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		New collation '+Coalesce(@NewCollation,'(NULL)')+' is not database collation. The changes could not be affected!.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Try to change database collation firstly:'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		SET @vMessage =  'USE master' + CHAR(10)
		SET @vMessage += 'GO' + CHAR(10)
		SET @vMessage += 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + CHAR(10)
		SET @vMessage += 'SET SINGLE_USER WITH ROLLBACK IMMEDIATE' + CHAR(10)
		SET @vMessage += 'GO' + CHAR(10)
		SET @vMessage += 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + CHAR(10)
		SET @vMessage += 'COLLATE ' + @NewCollation + CHAR(10)
		SET @vMessage += 'GO' + CHAR(10)
		SET @vMessage += 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + CHAR(10)
		SET @vMessage += 'SET MULTI_USER WITH ROLLBACK IMMEDIATE' + CHAR(10)
		SET @vMessage += 'GO' + CHAR(10)
  
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'	Collation re-definition procedure completed WITH error.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT

		RETURN
    END

    DECLARE @vConstraintName nvarchar(256)
    DECLARE @vSQLStatement nvarchar(max)
    DECLARE @vIsPrimaryKey bit
    DECLARE @vIsForeignKey bit
    DECLARE @vTableName nvarchar(256)
    DECLARE @vColumnName nvarchar(256)
    DECLARE @vObjectName nvarchar(512)
    DECLARE @vIsNullable nvarchar(10)
    DECLARE @vPrincipalName nvarchar(256)
    DECLARE @vPermissionType nvarchar(256)
    DECLARE @vPermissionScope nvarchar(256)
    IF (@NewCollation = @CurrentCollation)
    BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Old collation IS the same as the existing database collation.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'	Collation re-definition procedure completed WITH error.'
		RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		RETURN
    END
    
	DECLARE @t_IndexList Table (Index_Name nvarchar(256),Is_Primary_Key bit,Is_Foreign_Key bit,Drop_Statement nvarchar(1024),Create_Statement nvarchar(max))
	DECLARE @t_ColumnList Table (Table_Schema nvarchar(256),Table_Name nvarchar(256),Column_Name nvarchar(256), Is_Nullable nvarchar(10))
	DECLARE @t_ObjectList Table (Object_Schema nvarchar(256),Object_Name nvarchar(256), Object_Drop_Statement nvarchar(1024), Object_Definition nvarchar(max),Original_Object_ID bigint)
	DECLARE @t_ViewList Table (View_Schema nvarchar(256),View_Name nvarchar(256), View_Drop_Statement nvarchar(1024), View_Definition nvarchar(max),Original_Object_ID bigint)
	DECLARE @t_PermissionList Table (Original_Object_ID bigint, Permission_Grant_Statement nvarchar(1024), Object_Name nvarchar(256),Database_Principal nvarchar(256), Permission_Type nvarchar(256), Permission_Scope nvarchar(256))
    
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Database objects will be changed FROM collation ['+@CurrentCollation+'] to ['+@NewCollation+'].'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Getting list of constraints referencing columns of the requested collation'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
    INSERT
    INTO		@t_IndexList
    SELECT		DISTINCT 
				SI.Name,
				SI.Is_Primary_Key,
				0,
				dbo.GetDropIndex(SI.Object_ID, SI.Name),
				dbo.GetCreateIndex(SI.Object_ID, SI.Name)
	FROM		sys.Indexes SI
	JOIN		sys.Objects SO
			ON	SO.Object_ID = SI.Object_ID
			AND	SO.Is_MS_Shipped = 0
	JOIN		sys.Index_Columns SIC
			ON	SIC.Index_ID = SI.Index_ID
			AND	SIC.Object_ID = SI.Object_ID
	JOIN		sys.Columns SC
			ON	SC.Column_ID = SIC.Column_ID
			AND	SC.Object_ID = SIC.Object_ID
			AND	SC.Collation_Name = @CurrentCollation
	UNION	
    SELECT		DISTINCT 
				SI.Name,
				SI.Is_Primary_Key,
				0,
				dbo.GetDropIndex(SI.Object_ID, SI.Name),
				dbo.GetCreateIndex(SI.Object_ID, SI.Name)
	FROM		sys.Indexes SI
	JOIN		sys.Objects SO
			ON	SO.Object_ID = SI.Object_ID
			AND	SO.Is_MS_Shipped = 0
	WHERE		SI.Has_Filter = 1
	UNION
	SELECT		DISTINCT
				FK.Name,
				0,
				1,
				dbo.GetDropIndex(FK.Object_ID,FK.Name),
				dbo.GetCreateIndex(FK.Object_ID,FK.Name)
	FROM		sys.Foreign_Keys FK
	JOIN		sys.Objects SO
			ON	SO.Object_ID = FK.Object_ID
			AND	SO.Is_MS_Shipped = 0
	JOIN		sys.Foreign_Key_Columns FKC
			ON	FKC.Constraint_Object_ID = FK.Object_ID
	JOIN		sys.Columns SC
			ON	SC.Object_ID = FKC.Referenced_Object_ID
			AND	SC.Column_ID = FKC.Referenced_Column_ID
			AND	SC.Collation_Name = @CurrentCollation
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+Cast(@@RowCount as nvarchar)+' constraints found.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Getting list of columns of the requested collation.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	INSERT
	INTO	@t_ColumnList
	SELECT	ISC.Table_Schema,
			ISC.Table_Name,
			ISC.Column_Name,
			ISC.Is_Nullable
	FROM	Information_Schema.Columns ISC
	JOIN	Information_Schema.Tables IST
		ON	IST.Table_Name = ISC.Table_Name
		AND	IST.Table_Schema = ISC.Table_Schema
		AND	IST.Table_Type <> 'VIEW'
	WHERE	ISC.Collation_Name = @CurrentCollation
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+Cast(@@RowCount as nvarchar)+' columns found.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Getting a list of routines.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
    INSERT
    INTO		@t_ObjectList
    SELECT		Object_Schema_Name(SO.Object_ID),
				Object_Name(SO.Object_ID),
				Case
					When SO.Type = 'P' Then 'DROP PROCEDURE ['+Object_Schema_Name(SO.Object_ID)+'].['+Object_Name(SO.Object_ID)+']'
					When SO.Type In ('FN','IF','TF') Then 'DROP FUNCTION ['+Object_Schema_Name(SO.Object_ID)+'].['+Object_Name(SO.Object_ID)+']'
					When SO.Type In ('TR') Then 'DROP TRIGGER ['+Object_Schema_Name(SO.Object_ID)+'].['+Object_Name(SO.Object_ID)+']'
				END,
				SM.Definition,
				SO.Object_ID
	FROM		sys.SQL_Modules SM
	JOIN		sys.Objects SO
			ON	SO.Object_ID = SM.Object_ID
			AND	SO.Is_MS_Shipped = 0
	WHERE		Object_Name(SO.Object_ID) <> 'ChangeDbObjectCollation'
			AND	Object_Name(SO.Object_ID) <> 'Change_User_Defined_Type_Definition'
			AND	Object_Name(SO.Object_ID) <> 'PadString'
			AND	Object_Name(SO.Object_ID) <> 'GetDropIndex'
			AND	Object_Name(SO.Object_ID) <> 'GetCreateIndex'
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+Cast(@@Rowcount as nvarchar)+' routines found.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Getting a list of views.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
    INSERT
    INTO		@t_ViewList
    SELECT		DISTINCT
				VCU.View_Schema,
				VCU.View_Name,
				'DROP VIEW ['+VCU.View_Schema+'].['+VCU.View_Name+']',
				SM.Definition,
				SO.Object_ID
	FROM		Information_Schema.View_Column_Usage VCU
	JOIN		@t_ColumnList CL
			ON	CL.Table_Name = VCU.Table_Name
			AND	CL.Column_Name = VCU.Column_Name
	JOIN		sys.Objects SO
			ON	SO.Name = VCU.View_Name
			AND	Object_Schema_Name(SO.Object_ID) = VCU.View_Schema
	JOIN		sys.SQL_Modules SM
			ON	SM.Object_ID = SO.Object_ID
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+Cast(@@Rowcount as nvarchar)+' views found.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Getting a list of permission assignments ON objects that will be removed.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	INSERT
	INTO	@t_PermissionList
	SELECT	Original_Object_ID,
			State_Desc Collate Latin1_General_CI_AS+' '+Permission_Name Collate Latin1_General_CI_AS+' ON ['+Object_Schema_Name(SO.Object_ID)+'].['+Object_Name(SO.Object_ID)+'] TO '+ DP.Name Collate Latin1_General_CI_AS,
			'['+Object_Schema_Name(SO.Object_ID)+'].['+Object_Name(SO.Object_ID)+']',
			DP.Name,
			Upper(Substring(State_Desc,1,1))+Lower(Substring(State_Desc,2,256)),
			Permission_Name
	FROM	@t_ObjectList OL
	JOIN	sys.Database_Permissions DPE
		ON	DPE.Major_ID = OL.Original_Object_ID
	JOIN	sys.Objects SO
		ON	SO.Object_ID = OL.Original_Object_ID
	JOIN	sys.Database_Principals DP
		ON	DP.Principal_ID = DPE.Grantee_Principal_ID
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+Cast(@@Rowcount as nvarchar)+' permissions located.'
    IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
        	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Removing existing constraints.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_DropConstraints CURSOR FOR
		SELECT		Index_Name,
					Drop_Statement,
					Is_Primary_Key,
					Is_Foreign_Key
		FROM		@t_IndexList
		ORDER BY	Is_Foreign_Key Desc,
					Is_Primary_Key Asc,
					Index_Name Asc
	OPEN c_DropConstraints
	FETCH NEXT FROM c_DropConstraints INTO @vConstraintName, @vSQLStatement, @vIsPrimaryKey, @vIsForeignKey
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Removing constraint '+@vConstraintName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Removal of constraint '+@vConstraintName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'					'+@vSQLStatement
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_DropConstraints INTO @vConstraintName, @vSQLStatement, @vIsPrimaryKey, @vIsForeignKey
	END
	CLOSE c_DropConstraints
	DEALLOCATE c_DropConstraints

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Removing routines.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Routines CURSOR FOR
		SELECT		'['+Object_Schema+'].['+Object_Name+']',
					Object_Drop_Statement
		FROM		@t_ObjectList
		WHERE		Object_Drop_Statement IS NOT NULL
		ORDER BY	Object_Name
	OPEN c_Routines
	FETCH NEXT FROM c_Routines INTO @vObjectName, @vSQLStatement
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Removing routine '+@vObjectName+'. '+@vSQLStatement
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Removal of routine '+@vObjectName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'					'+@vSQLStatement
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Routines INTO @vObjectName, @vSQLStatement
	END
	CLOSE c_Routines
	DEALLOCATE c_Routines

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Removing views.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Views CURSOR FOR
		SELECT	'['+View_Schema+'].['+View_Name+']',
				View_Drop_Statement
		FROM	@t_ViewList
	OPEN c_Views
	FETCH NEXT FROM c_Views INTO @vObjectName, @vSQLStatement
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Removing view '+@vObjectName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Removal of view '+@vObjectName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'					'+@vSQLStatement
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Views INTO @vObjectName, @vSQLStatement
	END
	CLOSE c_Views
	DEALLOCATE c_Views

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Resetting columns.'
	RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Columns CURSOR FOR
		SELECT		'['+ISC.Table_Schema+'].['+ISC.Table_Name+']',
					ISC.Column_Name,
					'ALTER TABLE '+'['+ISC.Table_Schema+'].['+ISC.Table_Name+'] ALTER COLUMN ['+ISC.Column_Name+'] '+
						Coalesce(ISC.Domain_Name,ISC.Data_Type+Coalesce(Case when ISC.Data_Type = 'text' Then '' else NULL END,'('+Case When ISC.Character_Maximum_Length < 0 Then 'Max' Else Cast(ISC.Character_Maximum_Length As nvarchar) END+')'))+
						Case When ISC.Is_Nullable = 'NO' Then ' NOT NULL' Else ' NULL' END
		FROM		@t_ColumnList CL
		JOIN		Information_Schema.Columns ISC
				ON	ISC.Table_Name = CL.Table_Name
				AND	ISC.Column_Name = CL.Column_Name
		ORDER BY	ISC.Table_Name Asc,
					ISC.Column_Name Asc
	OPEN c_Columns
	FETCH NEXT FROM c_Columns INTO @vTableName, @vColumnName, @vSQLStatement
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Changing column '+@vColumnName+' ON table '+@vTableName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Column change of '+@vColumnName+' ON table '+@vTableName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'					'+@vSQLStatement
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Columns INTO @vTableName, @vColumnName, @vSQLStatement
	END
	CLOSE c_Columns
	DEALLOCATE c_Columns

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Re-creating constraints.'
	RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_CreateConstraints CURSOR FOR
		SELECT		Index_Name,
					Create_Statement,
					Is_Primary_Key,
					Is_Foreign_Key
		FROM		@t_IndexList
		ORDER BY	Is_Primary_Key Desc,
					Is_Foreign_Key Asc,
					Index_Name Desc
	OPEN c_CreateConstraints
	FETCH NEXT FROM c_CreateConstraints INTO @vConstraintName, @vSQLStatement, @vIsPrimaryKey, @vIsForeignKey
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Creating constraint '+@vConstraintName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Contraint recreation of '+@vConstraintName+' failed due to "'+Error_Message()+'". ['+@vSQLStatement+']'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_CreateConstraints INTO @vConstraintName, @vSQLStatement, @vIsPrimaryKey, @vIsForeignKey
	END
	CLOSE c_CreateConstraints
	DEALLOCATE c_CreateConstraints

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Recreating routines.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Routines CURSOR FOR
		SELECT		'['+Object_Schema+'].['+Object_Name+']',
					Object_Definition
		FROM		@t_ObjectList
		WHERE		Object_Drop_Statement IS NOT NULL
		ORDER BY	Object_Name
	OPEN c_Routines
	FETCH NEXT FROM c_Routines INTO @vObjectName, @vSQLStatement
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Creating routine '+@vObjectName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Routine recreation of '+@vObjectName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Routines INTO @vObjectName, @vSQLStatement
	END
	CLOSE c_Routines
	DEALLOCATE c_Routines

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Recreating views.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Views CURSOR FOR
		SELECT	'['+View_Schema+'].['+View_Name+']',
				View_Definition
		FROM	@t_ViewList
	OPEN c_Views
	FETCH NEXT FROM c_Views INTO @vObjectName, @vSQLStatement
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			Creating view '+@vObjectName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				View recreation of '+@vObjectName+' failed due to "'+Error_Message()+'".'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Views INTO @vObjectName, @vSQLStatement
	END
	CLOSE c_Views
	DEALLOCATE c_Views

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'		Re-applying permissions ON re-created objects.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT
	DECLARE c_Permissions CURSOR FOR
		SELECT		Object_Name,
					Permission_Grant_Statement,
					Database_Principal,
					Permission_Type,
					Permission_Scope
		FROM		@t_PermissionList
		ORDER BY	Object_Name,
					Database_Principal
	OPEN c_Permissions
	FETCH NEXT FROM c_Permissions INTO @vObjectName, @vSQLStatement, @vPrincipalName, @vPermissionType, @vPermissionScope
	While @@Fetch_Status = 0
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'			'+@vPermissionType+'ing '+Lower(@vPermissionScope)+' permission for '+@vPrincipalName+' ON object '+@vObjectName+'.'
		IF (@SupressInfoMessages = 0) RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		BEGIN TRY
			Exec sp_ExecuteSQL @vSQLStatement
		END TRY
		BEGIN CATCH
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'				Permission setting ON '+@vObjectName+' failed for principal '+@vPrincipalName+' due to "'+Error_Message()+'". ['+@vSQLStatement+']'
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
			SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'					'+@vSQLStatement
			RAISERROR(@vMessage, 0, 1) WITH NOWAIT
		END CATCH
		FETCH NEXT FROM c_Permissions INTO @vObjectName, @vSQLStatement, @vPrincipalName, @vPermissionType, @vPermissionScope
	END
	CLOSE c_Permissions
	DEALLOCATE c_Permissions

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'- '+'	Collation re-definition procedure complete.'
    RAISERROR(@vMessage, 0, 1) WITH NOWAIT

	SET NOCOUNT Off
	RETURN
END
/*
	EXEC [dbo].[ChangeDbObjectCollation]	@CurrentCollation = 'SQL_Latin1_General_CP1_CI_AS',
											@NewCollation = 'Latin1_General_CI_AS',
											@SupressInfoMessages = 0
*/