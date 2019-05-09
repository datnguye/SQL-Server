--======================================================
-- Usage: DoQueryStore
-- Notes: 
-- History:
-- Date			Author		Description
-- 2019-05-09	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS dbo.DoQueryStore
GO
CREATE PROCEDURE dbo.DoQueryStore	@QueryID bigint = NULL,
									@RemoveQuery Bit = 0,
									@SearchPattern nvarchar(256) = NULL,
									@Count Int = 100
AS
BEGIN
	--Bring in-memory data into disk
	EXEC sp_query_store_flush_db;

	--Select into temp table with minimal log
	SELECT		TOP (@Count)
				q.query_id,
				qt.query_text_id,
				qt.query_sql_text,
				p.plan_id,
				p.query_plan,
				q.initial_compile_start_time,
				q.last_compile_start_time
	INTO		#temp
	FROM		sys.query_store_query AS q  
	JOIN		sys.query_store_query_text AS qt  
		ON		q.query_text_id = qt.query_text_id
	LEFT JOIN	sys.query_store_plan AS p  
		ON		p.query_id = q.query_id  
	WHERE		(@QueryID IS NULL OR q.query_id = @QueryID)
		AND		(@SearchPattern IS NULL OR qt.query_sql_text LIKE @SearchPattern)
	ORDER BY	q.last_compile_start_time DESC

	--SELECT ACTION
	IF @RemoveQuery = 0 
	BEGIN 
		SELECT		*
		FROM		#temp
		ORDER BY	last_compile_start_time DESC
	END
	
	--REMOVE ACTION
	IF @RemoveQuery = 1
	BEGIN 
		DECLARE @vSQL varchar(4000) = ''
		DECLARE @vQueryId bigint

		DECLARE c_temp CURSOR FOR 
			SELECT DISTINCT t.query_id FROM #temp t
		OPEN c_temp

		FETCH NEXT FROM c_temp INTO @vQueryId
		WHILE @@FETCH_STATUS = 0
		BEGIN
			PRINT 'EXEC sp_query_store_remove_query @query_id = ' + Convert(varchar,@vQueryId)
			EXEC sp_query_store_remove_query @query_id = @vQueryId
			
			FETCH NEXT FROM c_temp INTO @vQueryId
		END

		CLOSE c_temp
		DEALLOCATE c_temp
	END

	RETURN;
END
GO

/*
--Select all
EXECUTE dbo.DoQueryStore
--Select specific
EXECUTE dbo.DoQueryStore @QueryID = ?
--Select with search patern
EXECUTE dbo.DoQueryStore @SearchPattern = '?'
EXECUTE dbo.DoQueryStore @SearchPattern = N'?'

--Remove all
EXECUTE dbo.DoQueryStore @RemoveQuery = 1
--Remove specific
EXECUTE dbo.DoQueryStore @QueryID = ?, @RemoveQuery = 1

*/