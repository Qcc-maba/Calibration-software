/* Rollback for MBA-943 on Prod, captured 20260831-101851.
   Run this whole file with:  sqlcmd -S <srv> -d <db> -U <u> -P <p> -C -I -f 65001 -i <this file>
   Objects that did not exist before the deploy appear here as a DROP. */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
=============================================================================================
    Every customer the portal caller is entitled to see, as a set.

    WHY THIS EXISTS
    ---------------
    A portal login is an e-mail address, and an e-mail address is not one customer. 3,684 addresses
    are a contact of more than one: davide@iscar.co.il is a contact of 22 ישקר entities,
    sharbaf_o@mac.org.il of 25 מכבי branches. Priority models an Iscar division as its own
    Customers row, not as a CustomerSites row - dbo.CustomerSites is empty for all of them - so
    from the database's point of view a plant manager simply has many customers.

    Until now every GetCustomer* proc resolved that to exactly one:

        SELECT TOP (1) @CustomerId = cc.CustomerId ... ORDER BY cc.CustomerContactId ASC

    Deterministic, but arbitrary, and measurably wrong. For davide@iscar.co.il the lowest contact
    id lands on ישקר בע"מ, which has ZERO devices, while ישקר-מתק"ש-תפן has 24, ישקר מיקרו-כלים 4
    and ישקר-מיבדקה 3. He logged in and saw an empty portal while 31 of his devices sat in the
    system. Measured across STAGE: 181 addresses see a blank portal despite owning devices, 240
    see only part of theirs, and 3,468 devices are hidden from their own contacts.

    THE DEVICE FILTER IS NOT COSMETIC
    ---------------------------------
    Not every association in Priority is a real one. davide@iscar.co.il is also listed against
    פאדאגיס ישראל פרמצבטיקה - an unrelated company - and against מקדמות מלקוחות, which is an
    accounting row rather than a customer. Both hold no devices today, but that is luck, not a
    rule. Since the portal now shows several customers at once, an untidy association would put
    another company's devices on an Iscar manager's screen with nothing to mark them as foreign.
    Restricting the set to customers that actually hold devices removes both, and does it on a
    property the portal genuinely depends on.

    The fallback matters: if NONE of the caller's customers hold a device, the whole set is
    returned rather than nothing. A newly registered customer with no calibrations yet must see an
    empty device list, not a portal that cannot resolve who they are - the profile, contacts and
    support screens still have to work.

    IsPrimary
    ---------
    The union is right for devices, reports and calibrations. It is meaningless for the screens
    that describe ONE customer - profile, contacts, sites, support, and the Priority invoices and
    quotes, which are keyed by a single CustomerIdFromSource. Those take the row flagged IsPrimary:
    most devices first, lowest contact id to break a tie. That is still one customer, but it is now
    the one the caller actually works with instead of whichever id happened to be lowest.

    SECURITY
    --------
    The set is derived from the caller's own CustomerContacts rows and nothing else. There is no
    parameter through which a caller can name a customer, so there is nothing to verify and nothing
    to forge. This replaces the @SelectedCustomerId parameter added in MBA-936, which was built for
    a branch picker that we are not building.
