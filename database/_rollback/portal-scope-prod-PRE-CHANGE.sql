/* TRUE pre-change rollback for MBA-943 on CalibratorProd.

   Source: git HEAD (the MBA-936 versions), NOT a capture of the live database.
   The live capture taken on 31/08 at 10:18 is NOT a rollback point: production had
   already been partially changed by then, so it preserves the mixed state.

   GetCustomerUpcommingCalibrationInfo is not tracked in git. Its pre-change definition
   was still live on production and is included below from that capture.

   Run with: sqlcmd -S <srv> -d CalibratorProd -U <u> -P <p> -C -I -f 65001 -i <this file>
   The -f 65001 is not optional: without it the Hebrew literals are stored as mojibake. */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/* ---- dbo.GetCustomerDeviceList (git HEAD) ---- */
/*
    dbo.GetCustomerDeviceList                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerDeviceList
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
-- Description: Returns ONE row per device for the logged-in customer (customer portal
--              Device List grid). Identity input matches dbo.GetCustomerDashboardData
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts). Scoped to the
--              calling customer only, consistent with the other GetCustomer* SPs.
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set for the customer with no pagination.
--
-- Output (exactly the 12 columns MBA-860 requires, in order):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport
--
--   * deviceStatus     -> FE `deviceCalibrationStatuses` code (camelCase). The 11 codes the
--                         filter chips depend on are mapped explicitly by StatusId; any other
--                         status falls back to a lower-camel of StatusDescriptionENG.
--   * lastCalibration  -> DD.MM.YYYY string (CONVERT style 104) from ActualCalibrationDate.
--   * nextCalibration  -> DD.MM.YYYY string (CONVERT style 104) from NextCalibrationDate.
--
-- NOTE for review (Ariel): three source mappings are best-guess — please confirm:
--   * sku                 -> itm.ManufacturerNumber   (מק"ט יצרן; alt: AdditionalDeviceNumber)
--   * calibrationLocation -> IIF(od.IsInHouse=1, מעבדה, לקוח)  (same as GetCustomerDashboardData;
--                            alt: itm.ProductLocation / itm.SiteAddress)
--   * lastReport          -> itm.MbaReportNumber       (alt: CalibratorsToWorkPlan.OrderDetailsMbaReportNumber)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    ;WITH devices AS
    (
        SELECT
             itm.OrderDetailsItemId                                                   AS id
            ,itm.CalibrationStatusId                                                  AS CalibrationStatusId
            ,st.StatusDescriptionENG                                                  AS StatusEng
            ,itm.ActualCalibrationDate                                                AS ActualCalibrationDate
            ,itm.NextCalibrationDate                                                  AS NextCalibrationDate
            ,itm.SerialNumber                                                         AS SerialNumber
            ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS CalibrationLocation
            ,pt.OrdersProductTypeName                                                 AS DeviceDescription
            ,itm.OrdersDeviceManufacturer                                             AS DeviceManufacturer
            ,itm.DeviceModel                                                          AS DeviceModel
            ,itm.ManufacturerNumber                                                   AS Sku
            ,wp.ShipTypeDesc                                                          AS ShippingMethod
            ,itm.MbaReportNumber                                                      AS LastReport
            ,ROW_NUMBER() OVER (PARTITION BY itm.SerialNumber
                                ORDER BY wp.OrderWorkPlanId DESC)                     AS IsLatestOrder
        FROM [dbo].[OrderWorkPlans]      AS wp
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.CustomerId       = @CustomerId
          AND wp.IsCancelled      = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
          AND ISNULL(itm.IsCancelled,0)= 0
    )
    SELECT
         d.id
        ,CASE d.CalibrationStatusId
            WHEN 31 THEN 'testedMetTheStandard'
            WHEN 32 THEN 'testedDidntMeetTheStandards'
            WHEN 23 THEN 'calibrationSuccess'
            WHEN 21 THEN 'calibrationFailed'
            WHEN 26 THEN 'adjusted'
            WHEN 24 THEN 'delivered'
            WHEN 22 THEN 'packaged'
            WHEN 29 THEN 'readyForPacking'
            WHEN 27 THEN 'readyForDelivery'
            WHEN 19 THEN 'waitingForCalibration'
            WHEN 33 THEN 'cannotBeDetermined'
            ELSE CASE
                    WHEN d.StatusEng IS NULL OR LEN(d.StatusEng) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(d.StatusEng, '''', ''), 1))
                       + SUBSTRING(REPLACE(d.StatusEng, '''', ''), 2, 200)
                 END
         END                                                             AS deviceStatus
        ,CONVERT(VARCHAR(10), d.ActualCalibrationDate, 104)              AS lastCalibration
        ,CONVERT(VARCHAR(10), d.NextCalibrationDate,   104)              AS nextCalibration
        ,d.SerialNumber                                                  AS serialNumber
        ,d.CalibrationLocation                                           AS calibrationLocation
        ,d.DeviceDescription                                            AS deviceDescription
        ,d.DeviceManufacturer                                           AS deviceManufacturer
        ,d.DeviceModel                                                   AS deviceModel
        ,d.Sku                                                           AS sku
        ,d.ShippingMethod                                               AS shippingMethod
        ,d.LastReport                                                    AS lastReport
    FROM devices AS d
    WHERE d.IsLatestOrder = 1
    ORDER BY d.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerDeviceDetail (git HEAD) ---- */
