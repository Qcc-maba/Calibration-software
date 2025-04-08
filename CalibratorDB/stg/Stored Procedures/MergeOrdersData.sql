-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Merge orders data from amaba
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeOrdersData]
AS
BEGIN

DECLARE @dt DATETIME2(0) = GETDATE()

MERGE INTO [dbo].[OrderWorkPlans] AS dest
USING (
	SELECT DISTINCT [OrderNumber]
		,[OpenDate] AS [WorkPlanOpenDate]
		,GETDATE() AS [CreatedDate]
		,0 AS [CreatedByUserId]
	FROM [stg].[stg_Orders]
	) AS source
	ON dest.[OrderNumber] = source.[OrderNumber]
WHEN MATCHED
	AND dest.[WorkPlanOpenDate] <> source.[WorkPlanOpenDate]
	THEN
		UPDATE
		SET dest.[WorkPlanOpenDate] = source.[WorkPlanOpenDate]
			,dest.[UpdatedDate] = @dt
			,dest.[UpdatedByUserId] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderNumber]
			,[WorkPlanOpenDate]
			,[CreatedByUserId]
			)
		VALUES (
			source.[OrderNumber]
			,source.[WorkPlanOpenDate]
			,0
			);

MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT DISTINCT wp.[OrderWorkPlanId]
		,o.[CustomerName]
		,o.[CustomerCity]
		,o.[CustomerID]
		,o.[CustomerPhone]
		,o.[CustomerContactName]
		,o.[CustomerAddress]
		,o.[CustomerContactPhone]
		,o.[MBAContactName]
		,o.[MBAContactPhone]
		,o.[MBAContactMobile]
		,o.[InHouse] AS [IsInHouse]
		,NULL AS [Notes]
		,o.[PartName]
		,o.[DeviceDescription] as [SecondCategory]
		,o.DepartmentName as [MainCategory]
		,o.[MbaReportNumber]
		,o.[CalibDate]
		,o.[NextCalibDate]
		,o.[CALIBMONTH]
		,o.[ReturnDate]
		,o.[PartDescription]
		,0 AS [IsCancelled]
		,s.StatusId
		,o.[CalibStatud]
		,o.[PART]
		,o.[SerialNumber]
		,o.[DeviceManufacturer]
		,o.Devicemodel AS [DeviceModel]
		,o.[Klita]
		,0 AS [CreatedByUserId]
		--add special care
	FROM [stg].[stg_Orders] AS o
	JOIN [dbo].[OrderWorkPlans] AS wp ON o.OrderNumber = wp.OrderNumber
	LEFT JOIN [dbo].[Statuses] AS s ON o.CalibStatud = s.StatusDescriptionHEB
		AND s.StatusCategoryId = 12
	WHERE o.[Klita] IS NOT NULL
		AND o.MbaReportNumber IS NOT NULL
	) AS source
	ON dest.[Klita] = source.[Klita]
		AND dest.MbaReportNumber = source.MbaReportNumber
		AND dest.[OrderWorkPlanId] = source.[OrderWorkPlanId]
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[CustomerName] = source.[CustomerName]
			,dest.[CustomerCity] = source.[CustomerCity]
			,dest.[CustomerID] = source.[CustomerID]
			,dest.[CustomerPhone] = source.[CustomerPhone]
			,dest.[CustomerContactName] = source.[CustomerContactName]
			,dest.[CustomerAddress] = source.[CustomerAddress]
			,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
			,dest.[MBAContactName] = source.[MBAContactName]
			,dest.[MBAContactPhone] = source.[MBAContactPhone]
			,dest.[MBAContactMobile] = source.[MBAContactMobile]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[Notes] = source.[Notes]
			,dest.[PartName] = source.[PartName]
			,dest.[SecondCategory] = source.[SecondCategory]
			,dest.[MainCategory] = source.[MainCategory]
			,dest.[CalibDate] = source.[CalibDate]
			,dest.[NextCalibDate] = source.[NextCalibDate]
			,dest.[CALIBMONTH] = source.[CALIBMONTH]
			,dest.[ReturnDate] = source.[ReturnDate]
			,dest.[PartDescription] = source.[PartDescription]
			,dest.[IsCancelled] = source.[IsCancelled]
			,dest.[StatusId] = source.[StatusId]
			,dest.[CalibStatud] = source.[CalibStatud]
			,dest.[PART] = source.[PART]
			,dest.[SerialNumber] = source.[SerialNumber]
			,dest.[DeviceManufacturer] = source.[DeviceManufacturer]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[UpdatedDate] = @dt
			,dest.[UpdatedByUserId] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[CustomerName]
			,[CustomerCity]
			,[CustomerID]
			,[CustomerPhone]
			,[CustomerContactName]
			,[CustomerAddress]
			,[CustomerContactPhone]
			,[MBAContactName]
			,[MBAContactPhone]
			,[MBAContactMobile]
			,[IsInHouse]
			,[Notes]
			,[PartName]
			,[SecondCategory]
			,[MainCategory]
			,[MbaReportNumber]
			,[CalibDate]
			,[NextCalibDate]
			,[CALIBMONTH]
			,[ReturnDate]
			,[PartDescription]
			,[IsCancelled]
			,[StatusId]
			,[CalibStatud]
			,[PART]
			,[SerialNumber]
			,[DeviceManufacturer]
			,[DeviceModel]
			,[Klita]
			,[CreatedByUserId]
			)
		VALUES (
			source.[OrderWorkPlanId]
			,source.[CustomerName]
			,source.[CustomerCity]
			,source.[CustomerID]
			,source.[CustomerPhone]
			,source.[CustomerContactName]
			,source.[CustomerAddress]
			,source.[CustomerContactPhone]
			,source.[MBAContactName]
			,source.[MBAContactPhone]
			,source.[MBAContactMobile]
			,source.[IsInHouse]
			,source.[Notes]
			,source.[PartName]
			,source.[SecondCategory]
			,source.[MainCategory]
			,source.[MbaReportNumber]
			,source.[CalibDate]
			,source.[NextCalibDate]
			,source.[CALIBMONTH]
			,source.[ReturnDate]
			,source.[PartDescription]
			,source.[IsCancelled]
			,source.[StatusId]
			,source.[CalibStatud]
			,source.[PART]
			,source.[SerialNumber]
			,source.[DeviceManufacturer]
			,source.[DeviceModel]
			,source.[Klita]
			,0
			);

