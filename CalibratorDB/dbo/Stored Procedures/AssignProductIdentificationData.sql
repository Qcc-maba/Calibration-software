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
@OrderLineCnt_new INT = NULL
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
					   ,[MainCategoryId]
					   ,[OrdersSecondaryCategoryId]
					   ,[OrdersDeviceManufacturerId]
					   ,[CalibrationSpecificationId]
					   ,[SpecificationReferenceId]
					   ,[MeasurementUnitId]
					   ,[MeasurementPoints]
					   ,[MeasurementValueList]
					   ,[CreatedDate]
					   ,[CreatedByUserId]
					)
				 SELECT
					@OrderDetailId,	
					@ActualCalibrationDate,	
					@NextCalibrationDate,	
					@SerialNumber,
					@ManufacturerNumber,
					@DeviceModel,	
					@AdditionalDeviceNumber,
					@OrdersMainCategoryId,
					@OrdersSecondaryCategoryId,
					@OrdersDeviceManufacturerId,

					@CalibrationSpecificationId,
					@SpecificationReferenceId,
					@MeasurementUnitId,
					@MeasurementPoints,
					@MeasurementValueList,
					GETDATE(),
					@UserId

				SELECT @OrderDetailItemIdInserted = SCOPE_IDENTITY()

		END

	UPDATE [dbo].[OrderDetails] 
	SET [OrdersProductTypeId] = @OrdersProductTypeId
	WHERE OrderDetailId = @OrderDetailId AND [OrdersProductTypeId] <> @OrdersProductTypeId

	UPDATE [dbo].[OrderDetails] 
	SET [OrderLineCnt] = @OrderLineCnt_new
	WHERE OrderDetailId = @OrderDetailId AND [OrderLineCnt] <> COALESCE(@OrderLineCnt_new,[OrderLineCnt])

	UPDATE [dbo].[OrderDetailsItems]
			SET 
			 [ActualCalibrationDate] = @ActualCalibrationDate
			,[NextCalibrationDate] = @NextCalibrationDate
			,[SerialNumber] = @SerialNumber
			,[ManufacturerNumber] = @ManufacturerNumber
			,[DeviceModel] = @DeviceModel
			,[AdditionalDeviceNumber] = @AdditionalDeviceNumber
			,[MainCategoryId] = @OrdersMainCategoryId
			,[OrdersSecondaryCategoryId] = @OrdersSecondaryCategoryId
			,[OrdersDeviceManufacturerId] = @OrdersDeviceManufacturerId
			,[CalibrationSpecificationId] = @CalibrationSpecificationId
			,[SpecificationReferenceId] = @SpecificationReferenceId
			,[MeasurementUnitId] = @MeasurementUnitId
			,[MeasurementPoints] = @MeasurementPoints
			,[MeasurementValueList] = @MeasurementValueList
			,[UpdatedDate] = GETDATE()
			,[UpdateUserID] = @UserId
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
			  ,[CalibrationProcessComment] = COMPRESS(@CalibrationProcessComment)
			  ,[TextHash] = BINARY_CHECKSUM([CalibrationProcessComment])
			  ,[UpdatedDate] = GETDATE()
			  ,[UpdateUserID] = @UserId
		WHERE [OrderDetailsItemId] = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) AND [TextHash] <> BINARY_CHECKSUM(@CalibrationProcessComment)

		SELECT COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) as OrderDetailsItemId
END