-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/12/2025
-- Description:	Get calibrator notification data
-- =============================================

CREATE   PROCEDURE dbo.GetCalibratorNotification
@CalibratorId INT,
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 10,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CreatedDate',      -- OrderBy column
@OrderByAsc AS BIT = 0                  -- OrderBy direction (ASC/DESC)

-- EXEC dbo.GetCalibratorNotification @CalibratorId = 13, @OrderBy= N'CreatedDate', @OrderByAsc=0

AS

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT cn.[CalibratorId]  
      ,cn.[CalibratorNotificationId]
      ,cn.[OrderWorkPlanId]
      ,cn.[OrderDetailId]
      ,cn.[OrderDetailItemId]
      ,cn.[NotificationText]
      ,cn.[NotificationTypeId]
      ,st.[StatusDescriptionHEB] as [NotificationType]
      ,cn.[ResolvedDate]
      ,cn.[CreatedDate]
      ,cn.[IsRead]
FROM [dbo].[CalibratorNotifications] as cn
LEFT JOIN [dbo].[Statuses] as st ON cn.[NotificationTypeId] = st.StatusId
WHERE cn.[CalibratorId] =', @CalibratorId,'
AND cn.[IsDeleted] = 0'
,  ' ORDER BY [' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN '] ASC' WHEN @OrderByAsc = 0 THEN '] DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)