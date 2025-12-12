-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 11/12/2025
-- Description:	Get packing information based on order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetPackingInfo
@OrderWorkPlanId INT
AS

SELECT 
od.OrderWorkPlanId,
COUNT(pb.PackingBoxId) OVER (PARTITION BY od.OrderWorkPlanId ORDER BY od.OrderWorkPlanId) as BoxesCount,
pb.PackingBoxId,
pb.BarCode,
COUNT(itm.OrderDetailsItemId) AS CountDevicesInBox,
STRING_AGG(itm.OrderDetailsItemId,',') as OrderDetailsItemsId
FROM [dbo].[PackingBox] as pb
LEFT JOIN [dbo].[PackingBoxToOrderDetailsItems] as itm ON pb.PackingBoxId = itm.PackingBoxId
JOIN [dbo].[OrderDetailsItems] as ordi ON ordi.OrderDetailsItemId = itm.OrderDetailsItemId
JOIN [dbo].[OrderDetails] as od ON ordi.OrderDetailId = od.OrderDetailId
WHERE pb.IsDeleted = 0 AND itm.IsDeleted = 0
AND (od.OrderWorkPlanId = @OrderWorkPlanId) 
GROUP BY od.OrderWorkPlanId,
pb.PackingBoxId,
pb.BarCode