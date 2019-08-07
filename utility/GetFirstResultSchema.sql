--================================================================================
-- Usage: GetFirstResultSchema - to get schema's first result returned from SQL
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-07-08	DN			Intial
--================================================================================
DROP PROCEDURE IF EXISTS GetFirstResultSchema
GO
CREATE PROCEDURE GetFirstResultSchema @TSql nvarchar(max)
AS
BEGIN
	EXEC sp_describe_first_result_set @tsql = @TSql

	RETURN
END
GO
/*
	EXEC dbo.GetFirstResultSchema 'SELECT * FROM sys.tables'
*/