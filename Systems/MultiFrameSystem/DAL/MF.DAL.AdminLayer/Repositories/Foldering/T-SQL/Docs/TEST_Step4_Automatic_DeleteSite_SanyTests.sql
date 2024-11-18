--------------------------------------------------------------------------------------------------------------
-- TESTING - STEP 3
-- -----------------

-- DELETE/ASSIGN TESTING

-- !!! MUST BE EXECUTED AFTER 'CREATE' SCRIPT !!!

-- Description
-- -----------------

-- Requirements:
--- ----------------
-- Make sure sure to have at least X projects and at least X sites inside each (for source and target users)
--------------------------------------------------------------------------------------------------------------

-- Testing complex senarios

--	Operation				Direct Link		From			From-Entity						
--	------------------		-----------		---------		-----------------------	
--	A1. Delete Project		U2S				Project			1st project
--	A2. Delete Site			-				Site			1st site in 2nd project

--------------------------------------------------------------------------------------------------------------
 
DECLARE @Users_StartID		INT = 20

DECLARE @_SourceUserID BIGINT = @Users_StartID+1
DECLARE @_TargetUserID BIGINT = @Users_StartID+2

IF (OBJECT_ID('tempDB..#Senarios','U') IS NOT NULL)
   DROP TABLE #Senarios

DECLARE @Operation_Type_DELETE_SITE VARCHAR(20)			= 'DELETE-SITE'
DECLARE @Operation_Type_DELETE_PROJECT VARCHAR(20)		= 'DELETE-PROJECT'

CREATE TABLE #Senarios (
						ID						BIGINT IDENTITY(1,1), 
						TypeOfOperation			VARCHAR(50),
						SDescription			VARCHAR(50), 
						SourceSiteID			BIGINT , 
						ExpectedPathOrResult	VARCHAR(MAX),
						ExpectedResult			BIT,
						IsEnabled				BIT);

---------------------------------------------------------------------
-- A1. Delete Project
-- 1st project for source userID
INSERT INTO #Senarios
        (TypeOfOperation , SDescription , SourceSiteID , ExpectedResult , ExpectedPathOrResult , IsEnabled)
VALUES  ( 
		--TypeOfOperation
		@Operation_Type_DELETE_PROJECT,
		--SDescription
		'A1. Delete Project (U2S)',
		--SourceSiteID
		(SELECT SiteID
		 FROM		(
					SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
					FROM Tree.User2Site AS U2S
					WHERE @_SourceUserID = LinkedUserID AND ParentSiteID IS NULL
					) AS T
		WHERE T.R = 1),
		--ExpectedResult
		1,
		--ExpectedPathOrResult
		'',
		--IsEnabled
		1)

---------------------------------------------------------------------
-- A2. Delete Site (U2S)
-- 1st site in 2nd project
INSERT INTO #Senarios
        (TypeOfOperation , SDescription , SourceSiteID , ExpectedResult , ExpectedPathOrResult , IsEnabled)
