/*
    dbo.AssignProductIdentificationData                                                MBA-577
    ---------------------------------------------------------------------------------------------
    Saves the Identification page. This copy adds the three fields the sensor calibration wizard
    needs, which the front end was already sending and the procedure was rejecting:

        Tolerance                  "סטייה מותרת"   DECIMAL(18,6)
        Resolution                 "רזולוציה"      DECIMAL(18,6)
        SpecificationReferenceIds  reference docs  NVARCHAR(MAX), a CSV of ids

    Why a CSV and not a link table
    ------------------------------
    Reference Document became multi-select. The column that held it, SpecificationReferenceId, is
    a single INT and stays exactly as it was so anything still sending it keeps working. The new
    column follows MeasurementValueList on the same table - a comma-separated list in one NVARCHAR
    - because that is the pattern this table already uses and the one the front end is coded to.
    A proper link table would be tidier and is a separate change.

    The NULL convention, and the one place it breaks
    ------------------------------------------------
    Every parameter here means "leave it alone" when NULL. That works for Tolerance and Resolution.
    It does not work for a multi-select: deselecting every reference document has to be storable,
    and under COALESCE the last selection would be impossible to remove. So an empty string clears
    the column and NULL leaves it - the same shape DiagramMapLink already uses on the line above.

    Round-tripped on STAGE against a live item: write, clear-the-list, restore.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/06/2025
-- Description:	Procedure enrich data for calibrated device in orders
-- JiraLink: 
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignProductIdentificationData]
@UserEmail NVARCHAR(50),
@OrderDetailId INT,
@OrderDetailsItemId INT = NULL,
@ActualCalibrationDate DATETIME2(0)= NULL,	
@NextCalibrationDate DATETIME2(0)= NULL,	
@SerialNumber NVARCHAR(100)= NULL,
@ManufacturerNumber	NVARCHAR(100)= NULL,
@DeviceModel NVARCHAR(100)= NULL,	
@AdditionalDeviceNumber NVARCHAR(100)= NULL,
@OrdersMainCategoryId INT= NULL,
@OrdersSecondaryCategoryId INT= NULL,
@OrdersDeviceManufacturer NVARCHAR(100) = NULL,
@OrdersProductTypeId INT= NULL,
@CalibrationSpecificationId INT= NULL,
@SpecificationReferenceId INT= NULL,
@MeasurementUnitId INT= NULL,
@MeasurementPoints INT= NULL,
@MeasurementValueList NVARCHAR(MAX) = NULL,
@OrderLineCnt_new INT = NULL,
@Accuracy TINYINT = NULL,
@MbaReportNumber NVARCHAR(100) =NULL,
@StickerAmount TINYINT = NULL,
@StickerTypeId INT = NULL,
@SecondCalibratorId INT = NULL,
@MainCalibratorId INT = NULL,
@Volume DECIMAL(16,4) = NULL,
@VisualCheck NVARCHAR(200) = NULL,
@ShouldShowGraphV BIT = NULL, 
@ShouldShowCertificateIcon BIT = NULL,
@RequiredProbability TINYINT = NULL,
@ReportLanguage NVARCHAR(50) = NULL,
@SiteAddress NVARCHAR(100) = NULL,
@ProductLocation NVARCHAR(50) = NULL,
@ControllerType NVARCHAR(40) = NULL,
@DiagramMapLink NVARCHAR(200) = NULL,
	/* MBA-577: sensor identification. Tolerance and Resolution are scalar.
	   SpecificationReferenceIds is a CSV because Reference Document became multi-select;
	   the older singular SpecificationReferenceId is left in place so anything still
	   sending it keeps working. */
	@Tolerance DECIMAL(18,6) = NULL,
	@Resolution DECIMAL(18,6) = NULL,
	@SpecificationReferenceIds NVARCHAR(MAX) = NULL