/*
    dbo.GetCustomerDeviceDetail                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerDeviceDetail
-- Jira:        MBA-798  "Customer Selected-device detail view"
-- Description: Returns the FULL detail of ONE device for the logged-in customer
--              (customer portal "selected device" detail view). This is a distinct
--              contract from:
--                * dbo.GetCustomerDeviceList     -> one row PER device, 12 list columns,
--                                                   no single-device key.
--                * dbo.GetOrderDetailsDevices    -> STAFF detail, keyed by OrderWorkPlanId,
--                                                   requires a MABA Users/UserRoles row via
--                                                   GetSourceFilterByEmail and performs NO
--                                                   customer-ownership check -> unusable and
--                                                   unsafe for a customer contact.
--
--              Identity input matches the other GetCustomer* SPs:
--                @LoggedInUserEmail -> CustomerId via dbo.CustomerContacts.
--              The device is looked up by @OrderDetailsItemId and is ALWAYS re-scoped to the
--              calling customer (WHERE wp.CustomerId = @CustomerId), so a customer can never
--              read another customer's device by guessing an id. Returns 0 rows if the id
--              does not belong to the caller.
--
-- Params:
--   @LoggedInUserEmail  NVARCHAR(50)  -- customer contact email (resolves CustomerId)
--   @OrderDetailsItemId INT           -- the selected device (OrderDetailsItems.OrderDetailsItemId)
--
-- Output (single row): superset of the Device-List contract plus detail-only fields.
--   id, deviceStatus (FE camelCase code), deviceStatusHeb,
--   lastCalibration (DD.MM.YYYY), nextCalibration (DD.MM.YYYY),
--   serialNumber, sku, additionalDeviceNumber,
--   calibrationLocation (מעבדה/לקוח), deviceDescription, deviceManufacturer, deviceModel,
--   mainCategory, secondaryCategory, accuracy, measurementUnit,
--   productLocation, siteAddress, shippingMethod,
--   orderNumber, lastReport,
--   calibratorFullName, calibratorPhone
--
--   * deviceStatus is mapped by StatusId to the exact FE `deviceCalibrationStatuses`
--     camelCase codes, IDENTICAL to dbo.GetCustomerDeviceList (kept in sync on purpose);
--     any unmapped status falls back to lower-camel of StatusDescriptionENG.
--   * Dates -> DD.MM.YYYY (CONVERT style 104), per house convention.
--
-- NOTE for review (Ariel): source mappings mirror dbo.GetCustomerDeviceList (MBA-860) --
--   sku -> ManufacturerNumber, calibrationLocation -> IIF(od.IsInHouse=1,'מעבדה','לקוח'),
--   lastReport -> itm.MbaReportNumber. Please confirm which extra detail fields the final
--   Figma frame requires; those listed above are the customer-safe superset available in
--   Calibrator. No financial/analytics fields are included (not in this DB).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceDetail]
    @LoggedInUserEmail  NVARCHAR(50),
    @OrderDetailsItemId INT,
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    IF @CustomerId IS NULL
        RETURN;  -- unknown contact -> no data

    SELECT TOP (1)
         itm.OrderDetailsItemId                                                   AS id
        ,CASE itm.CalibrationStatusId
            WHEN 31 THEN 'testedMetTheStandard'
            WHEN 32 THEN 'testedDidntMeetTheStandards'
            WHEN 23 THEN 'calibrationSuccess'
            WHEN 21 THEN 'calibrationFailed'
            WHEN 26 THEN 'adjusted'
            WHEN 24 THEN 'delivered'
            WHEN 22 THEN 'packaged'
            WHEN 29 THEN 'readyForPacking'
            WHEN 27 THEN 'readyForDelivery'
            WHEN 19 THEN 'waitingForCalibration'
            WHEN 33 THEN 'cannotBeDetermined'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                                      AS deviceStatus
        ,st.StatusDescriptionHEB                                                  AS deviceStatusHeb
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)                     AS lastCalibration
        ,CONVERT(VARCHAR(10), itm.NextCalibrationDate,   104)                     AS nextCalibration
        ,itm.SerialNumber                                                         AS serialNumber
        ,itm.ManufacturerNumber                                                   AS sku
        ,itm.AdditionalDeviceNumber                                               AS additionalDeviceNumber
        ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS calibrationLocation
        ,pt.OrdersProductTypeName                                                 AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                             AS deviceManufacturer
        ,itm.DeviceModel                                                          AS deviceModel
        ,mc.MainCategoryName                                                      AS mainCategory
        ,sc.SecondaryCategoryName                                                 AS secondaryCategory
        ,itm.Accuracy                                                             AS accuracy
        ,mu.ShortNameHe                                                           AS measurementUnit
        ,itm.ProductLocation                                                      AS productLocation
        ,COALESCE(itm.SiteAddress, cs.CustomerSiteAddress)                        AS siteAddress
        ,wp.ShipTypeDesc                                                          AS shippingMethod
        ,wp.OrderNumber                                                           AS orderNumber
        ,itm.MbaReportNumber                                                      AS lastReport
        ,CONCAT(u.FirstName, ' ', u.LastName)                                     AS calibratorFullName
        ,u.Phone                                                                  AS calibratorPhone
    FROM [dbo].[OrderWorkPlans]        AS wp
    JOIN [dbo].[OrderDetails]          AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]     AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]             AS st ON st.StatusId              = itm.CalibrationStatusId
    LEFT JOIN [dbo].[OrdersProductTypes]   AS pt ON pt.OrdersProductTypeId   = od.OrdersProductTypeId
    LEFT JOIN [dbo].[MainCategories]       AS mc ON mc.ID                    = od.MainCategoryId
    LEFT JOIN [dbo].[SecondaryCategories]  AS sc ON sc.ID                    = od.SecondaryCategoryId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] AS mu ON mu.MeasurementDeviceUnitId = itm.MeasurementUnitId
    LEFT JOIN [dbo].[CustomerSites]        AS cs ON cs.CustomerSiteId        = od.CustomerSiteId
    LEFT JOIN [dbo].[Users]                AS u  ON u.ID                     = od.CalibratorId
    WHERE itm.OrderDetailsItemId    = @OrderDetailsItemId
      AND wp.CustomerId             = @CustomerId          -- ownership guard
      AND wp.IsCancelled           = 0
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
      AND ISNULL(itm.IsCancelled, 0) = 0
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerDashboardData (git HEAD) ---- */
/*
    dbo.GetCustomerDashboardData                                                   MBA-865
    ---------------------------------------------------------------------------------
    The חזרה צפויה column is labelled *expected* return, but the procedure was
    returning ActualReturnDate. It now returns ExpectedReturnDate, and only for in-house
    (lab) calibration - for on-site work there is nothing to return, so it is NULL.

    The output alias stays ActualReturnDate on purpose: the front end already binds to it,
    and renaming would break the screen for no gain.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/02/2026
-- Description:	Get customer dashboad data
-- =============================================
CREATE OR ALTER   PROCEDURE [dbo].[GetCustomerDashboardData] 
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 50,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CalibratioinDate',      -- OrderBy column
@OrderByAsc AS BIT = 0,                  -- OrderBy direction (ASC/DESC)
@LoggedInUserEmail NVARCHAR(50),
@GlobalSearch NVARCHAR(200) = NULL
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT



SELECT 
	@CustomerId  = d.CustomerId 
,@SourceId = d.SourceId
FROM [dbo].[CustomerContacts] as d
WHERE CustomerContactEmail = @LoggedInUserEmail 

DROP TABLE IF EXISTS #CustomerOrdersIds
CREATE TABLE #CustomerOrdersIds
(
OrderWorkPlanId INT NOT NULL
)

INSERT #CustomerOrdersIds(OrderWorkPlanId)
SELECT wp.OrderWorkPlanId
FROM [dbo].[OrderWorkPlans] as wp
WHERE wp.[CustomerId] = @CustomerId

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
;WITH ds
AS
(
SELECT 
COALESCE(clst.StatusDescriptionHEB,N'''+N'מחכה לכיול'+''') as DeviceStatus
,itm.ActualCalibrationDate as CalibratioinDate
,itm.NextCalibrationDate
,od.OrderWorkPlanId
,IIF(od.IsInHouse = 1,N'''+N'מעבדה'+''',N'''+N'לקוח'+''') as CalibratioinLocation
,pt.OrdersProductTypeName as DeviceDescription
,itm.SerialNumber
,IIF(od.IsInHouse = 1, itm.ExpectedReturnDate, NULL) as ActualReturnDate
,od.CalibratorId
,u.FirstName as CalibratorFirstName
,u.LastName as CalibratorLastName
,u.Phone as CalibratorPhoneNumber
,ctwp.AssigmentDate as CalibratorAssigmentDate
,ROW_NUMBER() OVER( PARTITION BY itm.SerialNumber ORDER BY wp.OrderWorkPlanId DESC) as IsLatestOrder
FROM 
[dbo].[OrderWorkPlans] as wp
JOIN #CustomerOrdersIds as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[Statuses] as clst ON itm.[CalibrationStatusId] = clst.[StatusId]
LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
LEFT JOIN [dbo].[Users] as u ON od.CalibratorId = u.[ID]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = od.CalibratorId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
LEFT JOIN [dbo].[OrdersProductTypes] as pt ON od.OrdersProductTypeId = pt.OrdersProductTypeId
--WHERE wp.[CustomerId] = 2159
),
devices_cnt
AS
(
SELECT 
COALESCE(NULLIF(d.DeviceStatus,N''''),N''לא ניתן לקבוע'') as DeviceStatus
,d.CalibratioinDate
,d.NextCalibrationDate
,d.CalibratioinLocation
,d.DeviceDescription
,d.SerialNumber
,d.ActualReturnDate
,d.CalibratorId
,d.CalibratorFirstName
,d.CalibratorLastName
,d.CalibratorPhoneNumber
,d.CalibratorAssigmentDate
,d.IsLatestOrder
,SUM(IIF(d.IsLatestOrder = 1,1,NULL)) OVER( ORDER BY d.DeviceStatus) as OverallDevicesCount
,SUM(IIF(d.IsLatestOrder = 1 AND COALESCE(d.CalibratioinDate,''1900-01-01'') < GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus) as ExpiredevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.CalibratioinDate > GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as CalibratedDevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.DeviceStatus=N'''+N'מחכה לכיול'+''',1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as DevicesWaitingForCalibrationCount
FROM ds as d
)
SELECT 
 ds.DeviceStatus
,ds.CalibratioinDate
,ds.NextCalibrationDate
,ds.CalibratioinLocation
,ds.DeviceDescription
,ds.SerialNumber
,ds.ActualReturnDate
,ds.CalibratorId
,ds.CalibratorFirstName
,ds.CalibratorLastName
,ds.CalibratorPhoneNumber
,ds.CalibratorAssigmentDate
,ds.OverallDevicesCount
,ds.ExpiredevicesCount
,ds.CalibratedDevicesCount
,ds.DevicesWaitingForCalibrationCount
,SUM(IsLatestOrder) OVER( ORDER BY ds.DeviceStatus) as ItemsCount
FROM devices_cnt as ds
WHERE ds.IsLatestOrder = 1'
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(ds.DeviceDescription,ds.SerialNumber,ds.CalibratorFirstName,ds.CalibratorLastName,ds.CalibratorPhoneNumber) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)
GO
/* ---- dbo.GetCustomerCalibrationReports (git HEAD) ---- */
/*
    dbo.GetCustomerCalibrationReports                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerCalibrationReports
-- Jira:        MBA-796  "Customer Calibration-reports page (customer/calibration-reports)"
-- Description: Returns the calibration reports belonging to the logged-in customer
--              (customer portal "Calibration Reports" grid, route customer/calibration-reports).
--              Identity input matches dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped to the
--              calling customer only, consistent with the other GetCustomer* SPs.
--
--              A "calibration report" is an OrderDetailsItem that has an MbaReportNumber assigned.
--              Unlike GetCustomerDeviceList (one row per device, latest order only) this SP returns
--              ONE ROW PER REPORT (every report the customer has, including historical / update
--              cycles), newest calibration first. Filtering / sorting / search are CLIENT-SIDE.
--
-- Output columns (camelCase, matching the app's Raw* -> mapper convention):
--   id                 -> OrderDetailsItemId (row key AND part of the AWS report path)
--   orderNumber        -> OrderWorkPlans.OrderNumber (part of the AWS report path)
--   reportPath         -> convenience S3 key the FE otherwise builds via getOrderReportPath():
--                         'orders/{orderNumber}/reports/{id}/report.pdf'  (see
--                         src/lib/helpers/get-aws-file-paths.ts + pdf-preview-dialog)
--   mbaReportNumber    -> itm.MbaReportNumber (מספר דוח מבא)
--   serialNumber       -> itm.SerialNumber
--   deviceDescription  -> OrdersProductTypes.OrdersProductTypeName
--   deviceManufacturer -> itm.OrdersDeviceManufacturer
--   deviceModel        -> itm.DeviceModel
--   calibrationDate    -> DD.MM.YYYY (CONVERT style 104) from itm.ActualCalibrationDate
--   reportStatus       -> lower-camel of the ReportStatus StatusDescriptionENG (e.g.
--                         'createCalibrationReport'); NULL when no report status is set
--   reportStatusHeb    -> Statuses.StatusDescriptionHEB (Hebrew display text for the status)
--
-- OPEN QUESTIONS for review (screen is still a stub in the app, no wired tRPC/Figma yet):
--   * reportStatus source = itm.CalibrationReportStatusId (ReportStatus category). Confirm this
--     is the status the grid should show (vs. the calibration status used by GetCustomerDeviceList).
--   * FE enum for reportStatus is not defined yet, so the code is derived generically from the
--     English description (same fallback pattern GetCustomerDeviceList uses). Confirm the exact
--     camelCase codes once the FE filter chips exist, then map explicitly by StatusId.
--   * Download: FE builds the URL from {orderNumber, id}; reportPath is returned as a convenience.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerCalibrationReports]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    SELECT
         itm.OrderDetailsItemId                                              AS id
        ,wp.OrderNumber                                                      AS orderNumber
        ,CONCAT(N'orders/', wp.OrderNumber, N'/reports/',
                itm.OrderDetailsItemId, N'/report.pdf')                      AS reportPath
        ,itm.MbaReportNumber                                                 AS mbaReportNumber
        ,itm.SerialNumber                                                    AS serialNumber
        ,pt.OrdersProductTypeName                                            AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                        AS deviceManufacturer
        ,itm.DeviceModel                                                     AS deviceModel
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)               AS calibrationDate
        ,CASE
            WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
            ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
               + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
         END                                                                AS reportStatus
        ,st.StatusDescriptionHEB                                            AS reportStatusHeb
    FROM [dbo].[OrderWorkPlans]      AS wp
    JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationReportStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
    WHERE wp.CustomerId        = @CustomerId
      AND wp.IsCancelled       = 0
      AND ISNULL(od.IsDeleted, 0)   = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsCancelled, 0)= 0
      AND itm.MbaReportNumber IS NOT NULL
      AND LEN(itm.MbaReportNumber) > 0
    ORDER BY itm.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerRequests (git HEAD) ---- */
