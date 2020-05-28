--======================================================
-- Usage: GetDropIndex - to get CREATE indexes script
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-17	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetDropIndex
GO
CREATE FUNCTION [GetDropIndex] (@ObjectID BIGINT, @ObjectName sysname)
RETURNS nvarchar(max)
AS
BEGIN
	IF (@ObjectName Is NULL) RETURN NULL
	IF NOT EXISTS (SELECT 1 FROM sys.Indexes WHERE Object_ID = @ObjectID) AND NOT EXISTS (SELECT 1 FROM sys.Foreign_Keys WHERE Object_ID = @ObjectID) RETURN NULL
	
	DECLARE @vSQLString nvarchar(max)

	SELECT	@vSQLString = 'ALTER TABLE ['+Table_Schema+'].['+Upper(Table_Name) +'] DROP CONSTRAINT ['+Upper(Constraint_Name)+']'
	FROM	Information_Schema.Table_Constraints TC
	JOIN	sys.Indexes SI
		ON	SI.Name = TC.Constraint_Name
		AND	Object_Schema_Name(SI.Object_ID) = TC.Constraint_Schema
	WHERE	Constraint_Name = @ObjectName
		AND	Object_ID = @ObjectID

	IF (@vSQLString Is NULL)
	BEGIN
		SELECT	@vSQLString = 'DROP INDEX ['+SI.Name +'] ON ['+Object_Schema_Name(SI.Object_ID)+'].['+Object_Name(SI.Object_ID)+']'
		FROM	sys.Indexes SI
		WHERE	SI.Name = @ObjectName
			AND	Object_ID = @ObjectID
	END

	IF (@vSQLString Is NULL)
	BEGIN
		SELECT	@vSQLString = 'ALTER TABLE ['+Object_Schema_Name(FK.Parent_Object_ID)+'].['+Object_Name(FK.Parent_Object_ID)+'] DROP CONSTRAINT ['+FK.Name+']'
		FROM	sys.Foreign_Keys FK
		WHERE	FK.Name = @ObjectName
			AND	Object_ID = @ObjectID
	END
		
	RETURN @vSQLString
END

/*
DROP TABLE IF EXISTS Dummy20200527
GO
CREATE TABLE Dummy20200527 
(
	ID INT NOT NULL PRIMARY KEY,
	Name VARCHAR(255)
)
GO
CREATE INDEX IX_Dummy20200527_Name ON Dummy20200527 (Name) WHERE Name IS NOT NULL 
GO

SELECT	SI.Object_ID,
		SI.Name,
		dbo.GetDropIndex(SI.Object_ID, SI.Name)
FROM	sys.Indexes SI
JOIN	sys.Objects SO
		ON	SO.Object_ID = SI.Object_ID
		AND	SO.Is_MS_Shipped = 0
GO
DROP TABLE IF EXISTS Dummy20200527
GO
*/