MERGE INTO [dbo].[ClientRemarks] AS dest
USING (
	SELECT o.ClientRemarks AS [ClientRemark]
		,d.OrderDetailId
		,HASHBYTES('SHA2_256', o.ClientRemarks) AS TextHash
	FROM [stg].[stg_Orders] AS o
	JOIN [dbo].[OrderWorkPlans] AS wp ON o.OrderNumber = wp.OrderNumber
	JOIN [dbo].[OrderDetails] AS d ON wp.OrderWorkPlanId = d.OrderWorkPlanId
		AND o.MbaReportNumber = d.MbaReportNumber
		AND o.Klita = d.Klita
	) AS source
	ON dest.OrderDetailId = source.OrderDetailId
WHEN MATCHED
	AND dest.[TextHash] <> source.[TextHash]
	THEN
		UPDATE
		SET dest.[ClientRemark] = source.[ClientRemark]
			,dest.[TextHash] = source.[TextHash]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[ClientRemark]
			,[OrderDetailId]
			,[TextHash]
			)
		VALUES (
			source.[ClientRemark]
			,source.[OrderDetailId]
			,source.[TextHash]
			);

UPDATE d
SET d.ClientRemarkId = c.ClientRemarkId
FROM [dbo].[OrderDetails] as d
JOIN [dbo].[ClientRemarks] as c ON d.OrderDetailId = c.OrderDetailId
WHERE ISNULL(d.ClientRemarkId,0) <> c.ClientRemarkId

TRUNCATE TABLE [stg].[stg_Orders]

END