*/
CREATE   FUNCTION dbo.GetPortalCustomerIds (@LoggedInUserEmail NVARCHAR(100))
RETURNS TABLE
AS
RETURN
    WITH mine AS
    (
        /* One row per customer this address is a contact of, plus the id that used to decide
           everything - still useful as a stable tie-break. */
        SELECT cc.CustomerId,
               MIN(cc.CustomerContactId) AS FirstContactId
        FROM dbo.CustomerContacts AS cc
        WHERE ISNULL(cc.IsDeleted, 0) = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
        GROUP BY cc.CustomerId
    ),
    counted AS
    (
        SELECT m.CustomerId,
               m.FirstContactId,
               d.DeviceCount
        FROM mine AS m
        CROSS APPLY
        (
            SELECT COUNT_BIG(DISTINCT itm.SerialNumber) AS DeviceCount
            FROM dbo.OrderWorkPlans AS wp
            JOIN dbo.OrderDetails AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
            JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId = od.OrderDetailId
            WHERE wp.CustomerId = m.CustomerId
        ) AS d
    ),
    kept AS
    (
        SELECT * FROM counted WHERE DeviceCount > 0

        UNION ALL

        /* Fallback - see header. Only fires when the caller has no devices anywhere. */
        SELECT * FROM counted
        WHERE NOT EXISTS (SELECT 1 FROM counted AS any_devices WHERE any_devices.DeviceCount > 0)
    )
    SELECT k.CustomerId,
           c.CustomerName,
           k.DeviceCount,
           CONVERT(BIT, IIF(ROW_NUMBER() OVER (ORDER BY k.DeviceCount DESC, k.FirstContactId ASC) = 1, 1, 0)) AS IsPrimary
    FROM kept AS k
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = k.CustomerId;
GO
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
--              MBA-939 - union across every customer the caller belongs to.
-- Description: Returns ONE row per device for the logged-in caller (customer portal
--              Device List grid).
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set with no pagination.
--
-- 2026-08-31 - MBA-939: the caller is a SET of customers, not one.
--
--              An e-mail address is a contact of one customer far less often than we assumed:
--              3,684 addresses serve several. davide@iscar.co.il is a contact of 22 ישקר
--              entities. The old rule took the lowest CustomerContactId, which for him is
--              ישקר בע"מ - a row holding ZERO devices - while his 24 devices sit under
--              ישקר-מתק"ש-תפן. He saw an empty portal. 181 addresses were in that state.
--
--              Scoping now comes from dbo.GetPortalCustomerIds, which returns every customer
--              the address belongs to that actually holds devices. See that function for why
--              the device filter is there and not cosmetic.
--
--              @SelectedCustomerId is GONE. It was added in MBA-936 for a branch picker that
--              we decided not to build; a union needs no choice and therefore no parameter to
--              verify. Callers passing it will now fail loudly rather than be silently ignored.
--
-- NEW COLUMN:  customerName - which company each device belongs to. Without it a manager sees
--              devices from three Iscar divisions in one list with nothing to tell them apart.
--              The front end has to render it (MBA-940).
--
-- Output (13 columns):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport,
--   customerName
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

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
            ,mine.CustomerName                                                        AS CustomerName
            /* MBA-939: partition by CUSTOMER + serial, not serial alone.
               10 of 3,819 serial numbers appear under more than one customer. Partitioning on
               the serial alone would keep the newest order and silently drop the other
               company's device from a list that now spans several companies. */
            ,ROW_NUMBER() OVER (PARTITION BY wp.CustomerId, itm.SerialNumber
                                ORDER BY wp.OrderWorkPlanId DESC)                     AS IsLatestOrder
        FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
        JOIN [dbo].[OrderWorkPlans]      AS wp  ON wp.CustomerId        = mine.CustomerId
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId   = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId    = od.OrderDetailId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.IsCancelled      = 0
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
        ,d.CustomerName                                                  AS customerName
    FROM devices AS d
    WHERE d.IsLatestOrder = 1
    ORDER BY d.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
-- Jira:        MBA-798  "Customer Selected-device detail view"
--              MBA-939  the caller owns a set of customers, not one
-- Description: Returns the FULL detail of ONE device for the logged-in caller
--              (customer portal "selected device" detail view). This is a distinct
--              contract from:
--                * dbo.GetCustomerDeviceList     -> one row PER device, list columns,
--                                                   no single-device key.
--                * dbo.GetOrderDetailsDevices    -> STAFF detail, keyed by OrderWorkPlanId,
--                                                   requires a MABA Users/UserRoles row via
--                                                   GetSourceFilterByEmail and performs NO
--                                                   customer-ownership check -> unusable and
--                                                   unsafe for a customer contact.
--
-- 2026-08-31 - MBA-939: the ownership guard now spans every company the caller belongs to.
--
--              THE GUARD IS NOT WEAKENED, IT IS WIDENED TO THE RIGHT SET. The device is still
--              re-scoped on every call: it must sit under a customer returned by
--              dbo.GetPortalCustomerIds for this e-mail, which is derived from the caller's own
--              CustomerContacts rows and takes no input from the request. A guessed
--              @OrderDetailsItemId belonging to anyone else still returns 0 rows. What changes is
--              that a manager can now open a device in his own second division - before, clicking
--              a row that the list itself had returned could come back empty, because the list and
--              the detail resolved to different single customers.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- Params:
--   @LoggedInUserEmail  NVARCHAR(100) -- customer contact e-mail (resolves the customer set)
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
--   calibratorFullName, calibratorPhone,
--   customerName  -- NEW (MBA-939): which company owns this device. Front end: MBA-940.
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerDeviceDetail]
    @LoggedInUserEmail  NVARCHAR(100),
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

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
        ,mine.CustomerName                                                        AS customerName
    /* Ownership guard: the device must belong to one of the caller's own customers. */
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN [dbo].[OrderWorkPlans]        AS wp  ON wp.CustomerId      = mine.CustomerId
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
      AND wp.IsCancelled           = 0
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
      AND ISNULL(itm.IsCancelled, 0) = 0
    OPTION (RECOMPILE);
