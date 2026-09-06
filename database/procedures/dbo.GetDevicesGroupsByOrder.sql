-- Mirrors the definition deployed on STAGE (Calibrator) as of 2026-09-06.
-- Regenerated from the live object, then corrected: the odm OUTER APPLY that supplies
-- DeviceManufacturer and CalibrationStatus was uncorrelated. Do not hand-edit without
-- redeploying - this file is a mirror, not the source.
CREATE OR ALTER PROCEDURE [dbo].[GetDevicesGroupsByOrder] 
	@OrderNumber NVARCHAR(20),
	@MainCategories NVARCHAR(MAX) = NULL,
	@SecondaryCategories NVARCHAR(MAX) = NULL,
	@DeviceManufacturer NVARCHAR(MAX) = NULL,
	@DeviceModels NVARCHAR(MAX) = NULL,
	@Page NVARCHAR(100) = 'coordinator-orders'
AS
BEGIN

SET NOCOUNT ON;

/*
Filter logic by page
/coordinator-orders - @page = ‘coordinator-orders’ 
/external-schedule - @page = ‘external-schedule’
/internal-orders - @page = ‘internal-orders’
/calibration-wizard - @page = ‘calibration-wizard’ 
/external-orders - @page = 'external-orders'
*/
/*-------------------------------------------------*/
DECLARE @ExtIntFilter BIT = NULL

IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1 -- IsInHouse = 0 for internal orders

/*-------------------------------------------------*/	

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories
(
MainCategory NVARCHAR(50) 
)
INSERT #MainCategories(MainCategory)
SELECT DISTINCT CAST(v.Value AS NVARCHAR(50)) FROM dbo.ParseCSVToTable(@MainCategories) as v


DROP TABLE IF EXISTS #SecondaryCategories
CREATE TABLE #SecondaryCategories
(
SecondaryCategory NVARCHAR(50) 
)
INSERT #SecondaryCategories(SecondaryCategory)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@SecondaryCategories) as v

