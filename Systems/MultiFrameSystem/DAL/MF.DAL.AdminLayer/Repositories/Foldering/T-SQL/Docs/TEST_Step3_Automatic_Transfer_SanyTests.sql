------------------------------------------------------------------------------------
-- TESTING - STEP 2
-- -----------------

-- TRANSFER/LOCAL TRANSFER TESTING

-- !!! MUST BE EXECUTED AFTER 'CREATE' SCRIPT !!!

-- Description
-- -----------------
-- Insert temp table (#Senarios) all senarios (described in table below).
-- For each senario - run Transfer, Share etc..
-- Test before & after the numbers of sites and devices

-- Requirements:
--- ----------------
-- Make sure sure to have at least 9 projects and at least 3 sites inside each (for source and target users)
------------------------------------------------------------------------------------

-- Testing complex senarios

--	Operation				Direct Link		From			From-Entity						To					To-Entity							Expected Path
--	------------------		-----------		---------		-----------------------			------------		------------------------			------------------------------------
--	A10. Transfer			U2S				Site			1st project						Under Site			1st site in 1nd project				#_A1_A2_C1_C2
--	A11. Transfer			-				Site			1st site in 2nd project			Under Site			1st project							#_A1_A2_B_D21_D22_D2
--	A12. Transfer			-				Site			2nd site in 2nd project			As Project			New project							#_A1_A2_B_D11_D12
--	A13. Transfer			U2S				Site			2nd project						As Project			New project							#_A1_A2_C1_C2

--	B1. Transfer			U2S				Project			3nd Project						Under Site			1st site in 2nd project				#_A1_A2_C1_C2
--	B2. Transfer			U2S				Project			4nd Project						AS Project			New project							#_A1_A2_C1_C2

--	C1. Local Transfer		U2S				Site			5rd project						Under Site			1st site in 6rd project				#_A1_A2_C1_C2
--	C2. Local Transfer		-				Site			1st site in 6rd project			Under Site			2nd site in 6rd project				#_A1_A2_B_D21_D22_D2
--	C3. Local Transfer		-				Site			1st site in 6rd project			Under Site			1st site in 6rd project				ERROR - Circular
--	C4. Local Transfer		U2S				Site			*****							As Project			***									******
--	C5. Local Transfer		-				Site			2nd site in 6rd project			As Project			New project							#_A1_A2_B_D11_D12
--	C6. Local Transfer		U2S				Project			6rd project						Under Site			1st site in 7rd project				#_A1_A2_C1_C2


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
EXEC Tree.[TEST.PrintTree]
	@UserID			= @_SourceUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 0,
	@ResultTitle	= 'BEFORE TEST'

EXEC Tree.[TEST.PrintTree]
	@UserID			= @_TargetUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 0,
	@ResultTitle	= 'BEFORE TEST'

IF (OBJECT_ID('tempDB..#Senarios','U') IS NOT NULL)
   DROP TABLE #Senarios

DECLARE @Operation_Type_TRANSFER VARCHAR(20)		= 'TRANSFER'
DECLARE @Operation_Type_LOCAL_TRANSFER VARCHAR(20)	= 'LOCAL-TRANSFER'


CREATE TABLE #Senarios (
						ID						BIGINT IDENTITY(1,1), 
						TypeOfOperation			VARCHAR(50),
						SDescription			VARCHAR(50), 
						SourceSiteID			BIGINT , 
						TargetSiteID			BIGINT, 
						ExpectedResult			BIT,
						ExpectedPathOrResult	VARCHAR(50),
						IsEnabled				BIT);

----------------------------------------------------
-- A10. 
-- Linked in U2S
-- Site --> Under Site

--SourceUserID: 1st project in U2S
--TargetUserID: first site in 1st project in U2S
--------------------------------------------------- 
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A10. Transfer (U2S)(Site --> Under Site)',								--Description
	@Operation_Type_TRANSFER,												--Type of Operation
	(SELECT SiteID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
	WHERE T.R=1),
	(SELECT SiteID															--TargetUserID
	 FROM (
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R2
			FROM (
				SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
				FROM Tree.User2Site AS u2s
				WHERE u2s.LinkedUserID = @_TargetUserID AND ParentSiteID IS NULL
				) AS T
			WHERE T.R=1) AS T2
	 WHERE R2=1),
	1,
	'#_A1_A2_C1_C2',														--Expected Path
	1)																		--IsEnabled)		

	
