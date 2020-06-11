--======================================================
-- Usage: ApiCovid19
-- Notes: Practical exercise of API.sql
--		CAUTION!! This is scripted inside with real tables DROP and CREATE
-- History:
-- Date			Author		Description
-- 2020-06-11	DN			Intial
--======================================================
DROP PROCEDURE IF EXISTS [dbo].ApiCovid19
GO
CREATE PROCEDURE [dbo].ApiCovid19	@Url varchar(8000) = 'https://api.covid19api.com', 
									@Method varchar(5) = 'GET',--POST
									@ContentType varchar(255) = 'application/json'--'application/xml'
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @vWin int --token of WinHttp object
    DECLARE @vReturnCode int 
    DECLARE @tResponse TABLE (ResponseText nvarchar(max))
    DECLARE @vResponse nvarchar(max)

	--Creates an instance of WinHttp.WinHttpRequest
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/winhttp-versions
	--Version of 5.0 is no longer supported
    EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
    IF @vReturnCode <> 0 GOTO EXCEPTION

	--Opens an HTTP connection to an HTTP resource.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-open
    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @Url /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 GOTO EXCEPTION

	IF @ContentType IS NOT NULL
	BEGIN
		EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
		IF @vReturnCode <> 0 GOTO EXCEPTION
	END

	--Sends an HTTP request to an HTTP server.
	--Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
	EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
	IF @vReturnCode <> 0 GOTO EXCEPTION

	--Get Response text
	--Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
	INSERT INTO @tResponse (ResponseText) 
	EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
    IF @vReturnCode <> 0 GOTO EXCEPTION

	IF @vReturnCode = 0 
		GOTO RESULT

	EXCEPTION:
		BEGIN
			DECLARE @tException TABLE
			(
				Error binary(4),
				Source varchar(8000),
				Description varchar(8000),
				HelpFile varchar(8000),
				HelpID varchar(8000)
			)

			INSERT INTO @tException EXEC sp_OAGetErrorInfo @vWin
			INSERT
			INTO	@tResponse
			(
					ResponseText
			)
			SELECT	( 
						SELECT	*
						FROM	@tException
						FOR		JSON AUTO
					) AS ResponseText
		END

	--FINALLY
	RESULT:

	--Crawling Routes
	SELECT	@vResponse = ResponseText
	FROM	@tResponse
	
	DROP TABLE IF EXISTS ApiCovid19Route
	CREATE TABLE ApiCovid19Route
	(
		RouteName nvarchar(255),
		Name nvarchar(255),
		Description nvarchar(4000),
		Path nvarchar(255)
	)

	INSERT
	INTO	ApiCovid19Route
    SELECT	N'allRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.allRoute.Name', Description nvarchar(4000) N'$.allRoute.Description', Path nvarchar(255) N'$.allRoute.Path')
	UNION ALL	
    SELECT	N'countriesRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countriesRoute.Name', Description nvarchar(4000) N'$.countriesRoute.Description', Path nvarchar(255) N'$.countriesRoute.Path')
	UNION ALL	
    SELECT	N'countryDayOneRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryDayOneRoute.Name', Description nvarchar(4000) N'$.countryDayOneRoute.Description', Path nvarchar(255) N'$.countryDayOneRoute.Path')
	UNION ALL	
    SELECT	N'countryDayOneTotalRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryDayOneTotalRoute.Name', Description nvarchar(4000) N'$.countryDayOneTotalRoute.Description', Path nvarchar(255) N'$.countryDayOneTotalRoute.Path')
	UNION ALL	
    SELECT	N'countryRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryRoute.Name', Description nvarchar(4000) N'$.countryRoute.Description', Path nvarchar(255) N'$.countryRoute.Path')
	UNION ALL
    SELECT	N'countryStatusDayOneLiveRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusDayOneLiveRoute.Name', Description nvarchar(4000) N'$.countryStatusDayOneLiveRoute.Description', Path nvarchar(255) N'$.countryStatusDayOneLiveRoute.Path')
	UNION ALL
    SELECT	N'countryStatusDayOneRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusDayOneRoute.Name', Description nvarchar(4000) N'$.countryStatusDayOneRoute.Description', Path nvarchar(255) N'$.countryStatusDayOneRoute.Path')
	UNION ALL		
    SELECT	N'countryStatusDayOneTotalRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusDayOneTotalRoute.Name', Description nvarchar(4000) N'$.countryStatusDayOneTotalRoute.Description', Path nvarchar(255) N'$.countryStatusDayOneTotalRoute.Path')
	UNION ALL		
    SELECT	N'countryStatusLiveRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusLiveRoute.Name', Description nvarchar(4000) N'$.countryStatusLiveRoute.Description', Path nvarchar(255) N'$.countryStatusLiveRoute.Path')
	UNION ALL		
    SELECT	N'countryStatusRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusRoute.Name', Description nvarchar(4000) N'$.countryStatusRoute.Description', Path nvarchar(255) N'$.countryStatusRoute.Path')
	UNION ALL		
    SELECT	N'countryStatusTotalRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryStatusTotalRoute.Name', Description nvarchar(4000) N'$.countryStatusTotalRoute.Description', Path nvarchar(255) N'$.countryStatusTotalRoute.Path')
	UNION ALL		
    SELECT	N'countryTotalRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.countryTotalRoute.Name', Description nvarchar(4000) N'$.countryTotalRoute.Description', Path nvarchar(255) N'$.countryTotalRoute.Path')
	UNION ALL		
    SELECT	N'exportRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.exportRoute.Name', Description nvarchar(4000) N'$.exportRoute.Description', Path nvarchar(255) N'$.exportRoute.Path')
	UNION ALL		
    SELECT	N'liveCountryRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.liveCountryRoute.Name', Description nvarchar(4000) N'$.liveCountryRoute.Description', Path nvarchar(255) N'$.liveCountryRoute.Path')
	UNION ALL		
    SELECT	N'liveCountryStatusAfterDateRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.liveCountryStatusAfterDateRoute.Name', Description nvarchar(4000) N'$.liveCountryStatusAfterDateRoute.Description', Path nvarchar(255) N'$.liveCountryStatusAfterDateRoute.Path')
	UNION ALL		
    SELECT	N'liveCountryStatusRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.liveCountryStatusRoute.Name', Description nvarchar(4000) N'$.liveCountryStatusRoute.Description', Path nvarchar(255) N'$.liveCountryStatusRoute.Path')
	UNION ALL		
    SELECT	N'summaryRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.summaryRoute.Name', Description nvarchar(4000) N'$.summaryRoute.Description', Path nvarchar(255) N'$.summaryRoute.Path')
	UNION ALL		
    SELECT	N'webhookRoute' as RouteName,Name,Description,Path
	FROM	OPENJSON(@vResponse)
	WITH	(Name nvarchar(255)	N'$.webhookRoute.Name', Description nvarchar(4000) N'$.webhookRoute.Description', Path nvarchar(255) N'$.webhookRoute.Path')
	
	--Crawling COuntries	
	DROP TABLE IF EXISTS ApiCovid19Countries
	CREATE TABLE ApiCovid19Countries
	(
		Country nvarchar(255),
		Slug nvarchar(255),
		ISO2 varchar(2)
	)

	DECLARE @vRoute nvarchar(255)
	SELECT	@vRoute = @Url + Path 
	FROM	ApiCovid19Route
	WHERE	RouteName = 'countriesRoute'
	PRINT 'GET ' + @vRoute

    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @vRoute /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 GOTO EXCEPTION
	EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
	IF @vReturnCode <> 0 GOTO EXCEPTION
	EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
	IF @vReturnCode <> 0 GOTO EXCEPTION
	DELETE FROM @tResponse
	INSERT INTO @tResponse (ResponseText) 
	EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
    IF @vReturnCode <> 0 GOTO EXCEPTION
	SELECT	@vResponse = ResponseText
	FROM	@tResponse

	INSERT
	INTO	ApiCovid19Countries
    SELECT	Country,Slug,ISO2
	FROM	OPENJSON(@vResponse)
	WITH	(Country nvarchar(255)	N'$.Country', Slug nvarchar(255) N'$.Slug', ISO2 varchar(2) N'$.ISO2')

	--Crawling countryDayOneRoute	
	DECLARE @vCountry nvarchar(255)
	DROP TABLE IF EXISTS ApiCovid19CountryDayOne
	CREATE TABLE ApiCovid19CountryDayOne
	(
		Country nvarchar(255),
		CountryCode varchar(10),
		Province nvarchar(255),
		City nvarchar(255),
		CityCode nvarchar(255),
		Lat decimal(10,7),
		Lon decimal(10,7),
		Confirmed decimal(17,2),
		Deaths decimal(17,2),
		Recovered decimal(17,2),
		Active decimal(17,2),
		Date DateTime
	)
	Declare c CURSOR FOR
		SELECT		Slug
		FROM		ApiCovid19Countries
		ORDER BY	1 
	OPEN c
	FETCH NEXT FROM c INTO @vCountry
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT	TOP 1 @vRoute = @Url + LEFT(Path, CHARINDEX(':',Path,1)-1) + @vCountry
			FROM	ApiCovid19Route
			WHERE	RouteName = 'countryDayOneRoute'
			PRINT 'GET ' + @vRoute

			EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @vRoute /*Url*/, 'false' /*IsAsync*/
			IF @vReturnCode <> 0 GOTO EXCEPTION
			EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
			IF @vReturnCode <> 0 GOTO EXCEPTION
			EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
			IF @vReturnCode <> 0 GOTO EXCEPTION
			DELETE FROM @tResponse
			INSERT INTO @tResponse (ResponseText) 
			EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
			IF @vReturnCode <> 0 GOTO EXCEPTION
			SELECT	@vResponse = ResponseText
			FROM	@tResponse

			INSERT
			INTO	ApiCovid19CountryDayOne
		    SELECT	Country,CountryCode,Province,City,CityCode,Lat,Lon,Confirmed,Deaths,Recovered,Active,Date
			FROM	OPENJSON(@vResponse)
			WITH	(
						Country nvarchar(255)		N'$.Country',
						CountryCode varchar(10)		N'$.CountryCode',
						Province nvarchar(255)		N'$.Province',
						City nvarchar(255)			N'$.City',
						CityCode nvarchar(255)		N'$.CityCode',
						Lat decimal(10,7)			N'$.Lat',
						Lon decimal(10,7)			N'$.Lon',
						Confirmed decimal(17,2)		N'$.Confirmed',
						Deaths decimal(17,2)		N'$.Deaths',
						Recovered decimal(17,2)		N'$.Recovered',
						Active decimal(17,2)		N'$.Active',
						Date DateTime				N'$.Date'
					)


			FETCH NEXT FROM c INTO @vCountry
		END
	CLOSE c
	DEALLOCATE c 

	--Crawling summaryRoute	
	DROP TABLE IF EXISTS ApiCovid19Summary
	CREATE TABLE ApiCovid19Summary
	(
		Country nvarchar(255),
		CountryCode varchar(2),
		Slug nvarchar(255),
		NewConfirmed INT,
		TotalConfirmed INT,
		NewDeaths INT,
		TotalDeaths INT,
		NewRecovered INT,
		TotalRecovered INT,
		Date DATETIME
	)

	SET @vRoute = ''
	SELECT	@vRoute = @Url + Path 
	FROM	ApiCovid19Route
	WHERE	RouteName = 'summaryRoute'
	PRINT 'GET ' + @vRoute

    EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @vRoute /*Url*/, 'false' /*IsAsync*/
    IF @vReturnCode <> 0 GOTO EXCEPTION
	EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-Type', @ContentType
	IF @vReturnCode <> 0 GOTO EXCEPTION
	EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
	IF @vReturnCode <> 0 GOTO EXCEPTION
	DELETE FROM @tResponse
	INSERT INTO @tResponse (ResponseText) 
	EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
    IF @vReturnCode <> 0 GOTO EXCEPTION
	SELECT	@vResponse = ResponseText
	FROM	@tResponse

	INSERT
	INTO	ApiCovid19Summary
    SELECT	'Global' as Country,NULL as CountryCode, NULL as Slug,NewConfirmed,TotalConfirmed,NewDeaths,TotalDeaths,NewRecovered,TotalRecovered,Date
	FROM	OPENJSON(@vResponse)
	WITH	(
				NewConfirmed INT		N'$.Global.NewConfirmed',
				TotalConfirmed INT		N'$.Global.TotalConfirmed',
				NewDeaths INT			N'$.Global.NewDeaths',
				TotalDeaths INT			N'$.Global.TotalDeaths',
				NewRecovered INT		N'$.Global.NewRecovered',
				TotalRecovered INT		N'$.Global.TotalRecovered',
				Date DATETIME			N'$.Global.Date'
			)
	UNION ALL
    SELECT	Country,CountryCode,Slug,NewConfirmed,TotalConfirmed,NewDeaths,TotalDeaths,NewRecovered,TotalRecovered,Date
	FROM	OPENJSON(@vResponse)
	WITH	(
				CountryJson nvarchar(max)	N'$.Countries' AS JSON
			) as C
	CROSS APPLY OPENJSON (C.CountryJson)
	WITH	(
				Country nvarchar(255)	N'$.Country',
				CountryCode varchar(2)	N'$.CountryCode',
				Slug nvarchar(255)		N'$.Slug',
				NewConfirmed INT		N'$.NewConfirmed',
				TotalConfirmed INT		N'$.TotalConfirmed',
				NewDeaths INT			N'$.NewDeaths',
				TotalDeaths INT			N'$.TotalDeaths',
				NewRecovered INT		N'$.NewRecovered',
				TotalRecovered INT		N'$.TotalRecovered',
				Date DATETIME			N'$.Date'
			) as CD

	--Dispose objects 
	IF @vWin IS NOT NULL
		EXEC sp_OADestroy @vWin

	RETURN
END
GO
/*
EXEC ApiCovid19

SELECT * FROM ApiCovid19Route
SELECT * FROM ApiCovid19Countries
SELECT TOP 100 * FROM ApiCovid19CountryDayOne ORDER BY DATE DESC
SELECT * FROM ApiCovid19Summary ORDER BY DATE DESC
*/


