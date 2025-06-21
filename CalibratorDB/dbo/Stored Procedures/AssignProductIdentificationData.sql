-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/06/2025
-- Description:	Procedure enrich data for calibrated device in orders
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.AssignProductIdentificationData
@UserEmail NVARCHAR(50),
@OrderWorkPlanId INT,	
@OrderDetailId INT = NULL,
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
@MeasurementValueList NVARCHAR(200) = NULL,
@CalibrationProcessCommentComment NVARCHAR(MAX) = NULL
AS
BEGIN 

	DECLARE @OrderDetailIdInserted INT
	DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

	/*In some cases there are no information in order details and we need to insert it*/
	IF NOT EXISTS (SELECT 1 FROM [dbo].[OrderDetails] WHERE OrderWorkPlanId = @OrderWorkPlanId AND OrderDetailId = @OrderDetailId)
		BEGIN
			INSERT INTO [dbo].[OrderDetails]
					   ([OrderWorkPlanId]
					   ,[ActualCalibrationDate]
					   ,[NextCalibrationDate]
					   ,[SerialNumber]
					   ,[ManufacturerNumber]
					   ,[DeviceModel]
					   ,[AdditionalDeviceNumber]
					   ,[OrdersMainCategoryId]
					   ,[OrdersSecondaryCategoryId]
					   ,[OrdersDeviceManufacturerId]
					   ,[OrdersProductTypeId]
					   ,[CalibrationSpecificationId]
					   ,[SpecificationReferenceId]
					   ,[MeasurementUnitId]
					   ,[MeasurementPoints]
					   ,[MeasurementValueList]
					   ,[CreatedDate]
					   ,[CreatedByUserId]
					)
				 SELECT
					@OrderWorkPlanId,	
					@ActualCalibrationDate,	
					@NextCalibrationDate,	
					@SerialNumber,
					@ManufacturerNumber,
					@DeviceModel,	
					@AdditionalDeviceNumber,
					@OrdersMainCategoryId,
					@OrdersSecondaryCategoryId,
					@OrdersDeviceManufacturerId,
					@OrdersProductTypeId,
					@CalibrationSpecificationId,
					@SpecificationReferenceId,
					@MeasurementUnitId,
					@MeasurementPoints,
					@MeasurementValueList,
					GETDATE(),
					@UserId

				SELECT @OrderDetailIdInserted = SCOPE_IDENTITY()

		END

	UPDATE [dbo].[OrderDetails]
			SET 
			 [ActualCalibrationDate] = @ActualCalibrationDate
			,[NextCalibrationDate] = @NextCalibrationDate
			,[SerialNumber] = @SerialNumber
			,[ManufacturerNumber] = @ManufacturerNumber
			,[DeviceModel] = @DeviceModel
			,[AdditionalDeviceNumber] = @AdditionalDeviceNumber
			,[OrdersMainCategoryId] = @OrdersMainCategoryId
			,[OrdersSecondaryCategoryId] = @OrdersSecondaryCategoryId
			,[OrdersDeviceManufacturerId] = @OrdersDeviceManufacturerId
			,[OrdersProductTypeId] = @OrdersProductTypeId
			,[CalibrationSpecificationId] = @CalibrationSpecificationId
			,[SpecificationReferenceId] = @SpecificationReferenceId
			,[MeasurementUnitId] = @MeasurementUnitId
			,[MeasurementPoints] = @MeasurementPoints
			,[MeasurementValueList] = @MeasurementValueList
			,[UpdatedDate] = GETDATE()
			,[UpdateUserID] = @UserId
	WHERE [OrderWorkPlanId] = @OrderWorkPlanId AND [OrderDetailId] = COALESCE(@OrderDetailId,@OrderDetailIdInserted)
	SELECT COALESCE(@OrderDetailId,@OrderDetailIdInserted)
	IF NOT EXISTS (SELECT 1 FROM [CalibrationProcessComments] WHERE [OrderDetailsId] = COALESCE(@OrderDetailId,@OrderDetailIdInserted))
	  INSERT [CalibrationProcessComments]
		(
		   [OrderDetailsId]
		  ,[CalibrationProcessCommentComment]
		  ,[TextHash]
		  ,[CreateDate]
		  ,[UpdateUserID]
		  ,[IsDeleted]
	   )
	   SELECT
		COALESCE(@OrderDetailId,@OrderDetailIdInserted),
		COMPRESS(@CalibrationProcessCommentComment),
		BINARY_CHECKSUM(@CalibrationProcessCommentComment),
		GETDATE(),
		@UserId,
		0

		UPDATE [CalibrationProcessComments]
			SET [OrderDetailsId] = COALESCE(@OrderDetailId,@OrderDetailIdInserted)
			  ,[CalibrationProcessCommentComment] = COMPRESS(@CalibrationProcessCommentComment)
			  ,[TextHash] = BINARY_CHECKSUM([CalibrationProcessCommentComment])
			  ,[UpdatedDate] = GETDATE()
			  ,[UpdateUserID] = @UserId
		WHERE [OrderDetailsId] = COALESCE(@OrderDetailId,@OrderDetailIdInserted) AND [TextHash] <> BINARY_CHECKSUM(@CalibrationProcessCommentComment)

END