----------------------------
-- A11. 
-- NOT Linked in U2S
-- Site --> Under Site

--SourceUserID: first Site in 2nd Project (U2S)
--TargetUserID: 1nd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A11. Transfer (-)(Site --> Under Site)',								--Description
	@Operation_Type_TRANSFER,												--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=2) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	(SELECT SiteID															--TargetUserID
		FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_TargetUserID AND ParentSiteID IS NULL
			) AS T
		WHERE T.R=1),
	1,
	'#_A1_A2_B_D21_D22_D23',												--Expected Path
	1)																		--IsEnabled)		

	
----------------------------
-- A12. 
-- Linked in U2S
-- Site --> As Project

--SourceUserID: second site in 2nd Project (U2S)
--TargetUserID: NULL
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A12. Transfer (U2S)(Site --> As Project)',								--Description
	@Operation_Type_TRANSFER,												--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=2) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=2),
	NULL,																	--TargetUserID
	1,
	'#_A1_A2_B_D11_D12',													--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- A13. 
-- NOT Linked in U2S
-- Site --> As Project

--SourceUserID: 2nd Project (U2S)
--TargetUserID: NULL
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'A13. Transfer (U2S)(Site --> As Project)',								--Description
	@Operation_Type_TRANSFER,												--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS U2S
			WHERE U2S.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
	 WHERE T.R=2),
	NULL,																	--TargetUserID
	1,
	'#_A1_A2_c1_C2',														--Expected Path
	1)																		--IsEnabled)		


----------------------------
-- B1. 
-- Linked in U2S
-- Project --> Under Site

--SourceUserID: 3rd Project (U2S)
--TargetUserID: first Site in 2nd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'B1. Transfer (U2S)(Project --> Under Site)',							--Description
	@Operation_Type_TRANSFER,												--Type of Operation

	(SELECT SiteID															--SourceUserID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
			) AS T
	 WHERE T.R=3),
	(SELECT SiteID															--TargetUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_TargetUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=2) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	1,
	'#_A1_A2_C1_C2',														--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- B2. 
-- Linked in U2S
-- Project --> Under Site

--SourceUserID: 4nd Project (U2S)
--TargetUserID: as new Project
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'B2. Transfer (U2S)(Project --> Under Site)',							--Description
	@Operation_Type_TRANSFER,												--Type of Operation
	(SELECT SiteID															--SourceUserID
		FROM	(
				SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
				FROM Tree.User2Site AS u2s
				WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
				) AS T
		WHERE T.R=4),
	NULL,																	--TargetUserID
	1,
	'#_A1_A2_C1_C2',														--Expected Path
	1)																		--IsEnabled)		


----------------------------
-- C1. 
-- Linked in U2S
-- Site --> Under Site

