-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should cancel orders. It should take an array of order IDs and return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-176
-- =============================================
CREATE   PROCEDURE [dbo].[CancelOrders]
@OrderIDs NVARCHAR(2000)

--EXEC dbo.CancelOrders @OrderIDs = N'LA24101259,LA24101282,LA24101290,LA24101296,LA24101306,LA24101328'

AS
BEGIN

SET NOCOUNT ON;

DROP TABLE IF EXISTS #OrderIDs 
CREATE TABLE #OrderIDs
(
OrderNumber NVARCHAR(20) COLLATE Latin1_General_100_CI_AI_SC
)

INSERT #OrderIDs(OrderNumber)
SELECT Value FROM dbo.ParseCSVToTable(@OrderIDs)

UPDATE o
SET o.IsCancelled = 1
FROM [dbo].[OrderWorkPlans] as o
JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber

END