DROP TABLE IF EXISTS #DeviceManufacturer
CREATE TABLE #DeviceManufacturer
(
DeviceManufacturer NVARCHAR(255) 
)
INSERT #DeviceManufacturer(DeviceManufacturer)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceManufacturer) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels
(
DeviceModel NVARCHAR(30) 
)
INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceModels) as v

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT DISTINCT
     op.OrderNumber
	,od.OrderWorkPlanId as OrderId
	,od.OrderDetailId
	--,itm.OrderDetailsItemId
	,opt.OrdersProductTypeName AS DeviceType
	,mc.ID AS DepartmentId
	,mc.MainCategoryName as MainCategory
	,sc.SecondaryCategoryName AS SecondCategory
	--,itm.OrderDetailsItemId
	--,itm.SerialNumber
	--,itm.DeviceModel
	--,itm.MbaReportNumber
	--,od.OrderDetailId
	,odm.OrdersDeviceManufacturerName as DeviceManufacturer
	,od.OrderLineCnt
	,od.PartName
	,odm.[StatusDescriptionHEB] as CalibrationStatus
	,odm.[StatusDescriptionENG] as CalibrationStatusENG 
	,ptxt.TextToCatalogNumber
	,dtxt.TextToDevice 
	--,itm.[IsChecked]
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
OUTER APPLY
(
-- MBA: correlated to the order line. This APPLY used to have no WHERE and no
-- ORDER BY, so TOP 1 latched onto one arbitrary row of the whole OrderDetailsItems
-- table and stamped its status onto every device of every order.
SELECT TOP 1 odi.OrdersDeviceManufacturer as OrdersDeviceManufacturerName , cals.[StatusDescriptionHEB], [StatusDescriptionENG] 
FROM 
[dbo].[OrderDetailsItems] as odi
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = odi.[CalibrationStatusId]
WHERE odi.[OrderDetailId] = od.[OrderDetailId] AND ISNULL(odi.[IsDeleted],0) = 0
ORDER BY odi.[OrderDetailsItemId]
) as odm
'
+ '
OUTER APPLY
(
    SELECT
        STRING_AGG(x.CleanText, NCHAR(10))
            WITHIN GROUP (ORDER BY x.TEXTORD, x.TEXTLINE) AS TextToCatalogNumber
    FROM (
        SELECT
            pt.TEXTORD,
            pt.TEXTLINE,
            CleanText =
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REVERSE(CAST(pt.[TEXT] AS NVARCHAR(MAX))),
                        N''<style> p,div,li'', N''''),
                        N''</style>'', N''''),
                        N''<style>'', N''''),
                        N''<P dir=rtl align=right>'', N''''),
                        N''<P dir=rtl>'', N''''),
                        N''dir=rtl>'', N''''),
                        N''<FONT size=3 face=David>'', N''''),
                        N''<FONT face=David size=3>'', N''''),
                        N''<FONT face=David size=2>'', N''''),
                        N''<FONT face=David>'', N''''),
                        N''</FONT>'', N''''),
                        N''<BR>'', NCHAR(10)),
                        N''</P>'', NCHAR(10)),
                        N''&nbsp;'', N'' ''),
                        N''<B>'', N''''),
                        N''</B>'', N''''),
                        N''<STRONG>'', N''''),
                        N''</STRONG>'', N''''),
                        N''</strong>'', N'''')
                ))
        FROM [31.168.173.93].[amaba].[dbo].[PARTTEXT] AS pt
        WHERE pt.PART = od.PART
    ) x
    WHERE x.CleanText <> N''''
      AND x.CleanText NOT LIKE N''%font-family%''
      AND x.CleanText NOT LIKE N''%font-size%''
      AND x.CleanText NOT LIKE N''%margin%''
      AND x.CleanText NOT LIKE N''%style%''
      AND x.CleanText NOT LIKE N''%p,div,li%''
) as ptxt

OUTER APPLY
(
    SELECT
        STRING_AGG(x.CleanText, NCHAR(10))
            WITHIN GROUP (ORDER BY x.TEXTORD, x.TEXTLINE) AS TextToDevice
    FROM (
        SELECT
            st.TEXTORD,
            st.TEXTLINE,
            CleanText =
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REVERSE(CAST(st.[TEXT] AS NVARCHAR(MAX))),
                        N''<style> p,div,li'', N''''),
                        N''</style>'', N''''),
                        N''<style>'', N''''),
                        N''<P dir=rtl align=right>'', N''''),
                        N''<P dir=rtl>'', N''''),
                        N''dir=rtl>'', N''''),
                        N''<FONT size=3 face=David>'', N''''),
                        N''<FONT face=David size=3>'', N''''),
                        N''<FONT face=David size=2>'', N''''),
                        N''<FONT face=David>'', N''''),
                        N''</FONT>'', N''''),
                        N''<BR>'', NCHAR(10)),
                        N''</P>'', NCHAR(10)),
                        N''&nbsp;'', N'' ''),
                        N''<B>'', N''''),
                        N''</B>'', N''''),
                        N''<STRONG>'', N''''),
                        N''</STRONG>'', N''''),
                        N''</strong>'', N'''')
                ))
        FROM [31.168.173.93].[amaba].[dbo].[SERNUMBERSTEXT] AS st
        WHERE st.SERN = itm.SERN AND od.OrderLineCnt = 1
    ) x
    WHERE x.CleanText <> N''''
      AND x.CleanText NOT LIKE N''%font-family%''
      AND x.CleanText NOT LIKE N''%font-size%''
      AND x.CleanText NOT LIKE N''%margin%''
      AND x.CleanText NOT LIKE N''%style%''
      AND x.CleanText NOT LIKE N''%p,div,li%''
) as dtxt
'
+'
'
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.OrdersSecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceManufacturer IS NOT NULL,' JOIN #DeviceManufacturer as dmf ON odm.OrdersDeviceManufacturerName COLLATE DATABASE_DEFAULT  = dmf.DeviceManufacturer COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE OrderNumber = TRIM(''',@OrderNumber,''')

'
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
)
PRINT @sql
EXEC sp_executesql @sql

END