/*
    dbo.GetCustomerRequests                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerRequests
-- Jira:        MBA-858 (Customer Support — customer-inquiry / requests list + action modals)
-- Description: Read SP that backs the customer-portal "requests / inquiries" list shown in the
--              Customer Support area (FE: components/customers/QuotesDialog.tsx, mock MOCK_QUOTES,
--              row shape TQuoteRow in components/customers/constants/quotes-dialog.ts). Returns one
--              row per calibration order (OrderWorkPlan) belonging to the logged-in customer — an
--              order IS the "request/quote" the customer submitted and that the 4 action modals
--              (cancel calibration / devices deleted / order for shipping / reject request) act on.
--
--              Identity + scoping follow the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts), consistent with
--              dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList. Filtering / sorting are
--              done client-side (TanStack table), so the full clean set is returned, no paging.
--
-- Output columns (camelCase, exactly matching FE TQuoteRow):
--   status, quoteNumber, deviceCount, expectedCalibrationDate, calibrationLocation, price, note
--     * status                 -> FE quoteStatuses code. Sourced from the OrderStatus category
--                                 (StatusesCategories.StatusCategoryId = 9) via
--                                 COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId). The 4 codes
--                                 the FE combobox styles are mapped explicitly; any other status
--                                 falls back to a lower-camel of StatusDescriptionENG (same pattern
--                                 as GetCustomerDeviceList).
--                                   66 Sent                -> 'sent'
--                                   72 Rejected            -> 'rejected'
--                                   73 AwaitingConfirmation -> 'waitingForCustomer'
--                                   76 WaitingForCalibration-> 'waitingForCalibration'
--     * quoteNumber            -> wp.OrderNumber.
--     * deviceCount            -> COUNT of non-deleted OrderDetailsItems in the order.
--     * expectedCalibrationDate-> DD.MM.YYYY (CONVERT 104) — MIN(OrderDetailsItems.NextCalibrationDate).
--     * calibrationLocation    -> 'lab' if any order line IsInHouse=1, else 'customer' (NULL if no lines).
--     * price                  -> SUM(OrderDetails.PRICE) net, DECIMAL(18,2) (NULL if none).
--     * note                   -> wp.Notes (fallback wp.CustomerComment).
--
-- NOTE for review (Ariel / Dako) — best-guess mappings, please confirm:
--   * status: STAGE has wp.OrderStatusId 100% NULL and wp.OrderOverallStatusId = 76 for every
--     order, so every row currently returns 'waitingForCalibration'. The id->FE-code map above is
--     the assumed lifecycle; confirm which OrderStatus ids represent sent / rejected / waiting-for-
--     customer once real status data flows in.
--   * expectedCalibrationDate: no dedicated column exists — using earliest item NextCalibrationDate.
--     Alt candidates: wp.WorkPlanOpenDate, OrderDetails.ActualCalibrationDate.
--   * price: net (PRICE). Alt: VPRICE (VAT-inclusive), as used by dbo.GetCustomerInvoicesQuotes.
--   Write actions (cancel calibration / devices deleted / order for shipping / reject request) are
--   OUT OF SCOPE here and tracked as separate follow-ups — see the Jira ticket.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerRequests]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    ;WITH req AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId)      AS StatusId
            ,COALESCE(NULLIF(LTRIM(RTRIM(wp.Notes)), N''),
                      NULLIF(LTRIM(RTRIM(wp.CustomerComment)), N''))   AS Note
            ,(
                SELECT COUNT(*)
                FROM [dbo].[OrderDetails]      AS od2
                JOIN [dbo].[OrderDetailsItems] AS it2 ON it2.OrderDetailId = od2.OrderDetailId
                WHERE od2.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od2.IsDeleted, 0)  = 0
                  AND ISNULL(od2.IsCancelled,0) = 0
                  AND ISNULL(it2.IsDeleted, 0)  = 0
                  AND ISNULL(it2.IsCancelled,0) = 0
             )                                                         AS DeviceCount
            ,(
                SELECT MIN(it3.NextCalibrationDate)
                FROM [dbo].[OrderDetails]      AS od3
                JOIN [dbo].[OrderDetailsItems] AS it3 ON it3.OrderDetailId = od3.OrderDetailId
                WHERE od3.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od3.IsDeleted, 0)  = 0
                  AND ISNULL(it3.IsDeleted, 0)  = 0
             )                                                         AS ExpectedCalibrationDate
            ,(
                SELECT MAX(CAST(ISNULL(od4.IsInHouse, 0) AS INT))
                FROM [dbo].[OrderDetails] AS od4
                WHERE od4.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od4.IsDeleted, 0)  = 0
                  AND ISNULL(od4.IsCancelled,0) = 0
             )                                                         AS AnyInHouse
            ,(
                SELECT SUM(od5.PRICE)
                FROM [dbo].[OrderDetails] AS od5
                WHERE od5.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od5.IsDeleted, 0)  = 0
                  AND ISNULL(od5.IsCancelled,0) = 0
             )                                                         AS NetPrice
        FROM [dbo].[OrderWorkPlans] AS wp
        WHERE wp.CustomerId  = @CustomerId
          AND wp.IsCancelled = 0
    )
    SELECT
         CASE r.StatusId
            WHEN 66 THEN 'sent'
            WHEN 72 THEN 'rejected'
            WHEN 73 THEN 'waitingForCustomer'
            WHEN 76 THEN 'waitingForCalibration'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL
                      OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                          AS status
        ,r.OrderNumber                                                AS quoteNumber
        ,r.DeviceCount                                                AS deviceCount
        ,CONVERT(VARCHAR(10), r.ExpectedCalibrationDate, 104)         AS expectedCalibrationDate
        ,CASE
            WHEN r.AnyInHouse IS NULL THEN NULL
            WHEN r.AnyInHouse = 1     THEN 'lab'
            ELSE 'customer'
         END                                                          AS calibrationLocation
        ,CAST(r.NetPrice AS DECIMAL(18,2))                            AS price
        ,r.Note                                                       AS note
    FROM req AS r
    LEFT JOIN [dbo].[Statuses] AS st
           ON st.StatusId = r.StatusId
          AND st.StatusCategoryId = 9      -- OrderStatus category
    ORDER BY r.OrderWorkPlanId DESC
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerPortalRequestList (git HEAD) ---- */
/*
    dbo.GetCustomerPortalRequestList                                                    MBA-903
    ---------------------------------------------------------------------------------------------
    The requests a customer has submitted from the portal, newest first, with their status.

    Without this the customer submits into silence: the popups write a request and nothing ever
    shows it again. This is the "did anyone see what I asked for" screen, and it is also what lets
    the UI stop a customer filing the same extension request four times.

    Output columns are camelCase to match the front-end row types, the same convention as
    GetCustomerRequests and GetCustomerDeviceList.

    statusLabel and typeLabel are the Hebrew the screen shows. They are resolved here rather than
    in the client so that the portal and any MBA-side view cannot drift into calling the same
    status two different things.

    Scoped to the caller's own customer, so it cannot return another customer's requests even if a
    request id is guessed. @Status and @RequestType are optional filters; the list is otherwise
    returned whole, since filtering and sorting are done client-side.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerPortalRequestList
    @LoggedInUserEmail NVARCHAR(100),
    @Status            NVARCHAR(20) = NULL,
    @RequestType       NVARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    SELECT
         r.CustomerPortalRequestId                         AS id
        ,r.RequestType                                     AS requestType
        ,CASE r.RequestType
            WHEN N'ReportUpdate'            THEN N'בקשה לעדכון דוח'
            WHEN N'Shipment'                THEN N'הזמנה לשינוע'
            WHEN N'CalibrationExtension'    THEN N'הארכת תוקף כיול'
            WHEN N'CalibrationCancellation' THEN N'בקשה לביטול הכיול'
            WHEN N'Quote'                   THEN N'בקשה להצעת מחיר'
            WHEN N'QuoteFeedback'           THEN N'התייחסות לקוח'
            WHEN N'DeviceRemoval'           THEN N'מחיקת מכשיר'
         END                                               AS typeLabel
        ,r.Status                                          AS status
        ,CASE r.Status
            WHEN N'New'        THEN N'חדש'
            WHEN N'InProgress' THEN N'בטיפול'
            WHEN N'Approved'   THEN N'אושר'
            WHEN N'Rejected'   THEN N'נדחה'
            WHEN N'Cancelled'  THEN N'בוטל'
            WHEN N'Done'       THEN N'הסתיים'
         END                                               AS statusLabel
        ,r.OrderWorkPlanId                                 AS orderId
        ,wp.OrderNumber                                    AS orderNumber
        ,r.MbaReportNumber                                 AS mbaReportNumber
        ,r.QuoteNumber                                     AS quoteNumber
        ,CONVERT(VARCHAR(10), r.RequestedDate, 104)        AS requestedDate
        ,r.Reason                                          AS reason
        ,r.Notes                                           AS notes
        ,r.ShippingMethod                                  AS shippingMethod
        ,r.ShippingDocument                                AS shippingDocument
        ,r.DeviceLocation                                  AS deviceLocation
        ,r.CalibrationLocation                             AS calibrationLocation
        ,r.AttachmentPath                                  AS attachmentPath
        ,COALESCE(r.DeviceCount, itm.ItemCount)            AS deviceCount
        ,itm.SerialNumbers                                 AS serialNumbers
        ,r.SubmittedByEmail                                AS submittedByEmail
        ,CONVERT(VARCHAR(10), r.CreatedDate, 104)          AS createdDate
        ,CONVERT(VARCHAR(10), r.ResolvedDate, 104)         AS resolvedDate
        ,r.ResolutionNotes                                 AS resolutionNotes
    FROM dbo.CustomerPortalRequest AS r
    LEFT JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = r.OrderWorkPlanId
    OUTER APPLY
    (
        SELECT COUNT(*) AS ItemCount,
               STRING_AGG(i.SerialNumber, N', ') WITHIN GROUP (ORDER BY i.SerialNumber) AS SerialNumbers
        FROM dbo.CustomerPortalRequestItem AS i
        WHERE i.CustomerPortalRequestId = r.CustomerPortalRequestId
    ) AS itm
    WHERE r.CustomerId = @CustomerId
      AND r.IsDeleted = 0
      AND (@Status      IS NULL OR r.Status      = @Status)
      AND (@RequestType IS NULL OR r.RequestType = @RequestType)
    ORDER BY r.CreatedDate DESC;
END
GO
/* ---- dbo.GetCustomerShipments (git HEAD) ---- */
/*
    dbo.GetCustomerShipments                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerShipments
-- Jira:        MBA-795 ("Customer Shipping page (customer/shipping)")
-- Description: Returns the shipments / deliveries belonging to the logged-in customer
--              for the customer portal Shipping screen (route: /customer/shipping).
--              One row per shipped/shippable order item. Identity input matches the
--              other GetCustomer* SPs (@LoggedInUserEmail -> CustomerId via
--              dbo.CustomerContacts) and the result is scoped to that customer only.
--
--              Filtering / sorting / search are expected client-side (consistent with
--              MBA-860 GetCustomerDeviceList), so this SP returns the full clean set
--              with no pagination.
--
-- Output columns (order):
--   id, orderNumber, mbaReportNumber, serialNumber, deviceDescription,
--   deviceManufacturer, deviceModel, shippingMethod, shippingDoc, shippingAddress,
--   receivingDate, calibrationDate, expectedReturnDate, deliveryDate, status
--
--   * status       -> ORDER-level status (wp.OrderOverallStatusId -> dbo.Statuses),
--                     returned as a lower-camel code of StatusDescriptionENG
--                     (e.g. awaitingCollection, delivered, waitingForCalibration).
--                     Rationale: on STAGE the item-level CalibrationStatusId is entirely
--                     NULL, and shipping/delivery state is genuinely an order-level concept,
--                     so this SP keys on the order overall status (unlike GetCustomerDeviceList,
--                     which keys on the item calibration status). See NOTE below.
--   * statusLabel  -> Hebrew label of the same status (StatusDescriptionHEB) for the
--                     Hebrew-first portal, since no FE code->label map exists for this screen yet.
--   * shippingMethod   -> wp.ShipTypeDesc (order-level shipping method).
--   * shippingDoc      -> itm.ShippingDoc (delivery note / shipping document number).
--   * shippingAddress  -> COALESCE(itm.ShippingAddress, c.CustomerAddress).
--   * All *Date columns -> DD.MM.YYYY string (CONVERT style 104), NULL-safe.
--       receivingDate     = itm.CustomerReceivingDate (date device received at lab)
--       calibrationDate   = itm.ActualCalibrationDate
--       expectedReturnDate= itm.ExpectedReturnDate
--       deliveryDate      = itm.ActualReturnDate (date shipped back to customer)
--
-- NOTE for review (Ariel): source mappings below are best-guess from the Calibrator
--   schema (no Figma). Please confirm:
--     * status source   -> wp.OrderOverallStatusId (order-level). Item-level
--       CalibrationStatusId is 100% NULL on STAGE; confirm the shipping screen wants the
--       order status (and, if so, whether it should be filtered to the delivery-side
--       statuses only, e.g. AwaitingCollection / delivered).
--     * deliveryDate    -> itm.ActualReturnDate (alt: a dedicated shipping-out date if added)
--     * shippingAddress -> itm.ShippingAddress fallback c.CustomerAddress (alt: itm.SiteAddress)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerShipments]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    ;WITH shipments AS
    (
        SELECT
             itm.OrderDetailsItemId                                                  AS id
            ,wp.OrderNumber                                                          AS OrderNumber
            ,itm.MbaReportNumber                                                     AS MbaReportNumber
            ,itm.SerialNumber                                                        AS SerialNumber
            ,pt.OrdersProductTypeName                                                AS DeviceDescription
            ,itm.OrdersDeviceManufacturer                                            AS DeviceManufacturer
            ,itm.DeviceModel                                                         AS DeviceModel
            ,wp.ShipTypeDesc                                                         AS ShippingMethod
            ,itm.ShippingDoc                                                         AS ShippingDoc
            ,COALESCE(itm.ShippingAddress, c.CustomerAddress)                        AS ShippingAddress
            ,itm.CustomerReceivingDate                                               AS ReceivingDate
            ,itm.ActualCalibrationDate                                               AS CalibrationDate
            ,itm.ExpectedReturnDate                                                  AS ExpectedReturnDate
            ,itm.ActualReturnDate                                                    AS DeliveryDate
            ,st.StatusDescriptionENG                                                 AS StatusEng
            ,st.StatusDescriptionHEB                                                 AS StatusHeb
            ,ROW_NUMBER() OVER (PARTITION BY itm.OrderDetailsItemId
                                ORDER BY wp.OrderWorkPlanId DESC)                    AS Rn
        FROM [dbo].[OrderWorkPlans]      AS wp
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
        LEFT JOIN [dbo].[Customers]          AS c  ON c.CustomerId          = wp.CustomerId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId           = wp.OrderOverallStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.CustomerId       = @CustomerId
          AND wp.IsCancelled      = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
          AND ISNULL(itm.IsCancelled,0)= 0
    )
    SELECT
         s.id
        ,s.OrderNumber                                                   AS orderNumber
        ,s.MbaReportNumber                                              AS mbaReportNumber
        ,s.SerialNumber                                                  AS serialNumber
        ,s.DeviceDescription                                            AS deviceDescription
        ,s.DeviceManufacturer                                           AS deviceManufacturer
        ,s.DeviceModel                                                   AS deviceModel
        ,s.ShippingMethod                                               AS shippingMethod
        ,s.ShippingDoc                                                   AS shippingDoc
        ,s.ShippingAddress                                              AS shippingAddress
        ,CONVERT(VARCHAR(10), s.ReceivingDate,      104)               AS receivingDate
        ,CONVERT(VARCHAR(10), s.CalibrationDate,    104)               AS calibrationDate
        ,CONVERT(VARCHAR(10), s.ExpectedReturnDate, 104)               AS expectedReturnDate
        ,CONVERT(VARCHAR(10), s.DeliveryDate,       104)               AS deliveryDate
        ,CASE
            WHEN s.StatusEng IS NULL OR LEN(s.StatusEng) = 0 THEN NULL
            ELSE LOWER(LEFT(REPLACE(s.StatusEng, '''', ''), 1))
               + SUBSTRING(REPLACE(s.StatusEng, '''', ''), 2, 200)
         END                                                            AS status
        ,s.StatusHeb                                                    AS statusLabel
    FROM shipments AS s
    WHERE s.Rn = 1
    ORDER BY s.DeliveryDate DESC, s.CalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerInvoicesQuotes (git HEAD) ---- */
