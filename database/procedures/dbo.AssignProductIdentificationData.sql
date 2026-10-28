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

    MBA-855: a new UUT serial is also written to the device's sensor table rows that carry its
    MABA No or none, so page 1 and the table show the same serial. Rows carrying another MABA No
    are left alone. Tested by database/tests/Test-AssignProductIdentificationSerialSync.sql.

    MBA-802: a humidity device (secondary category "Humidity") has a second set of Guard Band,
    tolerance and resolution for its %RH readings. They go to HumidityAccuracy, HumidityTolerance
    and HumidityResolution (database/schema/dbo.OrderDetailsItems.Humidity.sql), typed like
    Accuracy, Tolerance and Resolution, which keep holding the temperature set. Same NULL
    convention: NULL leaves the column alone.
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
	@SpecificationReferenceIds NVARCHAR(MAX) = NULL,
	/* MBA-802: the humidity set of a humidity device; the temperature set stays in
	   @Accuracy, @Tolerance and @Resolution. */
	@HumidityAccuracy TINYINT = NULL,
	@HumidityTolerance DECIMAL(18,6) = NULL,
	@HumidityResolution DECIMAL(18,6) = NULL
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
					   ,[HumidityAccuracy]
					   ,[HumidityTolerance]
					   ,[HumidityResolution]
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
					NULLIF(@SpecificationReferenceIds, ''),
					@HumidityAccuracy,
					@HumidityTolerance,
					@HumidityResolution
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

	/* MBA-855: the device's MABA No before this save, so its table rows still match it below
	   even when this same save changes the MABA No. */
	DECLARE @ItemId INT = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)
	DECLARE @MabaBefore NVARCHAR(100) = (SELECT LTRIM(RTRIM([MbaReportNumber])) FROM [dbo].[OrderDetailsItems] WHERE OrderDetailsItemId = @ItemId)

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
			,[HumidityAccuracy] = COALESCE(@HumidityAccuracy,[HumidityAccuracy])
			,[HumidityTolerance] = COALESCE(@HumidityTolerance,[HumidityTolerance])
			,[HumidityResolution] = COALESCE(@HumidityResolution,[HumidityResolution])
	WHERE [OrderDetailId] = @OrderDetailId AND OrderDetailsItemId = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)

	/* MBA-855: one UUT serial per MABA No. A new serial on the device also goes to its sensor
	   table rows that carry the device's MABA No (before or after this save) or none; rows
	   carrying another MABA No belong to another device and keep their own serial. Without
	   this, page 1 changed only the device and the table kept showing the old serial.
	   The comparison is binary, so a change of letter case alone still reaches the rows. */
	IF @SerialNumber IS NOT NULL
		UPDATE p
		SET  p.[SerialNumber] = @SerialNumber
			,p.[UpdatedDate]  = GETDATE()
			,p.[UpdateUserID] = @UserId
		FROM [dbo].[MeasurmentPointsToOrderDetailsItems] p
		JOIN [dbo].[OrderDetailsItems] i ON i.OrderDetailsItemId = p.OrderDetailsItemId
		WHERE p.OrderDetailsItemId = @ItemId
		  AND p.IsDeleted = 0
		  AND (   NULLIF(LTRIM(RTRIM(p.[MbaReportNumber])), '') IS NULL
		       OR NULLIF(LTRIM(RTRIM(i.[MbaReportNumber])), '') IS NULL
		       OR LTRIM(RTRIM(p.[MbaReportNumber])) = LTRIM(RTRIM(i.[MbaReportNumber]))
		       OR LTRIM(RTRIM(p.[MbaReportNumber])) = @MabaBefore)
		  AND ISNULL(p.[SerialNumber], N'') COLLATE Latin1_General_BIN2 <> @SerialNumber COLLATE Latin1_General_BIN2

	SELECT COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) as OrderDetailsItemId
END
