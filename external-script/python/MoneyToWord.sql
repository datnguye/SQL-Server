--======================================================
-- Usage: To have ability to convert money to text 
--			with utilizing python in SQL
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2020-08-21	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS MoneyToWord
GO
CREATE PROCEDURE [dbo].MoneyToWord	@Money float = 0,--It does not support decimal type unfortunately
									@Lang varchar(3) = 'en'
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @vTemp TABLE (MoneyInText nvarchar(MAX))

	INSERT INTO @vTemp(MoneyInText)
	EXECUTE sp_execute_external_script 
	@language = N'Python',
	@script = N'
from num2words import num2words
import pandas

in_dists = pandas.DataFrame(input)
dists = [str(num2words(number=in_dists.iloc[0].MoneyValue, lang=in_dists.iloc[0].Lang))]
results = pandas.DataFrame(dists)
'
	, @input_data_1 = N'SELECT @vMoneyValue as MoneyValue, @vLang as Lang'
	, @input_data_1_name = N'input'
	, @output_data_1_name = N'results'
	, @params = N'@vMoneyValue float, @vLang varchar(10)'
	, @vMoneyValue = @Money
	, @vLang = @Lang

	SELECT		*
	FROM		@vTemp
	ORDER BY	1
END
GO
/*
1. Install module num2words
EXEC PipInstall @Module = 'num2words'--run once to install num2words pip package

Sample output as below
	2020-08-21 10:10:46.947-	Starting installing python module: num2words
	STDOUT message(s) from external script: 
	3.7.1 (default, Dec 10 2018, 22:54:23) [MSC v.1915 64 bit (AMD64)]
	2020-08-21 10:10:53.977-		PYTHON_SERVICES path: C:\Program Files\Microsoft SQL Server\MSSQL15.DAT19\PYTHON_SERVICES
	2020-08-21 10:10:53.980-		pip command: C: & cd "C:\Program Files\Microsoft SQL Server\MSSQL15.DAT19\PYTHON_SERVICES" & "Scripts\pip.exe" install num2words
	2020-08-21 10:11:03.633-		To remove this module, please try with: C: & cd "C:\Program Files\Microsoft SQL Server\MSSQL15.DAT19\PYTHON_SERVICES" & "Scripts\pip.exe" uninstall num2words
	2020-08-21 10:11:04.137-		SUCCESSFULLY installed: num2words 0.5.10
	2020-08-21 10:11:04.137-	Finished

	Completion time: 2020-08-21T10:11:04.1711011+07:00


2. ENJOY!
	EXEC MoneyToWord @Money = 550001.27
	EXEC MoneyToWord @Money = 550001.27, @Lang = 'vi'
	EXEC MoneyToWord @Money = 550001.27, @Lang = 'th'
*/
