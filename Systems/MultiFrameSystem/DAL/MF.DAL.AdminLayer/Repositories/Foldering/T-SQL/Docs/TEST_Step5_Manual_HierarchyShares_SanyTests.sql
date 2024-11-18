 
DECLARE @Users_StartID		INT = 20

DECLARE @SourceUserID				BIGINT	= @Users_StartID+1
DECLARE @SourceSiteID1_Upper		BIGINT	= NULL
DECLARE @SourceSiteID1_Internal	BIGINT	= NULL

DECLARE @TargetUserID				BIGINT	= @Users_StartID+2
DECLARE @TargetSiteID				BIGINT	= NULL
DECLARE @IsComplete					BIT		= 0



-----------------------------------------------------------------------------------
--share 1st project with target user as project
-----------------------------------------------------------------------------------

SET @TargetSiteID = NULL
SET @SourceSiteID1_Upper = (SELECT SiteID
	 FROM	(
			SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
			FROM Tree.User2Site AS u2s
			WHERE u2s.LinkedUserID=@SourceUserID AND ParentSiteID IS NULL
			) AS T
	WHERE T.R=1);

PRINT '-----------------------------------------------------'
PRINT 'Testing Senario :: Sharing Project (step (1/2)'
PRINT ' - UserID='+CAST(@SourceUserID AS VARCHAR(10))+ ' To UserID='+CAST(@TargetUserID AS VARCHAR(10))
PRINT ' - SiteID='+CAST(@SourceSiteID1_Upper AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))

EXEC Site.SharedUsers_Add
					--@SourceSiteID
					@SourceSiteID1_Upper,
					--@SourceUserID
					@SourceUserID,
					--@RoleModify
					1,
					--@RoleViewOnly
					1,
					--@RoleControlRT 
					1,
					--@RoleAdmin
					1,
					--Email
					NULL, 
					--TargetUserID		
					@TargetUserID,
					@IsComplete OUTPUT
IF (@IsComplete = 1)          
BEGIN
	PRINT 'Failed! Share_Add shouldn''t have complete the proccess';
	THROW 50100,'>> TEST FAILED AND TERMINATED!',1
END

EXEC Site.SharedUsers_Accept
	@SourceSiteID		= @SourceSiteID1_Upper,
	@TargetUserID		= @TargetUserID,
	@TargetSiteID		= @TargetSiteID


-----------------------------------------------------------------------------------
--now, share a site that already exists in target user (thanks to previous share)
-----------------------------------------------------------------------------------
SET @SourceSiteID1_Internal = (SELECT SiteID
	 FROM (	SELECT S.SiteID, ROW_NUMBER()OVER (ORDER BY S.SiteID) AS R1		
			FROM Site.MainSite AS S
				INNER JOIN 
					(SELECT SiteID
					FROM	(
							SELECT SiteID, ROW_NUMBER() OVER (ORDER BY SiteID) AS R
							FROM Tree.User2Site AS u2s
							WHERE u2s.LinkedUserID=@SourceUserID AND ParentSiteID IS NULL
							) AS T
					WHERE T.R=1) AS T2 ON S.ParentSiteID = T2.SiteID) AS T2
	WHERE R1=2)

PRINT '-----------------------------------------------------'
PRINT 'Testing Senario :: Sharing sub site from previous Project (step (2/2)'
PRINT ' - UserID='+CAST(@SourceUserID AS VARCHAR(10))+ ' To UserID='+CAST(@TargetUserID AS VARCHAR(10))
PRINT ' - SiteID='+CAST(@SourceSiteID1_Internal AS VARCHAR(10))+ ' To SiteID='+IIF(@TargetSiteID IS NULL, '<NULL>',CAST(@TargetSiteID AS VARCHAR(10)))


EXEC Site.SharedUsers_Add
					--@SourceSiteID
					@SourceSiteID1_Internal,
					--@SourceUserID
					@SourceUserID,
					--@RoleModify
					0,
					--@RoleViewOnly
					1,
					--@RoleControlRT 
					1,
					--@RoleAdmin
					0,
					--Email
					NULL, 
					--TargetUserID		= 
					@TargetUserID,
					@IsComplete OUTPUT
IF (@IsComplete = 0)          
BEGIN
	PRINT 'Failed! Share_Add shoud have complete the proccess..';
	THROW 50100,'>> TEST FAILED AND TERMINATED!',1
END

--print target tree (filter to relevant new project only)

EXEC Tree.[TEST.PrintTree]
	@UserID			= @TargetUserID,
    @Search			= NULL,
    @PageSize		= 10000,
    @OFFSET			= 0,
	@PrintSelect	= 1,
	@ResultTitle	= 'AFTER TEST'
	--@FilterSiteID	= @SourceSiteID1_Upper
