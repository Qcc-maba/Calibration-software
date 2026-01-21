-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/01/2026
-- Description:	Procedure to set data for AdditionalEquipmentForOrderDetailsItems]
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-565
-- =============================================
CREATE     PROCEDURE [dbo].[AssignAdditionalEquipmentForOrderDetailsItems]
@UserEmail NVARCHAR(50),
@json NVARCHAR(MAX) = NULL,
@IdsToBeDeleted NVARCHAR(MAX) = NULL
AS
BEGIN 
SET NOCOUNT ON;

	DECLARE @OrderDetailItemIdInserted INT
	DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 


	MERGE INTO [dbo].[AdditionalEquipmentForOrderDetailsItems] AS dest
	USING (
		SELECT
			a.OrderDetailsItemId,
			j.EquipmentNumber,
			j.EquipmentName
		FROM OPENJSON(@json)
		WITH
		(
			OrderDetailsItemId INT '$.OrderDetailsItemId',
			Equipment       nvarchar(max) '$.Equipment' AS JSON
		) a
		OUTER APPLY OPENJSON(a.Equipment)
		WITH
		(
			EquipmentNumber nvarchar(50) '$.EquipmentNumber',
			EquipmentName nvarchar(100) '$.EquipmentName'
		) j
		) AS source
		ON dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		AND dest.[EquipmentNumber] = source.[EquipmentNumber]
	WHEN MATCHED AND dest.[EquipmentName] <> source.[EquipmentName]
		THEN
			UPDATE
			SET  dest.[EquipmentName] = source.[EquipmentName]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = @UserId
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[OrderDetailsItemId]
				,[EquipmentNumber]
				,[EquipmentName]
				,[CreateDate]
				)
			VALUES (
				source.[OrderDetailsItemId]
				,source.[EquipmentNumber]
				,source.[EquipmentName]
				,GETDATE()
				);

	IF @IdsToBeDeleted IS NOT NULL
	
	UPDATE d
	SET IsDeleted = 1,
	    [UpdateUserID] = @UserId
	FROM [dbo].[AdditionalEquipmentForOrderDetailsItems] AS d
	JOIN STRING_SPLIT(@IdsToBeDeleted,',') as s ON d.OrderDetailsItemId > 0 AND d.AdditionalEquipmentForOrderDetailsItemsId = s.Value

END