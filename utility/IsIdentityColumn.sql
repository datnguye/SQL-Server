--======================================================
-- Usage: IsIdentityColumn - to return if an identity column
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-06-24	DN			Intial
--======================================================
DROP FUNCTION IF EXISTS IsIdentityColumn
GO
CREATE FUNCTION IsIdentityColumn 
(
	@Schema sysname = 'dbo',
	@Table sysname,
	@Column sysname
)
RETURNS BIT
AS
BEGIN
	RETURN COALESCE(COLUMNPROPERTY(OBJECT_ID(@Schema+'.'+@Table),@Column,'IsIdentity'),0)
END

/*
	SELECT dbo.IsIdentityColumn(default, 'Base01','ID')
	SELECT dbo.IsIdentityColumn(default, 'Base02','ID')
*/