AS
BEGIN 

	DECLARE @OrderDetailItemIdInserted INT
	DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

	/*In some cases there are no information in order details and we need to insert it*/
	IF NOT EXISTS (SELECT 1 FROM [dbo].[OrderDetailsItems] WHERE OrderDetailId = @OrderDetailId AND OrderDetailsItemId =@OrderDetailsItemId )
		BEGIN
			INSERT INTO [dbo].[OrderDetailsItems]
					   ([OrderDetailId]
					   ,[ActualCalibrationDate]
					   ,[NextCalibrationDate]
					   ,[SerialNumber]
					   ,[ManufacturerNumber]
					   ,[DeviceModel]
					   ,[AdditionalDeviceNumber]
					   ,[CalibrationSpecificationId]
					   ,[SpecificationReferenceId]
					   ,[MeasurementUnitId]
					   ,[MeasurementPoints]
					   ,[MeasurementValueList]
					   ,[CreatedDate]
					   ,[CreatedByUserId]
					   ,[Accuracy]
					   ,[IsManuallyAdded]
					   ,[MbaReportNumber]
					   ,[StickerAmount]
					   ,[StickerTypeId]
					   ,[SecondCalibratorId]
					   ,[MainCalibratorId]
					   ,[Volume]
					   ,[VisualCheck]
					   ,[ShouldShowGraphV]
					   ,[ShouldShowCertificateIcon]
					   ,[RequiredProbability]
					   ,[ReportLanguage]
					   ,[SiteAddress]
					   ,[ProductLocation]
					   ,[OrdersDeviceManufacturer] 
					   ,[ControllerType]
					   ,[DiagramMapLink]
					   ,[Tolerance]
					   ,[Resolution]
					   ,[SpecificationReferenceIds]
					)
				 SELECT
					@OrderDetailId,	
					@ActualCalibrationDate,	
					@NextCalibrationDate,	
					@SerialNumber,
					@ManufacturerNumber,
					@DeviceModel,	
					@AdditionalDeviceNumber,
					@CalibrationSpecificationId,
					@SpecificationReferenceId,
					@MeasurementUnitId,
					@MeasurementPoints,
					@MeasurementValueList,
					GETDATE(),
					@UserId,
					@Accuracy,
					1,
					@MbaReportNumber,
					@StickerAmount,
					@StickerTypeId,
					@SecondCalibratorId,
					@MainCalibratorId,
					@Volume,
					@VisualCheck,
					@ShouldShowGraphV,
					@ShouldShowCertificateIcon,
					@RequiredProbability,
					@ReportLanguage,
					@SiteAddress,
					@ProductLocation,
					@OrdersDeviceManufacturer,
					@ControllerType,
					@DiagramMapLink,
					@Tolerance,
					@Resolution,
					NULLIF(@SpecificationReferenceIds, '')
				SELECT @OrderDetailItemIdInserted = SCOPE_IDENTITY()

		END

	UPDATE [dbo].[OrderDetails] 
	SET [OrdersProductTypeId] = IIF(@OrdersProductTypeId IS NULL,[OrdersProductTypeId], @OrdersProductTypeId)
		,[MainCategoryId] = IIF(@OrdersMainCategoryId IS NULL,[MainCategoryId], @OrdersMainCategoryId)
		,[SecondaryCategoryId] =IIF(@OrdersSecondaryCategoryId IS NULL,[SecondaryCategoryId],@OrdersSecondaryCategoryId)
	WHERE OrderDetailId = @OrderDetailId-- AND [OrdersProductTypeId] <> @OrdersProductTypeId

	UPDATE [dbo].[OrderDetails] 
	SET [OrderLineCnt] = IIF(@OrderLineCnt_new IS NULL,[OrderLineCnt], @OrderLineCnt_new)
	WHERE OrderDetailId = @OrderDetailId AND [OrderLineCnt] <> COALESCE(@OrderLineCnt_new,[OrderLineCnt])

	UPDATE [dbo].[OrderDetailsItems]
			SET 
			 [ActualCalibrationDate] = IIF(@ActualCalibrationDate IS NULL,[ActualCalibrationDate],@ActualCalibrationDate)
			,[NextCalibrationDate] = IIF(@NextCalibrationDate IS NULL,[NextCalibrationDate],@NextCalibrationDate)
			,[SerialNumber] = IIF(@SerialNumber IS NULL,[SerialNumber],@SerialNumber)
			,[ManufacturerNumber] = IIF(@ManufacturerNumber IS NULL,[ManufacturerNumber],@ManufacturerNumber)
			,[DeviceModel] = IIF(@DeviceModel IS NULL,[DeviceModel],@DeviceModel)
			,[AdditionalDeviceNumber] = IIF(@AdditionalDeviceNumber IS NULL,[AdditionalDeviceNumber],@AdditionalDeviceNumber)
			,[CalibrationSpecificationId] = IIF(@CalibrationSpecificationId IS NULL,[CalibrationSpecificationId],@CalibrationSpecificationId)
			,[SpecificationReferenceId] = IIF(@SpecificationReferenceId IS NULL,[SpecificationReferenceId],@SpecificationReferenceId)
			,[MeasurementUnitId] = IIF(@MeasurementUnitId IS NULL,[MeasurementUnitId],@MeasurementUnitId)
			,[MeasurementPoints] = IIF(@MeasurementPoints IS NULL,[MeasurementPoints],@MeasurementPoints)
			,[MeasurementValueList] = IIF(@MeasurementValueList IS NULL,[MeasurementValueList],@MeasurementValueList)
			,[UpdatedDate] = GETDATE()
			,[UpdateUserID] = @UserId
			,[Accuracy] = IIF(@Accuracy IS NULL,[Accuracy],@Accuracy)
			,[MbaReportNumber] = IIF(@MbaReportNumber IS NULL,[MbaReportNumber],@MbaReportNumber)
			,[StickerAmount] = IIF(@StickerAmount IS NULL,[StickerAmount],@StickerAmount)
			,[StickerTypeId] = IIF(@StickerTypeId IS NULL,[StickerTypeId],@StickerTypeId)
			,[SecondCalibratorId] = COALESCE(@SecondCalibratorId,[SecondCalibratorId])
			,[MainCalibratorId] = COALESCE(@MainCalibratorId,[MainCalibratorId])
			,[Volume] = COALESCE(@Volume,[Volume])
			,[VisualCheck] = COALESCE(@VisualCheck,[VisualCheck])
			,[ShouldShowGraphV] = COALESCE(@ShouldShowGraphV,[ShouldShowGraphV])
			,[ShouldShowCertificateIcon] = COALESCE(@ShouldShowCertificateIcon,[ShouldShowCertificateIcon])
			,[RequiredProbability] = COALESCE(@RequiredProbability,[RequiredProbability])
			,[ReportLanguage] = COALESCE(@ReportLanguage,[ReportLanguage])
			,[SiteAddress] = COALESCE(@SiteAddress,[SiteAddress])
			,[ProductLocation] = COALESCE(@ProductLocation,[ProductLocation])
			,[OrdersDeviceManufacturer] = COALESCE(@OrdersDeviceManufacturer,[OrdersDeviceManufacturer])
			,[ControllerType] = COALESCE(@ControllerType,[ControllerType])
			,[DiagramMapLink] = IIF(@DiagramMapLink ='',NULL,COALESCE(@DiagramMapLink,[DiagramMapLink]))
			,[Tolerance] = COALESCE(@Tolerance,[Tolerance])
			,[Resolution] = COALESCE(@Resolution,[Resolution])
			/* '' clears the selection, NULL leaves it alone. Deselecting every reference
			   document has to be storable, and COALESCE on its own would make that
			   impossible. Same shape as DiagramMapLink above. */
			,[SpecificationReferenceIds] = IIF(@SpecificationReferenceIds = '',NULL,COALESCE(@SpecificationReferenceIds,[SpecificationReferenceIds]))
	WHERE [OrderDetailId] = @OrderDetailId AND OrderDetailsItemId = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)

	SELECT COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) as OrderDetailsItemId
END
