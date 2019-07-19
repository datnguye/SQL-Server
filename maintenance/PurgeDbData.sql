--======================================================
-- Usage:	Delete all tables's data and reseed identity
-- Notes:	!!USE WITH CAUTION!!
--			Useful for usage at the development phases
-- Parameters:
--			@ExcludeTablePattern: To excludes tables where name like pattern. Escape character is '\'
--			@ExcludeTables: To exclude tables where name exists. List of values splitted by comma
--			@IncludeTables: To include tables where name exists. List of values splitted by comma
--			@Force: Set to 1 to bypass restrictions
-- History:
-- Date			Author		Description
-- 2019-05-22	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS PurgeDbData
GO
CREATE PROCEDURE PurgeDbData	@ExcludeTablePattern nvarchar(256) = NULL,
								@ExcludeTables nvarchar(MAX) = NULL,
								@IncludeTables nvarchar(MAX) = NULL,
								@Force bit = 0,
								@Debug bit = 0
AS
BEGIN
	DECLARE @vGeneralWhere nvarchar(256)
	DECLARE @vIdentityWhere nvarchar(256)

	SET @vGeneralWhere = CASE WHEN @ExcludeTablePattern IS NOT NULL THEN 'AND o.name NOT LIKE '''+@ExcludeTablePattern+''' ESCAPE ''\''' ELSE '' END
						+ CASE WHEN @ExcludeTables IS NOT NULL THEN ' AND o.name NOT IN (SELECT value FROM STRING_SPLIT('''+@ExcludeTables+''','',''))' ELSE '' END
						+ CASE WHEN @IncludeTables IS NOT NULL THEN ' AND o.name IN (SELECT value FROM STRING_SPLIT('''+@IncludeTables+''','',''))' ELSE '' END
						+ ' AND o.type=''U'''
	IF @Debug = 1 PRINT @vGeneralWhere
	SET @vIdentityWhere = @vGeneralWhere + ' AND EXISTS(SELECT TOP 1 1 FROM [sys].[columns] c WHERE c.object_id = o.id AND c.is_identity = 1)'
	IF @Debug = 1 PRINT @vIdentityWhere

	IF @Force = 0
		AND @ExcludeTablePattern IS NULL
		AND @ExcludeTables IS NULL
		AND @IncludeTables IS NULL
	BEGIN
		SELECT 'Do you intend to purge all data? Use @Force = 1 to do it.' AS Error
		RETURN -1
	END

	BEGIN TRY
		-- disable all the constraints on each table
		EXEC sys.sp_MSforeachtable	@command1 = 'RAISERROR(''Disabling all contstraints on ?.'', 0, 1);',
									@command2 = 'ALTER TABLE ? NOCHECK CONSTRAINT ALL;',
									@whereand = @vGeneralWhere

		-- delete all data in each table
		EXEC sys.sp_MSforeachtable	@command1 = 'RAISERROR(''Deleting all data in ?.'', 0, 1);',
									@command2 = 'SET QUOTED_IDENTIFIER ON; DELETE FROM ?;',
									@whereand = @vGeneralWhere

		-- reseed the identity columns of each table back to their starting values
		EXEC sys.sp_MSforeachtable	@command1 = 'RAISERROR(''Re-Seeding identity columns in ?.'', 0, 1);',
									@command2 = 'SET IDENTITY_INSERT ? OFF;
													DECLARE @seed bigint;
													SELECT	@seed = CASE
																		WHEN last_value IS NULL THEN CAST(seed_value as bigint)
																		ELSE CAST(seed_value as bigint) - CAST(increment_value as bigint) 
																	END
													FROM	[sys].[identity_columns]
													WHERE	[object_id] = object_id(''?'');
													DBCC CHECKIDENT ( ''?'', RESEED, @seed) WITH NO_INFOMSGS;',
									@whereand = @vIdentityWhere

		-- enable all the constraints on each table again
		EXEC sys.sp_MSforeachtable	@command1 = 'RAISERROR(''Enabling all contstraints on ?.'', 0, 1);',
									@command2 = 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL',
									@whereand = @vGeneralWhere
	
	END TRY
	BEGIN CATCH
		SELECT	ERROR_NUMBER() AS ErrorNumber,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_STATE() AS ErrorState,
				ERROR_PROCEDURE() AS ErrorProcedure,
				ERROR_LINE() AS ErrorLine,
				ERROR_MESSAGE() AS ErrorMessage
	END CATCH
END
GO
/*
--Purge all data
BEGIN TRAN 
	EXEC PurgeDbData @Debug = 1, @Force = 1
ROLLBACK

--Purge data excluding somes
BEGIN TRAN 
	--EXEC PurgeDbData @ExcludeTablePattern = '\_%' --exclude tables where prefixed by underscore
	--EXEC PurgeDbData @ExcludeTables = 'User,Role' --exclude tables: Role, User
	EXEC PurgeDbData @IncludeTables = 'User' --delete User table data
ROLLBACK

*/