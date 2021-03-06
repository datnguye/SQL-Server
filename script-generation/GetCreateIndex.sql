--======================================================
-- Usage: GetCreateIndex - to get CREATE indexes script
-- Notes: 
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-05-17	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetCreateIndex
GO
CREATE FUNCTION [GetCreateIndex] (@ObjectID BIGINT, @ObjectName sysname)
RETURNS nvarchar(max)
AS
BEGIN
	IF (@ObjectID IS NULL) RETURN NULL
	IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE Object_ID = @ObjectID) AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE Object_ID = @ObjectID) RETURN NULL
	
	DECLARE @vSQLString nvarchar(max)

	IF (ObjectProperty(@ObjectID,'IsForeignKey') = 1)
	BEGIN
		SELECT	@vSQLString = 'ALTER TABLE ['+OBJECT_SCHEMA_NAME(FK.Parent_Object_ID)+'].['+UPPER(OBJECT_NAME(FK.Parent_Object_ID)) +'] ADD CONSTRAINT ['+UPPER(FK.Name)+'] '+
				'FOREIGN KEY ('
		FROM	sys.foreign_keys FK
		WHERE	FK.Object_ID = @ObjectID
			AND	FK.Name = @ObjectName

		SELECT		@vSQLString+='['+C.Name+'],'
		FROM		sys.foreign_keys FK
		JOIN		sys.Foreign_Key_Columns FKC
				ON	FKC.Constraint_Object_ID = FK.Object_ID
		JOIN		sys.Columns C
				ON	C.Object_ID = FKC.Parent_Object_ID
				AND	C.Column_ID = FKC.Parent_Column_ID
		WHERE		FK.Object_ID = @ObjectID
				AND	FK.Name = @ObjectName
		ORDER BY	FKC.Referenced_Column_ID

		SELECT	@vSQLString = LEFT(@vSQLString,LEN(@vSQLString)-1)+') REFERENCES ['+OBJECT_SCHEMA_NAME(FK.Referenced_Object_ID)+'].['+UPPER(OBJECT_NAME(FK.Referenced_Object_ID)) +'] ('
		FROM	sys.foreign_keys FK
		WHERE	FK.Object_ID = @ObjectID
			AND	FK.Name = @ObjectName

		SELECT		@vSQLString+='['+C.Name+'],'
		FROM		sys.foreign_keys FK
		JOIN		sys.Foreign_Key_Columns FKC
				ON	FKC.Constraint_Object_ID = FK.Object_ID
		JOIN		sys.Columns C
				ON	C.Object_ID = FKC.Referenced_Object_ID
				AND	C.Column_ID = FKC.Referenced_Column_ID
		WHERE		FK.Object_ID = @ObjectID
				AND	FK.Name = @ObjectName
		ORDER BY	FKC.Referenced_Column_ID
		SET @vSQLString =LEFT(@vSQLString,LEN(@vSQLString)-1)+')'
		
	END
	ELSE
	BEGIN
		SELECT	@vSQLString = 'ALTER TABLE ['+Table_Schema+'].['+UPPER(Table_Name) +'] ADD CONSTRAINT ['+UPPER(Constraint_Name)+'] '+
				Constraint_Type + ' '+SI.Type_Desc+' ('
		FROM	Information_Schema.Table_Constraints TC
		JOIN	sys.indexes SI
			ON	SI.Name = TC.Constraint_Name
			AND	OBJECT_SCHEMA_NAME(SI.Object_ID) = TC.Constraint_Schema
		WHERE	SI.Object_ID = @ObjectID
			AND	SI.Name = @ObjectName

		IF (@vSQLString IS NULL)
		BEGIN
			SELECT	@vSQLString = 'CREATE '+SI.Type_Desc Collate SQL_Latin1_General_CP1_CI_AS+' INDEX ['+SI.Name Collate SQL_Latin1_General_CP1_CI_AS+'] ON ['+SS.Name Collate SQL_Latin1_General_CP1_CI_AS+'].['+SO.Name Collate SQL_Latin1_General_CP1_CI_AS+'] ('
			FROM	sys.indexes SI
			JOIN	sys.Objects SO
				ON	SO.Object_ID = SI.Object_ID
			JOIN	sys.SchemAS SS
				ON	SS.Schema_ID = SO.Schema_ID
			WHERE	SI.Object_ID = @ObjectID
				AND	SI.Name = @ObjectName
			
		END
		
		SELECT		@vSQLString+= '['+SC.Name+']' + CASE WHEN SIC.Is_Descending_Key = 1 THEN ' DESC' ELSE '' END + ','
		FROM		sys.indexes SI
		JOIN		sys.Index_Columns SIC
				ON	SIC.Object_ID = SI.Object_ID
				AND	SIC.Index_ID = SI.Index_ID
				AND	SIC.Is_Included_Column = 0
		JOIN		sys.Columns SC
				ON	SC.Object_ID = SI.Object_ID
				AND	SC.Column_ID = SIC.Column_ID
		WHERE		SI.Object_ID = @ObjectID
				AND	SI.Name = @ObjectName
		ORDER BY	SIC.Index_Column_ID
		
		SET @vSQLString =LEFT(@vSQLString,LEN(@vSQLString)-1)+')'

		IF EXISTS (	SELECT	1
					FROM	sys.indexes SI
					JOIN	sys.Index_Columns SIC
						ON	SIC.Object_ID = SI.Object_ID
						AND	SIC.Index_ID = SI.Index_ID
						AND	SIC.Is_Included_Column = 1
					JOIN	sys.Columns SC
						ON	SC.Object_ID = SI.Object_ID
						AND	SC.Column_ID = SIC.Column_ID
					WHERE	SI.Object_ID = @ObjectID
						AND	SI.Name = @ObjectName)
		BEGIN
			SET @vSQLString+= ' INCLUDE ('
			SELECT		@vSQLString+= '['+SC.Name+']' + ','
			FROM		sys.indexes SI
			JOIN		sys.Index_Columns SIC
					ON	SIC.Object_ID = SI.Object_ID
					AND	SIC.Index_ID = SI.Index_ID
					AND	SIC.Is_Included_Column = 1
			JOIN		sys.Columns SC
					ON	SC.Object_ID = SI.Object_ID
					AND	SC.Column_ID = SIC.Column_ID
			WHERE		SI.Object_ID = @ObjectID
					AND	SI.Name = @ObjectName
			ORDER BY	SIC.Index_Column_ID

			SET @vSQLString =LEFT(@vSQLString,LEN(@vSQLString)-1)+')'

		END
		
		SELECT		@vSQLString+=	COALESCE(' WHERE '+SI.Filter_Definition,'')+' WITH (PAD_INDEX='+CASE WHEN SI.Is_Padded = 1 THEN 'ON' ELSE 'OFF' END+
									', STATISTICS_NORECOMPUTE='+CASE WHEN SS.No_Recompute = 1 THEN 'ON' ELSE 'OFF' END+
									', SORT_IN_TEMPDB=OFF'+
									', IGNORE_DUP_KEY='+CASE WHEN SI.Ignore_Dup_Key = 1 THEN 'ON' ELSE 'OFF' END+
									', ONLINE=OFF'+
									', ALLOW_ROW_LOCKS='+CASE WHEN SI.Allow_Row_Locks = 1 THEN 'ON' ELSE 'OFF' END+
									', ALLOW_PAGE_LOCKS='+CASE WHEN SI.Allow_Page_Locks = 1 THEN 'ON' ELSE 'OFF' END+
									CASE WHEN SI.Fill_Factor > 0 THEN ', FILLFACTOR='+CASt(SI.Fill_Factor AS nvarchar(3)) ELSE '' END+
									') ON ['+UPPER(FG.Name)+']'
		FROM		sys.indexes SI
		JOIN		sys.FileGroups FG
				ON	FG.Data_Space_ID = SI.Data_Space_ID
		LEFT JOIN	(
						SELECT		SS.Object_ID,
									MAX(CASt(No_Recompute AS int)) AS No_Recompute
						FROM		sys.Stats SS
						GROUP BY	SS.Object_ID
					) SS
				ON	SS.Object_ID = SI.Object_ID
		WHERE		SI.Object_ID = @ObjectID
				AND	SI.Name = @ObjectName
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
		dbo.GetCreateIndex(SI.Object_ID, SI.Name)
FROM	sys.Indexes SI
JOIN	sys.Objects SO
		ON	SO.Object_ID = SI.Object_ID
		AND	SO.Is_MS_Shipped = 0
GO
DROP TABLE IF EXISTS Dummy20200527
GO
*/