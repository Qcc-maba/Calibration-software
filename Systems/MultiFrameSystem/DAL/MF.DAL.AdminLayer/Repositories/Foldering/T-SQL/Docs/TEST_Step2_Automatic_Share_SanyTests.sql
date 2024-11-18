DECLARE @Users_StartID		INT = 20

DECLARE @_SourceUserID BIGINT = @Users_StartID+1
DECLARE @_TargetUserID BIGINT = @Users_StartID+2


/***********************************************************************************/
/***********************************************************************************/
PRINT ''
PRINT 'BEFORE :: Printing Users Trees'
PRINT '-----------------------------------------------------------------------------'
/***********************************************************************************/
/***********************************************************************************/
EXEC [Tree].[TEST.PrintTree]
	@UserID			= @_SourceUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 1,
	@ResultTitle	= 'BEFORE TEST'

EXEC [Tree].[TEST.PrintTree]
	@UserID			= @_TargetUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 1,
	@ResultTitle	= 'BEFORE TEST'	 

DECLARE @Operation_Type_Share VARCHAR(20)			= 'SHARE'
DECLARE @Operation_Type_DOUBLE_Share VARCHAR(20)	= 'DOUBLE-SHARE'

IF (OBJECT_ID('tempDB..#Senarios','U') IS NOT NULL)
   DROP TABLE #Senarios
CREATE TABLE #Senarios (
						ID						BIGINT IDENTITY(1,1), 
						TypeOfOperation			VARCHAR(50),
						SDescription			VARCHAR(50), 
						SourceSiteID			BIGINT , 
						TargetSiteID			BIGINT, 
						SourceUserID			BIGINT , 
						TargetUserID			BIGINT, 
						ExpectedResult			BIT,
						ExpectedPathOrResult	VARCHAR(50),
						IsEnabled				BIT);


----------------------------------------------------
-- A1. 

--transfer from SourceUserID -> TargetUserID
--project	-> as project
--1st project to as project
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceUserID, SourceSiteID, TargetUserID, TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A1. Share (Project --> Project)',										--Description
	@Operation_Type_Share,												--Type of Operation
	---------------------Source---------------------
	@_SourceUserID,
	(SELECT SiteID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
	WHERE T.R=1),
	---------------------Target---------------------
	@_TargetUserID,
	NULL,
	1,
	NULL,																	--Expected Result
	1)																		--IsEnabled)		


----------------------------------------------------
-- A2. 

--transfer from SourceUserID -> TargetUserID
--project	-> site
--2nd project to 1st site in 1st project
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceUserID, SourceSiteID, TargetUserID, TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A2. Share (Project --> Site)',										--Description
	@Operation_Type_Share,												--Type of Operation
	---------------------Source---------------------
	@_SourceUserID,
	(SELECT SiteID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
	WHERE T.R=2),
	---------------------Target---------------------
	@_TargetUserID,
	(SELECT SiteID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_TargetUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=1) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	1,
	NULL,																	--Expected Result
	1)																		--IsEnabled)		


----------------------------------------------------
-- A3. 

--transfer from SourceUserID -> TargetUserID
--site		-> site
--1st site in 3nd project to 2st site in 1nd project
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceUserID, SourceSiteID, TargetUserID, TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A3. Share (Site --> Site)',										--Description
	@Operation_Type_Share,												--Type of Operation
	---------------------Source---------------------
	@_SourceUserID,
	(SELECT SiteID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=3) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	---------------------Target---------------------
	@_TargetUserID,
	(SELECT SiteID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_TargetUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=1) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=2),
	1,
	NULL,																	--Expected Result
	1)																		--IsEnabled)		

----------------------------------------------------
-- A4. 

