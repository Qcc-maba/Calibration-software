-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 23/01/2026
-- Description:	Procedure allow to store calibration cycles information.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-565
-- =============================================
CREATE   PROCEDURE [dbo].[AddCalibrationCycle]
@UserEmail NVARCHAR(50),
@OrderDetailsItemId INT,
@CalibrationCycleStartDate DATETIME2(0),
@CalibrationCycleEndDate DATETIME2(0),
@CalibrationCycleName NVARCHAR(200),
@UnitId INT,
@TestedValue DECIMAL(18,6),
@SpecificationReferenceIds NVARCHAR(100),
@CalibrationCycleStatusId INT = NULL
/*
EXEC [dbo].[AddCalibrationCycle]
@UserEmail='sinova_calibrator@gmail.com',
@OrderDetailsItemId =1300,
@CalibrationCycleStartDate ='2025-11-29 11:23:18',
@CalibrationCycleEndDate ='2025-11-29 11:33:18',
@CalibrationCycleStatusId =21 -- can be retrieved EXEC [dbo].[GetStatusByCategory] 'CalibrationStatuses'
*/
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 


IF NOT EXISTS (SELECT 1 FROM [dbo].[CalibrationCycles] WHERE [OrderDetailsItemId] = @OrderDetailsItemId AND [CalibrationCycleStartDate] =@CalibrationCycleStartDate) 

INSERT INTO [dbo].[CalibrationCycles]
           ([OrderDetailsItemId]
           ,[CalibrationCycleStartDate]
           ,[CalibrationCycleEndDate]
           ,[CalibrationCycleStatusId]
           ,[CreatedUserID]
           ,[CalibrationCycleName]
           ,[UnitId]
           ,[TestedValue]
           ,[SpecificationReferenceIds]
           )
     VALUES
           (@OrderDetailsItemId,
            @CalibrationCycleStartDate,
            @CalibrationCycleEndDate,
            @CalibrationCycleStatusId,
            @UserId,
            @CalibrationCycleName,
            @UnitId,
            @TestedValue,
            @SpecificationReferenceIds
            )





END