/*
    dbo.GetCustomerInvoicesQuotes                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerInvoicesQuotes
-- Jira:        MBA-797 (Customer Invoice/Quotes page — customer/invoice)
-- Description: Customer-portal Invoices/Quotes grid (screen has two tabs: "quotes" and
--              "invoices"). Identity input matches the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped
--              to the calling customer only, consistent with dbo.GetCustomerDashboardData
--              / dbo.GetCustomerDeviceList.
--
--              *** PARTIAL / SCAFFOLD — see the "BLOCKED" note below. ***
--              The Calibrator DB holds calibration ORDERS with per-line pricing
--              (OrderDetails.PRICE = net, OrderDetails.VPRICE = VAT-inclusive), but it does
--              NOT hold billing/financial DOCUMENTS. It has no invoice numbers, no quote
--              numbers, no discount amounts, and no "paid by" party. Those live in the
--              Priority ERP and are not synced into Calibrator on STAGE:
--                  - OrderWorkPlans.BK_DOC_N is 100% NULL (0 distinct values on STAGE).
--                  - There is no Quotes / Invoices / Discount / Payments table.
--              This SP therefore returns one row per calibration order with the fields that
--              ARE legitimately available, and returns NULL for every field that must come
--              from Priority. It does NOT fabricate invoice/quote numbers or discounts.
--
--              There is also no data in Calibrator to split rows into "quotes" vs
--              "invoices"; @DocType is accepted for forward-compatibility but currently only
--              affects nothing (all rows are order-derived). FE tabs can filter later once
--              the Priority-sourced document type exists.
--
-- Output columns (superset covering both FE tabs; camelCase to match FE Raw* row types):
--   id, orderNumber, date, invoiceNumber, invoiceDate, quoteNumber,
--   price, discount, finalPrice, paidBy
--     * date / invoiceDate -> DD.MM.YYYY (CONVERT style 104) from WorkPlanOpenDate.
--     * price              -> SUM(OrderDetails.PRICE)  net, per order, 2dp string.
--     * finalPrice         -> SUM(OrderDetails.VPRICE) VAT-inclusive, per order, 2dp string.
--                             (NOTE: this is VAT-inclusive total, NOT a post-discount final;
--                              a true finalPrice needs the Priority discount — see BLOCKED.)
--     * invoiceNumber / invoiceDate / quoteNumber / discount / paidBy -> NULL (Priority ERP).
--
-- REVIEW / OPEN QUESTION (Ariel / Dako): confirm whether the Invoices/Quotes screen should
--   be sourced from a Priority sync (invoice/quote documents, discounts, paid-by) rather
--   than from Calibrator orders. If yes, this screen is blocked on that sync; if the intent
--   is "order pricing" only, drop the invoice/quote/discount/paidBy columns from the design.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerInvoicesQuotes]
    @LoggedInUserEmail NVARCHAR(50),
    @DocType           VARCHAR(10) = NULL   -- reserved: 'quotes' | 'invoices' (no source yet)
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted. */
   ,@SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    ;WITH orderTotals AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,wp.WorkPlanOpenDate
            ,SUM(ISNULL(od.PRICE, 0))  AS NetTotal
            ,SUM(ISNULL(od.VPRICE, 0)) AS VatTotal
        FROM [dbo].[OrderWorkPlans] AS wp
        JOIN [dbo].[OrderDetails]   AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        WHERE wp.CustomerId          = @CustomerId
          AND wp.IsCancelled         = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
        GROUP BY wp.OrderWorkPlanId, wp.OrderNumber, wp.WorkPlanOpenDate
    )
    SELECT
         ot.OrderWorkPlanId                                        AS id
        ,ot.OrderNumber                                            AS orderNumber
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS date
        ,CAST(NULL AS NVARCHAR(50))                                AS invoiceNumber   -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS invoiceDate     -- placeholder = order date; real invoice date is Priority
        ,CAST(NULL AS NVARCHAR(50))                                AS quoteNumber     -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.NetTotal AS DECIMAL(18,2)))  AS price           -- net
        ,CAST(NULL AS NVARCHAR(20))                                AS discount        -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.VatTotal AS DECIMAL(18,2)))  AS finalPrice      -- VAT-inclusive total (see header note)
        ,CAST(NULL AS NVARCHAR(100))                               AS paidBy          -- Priority ERP (not in Calibrator)
    FROM orderTotals AS ot
    ORDER BY ot.WorkPlanOpenDate DESC
    OPTION (RECOMPILE);
