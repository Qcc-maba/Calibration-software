-------------------------------------------------------------------------------------------------
-- Settings <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------

DECLARE @Users_Count		INT = 3
DECLARE @Users_StartID		INT = 20
DECLARE @RootSites_Count	INT = 10
DECLARE @SubSites_Count		INT = 3
DECLARE @Devices_Count		INT = 2


DECLARE @counter1			INT = 0
DECLARE @counter2			INT = 0
DECLARE @counter3			INT = 0
DECLARE @counter4			INT = 0
DECLARE @CurrentUsersID		BIGINT = NULL

-------------------------------------------------------------------------------------------------
-- B. 1. Test tree     <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------

DECLARE @SiteID		INT = NULL
DECLARE @Site_Name	VARCHAR(100) = NULL

DECLARE @error_message VARCHAR(MAX)
DECLARE @RootSites TABLE(SiteID INT,UserID INT)

SET @CurrentUsersID = @Users_StartID
WHILE (@CurrentUsersID < @Users_StartID + @Users_Count)
BEGIN

	WHILE (1=1)
	BEGIN

		SET @SiteID = NULL

		SELECT @SiteID = S.SiteID, @Site_Name = S.Name
		FROM Site.MainSite AS S
			INNER JOIN Tree.User2Site AS U2S ON S.SiteID = U2S.SiteID      
		WHERE S.ParentSiteID IS NULL 
		ORDER BY S.SiteID
		OFFSET @counter2 ROWS
		FETCH NEXT 1 ROWS ONLY

		IF (@SiteID IS NULL)
			BREAK;

		IF (@Site_Name LIKE 'User_'+CAST(@CurrentUsersID AS VARCHAR(50))+'%')
		BEGIN
			-- this site is owned by the user
			-- so all sub sites in this sites should return @SiteID as root site
			--SELECT @counter3 = COUNT(1)
			--FROM Tree.GetSubTree(@SiteID) AS T
			--WHERE Tree.GetMaxRootSite(@CurrentUsersID,T.SiteID) <> @SiteID

			SELECT @counter3 = COUNT(1)
			FROM Tree.GetSubTree(@SiteID) AS T
			WHERE	@SiteID <>(
					SELECT TOP(1) RootSiteID 
					FROM Tree.GetTree(@CurrentUsersID,NULL,1000000,0,NULL)
					WHERE SiteID = T.SiteID
					)

			IF (@counter3 > 0)
			BEGIN
				SET @error_message = '(1) WRONG Max root SiteID for userID='+CAST(@CurrentUsersID AS varchar(20))+' SiteID='+CAST(@SiteID AS varchar(20));
				THROW 50000, @error_message,0
				BREAK;
			END
		END
		ELSE
		BEGIN
        	-- this site is NOT owned by the user
			-- so all sub sites in this sites shouldn't return @SiteID as root site

			SELECT @counter3 = COUNT(1)
			FROM Tree.GetSubTree(@SiteID) AS T
			WHERE	@SiteID <>(
					SELECT TOP(1) RootSiteID 
					FROM Tree.GetTree(@CurrentUsersID,NULL,1000000,0,@SiteID) 
					WHERE SiteID = T.SiteID
					)

			IF (@counter3 > 0)
			BEGIN
				SET @error_message = '(2) WRONG Max root SiteID for userID='+CAST(@CurrentUsersID AS varchar(20))+' SiteID='+CAST(@SiteID AS varchar(20))+' Site_Name='+@Site_Name;
				THROW 50000, @error_message,0
				BREAK;
			END 
  
		END      

		SET @counter2 = @counter2 + 1

	END
	SET @CurrentUsersID = @CurrentUsersID + 1
END

------------------------------------------------------------------------------------------------
-- B. 2. Test devices on tree  <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------
SET @counter1 = 0
SET @counter2 = 0
SET @counter3 = 0
SET @counter4 = 0

SET @CurrentUsersID = @Users_StartID

WHILE (@CurrentUsersID < @Users_StartID + @Users_Count)
BEGIN

	--count devices on user's tree
	SELECT @counter2 = COUNT(1)
	FROM Tree.GetTree(@CurrentUsersID, NULL,10000,0, NULL) AS T 
		INNER JOIN Device.MainDevice AS D ON D.ParentSiteID = T.SiteID

	--count devices in Tree.User2Device for this user
	SELECT @counter3 = COUNT(1)
	FROM Tree.User2Device AS U2D
	WHERE U2D.UserID = @CurrentUsersID

	--both counters should be the same
	IF (@counter2 <> @counter3)
	BEGIN
		SET @error_message = 'WRONG NUMBER OF DEVICES FOR USER '+CAST(@CurrentUsersID AS varchar(20))
						+', Tree.GetTree='+CAST(@counter2 AS varchar(20)) +', Tree.User2Device='+CAST(@counter3 AS varchar(20));
		THROW 50000, @error_message,0
		BREAK;
	END
    
	--make sure only this user has these devices
	SELECT @counter4 = COUNT(1)
	FROM Tree.User2Device AS U2D
		INNER JOIN (SELECT * FROM Tree.User2Device) AS D ON D.DeviceID=U2D.DeviceID
	WHERE U2D.UserID = @CurrentUsersID AND D.UserID<>@CurrentUsersID

	IF (@counter4 > 0)
	BEGIN
		SET @error_message = 'FOUND DEVICES IN MORE THAN ONE USER. (User='+CAST(@CurrentUsersID AS varchar(20)) +' Count='+CAST(@counter4 AS varchar(20))+')';
		THROW 50000, @error_message,0
		BREAK;
	END   

	SET @CurrentUsersID = @CurrentUsersID + 1
