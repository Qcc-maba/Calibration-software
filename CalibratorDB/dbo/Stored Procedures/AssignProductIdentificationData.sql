-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/06/2025
-- Description:	Procedure enrich data for calibrated device in orders
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignProductIdentificationData]
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
@OrdersDeviceManufacturerId INT= NULL,
@OrdersProductTypeId INT= NULL,
@CalibrationSpecificationId INT= NULL,
@SpecificationReferenceId INT= NULL,
@MeasurementUnitId INT= NULL,
@MeasurementPoints INT= NULL,
@MeasurementValueList NVARCHAR(MAX) = NULL,
@CalibrationProcessComment NVARCHAR(MAX) = NULL,
@OrderLineCnt_new INT = NULL,
@Accuracy TINYINT = NULL,
@MbaReportNumber NVARCHAR(100) =NULL,
@StickerAmount TINYINT = NULL,
@StickerTypeId INT = NULL,
@SecondCalibratorId INT = NULL,
@MainCalibratorId INT = NULL,
@Volume DECIMAL(16,4) = NULL,
@VisualCheck NVARCHAR(200) = NULL
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
					   ,[OrdersDeviceManufacturerId]
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
					)
				 SELECT
					@OrderDetailId,	
					@ActualCalibrationDate,	
					@NextCalibrationDate,	
					@SerialNumber,
					@ManufacturerNumber,
					@DeviceModel,	
					@AdditionalDeviceNumber,
					@OrdersDeviceManufacturerId,

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
					@VisualCheck
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
			,[OrdersDeviceManufacturerId] = IIF(@OrdersDeviceManufacturerId IS NULL,[OrdersDeviceManufacturerId],@OrdersDeviceManufacturerId)
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
	WHERE [OrderDetailId] = @OrderDetailId AND OrderDetailsItemId = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)

	IF NOT EXISTS (SELECT 1 FROM [dbo].[CalibrationProcessComments] WHERE [OrderDetailsItemId] = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted))
	  BEGIN
		  INSERT [dbo].[CalibrationProcessComments]
			(
			   [OrderDetailsItemId]
			  ,[CalibrationProcessComment]
			  ,[TextHash]
			  ,[CreateDate]
			  ,[UpdateUserID]
			  ,[IsDeleted]
		   )
		   SELECT
			COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted),
			COMPRESS(@CalibrationProcessComment),
			BINARY_CHECKSUM(@CalibrationProcessComment),
			GETDATE(),
			@UserId,
			0
	END
		UPDATE [dbo].[CalibrationProcessComments]
			SET [OrderDetailsItemId] = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)
			  ,[CalibrationProcessComment] = IIF(@CalibrationProcessComment IS NULL,[CalibrationProcessComment],COMPRESS(@CalibrationProcessComment))
			  ,[TextHash] = BINARY_CHECKSUM(IIF(@CalibrationProcessComment IS NULL,[CalibrationProcessComment],@CalibrationProcessComment))
			  ,[UpdatedDate] = GETDATE()
			  ,[UpdateUserID] = @UserId
		WHERE [OrderDetailsItemId] = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) AND [TextHash] <> BINARY_CHECKSUM(@CalibrationProcessComment)

		SELECT COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) as OrderDetailsItemId
END