END
GO
/* ---- dbo.GetCustomerContacts (git HEAD) ---- */
/*
    dbo.GetCustomerContacts                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Contacts of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 ג€” FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users ג€” internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function.
--              Order matters ג€” the portal case is checked first, and the staff path is
--              untouched, so the internal screen behaves exactly as before.
--
--              Same defect and same fix as GetCustomerSupportData (2026-08-30).
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerContacts]
@LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS

SET NOCOUNT ON;

DECLARE @CustomerId INT = NULL;

-- Primary resolution: portal contact login
    /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,c.[CustomerContactName]
      ,c.[CustomerContactPersonRole]
      ,c.[CustomerContactPhone]
      ,c.[CustomerContactAdditionalPhoneNumber]
      ,c.[CustomerContactEmail]
      ,c.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,c.[CustomerSiteId]
      ,c.[IsDeleted]
  FROM [dbo].[CustomerContacts] as c
  LEFT JOIN [dbo].[Source] as s ON c.[SourceId] = s.[SourceId]
  WHERE /*c.[IsDeleted] = 0 AND*/ c.CustomerId = @CustomerId
GO
/* ---- dbo.GetCustomerSites (git HEAD) ---- */
/*
    dbo.GetCustomerSites                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Sites (sub-sites) of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 ג€” FIX: portal users could not resolve.
--
--              Identical defect to GetCustomerContacts: the customer was resolved only
--              through dbo.GetSourceFilterByEmail, a table-valued function over
--              dbo.Users. A portal user lives in dbo.CustomerContacts and has no Users
--              row, so the function returned no rows, @CustomerId stayed NULL, and
--              `WHERE cs.CustomerId = @CustomerId` was always false.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function,
--              so the internal screen is unaffected.
--
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSites]
@LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS

SET NOCOUNT ON;

DECLARE @CustomerId INT = NULL;

-- Primary resolution: portal contact login
    /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT cs.[CustomerId]
      ,cs.[CustomerSiteId]
      ,cs.[CustomerSiteAddress]
      ,cs.[CustomerSiteState]
      ,cs.[CustomerSiteZIP]
      ,cs.[CustomerSitePhone]
      ,cs.[CustomerSiteDescription]
      ,cs.[CustomerSiteCode]
      ,cs.[CreateDate]
      ,cs.[UpdatedDate]
      ,cs.[UpdateUserID]
      ,cs.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,cs.[CustomerSiteAddressENG]
      ,cs.[CustomerSiteStateENG]
      ,cs.[CustomerSiteDescriptionENG]
      ,cs.[IsDeleted]
  FROM [dbo].[CustomerSites] as cs
  LEFT JOIN [dbo].[Source] as s ON cs.[SourceId] = s.[SourceId]
  WHERE /*cs.[IsDeleted] = 0 AND */cs.CustomerId = @CustomerId
