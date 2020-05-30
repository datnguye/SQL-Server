--======================================================
-- Usage: To perform pip install command 
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-05-29	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS PipInstall
GO
CREATE PROCEDURE [dbo].PipInstall @Module nvarchar(255)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @vCommand nvarchar(4000)
	DECLARE @vMessage nvarchar(MAX)

	DECLARE @vSystemPath TABLE (SystemPath nvarchar(255))
	DECLARE @vPackageInstalled TABLE (PackageName nvarchar(255))
	DECLARE @vPythonServicePath nvarchar(255)
	DECLARE @vPackageName nvarchar(255)

	--Required options enabled
	DECLARE @vXpCmdShellInfo TABLE (name sysname, minimum int, maximum int, config_value int, run_value int)
	INSERT INTO @vXpCmdShellInfo EXEC sp_configure 'xp_cmdshell'
	IF (SELECT run_value FROM @vXpCmdShellInfo) = 0 
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: xp_cmdshell is being disabled. Please help to run EXEC sp_configure ''xp_cmdshell'', 1'' to fix it.'
		RAISERROR(@vMessage,0,1)

		RETURN -1;
	END

	DECLARE @vExternalScriptEnabledInfo TABLE (name sysname, minimum int, maximum int, config_value int, run_value int)
	INSERT INTO @vExternalScriptEnabledInfo EXEC sp_configure 'external scripts enabled'
	IF (SELECT run_value FROM @vExternalScriptEnabledInfo) = 0 
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: sp_execute_external_script is being disabled. Please help to run EXEC sp_configure ''external scripts enabled'', 1'' to fix it.'
		RAISERROR(@vMessage,0,1)

		RETURN -1;
	END

	--Printing python version	
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Starting installing python module: ' + @Module
	RAISERROR(@vMessage,0,1)
	EXECUTE sp_execute_external_script @language = N'Python'
    , @script = N'
import sys
print(sys.version)'
	
	--Getting SQL Server's PYTHON_SERVICES path
	INSERT
	INTO	@vSystemPath
	EXECUTE sp_execute_external_script 
		@language =N'Python', 
		@script=N'
import sys
import pandas
Results = pandas.DataFrame(sys.path)',
		@output_data_1_name = N'Results'

	SET @vPythonServicePath = 
	(
		SELECT	TOP 1 SystemPath
		FROM	@vSystemPath
		WHERE	SystemPath LIKE '%\PYTHON_SERVICES%'
		ORDER BY 1 
	)
	IF @vPythonServicePath IS NOT NULL
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		PYTHON_SERVICES path: ' + @vPythonServicePath
		RAISERROR(@vMessage,0,1)
	END
	ELSE
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: PYTHON_SERVICES path could not be found!'
		RAISERROR(@vMessage,0,1)

		RETURN -1;
	END

	--Build pip command and run it
	SET @vCommand = LEFT(@vPythonServicePath,2) + ' & cd "' + @vPythonServicePath + '" & "Scripts\pip.exe" install ' + @Module
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		pip command: ' + @vCommand
	RAISERROR(@vMessage,0,1)

	EXEC xp_cmdshell @vCommand, no_output

	SET @vCommand = LEFT(@vPythonServicePath,2) + ' & cd "' + @vPythonServicePath + '" & "Scripts\pip.exe" uninstall ' + @Module
	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		To remove this module, please try with: ' + @vCommand
	RAISERROR(@vMessage,0,1)
	

	--Verify packages installed
	INSERT
	INTO	@vPackageInstalled (PackageName)
	EXECUTE sp_execute_external_script @language = N'Python'
    , @script = N'
import pkg_resources
import pandas
dists = [str(d) for d in pkg_resources.working_set]
Results = pandas.DataFrame(dists)',
		@output_data_1_name = N'Results'

	SELECT	@vPackageName = PackageName 
	FROM	@vPackageInstalled
	WHERE	PackageName LIKE @Module + '%'
	IF @vPackageName IS NOT NULL
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		SUCCESSFULLY installed: ' + @vPackageName
		RAISERROR(@vMessage,0,1)
	END
	ELSE
	BEGIN
		SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-		ERROR: Module has not been installed yet. Please help to try with command in cmd to verify!'
		RAISERROR(@vMessage,0,1)

		RETURN -1;
	END

	SET @vMessage = CONVERT(nvarchar,CURRENT_TIMESTAMP,21)+'-	Finished'
	RAISERROR(@vMessage,0,1)

	RETURN
END
GO
/*
	EXEC PipInstall @Module = 'BeautifulSoup4'
*/

/*
EXEC sp_configure 'external scripts enabled', 1
RECONFIGURE
GO
EXECUTE sp_execute_external_script 
	@language =N'Python', 
	@script=N'
import sys
import pandas
OutputDataSet = pandas.DataFrame(sys.path)',
	@input_data_1 = N''
	WITH RESULT SETS(([RecordText] nvarchar(4000)));

EXECUTE sp_execute_external_script @language = N'Python'
    , @script = N'
import pkg_resources
import pandas
dists = [str(d) for d in pkg_resources.working_set]
OutputDataSet = pandas.DataFrame(dists)'
WITH RESULT SETS(([Package] NVARCHAR(max)))
GO

*/
