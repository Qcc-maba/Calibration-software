/* Rollback for MBA-1001: every object the etl retirement drops, as it stood on STAGE (Calibrator)
   captured 2026-11-18 07:38 from the live server by SMO. All tables held 0 rows, so no data.
   Re-run in SSMS against the same database to restore. Order: schema, tables, procedures, grant. */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA [etl] AUTHORIZATION [dbo]');
GO

-- ===== table etl.CalendarEvents (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalendarEvents]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalendarEvents](
	[CalendarEventId] [int] NOT NULL,
	[EventTypeId] [int] NOT NULL,
	[StartDate] [datetime2](0) NOT NULL,
	[EndDate] [datetime2](0) NOT NULL,
	[Comments] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[IsDeleted] [bit] NOT NULL,
	[UpdateUserID] [int] NULL,
	[AWSCalendarEventId] [int] NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.CalendarEventsToParticipants (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalendarEventsToParticipants]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalendarEventsToParticipants](
	[CalendarEventId] [int] NOT NULL,
	[UserId] [int] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[IsDeleted] [bit] NOT NULL,
	[UpdateUserID] [int] NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.CalibGetDataLog (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalibGetDataLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalibGetDataLog](
	[TableName] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastExecutionDate] [datetime2](0) NULL,
PRIMARY KEY CLUSTERED 
(
	[TableName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- ===== table etl.Cars (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[Cars]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[Cars](
	[CarId] [int] NOT NULL,
	[MabaNumber] [int] NULL,
	[Model] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LicenseNumber] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[Seats] [tinyint] NOT NULL,
	[TreatmentPeriod] [int] NOT NULL,
	[NextTreatmentDate] [date] NOT NULL,
	[NextYearlyTestDate] [date] NOT NULL,
	[OwnerId] [int] NULL,
	[CarStatusId] [int] NOT NULL,
	[CreateDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[AssignedCalibratorId] [int] NULL,
	[UpdateUserID] [int] NULL,
	[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.ETLExecutionLog (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[ETLExecutionLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[ETLExecutionLog](
	[ETLPackageName] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastExecutionDate] [datetime2](0) NULL,
PRIMARY KEY CLUSTERED 
(
	[ETLPackageName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- ===== table etl.Users (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[Users]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[Users](
	[ID] [int] NOT NULL,
	[FirstName] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastName] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[FirstNameEng] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[LastNameEng] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Email] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Password] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Phone] [nvarchar](20) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[UpdateUserID] [int] NULL,
	[UserAddress] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[LocationArea] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Stamp] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL
) ON [PRIMARY]
END
GO

-- ===== procedure etl.CalibGetDataLogGetSet
IF OBJECT_ID(N'[etl].[CalibGetDataLogGetSet]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[CalibGetDataLogGetSet] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[CalibGetDataLogGetSet]
@TableName [NVARCHAR](255),
@LastExecutionDate DATETIME2(0) = NULL
AS
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName)
INSERT [etl].[CalibGetDataLog]([TableName],LastExecutionDate)
VALUES(@TableName,'1900-01-01')

IF EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName) and @LastExecutionDate IS NOT NULL
UPDATE [etl].[CalibGetDataLog]
SET LastExecutionDate = @LastExecutionDate
WHERE [TableName] = @TableName

SELECT LastExecutionDate
FROM [etl].[CalibGetDataLog]
WHERE [TableName] = @TableName

GO

-- ===== procedure etl.MergeCalendarEventsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCalendarEventsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCalendarEventsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCalendarEventsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEvents] AS dest
USING (
	SELECT [CalendarEventId]
		,[EventTypeId]
		,[StartDate]
		,[EndDate]
		,[Comments]
		,[CreatedDate]
		,[UpdatedDate]
		,[IsDeleted]
		,0 as [UpdateUserID]
		,[AWSCalendarEventId]
	FROM [etl].[CalendarEvents]
	) AS source
	ON dest.AWSCalendarEventId = source.CalendarEventId
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[EventTypeId] = source.[EventTypeId]
			,dest.[StartDate] = source.[StartDate]
			,dest.[EndDate] = source.[EndDate]
			,dest.[Comments] = source.[Comments]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [EventTypeId]
			,[StartDate]
			,[EndDate]
			,[Comments]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			,[AWSCalendarEventId]
			)
		VALUES (
			 source.[EventTypeId]
			,source.[StartDate]
			,source.[EndDate]
			,source.[Comments]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			,source.[CalendarEventId]
			);

GO

-- ===== procedure etl.MergeCalendarEventsToParticipantsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCalendarEventsToParticipantsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCalendarEventsToParticipantsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCalendarEventsToParticipantsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEventsToParticipants] AS dest
USING (
	SELECT 
	     ce.[CalendarEventId]
		,u1.ID as [UserId]
		,ctp.[CreatedDate]
		,ctp.[UpdatedDate]
		,ctp.[IsDeleted]
		,u2.ID as [UpdateUserID]
	FROM [etl].[CalendarEventsToParticipants] as ctp
	JOIN [dbo].[CalendarEvents] as ce ON ce.AWSCalendarEventId = ctp.[CalendarEventId]
	LEFT JOIN [dbo].[Users] as u1 ON u1.AWSID = ctp.[UserId]
	LEFT JOIN [dbo].[Users] as u2 ON u2.AWSID = ctp.[UpdateUserID]
	) AS source
	ON dest.[CalendarEventId] = source.[CalendarEventId] AND
	   dest.[UserId] = source.[UserId] AND
	   dest.[CreatedDate] = source.[CreatedDate] 
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[CalendarEventId]
			,[UserId]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			)
		VALUES (
			source.[CalendarEventId]
			,source.[UserId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			);

GO

-- ===== procedure etl.MergeCarsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCarsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCarsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCarsToOnPrem]
AS
SELECT 1
/*
MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT 
	     c.[CarId]
		,c.[MabaNumber]
		,c.[Model]
		,c.[LicenseNumber]
		,c.[Seats]
		,c.[TreatmentPeriod]
		,c.[NextTreatmentDate]
		,c.[NextYearlyTestDate]
		,u.ID as [OwnerId]
		,c.[CarStatusId]
		,c.[CreateDate]
		,c.[UpdatedDate]
		,u1.ID as[AssignedCalibratorId]
		,0 as [UpdateUserID]
		,c.[IsDeleted]
	FROM [etl].[Cars] as c
	LEFT JOIN [dbo].[Users] as u ON c.[OwnerId] = u.AWSID
	LEFT JOIN [dbo].[Users] as u1 ON c.[AssignedCalibratorId] = u1.AWSID
	) AS source
	ON dest.AWSCarId = source.CarId
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MabaNumber] = source.[MabaNumber]
			,dest.[Model] = source.[Model]
			,dest.[LicenseNumber] = source.[LicenseNumber]
			,dest.[Seats] = source.[Seats]
			,dest.[TreatmentPeriod] = source.[TreatmentPeriod]
			,dest.[NextTreatmentDate] = source.[NextTreatmentDate]
			,dest.[NextYearlyTestDate] = source.[NextYearlyTestDate]
			,dest.[OwnerId] = source.[OwnerId]
			,dest.[CarStatusId] = source.[CarStatusId]
			,dest.[CreateDate] = source.[CreateDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[AssignedCalibratorId] = source.[AssignedCalibratorId]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[IsDeleted] = source.[IsDeleted]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaNumber]
			,[Model]
			,[LicenseNumber]
			,[Seats]
			,[TreatmentPeriod]
			,[NextTreatmentDate]
			,[NextYearlyTestDate]
			,[OwnerId]
			,[CarStatusId]
			,[CreateDate]
			,[UpdatedDate]
			,[AssignedCalibratorId]
			,[UpdateUserID]
			,[IsDeleted]
			,[AWSCarId]
			)
		VALUES (
             source.[MabaNumber]
			,source.[Model]
			,source.[LicenseNumber]
			,source.[Seats]
			,source.[TreatmentPeriod]
			,source.[NextTreatmentDate]
			,source.[NextYearlyTestDate]
			,source.[OwnerId]
			,source.[CarStatusId]
			,source.[CreateDate]
			,source.[UpdatedDate]
			,source.[AssignedCalibratorId]
			,source.[UpdateUserID]
			,source.[IsDeleted]
			,source.[CarId]
			);
*/

GO

-- ===== procedure etl.MergeUsersToOnPrem
IF OBJECT_ID(N'[etl].[MergeUsersToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeUsersToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE  [etl].[MergeUsersToOnPrem]
AS
MERGE INTO [dbo].[Users] AS dest
USING (
	SELECT [ID]
		,[FirstName]
		,[LastName]
		,[FirstNameEng]
		,[LastNameEng]
		,[Email]
		,[Password]
		,[Phone]
		,[IsActive]
		,[CreatedDate]
		,[UpdatedDate]
		,0 as [UpdateUserID]
		,[UserAddress]
		,[LocationArea]
		,[Stamp]
	FROM [etl].[Users]
	) AS source
	ON dest.AWSID = source.ID
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[FirstName] = source.[FirstName]
			,dest.[LastName] = source.[LastName]
			,dest.[FirstNameEng] = source.[FirstNameEng]
			,dest.[LastNameEng] = source.[LastNameEng]
			,dest.[Email] = source.[Email]
			,dest.[Password] = source.[Password]
			,dest.[Phone] = source.[Phone]
			,dest.[IsActive] = source.[IsActive]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[UserAddress] = source.[UserAddress]
			,dest.[LocationArea] = source.[LocationArea]
			,dest.[Stamp] = source.[Stamp]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [FirstName]
			,[LastName]
			,[FirstNameEng]
			,[LastNameEng]
			,[Email]
			,[Password]
			,[Phone]
			,[IsActive]
			,[CreatedDate]
			,[UpdatedDate]
			,[UpdateUserID]
			,[UserAddress]
			,[LocationArea]
			,[Stamp]
			,[AWSID]
			)
		VALUES (
             source.[FirstName]
			,source.[LastName]
			,source.[FirstNameEng]
			,source.[LastNameEng]
			,source.[Email]
			,source.[Password]
			,source.[Phone]
			,source.[IsActive]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[UpdateUserID]
			,source.[UserAddress]
			,source.[LocationArea]
			,source.[Stamp]
			,source.[ID]
			);

GO

-- ===== procedure stg.MergeCarsToOnPrem
IF OBJECT_ID(N'[stg].[MergeCarsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [stg].[MergeCarsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [stg].[MergeCarsToOnPrem]
AS
SELECT 1
/*MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT [CarId]
		,[MabaNumber]
		,[Model]
		,[LicenseNumber]
		,[Seats]
		,[TreatmentPeriod]
		,[NextTreatmentDate]
		,[NextYearlyTestDate]
		,[OwnerId]
		,[CarStatusId]
		,[CreateDate]
		,[UpdatedDate]
		,[AssignedCalibratorId]
		,[UpdateUserID]
		,[IsDeleted]
	FROM [stg].[Cars]
	) AS source
	ON dest.AWSCarId = source.CarId
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MabaNumber] = source.[MabaNumber]
			,dest.[Model] = source.[Model]
			,dest.[LicenseNumber] = source.[LicenseNumber]
			,dest.[Seats] = source.[Seats]
			,dest.[TreatmentPeriod] = source.[TreatmentPeriod]
			,dest.[NextTreatmentDate] = source.[NextTreatmentDate]
			,dest.[NextYearlyTestDate] = source.[NextYearlyTestDate]
			,dest.[OwnerId] = source.[OwnerId]
			,dest.[CarStatusId] = source.[CarStatusId]
			,dest.[CreateDate] = source.[CreateDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[AssignedCalibratorId] = source.[AssignedCalibratorId]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[IsDeleted] = source.[IsDeleted]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaNumber]
			,[Model]
			,[LicenseNumber]
			,[Seats]
			,[TreatmentPeriod]
			,[NextTreatmentDate]
			,[NextYearlyTestDate]
			,[OwnerId]
			,[CarStatusId]
			,[CreateDate]
			,[UpdatedDate]
			,[AssignedCalibratorId]
			,[UpdateUserID]
			,[IsDeleted]
			,[AWSCarId]
			)
		VALUES (
             source.[MabaNumber]
			,source.[Model]
			,source.[LicenseNumber]
			,source.[Seats]
			,source.[TreatmentPeriod]
			,source.[NextTreatmentDate]
			,source.[NextYearlyTestDate]
			,source.[OwnerId]
			,source.[CarStatusId]
			,source.[CreateDate]
			,source.[UpdatedDate]
			,source.[AssignedCalibratorId]
			,source.[UpdateUserID]
			,source.[IsDeleted]
			,source.[CarId]
			);
*/

GO

GRANT EXECUTE ON SCHEMA::[etl] TO [ed];
GO