GO
/* ---- dbo.GetCustomerProfile (git HEAD) ---- */
/*
    dbo.GetCustomerProfile                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Author:      Claude (subagent)
-- Create date: 04/08/2026
-- Description: Returns the customer profile / main-site header for the
--              logged-in customer user (screen: customer/profile, MBA-612).
--              Customer-scoped: @CustomerId is resolved from dbo.CustomerContacts
--              by @LoggedInUserEmail (same convention as GetCustomerDashboardData),
--              with a fallback to dbo.Users so support/portal logins also resolve.
--              Returns a single header row. The sub-sites list and the MABA
--              contact cards on the same screen are served by the existing
--              GetCustomerSites / GetCustomerContacts / GetCustomerSupportData SPs
--              and are intentionally NOT duplicated here.
-- JiraLink:    MBA-612
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerProfile]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = cc.CustomerId
        FROM dbo.CustomerContacts AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    -- Fallback: user account login (support / staff mapped to a customer)
    IF @CustomerId IS NULL
    BEGIN
        SELECT TOP 1 @CustomerId = u.CustomerId
        FROM dbo.Users AS u
        WHERE u.Email = @LoggedInUserEmail;
    END

    SELECT
         c.CustomerId
        ,c.CustomerCode                                              AS SiteNumber
        ,c.CustomerName                                             AS MainSiteName
        ,c.CustomerNameENG                                          AS MainSiteNameENG
        ,c.CustomerName                                             AS AccountName
        ,c.CustomerNameENG                                          AS AccountNameENG
        -- No dedicated report-language column exists; report output preference
        -- is currently a UI toggle. Returned NULL so FE can default to 'he'.
        ,CAST(NULL AS NVARCHAR(2))                                  AS ReportLanguage
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddress,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCity)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCity ELSE N'' END
            )))                                                    AS SiteAddress
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddressENG,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCityENG)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCityENG ELSE N'' END
            )))                                                    AS SiteAddressENG
        ,c.CustomerPhone                                           AS SitePhone
        ,c.ReportRequired                                          AS ReportRequired
        ,c.ShipTypeDescr                                           AS ShippingMethod
        ,c.SignatureAmount                                         AS SignatureAmount
        -- Count of sub-sites so FE can show/toggle "all sites"; the list itself
        -- comes from GetCustomerSites.
        ,(SELECT COUNT(*) FROM dbo.CustomerSites AS s
          WHERE s.CustomerId = c.CustomerId AND s.IsDeleted = 0)   AS SubSitesCount
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;
END
GO
/* ---- dbo.GetCustomerSupportData (git HEAD) ---- */
/*
    dbo.GetCustomerSupportData                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("׳©׳¨׳•׳× ׳׳§׳•׳—׳•׳× ׳׳‘\"׳" card). One employee per customer.
--
-- 2026-08-30 ג€” FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false ג€” the card was empty
--              for every portal user since the day it was written.
--
--              Now resolved from dbo.CustomerContacts first, falling back to dbo.Users,
--              which is the same convention GetCustomerProfile, GetCustomerDashboardData
--              and GetCustomerDeviceList already use. This SP was the only one in the
--              portal set that did not.
--
--              Output columns are unchanged, so the front end needs no change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSupportData]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = cc.CustomerId
        FROM dbo.CustomerContacts AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    -- Fallback: user account login (support / staff mapped to a customer)
    IF @CustomerId IS NULL
    BEGIN
        SELECT TOP 1 @CustomerId = u.CustomerId
        FROM dbo.Users AS u
        WHERE u.Email = @LoggedInUserEmail;
    END

    IF @CustomerId IS NULL
        RETURN;

    SELECT
         u.FirstName
        ,u.LastName
        ,u.Email
        ,u.Phone
    FROM dbo.Customers AS c
    JOIN dbo.Users     AS u ON u.ID = c.CustomerSupportContactId
    WHERE c.CustomerId = @CustomerId;
END
GO
/* ---- dbo.GetCustomerInvoicesFromPriority (git HEAD) ---- */
/*
    dbo.GetCustomerInvoicesFromPriority                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerInvoicesFromPriority
    @LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;
        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = CustomerId FROM dbo.CustomerContacts
          WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted,0)=0
          ORDER BY CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */;
    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId=@CustomerId;
    IF @Cust IS NULL RETURN;
    SELECT iv.IVNUM AS invoiceNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, iv.IVDATE, '1988-01-01'), 104) AS invoiceDate,
        iv.TOTPRICE AS totalPrice, iv.IVBALANCE AS balance,
        CAST(CASE WHEN iv.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit) AS isPaid
    FROM [31.168.173.93].amaba.dbo.INVOICES AS iv
    WHERE iv.CUST = @Cust
    ORDER BY iv.IVDATE DESC;
