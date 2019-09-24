--======================================================
-- Usage: GetFakeJson - to get fake data in json format
-- Dependencies: 
--			Function string/GetRandomSentence
--			Function utility/GetRandomNumber
--			Function utility/GetRandomDate
-- Notes: From SQL 2016
-- Parameters:
-- History:
-- Date			Author		Description
-- 2019-09-20	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS GetFakeJson
GO
CREATE PROCEDURE GetFakeJson	@Fields nvarchar(max) /*'Field1, Field2, Field3, Field4'*/,
								@FieldTypes nvarchar(max) /*'Number, String, Date, Bit'*/,
								@FieldLengths nvarchar(max) = NULL /*'null, 10, null, null' --null used for other type than string*/,
								@NoRecord INT = 10,
								@Debug BIT = 0
AS
BEGIN
	SET NOCOUNT ON
	--
	DROP TABLE IF EXISTS ##tResult
	CREATE TABLE ##tResult (dummy BIT)

	--Constants
	DECLARE @DefaultStringLength varchar(2) = '10'

	--Variables
	DECLARE @vSQL nvarchar(max)
	DECLARE @vInsertSQL nvarchar(max)
	DECLARE @vFields TABLE (Idx INT, Name nvarchar(255))
	DECLARE @vTypes TABLE (Idx INT, Name nvarchar(255))
	DECLARE @vLengths TABLE (Idx INT, Name nvarchar(255))
	DECLARE @vFieldName nvarchar(255)
	DECLARE @vFieldType nvarchar(255)
	DECLARE @vFieldLength INT
	DECLARE @vFieldTypeCalculated nvarchar(255)
	DECLARE @vLoop INT = 1

	INSERT INTO @vFields SELECT ROW_NUMBER() OVER (ORDER BY GETDATE()), VALUE FROM STRING_SPLIT(@Fields, ',')
	INSERT INTO @vTypes SELECT ROW_NUMBER() OVER (ORDER BY GETDATE()), VALUE FROM STRING_SPLIT(@FieldTypes, ',')
	INSERT INTO @vLengths SELECT ROW_NUMBER() OVER (ORDER BY GETDATE()), VALUE FROM STRING_SPLIT(@FieldLengths, ',')

	--CREATE table containing fake data
	SET @vInsertSQL = 'INSERT INTO ##tResult (' + @Fields + ') SELECT '
	DECLARE cField CURSOR FOR
		SELECT		F.Name as FieldName,
					COALESCE(T.Name, 'String') as FieldType,
					CASE COALESCE(T.Name, 'String')
						WHEN 'Date' THEN 'date'
						WHEN 'Number' THEN 'int'
						WHEN 'Bit' THEN 'bit'
						ELSE 'nvarchar(255)'--default to string
					END as FieldTypeCalculated,
					CONVERT(INT,COALESCE(NULLIF(L.Name,'null'),@DefaultStringLength)) as FieldLength
		FROM		@vFields F
		LEFT JOIN	@vTypes T
			ON		T.Idx = F.Idx
		LEFT JOIN	@vLengths L
			ON		L.Idx = F.Idx

	OPEN cField
	FETCH NEXT FROM cField INTO @vFieldName, @vFieldType, @vFieldTypeCalculated, @vFieldLength
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @vSQL = 'ALTER TABLE ##tResult ADD ' + QUOTENAME(@vFieldName) + ' ' + @vFieldTypeCalculated
		IF @Debug = 1 PRINT @vSQL
		SET @vInsertSQL += CASE @vFieldType
								WHEN 'Number' THEN 'dbo.GetRandomNumber(255),'
								WHEN 'Date' THEN 'dbo.GetRandomDate(),'
								WHEN 'Bit' THEN 'dbo.GetRandomNumber(2),'
								ELSE 'LEFT(dbo.GetRandomSentence('+ CONVERT(varchar, ABS(CHECKSUM(RAND()))%5+1) +'), ' + CONVERT(varchar,@vFieldLength) + '),'
							END
		EXEC(@vSQL)
	
		FETCH NEXT FROM cField INTO @vFieldName, @vFieldType, @vFieldTypeCalculated, @vFieldLength
	END
	CLOSE cField
	DEALLOCATE cField

	--INSERT fake data
	IF @Debug = 1 PRINT @vInsertSQL
	SET @vInsertSQL = LEFT(@vInsertSQL, LEN(@vInsertSQL)-1)
	WHILE @vLoop < @NoRecord
	BEGIN
		EXEC(@vInsertSQL)
		SET @vLoop = @vLoop + 1
	END

	--REMOVE dummy column
	ALTER TABLE ##tResult DROP COLUMN dummy;

	--RESULT HERE--
	IF @Debug = 1 SELECT *FROM ##tResult
	SELECT	*
	FROM	##tResult FOR JSON AUTO, INCLUDE_NULL_VALUES

	RETURN
END

/*
	EXEC dbo.GetFakeJson	@Fields = 'Make,Model,Dealership,Yard,SalesPerson,Phone,WalkIn,Email,Other,Total,TestDrives,TestDrivesCount,TestDriveConversion,TestDrivePhoneConversion,TestDriveWalkInConversion,TestDriveEmailConversion,TestDriveOtherConversion,Sales,SalesConversion,SalesPhoneConversion,SalesWalkInConversion,SalesEmailConversion,SalesOtherConversion',
							@FieldTypes = 'Number,String,String,Date,Bit,String,String,String,String,String,String,String,Date,String,String,String,String,String,Number,String,String,String,Bit',
							--@FieldLengths = 'null,30',
							@Debug = 1
							
	EXEC dbo.GetFakeJson	@Fields = 'Make,Model,Dealership,Yard,SalesPerson,Phone,WalkIn,Email,Other,Total,TestDrives,TestDrivesCount,TestDriveConversion,TestDrivePhoneConversion,TestDriveWalkInConversion,TestDriveEmailConversion,TestDriveOtherConversion,Sales,SalesConversion,SalesPhoneConversion,SalesWalkInConversion,SalesEmailConversion,SalesOtherConversion',
							@FieldTypes = 'Number,String,String,Date,Bit,String,String,String,String,String,String,String,Date,String,String,String,String,String,Number,String,String,String,Bit',
							@Debug = 0
*/