--SourceUserID: 5rd Project (U2S)
--TargetUserID: 1st site in 6rd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'C1. Transfer (U2S)(Site --> Under Site)',								--Description
	@Operation_Type_LOCAL_TRANSFER,											--Type of Operation
	(SELECT SiteID															--SourceUserID
		FROM	(
				SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
				FROM Tree.User2Site AS u2s
				WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
				) AS T
		WHERE T.R=5),
	(SELECT SiteID															--@_SourceUserID as TargetUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	1,
	'#_A1_A2_C1_C2',														--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- C2. 
-- NOT Linked in U2S
-- Site --> Under Site

--SourceUserID: 1st site in 6rd Project (U2S)
--TargetUserID: 2nd site in 6rd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'C2. Transfer (-)(Site --> Under Site)',								--Description
	@Operation_Type_LOCAL_TRANSFER,											--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	(SELECT SiteID															--@_SourceUserID as TargetUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=2),
	1,
	'#_A1_A2_B_D21_D22_D23',												--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- C3. 
-- NOT Linked in U2S
-- Site --> Under Site

--SourceUserID: 1st site in 6rd Project (U2S)
--TargetUserID: 1st site in 6rd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'C3. Transfer (-)(Site --> Under Site)',								--Description
	@Operation_Type_LOCAL_TRANSFER,											--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	(SELECT SiteID															--@_SourceUserID as TargetUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	0,
	'Circular',																--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- C4. 
-- Linked in U2S
-- Site --> As Project

--SourceUserID: second site in 5rd Project (U2S)
--TargetUserID: first site in 5rd Project (U2S)
----------------------------
--not in use!!!.
--we don't have linked Site to local transfer as project


----------------------------
-- C5. 
-- NULL Linked in U2S
-- Site --> As Project

--SourceUserID: 2nd site in 6rd Project (U2S)
--TargetUserID: New project
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'C5. Transfer (-)(Site --> As Project)',								--Description
	@Operation_Type_LOCAL_TRANSFER,											--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=6) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=2),
	NULL,																	--@_SourceUserID as TargetUserID
	1,
	'#_A1_A2_B_D11_D12',													--Expected Path
	1)																		--IsEnabled)		

----------------------------
-- C6. 
-- U2S Linked in U2S
-- Project --> under Site

--SourceUserID: 6rd Project (U2S)
--TargetUserID: first site in 7rd Project (U2S)
----------------------------
INSERT INTO #Senarios (  SDescription, TypeOfOperation , SourceSiteID , TargetSiteID , ExpectedResult , ExpectedPathOrResult, IsEnabled) 
	VALUES (
	'C6. Transfer (U2S)(Project --> under Site)',							--Description
	@Operation_Type_LOCAL_TRANSFER,											--Type of Operation
	(SELECT SiteID															--SourceUserID
	 FROM (
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID = @_SourceUserID AND ParentSiteID IS NULL) AS T
	WHERE T.R=6),
	(SELECT SiteID															--@_SourceUserID as TargetUserID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@_SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=7) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=1),
	1,
	'#_A1_A2_C1_c2',														--Expected Path
	1)																		--IsEnabled)		

SELECT *
FROM #Senarios
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
DECLARE @ExpectedResult					BIT				= NULL
DECLARE @ExpectedPathOrResult			VARCHAR(50)		= NULL
DECLARE @IsEnabled			BIT				= 0
DECLARE @_COUNT_DEVICES_Source_AFTER	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Target_AFTER	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Source_BEFORE	BIGINT			= NULL
DECLARE @_COUNT_DEVICES_Target_BEFORE	BIGINT			= NULL
DECLARE @RC INT
DECLARE @ErrorThrowed					BIT				= 0
DECLARE @LastErrorMessage				VARCHAR(MAX)	= NULL
DECLARE @LastErrorProcdure				VARCHAR(MAX)	= NULL
DECLARE @LastErrorProcdureLine			VARCHAR(MAX)	= NULL

DECLARE @Path VARCHAR(100) = NULL