END
GO
---------------------------------------------------------------------------------
    The חזרה צפויה column is labelled *expected* return, but the procedure was
    returning ActualReturnDate. It now returns ExpectedReturnDate, and only for in-house
    (lab) calibration - for on-site work there is nothing to return, so it is NULL.

    The output alias stays ActualReturnDate on purpose: the front end already binds to it,
    and renaming would break the screen for no gain.

    2026-08-31 - MBA-939: the caller is a SET of customers, not one.
    ---------------------------------------------------------------------------------
    An e-mail address is a contact of several customers in 3,684 cases. The old rule took the
    lowest CustomerContactId, which for davide@iscar.co.il landed on ישקר בע"מ - a row with zero
    devices - while his 31 devices sat under three other ישקר entities. The dashboard was empty
    for 181 such addresses.

    #CustomerOrdersIds is now filled from dbo.GetPortalCustomerIds, so every screen that reads it
    covers all the caller's companies at once. Everything downstream already filters through that
    temp table, so this is the only place the scope is decided.

    Two further changes inside the dynamic SQL:

      * IsLatestOrder partitions by CustomerId + SerialNumber, not SerialNumber alone. 10 of 3,819
        serials exist under more than one customer; over a union, partitioning on the serial alone
        keeps the newest order and silently drops the other company's device.
      * CustomerName is carried through to the output, so a manager can tell which company each
        row belongs to. The front end has to render it (MBA-940).

    @SourceId is removed. It was assigned from the contact row and never read.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/02/2026
-- Description:	Get customer dashboad data
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerDashboardData]
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 50,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CalibratioinDate',      -- OrderBy column
@OrderByAsc AS BIT = 0,                  -- OrderBy direction (ASC/DESC)
@LoggedInUserEmail NVARCHAR(100),
@GlobalSearch NVARCHAR(200) = NULL
AS

DROP TABLE IF EXISTS #CustomerOrdersIds
CREATE TABLE #CustomerOrdersIds
(
OrderWorkPlanId INT NOT NULL
)

/* MBA-939: every company this caller belongs to that holds devices - see dbo.GetPortalCustomerIds. */
INSERT #CustomerOrdersIds(OrderWorkPlanId)
SELECT wp.OrderWorkPlanId
FROM [dbo].[OrderWorkPlans] as wp
JOIN dbo.GetPortalCustomerIds(@LoggedInUserEmail) as mine ON mine.CustomerId = wp.[CustomerId]

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
,c.CustomerName as CustomerName
,ROW_NUMBER() OVER( PARTITION BY wp.[CustomerId], itm.SerialNumber ORDER BY wp.OrderWorkPlanId DESC) as IsLatestOrder
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
,d.CustomerName
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
,ds.CustomerName
,ds.OverallDevicesCount
,ds.ExpiredevicesCount
,ds.CalibratedDevicesCount
,ds.DevicesWaitingForCalibrationCount
,SUM(IsLatestOrder) OVER( ORDER BY ds.DeviceStatus) as ItemsCount
FROM devices_cnt as ds
WHERE ds.IsLatestOrder = 1'
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(ds.DeviceDescription,ds.SerialNumber,ds.CalibratorFirstName,ds.CalibratorLastName,ds.CalibratorPhoneNumber) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

