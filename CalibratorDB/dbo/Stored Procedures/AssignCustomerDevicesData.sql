-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/05/2026
-- Description:	This SP add/update/remove customer devices. Will be used on customer dashboard. bassed on this data order will be created
--              It get appopriate customer for filtering based on @LoggedInUserEmail
--              if @@CustomerDevicesIdsToRemove parameter specified - appropriate CustomerContactId's will be removed
--              if @CustomerDeviceID specified appropriate record will be updated with data specified in rest parameters. 
--              to add new record @CustomerContactsId shouldn't be specified
-- JiraLink: 
-- =============================================

CREATE   PROCEDURE [dbo].[AssignCustomerDevicesData]
@LoggedInUserEmail NVARCHAR(100),
@CustomerDevicesIdsToRemove NVARCHAR(400) = NULL,
-- Identification & Location
@MainCategoryId INT = NULL,
@SecondaryCategoryId INT = NULL,
@CustomerSiteId INT = NULL,
@CustomerContactId INT = NULL,
-- Type & Manufacturer
@OrdersProductTypeId INT = NULL,
@Accuracy TINYINT = NULL,
@OrdersDeviceManufacturer NVARCHAR(100) = NULL,
@DeviceLocation NVARCHAR(50) = NULL,
@LastAdjustmentDate DATETIME2(0) = NULL,
-- Technical Details
@Model NVARCHAR(150) = NULL,
@SerialNumber NVARCHAR(50) = NULL,
@ManufacturerNumber NVARCHAR(100) = NULL,
@AdditionalDeviceNumber NVARCHAR(100) = NULL,
@DateFormatStructure NVARCHAR(20) = NULL,
@NextCalibrationDate DATETIME2(0) = NULL,
@CalibrationIntervalMonths TINYINT = NULL,
@ReportLanguage NVARCHAR(50) = NULL,
-- Methodology & Specs
@IsThirdPartyCalibration BIT = 0,
@BatteriesReplacement BIT = 0,
@CalibrationMethod NVARCHAR(100) = NULL,
@SpecificationReferenceId INT = NULL,
@MeasurementsSpecificationId INT = NULL,
@PrimaryMeasurmentUnitId INT = NULL,
@SecondaryMeasurmentUnitId INT = NULL,

@CustomerDeviceId INT = NULL,
@RevertDeletion BIT = NULL

AS

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT
DECLARE @CustomerId INT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
,@CustomerId = d.CustomerId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d


--Check that user don't exist and insert new one
IF (@CustomerDeviceId IS NULL AND @CustomerDevicesIdsToRemove IS NULL 
    AND NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices as c WHERE c.CustomerId = @CustomerId AND c.CustomerDeviceID = @CustomerDeviceId))

       INSERT INTO dbo.CustomerDevices (
            CustomerId,
            MainCategoryId,
            SecondaryCategoryId,
            CustomerSiteId,
            CustomerContactId,
            OrdersProductTypeId,
            Accuracy,
            OrdersDeviceManufacturer,
            DeviceLocation,
            LastAdjustmentDate,
            Model,
            SerialNumber,
            ManufacturerNumber,
            AdditionalDeviceNumber,
            DateFormatStructure,
            NextCalibrationDate,
            CalibrationIntervalMonths,
            ReportLanguage,
            IsThirdPartyCalibration,
            BatteriesReplacement,
            CalibrationMethod,
            SpecificationReferenceId,
            MeasurementsSpecificationId,
            PrimaryMeasurmentUnitId,
            SecondaryMeasurmentUnitId,
            UpdateUserID
        )
        VALUES (
            @CustomerId,
            @MainCategoryId,
            @SecondaryCategoryId,
            @CustomerSiteId,
            @CustomerContactId,
            @OrdersProductTypeId,
            @Accuracy,
            @OrdersDeviceManufacturer,
            @DeviceLocation,
            @LastAdjustmentDate,
            @Model,
            @SerialNumber,
            @ManufacturerNumber,
            @AdditionalDeviceNumber,
            @DateFormatStructure,
            @NextCalibrationDate,
            @CalibrationIntervalMonths,
            @ReportLanguage,
            @IsThirdPartyCalibration,
            @BatteriesReplacement,
            @CalibrationMethod,
            @SpecificationReferenceId,
            @MeasurementsSpecificationId,
            @PrimaryMeasurmentUnitId,
            @SecondaryMeasurmentUnitId,
            @LoggedInUserId
            )
