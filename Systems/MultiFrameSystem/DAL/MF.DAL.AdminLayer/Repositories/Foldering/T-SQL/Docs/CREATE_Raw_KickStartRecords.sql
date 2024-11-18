-------------------------------------------------------------------------------------------------
-- Introduction
-- Written by: Eitan.R

-- A. Prepare
--		1. Empty relevant tables
--		2. Fill types tables
--		3. Add users
--		4. Add tree to each user
--		5. Add devices to all Sites
-- B. Test
--		1. Test trees  (simple1)


----------------------------------------------------------
-- in case of troubled connection to sql 
-- run this (to kill all current connections)
-- DECLARE @kill varchar(8000) = '';
	--SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), spid) + ';'
	--FROM master..sysprocesses 
	--WHERE dbid = db_id('MFSystemAdmin_Local')

	--PRINT @kill
	--EXEC(@kill);
----------------------------------------------------------

-------------------------------------------------------------------------------------------------
-- Settings <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------

DECLARE @Users_Count		INT = 3
DECLARE @Users_StartID		INT = 20
DECLARE @Site_StartID		INT = 50
DECLARE @Device_StartID		INT = 200

DECLARE @RootSites_Count	INT = 10
DECLARE @SubSites_Count		INT = 3
DECLARE @Devices_Count		INT = 2

-------------------------------------------------------------------------------------------------
-- A. 1. Empty relevant tables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------
DECLARE @NAME_PREFIX VARCHAR(50)= 'xTEST-';
DECLARE @DEFAULT_TimeZoneID INT
DECLARE @DEFAULT_DeviceTypeID INT

SELECT TOP(1) @DEFAULT_TimeZoneID = ZoneID
from Types.GlobalizationZone
ORDER BY IsDefault DESC

SELECT TOP(1) @DEFAULT_DeviceTypeID = TypeID
FROM Device.[Types.DeviceType]

DELETE FROM [Tree].[User2Device]
FROM Tree.User2Device AS U2D
	INNER JOIN Device.MainDevice AS D ON D.DeviceID = U2D.DeviceID AND d.[Name] LIKE @NAME_PREFIX+'%'

DELETE FROM [Device].[AlertSetting]
FROM [Device].[AlertSetting] AS AT
	INNER JOIN Device.MainDevice AS D ON D.DeviceID = AT.DeviceID AND d.[Name] LIKE @NAME_PREFIX+'%'

DELETE FROM [Device].[MainDevice]
WHERE [Name] LIKE @NAME_PREFIX+'%'



DELETE FROM [Tree].[User2Site]



DELETE FROM [Account].[LoginUser]
WHERE FirstName LIKE @NAME_PREFIX+'%'

DELETE FROM [Site].[MainSite]
WHERE [Name] LIKE @NAME_PREFIX+'%'

--members
DECLARE @Message VARCHAR(MAX)

--reset IDENTITY columns
DBCC CHECKIDENT ('[Device].[MainDevice]', RESEED, @Device_StartID);
DBCC CHECKIDENT ('[Site].[MainSite]', RESEED, @Site_StartID);
DBCC CHECKIDENT ('[Account].[LoginUser]', RESEED, @Users_StartID);

IF (NOT EXISTS (
				SELECT 1
				FROM Types.GlobalizationZone))
BEGIN
	RAISERROR (15600,-1,-1, 'No Records were found in Types.GlobalizationZone');  
END

IF (NOT EXISTS (
				SELECT 1
				FROM Device.[Types.DeviceType]))
BEGIN
	RAISERROR (15600,-1,-1, 'No Records were found in Device.[Types.DeviceType]');  
END
-------------------------------------------------------------------------------------------------
-- A. 3.  Add users        <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------

DECLARE @UserID bigint = @Users_StartID+1

WHILE (@UserID < @Users_StartID+@Users_Count)
BEGIN

	INSERT [Account].[LoginUser] 
		([UserID],   [IdentityUserGUID],  [FirstName], [LastName], [TimeZoneID], [Email]) 
		VALUES 
		(@UserID, N'92a98255-669e-48d2-b547-02004bad782c', @NAME_PREFIX+N'-'+CAST(@UserID as varchar(20)), N'LastName-'+CAST(@UserID as varchar(20)), @DEFAULT_TimeZoneID, NULL)

	SET @UserID = @UserID + 1

END


-------------------------------------------------------------------------------------------------
-- A. 4. Add tree to each user  <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------
DECLARE @SiteID_temp		BIGINT = 1
DECLARE @SiteID				BIGINT = 1
DECLARE @counter1			INT = 0
DECLARE @counter2			INT = 0
DECLARE @counter3			INT = 0
DECLARE @counter4			INT = 0

SET @UserID = @Users_StartID+1