WHILE(@Cursor_Index < @Cursor_Count)
BEGIN	

	--get current user pointer points on
	SELECT
			@Cursor_SenarioID		= ID,
			@TypeOfOperation		= TypeOfOperation,
			@SDescription			= SDescription,
			@SourceSiteID			= SourceSiteID,
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
	SET @Path							= NULL
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


	------------------------------
	-- Operate test
	------------------------------
	IF (@IsEnabled = 1)
	BEGIN
		PRINT '-----------------------------------------------------'
		PRINT 'Testing Senario :: ' + @TypeOfOperation + ' ['+ @SDescription + ']'
		PRINT ' - Trasferring SiteID='+CAST(@SourceSiteID AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))
		PRINT ' - BEFORE ::'
		PRINT ' - Source User owns '+CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + ' devices.';
		PRINT ' - Target User owns '+CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + ' devices.';

		BEGIN TRY        
			IF (@TypeOfOperation = @Operation_Type_TRANSFER)
			BEGIN
  
				EXEC Site.Transfer_Start
					@SiteID			= @SourceSiteID, 
					@SourceUserID	= @_SourceUserID, 
					@TargetUserID	= @_TargetUserID 


				EXEC @RC= Site.Transfer_Accept
					@SourceSiteID, 
					@_SourceUserID, 
					@TargetSiteID,
					@_TargetUserID, 
					@Path OUTPUT
			END 
	 
			IF (@TypeOfOperation = @Operation_Type_LOCAL_TRANSFER)
			BEGIN
  
				EXEC @RC = Site.LocalTransfer 
					@_SourceUserID,
					@SourceSiteID,
					@TargetSiteID, 
					@Path OUTPUT   
			END 
		END TRY
		BEGIN CATCH
          
		   SELECT	@LastErrorMessage		= error_message()
					,@LastErrorProcdure		= error_procedure()
					,@LastErrorProcdureLine	= error_line()
		
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
			ELSE IF (@RC = 1 OR (@Path IS NOT NULL AND @Path = @ExpectedPathOrResult))
			BEGIN
	
				PRINT ' - ERROR > Expected to fail but succeed!'
				PRINT '			  Expected Error=' + @ExpectedPathOrResult + ' (and got Path=' + @Path + ')';
				THROW 50100,'>> TEST FAILED AND TERMINATED!',1
			END          
		END 
		IF (@ExpectedResult = 1)
		BEGIN  
		IF (@ErrorThrowed = 1 OR @RC != 1 OR @Path IS NULL OR @Path != @ExpectedPathOrResult)
			BEGIN
	
				PRINT ' - ERROR > Expected Path=' + @ExpectedPathOrResult + ' But got Path=' + @Path;
				PRINT 'Last Error >> ' + @LastErrorMessage + 'On procedure >' + @LastErrorProcdure +'#Line:' + @LastErrorProcdureLine;
				THROW 50101,'>> TEST FAILED AND TERMINATED!',1
			END
			ELSE
			BEGIN
				PRINT 'Success! Got Path=' + @Path;
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

		IF (@TypeOfOperation = @Operation_Type_TRANSFER)
		BEGIN
			--in transfer both Source and Target user will have differnet number of devices after the action  
  			IF ((@_COUNT_DEVICES_Source_BEFORE=@_COUNT_DEVICES_Source_AFTER) OR (@_COUNT_DEVICES_Target_BEFORE=@_COUNT_DEVICES_Target_AFTER))
			BEGIN 

				PRINT ' - ERROR > Problem with number of devices in users. (Source ' + CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10))
						+' Target=' + CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10)) +')';

				THROW 50102,'>> Transfer failed',1
			END	         
		END
    
		IF (@TypeOfOperation = @Operation_Type_LOCAL_TRANSFER)
		BEGIN
			-- in local transfer we don't expect to change number of devices for none of the users...  
  			IF ((@_COUNT_DEVICES_Source_BEFORE<>@_COUNT_DEVICES_Source_AFTER) OR (@_COUNT_DEVICES_Target_BEFORE<>@_COUNT_DEVICES_Target_AFTER))
			BEGIN 

				PRINT ' - ERROR > Problem with number of devices in users. (Source ' + CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10))
						+' Target=' + CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10)) +')';

				THROW 50103,'>> Transfer failed',1
			END	

			IF ((@_COUNT_DEVICES_Source_BEFORE+ @_COUNT_DEVICES_Target_BEFORE) <> (@_COUNT_DEVICES_Source_AFTER+ @_COUNT_DEVICES_Target_AFTER))
			BEGIN 

				PRINT ' - ERROR > Problem with number of devices in users. (Source ' + CAST(@_COUNT_DEVICES_Source_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Source_AFTER AS VARCHAR(10))
						+' Target=' + CAST(@_COUNT_DEVICES_Target_BEFORE AS VARCHAR(10)) + '->' + CAST(@_COUNT_DEVICES_Target_AFTER AS VARCHAR(10)) +')';

				THROW 50104,'>> Transfer failed',1
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
		PRINT ' - Trasferring SiteID='+CAST(@SourceSiteID AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))
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