END
GO
/* ---- dbo.GetCustomerQuotesFromPriority (git HEAD) ---- */
/*
    dbo.GetCustomerQuotesFromPriority                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerQuotesFromPriority
    @LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;
        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = CustomerId FROM dbo.CustomerContacts
          WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted,0)=0
          ORDER BY CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */;
    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId=@CustomerId;
    IF @Cust IS NULL RETURN;
    SELECT cp.CPROFNUM AS quoteNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, cp.PDATE, '1988-01-01'), 104) AS quoteDate,
        CONVERT(varchar(10), DATEADD(MINUTE, NULLIF(cp.EXPIRYDATE,0), '1988-01-01'), 104) AS validUntil,
        cp.TOTPRICE AS totalPrice, cp.DISPRICE AS finalPrice,
        (cp.TOTPRICE - cp.DISPRICE) AS discount, cp.CPROFSTAT AS statusCode
    FROM [31.168.173.93].amaba.dbo.CPROF AS cp
    WHERE cp.CUST = @Cust
    ORDER BY cp.PDATE DESC;
END
GO
/* ---- dbo.GetCustomerPortalContactByEmail (git HEAD) ---- */
/*
    dbo.GetCustomerPortalContactByEmail
    -----------------------------------
    Step 2 of the customer-portal login: does this e-mail belong to a customer contact?

    Two sources, in order:
      1. dbo.CustomerContacts  - the local mirror of Priority, fast and always available.
      2. Priority PHONEBOOK    - over the linked server, because the mirror only carries a fraction
                                 of the contacts that exist in Priority (~2k of ~22k). Without this
                                 fallback most legitimate contacts are told their e-mail is unknown.

    The Priority lookup is wrapped in TRY/CATCH: if the linked server is unreachable the procedure
    degrades to the mirror instead of failing the login outright.

    Returns exactly 0 or 1 rows. `Source` says where the match came from. `MatchCount` is the number
    of distinct customers the e-mail resolves to; the portal treats an e-mail as a unique identifier,
    so anything above 1 is a data-quality problem worth logging (one contact is still returned, so
    login is never blocked).
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerPortalContactByEmail
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));

    IF @NormalizedEmail IS NULL OR @NormalizedEmail = ''
        RETURN;

    DECLARE @CustomerContactId INT,
            @CustomerId        INT,
            @ContactName       NVARCHAR(100),
            @ContactPhone      NVARCHAR(100),
            @PriorityPhone     INT,
            @MatchCount        INT = 0,
            @Source            NVARCHAR(10);

    /* ---------- 1. local mirror ---------- */
    SELECT TOP (1)
        @CustomerContactId = cc.CustomerContactId,
        @CustomerId        = cc.CustomerId,
        @ContactName       = cc.CustomerContactName,
        @ContactPhone      = cc.CustomerContactPhone
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
    ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated */

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @Source = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail;
    END
    ELSE
    BEGIN
        /* ---------- 2. Priority fallback ---------- */
        CREATE TABLE #PriorityContacts (PHONE INT, CUST INT, NAME NVARCHAR(100), PHONENUM NVARCHAR(50));

        BEGIN TRY
            INSERT INTO #PriorityContacts (PHONE, CUST, NAME, PHONENUM)
            EXEC dbo.GetPriorityContactsByEmail @Email = @NormalizedEmail;
        END TRY
        BEGIN CATCH
            /* linked server unreachable - behave as "not found in Priority" */
            DELETE FROM #PriorityContacts;
        END CATCH

        SELECT TOP (1)
            @PriorityPhone = p.PHONE,
            @CustomerId    = c.CustomerId,
            @ContactName   = LEFT(LTRIM(RTRIM(p.NAME)), 100),
            @ContactPhone  = LEFT(LTRIM(RTRIM(p.PHONENUM)), 100)
        FROM #PriorityContacts AS p
        INNER JOIN dbo.Customers AS c
                ON c.CustomerIdFromSource = p.CUST
               AND c.IsDeleted = 0
        ORDER BY p.PHONE ASC;

        IF @PriorityPhone IS NOT NULL
        BEGIN
            SET @Source = N'Priority';

            SELECT @MatchCount = COUNT(DISTINCT c.CustomerId)
            FROM #PriorityContacts AS p
            INNER JOIN dbo.Customers AS c
                    ON c.CustomerIdFromSource = p.CUST
                   AND c.IsDeleted = 0;
        END

        DROP TABLE #PriorityContacts;
    END

    IF @Source IS NULL
        RETURN;   /* no rows: the e-mail is not a customer contact anywhere */

    SELECT
        @CustomerContactId AS CustomerContactId,
        @PriorityPhone     AS PriorityContactId,
        @CustomerId        AS CustomerId,
        @ContactName       AS CustomerContactName,
        @ContactPhone      AS CustomerContactPhone,
        @NormalizedEmail   AS Email,
        c.CustomerName,
        c.CustomerNameENG,
        c.CustomerCode,
        @MatchCount        AS MatchCount,
        @Source            AS Source
    FROM (SELECT 1 AS X) AS Anchor
    LEFT JOIN dbo.Customers AS c
           ON c.CustomerId = @CustomerId
          AND c.IsDeleted = 0;