--transfer from SourceUserID -> TargetUserID
--site		-> as Project
--1st site in 4nd project to as project
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceUserID, SourceSiteID, TargetUserID, TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A4. Share (Site --> Project)',										--Description
	@Operation_Type_Share,												--Type of Operation
	---------------------Source---------------------
	@_SourceUserID,
	(SELECT SiteID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=4) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	---------------------Target---------------------
	@_TargetUserID,
	NULL,
	1,
	NULL,																	--Expected Result
	1)																		--IsEnabled)		

----------------------------------------------------
-- A5. 

--SPECIAL CASE - SHARE SITE THAT ALREADY LINKED TO TARGET BY OTHER UPPER SHARE
--transfer from SourceUserID -> TargetUserID
--site		-> as Project
--4nd project to as project
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceUserID, SourceSiteID, TargetUserID, TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A5. Share (Project --> Project)',										--Description
	@Operation_Type_DOUBLE_Share,												--Type of Operation
	---------------------Source---------------------
	@_SourceUserID,
	(	SELECT SiteID
		FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
		WHERE T.R=4),
	---------------------Target---------------------
	@_TargetUserID,
	NULL,
	1,
	NULL,																	--Expected Result
	1)																		--IsEnabled)		


------------------------------------------------------------------------------------
-- Run over all senarios
------------------------------------------------------------------------------------
DECLARE @Cursor_SenarioID INT = NULL
DECLARE @Cursor_Index INT = 0
DECLARE @Cursor_Count INT = (SELECT COUNT(1) FROM #Senarios)

DECLARE @TypeOfOperation				VARCHAR(50)		= NULL
DECLARE @SDescription					VARCHAR(50)		= NULL
DECLARE @SourceSiteID					BIGINT			= NULL
DECLARE @TargetSiteID					BIGINT			= NULL
DECLARE @SourceUserID					BIGINT			= NULL
DECLARE @TargetUserID					BIGINT			= NULL

DECLARE @ExpectedResult					BIT				= NULL
DECLARE @ExpectedPathOrResult			VARCHAR(50)		= NULL
DECLARE @IsEnabled						BIT				= 0
DECLARE @_COUNT_DEVICES_Specific_BEFORE	BIGINT			= NULL

DECLARE @_COUNT_DEVICES_Source_AFTER	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Target_AFTER	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Source_BEFORE	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Target_BEFORE	BIGINT			= NULL
DECLARE @RC								INT
DECLARE @RC1							INT
DECLARE @RC2							INT

DECLARE @ErrorThrowed					BIT				= 0
DECLARE @LastErrorMessage				VARCHAR(MAX)	= NULL

WHILE(@Cursor_Index < @Cursor_Count)
BEGIN	

	--get current user pointer points on
	SELECT
			@Cursor_SenarioID		= ID,
			@TypeOfOperation		= TypeOfOperation,
			@SDescription			= SDescription,
			@SourceUserID			= SourceUserID,
			@SourceSiteID			= SourceSiteID,
			@TargetUserID			= TargetUserID,
			@TargetSiteID			= TargetSiteID,
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
	SET @_COUNT_DEVICES_Target_BEFORE	= 0
	SET @_COUNT_DEVICES_Source_AFTER	= 0
	SET @_COUNT_DEVICES_Target_AFTER	= 0
	SET @ErrorThrowed					= 0
	SET @LastErrorMessage				= NULL

	------------------------------
	--Count devices before actions
	------------------------------
	SELECT @_COUNT_DEVICES_Source_BEFORE=COUNT(1)
	FROM (SELECT COUNT(1) AS C
	FROM Tree.User2Device
	WHERE UserID=@_SourceUserID
	GROUP BY DeviceID) AS T

	SELECT @_COUNT_DEVICES_Target_BEFORE=COUNT(1)
	FROM (SELECT COUNT(1) AS C
	FROM Tree.User2Device
	WHERE UserID=@_TargetUserID
	GROUP BY DeviceID) AS T	      

	SELECT @_COUNT_DEVICES_Specific_BEFORE = COUNT(DISTINCT DeviceID)
	FROM Tree.GetTreeDevices(@SourceSiteID) 


	------------------------------
	-- Operate test
	------------------------------
	IF (@IsEnabled = 1)
	BEGIN
		PRINT '-----------------------------------------------------'
		PRINT 'Testing Senario :: ' + @TypeOfOperation + ' ['+ @SDescription + ']'
		PRINT ' - UserID='+CAST(@SourceUserID AS VARCHAR(10))+ ' To UserID='+CAST(@TargetUserID AS VARCHAR(10))
		PRINT ' - SiteID='+CAST(@SourceSiteID AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))

		PRINT ' - BEFORE ::'
		PRINT ' - Source User owns '+CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + ' devices.';
		PRINT ' - Target User owns '+CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + ' devices.';
		
		BEGIN TRY        
			IF (@TypeOfOperation = @Operation_Type_Share OR @TypeOfOperation = @Operation_Type_DOUBLE_Share)
			BEGIN
  
				EXEC @RC1 = Site.SharedUsers_Add
					@SourceSiteID		= @SourceSiteID,
					@SourceUserID		= @SourceUserID,
					@RoleModify			= 1, 
					@RoleViewOnly		= 1,
					@RoleControlRT		= 1, 
					@RoleAdmin			= 1, 
					@Email				= NULL, 
					@TargetUserID		= @TargetUserID 

				EXEC @RC2 = Site.SharedUsers_Accept
					@SourceSiteID		= @SourceSiteID,
					@TargetUserID		= @TargetUserID,
					@TargetSiteID		= @TargetSiteID
	
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
			ELSE IF (@RC1 > 0 AND @RC2 > 0)
			BEGIN
	
				PRINT ' - ERROR > Expected to fail but succeed!'
				PRINT '			  Expected Error=' + @ExpectedPathOrResult;
				THROW 50100,'>> TEST FAILED AND TERMINATED!',1
			END          
		END 
		IF (@ExpectedResult = 1)
		BEGIN  
		IF (@ErrorThrowed = 1 OR @RC1 <=0 OR @RC2 <= 0)
			BEGIN
	
				PRINT ' - ERROR > Expected Path=' + @ExpectedPathOrResult;
				PRINT 'Error >> ' + @LastErrorMessage;
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

		SELECT @_COUNT_DEVICES_Target_AFTER=COUNT(1)
		FROM (SELECT COUNT(1) AS C
		FROM Tree.User2Device
		WHERE UserID=@_TargetUserID
		GROUP BY DeviceID) AS T

		--make sure source has the same number as before..
  		IF ((@_COUNT_DEVICES_Source_BEFORE <> @_COUNT_DEVICES_Source_AFTER))
		BEGIN 

			PRINT ' - ERROR > Problem with number of devices in Source User. (Source ' + CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10));
			THROW 50104,'>> Shared failed',1
		END	

		-- target should have more
		IF ((@_COUNT_DEVICES_Target_BEFORE >= @_COUNT_DEVICES_Target_AFTER))
		BEGIN 

			PRINT ' - ERROR > Problem with number of devices in Target User. (Source ' + CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10));
			THROW 50102,'>> Shared failed',1
		END 

		IF (@TypeOfOperation = @Operation_Type_Share)
		BEGIN
			IF ( (@_COUNT_DEVICES_Target_BEFORE + @_COUNT_DEVICES_Specific_BEFORE) <> @_COUNT_DEVICES_Target_AFTER)
			BEGIN 

				PRINT ' - ERROR > Problem with number of devices in Target User. (Source ' + CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10));
				PRINT ' - ERROR > Expected value is :' + CAST((@_COUNT_DEVICES_Target_BEFORE + @_COUNT_DEVICES_Specific_BEFORE) AS VARCHAR(10));

				THROW 50103,'>> Shared failed',1
			END
			
		END 
		
		
		IF (@TypeOfOperation = @Operation_Type_DOUBLE_Share)
		BEGIN
		
			DECLARE @OverlappedDeviceCount1 BIGINT =0 
			DECLARE @OverlappedDeviceCount2 BIGINT =0 

			SELECT @OverlappedDeviceCount1 = COUNT(DISTINCT DeviceID)
			FROM Tree.GetTreeDevices(@SourceSiteID) AS T

			SELECT @OverlappedDeviceCount2 = COUNT(1)
			FROM	(
					SELECT DeviceID, COUNT(1) AS C
					FROM Tree.User2Device AS U2D
					WHERE UserID = @TargetUserID
					GROUP BY DeviceID
					) AS T
			WHERE C > 1
		
			IF (@OverlappedDeviceCount1 <= @OverlappedDeviceCount2)
			BEGIN
  
				PRINT ' - ERROR > Problem with number of OVERLLAPED devices in Target User. (Source ' + CAST(@OverlappedDeviceCount1 AS VARCHAR(10)) + ' overallaped in target->' + CAST(@OverlappedDeviceCount2 AS VARCHAR(10)) +')';
				THROW 50105,'>> Shared failed',1
  
			END          
		
		
		END         


		----------------------------------
		-- test all tree for SourceUserID
		----------------------------------
		--test all tree for SourceUserID
		EXECUTE [Tree].[TEST.ValidateUserDevices] 
		   @UserID = @_SourceUserID
		  ,@SiteID = NULL
  
		--test all tree for TargetUserID
		EXECUTE [Tree].[TEST.ValidateUserDevices] 
		   @UserID = @_TargetUserID
		  ,@SiteID = NULL

		--test all tree for SourceUserID (in @_SourceSiteID)
		EXECUTE [Tree].[TEST.ValidateUserDevices] 
		   @UserID = @_SourceUserID
		  ,@SiteID = @SourceSiteID
  
		--test all tree for TargetUserID (in @_TargetSiteID)
		EXECUTE [Tree].[TEST.ValidateUserDevices] 
		   @UserID = @_TargetUserID
		  ,@SiteID = @TargetSiteID

		PRINT ' - AFTER ::'
		PRINT ' - Source User owns '+CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10)) + ' devices ('+IIF(@_COUNT_DEVICES_Source_AFTER >= @_COUNT_DEVICES_Source_BEFORE, '+','') + CAST((@_COUNT_DEVICES_Source_AFTER - @_COUNT_DEVICES_Source_BEFORE) AS VARCHAR(20)) +')';
		PRINT ' - Target User owns '+CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10)) + ' devices ('+IIF(@_COUNT_DEVICES_Target_AFTER >= @_COUNT_DEVICES_Target_BEFORE, '+','') + CAST((@_COUNT_DEVICES_Target_AFTER - @_COUNT_DEVICES_Target_BEFORE) AS VARCHAR(20)) +')';

	END
	ELSE
	BEGIN
		PRINT '-----------------------------------------------------'
		PRINT 'SKIPPING Testing Senario :: ' + @TypeOfOperation + ' ['+ @SDescription + ']'
		PRINT ' - UserID='+CAST(@SourceUserID AS VARCHAR(10))+ ' To UserID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetUserID AS VARCHAR(10)))
		PRINT ' - SiteID='+CAST(@SourceSiteID AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))
	END  

	--------------****************************************************************************************--------------
	-- END Of Loop Body
	--------------****************************************************************************************--------------

	SET @Cursor_Index = @Cursor_Index +1
END


/***********************************************************************************/
/***********************************************************************************/
PRINT ''
PRINT 'AFTER :: Printing Users Trees'
PRINT '-----------------------------------------------------------------------------'
/***********************************************************************************/
/***********************************************************************************/
EXEC Tree.[TEST.PrintTree]
	@UserID			= @_SourceUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 1,
	@ResultTitle	= 'AFTER TEST'

EXEC Tree.[TEST.PrintTree]
	@UserID			= @_TargetUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 1,
	@ResultTitle	= 'AFTER TEST'	 