END


-------------------------------------------------------------------------------------------------
-- B. 3. Test on tree  <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------
SET @counter1 = 0
WHILE (1=1)
BEGIN

	SET @SiteID = NULL

	SELECT @SiteID = SiteID, @Site_Name = Name
	FROM Site.MainSite
	WHERE Name LIKE 'X_%'
	ORDER BY SiteID
	OFFSET @counter1 ROWS
	FETCH NEXT 1 ROWS ONLY

	IF (@SiteID IS NULL)
		BREAK;

	PRINT '***** SiteID = '+CAST(@SiteID AS varchar(20))+' | ' + 'Site_Name = [' + @Site_Name +']';
     
	SELECT @counter3 = COUNT(1)
	FROM Tree.GetSubTree(@SiteID)
	
	-- Test count number of sub sites under @SiteID
	PRINT '- GetSubTree.Count=['+CAST(@counter3 AS varchar(20))+']';
	IF (@counter3 = 0)
	BEGIN
		SET @error_message = 'Wrong number of sites (SiteID='+CAST(@SiteID AS varchar(20)) 
				+' GetSubTree.Count='+CAST(@counter3 AS varchar(20))+')';

		THROW 50000, @error_message,0
		BREAK;
	END 

	-- Test number of devices per site
	SELECT @counter2 = COUNT(1)
	FROM Tree.GetTreeDevices(@SiteID)

	SET @counter4 = @counter3 * @Devices_Count
	PRINT '- [Devices_Count * GetSubTree.Count] = ['+CAST(@counter4 AS varchar(20))+']'

	IF (@counter2 <> @counter4)
	BEGIN
		SET @error_message = 'Number of devices does NOT match (SiteID='+CAST(@SiteID AS varchar(20)) 
				+' GetTreeDevices.Count='+CAST(@counter2 AS varchar(20))
				+' [Devices_Count * GetSubTree.Count]='+CAST(@counter4 AS varchar(20))+')';

		THROW 50000, @error_message,0
		BREAK;
	END   
    
	-- Test number of customer above tree
	SET @counter4 = NULL
	SELECT @counter4 = COUNT(1) FROM [Tree].[GetUpmostUsers] (@SiteID)
	
	IF (@counter4 IS NULL OR @counter4 <> 1)
	BEGIN
		SET @error_message = 'Wrong number of UpmostUsers (SiteID='+CAST(@SiteID AS varchar(20))  +' Tree.GetUpmostUsers='+CAST(@counter4 AS VARCHAR(20)) + ')';

		THROW 50000, @error_message,0
		BREAK;
	END 	

	-- Test root tree sites
	SET @counter4 = NULL
	SELECT @counter4 = COUNT(1)
	FROM [Tree].[GetRootSite] (@SiteID, NULL)
	WHERE SiteID <> @SiteID

	SELECT @counter3 = COUNT(1)
	FROM [Tree].[GetRootSite] (@SiteID, NULL)
	WHERE SiteID = @SiteID

	PRINT '- Tree.[GetRootSite] = ['+CAST(@counter4 AS VARCHAR(20))+'] Self Site=[' + CAST(@counter3 AS VARCHAR(20)) + ']';
	
	IF (@counter4 IS NULL OR 
		@counter3 IS NULL OR @counter3 <> 1 
		OR (NOT (@Site_Name LIKE '%Level*'+CAST(@counter4 AS varchar(20))) AND NOT (@Site_Name LIKE '%Level'+CAST(@counter4 AS varchar(20)))))
	BEGIN
		SET @error_message = 'Wrong number of root sites (SiteID='+CAST(@SiteID AS varchar(20))  
					+' Site_Name=' + @Site_Name + ' Tree.[GetRootSite]='+CAST(@counter4 AS VARCHAR(20)) 
					+ ' )';

		THROW 50000, @error_message,0
		BREAK;
	END 

	-- OK, go to next site
	SET @counter1 = @counter1 + 1

END
