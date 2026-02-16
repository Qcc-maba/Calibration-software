
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Merge orders data from amaba
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeOrdersData]
AS
BEGIN

SET NOCOUNT ON;

/*Clean-up Main categories*/

UPDATE t
SET MainCategorySourceId =
    CASE LTRIM(RTRIM(t.MainCategorySourceId))
        WHEN N'אורך'                    THEN N'אורך וזווית'
        WHEN N'אורך מדוייקים'           THEN N'אורך וזווית'
        WHEN N'אל חמה'                  THEN N'NA'
        WHEN N'אלקטרוניקה'              THEN N'אלקטרוניקה'
        WHEN N'בדיקות דגם'              THEN N'NA'
        WHEN N'גלאי גזים'               THEN N'גזים'
        WHEN N'גפן'                     THEN N'NA'
        WHEN N'זמן'                     THEN N'זמן'
        WHEN N'טמפרטורה'                THEN N'טמפרטורה ולחות'
        WHEN N'כח'                      THEN N'כוח'
        WHEN N'לחות'                    THEN N'טמפרטורה ולחות'
        WHEN N'לחץ'                     THEN N'לחץ'
        WHEN N'ללא מחלקה'               THEN N'NA'
        WHEN N'מאגנוס'                  THEN N'אלקטרוניקה'
        WHEN N'מדידים'                  THEN N'אורך וזווית'
        WHEN N'מהירות אוויר'            THEN N'מהירות אוויר'
        WHEN N'מומנט'                   THEN N'מומנט'
        WHEN N'מכונות'                  THEN N'NA'
        WHEN N'מסה'                     THEN N'מסה'
        WHEN N'מקבילונים'               THEN N'אורך וזווית'
        WHEN N'נפח'                     THEN N'נפח'
        WHEN N'סיבוב'                   THEN N'אורך וזווית'
        WHEN N'ספיקה'                   THEN N'ספיקה'
        WHEN N'קבלני משנה'              THEN N'NA'
        WHEN N'קבלני משנה כללי'         THEN N'NA'
        WHEN N'קושי'                    THEN N'קשיות'
        WHEN N'רדיומטריה ופוטומטריה'    THEN N'רדיומטריה'
        WHEN N'שירותי איכות ורגולציה'   THEN N'NA'
        WHEN N'תעשיה אוירית'            THEN N'NA'
        ELSE t.MainCategorySourceId
    END
FROM [stg].[stg_Orders] AS t;



DROP TABLE IF EXISTS #OrderStatus
CREATE TABLE #OrderStatus
(
StatusId INT NOT NULL,
CodeINT INT,
StatusType NVARCHAR(50)COLLATE Latin1_General_100_CI_AI_SC,
Code NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC,
StatusDescriptionENG NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC
)
INSERT #OrderStatus (StatusId,CodeINT,StatusType,Code,StatusDescriptionENG)
SELECT s.StatusId, TRY_CAST(s.Code AS INT) as CodeINT, sc.StatusDescriptionENG as StatusType, s.Code ,s.StatusDescriptionENG
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG IN('OrderStatus','ReportStatus','CalibrationStatuses')

DECLARE @InintialOrderStatus INT  
SELECT @InintialOrderStatus = StatusId FROM #OrderStatus as os WHERE os.StatusType = N'OrderStatus' AND os.StatusDescriptionENG = 'WaitingForCalibration'

