-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/01/2026
-- Description:	Procedure to get data for AdditionalEquipmentForOrderDetailsItems]
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-565
-- =============================================
CREATE     PROCEDURE [dbo].[GetAdditionalEquipmentForOrderDetailsItems]
@OrderDetailsItemId INT
AS
BEGIN 
SET NOCOUNT ON;

	SELECT
		d.[AdditionalEquipmentForOrderDetailsItemsId]
		,d.[EquipmentNumber]
		,d.[EquipmentName]
	FROM [dbo].[AdditionalEquipmentForOrderDetailsItems] as d
	WHERE [d].[OrderDetailsItemId] = @OrderDetailsItemId AND d.[IsDeleted] = 0

END