--=========================================================================================================
-- Usage:	This is to create a SQL login with reader right and can view only assigned database in a instance
-- Notes:	USE WITH CAUTION: it drops server login by default
--			Must have grantor login to run this sproc
-- History:
-- Date			Author		Description
-- 2019-05-21	DN			Intial
--==========================================================================================================
--use master;
DROP PROCEDURE IF EXISTS CreateReaderDBU
GO

CREATE PROCEDURE CreateReaderDBU	@LoginName sysname,
											@LoginPassword sysname,
											@AssignedToDatabase sysname,
											@DropLoginIfExists bit = 1,
											@Debug bit = 0	--1 to return script content only
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @vSQL nvarchar(4000) = ''
	DECLARE @EndLiner varchar(2) = char(10)
	
	--Drop database user if exists
	SET @vSQL +=	'use [{dbname}];'+@EndLiner
	SET @vSQL +=	'IF EXISTS ( SELECT TOP 1 1 FROM sys.sysusers WHERE name = ''{loginname}'' AND islogin = 1)'+@EndLiner
	SET @vSQL +=	'BEGIN'+@EndLiner
	SET @vSQL +=	'	DROP USER {loginname}'+@EndLiner
	SET @vSQL +=	'END;'+@EndLiner


	--Drop server login if exists
	IF @DropLoginIfExists = 1
	BEGIN
		SET @vSQL +=	'use master;'+@EndLiner
		SET @vSQL +=	'IF EXISTS ( SELECT TOP 1 1 FROM sys.syslogins WHERE name = ''{loginname}'' AND dbname = ''{dbname}'')'+@EndLiner
		SET @vSQL +=	'BEGIN'+@EndLiner
		SET @vSQL +=	'	DROP LOGIN {loginname}'+@EndLiner
		SET @vSQL +=	'END;'+@EndLiner
	END

	--Create server login (set default database and deny view any database)
	IF @DropLoginIfExists = 1
	BEGIN
		SET @vSQL +=	'use master;'+@EndLiner
		SET @vSQL +=	'CREATE LOGIN {loginname} WITH PASSWORD = ''{loginpassword}'', DEFAULT_DATABASE=[{dbname}], CHECK_POLICY = OFF;'+@EndLiner
		SET @vSQL +=	'DENY VIEW ANY DATABASE TO {loginname};'+@EndLiner
	END

	--Create database user and database role
	SET @vSQL +=	'use [{dbname}];'+@EndLiner
	SET @vSQL +=	'CREATE USER {loginname} FOR LOGIN {loginname};'+@EndLiner
	SET @vSQL +=	'ALTER ROLE db_datareader ADD MEMBER {loginname};'+@EndLiner


	--INPUT
	SET @vSQL = REPLACE(REPLACE(REPLACE(
					@vSQL,
						'{loginname}',@LoginName),
						'{loginpassword}',@LoginPassword),
						'{dbname}',@AssignedToDatabase)

	--OUTPUT / RESULT
	IF @Debug = 0
	BEGIN
		BEGIN TRY
			EXEC(@vSQL)
			SELECT @LoginName AS CreatedUser, @LoginPassword AS [Password], @AssignedToDatabase AS [Database]
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
	ELSE
	BEGIN
		PRINT @vSQL
	END

	RETURN;
END
GO
/*
	EXEC CreateReaderDBU @LoginName = 'test02', @LoginPassword = 'test02pwd', @AssignedToDatabase = 'Test', @Debug = 1
	EXEC CreateReaderDBU @LoginName = 'test02', @LoginPassword = 'test02pwd', @AssignedToDatabase = 'Test', @Debug = 0
*/