EXEC (@sql)
GO
-- Jira:        MBA-796  "Customer Calibration-reports page (customer/calibration-reports)"
--              MBA-939  union across every customer the caller belongs to
-- Description: Returns the calibration reports belonging to the logged-in caller
--              (customer portal "Calibration Reports" grid, route customer/calibration-reports).
--
--              A "calibration report" is an OrderDetailsItem that has an MbaReportNumber assigned.
--              Unlike GetCustomerDeviceList (one row per device, latest order only) this SP returns
--              ONE ROW PER REPORT (every report the caller has, including historical / update
--              cycles), newest calibration first. Filtering / sorting / search are CLIENT-SIDE.
--
-- 2026-08-31 - MBA-939: the caller is a SET of customers, not one.
--
--              Scoping now comes from dbo.GetPortalCustomerIds - every customer the address
--              belongs to that holds devices. The old lowest-CustomerContactId rule showed
--              davide@iscar.co.il the reports of ישקר בע"מ, which has none, while his three other
--              ישקר divisions held all of them.
--
--              This SP is also what getCustomerReportUrl re-runs to authorise a report download,
--              so widening it here widens the download check in exactly the same way - a report
--              is downloadable if and only if it appears in this list.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- Output columns (camelCase, matching the app's Raw* -> mapper convention):
--   id                 -> OrderDetailsItemId (row key AND part of the AWS report path)
--   orderNumber        -> OrderWorkPlans.OrderNumber (part of the AWS report path)
--   reportPath         -> convenience S3 key the FE otherwise builds via getOrderReportPath():
--                         'orders/{orderNumber}/reports/{id}/report.pdf'
--   mbaReportNumber    -> itm.MbaReportNumber (מספר דוח מבא)
--   serialNumber       -> itm.SerialNumber
--   deviceDescription  -> OrdersProductTypes.OrdersProductTypeName
--   deviceManufacturer -> itm.OrdersDeviceManufacturer
--   deviceModel        -> itm.DeviceModel
--   calibrationDate    -> DD.MM.YYYY (CONVERT style 104) from itm.ActualCalibrationDate
--   reportStatus       -> lower-camel of the ReportStatus StatusDescriptionENG
--   reportStatusHeb    -> Statuses.StatusDescriptionHEB
--   customerName       -> NEW (MBA-939): which company the report belongs to. Front end: MBA-940.
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerCalibrationReports]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

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
        ,mine.CustomerName                                                  AS customerName
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN [dbo].[OrderWorkPlans]      AS wp  ON wp.CustomerId       = mine.CustomerId
    JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId  = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId   = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationReportStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
    WHERE wp.IsCancelled       = 0
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
---------------------------------------------------------------------------------------------
    The customer's orders as the portal shows them ("בקשות"): one row per OrderWorkPlan, with the
    device count, the earliest next-calibration date, whether any line is in-house, and the net
    price.

    2026-08-31 - MBA-939: scoped to the caller's customer SET rather than a single customer.

    An e-mail address is a contact of several customers in 3,684 cases, and orders are filed
    against whichever company owns the devices. Resolving to the lowest CustomerContactId showed
    davide@iscar.co.il the orders of ישקר בע"מ - none - while his real orders sat under three other
    ישקר divisions.

    The set comes from dbo.GetPortalCustomerIds, which is derived from the caller's own contact
    rows and takes nothing from the request, so no order of another customer can be reached.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.

    NEW COLUMN: customerName - which company each order belongs to. Front end: MBA-940.
*/
CREATE   PROCEDURE [dbo].[GetCustomerRequests]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH req AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,mine.CustomerName
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
        FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
        JOIN [dbo].[OrderWorkPlans] AS wp ON wp.CustomerId = mine.CustomerId
        WHERE wp.IsCancelled = 0
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
        ,r.CustomerName                                               AS customerName
    FROM req AS r
    LEFT JOIN [dbo].[Statuses] AS st
           ON st.StatusId = r.StatusId
          AND st.StatusCategoryId = 9      -- OrderStatus category
    ORDER BY r.OrderWorkPlanId DESC
    OPTION (RECOMPILE);