-- If @CustomerContactsId exists update data
IF (@CustomerDevicesIdsToRemove IS NULL 
    AND EXISTS (SELECT 1 FROM dbo.CustomerDevices as c WHERE c.CustomerId = @CustomerId AND c.CustomerDeviceID = @CustomerDeviceId))
UPDATE dbo.CustomerDevices
     SET 
     [MainCategoryId] = COALESCE(@MainCategoryId,[MainCategoryId])
    ,[SecondaryCategoryId] = COALESCE(@SecondaryCategoryId,[SecondaryCategoryId])
    ,[CustomerSiteId] = COALESCE(@CustomerSiteId,[CustomerSiteId])
    ,[CustomerContactId] = COALESCE(@CustomerContactId,[CustomerContactId])
    ,[OrdersProductTypeId] = COALESCE(@OrdersProductTypeId,[OrdersProductTypeId])
    ,[Accuracy] = COALESCE(@Accuracy,[Accuracy])
    ,[OrdersDeviceManufacturer] = COALESCE(@OrdersDeviceManufacturer,[OrdersDeviceManufacturer])
    ,[DeviceLocation] = COALESCE(@DeviceLocation,[DeviceLocation])
    ,[LastAdjustmentDate] = COALESCE(@LastAdjustmentDate,[LastAdjustmentDate])
    ,[Model] = COALESCE(@Model,[Model])
    ,[SerialNumber] = COALESCE(@SerialNumber,[SerialNumber])
    ,[ManufacturerNumber] = COALESCE(@ManufacturerNumber,[ManufacturerNumber])
    ,[AdditionalDeviceNumber] = COALESCE(@AdditionalDeviceNumber,[AdditionalDeviceNumber])
    ,[DateFormatStructure] = COALESCE(@DateFormatStructure,[DateFormatStructure])
    ,[NextCalibrationDate] = COALESCE(@NextCalibrationDate,[NextCalibrationDate])
    ,[CalibrationIntervalMonths] = COALESCE(@CalibrationIntervalMonths,[CalibrationIntervalMonths])
    ,[ReportLanguage] = COALESCE(@ReportLanguage,[ReportLanguage])
    ,[IsThirdPartyCalibration] = COALESCE(@IsThirdPartyCalibration,[IsThirdPartyCalibration])
    ,[BatteriesReplacement] = COALESCE(@BatteriesReplacement,[BatteriesReplacement])
    ,[CalibrationMethod] = COALESCE(@CalibrationMethod,[CalibrationMethod])
    ,[SpecificationReferenceId] = COALESCE(@SpecificationReferenceId,[SpecificationReferenceId])
    ,[MeasurementsSpecificationId] = COALESCE(@MeasurementsSpecificationId,[MeasurementsSpecificationId])
    ,[PrimaryMeasurmentUnitId] = COALESCE(@PrimaryMeasurmentUnitId,[PrimaryMeasurmentUnitId])
    ,[SecondaryMeasurmentUnitId] = COALESCE(@SecondaryMeasurmentUnitId,[SecondaryMeasurmentUnitId])
    ,[UpdatedDate] = GETDATE()
    ,[UpdateUserID] = @LoggedInUserId
    ,[IsDeleted] = IIF(@RevertDeletion = 1,0,[IsDeleted])
WHERE CustomerId = @CustomerId AND CustomerDeviceID = @CustomerDeviceId

-- If @@CustomerContactsIdsToRemove exists delete data
IF (@CustomerDevicesIdsToRemove IS NOT NULL)
UPDATE c
SET
     [UpdatedDate] = GETDATE()
    ,[UpdateUserID] = COALESCE(@LoggedInUserId,[UpdateUserID])
    ,[IsDeleted] = 1
FROM [dbo].[CustomerDevices] as c
JOIN STRING_SPLIT(@CustomerDevicesIdsToRemove,',') as d ON c.[CustomerId] = @CustomerId AND c.[CustomerDeviceID] = d.value