END
GO
/* ---- dbo.CreateCustomerPortalOtp (git HEAD) ---- */
/*
    dbo.CreateCustomerPortalOtp
    ---------------------------
    Step 3 of the customer-portal login: issue a one-time passcode for an e-mail that belongs to a
    customer contact. The application generates the 6-digit code, hashes it (HMAC-SHA256 + server
    pepper) and passes only @CodeHash here - the plaintext code never reaches the database.

    Identity resolution is hybrid:
      1. dbo.CustomerContacts - the local mirror of Priority.
      2. Priority PHONEBOOK over the linked server, when the mirror does not know the e-mail. The
         mirror only carries ~2k of the ~22k contacts that exist in Priority, so without this step
         most legitimate contacts are told their address is unknown.

    A contact found only in Priority is materialised into dbo.CustomerContacts before the code is
    issued. That is deliberate: every other portal procedure resolves the customer by looking the
    logged-in e-mail up in CustomerContacts, so a session with no row there would authenticate and
    then show an empty portal. The inserted row carries SourceId/CustomerContactIdFromSource exactly
    as the Priority sync would write them, so the sync can still match it.

    A Priority contact whose customer does not exist locally is rejected - there would be no
    CustomerId to scope the portal's data by.

    Any previously issued, still-open code for the same e-mail is invalidated, so only the newest
    code can ever be redeemed.

    Result set (always exactly 1 row):
        Status        'Created' | 'EmailNotFound' | 'RateLimited'
        ExpiresAt     UTC expiry of the new code (NULL unless Created)
        RetryAfterSec seconds until the rate-limit window frees up (NULL unless RateLimited)
        IdentitySource 'Mirror' | 'Priority' | NULL
        CustomerId, CustomerContactId, CustomerContactName, CustomerName, MatchCount
*/
CREATE OR ALTER PROCEDURE dbo.CreateCustomerPortalOtp
    @Email         NVARCHAR(100),
    @CodeHash      VARBINARY(32),
    @TtlSeconds    INT     = 600,   /* code lifetime            */
    @MaxAttempts   TINYINT = 5,     /* wrong-code tries allowed  */
    @MaxPerWindow  INT     = 5,     /* codes issued per window   */
    @WindowSeconds INT     = 900,
    @RequestIp     NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));
    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @CustomerId        INT,
            @CustomerContactId INT,
            @ContactName       NVARCHAR(100),
            @ContactPhone      NVARCHAR(100),
            @CustomerName      NVARCHAR(200),
            @PriorityPhone     INT,
            @MatchCount        INT = 0,
            @IdentitySource    NVARCHAR(10);

    /* ---------- 1. local mirror ---------- */
    SELECT TOP (1)
        @CustomerContactId = cc.CustomerContactId,
        @CustomerId        = cc.CustomerId,
        @ContactName       = cc.CustomerContactName
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @IdentitySource = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail;
    END
    ELSE
    BEGIN
        /* ---------- 2. Priority fallback ---------- */
        CREATE TABLE #PriorityContacts (PHONE INT, CUST INT, NAME NVARCHAR(100), PHONENUM NVARCHAR(50));

        BEGIN TRY
            INSERT INTO #PriorityContacts (PHONE, CUST, NAME, PHONENUM)
            EXEC dbo.GetPriorityContactsByEmail @Email = @NormalizedEmail;
        END TRY
        BEGIN CATCH
            /* linked server unreachable - fall through as "not a known contact" */
            DELETE FROM #PriorityContacts;
        END CATCH

        SELECT TOP (1)
            @PriorityPhone = p.PHONE,
            @CustomerId    = c.CustomerId,
            @ContactName   = LEFT(LTRIM(RTRIM(p.NAME)), 100),
            @ContactPhone  = LEFT(LTRIM(RTRIM(p.PHONENUM)), 100)
        FROM #PriorityContacts AS p
        INNER JOIN dbo.Customers AS c
                ON c.CustomerIdFromSource = p.CUST
               AND c.IsDeleted = 0
        ORDER BY p.PHONE ASC;

        IF @PriorityPhone IS NOT NULL
            SELECT @MatchCount = COUNT(DISTINCT c.CustomerId)
            FROM #PriorityContacts AS p
            INNER JOIN dbo.Customers AS c
                    ON c.CustomerIdFromSource = p.CUST
                   AND c.IsDeleted = 0;

        DROP TABLE #PriorityContacts;

        IF @PriorityPhone IS NOT NULL AND @CustomerId IS NOT NULL
        BEGIN
            /* materialise so the rest of the portal can resolve this visitor */
            INSERT INTO dbo.CustomerContacts
                (CustomerId, CustomerContactName, CustomerContactPhone, CustomerContactEmail,
                 CustomerContactIdFromSource, SourceId, CreateDate, IsDeleted)
            SELECT @CustomerId, @ContactName, @ContactPhone, @NormalizedEmail,
                   @PriorityPhone, 1, @Now, 0
            WHERE NOT EXISTS (   /* another concurrent request may have just created it */
                SELECT 1 FROM dbo.CustomerContacts AS cc
                WHERE cc.IsDeleted = 0
                  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            );

            SELECT TOP (1) @CustomerContactId = cc.CustomerContactId
            FROM dbo.CustomerContacts AS cc
            WHERE cc.IsDeleted = 0
              AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            ORDER BY cc.CustomerContactId ASC;

            SET @IdentitySource = N'Priority';
        END
    END

    IF @CustomerContactId IS NULL
    BEGIN
        SELECT
            CAST('EmailNotFound' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))            AS ExpiresAt,
            CAST(NULL AS INT)                     AS RetryAfterSec,
            CAST(NULL AS INT)                     AS CustomerId,
            CAST(NULL AS INT)                     AS CustomerContactId,
            CAST(NULL AS NVARCHAR(100))           AS CustomerContactName,
            CAST(NULL AS NVARCHAR(200))           AS CustomerName,
            CAST(0 AS INT)                        AS MatchCount,
            CAST(NULL AS NVARCHAR(10))            AS IdentitySource;
        RETURN;
    END

    SELECT @CustomerName = c.CustomerName
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;

    /* ---- rate limit: at most @MaxPerWindow codes per e-mail per window ---- */
    DECLARE @IssuedInWindow INT, @OldestInWindow DATETIME2(3);

    SELECT
        @IssuedInWindow = COUNT(*),
        @OldestInWindow = MIN(o.CreatedAt)
    FROM dbo.CustomerPortalOtp AS o
    WHERE o.Email = @NormalizedEmail
      AND o.CreatedAt > DATEADD(SECOND, -@WindowSeconds, @Now);

    IF @IssuedInWindow >= @MaxPerWindow
    BEGIN
        SELECT
            CAST('RateLimited' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))          AS ExpiresAt,
            DATEDIFF(SECOND, @Now, DATEADD(SECOND, @WindowSeconds, @OldestInWindow)) AS RetryAfterSec,
            @CustomerId          AS CustomerId,
            @CustomerContactId   AS CustomerContactId,
            @ContactName         AS CustomerContactName,
            @CustomerName        AS CustomerName,
            @MatchCount          AS MatchCount,
            @IdentitySource      AS IdentitySource;
        RETURN;
    END

    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(SECOND, @TtlSeconds, @Now);

    BEGIN TRY
        BEGIN TRANSACTION;

            /* only the newest code stays redeemable */
            UPDATE dbo.CustomerPortalOtp
            SET InvalidatedAt = @Now
            WHERE Email = @NormalizedEmail
              AND ConsumedAt IS NULL
              AND InvalidatedAt IS NULL;

            INSERT INTO dbo.CustomerPortalOtp
                (Email, CodeHash, CustomerId, CustomerContactId, AttemptsLeft, CreatedAt, ExpiresAt, RequestIp)
            VALUES
                (@NormalizedEmail, @CodeHash, @CustomerId, @CustomerContactId, @MaxAttempts, @Now, @ExpiresAt, @RequestIp);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT
        CAST('Created' AS NVARCHAR(20)) AS Status,
        @ExpiresAt           AS ExpiresAt,
        CAST(NULL AS INT)    AS RetryAfterSec,
        @CustomerId          AS CustomerId,
        @CustomerContactId   AS CustomerContactId,
        @ContactName         AS CustomerContactName,
        @CustomerName        AS CustomerName,
        @MatchCount          AS MatchCount,
        @IdentitySource      AS IdentitySource;
END
GO
/* ---- dbo.GetCustomerUpcommingCalibrationInfo (captured live, still pre-change) ---- */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/03/2026
-- Description:	Get information about customer aucomming calibration
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerUpcommingCalibrationInfo] 
@LoggedInUserEmail NVARCHAR(50)
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT

SELECT TOP 1 
	@CustomerId  = d.CustomerId 
,@SourceId = d.SourceId
FROM [dbo].[CustomerContacts] as d
WHERE CustomerContactEmail = @LoggedInUserEmail 


ORDER BY d.CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */
DECLARE @CurrentDate DATETIME2(0) =  CAST(GETDATE() AS DATE)

SELECT TOP 1 WITH TIES
 u.FirstName	
,u.LastName
,u.Email
,u.Phone
,AssigmentDate
--,wp.OrderWorkPlanId
--, wp.CustomerId
--,wp.OrderNumber
FROM [dbo].[OrderWorkPlans] as wp
JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.IsDeleted = 0
JOIN [dbo].[Users] as u ON ctwp.CalibratorId = u.[ID]
WHERE  wp.CustomerId = @CustomerId AND ctwp.AssigmentDate >= @CurrentDate
AND wp.IsCancelled = 0 
ORDER BY RANK() OVER( ORDER BY ctwp.AssigmentDate)
GO
/* ---- the new function has no pre-change version: it did not exist ---- */
DROP FUNCTION IF EXISTS dbo.GetPortalCustomerIds;
GO