END
GO
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
CREATE   PROCEDURE dbo.GetCustomerPortalRequestList
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
CREATE   PROCEDURE [dbo].[GetCustomerShipments]
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
CREATE   PROCEDURE [dbo].[GetCustomerInvoicesQuotes]
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
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/03/2026
-- Description:	Get information about customer aucomming calibration
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerUpcommingCalibrationInfo] 
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
-- Create date: 04/05/2026
-- Description: Contacts of the customer(s) the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 - FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users - internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
-- 2026-08-31 - MBA-939: a portal caller is a SET of customers, not one.
--
--              3,684 addresses are a contact of more than one customer. A manager over
--              three ישקר divisions has contacts in all three; showing only the division
--              with the lowest CustomerContactId hid the rest for no reason.
--
--              The portal path is now a union over dbo.GetPortalCustomerIds. THE STAFF PATH
--              IS UNCHANGED: an internal user is still resolved to exactly one customer
--              through dbo.GetSourceFilterByEmail, and that lookup only runs when the caller
--              is not a portal contact at all. The internal screen therefore behaves exactly
--              as before.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided
--              not to build.
--
-- NEW COLUMN:  CustomerName - which company each contact belongs to. Without it, a union of
--              three divisions' contacts is an unlabelled list. Front end: MBA-940.
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerContacts]
    @LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

/* Staff fallback: only consulted when the caller is not a portal contact, so a portal caller
   can never pick up a staff mapping and vice versa. */
DECLARE @StaffCustomerId INT = NULL;

IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
BEGIN
    SELECT TOP 1 @StaffCustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,cust.[CustomerName]
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
  LEFT JOIN [dbo].[Customers] as cust ON cust.[CustomerId] = c.[CustomerId]
  WHERE /*c.[IsDeleted] = 0 AND*/
        (c.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
         OR c.CustomerId = @StaffCustomerId)
  ORDER BY cust.[CustomerName], c.[CustomerContactName];
GO
-- Create date: 04/05/2026
-- Description: Sites (sub-sites) of the customer(s) the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 - FIX: portal users could not resolve.
--
--              Identical defect to GetCustomerContacts: the customer was resolved only
--              through dbo.GetSourceFilterByEmail, a table-valued function over
--              dbo.Users. A portal user lives in dbo.CustomerContacts and has no Users
--              row, so the function returned no rows, @CustomerId stayed NULL, and
--              `WHERE cs.CustomerId = @CustomerId` was always false.
--
-- 2026-08-31 - MBA-939: a portal caller is a SET of customers, not one.
--
--              Worth knowing while reading this: what the business calls a "site" is usually
--              NOT a row in this table. dbo.CustomerSites is empty for every ישקר division -
--              Priority models each division as its own Customers row. So a manager's several
--              locations arrive through the union below, not through this table.
--
--              The portal path is now a union over dbo.GetPortalCustomerIds. THE STAFF PATH IS
--              UNCHANGED: dbo.GetSourceFilterByEmail is consulted only when the caller is not a
--              portal contact, so the internal screen behaves exactly as before.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- NEW COLUMN:  CustomerName - which company each site belongs to. Front end: MBA-940.
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerSites]
    @LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

DECLARE @StaffCustomerId INT = NULL;

IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
BEGIN
    SELECT TOP 1 @StaffCustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT cs.[CustomerId]
      ,cust.[CustomerName]
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
  LEFT JOIN [dbo].[Customers] as cust ON cust.[CustomerId] = cs.[CustomerId]
  WHERE /*cs.[IsDeleted] = 0 AND */
        (cs.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
         OR cs.CustomerId = @StaffCustomerId)
  ORDER BY cust.[CustomerName], cs.[CustomerSiteDescription];