MERGE INTO [dbo].[OrderWorkPlans] AS dest
USING (
SELECT DISTINCT
	     o.ORDNAME as [OrderNumber]
		,o.OpenDate as [WorkPlanOpenDate]
		,GETDATE() AS [CreatedDate]
		,0 as [UpdateUserID]
		,0 as [CreatedByUserId]
		,0 as [IsCancelled]
		,c.[CustomerId]
		,NULL as [Notes]
		,ss.[SourceId]
		,@InintialOrderStatus as OrderOverallStatusId
		,IIF(LEN(o.[ShipTypeDesc]) > 1,o.[ShipTypeDesc],NULL) as [ShipTypeDesc]
		,o.SourceOrderId as [OrderSourceId]
		FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = ss.SourceId AND c.IsDeleted = 0
	) AS source
	ON dest.[OrderSourceId] = source.[OrderSourceId] AND dest.[SourceId] = source.[SourceId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrderNumber]
			,[WorkPlanOpenDate]
			,[CreatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[IsCancelled]
			,[Notes]
			,[OrderSourceId]
			,[SourceId]
			,[CustomerId]
			,[OrderOverallStatusId]
			,[ShipTypeDesc]
			)
		VALUES (
			 source.[OrderNumber]
			,source.[WorkPlanOpenDate]
			,source.[CreatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[IsCancelled]
			,source.[Notes]
			,source.[OrderSourceId]
			,source.[SourceId]
			,source.[CustomerId]
			,source.[OrderOverallStatusId]
			,source.[ShipTypeDesc]

			);


MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT DISTINCT
	    wp.[OrderWorkPlanId]
		,o.[SpecialCareTypeId]
		,CASE 
			WHEN RIGHT(o.[PartName], 2) IN ('-7','-8','-9') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 0 
			WHEN RIGHT(o.[PartName], 2) IN ('-3','-0','-1') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 1 --10 should be external 
		ELSE NULL END  as [IsInHouse]
		,o.[PartName]
		--,o.[KLINE]
		,o.[PART]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.OrderLineCnt
		,pt.OrdersProductTypeId
		,o.DeviceType 
		,o.OrderDetailId as OrderDetailSourceId
		,o.VPRICE	
		,o.PRICE
		,mc.[ID] as [MainCategoryId]
		,sc.ID as [SecondaryCategoryId]
		,o.[CustomerPackingExists]
	    ,o.[PackageLocation]
		,cs.CustomerSiteId
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND o.SourceSystem = s.SourceName
	LEFT JOIN [dbo].[OrdersProductTypes] as pt ON pt.OrdersProductTypeName = o.DeviceType and pt.IsDeleted = 0
	LEFT JOIN [dbo].[MainCategories] as mc ON o.MainCategorySourceId = mc.MainCategoryName and mc.IsDeleted = 0
	LEFT JOIN [dbo].[SecondaryCategories] as sc ON o.SecondCategorySourceId = sc.SecondaryCategoryName and sc.IsDeleted = 0
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId AND c.IsDeleted = 0
	LEFT JOIN [dbo].[CustomerSites] as cs ON c.CustomerId = cs.CustomerId AND cs.CustomerSiteCode = o.[DESTCODE] AND cs.IsDeleted = 0
	) AS source
	ON dest.[OrderWorkPlanId] = source.[OrderWorkPlanId] AND source.OrderDetailSourceId = dest.[OrderDetailSourceId] 
WHEN MATCHED AND
	(
		  COALESCE(dest.[SpecialCareTypeId],0) <> COALESCE(source.[SpecialCareTypeId],0)
		OR COALESCE(dest.[IsInHouse],0) <> COALESCE(source.[IsInHouse],0)
		OR COALESCE(dest.[OrderLineCnt],0) <> COALESCE(source.[OrderLineCnt],0)
		OR COALESCE(dest.OrdersProductTypeId,0) <> COALESCE(source.[OrdersProductTypeId],0)
		OR COALESCE(dest.[PART],0) <> COALESCE(source.[PART],0)
		OR COALESCE(dest.[VPRICE],0) <> COALESCE(source.[VPRICE],0)
		OR COALESCE(dest.[PRICE],0) <> COALESCE(source.[PRICE],0)
		OR COALESCE(dest.[MainCategoryId],0) = COALESCE(source.[MainCategoryId],0)
		OR COALESCE(dest.[SecondaryCategoryId],0) = COALESCE(source.[SecondaryCategoryId],0)
		OR COALESCE(dest.[CustomerPackingExists],0) <> COALESCE(source.[CustomerPackingExists],0) 
		OR COALESCE(dest.[CustomerSiteId],0) <> COALESCE(source.[CustomerSiteId],0)
		OR COALESCE(dest.[PackageLocation],'') <> COALESCE(source.[PackageLocation],'')
		OR COALESCE(dest.[PartName],'') <> COALESCE(source.[PartName],'')
	)
	THEN
		UPDATE
		SET  dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[OrderLineCnt] = source.[OrderLineCnt]
			,dest.[OrdersProductTypeId] = source.[OrdersProductTypeId]
			,dest.[PART] = source.[PART]
			,dest.[VPRICE] = source.[VPRICE]
			,dest.[PRICE] = source.[PRICE]
			,dest.[MainCategoryId] = source.[MainCategoryId]
			,dest.[SecondaryCategoryId] = source.[SecondaryCategoryId]
			,dest.[CustomerPackingExists] = source.[CustomerPackingExists]
			,dest.[CustomerSiteId] = source.[CustomerSiteId]
			,dest.[PackageLocation] = source.[PackageLocation]
			,dest.[PartName] = source.[PartName]

WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			--,[KLINE]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[OrderLineCnt]
			,[OrdersProductTypeId]
			,[PART]
			,[OrderDetailSourceId]
			,[VPRICE]	
			,[PRICE]
			,[MainCategoryId]
			,[SecondaryCategoryId]
			,[CustomerPackingExists]
			,[CustomerSiteId]
			,[PackageLocation]
			)
		VALUES (
			 source.[OrderWorkPlanId]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
		--	,source.[KLINE]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[OrderLineCnt]
			,source.[OrdersProductTypeId]
			,source.[PART]
			,source.[OrderDetailSourceId]
			,source.[VPRICE]	
			,source.[PRICE]
			,source.[MainCategoryId]
			,source.[SecondaryCategoryId]
			,source.[CustomerPackingExists]
			,source.[CustomerSiteId]
			,source.[PackageLocation]
			);

MERGE INTO [dbo].[OrderDetailsItems] AS dest
USING (
	SELECT DISTINCT
	     o.[SerialNumber]
		,od.OrderDetailId
		,o.[ManufacturerNumber]
		,REVERSE(o.[Devicemodel]) as [DeviceModel]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,NULL AS [MbaReportNumber]
		,c.[CustomerId]
		,o.[KLINE]
		,o.[SERN]
	    ,o.[ProductLocation]
		,NULL AS [StatusId]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.[Doc]
		,o.[NextCalibrationDate]
		,o.AdditionalDeviceNumber
		,NULL /*o.CalibDate*/ as [ActualCalibrationDate]
		--,os.StatusId as CalibrationReportStatusId
		--,IIF(os2.Code <> N'CO',os2.StatusId,-1) as CalibrationStatusId
		,NULL AS CustomerReceivingDate
		,IIF(LEN(o.ShippingDoc) > 1,o.ShippingDoc,NULL) as ShippingDoc
		,IIF(LEN(o.ShippingAddress) > 1,o.ShippingAddress,NULL) as  ShippingAddress
		,o.DOC_N
	    ,IIF(o.[ActualReturnDate] > GETDATE()-100,o.[ActualReturnDate],NULL) as [ActualReturnDate]
	    ,IIF(o.[ExpectedReturnDate] > GETDATE()-100,o.[ExpectedReturnDate],NULL) as [ExpectedReturnDate]
		,o.OrdersDeviceManufacturer
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId
	JOIN [dbo].[OrderDetails] as od ON wp.[OrderWorkPlanId] = od.[OrderWorkPlanId] AND od.OrderDetailSourceId = o.OrderDetailId
	LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId and c.IsDeleted = 0
	--LEFT JOIN #OrderStatus AS os ON o.CurrentCalibrationStatus = os.Code AND os.StatusType = N'ReportStatus'
	--LEFT JOIN #OrderStatus AS os2 ON o.CurrentCalibrationStatus = os2.Code AND os2.StatusType = N'CalibrationStatuses'
	WHERE o.OrderDetailId IS NOT NULL AND o.Doc IS NOT NULL
	) AS source
	ON dest.OrderDetailId = source.OrderDetailId AND source.[Doc] = dest.[Doc]