VALUES  ( 
		--TypeOfOperation
		@Operation_Type_DELETE_SITE,
		--SDescription
		'A2. Delete Site (U2S)',
		--SourceSiteID
		(SELECT SiteID															--SourceUserID
		 FROM (
				SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
				FROM Site.MainSite AS S
					INNER JOIN ( 
								SELECT SiteID
								FROM	(
										SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
										FROM Tree.User2Site AS u2s
										WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
										) AS T
								WHERE T.R=2
								) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
		WHERE R1=1),
		--ExpectedResult
		1,
		--ExpectedPathOrResult
		'',
		--IsEnabled
		1)

------------------------------------------------------------------------------------
-- print Senarios table
------------------------------------------------------------------------------------
SELECT * FROM #Senarios

------------------------------------------------------------------------------------
-- Run over all senarios
------------------------------------------------------------------------------------
DECLARE @Cursor_SenarioID INT = NULL
DECLARE @Cursor_Index INT = 0
DECLARE @Cursor_Count INT = (SELECT COUNT(1) FROM #Senarios)

DECLARE @TypeOfOperation					VARCHAR(50)		= NULL
DECLARE @SDescription						VARCHAR(50)		= NULL
DECLARE @SourceSiteID						BIGINT			= NULL
DECLARE @ExpectedResult						BIT				= NULL
DECLARE @ExpectedPathOrResult				VARCHAR(MAX)	= NULL
DECLARE @IsEnabled							BIT				= 0
DECLARE @_COUNT_DEVICES_Source_AFTER		BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Source_BEFORE		BIGINT			= NULL
DECLARE @_COUNT_DEVICES_SourceSite_BEFORE	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_SourceSite_AFTER	BIGINT			= NULL

DECLARE @RC									INT
DECLARE @ErrorThrowed						BIT				= 0
DECLARE @LastErrorMessage					VARCHAR(MAX)	= NULL


WHILE(@Cursor_Index < @Cursor_Count)
BEGIN	

	--get current user pointer points on
	SELECT
			@Cursor_SenarioID		= ID,
			@TypeOfOperation		= TypeOfOperation,
			@SDescription			= SDescription,
			@SourceSiteID			= SourceSiteID,
			@ExpectedResult			= ExpectedResult,
			@ExpectedPathOrResult	= ExpectedPathOrResult,
			@IsEnabled				= IsEnabled
	FROM #Senarios
	ORDER BY ID
	OFFSET @Cursor_Index ROWS
	FETCH NEXT 1 ROWS ONLY

	--------------****************************************************************************************--------------
	-- Start Of Loop Body
	--------------****************************************************************************************--------------
	--RESET variables
	SET @RC = 0
	SET @_COUNT_DEVICES_Source_BEFORE	= 0
	SET @_COUNT_DEVICES_Source_AFTER	= 0
	SET @ErrorThrowed					= 0
	SET @LastErrorMessage				= NULL
  
	------------------------------
	-- Count devices before actions
	------------------------------
	SELECT @_COUNT_DEVICES_Source_BEFORE=COUNT(1)
	FROM (SELECT COUNT(1) AS C
	FROM Tree.User2Device
	WHERE UserID=@_SourceUserID
	GROUP BY DeviceID) AS T

	SELECT @_COUNT_DEVICES_SourceSite_BEFORE = COUNT(1)
	FROM Tree.GetTreeDevices(@SourceSiteID)

	------------------------------
	-- Operate test
	------------------------------
	IF (@IsEnabled = 1)
	BEGIN
		PRINT '-----------------------------------------------------'
		PRINT 'Testing Senario :: ' + @TypeOfOperation + ' ['+ @SDescription + ']'
		PRINT ' - For SiteID='+CAST(@SourceSiteID AS VARCHAR(10));
		PRINT ' - BEFORE ::'
		PRINT ' - Source User owns '+CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + ' devices.';

		BEGIN TRY        

			IF (@TypeOfOperation = @Operation_Type_DELETE_SITE)
			BEGIN

				EXEC @RC = Site.DeleteSite
					@SourceSiteID = @SourceSiteID,
				    @SourceUserID = @_SourceUserID

			END

			IF (@TypeOfOperation = @Operation_Type_DELETE_PROJECT)
			BEGIN
            
				EXEC @RC = Site.DeleteProject
					@ProjectID		= @SourceSiteID,
				    @SourceUserID	= @_SourceUserID
			
			END
  
		END TRY
		BEGIN CATCH
          
		   SELECT @LastErrorMessage = error_message()
					--, error_procedure()
					--, error_line()
		
			SET @ErrorThrowed = 1
		
		END CATCH          
    
		------------------------------
		-- Validate result
		------------------------------
		IF (@ExpectedResult = 0)
		BEGIN  
			
			IF (@ErrorThrowed = 1)          
			BEGIN
				PRINT 'Success! (Failed as expected with the failure:>' + @LastErrorMessage;
			END
			ELSE
			BEGIN
	
				PRINT ' - ERROR > Expected to fail but succeed!'
				PRINT '			  Expected Error=' + @ExpectedPathOrResult;
				THROW 50100,'>> TEST FAILED AND TERMINATED!',1
			END          
		END 
		IF (@ExpectedResult = 1)
		BEGIN  
		IF (@ErrorThrowed = 1)
			BEGIN
	
				PRINT ' - ERROR > ' + @LastErrorMessage;
				THROW 50101,'>> TEST FAILED AND TERMINATED!',1
			END
			ELSE
			BEGIN
				PRINT 'Success!';
			END
		END


		-----------------------------------
		-- Count devices after operations
		-----------------------------------
		SELECT @_COUNT_DEVICES_Source_AFTER=COUNT(1)
		FROM (SELECT COUNT(1) AS C
		FROM Tree.User2Device
		WHERE UserID=@_SourceUserID
		GROUP BY DeviceID) AS T
		
		--count on site
		SELECT @_COUNT_DEVICES_SourceSite_AFTER = COUNT(1)
		FROM Tree.GetTreeDevices(@SourceSiteID)

		----------------------------------
		-- test all tree for SourceUserID
		----------------------------------
		EXECUTE [Tree].[TEST.ValidateUserDevices] 
			   @UserID = @_SourceUserID
			  ,@SiteID = NULL
  
		PRINT ' - AFTER ::'
		PRINT ' - Source User owns '+CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10)) + ' devices ('+IIF(@_COUNT_DEVICES_Source_AFTER >= @_COUNT_DEVICES_Source_BEFORE, '+','') + CAST((@_COUNT_DEVICES_Source_AFTER - @_COUNT_DEVICES_Source_BEFORE) AS VARCHAR(20)) +')';
		PRINT ' - Source Site owns '+CAST(@_COUNT_DEVICES_SourceSite_AFTER AS VARCHAR(10)) + ' devices ('+IIF(@_COUNT_DEVICES_SourceSite_AFTER >= @_COUNT_DEVICES_SourceSite_BEFORE, '+','') + CAST((@_COUNT_DEVICES_SourceSite_AFTER - @_COUNT_DEVICES_SourceSite_BEFORE) AS VARCHAR(20)) +')';


	END -- end of opeartion
	ELSE
	BEGIN
		PRINT '-----------------------------------------------------'
		PRINT 'SKIPPING Testing Senario :: ' + @TypeOfOperation + ' ['+ @SDescription + ']'
		PRINT ' - SiteID='+CAST(@SourceSiteID AS VARCHAR(10))
	END 

	--------------****************************************************************************************--------------
	-- END Of Loop Body
	--------------****************************************************************************************--------------

	SET @Cursor_Index = @Cursor_Index +1
END