GO
-- Create date: 04/08/2026
-- Description: Returns the customer profile / main-site header for the
--              logged-in customer user (screen: customer/profile, MBA-612).
--              Returns a SINGLE header row. The sub-sites list and the MABA
--              contact cards on the same screen are served by the existing
--              GetCustomerSites / GetCustomerContacts / GetCustomerSupportData SPs
--              and are intentionally NOT duplicated here.
--
-- 2026-08-31 - MBA-939: which customer, when the address serves several.
--
--              This screen describes ONE company - name, address, phone, shipping - so it
--              cannot be a union without breaking its contract with the front end, which maps
--              a single row. It now returns the caller's PRIMARY customer (the one holding the
--              most devices) instead of the one with the lowest CustomerContactId. For
--              davide@iscar.co.il that moves the profile from ישקר בע"מ, which holds none of
--              his work, to ישקר-מתק"ש-תפן, which holds most of it.
--
--              Note the asymmetry, and that it is deliberate: the profile header names one
--              company while GetCustomerSites and GetCustomerContacts beneath it now list all
--              of them. If that reads as confusing on screen, the fix belongs in the front end
--              (label the header, or let the user switch) rather than here - see MBA-940.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided
--              not to build.
-- JiraLink:    MBA-612
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerProfile]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    /* MBA-939: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

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
        -- MBA-939: how many company records this caller covers in total. 1 for almost everyone;
        -- above 1 tells the front end the header names only one of several.
        ,(SELECT COUNT(*) FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
                                                                   AS RelatedCompaniesCount
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;
END
GO
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("שרות לקוחות מב"א" card). One employee per customer.
--
-- 2026-08-30 - FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false - the card was empty
--              for every portal user since the day it was written.
--
--              Now resolved from the portal contact first, falling back to dbo.Users.
--
-- 2026-08-31 - MBA-939: which customer, when the address serves several.
--
--              This card names ONE account manager, so it cannot be a union. It now takes
--              the caller's PRIMARY customer - the one holding the most devices - instead
--              of the one with the lowest CustomerContactId. For davide@iscar.co.il the old
--              rule pointed at ישקר בע"מ, a row with no devices; his work is under
--              ישקר-מתק"ש-תפן, and so is the account manager who actually handles it.
--
--              @SelectedCustomerId is gone: MBA-936 added it for a branch picker we decided
--              not to build.
--
--              Output columns are unchanged, so the front end needs no change.
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerSupportData]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    /* MBA-939: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

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
---------------------------------------------------------------------------------------------
    Invoices straight from Priority over the linked server, keyed by CustomerIdFromSource = CUST.
    Priority stores dates as minutes since 1988-01-01.

    2026-08-31 - MBA-939: which customer, when the address serves several.

    DELIBERATELY NOT A UNION. The device and report screens now show every company the caller
    belongs to, because a plant manager owning devices in three ישקר divisions should see all of
    them. Invoices are different: they are financial, and joining three subsidiaries' balances into
    one list is a disclosure decision, not a display decision. Until that is decided by the
    business, this stays scoped to ONE customer.

    What did change is WHICH one. The old rule took the lowest CustomerContactId, which for
    davide@iscar.co.il is ישקר בע"מ - a row with no devices and, in all likelihood, no invoices
    he cares about. It now takes the primary customer: the one holding the most devices.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.
*/
CREATE   PROCEDURE dbo.GetCustomerInvoicesFromPriority
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;

    /* MBA-939: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId = @CustomerId;
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
---------------------------------------------------------------------------------------------
    Quotes straight from Priority over the linked server, keyed by CustomerIdFromSource = CUST.
    Priority stores dates as minutes since 1988-01-01; EXPIRYDATE 0 means "no expiry", hence the
    NULLIF before the conversion.

    2026-08-31 - MBA-939: which customer, when the address serves several.

    Scoped to ONE customer for the same reason as GetCustomerInvoicesFromPriority: pricing is
    commercial information, and merging three subsidiaries' quotes into one list is a business
    decision rather than a display one. The customer picked is now the PRIMARY one - the one
    holding the most devices - instead of whichever had the lowest CustomerContactId.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.
*/
CREATE   PROCEDURE dbo.GetCustomerQuotesFromPriority
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;

    /* MBA-939: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId = @CustomerId;
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
CREATE   PROCEDURE dbo.GetCustomerPortalContactByEmail
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
CREATE   PROCEDURE dbo.CreateCustomerPortalOtp
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