DECLARE @Site_name VARCHAR(100)
DECLARE @SiteTreeLevel INT =0
DECLARE @Sites TABLE(SiteID INT, SiteName VARCHAR(100))

WHILE (@UserID < @Users_StartID+@Users_Count)
BEGIN    
	--create 5 projects for each user
	SET @counter1 = 0
	WHILE (@counter1 < @RootSites_Count)
	BEGIN
		--SET @Site_name = 'X_User_' + CAST(@UserID AS VARCHAR(5)) + '_Level*0'

		SET @Site_name = @NAME_PREFIX + CAST(@UserID AS VARCHAR(5)) + '_Level*0'
		EXECUTE @SiteID = [Site].[AddProject]
									@Name = @Site_name
									,@UserID = @UserID

		insert into @Sites (SiteID, SiteName) values (@SiteID, @Site_name)
		
		SET @counter1 = @counter1 + 1

	END
    
	SET @UserID = @UserID + 1
END

SET @counter1=0
SET @SiteTreeLevel=0

WHILE (@SiteTreeLevel <= 5)
BEGIN	

	SET @counter1 = 0

	WHILE (1=1)
	BEGIN
  
		SET @SiteID_temp = NULL
		
		SELECT @SiteID_temp = _Sites.SiteID, @Site_name = SiteName
		FROM @Sites AS _Sites INNER JOIN Site.MainSite ON Site.MainSite.SiteID = _Sites.SiteID
		WHERE Name LIKE '%Level*'+CAST(@SiteTreeLevel AS VARCHAR(2))
		ORDER BY Site.MainSite.SiteID
		OFFSET @counter1 ROWS
		FETCH NEXT 1 ROWS ONLY
    
		IF (@SiteID_temp IS NULL)
			BREAK;

		SET @counter4 = 0
		  
		WHILE (@counter4 < @SubSites_Count)
		BEGIN
  
			IF (@counter4 = 0)
			BEGIN
				SET @Site_name = @Site_name+'_Level*'+CAST((@SiteTreeLevel+1) AS VARCHAR(2))
			END          
			ELSE
			BEGIN
				SET @Site_name = @Site_name+'_Level'+CAST((@SiteTreeLevel+1) AS VARCHAR(2))
			END
            
			EXECUTE @SiteID =[Site].[AddSite] 
						@Name = @Site_name
						,@ParentSiteID = @SiteID_temp
						,@UserID = 99

			insert into @Sites (SiteID, SiteName) values (@SiteID, @Site_name)

			SET @counter4 = @counter4 + 1
		END
        
		SET @counter1 = @counter1 + 1
	END

	SET @SiteTreeLevel = @SiteTreeLevel + 1
END


-------------------------------------------------------------------------------------------------
-- A. 5. Add devices to all Sites <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-------------------------------------------------------------------------------------------------
SET @counter1	= 0
SET @counter2	= 0
SET @counter3	= 0

DECLARE @_SN VARCHAR(20)
DECLARE @DeviceID INT
DECLARE @_DeviceName VARCHAR(100)
DECLARE @Devices TABLE(DeviceID INT, SN VARCHAR(20), DeviceName VARCHAR(100))



WHILE (1=1)
BEGIN

	SET @SiteID_temp = NULL

	SELECT @SiteID_temp = _Sites.SiteID, @Site_name = SiteName
	FROM @Sites AS _Sites 
		INNER JOIN Site.MainSite ON Site.MainSite.SiteID = _Sites.SiteID
	ORDER BY _Sites.SiteID
	OFFSET @counter1 ROWS
	FETCH NEXT 1 ROWS ONLY

	IF (@SiteID_temp IS NULL)
		BREAK;

	SET @Message = 'Adding devices to site=' + CAST(@SiteID_temp AS VARCHAR(20))
	PRINT @Message

	SET @counter3 = 0
	WHILE (@counter3 < @Devices_Count)
	BEGIN
    
		SET @_SN = RIGHT('00000000000000000000'+CAST(@counter2 AS VARCHAR(20)),16)
		SET @_DeviceName = @NAME_PREFIX+ @Site_name + '_' + @_SN

		EXECUTE @DeviceID = [Device].[CreateDevice] 
						   @SN				= @_SN
						  ,@TypeID			= @DEFAULT_DeviceTypeID
						  ,@DeviceName		= @_DeviceName
						  ,@ParentSiteID	= @SiteID_temp
						  ,@StatusID		= 0
						  ,@Lat				= 0
						  ,@Lon				= 1
						  ,@ActivatedZones	= 16

		INSERT INTO @Devices (DeviceID, SN, DeviceName) VALUES (@DeviceID, @_SN, @_DeviceName)
		SET @counter2 = @counter2 + 1
		SET @counter3 = @counter3 + 1

	END

	SET @counter1 = @counter1 + 1
END
GO