/* WHEN MATCHED
        AND (COALESCE(dest.[SerialNumber],'') = COALESCE(source.[SerialNumber],'')
		OR COALESCE(dest.[ManufacturerNumber],'') = COALESCE(source.[ManufacturerNumber],'')
		OR COALESCE(dest.[DeviceModel],'') = COALESCE(source.[DeviceModel],'')
		OR COALESCE(dest.[MbaReportNumber],'') = COALESCE(source.[MbaReportNumber],'')
		OR COALESCE(dest.[UpdatedDate],'1900-01-01') = source.[UpdatedDate]
		OR COALESCE(dest.[UpdateUserID],0) = source.[UpdateUserID]
		OR COALESCE(dest.[Doc],0) = source.[Doc]
 		OR COALESCE(dest.[ProductLocation],'')<> COALESCE(source.[ProductLocation],'')
		OR COALESCE(dest.[NextCalibrationDate],'1900-01-01') = COALESCE(source.[NextCalibrationDate],'1900-01-01'))
		OR COALESCE(dest.[AdditionalDeviceNumber],'')<> COALESCE(source.[AdditionalDeviceNumber],'')
		OR COALESCE(dest.[ActualCalibrationDate],'1900-01-01') <> COALESCE(source.[ActualCalibrationDate],'1900-01-01')
		OR COALESCE(dest.CustomerReceivingDate,'1900-01-01') <> COALESCE(source.CustomerReceivingDate,'1900-01-01')
 		--OR COALESCE(dest.CalibrationStatusId,0) = IIF(source.CalibrationStatusId = -1,dest.CalibrationStatusId,source.CalibrationStatusId) -- Calibration status can not be delivered, but on source report and calibration statuses same column 
		OR COALESCE(dest.CalibrationReportStatusId,0) = source.[CalibrationReportStatusId]
		OR COALESCE(dest.[ShippingDoc],'') = COALESCE(source.[ShippingDoc],'')
		OR COALESCE(dest.[ShippingAddress],'') = COALESCE(source.[ShippingAddress],'')
		OR COALESCE(dest.[DOC_N],0) = COALESCE(source.[DOC_N],0)
		OR COALESCE(dest.[ActualReturnDate],'1900-01-01') <> COALESCE(source.[ActualReturnDate],'1900-01-01') 
		OR COALESCE(dest.[ExpectedReturnDate],'1900-01-01') <> COALESCE(source.[ExpectedReturnDate],'1900-01-01') 


	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[ProductLocation] = source.[ProductLocation]
			,dest.[Doc] = source.[Doc]
			,dest.[NextCalibrationDate] = source.[NextCalibrationDate]
			,dest.[AdditionalDeviceNumber] = source.[AdditionalDeviceNumber]
			,dest.[ActualCalibrationDate] = source.[ActualCalibrationDate]
			,dest.[CalibrationReportStatusId] = IIF(dest.[UpdateUserID] = 0,source.[CalibrationReportStatusId],dest.[CalibrationReportStatusId])
		   -- ,dest.[CalibrationStatusId] = IIF(dest.[UpdateUserID] = 0 and source.CalibrationStatusId > 0,source.CalibrationStatusId,dest.CalibrationStatusId) -- Calibration status can not be delivered, but on source report and calibration statuses same column 
		    ,dest.[CustomerReceivingDate] = source.[CustomerReceivingDate]
		    ,dest.[ShippingDoc] = source.[ShippingDoc]
		    ,dest.[ShippingAddress] = source.[ShippingAddress]
			,dest.[DOC_N] = source.[DOC_N]
			,dest.[ActualReturnDate] = source.[ActualReturnDate]
			,dest.[ExpectedReturnDate] = source.[ExpectedReturnDate]
			*/
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderDetailId]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[MbaReportNumber]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[SERN]
			,[ProductLocation]
			,[Doc]
			,[NextCalibrationDate]
			,[AdditionalDeviceNumber]
			,[ActualCalibrationDate]
		--	,[CalibrationReportStatusId]
		--  ,[CalibrationStatusId]
		    ,[CustomerReceivingDate]
		    ,[ShippingDoc]
		    ,[ShippingAddress]
			,[DOC_N]
			,[ActualReturnDate]
			,[ExpectedReturnDate]
			,[OrdersDeviceManufacturer]
			)
		VALUES (
			 source.[OrderDetailId]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[MbaReportNumber]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[SERN]
			,source.[ProductLocation]
			,source.[Doc]
			,source.[NextCalibrationDate]
			,source.[AdditionalDeviceNumber]
			,source.[ActualCalibrationDate]
		--	,source.[CalibrationReportStatusId]
		--  ,NULLIF(source.[CalibrationStatusId],-1)
		    ,source.[CustomerReceivingDate]
		    ,source.[ShippingDoc]
		    ,source.[ShippingAddress]
			,source.[DOC_N]
			,source.[ActualReturnDate]
			,source.[ExpectedReturnDate]
			,source.[OrdersDeviceManufacturer]
			);

			
END