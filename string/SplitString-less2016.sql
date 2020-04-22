--=============================================================================================================================================
-- Usage: This is to split string into pieces (supporting earlier 2016
-- Notes: 
-- History:
-- Date			By			Description
-- 2020-04-22	DN			Created.
--=============================================================================================================================================
--use CTUser
IF OBJECT_ID('StringSplit', 'IF') IS NOT NULL
	DROP FUNCTION dbo.StringSplit  
GO


CREATE FUNCTION [dbo].[StringSplit] 
(    
	@Text nvarchar(4000),  
	@Delimiter char(1)
) 
RETURNS TABLE   
AS 
	RETURN     
	WITH E1(N) AS   
	(  
		SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL  
		SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL  
		SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1  
	) --10E+1 or 10 rows  
	,E2(N) AS 
	(
		SELECT 1 FROM E1 a, E1 b
	) --10E+2 or 100 rows  
	,E4(N) AS 
	(
		SELECT 1 FROM E2 a, E2 b
	) --10E+4 or 10,000 rows max  
	,cteTally(N) AS   
	(  
		--==== This provides the "base" CTE and limits the number of rows right up front  
		-- for both a performance gain and prevention of accidental "overruns"  
		SELECT TOP (ISNULL(LEN(@Text),0)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM E4  
	)  
	,cteStart(N1) AS   
	(  
		--==== This returns N+1 (starting position of each "element" just once for each delimiter)  
		SELECT 1 UNION ALL  
		SELECT t.N+1 FROM cteTally t WHERE SUBSTRING(@Text,t.N,1) = @Delimiter
	)  
	,cteLen(N1,L1) AS  
	(  
		--==== Return start and length (for use in substring)  
		SELECT	s.N1,
				ISNULL(NULLIF(CHARINDEX(@Delimiter,@Text,s.N1),0)-s.N1,8000)  
		FROM	cteStart s  
	)  
	SELECT	SUBSTRING(@Text, l.N1, l.L1) [Value]  
	FROM	cteLen l  
	WHERE	SUBSTRING(@Text, l.N1, l.L1) != ''  
GO
/*
	SELECT * FROM dbo.StringSplit('sql1,sql2', ',')
*/